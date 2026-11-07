;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (wikimusic sqlite article-comment)
  #:declarative? #t
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain article-comment)
  #:export (make-sqlite-article-comment-repository))

;; --- SQLite implementation ---
(define (make-sqlite-article-comment-repository rc)
  (define columns
    '(identifier parent-identifier
                 article-identifier
                 author-name
                 created-by
                 visibility-status
                 approved-by
                 contents
                 created-at
                 last-edited-at))

  (define conn
    (DB-open rc))

  (define execute-write
    (db-write conn))

  (define execute-read
    (db-read conn))

  ;; Oldest first: a thread is read in the order it was written, unlike a list
  ;; of articles, which is read newest first because a reader is catching up.
  (define* (get-article-comments ids
                                 #:key (order-by '((created-at asc))))
    (execute-read "get-article-comments"
                  (sql-select 'article_comments
                              #:columns columns
                              #:where (list (list 'article-identifier
                                                  'in ids))
                              #:order-by order-by)))

  (define (insert-article-comment attrs)
    (execute-write "insert-article-comment"
                   (sql-insert 'article_comments
                               (attrs->row attrs columns))))

  (define (delete-article-comments-for-article article-id)
    (execute-write "delete-article-comments-for-article"
                   (sql-delete 'article_comments
                               #:where (list (cons 'article-identifier
                                                   article-id)))))

  (mk-article-comment-repository #:get-article-comments-proc
                                 get-article-comments
                                 #:insert-article-comment-proc
                                 insert-article-comment
                                 #:delete-article-comments-for-article-proc
                                 delete-article-comments-for-article))
