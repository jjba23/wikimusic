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

(define-artanis-controller artists)

(import (wikimusic html)
        (web uri)
        (ice-9 string-fun)
        (app models artists)
        (app models artist_artworks)
        (app views artists))

(get "/artists"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((artists ($artists 'get
                                 #:order-by '(created_at desc)))
              (artist-ids (map (lambda (s)
                                 (assoc-ref s "identifier")) artists))
              (artworks ($artist_artworks 'get
                                          #:ret 'all
                                          #:condition (where
                                                             #:artist_identifier
                                                             artist-ids))))
         (response-emit (:mime rc
                               (artists-list-page (:i18n rc) artists artworks))))))

(get "/artists/uuid/:uuid"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((artist ($artists 'get
                                #:ret 'top
                                #:condition (where #:identifier (params rc
                                                                 "uuid"))))
              (inc-v (+ 1
                        (assoc-ref (car artist) "views")))
              (artworks ($artist_artworks 'get
                                          #:ret 'all
                                          #:condition (where
                                                             #:artist_identifier
                                                             (params rc "uuid")))))
         ;; do views update
         (DB-query (DB-open rc)
                   (->sql update
                          'artists set
                          `((views ,inc-v))
                          (where #:identifier (params rc "uuid"))))
         (response-emit (:mime rc
                               (artists-detail-page (:i18n rc)
                                                    (car artist) artworks))))))

