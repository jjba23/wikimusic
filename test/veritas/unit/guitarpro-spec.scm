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

;;; Commentary:
;;;
;;; Reading the header of a Guitar Pro 5 file, and the base64 a data URL
;;; carries.  Neither can be tested against a file the repository holds -- a tab
;;; is its author's, and a fixture of one would be a copy of their work -- so
;;; the tests below *write* the files they read: every field of the format that
;;; matters is spelled out here, in the file's own order, and then read back.
;;;
;;; That is a real test of the thing most likely to break.  The header is a
;;; sequence and not a set of records, so what can go wrong is not "the title
;;; is read badly" but "the reader is one byte out from the title onward", and
;;; a written file catches exactly that: the count of bytes the writer produced
;;; is what the reader has to say it consumed, and a field added, dropped or
;;; measured wrongly in either one moves that number.
;;;
;;; What it cannot catch is a misreading of the format itself -- if the units
;;; below were wrong in the same way in both places, writing and reading would
;;; still agree.  That is settled elsewhere: the reader was checked against a
;;; real Guitar Pro 5.10 tab, whose title, tempo of 104, 79 measures and single
;;; track all agree with the same song exported from Guitar Pro 7.  The one
;;; piece of it worth repeating here is that a 5.1 file carries two fields a
;;; 5.0 file does not, which is why both generations are written below.

