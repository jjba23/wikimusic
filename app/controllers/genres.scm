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

(define-artanis-controller genres)

(import (wikimusic html)
        (web uri)
        (wikimusic url)
        (wikimusic auth)
        (wikimusic abstraction)
        (ice-9 string-fun)
        (app models genres)
        (app models genre_artworks)
        (app models genre_comments)
        (app models genre_opinions)
        (app models users)
        (wikimusic query-escape)
        (uuid generate)
        (app views genres))

(get "/genres"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names wikimusic-genre-sort)
     (lambda (rc)
       (let* ((user-sort (cond
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
              (user-limit (get-from-qstr rc "limit"))
              (user-offset (get-from-qstr rc "offset"))
              (genres ($genres 'get
                               #:order-by query-sort))
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
                               (genres-list-page (:i18n rc) genres artworks
                                                 opinions comments))))))

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
                          'genres set
                          `((views ,inc-v))
                          (where #:identifier uuid)))
         (response-emit (:mime rc
                               (genres-detail-page (:i18n rc)
                                                   genre
                                                   artworks
                                                   opinions
                                                   comments
                                                   user-alist))))))

(get "/genres/uuid/:uuid/edit"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((uuid (params rc "uuid"))
              (genre (car ($genres 'get
                                   #:ret 'top
                                   #:condition (where #:identifier uuid))))
              (artworks ($genre_artworks 'get
                                         #:ret 'all
                                         #:order-by '(order_value asc)
                                         #:condition (where #:genre_identifier
                                                            uuid))))
         
         (response-emit (:mime rc
                               (genre-edit-page (:i18n rc) genre artworks))))))

(define (do-edit rc)
  (let* ((body (rc-body rc))
         (kv (read-url-encoded-body body)))
    (DB-query (get-conn-from-pool!)
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
