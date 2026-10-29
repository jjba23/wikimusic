;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; What an instance says about itself.
;;;
;;; Everything here is a fact of the *deployment* rather than of wikimusic: who
;;; the project belongs to, where its source is read, where its manual is, where
;;; a reader is sent to support it, whether it asks for support at all, the
;;; picture a pasted link is previewed with, where the interface's own type and
;;; glyphs are fetched from, and the address its mail comes from.  They were
;;; written into the views that showed them, which meant a fork had to edit a
;;; view to change a link -- and an instance with a mirror, or a different name
;;; on the donation page, or a different host for its static assets, had nowhere
;;; to say so.
;;;
;;; A deployment states them in its own `(wikimusic env)' module, the one file
;;; it writes for itself, beside the secrets it already keeps there.  None is
;;; required: each falls back to what the upstream project uses, so an instance
;;; that says nothing about itself is wikimusic, unchanged.  One is derived
;;; rather than defaulted -- the manual's address is built from the source
;;; repository's, so a fork that moves its code gets its own manual link without
;;; having to say where the README is.

(define-module (wikimusic config)
  #:declarative? #t
  #:use-module (ice-9 format)
  #:use-module (ice-9 string-fun)
  #:use-module (srfi srfi-1)
  #:export (config-value deployment-overrides
                         source-repository-url
                         manual-url
                         licence-url
                         copyright-holder
                         donate-url
                         donation-shown?
                         social-image-url
                         assets-url
                         asset-address
                         mail-sender-name
                         mail-sender-address))

;;; ====== Reading the deployment's own module ======

;; What `deployment-binding' answers when the deployment named nothing: a value
;; no deployment can write down, so that a variable deliberately set to `#f' --
;; which is how a switch is turned off -- is told apart from one that is not
;; there at all.
(define unbound
  (list 'unbound))

;; What a caller has laid over the deployment's own answers for the length of a
;; dynamic extent, as an alist of names to values.  It is empty in an instance,
;; which is what makes the deployment's module the only thing read; a *test*
;; that proves what an instance says with a switch turned off has to be that
;; instance for one assertion, and its suites run their cases concurrently (see
;; `test/support/deployment.scm').  Laying the value over the deployment's rather
;; than writing it into the deployment's own module is what keeps one case's
;; instance from being read by its siblings: a parameter's binding is
;; fiber-local, so what a case laid down is visible exactly as far as the page,
;; control or answer it is building, and no other case in the run sees it.
;;
;; The overlay answers for the deployment, so it is read through the same
;; functions: `config-value' still falls back to the project's own value, and a
;; switch is still read the way a shell would have written it.
(define deployment-overrides
  (make-parameter '()))

(define (deployment-binding name)
  "Return what this deployment bound NAME to, or `unbound' when it bound nothing.

