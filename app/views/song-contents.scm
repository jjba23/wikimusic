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

(define-module (app views song-contents)
  #:use-module (wikimusic html)
  #:use-module (wikimusic abstraction)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (hygguile abstraction)
  #:use-module (hygguile components input)
  #:use-module (hygguile components button)
  #:use-module (ice-9 i18n)
  #:use-module (wikimusic query-escape)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun))

(define-public (render-song-contents G_ song song-contents)
  `(div (hr (@ (class ,(->css '(my-4)))))
        (div (@ (class ,(->css '(flex flex-col gap-6 md:p-4 xl:p-6))))
             (span (@ (class ,(->css '(font-black text-2xl text-stone-700 px-2
                                                  py-6))))
                   ,(G_ "musical contents"))
             (div ,(map (lambda (version)
                          (render-version G_ version)) song-contents))
             (a (@ (href ,(format #f "/songs/uuid/~a/contents/new"
                                  (assoc-ref song "identifier"))))
                ,(hyg-button #:content (G_ "new version"))))))

(define-public (render-version G_ version)
  `((hr)
    (details 
     (summary (@ (class ,(->css '(text-xl
                                  font-bold
                                  text-stone-700
                                  cursor-pointer))))
              ,(cond-render (lambda (version-name)
                              (format #f "~a ~a ~a" (G_ "version") version-name (assoc-ref version "instrument_type"))
                              )
                            (assoc-ref version "version_name")))
     (div (@(class ,(->css '(my-4))))

          ,(cond-render (lambda (ascii-legend)
                          `(details (@ (open "true"))
                                    (summary (@ (class ,(->css '(text-xl
                                                                 font-bold
                                                                 text-stone-700
                                                                 cursor-pointer))))
                                             ,(G_ "ascii legend"))
                                    (pre (@ (class ,(->css '(p-4
                                                             md:p-6
                                                             bg-stone-200/75
                                                             text-black
                                                             rounded-xl
                                                             white-space-pre
                                                             overflow-x-scroll
                                                             text-sm))))
                                         ,ascii-legend)))
                        (assoc-ref version "ascii_legend"))
          ,(cond-render (lambda (ascii-contents)
                          `(details (@ (open "true"))
                                    (summary (@ (class ,(->css '(text-xl
                                                                 font-bold
                                                                 text-stone-700
                                                                 cursor-pointer))))
                                             ,(G_ "ascii contents"))
                                    (pre (@ (class ,(->css '(p-4
                                                             md:p-6
                                                             bg-stone-200/75
                                                             text-black
                                                             rounded-xl
                                                             white-space-pre
                                                             overflow-x-scroll
                                                             text-sm))))
                                         ,ascii-contents)))
                        (assoc-ref version "ascii_contents"))))))

(begin
  (define* (song-content-edit-page G_ song song-contents artworks)
    (let* ((body `(div (@ (class "container mx-auto"))

                       (map (lambda (c)
                              `((div (hr (@ (class "my-6")))
                                     ,(song-content-form G_
                                                         #:song-identifier (assoc-ref
                                                                            song
                                                                            "identifier")
                                                         #:song-content-identifier
                                                         (assoc-ref c
                                                          "identifier")
                                                         #:ascii-legend (assoc-ref
                                                                         c
                                                                         "ascii_legend")
                                                         #:ascii-contents (assoc-ref
                                                                           c
                                                                           "ascii_contents")
                                                         #:guitarpro-contents (assoc-ref
                                                                               c
                                                                               "guitarpro_contents")
                                                         #:pdf-contents (assoc-ref
                                                                         c
                                                                         "pdf_contents")))))))))
      (html-template G_
                     #:body body)))
  (export song-content-edit-page))

(begin
  (define* (song-contents-new-page G_ song-identifier)
    (html-template G_
                   #:body `(div (@ (class ,(->css '(container mx-auto))))
                                ,(song-content-form G_
                                                    #:song-identifier
                                                    song-identifier))))
  (export song-contents-new-page))

(begin
  (define* (song-content-form G_
                              #:key song-identifier
                              song-content-identifier
                              (ascii-legend "")
                              (ascii-contents "")
                              (guitarpro-contents "")
                              (pdf-contents ""))
    `((form (@ (method POST)
               (action ,(if (and song-identifier song-content-identifier)
                            (format #f "/songs/uuid/~a/contents/~a/edit"
                                    song-identifier song-content-identifier)
                            (format #f "/songs/uuid/~a/contents/new"
                                    song-identifier)))
               (content-type application/x-www-form-urlencoded))
            (div ,(mk-textarea #:label (G_ "ascii legend")
                               #:name "ascii-legend"
                               #:value (unescape-str ascii-legend)
                               #:required #f)
                 ,(mk-textarea #:label (G_ "ascii contents")
                               #:name "ascii-contents"
                               #:value (unescape-str ascii-contents)
                               #:required #f)))
      (div ,(hyg-submit-button #:content (if song-content-identifier
                                             (G_ "edit")
                                             (G_ "create"))))))
  (export song-content-form))

