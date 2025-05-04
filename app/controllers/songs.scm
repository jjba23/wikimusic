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

(define-artanis-controller songs)

(import (app views songs))
(import (wikimusic html)
        (wikimusic url)
        (wikimusic domain)
        (wikimusic controller)
        (web uri)
        (ice-9 string-fun)
        (wikimusic auth)
        (app models songs)
        (app models song_artworks)
        (app models song_contents)
        (app models song_comments)
        (app models song_opinions)
        (uuid generate)
        (app views song-contents)
        (wikimusic query-escape)
        (app models users)
        (app views songs))

(get "/songs"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names wikimusic-song-sort)
     (lambda (rc)
       (let* ((user-sort (cond
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
              (query-sort (entity-sort-from-query user-sort))
              (query-offset (cond
                             ((not (nil? (get-from-qstr rc "offset")))
                              (string->number (get-from-qstr rc "offset")))
                             (else 0)))
              (query-limit (cond
                            ((not (nil? (get-from-qstr rc "limit")))
                             (string->number (get-from-qstr rc "limit")))
                            (else 20)))
              (songs (DB-get-all-rows (DB-query (DB-open rc) 
                                                (->sql select * from
                                                       'songs
                                                       (format #f
                                                               " ORDER BY ~a ~a LIMIT ~a OFFSET ~a"
                                                               (car query-sort)
                                                               (cadr query-sort)
                                                               query-limit
                                                               query-offset)))))
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
                         (songs-list-page (:i18n rc)
                                          #:songs songs
                                          #:artworks artworks
                                          #:song-version-count-alist
                                          song-version-count-alist
                                          #:opinions opinions
                                          #:comments comments
                                          #:limit query-limit
                                          #:offset query-offset))))))

(get "/songs/new"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (response-emit (:mime rc
                             (song-new-page (:i18n rc))))))

(get "/songs/uuid/:uuid/contents/new"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (response-emit (:mime rc
                             (song-contents-new-page (:i18n rc)
                                                     (params rc "uuid"))))))

(get "/songs/uuid/:uuid"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names wikimusic-ascii-size)
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
              (users ($users 'get
                             #:ret 'all
                             #:order-by '(display_name asc)
                             #:columns '(identifier display_name email_address
                                                    username avatar_url)))
              (user-alist (map (lambda (u)
                                 `(,(assoc-ref u "identifier") ,u)) users))
              (song-contents ($song_contents 'get
                                             #:ret 'all
                                             #:condition (where
                                                          #:song_identifier
                                                          uuid))))
         
         ;; do views update
         (DB-query (DB-open rc)
                   (->sql update
                          'songs set
                          `((views ,inc-v))
                          (where #:identifier uuid)))

         ;; return rendered view
         (response-emit (:mime rc
                         (songs-detail-page (:i18n rc)
                                            song
                                            artworks
                                            song-contents
                                            opinions
                                            comments
                                            user-alist
                                            ascii-size))))))

(get "/songs/uuid/:uuid/edit"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((uuid (params rc "uuid"))
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
                                                                uuid))))
         
         (response-emit (:mime rc
                               (song-edit-page (:i18n rc) song song-contents
                                               artworks))))))

(get "/songs/uuid/:uuid/contents/:version-uuid/edit"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((uuid (params rc "uuid"))
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
                               (song-content-edit-page (:i18n rc) song
                                                       song-contents))))))

