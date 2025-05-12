;;; wikimusic - the free music knowledge encyclopaedia

;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

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
  #:use-module (kracht prelude)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (hygguile abstraction)
  #:use-module (hygguile components input)
  #:use-module (hygguile components container)
  #:use-module (hygguile components icon)
  #:use-module (hygguile components button)
  #:use-module (hygguile components typography)
  #:use-module (srfi srfi-19)
  #:use-module (ice-9 textual-ports)
  #:use-module (artanis route))

(define-public asset-library
  (build-asset-library '("pub/css/fonts.css" "pub/css/phosphor.css"
                         "pub/js/tailwind.js" "pub/js/tailwind.config.js")))

(define-public (page-footer G_)
  `(,(hyg-footer `((div (@ (class ,(->css '(flex flex-row flex-wrap gap-2
                                                 justify-start))))
                        ,(hyg-p (G_ "find the source code here"))
                        ,(hyg-a "https://codeberg.org/jjba23/wikimusic"))
                   ,(hyg-em (G_
                             "Copyright 2025 © Josep Bigorra &lt;jjbigorra@gmail.com&gt;"))
                   ,(hyg-em (G_ "the free music knowledge encyclopaedia"))

                   (div (@ (class ,(->css '(flex flex-row flex-wrap gap-2
                                                 align-center items-center))))
                        ,(hyg-p "version:")
                        ,(hyg-mono (format #f "~a"
                                           (get-short-commit-sha))
                                   #:color 'text-stone-600
                                   #:size 'text-md))))))

(begin
  (define* (html-template G_
                          #:key body
                          (proj '()))
    (define nav-css
      (->css '(text-sm text-blue-900
                       hover:text-blue-700
                       font-sans
                       font-light
                       items-center
                       flex
                       flex-row
                       gap-1
                       px-2)))
    (define nav
      `((div (@ (class ,(->css '(flex flex-row
                                      flex-wrap
                                      gap-3
                                      p-3
                                      items-center
                                      justify-start
                                      w-full
                                      hover:text-blue-700
                                      bg-stone-200))))
             (a (@ (href "/"))
                (div (@ (class ,(->css '(flex flex-row gap-2 items-center px-4
                                              py-1))))
                     (span ,(hyg-icon #:type 'music-note))
                     (span (@ (class ,(->css '(text-md text-stone-700
                                                       hover:text-blue-700
                                                       font-sans font-bold))))
                           ,(G_ "Wikimusic"))))
             (a (@ (class ,nav-css)
                   (href "/songs"))
                ,(hyg-icon #:type 'music-notes-simple)
                ,(G_ "Songs"))
             (a (@ (class ,nav-css)
                   (href "/genres"))
                ,(hyg-icon #:type 'disc)
                ,(G_ "Genres"))
             (a (@ (class ,nav-css)
                   (href "/artists"))
                ,(hyg-icon #:type 'guitar)
                ,(G_ "Artists"))
             (a (@ (class ,nav-css)
                   (href "/login"))
                ,(hyg-icon #:type 'sign-in)
                ,(G_ "Login")))))
    `("<!DOCTYPE html>" (html (head (title "Wikimusic")
                                    (style ,(assoc-ref asset-library
                                                       "pub/css/fonts.css"))
                                    (style ,(assoc-ref asset-library
                                                       "pub/css/phosphor.css"))
                                    (meta (@ (name "viewport")
                                             (content
                                              "width=device-width, initial-scale=1.0")))
                                    (script ,(assoc-ref asset-library
                                                        "pub/js/tailwind.js"))
                                    (script ,(assoc-ref asset-library
                                                        "pub/js/tailwind.config.js")))
                              (body ,(hyg-with-footer #:main `((div (@ (class ,
                                                                         (->css '
                                                                          (flex
                                                                           flex-col
                                                                           justify-between
                                                                           min-h-screen))))
                                                                    (div (@ (class ,
                                                                              (->css '
                                                                               (flex
                                                                                flex-col
                                                                                gap-8
                                                                                justify-start))))
                                                                         ,nav
                                                                         ,body)))
                                                      #:footer (page-footer G_))))))
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
      `((div (@ (class ,(->css '(bg-stone-200 rounded-2xl shadow-md))))
             (div (@ (class ,(->css '(flex flex-col py-3 px-3))))
                  ,(cond-render (lambda (art)
                                  `(figure (@ (class ,(->css '(py-3
                                                               self-center))))
                                           (a (@ (href ,item-link))
                                              (img (@ (loading "lazy")
                                                      (class ,(->css '(rounded-xl
                                                                       w-40
                                                                       sm:w-48
                                                                       shadow-md)))
                                                      (src ,(assoc-ref art
                                                             "content_url")))))))
                                (cond
                                  ((equal? 0
                                           (length artworks))
                                   '())
                                  (else (car artworks))))
                  (a (@ (class ,(->css '(text-blue-900 hover:text-blue-700
                                                       text-xl font-bold
                                                       max-w-prose break-all)))
                        (href ,item-link))
                     (span ,(assoc-ref x "display_name")))
                  (div (@ (class ,(->css '(flex flex-row gap-2))))
                       (span ,(G_ "views"))
                       (span ,(format #f "~a"
                                      (assoc-ref x "views"))))
                  (div (@ (class ,(->css '(flex flex-row gap-2))))
                       (span (@ (class ,(->css '(font-black text-green-800
                                                            text-xs))))
                             ,(format #f "~a" likes))
                       (span (@ (class ,(->css '(font-black text-red-800
                                                            text-xs))))
                             ,(format #f "~a" dislikes)))
                  (div (@ (class ,(->css '(flex flex-row gap-2))))
                       (span (@ (class ,(->css '(text-xs text-stone-700))))
                             ,(format #f "~a"
                                      (length comments)))
                       (span (@ (class ,(->css '(text-xs text-stone-700))))
                             ,(G_ "comments")))
                  ,extra-info)))))
  (export item-tile))

(define-public (render-visibility-status status)
  (cond
    ((eq? status 0)
     `(span "published"))
    (else `(span "unkown status"))))

(define-public (render-comment G_ user-alist comment)
  `(div (@ (class "py-3"))
        ,(cond-render (lambda (u)
                        `(p (@ (class ,(->css '(text-xs text-stone-600))))
                            ,(format #f "~a (~a) &lt;~a&gt;"
                                     (assoc-ref u "display_name")
                                     (assoc-ref u "username")
                                     (assoc-ref u "email_address"))))
                      (car (assoc-ref user-alist
                                      (assoc-ref comment "created_by"))))
        (p (@ (class ,(->css '(text-sm text-stone-900))))
           ,(assoc-ref comment "contents"))
        (p (@ (class ,(->css '(text-xs text-stone-400))))
           ,(assoc-ref comment "created_at"))))

(define-public (render-comments G_ user-alist parent-identifier comments)
  (let* ((top-nodes (filter (lambda (c)
                              (equal? parent-identifier
                                      (assoc-ref c "parent_identifier")))
                            comments)))
    (map (lambda (comment)
           `((div (@ (class "max-w-prose"))
                  ,(render-comment G_ user-alist comment))
             (div (@ (class ,(->css '(max-w-prose pl-3))))
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
                                   `(figure (@ (class ,(->css '(py-3 sm:w-48))))
                                            (img (@ (loading lazy)
                                                    (class ,(->css '(rounded-xl
                                                                     shadow-md)))
                                                    (src ,(assoc-ref art
                                                           "content_url"))))
                                            ,(cond-render (lambda (fc)
                                                            `(figcaption ,fc))
                                                          (assoc-ref art
                                                           "content_caption"))))
                                 artworks))
         (rendered-comments (render-comments G_ user-alist #f comments))
         (like-count (length (filter (lambda (o)
                                       (and (equal? (assoc-ref x "identifier")
                                                    (assoc-ref o
                                                               (format #f
                                                                "~a_identifier"
                                                                entity)))
                                            (equal? 1
                                                    (assoc-ref o "is_like"))))
                                     opinions)))
         (dislike-count (length (filter (lambda (o)
                                          (and (equal? (assoc-ref x
                                                        "identifier")
                                                       (assoc-ref o
                                                                  (format #f
                                                                   "~a_identifier"
                                                                   entity)))
                                               (equal? 1
                                                       (assoc-ref o
                                                        "is_dislike"))))
                                        opinions)))
         (opinion-buttons `((div (@ (class ,(->css '(flex flex-row flex-wrap
                                                          gap-3))))
                                 (form (@ (method POST)
                                          (action ,(format #f
                                                    "/~as/uuid/~a/like" entity
                                                    (assoc-ref x "identifier"))))
                                       ,(hyg-icon-button #:icon 'thumbs-up
                                                         #:background 'bg-green-700
                                                         #:hover-background 'hover:bg-green-800
                                                         #:border-color 'border-stone-700
                                                         #:type 'submit
                                                         #:content `(div ,(G_
                                                                           "like")
                                                                         (span
                                                                          (@ (class
                                                                              "font-light text-xs"))
                                                                          ,(format
                                                                            #f
                                                                            " ( ~a ) "
                                                                            like-count)))))
                                 (form (@ (method POST)
                                          (action ,(format #f
                                                    "/~as/uuid/~a/dislike"
                                                    entity
                                                    (assoc-ref x "identifier"))))
                                       ,(hyg-icon-button #:icon 'thumbs-down
                                                         #:background 'bg-red-700
                                                         #:hover-background 'hover:bg-red-800
                                                         #:border-color 'border-stone-700
                                                         #:type 'submit
                                                         #:content `(div ,(G_
                                                                           "dislike")

                                                                         (span
                                                                          (@ (class ,
                                                                              (->css '
                                                                               (font-light
                                                                                text-xs))))
                                                                          ,(format
                                                                            #f
                                                                            " ( ~a ) "
                                                                            dislike-count))))))))
         (maybe-description (cond-render (lambda (description)
                                           `(div (p (@ (class ,(->css '(text-stone-700
                                                                        font-bold))))
                                                    ,(G_ "description"))
                                                 (p (@ (class ,(->css '(pl-3
                                                                        text-stone-800
                                                                        max-w-prose))))
                                                    ,description)))
                                         (assoc-ref x "description")))
         (maybe-last-edited-at (cond-render (lambda (last-edited-at)
                                              `((dt (@ (class ,(->css '(text-stone-700
                                                                        font-bold))))
                                                    ,(G_ "last edited"))
                                                (dd (@ (class
                                                        "pl-3 text-stone-800"))
                                                    ,(strftime "%c"
                                                               (localtime (string->number
                                                                           last-edited-at))))))
                                            (assoc-ref x "last_edited_at")))
         (maybe-approved-by (cond-render (lambda (approved-by)
                                           `((dt (@ (class ,(->css '(text-stone-700
                                                                     font-bold))))
                                                 ,(G_ "approved by"))
                                             (dd (@ (class ,(->css '(pl-3
                                                                     text-stone-800))))
                                                 ,approved-by)))
                                         (assoc-ref x "approved_by"))))
    
    `((div (@ (class ,(->css '(py-4 flex flex-row flex-wrap gap-6))))
           (div ,rendered-artworks)
           (div (div (@ (class ,(->css '(flex flex-col gap-3 my-4))))
                     ,opinion-buttons
                     (a (@ (href ,(format #f "/~as/uuid/~a/edit" entity
                                          (assoc-ref x "identifier"))))
                        ,(hyg-icon-button #:icon 'pencil
                                          #:content (G_ "edit"))))
                ,maybe-description
                (dl (dt (@ (class ,(->css '(text-stone-700 font-bold))))
                        ,(G_ "views"))
                    (dd (@ (class ,(->css '(pl-3 text-stone-800))))
                        ,(format #f "~a"
                                 (assoc-ref x "views")))
                    (dt (@ (class ,(->css '(text-stone-700 font-bold))))
                        ,(G_ "created"))
                    (dd (@ (class ,(->css '(pl-3 text-stone-800))))
                        ,(strftime "%c"
                                   (localtime (string->number (assoc-ref x
                                                               "created_at")))))
                    ,maybe-last-edited-at
                    (dt (@ (class ,(->css '(text-stone-700 font-bold))))
                        ,(G_ "contributor"))
                    (dd (@ (class ,(->css '(pl-3 text-stone-800))))
                        ,(cond-render (lambda (u)
                                        `(div (@ (class ,(->css '(flex
                                                                  flex-wrap
                                                                  flex-row
                                                                  gap-2))))
                                              (span ,(format #f
                                                      "~a (~a) &lt;~a&gt;"
                                                      (assoc-ref u
                                                       "display_name")
                                                      (assoc-ref u "username")
                                                      (assoc-ref u
                                                       "email_address")))))
                                      (car (assoc-ref user-alist
                                                      (assoc-ref x
                                                                 "created_by")))))
                    (dt (@ (class ,(->css '(text-stone-700 font-bold))))
                        ,(G_ "visibility"))
                    (dd (@ (class ,(->css '(pl-3 text-stone-800))))
                        ,(render-visibility-status (assoc-ref x
                                                    "visibility_status")))
                    ,maybe-approved-by
                    (dt (@ (class ,(->css '(text-stone-700 font-bold))))
                        ,(G_ "uuid"))
                    (dd (@ (class ,(->css '(pl-3 text-sm text-stone-600))))
                        ,(assoc-ref x "identifier")))))
      (details (summary (@ (class "cursor-pointer"))
                        ,(format #f "~a ~a"
                                 (length comments)
                                 (G_ "comments")))
               ,rendered-comments))))

(begin
  (define* (artwork-form G_
                         #:key entity
                         entity-identifier
                         (artwork-identifier #f)
                         (content-url "")
                         (content-caption "")
                         (order-value 0))
    (let* ((form-action (if (equal? #f artwork-identifier)
                            (format #f "/~as/uuid/~a/artworks/new" entity
                                    entity-identifier)
                            (format #f "/~as/uuid/~a/artworks/edit/~a" entity
                                    entity-identifier artwork-identifier))))
      `((div (@ (class "flex flex-col gap-2"))
             (form (@ (method POST)
                      (content-type application/x-www-form-urlencoded)
                      (action ,form-action))
                   (div ,(hyg-input #:label (G_ "content url")
                                    #:name "content-url"
                                    #:value content-url
                                    #:required #t)
                        ,(hyg-input #:label (G_ "content caption")
                                    #:name "content-caption"
                                    #:value content-caption)
                        ,(hyg-input #:label (G_ "order value")
                                    #:type 'number
                                    #:name "order-value"
                                    #:value order-value)
                        (div ,(hyg-submit-button (if artwork-identifier
                                                     (G_ "edit")
                                                     (G_ "create"))))))
             ,(cond-render (lambda (artwork-id)
                             `(form (@ (method POST)
                                       (content-type
                                        application/x-www-form-urlencoded)
                                       (action ,(format #f
                                                 "/~as/uuid/~a/artworks/~a/delete"
                                                 entity entity-identifier
                                                 artwork-identifier)))
                                    ,(hyg-danger-submit-button (G_ "delete"))))
                           artwork-identifier)))))
  (export artwork-form))

(begin
  (define* (sort-select G_
                        #:key entity user-sort)
    `((div (@ (class ,(->css '(flex flex-col gap-2 w-min))))
           (select (@ (onchange "window.location.href=this.value;")
                      (name "sort-select")
                      (id "sort-select")
                      (class ,(->css '(p-3 border-2 border-stone-200
                                           rounded-xl bg-white shadow-md))))
                   (option ,(G_ "sort order"))
                   ,(map (lambda (s)
                           `((option (@ (value ,(format #f "/~as?sort=~a"
                                                        entity
                                                        (car s)))
                                        ,(cond
                                           ((equal? user-sort
                                                    (car s))
                                            '(selected ""))
                                           (else '(not-selected ""))))
                                     ,(cdr s))))

                         `(("display-name-asc" unquote
                            (G_ "Name - Ascending"))
                           ("display-name-desc" unquote
                            (G_ "Name - Descending"))

                           ("created-at-asc" unquote
                            (G_ "Created - Ascending"))
                           ("created-at-desc" unquote
                            (G_ "Created - Descending"))

                           ("last-edited-at-asc" unquote
                            (G_ "Last edited - Ascending"))
                           ("last-edited-at-desc" unquote
                            (G_ "Last edited - Descending"))

                           ("views-asc" unquote
                            (G_ "Views - Ascending"))
                           ("views-desc" unquote
                            (G_ "Views - Descending"))

                           ))))))
  (export sort-select))

(begin
  (define* (ascii-size-select G_
                              #:key route)
    `((div (@ (class ,(->css '(flex flex-col gap-2 w-min))))
           (select (@ (onchange "window.location.href=this.value;")
                      (name "ascii-size-select")
                      (id "ascii-size-select")
                      (class ,(->css '(p-3 border-2 border-stone-200
                                           rounded-xl bg-white shadow-md))))
                   (option ,(G_ "ascii size"))
                   ,(map (lambda (s)
                           `((option (@ (value ,(format #f "~a?ascii-size=~a"
                                                        route
                                                        (car s))))
                                     ,(cdr s))))
                         `(("text-xs" . "text-xs") ("text-sm" . "text-sm")
                           ("text-md" . "text-md")
                           ("text-lg" . "text-lg")
                           ("text-xl" . "text-xl")))))))
  (export ascii-size-select))

(begin
  (define* (search-box G_
                       #:key search-query)
    `((script
       "
function addSearchQueryParam(form) {
  const searchInput = document.getElementsByName('search')[0];

  if (searchInput.value) {
    const urlSearchParams = new URLSearchParams(window.location.search);
    var params = Object.fromEntries(urlSearchParams.entries());

    params.search = encodeURIComponent(searchInput.value);

    const q = Object.entries(params).map((k,_)=>`${k[0]}=${k[1]}`).reduce((a,b) => `${a}&${b}`);

    console.log(q);
    console.log(`${window.location.pathname}?${q}`);

    window.location.href = `${window.location.pathname}?${q}`;
    return false; // Prevent the default form submission
  }
  return true; // Allow default submission if the input is empty
}
")
      (div (@ (class ,(->css '(my-3))))
           (form (@ (onsubmit "addSearchQueryParam(this)"))
                 (div (@ (class ,(->css '(flex flex-row align-center
                                               items-center justify-start
                                               gap-2))))
                      ,(hyg-input #:label ""
                                  #:name "search"
                                  #:value (cond
                                            ((equal? #f search-query)
                                             "")
                                            (else search-query))
                                  #:placeholder (G_ "Search...")
                                  #:input-css '(p-2 max-w-prose rounded-xl
                                                    border-stone-200 border-2
                                                    shadow-md)
                                  #:input-flex-css #f)
                      ,(hyg-submit-button (G_ "search")))))))
  (export search-box))

