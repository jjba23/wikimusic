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

(define-module (wikimusic sqlite artist)
  #:declarative? #t
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain artist)
  #:export (make-sqlite-artist-repository))

;; --- SQLite implementation ---
(define (make-sqlite-artist-repository rc)
  (define columns
    '(identifier display-name
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

  (define execute-read
    (db-read conn))

  (define (get-artist-by-id id)
    (let* ((query (format #f
                   "SELECT ~a FROM artists WHERE identifier = ~a LIMIT 1"
                   cols-sql
                   (value->sql-literal id)))
           (rows (execute-read "get-artist-by-id" query)))
      (if (nil? rows) #f
          (car rows))))

  (define* (get-artists #:key (order-by "created_at DESC")
                        (limit 100)
                        (offset 0))
    (let ((query (format #f
                  "SELECT ~a FROM artists ORDER BY ~a LIMIT ~a OFFSET ~a"
                  cols-sql
                  order-by
                  limit
                  offset)))
      (execute-read "get-artists" query)))

  (define* (search-artists s
                           #:key (order-by "created_at DESC")
                           (limit 100)
                           (offset 0))
    (let* ((search (value->sql-literal (format #f "%~a%" s)))
           (query (format #f
                   "SELECT ~a FROM artists WHERE (display_name LIKE ~a OR description LIKE ~a)
                   ORDER BY ~a LIMIT ~a OFFSET ~a"
                   cols-sql
                   search
                   search
                   order-by
                   limit
                   offset)))
      (execute-read "search-artists" query)))

  (define (get-artists-by-ids ids)
    (let* ((query (format #f "SELECT ~a FROM artists WHERE identifier IN(~a)"
                          cols-sql
                          (string-join (map value->sql-literal ids) ", "))))
      (execute-read "get-artists-by-ids" query)))

  (define (update-artist-by-id id attrs)
    (let* ((query (format #f "UPDATE artists SET ~a WHERE identifier = ~a"
                          (string-join (map pair->sql-assignment attrs) ", ")
                          (value->sql-literal id))))
      (execute-write "update-artist-by-id" query)))

  (define (delete-artist-by-id id)
    (let* ((query (format #f "DELETE FROM artists WHERE identifier = ~a"
                          (value->sql-literal id))))
      (execute-write "delete-artist-by-id" query)))

  (define (insert-artist attrs)
    (let* ((vals (map (lambda (x)
                        (value->sql-literal (assq-ref attrs x)))
                      insert-columns))
           (query (format #f "INSERT INTO artists (~a) VALUES (~a)"
                          insert-cols-sql
                          (string-join vals ", "))))
      (execute-write "insert-artist" query)))

  (mk-artist-repository #:get-artist-by-id-proc get-artist-by-id
                        #:get-artists-by-ids-proc get-artists-by-ids
                        #:get-artists-proc get-artists
                        #:search-artists-proc search-artists
                        #:insert-artist-proc insert-artist
                        #:delete-artist-by-id-proc delete-artist-by-id
                        #:update-artist-by-id-proc update-artist-by-id))
