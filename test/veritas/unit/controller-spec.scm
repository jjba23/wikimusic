;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;;
;;; The one guard every detail page of the site hangs on.  A page addressed by
;;; an identifier is addressed by something a reader can mistype, edit or
;;; invent, so the lookup that found nothing has to answer -- and answer with
;;; the page a request that matched no route is given.  `entity-or-404' is the
;;; whole of that decision, and these are its two answers: the row it was given
;;; back untouched, or a 404 for artanis to render.
;;;
;;; Why here rather than through a request: the guard takes three values and
;;; answers with one of two things, so it can be read without a server, a
;;; database or a route context, and the two states worth pinning -- found
;;; nothing, found something -- are the ones a single request can only reach
;;; one at a time.
;;;
;;; There is a second reason to call it, and it is the reason this file exists
;;; at all.  The prose above a procedure is a string, and a quote in that prose
;;; which is not escaped ends the string where it stands: the words that follow
;;; are read as code, the file still compiles, and the mistake surfaces as an
;;; unbound variable the first time the procedure is called -- and not before.
;;; A test that calls the guard both ways is what makes that a failing test
;;; rather than a page that answers 500 to a reader who mistyped an address.

(define-module (veritas unit controller-spec)
  #:use-module (veritas veritas)
  #:use-module (ice-9 format)
  #:use-module (ice-9 ftw)
  #:use-module (ice-9 textual-ports)
  #:use-module (srfi srfi-1)
  #:use-module (artanis cookie)
  #:use-module (artanis route)
  #:use-module (web request)
  #:use-module (web uri)
  #:use-module (wikimusic controller)
  #:export (spec))

;; A row as a repository hands one back: an association list keyed by symbols.
(define found-row
  '((identifier . "1c9a5b7e-2f3a-4c5d-9e0f-1a2b3c4d5e6f")
    (display-name . "blue")))

(define (answer-for thunk)
  "Return the arguments THUNK raises an artanis-err with, or #f when it does
not raise one.

Artanis reads such an exception as a code, the name of what raised it, and a
format string with its arguments, which is the shape built here."
  (catch 'artanis-err
         (lambda ()
           (thunk) #f)
         (lambda (key . args)
           args)))

(define (status-of answer)
  "Return the HTTP status ANSWER carries, or #f when there is no answer."
  (and answer
    (car answer)))

(define (message-of answer)
  "Return the format string ANSWER carries, or #f when there is no answer."
  (and answer
    (>= (length answer) 3)
    (caddr answer)))

(define (message-args-of answer)
  "Return the arguments ANSWER's format string is filled in with, or #f when
there is no answer."
  (and answer
    (>= (length answer) 3)
    (cdddr answer)))

(define guard-suite
  (suite "The guard a mistyped address reaches"
    (test "a row that was found is handed on as it is"
      (assert-true (eq? found-row
                        (entity-or-404 found-row "song" "1c9a"))
        #:name "the very row comes back, not a copy")
      (assert-equal #:name "and nothing about it is rewritten"
        #:expect found-row
        #:got (entity-or-404 found-row "song" "1c9a"))
      (assert-true (eq? found-row
                        (entity-or-404 found-row "artist"
                                       "a-mistyped-identifier"))
        #:name "what it is called does not decide what it returns"))

    (test "a lookup that found nothing is answered with a 404"
      (let ((answer (answer-for (lambda ()
                                  (entity-or-404 #f "song" "nope")))))
        (assert-true (and answer #t)
          #:name "it raises rather than returning nothing")
        (assert-equal #:name
          "with the code artanis renders a page for"
          #:expect 404
          #:got (status-of answer))
        (assert-true (and (>= (length answer) 4) #t)
          #:name
          "in the shape artanis reads: code, name, message, arguments")
        (assert-true (and (string? (message-of answer)) #t)
          #:name "the message is a format string")
        (assert-true (and (list? (message-args-of answer)) #t)
          #:name "and its arguments come as a list")))

    (test "the answer says what was looked for, and where"
      (let ((answer (answer-for (lambda ()
                                  (entity-or-404 #f "genre"
                                                 "a-genre-that-is-not-there")))))
        (assert-equal #:name
          "the message names the kind of thing and the identifier"
          #:expect
          "no genre with the identifier a-genre-that-is-not-there"
          #:got (apply format #f
                       (message-of answer)
                       (message-args-of answer)))))

    (test
      "a lookup that found an empty list is a lookup that found nothing"
      ;; #f is what the repositories answer with, and the guard has to
      ;; agree with them about what "there is no such thing" is.
      (assert-equal #:name "an empty list is answered like #f"
        #:expect 404
        #:got (status-of (answer-for (lambda ()
                                       (entity-or-404 '()
                                                      "song"
                                                      "nope"))))))))

;;; ====== Who may change a row ======
;;;
;;; The ownership half of the rule, read on its own.  `may-mutate?' takes a
;;; session -- the payload a token carries -- and the `created_by' of the row a
;;; route is about to change, and answers with a boolean, so both refusals and
;;; permissions can be pinned without a request, a database or a route.  The
;;; four states worth pinning are: the super grant on any row, and a plain
;;; contributor on a row of their own, a row of somebody else's, and a row
;;; that names no creator at all.

(define super-session
  '((owner-id . "the-maintainer") (owner-permissions
                                   wikimusic:modify-permissions)))

(define contributor-session
  '((owner-id . "a-contributor") (owner-permissions wikimusic:song-create
                                                    wikimusic:artist-create)))

(define ownership-suite
  (suite "The ownership half of who may change a row"
    (test "the super grant changes any row, whoever made it"
      (assert-true (may-mutate? #:session super-session
                                #:created-by "another-user")
        #:name "a row another user created")
      (assert-true (may-mutate? #:session super-session
                                #:created-by "the-maintainer")
        #:name "and a row of its own"))

    (test "a contributor changes the row they made"
      (assert-true (may-mutate? #:session contributor-session
                                #:created-by "a-contributor")
        #:name "their own row is theirs to change"))

    (test "a contributor does not change a row somebody else made"
      (assert-false (may-mutate? #:session contributor-session
                                 #:created-by "another-contributor")
        #:name "someone else's row is refused"))

    (test
      "a row that names no creator is only the super grant's to change"
      (assert-false (may-mutate? #:session contributor-session
                                 #:created-by #f)
        #:name "a row with no creator is refused")
      (assert-true (may-mutate? #:session super-session
                                #:created-by #f)
        #:name "while the super grant may still change it"))))

;;; ====== A remembered choice belongs to the answer that made it ======
;;;
;;; Artanis builds one cookie record for a rule when the rule is registered and
;;; appends that record to every answer the rule gives (`new-oht' runs once, in
;;; `define-handler'), so `:cookies-set!' does not write "this reader's choice":
;;; it writes a value into a record that every later request shares.  A session
;;; token the last sign-in put there is handed to the next visitor, and a tab
;;; that grows from 100% to 200% under a reader who chose neither is that record
;;; doing its work, one visitor's choice arriving in the next visitor's jar.
;;;
;;; A cookie built in the request that made the choice belongs to that answer
;;; alone, which is what `remember-cookie!' builds.  Three things are pinned
;;; here: the cookie it builds, that one request's answer carries no cookie of
;;; another's, and that no route writes through a rule's record any more -- the
;;; bug is invisible in a review of a handler, because the call that looks
;;; per-request is not.

(define (source-of path)
  "Return the text of the file at PATH."
  (call-with-input-file path
    (lambda (port)
      (get-string-all port))))

(define (scheme-files-under directory)
  "Return every Scheme file at or below DIRECTORY."
  (append-map (lambda (name)
                (let ((path (string-append directory "/" name)))
                  (cond
                    ((string-suffix? ".scm" name)
                     (list path))
                    ((and (not (member name '("." "..")))
                       (eq? 'directory
                            (stat:type (stat path))))
                     (scheme-files-under path))
                    (else '()))))
              (scandir directory)))

(define (a-request-context)
  "Return a route context as artanis builds one, with no answer written in it."
  (let ((make-route-context (@@ (artanis route) make-route-context)))
    (make-route-context #f #f #f
                        (build-request (string->uri
                                        "http://wikimusic.test/login")
                                       #:method 'GET)
                        "/login" #f 'GET #f #f #vu8() #f '() '() #f #f #f)))

(define (answer-cookies rc)
  "Return the Set-Cookie lines the answer to RC carries."
  (map cookie->header-string (rc-set-cookie rc)))

(define remembering-suite
  (suite "A choice is remembered by the answer that made it"
    (test "the answer that makes a choice carries it"
      (let ((rc (a-request-context)))
        (remember-cookie! rc "wikimusic-ascii-size" "text-md")
        (let ((cookies (answer-cookies rc)))
          (assert-equal #:name "exactly one cookie is added"
            #:expect 1
            #:got (length cookies))
          (assert-true (and (string-contains (car cookies)
                                             "wikimusic-ascii-size=text-md")
                            #t)
            #:name "holding what the reader chose")
          (assert-true (and (string-contains (car cookies) "Path=/") #t)
            #:name "good for the whole site")
          (assert-true (and (string-contains (car cookies) "Expires=") #t)
            #:name "with a day to lapse on")
          (assert-true (and (string-contains (car cookies) "; Secure") #t)
            #:name "sent only over an encrypted connection")
          (assert-true (and (string-contains (car cookies) "; HttpOnly") #t)
            #:name "and out of reach of a script"))))

    (test "a session cookie lapses with the session it was given for"
      (let ((rc (a-request-context)))
        (remember-cookie! rc "x-bewaking-wikimusic" "a-token" #:expires 60)
        (let ((cookie (car (answer-cookies rc))))
          (assert-true (and (string-contains cookie
                                             "x-bewaking-wikimusic=a-token")
                            #t)
            #:name "it carries the token")
          (assert-true (and (string-contains cookie "Expires=") #t)
            #:name "and an expiry"))))

    (test "forgetting a cookie expires it before the reader arrived"
      (let ((rc (a-request-context)))
        (forget-cookie! rc "x-bewaking-wikimusic")
        (let ((cookie (car (answer-cookies rc))))
          (assert-true (and (string-contains cookie
                                             "x-bewaking-wikimusic=\"\"")
                            #t)
            #:name "the cookie is emptied")
          (assert-true (and (string-contains cookie "Thu, 01 Jan 1970") #t)
            #:name "and dated in the past, which is what removes it"))))

    (test "a sign-in on one request sets no cookie on another"
      (let ((signed-in (a-request-context))
            (later (a-request-context)))
        (remember-cookie! signed-in "x-bewaking-wikimusic" "the-token")
        (assert-equal #:name "the answer to the sign-in carries one cookie"
          #:expect 1
          #:got (length (rc-set-cookie signed-in)))
        (assert-equal #:name "the next request's answer carries none"
          #:expect '()
          #:got (rc-set-cookie later))))

    (test "no route writes through a rule's shared cookie record"
      (for-each (lambda (path)
                  (let ((source (source-of path)))
                    (assert-false (string-contains source "(:cookies-set")
                      #:name (format #f "~a sets no shared cookie" path))
                    (assert-false (string-contains source "(:cookies-setattr")
                      #:name (format #f "~a adjusts no shared cookie" path))
                    (assert-false (string-contains source "#:cookies '(names")
                      #:name
                      (format #f "~a names no cookie of its rule" path))))
                (append (scheme-files-under "app")
                        (scheme-files-under "lib"))))))

(define cookie-suite
  (suite "How a song page remembers a reader's choice"
    (test "an ascii choice is a cookie of its own answer"
      (let ((source (source-of "app/controllers/song-page.scm")))
        (assert-true (and (string-contains source
                                           "(remember-cookie! rc cookie chosen)")
                          #t)
          #:name "the route hands the choice to the answer it is building")
        (assert-false (string-contains source "(new-cookie")
          #:name "and builds no cookie of its own")))))

(define (spec)
  (veritas-run guard-suite ownership-suite remembering-suite cookie-suite))
