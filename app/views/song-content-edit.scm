;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (app views song-content-edit)
  #:use-module (wikimusic html)
  #:use-module (wikimusic domain)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (hygguile hygguile)
  #:use-module (ice-9 i18n)
  #:use-module (kracht prelude)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun)
  #:export (song-content-edit-page song-content-new-page song-content-form))

(define* (song-content-edit-page G_
                                 #:key song song-contents is-logged-in)
  (let* ((clean-pdf-contents (lambda (x)
                               (if (equal? x
                                           "data:application/octet-stream;base64,")
                                 ""
                                 (assq-ref song-contents
                                           'pdf-contents))))
         (body `(div (@ (class ,(mk-class '(px-2 py-6))))
                     ((div ,(hr)
                           ,(song-content-form G_
                                               #:song-identifier (assq-ref
                                                                  song
                                                                  'identifier)
                                               #:song-content-identifier (assq-ref
                                                                          song-contents
                                                                          'identifier)
                                               #:instrument-type (assq-ref
                                                                  song-contents
                                                                  'instrument-type)
                                               #:version-name (assq-ref
                                                               song-contents
                                                               'version-name)
                                               #:ascii-legend (assq-ref
                                                               song-contents
                                                               'ascii-legend)
                                               #:ascii-contents (assq-ref
                                                                 song-contents
                                                                 'ascii-contents)
                                               #:guitarpro-contents (assq-ref
                                                                     song-contents
                                                                     'guitarpro-contents)
                                               #:pdf-contents
                                               clean-pdf-contents))))))
    (html-template G_
                   #:is-logged-in is-logged-in
                   #:title "Edit a song version · WikiMusic"
                   #:robots "noindex, nofollow"
                   #:body body)))

(define* (song-content-new-page G_
                                #:key song-identifier is-logged-in)
  (html-template G_
                 #:title "New song version · WikiMusic"
                 #:robots "noindex, nofollow"
                 #:is-logged-in is-logged-in
                 #:body `(div (@ (class ,(mk-class '())))
                              ,(song-content-form G_
                                                  #:song-identifier
                                                  song-identifier))))

(define* (song-content-form G_
                            #:key song-identifier
                            song-content-identifier
                            (instrument-type "")
                            (version-name "")
                            (ascii-legend "")
                            (ascii-contents "")
                            (guitarpro-contents "")
                            (pdf-contents ""))
  `((div (@ (class ,(mk-class '(py-3))))
         ,(if song-identifier
            `(a (@ (href ,(format #f "/songs/uuid/~a" song-identifier))
                   (class ,(mk-class '(text-sm
                                       font-sans
                                       text-onyx-300
                                       dark:text-stone-300
                                       underline
                                       underline-offset-2
                                       hover:text-persia-pink-500
                                       dark:hover:text-persia-pink-300))))
                ,(G_ "back to the song"))
            '())
         ,(if (and song-identifier song-content-identifier)
            (wm-page-heading "dark:text-stone-300 font-light font-sans hg-leading-display text-3xl text-onyx-300" (format #f "~a: ~a ~a"
                                                                                                                          (G_ "editing version") version-name instrument-type))
            (wm-page-heading "dark:text-stone-300 font-light font-sans hg-leading-display text-3xl text-onyx-300" (G_ "new version"))))
    (form (@ (method POST)
             (action ,(if (and song-identifier song-content-identifier)
                        (format #f "/songs/uuid/~a/contents/~a/edit"
                                song-identifier song-content-identifier)
                        (format #f "/songs/uuid/~a/contents/new"
                                song-identifier)))
             (content-type application/x-www-form-urlencoded))
          (div ,(input #:label (G_ "instrument type")
                       #:name 'instrument-type
                       #:value instrument-type
                       #:required #t)
               ,(input #:label (G_ "version name")
                       #:name 'version-name
                       #:value version-name
                       #:required #t
                       #:autofocus (if song-content-identifier #f #t))
               (label (@ (class ,(mk-class '(dark:text-stone-300
                                             text-stone-500 font-bold text-sm
                                             mt-3))))
                      ,(G_ "PDF contents"))
               (input (@ (type file)
                         (id pdf-upload)
                         (onchange
                          "translateFileToBase64AddToInput(
                                                                      document.getElementById('pdf-upload'),
                                                                      document.getElementById('pdf-contents')
                                                           )")
                         (class ,(mk-class '(bg-stone-300 dark:bg-stone-900
                                                          my-2
                                                          px-3
                                                          py-2
                                                          text-onyx-300
                                                          dark:text-stone-300
                                                          rounded-xl)))
                         (value "")) "")
               (input (@ (id pdf-contents)
                         (name pdf-contents)
                         (hidden "")) "")
               ,(textarea #:label (G_ "ascii legend")
                          #:name 'ascii-legend
                          #:value ascii-legend
                          #:required #f
                          #:textarea-css '(p-3 rounded-xl
                                               border-stone-300
                                               dark:border-stone-700
                                               dark:text-stone-300
                                               hg-frost
                                               bg-stone-100/75
                                               dark:bg-onyx-900/75
                                               border-2
                                               min-h-72
                                               shadow-md
                                               font-mono
                                               text-sm
                                               min-w-prose))
               ;; The tab is written in columns, so the field it is written
               ;; in does not wrap them, keeps the browser's spell checker out
               ;; of the notes, and is tall enough to hold a verse without
               ;; being scrolled first.
               ,(textarea #:label (G_ "ascii contents")
                          #:name 'ascii-contents
                          #:value ascii-contents
                          #:required #f
                          #:rows 24
                          #:spellcheck "false"
                          #:textarea-css '(p-3 rounded-xl
                                               border-stone-300
                                               dark:border-stone-700
                                               dark:text-stone-300
                                               hg-frost
                                               bg-stone-100/75
                                               dark:bg-onyx-900/75
                                               border-2
                                               min-h-72
                                               text-sm
                                               shadow-md
                                               font-mono
                                               w-full
                                               wm-tab-input))

               ;; A Guitar Pro tab is uploaded the way the PDF is: the browser
               ;; turns the file into a data URL and the form carries that, so
               ;; the field the form posts is a hidden one and what a reader
               ;; picks is the file input above it.  The input used to be
               ;; hidden itself and named `guitarpro-contents', which left a
               ;; reader nothing to click and the route a filename where a
               ;; file should have been.
               (label (@ (class ,(mk-class '(dark:text-stone-300
                                             text-stone-500 font-bold text-sm
                                             mt-3))))
                      ,(G_ "Guitar Pro 5 tab (.gp5)"))
               (input (@ (type file)
                         (id guitarpro-upload)
                         (accept ".gp5,application/x-guitar-pro")
                         (onchange
                          "translateFileToBase64AddToInput(document.getElementById('guitarpro-upload'), document.getElementById('guitarpro-contents'))")
                         (class ,(mk-class '(bg-stone-300 dark:bg-stone-900
                                                          my-2
                                                          px-3
                                                          py-2
                                                          text-onyx-300
                                                          dark:text-stone-300
                                                          rounded-xl)))
                         (value "")) "")
               (input (@ (id guitarpro-contents)
                         (name guitarpro-contents)
                         (hidden "")) ""))
          (div ,(submit-button (if song-content-identifier
                                 (G_ "edit")
                                 (G_ "create")))))))
