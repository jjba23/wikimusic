;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;;
;;; The API write path has two contracts that are easy to lose because no
;;; generated type checks them: the dispatcher calls every handler with the
;;; request *and* the path arguments, and a file field that the client did not
;;; send is absence, not a value.  A one-argument wrapper answers every write
;;; with a 500 and an untouched file input used to become the string "#f",
;;; which the API then reported as a real PDF.  These tests pin both.

(define-module (veritas unit api-write-spec)
  #:use-module (veritas veritas)
  #:use-module (ice-9 receive)
  #:use-module (wikimusic api)
  #:use-module (wikimusic-api models)
  #:export (spec))

(define (protected-answer session error)
  "Call a protected handler the way the generated dispatcher does."
  (let ((seen #f))
    (let ((handler (protected-handler
                     (lambda () (values session error))
                     (lambda (request-session args)
                       (set! seen (list request-session args))
                       'answered))))
      (values (handler 'request '((identifier . "entry-1"))) seen))))

(define (version-row pdf guitarpro)
  "Return a song-content row carrying PDF and GUITARPRO."
  (list (cons 'identifier "00000000-0000-4000-8000-000000000001")
        (cons 'version-name "Guitar tab")
        (cons 'instrument-type "guitar")
        (cons 'ascii-legend "Numbers are frets.")
        (cons 'ascii-contents "e|----------------|")
        (cons 'pdf-contents pdf)
        (cons 'guitarpro-contents guitarpro)
        (cons 'created-at "2026-11-07T00:00:00Z")))

(define (artwork-row content-url)
  "Return an artwork row whose image is CONTENT-URL."
  (list (cons 'identifier "00000000-0000-4000-8000-000000000003")
        (cons 'content-url content-url)
        (cons 'content-caption "A caption")
        (cons 'order-value 0)))

(define (external-source-row wikipedia-url)
  "Return an external-source row whose only link is WIKIPEDIA-URL."
  (list (cons 'identifier "00000000-0000-4000-8000-000000000002")
        (cons 'spotify-url #f)
        (cons 'youtube-url #f)
        (cons 'soundcloud-url #f)
        (cons 'wikipedia-url wikipedia-url)
        (cons 'created-at "1794045174")))

(define protected-handler-suite
  (suite "A protected API handler"
    (test "it takes the dispatcher's request and path arguments"
      (receive (answer seen)
        (protected-answer '((owner-id . "user-1")) #f)
        (assert-equal #:name "the handler answers"
          #:expect 'answered
          #:got answer)
        (assert-equal #:name "the authenticated session reaches the handler"
          #:expect '((owner-id . "user-1"))
          #:got (car seen))
        (assert-equal #:name "the path arguments reach the handler"
          #:expect '((identifier . "entry-1"))
          #:got (cadr seen))))

    (test "an unauthorized request answers without calling the handler"
      (receive (answer seen)
        (protected-answer #f 'unauthorized)
        (assert-equal #:name "the authorization answer is returned"
          #:expect 'unauthorized
          #:got answer)
        (assert-false seen
          #:name "the handler never ran")))))

(define version-presence-suite
  (suite "Whether a version carries a file"
    (test "a placeholder left by an empty file input is not a file"
      (for-each (lambda (placeholder)
                  (let ((version (version-record (version-row placeholder
                                                             placeholder))))
                    (assert-false (song-version-has-pdf version)
                      #:name "no PDF is reported")
                    (assert-false (song-version-has-tablature version)
                      #:name "no Guitar Pro file is reported")))
                '("#f" "" "data:application/octet-stream;base64,")))

    (test "a data URL with bytes is a file"
      (let ((version (version-record
                      (version-row "data:application/pdf;base64,JVBERi0="
                                   "data:application/x-guitar-pro;base64,R1A1"))))
        (assert-true (song-version-has-pdf version)
          #:name "the PDF is reported")
        (assert-true (song-version-has-tablature version)
          #:name "the Guitar Pro file is reported")))))

(define artwork-url-suite
  (suite "An artwork row"
    (test "an empty URL is not an artwork"
      (assert-equal #:name "only the usable artwork is kept"
        #:expect 1
        #:got (length (artwork-records
                        (list (artwork-row "")
                              (artwork-row
                               "https%253A%252F%252Fexample.org%252Fcover.jpg"))))))

    (test "a twice-encoded URL is decoded to the original"
      (let ((artwork (car (artwork-records
                            (list (artwork-row
                                   "https%253A%252F%252Fexample.org%252Fcover.jpg"))))))
        (assert-equal #:name "the URL is decoded twice"
          #:expect "https://example.org/cover.jpg"
          #:got (artwork-content-url artwork))))))

(define external-source-suite
  (suite "An external source"
    (test "an absent link is not an invalid URI"
      (let ((source (external-source-record (external-source-row ""))))
        (assert-false (external-source-wikipedia-url source)
          #:name "the empty link is absent")))

    (test "a stored encoded link is read back as the URI the client sent"
      (let ((source (external-source-record
                      (external-source-row
                       "https%3A%2F%2Fen.wikipedia.org%2Fwiki%2FAmazing_Grace"))))
        (assert-equal #:name "the link is decoded"
          #:expect "https://en.wikipedia.org/wiki/Amazing_Grace"
          #:got (external-source-wikipedia-url source))))))

(define timestamp-suite
  (suite "The timestamp a write records"
    (test "it is epoch seconds a page can read"
      (let ((stamp (api-timestamp)))
        (assert-true (string? stamp)
          #:name "the timestamp is text")
        (assert-true (number? (string->number stamp))
          #:name "the timestamp is a number")))))

(define (spec)
  (veritas-run protected-handler-suite version-presence-suite
               artwork-url-suite external-source-suite timestamp-suite))
