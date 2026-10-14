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
        (wikimusic domain genre)
        (wikimusic domain song)
        (wikimusic domain song-content)
        (wikimusic domain)
        (wikimusic html)
        (wikimusic sqlite artist)
        (wikimusic sqlite artwork)
        (wikimusic sqlite comment)
        (wikimusic sqlite genre)
        (wikimusic sqlite song)
        (wikimusic sqlite song-content))

;; How many songs the front page opens with.  The front page is a wall of
;; covers rather than a page of them: twelve is two full rows in the widest
;; grid, one row on a phone, and it is a door into the collection rather than
;; a second way of listing it -- `/songs' is where a reader browses, sorts and
;; searches, and every tile here leads to the same song that page would.
(define front-page-song-count 12)

;; How many genres the front page offers as ways in.  Twelve is the same
;; number the song wall shows and for the same reason: it fills a row or two,
;; and it is a first choice rather than the whole list -- `/genres' is where a
;; reader browses them, and a visitor who wants a genre that is not here is one
;; click from it.
(define front-page-genre-count 12)

;; What the front page says the instance holds.
;;
;; Three figures off its own rows, which is the only thing a landing page can
;; honestly say about a wiki: not what it *will* hold, but what is in it.  They
;; are counted one at a time because each is a table of its own, and the count
;; of a table is a question its own repository answers.
(define (front-page-counts rc)
  "Return how many songs, artists and genres this instance holds."
  `((songs . ,(count-songs (make-sqlite-song-repository rc)))
    (artists . ,(count-artists (make-sqlite-artist-repository rc)))
    (genres . ,(count-genres (make-sqlite-genre-repository rc)))))

;; How many artists the front page offers, the same number the song wall shows
;; and for the same reason: it fills a row or two, and a visitor who wants a
;; name that is not here is one click from `/artists'.
(define front-page-artist-count 12)

;; The genres a visitor can start from, newest first: the strip is a way into
;; the collection rather than a catalogue of it, so it moves as the place grows
;; and leads to the same page `/genres' would.
(define (front-page-genres rc)
  "Return the genres the front page offers as ways in."
  (get-genres (make-sqlite-genre-repository rc)
              #:order-by (entity-sort-from-query "created-at-desc")
              #:limit front-page-genre-count))

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

;; The newest artists, in the tiles the artist list page draws: the same rows
;; `/artists' asks for, in the same order a reader's own sort choice names, with
;; the covers and the comment counts a tile is drawn with.  A tile is a tile.
;;
;; The rows a tile is shown with are the ones that name *that* artist: the
;; covers and the comments are fetched for every artist on the shelf at once,
;; so each tile is handed its own -- which is the same thing the artist list
;; page does, and the reason it can be asked for a page of artists rather than
;; for one artist at a time.
(define (front-page-artist-fragment rc)
  "Return the front page's grid of the newest artists, as SXML."
  (let* ((artist-repo (make-sqlite-artist-repository rc))
         (artwork-repo (make-sqlite-artwork-repository rc))
         (comment-repo (make-sqlite-comment-repository rc))
         (artists (get-artists artist-repo
                               #:order-by (entity-sort-from-query
                                           "created-at-desc")
                               #:limit front-page-artist-count))
         (artist-ids (map (lambda (a)
                            (assq-ref a 'identifier)) artists))
         (artworks (if (nil? artist-ids)
                       '()
                       (get-artworks-by-entity-ids artwork-repo
                                                   'artist artist-ids)))
         (comments (if (nil? artist-ids)
                       '()
                       (get-comments-by-entity-ids comment-repo
                                                   'artist artist-ids))))
    `(div (@ (class ,(item-tile-grid-face #:size "medium")))
          ,@(map (lambda (x)
                   `(div ,(item-tile (:i18n rc) 'artist x
                                     (relevant-entities 'artist artworks x)
                                     (relevant-entities 'artist comments x))))
                 artists))))

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
                                           (front-page-song-fragment rc)
                                           #:artist-fragment
                                           (front-page-artist-fragment rc)
                                           #:genres (front-page-genres rc)
                                           #:counts (front-page-counts
                                                     rc))))))

;; `/robots.txt' and `/sitemap.xml' are served by the controller in
;; `app/controllers/seo.scm': both state this instance's own address, which is
;; not something a file checked into the tree can know.
(get "/favicon.ico" static-page-emitter)
