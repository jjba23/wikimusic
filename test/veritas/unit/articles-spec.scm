;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;;
;;; Articles: the pages a reader writes for other readers -- a tutorial, a
;;; video, a chord guide, a piece of theory, a discussion -- and the comments
;;; that hang off them.
;;;
;;; Two rules are pinned here because they are the ones a page can get wrong
;;; without anybody noticing.  The first is the kind: a form posts a word, and a
;;; word nobody offers is the tutorial it defaults to rather than a new kind the
;;; rest of the site has never heard of.  The second is who may comment: anyone,
;;; with no account at all, which is why the form asks a signed-out reader for a
;;; name and why the trap it carries has to be filled in by nobody.

(define-module (veritas unit articles-spec)
  #:use-module (veritas veritas)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:use-module ((artanis utils)
                #:select (sxml->xml-string))
  #:use-module (wikimusic domain article)
  #:use-module (app views articles)
  #:export (spec))

;; The translation of a page under test is the identity: what is asserted here
;; is the markup the view builds, not the wording of any one language.
(define (G_ key)
  key)

(define (html sxml)
  "Return the HTML SXML serializes to."
  (sxml->xml-string sxml))

(define (contains? text needle)
  "Return #t when TEXT holds NEEDLE, as a boolean."
  (and (string-contains text needle) #t))

(define* (article-row #:key (identifier "article-1")
                      (display-name "Barre chords without pain")
                      (kind "tutorial")
                      (contents "Start with the shape, not the pressure."))
  "Return a row shaped the way the views read one."
  `((identifier . ,identifier)
    (display-name . ,display-name)
    (kind . ,kind)
    (contents . ,contents)
    (created-by . "a-user")
    (views . 3)
    (created-at . "2026-11-06")
    (visibility-status . 0)))

(define kind-suite
  (suite "The kind of thing an article is"
    (test "the kinds a reader may write are the five the site shows"
      (assert-equal #:name "a tutorial comes first"
        #:expect 'tutorial
        #:got (car article-kinds))
      (assert-equal #:name "and a discussion last"
        #:expect 'discussion
        #:got (last article-kinds))
      (assert-equal #:name "five of them"
        #:expect 5
        #:got (length article-kinds)))

    (test "a kind posted as a word is the kind it names"
      (assert-equal #:name "a video"
        #:expect 'video
        #:got (article-kind-named "video"))
      (assert-equal #:name "a chord guide"
        #:expect 'chord-guide
        #:got (article-kind-named "chord-guide")))

    (test "a word nobody offers is the first kind, not a sixth one"
      (assert-equal #:name "a word invented by the form"
        #:expect 'tutorial
        #:got (article-kind-named "a-kind-of-my-own"))
      (assert-equal #:name "and an absent word"
        #:expect 'tutorial
        #:got (article-kind-named #f)))

    (test "every kind carries the word the page offers it under"
      (let ((named (map (lambda (kind)
                          (article-kind-word G_ kind))
                        article-kinds)))
        (assert-equal #:name "one word per kind"
          #:expect 5
          #:got (length named))
        (assert-true (every (lambda (word)
                              (and (string? word)
                                (not (string-null? word))))
                            named)
          #:name "and none of them empty")))))

(define trap-suite
  (suite "The trap a comment form carries"
    (test "a comment that filled the trap is refused"
      (assert-true (honeypot-tripped? '(("website"
                                         . "http://spam.example")))
        #:name "the field a reader cannot see was filled"))

    (test "a comment that left it alone is not"
      (assert-true (not (honeypot-tripped? '(("website" . ""))))
        #:name "the field was left empty")
      (assert-true (not (honeypot-tripped? '(("contents" . "hello"))))
        #:name "and a comment that never carried it"))

    (test "whitespace in the trap is still a filled trap"
      (assert-true (honeypot-tripped? '(("website" . "   ")))
        #:name "a bot that padded its answer"))))

;; The page as a reader meets it.
(define (comment-form-html)
  (html (article-comment-form G_
                              #:article (article-row)
                              #:is-logged-in #f)))

(define page-suite
  (suite "The page an article is read on"
    (test "the article is shown with the kind it was written as"
      (assert-true (contains? (html (article-page G_
                                                  #:article (article-row)
                                                  #:comments '()
                                                  #:is-logged-in #f))
                              "Barre chords without pain")
        #:name "its title")
      (assert-true (contains? (html (article-page G_
                                                  #:article (article-row
                                                             #:kind
                                                             "chord-guide")
                                                  #:comments '()
                                                  #:is-logged-in #f))
                              "chord guide")
        #:name "and the word for its kind"))

    (test "an owner is offered edit and delete controls"
      (let ((page (html (article-page G_
                                     #:article (article-row)
                                     #:comments '()
                                     #:is-logged-in #t
                                     #:can-edit? #t))))
        (assert-true (contains? page "/articles/uuid/article-1/edit")
          #:name "the edit link")
        (assert-true (contains? page "/articles/uuid/article-1/delete")
          #:name "the delete form")))

    (test "a reader is not offered controls they cannot use"
      (let ((page (html (article-page G_
                                     #:article (article-row)
                                     #:comments '()
                                     #:is-logged-in #f))))
        (assert-false (contains? page "/articles/uuid/article-1/edit")
          #:name "no edit link")
        (assert-false (contains? page "/articles/uuid/article-1/delete")
          #:name "no delete form")))

    (test "the edit form is filled in and posts to the article"
      (let ((page (html (article-edit-page G_
                                           #:article (article-row
                                                      #:contents "Start&apos;s here")
                                           #:is-logged-in #t))))
        (assert-true (contains? page "/articles/uuid/article-1/edit")
          #:name "the form action")
        (assert-true (contains? page "Barre chords without pain")
          #:name "the current title")
        (assert-true (contains? page "Start's here")
          #:name "the current body")))

    (test "stored entities are decoded before the article is rendered"
      (let ((page (html (article-page G_
                                     #:article (article-row
                                                #:contents "It&apos;s &ldquo;fine&rdquo; &mdash; caf&eacute;")
                                     #:comments '()
                                     #:is-logged-in #f))))
        (assert-true (contains? page "It's “fine” — café")
          #:name "apostrophes, quotation marks and accents are shown as characters")
        (assert-true (not (contains? page "&amp;apos;"))
          #:name "not as escaped text")))

    (test "a title stored with entities is decoded before it is shown"
      (let ((page (html (article-page G_
                                     #:article (article-row
                                                #:display-name "Don&apos;t fear barre chords")
                                     #:comments '()
                                     #:is-logged-in #f))))
        (assert-true (contains? page "Don't fear barre chords")
          #:name "the apostrophe is a character")
        (assert-true (not (contains? page "&amp;apos;"))
          #:name "not escaped text")))

    (test "the list preview decodes the stored entities too"
      (let ((page (html (articles-list-page G_
                                           #:articles (list
                                                       (article-row
                                                        #:display-name "Don&apos;t fear barre chords"
                                                        #:contents "It&apos;s &ldquo;fine&rdquo; &mdash; caf&eacute;"))
                                           #:pages 1
                                           #:page 1
                                           #:is-logged-in #f))))
        (assert-true (contains? page "Don't fear barre chords")
          #:name "the title shows its apostrophe")
        (assert-true (contains? page "/articles/new")
          #:name "the write link")
        (assert-true (contains? page "It's “fine” — café")
          #:name "the preview shows characters")
        (assert-true (not (contains? page "&amp;apos;"))
          #:name "not escaped text")))

    (test "a signed-out reader is asked for a name and no account"
      (assert-true (contains? (comment-form-html)
                              "name=\"author-name\"")
        #:name "the name field")
      (assert-true (contains? (comment-form-html) "name=\"contents\"")
        #:name "and the comment itself"))

    (test "a signed-in reader is not asked for a name"
      (assert-true (not (contains? (html (article-comment-form
                                          G_
                                          #:article (article-row)
                                          #:is-logged-in #t))
                                   "name=\"author-name\""))
        #:name "no name field"))

    (test "the trap is in the form and out of the reader's way"
      (assert-true (contains? (comment-form-html) "name=\"website\"")
        #:name "the trap is posted like any other field")
      (assert-true (contains? (comment-form-html) "wm-honeypot")
        #:name "and it is hidden by the site's own class")
      (assert-true (not (contains? (comment-form-html) "website</label>"))
        #:name "a reader is never asked for it in words"))

    (test "the form posts to the article's own comment route"
      (assert-true (contains? (comment-form-html)
                              "/articles/uuid/article-1/comments/new")
        #:name "the route the article's comments hang off"))))

(define (spec)
  (veritas-run kind-suite trap-suite page-suite))
