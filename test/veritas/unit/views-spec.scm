;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

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
  #:use-module (ice-9 ftw)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 regex)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:use-module (support deployment)
  #:use-module ((artanis utils)
                #:select (sxml->xml-string))
  #:use-module (wikimusic config)
  #:use-module (wikimusic html)
  #:use-module (app views song-content-view)
  #:use-module (app views song-view)
  #:use-module (app views song-edit)
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
                (lambda (match tail)
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
      [(null? tokens)
       #f]
      [(member (car tokens) seen)
       (car tokens)]
      [else (loop (cdr tokens)
                  (cons (car tokens) seen))])))

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

(define (song-page-html)
  "Return a song page as HTML, which is the sheet a phone reads it on.

The page is asked about its own gutter rather than about its music, so the song
is the smallest one that renders: an identifier, a name and the three columns
the details block counts with."
  (render (song-detail-page G_
                            #:song `((identifier . "one")
                                     (display-name . "one")
                                     (description . "a song")
                                     (views . 0)
                                     (created-at . "1700000000")
                                     (created-by . "someone"))
                            #:artworks '()
                            #:song-contents '()
                            #:song-artists '()
                            #:artists '()
                            #:song-genres '()
                            #:genres '()
                            #:opinions '()
                            #:comments '()
                            #:user-alist '()
                            #:external-sources '()
                            #:is-logged-in #f)))

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
          #:name "and every other page keeps it")))

    (test "a song page leaves the width to the music"
      (let ((tokens (class-tokens (song-page-html) "md:px-6")))
        (assert-true (and (member "px-0" tokens) #t)
          #:name "the page adds no gutter on top of the shell's")
        (assert-false (member "px-3" tokens)
          #:name "which is a column of the tab it would cost")))))

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

    (test "a signed-in reader is offered the account page"
      (let ((html (render (html-template G_
                                         #:is-logged-in #t
                                         #:body '((p "x"))))))
        (assert-true (and (string-contains html "href=\"/me\"") #t)
          #:name "the me link")))

    (test "a signed-out reader is offered sign-in instead"
      (let ((html (render (html-template G_
                                         #:is-logged-in #f
                                         #:body '((p "x"))))))
        (assert-true (and (string-contains html "href=\"/login\"") #t)
          #:name "the login link")
        (assert-true (not (string-contains html "href=\"/me\""))
          #:name "and no account link")))

    (test "no non-void element is closed as a self-closed tag"
      (let ((html (render (html-template G_
                                         #:body '((p "x")))))
            (pattern (make-regexp (string-append
                                   "<(div|span|main|p|section|article|nav|"
                                   "button|details|summary|ul|ol|li|h[1-6]|"
                                   "form|label)([ >])[^>]*/>"))))
        (assert-false (fold-matches pattern html #f
                                    (lambda (match tail)
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
                                          "/vendor/fonts/juliamono.css\""))
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
      ;; families and an icon CDN for the glyphs.  They are files in
      ;; `pub/' now, and a page that named one of them again would be
      ;; a page that stops being readable when that host is.
      (assert-false (string-contains (shell-html)
                                     "fonts.googleapis.com")
        #:name "no font host")
      (assert-false (string-contains (shell-html) "fonts.gstatic.com")
        #:name
        "and none of the hosts a face was fetched from")
      (assert-false (string-contains (shell-html) "cdn.jsdelivr.net")
        #:name "no icon CDN")
      ;; A typeface used to be read from the author's own static
      ;; assets, and that path is the one thing here that has to be
      ;; named rather than counted: the page carries the address of an
      ;; events endpoint on that domain as well, and a service is not
      ;; an asset -- what must not be there is a *file* of the
      ;; interface waiting on somebody else's machine to be up.
      (assert-false (string-contains (shell-html)
                                     "static-assets/fonts")
        #:name "and no typeface read from somebody's static assets"))))

;; The preferences a tab is read with.  Every one of them arrives from an
;; address or a cookie, so every one has to land on a value the page can draw:
;; an old or invented name is read as the default rather than applied.  And a
;; choice has to travel with the other two, or setting the paper would put the
;; reader's size back to 100%.
(define (anchor-with html text)
  "Return the opening <a> tag of HTML whose href names TEXT, or #f."
  (let ((match (regexp-exec (make-regexp (format #f "<a [^>]*~a[^>]*>"
                                                 (regexp-quote text)))
                            html)))
    (and match (match:substring match))))

(define ascii-suite
  (suite "The preferences a tab is read with"
    (test "a step is read as itself, and an old name as the step it means"
      (assert-equal #:name "a step of the ladder"
        #:expect "text-8"
        #:got (ascii-size-step "text-8"))
      (assert-equal #:name "the name an earlier control offered"
        #:expect "text-5"
        #:got (ascii-size-step "text-lg"))
      (assert-false (ascii-size-step "text-11")
        #:name "a name with no utility behind it"))

    (test "a paper or a face the page does not offer is no answer at all"
      (assert-false (ascii-paper-step "sepia")
        #:name "an invented paper")
      (assert-false (ascii-face-step "cursive")
        #:name "an invented face")
      (assert-equal #:name "and one it does offer is read as itself"
        #:expect "dark"
        #:got (ascii-paper-step "dark")))

    (test "the address wins over the cookie, and is what is remembered"
      (call-with-values
        (lambda ()
          (ascii-preference #:asked "text-6"
                            #:remembered "text-8"
                            #:step ascii-size-step
                            #:fallback ascii-size-default))
        (lambda (value remember)
          (assert-equal #:name "the size the address asked for"
            #:expect "text-6"
            #:got value)
          (assert-equal #:name "and the size written down for the next page"
            #:expect "text-6"
            #:got remember))))

    (test "a value the page cannot draw is never remembered"
      (call-with-values
        (lambda ()
          (ascii-preference #:asked "text-11"
                            #:remembered "text-8"
                            #:step ascii-size-step
                            #:fallback ascii-size-default))
        (lambda (value remember)
          (assert-equal #:name "the address is ignored and the cookie kept"
            #:expect "text-8"
            #:got value)
          (assert-false remember
            #:name "and nothing is written over the reader's choice"))))

    (test "a cookie left by an older control is read as the default"
      (call-with-values
        (lambda ()
          (ascii-preference #:asked #f
                            #:remembered "sepia"
                            #:step ascii-paper-step
                            #:fallback ascii-paper-default))
        (lambda (value remember)
          (assert-equal #:name "the sheet the page opens at"
            #:expect "auto"
            #:got value)
          (assert-false remember
            #:name "and no choice to remember"))))

    (test "a name the deployment does not know is read as the default"
      (assert-equal #:name "an invented paper"
        #:expect "auto"
        #:got (ascii-paper-known "sepia"))
      (assert-equal #:name "an invented face"
        #:expect "mono"
        #:got (ascii-face-known "cursive")))

    (test "a name it does know is read as itself"
      (assert-equal #:name "the dark sheet"
        #:expect "dark"
        #:got (ascii-paper-known "dark"))
      (assert-equal #:name "the serif face"
        #:expect "serif"
        #:got (ascii-face-known "serif")))

    (test "each choice carries the other two preferences"
      (let ((href (ascii-preference-href "/songs/uuid/one"
                                         #:key "ascii-size"
                                         #:value "text-8"
                                         #:size "text-4"
                                         #:paper "dark"
                                         #:face "serif")))
        (assert-true (and (string-contains href
                                           "ascii-size=text-8") #t)
          #:name "the choice being made")
        (assert-true (and (string-contains href
                                           "ascii-theme=dark") #t)
          #:name "the paper already chosen")
        (assert-true (and (string-contains href
                                           "ascii-face=serif") #t)
          #:name "and the face")))

    (test "the reader's paper is painted on the sheet, its face on the type"
      (let* ((html (render (ascii-block "x"
                                        #:id "one"
                                        #:size "text-4"
                                        #:paper "light"
                                        #:face "serif")))
             (sheet (class-tokens html "wm-tab"))
             (type (class-tokens html "wm-ascii")))
        (assert-true (and (member "bg-white" sheet) #t)
          #:name "a white sheet")
        (assert-false (member "dark:bg-onyx-900" sheet)
          #:name "whatever theme the page has")
        (assert-true (and (member "font-serif" type) #t)
          #:name "and the face the reader reads in")))

    (test "the size control offers the whole ladder as addresses"
      (let ((html (render (ascii-size-control G_
                                              #:route "/songs/uuid/one"
                                              #:size "text-4"
                                              #:paper "dark"
                                              #:face "serif"))))
        (assert-true (and (string-contains html ">100%<") #t)
          #:name "the share it is drawn at")
        (for-each (lambda (step)
                    (assert-true (and (string-contains
                                       html
                                       (format #f "ascii-size=~a"
                                               (car step))) #t)
                      #:name (format #f "~a is an address" (car step))))
                  ascii-size-steps)
        (assert-false (string-contains html "<select")
          #:name "and no menu a script has to drive")))

    (test "the paper control is a row of addresses, one of them current"
      (let* ((html (render (ascii-choice-control
                            G_
                            #:id "ascii-theme"
                            #:label "ascii paper"
                            #:key "ascii-theme"
                            #:options ascii-paper-steps
                            #:selected "dark"
                            #:route "/songs/uuid/one"
                            #:size "text-4"
                            #:paper "dark"
                            #:face "mono")))
             (chosen (anchor-with html "ascii-theme=dark"))
             (other (anchor-with html "ascii-theme=light")))
        (assert-true (and chosen (string-contains chosen "aria-current") #t)
          #:name "the sheet in use says so")
        (assert-false (and other (string-contains other "aria-current"))
          #:name "and a sheet not in use does not")
        (for-each (lambda (paper)
                    (assert-true (and (string-contains
                                       html
                                       (format #f "ascii-theme=~a" paper)) #t)
                      #:name (format #f "~a is an address" paper)))
                  ascii-paper-steps)
        (assert-false (string-contains html "<select")
          #:name "and no menu a script has to drive")))

    (test "a song page is drawn with the preferences it was handed"
      (let* ((html (song-page-html))
             (default-size (anchor-with html "ascii-size=text-4")))
        (assert-true (and (string-contains html ">100%<") #t)
          #:name "the default size, not a name nothing draws")
        (assert-true (and default-size
                       (string-contains default-size "aria-current") #t)
          #:name "marked as the step the page is drawn at")
        (assert-true (and (anchor-with html "ascii-theme=auto") #t)
          #:name "and the paper is a column of addresses")))

    (test "the legend is drawn as Org prose, not kept in a pre"
      (let ((html (render (html-template G_
                                         #:body (list (ascii-legend-block
                                                       "- = means hold the note"))))))
        (assert-true (and (string-contains html "wm-ascii-legend")
                       #t)
          #:name "the quiet block")
        (assert-false (string-contains html "<pre")
          #:name "not a tablature block")
        (assert-true (and (string-contains html "hold the note")
                       #t)
          #:name "and the words survive the markup")))

    (test "the controls that drive a tab are drawn on its sheet"
      (let* ((html (render (ascii-block "x"
                                        #:id "one"
                                        #:size "text-4"
                                        #:toolbar (ascii-tools G_))))
             (strip (string-contains html "wm-tab-bar")))
        (assert-true (and strip (> strip 0) #t)
          #:name "a strip on the sheet")
        (assert-true (and (< (string-contains html "wm-tab") strip) #t)
          #:name "drawn by the sheet itself")
        (assert-true (and (< strip (string-contains html "<pre")) #t)
          #:name "and in front of the tab")
        (assert-true (and (string-contains html "id=\"start-autoscroll\"") #t)
          #:name "the control that travels")
        (assert-true (and (string-contains html "id=\"scroll-speed\"") #t)
          #:name "with one menu of speeds")
        (assert-false (string-contains html "highlight")
          #:name "and nothing to press to mark the chords")))))

;; A page is built from the strings a view hands it, and a string a reader
;; typed is text until the document is written.  The template is therefore the
;; one place a page's text is escaped, and a fragment that is already HTML --
;; a description Org has been rendered into -- is the one thing it writes out
;; as it is.
(define escaping-suite
  (suite "The escaping a page gets"
    (test "text a view hands the template is escaped when it is written"
      (let ((html (render (html-template G_
                                         #:title "a & <b>"
                                         #:body '((p "5 < 6 & 7"))))))
        (assert-true (and (string-contains html "5 &lt; 6 &amp; 7") #t)
          #:name "the body's text")
        (assert-true (and (string-contains html
                                           "<title>a &amp; &lt;b&gt;</title>")
                       #t)
          #:name "and the title")))

    (test "a fragment that is already markup is written out as it is"
      (let ((html (render (html-template G_
                                         #:body (list `(div ,(raw
                                                              "<em>x</em>")))))))
        (assert-true (and (string-contains html "<em>x</em>") #t)
          #:name "the fragment")))

    (test "a script is code, not text"
      (let ((html (render (html-template G_
                                         #:body '((script "if (a && b) {}"))))))
        (assert-true (and (string-contains html "a && b") #t)
          #:name "the script's own characters")))

    (test "a value in an attribute is escaped exactly once"
      (let ((html (render (html-template G_
                                         #:body '((input (@ (value "a & b"))
                                                         ""))))))
        (assert-true (and (string-contains html "value=\"a &amp; b\"") #t)
          #:name "the attribute")))))

;;; ====== What stands in for a picture ======
;;;
;;; A song, an artist and a genre each draw their own placeholder when they have
;;; no artwork -- in a tile and on a page -- so a grid keeps its rhythm and a
;;; page keeps its shape.  The square is also the whole of the cover's link, so
;;; it has to carry the name the picture would have carried.
(define (tile-html entity)
  "Return a tile for ENTITY, whose entity has no artwork."
  (render (item-tile G_ entity
                     '((identifier . "id") (display-name . "Name"))
                     '() '())))

(define (panel-html)
  "Return the detail panel of an entity that has no artwork."
  (render (entity-details G_
                          #:entity 'song
                          #:x '((identifier . "id")
                                (display-name . "Name")
                                (views . 0)
                                (created-at . "1794044768")
                                (visibility-status . 0)
                                (created-by . "u"))
                          #:artworks '()
                          #:opinions '()
                          #:comments '()
                          #:user-alist '())))

(define picture-suite
  (suite "The picture an entity without one is drawn with"
    (test "a tile keeps its square and its name"
      (assert-true (and (string-contains (tile-html 'song)
                                         "wm-placeholder") #t)
        #:name "the placeholder is drawn")
      (assert-true (and (string-contains (tile-html 'song)
                                         "aria-label=\"Name\"") #t)
        #:name "and the square still names the thing it leads to"))

    (test "each entity class has a placeholder of its own"
      (assert-true (and (string-contains (tile-html 'song)
                                         "wm-placeholder-song") #t)
        #:name "a song")
      (assert-true (and (string-contains (tile-html 'artist)
                                         "wm-placeholder-artist") #t)
        #:name "an artist")
      (assert-true (and (string-contains (tile-html 'genre)
                                         "wm-placeholder-genre") #t)
        #:name "a genre"))

    (test "a page with no artwork still shows one"
      (assert-true (and (string-contains (panel-html)
                                         "wm-media-placeholder") #t)
        #:name "the page's placeholder"))

    (test "the opinions are thumbs and a count, not words"
      (let ((html (panel-html)))
        (assert-false (string-contains html ">like<")
          #:name "no written-out like")
        (assert-true (and (string-contains html "aria-label=\"like, 0\"") #t)
          #:name "and a name for a reader who cannot see the glyph")))))

;;; ====== The glyphs the markup asks the sheet for ======
;;;
;;; An icon is two classes: the family the helper builds from the weight it was
;;; given, and the name the call site passed.  The vendored sheet carries one
;;; family -- `ph' -- and its own list of names, so a call asking for any other
;;; weight draws nothing at all: an empty square where a control should be,
;;; which is how a `bold' request went unseen until a page was looked at.
;;;
;;; These assertions read the sheet and the source, so a glyph that is not there
;;; fails the suite instead of showing up blank on the site.

(define glyph-sheet
  (call-with-input-file "pub/vendor/phosphor/phosphor.css"
    (lambda (port) (get-string-all port))))

;; The names the vendored sheet draws, spelled the way a class spells them.
(define sheet-glyph-names
  (all-matches "\\.ph\\.ph-([a-z0-9-]+):before" glyph-sheet))

(define (scheme-files directory)
  "Return the Scheme files DIRECTORY holds."
  (map (lambda (name) (string-append directory "/" name))
       (scandir directory (lambda (name) (string-suffix? ".scm" name)))))

(define (glyph-calls form)
  "Return every `(icon ...)' call in FORM, however deeply nested it is.

A source file is not made of proper lists only -- `(lambda (key . args) ...)'
has a tail -- so this walks pair by pair instead of by list."
  (if (not (pair? form))
    '()
    (append (if (eq? (car form) 'icon) (list form) '())
            (glyph-calls (car form))
            (glyph-calls (cdr form)))))

(define (keyword-value form key)
  "Return the value FORM gives KEY, or #f."
  (let loop ((rest (cdr form)))
    (cond [(null? rest) #f]
          [(eq? (car rest) key) (and (pair? (cdr rest)) (cadr rest))]
          [else (loop (cdr rest))])))

(define (literal-symbol value)
  "Return VALUE as a symbol when it is a quoted one, else #f."
  (if (and (pair? value) (eq? (car value) 'quote) (symbol? (cadr value)))
    (cadr value)
    #f))

(define (icon-requests)
  "Return a (TYPE . WEIGHT) pair for every icon call whose arguments are literals.

A call that names its glyph through a variable is not here: `grid-size-select'
and `entity-placeholder' fill their own, and the suite renders them instead."
  (let* ((files (append (scheme-files "lib/wikimusic")
                        (scheme-files "app/views")))
         (calls (append-map (lambda (file)
                              (call-with-input-file file
                                (lambda (port)
                                  (let loop ((found '()))
                                    (let ((form (read port)))
                                      (if (eof-object? form)
                                        found
                                        (loop (append (glyph-calls form) found))))))))
                            files)))
    (delete-duplicates
     (filter-map (lambda (call)
                   (let ((type (literal-symbol (keyword-value call #:type))))
                     (and type
                          (cons type
                                (or (literal-symbol (keyword-value call #:weight))
                                    'regular)))))
                 calls))))

(define (glyph-tokens html)
  "Return every glyph class token HTML carries."
  (delete-duplicates
   (filter (lambda (token) (string-prefix? "ph-" token))
           (append-map string-tokenize (class-attributes html)))))

(define glyph-suite
  (suite "The glyphs the markup asks the sheet for"
    (test "every glyph named in the source is one the sheet draws"
      (for-each
       (lambda (request)
         (let ((name (symbol->string (car request))))
           (assert-true (if (member name sheet-glyph-names) #t #f)
                        #:name name)))
       (icon-requests)))

    (test "every weight asked for is a family the sheet carries"
      (for-each
       (lambda (weight)
         (let ((family (if (eq? weight 'regular)
                         "ph"
                         (format #f "ph-~a" (symbol->string weight)))))
           (assert-true (if (string-contains glyph-sheet
                                             (format #f ".~a" family))
                            #t
                            #f)
                        #:name family)))
       (delete-duplicates (map cdr (icon-requests)))))

    (test "the controls that choose their glyph draw one the sheet has"
      (for-each
       (lambda (html)
         (for-each
          (lambda (token)
            (assert-true (if (or (equal? token "ph")
                                 (member (substring token 3) sheet-glyph-names))
                          #t
                          #f)
                         #:name token))
          (glyph-tokens html)))
       (list (render (grid-size-select G_ #:entity 'song #:size "medium"))
             (render (entity-placeholder 'song))
             (render (entity-placeholder 'artist))
             (render (entity-placeholder 'genre)))))))

;;; ====== The chords a tab highlights ======
;;;
;;; A highlighted chord is drawn by a class the script writes, so the sheet and
;;; the script have to agree on the name: a class one of them renames is a silent
;;; no-op in the other, and the chord goes back to being only letters.  What the
;;; mark looks like is the sheet's to say, which is why the script names one of
;;; this site's classes rather than a set of utilities to keep in step.

(define chord-script
  (call-with-input-file "pub/js/song-chord-highlighter.js"
    (lambda (port) (get-string-all port))))

(define chord-sheet
  (call-with-input-file "pub/css/wikimusic.css"
    (lambda (port) (get-string-all port))))

(define chord-suite
  (suite "The chords a tab highlights"
    (test "the class the script writes is one the sheet draws"
      (assert-true (if (string-contains chord-script "wm-chord") #t #f)
                   #:name "the script names wm-chord")
      (assert-true (if (string-contains chord-sheet ".wm-chord") #t #f)
                   #:name "the sheet styles wm-chord"))

    (test "the tab is marked as it is drawn, not on a press"
      (assert-true (if (string-contains chord-script "DOMContentLoaded") #t #f)
                   #:name "the script runs itself")
      (assert-false (if (string-contains chord-script "onclick") #t #f)
                    #:name "and nothing has to be pressed"))))

;;; ====== Editing a song ======
;;;
;;; The relations a song has used to be edited by pasting a UUID into a text
;;; field: the identifier is what the route wants, and it was the
;;; contributor's job to go and find one.  The page asks for a name now; the
;;; identifier is still the value a submit sends, it is just never something a
;;; reader has to know.

(define editing-suite
  (suite "Editing a song"
    (test "an artist relation is chosen by name"
      (let ((html (render (relation-editor G_
                                           #:path "/songs/uuid/one/artists"
                                           #:link-base "/artists/uuid"
                                           #:field 'artist-identifier
                                           #:label "artist"
                                           #:candidates '(((identifier . "artist-1")
                                                           (display-name . "The Band")))
                                           #:linked '()))))
        (assert-true (and (string-contains html
                                           "name=\"artist-identifier\"") #t)
          #:name "the field the route reads")
        (assert-true (and (string-contains html "value=\"artist-1\"") #t)
          #:name "the identifier a menu row carries")
        (assert-true (and (string-contains html "The Band") #t)
          #:name "behind the name it is chosen by")
        (assert-false (string-contains html "UUID")
          #:name "and nothing an identifier has to be typed into")))

    (test "a linked row is a link to what it names, with the way to unlink it"
      (let ((html (render (relation-editor G_
                                           #:path "/songs/uuid/one/artists"
                                           #:link-base "/artists/uuid"
                                           #:field 'artist-identifier
                                           #:label "artist"
                                           #:candidates '()
                                           #:linked '(((identifier . "artist-1")
                                                       (display-name . "The Band")))))))
        (assert-true (and (string-contains html
                                           "href=\"/artists/uuid/artist-1\"") #t)
          #:name "the way to the artist")
        (assert-true (and (string-contains
                           html
                           "action=\"/songs/uuid/one/artists/artist-1/delete\"") #t)
          #:name "and the way to take the link away")))

    (test "a name holding an apostrophe reaches the page whole"
      (let ((html (render (relation-editor G_
                                           #:path "/songs/uuid/one/artists"
                                           #:link-base "/artists/uuid"
                                           #:field 'artist-identifier
                                           #:label "artist"
                                           #:candidates '(((identifier . "a-1")
                                                           (display-name . "Guns N' Roses")))
                                           #:linked '()))))
        (assert-true (and (string-contains html "Guns N' Roses") #t)
          #:name "the apostrophe is a character")))


    (test "the page opens on the song and asks for its relations by name"
      (let* ((page (render (song-edit-page
                            G_
                            #:song '((identifier . "song-1")
                                     (display-name . "Don't fear the reaper")
                                     (music-key . "Am")
                                     (music-tuning . "Standard")
                                     (music-creation-date . "1976")
                                     (album-name . "Guns N' Roses")
                                     (album-info-link . "https://example.org")
                                     (description . ""))
                            #:artworks '()
                            #:artists '()
                            #:genres '()
                            #:all-artists '(((identifier . "artist-1")
                                             (display-name . "Guns N' Roses")))
                            #:all-genres '(((identifier . "genre-1")
                                            (display-name . "Hard rock")))
                            #:external-sources '()
                            #:is-logged-in #t)))
             (song (string-contains page "editing song"))
             (artists (string-contains page "song&apos;s artists")))
        (assert-true (and song #t)
          #:name "the song's own section")
        (assert-true (and artists #t)
          #:name "and its artists'")
        (assert-true (and (< song artists) #t)
          #:name "the song comes first")
        (assert-true (and (string-contains page "value=\"artist-1\"") #t)
          #:name "the artist it can be linked to")
        (assert-true (and (string-contains page "Hard rock") #t)
          #:name "and the genre")
        (assert-true (and (string-contains page "Guns N&apos; Roses") #t)
          #:name "a name with an apostrophe reaches the menu")))))

(define (spec)
  (veritas-run locale-suite
    ascii-suite
    choose-suite
    reading-suite
    footer-suite
    shell-suite
    assets-suite
    picture-suite
    escaping-suite
    glyph-suite
    chord-suite
    editing-suite))
