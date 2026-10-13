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
;;; The pages a reader gets when a request cannot be served.  They are
;;; rendered by artanis from outside any route, so they are the one part of the
;;; site a test can render in full without a server, a database or a request:
;;; `error-page-html' is exactly what artanis hands the client.
;;;
;;; Two properties are worth pinning beyond the wording.  One is that the page
;;; is serialized with artanis's serializer and not SXML's: the shell carries
;;; inline script, and an escaping serializer turns `&&' in it into
;;; `&amp;&amp;', which no browser decodes inside a script element -- a page
;;; that renders and does nothing.  The other is the class vocabulary: the
;;; page asks for a set of utility classes, and a class neither shipped sheet
;;; defines is a no-op, so the frosted pane would silently not be frosted.
;;; The check for that lives here because this is the page a test can hold.

(define-module (veritas unit error-pages-spec)
  #:use-module (veritas veritas)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 textual-ports)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:use-module ((artanis env) #:select (get-syspage-handler))
  #:use-module ((artanis utils) #:select (sxml->xml-string))
  #:use-module (app views error)
  #:export (spec))

(define olive-bundle "pub/css/wikimusic.olive.min.css")

(define (all-matches pattern string)
  "Return every match of the regular expression PATTERN in STRING, as strings."
  (fold-matches (make-regexp pattern) string '()
                (lambda (match tail)
                  (cons (match:substring match 1) tail))))

(define (rendered status)
  "Return the HTML artanis serves for STATUS."
  (error-page-html status))

(define (classes-in html)
  "Return every class token the class attributes of HTML name, once each."
  (delete-duplicates
   (append-map (lambda (attribute) (string-tokenize attribute))
               (all-matches "class=\"([^\"]*)\"" html))))

(define (sheets-for html)
  "Return the two stylesheets that style HTML: the bundle it links, and the
companion sheet inlined into its own style elements."
  (string-append
   (call-with-input-file olive-bundle get-string-all)
   (string-join (all-matches "<style[^>]*>(.*?)</style>" html) "")))

(define (defined-by-sheet? class sheet)
  "Return #t when SHEET selects on CLASS.

Olive escapes the characters its utility names may contain, so a class is
looked for as a selector of its own: `.bg-stone-100/75' is written
`.bg-stone-100\\/75', and looking for the escaped spelling is also what keeps
a class from being found inside a longer one -- `.hover:bg-stone-100/75'
holds `hover:' between its dot and the rest."
  (string-contains sheet
                   (string-append "."
                                  (list->string
                                   (append-map (lambda (char)
                                                 (if (or (char-alphabetic? char)
                                                         (char-numeric? char)
                                                         (char=? char #\-))
                                                     (list char)
                                                     (list #\\ char)))
                                               (string->list class))))))

;; hygguile's icon component names a Phosphor glyph, and Phosphor's own
;; stylesheet is fetched from a CDN rather than shipped here.
(define (icon-class? class)
  (string-prefix? "ph" class))

(define wording-suite
  (suite "What an error page says"
         (test "a page leads with a headline of its own"
               (assert-true (and (string? (error-headline 404))
                                 (not (string-null? (error-headline 404)))
                                 #t)
                            #:name "a 404 has a headline")
               (assert-true (and (string? (error-detail 404))
                                 (not (string-null? (error-detail 404)))
                                 #t)
                            #:name "and something to explain itself")
               (assert-true (not (equal? (error-headline 404)
                                         (error-headline 500)))
                            #:name "the two codes do not share wording")
               (assert-true (not (equal? (error-detail 404)
                                         (error-detail 500)))
                            #:name "nor do their explanations"))

         (test "a page is drawn in the tone its class of refusal is read in"
               ;; The glyph and the tone come from the same row, so a status
               ;; the table does not spell out is still drawn as the kind of
               ;; refusal it is -- a 502 as a server failure, a 418 as a
               ;; request the server would not take -- rather than as a page
               ;; with no mark on it at all.
               (for-each (lambda (pair)
                           (let ((status (car pair))
                                 (expected (cdr pair)))
                             (assert-equal #:name (format #f
                                                          "a ~a is read as a ~a"
                                                          status expected)
                                           #:expect (car (error-note expected))
                                           #:got (car (error-note status)))))
                         '((502 . 500) (503 . 500) (418 . 400) (451 . 400)))
               (assert-true (and (member 408 error-statuses) #t)
                            #:name "a request that timed out has a page"))

         (test "a status with no wording of its own still describes itself"
               (assert-true (and (string-contains (error-headline 418) "418")
                                 #t)
                            #:name "an unnamed status is named in its headline")
               (assert-true (and (string? (error-detail 418))
                                 (not (string-null? (error-detail 418)))
                                 #t)
                            #:name "and it still has an explanation")
               (assert-true (not (equal? (error-detail 418) (error-detail 404)))
                            #:name "which is not the wording of a status that has one"))

         (test "an error page describes what the reader can do"
               ;; A reader cannot act on what the server did wrong, so the
               ;; detail is written as the reader's way forward.
               (assert-true (and (string-contains (error-detail 500)
                                                  "again")
                                 #t)
                            #:name "a 500 offers to be tried again")
               (assert-true (and (string-contains (error-detail 404)
                                                  "below")
                                 #t)
                            #:name "a 404 points at what is still there"))))

(define rendering-suite
  (suite "Rendering an error page"
         (test "the page is a whole document of the site's own shell"
               (let ((html (rendered 404)))
                 (assert-true (and (string-prefix? "<!DOCTYPE html" html) #t)
                              #:name "it starts with a doctype")
                 (assert-true (and (string-contains html "WikiMusic") #t)
                              #:name "it is titled a WikiMusic page")
                 (assert-true (and (string-contains html
                                                    "/css/wikimusic.olive.min.css")
                                   #t)
                              #:name "it links the site's stylesheet")
                 (assert-true (and (string-contains html "<nav") #t)
                              #:name "it carries the navigation")
                 (assert-true (and (string-contains html "<footer") #t)
                              #:name "and the footer")))

         (test "the page says which status it is"
               (for-each (lambda (status)
                           (let ((html (rendered status)))
                             (assert-true (and (string-contains html
                                                                (number->string
                                                                 status))
                                               #t)
                                          #:name (format #f
                                                         "a ~a page shows its code"
                                                         status))
                             (assert-true (and (string-contains
                                                html
                                                (error-headline status))
                                               #t)
                                          #:name (format #f
                                                         "a ~a page leads with its own wording"
                                                         status))
                             (assert-true
                              (and (string-contains html
                                                    (format #f
                                                            "ph-~a"
                                                            (car (error-note
                                                                  status))))
                                   #t)
                              #:name (format #f
                                             "a ~a page is drawn with a glyph"
                                             status))))
                         error-statuses))

         (test "the reader is offered a way out"
               (let ((html (rendered 404)))
                 (for-each (lambda (href)
                             (assert-true (and (string-contains
                                                html
                                                (string-append "href=\"" href
                                                               "\""))
                                               #t)
                                          #:name (format #f "a link to ~a"
                                                         href)))
                           '("/" "/songs" "/artists" "/genres"))))

         (test "the wording is translated through the procedure it is given"
               (let* ((marked (lambda (string) (string-append "⟦" string "⟧")))
                      (html (sxml->xml-string (error-page 404 #:G_ marked))))
                 (assert-true (and (string-contains html
                                                    (string-append "⟦"
                                                                   (error-headline
                                                                    404)
                                                                   "⟧"))
                                   #t)
                              #:name "the headline arrives wrapped")
                 (assert-true (and (string-contains html
                                                    (string-append "⟦"
                                                                   (error-detail
                                                                    404)
                                                                   "⟧"))
                                   #t)
                              #:name "and so does the detail")))

         (test "a reader who is signed in is not invited to sign in again"
               (assert-true (not (equal? (rendered 404)
                                         (sxml->xml-string
                                          (error-page 404 #:is-logged-in #t))))
                            #:name "the navigation differs with the session"))

         (test "the page is serialized the way the rest of the site is"
               ;; The shell's own dark-theme toggle is inline script holding a
               ;; `&&'.  A serializer that escaped text nodes would turn it
               ;; into `&amp;&amp;', which a browser reads as the characters
               ;; `&amp;&amp;' inside a script element -- a broken page that
               ;; still returns 200.
               (let ((html (rendered 500)))
                 (assert-true (and (string-contains html "&&") #t)
                              #:name "inline script survives the serializer")
                 (assert-true (equal? #f (string-contains html "&amp;&amp;"))
                              #:name "and is not escaped into nonsense")))))

(define sheet-suite
  (suite "The classes an error page asks for"
         (test "every class the page names is one the sheets define"
               (let* ((html (rendered 404))
                      (sheet (sheets-for html))
                      (missing (remove (lambda (class)
                                         (or (icon-class? class)
                                             (defined-by-sheet? class sheet)))
                                       (classes-in html))))
                 (assert-equal #:name "no class is a no-op on the page"
                               #:expect '()
                               #:got missing)
                 (assert-true (>= (length (classes-in html)) 100)
                              #:name "and the page does name a fair few")))))

(define (spec)
  (veritas-run wording-suite rendering-suite sheet-suite))
