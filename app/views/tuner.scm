;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; The page a musician opens with an instrument in their hands.
;;;
;;; It answers two questions a player has before playing anything: what notes
;;; are these strings *meant* to be, and what note is this string actually
;;; making.  The first is the page's own -- the preset, its strings, and a
;;; control that sounds each one -- and works with no script at all.  The second
;;; is the tuner: it turns on the microphone, and it is the one thing here that
;;; needs a browser's audio graph, so the whole control is hidden until the
;;; script that drives it is there and a reader with no script is still given
;;; the strings, their notes and their frequencies.
;;;
;;; Nothing about the microphone is recorded or sent anywhere, and the page says
;;; so where a reader asks, rather than expecting them to take it on trust.
;;;
;;; The presets are addresses: a reader who plays in drop D or picks up a bass
;;; asks for that preset in the query string, and the page is rendered for it --
;;; so the choice can be bookmarked, shared, and read back by the script without
;;; the script knowing which presets exist.

(define-module (app views tuner)
  #:use-module (wikimusic html)
  #:use-module (wikimusic seo)
  #:use-module (wikimusic domain tuning)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (hygguile hygguile)
  #:use-module (kracht prelude)
  #:use-module (ice-9 i18n)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun)
  #:export (tuner-page preset-name))

;; The column the page stands in: the frame the rest of the site is drawn in, so
;; a reader arriving here from a song is still on the same site.
(define tuner-column-classes
  '(w-full max-w-196 mx-auto flex flex-col gap-4 px-2 py-4))

;; What a search result and a pasted link say about the page.  The words are a
;; player's -- the string, the note it should be, how far off it is -- because
;; that is the page a reader is looking for.
(define tuner-description
  "Tune a guitar, bass or ukulele in the browser: play a string into the microphone and WikiMusic names the note and how far off it is, with the standard, drop D and half-step-down tunings and a reference tone for every string.")

(define (preset-name G_ preset)
  "Return the words PRESET is offered under."
  (cond
    [(eq? preset 'guitar-drop-d) (G_ "guitar, drop d")]
    [(eq? preset 'guitar-half-step) (G_ "guitar, half a step down")]
    [(eq? preset 'bass-4) (G_ "bass, four strings")]
    [(eq? preset 'bass-5) (G_ "bass, five strings")]
    [(eq? preset 'ukulele) (G_ "ukulele")]
    [else (G_ "guitar, standard tuning")]))

;; The presets as a row of addresses rather than as a menu the script has to
;; understand: choosing one is loading the page a reader wants, and a reader who
;; copies the address has copied the tuning.
(define* (preset-picker G_ #:key current)
  `(nav (@ (aria-label ,(G_ "tuning presets"))
           (class ,(mk-class '(flex flex-row flex-wrap gap-2 items-center))))
        ,@(map (lambda (preset)
                 (let ((named (car preset))
                       (here? (eq? (car preset) current)))
                   `(a (@ (href ,(format #f "?preset=~a" named))
                          ,@(if here? '((aria-current "page")) '())
                          (class
                           ,(mk-class
                             (append '(no-underline
                                       rounded-xl
                                       px-3
                                       py-1
                                       text-sm
                                       font-medium
                                       border-2
                                       transition-colors
                                       duration-150)
                                     (if here?
                                       '(bg-persia-pink-500/25
                                         border-persia-pink-500/25
                                         text-persia-pink-700
                                         dark:text-persia-pink-300)
                                       '(border-transparent
                                         text-onyx-500
                                         dark:text-stone-300
                                         hover:text-persia-pink-500
                                         dark:hover:text-persia-pink-300))))))
                      ,(preset-name G_ named))))
               tuning-presets)))

;; One string of the preset: the note it should sound, the frequency that note
;; is, and the control that plays it.  The note and the frequency are the page's
;; -- they are what a reader tunes against when the microphone is no use, and
;; they are readable with no script at all.
(define* (tuner-string G_ #:key id midi)
  (let ((name (midi-note-name midi)))
    `(button (@ (type "button")
                (data-midi ,(number->string midi))
                (class ,(mk-class '(wm-tuner-string
                                    flex
                                    flex-col
                                    items-center
                                    gap-1
                                    px-3
                                    py-2
                                    rounded-xl
                                    border-2
                                    border-stone-300
                                    dark:border-onyx-500
                                    bg-white
                                    dark:bg-onyx-900
                                    cursor-pointer
                                    transition-colors
                                    duration-150)))
                (aria-label ,(format #f "~a, ~a" name
                                     (G_ "play this string")))
                (onclick ,(format #f "wikimusicTunerTone('~a', ~a)" id midi)))
             (span (@ (class ,(mk-class '(text-lg
                                          font-bold
                                          tabular-nums
                                          text-onyx-900
                                          dark:text-stone-100))))
                   ,name)
             (span (@ (class ,(mk-class '(text-xs
                                          font-mono
                                          tabular-nums
                                          text-onyx-500
                                          dark:text-stone-300))))
                   ,(format #f "~,1f Hz" (midi-note-frequency midi))))))

;;; The tuner itself.
;;;
;;; Every part of it is named after the widget's identifier, which is the only
;;; contract between this markup and `pub/js/tuner.js'.  The words a reader can
;;; meet -- waiting, listening, in tune, refused, unsupported -- are all written
;;; here and the script un-hides one, so a translated page stays translated while
;;; the microphone does or does not answer.
(define* (tuner-widget G_ #:key id preset)
  (let* ((strings (tuning-preset preset))
         (part (lambda (suffix)
                 (format #f "~a~a" id suffix))))
    `(div (@ (id ,id)
             (data-tuner "")
             (data-preset ,(symbol->string preset))
             (hidden "")
             (class ,(mk-class '(flex flex-col gap-4 py-2))))
          ;; What it hears, as a player reads it: the note it is nearest, how far
          ;; from it, and a needle that points at the cents.
          (div (@ (class ,(mk-class '(flex
                                      flex-row
                                      flex-wrap
                                      items-end
                                      gap-4))))
               (span (@ (id ,(part "-note"))
                         (class ,(mk-class '(text-5xl
                                             font-bold
                                             tabular-nums
                                             leading-none
                                             text-onyx-900
                                             dark:text-stone-100))))
                     "—")
               (div (@ (class ,(mk-class '(flex
                                           flex-row
                                           items-baseline
                                           gap-1
                                           pb-1))))
                    (span (@ (id ,(part "-cents"))
                             (class ,(mk-class '(text-xl
                                                 font-medium
                                                 tabular-nums
                                                 text-onyx-500
                                                 dark:text-stone-300))))
                          "")
                    (span (@ (aria-hidden "true")
                             (class ,(mk-class '(text-sm
                                                 text-onyx-500
                                                 dark:text-stone-300))))
                          "¢")))
          ;; The meter: a line, its ticks at a quarter and a half of the way out,
          ;; and a marker the script moves.  It is decoration -- the number above
          ;; is the reading -- so a screen reader is not read a moving bar.
          (div (@ (aria-hidden "true")
                  (class ,(mk-class '(wm-tuner-meter
                                      text-persia-pink-700
                                      dark:text-persia-pink-300))))
               (div (@ (class "wm-tuner-track")) "")
               ,@(map (lambda (cents)
                        `(div (@ (class ,(if (zero? cents)
                                            "wm-tuner-tick wm-tuner-tick-centre"
                                            "wm-tuner-tick"))
                                 (style ,(format #f "left: calc(50% + ~a%%)"
                                                 cents)))
                              ""))
                      '(-50 -25 0 25 50))
               (div (@ (id ,(part "-needle"))
                       (class "wm-tuner-needle"))
                    ""))
          (p (@ (aria-live "polite")
                (class ,(mk-class '(text-sm
                                    text-onyx-500
                                    dark:text-stone-300))))
             (span (@ (id ,(part "-status-idle"))
                      (hidden ""))
                   ,(G_ "waiting for a note"))
             (span (@ (id ,(part "-status-listening"))
                      (hidden ""))
                   ,(G_ "listening …"))
             (span (@ (id ,(part "-status-in-tune"))
                      (hidden ""))
                   ,(G_ "in tune"))
             (span (@ (id ,(part "-status-denied"))
                      (hidden ""))
                   ,(G_ "permission was refused or there is no microphone"))
             (span (@ (id ,(part "-status-unsupported"))
                      (hidden ""))
                   ,(G_ "this browser cannot read a pitch from a microphone")))
          (div (@ (class ,(mk-class '(flex
                                      flex-row
                                      flex-wrap
                                      gap-2
                                      items-center))))
               ,@(map (lambda (midi)
                        (tuner-string G_
                                      #:id id
                                      #:midi midi))
                      strings))
          (div (@ (class ,(mk-class '(flex
                                      flex-row
                                      flex-wrap
                                      gap-3
                                      items-center))))
               ,(icon-button #:icon 'microphone
                             #:id (part "-toggle")
                             #:on-click (format #f
                                                "wikimusicTunerToggle('~a')" id)
                             #:content `((span (@ (id ,(part "-start")))
                                               ,(G_ "listen"))
                                         (span (@ (id ,(part "-stop"))
                                                  (hidden ""))
                                               ,(G_ "stop listening"))))))))

(define* (tuner-panel G_ #:key id preset)
  `(div (@ (class ,(mk-class '(flex
                               flex-col
                               gap-4
                               rounded-3xl
                               border-2
                               border-persia-pink-500/25
                               dark:border-persia-pink-900/10
                               bg-stone-100
                               dark:bg-onyx-900
                               p-4
                               sm:p-6))))
        ,(tuner-widget G_
                       #:id id
                       #:preset preset)
        (p (@ (class ,(mk-class '(text-sm
                                  text-onyx-500
                                  dark:text-stone-300))))
           ,(G_ "the microphone is read here and the sound never leaves your browser"))))

(define* (tuner-page G_
                     #:key (preset 'guitar-standard) is-logged-in)
  "Return the page a reader tunes an instrument from, as SXML."
  (let* ((preset (preset-id-named (and preset (symbol->string preset))))
         (id (format #f "tuner-~a" preset)))
    (html-template G_
                   #:is-logged-in is-logged-in
                   #:title (format #f "~a — tuner | WikiMusic"
                                   (preset-name G_ preset))
                   #:description tuner-description
                   #:path (format #f "/tuner?preset=~a" preset)
                   #:json-ld (list (page-json-ld #:type "WebPage"
                                                 #:url (absolute-url "/tuner")
                                                 #:name (G_ "tuner")
                                                 #:description
                                                 tuner-description))
                   #:body `((div (@ (class ,(mk-class
                                             tuner-column-classes)))
                                 ,(h2 (G_ "tuner")
                                      #:family '(font-sans)
                                      #:weight '(font-light)
                                      #:size '(text-3xl))
                                 (p (@ (class ,(mk-class '(max-w-prose
                                                           text-md
                                                           text-onyx-500
                                                           dark:text-stone-300))))
                                    ,(G_ "play a note into your microphone and this page names it and says how far it is from the note it should be; press a string to hear that note yourself"))
                                 ,(preset-picker G_ #:current preset)
                                 ,(tuner-panel G_ #:id id #:preset preset)
                                 (p (@ (class ,(mk-class '(max-w-prose
                                                           text-sm
                                                           text-onyx-500
                                                           dark:text-stone-300))))
                                    ,(G_ "tune each string against the note it is named after: the needle is in the middle when the string is in tune, and the dot above it shows which string of the preset you are nearest")))))))
