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

(define-artanis-controller artist-page)

(import (wikimusic html)
        (web uri)
        (wikimusic controller)
        (ice-9 string-fun)
        (wikimusic env)
        (wikimusic auth)
        (wikimusic domain)
        (app models artists)
        (app models artist_artworks)
        (app models artist_opinions)
        (app models artist_external_sources)
        (app models artist_comments)
        (app models songs)
        (app models song_artworks)
        (app models song_opinions)
        (app models song_comments)
        (app models song_contents)
        (kracht prelude)
        (uuid generate)
        (bewaking bewaking)
        (app models users)
        (app views songs)
        (wikimusic domain artist)
        (wikimusic sqlite artist)
        (wikimusic domain artwork)
        (wikimusic sqlite artwork)
        (wikimusic domain comment)
        (wikimusic sqlite comment)
        (wikimusic domain opinion)
        (wikimusic sqlite opinion)
        (wikimusic domain external-source)
        (wikimusic sqlite external-source)
        (wikimusic domain song)
        (wikimusic sqlite song)
        (app views artists))

;; ====== Data view GET routes ======

(get "/artists"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names wikimusic-artist-sort x-bewaking-wikimusic)
     (lambda (rc)
       (let* ((artwork-repo (make-sqlite-artwork-repository rc))
              (artist-repo (make-sqlite-artist-repository rc))
              (comment-repo (make-sqlite-comment-repository rc))
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
                                           'wikimusic-artist-sort
                                           "wikimusic-artist-sort"
                                           (get-from-qstr rc "sort"))
                            (:cookies-setattr! rc
                                               'wikimusic-artist-sort
                                               #:expires 12000000
                                               #:path "/"
                                               #:secure #t
                                               #:http-only #t)
                            (get-from-qstr rc "sort"))
                           ((not (equal? #f
                                         (:cookies-value rc
                                          "wikimusic-artist-sort")))
                            (:cookies-value rc "wikimusic-artist-sort"))
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
              (artists (cond
                         ((equal? #f user-search)
                          (get-artists artist-repo
                                       #:order-by (format #f "~a ~a"
                                                          (car query-sort)
                                                          (cadr query-sort))
                                       #:limit query-limit
                                       #:offset query-offset))
                         (else (search-artists artist-repo
                                               (html-escape user-search)
                                               #:order-by (format #f "~a ~a"
                                                                  (car
                                                                   query-sort)
                                                                  (cadr
                                                                   query-sort))
                                               #:limit query-limit
                                               #:offset query-offset))))
              (artist-ids (map (lambda (s)
                                 (assq-ref s
                                           'identifier)) artists))
              (artworks (cond
                          ((nil? artist-ids)
                           '())
                          (else (get-artworks-by-entity-ids artwork-repo
                                                            'artist artist-ids))))
              (opinions (cond
                          ((nil? artist-ids)
                           '())
                          (else (get-opinions-by-entity-ids opinion-repo
                                                            'artist artist-ids))))
              (comments (cond
                          ((nil? artist-ids)
                           '())
                          (else (get-comments-by-entity-ids comment-repo
                                                            'artist artist-ids)))))
         (response-emit (:mime rc
                               (artist-list-page (:i18n rc)
                                                 #:artists artists
                                                 #:artworks artworks
                                                 #:opinions opinions
                                                 #:comments comments
                                                 #:limit query-limit
                                                 #:offset query-offset
                                                 #:search-query user-search
                                                 #:user-sort user-sort
                                                 #:is-logged-in (:cookies-value
                                                                 rc
                                                                 "x-bewaking-wikimusic")))))))

(get "/artists/uuid/:uuid"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (let* ((artist-id (params rc "uuid"))
              (artist-repo (make-sqlite-artist-repository rc))
              (artist (get-artist-by-id artist-repo artist-id))
              (artwork-repo (make-sqlite-artwork-repository rc))
              (opinion-repo (make-sqlite-opinion-repository rc))
              (comment-repo (make-sqlite-comment-repository rc))
              (external-source-repo (make-sqlite-external-source-repository rc))
              (song-repo (make-sqlite-song-repository rc))
              (inc-v (+ 1
                        (assq-ref artist
                                  'views)))
              (artworks (get-artworks-by-entity-ids artwork-repo
                                                    'artist
                                                    (list artist-id)))
              (opinions (get-opinions-by-entity-ids opinion-repo
                                                    'artist
                                                    (list artist-id)))
              (comments (get-comments-by-entity-ids comment-repo
                                                    'artist
                                                    (list artist-id)))
              (raw-external-sources (get-external-sources-by-entity-ids
                                     external-source-repo
                                     'artist
                                     (list artist-id)))
              (external-sources (if (nil? raw-external-sources)
                                    '()
                                    (car raw-external-sources)))
              (users ($users 'get
                             #:ret 'all
                             #:order-by '(username asc)))
              (user-alist (map (lambda (u)
                                 `(,(assoc-ref u "identifier") ,u)) users))

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
              (songs (get-songs-by-artist-id song-repo artist-id
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
              (song-fragment (song-list-page (:i18n rc)
                                             #:only-tiles #t
                                             #:songs songs
                                             #:artworks song-artworks
                                             #:song-version-count-alist
                                             song-version-count-alist
                                             #:artists '()
                                             #:song-artists '()
                                             #:comments song-comments
                                             #:limit 0
                                             #:offset 0
                                             #:search-query ""
                                             #:user-sort song-user-sort)))
         (update-artist-by-id artist-repo artist-id
                              `((views unquote inc-v)))
         (response-emit (:mime rc
                               (artist-detail-page (:i18n rc)
                                                   #:artist artist
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

;; ====== Data edit GET routes ======

(get "/artists/new"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (response-emit (:mime rc
                             (artist-new-page (:i18n rc)
                                              #:is-logged-in (:cookies-value
                                                              rc
                                                              "x-bewaking-wikimusic"))))))

(get "/artists/uuid/:uuid/edit"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (let* ((uuid (params rc "uuid"))
              (artist (car ($artists 'get
                                     #:ret 'top
                                     #:condition (where #:identifier uuid))))
              (artist-external-sources '())
              (artworks ($artist_artworks 'get
                                          #:ret 'all
                                          #:order-by '(order_value asc)
                                          #:condition (where
                                                             #:artist_identifier
                                                             uuid)))
              (e ($artist_external_sources 'get
                                           #:ret 'top
                                           #:condition (where
                                                              #:artist_identifier
                                                              uuid)))
              (external-sources (if (not (nil? e))
                                    (car e)
                                    '())))
         
         (response-emit (:mime rc
                               (artist-edit-page (:i18n rc)
                                                 #:artist artist
                                                 #:artworks artworks
                                                 #:external-sources
                                                 external-sources
                                                 #:is-logged-in (:cookies-value
                                                                 rc
                                                                 "x-bewaking-wikimusic")))))))

