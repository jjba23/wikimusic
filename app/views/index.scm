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

(define-module (app views index)
  #:use-module (wikimusic html)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (hygguile hygguile)
  #:use-module (ice-9 i18n)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun)
  #:export (welcome-page))

(define* (welcome-page G_
                       #:key is-logged-in)
  (html-template G_
                 #:is-logged-in is-logged-in
                 #:body `(div (div (@ (class ,(mk-class '(p-2))))
                                   (div (@ (class ,(mk-class '(flex flex-row
                                                                    flex-wrap
                                                                    gap-5 px-3
                                                                    align-center items-center
                                                                    justify-center
                                                                    py-6))))
                                        ,(wikimusic-explain G_))))))

(define* (wikimusic-img)
  `((div (div (@ (class ,(mk-class '(bg-stone-300/50 dark:bg-onyx-700
                                     p-4
                                     rounded-xl
                                     shadow-xl
                                     py-4
                                     md:px-8
                                     xl:px-12
                                     px-6
                                     md:px-12
                                     xl:px-18
                                     border-persia-pink-500/25
                                     border-3))))
              (figure (img (@ (class ,(mk-class '(rounded-2xl h-auto max-w-64
                                                              sm:max-w-96)))
                              (loading lazy)
                              (src
                               "https://jointhefreeworld.org/static-assets/wikimusic/img/wikimusic.jpg"))))))))

(define* (wikimusic-explain G_)
  `(
    (div (@ (class ,(mk-class '(max-w-196 py-4
                                          md:px-8
                                          xl:px-12
                                          px-6
                                          md:px-12
                                          xl:px-18
                                          font-serif
                                          text-justify
                                          bg-stone-300/50
                                          dark:bg-onyx-700
                                          text-onyx-300
                                          dark:text-stone-300
                                          border-persia-pink-500/25
                                          border-3
                                          rounded-2xl
                                          shadow-xl
                                          leading-6
                                          flex
                                          flex-col
                                          gap-4))))
         (div (@(class ,(mk-class '(text-center)))) ,(sub-h3 (G_ "the free music knowledge encyclopaedia")
                  #:family '(font-serif)))

         (p ,(G_
              "The WikiMusic project is an non-profit community, with the goal of knowledge sharing and musical education, providing an open platform for exploring, sharing, and learning about music in all its forms."))

         (div (@ (class ,(mk-class '())))
              (a (@ (class ,(mk-class '(font-bold text-china-violet-100
                                        hover:text-persia-pink-900
                                        dark:text-persia-pink-300
                                        hover:dark:text-persia-pink-700

                                        flex
                                        flex-row
                                        no-underline
                                        hover:underline
                                        gap-3)))
                    (href "https://www.buymeacoffee.com/jjbigorra"))
                 (span "🩷")
                 ,(G_ "donate what you can, by clicking here")
                 (span "🩷")))
         (p ,(G_
              "This helps us keep the underlying cloud infrastructure and the contributor's work hours going strong."))

         (p ,(G_
              "WikiMusic leverages a database-backed architecture to ensure all content is easily searchable, linkable, and reusable. "))
         (p ,(G_
              "The user interface provides a seamless experience, inviting both beginners and experts to engage with the world of music collaboratively."))
         (p ,(G_
              "Join us in building an ever-growing library of musical knowledge — where every note tells a story.")))

    ,(wikimusic-img)

    (div (@ (class ,(mk-class '(max-w-196 bg-stone-300/50
                                          dark:bg-onyx-700
                                          text-onyx-300
                                          dark:text-stone-300
                                          rounded-2xl
                                          shadow-xl
                                          border-persia-pink-500/25
                                          border-3
                                          leading-6
                                          font-serif
                                          text-justify
                                          flex
                                          flex-col
                                          gap-4
                                          py-4
                                          md:px-8
                                          xl:px-12
                                          px-6
                                          md:px-12
                                          xl:px-18))))

         (p ,(G_
              "Whether you're a musician, educator, researcher, or simply a music lover, WikiMusic empowers you to:"))
         (ul (@ (class ,(mk-class '(pl-8 list-disc))))
             (li ,(G_ "Discover music from diverse genres and traditions."))
             (li ,(G_
                   "Organize information with structured metadata and multimedia content."))
             (li ,(G_
                   "Contribute by adding new compositions, analyses, or educational materials."))
             (li ,(G_
                   "Learn through curated resources that connect music theory, history, and practice.")))
         (p ,(G_
              "At its core, WikiMusic leverages the expressive power of Lisp to build a dynamic interactive Music Gallery and Content Management System (CMS).")))))
