;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

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
