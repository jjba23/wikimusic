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
        (wikimusic sqlite external-source)
        ;; `sql-execute!' is the one runner these edit routes reach for when a
        ;; row has to be rewritten in place; it lives with the other runners.
        (wikimusic sqlite util))

(post "/genres/uuid/:uuid/edit"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-edit)
          (let* ((G_ (:i18n rc))
                 (body (body-alist rc))
                 ;; Editing writes to a row someone owns, so the row is read
                 ;; first: its creator decides whether this session may change
                 ;; it (see `guard-owner').
                 (row (entity-or-404 (car ($genres 'get
                                                   #:condition (where
                                                                      #:identifier
                                                                      (params
                                                                       rc
                                                                       "uuid"))))
                                     "genre"
                                     (params rc "uuid")))
                 (created-by (assoc-ref row "created_by")))
            (when (guard-owner #:rc rc
                               #:created-by created-by)
              (sql-execute! rc
                            (sql-update 'genres
                                        `((display-name unquote
                                                        (html-escape (assoc-ref
                                                                      body
                                                                      "display-name")))
                                          (description unquote
                                                       (html-escape (assoc-ref
                                                                     body
                                                                     "description")))
                                          (last-edited-at unquote
                                                          (current-time)))
                                        #:where `((identifier unquote
                                                              (params rc
                                                                      "uuid"))))
                            #:name "edit-genre")
              (redirect-to rc
                           (string->uri (format #f
                                         "~a/genres/uuid/~a?notify-title=~a"
                                         (current-myhost)
                                         (params rc "uuid")
                                         (uri-encode (G_
                                                      "Edited genre succesfully!"))))
                           #:status 302))))
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
                 (body (body-alist rc)))
            ;; An artwork is a row someone owns, so its creator -- or a holder
            ;; of the super grant -- is who may rewrite it.
            (require-row-owner #:rc rc
                               #:table 'genre_artworks
                               #:where `((identifier unquote
                                                     (params rc "artwork-uuid"))))
            (sql-execute! rc
                          (sql-update 'genre_artworks
                                      `((content-url unquote
                                                     (uri-encode (assoc-ref
                                                                  body
                                                                  "content-url")))
                                        (content-caption unquote
                                                         (html-escape (assoc-ref
                                                                       body
                                                                       "content-caption")))
                                        (order-value unquote
                                                     (html-escape (assoc-ref
                                                                   body
                                                                   "order-value")))
                                        (last-edited-at unquote
                                                        (current-time)))
                                      #:where `((identifier unquote
                                                            (params rc
                                                             "artwork-uuid"))))
                          #:name "edit-genre-artwork")
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
                 (body (body-alist rc))
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
                 (body (body-alist rc))
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

;; ====== Comment routes ======
;;
;; A comment is written to the entity's own table, so the route names the
;; entity; editing or deleting one is allowed only to its author or a holder
;; of the super grant, and that rule lives in `guard-owner' inside the
;; `comment-*' helpers rather than being repeated at each route.

(post "/genres/uuid/:uuid/comments/new"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-comment)
          (comment-new #:rc rc
                       #:entity 'genre
                       #:entity-identifier (params rc "uuid")
                       #:redirect-url (format #f "~a/genres/uuid/~a"
                                              (current-myhost)
                                              (params rc "uuid"))))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '()
                           #:rc rc
                           #:happy-flow do-comment
                           #:unhappy-flow back-to-login)))

(post "/genres/uuid/:uuid/comments/:comment-uuid/edit"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-edit)
          (comment-edit #:rc rc
                        #:entity 'genre
                        #:comment-identifier (params rc "comment-uuid")
                        #:redirect-url (format #f "~a/genres/uuid/~a"
                                               (current-myhost)
                                               (params rc "uuid"))))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '()
                           #:rc rc
                           #:happy-flow do-edit
                           #:unhappy-flow back-to-login)))

(post "/genres/uuid/:uuid/comments/:comment-uuid/delete"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-delete)
          (comment-delete #:rc rc
                          #:entity 'genre
                          #:comment-identifier (params rc "comment-uuid")
                          #:redirect-url (format #f "~a/genres/uuid/~a"
                                                 (current-myhost)
                                                 (params rc "uuid"))))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '()
                           #:rc rc
                           #:happy-flow do-delete
                           #:unhappy-flow back-to-login)))

;; ====== Delete data routes ======

(post "/genres/uuid/:uuid/artworks/:artwork-uuid/delete"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-delete)
          (let* ((G_ (:i18n rc)))
            (delete-artwork #:rc rc
                            #:entity 'genre
                            #:artwork-identifier (params rc "artwork-uuid")
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
                 (body (body-alist rc)))
            ;; The external sources are a row someone owns: only its creator,
            ;; or a holder of the super grant, may rewrite them.
            (require-row-owner #:rc rc
                               #:table 'genre_external_sources
                               #:where `((identifier unquote
                                                     (params rc "sourcesuuid"))))
            (sql-execute! rc
                          (sql-update 'genre_external_sources
                                      `((wikipedia-url unquote
                                                       (uri-encode (assoc-ref
                                                                    body
                                                                    "wikipedia-url")))
                                        (spotify-url unquote
                                                     (uri-encode (assoc-ref
                                                                  body
                                                                  "spotify-url")))
                                        (youtube-url unquote
                                                     (uri-encode (assoc-ref
                                                                  body
                                                                  "youtube-url")))
                                        (soundcloud-url unquote
                                                        (uri-encode (assoc-ref
                                                                     body
                                                                     "soundcloud-url")))
                                        (last-edited-at unquote
                                                        (current-time)))
                                      #:where `((identifier unquote
                                                            (params rc
                                                             "sourcesuuid"))))
                          #:name "edit-genre-external-sources")
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
                 (body (body-alist rc))
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
