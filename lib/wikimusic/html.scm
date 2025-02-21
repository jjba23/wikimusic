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

(begin
  (define-syntax-rule (cond-render item render-func)
    "Render HTML conditionally if item exists"
    (cond
      ((or (nil? item)
           (equal? item #f))
       '())
      (else (render-func item))))
  (export cond-render))

(define-public (page-footer G_)
  `((div (@ (class "block text-center font-sans"))
         (div (@ (class
                  "flex flex-row flex-wrap gap-2 justify-center align-center py-3"))
              (p (@ (class "text-sm text-stone-600"))
                 ,(G_ "find the source code here"))
              (a (@ (class "text-blue-800 font-bold cursor-pointer text-sm")
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
            (a (@ (class
                   "text-sm lowercase text-blue-800 font-sans font-medium px-2")
                  (href "/songs"))
               ,(G_ "Songs"))
            (a (@ (class
                   "text-sm lowercase text-blue-800 font-sans font-medium px-2")
                  (href "/genres"))
               ,(G_ "Genres"))
            (a (@ (class
                   "text-sm lowercase text-blue-800 font-sans font-medium px-2")
                  (href "/artists"))
               ,(G_ "Artists"))
            (a (@ (class
                   "text-sm lowercase text-blue-800 font-sans font-medium px-2")
                  (href "/login"))
               ,(G_ "Login"))))
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
                           (div (@ (class "py-8"))
                                ,body))
                      (footer ,(page-footer G_))))))
  (export html-template))

(begin
  (define* (item-tile G_
                      entity
                      x
                      artworks
                      opinions
                      comments
                      #:key (extra-info '()))
    (let ((item-link (format #f "/~as/uuid/~a" entity
                             (assoc-ref x "identifier")))
          (likes (length (filter (lambda (o)
                                   (equal? 1
                                           (assoc-ref o "is_like"))) opinions)))
          (dislikes (length (filter (lambda (o)
                                      (equal? 1
                                              (assoc-ref o "is_dislike")))
                                    opinions))))
      `(div (@ (class "flex flex-col py-3"))
            ,(cond-render (cond
                            ((equal? 0
                                     (length artworks))
                             '())
                            (else (car artworks)))
                          (lambda (art)
                            `(figure (@ (class "py-3 sm:w-48"))
                                     (a (@ (href ,item-link))
                                        (img (@ (loading "lazy")
                                                (class "rounded-xl")
                                                (src ,(assoc-ref art
                                                       "content_url"))))))))
            (a (@ (class "text-blue-800 text-xl font-medium")
                  (href ,item-link))
               (span ,(assoc-ref x "display_name")))
            (div (@ (class "flex flex-row gap-2"))
                 (span ,(G_ "views"))
                 (span ,(format #f "~a"
                                (assoc-ref x "views"))))
            (div (@ (class "flex flex-row gap-2"))
                 (span (@ (class "font-black text-green-800 text-xs"))
                       ,(format #f "~a" likes))
                 (span (@ (class "font-black text-red-800 text-xs"))
                       ,(format #f "~a" dislikes)))
            (div (@ (class "flex flex-row gap-2"))
                 (span (@ (class "text-xs"))
                       ,(format #f "~a"
                                (length comments)))
                 (span (@ (class "text-xs"))
                       ,(G_ "comments")))
            ,extra-info)))
  (export item-tile))

(define-public (render-visibility-status status)
  (cond
    ((eq? status 0)
     `(span "published"))
    (else `(span "unkown status"))))

(define-public (render-comment G_ user-alist comment)
  `(div (@ (class "py-3"))
        ,(cond-render (car (assoc-ref user-alist
                                      (assoc-ref comment "created_by")))
                      (lambda (u)
                        `(p (@ (class "text-xs text-stone-600"))
                            ,(format #f "~a (~a) &lt;~a&gt;"
                                     (assoc-ref u "display_name")
                                     (assoc-ref u "username")
                                     (assoc-ref u "email_address")))))
        (p (@ (class "text-sm text-stone-900"))
           ,(assoc-ref comment "contents"))
        (p (@ (class "text-xs text-stone-400"))
           ,(assoc-ref comment "created_at"))))

(define-public (render-comments G_ user-alist parent-identifier comments)
  (let* ((top-nodes (filter (lambda (c)
                              (equal? parent-identifier
                                      (assoc-ref c "parent_identifier")))
                            comments)))
    (map (lambda (comment)
           `((div (@ (class "max-w-prose"))
                  ,(render-comment G_ user-alist comment))
             (div (@ (class "max-w-prose pl-3"))
                  ,(render-comments G_ user-alist
                                    (assoc-ref comment "identifier") comments))))
         top-nodes)))

(define-public (entity-details G_
                               entity
                               x
                               artworks
                               opinions
                               comments
                               user-alist)
  (let* ((rendered-artworks (map (lambda (art)
                                   `(figure (@ (class "py-3 sm:w-48"))
                                            (img (@ (loading "lazy")
                                                    (class "rounded-xl")
                                                    (src ,(assoc-ref art
                                                                     "content_url"))))))
                                 artworks))
         (rendered-comments (render-comments G_ user-alist #f comments))
         (opinion-buttons `((div (@(class "flex flex-row flex-wrap gap-3"))
                                 (form (@(action ,(format #f "/~as/like/~a" entity (assoc-ref x "identifier"))))
                                       (button (@(type "submit")(class "text-white bg-green-900 p-2 rounded-xl")) ,(G_ "like")))
                                 (form (@(action ,(format #f "/~as/dislike/~a" entity (assoc-ref x "identifier"))))
                                       (button (@(type "submit")(class "text-white bg-red-900 p-2 rounded-xl")) ,(G_ "dislike"))))))
         (maybe-description (cond-render (assoc-ref x "description")
                                         (lambda (description)
                                           `(div (p (@ (class
                                                         "text-stone-700 font-bold"))
                                                    ,(G_ "description"))
                                                 (p (@ (class
                                                         "pl-3 text-stone-800 max-w-prose"))
                                                    ,description)))))
         (maybe-last-edited-at (cond-render (assoc-ref x "last_edited_at")
                                            (lambda (last-edited-at)
                                              `((dt (@ (class
                                                         "text-stone-700 font-bold"))
                                                    ,(G_ "last edited"))
                                                (dd (@ (class
                                                         "pl-3 text-stone-800"))
                                                    ,last-edited-at)))))
         (maybe-approved-by (cond-render (assoc-ref x "approved_by")
                                         (lambda (approved-by)
                                           `((dt (@ (class
                                                      "text-stone-700 font-bold"))
                                                 ,(G_ "approved by"))
                                             (dd (@ (class
                                                      "pl-3 text-stone-800"))
                                                 ,approved-by))))))
    
    `((div (@ (class "py-4 flex flex-row flex-wrap gap-6"))
           (div ,rendered-artworks)
           (div ,opinion-buttons
                ,maybe-description
                (dl (dt (@ (class "text-stone-700 font-bold"))
                        ,(G_ "views"))
                    (dd (@ (class "pl-3 text-stone-800"))
                        ,(format #f "~a"
                                 (assoc-ref x "views")))
                    (dt (@ (class "text-stone-700 font-bold"))
                        ,(G_ "created"))
                    (dd (@ (class "pl-3 text-stone-800"))
                        ,(assoc-ref x "created_at"))
                    ,maybe-last-edited-at
                    (dt (@ (class "text-stone-700 font-bold"))
                        ,(G_ "contributor"))
                    (dd (@ (class "pl-3 text-stone-800"))
                        ,(cond-render (car (assoc-ref user-alist
                                                      (assoc-ref x
                                                                 "created_by")))
                                      (lambda (u)
                                        `(div (@ (class
                                                   "flex flex-wrap flex-row gap-2"))
                                              (span ,(format #f
                                                             "~a (~a) &lt;~a&gt;"
                                                             (assoc-ref u
                                                                        "display_name")
                                                             (assoc-ref u "username")
                                                             (assoc-ref u
                                                                        "email_address")))))))
                    (dt (@ (class "text-stone-700 font-bold"))
                        ,(G_ "visibility"))
                    (dd (@ (class "pl-3 text-stone-800"))
                        ,(render-visibility-status (assoc-ref x
                                                              "visibility_status")))
                    ,maybe-approved-by
                    (dt (@ (class "text-stone-700 font-bold"))
                        ,(G_ "uuid"))
                    (dd (@ (class "pl-3 text-sm text-stone-500"))
                        ,(assoc-ref x "identifier")))))
      (details (summary (@ (class "cursor-pointer"))
                        ,(format #f "~a ~a"
                                 (length comments)
                                 (G_ "comments")))
               ,rendered-comments))))

