;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (wikimusic sqlite article)
  #:declarative? #t
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain article)
  #:export (make-sqlite-article-repository))

;; --- SQLite implementation ---
(define (make-sqlite-article-repository rc)
  (define columns
    '(identifier display-name
                 kind
                 video-url
                 contents
                 created-by
                 visibility-status
                 approved-by
                 created-at
                 last-edited-at
                 views))

  (define conn
    (DB-open rc))

  (define execute-write
    (db-write conn))

  (define execute-read
    (db-read conn))

  (define (get-article-by-id id)
    (let ((rows (execute-read "get-article-by-id"
                              (sql-select 'articles
                                          #:columns columns
                                          #:where (list (cons 'identifier id))
                                          #:limit 1))))
      (if (nil? rows) #f
        (car rows))))

  (define* (get-articles #:key (order-by '((created-at desc)))
                         (limit 20)
                         (offset 0))
    (execute-read "get-articles"
                  (sql-select 'articles
                              #:columns columns
                              #:order-by order-by
                              #:limit limit
                              #:offset offset)))

  ;; A count is the one statement kracht's `sql-select' cannot write -- it takes
  ;; column names, and `COUNT(*)' is not a column -- so it goes through
  ;; `sql-parameterize', which carries no values here because nothing in the
  ;; statement is a reader's.
  (define (count-articles)
    (let ((rows (execute-read "count-articles"
                              (sql-parameterize
                               "SELECT COUNT(*) AS count FROM articles"
                               '()))))
      (if (nil? rows) 0
        (or (assq-ref (car rows) 'count) 0))))

  (define (insert-article attrs)
    (execute-write "insert-article"
                   (sql-insert 'articles
                               (attrs->row attrs columns))))

  (define (update-article-by-id id attrs)
    (execute-write "update-article-by-id"
                   (sql-update 'articles
                               (attrs->row attrs columns)
                               #:where (list (cons 'identifier id)))))

  (define (delete-article-by-id id)
    (execute-write "delete-article-by-id"
                   (sql-delete 'articles
                               #:where (list (cons 'identifier id)))))

  (mk-article-repository #:get-articles-proc get-articles
                         #:get-article-by-id-proc get-article-by-id
                         #:count-articles-proc count-articles
                         #:insert-article-proc insert-article
                         #:update-article-by-id-proc update-article-by-id
                         #:delete-article-by-id-proc delete-article-by-id))
