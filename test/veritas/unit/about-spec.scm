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
;;; The page that introduces the project, and the link every other page offers
;;; to it.
;;;
;;; Two things are pinned here, either of which a reader would notice at once
;;; if it broke.  The first is that the page says all of what it promises: the
;;; four things a reader can do are four list items and not three, each is said
;;; once, and they are said in the order the list was written in -- a promise
;;; that reaches a reader twice, or out of order, reads as padding.
;;;
;;; The second is that the page and the front page read the same project.  The
;;; sentences are held in one place (see `(wikimusic prose)') and looked up in
;;; the catalog from there, so the tests read the untranslated msgid each
;;; sentence is looked up by; the wording a translator chose is their business
;;; and is never asserted here.  What the sentences *are* is pinned only loosely
;;; -- a phrase or two per paragraph -- because the machinery that keeps the two
;;; pages in step is the shared module, not this file.
;;;
;;; The addresses are read from the configuration rather than written out (see
;;; `(wikimusic config)'): which donation page, repository or picture an
;;; instance uses is its own business, and a spec that pinned the upstream
;;; ones would fail for a deployment that had correctly named its own.
;;;
;;; The page is rendered through the shell, so what is asserted against is what
;;; a browser is actually served: the head a crawler reads and the body a
;;; reader does.
;;;
;;; Every assertion below is a sibling of its test's other cases.  That is not
;;; a style choice: a veritas assertion is a procedure the test invokes, and
;;; the cases of a test are the *procedure* arguments it was given -- so an
;;; assertion written inside a `let', a `for-each' or a `when' is built, is
;;; passed along as that form's value, and never runs.  A test whose cases all
;;; vanished that way passes while asserting nothing, which is worse than
;;; failing.  The per-item tests are therefore expanded one case per test
;;; through `test-each', and everything else is written out.

(define-module (veritas unit about-spec)
  #:use-module (veritas veritas)
  #:use-module (veritas table)
  #:use-module (ice-9 format)
  #:use-module (ice-9 rdelim)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:use-module ((artanis utils) #:select (sxml->xml-string))
  #:use-module (app views about)
  #:use-module (app views index)
  #:use-module (wikimusic config)
  #:use-module (wikimusic html)
  #:use-module (wikimusic prose)
  #:export (spec))

;; A page is read through a translator that does not translate: what a test
;; reads is then the msgid the catalog is asked for, which is the only part of
;; a translated page that is the same in all four locales.
(define (G_ key) key)

(define (about-html)
  "Return the about page as HTML, which every test below reads."
  (sxml->xml-string (about-page G_)))

(define (footer-html)
  "Return the footer as HTML, which the link tests read."
  (sxml->xml-string (page-footer G_)))

;; The promises the page is expected to make are taken from the module the
;; project writes its own prose in rather than copied here.  What this spec is
;; about is the *page*: that all four are rendered, each exactly once, in order,
;; and as list items.  A copy of the wording here would have to be edited every
;; time the prose is, and the two copies would drift in the one direction that
;; matters -- a page that stopped showing a promise while the test still listed
;; it as one.
(define (doings)
  "Return the promises the page is expected to make."
  (project-promises G_))

;; The locales this instance ships, which is the same four `wikimusic-locales'
;; names: a label added to the footer is only offered in a language if that
;; language's catalog carries it.
(define locales
  '("en_US" "nl_NL" "es_ES" "ja_JP"))

(define (position-of html needle)
  "Return where NEEDLE first occurs in HTML, or #f when it does not."
  (string-contains html needle))

(define (at html needle)
  "Return the position of NEEDLE in HTML as a number, or #f.

An assertion about where two things are relative to one another wants numbers,
and `string-contains' answers #f for something that is not there at all; a
missing needle is turned into a failure here rather than into a comparison
error."
  (let ((at (string-contains html needle)))
    (if (and at (number? at)) at #f)))

(define (occurrences html needle)
  "Return how many times NEEDLE occurs in HTML."
  (let loop ((start 0) (found 0))
    (let ((next (string-contains html needle start)))
      (if next
          (loop (+ next (string-length needle)) (+ found 1))
          found))))

(define (catalog-translates? path msgid)
  "Return #t when the catalog at PATH carries a translation for MSGID.

The `.po' is read rather than the compiled `.mo' because it is the file a
translator edits: a compiled catalog is rebuilt from it at any time, so a
missing translation is a missing entry here and nothing else."
  (and (file-exists? path)
       (let ((lines (call-with-input-file path
                      (lambda (port)
                        (let loop ((lines '()))
                          (let ((line (read-line port)))
                            (if (eof-object? line)
                                (reverse lines)
                                (loop (cons line lines)))))))))
         (let loop ((lines lines))
           (cond
             ((null? lines) #f)
             ((string=? (car lines) (format #f "msgid \"~a\"" msgid))
              (let ((msgstr (if (null? (cdr lines)) "" (cadr lines))))
                (and (string-prefix? "msgstr \"" msgstr)
                     (not (string=? msgstr "msgstr \"\"")))))
             (else (loop (cdr lines))))))))

(define account-suite
  (suite "What the page says the project is"
         (test "it names what the project is"
               (assert-true (and (position-of (about-html)
                                              "non-profit community")
                                 #t)
                            #:name "the community is named")
               (assert-true (and (position-of (about-html) "musical education")
                                 #t)
                            #:name "and what it works towards"))

         (test "it says what the project is built on"
               (assert-true (and (position-of (about-html) "Lisp") #t)
                            #:name "the language is named")
               (assert-true (and (position-of (about-html)
                                              "database-backed architecture")
                                 #t)
                            #:name "and so is the architecture"))

         (test "it introduces the list of what a reader can do"
               (assert-true (and (position-of
                                  (about-html)
                                  "Whether you're a musician, educator, researcher, or simply a music lover, WikiMusic empowers you to:")
                                 #t)
                            #:name "the list is introduced"))

         (test "it ends on an invitation"
               (assert-true (and (position-of
                                  (about-html)
                                  "Join us in building an ever-growing library of musical knowledge — where every note tells a story.")
                                 #t)
                            #:name "the last line is the invitation"))))

(define doings-suite
  (test-each "What the page promises a reader can do"
             (doings)
             (lambda (doing)
               (let ((label (string-take doing 40)))
                 (test (format #f "“~a…” is promised" label)
                       (assert-true (and (position-of
                                          (about-html)
                                          (format #f "<li>~a</li>" doing))
                                         #t)
                                    #:name "it is an item of the list")
                       (assert-equal #:name "and it is said once"
                                     #:expect 1
                                     #:got (occurrences (about-html) doing)))))))

(define order-suite
  (suite "The order the page says things in"
         (test "the promises keep the order they were written in"
               (assert-true (apply < (map (lambda (doing)
                                            (at (about-html) doing))
                                          (doings)))
                            #:name "each one follows the one before it"))

         (test "the list stands under the sentence that introduces it"
               (assert-true (< (at (about-html) "WikiMusic empowers you to:")
                               (at (about-html) (car (doings))))
                            #:name "the introduction comes first"))

         (test "the account of the place comes before the ask"
               (assert-true (< (at (about-html) (last (doings)))
                               (at (about-html) (donate-url)))
                            #:name "nothing is asked for before anything is said"))))

;; The two pages read the same project: the front page says what the place is
;; called and what it is for, and the about page says all of it.  The sentences
;; therefore live in one module (see `(wikimusic prose)'), and these tests are
;; what says the pages actually read it -- a view that went back to writing its
;; own copy of a sentence would keep them passing only until the two copies
;; disagreed.
(define (front-html)
  "Return the front page as HTML, with a stand-in for the songs it lists."
  (sxml->xml-string (welcome-page G_ #:song-fragment '((p "songs")))))

(define shared-suite
  (suite "The words the two pages share"
         (test "both pages name the place the same way"
               (assert-true (and (position-of (about-html)
                                              (project-tagline G_))
                                 #t)
                            #:name "the about page says it")
               (assert-true (and (position-of (front-html)
                                              (project-tagline G_))
                                 #t)
                            #:name "and so does the front page"))

         (test "both pages close on the same invitation"
               (assert-true (and (position-of (about-html)
                                              (project-invitation G_))
                                 #t)
                            #:name "the about page invites")
               (assert-true (and (position-of (front-html)
                                              (project-invitation G_))
                                 #t)
                            #:name "and so does the front page"))

         (test "the account of the project belongs to the about page"
               ;; The front page opens on the collection, which is the whole
               ;; reason the about page exists; a paragraph of introduction
               ;; creeping back above the tiles is the thing to catch.
               (assert-false (position-of (front-html) (project-account G_))
                             #:name "the front page is still the collection"))

         (test "the one ask is the same control on both pages"
               (assert-true (and (position-of
                                  (about-html)
                                  (format #f "href=\"~a\"" (donate-url)))
                                 #t)
                            #:name "the about page asks")
               (assert-true (and (position-of
                                  (front-html)
                                  (format #f "href=\"~a\"" (donate-url)))
                                 #t)
                            #:name "and so does the front page")
               (assert-true (and (position-of (front-html)
                                              (project-support-ask G_))
                                 #t)
                            #:name "offered in the project's own words"))))

(define seo-suite
  (suite "What the page tells a crawler"
         (test "the title names the community"
               (assert-true (and (position-of (about-html)
                                              "<title>About WikiMusic")
                                 #t)
                            #:name "the page is titled"))

         (test "the description is the page's own one"
               (assert-true (and (position-of
                                  (about-html)
                                  "name=\"description\" content=\"WikiMusic is a non-profit community")
                                 #t)
                            #:name "a search result shows the community"))

         (test "the page says what kind of page it is"
               (assert-true (and (position-of (about-html)
                                              "\"@type\":\"AboutPage\"")
                                 #t)
                            #:name "the page states its own type")
               (assert-true (and (position-of (about-html) "\"@type\":\"NGO\"")
                                 #t)
                            #:name "and names the community as its subject"))))

(define link-suite
  (suite "The link to the page"
         (test "every page offers it"
               (assert-true (and (position-of (footer-html) "href=\"/about\"")
                                 #t)
                            #:name "the footer links to it")
               (assert-true (and (position-of (footer-html) ">about<") #t)
                            #:name "and says where it leads"))))

(define label-suite
  (test-each "The word the link is offered in"
             locales
             (lambda (locale)
               (test (format #f "~a has a word for it" locale)
                     (assert-true (catalog-translates?
                                   (format #f
                                           "sys/i18n/locale/~a/LC_MESSAGES/translate.po"
                                           locale)
                                   "about")
                                  #:name "the label is translated")))))

(define (spec)
  (veritas-run account-suite
               doings-suite
               shared-suite
               order-suite
               seo-suite
               link-suite
               label-suite))
