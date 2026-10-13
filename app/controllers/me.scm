;;; wikimusic - free and open project management for everyone

;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;; wikimusic is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; wikimusic is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU Affero General Public License for more details.

;; You should have received a copy of the GNU Affero General Public License
;; along with wikimusic.  If not, see <https://www.gnu.org/licenses/>.

(define-artanis-controller me)

(import (wikimusic html)
        (web uri)
        (ice-9 string-fun)
        (app models users)
        (wikimusic env)
        (wikimusic auth)
        (wikimusic controller)
        (wikimusic sqlite util)
        (kracht prelude)
        (app views me)
        (curl)
        (uuid generate)
        (rnrs bytevectors)
        (json)
        (artanis security nss)
        (bewaking bewaking)
        (bewaking password))

(get "/me"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (let* ((t (decrypt-token #:token (:cookies-value rc
                                         "x-bewaking-wikimusic")
                                #:encryption-key encryption-key
                                #:signing-key signing-key))
              (user ($users 'get
                            #:ret 'top
                            #:condition (where #:identifier (assoc-ref t
                                                                       'owner-id)))))
         
         (catch #t
                (lambda ()
                  (response-emit (:mime rc
                                        (me-page (:i18n rc)
                                                 #:user (car user)
                                                 #:token t
                                                 #:is-logged-in (:cookies-value
                                                                 rc
                                                                 "x-bewaking-wikimusic")))))
                (lambda (key . args)
                  (display (format #f
                            "error getting user details-me page: ~a: ~a" key
                            args))
                  (redirect-to rc
                               (string->uri (format #f "~a/login"
                                                    (current-myhost)))
                               #:status 302))))))

(get "/users/manage"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (define (go-to-users-management)
         (let* ((t (decrypt-token #:token (:cookies-value rc
                                           "x-bewaking-wikimusic")
                                  #:encryption-key encryption-key
                                  #:signing-key signing-key))
                (user ($users 'get
                              #:ret 'top
                              #:condition (where #:identifier (assoc-ref t
                                                                         'owner-id))))
                (users ($users 'get
                               #:ret 'all
                               #:order-by '(username asc))))
           (response-emit (:mime rc
                                 (users-page (:i18n rc)
                                             #:users users)))))

       (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                          #:needed-permissions '(wikimusic:modify-permissions)
                          #:rc rc
                          #:happy-flow go-to-users-management
                          #:unhappy-flow back-to-login)))

(get "/users/new"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (define (go-to-new-user)
         (let* ((t (decrypt-token #:token (:cookies-value rc
                                           "x-bewaking-wikimusic")
                                  #:encryption-key encryption-key
                                  #:signing-key signing-key))
                (user ($users 'get
                              #:ret 'top
                              #:condition (where #:identifier (assoc-ref t
                                                                         'owner-id))))
                (users ($users 'get
                               #:ret 'all
                               #:order-by '(username asc))))
           (response-emit (:mime rc
                                 (new-user-page (:i18n rc))))))

       (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                          #:needed-permissions '(wikimusic:user-create)
                          #:rc rc
                          #:happy-flow go-to-new-user
                          #:unhappy-flow back-to-login)))

(get "/users/edit/:identifier"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (define (go-to-edit-user)
         (let* ((user (car ($users 'get
                                   #:ret 'top
                                   #:condition (where #:identifier (params rc
                                                                    "identifier"))))))
           (response-emit (:mime rc
                                 (edit-user-page (:i18n rc) user)))))

       (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                          #:needed-permissions '(wikimusic:modify-permissions)
                          #:rc rc
                          #:happy-flow go-to-edit-user
                          #:unhappy-flow back-to-login)))

(define (from-checkbox body n)
  (if (assoc-ref body
                 (symbol->string n)) n #f))

(post "/users/new"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-new-user)
          (let* ((G_ (:i18n rc))
                 (existing-token (if (:cookies-value rc "x-bewaking-wikimusic")
                                     (decrypt-token #:token (:cookies-value rc
                                                             "x-bewaking-wikimusic")
                                                    #:encryption-key
                                                    encryption-key
                                                    #:signing-key signing-key)
                                     #f))
                 (body (body-alist rc))
                 (username (html-escape (assoc-ref body "username")))
                 (email (html-escape (assoc-ref body "email")))
                 (permissions (filter (lambda (p)
                                        (not (equal? #f p)))
                                      (map (lambda (p)
                                             (from-checkbox body p))
                                           '(wikimusic:song-create
                                             wikimusic:song-delete
                                             wikimusic:artist-create
                                             wikimusic:artist-delete
                                             wikimusic:genre-create
                                             wikimusic:genre-delete
                                             wikimusic:user-create
                                             wikimusic:user-delete
                                             wikimusic:modify-permissions))))
                 (new-id (generate-string-uuid))
                 (_ ($users 'set
                            #:identifier new-id
                            #:username username
                            #:email email
                            #:permissions (format #f "`~s" permissions)))
                 (u ($users 'get
                            #:ret 'top
                            #:condition (where #:identifier new-id))))
            ;; The account exists either way; what the administrator is told
            ;; about is the invitation, because that is the part that can
            ;; fail without them being able to see it.  An account whose
            ;; mail could not be queued is not a lost account -- the same
            ;; link goes out again the next time it is asked for -- but
            ;; saying "created" and stopping there would leave them waiting
            ;; for a mail that is never coming.
            (let ((queued? (request-password-reset u)))
              (redirect-to rc
                           (string->uri
                            (format #f
                                    "~a/users/manage/?created=true~a"
                                    (current-myhost)
                                    (if queued?
                                        (notice-query
                                         #:title (G_ "account created")
                                         #:body
                                         (G_ "an invitation to choose a password has been emailed to them"))
                                        (notice-query
                                         #:title (G_ "account created, but the invitation was not sent")
                                         #:body
                                         (G_ "the mail service did not accept it; ask for a password reset for this account to try again")
                                         #:duration-millis 10000))))
                           #:status 302))))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:user-create)
                           #:rc rc
                           #:happy-flow do-new-user
                           #:unhappy-flow back-to-login)))

(post "/users/delete"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-delete-user)
          (let* ((G_ (:i18n rc))
                 (body (body-alist rc))
                 (identifier (assoc-ref body "identifier"))
                 (_ ($users 'mod
                            'row-delete
                            (where #:identifier identifier))))
            (redirect-to rc
                         (string->uri (format #f
                                              "~a/users/manage/?deleted=true"
                                              (current-myhost)))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:user-delete)
                           #:rc rc
                           #:happy-flow do-delete-user
                           #:unhappy-flow back-to-login)))

(post "/users/edit/:identifier"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-edit-user)
          (let* ((G_ (:i18n rc))
                 (body (body-alist rc))
                 (username (html-escape (assoc-ref body "username")))
                 (email (html-escape (assoc-ref body "email")))
                 (permissions (filter (lambda (p)
                                        (not (equal? #f p)))
                                      (map (lambda (p)
                                             (from-checkbox body p))
                                           '(wikimusic:song-create
                                             wikimusic:song-delete
                                             wikimusic:artist-create
                                             wikimusic:artist-delete
                                             wikimusic:genre-create
                                             wikimusic:genre-delete
                                             wikimusic:user-create
                                             wikimusic:user-delete
                                             wikimusic:modify-permissions))))
                 (_ (sql-execute! rc
                                  (sql-update 'users
                                              `((username . ,username)
                                                (email . ,email)
                                                (permissions
                                                 . ,(format #f "~s"
                                                            permissions)))
                                              #:where `((identifier
                                                         . ,(params rc
                                                                   "identifier"))))
                                  #:name "edit-user")))
            (redirect-to rc
                         (string->uri (format #f
                                              "~a/users/manage/?edited=true"
                                              (current-myhost)))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:modify-permissions)
                           #:rc rc
                           #:happy-flow do-edit-user
                           #:unhappy-flow back-to-login)))

;; A reset link is worth a page only while its envelope still opens *and* the
;; account it names is still there.  Everything else -- a truncated or edited
;; link, one whose hour is up, one for a user since deleted -- is answered by
;; sending the visitor to the sign-in page instead of the error page: a link
;; that can no longer be honoured is not a server fault, and the person who
;; clicked it a day late needs somewhere to go.
(get "/password/reset/token/:token"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((G_ (:i18n rc))
              (sealed-payload (decrypt-object #:object (params rc "token")
                                              #:encryption-key encryption-key
                                              #:signing-key signing-key))
              (user-id (and (not (nil? sealed-payload))
                            (equal? 'reset-password
                                    (assoc-ref sealed-payload 'action))
                            (assoc-ref sealed-payload 'user)))
              (user (and user-id ($users 'get
                                         #:ret 'top
                                         #:condition (where #:identifier
                                                            user-id))))
              (email (and (not (nil? user)) (assoc-ref (car user) "email"))))
         (if (not email)
             (redirect-to rc
                          (string->uri
                           (format #f "~a/login?reset-link-expired=true~a"
                                   (current-myhost)
                                   (notice-query
                                    #:title (G_ "this reset link has expired")
                                    #:body
                                    (G_ "ask for a new one and a fresh link will be emailed to you")
                                    #:duration-millis 8000)))
                          #:status 302)
             (response-emit (:mime rc
                                   (reset-password-page (:i18n rc)
                                                        #:token (params rc "token")
                                                        ;; The reason the last submission came
                                                        ;; back, when it did: `weak' or
                                                        ;; `mismatch', and #f on a first visit.
                                                        #:rejected (get-from-qstr
                                                                    rc
                                                                    "password-rejected")
                                                        #:email email)))))))

;; ====== Handing a mail to pingwing ======
;;
;; Every message the site sends -- a reset link, an invitation -- leaves
;; through one call, and a mail that never leaves is a reader who cannot get
;; back in.  So the sending is not fire-and-forget: an attempt that does not
;; land is made again, and the answer is read rather than assumed.
;;
;; What "landed" means is the service's own sentence.  pingwing answers a
;; queued task with `{"message": "successfully saved task to pingwing
;; system"}', and answers a task it could not save with an error sentence in
;; the same shape -- so the reply is tested for the sentence of acceptance,
;; and anything else is a failed attempt to be repeated: an error page, an
;; empty body, a refused connection, a transfer that ran out of time.  Reading
;; the body is also the only thing available here, since guile-curl hands back
;; a body but no status code.
;;
;; The attempts are made inside the request that asks for them, so the reader
;; waits while they happen.  That is deliberate: the point of retrying is that
;; the reader gets their mail, and the alternative -- handing the work to a
;; thread nobody is watching -- would let the page say a thing was sent when
;; nobody knows whether it was.  The timeout and the pauses are short enough
;; that a healthy service delays nobody, and a dead one costs a few seconds
;; rather than the message.
(define mail-attempts 3)

;; How long the first pause between attempts is; each later pause is twice the
;; one before it, so a service that is restarting gets room to come back.  It
;; is written in milliseconds because that is what `usleep' takes -- a sleep
;; of half a second is not an integer number of seconds.
(define mail-attempt-pause-milliseconds 500)

;; A request that never finishes is exactly the failure a retry is for, so
;; both the connection and the whole transfer are bounded.
(define mail-timeout-seconds 6)
(define mail-connect-timeout-seconds 3)

;; The sentence pingwing answers an accepted task with.  It is quoted here
;; rather than paraphrased: it is the service's own wording, and a rewording
;; there would make every mail look unsent and be sent over and over.
(define mail-accepted-sentence "successfully saved task")

;; Where this machine's trust anchors are.
;;
;; libcurl verifies a TLS certificate against a bundle file or a directory of
;; hashed certificates, and it has no default to fall back on when it is built
;; without one.  The failure is not the service refusing anything: the request
;; never leaves, and what curl says is this.
;;
;;   server certificate verification failed.  CAfile: none CRLfile: none
;;
;; Which is what every mail this site sent was met with, silently, because the
;; result of the request was never looked at.  The anchors are therefore looked
;; for the way the rest of the machine's tools find them: from the environment
;; when it names them, and otherwise where a unix puts them.
(define trust-anchor-bundle-paths
  '("/etc/ssl/certs/ca-certificates.crt"
    "/etc/ssl/certs/ca-bundle.crt"
    "/etc/pki/tls/certs/ca-bundle.crt"
    "/etc/ssl/cert.pem"))

(define trust-anchor-directories
  '("/etc/ssl/certs"
    "/etc/pki/tls/certs"))

(define (first-existing paths)
  "Return the first of PATHS that is on disk, or #f when none of them is."
  (let loop ((rest paths))
    (cond
     ((null? rest) #f)
     ((and (string? (car rest)) (file-exists? (car rest))) (car rest))
     (else (loop (cdr rest))))))

(define (trust-anchor-bundle)
  "Return the path of a file of certificate authorities, or #f."
  (first-existing (cons (getenv "SSL_CERT_FILE") trust-anchor-bundle-paths)))

(define (trust-anchor-directory)
  "Return the path of a directory of hashed certificate authorities, or #f.

@code{SSL_CERT_DIR} may name several, separated by colons, which is also the
shape the option below takes."
  (first-existing (cons (getenv "SSL_CERT_DIR") trust-anchor-directories)))

(define (mail-clock)
  "Return a reading of the wall clock in microseconds.

`gettimeofday' answers in whole seconds and microseconds, and an attempt that
succeeds takes a fraction of a second -- so the seconds alone would report
every healthy attempt as having taken no time at all."
  (let ((now (gettimeofday)))
    (+ (* (car now) 1000000) (cdr now))))

(define (mail-recipient-addresses mail-payload)
  "Return the addresses a mail is addressed to, as one comma-separated line.

Only the addresses are read out of the payload: what the mail carries is a
reset link or an invitation, and neither belongs in a log."
  (let ((recipients (assoc-ref mail-payload 'recipients)))
    (if (vector? recipients)
        (format #f "~{~a~^, ~}"
                (map (lambda (one)
                       (or (assoc-ref one 'address) "?"))
                     (vector->list recipients)))
        "?")))

(define (post-mail-once mail-payload)
  "Hand MAIL-PAYLOAD to pingwing once, and answer whether it was accepted.

Anything other than the service's own sentence of acceptance -- a refused
connection, a timeout, a 500 carrying an error sentence, a body that cannot be
read as text -- is answered with #f and no raised error: a mail that could not
be sent is an outcome of the attempt, not a fault of the request that asked
for it."
  (catch #t
         (lambda ()
           (let ((handle (curl-easy-init)))
             (dynamic-wind
              (lambda () #t)
              (lambda ()
                (curl-easy-setopt handle 'post #t)
                (curl-easy-setopt handle 'url
                                  (format #f "~a/api/v1/tasks" pingwing-url))
                (curl-easy-setopt handle 'postfields
                                  (string->utf8 (scm->json-string mail-payload)))
                ;; The payload is JSON, and saying so is what lets the service
                ;; read it as one rather than as a form.
                (curl-easy-setopt handle 'httpheader
                                  (list "Content-Type: application/json"))
                (curl-easy-setopt handle 'connecttimeout
                                  mail-connect-timeout-seconds)
                (curl-easy-setopt handle 'timeout mail-timeout-seconds)
                (curl-easy-setopt handle 'use-ssl 1)
                ;; Verification is on -- it is the point of TLS -- but curl has
                ;; to be told where to verify against, which is the one thing
                ;; this binding does not do for itself.
                (let ((bundle (trust-anchor-bundle)))
                  (if bundle
                      (curl-easy-setopt handle 'cainfo bundle)))
                (let ((anchors (trust-anchor-directory)))
                  (if anchors
                      (curl-easy-setopt handle 'capath anchors)))
                (curl-easy-setopt handle 'username pingwing-basic-auth-user)
                (curl-easy-setopt handle 'password pingwing-basic-auth-password)
                ;; `verbose' is left alone on purpose: it prints the request's
                ;; own headers, and one of them is the service's password.
                (let* ((answer (curl-easy-perform handle #t))
                       ;; A refusal arrives two ways: as a raised error, and as
                       ;; no answer at all, since this binding hands back a
                       ;; body or #f -- it exposes no status code.  Both are
                       ;; answered with #f, and what curl itself has to say
                       ;; about it is written where an operator can read it.
                       (body (and (bytevector? answer)
                                  (catch #t
                                         (lambda () (utf8->string answer))
                                         (lambda (key . args) "")))))
                  (if (and body
                           (string-contains body mail-accepted-sentence))
                      #t
                      (begin
                        (format (current-error-port)
                                "wikimusic mail: the service did not accept the task (curl: ~a)~%"
                                (curl-error-string))
                        #f))))
              (lambda () (curl-easy-cleanup handle)))))
         (lambda (key . args)
           ;; Why an attempt failed is worth a line of its own: a request the
           ;; service refused and a request this side could not even build
           ;; look the same from the outside, and only one of them is the
           ;; service's fault.
           (format (current-error-port)
                   "wikimusic mail: the attempt itself failed: ~a ~a~%"
                   key
                   args)
           #f)))

(define* (send-to-pingwing #:key body)
  "Ask pingwing to queue BODY, trying again when an attempt does not land, and
answer whether it was queued.

A failure is logged -- naming who the mail was for and which template it was,
and never what it carried -- because a mail that was not sent is something an
operator has to be able to find out, and nothing else can tell them."
  (let loop ((attempt 1) (pause mail-attempt-pause-milliseconds)
             (started (mail-clock)))
    (let ((landed? (post-mail-once body))
          (elapsed (/ (- (mail-clock) started) 1000000.0)))
      ;; A log line is worth nothing while it sits in a buffer: an operator
      ;; reading this file is reading it *because* something is wrong now.
      (force-output (current-error-port))
      (if landed?
          (begin
            (format (current-error-port)
                    "wikimusic mail: queued ~a for ~a (attempt ~a, ~,1fs)~%"
                    (assoc-ref body 'template)
                    (mail-recipient-addresses body)
                    attempt
                    elapsed)
            #t)
          (if (>= attempt mail-attempts)
              (begin
                (format (current-error-port)
                        "wikimusic mail: could not queue ~a for ~a after ~a attempt(s) in ~,1fs~%"
                        (assoc-ref body 'template)
                        (mail-recipient-addresses body)
                        attempt
                        elapsed)
                #f)
              (begin
                ;; How long each attempt took is worth saying: it is the
                ;; difference between a service that is refusing and one
                ;; that never answers, and the two want different fixes.
                (format (current-error-port)
                        "wikimusic mail: attempt ~a did not land after ~,1fs; trying again in ~ams~%"
                        attempt elapsed pause)
                (force-output (current-error-port))
                (usleep (* pause 1000))
                (loop (+ attempt 1) (* 2 pause) started)))))))

(define (request-password-reset u)
  "Mail U, the row of the account, a link to choose a new password.

Answer whether the mail was queued, so a caller that can tell somebody -- an
administrator who has just made the account, and who alone knows both that it
exists and that a mail was expected -- can say that it was not."
  (let* ((user-identifier (assoc-ref (car u) "identifier"))
         ;; The reset link is a sealed object rather than a row: bewaking
         ;; encrypts and authenticates the little payload below, records when it
         ;; was sealed and when it expires in the envelope's own header, and
         ;; refuses to open it once that hour is up.  Nothing has to be stored,
         ;; expired links leave nothing behind, and the link cannot be edited
         ;; into somebody else's.
         (reset-token (encrypt-object #:payload `((user . ,user-identifier)
                                                  (action
                                                   . reset-password))
                                      #:encryption-key encryption-key
                                      #:signing-key signing-key
                                      #:ttl-seconds password-reset-validity-seconds))
         (mail-payload `((task-type . send-email) (template . password-reset)
                         (template-vars (system-name . Wikimusic)
                                        (user unquote
                                              (assoc-ref (car u) "email"))
                                        (reset-link unquote
                                                    (format #f
                                                     "~a/password/reset/token/~a"
                                                     (current-myhost)
                                                     reset-token)))
                         (sender-name . "No Reply - Wikimusic")
                         (sender-address . "noreply@mail.jointhefreeworld.org")
                         (subject . "Wikimusic - Password Reset")
                         (recipients . #(((name unquote (assoc-ref (car u) "username")) (address unquote (assoc-ref (car u) "email"))))))))
    (send-to-pingwing #:body mail-payload)))

(post "/password/reset"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (let* ((G_ (:i18n rc))
               (existing-token (if (:cookies-value rc "x-bewaking-wikimusic")
                                   (decrypt-token #:token (:cookies-value rc
                                                           "x-bewaking-wikimusic")
                                                  #:encryption-key
                                                  encryption-key
                                                  #:signing-key signing-key)
                                   #f))
               (body (body-alist rc))
               (email (assoc-ref body "email"))
               (u (if (not email)
                      ($users 'get
                              #:ret 'top
                              #:condition (where #:identifier (assoc-ref
                                                               existing-token
                                                               'owner-id)))
                      ($users 'get
                              #:ret 'top
                              #:condition (where #:email email)))))
          ;; An address that is not on file is answered exactly like one that
          ;; is: the same redirect, and no mail.  Asking for a reset used to
          ;; raise here -- `car' of an empty result -- which turned a typo in
          ;; the email box into an internal error, and it also said out loud
          ;; whether an address is registered.
          (when (not (nil? u))
            (request-password-reset u))
          ;; The words are the same whether the address is on file or not, and
          ;; whether or not the mail was queued -- which is the point: this
          ;; page cannot be used to ask whether somebody has an account here.
          ;; A mail that could not be sent is recorded in the log the sender
          ;; keeps, where an operator can see it.
          (redirect-to rc
                       (string->uri
                        (format #f "~a/?sent-password-reset=true~a"
                                (current-myhost)
                                (notice-query
                                 #:title (G_ "check your email")
                                 #:body
                                 (G_ "if an account uses that address, a link to choose a new password is on its way")
                                 #:duration-millis 8000)))
                       #:status 302))))

(post "/password/do-reset"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (let* ((G_ (:i18n rc))
               (body (body-alist rc))
               (email (assoc-ref body "email"))
               (reset-token (assoc-ref body "reset-token"))
               (new-password (assoc-ref body "new-password"))
               (confirm-password (assoc-ref body "confirm-password"))
               ;; #f once the hour recorded in the envelope is over, or when the
               ;; link was edited on its way through the mail client: the tag
               ;; covers the whole payload, so there is no half-valid case.
               (sealed-payload (decrypt-object #:object reset-token
                                               #:encryption-key encryption-key
                                               #:signing-key signing-key))
               ;; A submission the server cannot accept is answered with a
               ;; redirect, never with a raised error: a mistyped confirmation
               ;; or a link that has aged out is not a server fault, and the
               ;; error page would leave the person who made the typo with
               ;; nothing to try again with.  The envelope is read first, so
               ;; a link that no longer opens never reaches the KDF.
               (link-works? (and (not (nil? sealed-payload))
                                 (equal? 'reset-password
                                         (assoc-ref sealed-payload 'action)))))
          (cond
           ((not link-works?)
            (redirect-to rc
                         (string->uri (format #f
                                       "~a/login?reset-link-expired=true"
                                       (current-myhost)))
                         #:status 302))
           ;; Which of the two reasons it was is kept, because the form says
           ;; it back: a reader sent to the same form with no explanation
           ;; types the same password again.
           ((not (and (string? new-password)
                      (equal? new-password confirm-password)
                      (strong-password? #:password new-password)))
            (redirect-to rc
                         (string->uri (format #f
                                       "~a/password/reset/token/~a?password-rejected=~a"
                                       (current-myhost)
                                       (uri-encode reset-token)
                                       (if (equal? new-password confirm-password)
                                           "weak"
                                           "mismatch")))
                         #:status 302))
           (else
            (sql-execute! rc
                          (sql-update 'users
                                      `((password
                                         . ,(hash-password new-password))
                                        (salt . ""))
                                      #:where `((identifier
                                                 . ,(assoc-ref sealed-payload
                                                               'user))))
                          #:name "reset-user-password")
            (:cookies-set! rc
                           'x-bewaking-wikimusic "x-bewaking-wikimusic" "")
            (:cookies-setattr! rc
                               'x-bewaking-wikimusic
                               #:expires 1
                               #:path "/"
                               #:secure #t
                               #:http-only #t)
            (redirect-to rc
                         (string->uri
                          (format #f "~a/login?has-reset-password=true~a"
                                  (current-myhost)
                                  (notice-query
                                   #:title (G_ "your password has been changed")
                                   #:body (G_ "sign in with the new one")
                                   #:duration-millis 8000)))
                         #:status 302))))))
