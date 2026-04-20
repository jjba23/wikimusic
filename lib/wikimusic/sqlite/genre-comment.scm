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

(define-module (wikimusic sqlite genre-comment)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain genre-comment)
  #:export (make-sqlite-genre-comment-repository))

;; --- SQLite implementation ---
(define (make-sqlite-genre-comment-repository rc)
  (define columns
    '(identifier parent-identifier genre-identifier
                 created-by
                 visibility-status
                 contents
                 approved-by
                 created-at
                 last-edited-at))

  (define insert-columns
    '(identifier parent-identifier genre-identifier
                 created-by
                 visibility-status
                 contents
                 approved-by
                 created-at))

  (define conn
    (DB-open rc))

  (define (get-genre-comments-by-genre-ids ids)
    (let* ((query (format #f
                   "SELECT ~a FROM genre_comments WHERE genre_identifier IN(~a)"
                   (symbols->sql-columns-list columns)
                   (string-join (map value->sql-literal ids) ", ")))
           (_ (log-info "get-genre-comments-by-genre-ids query:\n\t~a\n" query))
           (rows (map sql-row->scheme-alist
                      (DB-get-all-rows (DB-query conn query))))
           (_ (log-info "get-genre-comments-by-genre-ids rows: ~a\n"
                        (length rows))))
      rows))

  (define (update-genre-comment-by-id id attrs)
    (let* ((query (format #f
                   "UPDATE genre_comments SET ~a WHERE identifier = ~a"
                   (string-join (map pair->sql-assignment attrs) ", ")
                   (value->sql-literal id)))
           (_ (log-info "update-genre-comment-by-id query:\n\t~a\n" query)))
      (DB-query conn query)))

  (define (delete-genre-comment-by-id id)
    (let* ((query (format #f
                          "DELETE FROM genre-comments WHERE identifier = ~a"
                          (value->sql-literal id)))
           (_ (log-info "delete-genre-comment-by-id query:\n\t~a\n" query)))
      (DB-query conn query)))

  (define (insert-genre-comment attrs)
    (let* ((vals (map (lambda (x)
                        (value->sql-literal (assq-ref attrs x)))
                      insert-columns))
           (query (format #f "INSERT INTO genre_comments (~a) VALUES (~a)"
                          (symbols->sql-columns-list insert-columns)
                          (string-join vals ", ")))
           (_ (log-info "insert-genre-comment query:\n\t~a\n" query)))
      (DB-query conn query)))

  (mk-genre-comment-repository #:get-genre-comments-by-genre-ids-proc
                                get-genre-comments-by-genre-ids
                                #:insert-genre-comment-proc
                                insert-genre-comment
                                #:delete-genre-comment-by-id-proc
                                delete-genre-comment-by-id))
