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

(define-module (wikimusic domain artist)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (wikimusic domain repo)
  #:export (get-artist-by-id get-artists
                             count-artists
                             search-artists
                             insert-artist
                             delete-artist-by-id
                             update-artist-by-id
                             get-artists-by-ids))

;; -- Record definition ---

(define-record-with-kw (<artist-repository> %make-artist-repository
                                            artist-repository?)
                       mk-artist-repository
                       (get-artist-by-id-proc repo-get-artist-by-id)
                       (get-artists-by-ids-proc repo-get-artists-by-ids)
                       (search-artists-proc repo-search-artists)
                       (get-artists-proc repo-get-artists)
                       (count-artists-proc repo-count-artists)
                       (insert-artist-proc repo-insert-artist)
                       (delete-artist-by-id-proc repo-delete-artist-by-id)
                       (update-artist-by-id-proc repo-update-artist-by-id))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-artist-by-id repo-get-artist-by-id
                    "Retrieves a artist by their ID from the given REPO.")

(define-repo-method get-artists-by-ids repo-get-artists-by-ids
                    "Retrieves artists by their IDs from the given REPO.")

(define-repo-method get-artists repo-get-artists
 "Retrieves a list of all active artists from the given REPO.")

(define-repo-method count-artists repo-count-artists
 "Counts the artists in the given REPO, optionally those a SEARCH matches.")

(define-repo-method search-artists repo-search-artists
 "Retrieves a search list of all active artists from the given REPO.")

(define-repo-method insert-artist repo-insert-artist
                    "Inserts a artist with ATTRS in the given REPO.")

(define-repo-method update-artist-by-id repo-update-artist-by-id
 "Updates a artist identified by ID with ATTRS in the given REPO.")

(define-repo-method delete-artist-by-id repo-delete-artist-by-id
                    "Deletes a artist identified by ID in the given REPO.")
