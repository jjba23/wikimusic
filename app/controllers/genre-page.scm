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

(define-artanis-controller genre-page)

(import (wikimusic html)
        (web uri)
        (wikimusic env)
        (wikimusic auth)
        (wikimusic controller)
        (wikimusic domain)
        (ice-9 string-fun)
        (app models artists)
        (app models song_artists)
        (app models songs)
        (app models song_artworks)
        (app models song_contents)
        (app models song_opinions)
        (app models genre_external_sources)
        (app models song_comments)
        (app models genres)
        (app models genre_artworks)
        (app models genre_comments)
        (app models genre_opinions)
        (app models users)
        (bewaking bewaking)
        (kracht prelude)
        (uuid generate)
        (wikimusic domain genre)
        (wikimusic sqlite genre)
        (wikimusic domain artwork)
        (wikimusic sqlite artwork)
        (wikimusic domain song)
        (wikimusic sqlite song)
        (wikimusic domain comment)
        (wikimusic sqlite comment)
        (wikimusic domain opinion)
        (wikimusic sqlite opinion)
        (wikimusic domain external-source)
        (wikimusic sqlite external-source)
        (wikimusic domain user)
        (wikimusic sqlite user)
        (wikimusic domain artist)
        (wikimusic sqlite artist)        
        (app views genre-view)
        (app views genre-edit)
        (app views song-view)
        (app views song-edit))

