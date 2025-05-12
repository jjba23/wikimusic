;;; wikimusic - the free music knowledge encyclopaedia

;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;; wikimusic is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; wikimusic is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with wikimusic.  If not, see <https://www.gnu.org/licenses/>.

(define-module (app views login)
  #:use-module (wikimusic html)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (ice-9 i18n)
  #:use-module (hygguile hygguile)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun))

(define-public (login-page G_)
  (html-template G_
                 #:body `(div (@ (class ,(mk-class '(container mx-auto))))
                              ((h2 (@ (class ,(mk-class '(font-black
                                                          text-stone-800
                                                          text-2xl px-1))))
                                   ,(G_ "login to wikimusic"))
                               (div (form (@ (action "/login")
                                             (class ,(mk-class '(w-full
                                                                 rounded-xl
                                                                 bg-stone-200/75
                                                                 p-4
                                                                 flex
                                                                 flex-row
                                                                 flex-wrap
                                                                 items-center
                                                                 gap-4
                                                                 align-center)))
                                             (method POST))
                                          ,(input #:label (G_ "username")
                                                  #:name "username"
                                                  #:value "jjba23"
                                                  #:required #t)
                                          ,(input #:label (G_ "password")
                                                  #:name "password_hash"
                                                  #:value ""
                                                  #:type 'password
                                                  #:required #t)
                                          (div ,(submit-button (G_ "login")))))))))

