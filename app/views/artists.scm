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

(define-module (app views artists)
  #:use-module (wikimusic html)
  #:use-module (wikimusic domain)
  #:use-module (wikimusic query-escape)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (ice-9 i18n)
  #:use-module (kracht prelude)
  #:use-module (hygguile hygguile)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun))

(begin
  (define* (artists-list-page G_
                              #:key artists
                              artworks
                              opinions
                              comments
                              limit
                              offset
                              search-query
                              user-sort)
    (let* ((page-buttons `((div (@ (class "flex flex-row flex-wrap gap-3 my-4"))
                                ,(if (> offset 0)
                                     `((a (@ (href ,(format #f
                                                     "/artists?offset=~a&limit=~a"
                                                     (- offset limit) limit)))
                                          ,(icon-button #:icon 'arrow-left
                                                        #:content (G_
                                                                   "previous"))))
                                     '())
                                ,(if (= (length artists) limit)
                                     `((a (@ (href ,(format #f
                                                     "/artists?offset=~a&limit=~a"
                                                     (+ offset limit) limit)))
                                          ,(icon-button #:icon 'arrow-right
                                                        #:content (G_ "next"))))
                                     '()))))
           (body `(div (@ (class ,(mk-class '(container mx-auto))))
                       ((h2 (@ (class ,(mk-class '(font-black text-stone-800
                                                   dark:text-stone-200
                                                   text-2xl
                                                   py-4
                                                   px-1
                                                   flex
                                                   flex-row
                                                   items-center
                                                   gap-1))))
                            ,(icon #:type 'guitar)
                            ,(G_ "viewing artists"))
                        (div (@ (class ,(mk-class '(flex flex-wrap flex-row
                                                         justify-between))))
                             (div (@ (class ,(mk-class '(flex flex-wrap
                                                              flex-row
                                                              justify-start
                                                              items-center))))
                                  ,(sort-select G_
                                                #:entity 'artist
                                                #:user-sort user-sort))
                             (div (@ (class ,(mk-class '(flex flex-wrap
                                                              flex-row gap-3
                                                              justify-right
                                                              items-center))))

                                  ,(search-box G_
                                               #:search-query search-query)))
                        (div (div (@ (class ,(mk-class '(grid gap-4
                                                              sm:grid-cols-3
                                                              md:grid-cols-4
                                                              lg:grid-cols-5))))
                                  ,(map (lambda (x)
                                          `(div ,(item-tile G_
                                                            'artist
                                                            x
                                                            (relevant-entities 'artist
                                                             artworks x)
                                                            (relevant-entities 'artist
                                                             opinions x)
                                                            (relevant-entities 'artist
                                                             comments x))))
                                        artists))
                             ,page-buttons
                             ,(hr)
                             (div (@ (class ,(mk-class '(flex flex-row
                                                              flex-wrap gap-2
                                                              justify-end))))
                                  (a (@ (href "/artists/new"))
                                     ,(button (G_ "new artist")))))))))
      (html-template G_
                     #:body body)))
  (export artists-list-page))

(begin
  (define* (artists-detail-page G_
                                #:key artist
                                artworks
                                opinions
                                comments
                                user-alist
                                song-fragment
                                external-sources)
    (html-template G_
                   #:body `((div (@ (class ,(mk-class '(container mx-auto))))
                                 (,(h2 (assoc-ref artist "display_name")) (div
                                                                           (div ,
                                                                            (entity-details
                                                                             G_
                                                                             #:entity 'artist
                                                                             #:x
                                                                             artist
                                                                             #:artworks
                                                                             artworks
                                                                             #:opinions
                                                                             opinions
                                                                             #:comments
                                                                             comments
                                                                             #:user-alist
                                                                             user-alist)))))
                            ,(render-external-sources G_ external-sources)
                            (div ,song-fragment))))
  (export artists-detail-page))

(begin
  (define* (artist-edit-page G_ artist artworks)
    (let* ((artwork-forms (map (lambda (a)
                                 `(div (figure (@ (class ,(mk-class '(py-3
                                                                      sm:w-36))))
                                               (img (@ (loading "lazy")
                                                       (class "rounded-xl")
                                                       (src ,(assoc-ref a
                                                              "content_url")))))
                                       ,(artwork-form G_
                                                      #:entity 'artist
                                                      #:entity-identifier (assoc-ref
                                                                           artist
                                                                           "identifier")
                                                      #:artwork-identifier (assoc-ref
                                                                            a
                                                                            "identifier")
                                                      #:content-url (assoc-ref
                                                                     a
                                                                     "content_url")
                                                      #:content-caption (assoc-ref-or-empty-str
                                                                         a
                                                                         "content_caption")
                                                      #:order-value (assoc-ref
                                                                     a
                                                                     "order_value"))))
                               artworks))
           (body `(div (@ (class ,(mk-class '(container mx-auto))))
                       ,(if (assoc-ref artist "identifier")
                            (h2 (format #f "~a: ~a"
                                        (G_ "editing artist")
                                        (assoc-ref artist "display_name")))
                            (h2 (G_ "new artist")))
                       (details (@ (open true))
                                (summary (@ (class ,(mk-class '(font-black
                                                                text-stone-800
                                                                text-md
                                                                cursor-pointer))))
                                         ,(G_ "edit artworks"))
                                ,artwork-forms)
                       ,(hr)
                       (details (@ (open true))
                                (summary (@ (class ,(mk-class '(font-black
                                                                text-stone-800
                                                                dark:text-stone-200
                                                                text-md
                                                                cursor-pointer))))
                                         ,(G_ "new artwork"))
                                ,(artwork-form G_
                                               #:entity 'artist
                                               #:entity-identifier (assoc-ref
                                                                    artist
                                                                    "identifier")))
                       ,(hr)
                       (details (@ (open true))
                                (summary (@ (class ,(mk-class '(font-black
                                                                text-stone-800
                                                                dark:text-stone-200
                                                                text-md
                                                                cursor-pointer))))
                                         ,(G_ "editing artist"))
                                ,(artist-form G_
                                              #:identifier (assoc-ref artist
                                                            "identifier")
                                              #:display-name (assoc-ref artist
                                                              "display_name")
                                              #:description (assoc-ref-or-empty-str
                                                             artist
                                                             "description"))))))
      (html-template G_
                     #:body body)))
  (export artist-edit-page))

(begin
  (define* (artist-new-page G_)
    (html-template G_
                   #:body `(div (@ (class "container mx-auto"))
                                ,(artist-form G_))))
  (export artist-new-page))

(begin
  (define* (artist-form G_
                        #:key (identifier #f)
                        (display-name "")
                        (description ""))
    `((form (@ (method POST)
               (action ,(if identifier
                            (format #f "/artists/uuid/~a/edit" identifier)
                            (format #f "/artists/new" identifier)))
               (content-type application/x-www-form-urlencoded))
            (div ,(input #:label (G_ "display name")
                         #:name "display-name"
                         #:value (unescape-str display-name)
                         #:required #t)
                 ,(textarea #:label (G_ "description")
                            #:name "description"
                            #:value (unescape-str description))))
      (div ,(submit-button (if identifier
                               (G_ "edit")
                               (G_ "create"))))))
  (export artist-form))