(get "/genres"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names wikimusic-genre-sort x-bewaking-wikimusic)
     (lambda (rc)
       (let* ((artwork-repo (make-sqlite-artwork-repository rc))
              (genre-repo (make-sqlite-genre-repository rc))
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
                                           'wikimusic-genre-sort
                                           "wikimusic-genre-sort"
                                           (get-from-qstr rc "sort"))
                            (:cookies-setattr! rc
                                               'wikimusic-genre-sort
                                               #:expires 12000000
                                               #:path "/"
                                               #:secure #t
                                               #:http-only #t)
                            (get-from-qstr rc "sort"))
                           ((not (equal? #f
                                         (:cookies-value rc
                                          "wikimusic-genre-sort")))
                            (:cookies-value rc "wikimusic-genre-sort"))
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
              (genres (cond
                        ((equal? #f user-search)
                         (get-genres genre-repo
                                     #:order-by (format #f "~a ~a"
                                                        (car query-sort)
                                                        (cadr query-sort))
                                     #:limit query-limit
                                     #:offset query-offset))
                        (else (search-genres genre-repo
                                             (html-escape user-search)
                                             #:order-by (format #f "~a ~a"
                                                                (car
                                                                 query-sort)
                                                                (cadr
                                                                 query-sort))
                                             #:limit query-limit
                                             #:offset query-offset))))
              (genre-ids (map (lambda (s)
                                (assq-ref s
                                          'identifier)) genres))
              (artworks (cond
                          ((nil? genre-ids)
                           '())
                          (else (get-artworks-by-entity-ids artwork-repo
                                                            'genre genre-ids))))
              (comments (cond
                          ((nil? genre-ids)
                           '())
                          (else ($genre_comments 'get
                                                 #:ret 'all
                                                 #:condition (where
                                                                    #:genre_identifier
                                                                    genre-ids))))))
         (response-emit (:mime rc
                               (genre-list-page (:i18n rc)
                                                #:genres genres
                                                #:artworks artworks
                                                #:comments comments
                                                #:limit query-limit
                                                #:offset query-offset
                                                #:search-query user-search
                                                #:user-sort user-sort
                                                #:is-logged-in (:cookies-value
                                                                rc
                                                                "x-bewaking-wikimusic")))))))

(get "/genres/new"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (response-emit (:mime rc
                             (genre-new-page (:i18n rc)
                                             #:is-logged-in (:cookies-value rc
                                                             "x-bewaking-wikimusic"))))))

(get "/genres/uuid/:uuid"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (let* ((genre-id (params rc "uuid"))
              (genre-repo (make-sqlite-genre-repository rc))
              (opinion-repo (make-sqlite-opinion-repository rc))
              (external-source-repo (make-sqlite-external-source-repository rc))
              (genre (get-genre-by-id genre-repo genre-id))
              (artwork-repo (make-sqlite-artwork-repository rc))
              (artist-repo (make-sqlite-artist-repository rc))              
              (comment-repo (make-sqlite-comment-repository rc))
              (user-repo (make-sqlite-user-repository rc))
              (song-repo (make-sqlite-song-repository rc))
              (inc-v (+ 1
                        (assq-ref genre
                                  'views)))
              (artworks (get-artworks-by-entity-ids artwork-repo
                                                    'genre
                                                    (list genre-id)))
              (opinions (get-opinions-by-entity-ids opinion-repo
                                                    'genre
                                                    (list genre-id)))
              (comments (get-comments-by-entity-ids comment-repo
                                                    'genre
                                                    (list genre-id)))
              (raw-external-sources (get-external-sources-by-entity-ids
                                     external-source-repo
                                     'genre
                                     (list genre-id)))
              (external-sources (if (nil? raw-external-sources)
                                    '()
                                    (car raw-external-sources)))
              (user (get-user-by-id user-repo
                                    (assq-ref genre
                                              'created-by)))
              (user-alist (list (cons (assq-ref user
                                                'identifier) user)))
              ;; song-specific
              (song-user-sort (cond
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
              (song-query-sort (entity-sort-from-query song-user-sort))

              (songs (get-songs-by-genre-id song-repo genre-id
                                            #:order-by (format #f "~a ~a"
                                                               (car
                                                                song-query-sort)
                                                               (cadr
                                                                song-query-sort))))
              (song-ids (map (lambda (s)
                               (assq-ref s
                                         'identifier)) songs))
              (song-artworks (cond
                               ((nil? song-ids)
                                '())
                               (else (get-artworks-by-entity-ids artwork-repo
                                                                 'song
                                                                 song-ids))))
              (song-comments (cond
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
                                             songs))
              (song-artists (cond
                              ((nil? song-ids)
                               '())
                              (else (get-song-artists-by-ids song-repo
                                                             song-ids))))
              (artists (if (nil? song-artists)
                           '()
                           (get-artists-by-ids artist-repo (map (lambda (a)
                                                      (assq-ref a
                                                                'artist-identifier))
                                                    song-artists))))
              (song-fragment (song-list-page (:i18n rc)
                                             #:only-tiles #t
                                             #:songs songs
                                             #:artworks song-artworks
                                             #:song-version-count-alist
                                             song-version-count-alist
                                             #:artists artists
                                             #:song-artists song-artists
                                             #:comments song-comments
                                             #:limit 0
                                             #:offset 0
                                             #:search-query ""
                                             #:user-sort song-user-sort)))
         (update-genre-by-id genre-repo genre-id
                             `((views unquote inc-v)))
         (response-emit (:mime rc
                               (genre-detail-page (:i18n rc)
                                                  #:genre genre
                                                  #:artworks artworks
                                                  #:opinions opinions
                                                  #:comments comments
                                                  #:user-alist user-alist
                                                  #:song-fragment
                                                  song-fragment
                                                  #:external-sources
                                                  external-sources
                                                  #:is-logged-in (:cookies-value
                                                                  rc
                                                                  "x-bewaking-wikimusic")))))))

(get "/genres/uuid/:uuid/edit"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (let* ((uuid (params rc "uuid"))
              (genre (car ($genres 'get
                                   #:ret 'top
                                   #:condition (where #:identifier uuid))))
              (e ($genre_external_sources 'get
                                          #:ret 'top
                                          #:condition (where
                                                             #:genre_identifier
                                                             uuid)))
              (external-sources (if (not (nil? e))
                                    (car e)
                                    '()))
              (artworks ($genre_artworks 'get
                                         #:ret 'all
                                         #:order-by '(order_value asc)
                                         #:condition (where #:genre_identifier
                                                            uuid))))
         
         (response-emit (:mime rc
                               (genre-edit-page (:i18n rc)
                                                #:genre genre
                                                #:artworks artworks
                                                #:external-sources
                                                external-sources
                                                #:is-logged-in (:cookies-value
                                                                rc
                                                                "x-bewaking-wikimusic")))))))

