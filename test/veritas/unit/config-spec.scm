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
  #:use-module (wikimusic config)
  #:use-module (wikimusic env)
  #:export (spec))

(define (absolute-address? value)
  "Return #t when VALUE is an absolute http or https address."
  (and (string? value)
       (or (string-prefix? "https://" value)
           (string-prefix? "http://" value))
       #t))

(define reader-suite
  (suite "Where the instance reads what it says about itself"
         (test "a variable the deployment did not set falls back"
               (assert-equal #:name "the project's own value is used"
                             #:expect "the project's own value"
                             #:got (config-value 'a-variable-no-deployment-sets
                                                 #:default "the project's own value")))

         (test "a variable the deployment set is the one read"
               ;; `pingwing-url' is required of every deployment -- it is where
               ;; the instance sends its mail -- so it is a variable that is
               ;; there to be found without a test inventing one, and the
               ;; expected value is the deployment's own rather than a copy of
               ;; it written out here.
               (assert-equal #:name "the deployment's own value wins"
                             #:expect pingwing-url
                             #:got (config-value 'pingwing-url
                                                 #:default "the project's own value")))))

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
                            #:name "where a reader supports the project")
               (assert-true (absolute-address? (social-image-url))
                            #:name "the picture a link is previewed with"))

         (test "the copyright line names somebody"
               (assert-true (and (string? (copyright-holder))
                                 (not (string-null? (copyright-holder)))
                                 #t)
                            #:name "the holder is named"))

         (test "the mail an instance sends comes from an address"
               ;; A mail address is not an http address, so it is checked for
               ;; the one thing that makes it one: a local part and a domain
               ;; with an `@' between them, and nothing blank anywhere.
               (assert-true (and (string? (mail-sender-address))
                                 (string-index (mail-sender-address) #\@)
                                 (not (string-null? (mail-sender-address)))
                                 #t)
                            #:name "an address, not a blank")
               (assert-true (and (string? (mail-sender-name))
                                 (not (string-null? (mail-sender-name)))
                                 #t)
                            #:name "and a name beside it"))))

(define derived-suite
  (suite "The manual is read where the code is"
         ;; The manual is the README, and it is read in the repository the
         ;; instance names, so the two addresses are not independent: a fork
         ;; that changes where its code is read gets its own manual link without
         ;; having to say where the README is.  A deployment that names the
         ;; manual itself has the last word, and the rule is stated out loud
         ;; here rather than sampled: what the manual's address is, is what the
         ;; deployment said, or the README beside the code.
         (test "the manual's address is the deployment's, or the README beside its code"
               (assert-equal #:name "the manual follows the code"
                             #:expect (or (config-value 'manual-url)
                                          (format #f "~a/src/branch/trunk/README.org"
                                                  (source-repository-url)))
                             #:got (manual-url)))))

(define (spec)
  (veritas-run reader-suite address-suite derived-suite))
