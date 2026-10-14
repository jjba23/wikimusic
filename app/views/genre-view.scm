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

(define-module (app views genre-view)
  #:use-module (wikimusic html)
  #:use-module (wikimusic config)
  #:use-module (wikimusic seo)
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
  #:export (genre-list-page genre-detail-page))

(define* (genre-list-page G_
                          #:key genres
                          artworks
                          comments
                          limit
                          offset
                          search-query
                          user-sort
                          grid-size
                          pages
                          is-logged-in)
  (let* ((page (if (and limit
                        (> limit 0))
                   (+ 1
                      (quotient offset limit)) 1))
         (searching? (and (string? search-query)
                          (not (string-null? search-query))))
         (list-title (if searching?
                      (format #f "Genres matching “~a” | WikiMusic"
                              search-query)
                      "Genres: styles and traditions, with their songs and artists | WikiMusic"))
         (list-description (if searching?
                            (format #f
                             "Genres on WikiMusic matching “~a”, with their artists and songs."
                             search-query)
                            "Every musical genre on WikiMusic, with the artists and songs that belong to it, their keys and their tabs."))
         (page-buttons (if (and pages
                                (> pages 1))
                           (pagination #:current page
                                       #:total pages
                                       #:base-url (format #f
                                                   "/genres?limit=~a&sort=~a~a&page="
                                                   limit
                                                   (or user-sort "")
                                                   (if (and search-query
                                                            (not (equal?
                                                                  search-query
                                                                  "")))
                                                       (format #f "&search=~a"
                                                               search-query)
                                                       ""))
                                       #:prev-label (G_ "previous")
                                       #:next-label (G_ "next"))
                           '()))
         (body `(div (@ (class ,(mk-class '(px-4 md:px-8
                                                 py-2
                                                 flex
                                                 flex-col
                                                 md:flex-row
                                                 md:flex-wrap
                                                 gap-3
                                                 md:gap-5
                                                 items-center
                                                 items-center
                                                 justify-center
                                                 md:justify-between))))
                     (,(h4 `(div (@ (class ,(mk-class '(flex flex-row
                                                             items-center
                                                             items-center
                                                             gap-1))))
                                 ,(G_ "viewing genres:"))
                           #:weight '(font-light)
                           #:size '(text-2xl)
                           #:family '(font-sans)) (div (@ (class ,(mk-class '(flex
                                                                              flex-wrap
                                                                              flex-row
                                                                              justify-center
                                                                              gap-2))))
                                                       (div (@ (class ,(mk-class '
                                                                        (flex
                                                                         flex-wrap
                                                                         flex-row
                                                                         justify-start
                                                                         items-center))))
                                                            ,(sort-select G_
                                                              #:entity 'genre
                                                              #:user-sort
                                                              user-sort)
                                                            ,(grid-size-select
                                                              G_
                                                              #:entity 'genre
                                                              #:size grid-size
                                                              #:search-query
                                                              search-query))
                                                       (div (@ (class ,(mk-class '
                                                                        (flex
                                                                         flex-wrap
                                                                         flex-row
                                                                         gap-3
                                                                         justify-end
                                                                         items-center))))

                                                            ,(search-box G_
                                                              #:search-query
                                                              search-query)))
                      (div (div (@ (class ,(item-tile-grid-face #:size
                                                                grid-size)))
                                ,(map (lambda (x)
                                        `(div ,(item-tile G_
                                                          'genre x
                                                          (relevant-entities 'genre
                                                           artworks x)
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
                   #:title list-title
                   #:description list-description
                   #:path (if (and (= page 1)
                                   (not searching?)) "/genres" #f)
                   #:robots (if (or searching?
                                    (> page 1)) "noindex, follow" #f)
                   #:json-ld (list (page-json-ld #:type "CollectionPage"
                                                 #:url (if searching? #f
                                                           (absolute-url
                                                            "/genres"))
                                                 #:name list-title
                                                 #:description
                                                 list-description))
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
  (let* ((genre-name (assq-ref genre
                               'display-name))
         (genre-path (format #f "/genres/uuid/~a"
                             (assq-ref genre
                                       'identifier)))
         (page-title (format #f
                             "~a — genres, artists, songs & tabs | WikiMusic"
                             genre-name))
         (page-description (summarize (string-append genre-name
                                       " as a musical genre on WikiMusic: the artists and songs written under it, with their chords, keys and tabs. "
                                       (let ((written (assq-ref genre
                                                                'description)))
                                         (if (string? written) written "")))
                                      #:limit 300)))
    (html-template G_
                   #:is-logged-in is-logged-in
                   #:title page-title
                   #:description page-description
                   #:path genre-path
                   #:image (artwork-social-image artworks
                                                 #:fallback (announced-image))
                   #:image-alt (format #f "artwork for ~a" genre-name)
                   #:json-ld (list (page-json-ld #:type "CollectionPage"
                                                 #:url (absolute-url
                                                        genre-path)
                                                 #:name page-title
                                                 #:description
                                                 page-description
                                                 ;; schema.org defines no genre type, so the
                                                 ;; genre is described as the defined term it
                                                 ;; is, and the page -- which collects
                                                 ;; everything filed under it -- as the
                                                 ;; collection whose subject that term is.
                                                 #:main-entity (append (list (schema-name
                                                                              "DefinedTerm")
                                                                             (cons
                                                                              "name"
                                                                              genre-name))
                                                                       (if (string?
                                                                            (assq-ref
                                                                             genre
                                                                             'description))
                                                                           (list
                                                                            (cons
                                                                             "description"
                                                                             (summarize
                                                                              (assq-ref
                                                                               genre
                                                                               'description)
                                                                              #:limit
                                                                              300)))
                                                                           '()))))
                   #:body `((div (@ (class ,(mk-class '(px-3 py-2 md:px-6
                                                             md:py-4))))
                                 ((div (@ (class ,(mk-class '(py-4))))
                                       ,(h2 (assq-ref genre
                                                      'display-name)
                                            #:size '(text-3xl md:text-10)
                                            #:family '(font-sans)
                                            #:weight '(font-light leading-10)))
                                  (div (div ,(entity-details G_
                                                             #:entity 'genre
                                                             #:x genre
                                                             #:artworks
                                                             artworks
                                                             #:opinions
                                                             opinions
                                                             #:comments
                                                             comments
                                                             #:user-alist
                                                             user-alist)))))
                            ,(render-external-sources G_ external-sources)
                            ,song-fragment))))
