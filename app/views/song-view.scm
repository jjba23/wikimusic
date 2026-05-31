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

(define-module (app views song-view)
  #:use-module (wikimusic html)
  #:use-module (wikimusic domain)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (hygguile hygguile)
  #:use-module (kracht prelude)
  #:use-module (web uri)
  #:use-module (ice-9 i18n)
  #:use-module (srfi srfi-1)
  #:use-module (app views song-content-edit)
  #:use-module (app views song-content-view)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun)
  #:export (render-song-tile song-list-page song-detail-page))

(define* (render-song-tile G_
                           #:key artworks
                           song-version-count-alist
                           comments
                           artists
                           song-artists
                           x)
  (let* ((extra-bot-info (render-if-nempty (lambda (vc)
                                             `((div (@ (class ,(mk-class '(flex
                                                                           flex-row
                                                                           gap-2
                                                                           justify-center
                                                                           align-center))))
                                                    ,(em (format #f "~a ~a"
                                                                 (car vc)
                                                                 (G_
                                                                  "versions"))
                                                         #:size '(text-sm)
                                                         #:color '(text-onyx-300
                                                                   dark:text-stone-300)))))
                                           (assoc-ref song-version-count-alist
                                            (assq-ref x
                                                      'identifier))))
         (respective (filter (lambda (a)
                               (equal? (assq-ref x
                                                 'identifier)
                                       (assq-ref a
                                                 'song-identifier)))
                             song-artists))
         (this-song-artists-relations (map (lambda (aa)
                                             (assq-ref aa
                                                       'artist-identifier))
                                           respective))
         (art (filter (lambda (aaa)
                        (find (lambda (s)
                                (equal? s
                                        (assq-ref aaa
                                                  'identifier)))
                              this-song-artists-relations)) artists))

         (extra-top-info `((div (@ (class ,(mk-class '(py-2 text-center flex
                                                            flex-col gap-2
                                                            align-center))))
                                ,(map (lambda (ar)
                                        (a (assq-ref ar
                                                     'display-name)
                                           #:weight '(font-light)
                                           #:size '(text-md)
                                           #:href (format #f
                                                          "/artists/uuid/~a"
                                                          (assq-ref ar
                                                                    'identifier))
                                           #:color '(text-onyx-300
                                                     dark:text-stone-100)
                                           #:hover '(hover:text-persia-pink-900
                                                     hover:dark:text-persia-pink-300)))
                                      art))))

         )
    `((div ,(item-tile G_
                       'song
                       x
                       (relevant-entities 'song artworks x)
                       (relevant-entities 'song comments x)
                       #:extra-top-info extra-top-info
                       #:extra-bot-info extra-bot-info)))))

(define* (song-list-page G_
                         #:key (only-tiles #f)
                         songs
                         artworks
                         song-version-count-alist
                         comments
                         artists
                         song-artists
                         limit
                         offset
                         search-query
                         user-sort
                         is-logged-in)
  (let* ((page-buttons `((div (@ (class ,(mk-class '(flex flex-row flex-wrap
                                                          gap-3 my-4))))
                              ,(if (> offset 0)
                                   `((a (@ (href ,(format #f
                                                   "/songs?offset=~a&limit=~a"
                                                   (- offset limit) limit)))
                                        ,(icon-button #:icon 'arrow-left
                                                      #:content (G_ "previous"))))
                                   '())
                              ,(if (and (> limit 0)
                                        (= (length songs) limit))
                                   `((a (@ (href ,(format #f
                                                   "/songs?offset=~a&limit=~a"
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
                     (,(unless only-tiles
                         (h4 `(div (@ (class ,(mk-class '(flex flex-row
                                                               items-center
                                                               align-center
                                                               gap-1))))
                                   ,(G_ "viewing songs:"))
                             #:weight '(font-light)
                             #:size '(text-2xl)

                             #:family '(font-sans))) ,(unless only-tiles
                                                         `(div (@ (class ,(mk-class '
                                                                           (flex
                                                                            flex-wrap
                                                                            flex-row
                                                                            justify-center
                                                                            gap-2))))
                                                               (div (@ (class ,
                                                                              (mk-class '
                                                                               (flex
                                                                                flex-wrap
                                                                                flex-row
                                                                                justify-start
                                                                                items-center))))
                                                                    ,(sort-select
                                                                      G_
                                                                      #:entity 'song
                                                                      #:user-sort
                                                                      user-sort))
                                                               (div (@ (class ,
                                                                              (mk-class '
                                                                               (flex
                                                                                flex-wrap
                                                                                flex-row
                                                                                gap-3
                                                                                justify-right
                                                                                items-center))))

                                                                    ,(search-box
                                                                      G_
                                                                      #:search-query
                                                                      search-query))))
                      (div (div (@ (class ,(mk-class '(grid gap-4
                                                            sm:grid-cols-2
                                                            md:grid-cols-3
                                                            lg:grid-cols-4
                                                            xl:grid-cols-6))))
                                ,(map (lambda (x)
                                        (render-song-tile G_
                                         #:artworks artworks
                                         #:song-version-count-alist
                                         song-version-count-alist
                                         #:comments comments
                                         #:artists artists
                                         #:song-artists song-artists
                                         #:x x)) songs))
                           ,page-buttons

                           ,(unless only-tiles
                              `(,(hr) (div (@ (class ,(mk-class '(flex
                                                                  flex-row
                                                                  flex-wrap
                                                                  gap-2
                                                                  justify-end))))
                                           (a (@ (href "/songs/new"))
                                              ,(button (G_ "new song")))))))))))
    (if only-tiles body
        (html-template G_
                       #:is-logged-in is-logged-in
                       #:body body))))

(define* (song-detail-page G_
                           #:key song
                           artworks
                           song-contents
                           song-artists
                           artists
                           song-genres
                           genres
                           opinions
                           comments
                           user-alist
                           (ascii-size 'text-md)
                           external-sources
                           is-logged-in)

  (let* ((artist-name-titles (map (lambda (ar)
                                    `((div ,(a (assq-ref ar
                                                         'display-name)
                                               #:size '(text-lg)
                                               #:weight '(font-light)
                                               #:color '(text-onyx-300
                                                         dark:text-stone-100)
                                               #:hover '(hover:text-persia-pink-500
                                                         hover:dark:text-persia-pink-300
                                                         hover:underline)
                                               #:href (format #f
                                                       "/artists/uuid/~a"

                                                       (assq-ref ar
                                                                 'identifier))))))
                                  artists))
         (genre-name-titles (map (lambda (ar)
                                   `((div ,(a (assoc-ref ar
                                                         'display-name)
                                              #:size '(text-lg)
                                              #:weight '(font-light)
                                              #:color '(text-onyx-300
                                                        dark:text-stone-100)
                                              #:hover '(hover:text-persia-pink-500
                                                        hover:dark:text-persia-pink-300
                                                        hover:underline)
                                              #:href (format #f
                                                      "/genres/uuid/~a"

                                                      (assq-ref ar
                                                                'identifier))))))
                                 genres))
         (song-attributes `((div (@ (class ,(mk-class '(px-4 py-6 container
                                                             mx-auto))))
                                 (dl ,(render-if-nestring (lambda (tuning)
                                                            (list (dt (G_
                                                                       "tuning"))
                                                                  (dd tuning)))
                                                          (assoc-ref song
                                                           "music_tuning"))
                                     ,(render-if-nestring (lambda (keyy)
                                                            (list (dt (G_
                                                                       "music key"))
                                                                  (dd keyy)))
                                                          (assoc-ref song
                                                           "music_key"))
                                     ,(render-if-nestring (lambda (music-creation-date)
                                                            (list (dt (G_
                                                                       "music creation date"))
                                                                  (dd
                                                                   music-creation-date)))
                                                          (assoc-ref song
                                                           "music_creation_date"))
                                     ,(render-if-nestring (lambda (album-name)
                                                            (list (dt (G_
                                                                       "album name"))
                                                                  (dd
                                                                   album-name)))
                                                          (assoc-ref song
                                                           "album_name"))
                                     ,(render-if-nestring (lambda (album-link)
                                                            (list (dt (G_
                                                                       "album info link"))
                                                                  (dd (a (uri-decode
                                                                          album-link)))))
                                                          (assoc-ref song
                                                           "album_info_link")))))))
    (html-template G_
                   #:is-logged-in is-logged-in
                   #:body `((div (@ (class ,(mk-class '(px-3 py-2 md:px-6
                                                             md:py-4))))
                                 ((div (@ (class ,(mk-class '(flex flex-col
                                                                   gap-4))))
                                       (div (@ (class ,(mk-class '(py-4))))
                                            ,(h2 (assq-ref song
                                                           'display-name)
                                                 #:size '(text-3xl md:text-10)
                                                 #:family '(font-sans)
                                                 #:weight '(font-light
                                                            leading-10)))
                                       ,(when (not (nil? artists))
                                          `((div (@ (class ,(mk-class '(flex
                                                                        flex-row
                                                                        flex-wrap
                                                                        gap-4
                                                                        items-center
                                                                        align-center
                                                                        justify-start))))
                                                 ,(em "by:")
                                                 ,artist-name-titles)))
                                       ,(when (not (nil? genres))
                                          `((div (@ (class ,(mk-class '(flex
                                                                        flex-row
                                                                        flex-wrap
                                                                        gap-4
                                                                        items-center
                                                                        align-center
                                                                        justify-start))))
                                                 ,(em "genres:")
                                                 ,genre-name-titles))))

                                  (div (div ,(entity-details G_
                                                             #:entity 'song
                                                             #:x song
                                                             #:artworks
                                                             artworks
                                                             #:opinions
                                                             opinions
                                                             #:comments
                                                             comments
                                                             #:user-alist
                                                             user-alist)))))
                            ,(render-external-sources G_ external-sources)
                            (div song-attributes
                                 (div (@ (class ,(mk-class '(py-1 px-5))))
                                      ,(sub-h4 (G_ "musical content pref:"))
                                      ,(ascii-size-select G_
                                                          #:route (format #f
                                                                   "/~as/uuid/~a"
                                                                   'song
                                                                   (assq-ref
                                                                    song
                                                                    'identifier)))))

                            (div ,(render-song-content G_ song song-contents
                                                       ascii-size))))))
