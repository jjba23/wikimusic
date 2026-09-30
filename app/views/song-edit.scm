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

(define-module (app views song-edit)
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
  #:export (song-edit-page song-new-page song-form))

(define* (song-edit-page G_
                         #:key song
                         song-contents
                         artworks
                         (artists '())
                         (genres '())
                         (external-sources '())
                         is-logged-in)
  (let* ((html `(div (@ (class ,(mk-class '(px-2 py-4))))
                     (div (@ (class ,(mk-class '(py-3))))
                          ,(if (assq-ref song
                                         'identifier)
                               (h2 (format #f "~a: ~a"
                                           (G_ "editing song")
                                           (assq-ref song
                                                     'display-name)))
                               (h2 (G_ "new song"))))
                     (details (summary (@ (class ,(mk-class '(font-black
                                                              text-onyx-300
                                                              dark:text-stone-300
                                                              text-md
                                                              cursor-pointer))))
                                       ,(G_ "edit artworks"))
                              ,(map (lambda (a)
                                      `(div (figure (@ (class ,(mk-class '(py-3
                                                                           sm:w-36))))
                                                    (img (@ (loading lazy)
                                                            (class ,(mk-class '
                                                                              (rounded-xl
                                                                               max-w-full)))
                                                            (src ,(uri-decode (assq-ref
                                                                               a
                                                                               'content-url))))))
                                            ,(artwork-form G_
                                                           #:entity 'song
                                                           #:entity-identifier
                                                           (assoc-ref song
                                                                      'identifier)
                                                           #:artwork-identifier
                                                           (assoc-ref a
                                                                      'identifier)
                                                           #:content-url (uri-decode
                                                                          (assq-ref
                                                                           a
                                                                           'content-url))
                                                           #:content-caption (assoc-ref-or-empty-str
                                                                              a
                                                                              'content-caption)
                                                           #:order-value (assq-ref
                                                                          a
                                                                          'order-value))))
                                    artworks))
                     ,(hr)
                     (details (@ (class "cursor-pointer"))
                              (summary (@ (class ,(mk-class '(font-black
                                                              text-onyx-300
                                                              dark:text-stone-300
                                                              text-md))))
                                       ,(G_ "new artwork"))
                              ,(artwork-form G_
                                             #:entity 'song
                                             #:entity-identifier (assq-ref
                                                                  song
                                                                  'identifier)))
                     ,(hr)
                     (details (@ (open true))
                              (summary (@ (class ,(mk-class '(font-black
                                                              text-onyx-300
                                                              dark:text-stone-300
                                                              text-md
                                                              cursor-pointer))))
                                       ,(G_ "editing song"))
                              ,(song-form G_
                                          #:identifier (assq-ref song
                                                                 'identifier)
                                          #:display-name (assq-ref song
                                                                   'display-name)
                                          #:music-key (assoc-ref-or-empty-str
                                                       song
                                                       'music-key)
                                          #:music-tuning (assoc-ref-or-empty-str
                                                          song
                                                          'music-tuning)
                                          #:music-creation-date (assoc-ref-or-empty-str
                                                                 song
                                                                 'music-creation-date)
                                          #:album-name (assoc-ref-or-empty-str
                                                        song
                                                        'album-name)
                                          #:album-info-link (assoc-ref-or-empty-str
                                                             song
                                                             'album-info-link)
                                          #:description (assoc-ref-or-empty-str
                                                         song
                                                         'description)))
                     ,(hr)
                     (details (summary (@ (class ,(mk-class '(font-black
                                                              text-onyx-300
                                                              dark:text-stone-300
                                                              text-md
                                                              cursor-pointer))))
                                       ,(G_ "editing external sources"))
                              ,(external-sources-form G_
                                                      #:entity 'song
                                                      #:entity-identifier (assq-ref
                                                                           song
                                                                           'identifier)
                                                      #:external-sources-identifier
                                                      (assq-ref
                                                       external-sources
                                                       'identifier)
                                                      #:wikipedia-url (uri-decode
                                                                       (assoc-ref-or-empty-str
                                                                        external-sources
                                                                        'wikipedia-url))
                                                      #:spotify-url (uri-decode
                                                                     (assoc-ref-or-empty-str
                                                                      external-sources
                                                                      'spotify-url))
                                                      #:youtube-url (uri-decode
                                                                     (assoc-ref-or-empty-str
                                                                      external-sources
                                                                      'youtube-url))
                                                      #:soundcloud-url (uri-decode
                                                                        (assoc-ref-or-empty-str
                                                                         external-sources
                                                                         'soundcloud-url))))
                     ,(hr)
                     (details (summary (@ (class ,(mk-class '(font-black
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
                                                      (assq-ref song
                                                                'identifier))))
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
                                                                (assq-ref song
                                                                 'identifier)
                                                                (assq-ref a
                                                                          'identifier))))
                                                   (div (@ (class ,(mk-class '
                                                                             (flex
                                                                              flex-row
                                                                              flex-wrap
                                                                              gap-2
                                                                              items-center))))
                                                        ,(h4 (assq-ref a
                                                                       'display-name))
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
                     (details (summary (@ (class ,(mk-class '(font-black
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
                                                      (assq-ref song
                                                                'identifier))))
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
                                                                (assq-ref song
                                                                 'identifier)
                                                                (assq-ref a
                                                                          'identifier))))
                                                   (div (@ (class ,(mk-class '
                                                                             (flex
                                                                              flex-row
                                                                              flex-wrap
                                                                              gap-2
                                                                              items-center))))
                                                        ,(h4 (assq-ref a
                                                                       'display-name))
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

