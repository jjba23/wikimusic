;;; wikimusic - the free music knowledge encyclopaedia

;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

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

(define-artanis-controller artists)

(import (wikimusic html)
        (web uri)
        (wikimusic controller)
        (wikimusic url)
        (ice-9 string-fun)
        (wikimusic auth)
        (wikimusic domain)
        (app models artists)
        (app models artist_artworks)
        (app models artist_opinions)
        (app models artist_comments)
        (wikimusic query-escape)
        (uuid generate)
        (app models users)
        (app views artists))

;; ====== Data view GET routes ======

(get "/artists"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names wikimusic-artist-sort)
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
                            'wikimusic-artist-sort
                            "wikimusic-artist-sort"
                            (get-from-qstr rc "sort"))
                           (:cookies-setattr! rc
                            'wikimusic-artist-sort
                            #:expires 12000000
                            #:path "/"
                            #:http-only #t)
                           (get-from-qstr rc "sort"))
                          ((not (equal? #f
                                        (:cookies-value rc
                                         "wikimusic-artist-sort")))
                           (:cookies-value rc "wikimusic-artist-sort"))
                          (else "display-name-asc")))
              (query-sort (entity-sort-from-query user-sort))
              (_ (write query-sort))
              (query-offset (cond
                             ((not (nil? (get-from-qstr rc "offset")))
                              (string->number (get-from-qstr rc "offset")))
                             (else 0)))
              (query-limit (cond
                            ((not (nil? (get-from-qstr rc "limit")))
                             (string->number (get-from-qstr rc "limit")))
                            (else 20)))
              (artists (DB-get-all-rows (DB-query (DB-open rc)
                                                  (cond
                                                   ((equal? #f user-search)
                                                    (->sql select * from
                                                           'artists
                                                           (format #f
                                                                   " ORDER BY ~a ~a LIMIT ~a OFFSET ~a"
                                                                   (car query-sort)
                                                                   (cadr query-sort)
                                                                   query-limit
                                                                   query-offset)))
                                                   (else (->sql select * from
                                                                'artists
                                                                (format #f
                                                                        (string-join '(" WHERE (display_name LIKE '%~a%' OR description LIKE '%~a%') "
                                                                                       " ORDER BY ~a ~a LIMIT ~a OFFSET ~a ") " ")
                                                                        (escape-str user-search)
                                                                        (escape-str user-search)
                                                                        (car query-sort)
                                                                        (cadr query-sort)
                                                                        query-limit
                                                                        query-offset)))))))
              (artist-ids (map (lambda (s)
                                 (assoc-ref s "identifier")) artists))
              (artworks (cond
                         ((nil? artist-ids)
                          '())
                         (else ($artist_artworks 'get
                                                 #:ret 'all
                                                 #:order-by '(order_value asc)
                                                 #:condition (where
                                                              #:artist_identifier
                                                              artist-ids)))))
              (opinions (cond
                         ((nil? artist-ids)
                          '())
                         (else ($artist_opinions 'get
                                                 #:ret 'all
                                                 #:condition (where
                                                              #:artist_identifier
                                                              artist-ids)))))
              (comments (cond
                         ((nil? artist-ids)
                          '())
                         (else ($artist_comments 'get
                                                 #:ret 'all
                                                 #:condition (where
                                                              #:artist_identifier
                                                              artist-ids))))))
         (response-emit (:mime rc
                         (artists-list-page (:i18n rc)
                                            #:artists artists
                                            #:artworks artworks
                                            #:opinions opinions
                                            #:comments comments
                                            #:limit query-limit
                                            #:offset query-offset
                                            #:search-query user-search))))))

(get "/artists/uuid/:uuid"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((uuid (params rc "uuid"))
              (artist (car ($artists 'get
                                     #:ret 'top
                                     #:condition (where #:identifier uuid))))
              (inc-v (+ 1
                        (assoc-ref artist "views")))
              (artworks ($artist_artworks 'get
                                          #:ret 'all
                                          #:order-by '(order_value asc)
                                          #:condition (where
                                                             #:artist_identifier
                                                             uuid)))
              (opinions ($artist_opinions 'get
                                          #:ret 'all
                                          #:condition (where
                                                             #:artist_identifier
                                                             uuid)))
              (comments ($artist_comments 'get
                                          #:ret 'all
                                          #:order-by '(created_at asc)
                                          #:condition (where
                                                             #:artist_identifier
                                                             uuid)))
              (users ($users 'get
                             #:ret 'all
                             #:order-by '(display_name asc)
                             #:columns '(identifier display_name email_address
                                                    username avatar_url)))
              (user-alist (map (lambda (u)
                                 `(,(assoc-ref u "identifier") ,u)) users)))
         ;; do views update
         (DB-query (DB-open rc)
                   (->sql update
                          'artists set
                          `((views ,inc-v))
                          (where #:identifier uuid)))
         (response-emit (:mime rc
                               (artists-detail-page (:i18n rc)
                                                    artist
                                                    artworks
                                                    opinions
                                                    comments
                                                    user-alist))))))

;; ====== Data edit GET routes ======

(get "/artists/new"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (response-emit (:mime rc
                             (artist-new-page (:i18n rc))))))

(get "/artists/uuid/:uuid/edit"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((uuid (params rc "uuid"))
              (artist (car ($artists 'get
                                     #:ret 'top
                                     #:condition (where #:identifier uuid))))
              (artworks ($artist_artworks 'get
                                          #:ret 'all
                                          #:order-by '(order_value asc)
                                          #:condition (where
                                                             #:artist_identifier
                                                             uuid))))
         
         (response-emit (:mime rc
                               (artist-edit-page (:i18n rc) artist artworks))))))

;; ====== Data edit POST routes ======

(define (do-edit rc)
  (let* ((body (rc-body rc))
         (kv (read-url-encoded-body body)))
    (write kv)
    (DB-query (DB-open rc)
              (->sql update
                     'artists set
                     `((display_name ,(escape-str (uri-decode (car (assoc-ref
                                                                    kv
                                                                    "display-name")))))
                       (description ,(escape-str (uri-decode (car (assoc-ref
                                                                   kv
                                                                   "description")))))
                       (last_edited_at ,(current-time)))
                     (where #:identifier (params rc "uuid"))))
    (redirect-to rc
                 (string->uri (format #f "~a/artists/uuid/~a"
                                      (current-myhost)
                                      (params rc "uuid")))
                 #:status 302)))

(post "/artists/uuid/:uuid/edit"
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
                     'artist_artworks set
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
                 (string->uri (format #f "~a/artists/uuid/~a/edit"
                                      (current-myhost)
                                      (params rc "uuid")))
                 #:status 302)))

(post "/artists/uuid/:uuid/artworks/edit/:artwork-uuid"
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
    ($artist_artworks 'set
                      #:identifier new-uuid
                      #:artist_identifier (params rc "uuid")
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
                 (string->uri (format #f "~a/artists/uuid/~a/edit"
                                      (current-myhost)
                                      (params rc "uuid")))
                 #:status 302)))

(post "/artists/uuid/:uuid/artworks/new"
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
    ($artists 'set
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
                 (string->uri (format #f "~a/artists/uuid/~a"
                                      (current-myhost) new-uuid))
                 #:status 302)))

(post "/artists/new"
      #:auth '(table users "username" "password_hash")
      #:session #t
      (lambda (rc)
        (protected-endpoint rc
                            (lambda ()
                              (do-new rc)))))

(define (do-opinion rc is-like is-dislike)
  (let* ((uuid (params rc "uuid"))
         (user-identifier (:cookies-value rc "wikimusic-user-identifier"))
         (rec (car ($artists 'get
                             #:condition (where #:identifier uuid))))
         (new-uuid (generate-string-uuid))
         (ex-op (filter (lambda (o)
                          (equal? user-identifier
                                  (assoc-ref o "created_by")))
                        ($artist_opinions 'get
                                          #:condition (where
                                                             #:artist_identifier
                                                             uuid)))))
    (write rec)
    (if (not (nil? ex-op))
        ($artist_opinions 'mod
                          'row-delete
                          (where #:identifier (assoc-ref (car ex-op)
                                                         "identifier"))))
    ($artist_opinions 'set
                      #:identifier new-uuid
                      #:artist_identifier uuid
                      #:created_by user-identifier
                      #:is_like is-like
                      #:is_dislike is-dislike
                      #:created_at (current-time))
    (redirect-to rc
                 (string->uri (format #f "~a/artists/uuid/~a"
                                      (current-myhost) uuid))
                 #:status 302)))

(post "/artists/uuid/:uuid/like"
      #:auth '(table users "username" "password_hash")
      #:session #t
      (lambda (rc)
        (protected-endpoint rc
                            (lambda ()
                              (do-opinion rc 1 0)))))

(post "/artists/uuid/:uuid/dislike"
      #:auth '(table users "username" "password_hash")
      #:session #t
      (lambda (rc)
        (protected-endpoint rc
                            (lambda ()
                              (do-opinion rc 0 1)))))

;; ====== Delete data routes ======

(post "/artists/uuid/:uuid/artworks/:artwork-uuid/delete"
      #:auth '(table user "username" "password")
      #:session #t
      (lambda (rc)
        (define (do-delete)
          (delete-artwork #:rc rc
                          #:conn (DB-open rc)
                          #:entity 'artist
                          #:delete-condition (where #:identifier (params rc
                                                                  "artwork-uuid"))
                          #:redirect-url (format #f "~a/artists/uuid/~a/edit"
                                                 (current-myhost)
                                                 (params rc "uuid"))))
        (protected-endpoint rc do-delete)))
