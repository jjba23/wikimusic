;;; wikimusic - the free music knowledge encyclopaedia

;; Copyright © 2025 "Josep Bigorra" known as "jjba23" <jjbigorra@gmail.com>

;; wikimusic is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; wikimusic is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with wikimusic.  If not, see <https://www.gnu.org/licenses/>.

(define-module (app views artists)
  #:use-module (wikimusic html)
  #:use-module (wikimusic abstraction)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (ice-9 i18n)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun))

(define-public (artists-list-page G_ artists artworks opinions comments)
  (html-template G_
                 #:body `(div (@ (class "container mx-auto"))
                              ((h2 (@ (class
                                       "font-black text-stone-800 text-md"))
                                   ,(G_ "viewing artists"))
                               (div (div (@ (class
                                             "flex flex-row flex-wrap gap-3 items-center"))
                                         ,(map (lambda (x)
                                                 `(div ,(item-tile G_
                                                                   'artist
                                                                   x
                                                                   (relevant-entities 'artist
                                                                    artworks x)
                                                                   (relevant-entities 'artist
                                                                    opinions x)
                                                                   (relevant-entities 'artist
                                                                    comments x))))
                                               artists)))))))

(define-public (artists-detail-page G_ artist artworks opinions comments)
  (html-template G_
                 #:body `(div (@ (class "container mx-auto"))
                              ((h2 (@ (class
                                       "font-black text-stone-800 text-xl"))
                                   ,(assoc-ref artist "display_name"))
                               (div (div ,(entity-details G_
                                                          'artist
                                                          artist
                                                          artworks
                                                          opinions
                                                          comments)))))))

