;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;;
;;; Everything that turns "is this person allowed to do this?" into an answer
;;; lives here: the stateless session helper, and the two operations that keep
;;; a password from being stored in a form that can be read back.
;;;
;;; Autooization model
;;; ------------------
;;; A session is a bewaking token in an HttpOnly cookie.  Nothing about the
;;; session is kept on the server, so `authorized-payload' is the single place
;;; that decides who a request is: it opens the token, checks that the payload
;;; is well-formed and still in date, checks the permissions the route asks
;;; for, and answers with the payload or #f.  Every "no" -- no cookie, a
;;; truncated one, a tampered one, one sealed with a retired key, an expired
;;; one, or one that simply lacks the permission -- is the same #f, so a caller
;;; never has to tell the cases apart and can never half-admit a request.
;;;
;;; Password hashing
;;; ----------------
;;; Passwords used to be stored as a bare SHA-256 of password + salt, which is
;;; one unsalted-by-the-KDF round of a fast hash: cheap for an attacker with a
;;; stolen database and nothing more.  `hash-password' now derives the stored
;;; value with a key-derivation function -- Argon2id (RFC 9106) where
;;; libgcrypt provides it, PBKDF2-HMAC-SHA256 otherwise -- and records which
;;; one, with which parameters and which salt, in the stored string itself.
;;;
;;; Hashes written by the old scheme are still recognised, so nobody is locked
;;; out: `verify-password' answers for both, `password-hash-legacy?' says which
;;; one is on file, and the sign-in route re-hashes a legacy password as soon
;;; as it has seen the plaintext that proves the user knows it.

