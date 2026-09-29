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
  #:use-module (orgwebalchemy html)
  #:use-module (kracht prelude)
  #:use-module (ice-9 textual-ports)
  #:use-module (artanis route)
  #:export (asset-library page-footer
                          nav
                          html-template
                          item-tile
                          render-visibility-status
                          render-comment
                          render-comments
                          entity-details
                          artwork-form
                          org2html
                          external-sources-form
                          sort-select
                          ascii-size-select
                          search-box
                          render-external-sources
                          item-tile-grid-face))

(define item-tile-grid-face
  (mk-class '(grid grid-cols-2
                   gap-2
                   sm:gap-3
                   sm:grid-cols-3
                   md:grid-cols-4
                   lg:grid-cols-5
                   xl:grid-cols-6)))

(define* asset-library
  (build-asset-library '("pub/js/song-auto-scroll.js" "pub/js/symbanta.js"
                         "pub/js/song-chord-highlighter.js"
                         "pub/js/file-base64.js")))

(define* (page-footer G_)
  `(,(footer `(,(em (G_ "the free music knowledge encyclopaedia")) ,(em (G_
                                                                         "wikimusic is free software, available under the GNU AGPL v3 or newer")
                                                                        #:size '
                                                                        (text-sm))
               (div (@ (class ,(mk-class '(flex flex-row flex-wrap gap-2
                                                justify-start items-center))))
                    ,(em (G_ "find the source code here"))
                    ,(a "https://codeberg.org/jjba23/wikimusic"
                        #:size '(text-md)))
               (div (@ (class ,(mk-class '(flex flex-row flex-wrap gap-2
                                                align-center items-center))))
                    ,(em (G_ "find the manual here"))
                    ,(a "https://jointhefreeworld.org/manuals/wikimusic/"
                        #:size '(text-md)))
               ,(em (G_
                     "Copyright © Josep Bigorra &lt;jjbigorra@gmail.com&gt;")
                    #:size '(text-sm))

               (div (@ (class ,(mk-class '(flex flex-row flex-wrap gap-8
                                                align-center items-center))))
                    (div (@ (class ,(mk-class '(flex flex-row flex-wrap gap-2
                                                     align-center items-center))))
                         (a (@ (href "javascript:void(0)")
                               (class ,(mk-class '(no-underline text-onyx-500
                                                   dark:text-stone-300
                                                   cursor-pointer font-light)))
                               (onclick
                                "window.scrollTo({ top: 0, behavior: 'smooth' })"))
                            "⬆️ back to the top"))
                    (div (@ (class ,(mk-class '(flex flex-row flex-wrap gap-2
                                                     align-center items-center))))
                         ,(em "version:")
                         ,(mono (format #f "~a"
                                        (get-short-commit-sha))
                                #:size '(text-md)
                                #:weight '(font-light))))))))

(define* (nav G_
              #:key is-logged-in)
  `((div (@ (class ,(mk-class '(flex flex-row
                                     flex-wrap
                                     gap-3
                                     p-3
                                     items-center
                                     justify-between
                                     w-full
                                     hover:text-china-violet-700
                                     bg-stone-300/50
                                     dark:bg-onyx-700
                                     shadow-md))))

         (div (@ (class ,(mk-class '(px-4 py-1))))
              (a (@ (href "/")
                    (class ,(mk-class '(flex flex-row gap-2 items-center
                                             no-underline))))
                 ,(h1 (list (icon #:type 'music-note

                                  #:icon-css '(text-xl text-onyx-300
                                               dark:text-stone-300
                                               hover:text-persia-pink-900
                                               hover:dark:text-persia-pink-300

                                               )) "&nbsp;"
                            (G_ "WikiMusic"))
                      #:weight '(font-medium italic)
                      #:color '(text-onyx-300 dark:text-stone-300
                                              hover:text-persia-pink-900
                                              hover:dark:text-persia-pink-300)
                      #:family '(font-sans)

                      #:size '(text-xl md:text-2xl))))
         (div (@ (class ,(mk-class '(flex flex-row gap-3 flex-wrap
                                          justify-center md:justify-start))))
              (a (@ (href "/songs"))
                 ,(icon-button #:icon 'music-notes-simple
                               #:content (G_ "songs")
                               #:family '(font-sans)
                               #:color '(text-onyx-900 dark:text-stone-100)
                               #:weight '(font-light)
                               #:size '(text-md)
                               #:icon-css '(text-md lg:text-lg text-onyx-300
                                                    dark:text-stone-300)
                               #:extra-classes '(py-1 lg:py-2 px-2 lg:px-3
                                                      max-w-prose
                                                      cursor-pointer)))
              (a (@ (href "/genres"))
                 ,(icon-button #:icon 'disc
                               #:content (G_ "genres")
                               #:size '(text-md)
                               #:family '(font-sans)
                               #:color '(text-onyx-900 dark:text-stone-100)
                               #:weight '(font-light)
                               #:icon-css '(text-md lg:text-lg text-onyx-300
                                                    dark:text-stone-300)
                               #:extra-classes '(py-1 lg:py-2 px-2 lg:px-3
                                                      max-w-prose
                                                      cursor-pointer)))
              (a (@ (href "/artists"))
                 ,(icon-button #:icon 'guitar
                               #:content (G_ "artists")
                               #:size '(text-md)
                               #:family '(font-sans)
                               #:color '(text-onyx-900 dark:text-stone-100)
                               #:weight '(font-light)
                               #:icon-css '(text-md lg:text-lg text-onyx-300
                                                    dark:text-stone-300)
                               #:extra-classes '(py-1 lg:py-2 px-2 lg:px-3
                                                      max-w-prose
                                                      cursor-pointer)))

              ,(if (not is-logged-in)
                   `((a (@ (class ,(mk-class '(text-md lowercase
                                                       text-white
                                                       dark:text-black
                                                       font-sans
                                                       font-medium

                                                       flex-items-center
                                                       gap-2)))
                           (href "/login"))
                        ,(icon-button #:icon 'sign-in
                                      #:content (G_ "login")
                                      #:family '(font-sans)
                                      #:color '(text-onyx-900
                                                dark:text-stone-100)
                                      #:weight '(font-light)
                                      #:size '(text-md)
                                      #:icon-css '(text-md lg:text-lg
                                                   text-onyx-300
                                                   dark:text-stone-300)
                                      #:extra-classes '(py-1 py-1
                                                             lg:py-2
                                                             px-2
                                                             lg:px-3
                                                             max-w-prose
                                                             cursor-pointer))))
                   `((a (@ (class ,(mk-class '(text-md lowercase
                                                       text-white
                                                       dark:text-black
                                                       font-sans
                                                       font-medium

                                                       flex-items-center
                                                       gap-2)))
                           (href "/me"))
                        ,(icon-button #:icon 'user-circle
                                      #:content (G_ "me")
                                      #:family '(font-sans)
                                      #:color '(text-onyx-900
                                                dark:text-stone-100)
                                      #:weight '(font-light)
                                      #:size '(text-md)
                                      #:icon-css '(text-md lg:text-lg
                                                   text-onyx-300
                                                   dark:text-stone-300)
                                      #:extra-classes '(py-1 lg:py-2 px-2
                                                             lg:px-3
                                                             max-w-prose
                                                             cursor-pointer)))))

              ,(ui-mode-button #:icon ""
                               #:size '(text-md)
                               #:icon-css '(text-onyx-300 dark:text-stone-300
                                                          text-md)
                               #:family '(font-sans)
                               #:content `((div ,(icon #:type 'sun
                                                       #:icon-css '(text-md
                                                                    lg:text-lg
                                                                    text-onyx-300
                                                                    dark:text-stone-300))
                                                ,(icon #:type 'moon
                                                       #:icon-css '(text-md
                                                                    lg:text-lg
                                                                    text-onyx-300
                                                                    dark:text-stone-300))))
                               #:color '(text-onyx-900 dark:text-stone-100)
                               #:weight '(font-light)
                               #:extra-classes '(py-1 lg:py-2 px-2 lg:px-3
                                                      max-w-prose
                                                      cursor-pointer))))))

