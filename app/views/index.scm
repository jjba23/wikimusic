;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (app views index)
  #:use-module (wikimusic config)
  #:use-module (wikimusic html)
  #:use-module (wikimusic prose)
  #:use-module (wikimusic seo)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (hygguile hygguile)
  #:use-module (ice-9 i18n)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun)
  ;; `wikimusic-support' is exported beside the page: the front page's own ask
  ;; is the ask anywhere else a reader is told about the project, so the about
  ;; page links the one donation control rather than growing a second one.
  #:export (welcome-page wikimusic-support))

;;; The front page is the way in.
;;;
;;; A visitor who has never heard of the place lands here, and what they need
;;; from the first screen is what it is, what they can do with it, and a way to
;;; start -- not a list of somebody else's songs, which is what the page used to
;;; open on.  So the page is one sleeve: the name of the place over the
;;; collection's own figures, the sentence that says what it holds, the search,
;;; and the two doors into it (read the collection, add to it).  Everything
;;; after that first screen is the collection itself -- the promises, the
;;; genres, the newest songs, the newest artists -- and the page closes with
;;; the project's invitation.
;;;
;;; None of the prose is written here: every sentence the page reads is the
;;; project's, kept in one place and read by the about page as well (see
;;; `(wikimusic prose)'), so the two pages cannot drift into saying the same
;;; thing two ways.  This view's business is the page: what is on it, in what
;;; order, and what a crawler is told about it.  How any of it is painted is
;;; the interface's, in `pub/css/wikimusic.css' -- the classes here name a
;;; block of the page, and the sheet decides what a block is.

;; The words the front page is found by: what wikimusic is, and the things a
;; reader looks for in it -- the chords, the tabs and the lyrics of the songs it
;; holds, for the instruments it holds them for.  The same sentence is the meta
;; description, the Open Graph description and the description of the `WebSite'
;; node below, so the front page says the same thing wherever it is read from.
(define front-page-description
  "WikiMusic is a free, community-written encyclopaedia of music: songs, artists and genres, with guitar and bass tabs, chords, lyrics, keys, tunings and sheet music, written by musicians for anyone learning to play.")

(define* (welcome-page G_
                       #:key is-logged-in
                       selected-locale
                       song-fragment
                       artist-fragment
                       genres
                       (counts '()))
  (html-template G_
                 #:is-logged-in is-logged-in
                 #:title
                 "WikiMusic: guitar tabs, chords and lyrics for every song"
                 #:description front-page-description
                 #:path "/"
                 #:json-ld (list (append (list (schema-name "WebSite")
                                               (cons "name" "WikiMusic")
                                               (cons "alternateName"
                                                     "the free music knowledge encyclopaedia")
                                               (cons "description"
                                                     front-page-description))
                                         (if (absolute-url "/")
                                           (list (cons "url"
                                                       (absolute-url "/")))
                                           '())))
                 #:body `(div (@ (class "wm-front"))
                              ,(front-page-hero G_ counts)
                              ,(front-page-promises G_)
                              ,@(front-page-genres G_ genres)
                              ,(front-page-newest G_ song-fragment)
                              ,@(front-page-artists G_ artist-fragment)
                              ,(front-page-project G_)
                              ,(front-page-closing G_ selected-locale))))

;;; ====== The first screen ======

