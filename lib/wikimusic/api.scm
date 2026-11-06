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
;;; repositories the pages read, and it turns an Artanis request into the
;;; `<http-request>' the generated dispatcher understands.
;;;
;;; An Artanis route only calls `serve-api', which builds the repositories for
;;; that request and installs one handler per operation.  The handlers below
;;; take the repositories as arguments, so nothing here reaches for a global
;;; connection, and a handler that finds no row answers the `Error' schema the
;;; specification declares rather than the page controllers' HTML.

(define-module (wikimusic api)
  #:declarative? #t
  #:use-module (ice-9 receive)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 format)
  #:use-module (web request)
  #:use-module (web uri)
  #:use-module (artanis artanis)
  #:use-module (wikimusic domain song)
  #:use-module (wikimusic domain artist)
  #:use-module (wikimusic domain genre)
  #:use-module (wikimusic domain song-content)
  #:use-module (wikimusic domain artwork)
  #:use-module (wikimusic sqlite song)
  #:use-module (wikimusic sqlite artist)
  #:use-module (wikimusic sqlite genre)
  #:use-module (wikimusic sqlite song-content)
  #:use-module (wikimusic sqlite artwork)
  #:use-module (wikimusic-api controllers)
  #:use-module (wikimusic-api json)
  #:use-module (wikimusic-api models)
  #:use-module (wikimusic-api runtime)
  #:export (serve-api emit-api-response))

(define api-version "1.0.0")

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
    ((integer? value) value)
    ((number? value) (inexact->exact value))
    ((string? value) (or (string->number value) 0))
    (else 0)))

(define (by-identifier rows)
  "Return ROWS as an alist of identifier to row."
  (map (lambda (row) (cons (column row 'identifier) row)) rows))

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
   #:content-url (column row 'content-url)
   #:content-caption (text (column row 'content-caption))
   #:order-value (integer (column row 'order-value))))

(define (version-record row)
  (make-song-version
   #:identifier (column row 'identifier)
   #:version-name (column row 'version-name)
   #:instrument-type (column row 'instrument-type)
   #:ascii-legend (text (column row 'ascii-legend))
   #:ascii-contents (text (column row 'ascii-contents))
   #:has-pdf (if (text (column row 'pdf-contents)) #t #f)
   #:has-tablature (if (text (column row 'guitarpro-contents)) #t #f)
   #:created-at (text (column row 'created-at))))

(define (json-error status code message)
  "Return STATUS with the Error schema's `code' and `message'."
  (json-response status (list (cons "code" code) (cons "message" message))))

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

