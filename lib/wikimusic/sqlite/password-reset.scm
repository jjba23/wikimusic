;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (wikimusic sqlite password-reset)
  #:declarative? #t
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain password-reset)
  #:export (make-sqlite-password-reset-repository))

;; --- SQLite implementation ---
(define (make-sqlite-password-reset-repository rc)
  (define columns
    '(user-id reset-token created-at))

  (define conn
    (DB-open rc))

  (define execute-write
    (db-write conn))

  (define execute-read
    (db-read conn))

  (define (get-password-reset-by-token token)
    (let* ((rows (execute-read "get-password-reset-by-token"
                               (sql-select 'password_reset
                                           #:columns columns
                                           #:where (list (cons 'reset-token
                                                               token))
                                           #:limit 1)))
           (mapped-rows (map (lambda (r)
                               (cons (assq-ref r
                                               'reset-token)
                                     (assq-ref r
                                               'user-id))) rows)))
      (if (nil? mapped-rows) #f
          (car mapped-rows))))

  (define (delete-password-reset-by-user-id user-id)
    (execute-write "delete-password-reset-by-user-id"
                   (sql-delete 'password_reset
                               #:where (list (cons 'user-id user-id)))))

  (define (insert-password-reset attrs)
    (execute-write "insert-password-reset"
                   (sql-insert 'password_reset
                               (attrs->row attrs columns))))

  (mk-password-reset-repository #:get-password-reset-by-token-proc
                                get-password-reset-by-token
                                #:delete-password-reset-by-user-id-proc
                                delete-password-reset-by-user-id
                                #:insert-password-reset-proc
                                insert-password-reset))