;; The name of the place, set as the page's title over the collection's own
;; size, and the three things a visitor does from here: search it, read it, add
;; to it.  The figures are the honest answer to "is this worth my time", which
;; is the second question a stranger asks after what the place is, and they sit
;; on the sleeve's bottom edge rather than in a panel of their own -- a panel
;; holding three numbers was a box drawn around nothing.
;;
;; The language control is *not* here.  It is a reader's preference for the
;; whole site, and it stood between the title and the sentence that explains
;; the title: a control nobody came for, in the place every visitor's eye lands.
;; It has moved to the end of the page, where the site's furniture belongs.
(define (front-page-hero G_ counts)
  `((section (@ (class "wm-hero"))
             (div (@ (class "wm-hero-inner"))
                  (h1 (@ (class "wm-hero-title"))
                      ,(project-tagline G_))
                  (p (@ (class "wm-hero-lede"))
                     ,(project-summary G_))
                  ,@(front-page-search G_)
                  (div (@ (class "wm-hero-actions"))
                       ,@(front-page-action (G_ "browse the songs") "/songs" #t)
                       ,@(front-page-action (G_ "add a song") "/songs/new" #f)))
             ,@(if (null? counts) '()
                 (list (front-page-stats G_ counts))))))

;; One of the two doors into the place.  The solid one is the thing most
;; visitors came to do; the quiet one is beside it, the same size and one step
;; back, because "add a song" is a real invitation and not a footnote.  WHICH
;; shell it wears is the sheet's decision; this only says which door it is.
(define* (front-page-action label href primary?)
  `((a (@ (href ,href)
          (class ,(if primary? "wm-button" "wm-button-quiet")))
       ,label)))

;; What the instance holds, as the three ways into it: each figure is a link to
;; the list it counts, so the numbers are the first navigation a visitor can
;; use without reading a menu.
(define (front-page-stats G_ counts)
  `(div (@ (class "wm-stats"))
        ,@(map (lambda (stat)
                 (let ((value (assq-ref counts (car stat))))
                   `(a (@ (class "wm-stat")
                          (href ,(cadr stat)))
                       (div (@ (class "wm-stat-value"))
                            ,(if value (format #f "~a" value) "0"))
                       (div (@ (class "wm-stat-label"))
                            ,(G_ (caddr stat))))))
               '((songs "/songs" "songs")
                 (artists "/artists" "artists")
                 (genres "/genres" "genres")))))

;; The way in for a reader who is not browsing: the list pages' own search
;; control, told where to take the words.  `/songs' is the collection, and the
;; address is the whole of the difference -- a form that names a page is an
;; ordinary GET, so it is submitted the same way by a browser with scripting and
;; by one without.
;; The control is spliced rather than wrapped: a wrapper of its own would be a
;; `div' with nothing in it, and Artanis serializes a childless element as a
;; self-closed tag -- which HTML reads as an opening tag and nests the rest of
;; the page inside.
(define (front-page-search G_)
  (search-box G_ #:search-query "" #:action "/songs" #:centered? #t))

;;; ====== What a reader can do here ======

;; The four promises, on the page a visitor lands on rather than only on the
;; page they would have to go looking for.  They are set as four columns of
;; text under a hairline instead of four frosted panels: a promise is a
;; sentence, and a panel around one sentence is decoration that eats the screen
;; a visitor needs for the collection.
(define front-page-promise-icons
  '(music-notes-simple tag pencil-simple graduation-cap))

(define (front-page-promises G_)
  `((section (@ (class "wm-section"))
             (p (@ (class "wm-section-lede"))
                ,(project-lead-in G_))
             (ul (@ (class "wm-promises"))
                 ,@(map (lambda (promise glyph)
                          `(li (@ (class "wm-promise"))
                               ,(icon #:type glyph)
                               (span ,promise)))
                        (project-promises G_) front-page-promise-icons)))))

;;; ====== The ways into the collection ======

