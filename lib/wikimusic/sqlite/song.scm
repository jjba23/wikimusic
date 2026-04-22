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

  (define cols-sql
    (symbols->sql-columns-list columns))

  (define insert-columns
    (delq 'last-edited-at columns))

  (define insert-cols-sql
    (symbols->sql-columns-list insert-columns))

  (define conn
    (DB-open rc))

  (define execute-write
    (db-write conn))

  (define execute-select
    (db-select conn))

  (define (get-song-by-id id)
    (let* ((query (format #f
                   "SELECT ~a FROM songs WHERE identifier = ~a LIMIT 1"
                   cols-sql
                   (value->sql-literal id)))
           (rows (execute-select "get-song-by-id" query)))
      (if (nil? rows) #f
          (car rows))))

  (define* (get-songs #:key (order-by "created_at DESC")
                      (limit 100)
                      (offset 0))
    (let* ((query (format #f
                          "SELECT ~a FROM songs
                   ORDER BY ~a LIMIT ~a OFFSET ~a"
                          cols-sql
                          order-by
                          limit
                          offset)))
      (execute-select "get-songs" query)))

  (define* (get-songs-by-artist-id id
                                   #:key (order-by "display_name DESC"))
    (let* ((query (format #f
                   "SELECT ~a FROM songs
                   WHERE identifier IN (SELECT song_identifier FROM song_artists WHERE
                    artist_identifier = ~a)
                   ORDER BY ~a"
                   cols-sql
                   (value->sql-literal id) order-by)))
      (execute-select "get-songs-by-artist-id" query)))

  (define* (get-songs-by-genre-id id
                                  #:key (order-by "display_name DESC"))
    (let* ((query (format #f
                   "SELECT ~a FROM songs
                   WHERE identifier IN (SELECT song_identifier FROM song_genres WHERE
                    genre_identifier = ~a)
                   ORDER BY ~a"
                   cols-sql
                   (value->sql-literal id) order-by)))
      (execute-select "get-songs-by-genre-id" query)))

  (define* (search-songs s
                         #:key (order-by "created_at DESC")
                         (limit 100)
                         (offset 0))
    (let* ((search (value->sql-literal (format #f "%~a%" s)))
           (query (format #f
                   "SELECT ~a FROM songs
                   WHERE (display_name LIKE ~a OR description LIKE ~a)
                   ORDER BY ~a LIMIT ~a OFFSET ~a"
                   cols-sql
                   search
                   search
                   order-by
                   limit
                   offset)))
      (execute-select "search-songs" query)))

  (define* (get-song-artists-by-ids ids)
    (let* ((query (format #f
                   "SELECT song_identifier, artist_identifier FROM song_artists
                   WHERE song_identifier IN(~a)
                   ORDER BY created_at DESC"
                   (string-join (map value->sql-literal ids) ", "))))
      (execute-select "get-song-artists-by-ids" query)))

  (define* (get-song-genres-by-ids ids)
    (let* ((query (format #f
                   "SELECT song_identifier, genre_identifier FROM song_genres
                   WHERE song_identifier IN(~a)
                   ORDER BY created_at DESC"
                   (string-join (map value->sql-literal ids) ", "))))
      (execute-select "get-song-genres-by-ids" query)))

  (define (update-song-by-id id attrs)
    (let* ((query (format #f "UPDATE songs SET ~a WHERE identifier = ~a"
                          (string-join (map pair->sql-assignment attrs) ", ")
                          (value->sql-literal id))))
      (execute-write "update-song-by-id" query)))

  (define (delete-song-by-id id)
    (let* ((query (format #f "DELETE FROM songs WHERE identifier = ~a"
                          (value->sql-literal id))))
      (execute-write "delete-song-by-id" query)))

  (define (insert-song attrs)
    (let* ((vals (map (lambda (x)
                        (value->sql-literal (assq-ref attrs x)))
                      insert-columns))
           (query (format #f "INSERT INTO songs (~a) VALUES (~a)"
                          insert-cols-sql
                          (string-join vals ", "))))
      (execute-write "insert-song" query)))

  (mk-song-repository #:get-song-by-id-proc get-song-by-id
                      #:get-songs-proc get-songs
                      #:get-songs-by-artist-id-proc get-songs-by-artist-id
                      #:get-songs-by-genre-id-proc get-songs-by-genre-id
                      #:get-song-genres-by-ids-proc get-song-genres-by-ids
                      #:get-song-artists-by-ids-proc get-song-artists-by-ids
                      #:search-songs-proc search-songs
                      #:insert-song-proc insert-song
                      #:delete-song-by-id-proc delete-song-by-id
                      #:update-song-by-id-proc update-song-by-id))
