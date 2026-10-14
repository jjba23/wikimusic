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
;;; The shell every page is rendered into: the bar across its top, the footer
;;; below it, the language control, and the two promises the shell makes about
;;; a page rather than about its wording.
;;;
;;; One is that the bar gets out of the way.  While a reader is reading -- the
;;; ascii contents of a song, or a PDF beside them -- nothing should be pinned
;;; over the top of it, so the reading mode is a property of the rendered
;;; navigation.  The assertions name the bar's own class attribute rather than
;;; searching the whole page: an inlined stylesheet talks about sticky things
;;; too, and a search for the word would find that instead.
;;;
;;; The other is that the shell is a page a browser can parse at all.  Artanis
;;; serializes a childless element as `<div ... />', which HTML treats as an
;;; open tag and not a closed one: the parser then nests everything that
;;; follows inside it, and a decorative element that is blurred, unclickable
;;; and `aria-hidden' swallows the whole page.  That is exactly what a page
;;; with no body looks like, so it is pinned here too.

(define-module (veritas unit views-spec)
  #:use-module (veritas veritas)
  #:use-module (ice-9 format)
  #:use-module (ice-9 regex)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:use-module (support deployment)
  #:use-module ((artanis utils)
                #:select (sxml->xml-string))
  #:use-module (wikimusic config)
  #:use-module (wikimusic html)
  #:export (spec))

(define (G_ key)
  key)

(define (render sxml)
  "Return the HTML SXML serializes to."
  (sxml->xml-string sxml))

(define (all-matches pattern string)
  "Return every first group of PATTERN's matches in STRING."
  (fold-matches (make-regexp pattern) string
                '()
                (lambda (match tail
                          )
                  (cons (match:substring match 1) tail))))

(define (class-attributes html)
  "Return the value of every class attribute HTML carries."
  (all-matches "class=\"([^\"]*)\"" html))

(define (class-with html token)
  "Return the class attribute of HTML that names TOKEN, or #f."
  (find (lambda (attribute)
          (and (member token
                       (string-tokenize attribute)) #t))
        (class-attributes html)))

(define (class-tokens html token)
  "Return the class tokens of the attribute naming TOKEN, or '()."
  (let ((attribute (class-with html token)))
    (if attribute
        (string-tokenize attribute)
        '())))

(define (first-repeated-token attribute)
  "Return the first token ATTRIBUTE names twice, or #f when it names none twice."
  (let loop
    ((tokens (string-tokenize attribute))
     (seen '()))
    (cond
      ((null? tokens)
       #f)
      ((member (car tokens) seen)
       (car tokens))
      (else (loop (cdr tokens)
                  (cons (car tokens) seen))))))

(define locale-suite
  (suite "The languages a page offers"
         (test "every offered language is one this instance ships"
               (assert-equal #:name "the four catalogs are offered"
                             #:expect '("en_US" "nl_NL" "es_ES" "ja_JP")
                             #:got (map car wikimusic-locales)))

         (test "each language is named in that language"
               (for-each (lambda (entry)
                           (assert-true (and (string? (cdr entry))
                                             (not (string-null? (cdr entry))))
                                        #:name (format #f "~a is named"
                                                       (car entry))))
                         wikimusic-locales))

         (test "a compiled catalog stands behind each offered language"
               (for-each (lambda (entry)
                           (let ((mo (format #f
                                      "sys/i18n/locale/~a/LC_MESSAGES/translate.mo"
                                      (car entry))))
                             (assert-true (file-exists? mo)
                                          #:name (format #f "~a has a catalog"
                                                         (car entry)))))
                         wikimusic-locales))))

(define choose-suite
  (suite "Choosing a language"
         (test "the control posts the choice to the preference route"
               (let ((html (render (locale-choose-form G_
                                                       #:selected-locale
                                                       "nl_NL"))))
                 (assert-true (and (string-contains html
                                    "action=\"/preferences/locale\"") #t)
                              #:name "the form names the route")
                 (assert-true (and (string-contains html "name=\"user-lang\"")
                                   #t)
                              #:name "the menu is the posted field")))

         (test "every offered language is a row of the menu"
               (let ((html (render (locale-choose-form G_
                                                       #:selected-locale
                                                       "en_US"))))
                 (for-each (lambda (entry)
                             (assert-true (and (string-contains html
                                                                (format #f
                                                                 "value=\"~a\""
                                                                 (car entry)))
                                               #t)
                                          #:name (format #f "~a is offered"
                                                         (car entry))))
                           wikimusic-locales)))

         (test "the page states the language it is being read in"
               (let ((html (render (locale-choose-form G_
                                                       #:selected-locale
                                                       "ja_JP"))))
                 (assert-true (and (regexp-exec (make-regexp
                                                 "value=\"ja_JP\"[^>]*selected")
                                                html) #t)
                              #:name
                              "the language being read is the row shown")
                 (assert-false (regexp-exec (make-regexp
                                             "value=\"nl_NL\"[^>]*selected")
                                            html)
                               #:name "and a language not being read is not")))

         (test "the control names itself for a reader and for assistive tech"
               (let ((html (render (locale-choose-form G_
                                                       #:selected-locale
                                                       "es_ES"))))
                 (assert-true (and (string-contains html "for=\"user-lang\"")
                                   #t)
                              #:name "the label is bound to the menu")
                 (assert-true (and (string-contains html ">language<") #t)
                              #:name "and says what it is")))))

(define reading-suite
  (suite "A page a reader is reading"
         (test "the navigation is pinned while browsing"
               (let ((tokens (class-tokens (render (nav G_)) "lg:flex-row")))
                 (assert-true (and (member "sticky" tokens) #t)
                              #:name "the bar keeps its place")
                 (assert-true (and (member "top-2" tokens) #t)
                              #:name "just below the top edge")))

         (test "the navigation is left to scroll away while reading"
               (let ((tokens (class-tokens (render (nav G_
                                                        #:reading? #t))
                                           "lg:flex-row")))
                 (assert-true (and (pair? tokens) #t)
                              #:name "the bar is still rendered")
                 (assert-false (member "sticky" tokens)
                               #:name "nothing pins it")
                 (assert-false (member "top-2" tokens)
                               #:name "no offset holds it there")
                 (assert-false (member "z-32" tokens)
                               #:name "and it does not float above the text")))

         (test "the whole template carries the reading mode down to the bar"
               (let ((reading (class-tokens (render (html-template G_
                                                                   #:reading?
                                                                   #t
                                                                   #:body '((p
                                                                             "reading"))))
                                            "lg:flex-row"))
                     (browsing (class-tokens (render (html-template G_
                                                                    #:body '((p
                                                                              "browsing"))))
                                             "lg:flex-row")))
                 (assert-true (and (pair? reading) #t)
                              #:name "a reading page still has a bar")
                 (assert-false (member "sticky" reading)
                               #:name "but nothing pins it")
                 (assert-true (and (member "sticky" browsing) #t)
                              #:name "and every other page keeps it")))))

;; The footer is read through a procedure, and every assertion asks for it
;; itself.  That is not tidiness: a suite takes its children as arguments and a
;; test takes its cases as arguments, so a body wrapped in a `let' hands on the
;; value of that `let' alone.  This suite used to render once and wrap its four
;; tests in that `let', which passed the last test to the suite and dropped the
;; three above it, none of which had ever run; and an assertion is a thunk, so
;; two of three inside a `let' are built and never invoked.  A `let' holding a
;; single assertion is fine, which is why only the last one below sits in one.
(define (footer-html)
  "Return the footer as HTML, which is what every test below reads."
  (render (page-footer G_)))

(define footer-suite
  (suite "The footer"
         ;; The addresses are asked of the configuration rather than written
         ;; out here: what the footer owes a reader is that the link leads to
         ;; where *this* deployment says the code, the manual and the licence
         ;; are, and an instance that names its own is not a failure.
         (test "it points at the code, the manual and the licence"
               (assert-true (and (string-contains (footer-html)
                                                  (source-repository-url)) #t)
                            #:name "where the source is")
               (assert-true (and (string-contains (footer-html)
                                                  (manual-url)) #t)
                            #:name "where the manual is")
               (assert-true (and (string-contains (footer-html)
                                                  (licence-url)) #t)
                            #:name "and where the licence is written out"))

         (test "it states the version this instance runs"
               (assert-true (and (string-contains (footer-html) "version:") #t)
                            #:name "the version is named"))

         (test "it offers the way back to the top"
               (assert-true (and (string-contains (footer-html)
                                                  "back to the top") #t)
                            #:name "the control says what it does")
               (assert-true (and (string-contains (footer-html)
                                                  "window.scrollTo") #t)
                            #:name "and it is the one that scrolls"))

         (test "no class is asked for twice"
               (let ((offending (find first-repeated-token
                                      (class-attributes (footer-html)))))
                 (assert-false offending
                               #:name (if offending offending
                                          "a clean class attribute"))))))

(define shell-suite
  (suite "A page a browser can read"
         (test "the body the caller passed is the body that is served"
               (let ((html (render (html-template G_
                                                  #:body '((p (@ (id "marker"))
                                                            "HELLO-BODY-MARKER"))))))
                 (assert-true (and (string-contains html "HELLO-BODY-MARKER")
                                   #t)
                              #:name "the content survives")
                 (assert-true (and (string-contains html "<main") #t)
                              #:name "and it stands inside the document")))

         (test "no non-void element is closed as a self-closed tag"
               (let ((html (render (html-template G_
                                                  #:body '((p "x")))))
                     (pattern (make-regexp (string-append
                                            "<(div|span|main|p|section|article|nav|"
                                            "button|details|summary|ul|ol|li|h[1-6]|"
                                            "form|label)([ >])[^>]*/>"))))
                 (assert-false (fold-matches pattern html #f
                                             (lambda (match tail
                                                       )
                                               #t))
                               #:name "each one is closed, not reopened")))))

;; Where the shell reads the files it is made of.  The type a page is set in,
;; the glyphs its controls wear, the stylesheet it is laid out with and the icon
;; its tab is marked with are all files this project serves, so all four are
;; read off the instance that answered the request -- and a deployment behind a
;; CDN, or serving them from a path of its own, moves every one of them by
;; naming one address.  The two halves are read the same way as the switch
;; above: this instance with nothing said about it, and an instance that named
;; a host (see `(support deployment)').
(define (shell-html)
  "Return the shell as HTML, which the asset tests below read."
  (render (html-template G_
                         #:body '((p "a page")))))

(define assets-suite
  (suite "Where the shell reads its own files"
         (test "an instance that serves its own reads them off itself"
               (assert-true (and (string-contains (with-deployment 'assets-url
                                                                   ""
                                                                   shell-html)
                                  "href=\"/css/wikimusic.olive.min.css\"") #t)
                            #:name "the stylesheet the page is laid out with")
               (assert-true (and (string-contains (with-deployment 'assets-url
                                                                   ""
                                                                   shell-html)
                                                  "href=\"/favicon.ico\"") #t)
                            #:name "and the icon the tab is marked with"))

         (test
          "a deployment that serves them elsewhere moves every one of them"
          (assert-true (and (string-contains (with-deployment 'assets-url
                                              "https://assets.example.org/theme"
                                              shell-html)
                                             (string-append
                                              "href=\"https://assets.example.org/theme"
                                              "/css/wikimusic.olive.min.css\""))
                            #t)
                       #:name "the stylesheet")
          (assert-true (and (string-contains (with-deployment 'assets-url
                                              "https://assets.example.org/theme"
                                              shell-html)
                                             (string-append
                                              "href=\"https://assets.example.org/theme"
                                              "/vendor/fonts/lucida.css\""))
                            #t)
                       #:name "the type the page is set in")
          (assert-true (and (string-contains (with-deployment 'assets-url
                                              "https://assets.example.org/theme"
                                              shell-html)
                                             (string-append
                                              "href=\"https://assets.example.org/theme"
                                              "/vendor/phosphor/phosphor.css\""))
                            #t)
                       #:name "the glyphs its controls wear")
          (assert-true (and (string-contains (with-deployment 'assets-url
                                              "https://assets.example.org/theme"
                                              shell-html)
                             "href=\"https://assets.example.org/theme/favicon.ico\"")
                            #t)
                       #:name "and the icon, with no address left behind"))

         (test "no file of the interface is somebody else's to serve"
               ;; Every one of these was a request a reader's browser made to
               ;; a host this project does not run: a font host for the two web
               ;; families, an icon CDN for the glyphs, and the author's own
               ;; domain for the Lucida files.  They are files in `pub/' now,
               ;; and a page that named one of them again would be a page that
               ;; stops being readable when that host is.
               (assert-false (string-contains (shell-html)
                                              "fonts.googleapis.com")
                             #:name "no font host")
               (assert-false (string-contains (shell-html) "fonts.gstatic.com")
                             #:name
                             "and none of the hosts a face was fetched from")
               (assert-false (string-contains (shell-html) "cdn.jsdelivr.net")
                             #:name "no icon CDN")
               ;; The Lucida families used to be read from the author's own
               ;; static assets, and that path is the one thing here that has to
               ;; be named rather than counted: the page carries the address of
               ;; an events endpoint on that domain as well, and a service is
               ;; not an asset -- what must not be there is a *file* of the
               ;; interface waiting on somebody else's machine to be up.
               (assert-false (string-contains (shell-html)
                                              "static-assets/fonts")
                #:name "and no typeface read from somebody's static assets"))))

(define (spec)
  (veritas-run locale-suite
               choose-suite
               reading-suite
               footer-suite
               shell-suite
               assets-suite))
