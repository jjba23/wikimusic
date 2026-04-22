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

(define-module (wikimusic sqlite user)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain user)
  #:export (make-sqlite-user-repository))

;; --- SQLite implementation ---
(define (make-sqlite-user-repository rc)
  (define columns
    '(identifier username email password salt permissions))

  (define cols-sql
    (symbols->sql-columns-list columns))

  (define insert-columns
    (delq 'last-edited-at columns))

  (define insert-cols-sql
    (symbols->sql-columns-list insert-columns))

  (define conn
    (DB-open rc))

  (define execute-write
    (db-write conn))

  (define execute-read
    (db-read conn))

  (define (get-id-to-username)
    (let* ((query (format #f "SELECT ~a FROM users
                   ORDER BY username ASC"
                          cols-sql))
           (rows (execute-read "get-id-to-username" query))
           (mapped-rows (map (lambda (r)
                               (cons (assq-ref r
                                               'id)
                                     (assq-ref r
                                               'username))) rows)))
      mapped-rows))

  (define (get-user-by-email email)
    (let* ((query (format #f "SELECT ~a FROM users WHERE email = ~a LIMIT 1"
                          cols-sql
                          (value->sql-literal email)))
           (rows (execute-read "get-user-by-email" query)))
      (if (nil? rows) #f
          (car rows))))

  (define (get-user-by-id id)
    (let* ((query (format #f
                   "SELECT ~a FROM users WHERE identifier = ~a LIMIT 1"
                   cols-sql
                   (value->sql-literal id)))
           (rows (execute-read "get-user-by-id" query)))
      (if (nil? rows) #f
          (car rows))))

  (define (get-users)
    (let* ((query (format #f "SELECT ~a FROM users
                   ORDER BY username ASC"
                          cols-sql)))
      (execute-read "get-users" query)))

  (define (update-user-by-id id attrs)
    (let* ((query (format #f "UPDATE users SET ~a WHERE identifier = ~a"
                          (string-join (map pair->sql-assignment attrs) ", ")
                          (value->sql-literal id))))
      (execute-write "update-user-by-id" query)))

  (define (delete-user-by-id id)
    (let* ((query (format #f "DELETE FROM users WHERE identifier = ~a"
                          (value->sql-literal id))))
      (execute-write "delete-user-by-id" query)))

  (define (insert-user attrs)
    (let* ((vals (map (lambda (x)
                        (value->sql-literal (assq-ref attrs x)))
                      insert-columns))
           (query (format #f "INSERT INTO users (~a) VALUES (~a)"
                          insert-cols-sql
                          (string-join vals ", "))))
      (execute-write query)))

  (mk-user-repository #:get-id-to-username-proc get-id-to-username
                      #:get-user-by-email-proc get-user-by-email
                      #:get-user-by-id-proc get-user-by-id
                      #:get-users-proc get-users
                      #:insert-user-proc insert-user
                      #:delete-user-by-id-proc delete-user-by-id
                      #:update-user-by-id-proc update-user-by-id))
