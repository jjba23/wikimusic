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

(define-module (app views songs)
  #:use-module (wikimusic html)
  #:use-module (wikimusic domain)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (hygguile hygguile)
  #:use-module (kracht prelude)
  #:use-module (ice-9 i18n)
  #:use-module (wikimusic query-escape)
  #:use-module (app views song-contents)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun))

(define (render-song-tile G_
                          artworks
                          song-version-count-alist
                          opinions
                          comments
                          x)
  (let* ((extra-info (render-if-nempty (lambda (vc)
                                         `(div (@ (class ,(mk-class '(flex
                                                                      flex-row
                                                                      gap-2
                                                                      text-xs
                                                                      text-stone-700))))

                                               (span ,(format #f "~a"

                                                              (car vc)))
                                               (span ,(G_ "versions"))))
                                       (assoc-ref song-version-count-alist
                                                  (assoc-ref x "identifier")))))
    `((div ,(item-tile G_
                       'song
                       x
                       (relevant-entities 'song artworks x)
                       (relevant-entities 'song opinions x)
                       (relevant-entities 'song comments x)
                       #:extra-info extra-info)))))

(begin
  (define* (songs-list-page G_
                            #:key songs
                            artworks
                            song-version-count-alist
                            opinions
                            comments
                            limit
                            offset
                            search-query
                            user-sort)
    (let* ((page-buttons `((div (@ (class ,(mk-class '(flex flex-row flex-wrap
                                                            gap-3 my-4))))
                                ,(if (> offset 0)
                                     `((a (@ (href ,(format #f
                                                     "/songs?offset=~a&limit=~a"
                                                     (- offset limit) limit)))
                                          ,(icon-button #:icon 'arrow-left
                                                        #:content (G_
                                                                   "previous"))))
                                     '())
                                ,(if (= (length songs) limit)
                                     `((a (@ (href ,(format #f
                                                     "/songs?offset=~a&limit=~a"
                                                     (+ offset limit) limit)))
                                          ,(icon-button #:icon 'arrow-right
                                                        #:content (G_ "next"))))
                                     '()))))
           (body `(div (@ (class ,(mk-class '(container mx-auto))))
                       ((h2 (@ (class ,(mk-class '(font-black text-stone-800
                                                              text-2xl
                                                              py-4
                                                              px-1
                                                              flex
                                                              flex-row
                                                              items-center
                                                              gap-1))))
                            ,(icon #:type 'music-notes-simple)
                            ,(G_ "viewing songs"))
                        (div (@ (class ,(mk-class '(flex flex-wrap flex-row
                                                         justify-between))))
                             (div (@ (class ,(mk-class '(flex flex-wrap
                                                              flex-row
                                                              justify-start
                                                              items-center))))
                                  ,(sort-select G_
                                                #:entity 'song
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
                                          (render-song-tile G_
                                           artworks
                                           song-version-count-alist
                                           opinions
                                           comments
                                           x)) songs))
                             ,page-buttons
                             (hr (@ (class ,(mk-class '(my-6)))))
                             (div (@ (class ,(mk-class '(flex flex-row
                                                              flex-wrap gap-2
                                                              justify-end))))
                                  (a (@ (href "/songs/new"))
                                     ,(button (G_ "new song")))))))))
      (html-template G_
                     #:body body)))
  (export songs-list-page))

(define-public (songs-detail-page G_
                                  song
                                  artworks
                                  song-contents
                                  opinions
                                  comments
                                  user-alist
                                  ascii-size)
  (html-template G_
                 #:body `((div (@ (class ,(mk-class '(container mx-auto))))
                               ((h2 (@ (class ,(mk-class '(font-black
                                                           text-stone-800
                                                           text-3xl))))
                                    ,(assoc-ref song "display_name"))
                                
                                (div (div ,(entity-details G_
                                                           'song
                                                           song
                                                           artworks
                                                           opinions
                                                           comments
                                                           user-alist)))))
                          
                          (div ,(render-song-contents G_ song song-contents
                                                      ascii-size)))))

(begin
  (define* (song-edit-page G_ song song-contents artworks)
    (let* ((html `(div (@ (class "container mx-auto"))
                       ,(if (assoc-ref song "identifier")
                            `(h2 (@ (class ,(mk-class '(text-2xl my-6
                                                        font-bold
                                                        text-stone-800))))
                                 ,(format #f "~a: ~a"
                                          (G_ "editing song")
                                          (assoc-ref song "display_name")))
                            `(h2 (@ (class ,(mk-class '(text-2xl my-6
                                                        font-bold
                                                        text-stone-800))))
                                 (G_ "new song")))
                       (details (@ (open true))
                                (summary (@ (class ,(mk-class '(font-black
                                                                text-stone-800
                                                                text-md
                                                                cursor-pointer))))
                                         ,(G_ "edit artworks"))
                                ,(map (lambda (a)
                                        `(div (figure (@ (class ,(mk-class '(py-3
                                                                             sm:w-36))))
                                                      (img (@ (loading "lazy")
                                                              (class
                                                               "rounded-xl")
                                                              (src ,(assoc-ref
                                                                     a
                                                                     "content_url")))))
                                              ,(artwork-form G_
                                                             #:entity 'song
                                                             #:entity-identifier
                                                             (assoc-ref song
                                                              "identifier")
                                                             #:artwork-identifier
                                                             (assoc-ref a
                                                              "identifier")
                                                             #:content-url (assoc-ref
                                                                            a
                                                                            "content_url")
                                                             #:content-caption
                                                             (assoc-ref-or-empty-str
                                                              a
                                                              "content_caption")
                                                             #:order-value (assoc-ref
                                                                            a
                                                                            "order_value"))))
                                      artworks))
                       (hr (@ (class "my-6")))
                       (details (@ (open true)
                                   (class "cursor-pointer"))
                                (summary (@ (class ,(mk-class '(font-black
                                                                text-stone-800
                                                                text-md))))
                                         ,(G_ "new artwork"))
                                ,(artwork-form G_
                                               #:entity 'song
                                               #:entity-identifier (assoc-ref
                                                                    song
                                                                    "identifier")))
                       (hr (@ (class "my-6")))
                       (details (@ (open true))
                                (summary (@ (class ,(mk-class '(font-black
                                                                text-stone-800
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
                                                            song
                                                            "music_tuning")
                                            #:music-creation-date (assoc-ref-or-empty-str
                                                                   song
                                                                   "music_creation_date")
                                            #:album-name (assoc-ref-or-empty-str
                                                          song "album_name")
                                            #:album-info-link (assoc-ref-or-empty-str
                                                               song
                                                               "album_info_link")
                                            #:description (assoc-ref-or-empty-str
                                                           song "description"))))))
      (html-template G_
                     #:body html)))
  (export song-edit-page))

(begin
  (define* (song-new-page G_)
    (html-template G_
                   #:body `(div (@ (class ,(mk-class '(container mx-auto))))
                                ,(song-form G_))))
  (export song-new-page))

(begin
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
                            (format #f "/songs/new" identifier)))
               (content-type application/x-www-form-urlencoded))
            (div ,(input #:label (G_ "display name")
                         #:name "display-name"
                         #:value (unescape-str display-name)
                         #:required #t)

                 ,(input #:label (G_ "music key")
                         #:name "music-key"
                         #:value (unescape-str music-key))
                 ,(input #:label (G_ "music tuning")
                         #:name "music-tuning"
                         #:value (unescape-str music-tuning))
                 ,(input #:label (G_ "music creation date")
                         #:name "music-creation-date"
                         #:value (unescape-str music-creation-date))
                 ,(input #:label (G_ "album name")
                         #:name "album-name"
                         #:value (unescape-str album-name))
                 ,(input #:label (G_ "album info url")
                         #:name "album-info-link"
                         #:value (unescape-str album-info-link))
                 ,(textarea #:label (G_ "description")
                            #:name "description"
                            #:value (unescape-str description))))
      (div ,(submit-button (if identifier
                               (G_ "edit")
                               (G_ "create"))))))
  (export song-form))

