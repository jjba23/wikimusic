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

(define-module (wikimusic domain song-content)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (wikimusic domain repo)
  #:export (get-song-contents-by-song-ids insert-song-content
                                          get-song-contents-by-ids
                                          get-song-content-ids-by-song-ids
                                          delete-song-content-by-id
                                          update-song-content-by-id))

;; -- Record definition ---

(define-record-with-kw (<song-content-repository>
                        %make-song-content-repository song-content-repository?)
                       mk-song-content-repository
                       (get-song-contents-by-song-ids-proc
                        repo-get-song-contents-by-song-ids)
                       (get-song-contents-by-ids-proc
                        repo-get-song-contents-by-ids)
                       (get-song-content-ids-by-song-ids-proc
                        repo-get-song-content-ids-by-song-ids)
                       (insert-song-content-proc repo-insert-song-content)
                       (delete-song-content-by-id-proc
                        repo-delete-song-content-by-id)
                       (update-song-content-by-id-proc
                        repo-update-song-content-by-id))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-song-contents-by-song-ids
 repo-get-song-contents-by-song-ids
 "Retrieves song-contents by their song IDs from the given REPO.")

(define-repo-method get-song-contents-by-ids
 repo-get-song-contents-by-ids
 "Retrieves song-contents by their IDs from the given REPO.")

(define-repo-method get-song-content-ids-by-song-ids
 repo-get-song-content-ids-by-song-ids
 "Retrieves song-content ids by their song IDs from the given REPO.")

(define-repo-method insert-song-content repo-insert-song-content
                    "Inserts a song-content with ATTRS in the given REPO.")

(define-repo-method update-song-content-by-id repo-update-song-content-by-id
 "Updates a song-content identified by ID with ATTRS in the given REPO.")

(define-repo-method delete-song-content-by-id repo-delete-song-content-by-id
 "Deletes a song-content identified by ID in the given REPO.")
