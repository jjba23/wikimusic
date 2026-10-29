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
;;; open on.  So the page says what the place is in one line, offers the two
;;; things a reader came to do (read the collection, add to it), tells them what
;;; the place is for, shows them how much is already in it, gives them the
;;; genres to browse and the newest music, and closes with the project's own
;;; invitation.  Everything after the first screen is the collection.
;;;
;;; None of the prose is written here: every sentence the page reads is the
;;; project's, kept in one place and read by the about page as well (see
;;; `(wikimusic prose)'), so the two pages cannot drift into saying the same
;;; thing two ways.  This view's business is the page: what is on it, in what
;;; order, and what a crawler is told about it.

;; The words the front page is found by: what wikimusic is, and the things a
;; reader looks for in it -- the chords, the tabs and the lyrics of the songs it
;; holds, for the instruments it holds them for.  The same sentence is the meta
;; description, the Open Graph description and the description of the `WebSite'
;; node below, so the front page says the same thing wherever it is read from.
(define front-page-description
  "WikiMusic is a free, community-written encyclopaedia of music: songs, artists and genres, with guitar and bass tabs, chords, lyrics, keys, tunings and sheet music, written by musicians for anyone learning to play.")

;; Every section of the page stands in the same column, so the page reads as
;; one document rather than as a pile of panels of different widths.
(define front-page-column-classes
  '(w-full max-w-256
           mx-auto
           flex
           flex-col
           gap-4
           px-4
           py-2))

;; The frame the panels are cut from: the frosted pane the about page uses, so
;; that a visitor who goes on to read about the project is still on the same
;; site.
(define front-page-panel-classes
  '(hg-frost bg-stone-100/75
             dark:bg-onyx-900/75
             rounded-2xl
             shadow-md
             border-2
             border-persia-pink-500/25
             dark:border-persia-pink-900/10))

(define* (welcome-page G_
                       #:key is-logged-in
                       selected-locale
                       song-fragment
                       artist-fragment
                       genres
                       counts)
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
                 #:body `(div (@ (class ,(mk-class '(w-full flex
                                                            flex-col
                                                            items-center
                                                            gap-6
                                                            py-4
                                                            pb-8))))
                              ,(front-page-opening G_ selected-locale)
                              ,(front-page-promises G_)
                              ,@(front-page-holding G_ counts genres)
                              ,(front-page-newest G_ song-fragment)
                              ,@(front-page-artists G_ artist-fragment)
                              ,(front-page-project G_)
                              ,(front-page-closing G_))))

;;; ====== The first screen ======

