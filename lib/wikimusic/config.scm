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

;;; What an instance says about itself.
;;;
;;; Everything here is a fact of the *deployment* rather than of wikimusic: who
;;; the project belongs to, where its source is read, where its manual is, where
;;; a reader is sent to support it, the picture a pasted link is previewed with,
;;; and the address its mail comes from.  They were written into the views that
;;; showed them, which meant a fork had to edit a view to change a link -- and
;;; an instance with a mirror, or a different name on the donation page, or a
;;; different host for its static assets, had nowhere to say so.
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
  #:export (config-value
            source-repository-url
            manual-url
            licence-url
            copyright-holder
            donate-url
            social-image-url
            mail-sender-name
            mail-sender-address))

;;; ====== Reading the deployment's own module ======

(define (deployment-value name)
  "Return what this deployment set NAME to, or #f.

The module is `(wikimusic env)', which the server loads from the deployment's
own `env.scm' before it serves anything; a module that is not there, a variable
it does not name, and a value that is blank or not text at all all answer #f, so
that a caller can fall back to the project's own value.  A name is read as a
symbol, never as a request value: nothing a reader sends chooses what the
instance says about itself."
  (catch #t
         (lambda ()
           (let ((value (module-ref (resolve-module '(wikimusic env)) name)))
             (and (string? value)
                  (let ((trimmed (string-trim-both value)))
                    (and (not (string-null? trimmed)) trimmed)))))
         (lambda (key . args) #f)))

(define* (config-value name #:key default)
  "Return this deployment's NAME, or DEFAULT when it sets none.

DEFAULT is what the upstream project uses, so a caller never has to test the
result: what comes back is either what the operator wrote down or the value the
project ships with."
  (or (deployment-value name) default))

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
                #:default "https://www.gnu.org/licenses/agpl-3.0.html"))

(define (copyright-holder)
  "Return who the instance's copyright line names."
  (config-value 'copyright-holder #:default "Josep Bigorra"))

;;; ====== What a reader can do about it ======

(define (donate-url)
  "Return where a reader is sent to support the instance."
  (config-value 'donate-url
                #:default "https://www.buymeacoffee.com/jjbigorra"))

;; The picture a page without one of its own is announced with, and the one the
;; front page shows: the project's own asset host, which any instance may point
;; at, and which an instance with its own assets passes instead.  It is the same
;; value for both because it is the same picture -- the site previewed in a chat
;; client and the site shown at the bottom of its own front page.
(define (social-image-url)
  "Return the picture a page is previewed and introduced with."
  (config-value 'social-image-url
                #:default "https://jointhefreeworld.org/static-assets/wikimusic/img/wikimusic.jpg"))

;;; ====== The mail an instance sends ======

(define (mail-sender-name)
  "Return the name a reader sees on the mail this instance sends."
  (config-value 'mail-sender-name #:default "No Reply - Wikimusic"))

(define (mail-sender-address)
  "Return the address this instance's mail comes from."
  (config-value 'mail-sender-address
                #:default "noreply@mail.jointhefreeworld.org"))
