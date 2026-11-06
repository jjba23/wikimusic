;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; The tuner reads no rows and holds no state: every preset is the same page
;;; rendered for a different instrument, so all the route asks of the request is
;;; which preset was named and the two things the shell around the page needs.
;;;
;;; The name is validated where the tuning is looked up (`preset-id-named'), so a
;;; preset nobody offers is the default tuning rather than an error page -- a
;;; reader who mistypes an address gets a tuner, which is what they wanted.

(define-artanis-controller tuner)

(import (app views tuner)
        (kracht prelude)
        (wikimusic domain tuning)
        (wikimusic html))

(get "/tuner"
     #:mime 'xml
     #:i18n '(cookie "lang")
     #:cookies '(names x-bewaking-wikimusic)
     (lambda (rc)
       (response-emit (:mime rc
                             (tuner-page (:i18n rc)
                                         #:preset (preset-id-named
                                                   (get-from-qstr rc "preset"))
                                         #:is-logged-in (:cookies-value rc
                                                         "x-bewaking-wikimusic"))))))
