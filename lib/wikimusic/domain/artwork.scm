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

(define-module (wikimusic domain artwork)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (wikimusic domain repo)
  #:export (insert-artwork delete-artwork-by-id get-artworks-by-entity-ids))

;; -- Record definition ---

(define-record-with-kw (<artwork-repository> %make-artwork-repository
                                             artwork-repository?)
                       mk-artwork-repository
                       (get-artworks-by-entity-ids-proc repo-get-artworks-by-entity-ids)
                       (insert-artwork-proc repo-insert-artwork)
                       (delete-artwork-by-id-proc repo-delete-artwork-by-id))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-artworks-by-entity-ids repo-get-artworks-by-entity-ids
 "Retrieves artworks by their genre IDs from the given REPO.")

(define-repo-method insert-artwork repo-insert-artwork
                    "Inserts a artwork with ATTRS in the given REPO.")

(define-repo-method delete-artwork-by-id repo-delete-artwork-by-id
                    "Deletes a artwork identified by ID in the given REPO.")
