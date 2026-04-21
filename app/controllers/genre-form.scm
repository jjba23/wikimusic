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

(define-artanis-controller genre-form)

(import (wikimusic html)
        (web uri)
        (wikimusic env)
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
        (bewaking bewaking)
        (kracht prelude)
        (uuid generate)
        (wikimusic domain genre)
        (wikimusic sqlite genre)
        (wikimusic domain artwork)
        (wikimusic sqlite artwork)
        (wikimusic domain song)
        (wikimusic sqlite song)
        (wikimusic domain comment)
        (wikimusic sqlite comment)
        (wikimusic domain opinion)
        (wikimusic sqlite opinion)
        (wikimusic domain external-source)
        (wikimusic sqlite external-source))


(post "/genres/uuid/:uuid/edit"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-edit)
          (let* ((G_ (:i18n rc))
                 (body (alist-from-url-encoded-body (rc-body rc))))
            (DB-query (DB-open rc)
                      (->sql update
                             'genres set
                             `((display_name ,(html-escape (assoc-ref body
                                                            "display-name")))
                               (description ,(html-escape (assoc-ref body
                                                           "description")))
                               (last_edited_at ,(current-time)))
                             (where #:identifier (params rc "uuid"))))
            (redirect-to rc
                         (string->uri (format #f
                                       "~a/genres/uuid/~a?notify-title=~a"
                                       (current-myhost)
                                       (params rc "uuid")
                                       (uri-encode (G_
                                                    "Edited genre succesfully!"))))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:genre-create)
                           #:rc rc
                           #:happy-flow do-edit
                           #:unhappy-flow back-to-login)))

(post "/genres/uuid/:uuid/artworks/edit/:artwork-uuid"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-edit-artwork)
          (let* ((G_ (:i18n rc))
                 (body (alist-from-url-encoded-body (rc-body rc))))
            (DB-query (DB-open rc)
                      (->sql update
                             'genre_artworks set
                             `((content_url ,(uri-encode (assoc-ref body
                                                          "content-url")))
                               (content_caption ,(html-escape (assoc-ref body
                                                               "content-caption")))
                               (order_value ,(html-escape (assoc-ref body
                                                           "order-value")))
                               (last_edited_at ,(current-time)))
                             (where #:identifier (params rc "artwork-uuid"))))
            (redirect-to rc
                         (string->uri (format #f "~a/genres/uuid/~a/edit"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:genre-create)
                           #:rc rc
                           #:happy-flow do-edit-artwork
                           #:unhappy-flow back-to-login)))

;; 
;; ====== Data create POST routes ======
;; 

(post "/genres/uuid/:uuid/artworks/new"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-new-artwork)
          (let* ((G_ (:i18n rc))
                 (t (decrypt-token #:token (:cookies-value rc
                                            "x-bewaking-wikimusic")
                                   #:encryption-key encryption-key
                                   #:signing-key signing-key))
                 (body (alist-from-url-encoded-body (rc-body rc)))
                 (new-uuid (generate-string-uuid))
                 (user-identifier (assoc-ref t
                                             'owner-id)))
            ($genre_artworks 'set
                             #:identifier new-uuid
                             #:genre_identifier (params rc "uuid")
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
                         (string->uri (format #f "~a/genres/uuid/~a/edit"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:genre-create)
                           #:rc rc
                           #:happy-flow do-new-artwork
                           #:unhappy-flow back-to-login)))

(post "/genres/new"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-new)
          (let* ((G_ (:i18n rc))
                 (t (decrypt-token #:token (:cookies-value rc
                                            "x-bewaking-wikimusic")
                                   #:encryption-key encryption-key
                                   #:signing-key signing-key))
                 (body (alist-from-url-encoded-body (rc-body rc)))
                 (new-uuid (generate-string-uuid))
                 (user-identifier (assoc-ref t
                                             'owner-id)))
            ($genres 'set
                     #:identifier new-uuid
                     #:display_name (html-escape (assoc-ref body
                                                            "display-name"))
                     #:description (html-escape (assoc-ref body "description"))
                     #:created_by user-identifier
                     #:visibility_status 0
                     #:views 0
                     #:created_at (current-time))

            (redirect-to rc
                         (string->uri (format #f "~a/genres/uuid/~a"
                                              (current-myhost) new-uuid))
                         #:status 302)))

        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:genre-create)
                           #:rc rc
                           #:happy-flow do-new
                           #:unhappy-flow back-to-login)))

(define (do-opinion rc is-like is-dislike t)
  (let* ((G_ (:i18n rc))
         (uuid (params rc "uuid"))
         (user-identifier (assoc-ref t
                                     'owner-id))
         (rec (car ($genres 'get
                            #:condition (where #:identifier uuid))))
         (new-uuid (generate-string-uuid))
         (ex-op (filter (lambda (o)
                          (equal? user-identifier
                                  (assoc-ref o "created_by")))
                        ($genre_opinions 'get
                                         #:condition (where #:genre_identifier
                                                            uuid)))))
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
                 (string->uri (format #f "~a/genres/uuid/~a?notify-title=~a"
                                      (current-myhost) uuid
                                      (if (equal? 1 is-like)
                                          (uri-encode (G_ "Liked genre!"))
                                          (uri-encode (G_ "Disliked genre!")))))
                 #:status 302)))

(post "/genres/uuid/:uuid/like"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
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

(post "/genres/uuid/:uuid/dislike"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
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

(post "/genres/uuid/:uuid/artworks/:artwork-uuid/delete"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-delete)
          (let* ((G_ (:i18n rc)))
            (delete-artwork #:rc rc
                            #:conn (DB-open rc)
                            #:entity 'genre
                            #:delete-condition (where #:identifier (params rc
                                                                    "artwork-uuid"))
                            #:redirect-url (format #f "~a/genres/uuid/~a/edit"
                                                   (current-myhost)
                                                   (params rc "uuid")))))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:genre-delete)
                           #:rc rc
                           #:happy-flow do-delete
                           #:unhappy-flow back-to-login)))

(post "/genres/uuid/:uuid/external-sources/:sourcesuuid/edit"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-edit-external-sources)
          (let* ((G_ (:i18n rc))
                 (body (alist-from-url-encoded-body (rc-body rc))))
            (DB-query (DB-open rc)
                      (->sql update
                             'genre_external_sources set
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
                         (string->uri (format #f
                                       "~a/genres/uuid/~a?notify-title=~a"
                                       (current-myhost)
                                       (params rc "uuid")
                                       (uri-encode (G_
                                                    "Edited genre succesfully!"))))
                         #:status 302)))

        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:genre-create)
                           #:rc rc
                           #:happy-flow do-edit-external-sources
                           #:unhappy-flow back-to-login)))

(post "/genres/uuid/:uuid/external-sources/new"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-new-external-sources)
          (let* ((G_ (:i18n rc))
                 (t (decrypt-token #:token (:cookies-value rc
                                            "x-bewaking-wikimusic")
                                   #:encryption-key encryption-key
                                   #:signing-key signing-key))
                 (body (alist-from-url-encoded-body (rc-body rc)))
                 (new-uuid (generate-string-uuid))
                 (user-identifier (assoc-ref t
                                             'owner-id)))
            ($genre_external_sources 'set
                                     #:identifier new-uuid
                                     #:genre_identifier (params rc "uuid")
                                     #:wikipedia_url (uri-encode (assoc-ref
                                                                  body
                                                                  "wikipedia-url"))
                                     #:soundcloud_url (uri-encode (assoc-ref
                                                                   body
                                                                   "soundcloud-url"))
                                     #:youtube_url (uri-encode (assoc-ref body
                                                                "youtube-url"))
                                     #:spotify_url (uri-encode (assoc-ref body
                                                                "spotify-url"))
                                     #:created_by user-identifier
                                     #:created_at (current-time))

            (redirect-to rc
                         (string->uri (format #f
                                       "~a/genres/uuid/~a?notify-title=~a"
                                       (current-myhost)
                                       (params rc "uuid")
                                       (uri-encode (G_
                                                    "Edited genre succesfully!"))))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:genre-create)
                           #:rc rc
                           #:happy-flow do-new-external-sources
                           #:unhappy-flow back-to-login)))
