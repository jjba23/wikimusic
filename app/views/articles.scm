;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; The pages a reader writes for another reader.
;;;
;;; An article is one row whatever it is about, so the list draws the kind as a
;;; badge and the page names it in words: a reader scanning a list is looking for
;;; a tutorial or a chord guide, and a page that only said "articles" would make
;;; them open every one.  The body is Org, the same as a song's description, so
;;; a writer gets headings, lists and code without a new editor to learn.
;;;
;;; Comments are open to anyone, signed in or not -- that is the rule this whole
;;; feature exists for -- so the form asks a name only when there is no session
;;; to take one from, and it carries a field no reader can see, laid out off the
;;; page rather than `hidden', because a script that reads markup skips a hidden
;;; field and does not skip a text one.  Nothing in the page tells a machine
;;; which field that was: a trap that names itself is a trap that gets stepped
;;; around.

(define-module (app views articles)
  #:use-module (wikimusic html)
  #:use-module (wikimusic seo)
  #:use-module (wikimusic domain article)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (hygguile hygguile)
  #:use-module (kracht prelude)
  #:use-module (ice-9 format)
  #:use-module (ice-9 string-fun)
  #:export (article-kind-word articles-list-page article-page
            article-new-page article-comment-form))

;; The column every page here stands in, the same frame the rest of the site is
;; drawn in.
(define articles-column-classes
  '(w-full max-w-196 mx-auto flex flex-col gap-4 px-2 py-4))

(define (kind-string kind)
  "Return KIND as the word a form posted it as, or #f."
  (cond
    ((symbol? kind) (symbol->string kind))
    ((string? kind) kind)
    (else #f)))

(define (article-kind-word G_ kind)
  "Return the words the kind KIND is offered under.

The words are written here rather than in the domain, because a word is a thing
to translate and `G_' only translates a literal."
  (case (article-kind-named (kind-string kind))
    [(video) (G_ "video")]
    [(chord-guide) (G_ "chord guide")]
    [(theory) (G_ "music theory")]
    [(discussion) (G_ "discussion")]
    [else (G_ "tutorial")]))

