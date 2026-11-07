;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Articles: what a reader writes for another reader.
;;;
;;; The site already holds what a *song* is -- its artists, its versions, its
;;; tab -- and this is the other half of a musician's shelf: a tutorial that
;;; explains a technique, a video of somebody playing it, a chord guide for a
;;; progression, a page of theory, and a discussion that is just people talking.
;;; All five are the same row, because they are read the same way and commented
;;; on the same way; the `kind' is what a list and a badge are drawn from.
;;;
;;; The trap lives here rather than in the controller because it is a rule, not
;;; a request: a comment whose hidden field came back filled was written by
;;; something that reads markup rather than by a reader, and no route may decide
;;; otherwise.

(define-module (wikimusic domain article)
  #:declarative? #t
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:use-module (wikimusic domain repo)
  #:export (article-kinds article-kind-named
                          honeypot-field-name honeypot-tripped?
                          get-articles get-article-by-id count-articles insert-article
                          update-article-by-id delete-article-by-id))

;; --- Record definition ---

(define-record-with-kw (<article-repository> %make-article-repository
                                             article-repository?)
                       mk-article-repository
                       (get-articles-proc repo-get-articles)
                       (get-article-by-id-proc repo-get-article-by-id)
                       (count-articles-proc repo-count-articles)
                       (insert-article-proc repo-insert-article)
                       (update-article-by-id-proc repo-update-article-by-id)
                       (delete-article-by-id-proc repo-delete-article-by-id))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-articles repo-get-articles
                    "Retrieves articles from REPO, newest first unless told otherwise.")

(define-repo-method get-article-by-id repo-get-article-by-id
                    "Retrieves the article ID identifies, or #f when there is none.")

(define-repo-method count-articles repo-count-articles
                    "Returns how many articles REPO holds.")

(define-repo-method insert-article repo-insert-article
                    "Inserts the article ATTRS describes into REPO.")

(define-repo-method update-article-by-id repo-update-article-by-id
                    "Updates the article ID with ATTRS in the given REPO.")

(define-repo-method delete-article-by-id repo-delete-article-by-id
                    "Deletes the article ID in the given REPO.")

;;; ====== What an article is ======

;;; The five things a reader may write, in the order the form offers them.  A
;;; kind is a symbol in Scheme and a word in a form, and the two spellings are
;;; the same letters, so the word is derived from the symbol rather than listed
;;; twice.
(define article-kinds
  '(tutorial video chord-guide theory discussion))

(define (article-kind-named name)
  "Return the kind NAME names, or a tutorial when no kind is called that.

NAME is whatever a form posted -- a string, or #f when nothing was posted -- so
it is compared against the kinds that exist rather than turned into a symbol
and stored: a kind nobody offers is a form that was edited, not a sixth kind."
  (let ((offered (and (string? name)
                   (find (lambda (kind)
                           (string=? name (symbol->string kind)))
                         article-kinds))))
    (if offered offered 'tutorial)))

;;; ====== The trap ======
;;;
;;; A comment may be written by anyone, signed in or not, which is exactly the
;;; door a spam script walks through.  The form therefore carries one field a
;;; reader cannot see -- laid out off the page rather than `hidden', which a
;;; script that reads the markup will happily skip -- and an answer in it is a
;;; machine's answer.  It is checked by *content* rather than by presence,
;;; because a browser may send the field empty and that is a reader.

(define honeypot-field-name
  "website")

(define (honeypot-tripped? fields)
  "Return #t when FIELDS carries an answer in the trap.

FIELDS is a posted body as an association list.  Whitespace alone is still an
answer: a script that padded the field to look innocent is the one thing this
cannot tell from a script that typed in it."
  (let ((answer (and (list? fields)
                  (assoc-ref fields honeypot-field-name))))
    (and (string? answer)
      (not (string-null? answer)))))
