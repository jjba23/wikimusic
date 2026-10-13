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

(define-module (app views error)
  #:use-module (wikimusic html)
  #:use-module (hygguile hygguile)
  #:use-module (ice-9 format)
  #:use-module (ice-9 i18n)
  #:use-module ((artanis artanis) #:select (http-status))
  #:use-module ((artanis utils) #:select (sxml->xml-string))
  #:export (error-page error-page-html install-error-pages!
                       error-headline error-detail))

;;; What a reader is told when a page cannot be served.
;;;
;;; Artanis renders these pages itself, from outside any route: a request
;;; that matches no route never reaches a controller, and a handler that
;;; throws is already unwinding.  There is no route context to ask, so
;;; nothing here may depend on one -- no `rc', no `(:i18n rc)', no session
;;; cookie.  The page is therefore built from the parts of the shell that
;;; need no context either: the same document template, the same washes
;;; and the same frosted pane, with the translation taken from the text
;;; domain the server binds at start-up.
;;;
;;; The wording of a page is decided by its status alone, so that decision
;;; is a function of the status and nothing else: it can be read, and
;;; tested, without a server in front of it.

(define (error-headline status)
  "Return the one-line headline the page for STATUS leads with, in English.

@var{status} is an HTTP status code as a number.  A status with no
wording of its own is described by its class -- the page still says what
happened, even when nothing named that code."
  (cond
   ((= status 404)
    "we could not find that page")
   ((= status 500)
    "something went wrong on our side")
   ((= status 403)
    "you are not allowed to see that")
   ((= status 401)
    "you need to sign in first")
   ((= status 400)
    "that request did not make sense")
   (else
    (format #f "the server answered ~a" status))))

(define (error-detail status)
  "Return the paragraph the page for STATUS explains itself with.

The detail says what the reader can do next rather than what the server
did wrong: a reader cannot act on the second and can act on the first."
  (cond
   ((= status 404)
    "the address may have been mistyped, or the entry may have been moved
or renamed since it was linked.  the pages below are a good place to pick
the thread back up.")
   ((= status 500)
    "the server failed while building this page.  nothing was written, and
nothing you did caused it.  trying again in a moment usually works; if it
keeps failing, the source code is linked below and a report is welcome.")
   ((= status 403)
    "this entry exists, but it is not public and your account may not read
it.")
   ((= status 401)
    "signing in gives you access to this page.")
   ((= status 400)
    "the request arrived in a shape the server does not understand.  going
back and submitting the form again is the way to retry.")
   (else
    "the server could not serve this request.  the pages below are still
there.")))

(define (error-links G_)
  "Return the row of links a reader can leave an error page by."
  `((div (@ (class ,(mk-class '(flex flex-row flex-wrap
                                         gap-4 items-center justify-center
                                         py-2))))
         ,(a (G_ "the front page")
             #:href "/"
             #:size '(text-md))
         ,(a (G_ "songs") #:href "/songs" #:size '(text-md))
         ,(a (G_ "artists") #:href "/artists" #:size '(text-md))
         ,(a (G_ "genres") #:href "/genres" #:size '(text-md))
         ,(a "source code"
             #:href "https://codeberg.org/jjba23/wikimusic"
             #:size '(text-md)))))

(define* (error-page status #:key (G_ gettext) (is-logged-in #f))
  "Return the SXML of the page shown for HTTP @var{status}.

@var{G_} is the translation procedure to render the wording with.  It
defaults to the text domain's own @code{gettext}, which is what a page
rendered outside a route has, and a caller that has a locale in hand --
or a test that has none -- can pass its own.

@var{is-logged-in} only decides whether the navigation offers to sign in
or to leave; a reader who is signed in and lands here should not be
invited to sign in again."
  (html-template G_
                 #:title (format #f "~a · WikiMusic" status)
                 #:is-logged-in is-logged-in
                 #:body `((div (@ (class ,(mk-class
                                           '(w-full flex flex-col
                                                   items-center
                                                   justify-center
                                                   gap-6 py-8
                                                   px-2 sm:px-4))))
                               (div (@ (class ,(mk-class
                                                '(hg-frost
                                                  bg-stone-100/75
                                                  dark:bg-onyx-900/75
                                                  rounded-2xl
                                                  sm:rounded-3xl
                                                  shadow-xl
                                                  border-3
                                                  border-persia-pink-500/25
                                                  dark:border-persia-pink-900/10
                                                  max-w-196
                                                  w-full
                                                  flex flex-col
                                                  items-center
                                                  text-center
                                                  gap-4
                                                  p-6 sm:p-8 md:p-12))))
                                    (span (@ (class ,(mk-class
                                                      '(text-4xl
                                                        sm:text-5xl
                                                        font-bold
                                                        text-persia-pink-500/90
                                                        dark:text-persia-pink-300))))
                                          ,(format #f "~a" status))
                                    ,(sub-h3 (G_ (error-headline status))
                                             #:family '(font-sans))
                                    (p (@ (class ,(mk-class
                                                   '(text-onyx-300
                                                     dark:text-stone-300
                                                     leading-6
                                                     max-w-96))))
                                       ,(G_ (error-detail status)))
                                    ,(error-links G_))))))

(define (error-page-html status)
  "Return the page for @var{status} as the string artanis renders it with.

The string is built by artanis's own serializer rather than SXML's: a
page carries inline script, and SXML's serializer escapes a script's text
node (`&&' into `&amp;&amp;'), which no browser decodes inside a script
element.  Artanis's serializer is the one every other page of the site is
served through, so an error page is serialized exactly like a page that
worked."
  (sxml->xml-string (error-page status)))

(define *error-statuses*
  '(400 401 403 404 500))

(define (install-error-pages!)
  "Register the pretty error page for every status wikimusic can answer with.

Artanis looks up a status in `*sys-page-handlers*' before it falls back to
its own plain page, so registering here is what replaces that page.  The
call belongs in ENTRY, in the section artanis reserves for work that has to
happen before the server serves a request."
  (for-each (lambda (status)
              (http-status status (lambda () (error-page-html status))))
            *error-statuses*))
