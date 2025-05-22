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
  #:use-module (hygguile hygguile)
  #:use-module (srfi srfi-19)
  #:use-module (ice-9 textual-ports)
  #:use-module (artanis route))

(define-public asset-library
  (build-asset-library '("pub/css/fonts.css" "pub/css/phosphor.css"
                         "pub/js/tailwind.js")))

(define-public (page-footer G_)
  `(,(footer `(,(em (G_ "the free music knowledge encyclopaedia"))
               ,(em (G_
                     "wikimusic is free software, available under the GNU AGPL v3 or newer"))
               (div (@ (class ,(mk-class '(flex flex-row flex-wrap gap-2
                                                justify-start))))
                    ,(em (G_ "find the source code here"))
                    ,(a "https://codeberg.org/jjba23/wikimusic"))
               ,(em (G_
                     "Copyright © Josep Bigorra &lt;jjbigorra@gmail.com&gt;"))
               

               (div (@ (class ,(mk-class '(flex flex-row flex-wrap gap-2
                                                align-center items-center))))
                    ,(em "version:")
                    ,(mono (format #f "~a"
                                   (get-short-commit-sha))
                           #:size 'text-md))))))

(begin
  (define* (html-template G_
                          #:key body
                          (proj '()))
    (define nav-css
      (mk-class '(text-sm text-blue-900
                          hover:text-blue-700
                          font-sans
                          font-light
                          items-center
                          flex
                          flex-row
                          gap-1
                          px-2)))
    (define nav
      `((div (@ (class ,(mk-class '(flex flex-row
                                         flex-wrap
                                         gap-3
                                         p-3
                                         items-center
                                         justify-start
                                         w-full
                                         hover:text-blue-700
                                         bg-stone-200
                                         dark:bg-stone-900))))
             (a (@ (href "/"))
                (div (@ (class ,(mk-class '(flex flex-row gap-2 items-center
                                                 px-4 py-1))))
                     (span ,(icon #:type 'music-note
                                  #:icon-css '(text-xl text-stone-800
                                                       dark:text-stone-200)))
                     ,(h4 (G_ "Wikimusic"))))
             (a (@ (href "/songs"))
                ,(icon-button #:icon 'music-notes-simple
                              #:content (G_ "songs")))
             (a (@ (href "/genres"))
                ,(icon-button #:icon 'disc
                              #:content (G_ "genres")))
             (a (@ (href "/artists"))
                ,(icon-button #:icon 'guitar
                              #:content (G_ "artists")))
             (a (@ (href "/login"))
                ,(icon-button #:icon 'sign-in
                              #:content (G_ "login")))
             ,(ui-mode-button))))
    `("<!DOCTYPE html>" (html (head (title "Wikimusic")
                                    (style ,(assoc-ref asset-library
                                                       "pub/css/fonts.css"))
                                    (style ,(assoc-ref asset-library
                                                       "pub/css/phosphor.css"))
                                    (style (@ (type "text/tailwindcss"))
                                     "
@custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *));

@theme {
  --font-sans: \"Adwaita Sans\", sans-serif;
  --font-mono: \"Adwaita Mono\", monospace;
}
")
                                    (meta (@ (name "viewport")
                                             (content
                                              "width=device-width, initial-scale=1.0")))
                                    (meta (@ (charset "UTF-8")))
                                    (script ,(assoc-ref asset-library
                                                        "pub/js/tailwind.js"))
                                    (script ,toggle-dark-theme-js)
                                    (script ,remember-dark-theme-js)
                                    (script
                                     "
const fileToBase64 = (file) => {
  return new Promise((resolve, reject) => {
    const fileReader = new FileReader();
    fileReader.readAsDataURL(file);

    fileReader.onload = () => {
      resolve(fileReader.result);
    };

    fileReader.onerror = (error) => {
      reject(error);
    };
  });
};

async function translateFileToBase64AddToInput(sourceInput, targetInput) {
  const file = sourceInput.files[0];
  const base64 = await fileToBase64(file);
  targetInput.setAttribute('value', base64);
};
"))
                              (body (@ (class ,(mk-class '(bg-stone-100
                                                           dark:bg-stone-800))))
                                    ,(with-footer #:main `((div (@ (class ,(mk-class '
                                                                            (flex
                                                                             flex-col
                                                                             justify-between
                                                                             min-h-96))))
                                                                (div (@ (class ,
                                                                         (mk-class '
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
                      #:key (extra-bot-info '())
                      (extra-top-info '()))
    (let ((item-link (format #f "/~as/uuid/~a" entity
                             (assoc-ref x "identifier")))
          (likes (length (filter (lambda (o)
                                   (equal? 1
                                           (assoc-ref o "is_like"))) opinions)))
          (dislikes (length (filter (lambda (o)
                                      (equal? 1
                                              (assoc-ref o "is_dislike")))
                                    opinions))))
      `((div (@ (class ,(mk-class '(bg-stone-200 dark:bg-stone-900 rounded-2xl
                                                 shadow-md h-full))))
             (div (@ (class ,(mk-class '(flex flex-col
                                              py-3
                                              px-3
                                              justify-center
                                              align-center
                                              items-start
                                              h-full))))
                  ,(render-if-nempty (lambda (art)
                                       `(figure (@ (class ,(mk-class '(py-3
                                                                       self-center))))
                                                (a (@ (href ,item-link))
                                                   (img (@ (loading "lazy")
                                                           (class ,(mk-class '
                                                                             (rounded-xl
                                                                              w-40
                                                                              sm:w-48
                                                                              shadow-md)))
                                                           (src ,(assoc-ref
                                                                  art
                                                                  "content_url")))))))
                                     (cond
                                       ((equal? 0
                                                (length artworks))
                                        '())
                                       (else (car artworks))))
                  ,(a (assoc-ref x "display_name")
                      #:size 'text-2xl
                      #:href item-link)
                  (div (@ (class ,(mk-class '(py-2))))
                       ,extra-top-info)
                  (div (@ (class ,(mk-class '(flex flex-row gap-2))))
                       (span (@ (class ,(mk-class '(text-stone-800
                                                    dark:text-stone-200))))
                             ,(G_ "views"))
                       (span (@ (class ,(mk-class '(text-stone-800
                                                    dark:text-stone-200))))
                             ,(format #f "~a"
                                      (assoc-ref x "views"))))
                  (div (@ (class ,(mk-class '(flex flex-row gap-2))))
                       (span (@ (class ,(mk-class '(font-black text-green-800
                                                    dark:text-green-600
                                                    text-xs))))
                             ,(format #f "~a" likes))
                       (span (@ (class ,(mk-class '(font-black text-red-800
                                                    dark:text-red-600 text-xs))))
                             ,(format #f "~a" dislikes)))
                  (div (@ (class ,(mk-class '(flex flex-row gap-2))))
                       (span (@ (class ,(mk-class '(text-xs text-stone-700
                                                    dark:text-stone-300))))
                             ,(format #f "~a"
                                      (length comments)))
                       (span (@ (class ,(mk-class '(text-xs text-stone-700
                                                    dark:text-stone-300))))
                             ,(G_ "comments")))
                  ,extra-bot-info)))))
  (export item-tile))

(define-public (render-visibility-status status)
  (cond
   ((eq? status 0)
    (em "published"))
   (else (em "unkown status"))))

(define-public (render-comment G_ user-alist comment)
  `(div (@ (class "py-3"))
        ,(render-if-nempty (lambda (u)
                             `(p (@ (class ,(mk-class '(text-xs text-stone-600))))
                                 ,(format #f "~a (~a) &lt;~a&gt;"
                                          (assoc-ref u "display_name")
                                          (assoc-ref u "username")
                                          (assoc-ref u "email_address"))))
                           (car (assoc-ref user-alist
                                           (assoc-ref comment "created_by"))))
        (p (@ (class ,(mk-class '(text-sm text-stone-900))))
           ,(assoc-ref comment "contents"))
        (p (@ (class ,(mk-class '(text-xs text-stone-400 dark:text-stone-300))))
           ,(assoc-ref comment "created_at"))))

(define-public (render-comments G_ user-alist parent-identifier comments)
  (let* ((top-nodes (filter (lambda (c)
                              (equal? parent-identifier
                                      (assoc-ref c "parent_identifier")))
                            comments)))
    (map (lambda (comment)
           `((div (@ (class "max-w-prose"))
                  ,(render-comment G_ user-alist comment))
             (div (@ (class ,(mk-class '(max-w-prose pl-3))))
                  ,(render-comments G_ user-alist
                                    (assoc-ref comment "identifier") comments))))
         top-nodes)))

(begin
  (define* (entity-details G_
                           #:key entity
                           x
                           artworks
                           opinions
                           comments
                           user-alist)
    (let* ((rendered-artworks (map (lambda (art)
                                     `(figure (@ (class ,(mk-class '(py-3

                                                                     ))))
                                              (img (@ (loading lazy)
                                                      (class ,(mk-class '(rounded-xl
                                                                          shadow-md
                                                                          w-56
                                                                          sm:w-64
                                                                          md:w-72
                                                                          h-auto)))
                                                      (src ,(assoc-ref art
                                                                       "content_url"))))
                                              ,(render-if-nempty (lambda (fc)
                                                                   `(figcaption ,fc))
                                                                 (assoc-ref
                                                                  art
                                                                  "content_caption"))))
                                   artworks))
           (rendered-comments (render-comments G_ user-alist #f comments))
           (like-count (length (filter (lambda (o)
                                         (and (equal? (assoc-ref x
                                                                 "identifier")
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
           (opinion-buttons `((div (@ (class ,(mk-class '(flex flex-row
                                                               flex-wrap gap-3))))
                                   (form (@ (method POST)
                                            (action ,(format #f
                                                             "/~as/uuid/~a/like"
                                                             entity
                                                             (assoc-ref x
                                                                        "identifier"))))
                                         ,(icon-button #:icon 'thumbs-up
                                                       #:color '(text-stone-100)
                                                       #:background '(bg-green-700)
                                                       #:hover-background '(hover:bg-green-800)
                                                       #:border-color '(border-stone-700
                                                                        dark:border-stone-400)
                                                       #:type 'submit
                                                       #:content `(div ,(G_
                                                                         "like")
                                                                       (span (@
                                                                              (class
                                                                                "font-light text-xs"))
                                                                             ,
                                                                             (format
                                                                              #f
                                                                              " ( ~a ) "
                                                                              like-count)))))
                                   (form (@ (method POST)
                                            (action ,(format #f
                                                             "/~as/uuid/~a/dislike"
                                                             entity
                                                             (assoc-ref x
                                                                        "identifier"))))
                                         ,(icon-button #:icon 'thumbs-down
                                                       #:color '(text-stone-100)
                                                       #:background '(bg-red-700)
                                                       #:hover-background '(hover:bg-red-800)
                                                       #:border-color '(border-stone-700
                                                                        dark:border-stone-400)
                                                       #:type 'submit
                                                       #:content `(div ,(G_
                                                                         "dislike")

                                                                       (span (@
                                                                              (class ,
                                                                                (mk-class '
                                                                                 (font-light
                                                                                  text-xs))))
                                                                             ,
                                                                             (format
                                                                              #f
                                                                              " ( ~a ) "
                                                                              dislike-count))))))))
           (maybe-description (render-if-nempty (lambda (description)
                                                  `(div (p (@ (class ,(mk-class '
                                                                       (text-stone-700
                                                                        dark:text-stone-400
                                                                        font-bold))))
                                                           ,(G_ "description"))
                                                        (div (@(class ,(mk-class '(max-w-prose pl-3 whitespace-break-spaces))))
                                                             ,(p 
                                                               description #:weight 'font-light))
                                                        ))
                                                (assoc-ref x "description")))
           (maybe-last-edited-at (render-if-nempty (lambda (last-edited-at)
                                                     `((dt (@ (class ,(mk-class '
                                                                       (pt-3
                                                                        pb-1
                                                                        text-stone-700
                                                                        dark:text-stone-400
                                                                        font-bold))))
                                                           ,(G_ "last edited"))
                                                       (dd (@ (class ,(mk-class '
                                                                       (pl-3
                                                                        text-stone-800
                                                                        dark:text-stone-300))))
                                                           ,(em
                                                             (strftime "%c"
                                                                       (localtime
                                                                        (string->number
                                                                         last-edited-at)))))))
                                                   (assoc-ref x
                                                              "last_edited_at")))
           (maybe-approved-by (render-if-nempty (lambda (approved-by)
                                                  `((dt (@ (class ,(mk-class '
                                                                    (pt-3
                                                                     pb-1
                                                                     text-stone-700
                                                                     dark:text-stone-400
                                                                     font-bold))))
                                                        ,(G_ "approved by"))
                                                    (dd (@ (class ,(mk-class '
                                                                    (pl-3
                                                                     text-stone-800
                                                                     dark:text-stone-300))))
                                                        ,approved-by)))
                                                (assoc-ref x "approved_by"))))
      
      `((div (@ (class ,(mk-class '(py-4 flex flex-row flex-wrap gap-6))))
             (div ,rendered-artworks)
             (div (div (@ (class ,(mk-class '(flex flex-col gap-3 my-4))))
                       ,opinion-buttons
                       (a (@ (href ,(format #f "/~as/uuid/~a/edit" entity
                                            (assoc-ref x "identifier"))))
                          ,(icon-button #:icon 'pencil
                                        #:content (G_ "edit"))))
                  ,maybe-description
                  (dl (dt (@ (class ,(mk-class '(pt-3 pb-1 text-stone-700
                                                      dark:text-stone-400
                                                      font-bold))))
                          ,(G_ "views"))
                      (dd (@ (class ,(mk-class '(pl-3 text-stone-800
                                                      dark:text-stone-300))))
                          ,(em (format #f "~a"
                                       (assoc-ref x "views"))))
                      (dt (@ (class ,(mk-class '(pt-3 pb-1 text-stone-700
                                                      dark:text-stone-400
                                                      font-bold))))
                          ,(G_ "created"))
                      (dd (@ (class ,(mk-class '(pl-3 text-stone-800
                                                      dark:text-stone-300))))
                          ,(em (strftime "%c"
                                         (localtime (string->number (assoc-ref x
                                                                               "created_at"))))))
                      ,maybe-last-edited-at
                      (dt (@ (class ,(mk-class '(pt-3 pb-1 text-stone-700
                                                      dark:text-stone-400
                                                      font-bold))))
                          ,(G_ "contributor"))
                      (dd (@ (class ,(mk-class '(pl-3 text-stone-800
                                                      dark:text-stone-300))))
                          ,(render-if-nempty (lambda (u)
                                               `(div (@ (class ,(mk-class '(flex
                                                                            flex-wrap
                                                                            flex-row
                                                                            gap-2))))
                                                     ,(em (format #f
                                                                  "~a (~a) &lt;~a&gt;"
                                                                  (assoc-ref u
                                                                             "display_name")
                                                                  (assoc-ref u
                                                                             "username")
                                                                  (assoc-ref u
                                                                             "email_address")))))
                                             (car (assoc-ref user-alist
                                                             (assoc-ref x
                                                                        "created_by")))))
                      (dt (@ (class ,(mk-class '(pt-3 pb-1 text-stone-700
                                                      dark:text-stone-400
                                                      font-bold))))
                          ,(G_ "visibility"))
                      (dd (@ (class ,(mk-class '(pl-3 text-stone-800
                                                      dark:text-stone-300))))
                          ,(render-visibility-status (assoc-ref x
                                                                "visibility_status")))
                      ,maybe-approved-by
                      (dt (@ (class ,(mk-class '(pt-3 pb-1 pb-1 text-stone-700
                                                      dark:text-stone-400
                                                      font-bold))))
                          ,(G_ "uuid"))
                      (dd (@ (class ,(mk-class '(pl-3 text-sm text-stone-600
                                                      dark:text-stone-300))))

                          (div (@ (class ,(mk-class '(flex flex-row flex-wrap
                                                           gap-4))))
                               ,(mono (assoc-ref x "identifier") #:size 'text-sm)
                               ,(icon-button #:icon 'copy
                                             #:content "copy"

                                             #:on-click (format #f
                                                                "navigator.clipboard.writeText('~a')"
                                                                (assoc-ref x
                                                                           "identifier"))))))))
        (details (summary (@ (class ,(mk-class '(text-stone-800
                                                 dark:text-stone-200
                                                 cursor-pointer))))
                          ,(em
                            (format #f "~a ~a"
                                    (length comments)
                                    (G_ "comments"))))
                 ,rendered-comments))))
  (export entity-details))

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
      `((div (@ (class ,(mk-class '(flex flex-col gap-2))))
             (form (@ (method POST)
                      (content-type application/x-www-form-urlencoded)
                      (action ,form-action))
                   (div ,(input #:label (G_ "content url")
                                #:name "content-url"
                                #:value content-url
                                #:required #t)
                        ,(input #:label (G_ "content caption")
                                #:name "content-caption"
                                #:value content-caption)
                        ,(input #:label (G_ "order value")
                                #:type 'number
                                #:name "order-value"
                                #:value order-value)
                        (div ,(submit-button (if artwork-identifier
                                                 (G_ "edit")
                                                 (G_ "create"))))))
             ,(render-if-nempty (lambda (artwork-id)
                                  `(form (@ (method POST)
                                            (content-type
                                             application/x-www-form-urlencoded)
                                            (action ,(format #f
                                                             "/~as/uuid/~a/artworks/~a/delete"
                                                             entity entity-identifier
                                                             artwork-identifier)))
                                         ,(danger-submit-button (G_ "delete"))))
                                artwork-identifier)))))
  (export artwork-form))

(begin
  (define* (external-sources-form G_
                                  #:key
                                  entity
                                  entity-identifier
                                  (external-sources-identifier #f)
                                  (wikipedia-url "")
                                  (youtube-url "")
                                  (spotify-url "")
                                  (soundcloud-url "")                                  )
    (let* ((form-action (if (equal? #f external-sources-identifier)
                            (format #f "/~as/uuid/~a/external-sources/new" entity
                                    entity-identifier)
                            (format #f "/~as/uuid/~a/external-sources/~a/edit" entity
                                    entity-identifier external-sources-identifier))))
      `((div (@ (class ,(mk-class '(flex flex-col gap-2))))
             (form (@ (method POST)
                      (content-type application/x-www-form-urlencoded)
                      (action ,form-action))
                   (div ,(input #:label (G_ "wikipedia url")
                                #:name "wikipedia-url"
                                #:value wikipedia-url
                                #:required #f)
                        ,(input #:label (G_ "youtube url")
                                #:name "youtube-url"
                                #:value youtube-url
                                #:required #f)
                        ,(input #:label (G_ "spotify url")
                                #:name "spotify-url"
                                #:value spotify-url
                                #:required #f)
                        ,(input #:label (G_ "soundcloud url")
                                #:name "soundcloud-url"
                                #:value soundcloud-url
                                #:required #f)
                        (div ,(submit-button (if external-sources-identifier
                                                 (G_ "save")
                                                 (G_ "save"))))))))))
  (export external-sources-form))

(begin
  (define* (sort-select G_
                        #:key entity user-sort)
    `((div (@ (class ,(mk-class '(flex flex-col gap-2 w-min))))
           (select (@ (onchange "window.location.href=this.value;")
                      (name "sort-select")
                      (id "sort-select")
                      (class ,(mk-class '(p-3 border-2 border-stone-200
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
    `((div (@ (class ,(mk-class '(flex flex-col gap-2 w-min))))
           (select (@ (onchange "window.location.href=this.value;")
                      (name "ascii-size-select")
                      (id "ascii-size-select")
                      (class ,(mk-class '(p-3 border-2 border-stone-200
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
      (div (@ (class ,(mk-class '(my-3))))
           (form (@ (onsubmit "addSearchQueryParam(this)"))
                 (div (@ (class ,(mk-class '(flex flex-row align-center
                                                  items-center justify-start
                                                  gap-2))))
                      ,(input #:label ""
                              #:name "search"
                              #:value (cond
                                        ((equal? #f search-query)
                                         "")
                                        (else search-query))
                              #:placeholder (G_ "Search...")
                              #:input-css '(p-3 max-w-prose
                                                rounded-xl
                                                border-stone-200
                                                dark:border-stone-700
                                                dark:text-stone-300
                                                dark:bg-stone-700/75
                                                border-2
                                                shadow-md)
                              #:input-flex-css #f)
                      ,(submit-button (G_ "search")))))))
  (export search-box))

(define-public (render-external-sources G_ external-sources)
  `((div (@ (class ,(mk-class '(flex flex-row
                                     flex-wrap
                                     gap-6
                                     py-12
                                     px-6
                                     md:py-12
                                     md:px-18
                                     w-full
                                     justify-end
                                     items-start
                                     align-end))))
         ,(render-if-nestring (lambda (s)
                                `((div (@ (class ,(mk-class '(flex flex-col
                                                                   gap-3
                                                                   max-w-64
                                                                   md:max-w-80
                                                                   overflow-x-scroll))))
                                       ,(p (G_ "Wikipedia URL"))
                                       ,(a s))))
                              (assoc-ref external-sources "wikipedia_url"))

         ,(render-if-nestring (lambda (s)
                                `((div (@ (class ,(mk-class '(flex flex-col
                                                                   gap-3
                                                                   max-w-64
                                                                   md:max-w-80
                                                                   overflow-x-scroll))))
                                       ,(p (G_ "Spotify URL"))
                                       ,(a s))))
                              (assoc-ref external-sources "spotify_url"))
         ,(render-if-nestring (lambda (s)
                                `((div (@ (class ,(mk-class '(flex flex-col
                                                                   gap-3
                                                                   max-w-64
                                                                   md:max-w-80
                                                                   overflow-x-scroll))))
                                       ,(p (G_ "Youtube URL"))
                                       ,(a s))))
                              (assoc-ref external-sources "youtube_url"))
         ,(render-if-nestring (lambda (s)
                                `((div (@ (class ,(mk-class '(flex flex-col
                                                                   gap-3
                                                                   max-w-64
                                                                   md:max-w-80
                                                                   overflow-x-scroll))))
                                       ,(p (G_ "Soundcloud URL"))
                                       ,(a s))))
                              (assoc-ref external-sources "soundcloud_url"))
         )))
