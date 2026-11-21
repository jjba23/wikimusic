;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

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
  #:export (song-edit-page song-new-page song-form
            editor-section relation-editor))

;;; The sections an editing page is made of.
;;;
;;; An editing page is a handful of questions -- the song, its artists, its
;;; genres, its artwork, its links -- and each is a section that folds, headed
;;; the way the song page's own sections are.  A contributor opens the one they
;;; came to change and leaves the rest out of the way, and the heading is the
;;; same control in both places rather than a second kind of disclosure.
(define (editor-section G_ title open? body)
  "Return one foldable section of an editing page, titled TITLE."
  `(details (@ (class ,(mk-class '(wm-disclosure my-3)))
               ,@(if open? '((open "")) '()))
            ,(disclosure-summary G_ title)
            ,body))

;;; A relation, edited by name.
;;;
;;; The form used to ask for a UUID, which is not something a contributor
;;; holds: the identifier of the artist they mean is on that artist's page and
;;; in no list they can read.  The menu asks for the name instead -- the route
;;; still receives the identifier, it is just no longer what a reader has to
;;; find -- and the rows already linked are links to what they name, each with
;;; the button that removes the link.
(define* (relation-editor G_ #:key path link-base field label candidates linked)
  "Return the form that links an entity to the one chosen from CANDIDATES.

PATH is the route the link is posted to and the base of the route that removes
one; LINK-BASE is where a linked row's own page lives; LINKED is the rows
already linked, which the page shows whole rather than as identifiers."
  `(div (@ (class ,(mk-class '(flex flex-col gap-4))))
        ,@(map (lambda (row)
                 `(div (@ (class ,(mk-class '(flex flex-row flex-wrap
                                                    items-center gap-2))))
                       (a (@ (href ,(format #f "~a/~a" link-base
                                            (assq-ref row 'identifier)))
                             (class ,(mk-class '(font-bold
                                                 text-onyx-300
                                                 dark:text-stone-300
                                                 underline
                                                 underline-offset-2
                                                 decoration-1
                                                 hover:text-persia-pink-500
                                                 dark:hover:text-persia-pink-300))))
                          ,(assq-ref row 'display-name))
                       (form (@ (method POST)
                                (content-type
                                 application/x-www-form-urlencoded)
                                (action ,(format #f "~a/~a/delete"
                                                 path
                                                 (assq-ref row
                                                           'identifier))))
                             ,(icon-button #:icon 'trash
                                           #:content ""
                                           #:type 'submit
                                           #:background '(bg-red-700)
                                           #:color '(text-stone-200)
                                           #:hover-background '(hover:bg-red-900)))))
               linked)
        (form (@ (method POST)
                 (content-type application/x-www-form-urlencoded)
                 (action ,path)
                 (class ,(mk-class '(flex flex-row flex-wrap
                                            items-end gap-3))))
              ,(select #:name field
                       #:label (G_ label)
                       #:required #t
                       ;; `—' is the row a reader sees before they have
                       ;; chosen; it submits nothing, and `required' refuses
                       ;; that, so a menu cannot link whatever came first.
                       #:options (cons (option #:value "" #:content "—")
                                       (map (lambda (candidate)
                                              (option #:value (assq-ref candidate
                                                                        'identifier)
                                                      #:content (assq-ref candidate
                                                                          'display-name)))
                                            candidates)))
              (div ,(submit-button (G_ "add"))))))

(define* (song-edit-page G_
                         #:key song
                         song-contents
                         artworks
                         (artists '())
                         (genres '())
                         (all-artists '())
                         (all-genres '())
                         (external-sources '())
                         is-logged-in)
  (let* ((song-id (assq-ref song
                            'identifier))
         (artworks-section (map (lambda (a)
                                  `(div (figure (@ (class ,(mk-class '(py-3
                                                                       sm:w-32))))
                                                (img (@ (loading lazy)
                                                        (class ,(mk-class '(rounded-xl
                                                                            max-w-full)))
                                                        (src ,(uri-decode (assq-ref
                                                                           a
                                                                           'content-url))))))
                                        ,(artwork-form G_
                                                       #:entity 'song
                                                       #:entity-identifier
                                                       song-id
                                                       #:artwork-identifier
                                                       (assq-ref a
                                                                 'identifier)
                                                       #:content-url (uri-decode
                                                                      (assq-ref
                                                                       a
                                                                       'content-url))
                                                       #:content-caption
                                                       (assoc-ref-or-empty-str
                                                        a
                                                        'content-caption)
                                                       #:order-value (assq-ref
                                                                      a
                                                                      'order-value))))
                                artworks))
         (body `(div (@ (class ,(mk-class '(px-2 py-4))))
                     (div (@ (class ,(mk-class '(py-3))))
                          ,(if song-id
                             (wm-page-heading "dark:text-stone-300 font-light font-sans hg-leading-display text-3xl text-onyx-300" (format #f "~a: ~a" (G_ "editing song") (assq-ref song 'display-name)))
                             (wm-page-heading "dark:text-stone-300 font-light font-sans hg-leading-display text-3xl text-onyx-300" (G_ "new song"))))
                     ;; The song itself comes first: it is what most visits to
                     ;; this page change, and it used to sit below two artwork
                     ;; panels a contributor had to read past.
                     ,(editor-section
                       G_ (G_ "editing song") #t
                       (song-form G_
                                  #:identifier song-id
                                  #:display-name (assq-ref song
                                                           'display-name)
                                  #:music-key (assoc-ref-or-empty-str
                                               song 'music-key)
                                  #:music-tuning (assoc-ref-or-empty-str
                                                  song 'music-tuning)
                                  #:music-creation-date (assoc-ref-or-empty-str
                                                         song
                                                         'music-creation-date)
                                  #:album-name (assoc-ref-or-empty-str
                                                song 'album-name)
                                  #:album-info-link
                                  (assoc-ref-or-empty-str
                                   song 'album-info-link)
                                  #:description (assoc-ref-or-empty-str
                                                 song 'description)))
                     ,(editor-section
                       G_ (G_ "song's artists") #f
                       (relation-editor G_
                                        #:path (format #f
                                                       "/songs/uuid/~a/artists"
                                                       song-id)
                                        #:link-base "/artists/uuid"
                                        #:field 'artist-identifier
                                        #:label "artist"
                                        #:candidates all-artists
                                        #:linked artists))
                     ,(editor-section
                       G_ (G_ "song's genres") #f
                       (relation-editor G_
                                        #:path (format #f
                                                       "/songs/uuid/~a/genres"
                                                       song-id)
                                        #:link-base "/genres/uuid"
                                        #:field 'genre-identifier
                                        #:label "genre"
                                        #:candidates all-genres
                                        #:linked genres))
                     ,(editor-section G_ (G_ "edit artworks") #f artworks-section)
                     ,(editor-section
                       G_ (G_ "new artwork") #f
                       (artwork-form G_
                                     #:entity 'song
                                     #:entity-identifier song-id))
                     ,(editor-section
                       G_ (G_ "editing external sources") #f
                       (external-sources-form
                        G_
                        #:entity 'song
                        #:entity-identifier song-id
                        #:external-sources-identifier
                        (assq-ref external-sources 'identifier)
                        #:wikipedia-url (uri-decode
                                         (assoc-ref-or-empty-str
                                          external-sources 'wikipedia-url))
                        #:spotify-url (uri-decode
                                       (assoc-ref-or-empty-str
                                        external-sources 'spotify-url))
                        #:youtube-url (uri-decode
                                       (assoc-ref-or-empty-str
                                        external-sources 'youtube-url))
                        #:soundcloud-url (uri-decode
                                          (assoc-ref-or-empty-str
                                           external-sources
                                           'soundcloud-url)))))))
    (html-template G_
                   #:is-logged-in is-logged-in
                   ;; A form is written by a contributor, not read by a
                   ;; visitor, so it is kept out of the index entirely.
                   #:title "Edit a song · WikiMusic"
                   #:robots "noindex, nofollow"
                   #:body body)))

(define* (song-new-page G_
                        #:key is-logged-in)
  (html-template G_
                 #:title "New song · WikiMusic"
                 #:robots "noindex, nofollow"
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
  ;; The form asks for the same fields it always did, in the groups a
  ;; contributor thinks in -- the song, the album it came from, the words that
  ;; describe it -- and its control sits in a bar that stays in reach while the
  ;; page is scrolled: a long description is written under the form, so the
  ;; thing that saves it must not be the thing that scrolled away.
  `((form (@ (method POST)
             (action ,(if identifier
                        (format #f "/songs/uuid/~a/edit" identifier)
                        "/songs/new"))
             (content-type application/x-www-form-urlencoded)
             (class "flex flex-col gap-3"))
          (fieldset (@ (class "wm-editor-group"))
                    (legend (@ (class "wm-editor-legend"))
                            ,(G_ "the song"))
                    ,(input #:label (G_ "display name")
                            #:name "display-name"
                            #:value display-name
                            #:required #t
                            #:autofocus (if identifier #f #t))
                    ,(input #:label (G_ "music key")
                            #:name "music-key"
                            #:value music-key)
                    ,(input #:label (G_ "music tuning")
                            #:name "music-tuning"
                            #:value music-tuning)
                    ,(input #:label (G_ "music creation date")
                            #:name "music-creation-date"
                            #:value music-creation-date))
          (fieldset (@ (class "wm-editor-group"))
                    (legend (@ (class "wm-editor-legend"))
                            ,(G_ "the album"))
                    ,(input #:label (G_ "album name")
                            #:name "album-name"
                            #:value album-name)
                    ,(input #:label (G_ "album info url")
                            #:name "album-info-link"
                            #:value (uri-decode album-info-link)))
          (fieldset (@ (class "wm-editor-group"))
                    (legend (@ (class "wm-editor-legend"))
                            ,(G_ "the description"))
                    ,(textarea #:label (G_ "description")
                               #:name "description"
                               ;; The column is rendered as Org by `org2html'
                               ;; when the page is read, so the one who writes
                               ;; it is told so here rather than left to find
                               ;; out from the rendered page.
                               #:help-text (G_ "descriptions are written in Org mode syntax")
                               #:value description))
          (div (@ (class "wm-editor-actions"))
               ,(submit-button (if identifier
                                 (G_ "edit")
                                 (G_ "create")))))))
