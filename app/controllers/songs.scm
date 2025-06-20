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

(define-artanis-controller songs)

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
        (app models song_external_sources)
        (uuid generate)
        (app views songs)
        (bewaking bewaking)
        (app views song-contents)
        (app models users)
        (app views songs))

(get "/songs"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names wikimusic-song-sort x-bewaking-wikimusic)
     (lambda (rc)
       (let* ((user-search (cond
                             ((equal? #f
                                      (get-from-qstr rc "search"))
                              #f)
                             (else (html-escape (get-from-qstr rc "search")))))
              (user-sort (cond
                           ((not (equal? #f
                                         (get-from-qstr rc "sort")))
                            (:cookies-set! rc
                                           'wikimusic-song-sort
                                           "wikimusic-song-sort"
                                           (get-from-qstr rc "sort"))
                            (:cookies-setattr! rc
                                               'wikimusic-song-sort
                                               #:expires 12000000
                                               #:path "/"
                                               #:secure #t
                                               #:http-only #t)
                            (get-from-qstr rc "sort"))
                           ((not (equal? #f
                                         (:cookies-value rc
                                          "wikimusic-song-sort")))
                            (:cookies-value rc "wikimusic-song-sort"))
                           (else "display-name-asc")))
              (query-sort (entity-sort-from-query user-sort))
              (query-offset (cond
                              ((not (nil? (get-from-qstr rc "offset")))
                               (string->number (get-from-qstr rc "offset")))
                              (else 0)))
              (query-limit (cond
                             ((not (nil? (get-from-qstr rc "limit")))
                              (string->number (get-from-qstr rc "limit")))
                             (else 40)))
              (songs (DB-get-all-rows (DB-query (DB-open rc)
                                                (cond
                                                  ((equal? #f user-search)
                                                   (->sql select * from
                                                          'songs
                                                          (format #f
                                                           " ORDER BY ~a ~a LIMIT ~a OFFSET ~a"
                                                           (car query-sort)
                                                           (cadr query-sort)
                                                           query-limit
                                                           query-offset)))
                                                  (else (->sql select * from
                                                               'songs
                                                               (format #f
                                                                (string-join '
                                                                 (" WHERE (display_name LIKE '%~a%' OR description LIKE '%~a%') "
                                                                  " ORDER BY ~a ~a LIMIT ~a OFFSET ~a ")
                                                                 " ")
                                                                (html-escape
                                                                 user-search)
                                                                (html-escape
                                                                 user-search)
                                                                (car
                                                                 query-sort)
                                                                (cadr
                                                                 query-sort)
                                                                query-limit
                                                                query-offset)))))))
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

              (song-artists (cond
                              ((nil? song-ids)
                               '())
                              (else ($song_artists 'get
                                                   #:ret 'all
                                                   #:condition (where
                                                                #:song_identifier
                                                                song-ids)))))
              (artist-uuids (map (lambda (a)
                                   (assoc-ref a "artist_identifier"))
                                 song-artists))
              (artists (if (nil? artist-uuids)
                           '()
                           ($artists 'get
                                     #:ret 'all
                                     #:condition (where #:identifier
                                                        artist-uuids))))
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
                               (song-list-page (:i18n rc)
                                               #:songs songs
                                               #:artworks artworks
                                               #:song-version-count-alist
                                               song-version-count-alist
                                               #:artists artists
                                               #:song-artists song-artists
                                               #:opinions opinions
                                               #:comments comments
                                               #:limit query-limit
                                               #:offset query-offset
                                               #:search-query user-search
                                               #:user-sort user-sort
                                               #:is-logged-in (:cookies-value
                                                               rc
                                                               "x-bewaking-wikimusic")))))))

(get "/songs/new"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (response-emit (:mime rc
                             (song-new-page (:i18n rc)
                                            #:is-logged-in (:cookies-value rc
                                                            "x-bewaking-wikimusic"))))))

