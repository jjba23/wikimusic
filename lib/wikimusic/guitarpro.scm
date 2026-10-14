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

;;; Reading the header of a Guitar Pro 5 file.
;;;
;;; A `.gp5' is the binary the Guitar Pro editors of that generation write, and
;;; a wiki page about a song is a good place to keep one: the tablature a
;;; reader can practise from, in the program that reads it.  A browser cannot
;;; open the file, so what wikimusic does with it is hold it, hand it back for
;;; download, and read enough of its own header to say what it contains.
;;;
;;; What is read here is the *header*, and only the header: the version of the
;;; format, the nine text fields the score keeps about itself, the notice
;;; lines, the lyrics, the tempo, the key and the counts of measures and
;;; tracks.  Everything a player would play -- measure headers, tracks, beats,
;;; notes -- lies behind those counts and is left where it is; the reader stops
;;; as soon as the two counts are in hand.  That is a deliberate limit: those
;;; parts are long, version-dependent and structured, and none of what this
;;; site shows a reader needs them.
;;;
;;; The layout below is a *sequence* of fields rather than a set of tagged
;;; records, and some fields exist only in some releases, so the reader walks
;;; the file rather than searching it.  One consequence is worth stating
;;; plainly: a mistake of a single byte anywhere shifts everything after it, so
;;; the reader checks itself as it goes (every string's declared length must
;;; match the bytes it occupies, and the file must still hold as many bytes as
;;; the next field needs) and answers @code{#f} rather than guessing when
;;; something does not add up.
;;;
;;; The reader was written against a Guitar Pro 5.10 tab and its counts were
;;; checked against the same song's Guitar Pro 7 export: the title, the tempo
;;; of 104, 79 measures and a single track all agree, which is what pins the
;;; sequence below -- in particular that each of the 64 MIDI channels occupies
;;; twelve bytes and that the nineteen navigation marks ahead of the counts
;;; are sixteen-bit values.
;;;
;;; Everything here answers #f instead of raising when a file cannot be read.
;;; An uploaded file is a reader's, not the site's: a file wikimusic cannot
;;; parse is still a file its author may download, so an unreadable header
;;; costs the page its metadata and nothing else.

(define-module (wikimusic guitarpro)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (srfi srfi-13)
  #:use-module (rnrs bytevectors)
  #:use-module (ice-9 format)
  #:export (base64-decode-string data-url? data-url-payload gp5-bytes-metadata
                                 gp5-metadata-of-data-url gp5-key-name))

;;; ====== The base64 a data URL carries ======
;;;
;;; A file reaches wikimusic the way the PDF of a version does: the browser
;;; turns it into a data URL and posts that, so what the row holds is text
;;; (`data:application/octet-stream;base64,AAAA...') and what a reader gets back
;;; is the file.  Reading the header therefore starts by turning exactly that
;;; text back into bytes, and Guile ships no base64 for it, so the two small
;;; procedures below are it.

