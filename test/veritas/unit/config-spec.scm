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

;;; Commentary:
;;;
;;; What an instance says about itself, and where it comes from.
;;;
;;; The point of the configuration module is that a deployment can name these
;;; things and an instance that names none of them is still wikimusic, so what
;;; is pinned here is exactly those two halves: a variable the deployment set is
;;; the one the instance reads, and one it did not set falls back to the value
;;; the project ships.  Both halves are read through a variable the deployment
;;; is already required to set -- the mail host, which `env.scm' carries for
;;; every instance -- so no test has to write into the deployment's own module
;;; to prove what a value in it would do.
;;;
;;; The rest is read the other way round.  A switch is not a value but a rule
;;; with two halves -- the ask is shown *unless* the deployment turns it off --
;;; and the interface's own files are read from this instance *unless* it names
;;; a host -- and only one half of each is the deployment a suite is running
;;; under.  The other is therefore written into the loaded `(wikimusic env)'
;;; module for the length of one case and put back afterwards (see `(support
;;; deployment)'), which is why a case reads a deployment the suite is running
;;; on and the one it made up beside it, in the same test.  Nothing here is
;;; pinned to what *this* deployment happens to say: the value read back is
;;; compared against the rule, not against the project's own address, so a fork
;;; that has correctly named its own host or turned its own ask off still passes.
;;;
;;; The addresses are then checked for the only thing that can be checked
;;; without an opinion about where they lead: that each is an absolute address
;;; rather than an empty string, a path, or a mistake.  Which host a deployment
;;; names is its own business.
;;;
;;; Every assertion is a sibling of its test's other cases: an assertion is a
;;; procedure the test invokes, so one written inside a `let' or a `for-each' is
;;; built, passed along as that form's value, and never runs.
;;;
;;; What is *not* pinned here, because nothing in the tree can: a variable the
;;; deployment sets to a blank string.  The reader treats a blank value as unset
;;; -- the reading an operator who commented a line out expects -- but proving it
;;; would mean a test writing into `env.scm', and a test that edits the
;;; deployment's own module is one that fails on the next run for reasons of its
;;; own making.

(define-module (veritas unit config-spec)
  #:use-module (veritas veritas)
  #:use-module (ice-9 format)
  #:use-module (srfi srfi-13)
  #:use-module (support deployment)
  #:use-module (wikimusic config)
  #:use-module (wikimusic env)
  #:use-module (wikimusic seo)
  #:export (spec))

(define (absolute-address? value)
  "Return #t when VALUE is an absolute http or https address."
  (and (string? value)
       (or (string-prefix? "https://" value)
           (string-prefix? "http://" value)) #t))

(define reader-suite
  (suite "Where the instance reads what it says about itself"
         (test "a variable the deployment did not set falls back"
               (assert-equal #:name "the project's own value is used"
                             #:expect "the project's own value"
                             #:got (config-value 'a-variable-no-deployment-sets
                                                 #:default
                                                 "the project's own value")))

         (test "a variable the deployment set is the one read"
               ;; `pingwing-url' is required of every deployment -- it is where
               ;; the instance sends its mail -- so it is a variable that is
               ;; there to be found without a test inventing one, and the
               ;; expected value is the deployment's own rather than a copy of
               ;; it written out here.
               (assert-equal #:name "the deployment's own value wins"
                             #:expect pingwing-url
                             #:got (config-value 'pingwing-url
                                                 #:default
                                                 "the project's own value")))))

