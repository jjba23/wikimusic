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

(define-module (wikimusic domain artist-artwork)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (wikimusic domain repo)
  #:export (insert-artist-artwork delete-artist-artwork-by-id
                                  get-artist-artworks-by-artist-ids))

;; -- Record definition ---

(define-record-with-kw (<artist-artwork-repository>
                        %make-artist-artwork-repository
                        artist-artwork-repository?)
                       mk-artist-artwork-repository
                       (get-artist-artworks-by-artist-ids-proc
                        repo-get-artist-artworks-by-artist-ids)
                       (insert-artist-artwork-proc repo-insert-artist-artwork)
                       (delete-artist-artwork-by-id-proc
                        repo-delete-artist-artwork-by-id))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-artist-artworks-by-artist-ids repo-get-artist-artworks-by-artist-ids
 "Retrieves artist-artworks by their artist IDs from the given REPO.")

(define-repo-method insert-artist-artwork repo-insert-artist-artwork
                    "Inserts a artist-artwork with ATTRS in the given REPO.")

(define-repo-method delete-artist-artwork-by-id
 repo-delete-artist-artwork-by-id
 "Deletes a artist-artwork identified by ID in the given REPO.")
