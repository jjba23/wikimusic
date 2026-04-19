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

(define-module (app views songs)
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
  #:use-module (app views song-contents)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun)
  #:export (render-song-tile song-list-page song-detail-page song-edit-page
                             song-new-page song-form))

(define* (render-song-tile G_
                           #:key artworks
                           song-version-count-alist
                           opinions
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
                                            (assoc-ref x "identifier"))))
         (this-song-artists-relations (map (lambda (aa)
                                             (assoc-ref aa "artist_identifier"))
                                           (filter (lambda (a)
                                                     (equal? (assoc-ref x
                                                              "identifier")
                                                             (assoc-ref a
                                                              "song_identifier")))
                                                   song-artists)))

         (art (filter (lambda (aaa)
                        (find (lambda (s)
                                (equal? s
                                        (assoc-ref aaa "identifier")))
                              this-song-artists-relations)) artists))

         (extra-top-info `((div (@ (class ,(mk-class '(py-2 text-center flex
                                                            flex-col gap-2
                                                            align-center))))
                                ,(map (lambda (ar)
                                        (a (assoc-ref ar "display_name")
                                           #:weight '(font-light)
                                           #:size '(text-md)
                                           #:href (format #f
                                                          "/artists/uuid/~a"
                                                          (assoc-ref ar
                                                           "identifier"))
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
                       (relevant-entities 'song opinions x)
                       (relevant-entities 'song comments x)
                       #:extra-top-info extra-top-info
                       #:extra-bot-info extra-bot-info)))))

(define* (song-list-page G_
                         #:key (only-tiles #f)
                         songs
                         artworks
                         song-version-count-alist
                         opinions
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

                             #:family '(font-serif))) ,(unless only-tiles
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
                                                            xl:grid-cols-5))))
                                ,(map (lambda (x)
                                        (render-song-tile G_
                                         #:artworks artworks
                                         #:song-version-count-alist
                                         song-version-count-alist
                                         #:opinions opinions
                                         #:comments comments
                                         #:artists artists
                                         #:song-artists song-artists
                                         #:x x)) songs))
                           ,page-buttons
                           ,(hr)
                           ,(unless only-tiles
                              `(div (@ (class ,(mk-class '(flex flex-row
                                                                flex-wrap
                                                                gap-2
                                                                justify-end))))
                                    (a (@ (href "/songs/new"))
                                       ,(button (G_ "new song"))))))))))
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
                                    `((div ,(a (assoc-ref ar "display_name")
                                               #:size '(text-lg)
                                               #:weight '(font-light)
                                               #:color '(text-onyx-300
                                                         dark:text-stone-100)
                                               #:hover '(hover:text-persia-pink-500
                                                         hover:dark:text-persia-pink-300
                                                         hover:underline)
                                               #:href (format #f
                                                       "/artists/uuid/~a"

                                                       (assoc-ref ar
                                                        "identifier"))))))
                                  artists))
         (genre-name-titles (map (lambda (ar)
                                   `((div ,(a (assoc-ref ar "display_name")
                                              #:size '(text-lg)
                                              #:weight '(font-light)
                                              #:color '(text-onyx-300
                                                        dark:text-stone-100)
                                              #:hover '(hover:text-persia-pink-500
                                                        hover:dark:text-persia-pink-300
                                                        hover:underline)
                                              #:href (format #f
                                                      "/genres/uuid/~a"

                                                      (assoc-ref ar
                                                                 "identifier"))))))
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
                                            ,(h2 (assoc-ref song
                                                            "display_name")
                                                 #:size '(text-3xl md:text-10)
                                                 #:family '(font-serif)
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
                                                                   (assoc-ref
                                                                    song
                                                                    "identifier")))))

                            (div ,(render-song-content G_ song song-contents
                                                       ascii-size))))))

