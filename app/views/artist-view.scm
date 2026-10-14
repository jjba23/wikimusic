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

(define-module (app views artist-view)
  #:use-module (wikimusic html)
  #:use-module (wikimusic config)
  #:use-module (wikimusic seo)
  #:use-module (wikimusic domain)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (ice-9 i18n)
  #:use-module (kracht prelude)
  #:use-module (web uri)
  #:use-module (hygguile hygguile)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun)
  #:export (artist-list-page artist-detail-page))

(define* (artist-list-page G_
                           #:key artists
                           artworks
                           comments
                           limit
                           offset
                           search-query
                           user-sort
                           grid-size
                           pages
                           is-logged-in)
  (let* ((page (if (and limit (> limit 0)) (+ 1 (quotient offset limit)) 1))
         (searching? (and (string? search-query)
                          (not (string-null? search-query))))
         (list-title (if searching?
                         (format #f "Artists matching “~a” | WikiMusic" search-query)
                         "Artists: bands and musicians, with their songs and tabs | WikiMusic"))
         (list-description (if searching?
                               (format #f "Artists on WikiMusic matching “~a”, with their songs, tabs and chords."
                                       search-query)
                               "Every artist and band on WikiMusic, with the songs, guitar and bass tabs and chords written about them."))
         (page-buttons (if (and pages (> pages 1))
                           (pagination #:current page
                                       #:total pages
                                       #:base-url (format #f
                                                          "/artists?limit=~a&sort=~a~a&page="
                                                          limit (or user-sort "")
                                                          (if (and search-query
                                                                   (not (equal? search-query
                                                                                "")))
                                                              (format #f
                                                                      "&search=~a"
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
                                 ,(G_ "viewing artists:"))
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
                                                              #:entity 'artist
                                                              #:user-sort
                                                              user-sort)
                                                            ,(grid-size-select
                                                              G_
                                                              #:entity 'artist
                                                              #:size
                                                              grid-size
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
                      (div (div (@ (class ,(item-tile-grid-face
                                            #:size grid-size)))
                                ,(map (lambda (x)
                                        `(div ,(item-tile G_
                                                          'artist x
                                                          (relevant-entities 'artist
                                                           artworks x)
                                                          (relevant-entities 'artist
                                                           comments x))))
                                      artists))
                           ,page-buttons
                           ,(hr)
                           (div (@ (class ,(mk-class '(flex flex-row flex-wrap
                                                            gap-2 justify-end))))
                                (a (@ (href "/artists/new"))
                                   ,(button (G_ "new artist")))))))))
    (html-template G_
                   #:body body
                   #:title list-title
                   #:description list-description
                   #:path (if (and (= page 1) (not searching?)) "/artists" #f)
                   #:robots (if (or searching? (> page 1)) "noindex, follow" #f)
                   #:json-ld (list (page-json-ld #:type "CollectionPage"
                                                 #:url (if searching?
                                                          #f
                                                          (absolute-url "/artists"))
                                                 #:name list-title
                                                 #:description list-description))
                   #:is-logged-in is-logged-in)))

(define* (artist-detail-page G_
                             #:key artist
                             artworks
                             opinions
                             comments
                             user-alist
                             song-fragment
                             external-sources
                             is-logged-in)
  (let* ((artist-name (assq-ref artist 'display-name))
         (artist-path (format #f "/artists/uuid/~a" (assq-ref artist 'identifier)))
         (page-title (format #f "~a — songs, guitar tabs & chords | WikiMusic"
                             artist-name))
         (page-description (summarize
                            (string-append
                             artist-name
                             " on WikiMusic: the songs written about them, with their chords, keys and tabs. "
                             (let ((written (assq-ref artist 'description)))
                               (if (string? written) written "")))
                            #:limit 300)))
    (html-template G_
                 #:is-logged-in is-logged-in
                 #:title page-title
                 #:description page-description
                 #:path artist-path
                 #:image (artwork-social-image artworks
                                              #:fallback
                                              (social-image-url))
                 #:image-alt (format #f "artwork for ~a" artist-name)
                 #:og-type "profile"
                 #:json-ld (list (page-json-ld
                                  #:type "ProfilePage"
                                  #:url (absolute-url artist-path)
                                  #:name page-title
                                  #:description page-description
                                  #:main-entity
                                  (append (list (schema-name "MusicGroup")
                                                (cons "name" artist-name))
                                          (if (string? (assq-ref artist 'description))
                                              (list (cons "description"
                                                          (summarize (assq-ref artist 'description)
                                                                     #:limit 300)))
                                              '()))))
                 #:body `((div (@ (class ,(mk-class '(px-3 py-2 md:px-6
                                                           md:py-4))))
                               ((div (@ (class ,(mk-class '(py-4))))
                                     ,(h2 (assq-ref artist
                                                    'display-name)
                                          #:size '(text-3xl md:text-10)
                                          #:family '(font-sans)
                                          #:weight '(font-light leading-10)))
                                (div (div ,(entity-details G_
                                                           #:entity 'artist
                                                           #:x artist
                                                           #:artworks artworks
                                                           #:opinions opinions
                                                           #:comments comments
                                                           #:user-alist
                                                           user-alist)))))
                          ,(render-external-sources G_ external-sources)
                          (div ,song-fragment)))))
