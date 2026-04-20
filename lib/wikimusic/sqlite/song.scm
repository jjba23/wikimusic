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

  (define insert-columns
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
                 views
                 description))

    (define conn (DB-open rc))

  (define (get-song-by-id id)
    (let* ((query (format #f
                   "SELECT ~a FROM songs WHERE identifier = ~a LIMIT 1"
                   (symbols->sql-columns-list columns)
                   (value->sql-literal id)))
           (_ (log-info "get-song-by-id query:\n\t~a\n" query))
           (rows (map sql-row->scheme-alist
                      (DB-get-all-rows (DB-query conn query))))
           (_ (log-info "get-song-by-id rows: ~a\n"
                        (length rows))))
      (if (nil? rows) #f
          (car rows))))

  (define (get-songs)
    (let* ((query (format #f "SELECT ~a FROM songs
                   ORDER BY display_name ASC"
                          (symbols->sql-columns-list columns)))
           (_ (log-info "get-songs query:\n\t~a\n" query))
           (rows (map sql-row->scheme-alist
                      (DB-get-all-rows (DB-query conn query))))
           (_ (log-info "get-songs rows: ~a\n"
                        (length rows))))
      rows))

  (define (update-song-by-id id attrs)
    (let* ((query (format #f "UPDATE song SET ~a WHERE identifier = ~a"
                          (string-join (map pair->sql-assignment attrs) ", ")
                          (value->sql-literal id)))
           (_ (log-info "update-song-by-id query:\n\t~a\n" query)))
      (DB-query conn query)))

  (define (delete-song-by-id id)
    (let* ((query (format #f "DELETE FROM songs WHERE identifier = ~a"
                          (value->sql-literal id)))
           (_ (log-info "delete-song-by-id query:\n\t~a\n" query)))
      (DB-query conn query)))

  (define (insert-song attrs)
    (let* ((vals (map (lambda (x)
                        (value->sql-literal (assq-ref attrs x)))
                      insert-columns))
           (query (format #f "INSERT INTO song (~a) VALUES (~a)"
                          (symbols->sql-columns-list insert-columns)
                          (string-join vals ", ")))
           (_ (log-info "insert-song query:\n\t~a\n" query)))
      (DB-query conn query)))

  (mk-song-repository #:get-song-by-id-proc get-song-by-id
                      #:get-songs-proc get-songs
                      #:insert-song-proc insert-song
                      #:delete-song-by-id-proc delete-song-by-id
                      #:update-song-by-id-proc update-song-by-id))
