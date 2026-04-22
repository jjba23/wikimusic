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

(define-module (wikimusic sqlite genre)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain genre)
  #:export (make-sqlite-genre-repository))

;; --- SQLite implementation ---
(define (make-sqlite-genre-repository rc)
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

  (define (get-genre-by-id id)
    (let* ((query (format #f
                   "SELECT ~a FROM genres WHERE identifier = ~a LIMIT 1"
                   cols-sql
                   (value->sql-literal id)))
           (rows (execute-read "get-genre-by-id" query)))
      (if (nil? rows) #f
          (car rows))))

  (define (get-genres-by-ids ids)
    (let* ((query (format #f "SELECT ~a FROM genres WHERE identifier IN(~a)"
                          cols-sql
                          (string-join (map value->sql-literal ids) ", "))))
      (execute-read "get-genres-by-ids" query)))

  (define* (get-genres #:key (order-by "created_at DESC")
                       (limit 100)
                       (offset 0))
    (let* ((query (format #f
                          "SELECT ~a FROM genres
                   ORDER BY ~a LIMIT ~a OFFSET ~a"
                          cols-sql
                          order-by
                          limit
                          offset)))
      (execute-read "get-genres" query)))

  (define* (search-genres s
                          #:key (order-by "created_at DESC")
                          (limit 100)
                          (offset 0))
    (let* ((search (value->sql-literal (format #f "%~a%" s)))
           (query (format #f
                   "SELECT ~a FROM genres
                   WHERE (display_name LIKE ~a OR description LIKE ~a)
                   ORDER BY ~a LIMIT ~a OFFSET ~a"
                   cols-sql
                   search
                   search
                   order-by
                   limit
                   offset)))
      (execute-read "search-genres" query)))

  (define (update-genre-by-id id attrs)
    (let* ((query (format #f "UPDATE genres SET ~a WHERE identifier = ~a"
                          (string-join (map pair->sql-assignment attrs) ", ")
                          (value->sql-literal id))))
      (execute-write "update-genre-by-id" query)))

  (define (delete-genre-by-id id)
    (let* ((query (format #f "DELETE FROM genres WHERE identifier = ~a"
                          (value->sql-literal id))))
      (execute-write "delete-genre-by-id" query)))

  (define (insert-genre attrs)
    (let* ((vals (map (lambda (x)
                        (value->sql-literal (assq-ref attrs x)))
                      insert-cols))
           (query (format #f "INSERT INTO genres (~a) VALUES (~a)"
                          insert-cols-sql
                          (string-join vals ", "))))
      (execute-write "insert-genre" query)))

  (mk-genre-repository #:get-genre-by-id-proc get-genre-by-id
                       #:get-genres-by-ids-proc get-genres-by-ids
                       #:get-genres-proc get-genres
                       #:search-genres-proc search-genres
                       #:insert-genre-proc insert-genre
                       #:delete-genre-by-id-proc delete-genre-by-id
                       #:update-genre-by-id-proc update-genre-by-id))
