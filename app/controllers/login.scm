;;; wikimusic - the free music knowledge encyclopaedia

;; Copyright © 2025 "Josep Bigorra" known as "jjba23" <jjbigorra@gmail.com>

;; wikimusic is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; wikimusic is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with wikimusic.  If not, see <https://www.gnu.org/licenses/>.

(define-artanis-controller login)

(import (wikimusic html)
        (wikimusic url)
        (web uri)
        (app models users)
        (ice-9 string-fun)
        (app views login))

(get "/login"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (response-emit (:mime rc
                             (login-page (:i18n rc))))))

(post "/login"
      #:auth '(table users "username" "password_hash")
      #:session '(spawn "wikimusic-sid")
      #:cookies '(names wikimusic-user-identifier)
      (lambda (rc)
        (let* ((body (rc-body rc))
               (kv (read-url-encoded-body body))
               (username (uri-decode (car (assoc-ref kv "username"))))
               (identifier (assoc-ref (car ($users 'get #:ret 'top #:condition (where #:username username))) "identifier")))
          (cond
           ((:session rc
             '(check "wikimusic-sid"))
            (:cookies-set! rc
             'wikimusic-user-identifier "wikimusic-user-identifier" identifier)
            (:cookies-setattr! rc
             'wikimusic-user-identifier
             #:expires 12000000
             #:path "/"
             #:http-only #t)
            (redirect-to rc
                         (string->uri (format #f "~a/songs"
                                              (current-myhost)))
                         #:status 302))
           ((:auth rc)
            (:session rc '(check-and-spawn "wikimusic-sid"))
            (:cookies-set! rc
             'wikimusic-user-identifier "wikimusic-user-identifier" identifier)
            (:cookies-setattr! rc
             'wikimusic-user-identifier
             #:expires 12000000
             #:path "/"
             #:http-only #t)
            (redirect-to rc
                         (string->uri (format #f "~a/songs"
                                              (current-myhost)))
                         #:status 302))
           (else (redirect-to rc
                              (string->uri (format #f
                                                   "~a/login?login_failed=true"
                                                   (current-myhost)))
                              #:status 302))))))
