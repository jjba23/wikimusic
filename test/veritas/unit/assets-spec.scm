;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;;
;;; Refreshing the type and the glyphs into `pub/vendor' is a fetch, and a fetch
;;; needs a network -- so what is pinned here is the part of that job that
;;; decides what the refreshed tree says, and which is where a refresh can go
;;; quietly wrong.  A stylesheet that is copied down keeps naming the host it
;;; came from: the files land beside it while every reader of the page is still
;;; sent to Google, jsDelivr or the author's own server, which is the whole
;;; thing the copies are there to stop.  Nothing about fetching would show that
;;; -- the files would all be present and correct -- so it is pinned by
;;; rewriting a stylesheet that is *written* here, in the shape the two upstream
;;; answers are known to have, and reading the result back.
;;;
;;; Two things are therefore checked, neither of which needs an address to be
;;; live: that no address of anybody else's survives a rewrite, and that the
;;; copy still describes what is beside it.  The second is the one that would
;;; otherwise be found by a reader with a broken page in front of them: a face
;;; is named after the family, the subset of Unicode it carries and its slope,
;;; and a name built from the wrong block -- the previous subset, the wrong
;;; slope -- points at a file that is a different font, or at nothing at all.
;;;
;;; Phosphor's stylesheet is checked the same way and for the same reason.  Its
;;; face offers the set as woff2, woff, ttf and svg, one to a line; the vendored
;;; copy ships the woff2 alone, so the copy has to stop naming the three that
;;; are not beside it -- and has to stay a stylesheet while doing it, which is
;;; what the balanced braces and the terminated clause are for.  A face that
;;; ended on a comma, or on nothing, is a page whose glyphs are all missing.

(define-module (veritas unit assets-spec)
  #:use-module (veritas veritas)
  #:use-module (ice-9 format)
  #:use-module (srfi srfi-13)
  #:use-module (resources assets fetch)
  #:export (spec))

(define (count-character character text)
  "Return how many times CHARACTER occurs in TEXT."
  (let loop
    ((index 0)
     (count 0))
    (if (>= index
            (string-length text)) count
        (loop (+ index 1)
              (if (char=? (string-ref text index) character)
                  (+ count 1) count)))))

;; What Google answers with for the two families the interface is set in.  The
;; shape is the one the service is known to use: every face is announced by the
;; subset it carries, states its own slope, and names the file it is read from
;; on the gstatic host -- which is exactly the address that must not survive.
(define google-answer
  (string-append "/* symbols2 */\n"
   "@font-face {\n"
   "  font-family: 'Intel One Mono';\n"
   "  font-style: italic;\n"
   "  font-weight: 300 700;\n"
   "  font-display: swap;\n"
   "  src: url(https://fonts.gstatic.com/s/intelonemono/v25/aaa111.woff2) format('woff2');
"
   "  unicode-range: U+2000-2001, U+23B8-23BD;
"
   "}\n"
   "/* latin */\n"
   "@font-face {\n"
   "  font-family: 'Intel One Mono';\n"
   "  font-style: normal;\n"
   "  font-weight: 300 700;\n"
   "  font-display: swap;\n"
   "  src: url(https://fonts.gstatic.com/s/intelonemono/v25/bbb222.woff2) format('woff2');
"
   "  unicode-range: U+0000-00FF, U+0131;\n"
   "}\n"
   "/* latin */\n"
   "@font-face {\n"
   "  font-family: 'Plus Jakarta Sans';\n"
   "  font-style: italic;\n"
   "  font-weight: 200 800;\n"
   "  font-display: swap;\n"
   "  src: url(https://fonts.gstatic.com/s/plusjakartasans/v9/ccc333.woff2) format('woff2');
"
   "  unicode-range: U+0000-00FF, U+0131;\n"
   "}\n"))

;; The same, as Phosphor publishes it: one face, four files, one to a line.
(define phosphor-answer
  (string-append "@font-face {\n"
                 "  font-family: \"Phosphor\";\n"
                 "  src:\n"
                 "    url(\"./Phosphor.woff2\") format(\"woff2\"),
"
                 "    url(\"./Phosphor.woff\") format(\"woff\"),
"
                 "    url(\"./Phosphor.ttf\") format(\"truetype\"),
"
                 "    url(\"./Phosphor.svg#Phosphor\") format(\"svg\");
"
                 "  font-weight: normal;\n"
                 "  font-style: normal;\n"
                 "  font-display: block;\n"
                 "}\n"
                 "\n"
                 ".ph {\n"
                 "  font-family: \"Phosphor\" !important;\n"
                 "  line-height: 1;\n"
                 "}\n"))

;; The rewrite answers with two things -- the stylesheet with its addresses
;; made relative, and the faces it names as a list of addresses paired with the
;; names to keep them under -- so both are reached through this one call, in the
;; order the stylesheet writes them.
(define (rewritten-google-stylesheet)
  "Return what rewriting `google-answer' makes of it."
  (car (rewrite-google-stylesheet google-answer)))

(define (rewritten-google-faces)
  "Return the faces a rewrite of `google-answer' names, in order."
  (cadr (rewrite-google-stylesheet google-answer)))

