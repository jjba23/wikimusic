;;; wikimusic - the free music knowledge encyclopaedia

;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;; wikimusic is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; wikimusic is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU Affero General Public License for more details.

;; You should have received a copy of the GNU Affero General Public License
;; along with wikimusic.  If not, see <https://www.gnu.org/licenses/>.

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
                                         #:is-logged-in (:cookies-value
                                                         rc
                                                         "x-bewaking-wikimusic"))))))
