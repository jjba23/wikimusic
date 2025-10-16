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

(define-module (app views genres)
  #:use-module (wikimusic html)
  #:use-module (wikimusic domain)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (kracht prelude)
  #:use-module (web uri)
  #:use-module (ice-9 i18n)
  #:use-module (hygguile hygguile)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun)
  #:export (genre-list-page genre-detail-page genre-edit-page genre-new-page
                            genre-form))

(define* (genre-list-page G_
                          #:key genres
                          artworks
                          opinions
                          comments
                          limit
                          offset
                          search-query
                          user-sort
                          is-logged-in)
  (let* ((page-buttons `((div (@ (class ,(mk-class '(flex flex-row flex-wrap
                                                          gap-3 my-4))))
                              ,(if (> offset 0)
                                   `((a (@ (href ,(format #f
                                                   "/genres?offset=~a&limit=~a"
                                                   (- offset limit) limit)))
                                        ,(icon-button #:icon 'arrow-left
                                                      #:content (G_ "previous"))))
                                   '())
                              ,(if (= (length genres) limit)
                                   `((a (@ (href ,(format #f
                                                   "/genres?offset=~a&limit=~a"
                                                   (+ offset limit) limit)))
                                        ,(icon-button #:icon 'arrow-right
                                                      #:content (G_ "next"))))
                                   '()))))
         (body `(div (@ (class ,(mk-class '(px-4 md:px-8 py-2))))
                     (,(h2 `(div (@ (class ,(mk-class '(flex flex-row
                                                               items-center
                                                               align-center
                                                               gap-1))))
                                   ,(icon #:type 'disc)
                                   ,(G_ "viewing genres"))
                             #:weight '(font-light)
                             #:family '(font-serif))
                      (div (@ (class ,(mk-class '(flex flex-wrap flex-row
                                                       justify-between))))
                           (div (@ (class ,(mk-class '(flex flex-wrap flex-row
                                                            justify-start
                                                            items-center))))
                                ,(sort-select G_
                                              #:entity 'genre
                                              #:user-sort user-sort))
                           (div (@ (class ,(mk-class '(flex flex-wrap flex-row
                                                            gap-3
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
                           ,(hr)
                           (div (@ (class ,(mk-class '(flex flex-row flex-wrap
                                                            gap-2 justify-end))))
                                (a (@ (href "/genres/new"))
                                   ,(button (G_ "new genre")))))))))
    (html-template G_
                   #:is-logged-in is-logged-in
                   #:body body)))

(define* (genre-detail-page G_
                            #:key genre
                            artworks
                            opinions
                            comments
                            user-alist
                            song-fragment
                            external-sources
                            is-logged-in)
  (html-template G_
                 #:is-logged-in is-logged-in
                 #:body `((div (@ (class ,(mk-class '(container mx-auto p-3
                                                                sm:p-1 md:p-0))))
                               (,(h2 (assoc-ref genre "display_name")) (div (div ,
                                                                             (entity-details
                                                                              G_
                                                                              #:entity 'genre
                                                                              #:x
                                                                              genre
                                                                              #:artworks
                                                                              artworks
                                                                              #:opinions
                                                                              opinions
                                                                              #:comments
                                                                              comments
                                                                              #:user-alist
                                                                              user-alist)))))
                          ,(render-external-sources G_ external-sources)
                          ,song-fragment)))

(define* (genre-edit-page G_
                          #:key genre
                          artworks
                          external-sources
                          is-logged-in)
  (let* ((arts (map (lambda (a)
                      `(div (figure (@ (class ,(mk-class '(py-3 sm:w-36))))
                                    (img (@ (loading "lazy")
                                            (class ,(mk-class '(rounded-xl)))
                                            (src ,(uri-decode (assoc-ref a
                                                               "content_url"))))))
                            ,(artwork-form G_
                                           #:entity 'genre
                                           #:entity-identifier (assoc-ref
                                                                genre
                                                                "identifier")
                                           #:artwork-identifier (assoc-ref a
                                                                 "identifier")
                                           #:content-url (uri-decode (assoc-ref
                                                                      a
                                                                      "content_url"))
                                           #:content-caption (assoc-ref-or-empty-str
                                                              a
                                                              "content_caption")
                                           #:order-value (assoc-ref a
                                                          "order_value"))))
                    artworks))
         (body `(div (@ (class ,(mk-class '(container mx-auto))))
                     ,(if (assoc-ref genre "identifier")
                          (h2 (format #f "~a: ~a"
                                      (G_ "editing genre")
                                      (assoc-ref genre "display_name")))
                          (h2 (G_ "new genre")))
                     (details (@ (open true))
                              (summary (@ (class ,(mk-class '(font-black
                                                              text-onyx-300
                                                              dark:text-stone-300
                                                              text-md
                                                              cursor-pointer))))
                                       ,(G_ "edit artworks"))
                              ,arts)
                     ,(hr)
                     (details (@ (open true))
                              (summary (@ (class ,(mk-class '(font-black
                                                              text-onyx-300
                                                              dark:text-stone-300
                                                              text-md
                                                              cursor-pointer))))
                                       ,(G_ "new artwork"))
                              ,(artwork-form G_
                                             #:entity 'genre
                                             #:entity-identifier (assoc-ref
                                                                  genre
                                                                  "identifier")))
                     ,(hr)
                     (details (@ (open true))
                              (summary (@ (class ,(mk-class '(font-black
                                                              text-onyx-300
                                                              dark:text-stone-300
                                                              text-md
                                                              cursor-pointer))))
                                       ,(G_ "editing genre"))
                              ,(genre-form G_
                                           #:identifier (assoc-ref genre
                                                         "identifier")
                                           #:display-name (assoc-ref genre
                                                           "display_name")
                                           #:description (assoc-ref-or-empty-str
                                                          genre "description")))
                     ,(hr)
                     (details (@ (open true))
                              (summary (@ (class ,(mk-class '(font-black
                                                              text-onyx-300
                                                              dark:text-stone-300
                                                              text-md
                                                              cursor-pointer))))
                                       ,(G_ "editing external sources"))
                              ,(external-sources-form G_
                                                      #:entity 'genre
                                                      #:entity-identifier (assoc-ref
                                                                           genre
                                                                           "identifier")
                                                      #:external-sources-identifier
                                                      (assoc-ref
                                                       external-sources
                                                       "identifier")
                                                      #:wikipedia-url (uri-decode
                                                                       (assoc-ref-or-empty-str
                                                                        external-sources
                                                                        "wikipedia_url"))
                                                      #:spotify-url (uri-decode
                                                                     (assoc-ref-or-empty-str
                                                                      external-sources
                                                                      "spotify_url"))
                                                      #:youtube-url (uri-decode
                                                                     (assoc-ref-or-empty-str
                                                                      external-sources
                                                                      "youtube_url"))
                                                      #:soundcloud-url (uri-decode
                                                                        (assoc-ref-or-empty-str
                                                                         external-sources
                                                                         "soundcloud_url")))))))
    (html-template G_
                   #:is-logged-in is-logged-in
                   #:body body)))

(define* (genre-new-page G_
                         #:key is-logged-in)
  (html-template G_
                 #:is-logged-in is-logged-in
                 #:body `(div (@ (class ,(mk-class '(container mx-auto))))
                              ,(genre-form G_))))

(define* (genre-form G_
                     #:key (identifier #f)
                     (display-name "")
                     (description ""))
  `((form (@ (method POST)
             (action ,(if identifier
                          (format #f "/genres/uuid/~a/edit" identifier)
                          "/genres/new"))
             (content-type application/x-www-form-urlencoded))
          (div ,(input #:label (G_ "display name")
                       #:name "display-name"
                       #:value (html-unescape display-name)
                       #:required #t)
               ,(textarea #:label (G_ "description")
                          #:name "description"
                          #:value (html-unescape description)))
          (div ,(submit-button (if identifier
                                   (G_ "edit")
                                   (G_ "create")))))))