;; What a refresh keeps a face under.  A reader cannot get the subset or the
;; slope out of Google's own hash of an address, so a file in the tree is named
;; after the three things that say what is inside it -- and the block it was
;; named in is what tells the namer which subset and slope those are.
(define naming-suite
  (suite "A face is named after what it carries"
         (test "the family, the subset and the slope are all in the name"
               (assert-equal #:name "a straight face names no slope"
                             #:expect "intelonemono-latin.woff2"
                             #:got (font-file-name
                                    "https://fonts.gstatic.com/s/intelonemono/v25/bbb222.woff2"
                                    "latin" #f))
               (assert-equal #:name "a sloped one says so"
                             #:expect "plusjakartasans-latin-italic.woff2"
                             #:got (font-file-name
                                    "https://fonts.gstatic.com/s/plusjakartasans/v9/ccc333.woff2"
                                    "latin" #t))
               (assert-equal #:name
                             "and a subset that is not latin is kept apart"
                             #:expect "intelonemono-symbols2-italic.woff2"
                             #:got (font-file-name
                                    "https://fonts.gstatic.com/s/intelonemono/v25/aaa111.woff2"
                                    "symbols2" #t)))))

;; The rewrite itself: nobody else's address survives it, and everything that is
;; not an address is left as the stylesheet wrote it.
(define rewrite-suite
  (suite "A fetched stylesheet names the files beside it"
         (test "the address of the host it came from is gone"
               (let ((css (rewritten-google-stylesheet)))
                 (assert-true (not (string-contains css "fonts.gstatic.com"))
                              #:name "no gstatic face is asked for")
                 (assert-true (not (string-contains css "https://"))
                              #:name "nor any other absolute address")
                 (assert-true (and (string-contains css
                                    "url(./intelonemono-latin.woff2)") #t)
                              #:name "the file beside it is named instead")))

         (test "what the face says about itself is kept"
               (let ((css (rewritten-google-stylesheet)))
                 (assert-true (and (string-contains css "format('woff2')") #t)
                              #:name "the format stays on the line")
                 (assert-true (and (string-contains css "font-display: swap;")
                                   #t)
                              #:name
                              "so does what the face asks of the reader")
                 (assert-true (and (string-contains css
                                    "unicode-range: U+0000-00FF, U+0131;") #t)
                              #:name "and the range it carries")
                 (assert-true (and (string-contains css "/* symbols2 */") #t)
                              #:name "the line saying which subset follows")
                 (assert-equal #:name
                               "and the stylesheet is as long as it was"
                               #:expect (count-character #\newline
                                                         google-answer)
                               #:got (count-character #\newline css))))

         (test "each face is named for the block it stands in"
               ;; The subsets and the slopes are read in the order the
               ;; stylesheet writes them, so a face is named while the line that
               ;; describes it is still in hand.  The lists are compared whole,
               ;; in order, because the mistake this catches is exactly a name
               ;; taken from the block before or after.
               (assert-equal #:name "the addresses and the names line up"
                             #:expect '(("https://fonts.gstatic.com/s/intelonemono/v25/aaa111.woff2" . "intelonemono-symbols2-italic.woff2")
                                        ("https://fonts.gstatic.com/s/intelonemono/v25/bbb222.woff2" . "intelonemono-latin.woff2")
                                        ("https://fonts.gstatic.com/s/plusjakartasans/v9/ccc333.woff2" . "plusjakartasans-latin-italic.woff2"))
                             #:got (rewritten-google-faces)))

         (test "every face the answer named is a face to fetch"
               (assert-length #:name "three faces, three files"
                              #:expect 3
                              #:got (rewritten-google-faces)))))

;; Phosphor's answer offers four files for one face; the tree ships one.
(define pruning-suite
  (suite "An icon set is copied with what is served of it"
         (test "the face names the file that is beside it, and only it"
               (let ((css (prune-phosphor-stylesheet phosphor-answer)))
                 (assert-true (and (string-contains css
                                    "url(\"./Phosphor.woff2\") format(\"woff2\");")
                                   #t)
                              #:name "the woff2 clause ends the list")
                 (assert-true (not (string-contains css "Phosphor.woff\""))
                              #:name "the older woff is not named")
                 (assert-true (not (string-contains css "Phosphor.ttf"))
                              #:name "nor the ttf")
                 (assert-true (not (string-contains css "Phosphor.svg"))
                              #:name "nor the svg")))

         (test "what is left is still a stylesheet"
               (let ((css (prune-phosphor-stylesheet phosphor-answer)))
                 (assert-equal #:name "the braces still balance"
                               #:expect (count-character #\{ phosphor-answer)
                               #:got (count-character #\{ css))
                 (assert-equal #:name "and they close as often"
                               #:expect (count-character #\} phosphor-answer)
                               #:got (count-character #\} css))
                 (assert-true (and (string-contains css
                                    "font-family: \"Phosphor\";") #t)
                              #:name "the face keeps its family")
                 (assert-true (and (string-contains css ".ph {") #t)
                              #:name "and the class the glyphs are worn with")
                 (assert-true (not (string-contains css ",;"))
                              #:name "no clause is left dangling")))

         (test "a stylesheet with nothing to prune is left alone"
               ;; The rule is written against the three formats that are not
               ;; shipped, so a face that names none of them passes through it
               ;; unchanged -- which is what a set that stops publishing them
               ;; would need, and what this must not mangle if it does.
               (assert-equal #:name "the text comes back as it went in"
                             #:expect (prune-phosphor-stylesheet (prune-phosphor-stylesheet
                                                                  phosphor-answer))
                             #:got (prune-phosphor-stylesheet phosphor-answer)))))

(define (spec)
  (veritas-run naming-suite rewrite-suite pruning-suite))
