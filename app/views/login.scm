;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (app views login)
  #:use-module (wikimusic html)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (ice-9 i18n)
  #:use-module (hygguile hygguile)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun)
  #:export (login-page))

(define* (login-page G_
                     #:key is-logged-in)
  (let* ((login-form `(div (form (@ (action "/login")
                                    (class ,(mk-class '(w-full rounded-xl
                                                        hg-frost
                                                        bg-stone-100/75
                                                        dark:bg-onyx-900/75
                                                        p-4
                                                        flex
                                                        flex-row
                                                        flex-wrap
                                                        items-center
                                                        gap-4
                                                        shadow-md
                                                        items-center)))
                                    (method POST))
                                 ,(input #:label (G_ "email")
                                         #:name "email"
                                         #:type 'email
                                         #:value ""
                                         #:required #t)
                                 ,(input #:label (G_ "password")
                                         #:name "password"
                                         #:value ""
                                         #:type 'password
                                         #:required #t)
                                 (div ,(submit-button (G_ "login"))))))
         (reset-form `((form (@ (action "/password/reset")
                                (class ,(mk-class '(w-full rounded-xl
                                                    hg-frost
                                                    bg-stone-100/75
                                                    dark:bg-onyx-900/75
                                                    p-4
                                                    flex
                                                    flex-row
                                                    flex-wrap
                                                    items-center
                                                    gap-4
                                                    shadow-md)))
                                (method POST))
                             ,(input #:label (G_ "account to reset (email)")
                                     #:name "email"
                                     #:type 'email
                                     #:value ""
                                     #:required #t)
                             (div ,(icon-button #:icon 'password
                                                #:type 'submit
                                                #:content (G_ "reset")))))))
    (html-template G_
                   #:is-logged-in is-logged-in
                   ;; A sign-in form is nobody's search result and nothing to
                   ;; preview: it is kept out of the index and out of the
                   ;; crawl, while the pages it links to stay crawlable.
                   #:title "Sign in · WikiMusic"
                   #:robots "noindex, nofollow"
                   #:body `((div (@ (class ,(mk-class '(px-4 md:px-8 py-2))))
                                 (div (@ (class ,(mk-class '(w-full flex
                                                                    flex-row
                                                                    flex-wrap
                                                                    gap-10))))
                                      (div (@ (class ,(mk-class '(flex
                                                                  flex-col
                                                                  gap-8))))
                                           ,(h2 (G_ "login to wikimusic")
                                                #:weight '(font-light)
                                                #:family '(font-sans))
                                           (div ,login-form))
                                      (div (@ (class ,(mk-class '(flex
                                                                  flex-col
                                                                  gap-8))))
                                           ,(h2 (G_ "reset password")
                                                #:weight '(font-light)
                                                #:family '(font-sans))
                                           (div ,reset-form))))))))
