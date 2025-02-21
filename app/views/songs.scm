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

(define-module (app views songs)
  #:use-module (wikimusic html)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (ice-9 i18n)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun))

(define (relevant-artworks artworks x)
  (filter (lambda (art)
            (equal? (assoc-ref x "identifier")
                    (assoc-ref art "song_identifier"))) artworks))

(define (render-song-tile G_ artworks song-version-count-alist x)
  (let ((extra-info (cond-render (assoc-ref song-version-count-alist
                                            (assoc-ref x "identifier"))
                                 (lambda (vc)
                                   `(div (@ (class
                                             "flex flex-row gap-2 text-sm"))

                                         (span ,(G_ "versions"))

                                         (span ,(format #f "~a"

                                                        (car vc))))))))
    `((div ,(item-tile G_
                       "songs"
                       x
                       (relevant-artworks artworks x)
                       #:extra-info extra-info)))))

(define-public (songs-list-page G_ songs artworks song-version-count-alist)
  (html-template G_
                 #:body `(div (@ (class "container mx-auto"))
                              ((h2 (@ (class
                                       "font-black text-stone-800 text-md"))
                                   ,(G_ "viewing songs"))
                               (div (div (@ (class
                                             "flex flex-row flex-wrap gap-3 items-center"))
                                         ,(map (lambda (x)
                                                 (render-song-tile G_ artworks
                                                  song-version-count-alist x))
                                               songs)))))))

(define-public (songs-detail-page G_ song artworks song-contents)
  (html-template G_
                 #:body `((div (@ (class "container mx-auto"))
                               ((h2 (@ (class
                                        "font-black text-stone-800 text-xl"))
                                    ,(assoc-ref song "display_name"))
                                (div (div ,(entity-details G_ "songs" song
                                                           artworks)))))
                          (div ,(render-song-contents G_ song song-contents)))))

(define-public (render-song-contents G_ song song-contents)
  `(div (@ (class "flex flex-col gap-6"))
        ,(map (lambda (version)
                `((hr)
                  (details (@ (open "true")
                              (class "cursor-pointer"))
                           (summary (@ (class "p-6"))
                                    ,(cond-render (assoc-ref version
                                                             "version_name")
                                                  (lambda (version-name)
                                                    `(div (@ (class
                                                              "flex flex-row flex-wrap gap-4"))
                                                          (span (@ (class
                                                                    "text-xl font-bold text-stone-700"))
                                                                ,(G_ "version"))
                                                          (span (@ (class
                                                                    "text-xl font-bold text-stone-700"))
                                                                ,version-name)
                                                          ,(cond-render (assoc-ref
                                                                         version
                                                                         "instrument_type")
                                                                        (lambda 
                                                                                (instrument-type)
                                                                          `(span
                                                                            (@
                                                                             (class
                                                                              "text-xl font-bold text-stone-700"))
                                                                            ,instrument-type)))))))
                           (div (@ (class "p-4"))

                                ,(cond-render (assoc-ref version
                                                         "ascii_legend")
                                              (lambda (ascii-legend)
                                                `(div (span (@ (class
                                                                "text-xl font-bold text-stone-700"))
                                                            ,(G_
                                                              "ascii legend"))
                                                      (pre (@ (class
                                                               "p-6 m-4 bg-stone-200/75 text-black rounded-xl white-space-pre overflow-x-scroll text-sm"))
                                                           ,ascii-legend))))
                                ,(cond-render (assoc-ref version
                                                         "ascii_contents")
                                              (lambda (ascii-contents)
                                                `(div (span (@ (class
                                                                "text-xl font-bold text-stone-700"))
                                                            ,(G_
                                                              "ascii contents"))
                                                      (pre (@ (class
                                                               "p-6 m-4 bg-stone-200/75 text-black rounded-xl white-space-pre overflow-x-scroll text-sm"))
                                                           ,ascii-contents))))))))
              song-contents)))