;; What the place is called and what it is for, in the project's own words: the
;; tagline is the line both pages sign themselves with, and it is set here as
;; the page's heading rather than as a caption -- a visitor who reads nothing
;; else has read what this is.
;;
;; Under it, what is in the place and the three things a visitor can do from
;; here.  The sentence says what the encyclopaedia holds -- the second question
;; a stranger has, after what it is -- then the search field takes the one
;; reader who already knows what they are looking for straight to it, and the
;; two buttons are left for everyone else: the collection, which is what most
;; visitors came for, and the door for the musician who came to write something
;; down.  None of it is instruction: what a reader can do here is spelled out
;; in the list below, and a landing page's buttons are for starting.
(define (front-page-opening G_ selected-locale)
  `((section (@ (class ,(mk-class '(w-full max-w-196
                                           mx-auto
                                           flex
                                           flex-col
                                           items-center
                                           gap-4
                                           px-4
                                           py-6
                                           text-center))))
             (h1 (@ (class ,(mk-class '(font-sans font-bold text-4xl
                                                  sm:text-5xl hg-gradient-text
                                                  hg-leading-display))))
                 ,(project-tagline G_))
             (div (@ (class ,(mk-class '(flex flex-row
                                              flex-wrap
                                              gap-5
                                              px-3
                                              items-center
                                              justify-center
                                              py-2))))
                  ,(locale-choose-form G_
                                       #:selected-locale selected-locale))
             (p (@ (class ,(mk-class '(max-w-prose font-sans text-lg
                                                   font-light text-onyx-500
                                                   dark:text-stone-300))))
                ,(project-summary G_))
             ,(front-page-search G_)
             (div (@ (class ,(mk-class '(flex flex-row
                                              flex-wrap
                                              gap-3
                                              items-center
                                              justify-center
                                              pt-2))))
                  ,@(front-page-action (G_ "browse the songs") "/songs"
                                       '(bg-persia-pink-500/75
                                         hover:bg-persia-pink-500
                                         text-stone-100
                                         border-persia-pink-500/25))
                  ,@(front-page-action (G_ "add a song") "/songs/new"
                                       '(bg-stone-100/75 dark:bg-onyx-900/75
                                         hover:bg-stone-300/75
                                         dark:hover:bg-onyx-700/75
                                         text-onyx-500
                                         dark:text-stone-300
                                         border-stone-500/25
                                         dark:border-onyx-100/25))))))

;; One of the two doors into the place: a link wearing the shape of a button,
;; because a landing page's first two links are an instruction and should look
;; pressable rather than like one more word in a paragraph.
(define* (front-page-action label href classes)
  "Return LABEL as a link to HREF, dressed as a button by CLASSES."
  `((a (@ (href ,href)
          (class ,(mk-class (append '(inline-flex items-center
                                                  no-underline
                                                  rounded-xl
                                                  px-6
                                                  py-3
                                                  font-sans
                                                  font-bold
                                                  text-md
                                                  border-2
                                                  shadow-md
                                                  transition-colors
                                                  duration-200) classes))))
       ,label)))

;; The way in for a reader who is not browsing: the list pages' own search
;; control, told where to take the words.  `/songs' is the collection, and the
;; address is the whole of the difference -- a form that names a page is an
;; ordinary GET, so it is submitted the same way by a browser with scripting and
;; by one without.
(define (front-page-search G_)
  `((div (@ (class ,(mk-class '(w-full max-w-prose))))
         ,@(search-box G_
                       #:search-query ""
                       #:action "/songs"
                       #:centered? #t))))

;;; ====== What a reader can do here ======

;; The four promises, on the page a visitor lands on rather than only on the
;; page they would have to go looking for: what the community is for is the
;; first thing a stranger wants to know, and the list already exists -- the
;; project's own words, in the order they were written, read from the one place
;; that holds them and shown by the about page as well.
;;
;; One promise to a panel, each with the glyph for what it says, so the four can
;; be taken in at a glance instead of read as a paragraph.  The sentence that
;; introduces them is the one the about page introduces them with, colon and
;; all: the list is the same list.
(define front-page-promise-icons
  '(music-notes-simple tag pencil-simple graduation-cap))

(define (front-page-promises G_)
  (let ((promises (project-promises G_)))
    `((section (@ (class ,(mk-class front-page-column-classes)))
               (p (@ (class ,(mk-class '(text-center font-sans text-lg
                                                     font-light text-onyx-500
                                                     dark:text-stone-300))))
                  ,(project-lead-in G_))
               (ul (@ (class ,(mk-class '(list-none p-0
                                                    grid
                                                    grid-cols-1
                                                    sm:grid-cols-2
                                                    lg:grid-cols-4
                                                    gap-4))))
                   ,@(map (lambda (promise glyph)
                            `(li (@ (class ,(mk-class (append
                                                       front-page-panel-classes
                                                       '(flex flex-col gap-2
                                                              p-5)))))
                                 ,(icon #:type glyph
                                        #:icon-css '(text-3xl
                                                     text-persia-pink-500
                                                     dark:text-persia-pink-300))
                                 (span (@ (class ,(mk-class '(font-sans
                                                              text-md
                                                              text-onyx-500
                                                              dark:text-stone-300))))
                                       ,promise))) promises
                          front-page-promise-icons))))))

