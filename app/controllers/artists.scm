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

(define-artanis-controller artists)

(import (wikimusic html)
        (web uri)
        (wikimusic url)
        (ice-9 string-fun)
        (wikimusic auth)
        (wikimusic abstraction)
        (app models artists)
        (app models artist_artworks)
        (app models artist_opinions)
        (app models artist_comments)
        (wikimusic query-escape)
        (uuid generate)
        (app models users)
        (app views artists))

(get "/artists?"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names wikimusic-artist-sort)
     (lambda (rc)
       (let* ((user-sort (cond
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
              (user-limit (get-from-qstr rc "limit"))
              (user-offset (get-from-qstr rc "offset"))
              (artists ($artists 'get
                                 #:order-by query-sort))
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
                               (artists-list-page (:i18n rc) artists artworks
                                                  opinions comments))))))

(get "/artists/new"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (response-emit (:mime rc
                             (artist-new-page (:i18n rc))))))

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

(define (do-edit rc)
  (let* ((body (rc-body rc))
         (kv (read-url-encoded-body body)))
    (write kv)
    (DB-query (get-conn-from-pool!)
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
