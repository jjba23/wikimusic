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

(define-module (wikimusic sqlite artwork)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain artwork)
  #:export (make-sqlite-artwork-repository))

;; --- SQLite implementation ---
(define (make-sqlite-artwork-repository rc)
  (define (columns entity)
    (append (list (string->symbol (format #f "~a-identifier" entity)))
            '(identifier created-by
                         visibility-status
                         approved-by
                         content-url
                         content-caption
                         order-value
                         created-at
                         last-edited-at)))

  (define (insert-columns entity)
    (delq 'last-edited-at (columns entity)))

  (define conn
    (DB-open rc))

   (define execute-write
    (db-write conn))

  (define execute-select
    (db-select conn))

  (define (get-artworks-by-entity-ids entity ids)
    (let* ((query (format #f
                   "SELECT ~a FROM ~a_artworks WHERE ~a_identifier IN(~a)
                   ORDER BY order_value ASC"
                   (symbols->sql-columns-list (columns entity))
                   entity
                   entity
                   (string-join (map value->sql-literal ids) ", "))))
      (execute-select "get-artworks-by-entity-ids" query)))

  (define (update-artwork-by-id entity id attrs)
    (let* ((query (format #f "UPDATE ~a_artworks SET ~a WHERE identifier = ~a"
                          entity
                          (string-join (map pair->sql-assignment attrs) ", ")
                          (value->sql-literal id))))
      (execute-write "update-artwork-by-id" query)))

  (define (delete-artwork-by-id entity id)
    (let* ((query (format #f "DELETE FROM ~a_artworks WHERE identifier = ~a"
                          entity
                          (value->sql-literal id))))
      (execute-write "delete-artwork-by-id" query)))

  (define (insert-artwork entity attrs)
    (let* ((vals (map (lambda (x)
                        (value->sql-literal (assq-ref attrs x)))
                      (insert-columns entity)))
           (query (format #f "INSERT INTO ~a_artworks (~a) VALUES (~a)" entity
                          (symbols->sql-columns-list (insert-columns entity))
                          (string-join vals ", "))))
      (execute-write "insert-artwork" query)))

  (mk-artwork-repository #:get-artworks-by-entity-ids-proc
                         get-artworks-by-entity-ids
                         #:insert-artwork-proc insert-artwork
                         #:delete-artwork-by-id-proc delete-artwork-by-id))
