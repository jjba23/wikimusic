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

(define-artanis-controller songs)

(import (wikimusic html)
        (web uri)
        (ice-9 string-fun)
        (app models songs)
        (app models song_artworks)
        (app views songs))

(get "/songs"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((songs ($songs 'get
                             #:order-by '(created_at desc)))
              (artworks ($song_artworks 'get
                                        #:ret 'all
                                        #:condition (where #:song_identifier (map (lambda 
                                                                                          (s)
                                                                                    
                                                                                    
                                                                                    (assoc-ref
                                                                                     s
                                                                                     "identifier"))
                                                                              songs)))))
         (response-emit (:mime rc
                               (songs-list-page (:i18n rc) songs artworks))))))

(get "/songs/uuid/:uuid"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((song ($songs 'get
                            #:ret 'top
                            #:condition (where #:identifier (params rc "uuid"))))
              (inc-v (+ 1
                        (assoc-ref (car song) "views")))
              (artworks ($song_artworks 'get
                                        #:ret 'all
                                        #:condition (where #:song_identifier (params
                                                                              rc
                                                                              "uuid")))))
         ;; do views update
         (DB-query (DB-open rc)
                   (->sql update
                          'songs set
                          `((views ,inc-v))
                          (where #:identifier (params rc "uuid"))))
         (response-emit (:mime rc
                               (songs-detail-page (:i18n rc)
                                                  (car song) artworks))))))

