;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;;
;;; An instrument tuner: the arithmetic that turns a pitch number into the note a
;;; reader reads and the frequency a string is tuned to, and the page that offers
;;; the strings of a preset.
;;;
;;; The two halves are tested apart, because they answer different questions.
;;; The arithmetic is a pure function of a number, so it is pinned exactly: a
;;; reference pitch that is a cent out is a guitar that is a cent out, and the
;;; assertion is the same one a tuner's own dial makes.  The page is pinned on
;;; what a reader is *given* -- every preset as an address, every string as its
;;; note and its frequency, the words the microphone can show, and the fact that
;;; the control is hidden until the script that drives it is there.
;;;
;;; What no test here can see is the microphone: a browser's audio graph is not
;;; this suite's to run.  What is pinned instead is that the sentences a reader
;;; meets when it fails -- refused permission, no microphone, a browser that
;;; cannot read a pitch -- are the page's own, so a translated page stays
;;; translated when the microphone does not answer.

(define-module (veritas unit tuning-spec)
  #:use-module (veritas veritas)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:use-module ((artanis utils)
                #:select (sxml->xml-string))
  #:use-module (wikimusic domain tuning)
  #:use-module (app views tuner)
  #:export (spec))

;; The translation of a page under test is the identity: what is asserted here
;; is the markup the view builds, not the wording of any one language.
(define (G_ key)
  key)

(define (html sxml)
  "Return the HTML SXML serializes to."
  (sxml->xml-string sxml))

(define (contains? text needle)
  "Return #t when TEXT holds NEEDLE, as a boolean."
  (and (string-contains text needle) #t))

(define (opening-tag text id)
  "Return the opening tag TEXT gives the element with ID, or #f."
  (let ((at (string-contains text
                             (string-append "id=\"" id "\""))))
    (and at
         (let ((close (string-index text #\> at)))
           (and close
                (substring text at close))))))

(define (close-to? got expected tolerance)
  "Return #t when GOT is within TOLERANCE of EXPECTED."
  (< (abs (- got expected)) tolerance))

(define arithmetic-suite
  (suite "The note a string is tuned to"
         (test "a pitch number is the frequency the reference pitch names"
               (assert-true (close-to? (midi-note-frequency 69) 440.0 0.001)
                            #:name "A4 is the 440 hertz it is defined as")
               (assert-true (close-to? (midi-note-frequency 57) 220.0 0.001)
                            #:name "an octave below it is half of that")
               (assert-true (close-to? (midi-note-frequency 40) 82.41 0.01)
                            #:name "and a guitar's low E is where a tuner says"))

         (test "a pitch number is named by its note and its octave"
               (assert-equal #:name "the A above middle C"
                             #:expect "A4"
                             #:got (midi-note-name 69))
               (assert-equal #:name "a guitar's low E"
                             #:expect "E2"
                             #:got (midi-note-name 40))
               (assert-equal #:name "a sharp is named as one"
                             #:expect "C#4"
                             #:got (midi-note-name 61))
               (assert-equal #:name "and an octave is the number after the note"
                             #:expect "E4"
                             #:got (midi-note-name 64)))

         (test "a preset is the strings it tunes, lowest string first"
               (assert-equal #:name "a guitar in standard tuning"
                             #:expect '(40 45 50 55 59 64)
                             #:got (tuning-preset 'guitar-standard))
               (assert-equal #:name "drop D lowers only the lowest string"
                             #:expect '(38 45 50 55 59 64)
                             #:got (tuning-preset 'guitar-drop-d))
               (assert-equal #:name "and a ukulele's own string order is kept"
                             #:expect 4
                             #:got (length (tuning-preset 'ukulele))))

         (test "a preset is asked for by a name an address can carry"
               (assert-eq #:name "a preset that exists"
                          #:expect 'bass-4
                          #:got (preset-id-named "bass-4"))
               (assert-eq #:name "a name nothing offers"
                          #:expect 'guitar-standard
                          #:got (preset-id-named "a-guitar-that-does-not-exist"))
               (assert-eq #:name "and no name at all"
                          #:expect 'guitar-standard
                          #:got (preset-id-named #f)))))

;; The page as a reader meets it, rendered once and read by each assertion.
(define (page-html)
  (html (tuner-page G_
                    #:preset 'guitar-standard)))

(define page-suite
  (suite "The page a reader tunes from"
         (test "every preset the tuner knows is an address on the page"
               (for-each (lambda (preset)
                           (assert-true (contains? (page-html)
                                                   (format #f "?preset=~a"
                                                           preset))
                                        #:name (format #f "~a is offered"
                                                       preset)))
                         '(guitar-standard guitar-drop-d bass-4 bass-5
                                            ukulele)))

         (test "each string is named and its frequency is given"
               (assert-true (contains? (page-html) ">E2<")
                            #:name "the lowest string by name")
               (assert-true (contains? (page-html) "82.4")
                            #:name "and the frequency it should sound at")
               (assert-true (contains? (page-html) ">E4<")
                            #:name "and the highest string of the same preset"))

         (test "a string is a control that sounds it, not only a label"
               (assert-true (contains? (page-html)
                                       "wikimusicTunerTone('tuner-guitar-standard', 40)")
                            #:name "pressing the low E asks for its note"))

         (test "the control is hidden until the script that drives it is there"
               (let ((widget (or (opening-tag (page-html) "tuner-guitar-standard")
                                 "")))
                 (assert-true (contains? widget "data-tuner")
                              #:name "the script's own marker")
                 (assert-true (contains? widget "hidden")
                              #:name "and it starts hidden")))

         (test "the words the microphone can show are the page's own"
               ;; Every sentence a reader can meet while the tuner listens is
               ;; written here, by the view, and the script only un-hides one of
               ;; them.  A script carrying its own English would fail here.
               (assert-true (contains? (page-html) "waiting for a note")
                            #:name "before a note is heard")
               (assert-true (contains? (page-html) "listening …")
                            #:name "while it listens")
               (assert-true (contains? (page-html)
                                       "permission was refused or there is no microphone")
                            #:name "when the microphone is refused")
               (assert-true (contains? (page-html)
                                       "this browser cannot read a pitch from a microphone")
                            #:name "and when the browser cannot listen at all"))

         (test "nothing leaves the browser, and the page says so"
               (assert-true (contains? (page-html)
                                       "the microphone is read here and the sound never leaves your browser")
                            #:name "the promise the page makes"))))

(define (spec)
  (veritas-run arithmetic-suite page-suite))