(define-module (veritas unit guitarpro-spec)
  #:use-module (veritas veritas)
  #:use-module (srfi srfi-1)
  #:use-module (rnrs bytevectors)
  #:use-module (ice-9 format)
  #:use-module (wikimusic guitarpro)
  #:export (spec))

;;; ====== Writing a file the reader can read ======

;; The alphabet of base64, spelled out rather than imported: the point of these
;; tests is to pin the decoding against texts whose bytes are known, so the
;; encoding they are compared with must not come from the module under test.
(define alphabet
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")

(define (base64-encode-string text)
  "Return TEXT as a base64 text, which is what a browser makes of an uploaded
file before the data URL is posted."
  (let* ((bytes (bytevector->u8-list (string->utf8 text)))
         (padding (modulo (- 3
                             (modulo (length bytes) 3)) 3)))
    (let loop
      ((bytes bytes)
       (chars '()))
      (if (null? bytes)
          (list->string (append chars
                                (make-list padding #\=)))
          (let* ((step (min 3
                            (length bytes)))
                 (group (take bytes step))
                 (first (car group))
                 (second (if (> (length group) 1)
                             (list-ref group 1) 0))
                 (third (if (> (length group) 2)
                            (list-ref group 2) 0))
                 (digits (list (ash first -2)
                               (logior (ash (logand first #x3) 4)
                                       (ash second -4))
                               (logior (ash (logand second #xf) 2)
                                       (ash third -6))
                               (logand third #x3f)))
                 ;; Only the values a byte of the group took part in are
                 ;; written: a group of one byte is two characters and two
                 ;; padding marks, and a group of two is three and one.  A
                 ;; character written for a byte that is not there decodes
                 ;; back as a zero byte, which is how a round trip through an
                 ;; encoder that does this wrongly comes to hold NULs.
                 (written (take digits
                                (+ step 1))))
            (loop (drop bytes step)
                  (append chars
                          (map (lambda (digit)
                                 (string-ref alphabet digit)) written))))))))

(define (integer-bytes value width)
  "Return VALUE as WIDTH little-endian bytes, two's complement, which is how
every number in a Guitar Pro file is written."
  (let loop
    ((remaining width)
     (value value)
     (bytes '()))
    (if (zero? remaining)
        ;; The bytes come back most significant last, which is how the file
        ;; writes them: a number no reader could read otherwise is exactly the
        ;; kind of mistake these tests are here to catch, in either direction.
        (reverse bytes)
        (loop (- remaining 1)
              (ash value -8)
              (cons (logand value #xff) bytes)))))

(define (text-bytes text)
  "Return TEXT as the bytes a file writes it as: one byte per character."
  (map char->integer
       (string->list text)))

(define (byte-size-string-field size text)
  "Return a byte-size string of SIZE bytes: a length byte and then the field
itself, the text first and the padding after it."
  (append (integer-bytes (string-length text) 1)
          (text-bytes text)
          (make-list (- size
                        (string-length text)) 0)))

(define (int-byte-size-string-field text)
  "Return an int-byte-size string: a length that counts the string's own length
byte, then that byte, then the text."
  (append (integer-bytes (+ 1
                            (string-length text)) 4)
          (integer-bytes (string-length text) 1)
          (text-bytes text)))

(define (int-size-string-field text)
  "Return an int-size string: a length and then that many bytes of text."
  (append (integer-bytes (string-length text) 4)
          (text-bytes text)))

(define* (gp5-file-bytes #:key (version "5.10")
                         (title "a title")
                         (artist "")
                         (notices '())
                         (lyrics '(""))
                         (tempo 120)
                         (key 0)
                         (measures 8)
                         (tracks 2))
  "Return a Guitar Pro 5 header holding the given values, as a bytevector.

Every region of the header is written here in the order the format writes it,
with the two fields a release after 5.0 added -- the master volume and the flag
saying whether the sheet shows its tempo -- left out of a 5.0 file, so that
both generations are written the way they really are."
  (let ((later-than-5.0? (not (equal? version "5.00"))))
    (u8-list->bytevector (append (byte-size-string-field 30
                                                         (string-append
                                                          "FICHIER GUITAR PRO v"
                                                          version))
                                 ;; The nine text fields of the score.
                                 (append-map int-byte-size-string-field
                                             (list title
                                                   ""
                                                   artist
                                                   ""
                                                   ""
                                                   ""
                                                   ""
                                                   ""
                                                   ""))
                                 (integer-bytes (length notices) 4)
                                 (append-map int-byte-size-string-field
                                             notices)
                                 ;; The lyrics: the track they belong to, then five lines of the
                                 ;; measure each starts at and the words themselves.
                                 (integer-bytes 0 4)
                                 (append-map (lambda (line)
                                               (append (integer-bytes 1 4)
                                                       (int-size-string-field
                                                        line)))
                                             (append lyrics
                                                     (make-list (- 5
                                                                   (length
                                                                    lyrics))
                                                                "")))
                                 (if later-than-5.0?
                                     (integer-bytes 100 4)
                                     '())
                                 (integer-bytes 0 4)
                                 (make-list 11 0)
                                 ;; Page setup: the page, its four margins, the score's proportion
                                 ;; of it, the header and footer flags, and ten placeholders.
                                 (append (make-list 28 0)
                                         (integer-bytes 0 2))
                                 (append-map int-byte-size-string-field
                                             (make-list 10 ""))
                                 ;; The tempo, under the name an edition gives it.
                                 (int-byte-size-string-field "")
                                 (integer-bytes tempo 4)
                                 (if later-than-5.0?
                                     (integer-bytes 0 1)
                                     '())
                                 (integer-bytes key 1)
                                 (integer-bytes 0 4)
                                 ;; Sixty-four MIDI channels, then the navigation marks.
                                 (append-map (lambda (channel
                                                       )
                                               (make-list 12 0))
                                             (iota 64))
                                 (make-list 38 0)
                                 ;; The master reverb, and the two counts the music follows.
                                 (integer-bytes 0 4)
                                 (integer-bytes measures 4)
                                 (integer-bytes tracks 4)))))

(define (bytes-up-to bytes count)
  "Return the first COUNT bytes of BYTES."
  (u8-list->bytevector (take (bytevector->u8-list bytes) count)))

(define (header-alist bytes)
  "Return what the reader makes of BYTES, failing the run when it is #f."
  (or (gp5-bytes-metadata bytes)
      (error "the reader refused a file these tests wrote")))

(define (file-data-url bytes)
  "Return BYTES as the data URL a browser makes of an uploaded file."
  (string-append "data:application/octet-stream;base64,"
                 (base64-encode-string (list->string (map integer->char
                                                          (bytevector->u8-list
                                                           bytes))))))

(define (metadata-of options)
  "Return what the reader makes of the file written with OPTIONS.

The file is written afresh for every field that is asked about.  That is
because of how a test is written rather than what it tests: the cases of a
test are the assertion values in its body, so an assertion whose file is bound
and then read many times would leave only the last one of them counted."
  (header-alist (apply gp5-file-bytes options)))

;; The file whose every field is read back, and one that a version of a song
;; would really hold: a title, an artist, who wrote the words, notices, an
;; unusual tempo and key, and numbers on either side of the usual few.
(define fields-file-options
  '(#:version "5.10"
    #:title "a title"
    #:artist "an artist"
    #:notices ("first notice" "second notice")
    #:lyrics ("the words of the song")
    #:tempo 132
    #:key -2
    #:measures 42
    #:tracks 3))

(define (fields-file-field key)
  "Return what the reader makes of KEY in the file above."
  (assq-ref (metadata-of fields-file-options) key))

(define (written-file)
  "Return a Guitar Pro 5 header as these tests write one."
  (gp5-file-bytes #:title "a title"))

(define (written-file-short-by count)
  "Return the header above with its last COUNT bytes cut off.

The counts of measures and tracks are the last thing a header holds, so a file
that stops just short of them is the shape a truncated -- or partly written --
file really has."
  (let ((bytes (written-file)))
    (bytes-up-to bytes
                 (- (bytevector-length bytes) count))))

(define posted-file-options
  '(#:title "through a data url"
    #:tempo 90))

;; The data URL a browser would post the file above as.
(define posted-file-url
  (file-data-url (apply gp5-file-bytes posted-file-options)))

;;; ====== The suites ======

(define base64-suite
  (suite "What a base64 text spells"
         (test "a text whose bytes are known decodes to them"
               ;; The four lengths a base64 text comes in: a whole group of
               ;; four characters, and the three that end in padding.
               (assert-equal #:name "two characters"
                             #:expect "h"
                             #:got (utf8->string (base64-decode-string "aA==")))
               (assert-equal #:name "three characters"
                             #:expect "hi"
                             #:got (utf8->string (base64-decode-string "aGk=")))
               (assert-equal #:name "five characters"
                             #:expect "hello"
                             #:got (utf8->string (base64-decode-string
                                                  "aGVsbG8=")))
               (assert-equal #:name "six characters is two whole groups"
                             #:expect "hello!"
                             #:got (utf8->string (base64-decode-string
                                                  "aGVsbG8h"))))

         (test "the encoding a browser does round-trips through the decoder"
               ;; The encoder here is the test's own, and the three texts above
               ;; are what it must produce for them: with that pinned, a round
               ;; trip says the two agree on every byte.
               (let ((text "a"))
                 (assert-equal #:name
                  "one character, the shortest text that needs padding"
                  #:expect text
                  #:got (utf8->string (base64-decode-string (base64-encode-string
                                                             text)))))
               (let ((text "abc"))
                 (assert-equal #:name "one whole group of three"
                               #:expect text
                               #:got (utf8->string (base64-decode-string (base64-encode-string
                                                                          text)))))
               (let ((text "wikimusic"))
                 (assert-equal #:name "a word"
                               #:expect text
                               #:got (utf8->string (base64-decode-string (base64-encode-string
                                                                          text)))))
               (let ((text "a title with an accent: café"))
                 (assert-equal #:name
                               "a text whose bytes are not its characters"
                               #:expect text
                               #:got (utf8->string (base64-decode-string (base64-encode-string
                                                                          text))))))

         (test "a text broken across lines is read as one"
               ;; A data URL is one long line, but nothing about base64 says
               ;; the padding has to be the only thing that ends a group.
               (assert-equal #:name
                             "whitespace between the characters is ignored"
                             #:expect "hello"
                             #:got (utf8->string (base64-decode-string
                                                  "aGVs\n bG8=\n"))))

         (test "a text that is not base64 is refused rather than guessed at"
               (assert-error (lambda ()
                               (base64-decode-string "aGk*="))
                             #:name "a character outside the alphabet")
               ;; A text is read in groups of four, so what cannot happen is a
               ;; single character left over at the end: "aGVsbG8" is seven
               ;; characters and perfectly good, "aGVsb" is five and is not.
               (assert-error (lambda ()
                               (base64-decode-string "aGVsb"))
                             #:name "a text that ends in a lone character"))))

(define data-url-suite
  (suite "What a data URL holds"
         (test "an empty value is not a data URL"
               ;; A version with no tab holds the empty string, and it is not
               ;; an error: there is simply no file there.
               (assert-eq #:name "the empty string"
                          #:expect #f
                          #:got (data-url? ""))
               (assert-eq #:name "nor is a path"
                          #:expect #f
                          #:got (data-url? "/songs/uuid/1")))

         (test "a base64 data URL is one, and its bytes come back"
               (assert-eq #:name "a file posted by a browser"
                          #:expect #t
                          #:got (data-url?
                                 "data:application/octet-stream;base64,aGk="))
               (assert-equal #:name "the bytes after the comma"
                             #:expect "hi"
                             #:got (utf8->string (data-url-payload
                                                  "data:application/octet-stream;base64,aGk="))))

         (test
          "a data URL that holds something other than base64 holds no bytes"
          ;; Answers #f rather than raising: the value comes from a form.
          (assert-eq #:name "a text data URL"
                     #:expect #f
                     #:got (data-url-payload "data:text/plain,hello"))
          (assert-eq #:name "a base64 text that does not decode"
                     #:expect #f
                     #:got (data-url-payload
                            "data:application/octet-stream;base64,aGk*=")))

         (test "a version's own file is read through its data URL"
               (assert-equal #:name "the title"
                             #:expect "through a data url"
                             #:got (assq-ref (gp5-metadata-of-data-url
                                              posted-file-url)
                                             'title))
               (assert-eqv #:name "the tempo"
                           #:expect 90
                           #:got (assq-ref (gp5-metadata-of-data-url
                                            posted-file-url)
                                           'tempo)))))

(define header-suite
  (suite "What the header of a Guitar Pro 5 file declares"
         (test "every field of a written file is read back"
               (assert-equal #:name "the release"
                             #:expect '(5 10)
                             #:got (fields-file-field 'version))
               (assert-equal #:name "the title"
                             #:expect "a title"
                             #:got (fields-file-field 'title))
               (assert-equal #:name "the artist, two fields along"
                             #:expect "an artist"
                             #:got (fields-file-field 'artist))
               (assert-equal #:name "the notice lines, in order"
                             #:expect '("first notice" "second notice")
                             #:got (fields-file-field 'notices))
               (assert-equal #:name "the lyrics"
                             #:expect '("the words of the song")
                             #:got (fields-file-field 'lyrics))
               (assert-eqv #:name "the tempo"
                           #:expect 132
                           #:got (fields-file-field 'tempo))
               (assert-eqv #:name "the key signature"
                           #:expect -2
                           #:got (fields-file-field 'key))
               (assert-equal #:name "the key it names"
                             #:expect "Bb"
                             #:got (fields-file-field 'key-name))
               (assert-eqv #:name "the measures"
                           #:expect 42
                           #:got (fields-file-field 'measures))
               (assert-eqv #:name "the tracks"
                           #:expect 3
                           #:got (fields-file-field 'tracks)))

         (test "the reader consumes exactly the header and nothing more"
               ;; This is the test the sequence lives or dies by: the writer
               ;; knows how long its header is, and the reader has to stop
               ;; there -- one byte either way and every field would be read
               ;; from the wrong place in a real file.  The shapes differ in
               ;; the fields whose length is not fixed, which is where a
               ;; reader that measured something by a constant would drift.
               (let ((bytes (gp5-file-bytes)))
                 (assert-eqv #:name "the plain file"
                             #:expect (bytevector-length bytes)
                             #:got (assq-ref (header-alist bytes)
                                             'header-bytes)))
               (let ((bytes (gp5-file-bytes #:title "")))
                 (assert-eqv #:name "a file with no title"
                             #:expect (bytevector-length bytes)
                             #:got (assq-ref (header-alist bytes)
                                             'header-bytes)))
               (let ((bytes (gp5-file-bytes #:title
                             "a much longer title than the last one")))
                 (assert-eqv #:name "a file with a long title"
                             #:expect (bytevector-length bytes)
                             #:got (assq-ref (header-alist bytes)
                                             'header-bytes)))
               (let ((bytes (gp5-file-bytes #:notices '("a notice"
                                                        "another one"))))
                 (assert-eqv #:name "a file with two notice lines"
                             #:expect (bytevector-length bytes)
                             #:got (assq-ref (header-alist bytes)
                                             'header-bytes)))
               (let ((bytes (gp5-file-bytes #:version "5.00")))
                 (assert-eqv #:name "a file of the earlier release"
                             #:expect (bytevector-length bytes)
                             #:got (assq-ref (header-alist bytes)
                                             'header-bytes)))
               (let ((bytes (gp5-file-bytes #:tempo 40
                                            #:key 4
                                            #:measures 400
                                            #:tracks 32)))
                 (assert-eqv #:name "a file with numbers at their widest"
                             #:expect (bytevector-length bytes)
                             #:got (assq-ref (header-alist bytes)
                                             'header-bytes))))

         (test "a header written by a release after 5.0 is read the same way"
               ;; The two fields 5.1 added sit between the lyrics and the
               ;; tempo; a reader that knows only one generation reads the
               ;; other's tempo out of its master effect.
               (assert-eqv #:name "the tempo of a 5.1 file"
                           #:expect 155
                           #:got (assq-ref (metadata-of '(#:version "5.10"
                                                          #:tempo 155
                                                          #:tracks 5))
                                           'tempo))
               (assert-eqv #:name "the track count of a 5.1 file"
                           #:expect 5
                           #:got (assq-ref (metadata-of '(#:version "5.10"
                                                          #:tempo 155
                                                          #:tracks 5))
                                           'tracks))
               (assert-eqv #:name "the tempo of a 5.0 file"
                           #:expect 155
                           #:got (assq-ref (metadata-of '(#:version "5.00"
                                                          #:tempo 155
                                                          #:tracks 5))
                                           'tempo))
               (assert-eqv #:name "the track count of a 5.0 file"
                           #:expect 5
                           #:got (assq-ref (metadata-of '(#:version "5.00"
                                                          #:tempo 155
                                                          #:tracks 5))
                                           'tracks)))

         (test
          "a file that is not a readable Guitar Pro 5 file is answered with #f"
          ;; Nothing here may raise: the page a version is shown on asks
          ;; for its metadata every time it is rendered, and a file the
          ;; site cannot read is still a file its author may download.
          (let ((bytes (make-bytevector 0)))
            (assert-eq #:name "nothing at all"
                       #:expect #f
                       #:got (gp5-bytes-metadata bytes)))
          (let ((bytes (string->utf8 "hello, this is not a tab")))
            (assert-eq #:name "a text file"
                       #:expect #f
                       #:got (gp5-bytes-metadata bytes)))
          (let ((bytes (string->utf8
                        "%PDF-1.4 and some padding after the header")))
            (assert-eq #:name "a pdf"
                       #:expect #f
                       #:got (gp5-bytes-metadata bytes)))
          (let ((bytes (string->utf8 "FICHIER GUITAR PRO v4.06 padding")))
            (assert-eq #:name "a Guitar Pro 4 file"
                       #:expect #f
                       #:got (gp5-bytes-metadata bytes))))

         (test "a file of the right generation that is cut short is refused"
               (assert-eq #:name "a header missing its last fields"
                          #:expect #f
                          #:got (gp5-bytes-metadata (written-file-short-by 10)))
               (assert-eq #:name "a file missing its whole header"
                          #:expect #f
                          #:got (gp5-bytes-metadata (bytes-up-to (written-file)
                                                                 40))))

         (test "a field whose two lengths disagree is refused"
               ;; The reader checks every int-byte-size string's length against
               ;; its length byte, which is what stops a file that has come out
               ;; of step from being read as though it had not.
               (let ((tampered (bytevector-copy (gp5-file-bytes #:title
                                                                "a title"))))
                 ;; The title's length is the first field after the version's
                 ;; thirty-one bytes, and its low byte is written over with one
                 ;; the text does not have.
                 (bytevector-u8-set! tampered 31 99)
                 (assert-eq #:name
                            "a string that claims a length it does not have"
                            #:expect #f
                            #:got (gp5-bytes-metadata tampered))))

         (test "a file whose counts cannot be true is refused"
               ;; A count read out of the wrong place is how a header that has
               ;; already gone wrong shows itself, so the reader does not
               ;; believe a negative one.
               (assert-eq #:name "a negative measure count"
                          #:expect #f
                          #:got (gp5-bytes-metadata (gp5-file-bytes #:measures
                                                                    -1))))))

(define key-suite
  (suite "The key a header names"
         (test "each signature of the fifteen is named"
               (assert-equal #:name "no accidentals is C"
                             #:expect "C"
                             #:got (gp5-key-name 0))
               (assert-equal #:name "two flats is B flat"
                             #:expect "Bb"
                             #:got (gp5-key-name -2))
               (assert-equal #:name "one sharp is G"
                             #:expect "G"
                             #:got (gp5-key-name 1))
               (assert-equal #:name "seven sharps is C sharp"
                             #:expect "C#"
                             #:got (gp5-key-name 7))
               (assert-equal #:name "seven flats is C flat"
                             #:expect "Cb"
                             #:got (gp5-key-name -7)))

         (test "a number no signature has is not named at all"
               (assert-eq #:name "one flat too many"
                          #:expect #f
                          #:got (gp5-key-name -8))
               (assert-eq #:name "and one sharp too many"
                          #:expect #f
                          #:got (gp5-key-name 8)))))

(define (spec)
  (veritas-run base64-suite data-url-suite header-suite key-suite))
