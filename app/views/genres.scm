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

(define-module (app views genres)
  #:use-module (wikimusic html)
  #:use-module (wikimusic domain)
  #:use-module (wikimusic query-escape)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (kracht prelude)
  #:use-module (ice-9 i18n)
  #:use-module (hygguile abstraction)
  #:use-module (hygguile components button)
  #:use-module (hygguile components input)
  #:use-module (hygguile components icon)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun))

(begin
  (define* (genres-list-page G_
                             #:key genres
                             artworks
                             opinions
                             comments
                             limit
                             offset
                             search-query)
    (let* ((page-buttons `((div (@ (class ,(->css '(flex flex-row flex-wrap
                                                         gap-3 my-4))))
                                ,(if (> offset 0)
                                     `((a (@ (href ,(format #f
                                                            "/genres?offset=~a&limit=~a"
                                                            (- offset limit) limit)))
                                          ,(hyg-icon-button #:icon 'arrow-left
                                                            #:content (G_
                                                                       "previous"))))
                                     '())
                                ,(if (= (length genres) limit)
                                     `((a (@ (href ,(format #f
                                                            "/genres?offset=~a&limit=~a"
                                                            (+ offset limit) limit)))
                                          ,(hyg-icon-button #:icon 'arrow-right
                                                            #:content (G_
                                                                       "next"))))
                                     '()))))
           (body `(div (@ (class ,(->css '(container mx-auto))))
                       ((h2 (@ (class ,(->css '(font-black text-stone-800
                                                           text-2xl
                                                           py-4
                                                           px-1
                                                           flex
                                                           flex-row
                                                           items-center
                                                           gap-1))))
                            ,(hyg-icon #:type 'disc)
                            ,(G_ "viewing genres"))
                        (div (@(class ,(->css '(flex flex-wrap flex-row justify-between))))
                             (div (@ (class ,(->css '(flex flex-wrap flex-row justify-start items-center))))
                                  ,(sort-select G_
                                                #:entity 'genre))
                             (div (@ (class ,(->css '(flex flex-wrap flex-row gap-3
                                                           justify-right
                                                           items-center))))

                                  ,(search-box G_
                                               #:search-query search-query)))
                        (div (div (@ (class ,(->css '(grid gap-4
                                                           sm:grid-cols-3
                                                           md:grid-cols-4
                                                           lg:grid-cols-5))))
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
                                        genres))
                             ,page-buttons
                             (hr (@(class ,(->css '(my-6)))))
                             (div (@(class ,(->css '(flex flex-row flex-wrap gap-2 justify-end))))
                                  (a (@ (href "/genres/new"))
                                     ,(hyg-button (G_ "new genre")))))))))
      (html-template G_
                     #:body body)))
  (export genres-list-page))

(define-public (genres-detail-page G_
                                   genre
                                   artworks
                                   opinions
                                   comments
                                   user-alist)
  (html-template G_
                 #:body `(div (@ (class ,(->css '(container mx-auto))))
                              ((h2 (@ (class ,(->css '(font-black
                                                       text-stone-800 text-3xl))))
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
    (let* ((arts (map (lambda (a)
                        `(div (figure (@ (class ,(->css '(py-3 sm:w-36))))
                                      (img (@ (loading "lazy")
                                              (class ,(->css '(rounded-xl)))
                                              (src ,(assoc-ref a "content_url")))))
                              ,(artwork-form G_
                                             #:entity 'genre
                                             #:entity-identifier (assoc-ref
                                                                  genre
                                                                  "identifier")
                                             #:artwork-identifier (assoc-ref a
                                                                   "identifier")
                                             #:content-url (assoc-ref a
                                                            "content_url")
                                             #:content-caption (assoc-ref-or-empty-str
                                                                a
                                                                "content_caption")
                                             #:order-value (assoc-ref a
                                                            "order_value"))))
                      artworks))
           (body `(div (@ (class ,(->css '(container mx-auto))))
                       ,(if (assoc-ref genre "identifier")
                            `(h2 (@ (class ,(->css '(text-2xl my-6 font-bold
                                                              text-stone-800))))
                                 ,(format #f "~a: ~a"
                                          (G_ "editing genre")
                                          (assoc-ref genre "display_name")))
                            `(h2 (@ (class ,(->css '(text-2xl my-6 font-bold
                                                              text-stone-800))))
                                 (G_ "new genre")))
                       (details (@ (open true))
                                (summary (@ (class ,(->css '(font-black
                                                             text-stone-800
                                                             text-md
                                                             cursor-pointer))))
                                         ,(G_ "edit artworks"))
                                ,arts)
                       (hr (@ (class "my-6")))
                       (details (@ (open true))
                                (summary (@ (class ,(->css '(font-black
                                                             text-stone-800
                                                             text-md
                                                             cursor-pointer))))
                                         ,(G_ "new artwork"))
                                ,(artwork-form G_
                                               #:entity 'genre
                                               #:entity-identifier (assoc-ref
                                                                    genre
                                                                    "identifier")))
                       (hr (@ (class ,(->css '(my-6)))))
                       (details (@ (open true))
                                (summary (@ (class ,(->css '(font-black
                                                             text-stone-800
                                                             text-md
                                                             cursor-pointer))))
                                         ,(G_ "editing genre"))
                                ,(genre-form G_
                                             #:identifier (assoc-ref genre
                                                           "identifier")
                                             #:display-name (assoc-ref genre
                                                             "display_name")
                                             #:description (assoc-ref-or-empty-str
                                                            genre
                                                            "description"))))))
      (html-template G_
                     #:body body)))
  (export genre-edit-page))

(begin
  (define* (genre-new-page G_)
    (html-template G_
                   #:body `(div (@ (class ,(->css '(container mx-auto))))
                                ,(genre-form G_))))
  (export genre-new-page))

(begin
  (define* (genre-form G_
                       #:key (identifier #f)
                       (display-name "")
                       (description ""))
    `((form (@ (method POST)
               (action ,(if identifier
                            (format #f "/genres/uuid/~a/edit" identifier)
                            (format #f "/genres/new" identifier)))
               (content-type application/x-www-form-urlencoded))
            (div ,(hyg-input #:label (G_ "display name")
                             #:name "display-name"
                             #:value (unescape-str display-name)
                             #:required #t)
                 ,(hyg-textarea #:label (G_ "description")
                                #:name "description"
                                #:value (unescape-str description))))
      (div ,(hyg-submit-button (if identifier
                                   (G_ "edit")
                                   (G_ "create"))))))
  (export genre-form))

