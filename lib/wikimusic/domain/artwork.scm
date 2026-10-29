;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (wikimusic domain artwork)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (wikimusic domain repo)
  #:export (insert-artwork delete-artwork-by-id get-artworks-by-entity-ids))

;; -- Record definition ---

(define-record-with-kw (<artwork-repository> %make-artwork-repository
                                             artwork-repository?)
                       mk-artwork-repository
                       (get-artworks-by-entity-ids-proc
                        repo-get-artworks-by-entity-ids)
                       (insert-artwork-proc repo-insert-artwork)
                       (delete-artwork-by-id-proc repo-delete-artwork-by-id))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-artworks-by-entity-ids repo-get-artworks-by-entity-ids
 "Retrieves artworks by their entity IDs from the given REPO.")

(define-repo-method insert-artwork repo-insert-artwork
                    "Inserts a artwork with ATTRS in the given REPO.")

(define-repo-method delete-artwork-by-id repo-delete-artwork-by-id
                    "Deletes a artwork identified by ID in the given REPO.")
