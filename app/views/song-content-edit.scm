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

(define-module (app views song-content-edit)
  #:use-module (wikimusic html)
  #:use-module (wikimusic domain)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (hygguile hygguile)
  #:use-module (ice-9 i18n)
  #:use-module (kracht prelude)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun)
  #:export ( song-content-edit-page
                                song-content-new-page song-content-form))


(define* (song-content-edit-page G_
                                 #:key song song-contents is-logged-in)
  (let* ((clean-pdf-contents (lambda (x)
                               (if (equal? x
                                    "data:application/octet-stream;base64,")
                                   ""
                                   (html-unescape (assoc-ref song-contents
                                                             "pdf_contents")))))
         (body `(div (@ (class ,(mk-class '(px-2 py-6))))
                     ((div ,(hr)
                           ,(song-content-form G_
                                               #:song-identifier (assoc-ref
                                                                  song
                                                                  "identifier")
                                               #:song-content-identifier (assoc-ref
                                                                          song-contents
                                                                          "identifier")
                                               #:instrument-type (html-unescape
                                                                  (assoc-ref
                                                                   song-contents
                                                                   "instrument_type"))
                                               #:version-name (html-unescape (assoc-ref
                                                                              song-contents
                                                                              "version_name"))
                                               #:ascii-legend (html-unescape (assoc-ref
                                                                              song-contents
                                                                              "ascii_legend"))
                                               #:ascii-contents (html-unescape
                                                                 (assoc-ref
                                                                  song-contents
                                                                  "ascii_contents"))
                                               #:guitarpro-contents (html-unescape
                                                                     (assoc-ref
                                                                      song-contents
                                                                      "guitarpro_contents"))
                                               #:pdf-contents
                                               clean-pdf-contents))))))
    (html-template G_
                   #:is-logged-in is-logged-in
                   #:body body)))

(define* (song-content-new-page G_
                                #:key song-identifier is-logged-in)
  (html-template G_
                 #:is-logged-in is-logged-in
                 #:body `(div (@ (class ,(mk-class '())))
                              ,(song-content-form G_
                                                  #:song-identifier
                                                  song-identifier))))

(define* (song-content-form G_
                            #:key song-identifier
                            song-content-identifier
                            (instrument-type "")
                            (version-name "")
                            (ascii-legend "")
                            (ascii-contents "")
                            (guitarpro-contents "")
                            (pdf-contents ""))
  `((div (@(class ,(mk-class '(py-3))))
     ,(if (and song-identifier song-content-identifier)
         (h2 (format #f "~a: ~a ~a"
                     (G_ "editing version") version-name instrument-type))
         (h2 (G_ "new version"))))
    (form (@ (method POST)
                                           (action ,(if (and song-identifier
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
                                        (div ,(input #:label (G_
                                                              "instrument type")
                                                     #:name 'instrument-type
                                                     #:value (html-unescape
                                                              instrument-type)
                                                     #:required #t)
                                             ,(input #:label (G_
                                                              "version name")
                                                     #:name 'version-name
                                                     #:value (html-unescape
                                                              version-name)
                                                     #:required #t)
                                             (label (@ (class ,(mk-class '(dark:text-stone-300
                                                                           text-stone-600
                                                                           font-bold
                                                                           text-sm
                                                                           mt-3))))
                                                    ,(G_ "PDF contents"))
                                             (input (@ (type file)
                                                       (id pdf-upload)
                                                       (onchange
                                                        "translateFileToBase64AddToInput(\n                                                                      document.getElementById('pdf-upload'),\n                                                                      document.getElementById('pdf-contents')\n                                                           )")
                                                       (class ,(mk-class '(bg-stone-200
                                                                           dark:bg-stone-900
                                                                           my-2
                                                                           px-3
                                                                           py-2
                                                                           text-onyx-300
                                                                           dark:text-stone-300
                                                                           rounded-xl)))
                                                       (value "")) "")
                                             (input (@ (id pdf-contents)
                                                       (name pdf-contents)
                                                       (hidden "")) "")
                                             ,(textarea #:label (G_
                                                                 "ascii legend")
                                                        #:name 'ascii-legend
                                                        #:value (html-unescape
                                                                 ascii-legend)
                                                        #:required #f
                                                        #:textarea-css '(p-3
                                                                         rounded-xl
                                                                         border-stone-200
                                                                         dark:border-stone-700
                                                                         dark:text-stone-300
                                                                         bg-stone-200
                                                                         dark:bg-stone-700/75
                                                                         border-2
                                                                         min-h-72
                                                                         shadow-md
                                                                         font-mono
                                                                         text-sm
                                                                         min-w-prose))
                                             ,(textarea #:label (G_
                                                                 "ascii contents")
                                                        #:name 'ascii-contents
                                                        #:value (html-unescape
                                                                 ascii-contents)
                                                        #:required #f
                                                        #:textarea-css '(p-3
                                                                         rounded-xl
                                                                         border-stone-200
                                                                         dark:border-stone-700
                                                                         dark:text-stone-300
                                                                         bg-stone-200
                                                                         dark:bg-stone-700/75
                                                                         border-2
                                                                         min-h-256
                                                                         text-sm
                                                                         shadow-md
                                                                         font-mono
                                                                         min-w-prose))

                                             (input (@ (type file)
                                                       (hidden true)
                                                       (name
                                                        guitarpro-contents)
                                                       (value "")) ""))
                                        (div ,(submit-button (if
                                                              song-content-identifier
                                                              (G_ "edit")
                                                              (G_ "create")))))))

