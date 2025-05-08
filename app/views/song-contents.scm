;;; wikimusic - the free music knowledge encyclopaedia

;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

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
  #:use-module (wikimusic domain)
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

(define-public (render-song-contents G_ song song-contents ascii-size)
  `(div (hr (@ (class ,(->css '(my-4)))))
        (div (@ (class ,(->css '(flex flex-col gap-6 md:p-4 xl:p-6))))
             (span (@ (class ,(->css '(font-black text-2xl text-stone-700 px-2
                                                  py-6))))
                   ,(G_ "musical contents"))
             ,(ascii-size-select G_
                                 #:route (format #f "/~as/uuid/~a"
                                                 'song
                                                 (assoc-ref song "identifier")))
             (div ,(map (lambda (version)
                          (render-version G_ song version ascii-size))
                        song-contents))
             (a (@ (href ,(format #f "/songs/uuid/~a/contents/new"
                                  (assoc-ref song "identifier"))))
                ,(hyg-icon-button #:icon 'plus
                                  #:content (G_ "new version"))))))

(define-public (render-version G_ song version ascii-size)
  `((hr)
    (details (@ (open true))
             (summary (@ (class ,(->css '(text-xl font-bold text-stone-700
                                                  cursor-pointer))))
                      ,(cond-render (lambda (version-name)
                                      (format #f "~a ~a ~a"
                                              (G_ "version") version-name
                                              (assoc-ref version
                                                         "instrument_type")))
                                    (assoc-ref version "version_name")))

             (div (@ (class ,(->css '(my-4))))
                  (div (@ (class ,(->css '(py-3))))
                       (details (summary (@ (class ,(->css '(cursor-pointer))))
                                         ,(G_ "manage version"))
                                (div (@ (class ,(->css '(flex flex-wrap
                                                              flex-row gap-2))))
                                     (a (@ (href ,(format #f
                                                   "/songs/uuid/~a/contents/~a/edit"
                                                   (assoc-ref song
                                                              "identifier")
                                                   (assoc-ref version
                                                              "identifier"))))
                                        ,(hyg-icon-button #:icon 'pencil
                                                          #:content (G_
                                                                     "edit version")))
                                     (form (@ (method POST)
                                              (action ,(format #f
                                                        "/songs/uuid/~a/contents/~a/delete"
                                                        (assoc-ref song
                                                         "identifier")
                                                        (assoc-ref version
                                                         "identifier"))))
                                           ,(hyg-icon-button #:icon 'trash
                                                             #:background 'bg-red-700
                                                             #:hover-background 'hover:bg-red-800
                                                             #:border-color 'border-stone-700
                                                             #:type 'submit
                                                             #:content (G_
                                                                        "delete version"))))))
                  ,(cond-render (lambda (ascii-legend)
                                  `(details (@ (open true))
                                            (summary (@ (class ,(->css '(text-xl
                                                                         font-bold
                                                                         text-stone-700
                                                                         cursor-pointer))))
                                                     ,(G_ "ascii legend"))
                                            (pre (@ (class ,(->css (append (list
                                                                            (string->symbol
                                                                             ascii-size))
                                                                           '(p-4
                                                                             md:p-6
                                                                             shadow-md
                                                                             bg-stone-200/75
                                                                             text-black
                                                                             rounded-xl
                                                                             white-space-pre
                                                                             overflow-x-scroll)))))
                                                 ,ascii-legend)))
                                (assoc-ref version "ascii_legend"))
                  ,(cond-render (lambda (ascii-contents)
                                  `(details (@ (open "true"))
                                            (summary (@ (class ,(->css '(text-xl
                                                                         font-bold
                                                                         text-stone-700
                                                                         cursor-pointer))))
                                                     ,(G_ "ascii contents"))
                                            (pre (@ (class ,(->css (append (list
                                                                            (string->symbol
                                                                             ascii-size))
                                                                           '(p-4
                                                                             md:p-6
                                                                             shadow-md
                                                                             bg-stone-200/75
                                                                             text-black
                                                                             rounded-xl
                                                                             white-space-pre
                                                                             overflow-x-scroll)))))
                                                 ,ascii-contents)))
                                (assoc-ref version "ascii_contents"))))))

(begin
  (define* (song-content-edit-page G_ song song-contents)
    (let* ((body `(div (@ (class "container mx-auto"))

                       ((div (hr (@ (class "my-6")))
                             ,(song-content-form G_
                                                 #:song-identifier (assoc-ref
                                                                    song
                                                                    "identifier")
                                                 #:song-content-identifier (assoc-ref
                                                                            song-contents
                                                                            "identifier")
                                                 #:instrument-type (unescape-str
                                                                    (assoc-ref
                                                                     song-contents
                                                                     "instrument_type"))
                                                 #:version-name (unescape-str (assoc-ref
                                                                               song-contents
                                                                               "version_name"))
                                                 #:ascii-legend (unescape-str (assoc-ref
                                                                               song-contents
                                                                               "ascii_legend"))
                                                 #:ascii-contents (unescape-str
                                                                   (assoc-ref
                                                                    song-contents
                                                                    "ascii_contents"))
                                                 #:guitarpro-contents (unescape-str
                                                                       (assoc-ref
                                                                        song-contents
                                                                        "guitarpro_contents"))
                                                 #:pdf-contents (unescape-str (assoc-ref
                                                                               song-contents
                                                                               "pdf_contents"))))))))
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
                              (instrument-type "")
                              (version-name "")
                              (ascii-legend "")
                              (ascii-contents "")
                              (guitarpro-contents "")
                              (pdf-contents ""))
    `(,(if (and song-identifier song-content-identifier)
           `(h2 (@ (class ,(->css '(text-2xl my-6 font-bold text-stone-800))))
                ,(format #f "~a: ~a ~a"
                         (G_ "editing version") version-name instrument-type))
           `(h2 (@ (class ,(->css '(text-2xl my-6 font-bold text-stone-800))))
                (G_ "new version"))) (form (@ (method POST)
                                              (action ,(if (and
                                                            song-identifier
                                                            song-content-identifier)
                                                           (format #f
                                                            "/songs/uuid/~a/contents/~a/edit"
                                                            song-identifier
                                                            song-content-identifier)
                                                           (format #f
                                                            "/songs/uuid/~a/contents/new"
                                                            song-identifier)))
                                              (content-type
                                               application/x-www-form-urlencoded))
                                           (div ,(hyg-input #:label (G_
                                                                     "instrument type")
                                                            #:name 'instrument-type
                                                            #:value (unescape-str
                                                                     instrument-type)
                                                            #:required #t)
                                                ,(hyg-input #:label (G_
                                                                     "version name")
                                                            #:name 'version-name
                                                            #:value (unescape-str
                                                                     version-name)
                                                            #:required #t)
                                                ,(hyg-textarea #:label (G_
                                                                        "ascii legend")
                                                               #:name 'ascii-legend
                                                               #:value (unescape-str
                                                                        ascii-legend)
                                                               #:required #f
                                                               #:textarea-css '
                                                               (p-3
                                                                max-w-prose
                                                                rounded-xl
                                                                border-stone-200
                                                                border-2
                                                                min-h-80
                                                                text-sm
                                                                min-w-full
                                                                font-mono))
                                                ,(hyg-textarea #:label (G_
                                                                        "ascii contents")
                                                               #:name 'ascii-contents
                                                               #:value (unescape-str
                                                                        ascii-contents)
                                                               #:required #f
                                                               #:textarea-css '
                                                               (p-3
                                                                max-w-prose
                                                                rounded-xl
                                                                border-stone-200
                                                                border-2
                                                                min-h-96
                                                                text-sm
                                                                min-w-full
                                                                font-mono))
                                                (input (@ (type file)
                                                          (hidden true)
                                                          (name pdf-contents)
                                                          (value "")) "")
                                                (input (@ (type file)
                                                          (hidden true)
                                                          (name
                                                           guitarpro-contents)
                                                          (value "")) "")))
      (div ,(hyg-submit-button (if song-content-identifier
                                   (G_ "edit")
                                   (G_ "create"))))))
  (export song-content-form))

