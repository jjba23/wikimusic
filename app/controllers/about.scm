;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; The one standing page the front page no longer is.
;;;
;;; The route holds no state and reads no rows: what the page says is the same
;;; for every reader, so all that is asked of the request is the language it is
;;; being read in and whether a reader is signed in -- the two things the shell
;;; around the page needs.  Serving it is therefore the view and nothing else,
;;; and the page is as cacheable as a page of prose can be.

(define-artanis-controller about)

(import (app views about)
        (kracht prelude)
        (wikimusic html))

(get "/about"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (response-emit (:mime rc
                             (about-page (:i18n rc)
                                         #:is-logged-in (:cookies-value rc
                                                         "x-bewaking-wikimusic"))))))
