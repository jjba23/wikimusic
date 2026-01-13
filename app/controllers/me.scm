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
        (kracht prelude)
        (app views me)
        (curl)
        (uuid generate)
        (rnrs bytevectors)
        (json)
        (artanis security nss)
        (app models password_reset)
        (bewaking bewaking))

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
                 (body (alist-from-url-encoded-body (rc-body rc)))
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
                 (body (alist-from-url-encoded-body (rc-body rc)))
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
                 (body (alist-from-url-encoded-body (rc-body rc)))
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
                 (_ (DB-query (DB-open rc)
                              (->sql update
                                     'users set
                                     `((username ,username)
                                       (email ,email)
                                       (permissions ,(format #f "`~s"
                                                             permissions)))
                                     (where #:identifier (params rc
                                                                 "identifier"))))))
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

(get "/password/reset/token/:token"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((tt (car ($password_reset 'get
                                        #:ret 'top
                                        #:condition (where #:reset_token (params
                                                                          rc
                                                                          "token")))))
              (now (current-time))
              (allowance (* 24 7 3600)) ;reset token is valid for a week
              (_ (when (> now
                          (+ allowance
                             (assoc-ref tt "created_at")))
                   (error "reset token is found but not valid anymore")))
              (user-id (assoc-ref tt "user_id"))
              (email (assoc-ref (car ($users 'get
                                             #:ret 'top
                                             #:condition (where #:identifier
                                                                user-id)))
                                "email")))
         (response-emit (:mime rc
                               (reset-password-page (:i18n rc)
                                                    #:token (params rc "token")
                                                    #:email email))))))

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
                      (bytevector->string r "utf-8"))
                    (lambda (key . args)
                      r))))
    (display rr)))

(define (request-password-reset u)
  (let* ((_ ($password_reset 'mod
                             'row-delete
                             (where #:user_id (assoc-ref (car u) "identifier"))))
         (reset-token (base16-encode (format #f "~a-~a-~a"
                                             (generate-string-uuid)
                                             (generate-string-uuid)
                                             (generate-string-uuid))))
         (pr ($password_reset 'set
                              #:user_id (assoc-ref (car u) "identifier")
                              #:reset_token reset-token
                              #:created_at (current-time)))
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
                         (sender-address . "noreply@wikimusic.jointhefreeworld.org")
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
               (body (if (not (rc-body rc)) #f
                         (alist-from-url-encoded-body (rc-body rc))))
               (email (if (not body) #f
                          (assoc-ref body "email")))
               (u (if (not email)
                      ($users 'get
                              #:ret 'top
                              #:condition (where #:identifier (assoc-ref
                                                               existing-token
                                                               'owner-id)))
                      ($users 'get
                              #:ret 'top
                              #:condition (where #:email email)))))
          
          (request-password-reset u)
          (redirect-to rc
                       (string->uri (format #f "~a/?sent-password-reset=true"
                                            (current-myhost)))
                       #:status 302))))

(post "/password/do-reset"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (let* ((G_ (:i18n rc))
               (body (alist-from-url-encoded-body (rc-body rc)))
               (email (assoc-ref body "email"))
               (reset-token (assoc-ref body "reset-token"))
               (new-password (assoc-ref body "new-password"))
               (confirm-password (assoc-ref body "confirm-password"))
               (tt (car ($password_reset 'get
                                         #:ret 'top
                                         #:condition (where #:reset_token
                                                            reset-token))))
               (now (current-time))
               (allowance (* 24 7 3600)) ;reset token is valid for a week
               (_ (when (> now
                           (+ allowance
                              (assoc-ref tt "created_at")))
                    (error "reset token is found but not valid anymore!")))
               (_ (when (not (equal? new-password confirm-password))
                    (error "password confirmation did not match!")))
               (user-id (assoc-ref tt "user_id"))
               (u ($users 'get
                          #:ret 'top
                          #:condition (where #:identifier user-id)))
               (new-salt (generate-string-uuid))
               (h (string->sha-256 (string-append new-password new-salt)))
               (_ (DB-query (DB-open rc)
                            (format #f
                             "UPDATE users SET salt = '~a', password = '~a' WHERE identifier = '~a'"
                             new-salt h
                             (assoc-ref (car u) "identifier"))))
               (_ ($password_reset 'mod
                                   'row-delete
                                   (where #:user_id (assoc-ref (car u)
                                                               "identifier")))))
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
                       #:status 302))))
