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

(define-module (app views song-content-view)
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
  #:export (render-song-content render-version))

(define* (render-song-content G_ song song-contents ascii-size)
  `(div (div (@ (class ,(mk-class '(flex flex-col gap-6 md:p-4 xl:p-6))))
             (div ,(map (lambda (version)
                          (render-version G_ song version ascii-size))
                        song-contents))
             (a (@ (href ,(format #f "/songs/uuid/~a/contents/new"
                                  (assq-ref song
                                            'identifier))))
                ,(icon-button #:icon 'plus
                              #:content (G_ "new version"))))))

(define* (render-version G_ song version ascii-size)
  (let* ((v-name (render-if-nempty (lambda (version-name)
                                     (format #f "~a ~a" version-name
                                             (assq-ref version
                                                       'instrument-type)))
                                   (assq-ref version
                                             'version-name)))
         (version-management-section `((div (@ (class ,(mk-class '(flex
                                                                   flex-wrap
                                                                   flex-row
                                                                   gap-2))))
                                            (a (@ (href ,(format #f
                                                          "/songs/uuid/~a/contents/~a/edit"
                                                          (assq-ref song
                                                                    'identifier)
                                                          (assq-ref version
                                                                    'identifier))))
                                               ,(icon-button #:icon 'pencil
                                                             #:content (G_
                                                                        "edit version")))
                                            (form (@ (method POST)
                                                     (action ,(format #f
                                                               "/songs/uuid/~a/contents/~a/delete"
                                                               (assq-ref song
                                                                         'identifier)
                                                               (assq-ref
                                                                version
                                                                'identifier))))
                                                  ,(icon-button #:icon 'trash
                                                                #:background '
                                                                (bg-redwood-700)
                                                                #:hover-background '
                                                                (hover:bg-redwood-900)
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
                                                                              leading-5
                                                                              rounded-xl
                                                                              border-2
                                                                              border-persia-pink-100/25
                                                                              dark:border-persia-pink-900/10
                                                                              white-space-pre
                                                                              overflow-x-auto)))))
                                               ,ascii-legend))))
         (ascii-legend-section (render-if-nestring render-ascii-legend
                                                   (assq-ref version
                                                             'ascii-legend)))
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
                                                                              leading-5
                                                                              rounded-xl
                                                                              border-2
                                                                              border-persia-pink-100/25
                                                                              dark:border-persia-pink-900/10
                                                                              white-space-pre
                                                                              overflow-x-scroll)))))
                                                                       ,(string-join
                                                                         (list
                                                                          (map (lambda
                                                                                       (c)

                                                                                 (cons
                                                                                  c

                                                                                  (guitar-chord->fingering
                                                                                   c)))
                                                                           (extract-guitar-chords
                                                                            ascii-contents))
                                                                          ascii-contents)
                                                                         "\n\n")
                                                                       ,ascii-contents)))))
         (ascii-content-section (render-if-nestring render-ascii-content
                                                    (assq-ref version
                                                              'ascii-contents)))
         (cleaned-pdf-data (if (equal? (assq-ref version
                                                 'pdf-contents)
                                "data:application/octet-stream;base64,") ""
                               (assq-ref version
                                         'pdf-contents)))
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
                                                     (class ,(mk-class '(min-h-screen))))
                                                  "")))))
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
