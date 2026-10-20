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
;;; What a spec does when the thing it is proving is a *deployment*.
;;;
;;; Some of what an instance says about itself is not a value but a rule: the
;;; control that asks a reader for money is shown unless the deployment turns it
;;; off, and the interface's own files are read from this instance unless the
;;; deployment names a host they hang off instead.  A rule has two halves, and
;;; only one of them is the deployment the suite is running under -- so a spec
;;; has to *be* the other instance for the length of an assertion.
;;;
;;; Being that instance is a value laid over the deployment's own for the length
;;; of the call, rather than a binding written into the deployment's module (see
;;; `deployment-overrides' in `(wikimusic config)').  That is what keeps a case
;;; to itself: a veritas suite runs its cases concurrently, and a case that wrote
;;; its switch into the module every case reads would be turning it off for the
;;; cases beside it -- an assertion that asks for something failing while its
;;; sibling asserts that nothing is asked for.  A parameter's binding is
;;; fiber-local, so the instance a case lays down reaches as far as the page,
;;; control or answer that case is building, and no further.
;;;
;;; The deployment's own `env.scm' is never read for it and never written: what
;;; changes is one binding in the running process, for one call, and only while
;;; that call is being made.  It is put back when the call returns, whether it
;;; returned or raised, so a case that fails cannot leave the deployment turned
;;; off for the cases that follow it.
;;;
;;; It is a module of its own, and not under `test/veritas/unit/', because it is
;;; not a spec: the runner discovers every Scheme file under the unit directory
;;; and calls an entrypoint named `spec' in each, and a file that holds only a
;;; helper has none to call.  `maak test' puts `./test' on the load path, so a
;;; spec imports it as `(support deployment)'.

(define-module (support deployment)
  #:use-module ((wikimusic config)
                #:select (deployment-overrides))
  #:export (with-deployment))

(define* (with-deployment name value thunk)
  "Answer what THUNK answers, with NAME read as VALUE instead of the deployment.

NAME is a symbol rather than text, because that is what the deployment's module
names its own variables by: `show-donation?', `assets-url'.  VALUE is whatever
that variable should be read as -- `#f' for a switch turned off, a word such as
\"off\" for one written the way a shell writes it, an address for an instance
that serves its files elsewhere -- and a blank string is the same as an unset
variable, since that is how the instance's own reader treats one.

The value is laid over the deployment's own before THUNK is called and put back
afterwards, whether THUNK returned or raised, so a case that fails cannot leave
the deployment turned off for the cases that follow it.  The binding is this
fiber's rather than the process's, which is what lets a suite hold one instance
beside the one the run is on while its cases run concurrently.

@example
(assert-false (with-deployment 'show-donation? #f donation-shown?)
              #:name \"the switch is off\")
@end example"
  (parameterize ((deployment-overrides (acons name value
                                              (deployment-overrides))))
    (thunk)))