(define (do-edit rc)
  (let* ((body (rc-body rc))
         (kv (read-url-encoded-body body)))
    (DB-query (DB-open rc) 
              (->sql update
                     'songs set
                     `((display_name ,(escape-str (uri-decode (car (assoc-ref
                                                                    kv
                                                                    "display-name")))))
                       (description ,(escape-str (uri-decode (car (assoc-ref
                                                                   kv
                                                                   "description")))))
                       (last_edited_at ,(current-time)))
                     (where #:identifier (params rc "uuid"))))
    (redirect-to rc
                 (string->uri (format #f "~a/songs/uuid/~a"
                                      (current-myhost)
                                      (params rc "uuid")))
                 #:status 302)))

(post "/songs/uuid/:uuid/edit"
      #:auth '(table users "username" "password_hash")
      #:session #t
      (lambda (rc)
        (protected-endpoint rc
                            (lambda ()
                              (do-edit rc)))))

(define (do-contents-edit rc)
  (let* ((body (rc-body rc))
         (kv (read-url-encoded-body body)))
    (DB-query (DB-open rc) 
              (->sql update
                     'song_contents set
                     `((instrument_type ,(escape-str (uri-decode (car (assoc-ref
                                                                       kv
                                                                       "instrument-type")))))
                       (version_name ,(escape-str (uri-decode (car (assoc-ref
                                                                    kv
                                                                    "version-name")))))
                       (ascii_legend ,(escape-str (uri-decode (car (assoc-ref
                                                                    kv
                                                                    "ascii-legend")))))
                       (ascii_contents ,(escape-str (uri-decode (car (assoc-ref
                                                                      kv
                                                                      "ascii-contents")))))
                       (last_edited_at ,(current-time)))
                     (where #:identifier (params rc "version-uuid"))))
    (redirect-to rc
                 (string->uri (format #f "~a/songs/uuid/~a"
                                      (current-myhost)
                                      (params rc "uuid")))
                 #:status 302)))

(post "/songs/uuid/:uuid/contents/:version-uuid/edit"
      #:auth '(table users "username" "password_hash")
      #:session #t
      (lambda (rc)
        (protected-endpoint rc
                            (lambda ()
                              (do-contents-edit rc)))))

(define (do-edit-artwork rc)
  (let* ((body (rc-body rc))
         (kv (read-url-encoded-body body)))
    (DB-query (DB-open rc) 
              (->sql update
                     'song_artworks set
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
                 (string->uri (format #f "~a/songs/uuid/~a/edit"
                                      (current-myhost)
                                      (params rc "uuid")))
                 #:status 302)))

(post "/songs/uuid/:uuid/artworks/edit/:artwork-uuid"
      #:auth '(table users "username" "password_hash")
      #:session #t
      (lambda (rc)
        (protected-endpoint rc
                            (lambda ()
                              (do-edit-artwork rc)))))

;; 
;; ====== Data create POST routes ======
;; 

(define (do-new-content rc)
  (let* ((body (rc-body rc))
         (kv (read-url-encoded-body body))
         (new-uuid (generate-string-uuid))
         (user-identifier (:cookies-value rc "wikimusic-user-identifier")))
    ($song_contents 'set
                    #:identifier new-uuid
                    #:song_identifier (params rc "uuid")
                    #:created_by user-identifier
                    #:visibility_status 0
                    #:instrument_type (escape-str (uri-decode (car (assoc-ref
                                                                    kv
                                                                    "instrument-type"))))
                    #:version_name (escape-str (uri-decode (car (assoc-ref kv
                                                                 "version-name"))))
                    #:ascii_legend (escape-str (uri-decode (car (assoc-ref kv
                                                                 "ascii-legend"))))
                    #:ascii_contents (escape-str (uri-decode (car (assoc-ref
                                                                   kv
                                                                   "ascii-contents"))))
                    #:pdf_contents (escape-str (uri-decode (car (assoc-ref kv
                                                                 "pdf-contents"))))
                    #:guitarpro_contents (escape-str (uri-decode (car (assoc-ref
                                                                       kv
                                                                       "guitarpro-contents"))))
                    #:created_at (current-time))

    (redirect-to rc
                 (string->uri (format #f "~a/songs/uuid/~a"
                                      (current-myhost)
                                      (params rc "uuid")))
                 #:status 302)))

(post "/songs/uuid/:uuid/contents/new"
      #:auth '(table users "username" "password_hash")
      #:session #t
      (lambda (rc)
        (protected-endpoint rc
                            (lambda ()
                              (do-new-content rc)))))

(define (do-new-artwork rc)
  (let* ((body (rc-body rc))
         (kv (read-url-encoded-body body))
         (new-uuid (generate-string-uuid))
         (user-identifier (:cookies-value rc "wikimusic-user-identifier")))
    ($song_artworks 'set
                    #:identifier new-uuid
                    #:song_identifier (params rc "uuid")
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
                 (string->uri (format #f "~a/songs/uuid/~a/edit"
                                      (current-myhost)
                                      (params rc "uuid")))
                 #:status 302)))

(post "/songs/uuid/:uuid/artworks/new"
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
    ($songs 'set
            #:identifier new-uuid
            #:display_name (escape-str (uri-decode (car (assoc-ref kv
                                                         "display-name"))))
            #:music_key (escape-str (uri-decode (car (assoc-ref kv "music-key"))))
            #:music_tuning (escape-str (uri-decode (car (assoc-ref kv
                                                         "music-tuning"))))
            #:music_creation_date (escape-str (uri-decode (car (assoc-ref kv
                                                                "music-creation-date"))))
            #:album_name (escape-str (uri-decode (car (assoc-ref kv
                                                                 "album-name"))))
            #:album_info_link (escape-str (uri-decode (car (assoc-ref kv
                                                            "album-info-link"))))
            #:description (escape-str (uri-decode (car (assoc-ref kv
                                                        "description"))))
            #:created_by user-identifier
            #:visibility_status 0
            #:views 0
            #:created_at (current-time))

    (redirect-to rc
                 (string->uri (format #f "~a/songs/uuid/~a"
                                      (current-myhost) new-uuid))
                 #:status 302)))

(post "/songs/new"
      #:auth '(table users "username" "password_hash")
      #:session #t
      (lambda (rc)
        (protected-endpoint rc
                            (lambda ()
                              (do-new rc)))))

(define (do-opinion rc is-like is-dislike)
  (let* ((uuid (params rc "uuid"))
         (user-identifier (:cookies-value rc "wikimusic-user-identifier"))
         (rec (car ($songs 'get
                           #:condition (where #:identifier uuid))))
         (new-uuid (generate-string-uuid))
         (ex-op (filter (lambda (o)
                          (equal? user-identifier
                                  (assoc-ref o "created_by")))
                        ($song_opinions 'get
                                        #:condition (where #:song_identifier
                                                           uuid)))))
    (write rec)
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
                 (string->uri (format #f "~a/songs/uuid/~a"
                                      (current-myhost) uuid))
                 #:status 302)))

(post "/songs/uuid/:uuid/like"
      #:auth '(table users "username" "password_hash")
      #:session #t
      (lambda (rc)
        (protected-endpoint rc
                            (lambda ()
                              (do-opinion rc 1 0)))))

(post "/songs/uuid/:uuid/dislike"
      #:auth '(table users "username" "password_hash")
      #:session #t
      (lambda (rc)
        (protected-endpoint rc
                            (lambda ()
                              (do-opinion rc 0 1)))))

;; ====== Delete data routes ======

(post "/songs/uuid/:uuid/artworks/:artwork-uuid/delete"
      #:auth '(table user "username" "password")
      #:session #t
      (lambda (rc)
        (define (do-delete)
          (delete-artwork #:rc rc
                          #:conn (DB-open rc) 
                          #:entity 'song
                          #:delete-condition (where #:identifier (params rc
                                                                         "artwork-uuid"))
                          #:redirect-url (format #f "~a/songs/uuid/~a/edit"
                                                 (current-myhost)
                                                 (params rc "uuid"))))
        (protected-endpoint rc do-delete)))

(post "/songs/uuid/:uuid/contents/:version-uuid/delete"
      #:auth '(table user "username" "password")
      #:session #t
      (lambda (rc)
        (define (do-delete)
          (DB-query (DB-open rc) 
                    (->sql delete from
                           'song_contents
                           (where #:identifier (params rc "version-uuid")))))
        (protected-endpoint rc do-delete)))