(get "/songs/uuid/:uuid/contents/new"
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

(get "/songs/uuid/:uuid"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names wikimusic-ascii-size x-bewaking-wikimusic)
     (lambda (rc)
       (let* ((ascii-size (cond
                            ((not (equal? #f
                                          (get-from-qstr rc "ascii-size")))
                             (:cookies-set! rc
                                            'wikimusic-ascii-size
                                            "wikimusic-ascii-size"
                                            (get-from-qstr rc "ascii-size"))
                             (:cookies-setattr! rc
                                                'wikimusic-ascii-size
                                                #:expires 12000000
                                                #:path "/"
                                                #:secure #t
                                                #:http-only #t)
                             (get-from-qstr rc "ascii-size"))
                            ((not (equal? #f
                                          (:cookies-value rc
                                           "wikimusic-ascii-size")))
                             (:cookies-value rc "wikimusic-ascii-size"))
                            (else "text-sm")))
              (uuid (params rc "uuid"))
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
              (raw-external-sources ($song_external_sources 'get
                                                            #:ret 'top
                                                            #:condition (where
                                                                         #:song_identifier
                                                                         uuid)))
              (external-sources (if (nil? raw-external-sources)
                                    '()
                                    (car raw-external-sources)))
              (users ($users 'get
                             #:ret 'all))
              (user-alist (map (lambda (u)
                                 `(,(assoc-ref u "identifier") ,u)) users))
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
                                                        artist-uuids)))))
         
         ;; do views update
         (DB-query (DB-open rc)
                   (->sql update
                          'songs set
                          `((views ,inc-v))
                          (where #:identifier uuid)))

         ;; return rendered view
         (response-emit (:mime rc
                               (song-detail-page (:i18n rc)
                                                 #:song song
                                                 #:artworks artworks
                                                 #:song-contents song-contents
                                                 #:song-artists song-artists
                                                 #:artists artists
                                                 #:song-genres song-genres
                                                 #:genres genres
                                                 #:opinions opinions
                                                 #:comments comments
                                                 #:user-alist user-alist
                                                 #:ascii-size ascii-size
                                                 #:external-sources
                                                 external-sources
                                                 #:is-logged-in (:cookies-value
                                                                 rc
                                                                 "x-bewaking-wikimusic")))))))

(get "/songs/uuid/:uuid/edit"
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

(get "/songs/uuid/:uuid/contents/:version-uuid/edit"
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

(post "/songs/uuid/:uuid/edit"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-edit)
          (let* ((G_ (:i18n rc))
                 (body (alist-from-url-encoded-body (rc-body rc))))
            (DB-query (DB-open rc)
                      (->sql update
                             'songs set
                             `((display_name ,(html-escape (assoc-ref body
                                                            "display-name")))
                               (description ,(html-escape (assoc-ref body
                                                           "description")))
                               (music_key ,(html-escape (assoc-ref body
                                                         "music-key")))
                               (music_tuning ,(html-escape (assoc-ref body
                                                            "music-tuning")))
                               (music_creation_date ,(html-escape (assoc-ref
                                                                   body
                                                                   "music-creation-date")))
                               (album_name ,(html-escape (assoc-ref body
                                                          "album-name")))
                               (album_info_link ,(uri-encode (assoc-ref body
                                                              "album-info-link")))
                               (last_edited_at ,(current-time)))
                             (where #:identifier (params rc "uuid"))))
            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-edit
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/contents/:version-uuid/edit"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-contents-edit)
          (let* ((G_ (:i18n rc))
                 (body (alist-from-url-encoded-body (rc-body rc))))
            (DB-query (DB-open rc)
                      (->sql update
                             'song_contents set
                             `((instrument_type ,(html-escape (assoc-ref body
                                                               "instrument-type")))
                               (version_name ,(html-escape (assoc-ref body
                                                            "version-name")))
                               (ascii_legend ,(html-escape (assoc-ref body
                                                            "ascii-legend")))
                               (ascii_contents ,(html-escape (assoc-ref body
                                                              "ascii-contents")))
                               (pdf_contents ,(html-escape (assoc-ref body
                                                            "pdf-contents")))
                               (last_edited_at ,(current-time)))
                             (where #:identifier (params rc "version-uuid"))))
            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))

        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-contents-edit
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/artworks/edit/:artwork-uuid"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-edit-artwork)
          (let* ((G_ (:i18n rc))
                 (body (alist-from-url-encoded-body (rc-body rc))))
            (DB-query (DB-open rc)
                      (->sql update
                             'song_artworks set
                             `((content_url ,(uri-encode (assoc-ref body
                                                          "content-url")))
                               (content_caption ,(html-escape (assoc-ref body
                                                               "content-caption")))
                               (order_value ,(html-escape (assoc-ref body
                                                           "order-value")))
                               (last_edited_at ,(current-time)))
                             (where #:identifier (params rc "artwork-uuid"))))
            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a/edit"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-edit-artwork
                           #:unhappy-flow back-to-login)))

;; 
;; ====== Data create POST routes ======
;; 

(post "/songs/uuid/:uuid/contents/new"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-new-content)
          (let* ((G_ (:i18n rc))
                 (t (decrypt-token #:token (:cookies-value rc
                                            "x-bewaking-wikimusic")
                                   #:encryption-key encryption-key
                                   #:signing-key signing-key))
                 (body (alist-from-url-encoded-body (rc-body rc)))
                 (new-uuid (generate-string-uuid))
                 (user-identifier (assoc-ref t
                                             'owner-id)))
            ($song_contents 'set
                            #:identifier new-uuid
                            #:song_identifier (params rc "uuid")
                            #:created_by user-identifier
                            #:visibility_status 0
                            #:instrument_type (html-escape (assoc-ref body
                                                            "instrument-type"))
                            #:version_name (html-escape (assoc-ref body
                                                         "version-name"))
                            #:ascii_legend (html-escape (assoc-ref body
                                                         "ascii-legend"))
                            #:ascii_contents (html-escape (assoc-ref body
                                                           "ascii-contents"))
                            #:pdf_contents (html-escape (assoc-ref body
                                                         "pdf-contents"))
                            #:guitarpro_contents (html-escape (assoc-ref body
                                                               "guitarpro-contents"))
                            #:created_at (current-time))

            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-new-content
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/artworks/new"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-new-artwork)
          (let* ((G_ (:i18n rc))
                 (t (decrypt-token #:token (:cookies-value rc
                                            "x-bewaking-wikimusic")
                                   #:encryption-key encryption-key
                                   #:signing-key signing-key))
                 (body (alist-from-url-encoded-body (rc-body rc)))
                 (new-uuid (generate-string-uuid))
                 (user-identifier (assoc-ref t
                                             'owner-id)))
            ($song_artworks 'set
                            #:identifier new-uuid
                            #:song_identifier (params rc "uuid")
                            #:created_by user-identifier
                            #:visibility_status 0
                            #:content_url (uri-encode (assoc-ref body
                                                       "content-url"))
                            #:content_caption (html-escape (assoc-ref body
                                                            "content-caption"))
                            #:order_value (html-escape (assoc-ref body
                                                        "order-value"))
                            #:created_at (current-time))

            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a/edit"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-new-artwork
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/artists"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-new-song-artist)
          (let* ((G_ (:i18n rc))
                 (t (decrypt-token #:token (:cookies-value rc
                                            "x-bewaking-wikimusic")
                                   #:encryption-key encryption-key
                                   #:signing-key signing-key))
                 (body (alist-from-url-encoded-body (rc-body rc)))
                 (new-uuid (generate-string-uuid))
                 (user-identifier (assoc-ref t
                                             'owner-id))
                 (artist ($artists 'get
                                   #:ret 'top
                                   #:condition (where #:identifier (assoc-ref
                                                                    body
                                                                    "artist-identifier")))))
            (when (not (nil? artist))
              (log-info "creating song-artist relation: song ~a artist ~a"
                        (params rc "uuid")
                        (assoc-ref body "artist-identifier"))
              ($song_artists 'set
                             #:identifier new-uuid
                             #:song_identifier (params rc "uuid")
                             #:artist_identifier (assoc-ref body
                                                  "artist-identifier")
                             #:created_by user-identifier
                             #:created_at (current-time)))

            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a/edit"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-new-song-artist
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/genres"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-new-song-genre)
          (let* ((G_ (:i18n rc))
                 (t (decrypt-token #:token (:cookies-value rc
                                            "x-bewaking-wikimusic")
                                   #:encryption-key encryption-key
                                   #:signing-key signing-key))
                 (body (alist-from-url-encoded-body (rc-body rc)))
                 (new-uuid (generate-string-uuid))
                 (user-identifier (assoc-ref t
                                             'owner-id))
                 (genre ($genres 'get
                                 #:ret 'top
                                 #:condition (where #:identifier (assoc-ref
                                                                  body
                                                                  "genre-identifier")))))
            (when (not (nil? genre))
              (log-info "creating song-genre relation: song ~a genre ~a"
                        (params rc "uuid")
                        (assoc-ref body "genre-identifier"))
              ($song_genres 'set
                            #:identifier new-uuid
                            #:song_identifier (params rc "uuid")
                            #:genre_identifier (assoc-ref body
                                                          "genre-identifier")
                            #:created_by user-identifier
                            #:created_at (current-time)))

            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a/edit"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))

        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-new-song-genre
                           #:unhappy-flow back-to-login)))

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
                    #:display_name (html-escape (assoc-ref body "display-name"))
                    #:music_key (html-escape (assoc-ref body "music-key"))
                    #:music_tuning (html-escape (assoc-ref body "music-tuning"))
                    #:music_creation_date (html-escape (assoc-ref body
                                                        "music-creation-date"))
                    #:album_name (html-escape (assoc-ref body "album-name"))
                    #:album_info_link (uri-encode (assoc-ref body
                                                   "album-info-link"))
                    #:description (html-escape (assoc-ref body "description"))
                    #:created_by user-identifier
                    #:visibility_status 0
                    #:views 0
                    #:created_at (current-time))

            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a"
                                              (current-myhost) new-uuid))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-new
                           #:unhappy-flow back-to-login)))

(define (do-opinion rc is-like is-dislike t)
  (let* ((G_ (:i18n rc))
         (uuid (params rc "uuid"))
         (user-identifier (assoc-ref t
                                     'owner-id))
         (rec (car ($songs 'get
                           #:condition (where #:identifier uuid))))
         (new-uuid (generate-string-uuid))
         (ex-op (filter (lambda (o)
                          (equal? user-identifier
                                  (assoc-ref o "created_by")))
                        ($song_opinions 'get
                                        #:condition (where #:song_identifier
                                                           uuid)))))
    (if (not (nil? ex-op))
        ($song_opinions 'mod
                        'row-delete
                        (where #:identifier (assoc-ref (car ex-op)
                                                       "identifier"))))
    ($song_opinions 'set
                    #:identifier new-uuid
                    #:song_identifier uuid
                    #:created_by user-identifier
                    #:is_like is-like
                    #:is_dislike is-dislike
                    #:created_at (current-time))
    (redirect-to rc
                 (string->uri (format #f "~a/songs/uuid/~a?notify-title=~a"
                                      (current-myhost) uuid
                                      (if (equal? 1 is-like)
                                          (uri-encode (G_ "Liked song!"))
                                          (uri-encode (G_ "Disliked song!")))))
                 #:status 302)))

(post "/songs/uuid/:uuid/like"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '()
                           #:rc rc
                           #:happy-flow (lambda ()
                                          (do-opinion rc 1 0
                                                      (decrypt-token #:token (:cookies-value
                                                                              rc
                                                                              "x-bewaking-wikimusic")
                                                       #:encryption-key
                                                       encryption-key
                                                       #:signing-key
                                                       signing-key)))
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/dislike"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '()
                           #:rc rc
                           #:happy-flow (lambda ()
                                          (do-opinion rc 0 1
                                                      (decrypt-token #:token (:cookies-value
                                                                              rc
                                                                              "x-bewaking-wikimusic")
                                                       #:encryption-key
                                                       encryption-key
                                                       #:signing-key
                                                       signing-key)))
                           #:unhappy-flow back-to-login)))

;; ====== Delete data routes ======

(post "/songs/uuid/:uuid/artworks/:artwork-uuid/delete"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-delete)
          (let* ((G_ (:i18n rc)))
            (delete-artwork #:rc rc
                            #:conn (DB-open rc)
                            #:entity 'song
                            #:delete-condition (where #:identifier (params rc
                                                                    "artwork-uuid"))
                            #:redirect-url (format #f "~a/songs/uuid/~a/edit"
                                                   (current-myhost)
                                                   (params rc "uuid")))))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-delete)
                           #:rc rc
                           #:happy-flow do-delete
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/contents/:version-uuid/delete"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-delete)
          (let* ((G_ (:i18n rc)))
            (DB-query (DB-open rc)
                      (->sql delete from
                             'song_contents
                             (where #:identifier (params rc "version-uuid"))))
            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-delete)
                           #:rc rc
                           #:happy-flow do-delete
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/artists/:artist-uuid/delete"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-delete-artist)
          (let* ((G_ (:i18n rc)))
            (DB-query (DB-open rc)
                      (->sql delete from
                             'song_artists
                             (where #:artist_identifier (params rc
                                                                "artist-uuid")
                                    #:song_identifier (params rc "uuid"))))
            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a/edit"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-delete)
                           #:rc rc
                           #:happy-flow do-delete-artist
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/genres/:genre-uuid/delete"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-delete-genre)
          (let* ((G_ (:i18n rc)))
            (DB-query (DB-open rc)
                      (->sql delete from
                             'song_genres
                             (where #:genre_identifier (params rc "genre-uuid")
                                    #:song_identifier (params rc "uuid"))))
            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a/edit"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-delete)
                           #:rc rc
                           #:happy-flow do-delete-genre
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/external-sources/:sourcesuuid/edit"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-edit-external-sources)
          (let* ((G_ (:i18n rc))
                 (body (alist-from-url-encoded-body (rc-body rc))))
            (DB-query (DB-open rc)
                      (->sql update
                             'song_external_sources set
                             `((wikipedia_url ,(uri-encode (assoc-ref body
                                                            "wikipedia-url")))
                               (spotify_url ,(uri-encode (assoc-ref body
                                                          "spotify-url")))
                               (youtube_url ,(uri-encode (assoc-ref body
                                                          "youtube-url")))
                               (soundcloud_url ,(uri-encode (assoc-ref body
                                                             "soundcloud-url")))
                               (last_edited_at ,(current-time)))
                             (where #:identifier (params rc "sourcesuuid"))))
            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))

        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-edit-external-sources
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/external-sources/new"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-new-external-sources)
          (let* ((G_ (:i18n rc))
                 (t (decrypt-token #:token (:cookies-value rc
                                            "x-bewaking-wikimusic")
                                   #:encryption-key encryption-key
                                   #:signing-key signing-key))
                 (body (alist-from-url-encoded-body (rc-body rc)))
                 (new-uuid (generate-string-uuid))
                 (user-identifier (assoc-ref t
                                             'owner-id)))
            ($song_external_sources 'set
                                    #:identifier new-uuid
                                    #:song_identifier (params rc "uuid")
                                    #:wikipedia_url (uri-encode (assoc-ref
                                                                 body
                                                                 "wikipedia-url"))
                                    #:soundcloud_url (uri-encode (assoc-ref
                                                                  body
                                                                  "soundcloud-url"))
                                    #:youtube_url (uri-encode (assoc-ref body
                                                               "youtube-url"))
                                    #:spotify_url (uri-encode (assoc-ref body
                                                               "spotify-url"))
                                    #:created_by user-identifier
                                    #:created_at (current-time))

            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a?notify-title=~a"
                                              (current-myhost)
                                              (params rc "uuid")
                                              (uri-encode (G_ "Edited song succesfully!"))))
                         #:status 302)))

        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-new-external-sources
                           #:unhappy-flow back-to-login)))

