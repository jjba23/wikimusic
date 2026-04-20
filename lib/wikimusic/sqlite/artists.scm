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

(define-module (wikimusic sqlite artist)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain artist)
  #:export (make-sqlite-artist-repository))

;; --- SQLite implementation ---
(define (make-sqlite-artist-repository rc)
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

  (define (get-artist-by-id id)
    (let* ((query (format #f
                   "SELECT ~a FROM artists WHERE identifier = ~a LIMIT 1"
                   (symbols->sql-columns-list columns)
                   (value->sql-literal id)))
           (_ (log-info "get-artist-by-id query:\n\t~a\n" query))
           (rows (map sql-row->scheme-alist
                      (DB-get-all-rows (DB-query conn query))))
           (_ (log-info "get-artist-by-id rows: ~a\n"
                        (length rows))))
      (if (nil? rows) #f
          (car rows))))

  (define (get-artists)
    (let* ((query (format #f "SELECT ~a FROM artists
                   ORDER BY display_name ASC"
                          (symbols->sql-columns-list columns)))
           (_ (log-info "get-artists query:\n\t~a\n" query))
           (rows (map sql-row->scheme-alist
                      (DB-get-all-rows (DB-query conn query))))
           (_ (log-info "get-artists rows: ~a\n"
                        (length rows))))
      rows))

  (define (update-artist-by-id id attrs)
    (let* ((query (format #f "UPDATE artist SET ~a WHERE identifier = ~a"
                          (string-join (map pair->sql-assignment attrs) ", ")
                          (value->sql-literal id)))
           (_ (log-info "update-artist-by-id query:\n\t~a\n" query)))
      (DB-query conn query)))

  (define (delete-artist-by-id id)
    (let* ((query (format #f "DELETE FROM artists WHERE identifier = ~a"
                          (value->sql-literal id)))
           (_ (log-info "delete-artist-by-id query:\n\t~a\n" query)))
      (DB-query conn query)))

  (define (insert-artist attrs)
    (let* ((vals (map (lambda (x)
                        (value->sql-literal (assq-ref attrs x)))
                      insert-columns))
           (query (format #f "INSERT INTO artist (~a) VALUES (~a)"
                          (symbols->sql-columns-list insert-columns)
                          (string-join vals ", ")))
           (_ (log-info "insert-artist query:\n\t~a\n" query)))
      (DB-query conn query)))

  (mk-artist-repository #:get-artist-by-id-proc get-artist-by-id
                        #:get-artists-proc get-artists
                        #:insert-artist-proc insert-artist
                        #:delete-artist-by-id-proc delete-artist-by-id
                        #:update-artist-by-id-proc update-artist-by-id))
