;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;;
;;; The REST API's routes.  Every one of them is answered by the same
;;; generated dispatcher: the paths below only have to let Artanis hand the
;;; request over, and the matching, decoding and rendering happen in
;;; `(wikimusic api)' around `(wikimusic-api controllers)'.
;;;
;;; A route names a placeholder because Artanis needs one to compile the
;;; pattern; the dispatcher reads the path from the request itself, so the
;;; placeholder's name is not used.

(define-artanis-controller api)

(import (wikimusic api))

(define (serve rc)
  (emit-api-response (serve-api rc)))

(get "/api/v1/songs" serve)
(get "/api/v1/songs/:id" serve)
(get "/api/v1/songs/:id/versions" serve)
(get "/api/v1/artists" serve)
(get "/api/v1/artists/:id" serve)
(get "/api/v1/artists/:id/songs" serve)
(get "/api/v1/genres" serve)
(get "/api/v1/genres/:id" serve)
(get "/api/v1/genres/:id/songs" serve)
(get "/api/v1/instance" serve)
