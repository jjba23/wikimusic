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

(define-module (wikimusic auth)
  #:use-module (web uri)
  #:use-module (artanis artanis)
  #:export (protected-api-endpoint protected-endpoint))

(define-syntax-rule (protected-api-endpoint rc happy-flow-thunk)
  "Protect an HTTP REST endpoint, preventing unauthorized access and returning proper error response."
  (cond
   ((:auth rc)
    (happy-flow-thunk))
   (else (:mime rc
          '((error . "You must be authenticated to use this API endpoint"))))))

(define-syntax-rule (protected-endpoint rc happy-flow-thunk)
  "Protect an HTTP endpoint, preventing unauthorized access and redirecting to login page upon errors."
  (cond
   ((:session rc
     'check)
    (happy-flow-thunk))
   ((:auth rc)
    (:session rc
     'spawn)
    (happy-flow-thunk))
   (else (redirect-to rc
                      (string->uri (format #f "~a/login"
                                           (current-myhost)))
                      #:status 302))))