(define *base64-alphabet*
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")

(define (base64-digit char)
  "Return the six-bit value CHAR stands for in base64, or #f for any other
character."
  (let ((index (string-index *base64-alphabet* char)))
    index))

(define (base64-text-digits text)
  "Return TEXT as the list of its base64 values, ignoring whitespace and
stopping at the padding that ends the text.

Raise an error on a character no base64 text contains: the value this reads
comes from a form, so refusing loudly at this edge is what keeps the rest of
the reader working on digits alone."
  (let loop
    ((chars (string->list text))
     (digits '()))
    (cond
      ((null? chars)
       (reverse digits))
      ((char=? (car chars) #\=)
       (reverse digits))
      ((char-whitespace? (car chars))
       (loop (cdr chars) digits))
      ((base64-digit (car chars))
       =>
       (lambda (digit)
         (loop (cdr chars)
               (cons digit digits))))
      (else (error "base64-decode-string: not a base64 character"
                   (car chars))))))

(define (base64-digits->bytes digits)
  "Return DIGITS -- six-bit values, most significant first -- as the bytes they
spell.

Four digits make three bytes; a text whose last group is short makes the two
bytes (three digits) or the single byte (two digits) those digits can spell,
which is what the padding of a base64 text stands for.  A text that ends in a
lone digit spells no byte at all and is an error."
  (define (three-of first second)
    (logior (ash first 2)
            (ash second -4)))
  (define (two-of second third)
    (logior (ash (logand second #xf) 4)
            (ash third -2)))
  (define (one-of third fourth)
    (logior (ash (logand third #x3) 6) fourth))
  (let loop
    ((digits digits)
     (bytes '()))
    (cond
      ((null? digits)
       (reverse bytes))
      ((null? (cdr digits))
       (error "base64-decode-string: the text ends in a lone base64 character"))
      (else (let* ((first (car digits))
                   (second (cadr digits))
                   (rest (cddr digits)))
              (if (null? rest)
                  (reverse (cons (three-of first second) bytes))
                  (let ((third (car rest))
                        (rest (cdr rest)))
                    (if (null? rest)
                        (reverse (cons (two-of second third)
                                       (cons (three-of first second) bytes)))
                        (let ((fourth (car rest)))
                          (loop (cdr rest)
                                (cons (one-of third fourth)
                                      (cons (two-of second third)
                                            (cons (three-of first second)
                                                  bytes)))))))))))))

(define (base64-decode-string text)
  "Return the bytes the base64 TEXT spells, as a bytevector.

Whitespace is ignored and the text ends at its padding, so a data URL is
decoded by handing over everything after its comma."
  (u8-list->bytevector (base64-digits->bytes (base64-text-digits text))))

(define (data-url? url)
  "Return #t when URL is a data URL, and #f for anything else -- including for
the empty string a version that carries no file holds."
  (and (string? url)
       (string-prefix? "data:" url)
       (string-index url #\,) #t))

(define (data-url-payload url)
  "Return the bytes the base64 data URL URL carries, or #f when URL is not a
base64 data URL or does not decode.

The value comes from a form and is stored as it arrived, so it is read as
untrusted: anything that is not a decodable data URL is answered with #f."
  (and (data-url? url)
       (catch #t
              (lambda ()
                (let* ((comma (string-index url #\,))
                       (head (substring url 0 comma))
                       (payload (substring url
                                           (+ comma 1))))
                  (and (string-contains head ";base64")
                       (base64-decode-string payload))))
              (lambda (key . args)
                #f))))

;;; ====== Walking the file ======

(define (bytevector-slice bytes start count)
  "Return COUNT bytes of BYTES from START on, as a new bytevector.

A header is read as slices of one file, and the bytevector library this module
has in reach copies a whole bytevector or nothing, so the slice is written
here.  Nothing large goes through it: the longest field a page reads is a
title."
  (let ((slice (make-bytevector count)))
    (let loop
      ((index 0))
      (if (= index count) slice
          (begin
            (bytevector-u8-set! slice index
                                (bytevector-u8-ref bytes
                                                   (+ start index)))
            (loop (+ index 1)))))))

;; A reader is a bytevector with a position in it.  The position is the only
;; mutable thing in this module: a format that is a sequence of fields is read
;; by advancing through it, and threading an index through every one of the
;; thirty-odd reads below would say the same thing less clearly.
(define-record-type <gp5-reader>
  (%make-gp5-reader bytes position) gp5-reader?
  (bytes gp5-reader-bytes)
  (position gp5-reader-position set-gp5-reader-position!))

(define (reader-remaining reader)
  "Return how many bytes of READER are still unread."
  (- (bytevector-length (gp5-reader-bytes reader))
     (gp5-reader-position reader)))

(define (reader-need! reader count)
  "Raise unless READER still holds COUNT unread bytes.

This is the check that keeps a truncated -- or simply unrecognised -- file from
being read as if it were whole: every read goes through it, so the first field
the file is too short for is where the header ends."
  (when (> count
           (reader-remaining reader))
    (throw 'gp5-header-unreadable
           'gp5-file
           (format #f
            "the file ends after ~a bytes, where the header still needed ~a more"
            (gp5-reader-position reader) count))))

(define (reader-bytes reader count)
  "Return the next COUNT bytes of READER as a bytevector, or raise when it
holds fewer."
  (when (< count 0)
    (throw 'gp5-header-unreadable
           'gp5-file
           (format #f "a field declares a length of ~a bytes" count)))
  (reader-need! reader count)
  (let ((start (gp5-reader-position reader)))
    (set-gp5-reader-position! reader
                              (+ start count))
    (bytevector-slice (gp5-reader-bytes reader) start count)))

(define (reader-skip! reader count)
  "Advance READER past COUNT bytes it does not read."
  (reader-need! reader count)
  (set-gp5-reader-position! reader
                            (+ (gp5-reader-position reader) count)))

(define (reader-u8 reader)
  "Return the next byte of READER, as an unsigned number."
  (reader-need! reader 1)
  (let* ((position (gp5-reader-position reader))
         (value (bytevector-u8-ref (gp5-reader-bytes reader) position)))
    (set-gp5-reader-position! reader
                              (+ position 1)) value))

(define (reader-s8 reader)
  "Return the next byte of READER, as a signed number."
  (reader-need! reader 1)
  (let* ((position (gp5-reader-position reader))
         (value (bytevector-s8-ref (gp5-reader-bytes reader) position)))
    (set-gp5-reader-position! reader
                              (+ position 1)) value))

(define (reader-s16 reader)
  "Return the next sixteen bits of READER, little-endian and signed.

Signed is the reading that matters: the navigation marks a file may carry are
measure numbers, and an unused one is written as -1."
  (bytevector-s16-ref (reader-bytes reader 2) 0
                      (endianness little)))

(define (reader-u16 reader)
  "Return the next sixteen bits of READER, little-endian and unsigned."
  (bytevector-u16-ref (reader-bytes reader 2) 0
                      (endianness little)))

(define (reader-s32 reader)
  "Return the next thirty-two bits of READER, little-endian and signed."
  (bytevector-s32-ref (reader-bytes reader 4) 0
                      (endianness little)))

;;; --- The three strings a Guitar Pro file writes ---

(define (bytevector-text bytes)
  "Return BYTES as the text it spells.

A Guitar Pro file stores text one byte per character, in whatever code page
the author's machine used -- there is no encoding field to consult.  UTF-8 is
tried first because a modern author's accented letters are written that way and
decoding them as single bytes would show mojibake; anything that is not valid
UTF-8 is read byte by byte instead, which is exact for the ASCII of a title
written in English and no worse than any other guess for the rest."
  (catch #t
         (lambda ()
           (utf8->string bytes))
         (lambda (key . args)
           (list->string (map integer->char
                              (bytevector->u8-list bytes))))))

(define (reader-byte-size-string reader size)
  "Read a byte-size string of SIZE bytes from READER.

The file writes a length byte and then a field of exactly SIZE bytes, in which
the first LENGTH of them are the text and the rest is padding.  The version of
the format itself is written this way, with a field of thirty bytes, which is
why the header of every file starts with a length byte and ends its first
thirty-one bytes on padding."
  (let ((length (reader-u8 reader)))
    (when (> length size)
      (throw 'gp5-header-unreadable
             'gp5-file
             (format #f "a string declares ~a bytes in a ~a byte field" length
                     size)))
    (bytevector-text (bytevector-slice (reader-bytes reader size) 0 length))))

(define (reader-int-byte-size-string reader)
  "Read an int-byte-size string from READER.

The same string as above, with a thirty-two bit length in front of it that
counts the string's own length byte: the text is LENGTH bytes after a byte
saying LENGTH.  The two counts must agree, and the reader raises when they do
not -- a single string read out of step would be enough to make everything
after it nonsense."
  (let ((total (reader-s32 reader)))
    (let ((length (reader-u8 reader)))
      (unless (= total
                 (+ length 1))
        (throw 'gp5-header-unreadable
               'gp5-file
               (format #f "a string declares ~a bytes and then ~a more" total
                       length)))
      (bytevector-text (reader-bytes reader length)))))

(define (reader-int-size-string reader)
  "Read an int-size string from READER: a thirty-two bit length and then that
many bytes of text, with no length byte of its own."
  (let ((length (reader-s32 reader)))
    (bytevector-text (reader-bytes reader length))))

;;; ====== The header, field by field ======
;;;
;;; Each region of the header has its own reader below, in the order the file
;;; writes them, so that the sequence is read off the module rather than out of
;;; one long procedure.

(define *score-information-fields*
  '(title subtitle
          artist
          album
          words
          music
          copyright
          tabber
          instructions))

(define (reader-score-information reader)
  "Read the nine text fields a score carries about itself, and the notice lines
that follow them, from READER.  Return them as an association list.

The fields are the headline facts of the song as its author typed them into
Guitar Pro: the title and subtitle, the artist and album, who wrote the words
and who wrote the music, the copyright line, who tabbed it and any
instructions.  The notices are the numbered notes of a published edition, and
a file usually has none."
  (let ((fields (map (lambda (name)
                       (cons name
                             (reader-int-byte-size-string reader)))
                     *score-information-fields*)))
    (let ((notice-count (reader-s32 reader)))
      (when (< notice-count 0)
        (throw 'gp5-header-unreadable
               'gp5-file
               (format #f "a file declares ~a notice lines" notice-count)))
      (let loop
        ((remaining notice-count)
         (notices '()))
        (if (zero? remaining)
            (append fields
                    (list (cons 'notices
                                (reverse notices))))
            (loop (- remaining 1)
                  (cons (reader-int-byte-size-string reader) notices)))))))

(define (reader-lyrics reader)
  "Read the lyrics block of READER and return its lines.

Five lines are written, each with the measure it starts at; a line an author
did not write is empty.  The track the lyrics belong to is written first and is
not read: the lines themselves are what a page can show."
  (reader-s32 reader)
  (let loop
    ((remaining 5)
     (lines '()))
    (if (zero? remaining)
        (reverse (filter (lambda (line)
                           (not (string-null? line))) lines))
        (begin
          (reader-s32 reader)
          (loop (- remaining 1)
                (cons (reader-int-size-string reader) lines))))))

(define (reader-rse-master-effect! reader later-than-5.0?)
  "Read past the master effect of READER.

Guitar Pro 5.1 added a volume to it and every version keeps a reserved word and
an eleven-band equaliser behind it -- ten bands and a gain, one signed byte
each -- so the region is skipped rather than read: nothing here is shown."
  (when later-than-5.0?
    (reader-s32 reader))
  (reader-s32 reader)
  (reader-skip! reader 11))

(define (reader-page-setup! reader)
  "Read past the page setup of READER.

The margin of a printed page, the size of the score on it, the header and
footer flags, and the ten placeholders a file writes for its own title and
page number."
  (reader-skip! reader
                (+ (* 7 4) 2))
  (let loop
    ((remaining 10))
    (unless (zero? remaining)
      (reader-int-byte-size-string reader)
      (loop (- remaining 1)))))

(define (reader-midi-channels! reader)
  "Read past the sixty-four MIDI channels of READER.

Four ports of sixteen channels are written in order, each as a thirty-two bit
instrument number, the six signed bytes of its mixing values and two blank
bytes.  They are read past and not read: an instrument number is what the
author's synth played through, not what the page is about."
  (let loop
    ((remaining 64))
    (unless (zero? remaining)
      (reader-skip! reader 12)
      (loop (- remaining 1)))))

(define (reader-directions! reader)
  "Read past the nineteen navigation marks of READER.

Each is the sixteen-bit number of the measure it points at -- a coda, a segno,
a fine and the fifteen signs that jump to and from them -- or -1 when it is
unused, which is the common case."
  (let loop
    ((remaining 19))
    (unless (zero? remaining)
      (reader-s16 reader)
      (loop (- remaining 1)))))

;;; ====== What the header says ======

;; The version of a file is written as the name of the format and the release
;; it made: the name is what a file of another generation is recognised by, and
;; the release is what is left once the name is taken off.
(define *gp5-format-name*
  "FICHIER GUITAR PRO v")

(define *gp5-fifth-generation*
  "FICHIER GUITAR PRO v5.")

(define (gp5-version-number version-string)
  "Return the release VERSION-STRING names -- the \"5.10\" of \"FICHIER GUITAR
PRO v5.10\" -- as the list of its numbers."
  (map string->number
       (string-split (substring version-string
                                (string-length *gp5-format-name*)) #\.)))

(define (version-after? version base)
  "Return #t when VERSION is a later release than BASE, both lists of numbers."
  (cond
    ((null? version)
     #f)
    ((null? base)
     #t)
    ((< (car version)
        (car base))
     #f)
    ((> (car version)
        (car base))
     #t)
    (else (version-after? (cdr version)
                          (cdr base)))))

;; A key signature is written as the number of accidentals it has, negative for
;; flats and positive for sharps, which is a count and not a name; a reader is
;; shown the name.  Guitar Pro's own range is the seven either way.
(define *gp5-keys*
  '((-7 . "Cb") (-6 . "Gb")
    (-5 . "Db")
    (-4 . "Ab")
    (-3 . "Eb")
    (-2 . "Bb")
    (-1 . "F")
    (0 . "C")
    (1 . "G")
    (2 . "D")
    (3 . "A")
    (4 . "E")
    (5 . "B")
    (6 . "F#")
    (7 . "C#")))

(define (gp5-key-name key)
  "Return the name of the key signature KEY names, or #f when the number is
none of Guitar Pro's fifteen."
  (let ((named (assv key *gp5-keys*)))
    (and named
         (cdr named))))

;;; ====== The whole header ======

(define (gp5-bytes-metadata bytes)
  "Return what the header of the Guitar Pro 5 file BYTES declares, as an
association list, or #f when BYTES is not a Guitar Pro 5 file or a field in it
cannot be read.

The walk is the file's own order, region by region, and it stops at the counts
of measures and tracks: everything after them is the music, which nothing on a
page needs.  The keys of the answer are

@table @code
@item version
@itemx version-string
The release of the format, as a list of numbers and as the string the file
spells.  A file of any other generation than the fifth is refused here, since
the fields that follow are laid out differently in it.
@item title @itemx subtitle @itemx artist @itemx album @itemx words @itemx
music @itemx copyright @itemx tabber @itemx instructions
The nine text fields of the score, empty strings included.
@item notices
The numbered notes of a published edition, usually none.
@item lyrics
The lyric lines the author wrote, empty ones left out.
@item tempo
The tempo in quarter notes per minute.
@item key @itemx key-name
The key signature as the number of accidentals and as the name of the key
they name, which is #f for a number no signature has.
@item octave
The octave offset of the score.
@item measures @itemx tracks
How many measures and how many tracks the score holds.
@item header-bytes
How many bytes of the file the header occupies, which is where the music
starts.
@end table

A count that cannot be true of any score -- a negative one -- is read as a
header that has come out of step rather than as a song: the answer is #f,
because a number no file means only ever means the reader lost its place
earlier."
  (catch 'gp5-header-unreadable
         (lambda ()
           (let* ((reader (%make-gp5-reader bytes 0))
                  (version-string (reader-byte-size-string reader 30)))
             (and (string-prefix? *gp5-fifth-generation* version-string)
                  (let* ((version (gp5-version-number version-string))
                         (later-than-5.0? (version-after? version
                                                          '(5 0)))
                         (information (reader-score-information reader))
                         (lyrics (reader-lyrics reader)))
                    (reader-rse-master-effect! reader later-than-5.0?)
                    (reader-page-setup! reader)
                    ;; The tempo has a name -- "Allegro" -- written before the
                    ;; number itself, and the sheet's own tempo is the number.
                    (reader-int-byte-size-string reader)
                    (let* ((tempo (reader-s32 reader))
                           ;; Releases after 5.0 write whether the sheet should show
                           ;; the tempo at all; a page shows the song's tempo
                           ;; whatever the sheet is set to display.
                           (hidden-tempo (and later-than-5.0?
                                              (reader-u8 reader)))
                           (key (reader-s8 reader))
                           (octave (reader-s32 reader)))
                      (reader-midi-channels! reader)
                      (reader-directions! reader)
                      ;; The master reverb, the last field before the counts.
                      (reader-s32 reader)
                      (let ((measures (reader-s32 reader))
                            (tracks (reader-s32 reader))
                            (header-bytes (gp5-reader-position reader)))
                        ;; A count out of a misread field is where a header that
                        ;; has come out of step shows itself, and the shape it
                        ;; takes is a number no score could have.
                        (when (or (< measures 0)
                                  (< tracks 0))
                          (throw 'gp5-header-unreadable
                                 'gp5-file
                                 (format #f
                                  "a file declares ~a measures and ~a tracks"
                                  measures tracks)))
                        (append information
                                (list (cons 'lyrics lyrics)
                                      (cons 'version version)
                                      (cons 'version-string version-string)
                                      (cons 'tempo tempo)
                                      (cons 'hidden-tempo hidden-tempo)
                                      (cons 'key key)
                                      (cons 'key-name
                                            (gp5-key-name key))
                                      (cons 'octave octave)
                                      (cons 'measures measures)
                                      (cons 'tracks tracks)
                                      (cons 'header-bytes header-bytes)))))))))
         (lambda (key . args)
           #f)))

(define (gp5-metadata-of-data-url url)
  "Return the header metadata of the Guitar Pro file the data URL URL carries,
or #f when URL holds no readable Guitar Pro 5 file.

This is how a stored version is read: the file itself is in the row as the
data URL the browser made of it, so a page that wants to say what the tab
holds decodes it here and nowhere else."
  (let ((bytes (data-url-payload url)))
    (and bytes
         (gp5-bytes-metadata bytes))))
