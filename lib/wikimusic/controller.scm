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

(define-module (wikimusic controller)
  #:use-module (web server)
  #:use-module (web request)
  #:use-module (web response)
  #:use-module (web uri)
  #:use-module (json)
  #:use-module (ice-9 popen)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 time)
  #:use-module (ice-9 format)
  #:use-module (ice-9 string-fun)
  #:use-module (ice-9 iconv)
  #:use-module (ice-9 hash-table)
  #:use-module (ice-9 threads)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (hygguile abstraction)
  #:use-module (hygguile components input)
  #:use-module (hygguile components button)
  #:use-module (srfi srfi-19)
  #:use-module (ice-9 textual-ports)
  #:use-module (artanis route)
  #:use-module (artanis db)
  #:use-module (artanis artanis)
  #:use-module (wikimusic sqlite util)
  #:use-module (wikimusic sqlite comment)
  #:use-module (wikimusic domain comment)
  #:use-module (uuid generate)
  #:use-module (wikimusic auth)
  #:use-module (wikimusic env)
  #:use-module (bewaking bewaking)
  #:use-module (app views error)
  #:use-module (kracht prelude)
  #:export (body-alist delete-artwork entity-or-404
            session-payload may-mutate? forbidden guard-owner
            require-row-owner
            comment-new comment-edit comment-delete))

