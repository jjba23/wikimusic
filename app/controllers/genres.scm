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

(define-artanis-controller genres)

(import (wikimusic html)
        (web uri)
        (wikimusic url)
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
        (wikimusic query-escape)
        (uuid generate)
        (app views songs)
        (app views genres))

(get "/genres"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names wikimusic-genre-sort)
     (lambda (rc)
       (let* ((user-search (cond
                             ((equal? #f
                                      (get-from-qstr rc "search"))
                              #f)
                             (else (escape-str (get-from-qstr rc "search")))))
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
                             (else 40)))
              (genres (DB-get-all-rows (DB-query (DB-open rc)
                                                 (cond
                                                   ((equal? #f user-search)
                                                    (->sql select * from
                                                           'genres
                                                           (format #f
                                                            " ORDER BY ~a ~a LIMIT ~a OFFSET ~a"
                                                            (car query-sort)
                                                            (cadr query-sort)
                                                            query-limit
                                                            query-offset)))
                                                   (else (->sql select * from
                                                                'genres
                                                                (format #f
                                                                 (string-join '
                                                                  (" WHERE (display_name LIKE '%~a%' OR description LIKE '%~a%') "
                                                                   " ORDER BY ~a ~a LIMIT ~a OFFSET ~a ")
                                                                  " ")
                                                                 (escape-str
                                                                  user-search)
                                                                 (escape-str
                                                                  user-search)
                                                                 (car
                                                                  query-sort)
                                                                 (cadr
                                                                  query-sort)
                                                                 query-limit
                                                                 query-offset)))))))
              (genre-ids (map (lambda (s)
                                (assoc-ref s "identifier")) genres))
              (artworks (cond
                          ((nil? genre-ids)
                           '())
                          (else ($genre_artworks 'get
                                                 #:ret 'all
                                                 #:order-by '(order_value asc)
                                                 #:condition (where
                                                                    #:genre_identifier
                                                                    genre-ids)))))
              (opinions (cond
                          ((nil? genre-ids)
                           '())
                          (else ($genre_opinions 'get
                                                 #:ret 'all
                                                 #:condition (where
                                                                    #:genre_identifier
                                                                    genre-ids)))))
              (comments (cond
                          ((nil? genre-ids)
                           '())
                          (else ($genre_comments 'get
                                                 #:ret 'all
                                                 #:condition (where
                                                                    #:genre_identifier
                                                                    genre-ids))))))
         (response-emit (:mime rc
                               (genres-list-page (:i18n rc)
                                                 #:genres genres
                                                 #:artworks artworks
                                                 #:opinions opinions
                                                 #:comments comments
                                                 #:limit query-limit
                                                 #:offset query-offset
                                                 #:search-query user-search
                                                 #:user-sort user-sort))))))

(get "/genres/new"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (response-emit (:mime rc
                             (genre-new-page (:i18n rc))))))

(get "/genres/uuid/:uuid"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((uuid (params rc "uuid"))
              (genre (car ($genres 'get
                                   #:ret 'top
                                   #:condition (where #:identifier uuid))))
              (inc-v (+ 1
                        (assoc-ref genre "views")))
              (artworks ($genre_artworks 'get
                                         #:ret 'all
                                         #:order-by '(order_value asc)
                                         #:condition (where #:genre_identifier
                                                            uuid)))
              (opinions ($genre_opinions 'get
                                         #:ret 'all
                                         #:condition (where #:genre_identifier
                                                            uuid)))
              (comments ($genre_comments 'get
                                         #:ret 'all
                                         #:order-by '(created_at asc)
                                         #:condition (where #:genre_identifier
                                                            uuid)))
              (raw-external-sources ($genre_external_sources 'get
                                                             #:ret 'top
                                                             #:condition (where
                                                                          #:genre_identifier
                                                                          uuid)))
              (external-sources (if (nil? raw-external-sources)
                                    '()
                                    (car raw-external-sources)))
              (users ($users 'get
                             #:ret 'all
                             #:order-by '(display_name asc)
                             #:columns '(identifier display_name email_address
                                                    username avatar_url)))
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
                                                    #:http-only #t)
                                 (get-from-qstr rc "sort"))
                                ((not (equal? #f
                                              (:cookies-value rc
                                               "wikimusic-song-sort")))
                                 (:cookies-value rc "wikimusic-song-sort"))
                                (else "display-name-asc")))
              (song-query-sort (entity-sort-from-query song-user-sort))

              (songs (DB-get-all-rows (DB-query (DB-open rc)
                                                (format #f
                                                 "SELECT * FROM songs WHERE identifier IN
                                                             (SELECT song_identifier FROM song_genres WHERE genre_identifier = '~a') ORDER BY ~a ~a"
                                                 uuid
                                                 (car song-query-sort)
                                                 (cadr song-query-sort)))))
              (song-ids (map (lambda (s)
                               (assoc-ref s "identifier")) songs))
              (song-artworks (cond
                               ((nil? song-ids)
                                '())
                               (else ($song_artworks 'get
                                                     #:ret 'all
                                                     #:order-by '(order_value
                                                                  asc)
                                                     #:condition (where
                                                                  #:song_identifier
                                                                  song-ids)))))
              (song-opinions (cond
                               ((nil? song-ids)
                                '())
                               (else ($song_opinions 'get
                                                     #:ret 'all
                                                     #:condition (where
                                                                  #:song_identifier
                                                                  song-ids)))))
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
              (song-fragment (songs-list-page (:i18n rc)
                                              #:only-tiles #t
                                              #:songs songs
                                              #:artworks song-artworks
                                              #:song-version-count-alist
                                              song-version-count-alist
                                              #:artists artists
                                              #:song-artists song-artists
                                              #:opinions song-opinions
                                              #:comments song-comments
                                              #:limit 0
                                              #:offset 0
                                              #:search-query ""
                                              #:user-sort song-user-sort)))
         ;; do views update
         (DB-query (DB-open rc)
                   (->sql update
                          'genres set
                          `((views ,inc-v))
                          (where #:identifier uuid)))
         (response-emit (:mime rc
                               (genres-detail-page (:i18n rc)
                                                   #:genre genre
                                                   #:artworks artworks
                                                   #:opinions opinions
                                                   #:comments comments
                                                   #:user-alist user-alist
                                                   #:song-fragment
                                                   song-fragment
                                                   #:external-sources
                                                   external-sources))))))

(get "/genres/uuid/:uuid/edit"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((uuid (params rc "uuid"))
              (genre (car ($genres 'get
                                   #:ret 'top
                                   #:condition (where #:identifier uuid))))
              (external-sources '())
              (artworks ($genre_artworks 'get
                                         #:ret 'all
                                         #:order-by '(order_value asc)
                                         #:condition (where #:genre_identifier
                                                            uuid))))
         
         (response-emit (:mime rc
                         (genre-edit-page (:i18n rc) #:genre genre #:artworks artworks
                                          #:external-sources external-sources
                                          ))))))

(define (do-edit rc)
  (let* ((body (rc-body rc))
         (kv (read-url-encoded-body body)))
    (DB-query (DB-open rc)
              (->sql update
                     'genres set
                     `((display_name ,(escape-str (uri-decode (car (assoc-ref
                                                                    kv
                                                                    "display-name")))))
                       (description ,(escape-str (uri-decode (car (assoc-ref
                                                                   kv
                                                                   "description")))))
                       (last_edited_at ,(current-time)))
                     (where #:identifier (params rc "uuid"))))
    (redirect-to rc
                 (string->uri (format #f "~a/genres/uuid/~a"
                                      (current-myhost)
                                      (params rc "uuid")))
                 #:status 302)))

(post "/genres/uuid/:uuid/edit"
      #:auth '(table users "username" "password_hash")
      #:session #t
      (lambda (rc)
        (protected-endpoint rc
                            (lambda ()
                              (do-edit rc)))))

(define (do-edit-artwork rc)
  (let* ((body (rc-body rc))
         (kv (read-url-encoded-body body)))
    (DB-query (DB-open rc)
              (->sql update
                     'genre_artworks set
                     `((content_url ,(escape-str (uri-decode (car (assoc-ref
                                                                   kv
                                                                   "content-url")))))
                       (content_caption ,(escape-str (uri-decode (car (assoc-ref
                                                                       kv
                                                                       "content-caption")))))
                       (order_value ,(escape-str (uri-decode (car (assoc-ref
                                                                   kv
                                                                   "order-value")))))
                       (last_edited_at ,(current-time)))
                     (where #:identifier (params rc "artwork-uuid"))))
    (redirect-to rc
                 (string->uri (format #f "~a/genres/uuid/~a/edit"
                                      (current-myhost)
                                      (params rc "uuid")))
                 #:status 302)))

(post "/genres/uuid/:uuid/artworks/edit/:artwork-uuid"
      #:auth '(table users "username" "password_hash")
      #:session #t
      (lambda (rc)
        (protected-endpoint rc
                            (lambda ()
                              (do-edit-artwork rc)))))

;; 
;; ====== Data create POST routes ======
;; 

(define (do-new-artwork rc)
  (let* ((body (rc-body rc))
         (kv (read-url-encoded-body body))
         (new-uuid (generate-string-uuid))
         (user-identifier (:cookies-value rc "wikimusic-user-identifier")))
    ($genre_artworks 'set
                     #:identifier new-uuid
                     #:genre_identifier (params rc "uuid")
                     #:created_by user-identifier
                     #:visibility_status 0
                     #:content_url (escape-str (uri-decode (car (assoc-ref kv
                                                                 "content-url"))))
                     #:content_caption (escape-str (uri-decode (car (assoc-ref
                                                                     kv
                                                                     "content-caption"))))
                     #:order_value (escape-str (uri-decode (car (assoc-ref kv
                                                                 "order-value"))))
                     #:created_at (current-time))

    (redirect-to rc
                 (string->uri (format #f "~a/genres/uuid/~a/edit"
                                      (current-myhost)
                                      (params rc "uuid")))
                 #:status 302)))

(post "/genres/uuid/:uuid/artworks/new"
      #:auth '(table users "username" "password_hash")
      #:session #t
      (lambda (rc)
        (protected-endpoint rc
                            (lambda ()
                              (do-new-artwork rc)))))

(define (do-new rc)
  (let* ((body (rc-body rc))
         (kv (read-url-encoded-body body))
         (new-uuid (generate-string-uuid))
         (user-identifier (:cookies-value rc "wikimusic-user-identifier")))
    ($genres 'set
             #:identifier new-uuid
             #:display_name (escape-str (uri-decode (car (assoc-ref kv
                                                          "display-name"))))
             #:description (escape-str (uri-decode (car (assoc-ref kv
                                                         "description"))))
             #:created_by user-identifier
             #:visibility_status 0
             #:views 0
             #:created_at (current-time))

    (redirect-to rc
                 (string->uri (format #f "~a/genres/uuid/~a"
                                      (current-myhost) new-uuid))
                 #:status 302)))

(post "/genres/new"
      #:auth '(table users "username" "password_hash")
      #:session #t
      (lambda (rc)
        (protected-endpoint rc
                            (lambda ()
                              (do-new rc)))))

(define (do-opinion rc is-like is-dislike)
  (let* ((uuid (params rc "uuid"))
         (user-identifier (:cookies-value rc "wikimusic-user-identifier"))
         (rec (car ($genres 'get
                            #:condition (where #:identifier uuid))))
         (new-uuid (generate-string-uuid))
         (ex-op (filter (lambda (o)
                          (equal? user-identifier
                                  (assoc-ref o "created_by")))
                        ($genre_opinions 'get
                                         #:condition (where #:genre_identifier
                                                            uuid)))))
    (write rec)
    (if (not (nil? ex-op))
        ($genre_opinions 'mod
                         'row-delete
                         (where #:identifier (assoc-ref (car ex-op)
                                                        "identifier"))))
    ($genre_opinions 'set
                     #:identifier new-uuid
                     #:genre_identifier uuid
                     #:created_by user-identifier
                     #:is_like is-like
                     #:is_dislike is-dislike
                     #:created_at (current-time))
    (redirect-to rc
                 (string->uri (format #f "~a/genres/uuid/~a"
                                      (current-myhost) uuid))
                 #:status 302)))

(post "/genres/uuid/:uuid/like"
      #:auth '(table users "username" "password_hash")
      #:session #t
      (lambda (rc)
        (protected-endpoint rc
                            (lambda ()
                              (do-opinion rc 1 0)))))

(post "/genres/uuid/:uuid/dislike"
      #:auth '(table users "username" "password_hash")
      #:session #t
      (lambda (rc)
        (protected-endpoint rc
                            (lambda ()
                              (do-opinion rc 0 1)))))

;; ====== Delete data routes ======

(post "/genres/uuid/:uuid/artworks/:artwork-uuid/delete"
      #:auth '(table users "username" "password_hash")
      #:session #t
      (lambda (rc)
        (define (do-delete)
          (delete-artwork #:rc rc
                          #:conn (DB-open rc)
                          #:entity 'genre
                          #:delete-condition (where #:identifier (params rc
                                                                  "artwork-uuid"))
                          #:redirect-url (format #f "~a/genres/uuid/~a/edit"
                                                 (current-myhost)
                                                 (params rc "uuid"))))
        (protected-endpoint rc do-delete)))
