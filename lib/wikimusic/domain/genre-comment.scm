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

(define-module (wikimusic domain genre-comment)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (wikimusic domain repo)
  #:export (insert-genre-comment delete-genre-comment-by-id
                                  get-genre-comments-by-genre-ids))

;; -- Record definition ---

(define-record-with-kw (<genre-comment-repository>
                        %make-genre-comment-repository
                        genre-comment-repository?)
                       mk-genre-comment-repository
                       (get-genre-comments-by-genre-ids-proc
                        repo-get-genre-comments-by-genre-ids)
                       (insert-genre-comment-proc repo-insert-genre-comment)
                       (delete-genre-comment-by-id-proc
                        repo-delete-genre-comment-by-id))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-genre-comments-by-genre-ids repo-get-genre-comments-by-genre-ids
 "Retrieves genre-comments by their genre IDs from the given REPO.")

(define-repo-method insert-genre-comment repo-insert-genre-comment
                    "Inserts a genre-comment with ATTRS in the given REPO.")

(define-repo-method delete-genre-comment-by-id
 repo-delete-genre-comment-by-id
 "Deletes a genre-comment identified by ID in the given REPO.")
