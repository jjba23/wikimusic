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

(define-artanis-controller song-form)

(import (wikimusic html)
        (wikimusic domain)
        (wikimusic controller)
        (web uri)
        (ice-9 string-fun)
        (wikimusic auth)
        (app models songs)
        (app models genres)
        (wikimusic env)
        (app models artists)
        (app models song_artworks)
        (app models song_contents)
        (app models song_comments)
        (app models song_opinions)
        (app models artists)
        (app models genres)
        (kracht prelude)
        (app models song_artists)
        (app models song_genres)
        (app views song-view)
        (app views song-edit)
        (app views song-content-view)
        (app views song-content-edit)
        (app models song_external_sources)
        (uuid generate)
        (bewaking bewaking)
        (app models users)
        (wikimusic sqlite song)
        (wikimusic domain song)
        (wikimusic sqlite artwork)
        (wikimusic domain artwork)
        (wikimusic domain comment)
        (wikimusic sqlite comment)
        (wikimusic domain opinion)
        (wikimusic sqlite opinion)
        (wikimusic domain external-source)
        (wikimusic sqlite external-source)
        (wikimusic sqlite artist)
        (wikimusic domain artist)
        ;; `sql-execute!' is the one runner these edit routes reach for when a
        ;; row has to be rewritten in place; it lives with the other runners.
        (wikimusic sqlite util))

(post "/songs/uuid/:uuid/edit"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-edit)
          (let* ((G_ (:i18n rc))
                 (body (body-alist rc))
                 ;; Editing is a write to a row someone owns, so the row is
                 ;; read first: its creator decides whether this session may
                 ;; change it (see `guard-owner').
                 (row (entity-or-404 (car ($songs 'get
                                                  #:condition (where #:identifier
                                                                     (params
                                                                      rc
                                                                      "uuid"))))
                                     "song" (params rc "uuid")))
                 (created-by (assoc-ref row "created_by")))
            (when (guard-owner #:rc rc #:created-by created-by)
              (sql-execute! rc
                            (sql-update 'songs
                                        `((display-name
                                           . ,(html-escape (assoc-ref body
                                                                      "display-name")))
                                          (description
                                           . ,(html-escape (assoc-ref body
                                                                      "description")))
                                          (music-key
                                           . ,(html-escape (assoc-ref body
                                                                      "music-key")))
                                          (music-tuning
                                           . ,(html-escape (assoc-ref body
                                                                      "music-tuning")))
                                          (music-creation-date
                                           . ,(html-escape (assoc-ref body
                                                                      "music-creation-date")))
                                          (album-name
                                           . ,(html-escape (assoc-ref body
                                                                      "album-name")))
                                          (album-info-link
                                           . ,(uri-encode (assoc-ref body
                                                                     "album-info-link")))
                                          (last-edited-at . ,(current-time)))
                                        #:where `((identifier
                                                   . ,(params rc "uuid"))))
                            #:name "edit-song")
              (redirect-to rc
                           (string->uri (format #f
                                         "~a/songs/uuid/~a?notify-title=~a"
                                         (current-myhost)
                                         (params rc "uuid")
                                         (uri-encode (G_
                                                      "Edited song succesfully!"))))
                           #:status 302))))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-edit
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/contents/:version-uuid/edit"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-contents-edit)
          (let* ((G_ (:i18n rc))
                 (body (body-alist rc)))
            ;; A version is a row someone owns: only its creator, or a holder
            ;; of the super grant, may rewrite it.
            (require-row-owner #:rc rc
                               #:table 'song_contents
                               #:where `((identifier
                                          . ,(params rc "version-uuid"))))
            (sql-execute! rc
                          (sql-update 'song_contents
                                      `((instrument-type
                                         . ,(html-escape (assoc-ref body
                                                                    "instrument-type")))
                                        (version-name
                                         . ,(html-escape (assoc-ref body
                                                                    "version-name")))
                                        (ascii-legend
                                         . ,(html-escape (assoc-ref body
                                                                    "ascii-legend")))
                                        (ascii-contents
                                         . ,(html-escape (assoc-ref body
                                                                    "ascii-contents")))
                                        (pdf-contents
                                         . ,(assoc-ref body "pdf-contents"))
                                        (guitarpro-contents
                                         . ,(assoc-ref body
                                                       "guitarpro-contents"))
                                        (last-edited-at . ,(current-time)))
                                      #:where `((identifier
                                                 . ,(params rc
                                                           "version-uuid"))))
                          #:name "edit-song-contents")
            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))

        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-contents-edit
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/artworks/edit/:artwork-uuid"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-edit-artwork)
          (let* ((G_ (:i18n rc))
                 (body (body-alist rc)))
            ;; An artwork is a row someone owns, so its creator -- or a holder
            ;; of the super grant -- is who may rewrite it.
            (require-row-owner #:rc rc
                               #:table 'song_artworks
                               #:where `((identifier
                                          . ,(params rc "artwork-uuid"))))
            (sql-execute! rc
                          (sql-update 'song_artworks
                                      `((content-url
                                         . ,(uri-encode (assoc-ref body
                                                                  "content-url")))
                                        (content-caption
                                         . ,(html-escape (assoc-ref body
                                                                    "content-caption")))
                                        (order-value
                                         . ,(html-escape (assoc-ref body
                                                                    "order-value")))
                                        (last-edited-at . ,(current-time)))
                                      #:where `((identifier
                                                 . ,(params rc
                                                           "artwork-uuid"))))
                          #:name "edit-song-artwork")
            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a/edit"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-edit-artwork
                           #:unhappy-flow back-to-login)))

;;
;; ====== Data create POST routes ======
;;

(post "/songs/uuid/:uuid/contents/new"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-new-content)
          (let* ((G_ (:i18n rc))
                 (t (decrypt-token #:token (:cookies-value rc
                                            "x-bewaking-wikimusic")
                                   #:encryption-key encryption-key
                                   #:signing-key signing-key))
                 (body (body-alist rc))
                 (new-uuid (generate-string-uuid))
                 (user-identifier (assoc-ref t
                                             'owner-id)))
            ($song_contents 'set
                            #:identifier new-uuid
                            #:song_identifier (params rc "uuid")
                            #:created_by user-identifier
                            #:visibility_status 0
                            #:instrument_type (html-escape (assoc-ref body
                                                            "instrument-type"))
                            #:version_name (html-escape (assoc-ref body
                                                         "version-name"))
                            #:ascii_legend (html-escape (assoc-ref body
                                                         "ascii-legend"))
                            #:ascii_contents (html-escape (assoc-ref body
                                                           "ascii-contents"))
                            #:pdf_contents (assoc-ref body "pdf-contents")
                            #:guitarpro_contents (assoc-ref body
                                                  "guitarpro-contents")
                            #:created_at (current-time))

            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-new-content
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/artworks/new"
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
            ($song_artworks 'set
                            #:identifier new-uuid
                            #:song_identifier (params rc "uuid")
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
                         (string->uri (format #f "~a/songs/uuid/~a/edit"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-new-artwork
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/artists"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-new-song-artist)
          (let* ((G_ (:i18n rc))
                 (t (decrypt-token #:token (:cookies-value rc
                                            "x-bewaking-wikimusic")
                                   #:encryption-key encryption-key
                                   #:signing-key signing-key))
                 (body (body-alist rc))
                 (new-uuid (generate-string-uuid))
                 (user-identifier (assoc-ref t
                                             'owner-id))
                 (artist ($artists 'get
                                   #:ret 'top
                                   #:condition (where #:identifier (assoc-ref
                                                                    body
                                                                    "artist-identifier")))))
            (when (not (nil? artist))
              ($song_artists 'set
                             #:identifier new-uuid
                             #:song_identifier (params rc "uuid")
                             #:artist_identifier (assoc-ref body
                                                  "artist-identifier")
                             #:created_by user-identifier
                             #:created_at (current-time)))

            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a/edit"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-new-song-artist
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/genres"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-new-song-genre)
          (let* ((G_ (:i18n rc))
                 (t (decrypt-token #:token (:cookies-value rc
                                            "x-bewaking-wikimusic")
                                   #:encryption-key encryption-key
                                   #:signing-key signing-key))
                 (body (body-alist rc))
                 (new-uuid (generate-string-uuid))
                 (user-identifier (assoc-ref t
                                             'owner-id))
                 (genre ($genres 'get
                                 #:ret 'top
                                 #:condition (where #:identifier (assoc-ref
                                                                  body
                                                                  "genre-identifier")))))
            (when (not (nil? genre))
              ($song_genres 'set
                            #:identifier new-uuid
                            #:song_identifier (params rc "uuid")
                            #:genre_identifier (assoc-ref body
                                                          "genre-identifier")
                            #:created_by user-identifier
                            #:created_at (current-time)))

            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a/edit"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))

        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-new-song-genre
                           #:unhappy-flow back-to-login)))

(post "/songs/new"
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
            ($songs 'set
                    #:identifier new-uuid
                    #:display_name (html-escape (assoc-ref body "display-name"))
                    #:music_key (html-escape (assoc-ref body "music-key"))
                    #:music_tuning (html-escape (assoc-ref body "music-tuning"))
                    #:music_creation_date (html-escape (assoc-ref body
                                                        "music-creation-date"))
                    #:album_name (html-escape (assoc-ref body "album-name"))
                    #:album_info_link (uri-encode (assoc-ref body
                                                   "album-info-link"))
                    #:description (html-escape (assoc-ref body "description"))
                    #:created_by user-identifier
                    #:visibility_status 0
                    #:views 0
                    #:created_at (current-time))

            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a"
                                              (current-myhost) new-uuid))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-new
                           #:unhappy-flow back-to-login)))

(define (do-opinion rc is-like is-dislike t)
  (let* ((G_ (:i18n rc))
         (uuid (params rc "uuid"))
         (user-identifier (assoc-ref t
                                     'owner-id))
         (rec (car ($songs 'get
                           #:condition (where #:identifier uuid))))
         (new-uuid (generate-string-uuid))
         (ex-op (filter (lambda (o)
                          (equal? user-identifier
                                  (assoc-ref o "created_by")))
                        ($song_opinions 'get
                                        #:condition (where #:song_identifier
                                                           uuid)))))
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
                 (string->uri (format #f "~a/songs/uuid/~a?notify-title=~a"
                                      (current-myhost) uuid
                                      (if (equal? 1 is-like)
                                          (uri-encode (G_ "Liked song!"))
                                          (uri-encode (G_ "Disliked song!")))))
                 #:status 302)))

(post "/songs/uuid/:uuid/like"
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

(post "/songs/uuid/:uuid/dislike"
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

(post "/songs/uuid/:uuid/comments/new"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-comment)
          (comment-new #:rc rc
                       #:entity 'song
                       #:entity-identifier (params rc "uuid")
                       #:redirect-url (format #f "~a/songs/uuid/~a"
                                              (current-myhost)
                                              (params rc "uuid"))))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '()
                           #:rc rc
                           #:happy-flow do-comment
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/comments/:comment-uuid/edit"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-edit)
          (comment-edit #:rc rc
                        #:entity 'song
                        #:comment-identifier (params rc "comment-uuid")
                        #:redirect-url (format #f "~a/songs/uuid/~a"
                                               (current-myhost)
                                               (params rc "uuid"))))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '()
                           #:rc rc
                           #:happy-flow do-edit
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/comments/:comment-uuid/delete"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-delete)
          (comment-delete #:rc rc
                          #:entity 'song
                          #:comment-identifier (params rc "comment-uuid")
                          #:redirect-url (format #f "~a/songs/uuid/~a"
                                                 (current-myhost)
                                                 (params rc "uuid"))))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '()
                           #:rc rc
                           #:happy-flow do-delete
                           #:unhappy-flow back-to-login)))

;; ====== Delete data routes ======

(post "/songs/uuid/:uuid/artworks/:artwork-uuid/delete"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-delete)
          (let* ((G_ (:i18n rc)))
            (delete-artwork #:rc rc
                            #:entity 'song
                            #:artwork-identifier (params rc "artwork-uuid")
                            #:redirect-url (format #f "~a/songs/uuid/~a/edit"
                                                   (current-myhost)
                                                   (params rc "uuid")))))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-delete)
                           #:rc rc
                           #:happy-flow do-delete
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/contents/:version-uuid/delete"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-delete)
          (let* ((G_ (:i18n rc)))
            ;; The version is a row someone owns: only its creator, or a
            ;; holder of the super grant, may take it away.
            (require-row-owner #:rc rc
                               #:table 'song_contents
                               #:where `((identifier
                                          . ,(params rc "version-uuid"))))
            (sql-execute! rc
                          (sql-delete 'song_contents
                                      #:where `((identifier
                                                 . ,(params rc
                                                           "version-uuid"))))
                          #:name "delete-song-content")
            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-delete)
                           #:rc rc
                           #:happy-flow do-delete
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/artists/:artist-uuid/delete"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-delete-artist)
          (let* ((G_ (:i18n rc)))
            ;; The link is a row someone owns: only whoever made it, or a
            ;; holder of the super grant, may take it away.
            (require-row-owner #:rc rc
                               #:table 'song_artists
                               #:where `((artist-identifier
                                          . ,(params rc "artist-uuid"))
                                         (song-identifier
                                          . ,(params rc "uuid"))))
            (sql-execute! rc
                          (sql-delete 'song_artists
                                      #:where `((artist-identifier
                                                 . ,(params rc "artist-uuid"))
                                                (song-identifier
                                                 . ,(params rc "uuid"))))
                          #:name "delete-song-artist")
            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a/edit"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-delete)
                           #:rc rc
                           #:happy-flow do-delete-artist
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/genres/:genre-uuid/delete"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-delete-genre)
          (let* ((G_ (:i18n rc)))
            ;; The link is a row someone owns: only whoever made it, or a
            ;; holder of the super grant, may take it away.
            (require-row-owner #:rc rc
                               #:table 'song_genres
                               #:where `((genre-identifier
                                          . ,(params rc "genre-uuid"))
                                         (song-identifier
                                          . ,(params rc "uuid"))))
            (sql-execute! rc
                          (sql-delete 'song_genres
                                      #:where `((genre-identifier
                                                 . ,(params rc "genre-uuid"))
                                                (song-identifier
                                                 . ,(params rc "uuid"))))
                          #:name "delete-song-genre")
            (redirect-to rc
                         (string->uri (format #f "~a/songs/uuid/~a/edit"
                                              (current-myhost)
                                              (params rc "uuid")))
                         #:status 302)))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-delete)
                           #:rc rc
                           #:happy-flow do-delete-genre
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/external-sources/:sourcesuuid/edit"
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-edit-external-sources)
          (let* ((G_ (:i18n rc))
                 (body (body-alist rc)))
            ;; The external sources are a row someone owns: only its creator,
            ;; or a holder of the super grant, may rewrite them.
            (require-row-owner #:rc rc
                               #:table 'song_external_sources
                               #:where `((identifier
                                          . ,(params rc "sourcesuuid"))))
            (sql-execute! rc
                          (sql-update 'song_external_sources
                                      `((wikipedia-url
                                         . ,(uri-encode (assoc-ref body
                                                                  "wikipedia-url")))
                                        (spotify-url
                                         . ,(uri-encode (assoc-ref body
                                                                  "spotify-url")))
                                        (youtube-url
                                         . ,(uri-encode (assoc-ref body
                                                                  "youtube-url")))
                                        (soundcloud-url
                                         . ,(uri-encode (assoc-ref body
                                                                  "soundcloud-url")))
                                        (last-edited-at . ,(current-time)))
                                      #:where `((identifier
                                                 . ,(params rc
                                                           "sourcesuuid"))))
                          #:name "edit-song-external-sources")
            (redirect-to rc
                         (string->uri (format #f
                                       "~a/songs/uuid/~a?notify-title=~a"
                                       (current-myhost)
                                       (params rc "uuid")
                                       (uri-encode (G_
                                                    "Edited song succesfully!"))))
                         #:status 302)))

        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-edit-external-sources
                           #:unhappy-flow back-to-login)))

(post "/songs/uuid/:uuid/external-sources/new"
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
            ($song_external_sources 'set
                                    #:identifier new-uuid
                                    #:song_identifier (params rc "uuid")
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
                                       "~a/songs/uuid/~a?notify-title=~a"
                                       (current-myhost)
                                       (params rc "uuid")
                                       (uri-encode (G_
                                                    "Edited song succesfully!"))))
                         #:status 302)))

        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:song-create)
                           #:rc rc
                           #:happy-flow do-new-external-sources
                           #:unhappy-flow back-to-login)))
