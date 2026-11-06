;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Articles: the pages readers write for other readers.
;;;
;;; Writing one needs an account, because a page on this site is somebody's
;;; work and this instance keeps a name against it.  Commenting on one does not:
;;; a musician reading a chord guide should be able to say what worked for them
;;; without signing up first, so the comment route has no session check at all
;;; and the only thing standing between it and a flood of spam is the trap the
;;; form carries and the lengths the row allows.
;;;
;;; A trapped comment is answered exactly like a posted one -- the same redirect,
;;; the same page, the same absence of the comment -- because a spam script told
;;; it was caught is a spam script that gets rewritten.  Nothing about it is
;;; logged with the reader's address.

(define-artanis-controller articles)

(import (wikimusic html)
        (web uri)
        (ice-9 string-fun)
        (ice-9 time)
        (kracht prelude)
        (uuid generate)
        (wikimusic env)
        (wikimusic auth)
        (wikimusic controller)
        (wikimusic domain user)
        (wikimusic sqlite user)
        (wikimusic domain article)
        (wikimusic sqlite article)
        (wikimusic domain article-comment)
        (wikimusic sqlite article-comment)
        (app views articles))

;; A page of the list holds twenty articles: enough to fill a screen without
;; making the page a scroll to the end, and small enough that a slow instance
;; still answers.
(define articles-per-page
  20)

(get "/articles"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (let* ((repo (make-sqlite-article-repository rc))
              (page (max 1
                         (or (string->number (or (get-from-qstr rc "page") "1"))
                             1)))
              (offset (* (- page 1) articles-per-page))
              (total (count-articles repo))
              (pages (max 1
                          (ceiling (/ total articles-per-page))))
              (articles (get-articles repo
                                      #:limit articles-per-page
                                      #:offset offset)))
         (response-emit (:mime rc
                               (articles-list-page (:i18n rc)
                                                   #:articles articles
                                                   #:pages pages
                                                   #:page page
                                                   #:is-logged-in (:cookies-value
                                                                   rc
                                                                   "x-bewaking-wikimusic")))))))

(get "/articles/new"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (response-emit (:mime rc
                             (article-new-page (:i18n rc)
                                               #:is-logged-in (:cookies-value
                                                               rc
                                                               "x-bewaking-wikimusic"))))))

;; The body of an article is Org, escaped as it is written: the same rule a
;; song's description follows, because both are the reader's text and both are
;; rendered as Org rather than as HTML.  A comment is not Org -- it is a sentence
;; or two -- so it is stored as typed and escaped by the markup when it is shown,
;; which is the only escaping it needs.
(post "/articles/new"
      #:mime 'xml
      #:i18n '(cookie "lang")
      #:cookies '(names x-bewaking-wikimusic)
      (lambda (rc)
        (let* ((session (session-payload rc))
               (created-by (and session
                                (assoc-ref session
                                           'owner-id)))
               (body (body-alist rc))
               (display-name (html-escape (or (assoc-ref body "display-name")
                                              "")))
               (kind (assoc-ref body "kind"))
               (video-url (assoc-ref body "video-url"))
               (contents (html-escape (or (assoc-ref body "contents") ""))))
          (cond
            ((not created-by) (forbidden rc))
            ((string-null? (string-trim-both display-name)) (forbidden rc))
            (else (let ((identifier (generate-string-uuid)))
                    (insert-article (make-sqlite-article-repository rc)
                                  (list (cons 'identifier
                                              (generate-string-uuid))
                                        (cons 'display-name display-name)
                                        (cons 'kind
                                              (symbol->string
                                               (article-kind-named kind)))
                                        (cons 'contents contents)
                                        (cons 'created-by created-by)
                                        (cons 'visibility-status 0)
                                        (cons 'created-at (current-time))
                                        (cons 'views 0)))
                    (redirect-to rc
                                 (format #f "/articles/uuid/~a"
                                          identifier)
                                 #:status 302)))))))

(get "/articles/uuid/:uuid"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (let* ((article-id (params rc "uuid"))
              (article-repo (make-sqlite-article-repository rc))
              (comment-repo (make-sqlite-article-comment-repository rc))
              (user-repo (make-sqlite-user-repository rc))
              (article (entity-or-404 (get-article-by-id article-repo
                                                         article-id)
                                      "article" article-id))
              (comments (get-article-comments comment-repo
                                              (list article-id)))
              (user-alist (map (lambda (identifier)
                                 (cons identifier
                                       (get-user-by-id user-repo identifier)))
                               (filter-map (lambda (comment)
                                             (assq-ref comment
                                                       'created-by))
                                           comments))))
         (response-emit (:mime rc
                               (article-page (:i18n rc)
                                             #:article article
                                             #:comments comments
                                             #:user-alist user-alist
                                             #:is-logged-in (:cookies-value
                                                             rc
                                                             "x-bewaking-wikimusic")))))))

;; The one write on this site a reader needs no account for.
;;
;; The article is looked up first, so a comment posted to an address that names
;; no article is a 404 rather than a row hanging off nothing.  A trapped body is
;; then redirected exactly where a real one goes, and nothing is written: the
;; answer is the reader's page either way, which is what keeps the trap quiet.
(post "/articles/uuid/:uuid/comments/new"
      #:mime 'xml
      #:i18n '(cookie "lang")
      #:cookies '(names x-bewaking-wikimusic)
      (lambda (rc)
        (let* ((article-id (params rc "uuid"))
               (article (entity-or-404 (get-article-by-id
                                        (make-sqlite-article-repository rc)
                                        article-id)
                                       "article" article-id))
               (body (body-alist rc))
               (session (session-payload rc))
               (created-by (and session (assoc-ref session 'owner-id)))
               (posted-name (and (not created-by)
                                 (assoc-ref body "author-name")))
               (typed-name (and (string? posted-name)
                                (not (string-null?
                                      (string-trim-both posted-name)))
                                (substring (string-trim-both posted-name)
                                           0
                                           (min 80
                                                (string-length
                                                 (string-trim-both
                                                  posted-name))))))
               (posted (assoc-ref body "contents"))
               (contents (and (string? posted)
                              (not (string-null?
                                    (string-trim-both posted)))
                              posted))
               (where (format #f "/articles/uuid/~a#comments"
                              article-id)))
          (unless (or (honeypot-tripped? body) (not contents))
            (insert-article-comment
             (make-sqlite-article-comment-repository rc)
             (append (list (cons 'identifier (generate-string-uuid))
                           (cons 'article-identifier article-id)
                           (cons 'visibility-status 0)
                           (cons 'contents contents)
                           (cons 'created-at (current-time)))
                     (if created-by
                         (list (cons 'created-by created-by))
                         '())
                     (if typed-name
                         (list (cons 'author-name typed-name))
                         '()))))
          (redirect-to rc where #:status 302))))
