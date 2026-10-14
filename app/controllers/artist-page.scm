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
        (kracht prelude)
        (uuid generate)
        (bewaking bewaking)
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
        (wikimusic domain song-content)
        (wikimusic sqlite song-content)
        (wikimusic domain user)
        (wikimusic sqlite user)
        (app views artist-view)
        (app views artist-edit)
        (app views song-view)
        (app views song-edit))

;; ====== Data view GET routes ======

(get "/artists"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names wikimusic-artist-sort wikimusic-grid-size
                       x-bewaking-wikimusic)
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
              (artists (cond
                         ((equal? #f user-search)
                          (get-artists artist-repo
                                       #:order-by query-sort
                                       #:limit query-limit
                                       #:offset query-offset))
                         (else (search-artists artist-repo
                                               (html-escape user-search)
                                               #:order-by query-sort
                                               #:limit query-limit
                                               #:offset query-offset))))
              (artist-total (count-artists artist-repo
                                           #:search (and user-search
                                                         (html-escape
                                                          user-search))))
              (artist-pages (max 1
                                 (ceiling (/ artist-total query-limit))))
              (artist-ids (map (lambda (s)
                                 (assq-ref s
                                           'identifier)) artists))
              (artworks (cond
                          ((nil? artist-ids)
                           '())
                          (else (get-artworks-by-entity-ids artwork-repo
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
                                                 #:comments comments
                                                 #:limit query-limit
                                                 #:offset query-offset
                                                 #:pages artist-pages
                                                 #:search-query user-search
                                                 #:user-sort user-sort
                                                 #:grid-size grid-size
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
              (artist (entity-or-404 (get-artist-by-id artist-repo artist-id)
                                     "artist" artist-id))
              (artwork-repo (make-sqlite-artwork-repository rc))
              (opinion-repo (make-sqlite-opinion-repository rc))
              (comment-repo (make-sqlite-comment-repository rc))
              (song-content-repo (make-sqlite-song-content-repository rc))
              (external-source-repo (make-sqlite-external-source-repository rc))
              (user-repo (make-sqlite-user-repository rc))
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
              (user (get-user-by-id user-repo
                                    (assq-ref artist
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
              (songs (get-songs-by-artist-id song-repo artist-id
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
       (let* ((artist-id (params rc "uuid"))
              (artwork-repo (make-sqlite-artwork-repository rc))
              (artist-repo (make-sqlite-artist-repository rc))
              (artist (entity-or-404 (get-artist-by-id artist-repo artist-id)
                                     "artist" artist-id))
              (external-source-repo (make-sqlite-external-source-repository rc))
              (artworks (get-artworks-by-entity-ids artwork-repo
                                                    'artist
                                                    (list artist-id)))
              (e (get-external-sources-by-entity-ids external-source-repo
                                                     'artist
                                                     (list artist-id)))
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
