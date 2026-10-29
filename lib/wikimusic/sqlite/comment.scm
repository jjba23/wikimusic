;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (wikimusic sqlite comment)
  #:declarative? #t
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain comment)
  #:export (make-sqlite-comment-repository))

;; --- SQLite implementation ---
(define (make-sqlite-comment-repository rc)
  (define (table entity)
    (format #f "~a_comments" entity))

  (define (entity-column entity)
    (string->symbol (format #f "~a-identifier" entity)))

  (define (columns entity)
    (append (list (entity-column entity))
            '(identifier parent-identifier
                         created-by
                         visibility-status
                         approved-by
                         contents
                         created-at)))

  (define conn
    (DB-open rc))

  (define execute-write
    (db-write conn))

  (define execute-read
    (db-read conn))

  (define* (get-comments-by-entity-ids entity ids
                                       #:key (order-by '((created-at desc))))
    (execute-read "get-comments-by-entity-ids"
                  (sql-select (table entity)
                              #:columns (columns entity)
                              #:where (list (list (entity-column entity)
                                                  'in ids))
                              #:order-by order-by)))

  (define* (get-comment-by-id entity id)
    (let ((rows (execute-read "get-comment-by-id"
                              (sql-select (table entity)
                                          #:columns (columns entity)
                                          #:where (list (cons 'identifier id))
                                          #:limit 1))))
      (if (nil? rows) #f
          (car rows))))

  (define (update-comment-by-id entity id attrs)
    (execute-write "update-comment-by-id"
                   (sql-update (table entity)
                               (attrs->row attrs
                                           (columns entity))
                               #:where (list (cons 'identifier id)))))

  (define (delete-comment-by-id entity id)
    (execute-write "delete-comment-by-id"
                   (sql-delete (table entity)
                               #:where (list (cons 'identifier id)))))

  (define (insert-comment entity attrs)
    (execute-write "insert-comment"
                   (sql-insert (table entity)
                               (attrs->row attrs
                                           (columns entity)))))

  (mk-comment-repository #:get-comments-by-entity-ids-proc
                         get-comments-by-entity-ids
                         #:get-comment-by-id-proc get-comment-by-id
                         #:update-comment-by-id-proc update-comment-by-id
                         #:insert-comment-proc insert-comment
                         #:delete-comment-by-id-proc delete-comment-by-id))
