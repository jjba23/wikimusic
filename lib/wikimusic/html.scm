;;; wikimusic - the free music knowledge encyclopaedia

;; Copyright © 2025 "Josep Bigorra" known as "jjba23" <jjbigorra@gmail.com>

;; wikimusic is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; wikimusic is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with wikimusic.  If not, see <https://www.gnu.org/licenses/>.

(define-module (wikimusic html)
  #:use-module (web server)
  #:use-module (web request)
  #:use-module (web response)
  #:use-module (web uri)
  #:use-module (json)
  #:use-module (ice-9 popen)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 time)
  #:use-module (ice-9 format)
  #:use-module (ice-9 string-fun)
  #:use-module (ice-9 iconv)
  #:use-module (ice-9 hash-table)
  #:use-module (ice-9 threads)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (ice-9 textual-ports)
  #:use-module (artanis route))


(define-public (page-footer G_)
  `((div (@ (class "block text-center font-sans"))
         (div (@ (class
                   "flex flex-row flex-wrap gap-2 justify-center align-center py-3"))
              (p (@ (class "text-sm text-stone-600"))
                 ,(G_ "find the source code here"))
              (a (@ (class "text-stone-800 font-bold cursor-pointer text-sm")
                    (href "https://codeberg.org/jjba23/wikimusic"))
                 "https://codeberg.org/jjba23/wikimusic"))
         (p (@ (class "py-3"))
            (em (@ (class "text-md text-stone-600"))
                ,(G_ "Copyright 2025 © Josep Bigorra")))
         (p (@ (class "py-3"))
            (span (@ (class "text-sm text-stone-600"))
                  ,(G_ "the free music knowledge encyclopaedia"))))))

(begin
  (define* (html-template G_
                          #:key body
                          (proj '()))
    (define nav
      `(div (@ (class
                 "flex flex-row flex-wrap gap-3 p-3 bg-transparent items-center justify-left w-full shadow-md"))
            (a (@ (class "text-md text-stone-800 font-sans font-black px-4")
                  (href "/")) "Wikimusic")
            (a (@ (class "text-sm lowercase text-stone-800 font-sans font-medium px-2")
                  (href "/login"))
               ,(G_ "Login"))
            (a (@ (class "text-sm lowercase text-stone-800 font-sans font-medium px-2")
                  (href "/songs"))
               ,(G_ "Songs"))
            (a (@ (class "text-sm lowercase text-stone-800 font-sans font-medium px-2")
                  (href "/genres"))
               ,(G_ "Genres"))
            (a (@ (class "text-sm lowercase text-stone-800 font-sans font-medium px-2")
                  (href "/artists"))
               ,(G_ "Artists"))))
    `(html (head (title "Wikimusic")
                 (link (@ (rel "preconnect")
                          (href "https://fonts.googleapis.com")))
                 (link (@ (rel "preconnect")
                          (href "https://fonts.gstatic.com")
                          (crossorigin "")))
                 (link (@ (rel "stylesheet")
                          (href "https://fonts.cdnfonts.com/css/work-sans")))
                 (link (@ (rel "stylesheet")
                          (href "/css/fonts.css")))
                 (meta (@ (name "viewport")
                          (content "width=device-width, initial-scale=1.0")))
                 (script (@ (src "https://cdn.tailwindcss.com")) "")
                 (script (@ (src "/js/tailwind.config.js")) ()))
           (body (@ (class "bg-stone-200/50"))
                 (div (@ (class "flex flex-col h-screen justify-between"))
                      (div ,nav
                           (div (@(class "py-8")) ,body))
                      (footer ,(page-footer G_))))))
  (export html-template))

(define-public (item-tile G_ entity x)
  `(div (@(class "flex flex-col p-2"))
        (a (@(class "text-blue-800")
            (href ,(format #f "/~a/uuid/~a" entity (assoc-ref x "identifier"))))
           (span ,(assoc-ref x "display_name")))
        (span
         ,(G_ "views")
         ,(format #f "~a" (assoc-ref x "views")))
        )
  )
