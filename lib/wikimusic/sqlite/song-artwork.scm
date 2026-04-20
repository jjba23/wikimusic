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

(define-module (wikimusic sqlite song-artwork)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain song-artwork)
  #:export (make-sqlite-song-artwork-repository))

;; --- SQLite implementation ---
(define (make-sqlite-song-artwork-repository rc)
  (define columns
    '(identifier song-identifier
                 created-by
                 visibility-status
                 approved-by
                 content-url
                 content-caption
                 order-value
                 created-at
                 last-edited-at))

  (define insert-columns
    '(identifier song-identifier
                 created-by
                 visibility-status
                 approved-by
                 content-url
                 content-caption
                 order-value
                 created-at))

  (define conn
    (DB-open rc))

  (define (get-song-artworks-by-song-ids ids)
    (let* ((query (format #f
                   "SELECT ~a FROM song_artworks WHERE song_identifier IN(~a)"
                   (symbols->sql-columns-list columns)
                   (string-join (map value->sql-literal ids) ", ")))
           (_ (log-info "get-song-artworks-by-song-ids query:\n\t~a\n" query))
           (rows (map sql-row->scheme-alist
                      (DB-get-all-rows (DB-query conn query))))
           (_ (log-info "get-song-artworks-by-song-ids rows: ~a\n"
                        (length rows))))
      rows))

  (define (update-song-artwork-by-id id attrs)
    (let* ((query (format #f
                   "UPDATE song_artworks SET ~a WHERE identifier = ~a"
                   (string-join (map pair->sql-assignment attrs) ", ")
                   (value->sql-literal id)))
           (_ (log-info "update-song-artwork-by-id query:\n\t~a\n" query)))
      (DB-query conn query)))

  (define (delete-song-artwork-by-id id)
    (let* ((query (format #f
                          "DELETE FROM song-artworks WHERE identifier = ~a"
                          (value->sql-literal id)))
           (_ (log-info "delete-song-artwork-by-id query:\n\t~a\n" query)))
      (DB-query conn query)))

  (define (insert-song-artwork attrs)
    (let* ((vals (map (lambda (x)
                        (value->sql-literal (assq-ref attrs x)))
                      insert-columns))
           (query (format #f "INSERT INTO song_artworks (~a) VALUES (~a)"
                          (symbols->sql-columns-list insert-columns)
                          (string-join vals ", ")))
           (_ (log-info "insert-song-artwork query:\n\t~a\n" query)))
      (DB-query conn query)))

  (mk-song-artwork-repository #:get-song-artworks-by-song-ids-proc
                                get-song-artworks-by-song-ids
                                #:insert-song-artwork-proc
                                insert-song-artwork
                                #:delete-song-artwork-by-id-proc
                                delete-song-artwork-by-id))
