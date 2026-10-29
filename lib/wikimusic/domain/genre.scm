;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (wikimusic domain genre)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (wikimusic domain repo)
  #:export (get-genre-by-id get-genres-by-ids
                            get-genres
                            count-genres
                            search-genres
                            insert-genre
                            delete-genre-by-id
                            update-genre-by-id))

;; -- Record definition ---

(define-record-with-kw (<genre-repository> %make-genre-repository
                                           genre-repository?)
                       mk-genre-repository
                       (get-genre-by-id-proc repo-get-genre-by-id)
                       (get-genres-by-ids-proc repo-get-genres-by-ids)
                       (get-genres-proc repo-get-genres)
                       (count-genres-proc repo-count-genres)
                       (search-genres-proc repo-search-genres)
                       (insert-genre-proc repo-insert-genre)
                       (delete-genre-by-id-proc repo-delete-genre-by-id)
                       (update-genre-by-id-proc repo-update-genre-by-id))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-genre-by-id repo-get-genre-by-id
                    "Retrieves a genre by their ID from the given REPO.")

(define-repo-method get-genres-by-ids repo-get-genres-by-ids
                    "Retrieves genres by their IDs from the given REPO.")

(define-repo-method get-genres repo-get-genres
 "Retrieves a list of all active genres from the given REPO.")

(define-repo-method count-genres repo-count-genres
 "Counts the genres in the given REPO, optionally those a SEARCH matches.")

(define-repo-method search-genres repo-search-genres
 "Retrieves a search list of all active genres from the given REPO.")

(define-repo-method insert-genre repo-insert-genre
                    "Inserts a genre with ATTRS in the given REPO.")

(define-repo-method update-genre-by-id repo-update-genre-by-id
 "Updates a genre identified by ID with ATTRS in the given REPO.")

(define-repo-method delete-genre-by-id repo-delete-genre-by-id
                    "Deletes a genre identified by ID in the given REPO.")
