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

(define-artanis-controller song-form)

(import (wikimusic html)
        (wikimusic domain)
        (wikimusic controller)
        (web uri)
        (ice-9 string-fun)
        (wikimusic auth)
        (app models songs)
        (app models genres)
        (wikimusic env)
        (app models artists)
        (app models song_artworks)
        (app models song_contents)
        (app models song_comments)
        (app models song_opinions)
        (app models artists)
        (app models genres)
        (kracht prelude)
        (app models song_artists)
        (app models song_genres)
        (app views song-view)
        (app views song-edit)
        (app views song-content-view)
        (app views song-content-edit)
        (app models song_external_sources)
        (uuid generate)
        (bewaking bewaking)
        (app models users)
        (wikimusic sqlite song)
        (wikimusic domain song)
        (wikimusic sqlite artwork)
        (wikimusic domain artwork)
        (wikimusic domain comment)
        (wikimusic sqlite comment)
        (wikimusic domain opinion)
        (wikimusic sqlite opinion)
        (wikimusic domain external-source)
        (wikimusic sqlite external-source)
        (wikimusic sqlite artist)
        (wikimusic domain artist))


(post "/songs/new"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-new)
          (let* ((G_ (:i18n rc))
                 (t (decrypt-token #:token (:cookies-value rc
                                            "x-bewaking-wikimusic")
                                   #:encryption-key encryption-key
                                   #:signing-key signing-key))
                 (body (alist-from-url-encoded-body (rc-body rc)))
                 (new-uuid (generate-string-uuid))
                 (user-identifier (assoc-ref t
                                             'owner-id)))
            ($songs 'set
                     #:identifier new-uuid
                     #:display_name (html-escape (assoc-ref body
                                                            "display-name"))
                     #:description (html-escape (assoc-ref body "description"))
                     #:music_key (html-escape (assoc-ref body "music-key"))
                     #:music_tuning (html-escape (assoc-ref body "music-tuning"))
                     #:music_creation_date (html-escape (assoc-ref body "music-creation-date"))
                     #:album_name (html-escape (assoc-ref body "album-name"))
                     #:album_info_link (html-escape (assoc-ref body "album-info-link"))
                     #:created_by user-identifier
                     #:visibility_status 0
                     #:views 0
                     #:created_at (current-time))

            (redirect-to rc
                         (string->uri (format #f "~a/genres/uuid/~a"
                                              (current-myhost) new-uuid))
                         #:status 302)))

        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:genre-create)
                           #:rc rc
                           #:happy-flow do-new
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/contents/new"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (response-emit (:mime rc
                             (song-content-new-page (:i18n rc)
                                                    #:song-identifier (params
                                                                       rc
                                                                       "uuid")
                                                    #:is-logged-in (:cookies-value
                                                                    rc
                                                                    "x-bewaking-wikimusic"))))))


(post "/songs/uuid/:uuid/edit"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((G_ (:i18n rc))
              (uuid (params rc "uuid"))
              (song (car ($songs 'get
                                 #:ret 'top
                                 #:condition (where #:identifier uuid))))
              (artworks ($song_artworks 'get
                                        #:ret 'all
                                        #:order-by '(order_value asc)
                                        #:condition (where #:song_identifier
                                                           uuid)))
              (song-contents ($song_contents 'get
                                             #:ret 'all
                                             #:condition (where
                                                                #:song_identifier
                                                                uuid)))
              (song-genres ($song_genres 'get
                                         #:ret 'all
                                         #:condition (where #:song_identifier
                                                            uuid)))
              (genre-uuids (map (lambda (a)
                                  (assoc-ref a "genre_identifier"))
                                song-genres))
              (genres (if (nil? genre-uuids)
                          '()
                          ($genres 'get
                                   #:ret 'all
                                   #:condition (where #:identifier genre-uuids))))
              (song-artists ($song_artists 'get
                                           #:ret 'all
                                           #:condition (where
                                                              #:song_identifier
                                                              uuid)))
              (artist-uuids (map (lambda (a)
                                   (assoc-ref a "artist_identifier"))
                                 song-artists))
              (artists (if (nil? artist-uuids)
                           '()
                           ($artists 'get
                                     #:ret 'all
                                     #:condition (where #:identifier
                                                        artist-uuids))))
              (e ($song_external_sources 'get
                                         #:ret 'top
                                         #:condition (where #:song_identifier
                                                            uuid)))
              (external-sources (if (not (nil? e))
                                    (car e)
                                    '())))

         (response-emit (:mime rc
                               (song-edit-page (:i18n rc)
                                               #:song song
                                               #:song-contents song-contents
                                               #:artworks artworks
                                               #:artists artists
                                               #:genres genres
                                               #:external-sources
                                               external-sources
                                               #:is-logged-in (:cookies-value
                                                               rc
                                                               "x-bewaking-wikimusic")))))))

(post "/songs/uuid/:uuid/contents/:version-uuid/edit"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((G_ (:i18n rc))
              (uuid (params rc "uuid"))
              (song (car ($songs 'get
                                 #:ret 'top
                                 #:condition (where #:identifier uuid))))
              (version-uuid (params rc "version-uuid"))
              (song-contents (car ($song_contents 'get
                                                  #:ret 'top
                                                  #:condition (where
                                                               #:identifier
                                                               version-uuid)))))

         (response-emit (:mime rc
                               (song-content-edit-page (:i18n rc)
                                                       #:song song
                                                       #:song-contents
                                                       song-contents
                                                       #:is-logged-in (:cookies-value
                                                                       rc
                                                                       "x-bewaking-wikimusic")))))))
