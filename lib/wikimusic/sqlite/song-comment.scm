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

(define-module (wikimusic sqlite song-comment)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain song-comment)
  #:export (make-sqlite-song-comment-repository))

;; --- SQLite implementation ---
(define (make-sqlite-song-comment-repository rc)
  (define columns
    '(identifier parent-identifier song-identifier
                 created-by
                 visibility-status
                 contents
                 approved-by
                 created-at
                 last-edited-at))

  (define insert-columns
    '(identifier parent-identifier song-identifier
                 created-by
                 visibility-status
                 contents
                 approved-by
                 created-at
                 ))

  (define conn
    (DB-open rc))

  (define (get-song-comments-by-song-ids ids)
    (let* ((query (format #f
                   "SELECT ~a FROM song_comments WHERE song_identifier IN(~a)"
                   (symbols->sql-columns-list columns)
                   (string-join (map value->sql-literal ids) ", ")))
           (_ (log-info "get-song-comments-by-song-ids query:\n\t~a\n" query))
           (rows (map sql-row->scheme-alist
                      (DB-get-all-rows (DB-query conn query))))
           (_ (log-info "get-song-comments-by-song-ids rows: ~a\n"
                        (length rows))))
      rows))

  (define (update-song-comment-by-id id attrs)
    (let* ((query (format #f
                   "UPDATE song_comments SET ~a WHERE identifier = ~a"
                   (string-join (map pair->sql-assignment attrs) ", ")
                   (value->sql-literal id)))
           (_ (log-info "update-song-comment-by-id query:\n\t~a\n" query)))
      (DB-query conn query)))

  (define (delete-song-comment-by-id id)
    (let* ((query (format #f
                          "DELETE FROM song-comments WHERE identifier = ~a"
                          (value->sql-literal id)))
           (_ (log-info "delete-song-comment-by-id query:\n\t~a\n" query)))
      (DB-query conn query)))

  (define (insert-song-comment attrs)
    (let* ((vals (map (lambda (x)
                        (value->sql-literal (assq-ref attrs x)))
                      insert-columns))
           (query (format #f "INSERT INTO song_comments (~a) VALUES (~a)"
                          (symbols->sql-columns-list insert-columns)
                          (string-join vals ", ")))
           (_ (log-info "insert-song-comment query:\n\t~a\n" query)))
      (DB-query conn query)))

  (mk-song-comment-repository #:get-song-comments-by-song-ids-proc
                                get-song-comments-by-song-ids
                                #:insert-song-comment-proc
                                insert-song-comment
                                #:delete-song-comment-by-id-proc
                                delete-song-comment-by-id))
