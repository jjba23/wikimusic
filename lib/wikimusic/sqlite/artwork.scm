;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (wikimusic sqlite artwork)
  #:declarative? #t
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain artwork)
  #:export (make-sqlite-artwork-repository))

;; --- SQLite implementation ---
(define (make-sqlite-artwork-repository rc)
  ;; Every entity keeps its artworks in a table of its own, so a repository is
  ;; asked about one entity and the table name follows from it.  It is always
  ;; one of wikimusic's own names -- never a request value -- and kracht quotes
  ;; it as an identifier either way.
  (define (table entity)
    (format #f "~a_artworks" entity))

  (define (columns entity)
    (append (list (string->symbol (format #f "~a-identifier" entity)))
            '(identifier created-by
                         visibility-status
                         approved-by
                         content-url
                         content-caption
                         order-value
                         created-at
                         last-edited-at)))

  (define conn
    (DB-open rc))

  (define execute-write
    (db-write conn))

  (define execute-read
    (db-read conn))

  (define* (get-artworks-by-entity-ids entity ids
                                       #:key (order-by '((order-value asc))))
    (execute-read "get-artworks-by-entity-ids"
                  (sql-select (table entity)
                              #:columns (columns entity)
                              #:where (list (list (string->symbol (format #f
                                                                   "~a-identifier"
                                                                   entity))
                                                  'in ids))
                              #:order-by order-by)))

  (define (update-artwork-by-id entity id attrs)
    (execute-write "update-artwork-by-id"
                   (sql-update (table entity)
                               (attrs->row attrs
                                           (columns entity))
                               #:where (list (cons 'identifier id)))))

  (define (delete-artwork-by-id entity id)
    (execute-write "delete-artwork-by-id"
                   (sql-delete (table entity)
                               #:where (list (cons 'identifier id)))))

  (define (insert-artwork entity attrs)
    (execute-write "insert-artwork"
                   (sql-insert (table entity)
                               (attrs->row attrs
                                           (columns entity)))))

  (mk-artwork-repository #:get-artworks-by-entity-ids-proc
                         get-artworks-by-entity-ids
                         #:insert-artwork-proc insert-artwork
                         #:delete-artwork-by-id-proc delete-artwork-by-id))