;; The genres the instance has been given, newest first, as chips: the first
;; choice a reader who does not yet know what they are looking for can make,
;; and a strip that moves as the place grows.
(define (front-page-genres G_ genres)
  (if (or (not (list? genres)) (null? genres)) '()
    (list `(section (@ (class "wm-section"))
                    (div (@ (class "wm-section-head"))
                         (h2 (@ (class "wm-section-title"))
                             ,(G_ "browse by genre"))
                         (a (@ (class "wm-section-link")
                               (href "/genres"))
                            ,(G_ "see all the genres")))
                    (ul (@ (class "wm-chips"))
                        ,@(map (lambda (genre)
                                 `(li (a (@ (class "wm-chip")
                                            (href ,(format #f
                                                           "/genres/uuid/~a"
                                                           (assq-ref
                                                            genre
                                                            'identifier))))
                                        ,(assq-ref genre 'display-name))))
                               genres))))))

;; What the instance has been given most recently, in the tiles every list page
;; draws: a tile here is a tile there.  It stands under a heading and a way to
;; the whole collection, because a visitor who has read this far is either
;; interested in the music or not, and both want the same link.
(define (front-page-newest G_ song-fragment)
  `((section (@ (class "wm-section"))
             (div (@ (class "wm-section-head"))
                  (h2 (@ (class "wm-section-title"))
                      ,(G_ "newest songs"))
                  (a (@ (class "wm-section-link")
                        (href "/songs"))
                     ,(G_ "see all the songs")))
             ,song-fragment)))

;; The same shelf one row over: the artists the instance has been given most
;; recently, in the tiles `/artists' draws.  Songs and artists are the two ways
;; into a music collection -- what is played, and who played it.  A caller that
;; hands in nothing gets no section at all, so a page rendered without a
;; database -- by the tests, say -- is still the whole page it was.
(define (front-page-artists G_ artist-fragment)
  (if (or (not artist-fragment) (null? artist-fragment)) '()
    (list `(section (@ (class "wm-section"))
                    (div (@ (class "wm-section-head"))
                         (h2 (@ (class "wm-section-title"))
                             ,(G_ "newest artists"))
                         (a (@ (class "wm-section-link")
                               (href "/artists"))
                            ,(G_ "see all the artists")))
                    ,artist-fragment))))

;;; ====== The project ======

;; The picture the project shows of itself, and the one control on the page that
;; asks a visitor for anything.  Both are kept below the music: a picture of the
;; place is not what a visitor came for, and neither is the ask.
;;
;; The control is the project's own, the one the about page shows as well, and
;; it is the deployment's to turn off (see `(wikimusic config)'): an instance
;; that raises no money shows neither it nor its picture's caption, and the
;; picture stays where it is, because a picture of the place is not an ask.
(define (front-page-project G_)
  `((section (@ (class "wm-section"))
             (div (@ (class "wm-project"))
                  ,@(wikimusic-img)
                  ,@(wikimusic-support G_)))))

;; The picture of the project, as one framed figure rather than as a second
;; panel holding a picture: the frame is the border, and a border around a
;; border is what the old markup was.
(define (wikimusic-img)
  `((figure (@ (class "wm-figure"))
            (img (@ (alt "")
                    (loading lazy)
                    ;; The picture is the deployment's own asset, named where
                    ;; every other address an instance owns is named (see
                    ;; `(wikimusic config)').
                    (src ,(social-image-url)))))))

;; The one link on the front page that asks a reader for something, kept to a
;; line: what the money pays for is the project's own business, and is said on
;; the about page and in the manual, not in front of every visitor.
;;
;; It is exported because the about page offers the same control rather than a
;; second one: one project, one ask, one address to send a reader to -- and that
;; address is the deployment's, not this view's (see `(wikimusic config)').
;;
;; *Whether* there is an ask at all is the deployment's too, and it is read
;; here, in the one control both pages show: an instance that is not raising
;; money answers nothing, and neither page grows an ask of its own to get round
;; it.  A caller splices the answer rather than placing it, because the answer
;; may be nothing at all.
(define (wikimusic-support G_)
  (if (not (donation-shown?)) '()
    `((p (@ (class "wm-support"))
           (a (@ (href ,(donate-url)))
              (span "🩷")
              (span ,(project-support-ask G_))
              (span "🩷"))))))

;;; ====== The way out ======

;; The line both pages end on, and the control a reader changes language with.
;; The invitation is the project's own closing sentence -- "every note tells a
;; story" -- and it belongs at the end of the page that opened with the music.
;;
;; The language control lives here, beside the invitation, because that is what
;; it is: furniture.  A reader who cannot read the page will look for it at the
;; bottom, where a site keeps its settings, and every other reader is not asked
;; to step over it on the way to the songs.
(define (front-page-closing G_ selected-locale)
  `((section (@ (class "wm-closing"))
             (p (@ (class "wm-closing-invitation"))
                ,(project-invitation G_))
             ,(locale-choose-form G_ #:selected-locale selected-locale))))
