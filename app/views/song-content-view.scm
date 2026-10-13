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
  #:use-module (wikimusic guitarpro)
  #:use-module (rnrs bytevectors)
  #:use-module (srfi srfi-1)
  #:use-module (wikimusic domain guitar-chord-guide)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (hygguile hygguile)
  #:use-module (ice-9 i18n)
  #:use-module (kracht prelude)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun)
  #:export (render-song-content render-version
                       render-guitarpro-section guitarpro-facts
                       guitarpro-filename))

(define (render-chord-pill pair)
  "Helper to render a single chord pill badge."
  (let ((chord (car pair))
        (fingering (cdr pair)))
    `(div (@ (class ,(mk-class '(inline-flex items-center
                                             gap-2
                                             px-4
                                             py-3
                                             rounded-xl
                                             border
                                             border-stone-300
                                             dark:border-onyx-500
                                             hg-frost bg-stone-100/75
                                             dark:bg-onyx-500
                                             shadow-md
                                             transition-all))))
          (span (@ (class ,(mk-class '(font-bold text-md text-onyx-900
                                                 dark:text-stone-100))))
                ,chord)
          (span (@ (class ,(mk-class '(font-mono text-md
                                                 px-3
                                                 py-2
                                                 bg-stone-100
                                                 dark:bg-onyx-900
                                                 rounded-xl
                                                 text-onyx-700
                                                 dark:text-stone-300))))
                ,fingering))))

(define (render-chord-guide chord-pairs)
  "Helper to render the flex row container for all chord pills"
  (if (null? chord-pairs) ""
      `(div (@ (class ,(mk-class '(flex flex-wrap gap-3 py-6 items-center
                                        items-center))))
            ,@(map render-chord-pill chord-pairs))))

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

