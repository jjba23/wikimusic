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

(define-artanis-controller artists)

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
        (app views artists))

;; ====== Data view GET routes ======

(get "/artists"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names wikimusic-artist-sort x-bewaking-wikimusic)
     (lambda (rc)
       (let* ((user-search (cond
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
                             (else 40)))
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
                                                                  (string-join '
                                                                   (" WHERE (display_name LIKE '%~a%' OR description LIKE '%~a%') "
                                                                    " ORDER BY ~a ~a LIMIT ~a OFFSET ~a ")
                                                                   " ")
                                                                  (html-escape
                                                                   user-search)
                                                                  (html-escape
                                                                   user-search)
                                                                  (car
                                                                   query-sort)
                                                                  (cadr
                                                                   query-sort)
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
              (raw-external-sources ($artist_external_sources 'get
                                                              #:ret 'top
                                                              #:condition (where
                                                                           #:artist_identifier
                                                                           uuid)))
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

              (songs (DB-get-all-rows (DB-query (DB-open rc)
                                                (format #f
                                                 "SELECT * FROM songs WHERE identifier IN
                                                             (SELECT song_identifier FROM song_artists WHERE artist_identifier = '~a') ORDER BY ~a ~a"
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
              (song-fragment (song-list-page (:i18n rc)
                                             #:only-tiles #t
                                             #:songs songs
                                             #:artworks song-artworks
                                             #:song-version-count-alist
                                             song-version-count-alist
                                             #:artists '()
                                             #:song-artists '()
                                             #:opinions song-opinions
                                             #:comments song-comments
                                             #:limit 0
                                             #:offset 0
                                             #:search-query ""
                                             #:user-sort song-user-sort)))
         ;; do views update
         (DB-query (DB-open rc)
                   (->sql update
                          'artists set
                          `((views ,inc-v))
                          (where #:identifier uuid)))
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

;; ====== Data edit POST routes ======

(post "/artists/uuid/:uuid/edit"
      #:cookies '(names x-bewaking-wikimusic)
      (lambda (rc)
        (define (do-edit)
          (let* ((body (alist-from-url-encoded-body (rc-body rc))))
            (DB-query (DB-open rc)
                      (->sql update
                             'artists set
                             `((display_name ,(html-escape (assoc-ref body
                                                            "display-name")))
                               (description ,(html-escape (assoc-ref body
                                                           "description")))
                               (last_edited_at ,(current-time)))
                             (where #:identifier (params rc "uuid"))))
            (redirect-to rc
                         (string->uri (format #f "~a/artists/uuid/~a"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:artist-create)
                           #:rc rc
                           #:happy-flow do-edit
                           #:unhappy-flow back-to-login)))

(post "/artists/uuid/:uuid/external-sources/:sourcesuuid/edit"
      #:cookies '(names x-bewaking-wikimusic)
      (lambda (rc)
        (define (do-edit-external-sources)
          (let* ((body (alist-from-url-encoded-body (rc-body rc))))
            (DB-query (DB-open rc)
                      (->sql update
                             'artist_external_sources set
                             `((wikipedia_url ,(uri-encode (assoc-ref body
                                                            "wikipedia-url")))
                               (spotify_url ,(uri-encode (assoc-ref body
                                                          "spotify-url")))
                               (youtube_url ,(uri-encode (assoc-ref body
                                                          "youtube-url")))
                               (soundcloud_url ,(uri-encode (assoc-ref body
                                                             "soundcloud-url")))
                               (last_edited_at ,(current-time)))
                             (where #:identifier (params rc "sourcesuuid"))))
            (redirect-to rc
                         (string->uri (format #f "~a/artists/uuid/~a"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))

        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:artist-create)
                           #:rc rc
                           #:happy-flow do-edit-external-sources
                           #:unhappy-flow back-to-login)))

(post "/artists/uuid/:uuid/artworks/edit/:artwork-uuid"
      #:cookies '(names x-bewaking-wikimusic)
      (lambda (rc)
        (define (do-edit-artwork)
          (let* ((body (alist-from-url-encoded-body (rc-body rc))))
            (DB-query (DB-open rc)
                      (->sql update
                             'artist_artworks set
                             `((content_url ,(uri-encode (assoc-ref body
                                                          "content-url")))
                               (content_caption ,(html-escape (assoc-ref body
                                                               "content-caption")))
                               (order_value ,(html-escape (assoc-ref body
                                                           "order-value")))
                               (last_edited_at ,(current-time)))
                             (where #:identifier (params rc "artwork-uuid"))))
            (redirect-to rc
                         (string->uri (format #f "~a/artists/uuid/~a/edit"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))

        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:artist-create)
                           #:rc rc
                           #:happy-flow do-edit-artwork
                           #:unhappy-flow back-to-login)))

;; 
;; ====== Data create POST routes ======
;; 

(post "/artists/uuid/:uuid/artworks/new"
      #:cookies '(names x-bewaking-wikimusic)
      (lambda (rc)
        (define (do-new-artwork)
          (let* ((t (decrypt-token #:token (:cookies-value rc
                                            "x-bewaking-wikimusic")
                                   #:encryption-key encryption-key
                                   #:signing-key signing-key))
                 (body (alist-from-url-encoded-body (rc-body rc)))
                 (new-uuid (generate-string-uuid))
                 (user-identifier (assoc-ref t
                                             'owner-id)))
            ($artist_artworks 'set
                              #:identifier new-uuid
                              #:artist_identifier (params rc "uuid")
                              #:created_by user-identifier
                              #:visibility_status 0
                              #:content_url (uri-encode (assoc-ref body
                                                         "content-url"))
                              #:content_caption (html-escape (assoc-ref body
                                                              "content-caption"))
                              #:order_value (html-escape (assoc-ref body
                                                          "order-value"))
                              #:created_at (current-time))

            (redirect-to rc
                         (string->uri (format #f "~a/artists/uuid/~a/edit"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:artist-create)
                           #:rc rc
                           #:happy-flow do-new-artwork
                           #:unhappy-flow back-to-login)))

(post "/artists/new"
      #:cookies '(names x-bewaking-wikimusic)
      (lambda (rc)
        (define (do-new)
          (let* ((t (decrypt-token #:token (:cookies-value rc
                                            "x-bewaking-wikimusic")
                                   #:encryption-key encryption-key
                                   #:signing-key signing-key))
                 (body (alist-from-url-encoded-body (rc-body rc)))
                 (new-uuid (generate-string-uuid))
                 (user-identifier (assoc-ref t
                                             'owner-id)))
            ($artists 'set
                      #:identifier new-uuid
                      #:display_name (html-escape (assoc-ref body
                                                             "display-name"))
                      #:description (html-escape (assoc-ref body "description"))
                      #:created_by user-identifier
                      #:visibility_status 0
                      #:views 0
                      #:created_at (current-time))

            (redirect-to rc
                         (string->uri (format #f "~a/artists/uuid/~a"
                                              (current-myhost) new-uuid))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:artist-create)
                           #:rc rc
                           #:happy-flow do-new
                           #:unhappy-flow back-to-login)))

(define (do-opinion rc is-like is-dislike t)
  (let* ((uuid (params rc "uuid"))
         (user-identifier (assoc-ref t
                                     'owner-id))
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
      #:cookies '(names x-bewaking-wikimusic)
      (lambda (rc)
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '()
                           #:rc rc
                           #:happy-flow (lambda ()
                                          (do-opinion rc 1 0
                                                      (decrypt-token #:token (:cookies-value
                                                                              rc
                                                                              "x-bewaking-wikimusic")
                                                       #:encryption-key
                                                       encryption-key
                                                       #:signing-key
                                                       signing-key)))
                           #:unhappy-flow back-to-login)))

(post "/artists/uuid/:uuid/dislike"
      #:cookies '(names x-bewaking-wikimusic)
      (lambda (rc)
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '()
                           #:rc rc
                           #:happy-flow (lambda ()
                                          (do-opinion rc 0 1
                                                      (decrypt-token #:token (:cookies-value
                                                                              rc
                                                                              "x-bewaking-wikimusic")
                                                       #:encryption-key
                                                       encryption-key
                                                       #:signing-key
                                                       signing-key)))
                           #:unhappy-flow back-to-login)))

;; ====== Delete data routes ======

(post "/artists/uuid/:uuid/artworks/:artwork-uuid/delete"
      #:cookies '(names x-bewaking-wikimusic)
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
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:artist-delete)
                           #:rc rc
                           #:happy-flow do-delete
                           #:unhappy-flow back-to-login)))

(post "/artists/uuid/:uuid/external-sources/new"
      #:cookies '(names x-bewaking-wikimusic)
      (lambda (rc)
        (define (do-new-external-sources)
          (let* ((t (decrypt-token #:token (:cookies-value rc
                                            "x-bewaking-wikimusic")
                                   #:encryption-key encryption-key
                                   #:signing-key signing-key))
                 (body (alist-from-url-encoded-body (rc-body rc)))
                 (new-uuid (generate-string-uuid))
                 (user-identifier (assoc-ref t
                                             'owner-id)))
            ($artist_external_sources 'set
                                      #:identifier new-uuid
                                      #:artist_identifier (params rc "uuid")
                                      #:wikipedia_url (uri-encode (assoc-ref
                                                                   body
                                                                   "wikipedia-url"))
                                      #:soundcloud_url (uri-encode (assoc-ref
                                                                    body
                                                                    "soundcloud-url"))
                                      #:youtube_url (uri-encode (assoc-ref
                                                                 body
                                                                 "youtube-url"))
                                      #:spotify_url (uri-encode (assoc-ref
                                                                 body
                                                                 "spotify-url"))
                                      #:created_by user-identifier
                                      #:created_at (current-time))

            (redirect-to rc
                         (string->uri (format #f "~a/artists/uuid/~a"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))

        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:artist-create)
                           #:rc rc
                           #:happy-flow do-new-external-sources
                           #:unhappy-flow back-to-login)))
