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

(define-module (wikimusic sqlite comment)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain comment)
  #:export (make-sqlite-comment-repository))

;; --- SQLite implementation ---
(define (make-sqlite-comment-repository rc)
  (define (columns entity)
    (append (list (string->symbol (format #f "~a-identifier" entity)))
            '(identifier parent-identifier
                         created-by
                         visibility-status
                         approved-by
                         contents
                         created-at)))

  (define (insert-columns entity)
    (delq 'last-edited-at
          (columns entity)))

  (define conn
    (DB-open rc))

  (define execute-write
    (db-write conn))

  (define execute-select
    (db-select conn))

  (define (get-comments-by-entity-ids entity ids)
    (let* ((query (format #f
                   "SELECT ~a FROM ~a_comments WHERE ~a_identifier IN(~a) ORDER BY created_at DESC"
                   (symbols->sql-columns-list (columns entity))
                   entity
                   entity
                   (string-join (map value->sql-literal ids) ", "))))
      (execute-select "get-comments-by-entity-ids" query)))

  (define (update-comment-by-id entity id attrs)
    (let* ((query (format #f "UPDATE ~a_comments SET ~a WHERE identifier = ~a"
                          entity
                          (string-join (map pair->sql-assignment attrs) ", ")
                          (value->sql-literal id))))
      (execute-write "update-comment-by-id" query)))

  (define (delete-comment-by-id entity id)
    (let* ((query (format #f "DELETE FROM ~a_comments WHERE identifier = ~a"
                          entity
                          (value->sql-literal id))))
      (execute-write "delete-comment-by-id" query)))

  (define (insert-comment entity attrs)
    (let* ((vals (map (lambda (x)
                        (value->sql-literal (assq-ref attrs x)))
                      (insert-columns entity)))
           (query (format #f "INSERT INTO ~a_comments (~a) VALUES (~a)" entity
                          (symbols->sql-columns-list (insert-columns entity))
                          (string-join vals ", "))))
      (insert-comment "insert-comment" query)))

  (mk-comment-repository #:get-comments-by-entity-ids-proc
                         get-comments-by-entity-ids
                         #:insert-comment-proc insert-comment
                         #:delete-comment-by-id-proc delete-comment-by-id))
