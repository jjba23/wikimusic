;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (app views genre-edit)
  #:use-module (wikimusic html)
  #:use-module (wikimusic domain)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (kracht prelude)
  #:use-module (web uri)
  #:use-module (ice-9 i18n)
  #:use-module (hygguile hygguile)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun)
  #:export (genre-edit-page genre-new-page genre-form))

(define* (genre-edit-page G_
                          #:key genre
                          artworks
                          external-sources
                          is-logged-in)
  (let* ((arts (map (lambda (a)
                      `(div (figure (@ (class ,(mk-class '(py-3 sm:w-32))))
                                    (img (@ (loading lazy)
                                            (class ,(mk-class '(rounded-xl)))
                                            (src ,(uri-decode (assq-ref a
                                                                        'content-url))))))
                            ,(artwork-form G_
                                           #:entity 'genre
                                           #:entity-identifier (assq-ref genre
                                                                'identifier)
                                           #:artwork-identifier (assq-ref a
                                                                          'identifier)
                                           #:content-url (uri-decode (assq-ref
                                                                      a
                                                                      'content-url))
                                           #:content-caption (assoc-ref-or-empty-str
                                                              a
                                                              'content-caption)
                                           #:order-value (assq-ref a
                                                                   'order-value))))
                    artworks))
         (body `(div (@ (class ,(mk-class '(px-2 py-4))))
                     (div (@ (class ,(mk-class '(py-3))))
                          ,(if (assq-ref genre
                                         'identifier)
                               (h2 (format #f "~a: ~a"
                                           (G_ "editing genre")
                                           (assq-ref genre
                                                     'display-name)))
                               (h2 (G_ "new genre"))))
                     (details (summary (@ (class ,(mk-class '(font-black
                                                              text-onyx-300
                                                              dark:text-stone-300
                                                              text-md
                                                              cursor-pointer))))
                                       ,(G_ "edit artworks"))
                              ,arts)
                     ,(hr)
                     (details (summary (@ (class ,(mk-class '(font-black
                                                              text-onyx-300
                                                              dark:text-stone-300
                                                              text-md
                                                              cursor-pointer))))
                                       ,(G_ "new artwork"))
                              ,(artwork-form G_
                                             #:entity 'genre
                                             #:entity-identifier (assq-ref
                                                                  genre
                                                                  'identifier)))
                     ,(hr)
                     (details (@ (open true))
                              (summary (@ (class ,(mk-class '(font-black
                                                              text-onyx-300
                                                              dark:text-stone-300
                                                              text-md
                                                              cursor-pointer))))
                                       ,(G_ "editing genre"))
                              ,(genre-form G_
                                           #:identifier (assq-ref genre
                                                                  'identifier)
                                           #:display-name (assq-ref genre
                                                                    'display-name)
                                           #:description (assoc-ref-or-empty-str
                                                          genre
                                                          'description)))
                     ,(hr)
                     (details (summary (@ (class ,(mk-class '(font-black
                                                              text-onyx-300
                                                              dark:text-stone-300
                                                              text-md
                                                              cursor-pointer))))
                                       ,(G_ "editing external sources"))
                              ,(external-sources-form G_
                                                      #:entity 'genre
                                                      #:entity-identifier (assq-ref
                                                                           genre
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
                                                                         'soundcloud-url)))))))
    (html-template G_
                   #:is-logged-in is-logged-in
                   #:title "Edit a genre · WikiMusic"
                   #:robots "noindex, nofollow"
                   #:body body)))

(define* (genre-new-page G_
                         #:key is-logged-in)
  (html-template G_
                 #:title "New genre · WikiMusic"
                 #:robots "noindex, nofollow"
                 #:is-logged-in is-logged-in
                 #:body `(div (@ (class ,(mk-class '())))
                              ,(genre-form G_))))

(define* (genre-form G_
                     #:key (identifier #f)
                     (display-name "")
                     (description ""))
  `((form (@ (method POST)
             (action ,(if identifier
                          (format #f "/genres/uuid/~a/edit" identifier)
                          "/genres/new"))
             (content-type application/x-www-form-urlencoded))
          (div ,(input #:label (G_ "display name")
                       #:name "display-name"
                       #:value (html-unescape display-name)
                       #:required #t)
               ,(textarea #:label (G_ "description")
                          #:name "description"
                          ;; The column is rendered as Org by `org2html' when
                          ;; the page is read, so the one who writes it is told
                          ;; so here rather than left to find out.
                          #:help-text (G_
                                       "descriptions are written in Org mode syntax")
                          #:value (html-unescape description)))
          (div ,(submit-button (if identifier
                                   (G_ "edit")
                                   (G_ "create")))))))

