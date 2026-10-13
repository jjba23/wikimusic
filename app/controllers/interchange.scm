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

;;; Commentary:
;;;
;;; Moving wikimusic's knowledge out of one instance and into another -- or
;;; onto a disk for safe keeping.  Two views of the same rows are offered.
;;;
;;; `/export/json' is the machine's view: every content table, row by row,
;;; in a shape this controller can read back.  `/export.html' is the reader's
;;; view (`/export/html'): the same rows rendered as one long page a browser
;;; can open with no
;;; server behind it, which is what "offline" and "archival" mean for someone
;;; who is not writing a script.
;;;
;;; `/import/json' is the door back in.  It is the one write here, and it is
;;; gated: a share is a bulk change to the whole database, so only a holder
;;; of `wikimusic:modify-permissions' -- the super grant -- may do it, and it
;;; is never reachable by an anonymous request.  Rows are inserted one at a
;;; time and a row that fails (a foreign key that points at a user this
;;; instance does not have, a primary key that is already taken) is counted
;;; and skipped rather than aborting the whole share, so a partial import is
;;; still a partial success and the answer says which it was.
;;;
;;; The user credentials are deliberately absent.  A share carries what the
;;; wiki knows -- songs, artists, genres, their art, their sources, their
;;; opinions and their comments -- and every row's `created_by' points at a
;;; user identifier that the receiving instance resolves on its own.  A dump
;;; is a link to somebody's account, not a copy of it.

(define-artanis-controller interchange)

(import (wikimusic html)
        (wikimusic auth)
        (wikimusic controller)
        (wikimusic sqlite util)
        (kracht prelude)
        (json)
        (ice-9 iconv)
        (rnrs bytevectors)
        (bewaking bewaking)
        (artanis artanis))

;;; The tables a share carries, in an order that respects the foreign keys
;;; among them: an entity before anything that points at it.  `users' and
;;; `password_reset' are not here, and neither is any table invented later
;;; unless it is added here -- an import only ever writes what this list
;;; names, so a crafted body cannot reach a table of its own choosing.
(define content-tables
  '("artists" "genres"
    "songs"
    "artist_artworks" "genre_artworks" "song_artworks"
    "artist_external_sources" "genre_external_sources"
    "song_external_sources"
    "artist_genres" "song_artists" "song_genres"
    "song_contents"
    "artist_opinions" "genre_opinions" "song_opinions"
    "artist_comments" "genre_comments" "song_comments"))

