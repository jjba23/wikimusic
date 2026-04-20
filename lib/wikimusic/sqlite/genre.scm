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

  (define insert-columns
    '(identifier display-name
                 created-by
                 visibility-status
                 approved-by
                 created-at
                 last-edited-at
                 views
                 description))

  (define conn (DB-open rc))

  (define (get-genre-by-id id)
    (let* ((query (format #f
                   "SELECT ~a FROM genres WHERE identifier = ~a LIMIT 1"
                   (symbols->sql-columns-list columns)
                   (value->sql-literal id)))
           (_ (log-info "get-genre-by-id query:\n\t~a\n" query))
           (rows (map sql-row->scheme-alist
                      (DB-get-all-rows (DB-query conn query))))
           (_ (log-info "get-genre-by-id rows: ~a\n"
                        (length rows))))
      (if (nil? rows) #f
          (car rows))))

      (define (get-genres-by-ids ids)
    (let* ((query (format #f "SELECT ~a FROM genres WHERE identifier IN(~a)"
                          (symbols->sql-columns-list columns)
                          (string-join (map value->sql-literal ids) ", ")))
           (_ (log-info "get-genres-by-ids query:\n\t~a\n" query))
           (rows (map sql-row->scheme-alist
                      (DB-get-all-rows (DB-query conn query))))
           (_ (log-info "get-genres-by-ids rows: ~a\n"
                        (length rows))))
      rows))

  (define (get-genres)
    (let* ((query (format #f "SELECT ~a FROM genres
                   ORDER BY display_name ASC"
                          (symbols->sql-columns-list columns)))
           (_ (log-info "get-genres query:\n\t~a\n" query))
           (rows (map sql-row->scheme-alist
                      (DB-get-all-rows (DB-query conn query))))
           (_ (log-info "get-genres rows: ~a\n"
                        (length rows))))
      rows))

  (define (update-genre-by-id id attrs)
    (let* ((query (format #f "UPDATE genres SET ~a WHERE identifier = ~a"
                          (string-join (map pair->sql-assignment attrs) ", ")
                          (value->sql-literal id)))
           (_ (log-info "update-genre-by-id query:\n\t~a\n" query)))
      (DB-query conn query)))

  (define (delete-genre-by-id id)
    (let* ((query (format #f "DELETE FROM genres WHERE identifier = ~a"
                          (value->sql-literal id)))
           (_ (log-info "delete-genre-by-id query:\n\t~a\n" query)))
      (DB-query conn query)))

  (define (insert-genre attrs)
    (let* ((vals (map (lambda (x)
                        (value->sql-literal (assq-ref attrs x)))
                      insert-columns))
           (query (format #f "INSERT INTO genres (~a) VALUES (~a)"
                          (symbols->sql-columns-list insert-columns)
                          (string-join vals ", ")))
           (_ (log-info "insert-genre query:\n\t~a\n" query)))
      (DB-query conn query)))

  (mk-genre-repository #:get-genre-by-id-proc get-genre-by-id
                       #:get-genres-by-ids-proc get-genres-by-ids
                        #:get-genres-proc get-genres
                        #:insert-genre-proc insert-genre
                        #:delete-genre-by-id-proc delete-genre-by-id
                        #:update-genre-by-id-proc update-genre-by-id))
