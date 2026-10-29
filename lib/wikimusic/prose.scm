;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; What the project says about itself, written once.
;;;
;;; These sentences are read on two pages.  The front page opens on the
;;; collection and closes with the project's name and its invitation; the about
;;; page is the whole account -- what the community is, what a reader can do
;;; here, what it is built on, and the one control that asks for support.  Every
;;; one of them is therefore said on both, or on neither, and the same sentence
;;; written in two views is two sentences that drift: one page gets a new
;;; phrasing, the other keeps the old one, and there is nothing that fails.
;;;
;;; They are procedures of the translator rather than a table of msgids, because
;;; every one of them has to be looked up in the catalog: the text is a *literal*
;;; argument of @code{G_} here, which is the only way the string reaches the
;;; template `xgettext' builds and a translator ever sees it.  A caller hands in
;;; the translator it has -- the request's own, in a page, or the text domain's
;;; own, in a test -- so the sentence comes back in the language the page is
;;; being read in.
;;;
;;; Every string below is the msgid the catalogs already carry, character for
;;; character: rephrasing one here would silently drop it from the three
;;; translated locales, which is the one thing this module must not do.

(define-module (wikimusic prose)
  #:declarative? #t
  #:use-module (ice-9 format)
  #:export (project-tagline project-summary
                            project-account
                            project-lead-in
                            project-promises
                            project-foundation
                            project-support-ask
                            project-support-note
                            project-invitation))

(define (project-tagline G_)
  "Return what the project is called, in one line.

It is the words the site signs itself with, the title a reader meets first on
the about page and last on the front page, so the two pages agree about the
name of the place they are."
  (G_ "the free music knowledge encyclopaedia"))

(define (project-summary G_)
  "Return what the encyclopaedia holds, in one line.

It is the line the front page reads under its tagline: a visitor who has just
read what the place is *called* asks what is *in* it next, and this answers
that with the things they came for rather than with another adjective.  The
page's own description, which is what a search result is shown instead, says
the same thing in the register of a search result -- a sentence that has to
stand alone, so it names the project as well -- and the two are separate
sentences for that reason rather than by oversight."
  (G_
   "Songs, artists and genres, with guitar and bass tabs, chords, lyrics, keys, tunings and sheet music — written by musicians, for anyone learning to play."))

(define (project-account G_)
  "Return what the project is, in one paragraph."
  (G_
   "The WikiMusic project is an non-profit community, with the goal of knowledge sharing and musical education, providing an open platform for exploring, sharing, and learning about music in all its forms."))

(define (project-lead-in G_)
  "Return the sentence the list of promises is read under."
  (G_
   "Whether you're a musician, educator, researcher, or simply a music lover, WikiMusic empowers you to:"))

(define (project-promises G_)
  "Return the four things a reader can do here, in the order they are read.

The order is the order of the prose rather than of importance: what a reader
comes to read, what they can file it with, what they can write, and what they
can learn from it."
  (list (G_ "Discover music from diverse genres and traditions.")
        (G_
         "Organize information with structured metadata and multimedia content.")
        (G_
         "Contribute by adding new compositions, analyses, or educational materials.")
        (G_
         "Learn through curated resources that connect music theory, history, and practice.")))

(define (project-foundation G_)
  "Return what the project is built on, one paragraph per sentence.

Three paragraphs, in the order a reader meets them: the language the interface
is written in, the shape of the data behind it, and what that shape is for."
  (list
   ;; The trailing space in the second one is the catalog's, not a typo: the
   ;; msgid a translator was given ends with it.
   (G_
    "At its core, WikiMusic leverages the expressive power of Lisp to build a dynamic interactive Music Gallery and Content Management System (CMS).")
   (G_
    "WikiMusic leverages a database-backed architecture to ensure all content is easily searchable, linkable, and reusable. ")
   (G_
    "The user interface provides a seamless experience, inviting both beginners and experts to engage with the world of music collaboratively.")))

(define (project-support-ask G_)
  "Return the words on the one control that asks a reader for something.

It is the label beside the donation link, and it is the ask on both pages -- the
front page's control and the about page's are the same control."
  (G_ "donate what you can, by clicking here"))

(define (project-support-note G_)
  "Return what the money pays for, in one sentence."
  (G_
   "This helps us keep the underlying cloud infrastructure and the contributor's work hours going strong."))

(define (project-invitation G_)
  "Return the line both pages end on."
  (G_
   "Join us in building an ever-growing library of musical knowledge — where every note tells a story."))
