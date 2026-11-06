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
  #:export (tuning-presets tuning-families tuning-presets-in
            tuning-preset-family
            tuning-preset preset-id-named
            midi-note-frequency midi-note-name))

;;; The strings of each preset, as the notes of a piano keyboard: A4 -- the
;;; reference pitch a tuner is calibrated against -- is 69.
;;;
;;; Each entry is the preset's name, the family of instrument it is an
;;; instrument of, and then its strings.  The family is what a page groups the
;;; presets by, so a reader with a cello is not scanning a list of guitars to
;;; find it, and it is written here rather than derived from the name: a name is
;;; an address a reader can type, a family is what the instrument *is*.
;;;
;;; The order is the order a reader reads them in: one family after another,
;;; and within a family the tuning a player would reach for first.
(define tuning-presets
  '((guitar-standard guitar 40 45 50 55 59 64)
    (guitar-drop-d guitar 38 45 50 55 59 64)
    (guitar-half-step guitar 39 44 49 54 58 63)
    (guitar-full-step-down guitar 38 43 48 53 57 62)
    (guitar-open-d guitar 38 45 50 54 57 62)
    (guitar-open-g guitar 38 43 50 55 59 62)
    (guitar-open-e guitar 40 47 52 56 59 64)
    (guitar-dadgad guitar 38 45 50 55 57 62)
    (guitar-seven-string guitar 35 40 45 50 55 59 64)
    (bass-4 bass 28 33 38 43)
    (bass-drop-d bass 26 33 38 43)
    (bass-5 bass 23 28 33 38 43)
    (bass-6 bass 23 28 33 38 43 48)
    (ukulele ukulele 67 60 64 69)
    (ukulele-baritone ukulele 45 50 55 59)
    (mandolin folk 55 62 69 76)
    (banjo folk 50 55 59 62 67)
    (banjo-tenor folk 48 55 62 69)
    (violin orchestral 55 62 69 76)
    (viola orchestral 48 55 62 69)
    (cello orchestral 36 43 50 57)
    (double-bass orchestral 28 33 38 43)))

;;; The families in the order the page shows them.  A family is a symbol and the
;;; word the page offers it under is the page's, because a word is a thing to
;;; translate and a symbol is a thing to look up.
(define tuning-families
  '(guitar bass ukulele folk orchestral))

(define (tuning-presets-in family)
  "Return the presets that belong to FAMILY, in the order they are offered."
  (filter (lambda (preset)
            (eq? (cadr preset) family))
          tuning-presets))

(define (tuning-preset-family preset)
  "Return the family the preset PRESET is an instrument of, or the default's."
  (let ((entry (assq preset tuning-presets)))
    (if entry (cadr entry) 'guitar)))

;;; The preset a reader who has not chosen one is given, and the one a name
;;; nothing offers falls back to.
(define default-preset
  'guitar-standard)

(define (tuning-preset preset)
  "Return the notes PRESET tunes its strings to, lowest string first.

PRESET is a symbol a link carried, so a name nothing offers answers the
default guitar tuning rather than an empty instrument."
  (cddr (or (assq preset tuning-presets)
            (assq default-preset tuning-presets))))

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
