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

(define-module (wikimusic domain genre-artwork)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (wikimusic domain repo)
  #:export (insert-genre-artwork delete-genre-artwork-by-id
                                  get-genre-artworks-by-genre-ids))

;; -- Record definition ---

(define-record-with-kw (<genre-artwork-repository>
                        %make-genre-artwork-repository
                        genre-artwork-repository?)
                       mk-genre-artwork-repository
                       (get-genre-artworks-by-genre-ids-proc
                        repo-get-genre-artworks-by-genre-ids)
                       (insert-genre-artwork-proc repo-insert-genre-artwork)
                       (delete-genre-artwork-by-id-proc
                        repo-delete-genre-artwork-by-id))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-genre-artworks-by-genre-ids repo-get-genre-artworks-by-genre-ids
 "Retrieves genre-artworks by their genre IDs from the given REPO.")

(define-repo-method insert-genre-artwork repo-insert-genre-artwork
                    "Inserts a genre-artwork with ATTRS in the given REPO.")

(define-repo-method delete-genre-artwork-by-id
 repo-delete-genre-artwork-by-id
 "Deletes a genre-artwork identified by ID in the given REPO.")
