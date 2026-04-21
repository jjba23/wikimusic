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

(define-module (wikimusic domain external-source)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (wikimusic domain repo)
  #:export (insert-external-source delete-external-source-by-id get-external-sources-by-entity-ids))

;; -- Record definition ---

(define-record-with-kw (<external-source-repository> %make-external-source-repository
                                             external-source-repository?)
                       mk-external-source-repository
                       (get-external-sources-by-entity-ids-proc
                        repo-get-external-sources-by-entity-ids)
                       (insert-external-source-proc repo-insert-external-source)
                       (delete-external-source-by-id-proc repo-delete-external-source-by-id))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-external-sources-by-entity-ids repo-get-external-sources-by-entity-ids
 "Retrieves external-sources by their entity IDs from the given REPO.")

(define-repo-method insert-external-source repo-insert-external-source
                    "Inserts a external-source with ATTRS in the given REPO.")

(define-repo-method delete-external-source-by-id repo-delete-external-source-by-id
                    "Deletes a external-source identified by ID in the given REPO.")
