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

;;; The two files a crawler asks for by name.
;;;
;;; Both used to be static files in `pub/', which is the one place they cannot
;;; live: a sitemap states absolute addresses and a robots file states where its
;;; sitemap is, and neither is knowable at the time a file is written into the
;;; tree -- an instance's address is its own.  They are therefore built per
;;; request from the rows themselves, so a page added a minute ago is in the
;;; sitemap of the next request that asks for it, and there is no second copy of
;;; the address list to fall out of date.
;;;
;;; `xml' is deliberately kept out of the extensions `ENTRY' serves statically,
;;; which is what lets the route below answer `/sitemap.xml' at all.

(define-artanis-controller seo)

(import (ice-9 format)
        (ice-9 string-fun)
        (kracht prelude)
        (srfi srfi-1)
        (srfi srfi-19)
        (wikimusic domain artist)
        (wikimusic domain genre)
        (wikimusic domain song)
        (wikimusic seo)
        (wikimusic sqlite artist)
        (wikimusic sqlite genre)
        (wikimusic sqlite song))

;; How many rows of each kind one sitemap carries.  The protocol's ceiling is
;; 50,000 addresses in a file of at most 50 MB, and the whole corpus of a
;; community wiki fits inside this many several times over; an instance that
;; grows past it serves a sitemap index instead, which is a change to this
;; controller and not to anything that reads it.
(define sitemap-row-limit 20000)

;;; ====== Reading a row's own time ======
;;;
;;; The two time columns hold a number of seconds since the epoch, written into
;;; a text column by whichever of DBI's coercions applied at the time, so what
;;; comes back out is sometimes a number and sometimes the digits of one.  A
;;; sitemap wants a date, and a row whose time cannot be read is listed without
;;; one rather than with a wrong one.

(define (epoch->lastmod value)
  "Return VALUE -- seconds since the epoch, as a number or as its digits -- as
the `YYYY-MM-DD' a sitemap states, or #f when it is not a time at all."
  (let ((seconds (cond
                   ((integer? value) value)
                   ((string? value) (string->number value))
                   (else #f))))
    (if (and seconds (> seconds 0))
        (date->string (time-utc->date (make-time time-utc 0 seconds))
                      "~Y-~m-~d")
        #f)))

;;; ====== Building the sitemap ======

(define* (sitemap-entry #:key loc lastmod changefreq priority)
  "Return one `<url>' of a sitemap.

LOC is the only part a sitemap requires; each of the rest is stated by a
keyword and left out of the element when it is #f, so a caller states only what
it actually knows."
  `(url (loc ,loc)
        ,@(if lastmod `((lastmod ,lastmod)) '())
        ,@(if changefreq `((changefreq ,changefreq)) '())
        ,@(if priority `((priority ,priority)) '())))

(define* (entity-sitemap-entries rows #:key entity)
  "Return ROWS as the sitemap entries of the ENTITY kind of page.

ENTITY is wikimusic's own name for the kind -- `song', `artist', `genre',
`tutorial', `discussion' -- and never a request value; it is what the page's
address is spelled with.  A row whose own time is unreadable is still listed:
being in the sitemap at all is worth more to a reader than the date it changed,
and the address is what a crawler acts on."
  (map (lambda (row)
         (sitemap-entry
          #:loc (absolute-url (format #f "/~as/uuid/~a" entity
                                      (assq-ref row 'identifier)))
          #:lastmod (epoch->lastmod (assq-ref row 'last-edited-at))))
       rows))

(define (sitemap-entries rc)
  "Return every address this instance offers a crawler, as sitemap entries.

The five standing pages come first and are described with the frequency they
actually change at; then every song, artist and genre, each with the date it was
last written to.  Nothing that a reader cannot reach without signing in is
listed, and no address is listed twice: each kind of page has one address per
row, and a row has one identifier."
  (append
   (list (sitemap-entry #:loc (absolute-url "/")
                        #:changefreq "daily" #:priority "1.0")
         (sitemap-entry #:loc (absolute-url "/songs")
                        #:changefreq "daily" #:priority "0.9")
         (sitemap-entry #:loc (absolute-url "/artists")
                        #:changefreq "weekly" #:priority "0.8")
         (sitemap-entry #:loc (absolute-url "/genres")
                        #:changefreq "weekly" #:priority "0.8")
         ;; What the project is changes when the project does, which is
         ;; seldomer than the corpus -- a monthly-revisit hint, and a
         ;; standing page ranked below the three doors into the collection.
         (sitemap-entry #:loc (absolute-url "/about")
                        #:changefreq "monthly" #:priority "0.5"))
   (entity-sitemap-entries
    (get-songs (make-sqlite-song-repository rc)
               #:order-by '((display-name asc))
               #:limit sitemap-row-limit)
    #:entity 'song)
   (entity-sitemap-entries
    (get-artists (make-sqlite-artist-repository rc)
                 #:order-by '((display-name asc))
                 #:limit sitemap-row-limit)
    #:entity 'artist)
   (entity-sitemap-entries
    (get-genres (make-sqlite-genre-repository rc)
                #:order-by '((display-name asc))
                #:limit sitemap-row-limit)
    #:entity 'genre)))

(define (sitemap rc)
  "Return the sitemap of this instance.

The sitemap protocol's namespace is stated on the root element and the
namespace prefix is left off every child: a document whose root declares the
namespace has it in scope throughout, and a sitemap a crawler has to resolve a
prefix in is one more thing that can be got wrong."
  (when (string-null? (site-origin))
    (throw 'artanis-err 500 sitemap
           "no host name is configured, so this instance has no addresses to publish"))
  `(urlset (@ (xmlns "http://www.sitemaps.org/schemas/sitemap/0.9"))
           ,@(sitemap-entries rc)))

(get "/sitemap.xml"
     #:mime 'xml
     (lambda (rc)
       (:mime rc (sitemap rc))))

;;; ====== robots.txt ======
;;;
;;; A robots file says what a crawler may read, and then says where the sitemap
;;; is.  Everything a reader can reach is allowed -- the whole point of the site
;;; is to be found -- and the three kinds of address that are not for a crawler
;;; are refused: signing in and out, anything under a reader's own account, and
;;; every form and every export, which are a contributor's writing or a copy of
;;; pages that are already indexed under their own addresses.
;;;
;;; The refusals are written as path prefixes and one wildcard, which is what
;;; the major crawlers support: `Disallow: /*/edit' covers the edit route of
;;; every entity without having to name each of them, and a form that a new kind
;;; of page adds is covered the moment it exists.

(define robots-lines
  '("User-agent: *"
    "Allow: /"
    ""
    "Disallow: /login"
    "Disallow: /logout"
    "Disallow: /me"
    "Disallow: /export"
    "Disallow: /songs/new"
    "Disallow: /artists/new"
    "Disallow: /genres/new"
    "Disallow: /*/edit"
    "Disallow: /*/new"))

(define (robots-txt)
  "Return the body of this instance's robots.txt."
  (string-join (append robots-lines
                       (list ""
                             (format #f "Sitemap: ~a/sitemap.xml"
                                     (site-origin))))
               "\n"))

(get "/robots.txt"
     (lambda (rc)
       (response-emit (string-append (robots-txt) "\n")
                      #:headers `((content-type . (text/plain (charset . "UTF-8")))))))