(define address-suite
  (suite "The addresses the instance offers"
         (test "each one is an absolute address"
               (assert-true (absolute-address? (source-repository-url))
                            #:name "where the source is read")
               (assert-true (absolute-address? (manual-url))
                            #:name "where the manual is read")
               (assert-true (absolute-address? (licence-url))
                            #:name "where the licence is written out")
               (assert-true (absolute-address? (donate-url))
                            #:name "where a reader supports the project"))

         (test "the copyright line names somebody"
               (assert-true (and (string? (copyright-holder))
                                 (not (string-null? (copyright-holder))) #t)
                            #:name "the holder is named"))

         (test "the mail an instance sends comes from an address"
               ;; A mail address is not an http address, so it is checked for
               ;; the one thing that makes it one: a local part and a domain
               ;; with an `@' between them, and nothing blank anywhere.
               (assert-true (and (string? (mail-sender-address))
                                 (string-index (mail-sender-address) #\@)
                                 (not (string-null? (mail-sender-address))) #t)
                            #:name "an address, not a blank")
               (assert-true (and (string? (mail-sender-name))
                                 (not (string-null? (mail-sender-name))) #t)
                            #:name "and a name beside it"))))

;; The picture a page is announced with is the one thing an instance names that
;; is not necessarily an address: the project's own picture is a file this
;; instance serves, so what the configuration holds is a path on it, and the
;; address a crawler is handed is built where the page is built -- from the host
;; that page is being answered on.  Two things are pinned: a path is joined onto
;; an origin rather than left as one, and an address the deployment gave is
;; passed through as it is.  Both are read with a picture the test names, so a
;; fork that has a picture of its own is not asked to have this one.
(define picture-suite
  (suite "The picture a page is announced with"
         (test "a path is turned into an address of the instance serving it"
               (assert-equal #:name "the path is joined onto the origin"
                             #:expect "https://example.org/img/cover.jpg"
                             #:got (with-deployment 'social-image-url
                                                    "/img/cover.jpg"
                                                    (lambda ()
                                                      (absolute-url (social-image-url)
                                                       #:origin
                                                       "https://example.org")))))

         (test "an address the deployment gave is left alone"
               (assert-equal #:name "an address is already one"
                             #:expect "https://pictures.example.org/cover.jpg"
                             #:got (with-deployment 'social-image-url
                                    "https://pictures.example.org/cover.jpg"
                                    (lambda ()
                                      (absolute-url (social-image-url)
                                                    #:origin
                                                    "https://example.org")))))

         (test "and with no host to build one on, no address is invented"
               ;; An origin is what an address is built from, and there are
               ;; requests -- and whole runs -- where an instance has none to
               ;; name: the answer is then nothing at all, and the page states
               ;; the path it has.  That fallback is the whole reason the
               ;; configuration may hold a path, so what it rests on is pinned:
               ;; no origin, no address, rather than an address guessed at from
               ;; whatever the machine happens to be called.
               (assert-false (with-deployment 'social-image-url
                                              "/img/cover.jpg"
                                              (lambda ()
                                                (absolute-url (social-image-url)
                                                              #:origin "")))
                             #:name "no origin, no address"))))

;; The switch an instance that raises no money turns off.  It is not read as a
;; value: it is *on* unless the deployment says otherwise, and a deployment
;; says otherwise in whatever way its own file or a shell hands it over --
;; `#f', or the word every environment file in the world spells "no" with.
(define switch-suite
  (suite "The control an instance turns off"
         (test "an instance that says nothing about it asks"
               ;; The project does fundraise, so an instance that has not
               ;; thought about it keeps the control.  A blank value is the
               ;; reading an operator who commented the line out gets, which is
               ;; this half of the rule however the deployment's file is
               ;; written today.
               (assert-true (with-deployment 'show-donation? ""
                                             donation-shown?)
                            #:name "the ask is shown unless it says otherwise"))

         (test "an instance that raises nothing says so with #f"
               (assert-false (with-deployment 'show-donation? #f
                                              donation-shown?)
                             #:name "the switch itself"))

         (test "and may say so in words"
               ;; A switch written in a shell's environment or a `.env' file
               ;; arrives as text, and an operator should not have to check how
               ;; this particular instance spells it.
               (assert-false (with-deployment 'show-donation? "false"
                                              donation-shown?)
                             #:name "false")
               (assert-false (with-deployment 'show-donation? "No"
                                              donation-shown?)
                             #:name "No, however it is capitalised")
               (assert-false (with-deployment 'show-donation? " off "
                                              donation-shown?)
                             #:name "off, with room around it")
               (assert-false (with-deployment 'show-donation? "0"
                                              donation-shown?)
                             #:name "0"))

         (test "and words that are not a no leave it on"
               (assert-true (with-deployment 'show-donation? "yes"
                                             donation-shown?)
                            #:name "yes")
               (assert-true (with-deployment 'show-donation? #t
                                             donation-shown?)
                            #:name "or the switch itself"))))

;; Where the interface's own files are read from: the stylesheets a page is set
;; and painted with, and the icon its tab is marked with.  They are this
;; project's files, served by the instance that read them, so a deployment that
;; names nothing answers a path on itself -- and one behind a CDN, or serving
;; them from another path, or pointing at a mirror of its own, says where they
;; hang off once and every one of them moves with it.
(define asset-suite
  (suite "Where the interface's own files are read from"
         (test "an instance serving its own reads them off itself"
               (assert-equal #:name "a path on this instance"
                             #:expect "/vendor/fonts/lucida.css"
                             #:got (with-deployment 'assets-url ""
                                                    (lambda ()
                                                      (asset-address
                                                       "vendor/fonts/lucida.css"))))
               (assert-equal #:name "and the page's own stylesheet with it"
                             #:expect "/css/wikimusic.olive.min.css"
                             #:got (with-deployment 'assets-url ""
                                                    (lambda ()
                                                      (asset-address
                                                       "css/wikimusic.olive.min.css")))))

         (test "a deployment that serves them elsewhere says where"
               (assert-equal #:name "every file hangs off the host it named"
                #:expect
                "https://assets.example.org/wikimusic/vendor/fonts/lucida.css"
                #:got (with-deployment 'assets-url
                                       "https://assets.example.org/wikimusic"
                                       (lambda ()
                                         (asset-address
                                          "vendor/fonts/lucida.css")))))

         (test "a host written with a trailing slash does not double it"
               (assert-equal #:name "one slash between the two"
                #:expect "https://assets.example.org/wikimusic/favicon.ico"
                #:got (with-deployment 'assets-url
                       "https://assets.example.org/wikimusic/"
                       (lambda ()
                         (asset-address "favicon.ico")))))

         (test "a file named with a leading slash is one file"
               ;; A caller writes the path it has, and the two spellings of
               ;; `pub/css/wikimusic.olive.min.css' are the same file.
               (assert-equal #:name "the leading slash is not doubled"
                             #:expect "/css/wikimusic.olive.min.css"
                             #:got (with-deployment 'assets-url ""
                                                    (lambda ()
                                                      (asset-address
                                                       "/css/wikimusic.olive.min.css")))))))

(define derived-suite
  (suite "The manual is read where the code is"
         ;; The manual is the README, and it is read in the repository the
         ;; instance names, so the two addresses are not independent: a fork
         ;; that changes where its code is read gets its own manual link without
         ;; having to say where the README is.  A deployment that names the
         ;; manual itself has the last word, and the rule is stated out loud
         ;; here rather than sampled: what the manual's address is, is what the
         ;; deployment said, or the README beside the code.
         (test
          "the manual's address is the deployment's, or the README beside its code"
          (assert-equal #:name "the manual follows the code"
                        #:expect (or (config-value 'manual-url)
                                     (format #f
                                             "~a/src/branch/trunk/README.org"
                                             (source-repository-url)))
                        #:got (manual-url)))))

(define (spec)
  (veritas-run reader-suite
               address-suite
               picture-suite
               switch-suite
               asset-suite
               derived-suite))
