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
        (wikimusic abstraction)
        (web uri)
        (ice-9 string-fun)
        (wikimusic auth)
        (app models songs)
        (app models song_artworks)
        (app models song_contents)
        (app models song_comments)
        (app models song_opinions)
        (uuid generate)
        (wikimusic query-escape)
        (app models users)
        (app views songs))

(get "/songs?"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((user-sort (get-from-qstr rc "sort"))
              (query-sort (entity-sort-from-query user-sort))
              (user-limit (get-from-qstr rc "limit"))
              (user-offset (get-from-qstr rc "offset"))
              (songs ($songs 'get
                             #:order-by query-sort))
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
                                                songs
                                                artworks
                                                song-version-count-alist
                                                opinions
                                                comments))))))

(get "/songs/uuid/:uuid"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((uuid (params rc "uuid"))
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
                                                  user-alist))))))

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

(define (do-edit rc)
  (let* ((body (rc-body rc))
         (kv (read-url-encoded-body body)))
    (DB-query (get-conn-from-pool!)
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
