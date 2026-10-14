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

(define-module (wikimusic sqlite song)
  #:declarative? #t
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain song)
  #:export (make-sqlite-song-repository))

;; --- SQLite implementation ---
(define (make-sqlite-song-repository rc)
  (define columns
    '(identifier display-name
                 music-key
                 music-tuning
                 music-creation-date
                 album-name
                 album-info-link
                 created-by
                 visibility-status
                 approved-by
                 created-at
                 last-edited-at
                 views
                 description))

  (define conn
    (DB-open rc))

  (define execute-write
    (db-write conn))

  (define execute-read
    (db-read conn))

  (define (get-song-by-id id)
    (let ((rows (execute-read "get-song-by-id"
                              (sql-select 'songs
                                          #:columns columns
                                          #:where (list (cons 'identifier id))
                                          #:limit 1))))
      (if (nil? rows) #f
          (car rows))))

  (define* (get-songs #:key (order-by '((created-at desc)))
                      (limit 100)
                      (offset 0))
    (execute-read "get-songs"
                  (sql-select 'songs
                              #:columns columns
                              #:order-by order-by
                              #:limit limit
                              #:offset offset)))

  ;; A song's artists and genres are held in the join tables, so the songs of
  ;; an artist are those whose identifiers the join table names.  Reading the
  ;; identifiers first and then the songs keeps both statements inside
  ;; kracht's builders -- an `IN (SELECT ...)' subquery would have to be
  ;; written out by hand, and kracht would no longer own the statement.
  (define (song-ids-in-relation name related-table related-column id)
    (map (lambda (row)
           (assq-ref row
                     'song-identifier))
         (execute-read name
                       (sql-select related-table
                                   #:columns '(song-identifier)
                                   #:where (list (cons related-column id))))))

  (define* (get-songs-by-artist-id id
                                   #:key (order-by '((display-name desc))))
    (execute-read "get-songs-by-artist-id"
                  (sql-select 'songs
                              #:columns columns
                              #:where (list (list 'identifier
                                                  'in
                                                  (song-ids-in-relation
                                                   "song-ids-by-artist-id"
                                                   'song_artists
                                                   'artist-identifier id)))
                              #:order-by order-by)))

  (define* (get-songs-by-genre-id id
                                  #:key (order-by '((display-name desc))))
    (execute-read "get-songs-by-genre-id"
                  (sql-select 'songs
                              #:columns columns
                              #:where (list (list 'identifier
                                                  'in
                                                  (song-ids-in-relation
                                                   "song-ids-by-genre-id"
                                                   'song_genres
                                                   'genre-identifier id)))
                              #:order-by order-by)))

  ;; The one statement kracht's builders cannot write: a search matches the
  ;; term against either of two columns, and kracht joins its conditions with
  ;; `AND' only.  It is still kracht that owns it -- `sql-parameterize' is
  ;; kracht's own escape hatch -- and the columns and the sort come from
  ;; kracht's helpers, so only the `OR' itself is spelled here.
  (define* (search-songs s
                         #:key (order-by '((created-at desc)))
                         (limit 100)
                         (offset 0))
    (let ((search (format #f "%~a%" s)))
      (execute-read "search-songs"
                    (sql-parameterize (format #f
                                       "SELECT ~a FROM songs WHERE (display_name LIKE ? OR description LIKE ?) ORDER BY ~a LIMIT ? OFFSET ?"
                                       (symbols->sql-columns-list columns)
                                       (sql-order-by-sql order-by))
                                      (list search search limit offset)))))

  ;; A count is a statement kracht's `sql-select' cannot express -- it takes
  ;; column names, and `COUNT(*)' is not a column -- so `sql-parameterize',
  ;; kracht's own escape hatch, carries it.  The `WHERE' is the same one
  ;; `search-songs' uses, so a page count and a page of hits always agree.
  (define* (count-songs #:key search)
    (let* ((term (and search
                      (format #f "%~a%" search)))
           (rows (if term
                     (execute-read "count-songs"
                                   (sql-parameterize
                                    "SELECT COUNT(*) AS count FROM songs WHERE (display_name LIKE ? OR description LIKE ?)"
                                    (list term term)))
                     (execute-read "count-songs"
                                   (sql-parameterize
                                    "SELECT COUNT(*) AS count FROM songs"
                                    '())))))
      (if (nil? rows) 0
          (or (assq-ref (car rows)
                        'count) 0))))

  (define* (get-song-artists-by-ids ids)
    (execute-read "get-song-artists-by-ids"
                  (sql-select 'song_artists
                              #:columns '(song-identifier artist-identifier)
                              #:where (list (list 'song-identifier
                                                  'in ids))
                              #:order-by '((created-at desc)))))

  (define* (get-song-genres-by-ids ids)
    (execute-read "get-song-genres-by-ids"
                  (sql-select 'song_genres
                              #:columns '(song-identifier genre-identifier)
                              #:where (list (list 'song-identifier
                                                  'in ids))
                              #:order-by '((created-at desc)))))

  (define (update-song-by-id id attrs)
    (execute-write "update-song-by-id"
                   (sql-update 'songs
                               (attrs->row attrs columns)
                               #:where (list (cons 'identifier id)))))

  (define (delete-song-by-id id)
    (execute-write "delete-song-by-id"
                   (sql-delete 'songs
                               #:where (list (cons 'identifier id)))))

  (define (insert-song attrs)
    (execute-write "insert-song"
                   (sql-insert 'songs
                               (attrs->row attrs columns))))

  (mk-song-repository #:get-song-by-id-proc get-song-by-id
                      #:get-songs-proc get-songs
                      #:count-songs-proc count-songs
                      #:get-songs-by-artist-id-proc get-songs-by-artist-id
                      #:get-songs-by-genre-id-proc get-songs-by-genre-id
                      #:get-song-genres-by-ids-proc get-song-genres-by-ids
                      #:get-song-artists-by-ids-proc get-song-artists-by-ids
                      #:search-songs-proc search-songs
                      #:insert-song-proc insert-song
                      #:delete-song-by-id-proc delete-song-by-id
                      #:update-song-by-id-proc update-song-by-id))