(define (line-scroll-select G_)
  (select #:id 'line-scroll
          #:name 'line-scroll
          #:options (list (option #:value 1
                                  #:content (G_ "1 line"))
                          (option #:value 2
                                  #:content (G_ "2 line"))
                          (option #:value 4
                                  #:content (G_ "4 line")
                                  #:selected-value 4)
                          (option #:value 8
                                  #:content (G_ "8 line"))
                          (option #:value 16
                                  #:content (G_ "16 line"))
                          (option #:value 32
                                  #:content (G_ "32 line")))))
(define (second-scroll-select G_)
  (select #:id 'second-scroll
          #:name 'second-scroll
          #:options (list (option #:value 1
                                  #:content (G_ "1 second"))
                          (option #:value 2
                                  #:content (G_ "2 second"))
                          (option #:value 4
                                  #:content (G_ "4 second"))
                          (option #:value 8
                                  #:content (G_ "8 second"))
                          (option #:value 16
                                  #:content (G_ "16 second"))
                          (option #:value 32
                                  #:content (G_ "32 second")))))

(define (ascii-button-section G_)
  `((div (@ (class ,(mk-class '(flex flex-row flex-wrap gap-4 items-center
                                     justify-center))))
         ,(sub-h3 (G_ "auto-scrolling:"))
         ,(icon-button #:id 'start-autoscroll
                       #:icon 'mouse-scroll
                       #:content (G_ "scroll")
                       #:on-click "startSongAutoScroll()")
         ,(line-scroll-select G_)
         ,(second-scroll-select G_)
         ,(icon-button #:icon 'music-notes-simple
                       #:content (G_ "highlight chords")
                       #:on-click (string-append
                                   "highlightChords('ascii-content-container');"
                                   "highlightChords('ascii-legend-container');")))))

(define (format-chord-legend-ascii chord-alist)
  (if (or (not chord-alist)
          (null? chord-alist)) ""
      (string-append "Chords:\n\n"
                     (string-join (map (lambda (pair)
                                         (format #f "~a (~a)"
                                                 (car pair)
                                                 (cdr pair))) chord-alist)
                                  "  |  ") "\n\n")))

(define (render-ascii-content G_ ascii-size ascii-contents)
  (let* ((guitar-chord-guide-contents (generate-guitar-chord-guide
                                       ascii-contents)))
    `(,(ascii-button-section G_) ,(render-chord-guide
                                   guitar-chord-guide-contents)
      (details (@ (open true)
                  (class ,(mk-class '(my-6))))
               (summary (@ (class ,(mk-class '(text-xl font-bold text-onyx-300
                                                       dark:text-stone-300
                                                       cursor-pointer))))
                        ,(G_ "ascii contents"))

               (pre (@ (id ascii-content-container)
                       (class ,(mk-class (append (list (string->symbol
                                                        ascii-size))
                                                 '(p-4 md:p-6
                                                   shadow-md
                                                   font-mono
                                                   hg-frost bg-stone-100/75
                                                   dark:bg-onyx-900/75
                                                   text-black
                                                   dark:text-white
                                                   rounded-xl
                                                   border-2
                                                   border-persia-pink-100/25
                                                   dark:border-persia-pink-900/10
                                                   whitespace-pre
                                                   overflow-x-scroll)))))
                    ,ascii-contents)))))

;; The Guitar Pro 5 tab of a version: the file itself, which a browser cannot
;; open, offered back for download beside what its own header says about the
;; score.  The facts come from the file and not from the row, so a reader can
;; see what the download holds -- which song, whose tab, how long, how fast --
;; before spending a download on it, and a file whose header cannot be read is
;; offered all the same, because it is still its author's file.

(define (guitarpro-facts G_ metadata)
  "Return the (label . value) pairs a Guitar Pro 5 tab is described by.

A text field the tab's author left empty is left out, so a page never lists a
line that says nothing; the numbers a readable header always carries are always
listed, since they are what a reader is deciding about."
  (let ((text (lambda (key)
                (let ((value (assq-ref metadata key)))
                  (and (string? value)
                       (not (string-null? value))
                       value))))
        (number (lambda (key)
                  (let ((value (assq-ref metadata key)))
                    (and (number? value) (number->string value))))))
    (filter (lambda (fact) (cdr fact))
            (list (cons (G_ "title") (text 'title))
                  (cons (G_ "artist") (text 'artist))
                  (cons (G_ "album") (text 'album))
                  (cons (G_ "tabbed by") (text 'tabber))
                  (cons (G_ "tempo")
                        (let ((tempo (assq-ref metadata 'tempo)))
                          (and (number? tempo) (format #f "~a bpm" tempo))))
                  (cons (G_ "music key") (text 'key-name))
                  (cons (G_ "measures") (number 'measures))
                  (cons (G_ "tracks") (number 'tracks))))))

(define (filename-safe text)
  "Return TEXT with the characters a file name cannot hold replaced by dashes."
  (string-map (lambda (character)
                (if (memv character
                          '(#\/ #\\ #\: #\* #\? #\" #\< #\> #\|))
                    #\-
                    character))
              text))

(define (guitarpro-filename song version)
  "Return the name a version's Guitar Pro tab is saved under.

The name is what a reader meets in their downloads folder, so it says which
song and which version the file is: a tab saved as `tab.gp5' among many is a
file its reader has to open to identify."
  (let* ((parts (filter (lambda (part)
                          (and (string? part) (not (string-null? part))))
                        (list (assq-ref song 'display-name)
                              (assq-ref version 'version-name))))
         (base (if (null? parts)
                   "wikimusic-tab"
                   (string-join parts " - "))))
    (string-append (filename-safe base) ".gp5")))

(define* (render-guitarpro-section G_ song version)
  "Return the section a version's Guitar Pro 5 tab is shown in, or '() when
the version carries none.

A version that carries no tab holds either nothing at all or the empty data
URL a file input leaves behind (`data:application/octet-stream;base64,'), and
neither is a file: the section is shown only when the data URL actually carries
bytes, so an untouched field does not offer a reader an empty download.

What the section holds is what a reader can do with the tab.  The file is
still offered for download, because a tab is played in the program it was
written in and the download is the page's whole answer for a reader who has
one; beside it is the offer to draw the tablature in the page itself, which
fetches the renderer only when it is taken.  The file is written into the page
once -- in the download link's own `href' -- and the player reads it from
there, so a song page with several tabs does not carry several copies of the
largest thing each version holds.

Every part the script reaches is named after the version, so a page holding
more than one tab has no ambiguity about which it is addressing."
  (let* ((data-url (assq-ref version 'guitarpro-contents))
         (tab-bytes (data-url-payload data-url)))
    (if (and tab-bytes (not (zero? (bytevector-length tab-bytes))))
        (let* ((metadata (gp5-bytes-metadata tab-bytes))
               (id (format #f "guitarpro-~a" (assq-ref version 'identifier)))
               (filename (guitarpro-filename song version))
               (named (lambda (part) (string-append id part)))
               ;; One small vocabulary for the two controls that are fields
               ;; rather than buttons, so they read as the same kind of thing
               ;; the rest of the site's forms are made of.
               (label-class (mk-class '(dark:text-stone-300
                                        text-stone-500
                                        font-bold
                                        text-sm)))
               (field-class (mk-class '(bg-stone-100/75
                                        dark:bg-onyx-500
                                        dark:text-stone-300
                                        text-onyx-900
                                        border
                                        border-stone-300
                                        rounded-lg
                                        px-2
                                        py-1
                                        text-sm
                                        w-20))))
          (list
           `(details (@ (open true) (class ,(mk-class '(my-6))))
                     (summary (@ (class ,(mk-class '(text-xl
                                                     font-bold
                                                     text-onyx-300
                                                     dark:text-stone-300
                                                     cursor-pointer))))
                              ,(G_ "Guitar Pro 5 tab"))
                     (div (@ (id ,id)
                             (class ,(mk-class '(flex flex-col gap-4
                                                           py-4))))
                          ,(if metadata
                               `(div (@ (class ,(mk-class '(flex flex-col
                                                                   gap-2))))
                                     ,@(map (lambda (fact)
                                              `(div (@ (class ,(mk-class
                                                                '(flex flex-row
                                                                      flex-wrap
                                                                      gap-2))))
                                                    (span (@ (class ,(mk-class
                                                                      '(font-bold
                                                                        text-onyx-300
                                                                        dark:text-stone-300))))
                                                          ,(car fact))
                                                    (span (@ (class ,(mk-class
                                                                      '(text-onyx-300
                                                                        dark:text-stone-300))))
                                                          ,(cdr fact))))
                                            (guitarpro-facts G_ metadata)))
                               `(p (@ (class ,(mk-class '(text-onyx-300
                                                         dark:text-stone-300))))
                                   ,(G_ "the header of this tab could not be read, but the file itself can be downloaded")))
                          ;; The file, and the offer to draw it here.  The
                          ;; renderer is not on the page until the offer is
                          ;; taken, so a reader who came for the song pays
                          ;; nothing for a tablature they never open.
                          (div (@ (class ,(mk-class '(flex flex-row
                                                             flex-wrap
                                                             gap-3
                                                             items-center))))
                               (a (@ (id ,(named "-file"))
                                     (href ,data-url)
                                     (download ,filename))
                                  ,(icon-button #:icon 'download
                                                #:content (G_ "download the tab")))
                               (span (@ (id ,(named "-ask")))
                                     ,(icon-button #:icon 'music-notes-simple
                                                   #:content (G_
                                                              "show the tablature")
                                                   #:on-click (format #f
                                                              "wikimusicGuitarProShow('~a')"
                                                              id))))
                          ;; The tablature and the controls that come with it.
                          ;; The controls are hidden until a score is drawn:
                          ;; there is nothing to play before there is
                          ;; something written down.
                          (div (@ (class ,(mk-class '(flex flex-col
                                                             gap-3))))
                               (div (@ (id ,(named "-controls"))
                                       (hidden "")
                                       (class ,(mk-class '(flex flex-row
                                                                 flex-wrap
                                                                 gap-3
                                                                 items-center))))
                                    ,(icon-button #:icon 'play
                                                  #:content (G_ "play")
                                                  #:on-click (format #f
                                                              "wikimusicGuitarProPlayPause('~a')"
                                                              id))
                                    ,(icon-button #:icon 'stop
                                                  #:content (G_ "stop")
                                                  #:on-click (format #f
                                                              "wikimusicGuitarProStop('~a')"
                                                              id))
                                    ;; How fast the tab is played back.  The
                                    ;; first choice is the tempo the tab is
                                    ;; written in, which is the number
                                    ;; already listed above it.
                                    (label (@ (for ,(named "-speed"))
                                              (class ,label-class))
                                           ,(G_ "tempo"))
                                    (select (@ (id ,(named "-speed"))
                                               (name ,(named "-speed"))
                                               (onchange ,(format #f
                                                                  "wikimusicGuitarProSpeed('~a', this.value)"
                                                                  id))
                                               (class ,field-class))
                                            (option (@ (value "1"))
                                                    ,(format #f "100% — ~a"
                                                             (G_ "the tab's own tempo")))
                                            (option (@ (value "0.75")) "75%")
                                            (option (@ (value "0.5")) "50%")
                                            (option (@ (value "0.35")) "35%")
                                            (option (@ (value "0.25")) "25%"))
                                    ;; A passage to drill: the bars it runs from
                                    ;; and to, and the control that arms it.
                                    (label (@ (for ,(named "-loop-from"))
                                              (class ,label-class))
                                           ,(G_ "loop bars"))
                                    (input (@ (type number)
                                              (id ,(named "-loop-from"))
                                              (name ,(named "-loop-from"))
                                              (min "1")
                                              (value "1")
                                              (inputmode numeric)
                                              (class ,field-class)))
                                    (span ,(G_ "to"))
                                    (input (@ (type number)
                                              (id ,(named "-loop-to"))
                                              (name ,(named "-loop-to"))
                                              (min "1")
                                              (value "4")
                                              (inputmode numeric)
                                              (class ,field-class)))
                                    ,(icon-button #:icon 'repeat
                                                  #:id (named "-loop")
                                                  #:on-click (format #f
                                                              "wikimusicGuitarProToggleLoop('~a')"
                                                              id)
                                                  #:content `((span (@ (id ,(named "-loop-idle")))
                                                                    ,(G_ "loop these bars"))
                                                               (span (@ (id ,(named "-loop-armed"))
                                                                        (hidden ""))
                                                                     ,(G_ "stop looping")))))
                               ;; What the two bar fields are for, in the
                               ;; page's own words: a reader who has never met
                               ;; a practice loop should not have to find out
                               ;; by arming one.
                               (p (@ (class ,(mk-class '(text-sm
                                                        text-onyx-300
                                                        dark:text-stone-300))))
                                  ,(G_ "a passage plays over and over between the two bars, after a bar of count-in"))
                               (div (@ (id ,(named "-score"))
                                       (class ,(mk-class '(overflow-x-auto))))
                                    "")
                               ;; What the player is doing, in the page's own
                               ;; words: all three sentences are written here
                               ;; and the script un-hides the one that is
                               ;; true, so a translated page stays translated
                               ;; when a tablature loads.
                               (p (@ (class ,(mk-class '(text-sm
                                                        text-onyx-300
                                                        dark:text-stone-300)))
                                     (aria-live "polite"))
                                  (span (@ (id ,(named "-status-loading"))
                                           (hidden ""))
                                        ,(G_ "loading the tablature …"))
                                  (span (@ (id ,(named "-status-ready"))
                                           (hidden ""))
                                        ,(G_ "the tablature is drawn below: press play to hear it"))
                                  (span (@ (id ,(named "-status-failed"))
                                           (hidden ""))
                                        ,(G_ "this tablature could not be drawn here, but the file can still be downloaded"))))))))
        '())))

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
                                                                              hg-frost bg-stone-100/75
                                                                              dark:bg-onyx-900/75
                                                                              text-black
                                                                              dark:text-white
                                                                              rounded-xl
                                                                              border-2
                                                                              border-persia-pink-100/25
                                                                              dark:border-persia-pink-900/10
                                                                              whitespace-pre
                                                                              overflow-x-auto)))))
                                               ,ascii-legend))))
         (ascii-legend-section (render-if-nestring render-ascii-legend
                                                   (assq-ref version
                                                             'ascii-legend)))

         (ascii-content-section (render-if-nestring (lambda (c)
                                                      (render-ascii-content G_
                                                       ascii-size c))
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
                                                  cleaned-pdf-data))
         (guitarpro-section (render-guitarpro-section G_ song version)))
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
                          ,pdf-content-section
                          ,guitarpro-section)))))
