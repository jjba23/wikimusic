;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-artanis-controller genre-page)

(import (wikimusic html)
        (web uri)
        (wikimusic env)
        (wikimusic auth)
        (wikimusic controller)
        (wikimusic domain)
        (ice-9 string-fun)
        (bewaking bewaking)
        (kracht prelude)
        (uuid generate)
        (wikimusic domain genre)
        (wikimusic sqlite genre)
        (wikimusic domain artwork)
        (wikimusic sqlite artwork)
        (wikimusic domain song)
        (wikimusic sqlite song)
        (wikimusic domain song-content)
        (wikimusic sqlite song-content)
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
     #:cookies '(names wikimusic-genre-sort wikimusic-grid-size
                       x-bewaking-wikimusic)
     (lambda (rc)
       (let* ((artwork-repo (make-sqlite-artwork-repository rc))
              (genre-repo (make-sqlite-genre-repository rc))
              (opinion-repo (make-sqlite-opinion-repository rc))
              (comment-repo (make-sqlite-comment-repository rc))
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
              ;; The tile-size preference travels the same way the sort does:
              ;; a `grid-size' in the query string is stored in a cookie and
              ;; every later visit reads it back, so the choice outlives the
              ;; page it was made on.
              (grid-size (cond
                           ((not (equal? #f
                                         (get-from-qstr rc "grid-size")))
                            (:cookies-set! rc
                                           'wikimusic-grid-size
                                           "wikimusic-grid-size"
                                           (get-from-qstr rc "grid-size"))
                            (:cookies-setattr! rc
                                               'wikimusic-grid-size
                                               #:expires 12000000
                                               #:path "/"
                                               #:secure #t
                                               #:http-only #t)
                            (get-from-qstr rc "grid-size"))
                           ((not (equal? #f
                                         (:cookies-value rc
                                          "wikimusic-grid-size")))
                            (:cookies-value rc "wikimusic-grid-size"))
                           (else "medium")))
              (query-sort (entity-sort-from-query user-sort))
              ;; The list is read a page at a time.  Forty rows fill a
              ;; screenful of tiles without making the reader scroll far, and
              ;; the page number in the query string is what the nav links
              ;; carry, so a page is a plain `offset = (page - 1) * 40'.
              (query-page (let ((p (get-from-qstr rc "page")))
                            (if (nil? p) 1
                                (max 1
                                     (or (string->number p) 1)))))
              (query-limit 40)
              (query-offset (* (- query-page 1) query-limit))
              (genres (cond
                        ((equal? #f user-search)
                         (get-genres genre-repo
                                     #:order-by query-sort
                                     #:limit query-limit
                                     #:offset query-offset))
                        (else (search-genres genre-repo
                                             (html-escape user-search)
                                             #:order-by query-sort
                                             #:limit query-limit
                                             #:offset query-offset))))
              (genre-total (count-genres genre-repo
                                         #:search (and user-search
                                                       (html-escape
                                                        user-search))))
              (genre-pages (max 1
                                (ceiling (/ genre-total query-limit))))
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
                          (else (get-comments-by-entity-ids comment-repo
                                                            'genre genre-ids)))))
         (response-emit (:mime rc
                               (genre-list-page (:i18n rc)
                                                #:genres genres
                                                #:artworks artworks
                                                #:comments comments
                                                #:limit query-limit
                                                #:offset query-offset
                                                #:pages genre-pages
                                                #:search-query user-search
                                                #:user-sort user-sort
                                                #:grid-size grid-size
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
              (genre (entity-or-404 (get-genre-by-id genre-repo genre-id)
                                    "genre" genre-id))
              (artwork-repo (make-sqlite-artwork-repository rc))
              (artist-repo (make-sqlite-artist-repository rc))
              (comment-repo (make-sqlite-comment-repository rc))
              (song-content-repo (make-sqlite-song-content-repository rc))
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
                                            #:order-by song-query-sort))
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
                               (else (get-comments-by-entity-ids comment-repo
                                                                 'song
                                                                 song-ids))))
              (song-contents (cond
                               ((nil? song-ids)
                                '())
                               (else (get-song-contents-by-song-ids
                                      song-content-repo song-ids))))

              (song-version-count-alist (map (lambda (song)
                                               `(,(assq-ref song
                                                            'identifier) ,(length
                                                                           (filter (lambda 
                                                                                           (sc)
                                                                                     
                                                                                     
                                                                                     (equal?
                                                                                      (assq-ref
                                                                                       sc
                                                                                       'song-identifier)

                                                                                      
                                                                                      (assq-ref
                                                                                       song
                                                                                       'identifier)))
                                                                            song-contents))))
                                             songs))
              (song-artists (cond
                              ((nil? song-ids)
                               '())
                              (else (get-song-artists-by-ids song-repo
                                                             song-ids))))
              (artists (if (nil? song-artists)
                           '()
                           (get-artists-by-ids artist-repo
                                               (map (lambda (a)
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
       (let* ((genre-id (params rc "uuid"))
              (genre-repo (make-sqlite-genre-repository rc))
              (genre (entity-or-404 (get-genre-by-id genre-repo genre-id)
                                    "genre" genre-id))
              (artwork-repo (make-sqlite-artwork-repository rc))
              (external-source-repo (make-sqlite-external-source-repository rc))
              (e (get-external-sources-by-entity-ids external-source-repo
                                                     'genre
                                                     (list genre-id)))
              (external-sources (if (not (nil? e))
                                    (car e)
                                    '()))
              (artworks (get-artworks-by-entity-ids artwork-repo
                                                    'genre
                                                    (list genre-id))))
         
         (response-emit (:mime rc
                               (genre-edit-page (:i18n rc)
                                                #:genre genre
                                                #:artworks artworks
                                                #:external-sources
                                                external-sources
                                                #:is-logged-in (:cookies-value
                                                                rc
                                                                "x-bewaking-wikimusic")))))))
