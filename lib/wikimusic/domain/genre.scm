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

(define-module (wikimusic domain genre)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (wikimusic domain repo)
  #:export (get-genre-by-id get-genres-by-ids get-genres insert-genre delete-genre-by-id
                           update-genre-by-id))

;; -- Record definition ---

(define-record-with-kw (<genre-repository> %make-genre-repository
                                          genre-repository?)
                       mk-genre-repository
                       (get-genre-by-id-proc repo-get-genre-by-id)
                       (get-genres-by-ids-proc repo-get-genres-by-ids)                       
                       (get-genres-proc repo-get-genres)
                       (insert-genre-proc repo-insert-genre)
                       (delete-genre-by-id-proc repo-delete-genre-by-id)
                       (update-genre-by-id-proc repo-update-genre-by-id))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-genre-by-id repo-get-genre-by-id
                    "Retrieves a genre by their ID from the given REPO.")

(define-repo-method get-genres-by-ids repo-get-genres-by-ids
                    "Retrieves genres by their IDs from the given REPO.")

(define-repo-method get-genres repo-get-genres
 "Retrieves a list of all active genres from the given REPO.")

(define-repo-method insert-genre repo-insert-genre
                    "Inserts a genre with ATTRS in the given REPO.")

(define-repo-method update-genre-by-id repo-update-genre-by-id
 "Updates a genre identified by ID with ATTRS in the given REPO.")

(define-repo-method delete-genre-by-id repo-delete-genre-by-id
                    "Deletes a genre identified by ID in the given REPO.")
