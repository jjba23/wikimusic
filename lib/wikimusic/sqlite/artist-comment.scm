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

(define-module (wikimusic sqlite artist-comment)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain artist-comment)
  #:export (make-sqlite-artist-comment-repository))

;; --- SQLite implementation ---
(define (make-sqlite-artist-comment-repository rc)
  (define columns
    '(identifier parent-identifier artist-identifier
                 created-by
                 visibility-status
                 contents
                 approved-by
                 created-at
                 last-edited-at))

  (define insert-columns
    '(identifier parent-identifier artist-identifier
                 created-by
                 visibility-status
                 contents
                 approved-by
                 created-at))

  (define conn
    (DB-open rc))

  (define (get-artist-comments-by-artist-ids ids)
    (let* ((query (format #f
                   "SELECT ~a FROM artist_comments WHERE artist_identifier IN(~a)"
                   (symbols->sql-columns-list columns)
                   (string-join (map value->sql-literal ids) ", ")))
           (_ (log-info "get-artist-comments-by-artist-ids query:\n\t~a\n" query))
           (rows (map sql-row->scheme-alist
                      (DB-get-all-rows (DB-query conn query))))
           (_ (log-info "get-artist-comments-by-artist-ids rows: ~a\n"
                        (length rows))))
      rows))

  (define (update-artist-comment-by-id id attrs)
    (let* ((query (format #f
                   "UPDATE artist_comments SET ~a WHERE identifier = ~a"
                   (string-join (map pair->sql-assignment attrs) ", ")
                   (value->sql-literal id)))
           (_ (log-info "update-artist-comment-by-id query:\n\t~a\n" query)))
      (DB-query conn query)))

  (define (delete-artist-comment-by-id id)
    (let* ((query (format #f
                          "DELETE FROM artist-comments WHERE identifier = ~a"
                          (value->sql-literal id)))
           (_ (log-info "delete-artist-comment-by-id query:\n\t~a\n" query)))
      (DB-query conn query)))

  (define (insert-artist-comment attrs)
    (let* ((vals (map (lambda (x)
                        (value->sql-literal (assq-ref attrs x)))
                      insert-columns))
           (query (format #f "INSERT INTO artist_comments (~a) VALUES (~a)"
                          (symbols->sql-columns-list insert-columns)
                          (string-join vals ", ")))
           (_ (log-info "insert-artist-comment query:\n\t~a\n" query)))
      (DB-query conn query)))

  (mk-artist-comment-repository #:get-artist-comments-by-artist-ids-proc
                                get-artist-comments-by-artist-ids
                                #:insert-artist-comment-proc
                                insert-artist-comment
                                #:delete-artist-comment-by-id-proc
                                delete-artist-comment-by-id))
