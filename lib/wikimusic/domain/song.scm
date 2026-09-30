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

(define-module (wikimusic domain song)
  #:declarative? #t
  #:use-module (srfi srfi-9)
  #:use-module (wikimusic domain repo)
  #:export (get-song-by-id search-songs
                           get-songs
                           insert-song
                           get-songs-by-artist-id
                           get-songs-by-genre-id
                           get-song-genres-by-ids
                           get-song-artists-by-ids
                           delete-song-by-id
                           update-song-by-id))

;; -- Record definition ---

(define-record-with-kw (<song-repository> %make-song-repository
                                          song-repository?)
                       mk-song-repository
                       (get-song-by-id-proc repo-get-song-by-id)
                       (get-songs-proc repo-get-songs)
                       (get-songs-by-artist-id-proc
                        repo-get-songs-by-artist-id)
                       (get-songs-by-genre-id-proc repo-get-songs-by-genre-id)
                       (get-song-genres-by-ids-proc
                        repo-get-song-genres-by-ids)
                       (get-song-artists-by-ids-proc
                        repo-get-song-artists-by-ids)
                       (search-songs-proc repo-search-songs)
                       (insert-song-proc repo-insert-song)
                       (delete-song-by-id-proc repo-delete-song-by-id)
                       (update-song-by-id-proc repo-update-song-by-id))

;; --- eDSL: Embedded Domain Specific Language ---

(define-repo-method get-song-by-id repo-get-song-by-id
                    "Retrieves a song by their ID from the given REPO.")

(define-repo-method get-songs repo-get-songs
 "Retrieves a list of all active songs from the given REPO.")

(define-repo-method get-songs-by-artist-id repo-get-songs-by-artist-id
 "Retrieves a list of all active songs by artist ID from the given REPO.")

(define-repo-method get-songs-by-genre-id repo-get-songs-by-genre-id
 "Retrieves a list of all active songs by genre ID from the given REPO.")

(define-repo-method get-song-genres-by-ids repo-get-song-genres-by-ids
 "Retrieves a list of song genres by IDS from the given REPO.")

(define-repo-method get-song-artists-by-ids repo-get-song-artists-by-ids
 "Retrieves a list of song artists by IDS from the given REPO.")

(define-repo-method search-songs repo-search-songs
 "Retrieves a search list of all active songs from the given REPO.")

(define-repo-method insert-song repo-insert-song
                    "Inserts a song with ATTRS in the given REPO.")

(define-repo-method update-song-by-id repo-update-song-by-id
 "Updates a song identified by ID with ATTRS in the given REPO.")

(define-repo-method delete-song-by-id repo-delete-song-by-id
                    "Deletes a song identified by ID in the given REPO.")
