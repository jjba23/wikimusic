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

(define-module (wikimusic domain song-artwork)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (wikimusic domain repo)
  #:export (insert-song-artwork delete-song-artwork-by-id
                                  get-song-artworks-by-song-ids))

;; -- Record definition ---

(define-record-with-kw (<song-artwork-repository>
                        %make-song-artwork-repository
                        song-artwork-repository?)
                       mk-song-artwork-repository
                       (get-song-artworks-by-song-ids-proc
                        repo-get-song-artworks-by-song-ids)
                       (insert-song-artwork-proc repo-insert-song-artwork)
                       (delete-song-artwork-by-id-proc
                        repo-delete-song-artwork-by-id))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-song-artworks-by-song-ids repo-get-song-artworks-by-song-ids
 "Retrieves song-artworks by their song IDs from the given REPO.")

(define-repo-method insert-song-artwork repo-insert-song-artwork
                    "Inserts a song-artwork with ATTRS in the given REPO.")

(define-repo-method delete-song-artwork-by-id
 repo-delete-song-artwork-by-id
 "Deletes a song-artwork identified by ID in the given REPO.")
