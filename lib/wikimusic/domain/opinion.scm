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

(define-module (wikimusic domain opinion)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (wikimusic domain repo)
  #:export (insert-opinion delete-opinion-by-id get-opinions-by-entity-ids))

;; -- Record definition ---

(define-record-with-kw (<opinion-repository> %make-opinion-repository
                                             opinion-repository?)
                       mk-opinion-repository
                       (get-opinions-by-entity-ids-proc
                        repo-get-opinions-by-entity-ids)
                       (insert-opinion-proc repo-insert-opinion)
                       (delete-opinion-by-id-proc repo-delete-opinion-by-id))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-opinions-by-entity-ids repo-get-opinions-by-entity-ids
 "Retrieves opinions by their entity IDs from the given REPO.")

(define-repo-method insert-opinion repo-insert-opinion
                    "Inserts a opinion with ATTRS in the given REPO.")

(define-repo-method delete-opinion-by-id repo-delete-opinion-by-id
                    "Deletes a opinion identified by ID in the given REPO.")