(define* (song-edit-page G_
                         #:key song
                         song-contents
                         artworks
                         (artists '())
                         (genres '())
                         (external-sources '())
                         is-logged-in)
  (let* ((html `(div (@ (class ,(mk-class '())))
                     ,(if (assoc-ref song "identifier")
                          (h2 (format #f "~a: ~a"
                                      (G_ "editing song")
                                      (assoc-ref song "display_name")))
                          (h2 (G_ "new song")))
                     (details (@ (open true))
                              (summary (@ (class ,(mk-class '(font-black
                                                              text-onyx-300
                                                              dark:text-stone-300
                                                              text-md
                                                              cursor-pointer))))
                                       ,(G_ "edit artworks"))
                              ,(map (lambda (a)
                                      `(div (figure (@ (class ,(mk-class '(py-3
                                                                           sm:w-36))))
                                                    (img (@ (loading "lazy")
                                                            (class ,(mk-class '
                                                                              (rounded-xl
                                                                               max-w-full)))
                                                            (src ,(uri-decode (assoc-ref
                                                                               a
                                                                               "content_url"))))))
                                            ,(artwork-form G_
                                                           #:entity 'song
                                                           #:entity-identifier
                                                           (assoc-ref song
                                                            "identifier")
                                                           #:artwork-identifier
                                                           (assoc-ref a
                                                            "identifier")
                                                           #:content-url (uri-decode
                                                                          (assoc-ref
                                                                           a
                                                                           "content_url"))
                                                           #:content-caption (assoc-ref-or-empty-str
                                                                              a
                                                                              "content_caption")
                                                           #:order-value (assoc-ref
                                                                          a
                                                                          "order_value"))))
                                    artworks))
                     ,(hr)
                     (details (@ (open true)
                                 (class "cursor-pointer"))
                              (summary (@ (class ,(mk-class '(font-black
                                                              text-onyx-300
                                                              dark:text-stone-300
                                                              text-md))))
                                       ,(G_ "new artwork"))
                              ,(artwork-form G_
                                             #:entity 'song
                                             #:entity-identifier (assoc-ref
                                                                  song
                                                                  "identifier")))
                     ,(hr)
                     (details (@ (open true))
                              (summary (@ (class ,(mk-class '(font-black
                                                              text-onyx-300
                                                              dark:text-stone-300
                                                              text-md
                                                              cursor-pointer))))
                                       ,(G_ "editing song"))
                              ,(song-form G_
                                          #:identifier (assoc-ref song
                                                        "identifier")
                                          #:display-name (assoc-ref song
                                                          "display_name")
                                          #:music-key (assoc-ref-or-empty-str
                                                       song "music_key")
                                          #:music-tuning (assoc-ref-or-empty-str
                                                          song "music_tuning")
                                          #:music-creation-date (assoc-ref-or-empty-str
                                                                 song
                                                                 "music_creation_date")
                                          #:album-name (assoc-ref-or-empty-str
                                                        song "album_name")
                                          #:album-info-link (assoc-ref-or-empty-str
                                                             song
                                                             "album_info_link")
                                          #:description (assoc-ref-or-empty-str
                                                         song "description")))
                     ,(hr)
                     (details (@ (open true))
                              (summary (@ (class ,(mk-class '(font-black
                                                              text-onyx-300
                                                              dark:text-stone-300
                                                              text-md
                                                              cursor-pointer))))
                                       ,(G_ "editing external sources"))
                              ,(external-sources-form G_
                                                      #:entity 'song
                                                      #:entity-identifier (assoc-ref
                                                                           song
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
                                                                         "soundcloud_url"))))
                     ,(hr)
                     (details (@ (open true)
                                 (class ,(mk-class '(py-6))))
                              (summary (@ (class ,(mk-class '(font-black
                                                              text-onyx-300
                                                              dark:text-stone-300
                                                              text-md
                                                              cursor-pointer))))
                                       ,(G_ "song's artists"))
                              (div (@ (class ,(mk-class '(flex flex-col gap-2))))
                                   ,(h4 (G_ "add artist relation"))
                                   (form (@ (method POST)
                                            (content-type
                                             application/x-www-form-urlencoded)
                                            (action ,(format #f
                                                      "/songs/uuid/~a/artists"
                                                      (assoc-ref song
                                                                 "identifier"))))
                                         (div ,(input #:label "artist UUID"
                                                      #:name 'artist-identifier
                                                      #:value ""
                                                      #:required #t))
                                         (div ,(submit-button (G_ "submit")))))
                              (div (@ (class ,(mk-class '(flex flex-row
                                                               flex-wrap
                                                               gap-10 py-6))))
                                   ,(map (lambda (a)
                                           `((form (@ (method POST)
                                                      (content-type
                                                       application/x-www-form-urlencoded)
                                                      (action ,(format #f
                                                                "/songs/uuid/~a/artists/~a/delete"
                                                                (assoc-ref
                                                                 song
                                                                 "identifier")
                                                                (assoc-ref a
                                                                 "identifier"))))
                                                   (div (@ (class ,(mk-class '
                                                                             (flex
                                                                              flex-row
                                                                              flex-wrap
                                                                              gap-2
                                                                              items-center))))
                                                        ,(h4 (assoc-ref a
                                                              "display_name"))
                                                        ,(icon-button #:icon 'trash
                                                                      #:content
                                                                      ""
                                                                      #:type 'submit
                                                                      #:background '
                                                                      (bg-red-700)
                                                                      #:color '
                                                                      (text-stone-200)
                                                                      #:hover-background '
                                                                      (hover:bg-red-900))))))
                                         artists)))
                     ,(hr)
                     (details (@ (open true)
                                 (class ,(mk-class '(py-6))))
                              (summary (@ (class ,(mk-class '(font-black
                                                              text-onyx-300
                                                              dark:text-stone-300
                                                              text-md
                                                              cursor-pointer))))
                                       ,(G_ "song's genres"))
                              (div (@ (class ,(mk-class '(flex flex-col gap-2))))
                                   ,(h4 (G_ "add genre relation"))
                                   (form (@ (method POST)
                                            (content-type
                                             application/x-www-form-urlencoded)
                                            (action ,(format #f
                                                      "/songs/uuid/~a/genres"
                                                      (assoc-ref song
                                                                 "identifier"))))
                                         (div ,(input #:label "genre UUID"
                                                      #:name 'genre-identifier
                                                      #:value ""
                                                      #:required #t))
                                         (div ,(submit-button (G_ "submit")))))
                              (div (@ (class ,(mk-class '(flex flex-row
                                                               flex-wrap
                                                               gap-10 py-6))))
                                   ,(map (lambda (a)
                                           `((form (@ (method POST)
                                                      (content-type
                                                       application/x-www-form-urlencoded)
                                                      (action ,(format #f
                                                                "/songs/uuid/~a/genres/~a/delete"
                                                                (assoc-ref
                                                                 song
                                                                 "identifier")
                                                                (assoc-ref a
                                                                 "identifier"))))
                                                   (div (@ (class ,(mk-class '
                                                                             (flex
                                                                              flex-row
                                                                              flex-wrap
                                                                              gap-2
                                                                              items-center))))
                                                        ,(h4 (assoc-ref a
                                                              "display_name"))
                                                        ,(icon-button #:icon 'trash
                                                                      #:content
                                                                      ""
                                                                      #:type 'submit
                                                                      #:background '
                                                                      (bg-red-700)
                                                                      #:color '
                                                                      (text-stone-200)
                                                                      #:hover-background '
                                                                      (hover:bg-red-900))))))
                                         genres))))))
    (html-template G_
                   #:is-logged-in is-logged-in
                   #:body html)))

(define* (song-new-page G_
                        #:key is-logged-in)
  (html-template G_
                 #:is-logged-in is-logged-in
                 #:body `(div (@ (class ,(mk-class '())))
                              ,(song-form G_))))

(define* (song-form G_
                    #:key (identifier #f)
                    (display-name "")
                    (music-key "")
                    (music-tuning "")
                    (music-creation-date "")
                    (album-name "")
                    (album-info-link "")
                    (description ""))
  `((form (@ (method POST)
             (action ,(if identifier
                          (format #f "/songs/uuid/~a/edit" identifier)
                          "/songs/new"))
             (content-type application/x-www-form-urlencoded))
          (div ,(input #:label (G_ "display name")
                       #:name "display-name"
                       #:value (html-unescape display-name)
                       #:required #t)

               ,(input #:label (G_ "music key")
                       #:name "music-key"
                       #:value (html-unescape music-key))
               ,(input #:label (G_ "music tuning")
                       #:name "music-tuning"
                       #:value (html-unescape music-tuning))
               ,(input #:label (G_ "music creation date")
                       #:name "music-creation-date"
                       #:value (html-unescape music-creation-date))
               ,(input #:label (G_ "album name")
                       #:name "album-name"
                       #:value (html-unescape album-name))
               ,(input #:label (G_ "album info url")
                       #:name "album-info-link"
                       #:value (uri-decode album-info-link))
               ,(textarea #:label (G_ "description")
                          #:name "description"
                          #:value (html-unescape description)))
          (div ,(submit-button (if identifier
                                   (G_ "edit")
                                   (G_ "create")))))))

