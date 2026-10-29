;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;;
;;; The section a version's Guitar Pro tab is offered in: the facts read out of
;;; the tab's own header, the name its file is saved under, and the markup a
;;; reader acts on.
;;;
;;; No tab is checked in here, and none is written: a tab is its author's, and
;;; a fixture of one would be a copy of their work.  So the two halves are
;;; tested apart.  The facts are read from the *shape* the reader answers with
;;; -- an association list, which is just data -- and the section is rendered
;;; from bytes that are not a tab at all.  That last case is not a stand-in for
;;; a real one: it is what an instance meets every time someone uploads a file
;;; the reader cannot follow, and its wording is the one a reader has to be able
;;; to trust, so it is pinned deliberately rather than incidentally.
;;;
;;; What is left to the browser is the drawing and the playing, which no test
;;; here can see.  What *is* pinned is that the words describing them belong to
;;; the page: every sentence the player can show is written by the view, so a
;;; translated page stays translated when a tablature loads, and the script that
;;; swaps them only un-hides one.  A script that carried its own English would
;;; pass every assertion below except that one.

(define-module (veritas unit guitarpro-view-spec)
  #:use-module (veritas veritas)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:use-module ((artanis utils)
                #:select (sxml->xml-string))
  #:use-module (app views song-content-view)
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
  "Return the opening tag TEXT gives the element with ID, or #f.

The tag is taken from the identifier to its first `>', which is everything the
element is told about itself -- its classes and whether it is hidden -- and is
what an assertion about one element should read, rather than the whole page."
  (let ((at (string-contains text
                             (string-append "id=\"" id "\""))))
    (and at
         (let ((close (string-index text #\> at)))
           (and close
                (substring text at close))))))

(define (fact facts label)
  "Return the value FACTS lists under LABEL, or #f when it lists none."
  (let ((found (assoc label facts)))
    (and found
         (cdr found))))

;; A version as the view meets it: the columns a section is rendered from, with
;; the tab it carries as the data URL a file input made of it.
(define* (version #:key (identifier "a-version")
                  (tab "data:application/octet-stream;base64,"))
  `((identifier unquote identifier)
    (version-name . "v1")
    (instrument-type . "guitar")
    (guitarpro-contents unquote tab)))

;; Bytes that decode, and are no Guitar Pro file: the header reader answers #f
;; for them, which is what the page has to be able to say.
(define not-a-tab
  "data:application/octet-stream;base64,dGhpcyBpcyBub3QgYSB0YWI=")

;; The empty data URL a file input leaves in a field a reader never touched.
(define untouched-tab
  "data:application/octet-stream;base64,")