(define* (body-alist rc)
  "Return the parameters in RC's request body as an association list.

A POST may arrive with nothing in it -- a form whose only control is a submit
button, a client that posts an empty body, a request built by hand -- and the
parser is handed a bytevector, so it raises over an absent body.  A request
carrying no parameters is a request with no fields, not a fault, and every
handler that reads one field out of a body wants the same answer to it: an
empty list, on which `assoc-ref' answers #f for every name."
  (let ((body (rc-body rc)))
    (if (nil? body)
        '()
        (alist-from-url-encoded-body body))))

(define* (entity-or-404 entity entity-name identifier)
  "Return ENTITY, or answer the request with a 404 page when there is none.

A detail page is addressed by an identifier a reader can mistype, edit or
invent, so not finding one is an ordinary answer rather than a fault: the
repository hands back @code{#f} for an unknown identifier, and every
binding built on the result afterwards -- a view count, a display name, a
list of comments -- would fail on @code{#f} one line at a time, turning a
mistyped address into a server error.  Answering where the lookup happens
keeps that decision in one place, and answers with the page a request that
matched no route at all is given, so both read the same to a reader.

The throw is artanis's own: the framework catches an @code{artanis-err}
carrying a status and renders that status's page, which is the pretty one
ENTRY registers at start-up.

@table @var
@item entity
The row a repository lookup returned, or @code{#f}.
@item entity-name
The kind of thing that was being looked for, in the reader's words -- a song,
an artist, a genre.
@item identifier
The identifier the lookup was made with, so the log says which one.
@end table

@example
(get-song-by-id song-repo song-id)
;; => (get-song-by-id song-repo song-id), guarded:
(entity-or-404 (get-song-by-id song-repo song-id) \"song\" song-id)
@end example"
  (if (nil? entity)
      (throw 'artanis-err 404 entity-or-404
             "no ~a with the identifier ~a" entity-name identifier)
      entity))

;;; ====== Who may change a row ======
;;;
;;; A route already states the *permission* it needs; these are the *ownership*
;;; half.  `wikimusic:modify-permissions' is the super grant -- its holder may
;;; change any row on any entity -- and everyone else may change only the rows
;;; they created.  See "Who may edit what" in the manual for the whole rule.

(define* (session-payload rc)
  "Return the session payload the request in RC carries, or #f.

This is the same token `authorized-payload' opens, read again where a route
needs to know *who* is asking rather than only whether they hold a permission."
  (let ((token (:cookies-value rc session-cookie-name)))
    (and (string? token)
         (not (string-null? token))
         (decrypt-token #:token token
                        #:encryption-key encryption-key
                        #:signing-key signing-key))))

(define* (may-mutate? #:key session created-by)
  "Return #t when SESSION may change a row whose `created_by' is CREATED-BY.

The answer is #t for a session holding `wikimusic:modify-permissions', the
super grant, and otherwise only when the row's creator is the session's own
user.  A row whose `created_by' is missing or #f is nobody's, so only a super
session may change it."
  (or (has-needed-permissions? #:needed '(wikimusic:modify-permissions)
                               #:present (assoc-ref session
                                                    'owner-permissions))
      (and (assoc-ref session 'owner-id)
           (equal? (assoc-ref session 'owner-id) created-by))))

(define (forbidden rc)
  "Answer the request in RC with the 403 page, the same one every other status
is rendered by."
  (response-emit (error-page-html 403) #:status 403))

(define* (guard-owner #:key rc created-by)
  "Return #t when the request may change a row created by CREATED-BY, and
raise a 403 -- rendered by the same error pages as any other status -- when it
may not.

It is the *raising* that refuses, not a #f answer: the handler's return value
is what Artanis renders, so a route that emitted a 403 and then carried on
would have it thrown away and answer 500 instead.  A raise unwinds the whole
route, so a caller only has to write

  (when (guard-owner #:rc rc #:created-by created-by) ...mutate...)

and cannot forget to refuse."
  (let ((session (session-payload rc)))
    (unless (and session
                 (may-mutate? #:session session #:created-by created-by))
      (throw 'artanis-err 403 guard-owner
             "the session may not change a row created by ~a" created-by))
    #t))

(define* (require-row-owner #:key rc table where)
  "Ensure the request in RC may change the row of TABLE that WHERE selects,
and raise a 404 or a 403 -- rendered by the same pages as any other status --
when it may not.

This is the ownership half of the rule for a row that is not the page's own
entity -- an artwork, an external source, a song version, a relation between
two entities -- whose creator is only known by reading it.  The row is read for
its `created_by', because it is that column, and not the requester's word, that
decides.  TABLE is always one of wikimusic's own table names, written out in
the route and never a request value, and WHERE is an association list of
column names to bound values.

`guard-owner' answers about a `created_by' the caller already holds; this is
for the rows whose creator has to be read first, so a route names the table and
the row and stays unindented.  A WHERE that selects no row is a 404: there is
nothing there to change."
  (let* ((rows (sql-rows rc
                         (sql-select table
                                     #:columns '(created-by)
                                     #:where where
                                     #:limit 1)
                         #:name (format #f "guard-~a" table)))
         (created-by (and (pair? rows)
                          (assq-ref (car rows) 'created-by))))
    (when (null? rows)
      (throw 'artanis-err 404 require-row-owner
             "no ~a row for ~s" table where))
    (guard-owner #:rc rc #:created-by created-by)))

;;; ====== Comments ======
;;;
;;; A comment is a row someone owns, like every other row wikimusic holds:
;;; anyone signed in may write one, and only its author -- or a holder of the
;;; super grant -- may change or remove it.  That is `guard-owner', the same
;;; rule the entity edit routes use, so a comment and the thing it is about
;;; obey one rule and not two.

(define* (comment-new #:key rc entity entity-identifier redirect-url)
  "Add a comment to the ENTITY named ENTITY-IDENTIFIER, then send the client
on to REDIRECT-URL.

A comment is addressed to one entity -- a song, an artist, a genre -- and its
table, its identifier column and its thread follow from ENTITY, which is
wikimusic's own name for the kind of thing and never a request value.

The body carries `contents', and optionally `parent-identifier' when the
comment is a reply.  A body with no text is ignored rather than stored, so an
empty submit cannot leave an empty comment on a page, and the row's author is
the session's own user."
  (let* ((body (body-alist rc))
         (session (session-payload rc))
         (created-by (and session (assoc-ref session 'owner-id)))
         (contents (assoc-ref body "contents"))
         (parent (assoc-ref body "parent-identifier"))
         (parent (and (string? parent)
                      (not (string=? parent ""))
                      (html-escape parent))))
    (when (and created-by
               (string? contents)
               (not (string=? contents "")))
      ;; A nullable column is left out rather than written as #f: kracht
      ;; renders a bound #f as the literal 0, which `approved_by' -- a foreign
      ;; key to a user -- would then have to resolve, so an absent parent is an
      ;; absent column and the table's own NULL applies.
      (insert-comment (make-sqlite-comment-repository rc) entity
                      `((identifier . ,(generate-string-uuid))
                        (,(string->symbol (format #f "~a-identifier" entity))
                         .
                         ,entity-identifier)
                        (created-by . ,created-by)
                        (visibility-status . 0)
                        (contents . ,(html-escape contents))
                        (created-at . ,(current-time))
                        ,@(if parent
                              `((parent-identifier . ,parent))
                              '()))))
    (redirect-to rc (string->uri redirect-url) #:status 302)))

(define* (comment-edit #:key rc entity comment-identifier redirect-url)
  "Rewrite the comment COMMENT-IDENTIFIER of ENTITY, then send the client on to
REDIRECT-URL.

The row is read first, because it is the row's own creator -- not the
requester's word -- that decides whether this session may change it.  A
comment that is not there is a 404; one somebody else wrote is a 403."
  (let* ((repository (make-sqlite-comment-repository rc))
         (row (get-comment-by-id repository entity comment-identifier))
         (contents (assoc-ref (body-alist rc) "contents")))
    (cond
      ((not row) (forbidden rc))
      ((not (guard-owner #:rc rc
                         #:created-by (assq-ref row 'created-by)))
       #f)
      (else (when (and (string? contents) (not (string=? contents "")))
              (update-comment-by-id repository entity comment-identifier
                                    `((contents . ,(html-escape contents))
                                      (last-edited-at . ,(current-time)))))
            (redirect-to rc (string->uri redirect-url) #:status 302)))))

(define* (comment-delete #:key rc entity comment-identifier redirect-url)
  "Delete the comment COMMENT-IDENTIFIER of ENTITY, then send the client on to
REDIRECT-URL.

The author may remove their own comment and a holder of the super grant may
remove any; anyone else is refused.  Deleting a comment a reply hangs off
leaves the reply in place, addressed to a comment that is gone -- an orphan
the reader sees at the top of the thread, which is friendlier than quietly
taking their words with it."
  (let* ((repository (make-sqlite-comment-repository rc))
         (row (get-comment-by-id repository entity comment-identifier)))
    (cond
      ((not row) (forbidden rc))
      ((not (guard-owner #:rc rc
                         #:created-by (assq-ref row 'created-by)))
       #f)
      (else (delete-comment-by-id repository entity comment-identifier)
            (redirect-to rc (string->uri redirect-url) #:status 302)))))

(define* (delete-artwork #:key rc
                         entity
                         artwork-identifier
                         redirect-url)
  "Delete one artwork of ENTITY, identified by ARTWORK-IDENTIFIER, and send the
client on to REDIRECT-URL.

The statement is built by kracht's `sql-delete': the table is one of wikimusic's
own -- `artist_artworks', `genre_artworks' or `song_artworks' -- and the
identifier is a bound value, so neither reaches SQL as text.

An artwork is a row someone owns, so its `created_by' is read first: only its
creator, or a holder of the super grant, may take it away (see
`guard-row-owner')."
  (require-row-owner #:rc rc
                     #:table (format #f "~a_artworks" entity)
                     #:where `((identifier . ,artwork-identifier)))
  (sql-execute! rc
                (sql-delete (format #f "~a_artworks" entity)
                            #:where `((identifier . ,artwork-identifier)))
                #:name "delete-artwork")
  (redirect-to rc
               (string->uri redirect-url)
               #:status 302))
