;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; The comments an article carries.
;;;
;;; They are a table of their own rather than the generic `~a_comments' family
;;; the songs, artists and genres share, because an article is the one thing on
;;; this site anybody may comment on.  A comment's author is therefore either a
;;; user of the instance or a name the reader typed, and only one of those two
;;; has an identifier to point at -- so the row carries both and `created_by' is
;;; the only nullable author column in the schema.

(define-module (wikimusic domain article-comment)
  #:declarative? #t
  #:use-module (srfi srfi-1)
  #:use-module (wikimusic domain repo)
  #:export (get-article-comments insert-article-comment))

;; --- Record definition ---

(define-record-with-kw (<article-comment-repository>
                        %make-article-comment-repository
                        article-comment-repository?)
                       mk-article-comment-repository
                       (get-article-comments-proc
                        repo-get-article-comments)
                       (insert-article-comment-proc
                        repo-insert-article-comment))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-article-comments repo-get-article-comments
 "Retrieves the comments of the articles IDS from REPO, oldest first.")

(define-repo-method insert-article-comment repo-insert-article-comment
 "Inserts the comment ATTRS describes into REPO.")
