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
  (define columns
    '(identifier parent-identifier 
                 created-by
                 visibility-status
                 contents
                 approved-by
                 created-at
                 last-edited-at))

  (define insert-columns
    '(identifier parent-identifier 
                 created-by
                 visibility-status
                 contents
                 approved-by
                 created-at))

  (define conn
    (DB-open rc))

  (define (get-comments-by-entity-ids entity ids)
    (let* ((query (format #f
                   "SELECT ~a FROM genre_comments WHERE genre_identifier IN(~a)"
                   (symbols->sql-columns-list columns)
                   (string-join (map value->sql-literal ids) ", ")))
           (_ (log-info "get-comments-by-ids query:\n\t~a\n" query))
           (rows (map sql-row->scheme-alist
                      (DB-get-all-rows (DB-query conn query))))
           (_ (log-info "get-comments-by-ids rows: ~a\n"
                        (length rows))))
      rows))

  (define (update-comment-by-id entity id attrs)
    (let* ((query (format #f
                   "UPDATE genre_comments SET ~a WHERE identifier = ~a"
                   (string-join (map pair->sql-assignment attrs) ", ")
                   (value->sql-literal id)))
           (_ (log-info "update-comment-by-id query:\n\t~a\n" query)))
      (DB-query conn query)))

  (define (delete-comment-by-id entity id)
    (let* ((query (format #f
                          "DELETE FROM comments WHERE identifier = ~a"
                          (value->sql-literal id)))
           (_ (log-info "delete-comment-by-id query:\n\t~a\n" query)))
      (DB-query conn query)))

  (define (insert-comment entity attrs)
    (let* ((vals (map (lambda (x)
                        (value->sql-literal (assq-ref attrs x)))
                      insert-columns))
           (query (format #f "INSERT INTO genre_comments (~a) VALUES (~a)"
                          (symbols->sql-columns-list insert-columns)
                          (string-join vals ", ")))
           (_ (log-info "insert-comment query:\n\t~a\n" query)))
      (DB-query conn query)))

  (mk-comment-repository #:get-comments-by-entity-ids-proc
                                get-comments-by-entity-ids
                                #:insert-comment-proc
                                insert-comment
                                #:delete-comment-by-id-proc
                                delete-comment-by-id))
