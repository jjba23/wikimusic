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

(define-module (wikimusic html)
  #:use-module (web server)
  #:use-module (web request)
  #:use-module (web response)
  #:use-module (web uri)
  #:use-module (json)
  #:use-module (ice-9 popen)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 time)
  #:use-module (ice-9 format)
  #:use-module (ice-9 string-fun)
  #:use-module (ice-9 iconv)
  #:use-module (ice-9 hash-table)
  #:use-module (ice-9 threads)
  #:use-module (kracht prelude)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (hygguile hygguile)
  #:use-module (hygguile abstraction)
  #:use-module (srfi srfi-19)
  #:use-module (orgwebalchemy html)
  #:use-module (wikimusic config)
  #:use-module (wikimusic seo)
  #:use-module (kracht prelude)
  #:use-module (ice-9 textual-ports)
  #:use-module (artanis route)
  #:export (asset-library page-footer
                          nav
                          wikimusic-locales
                          locale-choose-form
                          html-template
                          item-tile
                          render-visibility-status
                          render-comment
                          render-comments
                          entity-details
                          artwork-form
                          org2html
                          external-sources-form
                          sort-select
                          grid-size-select
                          ascii-size-select
                          search-box
                          render-external-sources
                          artwork-social-image
                          metronome-widget
                          item-tile-grid-face))