(define (article-kind-badge G_ kind)
  "Return the badge an article's kind is drawn as."
  `(span (@ (class ,(mk-class '(text-xs
                                font-semibold
                                uppercase
                                tracking-wide
                                rounded-lg
                                px-2
                                py-1
                                border-2
                                border-persia-pink-500/25
                                text-persia-pink-700
                                dark:text-persia-pink-300))))
         ,(article-kind-word G_ kind)))

(define (article-excerpt contents)
  "Return a short preview of CONTENTS, at most 220 letters."
  (let* ((flat (string-join (string-split (string-map (lambda (ch)
                                                       (if (char-whitespace? ch)
                                                           #\space ch))
                                                     (or contents ""))
                                          #\space)
                            " "))
         (trimmed (string-trim-both flat)))
    (if (> (string-length trimmed) 220)
        (string-append (substring trimmed 0 220) " …")
        trimmed)))

(define* (article-comment-form G_ #:key article is-logged-in)
  "Return the form a comment on ARTICLE is left in.

A signed-out reader is asked for a name; a signed-in one is not, because the
session already carries it.  The trap is the last field and it is out of the
reading order: `aria-hidden' keeps it off a screen reader and `tabindex -1'
keeps it away from the keyboard, so the only thing that can fill it is
something that reads the markup rather than the page."
  (let ((article-identifier (assq-ref article 'identifier)))
    `(form (@ (method POST)
              (action ,(format #f "/articles/uuid/~a/comments/new"
                               article-identifier))
              (class ,(mk-class '(flex flex-col gap-2 my-3))))
           ,@(if is-logged-in
                 '()
                 (list (input #:label (G_ "your name")
                              #:name "author-name")))
           ,(textarea #:label (G_ "your comment")
                      #:name "contents"
                      #:required #t)
           (div (@ (class "wm-honeypot")
                   (aria-hidden "true"))
                (input (@ (type "text")
                          (name "website")
                          (tabindex "-1")
                          (autocomplete "off")) ""))
           ,(button (G_ "leave a comment") #:type 'submit))))

(define (comment-author G_ comment user-alist)
  "Return the name a comment is shown under.

That is what its reader typed, the name of the account it was written from, or
-- for the one case neither of those covers -- the page's word for a reader."
  (let ((typed (assq-ref comment 'author-name)))
    (cond
      ((and (string? typed)
            (not (string-null? typed))) typed)
      (else (let* ((creator (assq-ref comment 'created-by))
                   (user (and creator
                              (assoc-ref (or user-alist '()) creator))))
              (or (and user
                       (assq-ref user 'display-name))
                  (and user
                       (assq-ref user 'username))
                  (G_ "a reader")))))))

(define* (render-article-comment G_ comment #:key user-alist)
  (let ((author (comment-author G_ comment user-alist)))
    `(div (@ (class ,(mk-class '(py-3 max-w-prose
                                      rounded-lg
                                      border-2
                                      border-stone-500/25
                                      dark:border-onyx-100/25
                                      px-3))))
          (p (@ (class ,(mk-class '(text-sm
                                    font-semibold
                                    text-onyx-700
                                    dark:text-stone-300))))
             ,author)
          (p (@ (class ,(mk-class '(text-md
                                    text-stone-900
                                    dark:text-stone-100
                                    whitespace-pre-wrap))))
             ,(or (assq-ref comment 'contents) ""))
          (p (@ (class ,(mk-class '(text-sm
                                    text-stone-500
                                    dark:text-stone-300))))
             ,(or (assq-ref comment 'created-at) "")))))

(define* (articles-list-page G_
                             #:key articles pages page is-logged-in)
  (let* ((title "Articles: tutorials, chord guides and discussions | WikiMusic")
         (description "Tutorials, videos, chord guides, music theory and discussions written by the readers of WikiMusic, with a comment thread on every one.")
         (page-buttons (if (and pages (> pages 1))
                           (pagination #:current page
                                       #:total pages
                                       #:base-url "/articles?page="
                                       #:prev-label (G_ "previous")
                                       #:next-label (G_ "next"))
                           '()))
         (cards (map (lambda (article)
                       (let ((path (format #f "/articles/uuid/~a"
                                           (assq-ref article 'identifier))))
                         `(article (@ (class ,(mk-class '(flex
                                                          flex-col
                                                          gap-2
                                                          p-4
                                                          rounded-3xl
                                                          border-2
                                                          border-persia-pink-500/25
                                                          dark:border-persia-pink-900/10
                                                          bg-stone-100
                                                          dark:bg-onyx-900))))
                                   (div (@ (class ,(mk-class '(flex
                                                               flex-row
                                                               flex-wrap
                                                               gap-2
                                                               items-center))))
                                        ,(article-kind-badge G_
                                                             (assq-ref article
                                                                       'kind))
                                        (span (@ (class ,(mk-class '(text-sm
                                                                     text-onyx-500
                                                                     dark:text-stone-300))))
                                              ,(or (assq-ref article
                                                              'created-at)
                                                   "")))
                                   (a (@ (href ,path)
                                         (class ,(mk-class '(no-underline
                                                             text-xl
                                                             font-semibold
                                                             text-onyx-900
                                                             dark:text-stone-100))))
                                      ,(or (assq-ref article 'display-name)
                                           ""))
                                   (p (@ (class ,(mk-class '(text-md
                                                             text-onyx-500
                                                             dark:text-stone-300))))
                                      ,(article-excerpt (assq-ref article
                                                                  'contents)))
                                   (a (@ (href ,(string-append path
                                                               "#comments"))
                                         (class ,(mk-class '(no-underline
                                                             text-sm
                                                             text-persia-pink-700
                                                             dark:text-persia-pink-300))))
                                      ,(G_ "read and comment")))))
                     articles)))
    (html-template G_
                   #:is-logged-in is-logged-in
                   #:title title
                   #:description description
                   #:path (if (= page 1) "/articles" #f)
                   #:robots (if (> page 1) "noindex, follow" #f)
                   #:json-ld (list (page-json-ld #:type "CollectionPage"
                                                 #:url (absolute-url "/articles")
                                                 #:name title
                                                 #:description description))
                   #:body `((div (@ (class ,(mk-class articles-column-classes)))
                                 ,(wm-page-heading "dark:text-stone-300 font-light font-sans hg-leading-display text-3xl text-onyx-300" (G_ "articles"))
                                 (p (@ (class ,(mk-class '(max-w-prose
                                                           text-md
                                                           text-onyx-500
                                                           dark:text-stone-300))))
                                    ,(G_ "tutorials, videos, chord guides, music theory and discussions, written by readers; every one of them takes a comment, and no account is needed to leave one"))
                                 ,(if (null? articles)
                                      `(p (@ (class ,(mk-class '(text-md
                                                                 text-onyx-500
                                                                 dark:text-stone-300))))
                                          ,(G_ "nothing has been posted yet"))
                                      `(div (@ (class ,(mk-class '(flex
                                                                   flex-col
                                                                   gap-4))))
                                            ,@cards))
                                 ,page-buttons
                                 ,(hr)
                                 (div (@ (class ,(mk-class '(flex flex-row
                                                                  flex-wrap
                                                                  gap-2
                                                                  justify-end))))
                                      (a (@ (href "/articles/new"))
                                         ,(button (G_ "write an article")))))))))

(define* (article-page G_
                       #:key article comments user-alist is-logged-in)
  ;; The page's optional parts are built before the markup for one reason: a
  ;; video and a thread are both sometimes there, and a list of one fragment --
  ;; or of none -- splices into the page below without the markup asking.
  (let* ((identifier (assq-ref article 'identifier))
         (display-name (or (assq-ref article 'display-name) ""))
         (kind-word (article-kind-word G_ (assq-ref article 'kind)))
         (page-title (format #f "~a — ~a | WikiMusic" display-name kind-word))
         (page-description (article-excerpt (assq-ref article 'contents)))
         (video-url (assq-ref article 'video-url))
         (video-fragment
          (if (and (string? video-url)
                   (not (string-null? video-url)))
              (list `(video (@ (controls "controls")
                               (preload "metadata")
                               (class "w-full max-w-196 rounded-2xl"))
                            (source (@ (src ,video-url))) ""))
              '()))
         (comment-fragments
          (if (null? comments)
              (list `(p (@ (class ,(mk-class '(text-md
                                              text-onyx-500
                                              dark:text-stone-300))))
                        ,(G_ "no comments yet")))
              (map (lambda (comment)
                     (render-article-comment G_
                                             comment
                                             #:user-alist user-alist))
                   comments))))
    (html-template G_
                   #:is-logged-in is-logged-in
                   #:title page-title
                   #:description page-description
                   #:path (format #f "/articles/uuid/~a" identifier)
                   #:json-ld (list (page-json-ld
                                    #:type "Article"
                                    #:url (absolute-url
                                           (format #f "/articles/uuid/~a"
                                                   identifier))
                                    #:name display-name
                                    #:description page-description))
                   #:body `((div (@ (class ,(mk-class articles-column-classes)))
                                 (div (@ (class ,(mk-class '(flex
                                                             flex-row
                                                             flex-wrap
                                                             gap-2
                                                             items-center))))
                                      ,(article-kind-badge G_
                                                           (assq-ref article
                                                                     'kind))
                                      (span (@ (class ,(mk-class '(text-sm
                                                                   text-onyx-500
                                                                   dark:text-stone-300))))
                                            ,(or (assq-ref article 'created-at)
                                                 "")))
                                 ,(wm-page-heading "dark:text-stone-300 font-light font-sans hg-leading-display text-3xl text-onyx-300" display-name)
                                 ,@video-fragment
                                 (div (@ (class ,(mk-class '(max-w-prose))))
                                      ,(org2html (or (assq-ref article
                                                               'contents)
                                                     "")))
                                 (div (@ (id "comments")
                                         (class ,(mk-class '(flex
                                                             flex-col
                                                             gap-2
                                                             mt-6))))
                                      ,(h3 (G_ "comments")
                                           #:family '(font-sans)
                                           #:weight '(font-light)
                                           #:size '(text-2xl))
                                      ,@comment-fragments
                                      ,(article-comment-form
                                        G_
                                        #:article article
                                        #:is-logged-in
                                        is-logged-in)))))))

(define* (article-new-page G_ #:key is-logged-in)
  (let* ((write-form
          `(form (@ (method POST)
                    (action "/articles/new")
                    (class ,(mk-class '(flex flex-col gap-2))))
                 ,(input #:label (G_ "title")
                         #:name "display-name")
                 ,(input #:label (G_ "a video address, if it is one")
                         #:name "video-url")
                 (div (@ (class "flex flex-col gap-1 max-w-prose"))
                      (span (@ (class ,(mk-class '(text-sm
                                                   font-semibold
                                                   text-onyx-700
                                                   dark:text-stone-300))))
                            ,(G_ "what it is"))
                      (select (@ (name "kind")
                                 (id "kind")
                                 (class "p-2 rounded-xl border-2 border-stone-700 dark:border-onyx-100 dark:text-stone-300 dark:bg-onyx-700/75 bg-stone-300/75 w-full"))
                              ,@(map (lambda (kind)
                                       `(option (@ (value ,(kind-string kind)))
                                                ,(article-kind-word G_ kind)))
                                     article-kinds)))
                 ,(textarea #:label (G_ "the article itself, in Org")
                            #:name "contents"
                            #:required #t)
                 (div (@ (class "flex flex-row gap-2"))
                      ,(button (G_ "post it")
                               #:type 'submit))))
         (body `((div (@ (class ,(mk-class articles-column-classes)))
                      ,(wm-page-heading "dark:text-stone-300 font-light font-sans hg-leading-display text-3xl text-onyx-300" (G_ "write an article"))
                      ,@(if is-logged-in
                            (list write-form)
                            (list (list 'p
                                        (list '@ (list 'class
                                                       "max-w-prose text-md text-onyx-500 dark:text-stone-300"))
                                        (G_ "an account is needed to write; anyone may comment"))))))))
    (html-template G_
                   #:is-logged-in is-logged-in
                   #:title "Write an article | WikiMusic"
                   #:description "Write a tutorial, a chord guide, a piece of music theory or a discussion for the readers of WikiMusic."
                   #:path "/articles/new"
                   #:robots "noindex, follow"
                   #:body body)))