(define song
  '((identifier . "a-song") (display-name . "A Song")))

(define facts-suite
  (suite "What a tab's own header is shown as"
         (test "every field a tab's author filled in is listed"
               (let ((facts (guitarpro-facts G_
                                             '((title . "a title")
                                               (artist . "an artist")
                                               (album . "an album")
                                               (tabber . "a tabber")))))
                 (assert-equal #:name "the title"
                               #:expect "a title"
                               #:got (fact facts "title"))
                 (assert-equal #:name "the artist"
                               #:expect "an artist"
                               #:got (fact facts "artist"))
                 (assert-equal #:name "the album"
                               #:expect "an album"
                               #:got (fact facts "album"))
                 (assert-equal #:name "who tabbed it"
                               #:expect "a tabber"
                               #:got (fact facts "tabbed by"))))

         (test "a field its author left empty is not listed at all"
               (let ((facts (guitarpro-facts G_
                                             '((title . "a title")
                                               (artist . "")
                                               (album . #f)
                                               (key-name . #f)))))
                 (assert-eq #:name "an empty artist"
                            #:expect #f
                            #:got (fact facts "artist"))
                 (assert-eq #:name "an album that was never read"
                            #:expect #f
                            #:got (fact facts "album"))
                 (assert-eq #:name "a key with no name"
                            #:expect #f
                            #:got (fact facts "music key"))))

         (test "the numbers a header always carries are always listed"
               (let ((facts (guitarpro-facts G_
                                             '((measures . 42) (tracks . 3)))))
                 (assert-equal #:name "the measures"
                               #:expect "42"
                               #:got (fact facts "measures"))
                 (assert-equal #:name "the tracks"
                               #:expect "3"
                               #:got (fact facts "tracks"))))

         (test "a tempo is written as a reader reads it"
               (assert-equal #:name "a tempo in beats per minute"
                             #:expect "132 bpm"
                             #:got (fact (guitarpro-facts G_
                                                          '((tempo . 132)))
                                         "tempo")))

         (test "a key is listed by the name of the key and not the count"
               (assert-equal #:name "two flats is B flat"
                             #:expect "Bb"
                             #:got (fact (guitarpro-facts G_
                                                          '((key-name . "Bb")))
                                         "music key")))))

(define filename-suite
  (suite "The name a tab is saved under"
         (test "the name says which song and which version it is"
               (assert-equal #:name "the two together"
                             #:expect "A Song - v1.gp5"
                             #:got (guitarpro-filename song
                                                       '((version-name . "v1")))))

         (test "the characters a file name cannot hold are replaced"
               (assert-equal #:name
                             "a song whose name holds a slash and a colon"
                             #:expect "A-B- C-D-.gp5"
                             #:got (guitarpro-filename '((display-name . "A/B: C*D?"))
                                                       '((version-name . "")))))

         (test "a name is still made of nothing"
               (assert-equal #:name "a version with no name of its own"
                             #:expect "wikimusic-tab.gp5"
                             #:got (guitarpro-filename '((display-name . ""))
                                                       '((version-name . ""))))
               (assert-equal #:name "and a song the page has not read yet"
                             #:expect "wikimusic-tab.gp5"
                             #:got (guitarpro-filename '()
                                                       '())))))

;; The same section, rendered once, so each assertion below names only the one
;; thing it is about.
(define (section-html)
  (html (render-guitarpro-section G_ song
                                  (version #:tab not-a-tab))))

(define* (assert-shows #:key name html needle)
  "Assert that HTML holds NEEDLE, naming the promise the test makes."
  (assert-true (contains? html needle)
               #:name name))

(define* (assert-omits #:key name html needle)
  "Assert that HTML does not hold NEEDLE, naming the promise the test makes."
  (assert-true (not (contains? html needle))
               #:name name))

(define section-suite
  (suite "The section a version's tab is offered in"
         (test "a version carrying no tab is offered none"
               (assert-eq #:name "a field a reader never touched"
                          #:expect '()
                          #:got (render-guitarpro-section G_ song
                                                          (version #:tab
                                                           untouched-tab)))
               (assert-eq #:name "and a version whose tab is not a tab at all"
                          #:expect '()
                          #:got (render-guitarpro-section G_ song
                                                          (version #:tab
                                                           "data:text/plain,not a tab"))))

         (test "a version carrying a tab offers it for download"
               (let ((file (or (opening-tag (section-html)
                                            "guitarpro-a-version-file") "")))
                 (assert-true (contains? file
                                         (string-append "href=\"" not-a-tab
                                                        "\""))
                              #:name "the link to the file")
                 (assert-true (contains? file "download=\"A Song - v1.gp5\"")
                              #:name "and the name it is saved under")))

         (test
          "and the offer to draw it here, which is a button and not a script"
          (assert-shows #:name "the button"
                        #:html (section-html)
                        #:needle
                        "wikimusicGuitarProShow('guitarpro-a-version')"))

         (test
          "the controls and the score are on the page before they are used"
          ;; Hidden until there is a score: there is nothing to play before
          ;; something is written down, and a reader should not be offered
          ;; a control that cannot do anything yet.
          (assert-true (contains? (or (opening-tag (section-html)
                                       "guitarpro-a-version-controls") "")
                                  "hidden")
                       #:name "the controls start hidden")
          (assert-shows #:name "the place a score is drawn in"
                        #:html (section-html)
                        #:needle "id=\"guitarpro-a-version-score\""))

         (test
          "playing and stopping are offered once there is something to play"
          (assert-shows #:name "playing"
                        #:html (section-html)
                        #:needle
                        "wikimusicGuitarProPlayPause('guitarpro-a-version')")
          (assert-shows #:name "and stopping"
                        #:html (section-html)
                        #:needle
                        "wikimusicGuitarProStop('guitarpro-a-version')"))

         (test "the words the player shows are the page's own"
               ;; Every sentence the player can show is written here, by the
               ;; view, and the script only un-hides one of them -- which is
               ;; what keeps a translated page translated while a tablature
               ;; loads.  A script carrying its own English would fail here.
               (assert-shows #:name "while it loads"
                             #:html (section-html)
                             #:needle "loading the tablature …")
               (assert-shows #:name "once it is drawn"
                #:html (section-html)
                #:needle "the tablature is drawn below: press play to hear it")
               (assert-shows #:name "and when it cannot be drawn"
                #:html (section-html)
                #:needle
                "this tablature could not be drawn here, but the file can still be downloaded")
               (assert-shows #:name
                "the state while loading is a place the script reaches"
                #:html (section-html)
                #:needle "id=\"guitarpro-a-version-status-loading\"")
               (assert-shows #:name "and the state once drawn"
                             #:html (section-html)
                             #:needle
                             "id=\"guitarpro-a-version-status-ready\"")
               (assert-shows #:name "and the state that failed"
                             #:html (section-html)
                             #:needle
                             "id=\"guitarpro-a-version-status-failed\""))

         (test
          "a tab whose header cannot be read says so and is still a download"
          (assert-shows #:name "the sentence"
           #:html (section-html)
           #:needle
           "the header of this tab could not be read, but the file itself can be downloaded"))

         (test "each version's section is named after the version it is"
               ;; A page holds every version of a song, so the parts a script
               ;; reaches have to be unambiguous: two tabs on one page must not
               ;; share a single identifier.
               (let ((other (html (render-guitarpro-section G_ song
                                                            (version
                                                             #:identifier
                                                             "another-version"
                                                             #:tab not-a-tab)))))
                 (assert-shows #:name "the score of the second version"
                               #:html other
                               #:needle
                               "id=\"guitarpro-another-version-score\"")
                 (assert-omits #:name "and not the first version's"
                               #:html other
                               #:needle "id=\"guitarpro-a-version-score\"")))))

(define (spec)
  (veritas-run facts-suite filename-suite section-suite))
