;;; wikimusic - the free music knowledge encyclopaedia

;; Copyright © 2025 "Josep Bigorra" known as "jjba23" <jjbigorra@gmail.com>

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

(define-module (app views genres)
  #:use-module (wikimusic html)
  #:use-module (wikimusic abstraction)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (wikimusic query-escape)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (hygguile abstraction)
  #:use-module (hygguile components button)
  #:use-module (hygguile components input)
  #:use-module (ice-9 i18n)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun))

(define-public (genres-list-page G_ genres artworks opinions comments)
  (html-template G_
                 #:body `(div (@ (class "container mx-auto"))
                              ((h2 (@ (class
                                       "font-black text-stone-800 text-2xl py-4"))
                                   ,(G_ "viewing genres"))
                               (div (div (@ (class
                                             "flex flex-row flex-wrap gap-3 items-center"))
                                         ,(map (lambda (x)
                                                 `(div ,(item-tile G_
                                                                   'genre
                                                                   x
                                                                   (relevant-entities 'genre
                                                                    artworks x)
                                                                   (relevant-entities 'genre
                                                                    opinions x)
                                                                   (relevant-entities 'genre
                                                                    comments x))))
                                               genres)))))))

(define-public (genres-detail-page G_
                                   genre
                                   artworks
                                   opinions
                                   comments
                                   user-alist)
  (html-template G_
                 #:body `(div (@ (class "container mx-auto"))
                              ((h2 (@ (class
                                       "font-black text-stone-800 text-xl"))
                                   ,(assoc-ref genre "display_name"))
                               (div (div ,(entity-details G_
                                                          'genre
                                                          genre
                                                          artworks
                                                          opinions
                                                          comments
                                                          user-alist)))))))

(begin
  (define* (genre-edit-page G_ genre artworks)
    (html-template G_
                   #:body `(div (@ (class "container mx-auto"))
                                (details (@ (class "cursor-pointer"))
                                         (summary (@ (class
                                                       "font-black text-stone-800 text-md"))
                                                  ,(G_ "edit artworks"))
                                         ,(map (lambda (a)
                                                 `(div (figure (@ (class
                                                                    "py-3 sm:w-36"))
                                                               (img (@ (loading
                                                                        "lazy")
                                                                       (class
                                                                         "rounded-xl")
                                                                       (src ,(assoc-ref
                                                                              a
                                                                              "content_url")))))
                                                       ,(artwork-form G_
                                                                      #:entity 'genre
                                                                      #:entity-identifier
                                                                      (assoc-ref
                                                                       genre
                                                                       "identifier")
                                                                      #:artwork-identifier
                                                                      (assoc-ref
                                                                       a
                                                                       "identifier")
                                                                      #:content-url
                                                                      (assoc-ref
                                                                       a
                                                                       "content_url")
                                                                      #:content-caption
                                                                      (assoc-ref-or-empty-str
                                                                       a
                                                                       "content_caption")
                                                                      #:order-value
                                                                      (assoc-ref
                                                                       a
                                                                       "order_value"))))
                                               artworks))
                                (hr (@ (class "my-6")))
                                (details (@ (class "cursor-pointer"))
                                         (summary (@ (class
                                                       "font-black text-stone-800 text-md"))
                                                  ,(G_ "new artwork"))
                                         ,(artwork-form G_
                                                        #:entity 'genre
                                                        #:entity-identifier (assoc-ref
                                                                             genre
                                                                             "identifier")))
                                (hr (@ (class "my-6")))
                                (details (@ (class "cursor-pointer"))
                                         (summary (@ (class
                                                       "font-black text-stone-800 text-md"))
                                                  ,(G_ "editing genre"))
                                         ,(genre-form G_
                                                      #:identifier (assoc-ref song "identifier")
                                                      #:display-name (assoc-ref
                                                                      genre
                                                                      "display_name")
                                                      #:description (assoc-ref-or-empty-str
                                                                     genre
                                                                     "description"))))))
  (export genre-edit-page))

(begin
  (define* (genre-form G_
                       #:key
                       (identifier #f)
                       (display-name "")
                       (description ""))
    `((form (@ (method POST)
               (action ,(if identifier
                            (format #f "/genres/uuid/~a/edit" identifier)
                            (format #f "/genres/new" identifier)))
               (content-type application/x-www-form-urlencoded))
            (div ,(mk-input #:label (G_ "display name")
                            #:name "display-name"
                            #:value (unescape-str display-name)
                            #:required #t)
                 ,(mk-textarea #:label (G_ "description")
                               #:name "description"
                               #:value (unescape-str description))))
      (div ,(success-submit-button #:content (G_ "edit")))))
  (export genre-form))

