;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (app views song-view)
  #:use-module (wikimusic html)
  #:use-module (wikimusic config)
  #:use-module (wikimusic seo)
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
  #:use-module (wikimusic guitarpro)
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
                                                                           items-center))))
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
                                                            items-center))))
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
                                                     dark:hover:text-persia-pink-300)))
                                      art))))

         )
    `((div ,(item-tile G_
                       'song
                       x
                       (relevant-entities 'song artworks x)
                       (relevant-entities 'song comments x)
                       #:extra-top-info extra-top-info
                       #:extra-bot-info extra-bot-info)))))

;; The tempo a page's metronome is offered at: the tempo the first readable tab
;; among a song's VERSIONS declares, or #f when none of them says.
;;
;; A reader practising from a tab wants the click at the tab's own tempo, which
;; is a number the page already lists beside the download -- so it is read from
;; the versions rather than asked for again.  Versions are asked in turn because
;; a song may carry several and only some of them are Guitar Pro files; one that
;; carries no tab, or a file whose header cannot be read, is passed over.
(define (first-tab-tempo versions)
  "Return the tempo the first readable tab among VERSIONS declares, or #f."
  (let loop
    ((rest versions))
    (if (null? rest) #f
        (let* ((url (assq-ref (car rest)
                              'guitarpro-contents))
               (metadata (and (string? url)
                              (gp5-metadata-of-data-url url))))
          (or (and metadata
                   (assq-ref metadata
                             'tempo))
              (loop (cdr rest)))))))

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
                         grid-size
                         pages
                         is-logged-in)
  (let* ((page (if (and limit
                        (> limit 0))
                   (+ 1
                      (quotient offset limit)) 1))
         ;; A list page is described by the list itself: what is on it, and --
         ;; when one was searched for -- the words that found it.  Everything
         ;; past the first page, and every page of results, is kept out of the
         ;; index: a crawler that follows `?page=' forever would index the same
         ;; songs over and over under addresses no reader ever types.
         (searching? (and (string? search-query)
                          (not (string-null? search-query))))
         (list-title (if searching?
                      (format #f
                       "Songs matching “~a” — guitar tabs & chords | WikiMusic"
                       search-query)
                      "Songs: guitar tabs, bass tabs, chords and keys | WikiMusic"))
         (list-description (if searching?
                            (format #f
                             "Songs on WikiMusic matching “~a”, with their artists, keys, tunings and stored tabs."
                             search-query)
                            "Every song on WikiMusic with its artists, key, tuning and stored guitar and bass tabs, chords and notation."))
         (page-buttons (if (and pages
                                (> pages 1))
                           (pagination #:current page
                                       #:total pages
                                       #:base-url (format #f
                                                   "/songs?limit=~a&sort=~a~a&page="
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
                     (,(unless only-tiles
                         (h4 `(div (@ (class ,(mk-class '(flex flex-row
                                                               items-center
                                                               items-center
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
                                                                     user-sort)
                                                                   ,(grid-size-select
                                                                     G_
                                                                     #:entity 'song
                                                                     #:size
                                                                     grid-size
                                                                     #:search-query
                                                                     search-query))
                                                              (div (@ (class ,
                                                                             (mk-class '
                                                                              (flex
                                                                               flex-wrap
                                                                               flex-row
                                                                               gap-3
                                                                               justify-end
                                                                               items-center))))

                                                                   ,(search-box
                                                                     G_
                                                                     #:search-query
                                                                     search-query))))
                      (div (div (@ (class ,(item-tile-grid-face #:size
                                                                grid-size)))
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
                       #:title list-title
                       #:description list-description
                       #:path (if (and (= page 1)
                                       (not searching?)) "/songs" #f)
                       #:robots (if (or searching?
                                        (> page 1)) "noindex, follow" #f)
                       #:json-ld (list (page-json-ld #:type "CollectionPage"
                                                     #:url (if searching? #f
                                                               (absolute-url
                                                                "/songs"))
                                                     #:name list-title
                                                     #:description
                                                     list-description))
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
                                                         dark:hover:text-persia-pink-300
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
                                                        dark:hover:text-persia-pink-300
                                                        hover:underline)
                                              #:href (format #f
                                                      "/genres/uuid/~a"

                                                      (assq-ref ar
                                                                'identifier))))))
                                 genres))
         ;; ---- What a crawler and a link preview are told about this page
         ;;
         ;; The words a reader would type are the song's own: its title, the
         ;; artist's name, and what the page actually holds -- the instruments
         ;; its stored versions are written for, its key and its tuning.  The
         ;; description leads with the same facts written as a sentence and
         ;; then carries as much of the song's own description as a meta tag
         ;; holds, so a phrase a contributor wrote -- the lyrics they quoted,
         ;; the album they named -- is searchable too.
         (song-path (format #f "/songs/uuid/~a"
                            (assq-ref song
                                      'identifier)))
         (song-name (assq-ref song
                              'display-name))
         (artist-names (map (lambda (ar)
                              (assq-ref ar
                                        'display-name)) artists))
         (artist-line (and (pair? artist-names)
                           (string-join artist-names " and ")))
         (instruments (delete-duplicates (filter (lambda (word)
                                                   (and (string? word)
                                                        (not (string-null?
                                                              word))))
                                                 (map (lambda (sc)
                                                        (assq-ref sc
                                                                  'instrument-type))
                                                      song-contents))))
         (genre-names (map (lambda (g)
                             (assq-ref g
                                       'display-name)) genres))
         (key (assq-ref song
                        'music-key))
         (tuning (assq-ref song
                           'music-tuning))
         (album (assq-ref song
                          'album-name))
         (stored-words (cond
                         ((pair? instruments)
                          (format #f "~a tabs, chords"
                                  (string-join instruments " & ")))
                         ((pair? song-contents)
                          "tabs, chords")
                         (else "chords")))
         (page-title (format #f
                             "~a~a — ~a~a | WikiMusic"
                             song-name
                             (if artist-line
                                 (format #f " – ~a" artist-line) "")
                             stored-words
                             (if (and (string? key)
                                      (not (string-null? key)))
                                 (format #f " & the key of ~a" key) "")))
         (page-description (summarize (string-append song-name
                                       (if artist-line
                                           (format #f " by ~a" artist-line) "")
                                       (if (and (string? album)
                                                (not (string-null? album)))
                                           (format #f " from ~a" album) "")
                                       " — "
                                       stored-words
                                       (if (and (string? tuning)
                                                (not (string-null? tuning)))
                                           (format #f " in ~a tuning" tuning)
                                           "")
                                       ", stored on WikiMusic as "
                                       (if (pair? song-contents)
                                           (format #f "~a~a"
                                                   (length song-contents)
                                                   (if (= 1
                                                          (length
                                                           song-contents))
                                                       " version" " versions"))
                                           "a song page")
                                       ". "
                                       (let ((written (assq-ref song
                                                                'description)))
                                         (if (string? written) written "")))
                                      #:limit 300))
         (page-image (artwork-social-image artworks
                                           #:fallback (announced-image)))
         ;; A click track, at the tempo the first tab declares when one does:
         ;; a reader practising a passage wants it at the speed the tab is
         ;; written in, and the page already knows what that is.
         (tab-tempo (first-tab-tempo song-contents))
         (page-json-ld-data (page-json-ld #:type "WebPage"
                                          #:url (absolute-url song-path)
                                          #:name page-title
                                          #:description page-description
                                          #:main-entity (append (list (schema-name
                                                                       "MusicComposition")
                                                                      (cons
                                                                       "name"
                                                                       song-name))
                                                                (if (and (string?
                                                                          key)
                                                                         (not (string-null?
                                                                               key)))
                                                                    (list (cons
                                                                           "musicalKey"
                                                                           key))
                                                                    '())
                                                                (let ((creators
                                                                       (named-nodes
                                                                        #:type
                                                                        "MusicGroup"
                                                                        #:names
                                                                        artist-names)))
                                                                  (if creators
                                                                   (list (cons
                                                                          "creator"
                                                                          creators))
                                                                   '()))
                                                                (let ((genres-node
                                                                       (named-nodes
                                                                        #:type
                                                                        "DefinedTerm"
                                                                        #:names
                                                                        genre-names)))
                                                                  (if
                                                                   genres-node
                                                                   (list (cons
                                                                          "genre"
                                                                          genres-node))
                                                                   '())))))
         (song-attributes `((div (@ (class ,(mk-class '(px-4 py-6 mx-auto))))
                                 (dl ;The row's own keys are the hyphenated
                                     ;; ones the repository asked SQL for; a
                                     ;; column named with an underscore is
                                     ;; not there, so each of these is `#f'
                                     ;; and the whole list below rendered as
                                     ;; nothing at all.
                                     ,(render-if-nestring (lambda (tuning)
                                                            (list (dt (G_
                                                                       "tuning"))
                                                                  (dd tuning)))
                                                          (assq-ref song
                                                                    'music-tuning))
                                     ,(render-if-nestring (lambda (keyy)
                                                            (list (dt (G_
                                                                       "music key"))
                                                                  (dd keyy)))
                                                          (assq-ref song
                                                                    'music-key))
                                     ,(render-if-nestring (lambda (music-creation-date)
                                                            (list (dt (G_
                                                                       "music creation date"))
                                                                  (dd
                                                                   music-creation-date)))
                                                          (assq-ref song
                                                                    'music-creation-date))
                                     ,(render-if-nestring (lambda (album-name)
                                                            (list (dt (G_
                                                                       "album name"))
                                                                  (dd
                                                                   album-name)))
                                                          (assq-ref song
                                                                    'album-name))
                                     ,(render-if-nestring (lambda (album-link)
                                                            (list (dt (G_
                                                                       "album info link"))
                                                                  (dd (a (uri-decode
                                                                          album-link)))))
                                                          (assq-ref song
                                                                    'album-info-link)))))))
    (html-template G_
                   #:is-logged-in is-logged-in
                   #:title page-title
                   #:description page-description
                   #:path song-path
                   #:image page-image
                   #:image-alt (format #f "artwork for ~a" song-name)
                   #:og-type "music.song"
                   #:json-ld (list page-json-ld-data)
                   ;; A song page is where a reader reads: its ascii contents,
                   ;; its ascii legend and any embedded PDF.  Nothing about
                   ;; reading wants a bar pinned over the top of it, so the
                   ;; navigation is left to scroll away here and gives the
                   ;; viewport back to the music.
                   #:reading? #t
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
                                                                        items-center
                                                                        justify-start))))
                                                 ,(em "by:")
                                                 ,artist-name-titles)))
                                       ,(when (not (nil? genres))
                                          `((div (@ (class ,(mk-class '(flex
                                                                        flex-row
                                                                        flex-wrap
                                                                        gap-4
                                                                        items-center
                                                                        items-center
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
                            (div (@ (class ,(mk-class '(py-1 px-5))))
                                 ,(sub-h4 (G_ "metronome"))
                                 ,(metronome-widget G_
                                                    #:id (format #f
                                                          "metronome-~a"
                                                          (assq-ref song
                                                                    'identifier))
                                                    #:tempo (or tab-tempo 120)))

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
