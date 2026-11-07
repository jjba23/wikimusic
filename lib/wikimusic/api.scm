;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;;
;;; The handlers behind `/api/v1'.  The paths, the parameter decoding and the
;;; records are generated from `openapi/wikimusic.yaml' into
;;; `(wikimusic-api controllers)' and `(wikimusic-api models)'; this module is
;;; the other half.  It answers each operation from the same SQLite
;;; repositories the pages read and write, and it turns an Artanis request into
;;; the `<http-request>' the generated dispatcher understands.
;;;
;;; An Artanis route only calls `serve-api', which builds the repositories for
;;; that request and installs one handler per operation.  Reading is public;
;;; writing needs a bearer token (or the session cookie a browser already has)
;;; and the permission the specification names.  A row may be changed by its
;;; creator or by a holder of `wikimusic:modify-permissions', which is the same
;;; ownership rule the pages follow, so the API cannot become a way around it.

(define-module (wikimusic api)
  #:declarative? #t
  #:use-module (ice-9 receive)
  #:use-module (ice-9 format)
  #:use-module (ice-9 iconv)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:use-module (rnrs bytevectors)
  #:use-module (web request)
  #:use-module (web uri)
  #:use-module (artanis artanis)
  #:use-module (uuid generate)
  #:use-module (kracht prelude)
  #:use-module (bewaking bewaking)
  #:use-module ((wikimusic auth)
                #:select (authorized-payload verify-password hash-password
                                             permissions-from-column
                                             session-token-validity-seconds
                                             session-cookie-name))
  #:use-module ((wikimusic controller) #:select (may-mutate?))
  #:use-module (wikimusic env)
  #:use-module (wikimusic guitarpro)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain song)
  #:use-module (wikimusic domain artist)
  #:use-module (wikimusic domain genre)
  #:use-module (wikimusic domain song-content)
  #:use-module (wikimusic domain artwork)
  #:use-module (wikimusic domain comment)
  #:use-module (wikimusic domain opinion)
  #:use-module (wikimusic domain external-source)
  #:use-module (wikimusic domain article)
  #:use-module (wikimusic domain article-comment)
  #:use-module (wikimusic domain user)
  #:use-module (wikimusic sqlite song)
  #:use-module (wikimusic sqlite artist)
  #:use-module (wikimusic sqlite genre)
  #:use-module (wikimusic sqlite song-content)
  #:use-module (wikimusic sqlite artwork)
  #:use-module (wikimusic sqlite comment)
  #:use-module (wikimusic sqlite opinion)
  #:use-module (wikimusic sqlite external-source)
  #:use-module (wikimusic sqlite article)
  #:use-module (wikimusic sqlite article-comment)
  #:use-module (wikimusic sqlite user)
  #:use-module (wikimusic-api controllers)
  #:use-module (wikimusic-api json)
  #:use-module (wikimusic-api models)
  #:use-module ((wikimusic-api runtime) #:hide (uri-encode))
  #:export (serve-api emit-api-response protected-handler version-record
            external-source-record api-timestamp))

(define api-version "1.1.0")

(define (api-timestamp)
  "Return the current time as the epoch seconds text a page can read.

An API write records the same kind of timestamp the forms do.  Guile's SRFI 19
`current-time' is a time object, and a row written with one made every page
that showed its date fail to parse it."
  (number->string (current-time)))

;; The name an instance gives itself.  The pages read it from the same place
;; the rest of the site does; an instance that renames itself will pass it in.
(define instance-name "WikiMusic")

;;; ====== Reading a row ======

(define (column row key)
  "Return the value of KEY in ROW, or #f."
  (assq-ref row key))

(define (text value)
  "Return VALUE when it is a non-empty string, and #f otherwise.

An empty text column is absence here: the API leaves an absent optional member
out rather than sending an empty string a client would have to know to ignore."
  (and (string? value) (not (string-null? value)) value))

(define (integer value)
  "Return VALUE as an integer, and zero when it is not one.

SQLite gives the columns back as the driver read them; a count and a view are
numbers to every caller, so the conversion is made once, here."
  (cond
    [(integer? value) value]
    [(number? value) (inexact->exact value)]
    [(string? value) (or (string->number value) 0)]
    [else 0]))

(define (decoded-url value)
  "Return VALUE, a stored URL, as the URI a client sent.

The forms store a URI-encoded URL; the generated record validates the URI, so
the encoding is undone here before the record is built."
  (and (string? value) (uri-decode value)))

(define (non-empty-string? value)
  "Return #t when VALUE is a string with something besides whitespace in it."
  (and (string? value) (not (string-null? (string-trim-both value)))))

