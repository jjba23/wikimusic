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

(define-module (app views songs)
  #:use-module (wikimusic html)
  #:use-module (wikimusic abstraction)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (hygguile abstraction)
  #:use-module (hygguile components input)
  #:use-module (hygguile components button)
  #:use-module (ice-9 i18n)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun))

(define (render-song-tile G_
                          artworks
                          song-version-count-alist
                          opinions
                          comments
                          x)
  (let ((extra-info (cond-render (lambda (vc)
                                   `(div (@ (class
                                             "flex flex-row gap-2 text-xs"))

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

(define-public (songs-list-page G_
                                songs
                                artworks
                                song-version-count-alist
                                opinions
                                comments)
  (html-template G_
                 #:body `(div (@ (class "container mx-auto"))
                              ((h2 (@ (class
                                       "font-black text-stone-800 text-md"))
                                   ,(G_ "viewing songs"))
                               (div (div (@ (class
                                             "flex flex-row flex-wrap gap-3 items-center"))
                                         ,(map (lambda (x)
                                                 (render-song-tile G_
                                                  artworks
                                                  song-version-count-alist
                                                  opinions
                                                  comments
                                                  x)) songs)))))))

(define-public (songs-detail-page G_
                                  song
                                  artworks
                                  song-contents
                                  opinions
                                  comments
                                  user-alist)
  (html-template G_
                 #:body `((div (@ (class "container mx-auto"))
                               ((h2 (@ (class
                                        "font-black text-stone-800 text-xl"))
                                    ,(assoc-ref song "display_name"))
                                (div (div ,(entity-details G_
                                                           'song
                                                           song
                                                           artworks
                                                           opinions
                                                           comments
                                                           user-alist)))))
                          (div ,(render-song-contents G_ song song-contents)))))

(define-public (render-song-contents G_ song song-contents)
  `(div (@ (class "flex flex-col gap-6"))
        ,(map (lambda (version)
                `((hr)
                  (details (@ (open "true")
                              (class "cursor-pointer"))
                           (summary (@ (class "p-6"))
                                    ,(cond-render (lambda (version-name)
                                                    `(div (@ (class
                                                              "flex flex-row flex-wrap gap-4"))
                                                          (span (@ (class
                                                                    "text-xl font-bold text-stone-700"))
                                                                ,(G_ "version"))
                                                          (span (@ (class
                                                                    "text-xl font-bold text-stone-700"))
                                                                ,version-name)
                                                          ,(cond-render (lambda 
                                                                                (instrument-type)
                                                                          `(span
                                                                            (@
                                                                             (class
                                                                              "text-xl font-bold text-stone-700"))
                                                                            ,instrument-type))
                                                                        (assoc-ref
                                                                         version
                                                                         "instrument_type"))))
                                                  (assoc-ref version
                                                             "version_name")))
                           (div (@ (class "p-4"))

                                ,(cond-render (lambda (ascii-legend)
                                                `(div (span (@ (class
                                                                "text-xl font-bold text-stone-700"))
                                                            ,(G_
                                                              "ascii legend"))
                                                      (pre (@ (class
                                                               "p-6 m-4 bg-stone-200/75 text-black rounded-xl white-space-pre overflow-x-scroll text-sm"))
                                                           ,ascii-legend)))
                                              (assoc-ref version
                                                         "ascii_legend"))
                                ,(cond-render (lambda (ascii-contents)
                                                `(div (span (@ (class
                                                                "text-xl font-bold text-stone-700"))
                                                            ,(G_
                                                              "ascii contents"))
                                                      (pre (@ (class
                                                               "p-6 m-4 bg-stone-200/75 text-black rounded-xl white-space-pre overflow-x-scroll text-sm"))
                                                           ,ascii-contents)))
                                              (assoc-ref version
                                                         "ascii_contents"))))))
              song-contents)))

(begin
  (define* (song-edit-page G_ song song-contents artworks)
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
                                                                      #:entity 'song
                                                                      #:entity-identifier
                                                                      (assoc-ref
                                                                       song
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
                                                        #:entity 'song
                                                        #:entity-identifier (assoc-ref
                                                                             song
                                                                             "identifier")))
                                (hr (@ (class "my-6")))
                                (details (@ (class "cursor-pointer"))
                                         (summary (@ (class
                                                      "font-black text-stone-800 text-md"))
                                                  ,(G_ "editing song"))
                                         ,(song-form G_
                                                     #:display-name (assoc-ref
                                                                     song
                                                                     "display_name")
                                                     #:music-key (assoc-ref-or-empty-str
                                                                  song
                                                                  "music_key")
                                                     #:music-tuning (assoc-ref-or-empty-str
                                                                     song
                                                                     "music_tuning")
                                                     #:music-creation-date (assoc-ref-or-empty-str
                                                                            song
                                                                            "music_creation_date")
                                                     #:album-name (assoc-ref-or-empty-str
                                                                   song
                                                                   "album_name")
                                                     #:album-info-link (assoc-ref-or-empty-str
                                                                        song
                                                                        "album_info_link")
                                                     #:description (assoc-ref-or-empty-str
                                                                    song
                                                                    "description"))))))
  (export song-edit-page))

(begin
  (define* (song-form G_
                      #:key (display-name "")
                      (music-key "")
                      (music-tuning "")
                      (music-creation-date "")
                      (album-name "")
                      (album-info-link "")
                      (description ""))
    `((form (@ (method POST)
               (content-type application/x-www-form-urlencoded))
            (div ,(mk-input #:label (G_ "display name")
                            #:name "display-name"
                            #:value display-name
                            #:required #t)
                 ,(mk-input #:label (G_ "music key")
                            #:name "music-key"
                            #:value music-key)
                 ,(mk-input #:label (G_ "music tuning")
                            #:name "music-tuning"
                            #:value music-tuning)
                 ,(mk-input #:label (G_ "music creation date")
                            #:name "music-creation-date"
                            #:value music-creation-date)
                 ,(mk-input #:label (G_ "album name")
                            #:name "album-name"
                            #:value album-name)
                 ,(mk-input #:label (G_ "album info url")
                            #:name "album-info-link"
                            #:value album-info-link)
                 ,(mk-textarea #:label (G_ "description")
                               #:name "description"
                               #:value description)))
      (div ,(success-submit-button #:content (G_ "edit")))))
  (export song-form))

