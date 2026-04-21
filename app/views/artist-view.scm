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
                           is-logged-in)
  (let* ((page-buttons `((div (@ (class ,(mk-class '(flex flex-row flex-wrap
                                                          gap-3 my-4))))
                              ,(if (> offset 0)
                                   `((a (@ (href ,(format #f
                                                   "/artists?offset=~a&limit=~a"
                                                   (- offset limit) limit)))
                                        ,(icon-button #:icon 'arrow-left
                                                      #:content (G_ "previous"))))
                                   '())
                              ,(if (= (length artists) limit)
                                   `((a (@ (href ,(format #f
                                                   "/artists?offset=~a&limit=~a"
                                                   (+ offset limit) limit)))
                                        ,(icon-button #:icon 'arrow-right
                                                      #:content (G_ "next"))))
                                   '()))))
         (body `(div (@ (class ,(mk-class '(px-4 md:px-8
                                                 py-2
                                                 flex
                                                 flex-col
                                                 md:flex-row
                                                 md:flex-wrap
                                                 gap-3
                                                 md:gap-5
                                                 items-center
                                                 align-center
                                                 justify-center
                                                 md:justify-between))))
                     (,(h4 `(div (@ (class ,(mk-class '(flex flex-row
                                                             items-center
                                                             align-center
                                                             gap-1))))
                                 ,(G_ "viewing artists:"))
                           #:weight '(font-light)
                           #:size '(text-2xl)
                           #:family '(font-serif)) (div (@ (class ,(mk-class '
                                                                             (flex
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
                                                               user-sort))
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
                      (div (div (@ (class ,(mk-class '(grid gap-3
                                                            sm:grid-cols-2
                                                            md:grid-cols-3
                                                            lg:grid-cols-4
                                                            xl:grid-cols-6))))
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
  (html-template G_
                 #:is-logged-in is-logged-in
                 #:body `((div (@ (class ,(mk-class '(px-3 py-2 md:px-6
                                                           md:py-4))))
                               ((div (@ (class ,(mk-class '(py-4))))
                                     ,(h2 (assq-ref artist
                                                    'display-name)
                                          #:size '(text-3xl md:text-10)
                                          #:family '(font-serif)
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
                          (div ,song-fragment))))

