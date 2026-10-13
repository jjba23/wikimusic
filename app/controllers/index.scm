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

(define-artanis-controller index)

(import (app views index)
        (app views song-view)
        (ice-9 string-fun)
        (kracht prelude)
        (web uri)
        (wikimusic domain artist)
        (wikimusic domain artwork)
        (wikimusic domain comment)
        (wikimusic domain song)
        (wikimusic domain song-content)
        (wikimusic domain)
        (wikimusic html)
        (wikimusic sqlite artist)
        (wikimusic sqlite artwork)
        (wikimusic sqlite comment)
        (wikimusic sqlite song)
        (wikimusic sqlite song-content))

;; How many songs the front page opens with.  The front page is a wall of
;; covers rather than a page of them: twelve is two full rows in the widest
;; grid, one row on a phone, and it is a door into the collection rather than
;; a second way of listing it -- `/songs' is where a reader browses, sorts and
;; searches, and every tile here leads to the same song that page would.
(define front-page-song-count 12)

;; The newest songs a reader can be shown, in the tiles the list pages draw.
;;
;; A tile says what a song is called beside its cover, so the page needs the
;; same context `/songs' assembles for its own tiles: the covers, the artists
;; that song is credited to, how many comments it has, and how many versions it
;; is stored in.  The songs are asked for newest first, which is what makes the
;; front page change as the corpus grows, and `created-at-desc' is named the
;; way a reader's sort choice is, so this order is the list page's own order.
(define (front-page-song-fragment rc)
  "Return the front page's grid of the newest songs, as SXML."
  (let* ((song-repo (make-sqlite-song-repository rc))
         (artwork-repo (make-sqlite-artwork-repository rc))
         (artist-repo (make-sqlite-artist-repository rc))
         (comment-repo (make-sqlite-comment-repository rc))
         (song-content-repo (make-sqlite-song-content-repository rc))
         (songs (get-songs song-repo
                           #:order-by (entity-sort-from-query
                                       "created-at-desc")
                           #:limit front-page-song-count))
         (song-ids (map (lambda (s)
                          (assq-ref s
                                    'identifier)) songs))
         (artworks (if (nil? song-ids)
                       '()
                       (get-artworks-by-entity-ids artwork-repo
                                                   'song song-ids)))
         (comments (if (nil? song-ids)
                       '()
                       (get-comments-by-entity-ids comment-repo
                                                   'song song-ids)))
         (song-contents (if (nil? song-ids)
                            '()
                            (get-song-content-ids-by-song-ids
                             song-content-repo song-ids)))
         (song-artists (if (nil? song-ids)
                           '()
                           (get-song-artists-by-ids song-repo song-ids)))
         (artists (if (nil? song-artists)
                      '()
                      (get-artists-by-ids artist-repo
                                          (map (lambda (a)
                                                 (assq-ref a
                                                           'artist-identifier))
                                               song-artists))))
         (song-version-count-alist (map (lambda (song)
                                          (list (assq-ref song 'identifier)
                                                (length
                                                 (filter (lambda (sc)
                                                           (equal? (assq-ref
                                                                    sc
                                                                    'song-identifier)
                                                                   (assq-ref
                                                                    song
                                                                    'identifier)))
                                                         song-contents))))
                                        songs)))
    (song-list-page (:i18n rc)
                    #:only-tiles #t
                    #:songs songs
                    #:artworks artworks
                    #:song-version-count-alist song-version-count-alist
                    #:artists artists
                    #:song-artists song-artists
                    #:comments comments
                    #:limit 0
                    #:offset 0
                    #:search-query ""
                    #:user-sort "created-at-desc")))

(get "/"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic lang)
     (lambda (rc)
       (response-emit (:mime rc
                             (welcome-page (:i18n rc)
                                           #:selected-locale (:cookies-value
                                                              rc "lang")
                                           #:is-logged-in (:cookies-value rc
                                                           "x-bewaking-wikimusic")
                                           #:song-fragment
                                           (front-page-song-fragment
                                            rc))))))

;; `/robots.txt' and `/sitemap.xml' are served by the controller in
;; `app/controllers/seo.scm': both state this instance's own address, which is
;; not something a file checked into the tree can know.
(get "/favicon.ico" static-page-emitter)
