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

(define-module (wikimusic sqlite external-source)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (kracht prelude)
  #:use-module (artanis db)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic domain external-source)
  #:export (make-sqlite-external-source-repository))

;; --- SQLite implementation ---
(define (make-sqlite-external-source-repository rc)
  (define (columns entity)
    (append (list (string->symbol (format #f "~a_identifier" entity)))
            '(identifier created-by
                         spotify_url
                         youtube_url
                         soundcloud_url
                         wikipedia_url
                         created-at
                         last-edited-at)))

  (define (insert-columns entity)
    (append (list (string->symbol (format #f "~a_identifier" entity)))
            '(identifier created-by
                         spotify_url
                         youtube_url
                         soundcloud_url
                         wikipedia_url
                         created-at)))

  (define conn
    (DB-open rc))

  (define (get-external-sources-by-entity-ids entity ids)
    (let* ((query (format #f
                   "SELECT ~a FROM ~a_external_sources WHERE ~a_identifier IN(~a) ORDER BY created_at DESC"
                   (symbols->sql-columns-list (columns entity))
                   entity
                   entity
                   (string-join (map value->sql-literal ids) ", ")))
           (_ (log-info "get-external-sources-by-entity-ids query:
	~a
" query))
           (rows (map sql-row->scheme-alist
                      (DB-get-all-rows (DB-query conn query))))
           (_ (log-info "get-external-sources-by-entity-ids rows: ~a
"
                        (length rows))))
      rows))

  (define (update-external-source-by-id entity id attrs)
    (let* ((query (format #f
                   "UPDATE ~a_external_sources SET ~a WHERE identifier = ~a"
                   entity
                   (string-join (map pair->sql-assignment attrs) ", ")
                   (value->sql-literal id)))
           (_ (log-info "update-external-source-by-id query:\n\t~a\n" query)))
      (DB-query conn query)))

  (define (delete-external-source-by-id entity id)
    (let* ((query (format #f
                   "DELETE FROM ~a_external_sources WHERE identifier = ~a"
                   entity
                   (value->sql-literal id)))
           (_ (log-info "delete-external-source-by-id query:\n\t~a\n" query)))
      (DB-query conn query)))

  (define (insert-external-source entity attrs)
    (let* ((vals (map (lambda (x)
                        (value->sql-literal (assq-ref attrs x)))
                      insert-columns))
           (query (format #f
                          "INSERT INTO ~a_external_sources (~a) VALUES (~a)"
                          entity
                          (symbols->sql-columns-list (insert-columns entity))
                          (string-join vals ", ")))
           (_ (log-info "insert-external-source query:\n\t~a\n" query)))
      (DB-query conn query)))

  (mk-external-source-repository #:get-external-sources-by-entity-ids-proc
                                 get-external-sources-by-entity-ids
                                 #:insert-external-source-proc
                                 insert-external-source
                                 #:delete-external-source-by-id-proc
                                 delete-external-source-by-id))