(define (table-name? name)
  "Return #t when NAME is one of the tables a share may carry."
  (and (member name content-tables) #t))

(define* (read-table rc table)
  "Return every row of TABLE, as a list of association lists.

TABLE is always one of `content-tables', never a request value, so naming it
in the statement is naming a constant."
  (sql-rows rc
            (sql-parameterize (format #f "SELECT * FROM ~a" table) '())
            #:name (format #f "export-~a" table)))

;;; ====== The machine's view ======

(get "/export/json"
     #:mime 'json
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let ((tables (list->vector
                      (map (lambda (table)
                             ;; Vectors, not lists, are what the JSON writer
                             ;; reads as arrays -- a Scheme list in a value
                             ;; position is what it refuses.
                             `((table . ,table)
                               (rows . ,(list->vector
                                         (read-table rc table)))))
                           content-tables))))
         ;; `(:mime rc OBJ)' is returned, not wrapped in `response-emit':
         ;; it answers with two values -- the body and the content-type
         ;; header it must go with -- and `response-emit' would keep only
         ;; the first, serving the dump as text/html.  The route's
         ;; `#:mime 'json' is what serialises OBJ, so the object itself is
         ;; handed over rather than a string it would encode twice.
         (:mime rc `((format . "wikimusic-export")
                     (version . 1)
                     (exported-at . ,(current-time))
                     (tables . ,tables))))))

;;; ====== The reader's view ======

(define* (export-section G_ #:key heading rows)
  "Return one entity's section of the rendered export: a heading and, under
it, one paragraph per row, its name linked to its page and its description
rendered from Org."
  `(section (@ (class "py-4"))
            (h2 ,heading)
            (ul ,@(map (lambda (row)
                         `(li (@ (class "py-2"))
                              (a (@ (href ,(format #f "/~as/uuid/~a"
                                                   (assq-ref row 'entity-name)
                                                   (assq-ref row 'identifier))))
                                 ,(assq-ref row 'display-name))
                              ,(let ((description
                                      (assq-ref row 'description)))
                                 (if (and (string? description)
                                          (not (string=? description "")))
                                     `(div ,(org2html (html-unescape
                                                       description)))
                                     '()))))
                       rows))))

(get "/export/html"
     #:mime 'xml
     #:i18n '(cookie "lang")
     (lambda (rc)
       (let* ((G_ (:i18n rc))
              (with-name (lambda (entity table)
                           (map (lambda (row)
                                  (cons (cons 'entity-name entity) row))
                                (read-table rc table)))))
         (response-emit
          (:mime rc
                 (html-template G_
                   #:title "wikimusic export"
                   ;; The archive is a copy of every page this instance serves,
                   ;; so it is a copy of their content under one address: it is
                   ;; linked from the footer and followed, but the pages
                   ;; themselves are what should answer a search.
                   #:robots "noindex, follow"
                   #:body
                   `(div (@ (class "px-4 md:px-8 py-4 max-w-prose"))
                         (h1 "wikimusic export")
                         (p ,(format #f "~a ~a"
                                     (G_ "exported at")
                                     (current-time)))
                         (p ,(G_ "This page is a self-contained copy of the knowledge this instance holds. It can be saved, archived and read without a server; the JSON export carries the same rows for a machine to read."))
                         (a (@ (href "/export/json"))
                            ,(G_ "Download the JSON export"))
                         ,(export-section G_
                                          #:heading (G_ "artists")
                                          #:rows (with-name 'artist "artists"))
                         ,(export-section G_
                                          #:heading (G_ "genres")
                                          #:rows (with-name 'genre "genres"))
                         ,(export-section G_
                                          #:heading (G_ "songs")
                                          #:rows (with-name 'song "songs")))))))))

;;; ====== The door back in ======

(define* (import-row! rc table row)
  "Insert ROW into TABLE through kracht's builder, or raise.

Columns whose value is JSON's null -- or an array, which no content column is
-- are left out of the statement rather than written as a value, so a column
the row does not carry keeps whatever the table would give it."
  (let ((attrs (filter-map (lambda (cell)
                             (let ((column (car cell))
                                   (value (cdr cell)))
                               (and (not (eq? value 'null))
                                    (not (vector? value))
                                    (cons column value))))
                           row)))
    (if (null? attrs)
        #f
        (begin (sql-execute! rc
                             (sql-insert table attrs)
                             #:name (format #f "import-~a" table))
               #t))))

(define* (import-payload rc payload)
  "Insert every row the export PAYLOAD carries, and answer with what happened.

PAYLOAD is the parsed JSON a previous `/export/json' produced: an association
list holding `tables', a vector of `(table . name)' and `(rows . vector)'
entries.  A row that cannot be inserted -- a duplicate key, a foreign key
that points nowhere on this instance -- is counted under `skipped' and left
behind rather than stopping the share."
  (let* ((tables (assoc-ref payload 'tables))
         (entries (if (vector? tables) (vector->list tables) '())))
    (let loop ((entries entries)
               (inserted 0)
               (skipped 0))
      (if (null? entries)
          (list (cons 'inserted inserted)
                (cons 'skipped skipped))
          (let* ((entry (car entries))
                 (name (assoc-ref entry 'table))
                 (rows (assoc-ref entry 'rows))
                 (rows (if (vector? rows) (vector->list rows) '())))
            (if (or (not (string? name)) (not (table-name? name)))
                (loop (cdr entries) inserted skipped)
                (let row-loop ((rows rows)
                               (inserted inserted)
                               (skipped skipped))
                  (if (null? rows)
                      (loop (cdr entries) inserted skipped)
                      (let ((ok? (false-if-exception
                                  (import-row! rc name (car rows)))))
                        (row-loop (cdr rows)
                                  (if ok? (1+ inserted) inserted)
                                  (if ok? skipped (1+ skipped))))))))))))

(post "/import/json"
      #:mime 'json
      #:cookies '(names x-bewaking-wikimusic)
      #:i18n '(cookie "lang")
      (lambda (rc)
        (define (do-import)
          (let* ((body (rc-body rc))
                 (payload (false-if-exception
                           (json-string->scm (if (bytevector? body)
                                                 (utf8->string body)
                                                 body))))
                 (summary (if (and payload (assoc-ref payload 'tables))
                              (import-payload rc payload)
                              (list (cons 'inserted 0) (cons 'skipped 0)))))
            ;; Returned, not emitted, for the same reason the export is:
            ;; the answer is JSON and says so.
            (:mime rc `((format . "wikimusic-import")
                        ,@summary))))
        (bewaking-endpoint #:token-name 'x-bewaking-wikimusic
                           #:needed-permissions '(wikimusic:modify-permissions)
                           #:rc rc
                           #:happy-flow do-import
                           #:unhappy-flow back-to-login)))
