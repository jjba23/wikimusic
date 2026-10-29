;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (wikimusic sqlite genre)
  #:declarative? #t
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain genre)
  #:export (make-sqlite-genre-repository))

;; --- SQLite implementation ---
(define (make-sqlite-genre-repository rc)
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

  (define (get-genre-by-id id)
    (let ((rows (execute-read "get-genre-by-id"
                              (sql-select 'genres
                                          #:columns columns
                                          #:where (list (cons 'identifier id))
                                          #:limit 1))))
      (if (nil? rows) #f
          (car rows))))

  (define (get-genres-by-ids ids)
    (execute-read "get-genres-by-ids"
                  (sql-select 'genres
                              #:columns columns
                              #:where (list (list 'identifier
                                                  'in ids)))))

  (define* (get-genres #:key (order-by '((created-at desc)))
                       (limit 100)
                       (offset 0))
    (execute-read "get-genres"
                  (sql-select 'genres
                              #:columns columns
                              #:order-by order-by
                              #:limit limit
                              #:offset offset)))

  ;; The one statement kracht's builders cannot write: a search matches the
  ;; term against either of two columns, and kracht joins its conditions with
  ;; `AND' only.  It is still kracht that owns it -- `sql-parameterize' is
  ;; kracht's own escape hatch -- and the columns and the sort come from
  ;; kracht's helpers, so only the `OR' itself is spelled here.
  (define* (search-genres s
                          #:key (order-by '((created-at desc)))
                          (limit 100)
                          (offset 0))
    (let ((search (format #f "%~a%" s)))
      (execute-read "search-genres"
                    (sql-parameterize (format #f
                                       "SELECT ~a FROM genres WHERE (display_name LIKE ? OR description LIKE ?) ORDER BY ~a LIMIT ? OFFSET ?"
                                       (symbols->sql-columns-list columns)
                                       (sql-order-by-sql order-by))
                                      (list search search limit offset)))))

  ;; A count is a statement kracht's `sql-select' cannot express -- it takes
  ;; column names, and `COUNT(*)' is not a column -- so `sql-parameterize',
  ;; kracht's own escape hatch, carries it.  The `WHERE' is the same one
  ;; `search-genres' uses, so a page count and a page of hits always agree.
  (define* (count-genres #:key search)
    (let* ((term (and search
                      (format #f "%~a%" search)))
           (rows (if term
                     (execute-read "count-genres"
                                   (sql-parameterize
                                    "SELECT COUNT(*) AS count FROM genres WHERE (display_name LIKE ? OR description LIKE ?)"
                                    (list term term)))
                     (execute-read "count-genres"
                                   (sql-parameterize
                                    "SELECT COUNT(*) AS count FROM genres"
                                    '())))))
      (if (nil? rows) 0
          (or (assq-ref (car rows)
                        'count) 0))))

  (define (update-genre-by-id id attrs)
    (execute-write "update-genre-by-id"
                   (sql-update 'genres
                               (attrs->row attrs columns)
                               #:where (list (cons 'identifier id)))))

  (define (delete-genre-by-id id)
    (execute-write "delete-genre-by-id"
                   (sql-delete 'genres
                               #:where (list (cons 'identifier id)))))

  (define (insert-genre attrs)
    (execute-write "insert-genre"
                   (sql-insert 'genres
                               (attrs->row attrs columns))))

  (mk-genre-repository #:get-genre-by-id-proc get-genre-by-id
                       #:get-genres-by-ids-proc get-genres-by-ids
                       #:get-genres-proc get-genres
                       #:count-genres-proc count-genres
                       #:search-genres-proc search-genres
                       #:insert-genre-proc insert-genre
                       #:delete-genre-by-id-proc delete-genre-by-id
                       #:update-genre-by-id-proc update-genre-by-id))
