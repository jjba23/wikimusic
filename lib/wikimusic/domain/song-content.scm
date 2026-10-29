;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

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

(define-repo-method get-song-contents-by-ids repo-get-song-contents-by-ids
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
