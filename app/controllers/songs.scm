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

(import (app views songs))
(import (wikimusic html)
        (web uri)
        (ice-9 string-fun)
        (app models songs)
        (app models song_artworks)
        (app models song_contents)
        (app models song_comments)
        (app models song_opinions)
        (app views songs))

(get "/songs"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((songs ($songs 'get
                             #:order-by '(created_at desc)))
              (song-ids (map (lambda (s)
                               (assoc-ref s "identifier")) songs))
              (artworks (cond
                          ((nil? song-ids)
                           '())
                          (else ($song_artworks 'get
                                                #:ret 'all
                                                #:order-by '(order_value asc)
                                                #:condition (where
                                                                   #:song_identifier
                                                                   song-ids)))))
              (opinions (cond
                          ((nil? song-ids)
                           '())
                          (else ($song_opinions 'get
                                                #:ret 'all
                                                #:condition (where
                                                                   #:song_identifier
                                                                   song-ids)))))
              (comments (cond
                          ((nil? song-ids)
                           '())
                          (else ($song_comments 'get
                                                #:ret 'all
                                                #:condition (where
                                                                   #:song_identifier
                                                                   song-ids)))))
              (song-contents (cond
                               ((nil? song-ids)
                                '())
                               (else ($song_contents 'get
                                                     #:columns '(identifier
                                                                 song_identifier)
                                                     #:ret 'all
                                                     #:condition (where
                                                                  #:song_identifier
                                                                  song-ids)))))
              (song-version-count-alist (map (lambda (song)
                                               `(,(assoc-ref song "identifier") ,
                                                 (length (filter (lambda (sc)
                                                                   (equal? (assoc-ref
                                                                            sc
                                                                            "song_identifier")
                                                                           (assoc-ref
                                                                            song
                                                                            "identifier")))
                                                          song-contents))))
                                             songs)))
         (response-emit (:mime rc
                               (songs-list-page (:i18n rc)
                                                songs
                                                artworks
                                                song-version-count-alist
                                                opinions
                                                comments))))))

(get "/songs/uuid/:uuid"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((uuid (params rc "uuid"))
              (song (car ($songs 'get
                                 #:ret 'top
                                 #:condition (where #:identifier uuid))))
              (inc-v (+ 1
                        (assoc-ref song "views")))
              (artworks ($song_artworks 'get
                                        #:ret 'all
                                        #:order-by '(order_value asc)
                                        #:condition (where #:song_identifier
                                                           uuid)))
              (opinions ($song_opinions 'get
                                        #:ret 'all
                                        #:condition (where #:song_identifier
                                                           uuid)))
              (comments ($song_comments 'get
                                        #:ret 'all
                                        #:order-by '(created_at asc)
                                        #:condition (where #:song_identifier
                                                           uuid)))
              (created-by-alist '())
              (song-contents ($song_contents 'get
                                             #:ret 'all
                                             #:condition (where
                                                                #:song_identifier
                                                                uuid))))
         
         ;; do views update
         (DB-query (DB-open rc)
                   (->sql update
                          'songs set
                          `((views ,inc-v))
                          (where #:identifier uuid)))

         ;; return rendered view
         (response-emit (:mime rc
                               (songs-detail-page (:i18n rc)
                                                  song
                                                  artworks
                                                  song-contents
                                                  opinions
                                                  comments))))))

