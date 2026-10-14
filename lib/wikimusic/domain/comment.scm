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

(define-module (wikimusic domain comment)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (wikimusic domain repo)
  #:export (insert-comment delete-comment-by-id update-comment-by-id
                           get-comment-by-id get-comments-by-entity-ids))

;; -- Record definition ---

(define-record-with-kw (<comment-repository> %make-comment-repository
                                             comment-repository?)
                       mk-comment-repository
                       (get-comments-by-entity-ids-proc
                        repo-get-comments-by-entity-ids)
                       (insert-comment-proc repo-insert-comment)
                       (update-comment-by-id-proc repo-update-comment-by-id)
                       (get-comment-by-id-proc repo-get-comment-by-id)
                       (delete-comment-by-id-proc repo-delete-comment-by-id))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-comments-by-entity-ids repo-get-comments-by-entity-ids
 "Retrieves comments by their entity IDs from the given REPO.")

(define-repo-method insert-comment repo-insert-comment
                    "Inserts a comment with ATTRS in the given REPO.")

(define-repo-method get-comment-by-id repo-get-comment-by-id
 "Retrieves a single comment of ENTITY identified by ID from the given REPO.")

(define-repo-method update-comment-by-id repo-update-comment-by-id
 "Updates a comment of ENTITY identified by ID with ATTRS in the given REPO.")

(define-repo-method delete-comment-by-id repo-delete-comment-by-id
                    "Deletes a comment identified by ID in the given REPO.")
