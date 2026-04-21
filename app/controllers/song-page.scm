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

(define-artanis-controller song-page)

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
        (app views song-view)
        (app views song-edit)
        (app views song-content-view)
        (app views song-content-edit)
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
        (wikimusic domain user)
        (wikimusic sqlite user)
        (wikimusic domain genre)
        (wikimusic sqlite genre)        
        (wikimusic sqlite artist)
        (wikimusic domain artist))

(get "/songs"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names wikimusic-song-sort x-bewaking-wikimusic)
     (lambda (rc)
       (let* ((artwork-repo (make-sqlite-artwork-repository rc))
              (song-repo (make-sqlite-song-repository rc))
              (opinion-repo (make-sqlite-opinion-repository rc))
              (external-source-repo (make-sqlite-external-source-repository rc))
              (user-search (cond
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
                             (else 100)))
              (songs (cond
                       ((equal? #f user-search)
                        (get-songs song-repo
                                   #:order-by (format #f "~a ~a"
                                                      (car query-sort)
                                                      (cadr query-sort))
                                   #:limit query-limit
                                   #:offset query-offset))
                       (else (search-songs song-repo
                                           (html-escape user-search)
                                           #:order-by (format #f "~a ~a"
                                                              (car query-sort)
                                                              (cadr query-sort))
                                           #:limit query-limit
                                           #:offset query-offset))))
              (song-ids (map (lambda (s)
                               (assq-ref s
                                         'identifier)) songs))
              (artworks (cond
                          ((nil? song-ids)
                           '())
                          (else (get-artworks-by-entity-ids artwork-repo
                                                            'song song-ids))))
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
       (let* ((song-repo (make-sqlite-song-repository rc))
              (artist-repo (make-sqlite-artist-repository rc))
              (genre-repo (make-sqlite-genre-repository rc))              
              (artwork-repo (make-sqlite-artwork-repository rc))
              (comment-repo (make-sqlite-comment-repository rc))
              (opinion-repo (make-sqlite-opinion-repository rc))
              (external-source-repo (make-sqlite-external-source-repository rc))
              (user-repo (make-sqlite-user-repository rc))
              (song-id (params rc "uuid"))
              (song (get-song-by-id song-repo song-id))
              (ascii-size (cond
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
              (inc-v (+ 1
                        (assq-ref song
                                  'views)))
              (artworks (get-artworks-by-entity-ids artwork-repo
                                                    'song
                                                    (list song-id)))
              (opinions (get-opinions-by-entity-ids opinion-repo
                                                    'song
                                                    (list song-id)))
              (comments (get-comments-by-entity-ids comment-repo
                                                    'song
                                                    (list song-id)))
              (raw-external-sources (get-external-sources-by-entity-ids
                                     external-source-repo
                                     'song
                                     (list song-id)))
              (external-sources (if (nil? raw-external-sources)
                                    '()
                                    (car raw-external-sources)))
              (user (get-user-by-id user-repo
                                    (assq-ref song
                                              'created-by)))
              (user-alist (list (cons (assq-ref user
                                                'identifier) user)))

              (song-contents ($song_contents 'get
                                             #:ret 'all
                                             #:condition (where
                                                                #:song_identifier
                                                                song-id)))
              (song-genres (get-song-genres-by-id song-repo song-id))
              (genres (if (nil? song-genres)
                          '()
                          (get-genres-by-ids genre-repo song-genres)))
              (song-artists (get-song-artists-by-id song-repo song-id))
              (artists (if (nil? song-artists)
                           '()
                           (get-artists-by-ids artist-repo song-artists))))
         
         ;; do views update
         (update-song-by-id song-repo song-id
                            `((views unquote inc-v)))

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
              (song-id (params rc "uuid"))
              (song-repo (make-sqlite-song-repository rc))
              (artwork-repo (make-sqlite-artwork-repository rc))
              (external-source-repo (make-sqlite-external-source-repository rc))
              (song (get-song-by-id song-repo song-id))
              (artworks (get-artworks-by-entity-ids artwork-repo
                                                    'song
                                                    (list song-id)))
              (song-contents ($song_contents 'get
                                             #:ret 'all
                                             #:condition (where
                                                                #:song_identifier
                                                                song-id)))
              (song-genres ($song_genres 'get
                                         #:ret 'all
                                         #:condition (where #:song_identifier
                                                            song-id)))
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
                                                              song-id)))
              (artist-uuids (map (lambda (a)
                                   (assoc-ref a "artist_identifier"))
                                 song-artists))
              (artists (if (nil? artist-uuids)
                           '()
                           ($artists 'get
                                     #:ret 'all
                                     #:condition (where #:identifier
                                                        artist-uuids))))
              (e (get-external-sources-by-entity-ids external-source-repo
                                                     'song
                                                     (list song-id)))
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

