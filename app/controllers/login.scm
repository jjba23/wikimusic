;;; wikimusic - the free music knowledge encyclopaedia

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

(define-artanis-controller login)

(import (wikimusic html)
        (kracht prelude)
        (wikimusic controller)
        (wikimusic env)
        (web uri)
        (wikimusic auth)
        (wikimusic sqlite util)
        (ice-9 string-fun)
        (app models users)
        (bewaking bewaking)
        (app views login))

;; Nothing imports `(app models password_reset)' any more: a reset link is a
;; sealed object with its own expiry, so there is no row to write.  The model
;; and the table it describes are left in place, unreferenced.

(get "/login"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (response-emit (:mime rc
                             (login-page (:i18n rc)
                                         #:is-logged-in (:cookies-value rc
                                                         "x-bewaking-wikimusic"))))))

(post "/login"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (let* ((G_ (:i18n rc))
               (body (body-alist rc))
               (email (assoc-ref body "email"))
               (password (assoc-ref body "password"))
               (u ($users 'get
                          #:ret 'top
                          #:condition (where #:email email))))
          ;; A refused sign-in says so on the page the reader lands back on.
          ;; The two ways to be refused -- no such address, wrong password --
          ;; are answered with the same sentence, so the form cannot be used
          ;; to ask which addresses have accounts here.
          (if (nil? u)
              (redirect-to rc
                           (string->uri (format #f
                                         "~a/login?login_failed=true~a"
                                         (current-myhost)
                                         (notice-query #:title (G_
                                                                "could not sign you in")
                                                       #:body (G_
                                                               "that email and password do not match an account")
                                                       #:duration-millis 8000)))
                           #:status 302)
              (let* ((user (car u))
                     (stored-hash (assoc-ref user "password"))
                     (stored-salt (assoc-ref user "salt"))
                     (password-ok? (verify-password password
                                                    #:hash stored-hash
                                                    #:salt stored-salt)))
                (if (not password-ok?)
                    (redirect-to rc
                                 (string->uri (format #f
                                               "~a/login?login_failed=true~a"
                                               (current-myhost)
                                               (notice-query #:title (G_
                                                                      "could not sign you in")
                                                             #:body (G_
                                                                     "that email and password do not match an account")
                                                             #:duration-millis
                                                             8000)))
                                 #:status 302)
                    (let* ((user-identifier (assoc-ref user "identifier"))
                           ;; The permissions column decides what this session
                           ;; may do, so it is read as data -- never evaluated.
                           (permissions (permissions-from-column (assoc-ref
                                                                  user
                                                                  "permissions")))
                           ;; A password still stored the old way proves the
                           ;; user knows it, which is the moment to replace it
                           ;; with one derived by a KDF.  Nobody is asked to
                           ;; change anything, and nothing is lost.
                           (_ (when (password-hash-legacy? stored-hash)
                                (sql-execute! rc
                                              (sql-update 'users
                                                          `((password unquote
                                                                      (hash-password
                                                                       password))
                                                            (salt . ""))
                                                          #:where `((identifier
                                                                     unquote
                                                                     user-identifier)))
                                              #:name "upgrade-password-hash")))
                           (get-owner-details (lambda ()
                                                `((id unquote user-identifier)
                                                  (email unquote
                                                         (assoc-ref user
                                                                    "email"))
                                                  (name unquote
                                                        (assoc-ref user
                                                                   "username"))
                                                  (permissions unquote
                                                               permissions))))
                           (t (generate-token #:encryption-key encryption-key
                                              #:signing-key signing-key
                                              #:token-validity-seconds
                                              session-token-validity-seconds
                                              #:get-owner-details
                                              get-owner-details)))
                      (:cookies-set! rc
                                     'x-bewaking-wikimusic
                                     "x-bewaking-wikimusic" t)
                      (:cookies-setattr! rc
                                         'x-bewaking-wikimusic
                                         #:expires
                                         session-token-validity-seconds
                                         #:path "/"
                                         #:secure #t
                                         #:http-only #t)
                      (redirect-to rc
                                   (string->uri (format #f
                                                 "~a/songs?login_succeeded=true~a"
                                                 (current-myhost)
                                                 (notice-query #:title (G_
                                                                        "signed in")
                                                               #:body (G_
                                                                       "welcome back; you may now add and edit songs"))))
                                   #:status 302))))))))

(get "/logout"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (begin
         (:cookies-set! rc
                        'x-bewaking-wikimusic "x-bewaking-wikimusic" "")
         (:cookies-setattr! rc
                            'x-bewaking-wikimusic
                            #:expires 1
                            #:path "/"
                            #:secure #t
                            #:http-only #t)

         (redirect-to rc
                      (string->uri (format #f "~a/"
                                           (current-myhost)))
                      #:status 302))))
