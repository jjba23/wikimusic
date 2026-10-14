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
;;; has to *be* the other instance for the length of an assertion, and the
;;; variable is therefore bound in the loaded `(wikimusic env)' module and put
;;; back exactly as it was found.  The deployment's own `env.scm' is never read
;;; for it and never written: what changes is one binding in the running
;;; process, and only while a case is being built.
;;;
;;; That last part is worth saying plainly, because it is what makes this small
;;; helper enough.  A veritas assertion is a *value* -- the expected and the
;;; got are both computed where the assertion is written, inside the suite, and
;;; compared when the test runs -- so the value read with a deployment's switch
;;; flipped is the value the assertion carries, and the switch is back before
;;; the next case is even written.  A suite is therefore free to hold an
;;; instance that raises nothing beside the one it is running on.
;;;
;;; It is a module of its own, and not under `test/veritas/unit/', because it is
;;; not a spec: the runner discovers every Scheme file under the unit directory
;;; and calls an entrypoint named `spec' in each, and a file that holds only a
;;; helper has none to call.  `maak test' puts `./test' on the load path, so a
;;; spec imports it as `(support deployment)'.

(define-module (support deployment)
  #:export (with-deployment))

;; What `with-deployment' answers when the variable it is asked for was not
;; bound at all, told apart from one bound to #f -- which is a deployment
;; turning something off, and a value that has to be restored rather than
;; removed.
(define unbound
  (list 'unbound))

(define* (with-deployment name value thunk)
  "Answer what THUNK answers, with NAME bound to VALUE in `(wikimusic env)'.

NAME is a symbol rather than text, because that is what the deployment's module
names its own variables by: `show-donation?', `assets-url'.  VALUE is whatever
that variable should be read as -- `#f' for a switch turned off, a word such as
\"off\" for one written the way a shell writes it, an address for an instance
that serves its files elsewhere -- and a blank string is the same as an unset
variable, since that is how the instance's own reader treats one.

The binding is made before THUNK is called and put back afterwards, whether
THUNK raised or not, so a case that fails cannot leave the deployment turned
off for the cases that follow it.

@example
(assert-false (with-deployment 'show-donation? #f donation-shown?)
              #:name \"the switch is off\")
@end example"
  (let* ((module (resolve-module '(wikimusic env)))
         (variable (module-variable module name))
         (was (if (and variable
                       (variable-bound? variable))
                  (variable-ref variable) unbound)))
    (dynamic-wind (lambda ()
                    (module-define! module name value)) thunk
                  (lambda ()
                    (if (eq? was unbound)
                        (module-remove! module name)
                        (module-set! module name was))))))
