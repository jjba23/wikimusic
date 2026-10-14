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

;;; The words the front page is found by: what wikimusic is, and the things a
;;; reader looks for in it -- the chords, the tabs and the lyrics of the songs
;;; it holds, for the instruments it holds them for.  The same sentence is the
;;; meta description, the Open Graph description and the description of the
;;; `WebSite' node below, so the front page says the same thing wherever it is
;;; read from.
;;
;;; The page itself is not read through this sentence: what a visitor sees
;;; first is the collection -- the newest songs, in the same tiles every list
;;; page draws -- and then two lines, because a page whose subject is music
;;; should open with music rather than with an account of what the site is.
;;; Everything the front page used to explain is in the manual, where a reader
;;; who wants it can read it at length.
(define front-page-description
  "WikiMusic is a free, community-written encyclopaedia of music: songs, artists and genres, with guitar and bass tabs, chords, lyrics, keys, tunings and sheet music, written by musicians for anyone learning to play.")

(define* (welcome-page G_
                       #:key is-logged-in selected-locale song-fragment)
  (html-template G_
                 #:is-logged-in is-logged-in
                 #:title "WikiMusic: guitar tabs, chords and lyrics for every song"
                 #:description front-page-description
                 #:path "/"
                 #:json-ld (list (append (list (schema-name "WebSite")
                                               (cons "name" "WikiMusic")
                                               (cons "alternateName"
                                                     "the free music knowledge encyclopaedia")
                                               (cons "description"
                                                     front-page-description))
                                         (if (absolute-url "/")
                                             (list (cons "url" (absolute-url "/")))
                                             '())))
                 #:body `(div (@ (class ,(mk-class '(p-2 pb-8
                                                            flex
                                                            flex-col
                                                            gap-6))))

                              ;; The two lines that remain: what the place is
                              ;; called, and what it is for.  Both are already
                              ;; said elsewhere on the page, so they are said
                              ;; once each and not expanded into a pitch.  The
                              ;; words are the project's, read from the one
                              ;; module that holds them (see `(wikimusic
                              ;; prose)'), so the about page -- where the rest
                              ;; of them are read -- cannot say something else.
                              (div (@ (class ,(mk-class '(mx-auto
                                                          max-w-196
                                                          px-6
                                                          md:px-12
                                                          py-2
                                                          text-center
                                                          font-sans
                                                          flex
                                                          flex-col
                                                          gap-2))))
                                   ,(sub-h3 (project-tagline G_)
                                            #:family '(font-sans))
                                   (p ,(project-invitation G_)))

                              ;; What is left of the furniture: the control a
                              ;; reader changes language with, and the one link
                              ;; that asks for anything.
                              (div (@ (class ,(mk-class '(flex
                                                          flex-row
                                                          flex-wrap
                                                          gap-5
                                                          px-3
                                                          items-center
                                                          justify-center
                                                          py-2))))
                                   ,(locale-choose-form G_
                                                        #:selected-locale
                                                        selected-locale)
                                   ,(wikimusic-support G_))

                              ,(wikimusic-img)
                              ;; What the instance holds, before anything said
                              ;; about it.  The grid is the list page's own, so
                              ;; a tile here is a tile there, down to the cover,
                              ;; the artists, the comment and version counts, and
                              ;; the song it leads to.
                              ,song-fragment)))

;; The picture of the project, kept below the music and the lines that name
;; it: a picture of the place is not what a visitor came for.
(define* (wikimusic-img)
  `((div (div (@ (class ,(mk-class '(hg-frost bg-stone-100/75 dark:bg-onyx-900/75
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
(define (wikimusic-support G_)
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
            (span "🩷")))))
