;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (wikimusic sqlite external-source)
  #:declarative? #t
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain external-source)
  #:export (make-sqlite-external-source-repository))

;; --- SQLite implementation ---
(define (make-sqlite-external-source-repository rc)
  (define (table entity)
    (format #f "~a_external_sources" entity))

  (define (entity-column entity)
    (string->symbol (format #f "~a-identifier" entity)))

  (define (columns entity)
    (append (list (entity-column entity))
            '(identifier created-by
                         spotify-url
                         youtube-url
                         soundcloud-url
                         wikipedia-url
                         created-at
                         last-edited-at)))

  (define conn
    (DB-open rc))

  (define execute-write
    (db-write conn))

  (define execute-read
    (db-read conn))

  (define* (get-external-sources-by-entity-ids entity ids
                                               #:key (order-by '((created-at
                                                                  desc))))
    (execute-read "get-external-sources-by-entity-ids"
                  (sql-select (table entity)
                              #:columns (columns entity)
                              #:where (list (list (entity-column entity)
                                                  'in ids))
                              #:order-by order-by)))

  (define (update-external-source-by-id entity id attrs)
    (execute-write "update-external-source-by-id"
                   (sql-update (table entity)
                               (attrs->row attrs
                                           (columns entity))
                               #:where (list (cons 'identifier id)))))

  (define (delete-external-source-by-id entity id)
    (execute-write "delete-external-source-by-id"
                   (sql-delete (table entity)
                               #:where (list (cons 'identifier id)))))

  (define (insert-external-source entity attrs)
    (execute-write "insert-external-source"
                   (sql-insert (table entity)
                               (attrs->row attrs
                                           (columns entity)))))

  (mk-external-source-repository #:get-external-sources-by-entity-ids-proc
                                 get-external-sources-by-entity-ids
                                 #:insert-external-source-proc
                                 insert-external-source
                                 #:delete-external-source-by-id-proc
                                 delete-external-source-by-id))
