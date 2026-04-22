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

(define-module (wikimusic sqlite song-content)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain song-content)
  #:export (make-sqlite-song-content-repository))

;; --- SQLite implementation ---
(define (make-sqlite-song-content-repository rc)
  (define columns
    '(identifier song-identifier
                 version-name
                 created-by
                 visibility-status
                 approved-by
                 instrument-type
                 ascii-legend
                 ascii-contents
                 pdf-contents
                 guitarpro-contents
                 created-at
                 last-edited-at))

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

  (define (get-song-contents-by-song-ids ids)
    (let* ((query (format #f
                   "SELECT ~a FROM song_contents WHERE song_identifier IN(~a)
                            ORDER BY version_name DESC"
                   cols-sql
                   (string-join (map value->sql-literal ids) ", "))))
      (execute-read "get-song-contents-by-song-ids" query)))

  (define (get-song-content-ids-by-song-ids ids)
    (let* ((query (format #f
                   "SELECT identifier, song_identifier FROM song_contents WHERE song_identifier IN(~a)"
                   cols-sql
                   (string-join (map value->sql-literal ids) ", "))))
      (execute-read "get-song-content-ids-by-song-ids" query)))

  (define (update-song-content-by-id id attrs)
    (let* ((query (format #f
                          "UPDATE song_contents SET ~a WHERE identifier = ~a"
                          (string-join (map pair->sql-assignment attrs) ", ")
                          (value->sql-literal id))))
      (execute-write "update-song-content-by-id" query)))

  (define (delete-song-content-by-id id)
    (let* ((query (format #f "DELETE FROM song_contents WHERE identifier = ~a"
                          (value->sql-literal id))))
      (execute-write "delete-song-content-by-id" query)))

  (define (insert-song-content attrs)
    (let* ((vals (map (lambda (x)
                        (value->sql-literal (assq-ref attrs x)))
                      insert-columns))
           (query (format #f "INSERT INTO song_contents (~a) VALUES (~a)"
                          insert-cols-sql
                          (string-join vals ", "))))
      (execute-write "insert-song-content" query)))

  (mk-song-content-repository #:get-song-contents-by-song-ids-proc
                              get-song-contents-by-song-ids
                              #:get-song-content-ids-by-song-ids-proc
                              get-song-content-ids-by-song-ids
                              #:insert-song-content-proc insert-song-content
                              #:delete-song-content-by-id-proc
                              delete-song-content-by-id
                              #:update-song-content-by-id-proc
                              update-song-content-by-id))
