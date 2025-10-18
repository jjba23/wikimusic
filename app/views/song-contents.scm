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

(define-module (app views song-contents)
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
  #:export (render-song-content render-version song-content-edit-page
                                song-content-new-page song-content-form))

(define* (render-song-content G_ song song-contents ascii-size)
  `(div ,(hr)
        (div (@ (class ,(mk-class '(flex flex-col gap-6 md:p-4 xl:p-6))))
             ,(sub-h2 (G_ "musical contents:"))
             ,(ascii-size-select G_
                                 #:route (format #f "/~as/uuid/~a"
                                                 'song
                                                 (assoc-ref song "identifier")))
             (div ,(map (lambda (version)
                          (render-version G_ song version ascii-size))
                        song-contents))
             (a (@ (href ,(format #f "/songs/uuid/~a/contents/new"
                                  (assoc-ref song "identifier"))))
                ,(icon-button #:icon 'plus
                              #:content (G_ "new version"))))))

(define* (render-version G_ song version ascii-size)
  (let* ((v-name (render-if-nempty (lambda (version-name)
                                     (format #f "~a ~a" version-name
                                             (assoc-ref version
                                                        "instrument_type")))
                                   (assoc-ref version "version_name")))
         (version-management-section `((div (@ (class ,(mk-class '(flex
                                                                   flex-wrap
                                                                   flex-row
                                                                   gap-2))))
                                            (a (@ (href ,(format #f
                                                          "/songs/uuid/~a/contents/~a/edit"
                                                          (assoc-ref song
                                                           "identifier")
                                                          (assoc-ref version
                                                           "identifier"))))
                                               ,(icon-button #:icon 'pencil
                                                             #:content (G_
                                                                        "edit version")))
                                            (form (@ (method POST)
                                                     (action ,(format #f
                                                               "/songs/uuid/~a/contents/~a/delete"
                                                               (assoc-ref song
                                                                "identifier")
                                                               (assoc-ref
                                                                version
                                                                "identifier"))))
                                                  ,(icon-button #:icon 'trash
                                                                #:background '
                                                                (bg-red-700)
                                                                #:hover-background '
                                                                (hover:bg-red-800)
                                                                #:border-color '
                                                                (border-stone-300
                                                                 dark:border-stone-700)
                                                                #:type 'submit
                                                                #:content (G_
                                                                           "delete version"))))))
         (render-ascii-legend (lambda (ascii-legend)
                                `(details (@ (open true)
                                             (class ,(mk-class '(my-6))))
                                          (summary (@ (class ,(mk-class '(text-xl
                                                                          font-bold
                                                                          text-onyx-300
                                                                          dark:text-stone-300

                                                                          cursor-pointer))))
                                                   ,(G_ "ascii legend"))
                                          (pre (@ (id ascii-legend-container)
                                                  (class ,(mk-class (append (list
                                                                             (string->symbol
                                                                              ascii-size))
                                                                            '(p-4
                                                                              font-mono
                                                                              md:p-6
                                                                              shadow-md
                                                                              bg-stone-300/50
                                                                              dark:bg-onyx-700
                                                                              text-black
                                                                              dark:text-white
                                                                              rounded-xl
                                                                              border-2
                                                                              border-persia-pink-100/25
                                                                              dark:border-persia-pink-900/10
                                                                              white-space-pre
                                                                              overflow-x-scroll)))))
                                               ,ascii-legend))))
         (ascii-legend-section (render-if-nestring render-ascii-legend
                                                   (assoc-ref version
                                                              "ascii_legend")))
         (line-scroll-select (select #:id 'line-scroll
                                     #:name 'line-scroll
                                     #:options (list (option #:value 1
                                                             #:content (G_
                                                                        "1 line"))
                                                     (option #:value 2
                                                             #:content (G_
                                                                        "2 line"))
                                                     (option #:value 4
                                                             #:content (G_
                                                                        "4 line")
                                                             #:selected-value
                                                             4)
                                                     (option #:value 8
                                                             #:content (G_
                                                                        "8 line"))
                                                     (option #:value 16
                                                             #:content (G_
                                                                        "16 line"))
                                                     (option #:value 32
                                                             #:content (G_
                                                                        "32 line")))))
         (second-scroll-select (select #:id 'second-scroll
                                       #:name 'second-scroll
                                       #:options (list (option #:value 1
                                                               #:content (G_
                                                                          "1 second"))
                                                       (option #:value 2
                                                               #:content (G_
                                                                          "2 second"))
                                                       (option #:value 4
                                                               #:content (G_
                                                                          "4 second"))
                                                       (option #:value 8
                                                               #:content (G_
                                                                          "8 second"))
                                                       (option #:value 16
                                                               #:content (G_
                                                                          "16 second"))
                                                       (option #:value 32
                                                               #:content (G_
                                                                          "32 second")))))
         (ascii-button-section `((div (@ (class ,(mk-class '(flex flex-row
                                                             flex-wrap gap-4
                                                             items-center
                                                             justify-center))))
                                      ,(sub-h3 (G_ "auto-scrolling:"))
                                      ,(icon-button #:id 'start-autoscroll
                                                    #:icon 'mouse-scroll
                                                    #:content (G_ "scroll")
                                                    #:on-click
                                                    "startSongAutoScroll()")
                                      ,line-scroll-select
                                      ,second-scroll-select
                                      ,(icon-button #:icon 'music-notes-simple
                                                    #:content (G_
                                                               "highlight chords")
                                                    #:on-click (string-append
                                                                "highlightChords('ascii-content-container');"
                                                                "highlightChords('ascii-legend-container');")))))
         (render-ascii-content (lambda (ascii-contents)
                                 `(,ascii-button-section (details (@ (open
                                                                      true)
                                                                     (class ,(mk-class '
                                                                              (my-6))))
                                                                  (summary (@ (class ,
                                                                               (mk-class '
                                                                                (text-xl
                                                                                 font-bold
                                                                                 text-onyx-300
                                                                                 dark:text-stone-300
                                                                                 cursor-pointer))))
                                                                           ,(G_
                                                                             "ascii contents"))

                                                                  (pre (@ (id
                                                                           ascii-content-container)
                                                                          (class ,
                                                                           (mk-class
                                                                            (append
                                                                             (list
                                                                              (string->symbol
                                                                               ascii-size))
                                                                             '
                                                                             (p-4
                                                                              md:p-6
                                                                              shadow-md
                                                                              font-mono
                                                                              bg-stone-300/75
                                                                              dark:bg-onyx-700
                                                                              text-black
                                                                              dark:text-white
                                                                              rounded-xl
                                                                              border-2
                                                                              border-persia-pink-100/25
                                                                              dark:border-persia-pink-900/10
                                                                              white-space-pre
                                                                              overflow-x-scroll)))))
                                                                       ,ascii-contents)))))
         (ascii-content-section (render-if-nestring render-ascii-content
                                                    (assoc-ref version
                                                     "ascii_contents")))
         (cleaned-pdf-data (if (equal? (assoc-ref version "pdf_contents")
                                "data:application/octet-stream;base64,") ""
                               (assoc-ref version "pdf_contents")))
         (render-pdf-content (lambda (pdf-contents)
                               `((details (@ (open true)
                                             (class ,(mk-class '(my-6))))
                                          (summary (@ (class ,(mk-class '(text-xl
                                                                          font-bold
                                                                          text-onyx-300
                                                                          dark:text-stone-300
                                                                          cursor-pointer))))
                                                   ,(G_ "PDF contents"))
                                          (iframe (@ (src ,pdf-contents)
                                                     (width "100%")
                                                     (class ,(mk-class '(min-h-screen)))))))))
         (pdf-content-section (render-if-nestring render-pdf-content
                                                  cleaned-pdf-data)))
    `(,(hr) (details (@ (open true))
                     (summary (@ (class ,(mk-class '(text-xl font-bold
                                                     text-onyx-300
                                                     dark:text-stone-300
                                                     cursor-pointer))))
                              ,v-name)

                     (div (@ (class ,(mk-class '(my-4))))
                          (div (@ (class ,(mk-class '(py-3))))
                               (details (summary (@ (class ,(mk-class '(cursor-pointer
                                                                        dark:text-stone-300
                                                                        text-onyx-300))))
                                                 ,(G_ "manage version"))
                                        ,version-management-section))
                          ,ascii-legend-section
                          ,ascii-content-section
                          ,pdf-content-section)))))

(define* (song-content-edit-page G_
                                 #:key song song-contents is-logged-in)
  (let* ((clean-pdf-contents (lambda (x)
                               (if (equal? x
                                    "data:application/octet-stream;base64,")
                                   ""
                                   (html-unescape (assoc-ref song-contents
                                                             "pdf_contents")))))
         (body `(div (@ (class ,(mk-class '())))
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
  `(,(if (and song-identifier song-content-identifier)
         (h2 (format #f "~a: ~a ~a"
                     (G_ "editing version") version-name instrument-type))
         (h2 (G_ "new version"))) (form (@ (method POST)
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
                                                        "translateFileToBase64AddToInput(
                                                                      document.getElementById('pdf-upload'),
                                                                      document.getElementById('pdf-contents')
                                                           )")
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
                                                                         min-h-240
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

