;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (wikimusic domain external-source)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (wikimusic domain repo)
  #:export (insert-external-source delete-external-source-by-id
                                   get-external-sources-by-entity-ids))

;; -- Record definition ---

(define-record-with-kw (<external-source-repository>
                        %make-external-source-repository
                        external-source-repository?)
                       mk-external-source-repository
                       (get-external-sources-by-entity-ids-proc
                        repo-get-external-sources-by-entity-ids)
                       (insert-external-source-proc
                        repo-insert-external-source)
                       (delete-external-source-by-id-proc
                        repo-delete-external-source-by-id))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-external-sources-by-entity-ids
 repo-get-external-sources-by-entity-ids
 "Retrieves external-sources by their entity IDs from the given REPO.")

(define-repo-method insert-external-source repo-insert-external-source
                    "Inserts a external-source with ATTRS in the given REPO.")

(define-repo-method delete-external-source-by-id
 repo-delete-external-source-by-id
 "Deletes a external-source identified by ID in the given REPO.")
