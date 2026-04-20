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

(define-module (wikimusic domain song-comment)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (wikimusic domain repo)
  #:export (insert-song-comment delete-song-comment-by-id
                                  get-song-comments-by-song-ids))

;; -- Record definition ---

(define-record-with-kw (<song-comment-repository>
                        %make-song-comment-repository
                        song-comment-repository?)
                       mk-song-comment-repository
                       (get-song-comments-by-song-ids-proc
                        repo-get-song-comments-by-song-ids)
                       (insert-song-comment-proc repo-insert-song-comment)
                       (delete-song-comment-by-id-proc
                        repo-delete-song-comment-by-id))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-song-comments-by-song-ids repo-get-song-comments-by-song-ids
 "Retrieves song-comments by their song IDs from the given REPO.")

(define-repo-method insert-song-comment repo-insert-song-comment
                    "Inserts a song-comment with ATTRS in the given REPO.")

(define-repo-method delete-song-comment-by-id
 repo-delete-song-comment-by-id
 "Deletes a song-comment identified by ID in the given REPO.")
