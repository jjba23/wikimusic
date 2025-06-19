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
        (wikimusic url)
        (wikimusic env)
        (web uri)
        (wikimusic auth)
        (ice-9 string-fun)
        (app models users)
        (wikimusic env)
        (bewaking bewaking)
        (artanis security nss)
        (app models users)
        (app models password_reset)
        (ice-9 string-fun)
        (app views login))

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
      (lambda (rc)
        (let* ((body (alist-from-url-encoded-body (rc-body rc)))
               (email (assoc-ref body "email"))
               (password (assoc-ref body "password"))
               (u ($users 'get
                          #:ret 'top
                          #:condition (where #:email email)))
               (get-owner-details (lambda ()
                                    `((id unquote
                                          (assoc-ref (car u) "identifier"))
                                      (email unquote
                                             (assoc-ref (car u) "email"))
                                      (name unquote
                                            (assoc-ref (car u) "username"))
                                      (permissions unquote
                                                   (eval-string (assoc-ref (car
                                                                            u)
                                                                 "permissions"))))))
               (_ (write (get-owner-details)))
               (t (generate-token #:encryption-key encryption-key
                                  #:signing-key signing-key
                                  #:get-owner-details get-owner-details)))
          
          (cond
            ((equal? (string->sha-256 (string-append password
                                                     (assoc-ref (car u) "salt")))
                     (assoc-ref (car u) "password"))
             (begin
               (:cookies-set! rc
                              'x-bewaking-wikimusic "x-bewaking-wikimusic" t)
               (:cookies-setattr! rc
                                  'x-bewaking-wikimusic
                                  #:expires (* 3600 24 7)
                                  #:path "/"
                                  #:secure #t
                                  #:http-only #t)
               (redirect-to rc
                            (string->uri (format #f
                                          "~a/songs?login_succeeded=true"
                                          (current-myhost)))
                            #:status 302)))
            (else (redirect-to rc
                               (string->uri (format #f
                                             "~a/login?login_failed=true"
                                             (current-myhost)))
                               #:status 302))))))

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