;;; ====== What the place holds ======

;; How much music is already here, and the ways into it.
;;
;; The count is the honest answer to "is this worth my time" -- three figures,
;; the first thing an encyclopaedia can say about itself -- and the genres are
;; the first choice a reader who does not yet know what they are looking for
;; can make.  Both are the instance's own rows: a count of what it serves, and
;; the genres it has been given, ordered newest first so that the strip moves as
;; the place grows.
(define (front-page-holding G_ counts genres)
  (let* ((songs (assq-ref counts
                          'songs))
         (artists (assq-ref counts
                            'artists))
         (genres-count (assq-ref counts
                                 'genres))
         (counts-section `(section (@ (class ,(mk-class
                                               front-page-column-classes)))
                                   (div (@ (class ,(mk-class (append
                                                              front-page-panel-classes
                                                              '(grid
                                                                grid-cols-3
                                                                gap-4 p-6
                                                                justify-items-center)))))
                                        ,@(stat-card #:value (format #f "~a"
                                                                     songs)
                                                     #:label (G_ "songs"))
                                        ,@(stat-card #:value (format #f "~a"
                                                                     artists)
                                                     #:label (G_ "artists"))
                                        ,@(stat-card #:value (format #f "~a"
                                                              genres-count)
                                                     #:label (G_ "genres")))))
         (genres-section (if (or (not (list? genres))
                                 (null? genres)) #f
                             `(section (@ (class ,(mk-class
                                                   front-page-column-classes)))
                                       (h2 (@ (class ,(mk-class '(text-center
                                                                  font-sans
                                                                  font-bold
                                                                  text-2xl
                                                                  text-onyx-500
                                                                  dark:text-stone-300))))
                                           ,(G_ "browse by genre"))
                                       (ul (@ (class ,(mk-class '(list-none
                                                                  p-0
                                                                  flex
                                                                  flex-row
                                                                  flex-wrap
                                                                  gap-2
                                                                  items-center
                                                                  justify-center))))
                                           ,@(map (lambda (genre)
                                                    `(li ,@(a (assq-ref genre
                                                                        'display-name)
                                                              #:href (format
                                                                             #f
                                                                             "/genres/uuid/~a"
                                                                             (assq-ref
                                                                              genre
                                                                              'identifier))
                                                              #:size '(text-md)
                                                              #:weight '(font-medium)
                                                              #:color '(text-onyx-500
                                                                        dark:text-stone-300)
                                                              #:hover '(hover:text-persia-pink-900
                                                                        dark:hover:text-persia-pink-300)
                                                              #:extra-classes '
                                                              (no-underline
                                                               rounded-full
                                                               px-3
                                                               py-1
                                                               bg-stone-300/75
                                                               dark:bg-onyx-700/75
                                                               hover:bg-persia-pink-500/25
                                                               dark:hover:bg-persia-pink-500/25
                                                               transition-colors
                                                               duration-200))))
                                                  genres))))))
    (if genres-section
        (list counts-section genres-section)
        (list counts-section))))

;;; ====== The newest music ======

;; What the instance has been given most recently, in the tiles every list page
;; draws: a tile here is a tile there, down to the cover, the artists, the
;; comment and version counts, and the song it leads to.  It stands under a
;; heading and a way to the whole collection, because a visitor who has read
;; this far is either interested in the music or not, and both want the same
;; link.
(define (front-page-newest G_ song-fragment)
  `((section (@ (class ,(mk-class front-page-column-classes)))
             (div (@ (class ,(mk-class '(flex flex-row flex-wrap gap-2
                                              items-baseline justify-between))))
                  (h2 (@ (class ,(mk-class '(font-sans font-bold text-2xl
                                                       text-onyx-500
                                                       dark:text-stone-300))))
                      ,(G_ "newest songs"))
                  ,@(a (G_ "see all the songs")
                       #:href "/songs"
                       #:size '(text-md)))
             ,song-fragment)))

;;; ====== The newest artists ======

;; The same shelf one row over: the artists the instance has been given most
;; recently, in the tiles `/artists' draws.  Songs and artists are the two ways
;; into a music collection -- what is played, and who played it -- and a visitor
;; who came to look up a band rather than a song should not have to work out
;; that the front page's only way in is the other one.
;;
;; It is a fragment rather than a part of this view, like the songs above it:
;; what an artist tile is and what it needs to be drawn are the tile's business,
;; and the query that found the rows is the controller's.  A caller that hands
;; in nothing gets no section at all, so a page rendered without a database -- by
;; the tests, say -- is still the whole page it was.
(define (front-page-artists G_ artist-fragment)
  (if (or (not artist-fragment)
          (null? artist-fragment))
      '()
      (list `(section (@ (class ,(mk-class front-page-column-classes)))
                      (div (@ (class ,(mk-class '(flex flex-row flex-wrap
                                                       gap-2 items-baseline
                                                       justify-between))))
                           (h2 (@ (class ,(mk-class '(font-sans font-bold
                                                      text-2xl text-onyx-500
                                                      dark:text-stone-300))))
                               ,(G_ "newest artists"))
                           ,@(a (G_ "see all the artists")
                                #:href "/artists"
                                #:size '(text-md)))
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
  (let ((picture (wikimusic-img))
        (ask (wikimusic-support G_)))
    (if (null? ask) picture
        `((section (@ (class ,(mk-class '(w-full max-w-196
                                                 mx-auto
                                                 flex
                                                 flex-col
                                                 items-center
                                                 gap-4
                                                 px-4
                                                 py-2))))
                   ,@picture
                   (div (@ (class ,(mk-class '(flex flex-col items-center))))
                        ,@ask))))))

;;; ====== The way out ======

;; The line both pages end on, and the control a reader changes language with.
;; The invitation is the project's own closing sentence -- "every note tells a
;; story" -- and it belongs at the end of the page that opened with the music;
;; the language control is furniture, and furniture goes under the line.
(define (front-page-closing G_)
  `((section (@ (class ,(mk-class '(w-full max-w-196
                                           mx-auto
                                           flex
                                           flex-col
                                           items-center
                                           gap-5
                                           px-4
                                           py-4
                                           text-center))))
             (p (@ (class ,(mk-class '(font-sans text-lg font-light
                                                 text-onyx-500
                                                 dark:text-stone-300))))
                ,(project-invitation G_)))))

;; The picture of the project, kept below the music and the lines that name
;; it: a picture of the place is not what a visitor came for.
(define* (wikimusic-img)
  `((div (div (@ (class ,(mk-class '(hg-frost bg-stone-100/75
                                              dark:bg-onyx-900/75
                                              p-4
                                              rounded-xl
                                              shadow-xl
                                              py-4
                                              md:px-8
                                              xl:px-12
                                              px-6
                                              md:px-12
                                              xl:px-20
                                              border-persia-pink-500/25
                                              border-3))))
              (figure (img (@ (class ,(mk-class '(rounded-2xl h-auto max-w-64
                                                              sm:max-w-96)))
                              (loading lazy)
                              ;; The picture is the deployment's own asset,
                              ;; named where every other address an instance
                              ;; owns is named (see `(wikimusic config)').
                              (src ,(social-image-url)))))))))

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
  (if (not (donation-shown?))
      '()
      `((div (@ (class ,(mk-class '(text-center))))
             (a (@ (class ,(mk-class '(font-bold text-china-violet-100
                                       hover:text-persia-pink-900
                                       dark:text-persia-pink-300
                                       dark:hover:text-persia-pink-700
                                       flex
                                       flex-row
                                       no-underline
                                       hover:underline
                                       gap-3)))
                   (href ,(donate-url)))
                (span "🩷")
                ,(project-support-ask G_)
                (span "🩷"))))))