;; The tile grid's shape, chosen by the reader and remembered in a cookie.  A
;; reader who wants a dense wall of covers asks for `small' and gets more,
;; narrower columns at every breakpoint; a reader who wants a handful of large
;; tiles asks for `large' and gets fewer, wider ones.  `medium' is the default
;; and is what the grid has always been.
(define* (item-tile-grid-face #:key (size "medium"))
  "Return the tile grid's class string, sized to SIZE.

SIZE is one of the strings `small', `medium' or `large'; anything else is
read as `medium'."
  (mk-class (cond
              ((equal? size "small")
               '(grid grid-cols-3
                      gap-1
                      sm:gap-2
                      sm:grid-cols-4
                      md:grid-cols-6
                      lg:grid-cols-8
                      xl:grid-cols-10))
              ((equal? size "large")
               '(grid grid-cols-1
                      gap-3
                      sm:gap-4
                      sm:grid-cols-2
                      md:grid-cols-2
                      lg:grid-cols-3
                      xl:grid-cols-3))
              (else
               '(grid grid-cols-2
                      gap-2
                      sm:gap-3
                      sm:grid-cols-3
                      md:grid-cols-4
                      lg:grid-cols-5
                      xl:grid-cols-6)))))

;; The page's own colour, laid down once for the whole document: three
;; oversized, heavily blurred discs drifting very slowly behind everything.
;; They are what the frosted panes have to frost -- a backdrop filter over a
;; flat page hands back a flat pane -- and they are the framework's own wash
;; mechanics (`hg-blob' for the drift, Olive's blur ladder for the rest),
;; which a `glass-panel' would otherwise build for one pane at a time.
(define* (ambient-wash classes #:key delay pace)
  "Render one decorative colour wash for the page's background.

@var{classes} give the disc its size, its place and its colour; the
positioning, the blur and the fact that it never takes a pointer event are
named here, the same way `glass-panel' names them for a pane.

@table @var
@item delay
A number of seconds, or any CSS time as a string. A negative delay starts
the disc part way through its cycle, which is how the page's three washes
are kept out of step with one another.
@item pace
How long one drift takes, as a number of seconds or any CSS time.
@end table"
  (let ((style (append (if delay
                           (list (cons 'animation-delay
                                       (if (symbol? delay)
                                           (symbol->string delay)
                                           (format #f "~as" delay))))
                           '())
                       (if pace
                           (list (cons '--hg-blob-duration
                                       (if (symbol? pace)
                                           (symbol->string pace)
                                           (format #f "~as" pace))))
                           '()))))
    `((div (@ (aria-hidden "true")
              (class ,(mk-class classes))
              ,@(if (null? style)
                    '()
                    (list (list 'style (mk-style style)))))
           ;; The empty string is load-bearing, as it is for the notification
           ;; tray.  A childless element is serialized as `<div ... />', and
           ;; HTML has no self-closing tag for a div: the parser reads it as an
           ;; opening tag and nests everything that follows inside the disc.
           ;; A wash is `pointer-events-none', `select-none', `aria-hidden' and
           ;; blurred by 128px, so the whole page would end up unclickable,
           ;; unselectable, invisible to a screen reader and painted as haze.
           ""))))

(define ambient-wash-classes
  '(absolute pointer-events-none select-none rounded-512 blur-3xl opacity-75
             hg-blob))

;; Olive's offsets are the positive ones (`top-196', `bottom-1/4'): it
;; generates no negative inset utility at all, so a wash cannot be pushed
;; off an edge by naming a negative offset.  It does not have to be.  The
;; whitespace around the panes is where the colour reads, so the discs sit
;; inside the page instead -- anchored from whichever edge keeps them off
;; the centre -- and the blur decides how much of the page each one tints.
(define* (ambient-washes)
  "Return the page's background washes, out of phase with one another."
  (list (ambient-wash `(,@ambient-wash-classes
                        w-196 h-196 bottom-1/4 right-1/4
                        bg-persia-pink-500/25 dark:bg-persia-pink-900/25)
                      #:delay -6 #:pace 48)
        (ambient-wash `(,@ambient-wash-classes
                        w-128 h-128 bottom-0 right-1/2
                        bg-china-violet-500/25 dark:bg-china-violet-900/25)
                      #:delay -22 #:pace 62)
        (ambient-wash `(,@ambient-wash-classes
                        w-196 h-196 bottom-0 left-1/4
                        bg-jeans-blue-500/25 dark:bg-jeans-blue-900/25)
                      #:delay -38 #:pace 74)));;; ===== The language a reader reads the interface in =====

;; The languages this instance answers in: the name of the catalog under
;; `sys/i18n/locale', and the language as it is written in that language.
;; The list is the page's -- it is what a reader is offered -- so a catalog
;; added under that directory is offered here, and one removed stops being
;; offered.  See `sys/i18n/locale' and `maak i18n-compile'.
(define-public wikimusic-locales
  '(("en_US" . "English (US)")
    ("nl_NL" . "Nederlands")
    ("es_ES" . "Español")
    ("ja_JP" . "日本語")))

(define* (locale-choose-form G_
                             #:key selected-locale return-to)
  "The control a reader changes the interface's language with.

The choice is posted to @code{/preferences/locale}, which writes it to the
@code{lang} cookie -- the cookie every route builds its translator from --
and sends the reader back to the page they were reading.  The language a
page is *being* read in is the server's to state, since it is the language
that page was rendered in, so the row the menu shows is the one the caller
passes rather than one this control guesses.

The control names itself: a translate glyph and the word @code{language}
stand beside the menu rather than hiding behind it, because a reader who
cannot read the page around them cannot be asked to recognise a control that
shows nothing but the language it is already set to.  The name is bound to
the menu with @code{for}, so it reaches assistive technology as well."
  `((form (@ (action "/preferences/locale")
             (method "POST")
             (enctype "application/x-www-form-urlencoded")
             (class ,(mk-class '(flex flex-row flex-wrap
                                        items-center
                                        gap-1
                                        px-2 py-1
                                        w-fit
                                        rounded-xl
                                        hg-frost bg-stone-100/75
                                        dark:bg-onyx-900/75
                                        border-2
                                        border-china-violet-500/25
                                        dark:border-china-violet-300/25
                                        shadow-md))))
          ,@(if return-to
                `((input (@ (type "hidden")
                            (name "return-to")
                            (value ,return-to)))
                         "")
                '())
          ,(icon #:type 'translate
                 #:icon-css '(text-lg text-china-violet-700
                                     dark:text-china-violet-300))
          (label (@ (class ,(mk-class '(text-md
                                        font-medium
                                        font-sans
                                        px-1
                                        text-onyx-700
                                        dark:text-stone-300)))
                    (for user-lang))
                 ,(G_ "language"))
          ,(select #:name 'user-lang
                   ;; No `lowercase' here: a language writes its own name,
                   ;; and `Nederlands' or `Español' is how it is spelled.
                   #:select-classes '(text-md
                                      font-medium
                                      font-sans
                                      text-onyx-900
                                      dark:text-stone-100
                                      bg-transparent
                                      rounded-lg
                                      border-0
                                      px-2
                                      py-1
                                      outline-none
                                      cursor-pointer
                                      hover:bg-stone-300/75
                                      dark:hover:bg-onyx-700/75
                                      focus:ring-2)
                   #:select-flex-css '(flex flex-row
                                             items-center
                                             my-0
                                             w-fit)
                   #:options (map (lambda (locale)
                                    (option #:value (car locale)
                                            #:content (cdr locale)
                                            #:selected-value selected-locale))
                                  wikimusic-locales))
          ,(icon-button #:icon 'check
                        #:content ""
                        #:type 'submit
                        #:extra-classes '(py-1
                                          px-2
                                          max-w-prose
                                          cursor-pointer
                                          text-onyx-700
                                          dark:text-stone-300)
                        #:icon-css '(text-lg
                                     text-onyx-700
                                     dark:text-stone-300)))))

;; Every page carries these, so they are the site's smallest scripts: what a
;; page uses only sometimes -- the renderer a Guitar Pro tab is drawn with, and
;; the SoundFont that makes it audible -- is fetched by the script below when a
;; reader asks for a tab, and the renderer itself is never inlined.
;;; ====== The type and the glyphs ======
;;;
;;; The interface is set in three Lucida families and a pair of web families,
;;; and its controls wear Phosphor glyphs.  All of it used to be somebody else's
;;; address: a font host for the web families, an icon CDN for the glyphs, and
;;; the author's own domain for the Lucida files -- so every page of every
;;; instance made three third-party requests before it could be read, and the
;;; type was only there while those hosts were.
;;;
;;; They are now files this project ships, fetched into `pub/' (see `maak
;;; vendor-assets'), and a page points at them where the deployment said they
;;; are read from (see `(wikimusic config)') -- nowhere by default, which is
;;; this instance's own copy.  Every address in each stylesheet is relative, so
;;; the three files carry their own fonts to whatever host serves them.
(define theme-stylesheets
  '("vendor/fonts/lucida.css"
    "vendor/fonts/google.css"
    "vendor/phosphor/phosphor.css"))

;; The stylesheet the rest of the page is laid out with, and the icon a tab or a
;; bookmark is shown with.  They are this project's own files rather than
;; somebody else's, but a page reads them the same way and from the same place
;; as the three above: an instance that serves its assets from another host says
;; so once, and everything the document itself reads moves with it.
(define page-stylesheet "css/wikimusic.olive.min.css")
(define page-icon "favicon.ico")

;; Every address of the interface's own assets a document head states, built at
;; the one place a document is built: a page reads what this instance serves,
;; or what the deployment said it serves instead of it.
(define (theme-stylesheet-links)
  "Return the links a page reads the interface's type and glyphs with."
  (map (lambda (path)
         `(link (@ (rel stylesheet)
                   (href ,(asset-address path)))
                ""))
       theme-stylesheets))

(define (hosted-elsewhere? fragment host)
  "Return #t when FRAGMENT names HOST anywhere in it.

A fragment is a piece of SXML, so what is read is its written form: the name of
somebody else's host can only reach a page through an address, and an address is
the same string however it is nested."
  (let ((written (format #f "~s" fragment)))
    (and (string-contains written host) #t)))

(define* asset-library
  (build-asset-library '("pub/js/song-auto-scroll.js" "pub/js/symbanta.js"
                         "pub/js/song-chord-highlighter.js"
                         "pub/js/file-base64.js"
                         "pub/js/metronome.js"
                         "pub/js/password-strength.js"
                         "pub/js/guitarpro-player.js")))

;; The two lines every page ends with: where the rest of the project is, and
;; what this running copy is.
;;
;; It used to carry four: a tagline, a row that announced its own links, a
;; sentence of licence and a copyright.  All of that is either said elsewhere
;; -- the tagline is the page's own description -- or said shorter: an SPDX
;; identifier names the licence exactly where a sentence about it only
;; described it, and the reader who wants the whole text is one click from it.
(define* (page-footer G_)
  `(,(footer
      `(;; Where the rest of it is.  The archive is the one link that leaves the
        ;; server behind, so it is offered here rather than only to a reader
        ;; who knows the address: a copy of everything, to save or read
        ;; offline.
        (div (@ (class ,(mk-class '(flex flex-row flex-wrap
                                           gap-2 sm:gap-4
                                           justify-start
                                           items-center))))
             ;; What the place is, first: a reader who has read the collection
             ;; and wants to know who writes it is offered the one page that
             ;; says so, without having to work out that a tagline is a page.
             ,(a (G_ "about")
                 #:href "/about"
                 #:size '(text-md))
             ;; Where the code is, where the manual is and where the licence is
             ;; written out are the deployment's to name, not this view's: a
             ;; fork reads its own source, and an instance that mirrors the
             ;; project says so in its own `env.scm'.  Each falls back to the
             ;; upstream address (see `(wikimusic config)').
             ,(a (G_ "source code")
                 #:href (source-repository-url)
                 #:size '(text-md))
             ;; The manual is the README -- one document to keep true rather
             ;; than two that drift -- so the link leads to that document.
             ,(a (G_ "manual")
                 #:href (manual-url)
                 #:size '(text-md))
             ,(a (G_ "export")
                 #:href "/export/html"
                 #:size '(text-md)))

        ;; What this copy is, who made it, and the way back up.
        (div (@ (class ,(mk-class '(flex flex-row flex-wrap
                                           gap-2 sm:gap-4
                                           justify-start
                                           items-center))))
             (div (@ (class ,(mk-class '(flex flex-row
                                                flex-wrap
                                                gap-1
                                                items-center))))
                  ,(em (G_ "version:")
                       #:size '(text-sm))
                  ,(mono (format #f "~a"
                                 (get-short-commit-sha))
                         #:size '(text-sm)
                         #:weight '(font-light)))
             ,(a (G_ "AGPL-3.0-or-later")
                 #:href (licence-url)
                 #:size '(text-sm))
             ,(em (format #f "© ~a" (copyright-holder))
                  #:size '(text-sm))
             (a (@ (href "javascript:void(0)")
                   (class ,(mk-class '(no-underline
                                       text-onyx-500
                                       dark:text-stone-300
                                       cursor-pointer
                                       font-light)))
                   (onclick
                    "window.scrollTo({ top: 0, behavior: 'smooth' })"))
                ,(G_ "back to the top"))))
      #:footer-classes '(flex flex-col
                                gap-2
                                items-start
                                px-6
                                sm:px-8
                                md:px-12
                                justify-start
                                py-6))))

(define* (nav G_
              #:key is-logged-in (reading? #f))
  (let ((nav-link (lambda (href icon content)
                    `(a (@ (href ,href)
                           (class ,(mk-class '(shrink-0 no-underline))))
                        ,(icon-button #:icon icon
                                      #:content (G_ content)
                                      #:family '(font-sans)
                                      #:color '(text-onyx-900
                                                dark:text-stone-100)
                                      #:weight '(font-light)
                                      #:size '(text-sm sm:text-md)
                                      #:icon-css '(text-sm sm:text-md
                                                   lg:text-lg text-onyx-300
                                                   dark:text-stone-300)
                                      #:extra-classes '(py-1 px-2
                                                        sm:py-1
                                                        sm:px-2
                                                        md:py-2
                                                        md:px-3
                                                        cursor-pointer
                                                        whitespace-nowrap))))))
    `((div (@ (class ,(mk-class (append
                                 ;; The bar is a strip, not a panel: a reader
                                 ;; looks past it on every page, so it keeps
                                 ;; just enough height for its controls and
                                 ;; no more, and grows no taller than the
                                 ;; row it holds.
                                 '(flex flex-col
                                        lg:flex-row
                                        lg:items-center
                                        lg:justify-between
                                        gap-1
                                        sm:gap-2
                                        w-full
                                        px-2
                                        py-1
                                        sm:px-3
                                        sm:py-2
                                        hg-frost bg-stone-100/75
                                        dark:bg-onyx-900/75
                                        rounded-2xl
                                        border
                                        border-stone-500/25
                                        dark:border-onyx-100/10
                                        shadow-md)
                                 ;; While a reader is reading -- a song's ascii
                                 ;; contents, or a PDF beside them -- the bar is
                                 ;; not pinned: it scrolls away with the page and
                                 ;; gives the whole viewport back to the content.
                                 (if reading?
                                     '()
                                     '(sticky top-2 z-32))
                                 '(hover:text-china-violet-700)))))

           ;; Logo
           (div (@ (class ,(mk-class '(flex items-center
                                            justify-center
                                            md:justify-start
                                            w-full
                                            md:w-auto
                                            min-w-0
                                            px-1
                                            sm:px-2))))
                (a (@ (href "/")
                      (class ,(mk-class '(flex items-center
                                               justify-center
                                               gap-1
                                               sm:gap-2
                                               min-w-0
                                               no-underline))))
                   ,(h1 (list (icon #:type 'music-note
                                    #:icon-css '(shrink-0 text-lg
                                                 sm:text-xl
                                                 text-onyx-300
                                                 dark:text-stone-300
                                                 hover:text-persia-pink-900
                                                 dark:hover:text-persia-pink-300))
                              (G_ "WikiMusic"))
                        #:weight '(font-medium italic)
                        #:color '(text-onyx-300 dark:text-stone-300
                                  hover:text-persia-pink-900
                                  dark:hover:text-persia-pink-300)
                        #:family '(font-sans)
                        #:size '(text-lg sm:text-xl md:text-2xl))))

           ;; Navigation / account / theme
           (div (@ (class ,(mk-class '(flex flex-wrap
                                            items-center
                                            justify-center
                                            md:justify-end
                                            gap-1
                                            sm:gap-2
                                            w-full
                                            md:w-auto))))

                ,(nav-link "/songs"
                           'music-notes-simple "songs")

                ,(nav-link "/genres"
                           'disc "genres")

                ,(nav-link "/artists"
                           'guitar "artists")

                ;; Login / profile
                ,(if (not is-logged-in)
                     `(a (@ (href "/login")
                            (class ,(mk-class '(shrink-0 no-underline))))
                         ,(icon-button #:icon 'sign-in
                                       #:content (G_ "login")
                                       #:family '(font-sans)
                                       #:color '(text-onyx-900
                                                 dark:text-stone-100)
                                       #:weight '(font-light)
                                       #:size '(text-sm sm:text-md)
                                       #:icon-css '(text-sm sm:text-md
                                                    lg:text-lg text-onyx-300
                                                    dark:text-stone-300)
                                       #:extra-classes '(py-1 px-2
                                                         sm:py-1
                                                         sm:px-2
                                                         md:py-2
                                                         md:px-3
                                                         cursor-pointer
                                                         whitespace-nowrap)))
                     `(a (@ (href "/me")
                            (class ,(mk-class '(shrink-0 no-underline))))
                         ,(icon-button #:icon 'user-circle
                                       #:content (G_ "me")
                                       #:family '(font-sans)
                                       #:color '(text-onyx-900
                                                 dark:text-stone-100)
                                       #:weight '(font-light)
                                       #:size '(text-sm sm:text-md)
                                       #:icon-css '(text-sm sm:text-md
                                                    lg:text-lg text-onyx-300
                                                    dark:text-stone-300)
                                       #:extra-classes '(py-1 px-2
                                                         sm:py-1
                                                         sm:px-2
                                                         md:py-2
                                                         md:px-3
                                                         cursor-pointer
                                                         whitespace-nowrap))))

                ;; Theme switch
                ,(ui-mode-button #:icon ""
                                 #:size '(text-sm sm:text-md)
                                 #:icon-css '(text-onyx-300
                                              dark:text-stone-300 text-sm
                                              sm:text-md)
                                 #:family '(font-sans)
                                 #:content `((div ,(icon #:type 'sun
                                                         #:icon-css '(text-sm
                                                                      sm:text-md
                                                                      lg:text-lg
                                                                      text-onyx-300
                                                                      dark:text-stone-300))
                                                  ,(icon #:type 'moon
                                                         #:icon-css '(text-sm
                                                                      sm:text-md
                                                                      lg:text-lg
                                                                      text-onyx-300
                                                                      dark:text-stone-300))))
                                 #:color '(text-onyx-900 dark:text-stone-100)
                                 #:weight '(font-light)
                                 #:extra-classes '(shrink-0 py-1
                                                            px-2
                                                            sm:py-1
                                                            sm:px-2
                                                            md:py-2
                                                            md:px-3
                                                            cursor-pointer)))))))

;;; A click track, for a reader practising from a song page.
;;;
;;; The words are the page's: both labels the control can show are written
;;; here -- one for a metronome that is stopped and one for a metronome that is
;;; running -- and the script un-hides one of them, so a translated page stays
;;; translated.  The numbers are the reader's: the tempo, the meter, and the
;;; lamps, one per beat the meter can hold, which the script hides and lights.
;;;
;;; The whole control is hidden until the script finds it, so a browser with no
;;; JavaScript is offered no control that would do nothing.  `data-metronome'
;;; is the only thing the script looks for; everything else it reaches is named
;;; after the control's own identifier, which is why a page may hold more than
;;; one of these without any of them being ambiguous.
(define* (metronome-widget G_
                           #:key id (tempo 120) (beats 4))
  "Return a metronome a reader can practise to, named ID.

@table @var
@item id
The identifier the control and every part of it are named after.  It is what
makes a page holding two metronomes unambiguous, and it is the only contract
between this markup and `pub/js/metronome.js'.
@item tempo
The tempo the control opens with, in beats per minute: the tempo of a stored
tabulation when the page knows one, and 120 otherwise.
@item beats
The beats in a bar the control opens with; the menu offers two, three, four
and six.
@end table"
  (let* ((tempo-id (format #f "~a-tempo" id))
         (beats-id (format #f "~a-beats" id))
         (label-class (mk-class '(dark:text-stone-300
                                  text-stone-500
                                  font-bold
                                  text-sm)))
         (field-class (mk-class '(bg-stone-100/75
                                  dark:bg-onyx-500
                                  dark:text-stone-300
                                  text-onyx-900
                                  border
                                  border-stone-300
                                  rounded-lg
                                  px-2
                                  py-1
                                  text-sm
                                  w-20)))
         (option (lambda (meter)
                   `(option (@ (value ,(number->string meter))
                               ,@(if (= meter beats)
                                     '((selected ""))
                                     '()))
                            ,(number->string meter)))))
    `(div (@ (id ,id)
             (data-metronome "")
             (hidden "")
             (class ,(mk-class '(flex flex-col gap-2 py-2))))
          (div (@ (class ,(mk-class '(flex flex-row
                                              flex-wrap
                                              gap-3
                                              items-center))))
               (label (@ (for ,tempo-id) (class ,label-class))
                      ,(G_ "tempo"))
               (input (@ (type number)
                         (id ,tempo-id)
                         (name ,tempo-id)
                         (min "20")
                         (max "300")
                         (step "1")
                         (inputmode numeric)
                         (value ,(number->string tempo))
                         (class ,field-class)))
               (label (@ (for ,beats-id) (class ,label-class))
                      ,(G_ "beats in a bar"))
               (select (@ (id ,beats-id)
                          (name ,beats-id)
                          (onchange ,(format #f
                                             "wikimusicMetronomeMeterChanged('~a')"
                                             id))
                          (class ,field-class))
                       ,(option 2)
                       ,(option 3)
                       ,(option 4)
                       ,(option 6))
               ,(icon-button #:icon 'timer
                             #:id (format #f "~a-toggle" id)
                             #:on-click (format #f
                                                "wikimusicMetronomeToggle('~a')"
                                                id)
                             #:content `((span (@ (id ,(format #f "~a-start" id)))
                                              ,(G_ "start"))
                                         (span (@ (id ,(format #f "~a-stop" id))
                                                  (hidden ""))
                                               ,(G_ "stop")))))
          ;; One lamp for each beat a meter can hold, all of them dim; the
          ;; script hides the ones this meter does not use and brightens the
          ;; one that is sounding.  They are decoration and are named as such,
          ;; so a screen reader is not read a flickering row it cannot use.
          (div (@ (id ,(format #f "~a-lamps" id))
                  (aria-hidden "true")
                  (class ,(mk-class '(flex flex-row gap-2 items-center))))
               ,@(map (lambda (beat)
                        `(span (@ (id ,(format #f "~a-beat-~a" id beat))
                                  (class ,(mk-class '(w-2
                                                      h-2
                                                      rounded-full
                                                      bg-persia-pink-900
                                                      opacity-40))))
                               ""))
                      '(1 2 3 4 5 6))))))

;;; The picture a page's link preview is shown with, when the page has one.
;;;
;;; An artwork's address is whatever its contributor typed, stored
;;; percent-encoded: it may be a picture on somebody else's server or a path
;;; into this instance's own upload directory.  A preview picture has to be an
;;; address a crawler can fetch from outside, so only an absolute one is used
;;; and a page whose artworks are all relative keeps the site's default.  The
;;; first artwork wins because the artworks are ordered by their own
;;; `order value', which is what puts the picture a contributor chose first.
(define* (artwork-social-image artworks #:key fallback)
  "Return the address of ARTWORKS' first absolute picture, or FALLBACK."
  (let ((addresses (filter (lambda (address)
                             (and (string? address)
                                  (or (string-prefix? "http://" address)
                                      (string-prefix? "https://" address))))
                           (map (lambda (artwork)
                                  (catch #t
                                         (lambda ()
                                           (uri-decode (assq-ref artwork
                                                                 'content-url)))
                                         (lambda (key . args)
                                           (assq-ref artwork 'content-url))))
                                artworks))))
    (if (pair? addresses) (car addresses) fallback)))

;;; The document every page is rendered into.  Its body is what a reader sees;
;;; the keywords after it are what a crawler and a link preview are told about
;;; the page instead, and are collected in `seo-head' (wikimusic seo).
;;;
;;; A page states its own title and description and every caller does: the
;;; title is the `<title>', the tab's label and the headline of a pasted link
;;; all at once, so it is the one place the words a reader would search for are
;;; written down.  The remaining keywords are optional and a page that does not
;;; pass one is described by the site's own defaults.
(define* (html-template G_
                        #:key (title "WikiMusic") body
                        (description #f)
                        (path #f) (url #f)
                        (image #f) (image-alt #f)
                        (og-type "website") (locale "en_US")
                        robots (json-ld '())
                        (is-logged-in #f) (reading? #f))
  
  `(,doctype-html (html (@ (lang ,(language-of locale)))
                        (head (title ,title)
                              ,(hygguile-recommended-meta)
                              ,(seo-head #:title title
                                         #:description description
                                         #:path path
                                         #:url url
                                         #:image image
                                         #:image-alt image-alt
                                         #:og-type og-type
                                         #:locale locale
                                         #:robots robots
                                         #:json-ld json-ld)
                              ;; What the framework recommends a page carry, with
                              ;; its own icon stylesheet left out: that link points
                              ;; at a CDN, and the glyphs are served from here
                              ;; instead (`theme-stylesheet-links' below).
                              ,@(filter (lambda (fragment)
                                          (not (hosted-elsewhere? fragment
                                                                  "cdn.jsdelivr.net")))
                                        (hygguile-recommended-resources
                                         #:fonts (theme-stylesheet-links)))

                              (link (@ (rel "shortcut icon")
                                       (href ,(asset-address page-icon))
                                       (type "image/x-icon")) "")

                              (link (@ (rel "icon")
                                       (href ,(asset-address page-icon))
                                       (type "image/x-icon")) "")

                              (link (@ (rel stylesheet)
                                       (href ,(asset-address
                                               page-stylesheet)))
                                    "")

                              (script (@ (type speculationrules))
                                      "
{
  \"prerender\": [
    {
      \"where\": {
        \"selector_matches\": \"a\"
      }
    }
  ]
}
")

                              (script ,(assoc-ref asset-library
                                        "pub/js/song-chord-highlighter.js"))

                              (script ,(assoc-ref asset-library
                                        "pub/js/song-auto-scroll.js"))

                              (script ,(assoc-ref asset-library
                                                  "pub/js/symbanta.js"))

                              (script ,(assoc-ref asset-library
                                                  "pub/js/file-base64.js"))

                              (script ,(assoc-ref asset-library
                                                  "pub/js/metronome.js"))

                              (script ,(assoc-ref asset-library
                                                  "pub/js/password-strength.js"))

                              (script ,(assoc-ref asset-library
                                                  "pub/js/guitarpro-player.js")))

                        (body (@ (class ,(mk-class '(bg-stone-100
                                                     dark:bg-onyx-900
                                                     font-sans min-h-screen))))

                              ,notification-tray

                              ;; The page's colour, behind everything the frost
                              ;; has to frost (see `ambient-washes').  A wash is
                              ;; wider than any screen and is anchored inside the
                              ;; first screenful, so the three of them lay down
                              ;; in a layer of their own that clips them: a
                              ;; decorative disc must not be what makes a phone
                              ;; scroll sideways to find the edge of the page.
                              (div (@ (class ,(mk-class '(absolute
                                                          inset-0
                                                          overflow-hidden
                                                          pointer-events-none))))
                                   ,@(ambient-washes))

                              ,(with-footer #:main `((main (@ (class ,(mk-class '
                                                                       (flex
                                                                        flex-col
                                                                        justify-start
                                                                        min-h-96
                                                                        w-full
                                                                        min-w-0))))

                                                           ,(nav G_
                                                                 #:is-logged-in
                                                                 is-logged-in
                                                                 #:reading?
                                                                 reading?)

                                                           ;; Content gets its own responsive container.
                                                           (div (@ (class ,(mk-class '
                                                                            (w-full
                                                                             min-w-0
                                                                             px-2
                                                                             sm:px-3
                                                                             md:px-4
                                                                             lg:px-6
                                                                             py-3
                                                                             sm:py-4
                                                                             md:py-6))))

                                                                ,body)))

                                            #:footer (page-footer G_))))))

(define* (item-tile G_
                    entity
                    x
                    artworks
                    comments
                    #:key (extra-bot-info '())
                    (extra-top-info '()))
  (let ((item-link (format #f "/~as/uuid/~a" entity
                           (assq-ref x
                                     'identifier))))
    `((div (@ (class ,(mk-class '(hg-frost bg-stone-100/75 dark:bg-onyx-900/75
                                               rounded-xl
                                               sm:rounded-2xl
                                               shadow-md
                                               hover:shadow-lg
                                               transition-shadow
                                               duration-200
                                               h-full
                                               flex
                                               flex-col
                                               overflow-hidden
                                               border
                                               border-persia-pink-100/25
                                               dark:border-persia-pink-900/10))))

           ;; Cover
           ,(render-if-nempty (lambda (art)
                                `(a (@ (href ,item-link)
                                       (class ,(mk-class '(block w-full
                                                           aspect-square
                                                           shrink-0
                                                           overflow-hidden))))
                                    (img (@ (loading "lazy")
                                            (class ,(mk-class '(w-full h-full
                                                                object-cover
                                                                transition-transform
                                                                duration-200
                                                                hover:scale-105)))
                                            (src ,(uri-decode (assq-ref art
                                                                        'content-url)))))))
                              (cond
                                ((nil? artworks)
                                 '())
                                (else (car artworks))))

           ;; Content
           (div (@ (class ,(mk-class '(flex flex-col
                                            grow
                                            min-w-0
                                            p-2
                                            sm:p-3
                                            md:p-4))))

                ;; Name
                (div (@ (class ,(mk-class '(min-w-0 text-center))))
                     ,(a (assq-ref x
                                   'display-name)
                         #:size '(text-md sm:text-md md:text-lg)
                         #:weight '(font-light)
                         #:family '(font-sans)
                         #:href item-link
                         #:color '(text-onyx-300 dark:text-stone-100)
                         #:hover '(hover:text-persia-pink-500
                                   dark:hover:text-persia-pink-300)))

                ;; Extra information
                ,(render-if-nempty (lambda (info)
                                     `(div (@ (class ,(mk-class '(pt-1 sm:pt-2
                                                                  text-center))))
                                           ,info)) extra-top-info)

                ;; Statistics
                (div (@ (class ,(mk-class '(mt-2 flex flex-wrap items-center
                                                 justify-center gap-1))))
                     (div ,(em (format #f "~a ~a"
                                       (assq-ref x
                                                 'views)
                                       (G_ "views"))
                               #:size '(text-sm)
                               #:color '(text-onyx-300 dark:text-stone-300)))

                     (span ,(p "·"
                               #:color '(text-onyx-500 dark:text-stone-700)
                               #:size '(text-sm)))

                     (div (@ (class ,(mk-class '(min-w-0))))
                          ,(em (format #f "~a ~a"
                                       (length comments)
                                       (G_ "comments"))
                               #:size '(text-sm)
                               #:color '(text-onyx-300 dark:text-stone-300))))

                ,extra-bot-info)))))

(define* (render-visibility-status G_ status)
  (cond
    ((eq? status 0)
     (G_ "published"))
    (else (G_ "unkown status"))))

;; A comment's toolbar.  Reply, edit and delete all need the entity the thread
;; hangs off and the comment's own identifier, so both are handed down from the
;; page rather than guessed.  Every control is rendered for every reader -- the
;; way the entity's own edit link is -- and the route it posts to is what
;; refuses a session that may not use it (see `guard-owner').
(define* (comment-actions G_ #:key entity entity-identifier comment)
  (let* ((comment-identifier (assq-ref comment 'identifier))
         (base (format #f "/~as/uuid/~a/comments/~a" entity entity-identifier
                       comment-identifier)))
    `(div (@ (class ,(mk-class '(flex flex-row flex-wrap gap-3
                                          items-center my-2))))
          (details
           (summary (@ (class ,(mk-class '(cursor-pointer
                                           text-sm
                                           text-persia-pink-500
                                           dark:text-persia-pink-300))))
                    ,(G_ "reply"))
           (form (@ (method POST)
                    (action ,(format #f "/~as/uuid/~a/comments/new" entity
                                     entity-identifier)))
                 (input (@ (type hidden)
                           (name parent-identifier)
                           (value ,comment-identifier)))
                 ,(textarea #:label (G_ "your reply")
                            #:name "contents"
                            #:rows 3
                            #:maxlength 4096
                            #:textarea-css '(p-3
                                             rounded-xl
                                             border-2
                                             border-stone-700
                                             dark:border-onyx-100
                                             dark:text-stone-300
                                             dark:bg-onyx-700/75
                                             bg-stone-300/75
                                             min-h-16
                                             w-full
                                             max-w-prose
                                             resize-y
                                             shadow-md))
                 ,(button (G_ "post reply") #:type 'submit)))
          (details
           (summary (@ (class ,(mk-class '(cursor-pointer
                                           text-sm
                                           text-persia-pink-500
                                           dark:text-persia-pink-300))))
                    ,(G_ "edit"))
           (form (@ (method POST)
                    (action ,(format #f "~a/edit" base)))
                 ,(textarea #:label (G_ "your comment")
                            #:name "contents"
                            #:value (or (assq-ref comment 'contents) "")
                            #:rows 3
                            #:maxlength 4096
                            #:textarea-css '(p-3
                                             rounded-xl
                                             border-2
                                             border-stone-700
                                             dark:border-onyx-100
                                             dark:text-stone-300
                                             dark:bg-onyx-700/75
                                             bg-stone-300/75
                                             min-h-16
                                             w-full
                                             max-w-prose
                                             resize-y
                                             shadow-md))
                 ,(button (G_ "save") #:type 'submit)))
          (form (@ (method POST)
                   (action ,(format #f "~a/delete" base)))
                ,(button (G_ "delete")
                         #:type 'submit
                         #:color '(text-stone-100)
                         #:background '(bg-redwood-500)
                         #:hover-background '(hover:bg-redwood-900))))))

(define* (render-comment G_ user-alist comment
                         #:key entity entity-identifier)
  `(div (@ (class ,(mk-class '(py-3 max-w-prose
                                      rounded-lg
                                      border-2
                                      border-stone-500/25
                                      dark:border-onyx-100/25
                                      px-3))))
        ,(render-if-nempty (lambda (u)
                             `(p (@ (class ,(mk-class '(text-sm
                                                        text-stone-500))))
                                 ,(format #f "~a (~a) &lt;~a&gt;"
                                          (assoc-ref u "display_name")
                                          (assoc-ref u "username")
                                          (assoc-ref u "email"))))
                           (car (assoc-ref user-alist
                                           (assq-ref comment
                                                     'created-by))))
        (p (@ (class ,(mk-class '(text-md text-stone-900))))
           ,(assq-ref comment
                      'contents))
        (p (@ (class ,(mk-class '(text-sm text-stone-500 dark:text-stone-300))))
           ,(assq-ref comment
                      'created-at))
        ,(render-if-nempty (lambda (at)
                             `(p (@ (class ,(mk-class '(text-sm
                                                        italic
                                                        text-stone-500
                                                        dark:text-stone-300))))
                                 ,(G_ "edited")))
                           (assq-ref comment 'last-edited-at))
        ,(comment-actions G_ #:entity entity
                          #:entity-identifier entity-identifier
                          #:comment comment)))

(define* (render-comments G_ user-alist parent-identifier comments
                          #:key entity entity-identifier)
  (let* ((top-nodes (filter (lambda (c)
                              (equal? parent-identifier
                                      (assoc-ref c
                                                 'parent-identifier)))
                            comments)))
    (map (lambda (comment)
           `((div (@ (class "max-w-prose"))
                  ,(render-comment G_ user-alist comment
                                   #:entity entity
                                   #:entity-identifier entity-identifier))
             (div (@ (class ,(mk-class '(max-w-prose pl-3))))
                  ,(render-comments G_ user-alist
                                    (assoc-ref comment
                                               'identifier) comments
                                    #:entity entity
                                    #:entity-identifier entity-identifier))))
         top-nodes)))

(define* (entity-details G_
                         #:key entity
                         x
                         artworks
                         opinions
                         comments
                         user-alist)
  (let* (         ;; One photograph is a photograph and is shown as one.  Two or more
         ;; are a carousel: the framework's track pans with a swipe and its
         ;; arrows page one picture at a time, and both of those are better
         ;; than a stack that pushes the rest of the page -- the opinions, the
         ;; description, every fact a reader came for -- below the fold.  The
         ;; arrows carry the framework's own `.js-only' class, so a browser
         ;; with no scripting is told to scroll the track instead of being
         ;; offered controls that do nothing.
         (artwork-count (length (if (list? artworks) artworks '())))
         ;; A picture is sized by the room it is standing in and not by itself,
         ;; and the room is the same on every page: a figure of one height per
         ;; breakpoint, growing with the slide beside it and then stopping, with
         ;; the picture fitted inside it and never made bigger than it already
         ;; is.
         ;;
         ;; Both halves of that are corrections.  Filling the slide outright
         ;; -- what this did -- blew a small portrait up to the width of the
         ;; track, where it stood taller than the photograph beside it and set
         ;; the height of the whole row: a band of empty panel under one
         ;; picture on a phone, a column of nothing on a desk.  And a *limit*
         ;; alone still let the row be as tall as the tallest thing in it, so
         ;; the page moved -- and the facts a reader came for moved with it --
         ;; according to which pictures a contributor had happened to upload.
         ;; A figure of its own height is the same on every song: the pictures
         ;; inside it are shown at the size they were made at when that fits,
         ;; shrunk to fit when it does not, and centred either way, with their
         ;; own proportions kept.
         (rendered-artworks (map (lambda (art)
                                   `(figure (@ (class ,(mk-class '(w-full
                                                                   h-48
                                                                   sm:h-72
                                                                   md:h-96
                                                                   flex flex-col
                                                                   items-center
                                                                   justify-center
                                                                   gap-2))))

                                            (div (@ (class ,(mk-class '(flex-1
                                                                        min-h-0
                                                                        w-full
                                                                        flex
                                                                        items-center
                                                                        justify-center))))
                                                 (img (@ (loading lazy)
                                                         (class ,(mk-class '(max-w-full
                                                                             max-h-full
                                                                             w-auto
                                                                             h-auto
                                                                             rounded-xl
                                                                             shadow-md)))
                                                         (src ,(uri-decode (assq-ref
                                                                            art
                                                                            'content-url))))))
                                            ,(render-if-nempty (lambda (fc)
                                                                 `(figcaption (@
                                                                               (class ,
                                                                                (mk-class '
                                                                                 (text-onyx-300
                                                                                  dark:text-stone-300))))
                                                                              ,fc))
                                                               (assq-ref art
                                                                         'content-caption))))
                                 artworks))
         (rendered-comments (render-comments G_ user-alist #f comments
                                             #:entity entity
                                             #:entity-identifier
                                             (assq-ref x 'identifier)))
         (like-count (length (filter (lambda (o)
                                       (and (equal? (assq-ref x
                                                              'identifier)
                                                    (assoc-ref o
                                                               (string->symbol
                                                                (format #f
                                                                 "~a-identifier"
                                                                 entity))))
                                            (equal? 1
                                                    (assq-ref o
                                                              'is-like))))
                                     opinions)))
         (dislike-count (length (filter (lambda (o)
                                          (and (equal? (assq-ref x
                                                                 'identifier)
                                                       (assq-ref o
                                                                 (string->symbol
                                                                  (format #f
                                                                   "~a-identifier"
                                                                   entity))))
                                               (equal? 1
                                                       (assoc-ref o
                                                                  'is-dislike))))
                                        opinions)))
         (opinion-buttons `((div (@ (class ,(mk-class '(flex flex-row
                                                             flex-wrap gap-3))))
                                 (form (@ (method POST)
                                          (action ,(format #f
                                                    "/~as/uuid/~a/like" entity
                                                    (assq-ref x
                                                              'identifier))))
                                       ,(icon-button #:icon 'thumbs-up
                                                     #:color '(text-stone-100)
                                                     #:background '(bg-asparagus-500)
                                                     #:hover-background '(hover:bg-asparagus-900)
                                                     #:type 'submit
                                                     #:icon-css '(text-lg
                                                                  text-stone-300
                                                                  dark:text-stone-300)
                                                     #:content `(div ,(G_
                                                                       "like")
                                                                     (span (@ (class ,
                                                                               (mk-class '
                                                                                (font-light
                                                                                 text-md))))
                                                                           ,(format
                                                                             #f
                                                                             " ( ~a ) "
                                                                             like-count)))))
                                 (form (@ (method POST)
                                          (action ,(format #f
                                                    "/~as/uuid/~a/dislike"
                                                    entity
                                                    (assq-ref x
                                                              'identifier))))
                                       ,(icon-button #:icon 'thumbs-down
                                                     #:color '(text-stone-100)
                                                     #:background '(bg-redwood-500)
                                                     #:hover-background '(hover:bg-redwood-900)
                                                     #:type 'submit
                                                     #:icon-css '(text-lg
                                                                  text-stone-300
                                                                  dark:text-stone-300)
                                                     #:content `(div ,(G_
                                                                       "dislike")

                                                                     (span (@ (class ,
                                                                               (mk-class '
                                                                                (font-light
                                                                                 text-sm))))
                                                                           ,(format
                                                                             #f
                                                                             " ( ~a ) "
                                                                             dislike-count))))))))
         (maybe-description (render-if-nestring (lambda (description)
                                                  (dl (list (dt (G_
                                                                 "description")
                                                                #:dt-classes '
                                                                (pt-3 sm:pt-4
                                                                      pb-1))
                                                            (dd (org2html (html-unescape
                                                                           description))))))
                                                (assq-ref x
                                                          'description)))
         (maybe-last-edited-at (render-if-nempty (lambda (last-edited-at)
                                                   `(,(dt (G_ "last edited")
                                                          #:dt-classes '(pt-3
                                                                         sm:pt-4
                                                                         pb-1)) ,
                                                     (dd (strftime "%c"

                                                                   (localtime (string->number
                                                                               last-edited-at))))))
                                                 (assq-ref x
                                                           'last-edited-at)))
         (maybe-approved-by (render-if-nempty (lambda (approved-by)
                                                `(,(dt (G_ "approved by")
                                                       #:dt-classes '(pt-3
                                                                      sm:pt-4
                                                                      pb-1)) ,
                                                  (dd approved-by)))
                                              (assq-ref x
                                                        'approved-by))))
    
    `((div (@ (class ,(mk-class '(hg-frost
                                  bg-stone-100/75
                                  dark:bg-onyx-900/75
                                  rounded-3xl
                                  border-2
                                  border-stone-500/25
                                  dark:border-onyx-100/25
                                  shadow-lg
                                  p-4
                                  sm:p-6
                                  flex flex-row flex-wrap gap-6))))
           ,@(if (> artwork-count 1)
                 (carousel #:id (format #f "artworks-~a-~a" entity
                                        (assq-ref x 'identifier))
                           #:fragments rendered-artworks
                           ;; The track is as wide as the panel and no
                           ;; wider: without this the list is sized by the
                           ;; pictures in it, so a card holding four of them
                           ;; stretches to their width and takes the whole
                           ;; page sideways with it -- the arrows land off the
                           ;; screen and the right-hand one cannot be pressed.
                           #:carousel-list-wrapper-css '(relative min-w-0 w-full)
                           #:carousel-list-css '(flex
                                                 gap-3
                                                 sm:gap-4
                                                 lg:gap-6
                                                 list-none
                                                 w-full
                                                 overflow-x-auto
                                                 scroll-smooth
                                                 snap-x
                                                 rounded-xl
                                                 my-2)
                           ;; A slide on a phone is a share of the track
                           ;; rather than a width in `rem': a fixed width that
                           ;; fits one phone overflows the next one down, and
                           ;; the point of the sliver of the next picture left
                           ;; showing is that it is a share of whatever width
                           ;; the track turned out to be.  From the small
                           ;; breakpoint up the track is wide enough to size a
                           ;; slide in `rem' again, and a reader sees one and a
                           ;; half of them at every width from there to the
                           ;; widest desk.
                           #:item-width '(w-5/6 sm:w-72 md:w-96 lg:w-128)
                           #:item-height '(h-auto)
                           #:carousel-item-content-css '(flex items-center
                                                              justify-center)
                           #:no-js-hint (G_ "several pictures — scroll sideways to see them"))
                 (list `(div ,rendered-artworks)))
           (div (div (@ (class ,(mk-class '(flex flex-col gap-3 my-4))))
                     ,opinion-buttons
                     (a (@ (href ,(format #f "/~as/uuid/~a/edit" entity
                                          (assq-ref x
                                                    'identifier))))
                        ,(icon-button #:icon 'pencil
                                      #:content (G_ "edit"))))
                ,maybe-description
                (dl ,(dt (G_ "views")
                         #:dt-classes '(pt-3 sm:pt-4 pb-1))
                    ,(dd (format #f "~a"
                                 (assq-ref x
                                           'views)))
                    ,(dt (G_ "created")
                         #:dt-classes '(pt-3 sm:pt-4 pb-1))
                    ,(dd (strftime "%c"
                                   (localtime (string->number (assq-ref x
                                                                        'created-at)))))
                    ,maybe-last-edited-at
                    ,(dt (G_ "contributor")
                         #:dt-classes '(pt-3 sm:pt-4 pb-1))
                    ,(dd (render-if-nempty (lambda (u)
                                             (format #f "~a &lt;~a&gt;"
                                                     (assq-ref u
                                                               'username)
                                                     (assq-ref u
                                                               'email)))
                                           (assoc-ref user-alist
                                                      (assq-ref x
                                                                'created-by))))
                    ,(dt (G_ "visibility")
                         #:dt-classes '(pt-3 sm:pt-4 pb-1))
                    ,(dd (render-visibility-status G_
                                                   (assq-ref x
                                                             'visibility-status)))
                    ,maybe-approved-by
                    ,(dt (G_ "uuid")
                         #:dt-classes '(pt-3 sm:pt-4 pb-1))
                    ,(dd `((div (@ (class ,(mk-class '(flex flex-row flex-wrap
                                                            gap-4))))
                                ,(mono (assq-ref x
                                                 'identifier)
                                       #:size '(text-sm)
                                       #:color '(text-stone-500
                                                 dark:text-stone-500))
                                ,(icon-button #:icon 'copy
                                              #:content "copy"

                                              #:on-click (format #f
                                                          "navigator.clipboard.writeText('~a')"
                                                          (assoc-ref x
                                                                     'identifier)))))))))
      (details (summary (@ (class ,(mk-class '(text-onyx-300
                                               dark:text-stone-300
                                               cursor-pointer))))
                        ,(em (format #f "~a ~a"
                                     (length comments)
                                     (G_ "comments"))))
               ;; Anyone signed in may add a comment; nobody else is let in by
               ;; the route this posts to.
               (form (@ (method POST)
                        (action ,(format #f "/~as/uuid/~a/comments/new" entity
                                         (assq-ref x 'identifier))))
                     ,(textarea #:label (G_ "new comment")
                                #:name "contents"
                                #:rows 4
                                #:maxlength 4096
                                #:textarea-css '(p-3
                                                 rounded-xl
                                                 border-2
                                                 border-stone-700
                                                 dark:border-onyx-100
                                                 dark:text-stone-300
                                                 dark:bg-onyx-700/75
                                                 bg-stone-300/75
                                                 min-h-16
                                                 w-full
                                                 max-w-prose
                                                 resize-y
                                                 shadow-md))
                     ,(button (G_ "post comment") #:type 'submit))
               ,rendered-comments))))

(define* (artwork-form G_
                       #:key entity
                       entity-identifier
                       (artwork-identifier #f)
                       (content-url "")
                       (content-caption "")
                       (order-value 0))
  (let* ((form-action (if (equal? #f artwork-identifier)
                          (format #f "/~as/uuid/~a/artworks/new" entity
                                  entity-identifier)
                          (format #f "/~as/uuid/~a/artworks/edit/~a" entity
                                  entity-identifier artwork-identifier))))
    `((div (@ (class ,(mk-class '(flex flex-col gap-2))))
           (form (@ (method POST)
                    (content-type application/x-www-form-urlencoded)
                    (action ,form-action))
                 (div ,(input #:label (G_ "content url")
                              #:name "content-url"
                              #:value content-url
                              #:required #t)
                      ,(input #:label (G_ "content caption")
                              #:name "content-caption"
                              #:value content-caption)
                      ,(input #:label (G_ "order value")
                              #:type 'number
                              #:name "order-value"
                              #:value order-value)
                      (div ,(submit-button (if artwork-identifier
                                               (G_ "edit")
                                               (G_ "create"))))))
           ,(render-if-nempty (lambda (artwork-id)
                                `(form (@ (method POST)
                                          (content-type
                                           application/x-www-form-urlencoded)
                                          (action ,(format #f
                                                    "/~as/uuid/~a/artworks/~a/delete"
                                                    entity entity-identifier
                                                    artwork-identifier)))
                                       ,(danger-submit-button (G_ "delete"))))
                              artwork-identifier)))))

(define* (external-sources-form G_
                                #:key entity
                                entity-identifier
                                (external-sources-identifier #f)
                                (wikipedia-url "")
                                (youtube-url "")
                                (spotify-url "")
                                (soundcloud-url ""))
  (let* ((form-action (if (equal? #f external-sources-identifier)
                          (format #f "/~as/uuid/~a/external-sources/new"
                                  entity entity-identifier)
                          (format #f "/~as/uuid/~a/external-sources/~a/edit"
                                  entity entity-identifier
                                  external-sources-identifier))))
    `((div (@ (class ,(mk-class '(flex flex-col gap-2))))
           (form (@ (method POST)
                    (content-type application/x-www-form-urlencoded)
                    (action ,form-action))
                 (div ,(input #:label (G_ "wikipedia url")
                              #:name "wikipedia-url"
                              #:value wikipedia-url
                              #:required #f)
                      ,(input #:label (G_ "youtube url")
                              #:name "youtube-url"
                              #:value youtube-url
                              #:required #f)
                      ,(input #:label (G_ "spotify url")
                              #:name "spotify-url"
                              #:value spotify-url
                              #:required #f)
                      ,(input #:label (G_ "soundcloud url")
                              #:name "soundcloud-url"
                              #:value soundcloud-url
                              #:required #f)
                      (div ,(submit-button (if external-sources-identifier
                                               (G_ "save")
                                               (G_ "save"))))))))))

(define* (sort-select G_
                      #:key entity user-sort)
  `((div (@ (class ,(mk-class '(flex flex-col gap-2 w-min))))
         (select (@ (onchange "window.location.href=this.value;")
                    (name "sort-select")
                    (id "sort-select")
                    (class ,(mk-class '(px-3 py-2
                                             border-2
                                             border-persia-pink-300/25
                                             dark:border-persia-pink-300/25
                                             font-sans
                                             hg-frost bg-stone-100/75
                                             dark:bg-onyx-900/75
                                             text-onyx-300
                                             dark:text-stone-300
                                             rounded-xl
                                             shadow-md))))
                 (option (@ (disabled "true"))
                         ,(G_ "sort order"))
                 ,(map (lambda (s)
                         `((option (@ (value ,(format #f "/~as?sort=~a" entity
                                                      (car s)))
                                      ,(cond
                                         ((equal? user-sort
                                                  (car s))
                                          '(selected ""))
                                         (else '(not-selected ""))))
                                   ,(cdr s))))

                       `(("display-name-asc" unquote
                          (G_ "Name - Ascending"))
                         ("display-name-desc" unquote
                          (G_ "Name - Descending"))

                         ("created-at-asc" unquote
                          (G_ "Created - Ascending"))
                         ("created-at-desc" unquote
                          (G_ "Created - Descending"))

                         ("last-edited-at-asc" unquote
                          (G_ "Last edited - Ascending"))
                         ("last-edited-at-desc" unquote
                          (G_ "Last edited - Descending"))

                         ("views-asc" unquote
                          (G_ "Views - Ascending"))
                         ("views-desc" unquote
                          (G_ "Views - Descending"))

                         ))))))

(define* (grid-size-select G_
                           #:key entity size (search-query #f))
  "Render the tile-size chooser.

The chooser is three links and not a `select': each one is a size, and
following it takes the reader to the same list carrying `grid-size' in the
query string, which the route stores in the `wikimusic-grid-size' cookie and
reads back on the next page.  A link is what lets the control be three icons
with no script behind them, and it is also what makes a size an address a
reader can open, bookmark or share.

What the control shows is the icon alone -- no page needs the words `small',
`medium' and `large' taking up room beside a list -- so the wording is what
names each link to a reader who cannot see it, through the link's title and its
accessible name, and the control itself is named to a screen reader.

ENTITY is the list's own name -- `song', `artist', `genre' -- so each page
chooses its own size against its own address, and SEARCH-QUERY is carried along
when the reader is looking at search results, so that choosing a size does not
throw the results away."
  (let ((tail (if (and search-query
                       (not (equal? search-query "")))
                  (format #f "&search=~a" search-query)
                  "")))
    `((div (@ (role "group")
              (aria-label ,(G_ "tile size"))
              (class ,(mk-class '(inline-flex flex-row items-center
                                             gap-1
                                             p-1
                                             rounded-xl
                                             border
                                             border-persia-pink-100/25
                                             dark:border-persia-pink-900/10
                                             bg-stone-100/50
                                             dark:bg-onyx-900/50))))
           ,@(map (lambda (choice)
                    (let ((name (car choice))
                          (glyph (cadr choice))
                          (wording (caddr choice)))
                      (let ((current? (equal? size name)))
                        `(a (@ (href ,(format #f "/~as?grid-size=~a~a"
                                              entity name tail))
                               (title ,wording)
                               (aria-label ,wording)
                               ,@(if current?
                                     '((aria-current "true"))
                                     '())
                               (class ,(mk-class
                                        (append
                                         '(inline-flex items-center
                                                       justify-center
                                                       p-1
                                                       rounded-lg
                                                       no-underline
                                                       cursor-pointer
                                                       transition-colors
                                                       duration-150)
                                         (if current?
                                             '(bg-persia-pink-500/15
                                               text-persia-pink-700
                                               dark:text-persia-pink-300)
                                             '(text-onyx-300/50
                                               dark:text-stone-300/50
                                               hover:bg-stone-300/40
                                               dark:hover:bg-onyx-500/40
                                               hover:text-persia-pink-500
                                               dark:hover:text-persia-pink-300))))))
                            ,(icon #:type glyph
                                   #:weight (if current? 'bold 'regular)
                                   #:icon-css '(text-base))))))
                  (list (list "small" 'dots-nine (G_ "Small tiles"))
                        (list "medium" 'squares-four (G_ "Medium tiles"))
                        (list "large" 'square (G_ "Large tiles"))))))))

(define* (ascii-size-select G_
                            #:key route)
  `((div (@ (class ,(mk-class '(flex flex-col gap-2 w-min))))
         (select (@ (onchange "window.location.href=this.value;")
                    (name ascii-size-select)
                    (id ascii-size-select)
                    (class ,(mk-class '(py-2 px-3
                                             border-2
                                             border-persia-pink-300/25
                                             dark:border-persia-pink-300/25
                                             hg-frost bg-stone-100/75
                                             dark:bg-onyx-900/75
                                             text-onyx-300
                                             dark:text-stone-300
                                             rounded-xl
                                             max-w-72
                                             shadow-md))))
                 (option ,(G_ "ascii size"))
                 ,(map (lambda (s)
                         `((option (@ (value ,(format #f "~a?ascii-size=~a"
                                                      route
                                                      (car s))))
                                   ,(cdr s))))
                       `(("text-xs" . "text-xs") ("text-sm" . "text-sm")
                         ("text-md" . "text-md")
                         ("text-lg" . "text-lg")
                         ("text-xl" . "text-xl")
                         ("text-1" . "text-1")
                         ("text-2" . "text-2")
                         ("text-3" . "text-3")
                         ("text-4" . "text-4")
                         ("text-5" . "text-5")
                         ("text-6" . "text-6")
                         ("text-7" . "text-7")
                         ("text-8" . "text-8")
                         ("text-9" . "text-9")
                         ("text-10" . "text-10")
                         ("text-11" . "text-11")
                         ("text-12" . "text-12")
                         ("text-16" . "text-16")))))))

;; The search control, and where it takes the words it is given.
;;
;; A list page searches itself: the words are added to the query string the page
;; is already read with, so the sort order, the tile size and the page number a
;; reader chose survive their search.  A page *about* something else -- the
;; front page -- names the collection instead, and the form is then an ordinary
;; GET: a browser without scripting submits it to `/songs?search=…' and the
;; script below navigates to the same address, so the control behaves the same
;; with and without it.
(define* (search-box G_
                     #:key search-query (action "") (centered? #f))
  `((script
     "
function addSearchQueryParam(form) {
  const searchInput = document.getElementsByName('search')[0];

  if (searchInput.value) {
    // A form that names another page is asking *there*: the words travel with
    // it and the query string this page carries stays where it is.
    const action = form.getAttribute('action');

    if (action) {
      window.location.href = `${action}?search=${encodeURIComponent(searchInput.value)}`;
      return false; // Prevent the default form submission
    }

    const urlSearchParams = new URLSearchParams(window.location.search);
    var params = Object.fromEntries(urlSearchParams.entries());

    params.search = encodeURIComponent(searchInput.value);

    const q = Object.entries(params).map((k,_)=>`${k[0]}=${k[1]}`).reduce((a,b) => `${a}&${b}`);

    console.log(q);
    console.log(`${window.location.pathname}?${q}`);

    window.location.href = `${window.location.pathname}?${q}`;
    return false; // Prevent the default form submission
  }
  return true; // Allow default submission if the input is empty
}
")
    (div (@ (class ,(mk-class '(my-3))))
         (form (@ (action ,action)
                  (onsubmit "addSearchQueryParam(this)"))
               ;; A list page reads its words at the end of its own toolbar, so
               ;; they line up with the left of it; a page that offers the
               ;; control on its own -- the front page -- asks for it centred
               ;; at every width.
               (div (@ (class ,(mk-class
                                (append
                                 '(flex flex-row
                                        items-center
                                        flex-wrap
                                        gap-2)
                                 (if centered?
                                     '(justify-center)
                                     '(justify-center md:justify-start)))))))
                    ,(input #:label ""
                            #:name "search"
                            #:value (cond
                                      ((equal? #f search-query)
                                       "")
                                      (else search-query))
                            #:placeholder (G_ "Search...")
                            #:input-css '(py-2 px-3
                                               max-w-prose
                                               rounded-xl
                                               border-2
                                               border-persia-pink-300/25
                                               dark:border-persia-pink-300/25
                                               hg-frost bg-stone-100/75
                                               dark:bg-onyx-900/75
                                               dark:text-stone-300
                                               text-onyx-300
                                               shadow-md)
                            #:input-flex-css #f)
                    ,(submit-button (G_ "search"))))))

(define* (render-external-link #:key link label)
  (render-if-nestring (lambda (l)
                        `((div (@ (class ,(mk-class '(flex flex-row gap-1
                                                           items-center
                                                           flex-wrap
                                                           items-center))))
                               ,(a `((div (@ (class ,(mk-class '(flex flex-row
                                                                 items-center
                                                                 gap-1))))
                                          (span ,label)
                                          ,(icon #:type 'link
                                                 #:icon-css '(text-china-violet-700
                                                              dark:text-china-violet-300
                                                              hover:text-persia-pink-500
                                                              dark:hover:text-persia-pink-300
                                                              text-2xl))))
                                   #:href l
                                   #:size '(text-lg)
                                   #:weight '(font-light)
                                   #:color '(text-china-violet-700
                                             dark:text-china-violet-300)
                                   #:hover '(hover:text-persia-pink-500
                                             dark:hover:text-persia-pink-300))

                               ))) link))

(define* (render-external-sources G_ external-sources)
  `((div (@ (class ,(mk-class '(flex flex-row
                                     flex-wrap
                                     gap-6
                                     py-2
                                     px-6
                                     md:py-4
                                     md:px-12
                                     w-full
                                     justify-center
                                     items-start
                                     items-end))))
         ,(render-external-link #:link (uri-decode (assoc-ref-or-empty-str
                                                    external-sources
                                                    'wikipedia-url))
                                #:label (G_ "Wikipedia"))
         ,(render-external-link #:link (uri-decode (assoc-ref-or-empty-str
                                                    external-sources
                                                    'spotify-url))
                                #:label (G_ "Spotify"))
         ,(render-external-link #:link (uri-decode (assoc-ref-or-empty-str
                                                    external-sources
                                                    'youtube-url))
                                #:label (G_ "Youtube"))
         ,(render-external-link #:link (uri-decode (assoc-ref-or-empty-str
                                                    external-sources
                                                    'soundcloud-url))
                                #:label (G_ "Soundcloud")))))

(define (org2html org)
  (parameterize ((link-classes '(dark:text-china-violet-300
                                 dark:hover:text-persia-pink-300
                                 hover:text-persia-pink-500
                                 text-china-violet-700 hover:underline
                                 font-bold))
                 (italic-classes '(italic))
                 (ordered-list-classes '(list-decimal ml-3))
                 (ordered-list-item-classes '(font-sans text-onyx-500
                                                        dark:text-stone-500
                                                        text-md leading-7))
                 (unordered-list-classes '(list-disc ml-3))
                 (unordered-list-item-classes '(font-sans text-onyx-500
                                                          dark:text-stone-500
                                                          text-md leading-7))
                 (heading-classes (lambda (level)
                                    (case level
                                      ((1)
                                       '(my-2 text-4xl font-bold text-onyx-300
                                              dark:text-stone-300))
                                      ((2)
                                       '(my-2 text-3xl font-bold text-onyx-300
                                              dark:text-stone-300))
                                      ((3)
                                       '(my-2 text-2xl font-bold text-onyx-300
                                              dark:text-stone-300))
                                      (else '(my-2 text-xl font-bold
                                                   text-onyx-300
                                                   dark:text-stone-300)))))
                 (separator-classes '(my-8 mx-4 border-2 border-stone-500/50
                                           dark:border-onyx-100/50))
                 (paragraph-classes '(font-sans text-onyx-500
                                                dark:text-stone-500
                                                text-md
                                                leading-7
                                                max-w-196
                                                overflow-hidden))
                 (bold-classes '(font-bold text-onyx-500 dark:text-stone-500))
                 (example-block-classes '(hg-frost bg-stone-100/75 dark:bg-onyx-900/75
                                                          text-onyx-700
                                                          dark:text-stone-300
                                                          rounded-lg
                                                          my-3
                                                          py-2
                                                          px-3
                                                          whitespace-pre
                                                          font-mono
                                                          overflow-x-scroll))
                 (quote-block-classes '(hg-frost bg-stone-100/75 dark:bg-onyx-900/75
                                                        text-onyx-700
                                                        dark:text-stone-300
                                                        rounded-lg
                                                        my-3
                                                        py-2
                                                        px-3
                                                        whitespace-pre
                                                        font-sans
                                                        overflow-x-scroll))
                 (code-block-classes '(hg-frost bg-stone-100/75 dark:bg-onyx-900/75
                                                       text-onyx-700
                                                       dark:text-stone-300
                                                       rounded-lg
                                                       my-3
                                                       py-2
                                                       px-3
                                                       whitespace-pre
                                                       font-mono
                                                       overflow-x-scroll))
                 (code-classes '(rounded-lg hg-frost bg-stone-100/75
                                            dark:bg-onyx-900/75
                                            text-onyx-700
                                            px-2
                                            py-1
                                            font-mono
                                            dark:text-stone-300)))
    (org->html org)))
