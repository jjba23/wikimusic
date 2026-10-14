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
  #:use-module (srfi srfi-1)
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

  (define conn
    (DB-open rc))

  (define execute-write
    (db-write conn))

  (define execute-read
    (db-read conn))

  (define (get-artist-by-id id)
    (let ((rows (execute-read "get-artist-by-id"
                              (sql-select 'artists
                                          #:columns columns
                                          #:where (list (cons 'identifier id))
                                          #:limit 1))))
      (if (nil? rows) #f
          (car rows))))

  (define* (get-artists #:key (order-by '((created-at desc)))
                        (limit 100)
                        (offset 0))
    (execute-read "get-artists"
                  (sql-select 'artists
                              #:columns columns
                              #:order-by order-by
                              #:limit limit
                              #:offset offset)))

  ;; The one statement kracht's builders cannot write: a search matches the
  ;; term against either of two columns, and kracht joins its conditions with
  ;; `AND' only.  It is still kracht that owns it -- `sql-parameterize' is
  ;; kracht's own escape hatch -- and the columns and the sort come from
  ;; kracht's helpers, so only the `OR' itself is spelled here.
  (define* (search-artists s
                           #:key (order-by '((created-at desc)))
                           (limit 100)
                           (offset 0))
    (let ((search (format #f "%~a%" s)))
      (execute-read "search-artists"
                    (sql-parameterize (format #f
                                       "SELECT ~a FROM artists WHERE (display_name LIKE ? OR description LIKE ?) ORDER BY ~a LIMIT ? OFFSET ?"
                                       (symbols->sql-columns-list columns)
                                       (sql-order-by-sql order-by))
                                      (list search search limit offset)))))

  (define (get-artists-by-ids ids)
    (execute-read "get-artists-by-ids"
                  (sql-select 'artists
                              #:columns columns
                              #:where (list (list 'identifier
                                                  'in ids)))))

  ;; A count is a statement kracht's `sql-select' cannot express -- it takes
  ;; column names, and `COUNT(*)' is not a column -- so `sql-parameterize',
  ;; kracht's own escape hatch, carries it.  The `WHERE' is the same one
  ;; `search-artists' uses, so a page count and a page of hits always agree.
  (define* (count-artists #:key search)
    (let* ((term (and search
                      (format #f "%~a%" search)))
           (rows (if term
                     (execute-read "count-artists"
                                   (sql-parameterize
                                    "SELECT COUNT(*) AS count FROM artists WHERE (display_name LIKE ? OR description LIKE ?)"
                                    (list term term)))
                     (execute-read "count-artists"
                                   (sql-parameterize
                                    "SELECT COUNT(*) AS count FROM artists"
                                    '())))))
      (if (nil? rows) 0
          (or (assq-ref (car rows)
                        'count) 0))))

  (define (update-artist-by-id id attrs)
    (execute-write "update-artist-by-id"
                   (sql-update 'artists
                               (attrs->row attrs columns)
                               #:where (list (cons 'identifier id)))))

  (define (delete-artist-by-id id)
    (execute-write "delete-artist-by-id"
                   (sql-delete 'artists
                               #:where (list (cons 'identifier id)))))

  (define (insert-artist attrs)
    (execute-write "insert-artist"
                   (sql-insert 'artists
                               (attrs->row attrs columns))))

  (mk-artist-repository #:get-artist-by-id-proc get-artist-by-id
                        #:get-artists-by-ids-proc get-artists-by-ids
                        #:get-artists-proc get-artists
                        #:count-artists-proc count-artists
                        #:search-artists-proc search-artists
                        #:insert-artist-proc insert-artist
                        #:delete-artist-by-id-proc delete-artist-by-id
                        #:update-artist-by-id-proc update-artist-by-id))