(define* (html-template G_
                        #:key (title "WikiMusic") body
                        (is-logged-in #f))
  
  `(,doctype-html (html (head (title ,title)
                              ,(hygguile-recommended-meta)
                              ,(hygguile-recommended-resources #:fonts (custom-fonts))
                              (link (@ (rel "shortcut icon")
                                       (href "/favicon.ico")
                                       (type "image/x-icon")) "")
                              (link (@ (rel "icon")
                                       (href "/favicon.ico")
                                       (type "image/x-icon")) "")
                              (link (@ (rel stylesheet)
                                       (href "/css/wikimusic.olive.min.css"))
                                    "")
                              (script (@ (type speculationrules))
                                      "
{
  \"prerender\": [
    {
      \"where\": {
        \"selector_matches\": \"a\"
      }
    }
  ]
}
")
                              (script ,(assoc-ref asset-library
                                        "pub/js/song-chord-highlighter.js"))
                              (script ,(assoc-ref asset-library
                                        "pub/js/song-auto-scroll.js"))
                              (script ,(assoc-ref asset-library
                                                  "pub/js/symbanta.js"))
                              (script ,(assoc-ref asset-library
                                                  "pub/js/file-base64.js")))
                        (body (@ (class ,(mk-class '(bg-stone-100
                                                     dark:bg-onyx-900
                                                     font-sans))))
                              ,notification-tray
                              ,(with-footer #:main `((div (@ (class ,(mk-class '
                                                                      (flex
                                                                       flex-col
                                                                       justify-between
                                                                       min-h-96))))
                                                          (div (@ (class ,(mk-class '
                                                                           (flex
                                                                            flex-col
                                                                            gap-8
                                                                            justify-start))))
                                                               ,(nav G_
                                                                 #:is-logged-in
                                                                 is-logged-in)
                                                               ,body)))
                                            #:footer (page-footer G_))))))

(define* (item-tile G_
                    entity
                    x
                    artworks
                    comments
                    #:key (extra-bot-info '())
                    (extra-top-info '()))
  (let ((item-link (format #f "/~as/uuid/~a" entity
                           (assq-ref x
                                     'identifier))))
    `((div (@ (class ,(mk-class '(bg-stone-300 dark:bg-onyx-700
                                               rounded-xl
                                               sm:rounded-2xl
                                               shadow-md
                                               hover:shadow-lg
                                               transition-shadow
                                               duration-200
                                               h-full
                                               flex
                                               flex-col
                                               overflow-hidden
                                               border
                                               border-persia-pink-100/25
                                               dark:border-persia-pink-900/10))))

           ;; Cover
           ,(render-if-nempty (lambda (art)
                                `(a (@ (href ,item-link)
                                       (class ,(mk-class '(block w-full
                                                           aspect-square
                                                           shrink-0
                                                           overflow-hidden))))
                                    (img (@ (loading "lazy")
                                            (class ,(mk-class '(w-full h-full
                                                                object-cover
                                                                transition-transform
                                                                duration-200
                                                                hover:scale-105)))
                                            (src ,(uri-decode (assq-ref art
                                                                        'content-url)))))))
                              (cond
                                ((nil? artworks)
                                 '())
                                (else (car artworks))))

           ;; Content
           (div (@ (class ,(mk-class '(flex flex-col
                                            flex-grow
                                            min-w-0
                                            p-2
                                            sm:p-3
                                            md:p-4))))

                ;; Name
                (div (@ (class ,(mk-class '(min-w-0 text-center))))
                     ,(a (assq-ref x
                                   'display-name)
                         #:size '(text-md sm:text-md md:text-lg)
                         #:weight '(font-light)
                         #:family '(font-sans)
                         #:href item-link
                         #:color '(text-onyx-300 dark:text-stone-100)
                         #:hover '(hover:text-persia-pink-500
                                   hover:dark:text-persia-pink-300)))

                ;; Extra information
                ,(render-if-nempty (lambda (info)
                                     `(div (@ (class ,(mk-class '(pt-1 sm:pt-2
                                                                  text-center))))
                                           ,info)) extra-top-info)

                ;; Statistics
                (div (@ (class ,(mk-class '(mt-2 flex
                                                 flex-wrap
                                                 items-center
                                                 justify-center
                                                 gap-x-2
                                                 gap-y-1))))
                     (div ,(em (format #f "~a ~a"
                                       (assq-ref x
                                                 'views)
                                       (G_ "views"))
                               #:size '(text-sm)
                               #:color '(text-onyx-300 dark:text-stone-300)))

                     (span ,(p "·"
                               #:color '(text-onyx-500 dark:text-stone-700)
                               #:size '(text-sm)))

                     (div (@ (class ,(mk-class '(min-w-0))))
                          ,(em (format #f "~a ~a"
                                       (length comments)
                                       (G_ "comments"))
                               #:size '(text-sm)
                               #:color '(text-onyx-300 dark:text-stone-300))))

                ,extra-bot-info)))))

(define* (render-visibility-status G_ status)
  (cond
    ((eq? status 0)
     (G_ "published"))
    (else (G_ "unkown status"))))

(define* (render-comment G_ user-alist comment)
  `(div (@ (class "py-3"))
        ,(render-if-nempty (lambda (u)
                             `(p (@ (class ,(mk-class '(text-sm text-stone-600))))
                                 ,(format #f "~a (~a) &lt;~a&gt;"
                                          (assoc-ref u "display_name")
                                          (assoc-ref u "username")
                                          (assoc-ref u "email"))))
                           (car (assoc-ref user-alist
                                           (assq-ref comment
                                                     'created-by))))
        (p (@ (class ,(mk-class '(text-md text-stone-900))))
           ,(assq-ref comment
                      'contents))
        (p (@ (class ,(mk-class '(text-sm text-stone-400 dark:text-stone-300))))
           ,(assq-ref comment
                      'created-at))))

(define* (render-comments G_ user-alist parent-identifier comments)
  (let* ((top-nodes (filter (lambda (c)
                              (equal? parent-identifier
                                      (assoc-ref c
                                                 'parent-identifier)))
                            comments)))
    (map (lambda (comment)
           `((div (@ (class "max-w-prose"))
                  ,(render-comment G_ user-alist comment))
             (div (@ (class ,(mk-class '(max-w-prose pl-3))))
                  ,(render-comments G_ user-alist
                                    (assoc-ref comment
                                               'identifier) comments))))
         top-nodes)))

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
                                                                        w-72
                                                                        sm:w-96
                                                                        md:w-96
                                                                        lg:w-128
                                                                        max-w-full
                                                                        h-auto)))
                                                    (src ,(uri-decode (assq-ref
                                                                       art
                                                                       'content-url)))))
                                            ,(render-if-nempty (lambda (fc)
                                                                 `(figcaption (@
                                                                               (class ,
                                                                                (mk-class '
                                                                                 (text-onyx-300
                                                                                  dark:text-stone-300))))
                                                                              ,fc))
                                                               (assq-ref art
                                                                         'content-caption))))
                                 artworks))
         (rendered-comments (render-comments G_ user-alist #f comments))
         (like-count (length (filter (lambda (o)
                                       (and (equal? (assq-ref x
                                                              'identifier)
                                                    (assoc-ref o
                                                               (string->symbol
                                                                (format #f
                                                                 "~a-identifier"
                                                                 entity))))
                                            (equal? 1
                                                    (assq-ref o
                                                              'is-like))))
                                     opinions)))
         (dislike-count (length (filter (lambda (o)
                                          (and (equal? (assq-ref x
                                                                 'identifier)
                                                       (assq-ref o
                                                                 (string->symbol
                                                                  (format #f
                                                                   "~a-identifier"
                                                                   entity))))
                                               (equal? 1
                                                       (assoc-ref o
                                                                  'is-dislike))))
                                        opinions)))
         (opinion-buttons `((div (@ (class ,(mk-class '(flex flex-row
                                                             flex-wrap gap-3))))
                                 (form (@ (method POST)
                                          (action ,(format #f
                                                    "/~as/uuid/~a/like" entity
                                                    (assq-ref x
                                                              'identifier))))
                                       ,(icon-button #:icon 'thumbs-up
                                                     #:color '(text-stone-100)
                                                     #:background '(bg-asparagus-500)
                                                     #:hover-background '(hover:bg-asparagus-900)
                                                     #:type 'submit
                                                     #:icon-css '(text-lg
                                                                  text-stone-300
                                                                  dark:text-stone-300)
                                                     #:content `(div ,(G_
                                                                       "like")
                                                                     (span (@ (class ,
                                                                               (mk-class '
                                                                                (font-light
                                                                                 text-md))))
                                                                           ,(format
                                                                             #f
                                                                             " ( ~a ) "
                                                                             like-count)))))
                                 (form (@ (method POST)
                                          (action ,(format #f
                                                    "/~as/uuid/~a/dislike"
                                                    entity
                                                    (assq-ref x
                                                              'identifier))))
                                       ,(icon-button #:icon 'thumbs-down
                                                     #:color '(text-stone-100)
                                                     #:background '(bg-redwood-500)
                                                     #:hover-background '(hover:bg-redwood-900)
                                                     #:type 'submit
                                                     #:icon-css '(text-lg
                                                                  text-stone-300
                                                                  dark:text-stone-300)
                                                     #:content `(div ,(G_
                                                                       "dislike")

                                                                     (span (@ (class ,
                                                                               (mk-class '
                                                                                (font-light
                                                                                 text-sm))))
                                                                           ,(format
                                                                             #f
                                                                             " ( ~a ) "
                                                                             dislike-count))))))))
         (maybe-description (render-if-nempty (lambda (description)
                                                `(div (p (@ (class ,(mk-class '
                                                                              (text-onyx-300
                                                                               dark:text-stone-300
                                                                               font-bold))))
                                                         ,(G_ "description"))
                                                      (div (@ (class ,(mk-class '
                                                                       (max-w-prose
                                                                        pl-3
                                                                        whitespace-break-spaces))))
                                                           ,(p description
                                                               #:weight '(font-light)))))
                                              (org2html (html-unescape (assq-ref
                                                                        x
                                                                        'description)))))
         (maybe-last-edited-at (render-if-nempty (lambda (last-edited-at)
                                                   `(,(dt (G_ "last edited")) ,
                                                     (dd (strftime "%c"

                                                                   (localtime (string->number
                                                                               last-edited-at))))))
                                                 (assq-ref x
                                                           'last-edited-at)))
         (maybe-approved-by (render-if-nempty (lambda (approved-by)
                                                `(,(dt (G_ "approved by")) ,(dd
                                                                             approved-by)))
                                              (assq-ref x
                                                        'approved-by))))
    
    `((div (@ (class ,(mk-class '(py-4 flex flex-row flex-wrap gap-6))))
           (div ,rendered-artworks)
           (div (div (@ (class ,(mk-class '(flex flex-col gap-3 my-4))))
                     ,opinion-buttons
                     (a (@ (href ,(format #f "/~as/uuid/~a/edit" entity
                                          (assq-ref x
                                                    'identifier))))
                        ,(icon-button #:icon 'pencil
                                      #:content (G_ "edit"))))
                ,maybe-description
                (dl ,(dt (G_ "views"))
                    ,(dd (format #f "~a"
                                 (assq-ref x
                                           'views)))
                    ,(dt (G_ "created"))
                    ,(dd (strftime "%c"
                                   (localtime (string->number (assq-ref x
                                                                        'created-at)))))
                    ,maybe-last-edited-at
                    ,(dt (G_ "contributor"))
                    ,(dd (render-if-nempty (lambda (u)
                                             (format #f "~a &lt;~a&gt;"
                                                     (assq-ref u
                                                               'username)
                                                     (assq-ref u
                                                               'email)))
                                           (assoc-ref user-alist
                                                      (assq-ref x
                                                                'created-by))))
                    ,(dt (G_ "visibility"))
                    ,(dd (render-visibility-status G_
                                                   (assq-ref x
                                                             'visibility-status)))
                    ,maybe-approved-by
                    ,(dt (G_ "uuid"))
                    ,(dd `((div (@ (class ,(mk-class '(flex flex-row flex-wrap
                                                            gap-4))))
                                ,(mono (assq-ref x
                                                 'identifier)
                                       #:size '(text-sm)
                                       #:color '(text-stone-600
                                                 dark:text-stone-400))
                                ,(icon-button #:icon 'copy
                                              #:content "copy"

                                              #:on-click (format #f
                                                          "navigator.clipboard.writeText('~a')"
                                                          (assoc-ref x
                                                                     'identifier)))))))))
      (details (summary (@ (class ,(mk-class '(text-onyx-300
                                               dark:text-stone-300
                                               cursor-pointer))))
                        ,(em (format #f "~a ~a"
                                     (length comments)
                                     (G_ "comments"))))
               ,rendered-comments))))

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

(define* (external-sources-form G_
                                #:key entity
                                entity-identifier
                                (external-sources-identifier #f)
                                (wikipedia-url "")
                                (youtube-url "")
                                (spotify-url "")
                                (soundcloud-url ""))
  (let* ((form-action (if (equal? #f external-sources-identifier)
                          (format #f "/~as/uuid/~a/external-sources/new"
                                  entity entity-identifier)
                          (format #f "/~as/uuid/~a/external-sources/~a/edit"
                                  entity entity-identifier
                                  external-sources-identifier))))
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

(define* (sort-select G_
                      #:key entity user-sort)
  `((div (@ (class ,(mk-class '(flex flex-col gap-2 w-min))))
         (select (@ (onchange "window.location.href=this.value;")
                    (name "sort-select")
                    (id "sort-select")
                    (class ,(mk-class '(px-3 py-2
                                             border-2
                                             border-persia-pink-300/25
                                             dark:border-persia-pink-300/25
                                             font-sans
                                             bg-stone-300
                                             dark:bg-onyx-700
                                             text-onyx-300
                                             dark:text-stone-300
                                             rounded-xl
                                             shadow-md))))
                 (option (@ (disabled "true"))
                         ,(G_ "sort order"))
                 ,(map (lambda (s)
                         `((option (@ (value ,(format #f "/~as?sort=~a" entity
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

(define* (ascii-size-select G_
                            #:key route)
  `((div (@ (class ,(mk-class '(flex flex-col gap-2 w-min))))
         (select (@ (onchange "window.location.href=this.value;")
                    (name ascii-size-select)
                    (id ascii-size-select)
                    (class ,(mk-class '(py-2 px-3
                                             border-2
                                             border-persia-pink-300/25
                                             dark:border-persia-pink-300/25
                                             bg-stone-300
                                             dark:bg-onyx-700
                                             text-onyx-300
                                             dark:text-stone-300
                                             rounded-xl
                                             max-w-72
                                             shadow-md))))
                 (option ,(G_ "ascii size"))
                 ,(map (lambda (s)
                         `((option (@ (value ,(format #f "~a?ascii-size=~a"
                                                      route
                                                      (car s))))
                                   ,(cdr s))))
                       `(("text-xs" . "text-xs") ("text-sm" . "text-sm")
                         ("text-md" . "text-md")
                         ("text-lg" . "text-lg")
                         ("text-xl" . "text-xl")
                         ("text-1" . "text-1")
                         ("text-2" . "text-2")
                         ("text-3" . "text-3")
                         ("text-4" . "text-4")
                         ("text-5" . "text-5")
                         ("text-6" . "text-6")
                         ("text-7" . "text-7")
                         ("text-8" . "text-8")
                         ("text-9" . "text-9")
                         ("text-10" . "text-10")
                         ("text-11" . "text-11")
                         ("text-12" . "text-12")
                         ("text-16" . "text-16")))))))

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
               (div (@ (class ,(mk-class '(flex flex-row
                                                align-center
                                                flex-wrap
                                                items-center
                                                justify-center
                                                md:justify-start
                                                gap-2))))
                    ,(input #:label ""
                            #:name "search"
                            #:value (cond
                                      ((equal? #f search-query)
                                       "")
                                      (else search-query))
                            #:placeholder (G_ "Search...")
                            #:input-css '(py-2 px-3
                                               max-w-prose
                                               rounded-xl
                                               border-2
                                               border-persia-pink-300/25
                                               dark:border-persia-pink-300/25
                                               bg-stone-300
                                               dark:bg-onyx-700
                                               dark:text-stone-300
                                               text-onyx-300
                                               shadow-md)
                            #:input-flex-css #f)
                    ,(submit-button (G_ "search")))))))

(define* (render-external-link #:key link label)
  (render-if-nestring (lambda (l)
                        `((div (@ (class ,(mk-class '(flex flex-row gap-1
                                                           items-center
                                                           flex-wrap
                                                           align-center))))
                               ,(a `((div (@ (class ,(mk-class '(flex flex-row
                                                                 items-center
                                                                 gap-1))))
                                          (span ,label)
                                          ,(icon #:type 'link
                                                 #:icon-css '(text-china-violet-700
                                                              dark:text-china-violet-300
                                                              hover:text-persia-pink-500
                                                              hover:dark:text-persia-pink-300
                                                              text-2xl))))
                                   #:href l
                                   #:size '(text-lg)
                                   #:weight '(font-light)
                                   #:color '(text-china-violet-700
                                             dark:text-china-violet-300)
                                   #:hover '(hover:text-persia-pink-500
                                             hover:dark:text-persia-pink-300))

                               ))) link))

(define* (render-external-sources G_ external-sources)
  `((div (@ (class ,(mk-class '(flex flex-row
                                     flex-wrap
                                     gap-6
                                     py-2
                                     px-6
                                     md:py-4
                                     md:px-12
                                     w-full
                                     justify-center
                                     items-start
                                     align-end))))
         ,(render-external-link #:link (uri-decode (assoc-ref-or-empty-str
                                                    external-sources
                                                    'wikipedia-url))
                                #:label (G_ "Wikipedia"))
         ,(render-external-link #:link (uri-decode (assoc-ref-or-empty-str
                                                    external-sources
                                                    'spotify-url))
                                #:label (G_ "Spotify"))
         ,(render-external-link #:link (uri-decode (assoc-ref-or-empty-str
                                                    external-sources
                                                    'youtube-url))
                                #:label (G_ "Youtube"))
         ,(render-external-link #:link (uri-decode (assoc-ref-or-empty-str
                                                    external-sources
                                                    'soundcloud-url))
                                #:label (G_ "Soundcloud")))))

(define (org2html org)
  (parameterize ((link-classes '(dark:text-china-violet-300
                                 hover:dark:text-persia-pink-300
                                 hover:text-persia-pink-500
                                 text-china-violet-700 hover:underline
                                 font-bold))
                 (italic-classes '(italic))
                 (ordered-list-classes '(list-decimal ml-3))
                 (ordered-list-item-classes '(font-sans text-onyx-500
                                                        dark:text-stone-500
                                                        text-md leading-7))
                 (unordered-list-classes '(list-disc ml-3))
                 (unordered-list-item-classes '(font-sans text-onyx-500
                                                          dark:text-stone-500
                                                          text-md leading-7))
                 (heading-classes (lambda (level)
                                    (case level
                                      ((1)
                                       '(my-2 text-4xl font-bold text-onyx-300
                                              dark:text-stone-300))
                                      ((2)
                                       '(my-2 text-3xl font-bold text-onyx-300
                                              dark:text-stone-300))
                                      ((3)
                                       '(my-2 text-2xl font-bold text-onyx-300
                                              dark:text-stone-300))
                                      (else '(my-2 text-xl font-bold
                                                   text-onyx-300
                                                   dark:text-stone-300)))))
                 (separator-classes '(my-8 mx-4 border-2 border-stone-500/50
                                           dark:border-onyx-100/50))
                 (paragraph-classes '(font-sans text-onyx-500
                                                dark:text-stone-500
                                                text-md
                                                leading-7
                                                max-w-196
                                                break-words))
                 (bold-classes '(font-bold text-onyx-500 dark:text-stone-500))
                 (example-block-classes '(bg-stone-300/75 dark:bg-onyx-700/75
                                                          text-onyx-700
                                                          dark:text-stone-300
                                                          rounded-lg
                                                          my-3
                                                          py-2
                                                          px-3
                                                          whitespace-pre
                                                          font-mono
                                                          overflow-x-scroll))
                 (quote-block-classes '(bg-stone-300/75 dark:bg-onyx-700/75
                                                        text-onyx-700
                                                        dark:text-stone-300
                                                        rounded-lg
                                                        my-3
                                                        py-2
                                                        px-3
                                                        whitespace-pre
                                                        font-sans
                                                        overflow-x-scroll))
                 (code-block-classes '(bg-stone-300/75 dark:bg-onyx-700/75
                                                       text-onyx-700
                                                       dark:text-stone-300
                                                       rounded-lg
                                                       my-3
                                                       py-2
                                                       px-3
                                                       whitespace-pre
                                                       font-mono
                                                       overflow-x-scroll))
                 (code-classes '(rounded-lg bg-stone-300/75
                                            dark:bg-onyx-700/75
                                            text-onyx-700
                                            px-2
                                            py-1
                                            font-mono
                                            dark:text-stone-300)))
    (org->html org)))
