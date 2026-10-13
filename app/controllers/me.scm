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
            (request-password-reset u)
            (redirect-to rc
                         (string->uri (format #f
                                              "~a/users/manage/?created=true"
                                              (current-myhost)))
                         #:status 302)))
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
       (let* ((sealed-payload (decrypt-object #:object (params rc "token")
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
                          (string->uri (format #f
                                        "~a/login?reset-link-expired=true"
                                        (current-myhost)))
                          #:status 302)
             (response-emit (:mime rc
                                   (reset-password-page (:i18n rc)
                                                        #:token (params rc "token")
                                                        #:email email)))))))

(define* (send-to-pingwing #:key body)
  (write body)
  (let* ((handle (curl-easy-init))
         (_ (begin
              (curl-easy-setopt handle
                                'post #t)
              (curl-easy-setopt handle
                                'url
                                (format #f "~a/api/v1/tasks" pingwing-url))
              (curl-easy-setopt handle
                                'postfields
                                (string->utf8 (scm->json-string body)))
              (curl-easy-setopt handle
                                'verbose #t)
              (curl-easy-setopt handle
                                'use-ssl 1)
              (curl-easy-setopt handle
                                'username pingwing-basic-auth-user)
              (curl-easy-setopt handle
                                'password pingwing-basic-auth-password)))
         (r (curl-easy-perform handle #t))
         (rr (catch #t
                    (lambda ()
                      (utf8->string r))
                    (lambda (key . args)
                      r))))
    (display rr)))

(define (request-password-reset u)
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
          (redirect-to rc
                       (string->uri (format #f "~a/?sent-password-reset=true"
                                            (current-myhost)))
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
           ((not (and (string? new-password)
                      (equal? new-password confirm-password)
                      (strong-password? #:password new-password)))
            (redirect-to rc
                         (string->uri (format #f
                                       "~a/password/reset/token/~a?password-rejected=true"
                                       (current-myhost)
                                       (uri-encode reset-token)))
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
                         (string->uri (format #f
                                       "~a/login?has-reset-password=true"
                                       (current-myhost)))
                         #:status 302))))))
