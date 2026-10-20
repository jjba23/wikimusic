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
  #:use-module ((artanis artanis)
                #:select (http-status))
  #:use-module ((artanis utils)
                #:select (sxml->xml-string))
  #:use-module (wikimusic config)
  #:export (error-page error-page-html
                       install-error-pages!
                       error-headline
                       error-detail
                       error-note
                       error-statuses))

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
;;;
;;; Each refusal is written down here the way it is met: a glyph to catch
;;; the eye, the tone it is drawn in, a headline that says what happened in
;;; the reader's own terms, and the sentence or two that says what to do
;;; about it.  A status is a code a client understands and a reader is not a
;;; client, so the code on its own is not enough to serve anyone.
;;;
;;; The tones are the accents the rest of the site is already built from,
;;; used for what they mean there: plain ink for a wrong turn, the pink of
;;; the site's own voice for a door that is shut, and the red the framework
;;; already marks an error with for a failure on the server's side.
(define error-notes
  '((400 plugs
     (text-onyx-300 dark:text-stone-300) "that request did not make sense"
     "the request arrived in a shape the server does not understand.  going
back and submitting the form again is the way to retry.")
    (401 lock-key
     (text-persia-pink-500/90 dark:text-persia-pink-300)
     "you need to sign in first" "signing in gives you access to this page.")
    (403 shield-slash
     (text-persia-pink-500/90 dark:text-persia-pink-300)
     "you are not allowed to see that"
     "this entry exists, but it is not public and your account may not read
it.")
    (404 magnifying-glass
     (text-onyx-300 dark:text-stone-300) "we could not find that page"
     "the address may have been mistyped, or the entry may have been moved
or renamed since it was linked.  the pages below are a good place to pick
the thread back up.")
    ;; A request kept so long that the server gave up on it is a refusal
    ;; artanis raises itself, and the page it answers with is empty: a
    ;; reader who waited gets nothing at all unless there is a page here.
    (408 arrow-clockwise
     (text-onyx-300 dark:text-stone-300)
     "that request took too long to arrive"
     "the request was still on its way when the server stopped waiting for
it, so it was left unread and nothing was changed.  sending it again
usually settles it.")
    (500 warning
     (text-redwood-700 dark:text-redwood-300)
     "something went wrong on our side"
     "the server failed while building this page.  nothing was written, and
nothing you did caused it.  trying again in a moment usually works; if it
keeps failing, the source code is linked below and a report is welcome.")))

(define (error-note status)
  "Return the @code{(glyph tone headline detail)} STATUS is read with.

The table is not a list of the statuses artanis can answer with -- it is the
list of refusals that mean something particular to a reader.  A status
without a line of its own is still rendered as a page rather than as a blank
one: it is described by its class when it has one, and as a server failure
when it has not, because that is what a page rendered for it would mean."
  (let ((row (assv status error-notes)))
    (cond
      (row (cdr row))
      ((and (>= status 400)
            (< status 500))
       (cdr (assv 400 error-notes)))
      (else (cdr (assv 500 error-notes))))))

(define (error-headline status)
  "Return the one-line headline the page for STATUS leads with, in English.

@var{status} is an HTTP status code as a number.  A status with no
wording of its own is described by its class -- the page still says what
happened, even when nothing named that code."
  (let ((row (assv status error-notes)))
    (if row
        (caddr (cdr row))
        (format #f "the server answered ~a" status))))

(define (error-detail status)
  "Return the paragraph the page for STATUS explains itself with.

The detail says what the reader can do next rather than what the server
did wrong: a reader cannot act on the second and can act on the first."
  (let ((row (assv status error-notes)))
    (if row
        (cadddr (cdr row))
        "the server could not serve this request.  the pages below are still
there.")))

;; The statuses the deployment answers with a page of its own.  The five are
;; the ones a reader arrives at through no fault of the site's own views: a
;; `400' is a request artanis could not read, a `401' a rule asking for a
;; credential the request did not carry, a `403' an entry the reader's account
;; may not read, a `404' a path no route answers, a `408' a request that
;; arrived too slowly, and a `500' a handler that threw.  A refusal written by
;; a proxy in front of the site -- a 502 while the service restarts, say --
;; never reaches this process, so its page is the proxy's to write.
(define error-statuses
  '(400 401 403 404 408 500))

(define (error-links G_)
  "Return the row of links a reader can leave an error page by.

Each one is painted with the interface's own ink (see `link-ink' in
`(wikimusic html)'), so a reader who lands here on the dark theme gets the link
colours every other page uses instead of the browser's own blue."
  `((div (@ (class ,(mk-class '(flex flex-row
                                     flex-wrap
                                     gap-4
                                     items-center
                                     justify-center
                                     py-2))))
         ,(a (G_ "the front page")
             #:href "/"
             #:size '(text-md)
             #:color link-ink
             #:hover link-hover-ink)
         ,(a (G_ "songs")
             #:href "/songs"
             #:size '(text-md)
             #:color link-ink
             #:hover link-hover-ink)
         ,(a (G_ "artists")
             #:href "/artists"
             #:size '(text-md)
             #:color link-ink
             #:hover link-hover-ink)
         ,(a (G_ "genres")
             #:href "/genres"
             #:size '(text-md)
             #:color link-ink
             #:hover link-hover-ink)
         ;; The one link on an error page that leaves the instance: where the
         ;; code that produced this refusal is read, which is the deployment's
         ;; own address to name (see `(wikimusic config)').
         ,(a "source code"
             #:href (source-repository-url)
             #:size '(text-md)
             #:color link-ink
             #:hover link-hover-ink))))

(define* (error-page status
                     #:key (G_ gettext)
                     (is-logged-in #f))
  "Return the SXML of the page shown for HTTP @var{status}.

@var{G_} is the translation procedure to render the wording with.  It
defaults to the text domain's own @code{gettext}, which is what a page
rendered outside a route has, and a caller that has a locale in hand --
or a test that has none -- can pass its own.

@var{is-logged-in} only decides whether the navigation offers to sign in
or to leave; a reader who is signed in and lands here should not be
invited to sign in again."
  (let* ((note (error-note status))
         (glyph (car note))
         (tone (cadr note))
         ;; A status the table does not spell out is described by its class,
         ;; and there is no glyph drawn for the status itself -- the glyph of
         ;; the class it reads as is what the page shows, over the code it
         ;; actually answered with.
         (drawing (car (error-note (if (assv status error-notes) status
                                       (if (< status 500) 400 500))))))
    (html-template G_
                   #:title (format #f "~a · WikiMusic" status)
                   ;; A refusal is nothing to index and nothing to preview; the
                   ;; links back to what is still there are followed so that a
                   ;; stale address still leads a crawler somewhere real.
                   #:robots "noindex, follow"
                   #:is-logged-in is-logged-in
                   #:body `((div (@ (class ,(mk-class '(w-full flex
                                                               flex-col
                                                               items-center
                                                               justify-center
                                                               gap-6
                                                               py-8
                                                               px-2
                                                               sm:px-4))))
                                 (div (@ (class ,(mk-class '(hg-frost
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
                                                             flex
                                                             flex-col
                                                             items-center
                                                             text-center
                                                             gap-4
                                                             p-6
                                                             sm:p-8
                                                             md:p-12))))
                                      ;; The code is shown beside a glyph of the
                                      ;; same tone, so which kind of refusal a
                                      ;; reader is reading is legible before a
                                      ;; word of it is read.  The two are one
                                      ;; line that wraps rather than two
                                      ;; columns, which is what the pane can
                                      ;; still hold on a phone.
                                      (div (@ (class ,(mk-class '(flex
                                                                  flex-row
                                                                  flex-wrap
                                                                  items-center
                                                                  justify-center
                                                                  gap-3))))
                                           ,(icon #:type drawing
                                                  #:weight 'bold
                                                  #:icon-css (append tone
                                                                     '(text-4xl
                                                                       sm:text-5xl)))
                                           (span (@ (class ,(mk-class (append '
                                                                       (font-bold
                                                                        text-4xl
                                                                        sm:text-5xl)
                                                                       tone))))
                                                 ,(format #f "~a" status)))
                                      ,(sub-h3 (G_ (error-headline status))
                                               #:family '(font-sans))
                                      (p (@ (class ,(mk-class '(text-onyx-300
                                                                dark:text-stone-300
                                                                leading-6
                                                                max-w-96))))
                                         ,(G_ (error-detail status)))
                                      ,(error-links G_)))))))

(define (error-page-html status)
  "Return the page for @var{status} as the string artanis renders it with.

The string is built by artanis's own serializer rather than SXML's: a
page carries inline script, and SXML's serializer escapes a script's text
node (`&&' into `&amp;&amp;'), which no browser decodes inside a script
element.  Artanis's serializer is the one every other page of the site is
served through, so an error page is serialized exactly like a page that
worked."
  (sxml->xml-string (error-page status)))

(define (install-error-pages!)
  "Register the pretty error page for every status wikimusic can answer with.

Artanis looks up a status in `*sys-page-handlers*' before it falls back to
its own plain page, so registering here is what replaces that page.  The
call belongs in ENTRY, in the section artanis reserves for work that has to
happen before the server serves a request."
  (for-each (lambda (status)
              (http-status status
                           (lambda ()
                             (error-page-html status)))) error-statuses))
