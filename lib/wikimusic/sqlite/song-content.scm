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

(define-module (wikimusic sqlite song-content)
  #:declarative? #t
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain song-content)
  #:export (make-sqlite-song-content-repository))

;; --- SQLite implementation ---
(define (make-sqlite-song-content-repository rc)
  (define columns
    '(identifier song-identifier
                 version-name
                 created-by
                 visibility-status
                 approved-by
                 instrument-type
                 ascii-legend
                 ascii-contents
                 pdf-contents
                 guitarpro-contents
                 created-at
                 last-edited-at))

  (define conn
    (DB-open rc))

  (define execute-write
    (db-write conn))

  (define execute-read
    (db-read conn))

  (define* (get-song-contents-by-ids ids
                                     #:key (order-by '((version-name desc))))
    (execute-read "get-song-contents-by-ids"
                  (sql-select 'song_contents
                              #:columns columns
                              #:where (list (list 'identifier
                                                  'in ids))
                              #:order-by order-by)))

  (define* (get-song-contents-by-song-ids ids
                                          #:key (order-by '((version-name desc))))
    (execute-read "get-song-contents-by-song-ids"
                  (sql-select 'song_contents
                              #:columns columns
                              #:where (list (list 'song-identifier
                                                  'in ids))
                              #:order-by order-by)))

  (define (get-song-content-ids-by-song-ids ids)
    (execute-read "get-song-content-ids-by-song-ids"
                  (sql-select 'song_contents
                              #:columns '(identifier song-identifier)
                              #:where (list (list 'song-identifier
                                                  'in ids)))))

  (define (update-song-content-by-id id attrs)
    (execute-write "update-song-content-by-id"
                   (sql-update 'song_contents
                               (attrs->row attrs columns)
                               #:where (list (cons 'identifier id)))))

  (define (delete-song-content-by-id id)
    (execute-write "delete-song-content-by-id"
                   (sql-delete 'song_contents
                               #:where (list (cons 'identifier id)))))

  (define (insert-song-content attrs)
    (execute-write "insert-song-content"
                   (sql-insert 'song_contents
                               (attrs->row attrs columns))))

  (mk-song-content-repository #:get-song-contents-by-song-ids-proc
                              get-song-contents-by-song-ids
                              #:get-song-contents-by-ids-proc
                              get-song-contents-by-ids
                              #:get-song-content-ids-by-song-ids-proc
                              get-song-content-ids-by-song-ids
                              #:insert-song-content-proc insert-song-content
                              #:delete-song-content-by-id-proc
                              delete-song-content-by-id
                              #:update-song-content-by-id-proc
                              update-song-content-by-id))