(define (by-identifier rows)
  "Return ROWS as an alist of identifier to row."
  (map (lambda (row) (cons (column row 'identifier) row)) rows))

(define (entity-column entity)
  "Return the symbol that names ENTITY's parent column, e.g. `song-identifier'."
  (string->symbol (format #f "~a-identifier" entity)))

(define (entity-table entity suffix)
  "Return the symbol of ENTITY's table for SUFFIX, e.g. `song_artworks'."
  (string->symbol (format #f "~a_~a" entity suffix)))

(define (artist-ref row)
  (make-artist-ref #:identifier (column row 'identifier)
                   #:display-name (column row 'display-name)))

(define (genre-ref row)
  (make-genre-ref #:identifier (column row 'identifier)
                  #:display-name (column row 'display-name)))

(define (refs-for song-id links link-key rows make-ref)
  "Return the records of the rows LINK names for SONG-ID."
  (filter-map (lambda (link)
                (and (equal? (column link 'song-identifier) song-id)
                  (let ((row (assoc-ref rows (column link link-key))))
                    (and row (make-ref row)))))
              links))

(define (song-relations song-repo artist-repo genre-repo ids)
  "Return the credits of the songs IDS, as four values.

The first two are the join-table rows, the last two the artists and genres they
name as alists of identifier to row, so a page of songs is four statements and
not two per song."
  (if (null? ids)
    (values '() '() '() '())
    (let* ((artist-links (get-song-artists-by-ids song-repo ids))
           (genre-links (get-song-genres-by-ids song-repo ids))
           (artist-ids (delete-duplicates
                        (map (lambda (link)
                               (column link 'artist-identifier))
                             artist-links)))
           (genre-ids (delete-duplicates
                       (map (lambda (link)
                              (column link 'genre-identifier))
                            genre-links))))
      (values artist-links genre-links
              (if (null? artist-ids)
                '()
                (by-identifier (get-artists-by-ids artist-repo artist-ids)))
              (if (null? genre-ids)
                '()
                (by-identifier (get-genres-by-ids genre-repo genre-ids)))))))

(define (song-summary row artist-links genre-links artists genres)
  (make-song-summary
   #:identifier (column row 'identifier)
   #:display-name (column row 'display-name)
   #:description (text (column row 'description))
   #:music-key (text (column row 'music-key))
   #:music-tuning (text (column row 'music-tuning))
   #:album-name (text (column row 'album-name))
   #:views (integer (column row 'views))
   #:artists (refs-for (column row 'identifier) artist-links
                       'artist-identifier artists artist-ref)
   #:genres (refs-for (column row 'identifier) genre-links
                      'genre-identifier genres genre-ref)
   #:created-at (text (column row 'created-at))))

(define (artist-summary row)
  (make-artist-summary
   #:identifier (column row 'identifier)
   #:display-name (column row 'display-name)
   #:description (text (column row 'description))
   #:views (integer (column row 'views))
   #:created-at (text (column row 'created-at))))

(define (genre-summary row)
  (make-genre-summary
   #:identifier (column row 'identifier)
   #:display-name (column row 'display-name)
   #:description (text (column row 'description))
   #:views (integer (column row 'views))
   #:created-at (text (column row 'created-at))))

(define (artwork-record row)
  (make-artwork
   #:identifier (column row 'identifier)
   #:content-url (uri-decode (column row 'content-url))
   #:content-caption (text (column row 'content-caption))
   #:order-value (integer (column row 'order-value))))

(define (version-record row)
  (make-song-version
   #:identifier (column row 'identifier)
   #:version-name (column row 'version-name)
   #:instrument-type (column row 'instrument-type)
   #:ascii-legend (text (column row 'ascii-legend))
   #:ascii-contents (text (column row 'ascii-contents))
   #:has-pdf (data-url-with-payload? (column row 'pdf-contents))
   #:has-tablature (data-url-with-payload? (column row 'guitarpro-contents))
   #:created-at (text (column row 'created-at))))

(define (comment-record row)
  (make-comment
   #:identifier (column row 'identifier)
   #:parent-identifier (text (column row 'parent-identifier))
   #:contents (column row 'contents)
   #:created-by (text (column row 'created-by))
   #:created-at (text (column row 'created-at))))

(define (external-source-record row)
  (make-external-source
   #:identifier (column row 'identifier)
   #:spotify-url (decoded-url (column row 'spotify-url))
   #:youtube-url (decoded-url (column row 'youtube-url))
   #:soundcloud-url (decoded-url (column row 'soundcloud-url))
   #:wikipedia-url (decoded-url (column row 'wikipedia-url))
   #:created-at (text (column row 'created-at))))

(define (article-summary-record row)
  (make-article-summary
   #:identifier (column row 'identifier)
   #:display-name (column row 'display-name)
   #:kind (column row 'kind)
   #:video-url (text (column row 'video-url))
   #:views (integer (column row 'views))
   #:created-at (text (column row 'created-at))))

(define (article-comment-record row)
  (make-article-comment
   #:identifier (column row 'identifier)
   #:parent-identifier (text (column row 'parent-identifier))
   #:author-name (text (column row 'author-name))
   #:created-by (text (column row 'created-by))
   #:contents (column row 'contents)
   #:created-at (text (column row 'created-at))))

(define (article-record row article-comment-repo)
  (make-article
   #:identifier (column row 'identifier)
   #:display-name (column row 'display-name)
   #:kind (column row 'kind)
   #:video-url (text (column row 'video-url))
   #:contents (column row 'contents)
   #:views (integer (column row 'views))
   #:comments (map article-comment-record
                   (get-article-comments article-comment-repo
                                         (list (column row 'identifier))))
   #:created-at (text (column row 'created-at))))

(define (permission-strings value)
  "Return VALUE, a permissions column or a list, as strings for the schema."
  (map (lambda (permission)
         (if (symbol? permission)
           (symbol->string permission)
           (format #f "~a" permission)))
       (permissions-from-column value)))

(define (user-record row)
  (make-user
   #:identifier (column row 'identifier)
   #:username (column row 'username)
   #:email (column row 'email)
   #:permissions (permission-strings (column row 'permissions))))

(define (opinion-counts opinion-repo entity id)
  "Return the number of likes and dislikes ENTITY ID has, as two values."
  (let ((rows (get-opinions-by-entity-ids opinion-repo entity (list id))))
    (values (length (filter (lambda (row)
                              (equal? 1 (column row 'is-like)))
                            rows))
            (length (filter (lambda (row)
                              (equal? 1 (column row 'is-dislike)))
                            rows)))))

(define (json-error status code message)
  "Return STATUS with the Error schema's `code' and `message'."
  (json-response status (list (cons "code" code) (cons "message" message))))

;;; ====== Request helpers ======

(define (header-name-string name)
  (if (string? name) name (symbol->string name)))

(define (header-text value)
  "Return VALUE, a header parsed by Artanis, as its text."
  (cond
    [(string? value) value]
    [(pair? value)
     (let ((parameters (cdr value)))
       (string-append
        (format #f "~a" (car value))
        (if (list? parameters)
          (apply string-append
                 (map (lambda (parameter)
                        (if (pair? parameter)
                          (format #f "; ~a=~a" (car parameter) (cdr parameter))
                          (format #f "; ~a" parameter)))
                      parameters))
          "")))]
    [else (format #f "~a" value)]))

(define (header-value rc name)
  "Return the header NAME of RC, or #f."
  (let ((headers (request-headers (rc-req rc))))
    (let ((entry (find (lambda (candidate)
                         (string-ci=? (header-name-string (car candidate)) name))
                       headers)))
      (and entry (header-text (cdr entry))))))

(define (bearer-token rc)
  "Return the token in RC's Authorization header, or #f."
  (let ((value (header-value rc "authorization")))
    (and value
      (>= (string-length value) 7)
      (string-ci=? (substring value 0 7) "bearer ")
      (let ((token (string-trim-both (substring value 7 (string-length value)))))
        (and (not (string-null? token)) token)))))

(define (cookie-token rc)
  "Return the token in RC's session cookie, or #f."
  (let ((value (:cookies-value rc session-cookie-name)))
    (and (string? value) (not (string-null? value)) value)))

(define (api-token rc)
  "Return the bearer token or session cookie token RC carries, or #f."
  (or (bearer-token rc) (cookie-token rc)))

(define (api-session rc)
  "Return the session payload RC carries, or #f."
  (authorized-payload #:token (api-token rc)))

(define (require-session rc needed)
  "Return the session and #f, or #f and the response that refuses RC.

A request with no valid token is a 401; one with a token that lacks a needed
permission is a 403, so a client can tell the two apart."
  (let ((session (api-session rc)))
    (cond
      [(not session)
       (values #f (json-error 401 "unauthenticated"
                              "A valid session token is required"))]
      [(not (has-needed-permissions?
             #:needed needed
             #:present (assoc-ref session 'owner-permissions)))
       (values #f (json-error 403 "forbidden"
                              "The session lacks a required permission"))]
      [else (values session #f)])))

(define (protected-handler session-thunk handler)
  "Return the handler the dispatcher calls for a protected operation.

The generated dispatcher calls every handler with the request and the path
arguments, while an operation that changes a row first needs the session the
request carries.  SESSION-THUNK returns that session and an error response;
HANDLER then receives the session and the arguments.  A one-argument closure
here answered every write with a 500."
  (lambda (request args)
    (receive (session error) (session-thunk)
      (if error error (handler session args)))))

(define (require-body args)
  "Return ARGS' decoded body and #f, or #f and a 400 response."
  (let ((body (assq-ref args 'body)))
    (if body
      (values body #f)
      (values #f (json-error 400 "invalid-request"
                             "A JSON request body is required")))))

(define (owner-denied session created-by)
  "Return the 403 response when SESSION may not change CREATED-BY's row."
  (and (not (may-mutate? #:session session #:created-by created-by))
    (json-error 403 "forbidden"
                "The session may not change a row it did not create")))

(define (text-attr key value)
  "Return an alist entry for KEY when VALUE is a string, and nothing otherwise."
  (if (string? value) (list (cons key (html-escape value))) '()))

(define (url-attr key value)
  "Return an encoded alist entry for KEY when VALUE is a string."
  (if (string? value) (list (cons key (uri-encode value))) '()))

(define (int-attr key value)
  "Return an alist entry for KEY when VALUE is an integer."
  (if (integer? value) (list (cons key value)) '()))

(define (stored-permissions permissions)
  "Return PERMISSIONS, a list of strings or symbols, as the column's text."
  (format #f "~s"
          (map (lambda (permission)
                 (if (symbol? permission)
                   permission
                   (string->symbol (format #f "~a" permission))))
               (or permissions '()))))

(define (set-session-cookie! rc token)
  (:cookies-set! rc 'x-bewaking-wikimusic "x-bewaking-wikimusic" token)
  (:cookies-setattr! rc 'x-bewaking-wikimusic
                     #:expires session-token-validity-seconds
                     #:path "/"
                     #:secure #t
                     #:http-only #t))

(define (clear-session-cookie! rc)
  (:cookies-set! rc 'x-bewaking-wikimusic "x-bewaking-wikimusic" "")
  (:cookies-setattr! rc 'x-bewaking-wikimusic
                     #:expires 1
                     #:path "/"
                     #:secure #t
                     #:http-only #t))

;;; ====== The operations ======

(define* (pagination args)
  "Return the LIMIT and OFFSET ARGS ask for, refusing what the spec refuses."
  (let ((limit (assq-ref args 'limit))
        (offset (assq-ref args 'offset)))
    (when (and limit (not (and (integer? limit) (<= 1 limit 100))))
      (throw 'api-bad-request "limit must be an integer from 1 to 100"))
    (when (and offset (not (and (integer? offset) (<= 0 offset))))
      (throw 'api-bad-request "offset must be a non-negative integer"))
    (values (or limit 20) (or offset 0))))

(define (slice items limit offset)
  "Return the page of ITEMS at OFFSET, LIMIT items long."
  (let* ((start (min offset (length items)))
         (end (min (+ start limit) (length items))))
    (take (drop items start) (- end start))))

(define (handlers-for rc)
  "Return the operation handlers of the request context RC, as an alist."
  (let* ((song-repo (make-sqlite-song-repository rc))
         (artist-repo (make-sqlite-artist-repository rc))
         (genre-repo (make-sqlite-genre-repository rc))
         (content-repo (make-sqlite-song-content-repository rc))
         (artwork-repo (make-sqlite-artwork-repository rc))
         (comment-repo (make-sqlite-comment-repository rc))
         (opinion-repo (make-sqlite-opinion-repository rc))
         (source-repo (make-sqlite-external-source-repository rc))
         (article-repo (make-sqlite-article-repository rc))
         (article-comment-repo (make-sqlite-article-comment-repository rc))
         (user-repo (make-sqlite-user-repository rc)))

    (define (answer handler)
      (lambda (request args) (handler args)))

    (define (protected needed handler)
      (protected-handler (lambda () (require-session rc needed)) handler))

    (define (row-by-id table columns id)
      (let ((rows (sql-rows rc
                            (sql-select table
                                        #:columns columns
                                        #:where (list (cons 'identifier id))
                                        #:limit 1)
                            #:name "api-row-by-id")))
        (and (pair? rows) (car rows))))

    (define (version-row song-id version-id)
      (let ((rows (get-song-contents-by-ids content-repo (list version-id))))
        (let ((row (and (pair? rows) (car rows))))
          (and row
            (equal? (column row 'song-identifier) song-id)
            row))))

    (define (artwork-row entity entity-id artwork-id)
      (let ((rows (sql-rows rc
                            (sql-select (entity-table entity "artworks")
                                        #:columns '(identifier created-by
                                                               content-url content-caption
                                                               order-value)
                                        #:where (list (cons 'identifier artwork-id)
                                                      (cons (entity-column entity)
                                                            entity-id))
                                        #:limit 1)
                            #:name "api-artwork-row")))
        (and (pair? rows) (car rows))))

    (define (source-row entity entity-id source-id)
      (let ((rows (sql-rows rc
                            (sql-select (entity-table entity "external_sources")
                                        #:columns '(identifier created-by
                                                               spotify-url youtube-url
                                                               soundcloud-url
                                                               wikipedia-url)
                                        #:where (list (cons 'identifier source-id)
                                                      (cons (entity-column entity)
                                                            entity-id))
                                        #:limit 1)
                            #:name "api-source-row")))
        (and (pair? rows) (car rows))))

    (define (relation-row table related-column song-id related-id)
      (let ((rows (sql-rows rc
                            (sql-select table
                                        #:columns '(identifier created-by)
                                        #:where (list (cons 'song-identifier song-id)
                                                      (cons related-column related-id))
                                        #:limit 1)
                            #:name "api-relation-row")))
        (and (pair? rows) (car rows))))

    ;; ====== Reading ======

    (define (list-songs args)
      (receive (limit offset) (pagination args)
               (let* ((search (text (assq-ref args 'search)))
                      (rows (if search
                              (search-songs song-repo search
                                            #:limit limit #:offset offset)
                              (get-songs song-repo #:limit limit #:offset offset)))
                      (total (count-songs song-repo #:search search)))
                 (receive (artist-links genre-links artists genres)
                          (song-relations song-repo artist-repo genre-repo
                                          (map (lambda (row) (column row 'identifier))
                                               rows))
                          (ok (song-list->jso
                               (make-song-list
                                #:items (map (lambda (row)
                                               (song-summary row artist-links genre-links
                                                             artists genres))
                                             rows)
                                #:total total
                                #:limit limit
                                #:offset offset)))))))

    (define (song-detail id)
      (let ((row (get-song-by-id song-repo id)))
        (if (not row)
          (json-error 404 "not-found" "No such song")
          (receive (artist-links genre-links artists genres)
                   (song-relations song-repo artist-repo genre-repo (list id))
                   (let ((summary (song-summary row artist-links genre-links
                                                artists genres)))
                     (receive (likes dislikes)
                              (opinion-counts opinion-repo 'song id)
                              (ok (song->jso
                                   (make-song
                                    #:identifier (song-summary-identifier summary)
                                    #:display-name (song-summary-display-name summary)
                                    #:description (song-summary-description summary)
                                    #:music-key (song-summary-music-key summary)
                                    #:music-tuning (song-summary-music-tuning summary)
                                    #:music-creation-date
                                    (text (column row 'music-creation-date))
                                    #:album-name (song-summary-album-name summary)
                                    #:album-info-link
                                    (text (column row 'album-info-link))
                                    #:views (song-summary-views summary)
                                    #:like-count likes
                                    #:dislike-count dislikes
                                    #:artists (song-summary-artists summary)
                                    #:genres (song-summary-genres summary)
                                    #:versions
                                    (map version-record
                                         (get-song-contents-by-song-ids
                                          content-repo (list id)))
                                    #:artworks
                                    (map artwork-record
                                         (get-artworks-by-entity-ids
                                          artwork-repo 'song (list id)))
                                    #:comments
                                    (map comment-record
                                         (get-comments-by-entity-ids
                                          comment-repo 'song (list id)))
                                    #:external-sources
                                    (map external-source-record
                                         (get-external-sources-by-entity-ids
                                          source-repo 'song (list id)))
                                    #:created-at
                                    (song-summary-created-at summary))))))))))

    (define (get-song args)
      (song-detail (assq-ref args 'song-id)))

    (define (list-song-versions args)
      (let ((id (assq-ref args 'song-id)))
        (if (not (get-song-by-id song-repo id))
          (json-error 404 "not-found" "No such song")
          (ok (list->vector
               (map song-version->jso
                    (map version-record
                         (get-song-contents-by-song-ids content-repo
                                                        (list id)))))))))

    (define (get-song-version args)
      (let ((row (version-row (assq-ref args 'song-id)
                              (assq-ref args 'version-id))))
        (if row
          (ok (song-version->jso (version-record row)))
          (json-error 404 "not-found" "No such version of that song"))))

    (define (list-artists args)
      (receive (limit offset) (pagination args)
               (let* ((search (text (assq-ref args 'search)))
                      (rows (if search
                              (search-artists artist-repo search
                                              #:limit limit #:offset offset)
                              (get-artists artist-repo #:limit limit #:offset offset)))
                      (total (count-artists artist-repo #:search search)))
                 (ok (artist-list->jso
                      (make-artist-list
                       #:items (map artist-summary rows)
                       #:total total
                       #:limit limit
                       #:offset offset))))))

    (define (artist-detail id)
      (let ((row (get-artist-by-id artist-repo id)))
        (if (not row)
          (json-error 404 "not-found" "No such artist")
          (let ((summary (artist-summary row)))
            (receive (likes dislikes)
                     (opinion-counts opinion-repo 'artist id)
                     (ok (artist->jso
                          (make-artist
                           #:identifier (artist-summary-identifier summary)
                           #:display-name (artist-summary-display-name summary)
                           #:description (artist-summary-description summary)
                           #:views (artist-summary-views summary)
                           #:like-count likes
                           #:dislike-count dislikes
                           #:artworks
                           (map artwork-record
                                (get-artworks-by-entity-ids
                                 artwork-repo 'artist (list id)))
                           #:comments
                           (map comment-record
                                (get-comments-by-entity-ids
                                 comment-repo 'artist (list id)))
                           #:external-sources
                           (map external-source-record
                                (get-external-sources-by-entity-ids
                                 source-repo 'artist (list id)))
                           #:created-at
                           (artist-summary-created-at summary)))))))))

    (define (get-artist args)
      (artist-detail (assq-ref args 'artist-id)))

    (define (list-artist-songs args)
      (let ((id (assq-ref args 'artist-id)))
        (if (not (get-artist-by-id artist-repo id))
          (json-error 404 "not-found" "No such artist")
          (receive (limit offset) (pagination args)
                   (let* ((rows (get-songs-by-artist-id song-repo id))
                          (total (length rows)))
                     (receive (artist-links genre-links artists genres)
                              (song-relations song-repo artist-repo genre-repo
                                              (map (lambda (row)
                                                     (column row 'identifier))
                                                   rows))
                              (ok (song-list->jso
                                   (make-song-list
                                    #:items (map (lambda (row)
                                                   (song-summary row artist-links
                                                                 genre-links artists
                                                                 genres))
                                                 (slice rows limit offset))
                                    #:total total
                                    #:limit limit
                                    #:offset offset)))))))))

    (define (list-genres args)
      (receive (limit offset) (pagination args)
               (let* ((search (text (assq-ref args 'search)))
                      (rows (if search
                              (search-genres genre-repo search
                                             #:limit limit #:offset offset)
                              (get-genres genre-repo #:limit limit #:offset offset)))
                      (total (count-genres genre-repo #:search search)))
                 (ok (genre-list->jso
                      (make-genre-list
                       #:items (map genre-summary rows)
                       #:total total
                       #:limit limit
                       #:offset offset))))))

    (define (genre-detail id)
      (let ((row (get-genre-by-id genre-repo id)))
        (if (not row)
          (json-error 404 "not-found" "No such genre")
          (let ((summary (genre-summary row)))
            (receive (likes dislikes)
                     (opinion-counts opinion-repo 'genre id)
                     (ok (genre->jso
                          (make-genre
                           #:identifier (genre-summary-identifier summary)
                           #:display-name (genre-summary-display-name summary)
                           #:description (genre-summary-description summary)
                           #:views (genre-summary-views summary)
                           #:like-count likes
                           #:dislike-count dislikes
                           #:artworks
                           (map artwork-record
                                (get-artworks-by-entity-ids
                                 artwork-repo 'genre (list id)))
                           #:comments
                           (map comment-record
                                (get-comments-by-entity-ids
                                 comment-repo 'genre (list id)))
                           #:external-sources
                           (map external-source-record
                                (get-external-sources-by-entity-ids
                                 source-repo 'genre (list id)))
                           #:created-at
                           (genre-summary-created-at summary)))))))))

    (define (get-genre args)
      (genre-detail (assq-ref args 'genre-id)))

    (define (list-genre-songs args)
      (let ((id (assq-ref args 'genre-id)))
        (if (not (get-genre-by-id genre-repo id))
          (json-error 404 "not-found" "No such genre")
          (receive (limit offset) (pagination args)
                   (let* ((rows (get-songs-by-genre-id song-repo id))
                          (total (length rows)))
                     (receive (artist-links genre-links artists genres)
                              (song-relations song-repo artist-repo genre-repo
                                              (map (lambda (row)
                                                     (column row 'identifier))
                                                   rows))
                              (ok (song-list->jso
                                   (make-song-list
                                    #:items (map (lambda (row)
                                                   (song-summary row artist-links
                                                                 genre-links artists
                                                                 genres))
                                                 (slice rows limit offset))
                                    #:total total
                                    #:limit limit
                                    #:offset offset)))))))))

    (define (comments-response entity id)
      (ok (list->vector
           (map comment->jso
                (map comment-record
                     (get-comments-by-entity-ids
                      comment-repo entity (list id)))))))

    (define (list-song-comments args)
      (let ((id (assq-ref args 'song-id)))
        (if (get-song-by-id song-repo id)
          (comments-response 'song id)
          (json-error 404 "not-found" "No such song"))))

    (define (list-artist-comments args)
      (let ((id (assq-ref args 'artist-id)))
        (if (get-artist-by-id artist-repo id)
          (comments-response 'artist id)
          (json-error 404 "not-found" "No such artist"))))

    (define (list-genre-comments args)
      (let ((id (assq-ref args 'genre-id)))
        (if (get-genre-by-id genre-repo id)
          (comments-response 'genre id)
          (json-error 404 "not-found" "No such genre"))))

    (define (external-sources-response entity id)
      (ok (list->vector
           (map external-source->jso
                (map external-source-record
                     (get-external-sources-by-entity-ids
                      source-repo entity (list id)))))))

    (define (list-song-external-sources args)
      (let ((id (assq-ref args 'song-id)))
        (if (get-song-by-id song-repo id)
          (external-sources-response 'song id)
          (json-error 404 "not-found" "No such song"))))

    (define (list-artist-external-sources args)
      (let ((id (assq-ref args 'artist-id)))
        (if (get-artist-by-id artist-repo id)
          (external-sources-response 'artist id)
          (json-error 404 "not-found" "No such artist"))))

    (define (list-genre-external-sources args)
      (let ((id (assq-ref args 'genre-id)))
        (if (get-genre-by-id genre-repo id)
          (external-sources-response 'genre id)
          (json-error 404 "not-found" "No such genre"))))

    (define (list-articles args)
      (receive (limit offset) (pagination args)
               (let ((rows (get-articles article-repo
                                         #:limit limit #:offset offset)))
                 (ok (article-list->jso
                      (make-article-list
                       #:items (map article-summary-record rows)
                       #:total (count-articles article-repo)
                       #:limit limit
                       #:offset offset))))))

    (define (article-detail id)
      (let ((row (get-article-by-id article-repo id)))
        (if row
          (ok (article->jso (article-record row article-comment-repo)))
          (json-error 404 "not-found" "No such article"))))

    (define (get-article args)
      (article-detail (assq-ref args 'article-id)))

    (define (list-article-comments args)
      (let ((id (assq-ref args 'article-id)))
        (if (not (get-article-by-id article-repo id))
          (json-error 404 "not-found" "No such article")
          (ok (list->vector
               (map article-comment->jso
                    (map article-comment-record
                         (get-article-comments article-comment-repo
                                               (list id)))))))))

    (define (get-me session args)
      (let ((row (get-user-by-id user-repo (assoc-ref session 'owner-id))))
        (if row
          (ok (user->jso (user-record row)))
          (json-error 401 "unauthenticated" "The session's user no longer exists"))))

    (define (list-users session args)
      (receive (limit offset) (pagination args)
               (let ((rows (get-users user-repo)))
                 (ok (user-list->jso
                      (make-user-list
                       #:items (map user-record (slice rows limit offset))
                       #:total (length rows)
                       #:limit limit
                       #:offset offset))))))

    (define (get-instance args)
      (ok (instance->jso
           (make-instance
            #:name instance-name
            #:version api-version
            #:counts (make-instance-counts
                      #:songs (count-songs song-repo)
                      #:artists (count-artists artist-repo)
                      #:genres (count-genres genre-repo)
                      #:articles (count-articles article-repo))))))

    ;; ====== Writing: songs, artists and genres ======

    (define (insert-relation table related-column song-id related-id owner)
      (sql-execute! rc
                    (sql-insert table
                                (list (cons 'identifier
                                            (generate-string-uuid))
                                      (cons 'song-identifier song-id)
                                      (cons related-column related-id)
                                      (cons 'created-by owner)
                                      (cons 'created-at (api-timestamp))))
                    #:name "api-insert-relation"))

    (define (delete-relation table related-column song-id related-id)
      (sql-execute! rc
                    (sql-delete table
                                #:where (list (cons 'song-identifier song-id)
                                              (cons related-column related-id)))
                    #:name "api-delete-relation"))

    (define (create-song session args)
      (receive (body error) (require-body args)
               (if error error
                 (let ((name (song-input-display-name body)))
                   (if (not (non-empty-string? name))
                     (json-error 400 "invalid-request" "displayName is required")
                     (let ((id (generate-string-uuid))
                           (owner (assoc-ref session 'owner-id)))
                       (insert-song song-repo
                                    (append
                                     (list (cons 'identifier id)
                                           (cons 'display-name (html-escape name))
                                           (cons 'created-by owner)
                                           (cons 'visibility-status 0)
                                           (cons 'views 0)
                                           (cons 'created-at (api-timestamp)))
                                     (text-attr 'description
                                                (song-input-description body))
                                     (text-attr 'music-key
                                                (song-input-music-key body))
                                     (text-attr 'music-tuning
                                                (song-input-music-tuning body))
                                     (text-attr 'music-creation-date
                                                (song-input-music-creation-date body))
                                     (text-attr 'album-name
                                                (song-input-album-name body))
                                     (url-attr 'album-info-link
                                               (song-input-album-info-link body))))
                       (for-each (lambda (artist-id)
                                   (when (and (string? artist-id)
                                           (get-artist-by-id artist-repo artist-id))
                                     (insert-relation 'song_artists
                                                      'artist-identifier
                                                      id artist-id owner)))
                                 (or (song-input-artist-ids body) '()))
                       (for-each (lambda (genre-id)
                                   (when (and (string? genre-id)
                                           (get-genre-by-id genre-repo genre-id))
                                     (insert-relation 'song_genres
                                                      'genre-identifier
                                                      id genre-id owner)))
                                 (or (song-input-genre-ids body) '()))
                       (song-detail id)))))))

    (define (update-song session args)
      (let ((id (assq-ref args 'song-id)))
        (let ((row (get-song-by-id song-repo id)))
          (cond
            [(not row)
             (json-error 404 "not-found" "No such song")]
            [(owner-denied session (column row 'created-by))]
            [else
              (receive (body error) (require-body args)
                       (if error error
                         (let ((name (song-patch-display-name body)))
                           (if (and (string? name) (not (non-empty-string? name)))
                             (json-error 400 "invalid-request"
                                         "displayName may not be empty")
                             (let ((attrs
                                    (append
                                     (text-attr 'display-name name)
                                     (text-attr 'description
                                                (song-patch-description body))
                                     (text-attr 'music-key
                                                (song-patch-music-key body))
                                     (text-attr 'music-tuning
                                                (song-patch-music-tuning body))
                                     (text-attr 'music-creation-date
                                                (song-patch-music-creation-date body))
                                     (text-attr 'album-name
                                                (song-patch-album-name body))
                                     (url-attr 'album-info-link
                                               (song-patch-album-info-link body)))))
                               (when (pair? attrs)
                                 (update-song-by-id song-repo id
                                                    (append attrs
                                                            (list (cons 'last-edited-at
                                                                        (api-timestamp))))))
                               (song-detail id))))))]))))

    (define (delete-song session args)
      (let ((id (assq-ref args 'song-id)))
        (let ((row (get-song-by-id song-repo id)))
          (cond
            [(not row) (json-error 404 "not-found" "No such song")]
            [(owner-denied session (column row 'created-by))]
            [else
              (delete-song-by-id song-repo id)
              (no-content)]))))

    (define (create-artist session args)
      (receive (body error) (require-body args)
               (if error error
                 (let ((name (artist-input-display-name body)))
                   (if (not (non-empty-string? name))
                     (json-error 400 "invalid-request" "displayName is required")
                     (let ((id (generate-string-uuid)))
                       (insert-artist artist-repo
                                      (append
                                       (list (cons 'identifier id)
                                             (cons 'display-name (html-escape name))
                                             (cons 'created-by
                                                   (assoc-ref session 'owner-id))
                                             (cons 'visibility-status 0)
                                             (cons 'views 0)
                                             (cons 'created-at (api-timestamp)))
                                       (text-attr 'description
                                                  (artist-input-description body))))
                       (artist-detail id)))))))

    (define (update-artist session args)
      (let ((id (assq-ref args 'artist-id)))
        (let ((row (get-artist-by-id artist-repo id)))
          (cond
            [(not row) (json-error 404 "not-found" "No such artist")]
            [(owner-denied session (column row 'created-by))]
            [else
              (receive (body error) (require-body args)
                       (if error error
                         (let ((name (artist-patch-display-name body)))
                           (if (and (string? name) (not (non-empty-string? name)))
                             (json-error 400 "invalid-request"
                                         "displayName may not be empty")
                             (let ((attrs
                                    (append
                                     (text-attr 'display-name name)
                                     (text-attr 'description
                                                (artist-patch-description body)))))
                               (when (pair? attrs)
                                 (update-artist-by-id artist-repo id
                                                      (append attrs
                                                              (list (cons 'last-edited-at
                                                                          (api-timestamp))))))
                               (artist-detail id))))))]))))

    (define (delete-artist session args)
      (let ((id (assq-ref args 'artist-id)))
        (let ((row (get-artist-by-id artist-repo id)))
          (cond
            [(not row) (json-error 404 "not-found" "No such artist")]
            [(owner-denied session (column row 'created-by))]
            [else
              (delete-artist-by-id artist-repo id)
              (no-content)]))))

    (define (create-genre session args)
      (receive (body error) (require-body args)
               (if error error
                 (let ((name (genre-input-display-name body)))
                   (if (not (non-empty-string? name))
                     (json-error 400 "invalid-request" "displayName is required")
                     (let ((id (generate-string-uuid)))
                       (insert-genre genre-repo
                                     (append
                                      (list (cons 'identifier id)
                                            (cons 'display-name (html-escape name))
                                            (cons 'created-by
                                                  (assoc-ref session 'owner-id))
                                            (cons 'visibility-status 0)
                                            (cons 'views 0)
                                            (cons 'created-at (api-timestamp)))
                                      (text-attr 'description
                                                 (genre-input-description body))))
                       (genre-detail id)))))))

    (define (update-genre session args)
      (let ((id (assq-ref args 'genre-id)))
        (let ((row (get-genre-by-id genre-repo id)))
          (cond
            [(not row) (json-error 404 "not-found" "No such genre")]
            [(owner-denied session (column row 'created-by))]
            [else
              (receive (body error) (require-body args)
                       (if error error
                         (let ((name (genre-patch-display-name body)))
                           (if (and (string? name) (not (non-empty-string? name)))
                             (json-error 400 "invalid-request"
                                         "displayName may not be empty")
                             (let ((attrs
                                    (append
                                     (text-attr 'display-name name)
                                     (text-attr 'description
                                                (genre-patch-description body)))))
                               (when (pair? attrs)
                                 (update-genre-by-id genre-repo id
                                                     (append attrs
                                                             (list (cons 'last-edited-at
                                                                         (api-timestamp))))))
                               (genre-detail id))))))]))))

    (define (delete-genre session args)
      (let ((id (assq-ref args 'genre-id)))
        (let ((row (get-genre-by-id genre-repo id)))
          (cond
            [(not row) (json-error 404 "not-found" "No such genre")]
            [(owner-denied session (column row 'created-by))]
            [else
              (delete-genre-by-id genre-repo id)
              (no-content)]))))

    ;; ====== Writing: tablature versions ======

    (define (create-song-version session args)
      (let ((song-id (assq-ref args 'song-id)))
        (if (not (get-song-by-id song-repo song-id))
          (json-error 404 "not-found" "No such song")
          (receive (body error) (require-body args)
                   (if error error
                     (let ((version-name (song-version-input-version-name body))
                           (instrument-type
                            (song-version-input-instrument-type body)))
                       (if (not (and (non-empty-string? version-name)
                                  (non-empty-string? instrument-type)))
                         (json-error 400 "invalid-request"
                                     "versionName and instrumentType are required")
                         (let ((id (generate-string-uuid)))
                           (insert-song-content
                            content-repo
                            (append
                             (list (cons 'identifier id)
                                   (cons 'song-identifier song-id)
                                   (cons 'created-by
                                         (assoc-ref session 'owner-id))
                                   (cons 'visibility-status 0)
                                   (cons 'version-name (html-escape version-name))
                                   (cons 'instrument-type
                                         (html-escape instrument-type))
                                   (cons 'created-at (api-timestamp)))
                             (text-attr 'ascii-legend
                                        (song-version-input-ascii-legend body))
                             (text-attr 'ascii-contents
                                        (song-version-input-ascii-contents body))
                             (if (string? (song-version-input-pdf-contents body))
                               (list (cons 'pdf-contents
                                           (song-version-input-pdf-contents body)))
                               '())
                             (if (string? (song-version-input-tablature-contents body))
                               (list (cons 'guitarpro-contents
                                           (song-version-input-tablature-contents body)))
                               '())))
                           (let ((row (version-row song-id id)))
                             (if row
                               (created (song-version->jso (version-record row)))
                               (json-error 500 "internal-error"
                                           "The version could not be read back")))))))))))

    (define (song-version-patch-attrs body)
      (append
       (text-attr 'version-name
                  (song-version-patch-version-name body))
       (text-attr 'instrument-type
                  (song-version-patch-instrument-type body))
       (text-attr 'ascii-legend
                  (song-version-patch-ascii-legend body))
       (text-attr 'ascii-contents
                  (song-version-patch-ascii-contents body))
       (if (string? (song-version-patch-pdf-contents body))
         (list (cons 'pdf-contents
                     (song-version-patch-pdf-contents body)))
         '())
       (if (string? (song-version-patch-tablature-contents body))
         (list (cons 'guitarpro-contents
                     (song-version-patch-tablature-contents body)))
         '())))

    (define (update-song-version session args)
      (let* ((song-id (assq-ref args 'song-id))
             (version-id (assq-ref args 'version-id))
             (row (version-row song-id version-id)))
        (cond
          [(not row)
           (json-error 404 "not-found" "No such version of that song")]
          [(owner-denied session (column row 'created-by))]
          [else
            (receive (body error) (require-body args)
                     (if error
                       error
                       (let ((attrs (song-version-patch-attrs body)))
                         (when (pair? attrs)
                           (update-song-content-by-id
                            content-repo version-id
                            (append attrs
                                    (list (cons 'last-edited-at (api-timestamp))))))
                         (let ((updated (version-row song-id version-id)))
                           (if updated
                             (ok (song-version->jso (version-record updated)))
                             (json-error 500 "internal-error"
                                         "The version could not be read back"))))))])))

    (define (delete-song-version session args)
      (let* ((song-id (assq-ref args 'song-id))
             (version-id (assq-ref args 'version-id))
             (row (version-row song-id version-id)))
        (cond
          [(not row)
           (json-error 404 "not-found" "No such version of that song")]
          [(owner-denied session (column row 'created-by))]
          [else
            (delete-song-content-by-id content-repo version-id)
            (no-content)])))

    ;; ====== Writing: comments ======

    (define (create-comment entity entity-id owner args)
      (receive (body error) (require-body args)
               (if error error
                 (let ((contents (comment-input-contents body)))
                   (if (not (non-empty-string? contents))
                     (json-error 400 "invalid-request" "contents is required")
                     (let ((id (generate-string-uuid))
                           (parent (comment-input-parent-identifier body)))
                       (insert-comment
                        comment-repo entity
                        (append
                         (list (cons 'identifier id)
                               (cons (entity-column entity) entity-id)
                               (cons 'created-by owner)
                               (cons 'visibility-status 0)
                               (cons 'contents (html-escape contents))
                               (cons 'created-at (api-timestamp)))
                         (if (non-empty-string? parent)
                           (list (cons 'parent-identifier (html-escape parent)))
                           '())))
                       (let ((row (get-comment-by-id comment-repo entity id)))
                         (if row
                           (created (comment->jso (comment-record row)))
                           (json-error 500 "internal-error"
                                       "The comment could not be read back")))))))))

    (define (update-comment entity entity-id session args)
      (let ((comment-id (assq-ref args 'comment-id)))
        (let ((row (get-comment-by-id comment-repo entity comment-id)))
          (cond
            [(or (not row)
               (not (equal? (column row (entity-column entity)) entity-id)))
             (json-error 404 "not-found" "No such comment")]
            [(owner-denied session (column row 'created-by))]
            [else
              (receive (body error) (require-body args)
                       (if error error
                         (let ((contents (comment-patch-contents body)))
                           (if (not (non-empty-string? contents))
                             (json-error 400 "invalid-request"
                                         "contents may not be empty")
                             (begin
                               (update-comment-by-id
                                comment-repo entity comment-id
                                (list (cons 'contents (html-escape contents))
                                      (cons 'last-edited-at (api-timestamp))))
                               (ok (comment->jso
                                    (comment-record
                                     (get-comment-by-id comment-repo entity
                                                        comment-id)))))))))]))))

    (define (delete-comment entity entity-id session args)
      (let ((comment-id (assq-ref args 'comment-id)))
        (let ((row (get-comment-by-id comment-repo entity comment-id)))
          (cond
            [(or (not row)
               (not (equal? (column row (entity-column entity)) entity-id)))
             (json-error 404 "not-found" "No such comment")]
            [(owner-denied session (column row 'created-by))]
            [else
              (delete-comment-by-id comment-repo entity comment-id)
              (no-content)]))))

    (define (create-song-comment session args)
      (let ((id (assq-ref args 'song-id)))
        (if (get-song-by-id song-repo id)
          (create-comment 'song id (assoc-ref session 'owner-id) args)
          (json-error 404 "not-found" "No such song"))))

    (define (create-artist-comment session args)
      (let ((id (assq-ref args 'artist-id)))
        (if (get-artist-by-id artist-repo id)
          (create-comment 'artist id (assoc-ref session 'owner-id) args)
          (json-error 404 "not-found" "No such artist"))))

    (define (create-genre-comment session args)
      (let ((id (assq-ref args 'genre-id)))
        (if (get-genre-by-id genre-repo id)
          (create-comment 'genre id (assoc-ref session 'owner-id) args)
          (json-error 404 "not-found" "No such genre"))))

    (define (update-song-comment session args)
      (update-comment 'song (assq-ref args 'song-id) session args))

    (define (update-artist-comment session args)
      (update-comment 'artist (assq-ref args 'artist-id) session args))

    (define (update-genre-comment session args)
      (update-comment 'genre (assq-ref args 'genre-id) session args))

    (define (delete-song-comment session args)
      (delete-comment 'song (assq-ref args 'song-id) session args))

    (define (delete-artist-comment session args)
      (delete-comment 'artist (assq-ref args 'artist-id) session args))

    (define (delete-genre-comment session args)
      (delete-comment 'genre (assq-ref args 'genre-id) session args))

    ;; ====== Writing: artwork ======

    (define (create-artwork entity entity-exists? entity-id session args)
      (if (not (entity-exists? entity-id))
        (json-error 404 "not-found" (format #f "No such ~a" entity))
        (receive (body error) (require-body args)
                 (if error error
                   (let ((id (generate-string-uuid)))
                     (insert-artwork
                      artwork-repo entity
                      (append
                       (list (cons 'identifier id)
                             (cons (entity-column entity) entity-id)
                             (cons 'created-by (assoc-ref session 'owner-id))
                             (cons 'visibility-status 0)
                             (cons 'content-url
                                   (uri-encode (artwork-input-content-url body)))
                             (cons 'order-value
                                   (or (artwork-input-order-value body) 0))
                             (cons 'created-at (api-timestamp)))
                       (text-attr 'content-caption
                                  (artwork-input-content-caption body))))
                     (let ((row (artwork-row entity entity-id id)))
                       (if row
                         (created (artwork->jso (artwork-record row)))
                         (json-error 500 "internal-error"
                                     "The artwork could not be read back"))))))))

    (define (artwork-patch-attrs body)
      (append
       (url-attr 'content-url (artwork-patch-content-url body))
       (text-attr 'content-caption (artwork-patch-content-caption body))
       (int-attr 'order-value (artwork-patch-order-value body))))

    (define (update-artwork entity entity-id session args)
      (let ((artwork-id (assq-ref args 'artwork-id)))
        (let ((row (artwork-row entity entity-id artwork-id)))
          (cond
            [(not row) (json-error 404 "not-found" "No such artwork")]
            [(owner-denied session (column row 'created-by))]
            [else
              (receive (body error) (require-body args)
                       (if error
                         error
                         (let ((attrs (artwork-patch-attrs body)))
                           (when (pair? attrs)
                             (sql-execute! rc
                                           (sql-update
                                            (entity-table entity "artworks")
                                            (append attrs
                                                    (list (cons 'last-edited-at
                                                                (api-timestamp))))
                                            #:where (list (cons 'identifier artwork-id)
                                                          (cons (entity-column entity)
                                                                entity-id)))
                                           #:name "api-update-artwork"))
                           (let ((updated (artwork-row entity entity-id artwork-id)))
                             (if updated
                               (ok (artwork->jso (artwork-record updated)))
                               (json-error 500 "internal-error"
                                           "The artwork could not be read back"))))))]))))

    (define (delete-artwork entity entity-id session args)
      (let ((artwork-id (assq-ref args 'artwork-id)))
        (let ((row (artwork-row entity entity-id artwork-id)))
          (cond
            [(not row) (json-error 404 "not-found" "No such artwork")]
            [(owner-denied session (column row 'created-by))]
            [else
              (delete-artwork-by-id artwork-repo entity artwork-id)
              (no-content)]))))

    (define (create-song-artwork session args)
      (create-artwork 'song
                      (lambda (id) (get-song-by-id song-repo id))
                      (assq-ref args 'song-id) session args))

    (define (create-artist-artwork session args)
      (create-artwork 'artist
                      (lambda (id) (get-artist-by-id artist-repo id))
                      (assq-ref args 'artist-id) session args))

    (define (create-genre-artwork session args)
      (create-artwork 'genre
                      (lambda (id) (get-genre-by-id genre-repo id))
                      (assq-ref args 'genre-id) session args))

    (define (update-song-artwork session args)
      (update-artwork 'song (assq-ref args 'song-id) session args))

    (define (update-artist-artwork session args)
      (update-artwork 'artist (assq-ref args 'artist-id) session args))

    (define (update-genre-artwork session args)
      (update-artwork 'genre (assq-ref args 'genre-id) session args))

    (define (delete-song-artwork session args)
      (delete-artwork 'song (assq-ref args 'song-id) session args))

    (define (delete-artist-artwork session args)
      (delete-artwork 'artist (assq-ref args 'artist-id) session args))

    (define (delete-genre-artwork session args)
      (delete-artwork 'genre (assq-ref args 'genre-id) session args))

    ;; ====== Writing: relations ======

    ;; The two relation creators differ only in the table, the column and the
    ;; record the identifier names, so each one is written out rather than
    ;; making a generic helper know how to call a repository that is not there.
    (define (add-song-artist session args)
      (let ((song-id (assq-ref args 'song-id)))
        (receive (body error) (require-body args)
                 (if error error
                   (let ((artist-id (artist-relation-input-artist-id body)))
                     (cond
                       [(not (get-song-by-id song-repo song-id))
                        (json-error 404 "not-found" "No such song")]
                       [(not (get-artist-by-id artist-repo artist-id))
                        (json-error 404 "not-found" "No such artist")]
                       [else
                         (unless (relation-row 'song_artists 'artist-identifier
                                               song-id artist-id)
                           (insert-relation 'song_artists 'artist-identifier
                                            song-id artist-id
                                            (assoc-ref session 'owner-id)))
                         (no-content)]))))))

    (define (add-song-genre session args)
      (let ((song-id (assq-ref args 'song-id)))
        (receive (body error) (require-body args)
                 (if error error
                   (let ((genre-id (genre-relation-input-genre-id body)))
                     (cond
                       [(not (get-song-by-id song-repo song-id))
                        (json-error 404 "not-found" "No such song")]
                       [(not (get-genre-by-id genre-repo genre-id))
                        (json-error 404 "not-found" "No such genre")]
                       [else
                         (unless (relation-row 'song_genres 'genre-identifier
                                               song-id genre-id)
                           (insert-relation 'song_genres 'genre-identifier
                                            song-id genre-id
                                            (assoc-ref session 'owner-id)))
                         (no-content)]))))))

    (define (remove-relation table related-column session args related-id-key)
      (let ((song-id (assq-ref args 'song-id))
            (related-id (assq-ref args related-id-key)))
        (let ((row (relation-row table related-column song-id related-id)))
          (cond
            [(not row) (json-error 404 "not-found" "No such credit")]
            [(owner-denied session (column row 'created-by))]
            [else
              (delete-relation table related-column song-id related-id)
              (no-content)]))))

    (define (remove-song-artist session args)
      (remove-relation 'song_artists 'artist-identifier
                       session args 'artist-id))

    (define (remove-song-genre session args)
      (remove-relation 'song_genres 'genre-identifier
                       session args 'genre-id))

    ;; ====== Writing: external sources ======

    (define (create-source entity entity-exists? entity-id session args)
      (if (not (entity-exists? entity-id))
        (json-error 404 "not-found" (format #f "No such ~a" entity))
        (receive (body error) (require-body args)
                 (if error error
                   (let ((id (generate-string-uuid)))
                     (insert-external-source
                      source-repo entity
                      (append
                       (list (cons 'identifier id)
                             (cons (entity-column entity) entity-id)
                             (cons 'created-by (assoc-ref session 'owner-id))
                             (cons 'created-at (api-timestamp)))
                       (url-attr 'spotify-url
                                 (external-source-input-spotify-url body))
                       (url-attr 'youtube-url
                                 (external-source-input-youtube-url body))
                       (url-attr 'soundcloud-url
                                 (external-source-input-soundcloud-url body))
                       (url-attr 'wikipedia-url
                                 (external-source-input-wikipedia-url body))))
                     (let ((row (source-row entity entity-id id)))
                       (if row
                         (created (external-source->jso
                                   (external-source-record row)))
                         (json-error 500 "internal-error"
                                     "The source could not be read back"))))))))

    (define (source-patch-attrs body)
      (append
       (url-attr 'spotify-url (external-source-patch-spotify-url body))
       (url-attr 'youtube-url (external-source-patch-youtube-url body))
       (url-attr 'soundcloud-url (external-source-patch-soundcloud-url body))
       (url-attr 'wikipedia-url (external-source-patch-wikipedia-url body))))

    (define (update-source entity entity-id session args)
      (let ((source-id (assq-ref args 'source-id)))
        (let ((row (source-row entity entity-id source-id)))
          (cond
            [(not row) (json-error 404 "not-found" "No such source")]
            [(owner-denied session (column row 'created-by))]
            [else
              (receive (body error) (require-body args)
                       (if error
                         error
                         (let ((attrs (source-patch-attrs body)))
                           (when (pair? attrs)
                             (sql-execute! rc
                                           (sql-update
                                            (entity-table entity "external_sources")
                                            (append attrs
                                                    (list (cons 'last-edited-at
                                                                (api-timestamp))))
                                            #:where (list (cons 'identifier source-id)
                                                          (cons (entity-column entity)
                                                                entity-id)))
                                           #:name "api-update-source"))
                           (let ((updated (source-row entity entity-id source-id)))
                             (if updated
                               (ok (external-source->jso
                                    (external-source-record updated)))
                               (json-error 500 "internal-error"
                                           "The source could not be read back"))))))]))))

    (define (create-song-external-source session args)
      (create-source 'song
                     (lambda (id) (get-song-by-id song-repo id))
                     (assq-ref args 'song-id) session args))

    (define (create-artist-external-source session args)
      (create-source 'artist
                     (lambda (id) (get-artist-by-id artist-repo id))
                     (assq-ref args 'artist-id) session args))

    (define (create-genre-external-source session args)
      (create-source 'genre
                     (lambda (id) (get-genre-by-id genre-repo id))
                     (assq-ref args 'genre-id) session args))

    (define (update-song-external-source session args)
      (update-source 'song (assq-ref args 'song-id) session args))

    (define (update-artist-external-source session args)
      (update-source 'artist (assq-ref args 'artist-id) session args))

    (define (update-genre-external-source session args)
      (update-source 'genre (assq-ref args 'genre-id) session args))

    ;; ====== Writing: opinions ======

    (define (set-opinion entity entity-exists? entity-id session args is-like
                         is-dislike)
      (if (not (entity-exists? entity-id))
        (json-error 404 "not-found" (format #f "No such ~a" entity))
        (let ((owner (assoc-ref session 'owner-id)))
          (for-each (lambda (row)
                      (delete-opinion-by-id opinion-repo entity
                                            (column row 'identifier)))
                    (filter (lambda (row)
                              (equal? owner (column row 'created-by)))
                            (get-opinions-by-entity-ids
                             opinion-repo entity (list entity-id))))
          (insert-opinion
           opinion-repo entity
           (list (cons 'identifier (generate-string-uuid))
                 (cons (entity-column entity) entity-id)
                 (cons 'created-by owner)
                 (cons 'is-like is-like)
                 (cons 'is-dislike is-dislike)
                 (cons 'created-at (api-timestamp))))
          (no-content))))

    (define (like-song session args)
      (set-opinion 'song
                   (lambda (id) (get-song-by-id song-repo id))
                   (assq-ref args 'song-id) session args 1 0))

    (define (dislike-song session args)
      (set-opinion 'song
                   (lambda (id) (get-song-by-id song-repo id))
                   (assq-ref args 'song-id) session args 0 1))

    (define (like-artist session args)
      (set-opinion 'artist
                   (lambda (id) (get-artist-by-id artist-repo id))
                   (assq-ref args 'artist-id) session args 1 0))

    (define (dislike-artist session args)
      (set-opinion 'artist
                   (lambda (id) (get-artist-by-id artist-repo id))
                   (assq-ref args 'artist-id) session args 0 1))

    (define (like-genre session args)
      (set-opinion 'genre
                   (lambda (id) (get-genre-by-id genre-repo id))
                   (assq-ref args 'genre-id) session args 1 0))

    (define (dislike-genre session args)
      (set-opinion 'genre
                   (lambda (id) (get-genre-by-id genre-repo id))
                   (assq-ref args 'genre-id) session args 0 1))

    ;; ====== Writing: articles ======

    (define (create-article session args)
      (receive (body error) (require-body args)
               (if error error
                 (let ((name (article-input-display-name body)))
                   (if (not (non-empty-string? name))
                     (json-error 400 "invalid-request" "displayName is required")
                     (let ((id (generate-string-uuid)))
                       (insert-article
                        article-repo
                        (append
                         (list (cons 'identifier id)
                               (cons 'display-name (html-escape name))
                               (cons 'kind
                                     (symbol->string
                                      (article-kind-named (article-input-kind body))))
                               (cons 'contents
                                     (html-escape (or (article-input-contents body) "")))
                               (cons 'created-by (assoc-ref session 'owner-id))
                               (cons 'visibility-status 0)
                               (cons 'created-at (api-timestamp))
                               (cons 'views 0))
                         (if (string? (article-input-video-url body))
                           (list (cons 'video-url (article-input-video-url body)))
                           '())))
                       (article-detail id)))))))

    (define (article-comment-attrs id body article-id created-by typed-name)
      (append
       (list (cons 'identifier id)
             (cons 'article-identifier article-id)
             (cons 'visibility-status 0)
             (cons 'contents (article-comment-input-contents body))
             (cons 'created-at (api-timestamp)))
       (if created-by
         (list (cons 'created-by created-by))
         '())
       (if typed-name
         (list (cons 'author-name typed-name))
         '())
       (if (non-empty-string? (article-comment-input-parent-identifier body))
         (list (cons 'parent-identifier
                     (article-comment-input-parent-identifier body)))
         '())))

    (define (create-article-comment args)
      (let ((article-id (assq-ref args 'article-id)))
        (if (not (get-article-by-id article-repo article-id))
          (json-error 404 "not-found" "No such article")
          (receive (body error) (require-body args)
                   (if error
                     error
                     (let* ((contents (article-comment-input-contents body))
                            (session (api-session rc))
                            (created-by (and session (assoc-ref session 'owner-id)))
                            (posted-name
                             (and (not created-by)
                               (article-comment-input-author-name body)))
                            (typed-name
                             (and (non-empty-string? posted-name)
                               (let ((trimmed (string-trim-both posted-name)))
                                 (substring trimmed 0
                                            (min 80 (string-length trimmed)))))))
                       (if (not (non-empty-string? contents))
                         (json-error 400 "invalid-request" "contents is required")
                         (let ((id (generate-string-uuid)))
                           (insert-article-comment
                            article-comment-repo
                            (article-comment-attrs id body article-id created-by
                                                   typed-name))
                           (let ((row (find (lambda (candidate)
                                              (equal? (column candidate 'identifier)
                                                      id))
                                            (get-article-comments
                                             article-comment-repo (list article-id)))))
                             (if row
                               (created (article-comment->jso
                                         (article-comment-record row)))
                               (json-error 500 "internal-error"
                                           "The comment could not be read back")))))))))))

    ;; ====== Accounts ======

    (define (session-response row)
      (let* ((user-id (column row 'identifier))
             (permissions
              (permissions-from-column (column row 'permissions)))
             (get-owner-details
              (lambda ()
                `((id unquote user-id)
                  (email unquote (column row 'email))
                  (name unquote (column row 'username))
                  (permissions unquote permissions))))
             (token
              (generate-token
               #:encryption-key encryption-key
               #:signing-key signing-key
               #:token-validity-seconds
               session-token-validity-seconds
               #:get-owner-details get-owner-details)))
        (set-session-cookie! rc token)
        (ok (session->jso
             (make-session
              #:token token
              #:expires-in session-token-validity-seconds
              #:user (user-record row))))))

    (define (login args)
      (receive (body error) (require-body args)
               (if error
                 error
                 (let* ((email (login-request-email body))
                        (password (login-request-password body))
                        (row (get-user-by-email user-repo email)))
                   (if (not row)
                     (json-error 401 "unauthenticated"
                                 "That email and password do not match an account")
                     (let ((stored-hash (column row 'password))
                           (stored-salt (column row 'salt)))
                       (if (not (verify-password password
                                                 #:hash stored-hash
                                                 #:salt stored-salt))
                         (json-error 401 "unauthenticated"
                                     "That email and password do not match an account")
                         (session-response row))))))))

    (define (logout session args)
      (clear-session-cookie! rc)
      (no-content))

    (define (create-user session args)
      (receive (body error) (require-body args)
               (if error error
                 (let ((username (user-input-username body))
                       (email (user-input-email body)))
                   (cond
                     [(not (non-empty-string? username))
                      (json-error 400 "invalid-request" "username is required")]
                     [(not (non-empty-string? email))
                      (json-error 400 "invalid-request" "email is required")]
                     [(get-user-by-email user-repo email)
                      (json-error 409 "conflict"
                                  "An account already uses that email")]
                     [else
                       (let ((id (generate-string-uuid))
                             (password (user-input-password body)))
                         (insert-user
                          user-repo
                          (append
                           (list (cons 'identifier id)
                                 (cons 'username (html-escape username))
                                 (cons 'email (html-escape email))
                                 (cons 'permissions
                                       (stored-permissions
                                        (user-input-permissions body))))
                           (if (non-empty-string? password)
                             (list (cons 'password (hash-password password)))
                             '())))
                         (created (user->jso
                                   (user-record (get-user-by-id user-repo id)))))])))))

    (define (user-patch-attrs body email permissions password)
      (append
       (text-attr 'username (user-patch-username body))
       (text-attr 'email email)
       (if (list? permissions)
         (list (cons 'permissions (stored-permissions permissions)))
         '())
       (if (non-empty-string? password)
         (list (cons 'password (hash-password password)))
         '())))

    (define (update-user session args)
      (let ((id (assq-ref args 'user-id)))
        (let ((row (get-user-by-id user-repo id)))
          (if (not row)
            (json-error 404 "not-found" "No such user")
            (receive (body error) (require-body args)
                     (if error
                       error
                       (let* ((email (user-patch-email body))
                              (other (and (non-empty-string? email)
                                       (get-user-by-email user-repo email)))
                              (permissions (user-patch-permissions body))
                              (password (user-patch-password body)))
                         (if (and other
                               (not (equal? (column other 'identifier) id)))
                           (json-error 409 "conflict"
                                       "An account already uses that email")
                           (let ((attrs
                                  (user-patch-attrs body email permissions password)))
                             (when (pair? attrs)
                               (update-user-by-id user-repo id attrs))
                             (ok (user->jso
                                  (user-record (get-user-by-id user-repo id)))))))))))))

    (define (delete-user session args)
      (let ((id (assq-ref args 'user-id)))
        (if (not (get-user-by-id user-repo id))
          (json-error 404 "not-found" "No such user")
          (begin
            (delete-user-by-id user-repo id)
            (no-content)))))

    (list
     (cons 'list-songs (answer list-songs))
     (cons 'create-song
           (protected '(wikimusic:song-create) create-song))
     (cons 'get-song (answer get-song))
     (cons 'update-song
           (protected '(wikimusic:song-create) update-song))
     (cons 'delete-song
           (protected '(wikimusic:song-delete) delete-song))
     (cons 'list-song-versions (answer list-song-versions))
     (cons 'create-song-version
           (protected '(wikimusic:song-create) create-song-version))
     (cons 'get-song-version (answer get-song-version))
     (cons 'update-song-version
           (protected '(wikimusic:song-create) update-song-version))
     (cons 'delete-song-version
           (protected '(wikimusic:song-delete) delete-song-version))
     (cons 'list-song-comments (answer list-song-comments))
     (cons 'create-song-comment
           (protected '() create-song-comment))
     (cons 'update-song-comment
           (protected '() update-song-comment))
     (cons 'delete-song-comment
           (protected '() delete-song-comment))
     (cons 'create-song-artwork
           (protected '(wikimusic:song-create) create-song-artwork))
     (cons 'update-song-artwork
           (protected '(wikimusic:song-create) update-song-artwork))
     (cons 'delete-song-artwork
           (protected '(wikimusic:song-delete) delete-song-artwork))
     (cons 'add-song-artist
           (protected '(wikimusic:song-create) add-song-artist))
     (cons 'remove-song-artist
           (protected '(wikimusic:song-delete) remove-song-artist))
     (cons 'add-song-genre
           (protected '(wikimusic:song-create) add-song-genre))
     (cons 'remove-song-genre
           (protected '(wikimusic:song-delete) remove-song-genre))
     (cons 'list-song-external-sources
           (answer list-song-external-sources))
     (cons 'create-song-external-source
           (protected '(wikimusic:song-create)
                      create-song-external-source))
     (cons 'update-song-external-source
           (protected '(wikimusic:song-create)
                      update-song-external-source))
     (cons 'like-song
           (protected '() like-song))
     (cons 'dislike-song
           (protected '() dislike-song))
     (cons 'list-artists (answer list-artists))
     (cons 'create-artist
           (protected '(wikimusic:artist-create) create-artist))
     (cons 'get-artist (answer get-artist))
     (cons 'update-artist
           (protected '(wikimusic:artist-create) update-artist))
     (cons 'delete-artist
           (protected '(wikimusic:artist-delete) delete-artist))
     (cons 'list-artist-songs (answer list-artist-songs))
     (cons 'list-artist-comments (answer list-artist-comments))
     (cons 'create-artist-comment
           (protected '() create-artist-comment))
     (cons 'update-artist-comment
           (protected '() update-artist-comment))
     (cons 'delete-artist-comment
           (protected '() delete-artist-comment))
     (cons 'create-artist-artwork
           (protected '(wikimusic:artist-create) create-artist-artwork))
     (cons 'update-artist-artwork
           (protected '(wikimusic:artist-create) update-artist-artwork))
     (cons 'delete-artist-artwork
           (protected '(wikimusic:artist-delete) delete-artist-artwork))
     (cons 'list-artist-external-sources
           (answer list-artist-external-sources))
     (cons 'create-artist-external-source
           (protected '(wikimusic:artist-create)
                      create-artist-external-source))
     (cons 'update-artist-external-source
           (protected '(wikimusic:artist-create)
                      update-artist-external-source))
     (cons 'like-artist
           (protected '() like-artist))
     (cons 'dislike-artist
           (protected '() dislike-artist))
     (cons 'list-genres (answer list-genres))
     (cons 'create-genre
           (protected '(wikimusic:genre-create) create-genre))
     (cons 'get-genre (answer get-genre))
     (cons 'update-genre
           (protected '(wikimusic:genre-create) update-genre))
     (cons 'delete-genre
           (protected '(wikimusic:genre-delete) delete-genre))
     (cons 'list-genre-songs (answer list-genre-songs))
     (cons 'list-genre-comments (answer list-genre-comments))
     (cons 'create-genre-comment
           (protected '() create-genre-comment))
     (cons 'update-genre-comment
           (protected '() update-genre-comment))
     (cons 'delete-genre-comment
           (protected '() delete-genre-comment))
     (cons 'create-genre-artwork
           (protected '(wikimusic:genre-create) create-genre-artwork))
     (cons 'update-genre-artwork
           (protected '(wikimusic:genre-create) update-genre-artwork))
     (cons 'delete-genre-artwork
           (protected '(wikimusic:genre-delete) delete-genre-artwork))
     (cons 'list-genre-external-sources
           (answer list-genre-external-sources))
     (cons 'create-genre-external-source
           (protected '(wikimusic:genre-create)
                      create-genre-external-source))
     (cons 'update-genre-external-source
           (protected '(wikimusic:genre-create)
                      update-genre-external-source))
     (cons 'like-genre
           (protected '() like-genre))
     (cons 'dislike-genre
           (protected '() dislike-genre))
     (cons 'list-articles (answer list-articles))
     (cons 'create-article
           (protected '() create-article))
     (cons 'get-article (answer get-article))
     (cons 'list-article-comments (answer list-article-comments))
     (cons 'create-article-comment (answer create-article-comment))
     (cons 'login (answer login))
     (cons 'logout
           (protected '() logout))
     (cons 'get-me
           (protected '() get-me))
     (cons 'list-users
           (protected '(wikimusic:modify-permissions) list-users))
     (cons 'create-user
           (protected '(wikimusic:user-create) create-user))
     (cons 'update-user
           (protected '(wikimusic:modify-permissions) update-user))
     (cons 'delete-user
           (protected '(wikimusic:user-delete) delete-user))
     (cons 'get-instance (answer get-instance)))))

;;; ====== Serving ======

(define (artanis->http-request rc)
  "Return the <http-request> that an Artanis request context describes."
  (let ((body (rc-body rc)))
    (make-http-request
     (rc-method rc)
     (rc-path rc)
     (parse-query (uri-query (request-uri (rc-req rc))))
     (map (lambda (entry)
            (cons (format #f "~a" (car entry))
                  (header-text (cdr entry))))
          (request-headers (rc-req rc)))
     (if (bytevector? body)
       (bytevector->string body "utf-8")
       body))))

(define (serve-api rc)
  "Answer the Artanis request RC with the generated dispatcher."
  (parameterize ((api-handlers (handlers-for rc)))
    (catch #t
           (lambda ()
             (dispatch (artanis->http-request rc)))
           (lambda (key . args)
             (case key
               [(api-bad-request)
                (json-error 400 "invalid-parameter" (car args))]
               [(openapi-no-route)
                (json-error 404 "not-found" "No such endpoint")]
               [(openapi-validation-error)
                (json-error 400 "invalid-request"
                            (if (and (pair? args) (pair? (cdr args)))
                              (cadr args)
                              "The request does not match the specification"))]
               [(openapi-not-implemented)
                (json-error 501 "not-implemented"
                            "This operation is not implemented")]
               [else (apply throw key args)])))))

(define (emit-api-response response)
  "Return RESPONSE in the two values Artanis' response-emit expects."
  (let ((status (http-response-status response))
        (body (http-response-body response)))
    (if (= status 204)
      (response-emit "" #:status 204)
      (response-emit (if (string? body) body (jso->json-string body))
                     #:status status
                     #:headers
                     (list (cons 'content-type
                                 (list 'application/json
                                       (cons 'charset "utf-8"))))))))