The module is `(wikimusic env)', which the server loads from the deployment's
own `env.scm' before it serves anything.  A module that is not there and a
variable it does not name are the same answer, and it is one a caller can tell
apart from a variable that was set to `#f'.  A name is read as a symbol, never
as a request value: nothing a reader sends chooses what the instance says about
itself.

A name laid over the deployment for the current dynamic extent (see
@code{deployment-overrides}) is answered instead of the module's, innermost
first, so that a caller can say what the deployment it is building for had bound
without editing the deployment's file."
  (let ((overlaid (assq name
                        (deployment-overrides))))
    (if overlaid
        (cdr overlaid)
        (catch #t
               (lambda ()
                 (let* ((module (resolve-module '(wikimusic env)))
                        (variable (module-variable module name)))
                   (if (and variable
                            (variable-bound? variable))
                       (variable-ref variable) unbound)))
               (lambda (key . args)
                 unbound)))))

(define (deployment-value name)
  "Return what this deployment set NAME to as text, or #f.

A value that is blank, or not text at all, answers #f exactly as an unset
variable does, so that a caller falls back to the project's own value: a line an
operator commented out cannot leave the instance with nothing to say."
  (let ((value (deployment-binding name)))
    (and (string? value)
         (let ((trimmed (string-trim-both value)))
           (and (not (string-null? trimmed)) trimmed)))))

(define* (config-value name
                       #:key default)
  "Return this deployment's NAME, or DEFAULT when it sets none.

DEFAULT is what the upstream project uses, so a caller never has to test the
result: what comes back is either what the operator wrote down or the value the
project ships with."
  (or (deployment-value name) default))

(define* (config-switch name
                        #:key (default #t))
  "Return whether this deployment's NAME says yes.

NAME is a switch rather than a value, so what is read is not text: `#f' is a
deployment saying no, `#t' a deployment saying yes, and a word -- `false', `no',
`off', `0', however it is capitalised -- says no as well, because a switch
written in a shell's environment or a `.env' file arrives as text and an
operator should not have to check how it is spelled here.  A name the
deployment does not set answers DEFAULT, and so does one it sets to nothing at
all: a blank is read as the absent line it looks like, which is the reading a
*value* gets as well, so that one rule covers both kinds of variable a
deployment might leave empty."
  (let ((value (deployment-binding name)))
    (cond
      ((eq? value unbound)
       default)
      ((string? value)
       (let ((word (string-trim-both value)))
         (if (string-null? word) default
             (not (any (lambda (no)
                         (string-ci=? no word))
                       '("false" "no" "off" "0"))))))
      (else (and value #t)))))

;;; ====== Where the project is ======

(define (source-repository-url)
  "Return the address a reader browses the source at."
  (config-value 'source-repository-url
                #:default "https://codeberg.org/jjba23/wikimusic"))

(define (manual-url)
  "Return the address the manual is read at.

It is built from the source repository when the deployment does not name one:
the manual is the README, so it is read where the code is, and a fork that
changes only `source-repository-url' is not left pointing readers at somebody
else's README."
  (config-value 'manual-url
                #:default (format #f "~a/src/branch/trunk/README.org"
                                  (source-repository-url))))

(define (licence-url)
  "Return the address the licence text is read at."
  (config-value 'licence-url
                #:default "https://opensource.org/license/mit"))

(define (copyright-holder)
  "Return who the instance's copyright line names."
  (config-value 'copyright-holder
                #:default "Josep Bigorra"))

;;; ====== What a reader can do about it ======

(define (donate-url)
  "Return where a reader is sent to support the instance."
  (config-value 'donate-url
                #:default "https://www.buymeacoffee.com/jjbigorra"))

(define* (donation-shown?)
  "Return whether this instance asks its readers for money at all.

A deployment that raises none -- a mirror, a fork kept for its own use, a
project funded another way -- hides the control rather than pointing it at
somebody else's page:

@example
(define-public show-donation? #f)
@end example

Everything that shows the ask asks this first, the front page and the about page
alike, so `#f' is the whole of it: no control, no label, no note about what the
money pays for.  Shown unless it says otherwise."
  (config-switch 'show-donation?))

;; The picture a page without one of its own is announced with, and the one the
;; front page shows: the same picture, because it is the same subject -- the
;; project seen at the bottom of its own front page and the site previewed in a
;; chat client.  It is a *path* rather than an address because the picture is
;; this project's own asset, now served by the instance itself like the typefaces
;; are, and only a page being answered knows what its host is called: the address
;; a crawler is given is built from this path at the point a page states it (see
;; `(wikimusic seo)').  A deployment that has a picture of its own hands in its
;; address, or a path to serve its own, and either way it wins over this one.
(define (social-image-url)
  "Return the picture a page is previewed and introduced with.

An absolute address, or a path on this instance, which a page turns into one."
  (config-value 'social-image-url
                #:default "/img/wikimusic.jpg"))

;;; ====== Where the interface's own assets are read from ======

;; The type the pages are set in, the glyphs their controls wear and the icon a
;; tab is marked with are files, and the files are this project's own: fetched
;; into `pub/' so that a browser asks this instance for them instead of a font
;; host or an icon CDN (see `maak vendor-assets').  Where they are read from is
;; therefore a fact of the deployment: an instance serving them itself says
;; nothing, and one behind a CDN, or serving them from another path, or pointing
;; at a mirror of its own, names the address they hang off.
(define (assets-url)
  "Return the address the interface's own assets are read from.

Empty by default, which means this instance's copy under `pub/'.  A deployment
that serves them from somewhere else -- a CDN in front of it, another path, a
mirror -- names the address they hang off, without a trailing slash:

@example
(define-public assets-url \"https://assets.example.org/wikimusic\")
@end example"
  (config-value 'assets-url
                #:default ""))

(define (asset-address path)
  "Return PATH as the address a page reads one of the interface's assets at.

PATH is the file's place inside `pub/' (`vendor/fonts/lucida.css',
`css/wikimusic.olive.min.css', say).  It is returned as a path of this instance
when the deployment named no other host, so that a page renders the same on
every instance -- local, mirrored or behind a CDN -- and a deployment that moved
its assets says where they went in one place instead of in every view that names
a file."
  (let ((base (string-trim-right (assets-url) #\/))
        (path (string-trim path #\/)))
    (if (string-null? base)
        (format #f "/~a" path)
        (format #f "~a/~a" base path))))

;;; ====== The mail an instance sends ======

(define (mail-sender-name)
  "Return the name a reader sees on the mail this instance sends."
  (config-value 'mail-sender-name
                #:default "No Reply - Wikimusic"))

(define (mail-sender-address)
  "Return the address this instance's mail comes from."
  (config-value 'mail-sender-address
                #:default "noreply@mail.jointhefreeworld.org"))
