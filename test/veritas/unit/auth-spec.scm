;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;;
;;; The three questions (wikimusic auth) answers, each answered here without a
;;; request in sight: does this token name a signed-in person who may do what
;;; the route asks, is this the password that hash was derived from, and what
;;; does the permissions column mean.
;;;
;;; The token cases are built on `generate-token' from bewaking, which is the
;;; same call the sign-in route makes, so what is tested is wikimusic's reading
;;; of a token rather than bewaking's sealing of one.  Every way of failing is
;;; expected to be the same #f: that is the property the module's commentary
;;; promises, and the reason a bad cookie reaches the sign-in page instead of
;;; the error page.

(define-module (veritas unit auth-spec)
  #:use-module (veritas veritas)
  #:use-module (ice-9 format)
  #:use-module (artanis security nss)
  #:use-module (bewaking bewaking)
  #:use-module (wikimusic auth)
  #:use-module (wikimusic env)
  #:export (spec))

(define password
  "correct horse battery staple")

(define (owned-permissions permissions)
  "Return the permission list a session sealed for a reader holding
PERMISSIONS carries."
  permissions)

(define (owner-details permissions)
  "Return a thunk describing a signed-in owner holding PERMISSIONS, in the
shape `generate-token' reads."
  (lambda ()
    (list (cons 'id "8b3f6a1e-1c2d-4e5f-8a9b-0c1d2e3f4a5b")
          (cons 'email "joe@example.org")
          (cons 'name "joe")
          (cons 'permissions permissions))))

(define* (sealed-token #:key (permissions '(wikimusic:song-create))
                       (validity 3600)
                       (encryption-key encryption-key)
                       (signing-key signing-key))
  "Return a session token sealed the way the sign-in route seals one."
  (generate-token #:encryption-key encryption-key
                  #:signing-key signing-key
                  #:get-owner-details (owner-details permissions)
                  #:token-validity-seconds validity))

(define (fields hash)
  "Return the `$'-separated fields of a stored password HASH."
  (string-split hash #\$))

;;; ====== The hashes and the verifications the suites read ======
;;;
;;; A veritas test body is evaluated when the test runs, and it runs in a fiber
;;; -- so work a case does is work done on the fiber scheduler's stack.  An
;;; Argon2id derivation is not something libgcrypt will do there: the call fails
;;; with "gcry_kdf_final (Argon2id) failed" inside a fiber and answers exactly as
;;; it should on this process's main thread or on a thread of its own (it asks
;;; for 64 MiB per call besides, see `hash-password').  The derivations the two
;;; password suites are about are therefore made here, once, when this module is
;;; loaded, and the cases compare the facts they produced.
;;;
;;; That is how the suite reads anyway: a hash is a fact about a password, and
;;; what the tests are about is what the interface makes of one -- which scheme
;;; it names, what cost it records, and whether the right password is the only
;;; one that verifies.
(define preferred-hash
  (hash-password password))
(define another-hash
  (hash-password password))
(define argon2id-hash
  (hash-password password
                 #:algorithm 'argon2id))
(define argon2id-fields
  (fields argon2id-hash))
(define pbkdf2-hash
  (hash-password password
                 #:algorithm 'pbkdf2-sha256))
(define pbkdf2-fields
  (fields pbkdf2-hash))
(define preferred-verifies?
  (verify-password password
                   #:hash preferred-hash
                   #:salt ""))
(define fallback-verifies?
  (verify-password password
                   #:hash pbkdf2-hash
                   #:salt ""))
(define salt-column-ignored?
  (verify-password password
                   #:hash preferred-hash
                   #:salt "irrelevant"))
(define near-miss-refused?
  (verify-password "correct horse battery stapl"
                   #:hash preferred-hash
                   #:salt ""))
(define wrong-case-refused?
  (verify-password "Correct horse battery staple"
                   #:hash preferred-hash
                   #:salt ""))
(define empty-refused?
  (verify-password ""
                   #:hash preferred-hash
                   #:salt ""))
;; The hash a sign-in re-derives from a password that was on file in the old
;; scheme (see the legacy test below).
(define rehashed-legacy
  (hash-password "hunter2"))

(define password-suite
  (suite "Passwords on file"
         (test "a hash names the scheme it was derived with"
               (assert-equal #:name "an argon2id hash says so"
                             #:expect "argon2id"
                             #:got (car argon2id-fields))
               (assert-equal #:name
                "and carries iterations, memory, lanes, salt and key"
                #:expect 6
                #:got (length argon2id-fields))
               (assert-equal #:name "a pbkdf2 hash says so"
                             #:expect "pbkdf2-sha256"
                             #:got (car pbkdf2-fields))
               (assert-equal #:name "and carries iterations, salt and key"
                             #:expect 4
                             #:got (length pbkdf2-fields)))
         (test "the recorded cost is at least the cost that was chosen"
               ;; Argon2id is the scheme a build with libgcrypt uses, and its
               ;; figures are OWASP's: two passes and at least 19 MiB.  The
               ;; PBKDF2 fallback asks for 210000 iterations, which is where
               ;; wikimusic set it; the point of the assertion is that the
               ;; cost is recorded in the hash and cannot be lowered quietly.
               (assert-true (>= (string->number (cadr argon2id-fields)) 2)
                            #:name "argon2id does at least two passes")
               (assert-true (>= (string->number (caddr argon2id-fields)) 19456)
                            #:name "and asks for at least 19 MiB a pass")
               (assert-true (>= (string->number (cadr pbkdf2-fields)) 210000)
                            #:name "pbkdf2 does at least 210000 iterations"))
         (test "the same password hashed twice is never the same hash"
               (assert-true (not (equal? preferred-hash another-hash))
                            #:name "the salt is drawn fresh every time"))))

(define verification-suite
  (suite "Checking a password"
         (test "the password a hash was derived from verifies"
               (assert-true preferred-verifies?
                            #:name "the preferred scheme round trips")
               (assert-true fallback-verifies?
                            #:name "and so does the fallback scheme")
               (assert-true salt-column-ignored?
                            #:name "the salt column no longer decides"))
         (test "a hash was only derived from the one password"
               (assert-false near-miss-refused?
                             #:name "a password missing its last character")
               (assert-false wrong-case-refused?
                             #:name "a password with the wrong case")
               (assert-false empty-refused?
                             #:name "the empty password"))
         (test "a hash that cannot be read is not a match"
               (assert-false (verify-password password
                                              #:hash #f
                                              #:salt "")
                             #:name "no hash at all")
               (assert-false (verify-password password
                                              #:hash
                                              "argon2id$3$65536$1$nothex$aa"
                                              #:salt "")
                             #:name "an argon2id salt that is not hexadecimal")
               (assert-false (verify-password password
                                              #:hash
                                              "argon2id$three$65536$1$ab$cd"
                                              #:salt "")
                             #:name "an argon2id cost that is not a number")
               (assert-false (verify-password password
                                              #:hash "argon2id$3$65536$1$ab"
                                              #:salt "")
                             #:name "an argon2id hash with a field missing")
               (assert-false (verify-password password
                                              #:hash "pbkdf2-sha256$210000$ab"
                                              #:salt "")
                             #:name "a pbkdf2 hash with a field missing"))
         (test "a password hashed before the change still verifies"
               ;; The old scheme was SHA-256 over the password followed by the
               ;; salt kept in its own column; nobody is locked out by the
               ;; change, and the sign-in route re-hashes it afterwards.
               (let ((legacy (string->sha-256 (string-append "hunter2"
                                                             "pepper"))))
                 (assert-true (verify-password "hunter2"
                                               #:hash legacy
                                               #:salt "pepper")
                              #:name "the right password still signs in")
                 (assert-false (verify-password "hunter3"
                                                #:hash legacy
                                                #:salt "pepper")
                               #:name "the wrong one still does not")
                 (assert-true (password-hash-legacy? legacy)
                              #:name
                              "and the row is recognisable as an old one")
                 (assert-false (password-hash-legacy? rehashed-legacy)
                               #:name "while a derived hash is not")))
         (test "a row with no usable hash is refused rather than crashed on"
               (assert-false (password-hash-legacy? #f)
                             #:name "no hash is not a legacy hash")
               (assert-false (password-hash-legacy? 'not-a-string)
                             #:name "nor is something that is not a string"))))

(define permissions-suite
  (suite "The permissions column"
         (test "a list of permissions is read as written"
               (assert-equal #:name "one permission"
                             #:expect '(wikimusic:song-create)
                             #:got (permissions-from-column
                                    "(wikimusic:song-create)"))
               (assert-equal #:name "several, in order"
                             #:expect '(wikimusic:song-create
                                        wikimusic:artist-delete)
                             #:got (permissions-from-column
                                    "(wikimusic:song-create wikimusic:artist-delete)")))
         (test "the column is read, never run"
               ;; `read' returns the form as data, whatever the form says, and
               ;; `eval-string' would have run it: this is the difference
               ;; between a column that decides who may write and a column
               ;; that decides what the server does.
               (assert-equal #:name
                             "a form naming a procedure comes back as data"
                             #:expect '(system "rm -rf /")
                             #:got (permissions-from-column
                                    "(system \"rm -rf /\")"))
               (assert-equal #:name "and so does a lambda"
                             #:expect '(lambda (x)
                                         x)
                             #:got (permissions-from-column "(lambda (x) x)")))
         (test "a row written before the change still yields its permissions"
               (assert-equal #:name "a quasiquoted list is unwrapped"
                             #:expect '(wikimusic:song-create)
                             #:got (permissions-from-column
                                    "`(wikimusic:song-create)"))
               (assert-equal #:name "the long spelling of it too"
                             #:expect '(wikimusic:song-create)
                             #:got (permissions-from-column
                                    "(quasiquote (wikimusic:song-create))")))
         (test "anything that is not a list of permissions is an empty list"
               (assert-equal #:name "an empty column"
                             #:expect '()
                             #:got (permissions-from-column ""))
               (assert-equal #:name "no column at all"
                             #:expect '()
                             #:got (permissions-from-column #f))
               (assert-equal #:name "an unreadable column"
                             #:expect '()
                             #:got (permissions-from-column "( (("))
               (assert-equal #:name "a bare symbol"
                             #:expect '()
                             #:got (permissions-from-column
                                    "wikimusic:song-create"))
               (assert-equal #:name "a string"
                             #:expect '()
                             #:got (permissions-from-column "\"all\"")))))

(define session-suite
  (suite "Reading a session"
         (test "a token sealed with the project's keys names its owner"
               (let ((payload (authorized-payload #:token (sealed-token))))
                 (assert-equal #:name "the owner's identifier comes back"
                               #:expect "8b3f6a1e-1c2d-4e5f-8a9b-0c1d2e3f4a5b"
                               #:got (assoc-ref payload
                                                'owner-id))
                 (assert-equal #:name "and the permissions it was sealed with"
                               #:expect (owned-permissions '(wikimusic:song-create))
                               #:got (assoc-ref payload
                                                'owner-permissions))
                 (assert-true (number? (assoc-ref payload
                                                  'token-expires-at))
                              #:name "the payload carries its own expiry")))
         (test "a route's permission has to be one the session holds"
               (let ((token (sealed-token #:permissions '(wikimusic:song-create
                                                          wikimusic:song-edit))))
                 (assert-true (and (authorized-payload #:token token
                                                       #:needed '(wikimusic:song-create))
                                   #t)
                              #:name "the permission it holds is granted")
                 (assert-true (and (authorized-payload #:token token
                                                       #:needed '(wikimusic:song-create
                                                                  wikimusic:song-edit))
                                   #t)
                              #:name "and so is a set it holds in full")
                 (assert-false (authorized-payload #:token token
                                                   #:needed '(wikimusic:user-delete))
                               #:name "one it does not hold is refused")
                 (assert-true (and (authorized-payload #:token token) #t)
                  #:name "with no permission asked for, a session is enough")))
         (test "every way of failing is the same no"
               (assert-false (authorized-payload)
                             #:name "no token at all")
               (assert-false (authorized-payload #:token #f)
                             #:name "a false token")
               (assert-false (authorized-payload #:token "")
                             #:name "an empty cookie")
               (assert-false (authorized-payload #:token "not-a-token")
                             #:name "a cookie that is not even an envelope")
               (assert-false (authorized-payload #:token (number->string (current-time)))
                             #:name "a cookie of some other shape"))
         (test "a token that has been altered does not open"
               (let ((token (sealed-token)))
                 (assert-false (authorized-payload #:token (substring token 0
                                                                      (- (string-length
                                                                          token)
                                                                         8)))
                               #:name "a truncated token")
                 (assert-false (authorized-payload #:token (string-append
                                                            token "x"))
                               #:name "a token with something appended")))
         (test "an expired session is no session"
               (assert-false (authorized-payload #:token (sealed-token
                                                                       #:validity
                                                                       -10))
                             #:name "a validity that is already behind it"))
         (test "a token sealed under another key is not ours"
               (assert-false (authorized-payload #:token (sealed-token
                                                          #:encryption-key
                                                          "00000000-0000-0000-0000-000000000000"))
                             #:name "a token sealed with a key we do not hold")
               (assert-false (authorized-payload #:token (sealed-token
                                                          #:signing-key
                                                          "00000000-0000-0000-0000-000000000000"))
                             #:name "nor one signed with another"))))

(define (spec)
  (veritas-run password-suite verification-suite permissions-suite
               session-suite))
