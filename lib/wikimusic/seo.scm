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

;;; Everything a search engine or a link preview is told about a page, in one
;;; place.  A page's body is written for the reader; this module is what a
;;; crawler reads instead -- the title, the one-sentence description, the
;;; canonical address, the Open Graph and Twitter card tags a chat client shows
;;; when the link is pasted, and the JSON-LD that says what kind of thing the
;;; page is about.
;;;
;;; Three rules the rest of the site relies on:
;;;
;;; * A tag that cannot be filled in truthfully is left out rather than
;;;   guessed at.  A tag whose value is wrong is worse than a missing one, so an
;;;   address that cannot be made absolute simply produces no `canonical' link.
;;; * A description is *text*.  Descriptions are written in Org, and the
;;;   markup is taken back off before any of it reaches a meta tag, so
;;;   `[[https://example.org][Example]]' is announced as "Example" and not as
;;;   the source of the page.
;;; * Nothing here reads a request.  `seo-head' is handed what a view already
;;;   knows, so the same page fragment can be built and tested without a server
;;;   in front of it.

(define-module (wikimusic seo)
  #:declarative? #t
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-19)
  #:use-module (ice-9 format)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 string-fun)
  #:use-module (web uri)
  #:use-module (json)
  #:use-module (artanis artanis)
  #:use-module (wikimusic config)
  #:export (site-origin absolute-url
                        announced-image
                        summarize
                        org-plain-text
                        language-of
                        seo-head
                        json-ld-script
                        page-json-ld
                        schema-name
                        schema-node
                        named-nodes))

;;; ====== The instance's own address ======

;; The image a page without one of its own is announced with is the one the
;; deployment names -- the project's own picture by default, and an instance's
;; own when it has one (see `(wikimusic config)').  It is read per page rather
;; than kept here, so an instance that points at its own picture says so in one
;; place instead of in every view that shows one.
;;
;; What is announced has to be an address a crawler can fetch from outside this
;; request, and what the configuration holds may be a path on this instance --
;; which is what the project's own picture is, since the instance serves it
;; itself.  The two are therefore joined here, at the point a page states one,
;; where the host being answered is known; an address the deployment gave
;; outright is passed through as it is.
(define (announced-image)
  "Return the address a page without a picture of its own is announced with."
  (let ((picture (social-image-url)))
    (or (absolute-url picture) picture)))

;; How big the picture this project ships is, as the tags that describe it have
;; to say.  They are read off the file itself rather than guessed: a preview
;; half the width a client was promised is one it lays out wrong.  A deployment
;; that announces a picture of its own has one of a different size, and these
;; are the one tag here that describe the project's default rather than the
;; deployment's choice.
(define announced-image-width
  "2048")
(define announced-image-height
  "2048")

(define (loopback-host? host)
  "Return #t when HOST names the machine the server is running on.

A development instance is reached over plain HTTP on the loopback interface,
and upgrading its scheme to HTTPS would name an address that does not exist."
  (and (string? host)
       (or (equal? host "localhost")
           (equal? host "127.0.0.1")
           (equal? host "::1")
           (equal? host "[::1]")
           (string-suffix? ".localhost" host))))

(define (with-https origin)
  "Return ORIGIN with its scheme changed to HTTPS when that is what a public
address of a public host is served as, and ORIGIN unchanged otherwise.

The framework answers `current-myhost' from the configured host name and
always spells the scheme `http', because it cannot know what a reverse proxy or
a CDN in front of it terminates; a canonical address has to be the one a reader
actually types, so a public host is upgraded and the loopback of a development
instance is left exactly as it is."
  (let ((uri (catch #t
                    (lambda ()
                      (string->uri origin))
                    (lambda (key . args)
                      #f))))
    (if (and uri
             (uri-host uri)
             (not (loopback-host? (uri-host uri)))
             (or (not (uri-port uri))
                 (= (uri-port uri) 80)))
        (uri->string (build-uri 'https
                                #:host (uri-host uri))) origin)))

(define (configured-site-origin)
  "Return the public origin an operator set for this instance, or #f.

The variable is read from the deployment's own `(wikimusic env)' module -- the
one file a deployment writes for itself -- so an instance behind a proxy that
terminates TLS somewhere else can simply say what its address is.  Nothing
needs to set it: an instance that does not is described by its own configured
host name."
  (let ((value (config-value 'site-origin)))
    (and value
         (string-trim value #\/))))

(define* (site-origin)
  "Return this instance's public origin, without a trailing slash.

It is, in order: `site-origin' from the deployment's `(wikimusic env)' when it
sets one, the framework's configured host name with a public host's scheme
upgraded to HTTPS, or the empty string when neither is available -- which is
the answer outside a request, and which makes every address built from it a
plain path rather than a wrong full one."
  (or (configured-site-origin)
      (let ((origin
              (catch #t
                     (lambda ()
                       (current-myhost))
                     (lambda (key . args)
                       #f))))
        (if (string? origin)
            (with-https (string-trim origin #\/)) ""))))

(define* (absolute-url path
                       #:key (origin
                               (site-origin)))
  "Return PATH as an address on this instance, or #f when there is no origin to
build one on.

A path that is already a full `http' or `https' address is returned unchanged,
so a caller may hand in either the page's own path or an address from a row."
  (cond
    ((not (string? path))
     #f)
    ((or (string-prefix? "http://" path)
         (string-prefix? "https://" path))
     path)
    ((string-null? origin)
     #f)
    ((string-null? path)
     (format #f "~a/" origin))
    (else (format #f "~a/~a" origin
                  (string-trim path #\/)))))

;;; ====== Turning a description into an announcement ======

(define (collapse-whitespace text)
  "Return TEXT with every run of whitespace reduced to one space."
  (regexp-substitute/global #f
                            "[ \t\r\n]+"
                            text
                            'pre
                            " "
                            'post))

(define (org-plain-text text)
  "Return the prose of TEXT without the Org markup it is written with.

A description is stored as Org and rendered as Org on its own page, but a meta
description is read out of place: by a search result, a chat client, a screen
reader's link list.  Links keep their words, verbatim quotes keep their text,
the block delimiters and the keywords that configure a document are dropped,
and the emphasis markers that surround a word are removed."

  (define (keyword-line? line)
    (let ((trimmed (string-trim-both line)))
      (or (string-null? trimmed)
          (string-prefix? "#+" trimmed)
          (string-prefix? ":" trimmed))))

  (if (or (not (string? text))
          (string-null? text)) ""
      (let* ((kept (filter (lambda (line)
                             (not (keyword-line? line)))
                           (string-split text #\newline)))
             (joined (string-join kept " "))
             ;; [[address][the words shown]] keeps the words, and a bare
             ;; [[address]] keeps the address itself.
             (words (regexp-substitute/global #f
                                              "\\[\\[[^\\]]*\\]\\[([^\\]]*)\\]\\]"
                                              joined
                                              'pre
                                              1
                                              'post))
             (bare (regexp-substitute/global #f
                                             "\\[\\[([^\\]]*)\\]\\]"
                                             words
                                             'pre
                                             1
                                             'post))
             ;; The emphasis markers *bold*, /italic/, _underline_, =verbatim=
             ;; and ~code~ are removed rather than their contents.
             (plain (regexp-substitute/global #f
                                              "[*_=~]"
                                              bare
                                              'pre
                                              ""
                                              'post))
             ;; An ordered or bulleted list item begins with its marker.
             (items (regexp-substitute/global #f
                                              "(^| )[-+] "
                                              plain
                                              'pre
                                              1
                                              'post))
             (squashed (collapse-whitespace items)))
        (string-trim-both squashed))))

(define* (summarize text
                    #:key (limit 160))
  "Return TEXT as one sentence-sized line a meta description can hold.

The Org markup is taken off first, then the text is cut at the last whole word
that fits within LIMIT characters, with an ellipsis where the rest was.  A
description already short enough is returned as it is, and one that is empty or
not text at all answers the empty string, so a caller may pass the result on
without testing it again."
  (let* ((plain (org-plain-text text))
         (plain (if (string? plain) plain "")))
    (cond
      ((string-null? plain)
       "")
      ((<= (string-length plain) limit)
       plain)
      (else (let* ((head (substring plain 0 limit))
                   ;; Cutting mid-word makes a sentence look unfinished, so the cut
                   ;; moves back to the space after the last whole word -- unless
                   ;; the whole window is one very long word, which is then simply
                   ;; cut.
                   (space (string-rindex head #\space))
                   (head (if (and space
                                  (> space
                                     (/ limit 2)))
                             (substring head 0 space) head)))
              (format #f "~a…"
                      (string-trim-right head)))))))

;;; ====== The head of a page ======

(define* (meta #:key name property content)
  "Return one `<meta>' element carrying CONTENT, named by NAME or PROPERTY.

An attribute whose value is #f is left off the element entirely: an empty
`og:image' tells a chat client that the page has an image and that it is
nothing, which is worse than saying nothing at all."
  `(meta (@ ,@(if name
                  `((name ,name))
                  '())
            ,@(if property
                  `((property ,property))
                  '())
            (content ,content))))

(define (json-ld-script data)
  "Return DATA as a `<script type=\"application/ld+json\">' element.

A `<script>' is raw text: the browser hands its contents to the JSON parser
without decoding entities, so a `<', '>' or `&' left as itself would either be
read as markup that is not there or arrive as the characters `&amp;' and break
the parse.  Each of the three is therefore written as the JSON escape that
means the same character, which keeps what is written exactly what is parsed."
  (let* ((encoded (scm->json-string data))
         (safe (regexp-substitute/global #f
                                         "[<>&]"
                                         encoded
                                         'pre
                                         (lambda (match )
                                           (format #f "\\u~4,'0x"
                                                   (char->integer (string-ref (match:substring
                                                                               match
                                                                               0)
                                                                              0))))
                                         'post)))
    `(script (@ (type "application/ld+json"))
             ,safe)))

(define (language-of locale)
  "Return the language part of LOCALE, which Open Graph spells as `en_US'.

A document's `lang' attribute names a language and not a place -- `en', not
`en_US' -- so the region is dropped; a locale that is already a bare language
is returned unchanged."
  (if (not (string? locale)) "en"
      (let ((underscore (string-index locale #\_)))
        (if underscore
            (substring locale 0 underscore) locale))))

(define* (schema-name type)
  "Return a node whose only fact is that it is of TYPE.

TYPES is a string naming a schema.org type, or a list of them, which becomes
the JSON-LD array a node that is more than one kind of thing is written as."
  (cons "@type"
        (if (list? type)
            (list->vector type) type)))

(define* (schema-node #:key type name extra)
  "Return a JSON-LD node of TYPE named NAME, with EXTRA's pairs as well.

It is the shape almost every node here has -- what it is, what it is called,
and the couple of facts that make it worth describing -- without the caller
having to remember to put `@type' first."
  (append (list (schema-name type))
          (if (and name
                   (not (string-null? name)))
              (list (cons "name" name))
              '())
          (or extra
              '())))

(define* (named-nodes #:key type names)
  "Return NAMES as a JSON-LD array of nodes of TYPE, or #f when there are none.

An empty array is #f rather than `#()': a property whose value is an empty
array says the page has something here and it is nothing, and the caller can
therefore drop the pair instead.  The list becomes a *vector* because that is
what the JSON writer reads as an array -- a Scheme list is written as an
object."
  (if (or (not (list? names))
          (null? names)) #f
      (list->vector (map (lambda (name)
                           (schema-node #:type type
                                        #:name name)) names))))

(define* (page-json-ld #:key type
                       (url #f)
                       name
                       description
                       main-entity
                       extra)
  "Return the JSON-LD node that says what a page is and what it is about.

The site is a wiki, so a page about a song is a page whose *subject* is a
composition: the page itself is a `WebPage' (`CollectionPage' or `Article' when
that is what it is) and the thing it documents is its `mainEntity'.  That is
the shape schema.org asks for, and the one a search engine reads a page's
subject out of.

@table @var
@item type
The page's own type, as a string or a list of strings.
@item url
The page's absolute address, or #f when there is none to state.
@item name
The page's title.
@item description
The one-sentence description.
@item main-entity
An association list describing what the page is about, or #f.
@item extra
Further pairs to add to the node, for the few facts that are neither of the
page nor of its subject.
@end table"
  (append (list (schema-name type))
          (if url
              (list (cons "url" url))
              '())
          (if (and name
                   (not (string-null? name)))
              (list (cons "name" name))
              '())
          (if (and description
                   (not (string-null? description)))
              (list (cons "description" description))
              '())
          (if main-entity
              (list (cons "mainEntity"
                          (if (list? main-entity) main-entity
                              (list main-entity))))
              '())
          (or extra
              '())))

(define* (seo-head #:key title
                   description
                   path
                   url
                   image
                   image-alt
                   (og-type "website")
                   (locale "en")
                   (site-name "WikiMusic")
                   robots
                   json-ld)
  "Return the head elements that describe a page to crawlers and link previews.

Everything is optional and nothing is invented: a title always produces a
`og:title' and a `twitter:title', a description always produces the three tags
that hold one, and the address tags are produced only when PATH or URL resolves
to an absolute address on this instance.

@table @var
@item title
The page's title, as the `<title>' has it.
@item description
One or two sentences, in plain prose, already stripped of Org markup.
@item path
The page's path on this instance, from which its canonical address is built.
@item url
The page's address, when it is already known; it wins over PATH.
@item image
The picture a preview is shown with; the default is the project's own.
@item image-alt
What that picture shows.
@item og-type
The Open Graph type: `website' for a page, `article' for something written.
@item locale
The language a preview is labelled with, as Open Graph spells it.
@item robots
What crawlers may do with the page; #f means nothing is said and the
defaults apply.
@item json-ld
A list of JSON-LD nodes, each written into a script of its own.
@end table"
  (let* ((absolute (or url
                       (and path
                            (absolute-url path))))
         (description (if (and (string? description)
                               (not (string-null? description))) description
                          #f))
         (image (or image
                    (announced-image))))
    (filter (lambda (element)
              element)
            (append (if description
                        (list (meta #:name "description"
                                    #:content description))
                        '())
                    (if absolute
                        (list `(link (@ (rel "canonical")
                                        (href ,absolute))))
                        '())
                    (if robots
                        (list (meta #:name "robots"
                                    #:content robots))
                        '())
                    ;; Open Graph: the tags a chat client, a forum and a social site
                    ;; read a pasted link out of.
                    (if title
                        (list (meta #:property "og:title"
                                    #:content title))
                        '())
                    (if description
                        (list (meta #:property "og:description"
                                    #:content description))
                        '())
                    (if absolute
                        (list (meta #:property "og:url"
                                    #:content absolute))
                        '())
                    (list (meta #:property "og:type"
                                #:content og-type)
                          (meta #:property "og:site_name"
                                #:content site-name)
                          (meta #:property "og:locale"
                                #:content locale))
                    (if image
                        (append (list (meta #:property "og:image"
                                            #:content image)
                                      (meta #:property "og:image:width"
                                            #:content announced-image-width)
                                      (meta #:property "og:image:height"
                                            #:content announced-image-height))
                                (if image-alt
                                    (list (meta #:property "og:image:alt"
                                                #:content image-alt))
                                    '()))
                        '())
                    ;; Twitter/X reads its own names first: the card is a large image
                    ;; card, and each tag is stated rather than left to be guessed
                    ;; from the Open Graph ones.
                    (list (meta #:name "twitter:card"
                                #:content "summary_large_image"))
                    (if title
                        (list (meta #:name "twitter:title"
                                    #:content title))
                        '())
                    (if description
                        (list (meta #:name "twitter:description"
                                    #:content description))
                        '())
                    (if image
                        (append (list (meta #:name "twitter:image"
                                            #:content image))
                                (if image-alt
                                    (list (meta #:name "twitter:image:alt"
                                                #:content image-alt))
                                    '()))
                        '())
                    (map json-ld-script
                         (or json-ld
                             '()))))))
