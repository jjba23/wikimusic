;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; The page that says what this place is.
;;;
;;; The front page is the collection: a visitor lands on the newest songs and
;;; reads about the project only if they ask to.  This is the asking -- who
;;; writes wikimusic, what a reader can do with it, what it is built on, and
;;; what keeps it running -- and it is a page of its own rather than a block on
;;; the front page, so that the music is what a visitor meets first and the
;;; introduction is still somewhere a reader can find it.
;;;
;;; The words are not written here.  Every sentence this page reads is the
;;; project's own, kept in one place and read by the front page as well (see
;;; `(wikimusic prose)'): what a page shows can then change -- a paragraph added
;;; to the account, the order of the promises -- without the other page's copy
;;; of the same sentence staying behind, which is exactly what happened when
;;; this paragraph lived on the front page.  This view's business is the page:
;;; the panel it is read on, the order the sentences are met in, and what a
;;; crawler is told about them.

(define-module (app views about)
  #:use-module (wikimusic config)
  #:use-module (wikimusic html)
  #:use-module (wikimusic prose)
  #:use-module (wikimusic seo)
  #:use-module (app views index)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (hygguile hygguile)
  #:use-module (kracht prelude)
  #:use-module (ice-9 i18n)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun)
  #:export (about-page))

;; What the page is called wherever it is named: in the browser's tab, in a
;; search result, and in the JSON-LD below.  It says who the community is as
;; well as what the page is, because the address `/about' is not something a
;; reader sees in a link they were sent.
(define about-title
  "About WikiMusic: the non-profit music community")

;; The one sentence a search result shows.  It names the community, what it
;; offers and who writes it, so a reader who has never heard of the project
;; knows what they are clicking before they click it.  It is the page's own --
;; the front page is found as the place to read music, and says so in its own
;; description.
(define about-description
  "WikiMusic is a non-profit community for knowledge sharing and musical education, and an open platform for exploring, sharing and learning about music: songs, artists and genres with tabs, chords, lyrics and sheet music, written by musicians for anyone learning to play.")

;; The column the whole page stands in: the frame every other page of the site
;; is drawn inside, so a reader arriving here from the collection is still on
;; the same site.
(define about-page-classes
  '(w-full flex
           flex-col
           items-center
           gap-6
           py-8
           px-2
           sm:px-4))

;; The frosted panel the content is read on, and the list and the rule inside
;; it.  They are named here rather than written into the markup so that the
;; page reads as an outline of itself.
(define about-panel-classes
  '(hg-frost bg-stone-100/75
             dark:bg-onyx-900/75
             rounded-2xl
             sm:rounded-3xl
             shadow-xl
             border-3
             border-persia-pink-500/25
             dark:border-persia-pink-900/10
             max-w-196
             w-full
             flex
             flex-col
             gap-4
             p-6
             sm:p-8
             md:p-12))

(define about-doings-classes
  '(pl-8 list-disc
         flex
         flex-col
         gap-1
         font-sans
         text-lg
         leading-6
         text-onyx-500
         dark:text-stone-300))

;; The rule that separates the account of the place from the ask.
(define about-ask-classes
  '(flex flex-col
         items-center
         gap-3
         pt-4
         border-t-2
         border-persia-pink-500/25))

(define (about-panel G_)
  "Return the panel the page is read on, as SXML.

@var{G_} is the translation procedure to render the wording with.

It is the page's whole content, in the order a reader meets it: what the
project is, what they can do here, what it is built on, and the one control that
asks them for something.  A page about an encyclopaedia that opens with its own
architecture has told a reader nothing they can use, so the account comes first
and the foundation last."
  `(div (@ (class ,(mk-class about-panel-classes)))
        ;; What the place is called, in the words the front page signs itself
        ;; with, so a reader arriving here from the collection recognises where
        ;; they are.
        ,(sub-h3 (project-tagline G_)
                 #:family '(font-sans))

        (p ,(project-account G_))

        (p ,(project-lead-in G_))

        (ul (@ (class ,(mk-class about-doings-classes)))
            ,@(map (lambda (promise)
                     `(li ,promise))
                   (project-promises G_)))

        ;; What the project is built on, one paragraph per sentence, in the
        ;; order the sentences are written in.
        ,@(map (lambda (sentence)
                 `(p ,sentence))
               (project-foundation G_))

        ;; What a reader can do about it, under the rule that separates the
        ;; account of the place from the ask.  The control itself is the front
        ;; page's own, so the two pages cannot drift into asking for the same
        ;; thing two ways.
        ;;
        ;; An instance that asks for nothing says nothing here, rule and note
        ;; as well as control: a line drawn across the page with nothing under
        ;; it, or a paragraph about what donations pay for, is the ask by
        ;; another name (see `(wikimusic config)').
        ,@(if (donation-shown?)
              `((div (@ (class ,(mk-class about-ask-classes)))
                     ,@(wikimusic-support G_)
                     (p ,(project-support-note G_))))
              '())

        (p ,(project-invitation G_))))

(define* (about-page G_
                     #:key is-logged-in)
  "Return the page that introduces the project, as SXML.

@var{G_} is the translation procedure to render the wording with.

The page states the project's own address as its canonical one and is offered
to crawlers: unlike a search result or a list's second page, it is a standing
address whose content is the same for every reader, so there is one page to
index and no reason to hide it."
  (html-template G_
                 #:is-logged-in is-logged-in
                 #:title about-title
                 #:description about-description
                 #:path "/about"
                 #:json-ld (list (page-json-ld #:type "AboutPage"
                                               #:url (absolute-url "/about")
                                               #:name about-title
                                               #:description about-description
                                               ;; What the page is about: the community, and
                                               ;; not the page.  A wiki that works towards
                                               ;; knowledge sharing for musical education is
                                               ;; an NGO, which is the closest type
                                               ;; schema.org has for it.
                                               #:main-entity (append (list (schema-name
                                                                            "NGO")
                                                                           (cons
                                                                            "name"
                                                                            "WikiMusic")
                                                                           (cons
                                                                            "alternateName"
                                                                            "the free music knowledge encyclopaedia"))
                                                                     (if (absolute-url
                                                                          "/")
                                                                         (list
                                                                          (cons
                                                                           "url"
                                                                           (absolute-url
                                                                            "/")))
                                                                         '()))))
                 #:body `((div (@ (class ,(mk-class about-page-classes)))
                               ,(about-panel G_)))))