(define (list-songs-handler song-repo artist-repo genre-repo args)
  (receive (limit offset) (pagination args)
    (let* ((search (text (assq-ref args 'search)))
           (rows (if search
                     (search-songs song-repo search
                                   #:limit limit #:offset offset)
                     (get-songs song-repo #:limit limit #:offset offset)))
           (total (count-songs song-repo #:search search)))
      (receive (artist-links genre-links artists genres)
          (song-relations song-repo artist-repo genre-repo
                          (map (lambda (row) (column row 'identifier)) rows))
        (ok (song-list->jso
             (make-song-list
              #:items (map (lambda (row)
                             (song-summary row artist-links genre-links
                                           artists genres))
                           rows)
              #:total total
              #:limit limit
              #:offset offset)))))))

(define (get-song-handler song-repo artist-repo genre-repo
                          content-repo artwork-repo args)
  (let ((id (assq-ref args 'song-id)))
    (let ((row (get-song-by-id song-repo id)))
      (if (not row)
          (json-error 404 "not-found" "No such song")
          (let ((ids (list id)))
            (receive (artist-links genre-links artists genres)
                (song-relations song-repo artist-repo genre-repo ids)
              (let ((summary (song-summary row artist-links genre-links
                                           artists genres)))
                (ok (song->jso
                     (make-song
                      #:identifier (song-summary-identifier summary)
                      #:display-name (song-summary-display-name summary)
                      #:description (song-summary-description summary)
                      #:music-key (song-summary-music-key summary)
                      #:music-tuning (song-summary-music-tuning summary)
                      #:music-creation-date (text (column row
                                                          'music-creation-date))
                      #:album-name (song-summary-album-name summary)
                      #:album-info-link (text (column row 'album-info-link))
                      #:views (song-summary-views summary)
                      #:artists (song-summary-artists summary)
                      #:genres (song-summary-genres summary)
                      #:versions
                      (map version-record
                           (get-song-contents-by-song-ids content-repo ids))
                      #:artworks
                      (map artwork-record
                           (get-artworks-by-entity-ids artwork-repo 'song ids))
                      #:created-at (song-summary-created-at summary)))))))))))

(define (list-song-versions-handler song-repo content-repo args)
  (let ((id (assq-ref args 'song-id)))
    (if (not (get-song-by-id song-repo id))
        (json-error 404 "not-found" "No such song")
        (ok (map version-record
                 (get-song-contents-by-song-ids content-repo (list id)))))))

(define (list-artists-handler artist-repo args)
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

(define (get-artist-handler artist-repo artwork-repo args)
  (let ((id (assq-ref args 'artist-id)))
    (let ((row (get-artist-by-id artist-repo id)))
      (if (not row)
          (json-error 404 "not-found" "No such artist")
          (let ((summary (artist-summary row)))
            (ok (artist->jso
                 (make-artist
                  #:identifier (artist-summary-identifier summary)
                  #:display-name (artist-summary-display-name summary)
                  #:description (artist-summary-description summary)
                  #:views (artist-summary-views summary)
                  #:artworks
                  (map artwork-record
                       (get-artworks-by-entity-ids artwork-repo 'artist
                                                   (list id)))
                  #:created-at (artist-summary-created-at summary)))))))))

(define (list-artist-songs-handler song-repo artist-repo genre-repo args)
  (let ((id (assq-ref args 'artist-id)))
    (if (not (get-artist-by-id artist-repo id))
        (json-error 404 "not-found" "No such artist")
        (receive (limit offset) (pagination args)
          (let* ((rows (get-songs-by-artist-id song-repo id))
                 (total (length rows)))
            (receive (artist-links genre-links artists genres)
                (song-relations song-repo artist-repo genre-repo
                                (map (lambda (row) (column row 'identifier))
                                     rows))
              (ok (song-list->jso
                   (make-song-list
                    #:items (map (lambda (row)
                                   (song-summary row artist-links genre-links
                                                 artists genres))
                                 (slice rows limit offset))
                    #:total total
                    #:limit limit
                    #:offset offset)))))))))

(define (list-genres-handler genre-repo args)
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

(define (get-genre-handler genre-repo artwork-repo args)
  (let ((id (assq-ref args 'genre-id)))
    (let ((row (get-genre-by-id genre-repo id)))
      (if (not row)
          (json-error 404 "not-found" "No such genre")
          (let ((summary (genre-summary row)))
            (ok (genre->jso
                 (make-genre
                  #:identifier (genre-summary-identifier summary)
                  #:display-name (genre-summary-display-name summary)
                  #:description (genre-summary-description summary)
                  #:views (genre-summary-views summary)
                  #:artworks
                  (map artwork-record
                       (get-artworks-by-entity-ids artwork-repo 'genre
                                                   (list id)))
                  #:created-at (genre-summary-created-at summary)))))))))

(define (list-genre-songs-handler song-repo artist-repo genre-repo args)
  (let ((id (assq-ref args 'genre-id)))
    (if (not (get-genre-by-id genre-repo id))
        (json-error 404 "not-found" "No such genre")
        (receive (limit offset) (pagination args)
          (let* ((rows (get-songs-by-genre-id song-repo id))
                 (total (length rows)))
            (receive (artist-links genre-links artists genres)
                (song-relations song-repo artist-repo genre-repo
                                (map (lambda (row) (column row 'identifier))
                                     rows))
              (ok (song-list->jso
                   (make-song-list
                    #:items (map (lambda (row)
                                   (song-summary row artist-links genre-links
                                                 artists genres))
                                 (slice rows limit offset))
                    #:total total
                    #:limit limit
                    #:offset offset)))))))))

(define (get-instance-handler song-repo artist-repo genre-repo args)
  (ok (instance->jso
       (make-instance
        #:name instance-name
        #:version api-version
        #:counts (make-instance-counts
                  #:songs (count-songs song-repo)
                  #:artists (count-artists artist-repo)
                  #:genres (count-genres genre-repo))))))

;;; ====== Serving ======

(define (artanis->http-request rc)
  "Return the <http-request> that an Artanis request context describes."
  (make-http-request (rc-method rc)
                     (rc-path rc)
                     (parse-query (uri-query (request-uri (rc-req rc))))
                     '()
                     #f))

(define (handlers-for rc)
  "Return the operation handlers of the request context RC, as an alist."
  (let ((song-repo (make-sqlite-song-repository rc))
        (artist-repo (make-sqlite-artist-repository rc))
        (genre-repo (make-sqlite-genre-repository rc))
        (content-repo (make-sqlite-song-content-repository rc))
        (artwork-repo (make-sqlite-artwork-repository rc)))
    (list (cons 'list-songs
                (lambda (request args)
                  (list-songs-handler song-repo artist-repo genre-repo args)))
          (cons 'get-song
                (lambda (request args)
                  (get-song-handler song-repo artist-repo genre-repo
                                    content-repo artwork-repo args)))
          (cons 'list-song-versions
                (lambda (request args)
                  (list-song-versions-handler song-repo content-repo args)))
          (cons 'list-artists
                (lambda (request args)
                  (list-artists-handler artist-repo args)))
          (cons 'get-artist
                (lambda (request args)
                  (get-artist-handler artist-repo artwork-repo args)))
          (cons 'list-artist-songs
                (lambda (request args)
                  (list-artist-songs-handler song-repo artist-repo
                                             genre-repo args)))
          (cons 'list-genres
                (lambda (request args)
                  (list-genres-handler genre-repo args)))
          (cons 'get-genre
                (lambda (request args)
                  (get-genre-handler genre-repo artwork-repo args)))
          (cons 'list-genre-songs
                (lambda (request args)
                  (list-genre-songs-handler song-repo artist-repo
                                            genre-repo args)))
          (cons 'get-instance
                (lambda (request args)
                  (get-instance-handler song-repo artist-repo
                                        genre-repo args))))))

(define (serve-api rc)
  "Answer the Artanis request RC with the generated dispatcher."
  (parameterize ((api-handlers (handlers-for rc)))
    (catch #t
      (lambda ()
        (dispatch (artanis->http-request rc)))
      (lambda (key . args)
        (case key
          ((api-bad-request)
           (json-error 400 "invalid-parameter" (car args)))
          ((openapi-no-route)
           (json-error 404 "not-found" "No such endpoint"))
          ((openapi-validation-error)
           (json-error 400 "invalid-request"
                      "The request does not match the specification"))
          ((openapi-not-implemented)
           (json-error 501 "not-implemented"
                      "This operation is not implemented"))
          (else (apply throw key args)))))))

(define (emit-api-response response)
  "Return RESPONSE in the two values Artanis' response-emit expects."
  (let ((body (http-response-body response)))
    (response-emit (if (string? body) body (jso->json-string body))
                   #:status (http-response-status response)
                   #:headers '((Content-Type . "application/json; charset=utf-8")))))
