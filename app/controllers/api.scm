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
;;; placeholder's name is not used.  Every route declares the session cookie
;;; even where it does not require one, because the API accepts a cookie for a
;;; browser client and a bearer token for every other client.

(define-artanis-controller api)

(import (wikimusic api))

(define (serve rc)
  (emit-api-response (serve-api rc)))

(define routes
  '((get "/api/v1/songs")
    (post "/api/v1/songs")
    (get "/api/v1/songs/:id")
    (patch "/api/v1/songs/:id")
    (delete "/api/v1/songs/:id")
    (get "/api/v1/songs/:id/versions")
    (post "/api/v1/songs/:id/versions")
    (get "/api/v1/songs/:id/versions/:version")
    (patch "/api/v1/songs/:id/versions/:version")
    (delete "/api/v1/songs/:id/versions/:version")
    (get "/api/v1/songs/:id/comments")
    (post "/api/v1/songs/:id/comments")
    (patch "/api/v1/songs/:id/comments/:comment")
    (delete "/api/v1/songs/:id/comments/:comment")
    (post "/api/v1/songs/:id/artworks")
    (patch "/api/v1/songs/:id/artworks/:artwork")
    (delete "/api/v1/songs/:id/artworks/:artwork")
    (post "/api/v1/songs/:id/artists")
    (delete "/api/v1/songs/:id/artists/:artist")
    (post "/api/v1/songs/:id/genres")
    (delete "/api/v1/songs/:id/genres/:genre")
    (get "/api/v1/songs/:id/external-sources")
    (post "/api/v1/songs/:id/external-sources")
    (patch "/api/v1/songs/:id/external-sources/:source")
    (post "/api/v1/songs/:id/like")
    (post "/api/v1/songs/:id/dislike")
    (get "/api/v1/artists")
    (post "/api/v1/artists")
    (get "/api/v1/artists/:id")
    (patch "/api/v1/artists/:id")
    (delete "/api/v1/artists/:id")
    (get "/api/v1/artists/:id/songs")
    (get "/api/v1/artists/:id/comments")
    (post "/api/v1/artists/:id/comments")
    (patch "/api/v1/artists/:id/comments/:comment")
    (delete "/api/v1/artists/:id/comments/:comment")
    (post "/api/v1/artists/:id/artworks")
    (patch "/api/v1/artists/:id/artworks/:artwork")
    (delete "/api/v1/artists/:id/artworks/:artwork")
    (get "/api/v1/artists/:id/external-sources")
    (post "/api/v1/artists/:id/external-sources")
    (patch "/api/v1/artists/:id/external-sources/:source")
    (post "/api/v1/artists/:id/like")
    (post "/api/v1/artists/:id/dislike")
    (get "/api/v1/genres")
    (post "/api/v1/genres")
    (get "/api/v1/genres/:id")
    (patch "/api/v1/genres/:id")
    (delete "/api/v1/genres/:id")
    (get "/api/v1/genres/:id/songs")
    (get "/api/v1/genres/:id/comments")
    (post "/api/v1/genres/:id/comments")
    (patch "/api/v1/genres/:id/comments/:comment")
    (delete "/api/v1/genres/:id/comments/:comment")
    (post "/api/v1/genres/:id/artworks")
    (patch "/api/v1/genres/:id/artworks/:artwork")
    (delete "/api/v1/genres/:id/artworks/:artwork")
    (get "/api/v1/genres/:id/external-sources")
    (post "/api/v1/genres/:id/external-sources")
    (patch "/api/v1/genres/:id/external-sources/:source")
    (post "/api/v1/genres/:id/like")
    (post "/api/v1/genres/:id/dislike")
    (get "/api/v1/articles")
    (post "/api/v1/articles")
    (get "/api/v1/articles/:id")
    (get "/api/v1/articles/:id/comments")
    (post "/api/v1/articles/:id/comments")
    (post "/api/v1/login")
    (post "/api/v1/logout")
    (get "/api/v1/me")
    (get "/api/v1/users")
    (post "/api/v1/users")
    (patch "/api/v1/users/:id")
    (delete "/api/v1/users/:id")
    (get "/api/v1/instance")))

(for-each
 (lambda (route)
   (let ((path (cadr route)))
     (case [car route]
       [(get) (get path #:cookies '(names x-bewaking-wikimusic) serve)]
       [(post) (post path #:cookies '(names x-bewaking-wikimusic) serve)]
       [(patch) (patch path #:cookies '(names x-bewaking-wikimusic) serve)]
       [(put) (put path #:cookies '(names x-bewaking-wikimusic) serve)]
       [(delete)
        (page-delete path #:cookies '(names x-bewaking-wikimusic) serve)])))
 routes)
