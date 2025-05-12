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

(define-module (app views index)
  #:use-module (wikimusic html)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (hygguile abstraction)
  #:use-module (hygguile components icon)
  #:use-module (hygguile components typography)
  #:use-module (ice-9 i18n)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun))

(define-public (welcome-page G_)
  (html-template G_
                 #:body `(div (@ (class "container mx-auto"))
                              (div (@ (class "p-2"))
                                   ,(hyg-h2 (G_ "Welcome to Wikimusic"))
                                   ,(hyg-sub-h3 (G_
                                                 "the free music knowledge encyclopaedia"))
                                   (div (@ (class ,(->css '(flex flex-row
                                                            flex-wrap
                                                            justify-between))))
                                        ,(wikimusic-explain G_)
                                        ,(wikimusic-img))))))

(define (wikimusic-img)
  `((div
     (div (@ (class ,(->css '(bg-stone-300/50 max-w-56 sm:max-w-90 p-4 rounded-xl shadow-md))))
          (figure (img (@ (class ,(->css '(rounded-2xl h-auto)))(loading lazy)
                          (src "https://jointhefreeworld.org/static-assets/wikimusic/img/wikimusic.jpg")))))
     )))

(define (wikimusic-explain G_)
  `((div (@ (class ,(->css '(max-w-prose my-8 p-4 bg-stone-300/50 rounded-2xl
                                         shadow-md))))
         (p ,(G_
              "The WikiMusic project is an non-profit community, with the goal of knowledge sharing and musical education, providing an open platform for exploring, sharing, and learning about music in all its forms."))

         (p ,(G_
              "At its core, WikiMusic leverages the expressive power of Lisp to build a dynamic interactive Music Gallery and Content Management System (CMS)."))

         (p ,(G_
              "Whether you're a musician, educator, researcher, or simply a music lover, WikiMusic empowers you to:"))

         (ul (@ (class "my-4 px-2 list-disc"))
             (li ,(G_ "Discover music from diverse genres and traditions."))
             (li ,(G_
                   "Organize information with structured metadata and multimedia content."))
             (li ,(G_
                   "Contribute by adding new compositions, analyses, or educational materials."))
             (li ,(G_
                   "Learn through curated resources that connect music theory, history, and practice.")))

         (div (@ (class "my-2"))
              (a (@ (class
                     "font-bold text-blue-900 hover:text-blue-700 flex flex-row gap-3")
                    (href "https://www.buymeacoffee.com/jjbigorra"))
                 (span "💙")
                 ,(G_ "Please donate by clicking here")
                 (span "💙")))
         (p ,(G_
              "This helps us keep the underlying cloud infrastructure and the contributor's work hours going strong."))

         (p ,(G_
              "WikiMusic leverages a database-backed architecture to ensure all content is easily searchable, linkable, and reusable. The user interface provides a seamless experience, inviting both beginners and experts to engage with the world of music collaboratively."))
         (p ,(G_
              "Join us in building an ever-growing library of musical knowledge — where every note tells a story.")))))
