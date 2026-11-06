;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

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
  #:export (render-song-content render-version render-guitarpro-section
                                guitarpro-facts guitarpro-filename))

;;; A chord guide a player can hear.
;;;
;;; The guide has always listed the chords a tab names, with the fingering the
;;; transposition implies (`Am  x02210').  A fingering is a picture to a player,
;;; so it is drawn as one -- six strings, the frets under them, a dot where a
;;; finger goes -- and the pill is a control rather than a label: pressing it
;;; plays the chord, so a reader hears the shape they are being shown without
;;; leaving the page or reaching for an instrument.

(define (fingering-frets fingering)
  "Return FINGERING as a list of frets, -1 for a silent string, or #f.

FINGERING is what the guide stores: one character per string from the lowest,
 a digit for the fret it is held at and `x' for a string left silent."
  (let ((frets (map (lambda (character)
                      (cond
                        [(char=? character #\x) -1]
                        [(char-numeric? character) (- (char->integer character)
                                                     (char->integer #\0))]
                        [else #f]))
                    (string->list fingering))))
    (and (every (lambda (fret) fret) frets)
         frets)))

(define (svg-number value)
  "Return VALUE as the text an SVG attribute is written with."
  (format #f "~a" value))

(define (fretboard-diagram fingering)
  "Return FINGERING drawn as a fretboard, or '() when it is not one.

The diagram is a picture of a fact the pill already states in characters, so it
is decoration to a screen reader and is named as such: what a reader is told is
the fingering, and what they are offered is the chord, played."
  (let ((frets (fingering-frets fingering)))
    (if (not (and frets
                  (= 6 (length frets))))
      '()
      (let* ((held (filter (lambda (fret)
                             (> fret 0)) frets))
             (base (if (and (pair? held)
                            (> (apply min held) 1))
                     (apply min held)
                     1))
             (x0 10)
             (dx 9)
             (y0 18)
             (dy 13)
             (string-x (lambda (string)
                         (+ x0 (* string dx))))
             (fret-y (lambda (row)
                       (+ y0 (* row dy)))))
        (list `(svg (@ (viewBox "0 0 66 92")
                       (class ,(mk-class '(h-16 w-auto)))
                       (aria-hidden "true")
                       (fill "none")
                       (stroke "currentColor")
                       (stroke-width "1")
                       (stroke-linecap "round"))
                    ;; The frets, with the nut drawn as the thick line it is.
                    ,@(map (lambda (row)
                             `(line (@ (x1 ,(svg-number x0))
                                       (y1 ,(svg-number (fret-y row)))
                                       (x2 ,(svg-number (+ x0 (* 5 dx))))
                                       (y2 ,(svg-number (fret-y row)))
                                       ,@(if (and (= row 0) (= base 1))
                                           '((stroke-width "3"))
                                           '()))))
                           '(0 1 2 3 4 5))
                    ;; The strings.
                    ,@(map (lambda (string)
                             `(line (@ (x1 ,(svg-number (string-x string)))
                                       (y1 ,(svg-number (fret-y 0)))
                                       (x2 ,(svg-number (string-x string)))
                                       (y2 ,(svg-number (fret-y 5))))))
                           '(0 1 2 3 4 5))
                    ;; Where the fingers go: an open string above the nut, a
                    ;; silent one crossed out, a held one a dot in its fret.
                    ,@(map (lambda (fret string)
                             (let ((x (string-x string)))
                               (cond
                                 [(= fret -1)
                                  `(text (@ (x ,(svg-number x))
                                            (y ,(svg-number (- (fret-y 0) 5)))
                                            (text-anchor "middle")
                                            (stroke "none")
                                            (fill "currentColor")
                                            (font-size "10"))
                                         "×")]
                                 [(= fret 0)
                                  `(circle (@ (cx ,(svg-number x))
                                              (cy ,(svg-number (- (fret-y 0) 7)))
                                              (r "2.6")))]
                                 [else
                                  `(circle (@ (cx ,(svg-number x))
                                              (cy ,(svg-number (+ (fret-y (- fret
                                                                          base))
                                                                  6.5)))
                                              (r "3.4")
                                              (fill "currentColor")
                                              (stroke "none")))])))
                           frets '(0 1 2 3 4 5))
                    ;; A shape played high up the neck says which fret it
                    ;; starts at, the way a printed chord chart does.
                    ,@(if (> base 1)
                        (list `(text (@ (x ,(svg-number (- x0 3)))
                                        (y ,(svg-number (+ (fret-y 0) 9)))
                                        (text-anchor "end")
                                        (stroke "none")
                                        (fill "currentColor")
                                        (font-size "8"))
                                     ,(format #f "~afr" base)))
                        '())))))))

(define* (render-chord-pill G_ pair)
  "Return one chord of the guide, drawn and playable, as SXML."
  (let* ((chord (car pair))
         (fingering (cdr pair))
         (diagram (fretboard-diagram fingering))
         (pill-classes '(flex flex-row items-center gap-2
                              px-3 py-2
                              rounded-xl
                              border
                              border-stone-300
                              dark:border-onyx-500
                              bg-stone-100/75
                              dark:bg-onyx-500
                              shadow-md
                              transition-all
                              text-onyx-900
                              dark:text-stone-100)))
    (if (pair? diagram)
      `(button (@ (type "button")
                  (class
                   ,(mk-class (append '(cursor-pointer
                                        active:scale-95)
                                      pill-classes)))
                  (title ,(G_ "hear this chord"))
                  (aria-label ,(format #f "~a, ~a" chord fingering))
                  (onclick ,(format #f "wikimusicChordPlay('~a')" fingering)))
               (div (@ (class ,(mk-class '(flex
                                           flex-col
                                           items-start
                                           gap-1))))
                    (span (@ (class ,(mk-class '(font-bold
                                                 text-md
                                                 text-onyx-900
                                                 dark:text-stone-100))))
                          ,chord)
                    (span (@ (class ,(mk-class '(font-mono
                                                 text-sm
                                                 text-onyx-700
                                                 dark:text-stone-300))))
                          ,fingering))
               ,(car diagram))
      `(div (@ (class ,(mk-class pill-classes)))
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
                  ,fingering)))))

(define (render-chord-guide G_ chord-pairs)
  "Return the guide's chords as one row of playable pills."
  (if (null? chord-pairs) ""
      `(div (@ (class ,(mk-class '(flex flex-wrap gap-3 py-6 items-center))))
            ,@(map (lambda (pair)
                     (render-chord-pill G_ pair)) chord-pairs))))

(define* (render-song-content G_ song song-contents ascii-size)
  `(div (div (@ (class "wm-song-content"))
             (div ,(map (lambda (version)
                          (render-version G_ song version ascii-size))
                        song-contents))
             (a (@ (href ,(format #f "/songs/uuid/~a/contents/new"
                                  (assq-ref song
                                            'identifier))))
                ,(icon-button #:icon 'plus
                              #:content (G_ "new version"))))))

(define* (scroll-step-select G_ #:key id label selected steps)
  "Return a menu of auto-scroll steps, named for what it chooses.

The library's `select' builder carries no aria attribute, and a menu beside a
heading with no name of its own is announced as an unnamed combobox.  The
classes are the ones that builder gave it, so the menu looks the same as the
others on the page; what is new is the name and the options written out, which
is the only way to attach one."
  `(select (@ (id ,id)
              (name ,id)
              (aria-label ,(G_ label))
              (class ,(mk-class '(bg-stone-300/75
                                  border-2
                                  border-stone-700
                                  cursor-pointer
                                  dark:bg-onyx-700
                                  dark:border-onyx-100
                                  dark:text-stone-300
                                  duration-150
                                  focus-visible:outline-2
                                  focus-visible:outline-offset-2
                                  font-sans
                                  max-w-full
                                  outline-onyx-500
                                  px-3
                                  py-2
                                  rounded-xl
                                  shadow-md
                                  text-md
                                  text-onyx-500
                                  transition-colors
                                  w-full))))
           ,@(map (lambda (step)
                    `(option (@ (value ,(car step))
                                (class "font-sans")
                                ,@(if (equal? (car step) selected)
                                    '((selected ""))
                                    '()))
                             ,(cdr step)))
                  steps)))

(define (line-scroll-select G_)
  (scroll-step-select G_
                      #:id "line-scroll"
                      #:label "lines per scroll step"
                      #:selected "4"
                      #:steps (list (cons "1" (G_ "1 line"))
                                    (cons "2" (G_ "2 line"))
                                    (cons "4" (G_ "4 line"))
                                    (cons "8" (G_ "8 line"))
                                    (cons "16" (G_ "16 line"))
                                    (cons "32" (G_ "32 line")))))

(define (second-scroll-select G_)
  (scroll-step-select G_
                      #:id "second-scroll"
                      #:label "seconds per scroll step"
                      #:selected "1"
                      #:steps (list (cons "1" (G_ "1 second"))
                                    (cons "2" (G_ "2 second"))
                                    (cons "4" (G_ "4 second"))
                                    (cons "8" (G_ "8 second"))
                                    (cons "16" (G_ "16 second"))
                                    (cons "32" (G_ "32 second")))))

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

;; The heading of a disclosure, and the mark that says whether it is open.
;;
;; The chevron is the affordance: it turns as the section opens, so a reader
;; reads from the heading alone that what is under it can be folded away.  A
;; song page holds several such sections -- the tab, its legend, a PDF beside
;; them -- and they are all long enough that a reader who came for one of them
;; wants the others out of the way.
;;
;; The two classes are the framework's own, and neither needs a script: one
;; drops the browser's marker and turns the mark when the `details' is open,
;; the other carries the transition that makes the turn read as a turn rather
;; than as a jump.  `<details>' folds and unfolds without any JavaScript, so
;; the animation is the only part of this that a browser without it misses.
(define* (disclosure-summary G_ wording)
  "Return the summary a disclosure is titled with, as a heading that turns."
  `(summary (@ (class ,(mk-class '(flex flex-row items-center gap-2
                                   text-xl font-bold
                                   text-onyx-300 dark:text-stone-300
                                   select-none
                                   transition-colors duration-150
                                   hover:text-persia-pink-500
                                   dark:hover:text-persia-pink-300))))
            (span (@ (aria-hidden "true")
                     (class ,(mk-class '(wm-disclosure-mark text-base))))
                  ,(icon #:type 'caret-down))
            ,(G_ wording)))

;; The block an ascii text is drawn in.
;;
;; One definition for the two places a song page shows one -- the contents and
;; the legend -- so the two cannot disagree about the size the reader chose,
;; the surface under them, or how a line wider than the page is reached:
;; `overflow-x-auto' shows a scrollbar when the text needs one, where `scroll'
;; kept one over a tab that fitted.
;;
;; The size comes through `ascii-size-known', so a name the deployment was
;; handed that is not a step of the ladder -- `text-11', say, which an earlier
;; control offered and the stylesheet has no utility for -- is drawn at the
;; step it stands in for rather than at no size at all.
(define* (ascii-block content #:key id size)
  "Return CONTENT as the ascii block a song page draws it in, at SIZE."
  `(pre (@ (id ,id)
           (class ,(mk-class (append (list (string->symbol
                                            (ascii-size-known size)))
                                     ;; A tablature is the music itself, so it
                                     ;; is drawn on a surface of its own rather
                                     ;; than on a pane of the page: the paper
                                     ;; under it is opaque, so no colour wash
                                     ;; and no content scrolling behind it
                                     ;; tints a note, and it casts no shadow for
                                     ;; the same reason -- a shadow is an edge
                                     ;; of paper, not of the music.
                                     '(wm-ascii
                                       p-4 md:p-6
                                       font-mono
                                       bg-white
                                       dark:bg-onyx-900
                                       text-black
                                       dark:text-white
                                       rounded-xl
                                       border-2
                                       border-persia-pink-100/25
                                       dark:border-persia-pink-900/10
                                       whitespace-pre
                                       overflow-x-auto)))))
       ,content))

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
    `(,(ascii-button-section G_) ,(render-chord-guide G_
                                                       guitar-chord-guide-contents)
      (details (@ (open true)
                  (class ,(mk-class '(wm-disclosure my-6))))
               ,(disclosure-summary G_ "ascii contents")

               ,(ascii-block ascii-contents
                             #:id "ascii-content-container"
                             #:size ascii-size)))))

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
                       (not (string-null? value)) value))))
        (number (lambda (key)
                  (let ((value (assq-ref metadata key)))
                    (and (number? value)
                         (number->string value))))))
    (filter (lambda (fact)
              (cdr fact))
            (list (cons (G_ "title")
                        (text 'title))
                  (cons (G_ "artist")
                        (text 'artist))
                  (cons (G_ "album")
                        (text 'album))
                  (cons (G_ "tabbed by")
                        (text 'tabber))
                  (cons (G_ "tempo")
                        (let ((tempo (assq-ref metadata
                                               'tempo)))
                          (and (number? tempo)
                               (format #f "~a bpm" tempo))))
                  (cons (G_ "music key")
                        (text 'key-name))
                  (cons (G_ "measures")
                        (number 'measures))
                  (cons (G_ "tracks")
                        (number 'tracks))))))

(define (filename-safe text)
  "Return TEXT with the characters a file name cannot hold replaced by dashes."
  (string-map (lambda (character)
                (if (memv character
                          '(#\/ #\\
                            #\:
                            #\*
                            #\?
                            #\"
                            #\<
                            #\>
                            #\|)) #\- character)) text))

(define (guitarpro-filename song version)
  "Return the name a version's Guitar Pro tab is saved under.

The name is what a reader meets in their downloads folder, so it says which
song and which version the file is: a tab saved as `tab.gp5' among many is a
file its reader has to open to identify."
  (let* ((parts (filter (lambda (part)
                          (and (string? part)
                               (not (string-null? part))))
                        (list (assq-ref song
                                        'display-name)
                              (assq-ref version
                                        'version-name))))
         (base (if (null? parts) "wikimusic-tab"
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
  (let* ((data-url (assq-ref version
                             'guitarpro-contents))
         (tab-bytes (data-url-payload data-url)))
    (if (and tab-bytes
             (not (zero? (bytevector-length tab-bytes))))
        (let* ((metadata (gp5-bytes-metadata tab-bytes))
               (id (format #f "guitarpro-~a"
                           (assq-ref version
                                     'identifier)))
               (filename (guitarpro-filename song version))
               (named (lambda (part)
                        (string-append id part)))
               ;; One small vocabulary for the two controls that are fields
               ;; rather than buttons, so they read as the same kind of thing
               ;; the rest of the site's forms are made of.
               (label-class (mk-class '(dark:text-stone-300 text-stone-500
                                                            font-bold text-sm)))
               (field-class (mk-class '(bg-stone-100/75 dark:bg-onyx-500
                                                        dark:text-stone-300
                                                        text-onyx-900
                                                        border
                                                        border-stone-300
                                                        dark:border-stone-700
                                                        rounded-lg
                                                        px-2
                                                        py-1
                                                        text-sm
                                                        w-20))))
          (list `(details (@ (open true)
                             (class ,(mk-class '(wm-disclosure my-6))))
                          ,(disclosure-summary G_ "Guitar Pro 5 tab")
                          (div (@ (id ,id)
                                  (class ,(mk-class '(flex flex-col gap-4 py-4))))
                               ,(if metadata
                                    `(div (@ (class ,(mk-class '(flex flex-col
                                                                 gap-2))))
                                          ,@(map (lambda (fact)
                                                   `(div (@ (class ,(mk-class '
                                                                              (flex
                                                                               flex-row
                                                                               flex-wrap
                                                                               gap-2))))
                                                         (span (@ (class ,(mk-class '
                                                                           (font-bold
                                                                            text-onyx-300
                                                                            dark:text-stone-300))))
                                                               ,(car fact))
                                                         (span (@ (class ,(mk-class '
                                                                           (text-onyx-300
                                                                            dark:text-stone-300))))
                                                               ,(cdr fact))))
                                                 (guitarpro-facts G_ metadata)))
                                    `(p (@ (class ,(mk-class '(text-onyx-300
                                                               dark:text-stone-300))))
                                        ,(G_
                                          "the header of this tab could not be read, but the file itself can be downloaded")))
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
                                                     #:content (G_
                                                                "download the tab")))
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
                               (div (@ (class ,(mk-class '(flex flex-col gap-3))))
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
                                                         ,(format #f
                                                                  "100% — ~a"
                                                                  (G_
                                                                   "the tab's own tempo")))
                                                 (option (@ (value "0.75"))
                                                         "75%")
                                                 (option (@ (value "0.5"))
                                                         "50%")
                                                 (option (@ (value "0.35"))
                                                         "35%")
                                                 (option (@ (value "0.25"))
                                                         "25%"))
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
                                                       #:content `((span (@ (id ,
                                                                             (named
                                                                              "-loop-idle")))
                                                                         ,(G_
                                                                           "loop these bars"))
                                                                   (span (@ (id ,
                                                                             (named
                                                                              "-loop-armed"))
                                                                            (hidden
                                                                             ""))
                                                                         ,(G_
                                                                           "stop looping")))))
                                    ;; What the two bar fields are for, in the
                                    ;; page's own words: a reader who has never met
                                    ;; a practice loop should not have to find out
                                    ;; by arming one.
                                    (p (@ (class ,(mk-class '(text-sm
                                                              text-onyx-300
                                                              dark:text-stone-300))))
                                       ,(G_
                                         "a passage plays over and over between the two bars, after a bar of count-in"))
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
                                             ,(G_
                                               "the tablature is drawn below: press play to hear it"))
                                       (span (@ (id ,(named "-status-failed"))
                                                (hidden ""))
                                             ,(G_
                                               "this tablature could not be drawn here, but the file can still be downloaded"))))))))
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
                                                                (hover:bg-redwood-900
                                                                 dark:hover:bg-redwood-500)
                                                                #:border-color '
                                                                (border-stone-300
                                                                 dark:border-stone-700)
                                                                #:type 'submit
                                                                #:content (G_
                                                                           "delete version"))))))
         (render-ascii-legend (lambda (ascii-legend)
                                `(details (@ (open true)
                                             (class ,(mk-class '(wm-disclosure
                                                                 my-6))))
                                          ,(disclosure-summary G_ "ascii legend")
                                          ,(ascii-block ascii-legend
                                                        #:id
                                                        "ascii-legend-container"
                                                        #:size ascii-size))))
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
                                             (class ,(mk-class '(wm-disclosure
                                                                 my-6))))
                                          ,(disclosure-summary G_ "PDF contents")
                                          (iframe (@ (src ,pdf-contents)
                                                     (width "100%")
                                                     (class ,(mk-class '(wm-reading-frame))))
                                                  "")))))
         (pdf-content-section (render-if-nestring render-pdf-content
                                                  cleaned-pdf-data))
         (guitarpro-section (render-guitarpro-section G_ song version)))
    `(,(hr) (details (@ (open true)
                          (class ,(mk-class '(wm-disclosure))))
                     (summary (@ (class ,(mk-class '(flex flex-row items-center
                                                     gap-2
                                                     text-xl font-bold
                                                     text-onyx-300
                                                     dark:text-stone-300
                                                     select-none
                                                     transition-colors
                                                     duration-150
                                                     hover:text-persia-pink-500
                                                     dark:hover:text-persia-pink-300))))
                              (span (@ (aria-hidden "true")
                                       (class ,(mk-class '(wm-disclosure-mark
                                                           text-base))))
                                    ,(icon #:type 'caret-down))
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