(define-module (wikimusic auth)
  #:use-module (ice-9 format)
  #:use-module (ice-9 textual-ports)
  #:use-module (rnrs bytevectors)
  #:use-module (srfi srfi-1)
  #:use-module (web uri)
  #:use-module (artanis artanis)
  #:use-module (artanis route)
  ;; `string->sha-256' verifies the passwords still on file in the old scheme;
  ;; it comes from NSS, which Guile reaches through Artanis.
  #:use-module (artanis security nss)
  #:use-module (kracht prelude)
  #:use-module (bewaking bewaking)
  #:use-module (bewaking crypto)
  #:use-module (bewaking password)
  #:use-module (wikimusic env)
  #:export (session-cookie-name session-token-validity-seconds
                                password-reset-validity-seconds
                                authorized-payload
                                back-to-login
                                unauthorized-api-message
                                bewaking-endpoint
                                bewaking-api-endpoint
                                hash-password
                                verify-password
                                password-hash-legacy?
                                preferred-password-algorithm
                                permissions-from-column))

;;; ====== Sessions ======

;; The cookie Artanis is asked to read, and a window for the token inside it.
;; The cookie's own lifetime is set from this, so a cookie never outlives the
;; token it carries and nobody is left half-signed-in.
(define session-cookie-name
  "x-bewaking-wikimusic")
(define session-token-validity-seconds
  (* 7 24 3600))

;; A password-reset link is a sealed object rather than a row, and this is the
;; hour it is good for.
(define password-reset-validity-seconds
  3600)

(define* (authorized-payload #:key token
                             (needed '()))
  "Return the decrypted session payload TOKEN carries, or #f.

The answer is #f for every way a request can fail to be authorized: no token, a
truncated or edited one, one sealed with an unknown or retired key, an expired
one, or one that does not carry every permission in NEEDED.  `decrypt-token'
catches its own errors and answers #f, so the payload must be tested *before*
it is read -- asking a #f payload about its expiry would raise rather than
refuse, which is how a bad cookie used to reach the error page instead of the
sign-in page."
  (let ((payload (and (string? token)
                      (not (string-null? token))
                      (decrypt-token #:token token
                                     #:encryption-key encryption-key
                                     #:signing-key signing-key))))
    (and payload
         (token-valid? #:token payload)
         (has-needed-permissions? #:needed needed
                                  #:present (assoc-ref payload
                                                       'owner-permissions))
         payload)))

(define* (bewaking-endpoint #:key token-name
                            needed-permissions
                            happy-flow
                            unhappy-flow
                            rc)
  "Run HAPPY-FLOW when the request in RC carries a session that holds every
permission in NEEDED-PERMISSIONS, and call UNHAPPY-FLOW with RC otherwise.

TOKEN-NAME is the cookie's *symbol*: Artanis' `#:cookies' declaration and
`:cookies-set!' are written in symbols while `:cookies-value' looks the cookie
up by string."
  (let ((who (authorized-payload #:token (:cookies-value rc
                                                         (symbol->string
                                                          token-name))
                                 #:needed needed-permissions)))
    (if who
        (happy-flow)
        (unhappy-flow rc))))

(define* (bewaking-api-endpoint #:key token-name
                                needed-permissions
                                happy-flow
                                unhappy-flow
                                rc)
  "Like `bewaking-endpoint', but read the token from the request's headers
instead of a cookie, which suits clients that have no cookie jar."
  (let ((who (authorized-payload #:token (get-header rc
                                                     (symbol->string
                                                      token-name))
                                 #:needed needed-permissions)))
    (if who
        (happy-flow)
        (unhappy-flow rc))))

(define (unauthorized-api-message rc)
  (response-emit '((error . "You must be authenticated to use this API endpoint"))
                 #:status 401))

(define (back-to-login rc)
  (redirect-to rc
               (string->uri (format #f "~a/login"
                                    (current-myhost)))
               #:status 302))

;;; ====== Permissions ======
;;;
;;; A user's permissions live in one text column, written as a Scheme list --
;;; `(wikimusic:song-create wikimusic:artist-delete)' -- and read back here.
;;; `read' is the right reader and `eval-string' is not: the column decides what
;;; its holder may do, so reading it must never be able to run anything.  Rows
;;; written before this change carry a quasiquote in front of the list, which
;;; `read' sees as the inert datum it is, so it is unwrapped rather than
;;; refused and nobody loses their permissions to a migration.

(define (datum-second datum)
  "Return the second element of DATUM, or the empty list when there is none."
  (if (and (pair? datum)
           (pair? (cdr datum)))
      (cadr datum)
      '()))

(define (datum-head datum)
  "Return the first element of DATUM, or #f when it does not have one."
  (if (pair? datum)
      (car datum) #f))

(define* (permissions-from-column value)
  "Return the permission list held in the users' PERMISSIONS column VALUE, or
the empty list when the column is empty or cannot be read."
  (catch #t
         (lambda ()
           (if (or (not (string? value))
                   (string-null? value))
               '()
               (let ((datum (read (open-input-string value))))
                 (cond
                   ((eq? (datum-head datum)
                         'quasiquote)
                    (datum-second datum))
                   ((list? datum)
                    datum)
                   (else '())))))
         (lambda (key . args)
           '())))

;;; ====== Passwords ======

;; What `hash-password' derives, and how much work it asks for.  Argon2id is
;; memory-hard, so its cost is memory and passes; PBKDF2's is iterations.  The
;; figures are the ones OWASP suggests for each.
(define argon2id-memory-kib
  65536)
(define argon2id-iterations
  3)
(define argon2id-parallelism
  1)
(define pbkdf2-iterations
  210000)
(define password-hash-length
  32)
(define password-salt-length
  16)

(define (preferred-password-algorithm)
  "Return the symbol naming the strongest password KDF this build can use:
`argon2id' when libgcrypt provides Argon2, and `pbkdf2-sha256' otherwise."
  (if (argon2id-available?)
      'argon2id
      'pbkdf2-sha256))

(define (salt->hex salt)
  (bytes->base16 salt))

(define (hex->salt hex)
  (base16->bytes hex))

(define* (hash-password password
                        #:key (algorithm (preferred-password-algorithm)))
  "Return the string to store for PASSWORD.

The result says how it was made, so a future change of algorithm or cost does
not invalidate the passwords already on file:

  argon2id$<iterations>$<memory-kib>$<parallelism>$<salt>$<derived>
  pbkdf2-sha256$<iterations>$<salt>$<derived>

The salt is drawn fresh here, which is why the users table's own `salt' column
is no longer read for anything but the legacy scheme."
  (let ((salt (random-bytes password-salt-length)))
    (case algorithm
      ((argon2id)
       (format #f
               "argon2id$~a$~a$~a$~a$~a"
               argon2id-iterations
               argon2id-memory-kib
               argon2id-parallelism
               (salt->hex salt)
               (bytes->base16 (argon2id-derive password
                                               salt
                                               password-hash-length
                                               #:memory-kib
                                               argon2id-memory-kib
                                               #:iterations
                                               argon2id-iterations
                                               #:parallelism
                                               argon2id-parallelism))))
      ((pbkdf2-sha256)
       (format #f "pbkdf2-sha256$~a$~a$~a" pbkdf2-iterations
               (salt->hex salt)
               (bytes->base16 (pbkdf2-sha256 password salt
                                             password-hash-length
                                             #:iterations pbkdf2-iterations))))
      (else (error "hash-password: unknown algorithm" algorithm)))))

(define (constant-time-string=? a b)
  "Return #t when strings A and B are equal, comparing every character either
way so that the time taken does not say how much of a wrong value was right."
  (if (not (= (string-length a)
              (string-length b))) #f
      (let loop
        ((i 0)
         (same? #t))
        (if (= i
               (string-length a)) same?
            (loop (+ i 1)
                  (and same?
                       (char=? (string-ref a i)
                               (string-ref b i))))))))

(define (hex-derived=? computed stored)
  "Return #t when the hexadecimal COMPUTED key equals the hexadecimal STORED
one, in a way that does not leak where they first differ."
  (and (string? stored)
       (constant-time-string=? computed stored)))

(define (verify-argon2id password stored)
  (let ((parts (string-split stored #\$)))
    (if (not (= (length parts) 6)) #f
        (let ((iterations (string->number (list-ref parts 1)))
              (memory-kib (string->number (list-ref parts 2)))
              (parallelism (string->number (list-ref parts 3)))
              (salt (catch #t
                           (lambda ()
                             (hex->salt (list-ref parts 4)))
                           (lambda (key . args)
                             #f)))
              (expected (list-ref parts 5)))
          (if (or (not iterations)
                  (not memory-kib)
                  (not parallelism)
                  (not salt)) #f
              (catch #t
                     (lambda ()
                       (hex-derived=? (bytes->base16 (argon2id-derive password
                                                      salt
                                                      (/ (string-length
                                                          expected) 2)
                                                      #:memory-kib memory-kib
                                                      #:iterations iterations
                                                      #:parallelism
                                                      parallelism)) expected))
                     (lambda (key . args)
                       #f)))))))

(define (verify-pbkdf2 password stored)
  (let ((parts (string-split stored #\$)))
    (if (not (= (length parts) 4)) #f
        (let ((iterations (string->number (list-ref parts 1)))
              (salt (catch #t
                           (lambda ()
                             (hex->salt (list-ref parts 2)))
                           (lambda (key . args)
                             #f)))
              (expected (list-ref parts 3)))
          (if (or (not iterations)
                  (not salt)) #f
              (catch #t
                     (lambda ()
                       (hex-derived=? (bytes->base16 (pbkdf2-sha256 password
                                                      salt
                                                      (/ (string-length
                                                          expected) 2)
                                                      #:iterations iterations))
                                      expected))
                     (lambda (key . args)
                       #f)))))))

(define (verify-legacy-password password hash salt)
  "Verify PASSWORD the way wikimusic did before passwords were derived with a
KDF: SHA-256 over the password followed by the salt kept beside it."
  (and (string? hash)
       (string? salt)
       (constant-time-string=? (string->sha-256 (string-append password salt))
                               hash)))

(define (password-hash-legacy? hash)
  "Return #t when HASH was written by the old scheme, which `verify-password'
still accepts and which a successful sign-in replaces."
  (and (string? hash)
       (not (string-prefix? "argon2id$" hash))
       (not (string-prefix? "pbkdf2-sha256$" hash))))

(define* (verify-password password
                          #:key hash salt)
  "Return #t when PASSWORD is the password HASH was derived from.

HASH is the users table's `password' column and SALT its `salt' column: the
current schemes carry their own salt, the legacy one needs the column, and a
row whose hash is missing or unreadable is simply not a match."
  (cond
    ((not (string? hash))
     #f)
    ((string-prefix? "argon2id$" hash)
     (verify-argon2id password hash))
    ((string-prefix? "pbkdf2-sha256$" hash)
     (verify-pbkdf2 password hash))
    (else (verify-legacy-password password hash salt))))
