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

(define-module (wikimusic domain guitar-chord-guide)
  #:use-module (ice-9 regex)
  #:use-module (srfi srfi-1)
  #:export (extract-guitar-chords guitar-chord->fingering format-fretboard
                                  generate-guitar-chord-guide
                                  guitar-chord-database guitar-chord-pattern))

;; Regex pattern matching standard guitar-chord names (e.g., C, F#, Bm7, Emaj9, Ab)
(define guitar-chord-pattern
  (make-parameter (make-regexp "[A-G][b#]?(maj|min|m|dim|aug|sus)?[0-9]*")))

(define (extract-guitar-chords text)
  "Parses ASCII text and extracts a list of unique guitar-chord names."
  (let loop
    ((start 0)
     (acc '()))
    (let ((match (regexp-exec (guitar-chord-pattern) text start)
            ))
      (if (not match)
          (delete-duplicates (reverse acc))
          (let ((guitar-chord (match:substring match 0))
                (next-start (match:end match)))
            (loop next-start
                  (cons guitar-chord acc)))))))

(define (guitar-chord->fingering guitar-chord)
  "Looks up 6-string fret positions for a given guitar-chord symbol."
  (let ((entry (assoc guitar-chord (guitar-chord-database))))
    (if entry
        (cdr entry) "xxxxxx")))
; Default/unknown representation

(define (format-fretboard guitar-chord fingering)
  "Renders a guitar-chord and its string fingering into a readable text format."
  (string-append guitar-chord
                 " -> "
                 "E:"
                 (string (string-ref fingering 0))
                 " "
                 "A:"
                 (string (string-ref fingering 1))
                 " "
                 "D:"
                 (string (string-ref fingering 2))
                 " "
                 "G:"
                 (string (string-ref fingering 3))
                 " "
                 "B:"
                 (string (string-ref fingering 4))
                 " "
                 "e:"
                 (string (string-ref fingering 5))))

(define (generate-guitar-chord-guide text)
  "Main function: extracts guitar-chords from ASCII text and prints guitar playing guide."
  (let* ((guitar-chords (extract-guitar-chords text))
         (fingerings (map (lambda (c)
                            (cons c
                                  (guitar-chord->fingering c))) guitar-chords)))
    (map (lambda (pair)
           (format-fretboard (car pair)
                             (cdr pair))) fingerings)))

;; Dictionary mapping chord names to fret positions
(define guitar-chord-database
  (make-parameter '(("C" . "x32010") ("Cm" . "x35543")
                    ("C7" . "x32310")
                    ("Cmaj7" . "x32000")
                    ("Cm7" . "x35343")
                    ("Cadd9" . "x32030")
                    ("Csus2" . "x30010")
                    ("Csus4" . "x33010")
                    ("Cdim7" . "xx1212")
                    ("Db" . "x46664")
                    ("D" . "xx0232")
                    ("Dm" . "xx0231")
                    ("D7" . "xx0212")
                    ("Dmaj7" . "xx0222")
                    ("Dm7" . "xx0211")
                    ("D9" . "x54555")
                    ("Dsus2" . "xx0230")
                    ("Dsus4" . "xx0233")
                    ("Eb" . "x68886")
                    ("E" . "022100")
                    ("Em" . "022000")
                    ("E7" . "020100")
                    ("Emaj7" . "021100")
                    ("Em7" . "020000")
                    ("Emaj9" . "021102")
                    ("Esus4" . "022200")
                    ("E7#9" . "07678x")
                    ("F" . "133211")
                    ("Fm" . "133111")
                    ("F7" . "131211")
                    ("Fmaj7" . "132211")
                    ("Fm7" . "131111")
                    ("F#" . "244322")
                    ("F#m" . "244222")
                    ("F#7" . "242322")
                    ("F#m7b5" . "2x2210")
                    ("G" . "320003")
                    ("Gm" . "355333")
                    ("G7" . "320001")
                    ("Gmaj7" . "320002")
                    ("Gm7" . "353333")
                    ("Gsus4" . "320013")
                    ("Gadd9" . "320005")
                    ("Ab" . "466544")
                    ("Abm" . "466444")
                    ("A" . "x02220")
                    ("Am" . "x02210")
                    ("A7" . "x02020")
                    ("Amaj7" . "x02120")
                    ("Am7" . "x02010")
                    ("Aadd9" . "x02420")
                    ("Asus2" . "x02200")
                    ("Asus4" . "x02230")
                    ("Am7b5" . "x01010")
                    ("Bb" . "x13331")
                    ("Bbm" . "x13321")
                    ("B" . "x24442")
                    ("Bm" . "x24432")
                    ("B7" . "x21202")
                    ("Bmaj7" . "x24342")
                    ("Bm7" . "x20202")
                    ("Bm7b5" . "x2323x"))))
