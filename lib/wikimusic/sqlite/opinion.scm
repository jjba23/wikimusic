;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (wikimusic sqlite opinion)
  #:declarative? #t
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain opinion)
  #:export (make-sqlite-opinion-repository))

;; --- SQLite implementation ---
(define (make-sqlite-opinion-repository rc)
  (define (table entity)
    (format #f "~a_opinions" entity))

  (define (entity-column entity)
    (string->symbol (format #f "~a-identifier" entity)))

  (define (columns entity)
    (append (list (entity-column entity))
            '(identifier created-by is-like is-dislike created-at
                         last-edited-at)))

  (define conn
    (DB-open rc))

  (define execute-write
    (db-write conn))

  (define execute-read
    (db-read conn))

  (define* (get-opinions-by-entity-ids entity ids
                                       #:key (order-by '((created-at desc))))
    (execute-read "get-opinions-by-entity-ids"
                  (sql-select (table entity)
                              #:columns (columns entity)
                              #:where (list (list (entity-column entity)
                                                  'in ids))
                              #:order-by order-by)))

  (define (update-opinion-by-id entity id attrs)
    (execute-write "update-opinion-by-id"
                   (sql-update (table entity)
                               (attrs->row attrs
                                           (columns entity))
                               #:where (list (cons 'identifier id)))))

  (define (delete-opinion-by-id entity id)
    (execute-write "delete-opinion-by-id"
                   (sql-delete (table entity)
                               #:where (list (cons 'identifier id)))))

  (define (insert-opinion entity attrs)
    (execute-write "insert-opinion"
                   (sql-insert (table entity)
                               (attrs->row attrs
                                           (columns entity)))))

  (mk-opinion-repository #:get-opinions-by-entity-ids-proc
                         get-opinions-by-entity-ids
                         #:insert-opinion-proc insert-opinion
                         #:delete-opinion-by-id-proc delete-opinion-by-id))
