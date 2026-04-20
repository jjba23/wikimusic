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

(define-module (wikimusic domain artist-comment)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (wikimusic domain repo)
  #:export (insert-artist-comment delete-artist-comment-by-id
                                  get-artist-comments-by-artist-ids))

;; -- Record definition ---

(define-record-with-kw (<artist-comment-repository>
                        %make-artist-comment-repository
                        artist-comment-repository?)
                       mk-artist-comment-repository
                       (get-artist-comments-by-artist-ids-proc
                        repo-get-artist-comments-by-artist-ids)
                       (insert-artist-comment-proc repo-insert-artist-comment)
                       (delete-artist-comment-by-id-proc
                        repo-delete-artist-comment-by-id))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-artist-comments-by-artist-ids repo-get-artist-comments-by-artist-ids
 "Retrieves artist-comments by their artist IDs from the given REPO.")

(define-repo-method insert-artist-comment repo-insert-artist-comment
                    "Inserts a artist-comment with ATTRS in the given REPO.")

(define-repo-method delete-artist-comment-by-id
 repo-delete-artist-comment-by-id
 "Deletes a artist-comment identified by ID in the given REPO.")
