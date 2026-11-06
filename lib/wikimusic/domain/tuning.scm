;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; What a string is tuned to.
;;;
;;; An instrument is tuned to pitches, and a pitch is a number: every note is a
;;; key of a piano, every fret a step up that keyboard, and the frequency a
;;; string sounds at follows from the note's distance from the reference pitch.
;;; This module is that arithmetic and the presets a reader is offered, and
;;; nothing else -- no markup, no cookies, no browser -- so the numbers a tuner
;;; shows can be checked without a microphone in front of them.
;;;
;;; The presets are listed lowest string first, which is the order a player
;;; reads a tuning in and the order the page draws its strings in.  A ukulele's
;;; re-entrant tuning is why that order is written down rather than sorted: its
;;; fourth string is the *highest* of the four, and a tuner that sorted them
;;; would be showing a different instrument.

(define-module (wikimusic domain tuning)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 format)
  #:export (tuning-presets tuning-preset preset-id-named
            midi-note-frequency midi-note-name))

;;; The strings of each preset, as the notes of a piano keyboard: A4 -- the
;;; reference pitch a tuner is calibrated against -- is 69.
(define tuning-presets
  '((guitar-standard 40 45 50 55 59 64)
    (guitar-drop-d 38 45 50 55 59 64)
    (guitar-half-step 39 44 49 54 58 63)
    (bass-4 28 33 38 43)
    (bass-5 23 28 33 38 43)
    (ukulele 67 60 64 69)))

;;; The preset a reader who has not chosen one is given, and the one a name
;;; nothing offers falls back to.
(define default-preset
  'guitar-standard)

(define (tuning-preset preset)
  "Return the notes PRESET tunes its strings to, lowest string first.

PRESET is a symbol a link carried, so a name nothing offers answers the
default guitar tuning rather than an empty instrument."
  (or (assq-ref tuning-presets preset)
      (assq-ref tuning-presets default-preset)))

(define (preset-id-named name)
  "Return the preset NAME names, or the default when no preset is called that.

NAME is whatever a page was asked for in its query string -- a string, or #f
when nothing was asked -- so it is compared against the presets that exist
rather than turned into a symbol and looked up: a name nobody offers is a
reader's guess at an address, not a new preset."
  (let ((offered (and (string? name)
                      (find (lambda (preset)
                              (string=? name (symbol->string (car preset))))
                            tuning-presets))))
    (if offered (car offered) default-preset)))

;;; The reference pitch.  A4 is 440 hertz by definition and every other note is
;;; its own distance from that: twelve equal steps to the octave, each the
;;; twelfth root of two.
(define (midi-note-frequency note)
  "Return the frequency NOTE sounds at, in hertz."
  (* 440.0 (expt 2 (/ (- note 69) 12))))

(define note-names
  '#("C" "C#" "D" "D#" "E" "F" "F#" "G" "G#" "A" "A#" "B"))

(define (midi-note-name note)
  "Return NOTE as a player writes it: the note, then the octave it is in."
  (format #f "~a~a"
          (vector-ref note-names (modulo note 12))
          (- (quotient note 12) 1)))
