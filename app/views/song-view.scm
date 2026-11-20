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
  (let* ((extra-bot-info '())
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

         (artist-links (map (lambda (ar)
                              `(a (@ (href ,(format #f "/artists/uuid/~a"
                                                    (assq-ref ar
                                                              'identifier)))
                                     (class "wm-tile-by-link"))
                                  ,(assq-ref ar
                                             'display-name)))
                            art))
         ;; "by" and then the players, on the card's second line, separated by
         ;; commas: a reader reads a name and then who made it, and the last
         ;; comma is dropped because a list of two does not end in one.
         (subtitle (if (null? artist-links)
                     '()
                     (cons (G_ "by ")
                           (drop-right (append-map
                                        (lambda (line)
                                          (list line ", "))
                                        artist-links)
                                       1)))))
    `((div ,(item-tile G_
                       'song
                       x
                       (relevant-entities 'song artworks x)
                       (relevant-entities 'song comments x)
                       #:subtitle subtitle
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
                                                                  (uri-encode
                                                                   search-query))
                                                          ""))
                                     #:prev-label (G_ "previous")
                                     #:next-label (G_ "next"))
                         '()))
                  (body `(div (@ (class "wm-list"))
                     ,@(if only-tiles
                         '()
                         `((div (@ (class "wm-list-head"))
                                ,(wm-page-heading "wm-list-title"
                                                  (G_ "songs"))
                                (div (@ (class "wm-list-tools"))
                                     ,(sort-select G_
                                                   #:entity 'song
                                                   #:user-sort user-sort)
                                     ,(grid-size-select G_
                                                        #:entity 'song
                                                        #:size grid-size
                                                        #:search-query
                                                        search-query)
                                     ,@(search-box G_
                                                   #:search-query
                                                   search-query)))))
                     (div (@ (class ,(item-tile-grid-face #:size
                                                          grid-size)))
                          ,(map (lambda (x)
                                  (render-song-tile G_
                                                    #:artworks artworks
                                                    #:song-version-count-alist
                                                    song-version-count-alist
                                                    #:comments comments
                                                    #:artists artists
                                                    #:song-artists song-artists
                                                    #:x x))
                                songs))
                     ,page-buttons
                     ,@(if only-tiles
                         '()
                         `((div (@ (class "wm-list-actions"))
                                (a (@ (href "/songs/new")
                                      (class "wm-button"))
                                   ,(G_ "new song"))))))))
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

;; The facts the song itself carries -- its key, its tuning, when it was written
;; and the album it is from -- as the row of cards under its name.  These are
;; the song's and not the row's: a reader came for the key and the tuning, so
;; they are shown, while the row's own bookkeeping is a press away in
;; `entity-details'.  A fact the song does not carry is left out rather than
;; drawn empty, and the album's link is a link because that is what it is.
(define (song-facts G_ song)
  "Return the facts SONG carries, as the cards a reader skims under its name."
  (let* ((text (lambda (key)
                 (let ((value (assq-ref song key)))
                   (and (string? value)
                     (not (string-null? value))
                     value))))
         (album-link (text 'album-info-link))
         (facts (filter (lambda (fact)
                          (cdr fact))
                        (list (cons (G_ "tuning")
                                    (text 'music-tuning))
                              (cons (G_ "music key")
                                    (text 'music-key))
                              (cons (G_ "music creation date")
                                    (text 'music-creation-date))
                              (cons (G_ "album")
                                    (text 'album-name))
                              (cons (G_ "album info")
                                    (and album-link
                                      `(a (@ (href ,(uri-decode album-link)))
                                          ,(G_ "album info"))))))))
    (if (null? facts) '()
      `(dl (@ (class "wm-facts"))
           ,@(map (lambda (fact)
                    `(div (@ (class "wm-fact"))
                          (dt ,(car fact))
                          (dd ,(cdr fact))))
                  facts)))))

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
                           (ascii-size ascii-size-default)
                           (ascii-theme ascii-paper-default)
                           (ascii-face ascii-face-default)
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
                         [(pair? instruments)
                          (format #f "~a tabs, chords"
                                  (string-join instruments " & "))]
                         [(pair? song-contents)
                          "tabs, chords"]
                         [else "chords"]))
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
         ;; The song's own facts, as the row of cards under its name (see
         ;; `song-facts').
         (facts (song-facts G_ song)))
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
                   ;; A phone's gutter is the shell's own: a second one on top
                   ;; of it is the width of a tab's first column, and a song
                   ;; page is read rather than skimmed.  From the medium
                   ;; breakpoint up there is room for both.
                   ;; The page is one column: the song's name, who wrote it,
                   ;; what the song carries, the panel holding its pictures and
                   ;; its opinions, and then the music itself.  What belongs to
                   ;; the page rather than to the song -- the metronome's
                   ;; settings, the size its tab is drawn at -- is folded into
                   ;; one row that a reader opens when they want it.
                   ;; A phone's gutter is the shell's own: a second one on top of
                   ;; it is the width of a tab's first column, and a song page
                   ;; is read rather than skimmed.  From the medium breakpoint
                   ;; up there is room for both.
                   #:body `((div (@ (class "wm-song px-0 md:px-6"))
                                 (header (@ (class "wm-song-head"))
                                         ,(wm-page-heading "wm-song-title"
                                                           song-name)
                                         ,@(if (nil? artists)
                                             '()
                                             `((div (@ (class "wm-song-meta"))
                                                    (em ,(G_ "by"))
                                                    ,artist-name-titles)))
                                         ,@(if (nil? genres)
                                             '()
                                             `((div (@ (class "wm-song-meta"))
                                                    (em ,(G_ "genres"))
                                                    ,genre-name-titles))))
                                 ,facts
                                 (div ,(entity-details G_
                                                        #:entity 'song
                                                        #:x song
                                                        #:artworks artworks
                                                        #:opinions opinions
                                                        #:comments comments
                                                        #:user-alist
                                                        user-alist))
                                 ,(render-external-sources G_
                                                           external-sources)
                                 (div (@ (class "wm-practice"))
                                      ,(sub-h3 (G_ "metronome"))
                                      ,(metronome-widget G_
                                                         #:id (format #f
                                                                      "metronome-~a"
                                                                      (assq-ref
                                                                       song
                                                                       'identifier))
                                                         #:tempo (or tab-tempo
                                                                     120)))
                                 (details (@ (class "wm-reading-options"))
                                          (summary (@ (class
                                                       "wm-reading-options-summary"))
                                                   ,(icon #:type
                                                          'sliders-horizontal
                                                          #:icon-css '(text-base))
                                                   ,(G_ "reading options"))
                                          (div (@ (class "wm-song-setting"))
                                               ;; The size the ascii contents
                                               ;; are read at, said in the
                                               ;; reader's own terms: the control
                                               ;; steps up and down and shows the
                                               ;; share it is drawn at, and the
                                               ;; page remembers the choice for
                                               ;; the next song they open (see
                                               ;; `(wikimusic html)' and the
                                               ;; route).
                                               ,(sub-h3 (G_ "ascii size"))
                                               ,(ascii-size-control G_
                                                                    #:route
                                                                    song-path
                                                                    #:size
                                                                    ascii-size
                                                                    #:paper
                                                                    (ascii-paper-known
                                                                     ascii-theme)
                                                                    #:face
                                                                    (ascii-face-known
                                                                     ascii-face)))
                                          ;; The paper the tab is drawn on and
                                          ;; the face it is set in.  Both are
                                          ;; remembered beside the size and
                                          ;; travel in the same address, so each
                                          ;; control changes one without
                                          ;; resetting the others (see
                                          ;; `ascii-preference-href').
                                          (div (@ (class "wm-song-setting"))
                                               ,(sub-h3 (G_ "ascii paper"))
                                               ,(ascii-choice-control
                                                 G_
                                                 #:id "ascii-theme"
                                                 #:label "ascii paper"
                                                 #:key "ascii-theme"
                                                 #:options ascii-paper-steps
                                                 #:selected (ascii-paper-known
                                                             ascii-theme)
                                                 #:route song-path
                                                 #:size ascii-size
                                                 #:paper ascii-theme
                                                 #:face ascii-face))
                                          (div (@ (class "wm-song-setting"))
                                               ,(sub-h3 (G_ "ascii face"))
                                               ,(ascii-choice-control
                                                 G_
                                                 #:id "ascii-face"
                                                 #:label "ascii face"
                                                 #:key "ascii-face"
                                                 #:options ascii-face-steps
                                                 #:selected (ascii-face-known
                                                             ascii-face)
                                                 #:route song-path
                                                 #:size ascii-size
                                                 #:paper ascii-theme
                                                 #:face ascii-face)))
                                 (div ,(render-song-content G_
                                                            song
                                                            song-contents
                                                            ascii-size
                                                            #:paper
                                                            ascii-theme
                                                            #:face
                                                            ascii-face)))))))
