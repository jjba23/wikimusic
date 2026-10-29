;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Fetching the assets the interface is painted with.
;;;
;;; The type the pages are set in and the glyphs their controls wear are not
;;; wikimusic's own: the three Lucida families are the author's, the two web
;;; families are Google's, and the Phosphor set is Phosphor's.  What this script
;;; does is bring a copy of each into `pub/', so that a browser reading a page
;;; of this instance asks this instance for them and nobody else -- no
;;; third-party request for every reader to be told about, nothing to break when
;;; somebody else's host is down or renamed, and pages that render the same on a
;;; machine with no way out to the network at all.
;;;
;;; The files it writes are checked in, because they are what the instance
;;; serves; running it is only needed to refresh them, and it is written so that
;;; a refresh is the whole job: every address is either fixed upstream or read
;;; out of the stylesheet that answers, and every file a stylesheet names is
;;; downloaded from that same answer rather than from a version written down
;;; here to go stale.  Where a stylesheet names a file on another host, the
;;; address is rewritten to the file beside it before the copy is written, so
;;; that nothing in `pub/' points at a host that is not this instance.
;;;
;;; Run it as `maak vendor-assets'.

(define-module (resources assets fetch)
  #:use-module (ice-9 format)
  #:use-module (ice-9 popen)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 textual-ports)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:export (fetch-theme-assets! font-file-name rewrite-google-stylesheet
                                prune-phosphor-stylesheet))

;; Where the project is, so that the script writes the same files wherever it is
;; called from: the directory this file is read from, or the working directory
;; when it is handed to Guile in a way that has no file behind it.
(define project-root
  (let ((file (current-filename)))
    (if (and file
             (absolute-file-name? file))
        (dirname (dirname (dirname file)))
        (getcwd))))

(define (path-under-root . parts)
  "Return the path PARTS name inside the project."
  (string-join (cons project-root parts) "/"))

;; What Google is asked for.  The families are spelled the way their stylesheet
;; spells them, and the ranges are what makes the answer carry every weight and
;; slope the interface uses.  Every browser is sent the same agent: Google
;; decides between woff2 and its older formats from it, and a request that does
;; not look like a browser is answered with neither.
(define browser-user-agent
  (string-append "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
                 " (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"))

(define google-fonts-stylesheet
  (string-append "https://fonts.googleapis.com/css2?family="
                 "Intel+One+Mono:ital,wght@0,300..700;1,300..700" "&family="
                 "Plus+Jakarta+Sans:ital,wght@0,200..800;1,200..800"
                 "&display=swap"))

(define phosphor-stylesheet
  "https://cdn.jsdelivr.net/npm/@phosphor-icons/web@2.1.1/src/regular/style.css")

(define phosphor-font
  "https://cdn.jsdelivr.net/npm/@phosphor-icons/web@2.1.1/src/regular/Phosphor.woff2")

;; The three Lucida families the interface is set in and the picture the project
;; shows of itself.  Unlike the two above, these are wikimusic's own host's
;; files, which is exactly why a copy belongs here: the site worked only as long
;; as one machine stayed up and kept serving it.
(define lucida-font-files
  '("LSANS" "LSANSI"
    "LSANSD"
    "LSANSDI"
    "LTYPE"
    "LTYPEO"
    "LTYPEB"
    "LTYPEBO"
    "l_10646"))

(define lucida-font-host
  "https://jointhefreeworld.org/static-assets/fonts")

(define project-picture
  "https://jointhefreeworld.org/static-assets/wikimusic/img/wikimusic.jpg")

;; The licences of the files above, kept beside them.  They are somebody else's
;; work and they say so: the two web families travel under the SIL Open Font
;; Licence, which asks that a copy of it go with them, and the icon set under
;; the MIT licence, which asks for the notice.  A licence is fetched from the
;; place its own author keeps it rather than written out here, because the text
;; is theirs -- and it is fetched every time, so a set that is refreshed is
;; refreshed with the licence it was published under.
(define licence-files
  `(("https://raw.githubusercontent.com/google/fonts/main/ofl/intelonemono/OFL.txt" . "vendor/fonts/IntelOneMono-OFL.txt")
    ("https://raw.githubusercontent.com/google/fonts/main/ofl/plusjakartasans/OFL.txt" . "vendor/fonts/PlusJakartaSans-OFL.txt")
    ("https://raw.githubusercontent.com/phosphor-icons/web/master/LICENSE" . "vendor/phosphor/LICENSE")))

;;; ====== Fetching one file ======

(define (fetch! url file)
  "Download URL to FILE, failing loudly when it cannot be had.

`curl' is asked rather than Guile's own client because the manifest's Guile is
not guaranteed to carry the TLS bindings one needs, while `curl' is already what
the project's other asset task reaches for."
  (format #t "  fetching ~a~%" url)
  (let* ((port (open-pipe* OPEN_READ
                           "curl"
                           "--fail"
                           "--silent"
                           "--show-error"
                           "--location"
                           "--user-agent"
                           browser-user-agent
                           "--output"
                           file
                           url))
         (output (get-string-all port))
         (status (close-pipe port)))
    (when (not (zero? (status:exit-val status)))
      (error "could not fetch" url
             (string-trim-right output))) file))

(define (fetched-text url file)
  "Return the text of URL, keeping a copy of it in FILE."
  (fetch! url file)
  (call-with-input-file file
    get-string-all))

(define (write-text! text file)
  "Write TEXT to FILE."
  (call-with-output-file file
    (lambda (port)
      (display text port))))

;;; ====== Rewriting a fetched stylesheet ======

;; A stylesheet fetched to be served from here has to name its files here.  Each
;; face is therefore named after the family, the subset of Unicode it carries
;; and its slope, so that a file in the tree says what it holds instead of
;; carrying whatever opaque hash Google addresses it by.
(define (font-file-name url subset italic?)
  "Return what the face URL carries is called in the tree."
  (let* ((parts (string-split url #\/))
         ;; .../s/<family>/<version>/<file>.woff2
         (family (list-ref parts
                           (- (length parts) 3))))
    (string-append family "-" subset
                   (if italic? "-italic" "") ".woff2")))

(define (rewrite-google-stylesheet css)
  "Return the rewritten CSS and the faces it names.

The answer is the stylesheet with every `url(https://fonts.gstatic.com/...)' --
the address Google serves a face from -- replaced by the address of the file
beside it, together with the list of the addresses to fetch and the names to
keep them under.

Which subset a face carries and how it is sloped are the two things a reader
cannot get from the file name, so they are read off the block the face is
written in: each block is announced by the subset it is for, and states its own
slope.  Both are read in the order the stylesheet is written, so each face is
named while the block that describes it is still in hand."
  (let loop
    ((lines (string-split css #\newline))
     (subset "latin")
     (italic? #f)
     (kept '())
     (faces '()))
    (if (null? lines)
        (list (string-join (reverse kept) "\n")
              (reverse faces))
        (let* ((line (car lines))
               (announced (string-match "^/\\* (.+) \\*/[[:space:]]*$" line))
               (sloped (string-match "font-style:[[:space:]]*italic" line))
               (straight (string-match "font-style:[[:space:]]*normal" line))
               (face (string-match "url\\((https://[^)]+\\.woff2)\\)" line)))
          (cond
            (announced (loop (cdr lines)
                             (match:substring announced 1) italic?
                             (cons line kept) faces))
            (sloped (loop (cdr lines) subset #t
                          (cons line kept) faces))
            (straight (loop (cdr lines) subset #f
                            (cons line kept) faces))
            (face (let* ((url (match:substring face 1))
                         (name (font-file-name url subset italic?)))
                    (loop (cdr lines) subset italic?
                          (cons (regexp-substitute #f
                                                   face
                                                   'pre
                                                   "url(./"
                                                   name
                                                   ")"
                                                   'post) kept)
                          (cons (cons url name) faces))))
            (else (loop (cdr lines) subset italic?
                        (cons line kept) faces)))))))

(define (prune-phosphor-stylesheet css)
  "Return CSS with the older formats of its font dropped from the face.

Phosphor's stylesheet offers the same set as woff2, woff, ttf and svg, one to a
line.  The vendored copy ships the woff2 -- every browser able to read this
interface reads it -- and a stylesheet that went on naming the three files it
does not ship would be a copy that does not describe what is beside it.  What is
left of the face names one file, so the list it ends is ended by a semicolon."
  (let ((terminated ;what the face still names is the last of what it named
                    (regexp-substitute/global #f
                                              "format\\(\"woff2\"\\),"
                                              css
                                              'pre
                                              "format(\"woff2\");"
                                              'post)))
    (regexp-substitute/global
     ;; a clause naming a file this instance does not serve, with the
     ;; whitespace in front of it -- the newline that ended the clause before
     ;; it -- and the comma that followed
     #f
     "[[:space:]]*url\\(\"\\./Phosphor\\.[^)]*\\) format\\(\"(woff|truetype|svg)\"\\),?;?"
     terminated
     'pre
     ""
     'post)))

;;; ====== The job ======

(define (make-directory! path)
  "Create PATH when it is not there yet."
  (when (not (file-exists? path))
    (format #t "  creating ~a~%" path)
    (mkdir path)))

(define (fetch-google-fonts!)
  "Bring Google's answer, and every face it names, into `pub/vendor/fonts'."
  (let* ((file (path-under-root "pub/vendor/fonts/google.css"))
         (rewritten (rewrite-google-stylesheet (fetched-text
                                                google-fonts-stylesheet file)))
         (faces (cadr rewritten)))
    (for-each (lambda (face)
                (fetch! (car face)
                        (path-under-root "pub/vendor/fonts/"
                                         (cdr face)))) faces)
    (write-text! (car rewritten) file)
    (format #t "  wrote ~a (~a faces)~%" file
            (length faces))))

(define (fetch-phosphor-icons!)
  "Bring the Phosphor glyph set, and its stylesheet, into `pub/vendor/phosphor'."
  (let ((file (path-under-root "pub/vendor/phosphor/phosphor.css")))
    (fetch! phosphor-font
            (path-under-root "pub/vendor/phosphor/Phosphor.woff2"))
    (write-text! (prune-phosphor-stylesheet (fetched-text phosphor-stylesheet
                                                          file)) file)
    (format #t "  wrote ~a~%" file)))

(define (fetch-lucida-fonts!)
  "Bring the three Lucida families into `pub/vendor/fonts'."
  (for-each (lambda (face)
              (fetch! (string-append lucida-font-host "/" face ".woff")
                      (path-under-root "pub/vendor/fonts"
                                       (string-append face ".woff"))))
            lucida-font-files))

(define (fetch-project-picture!)
  "Bring the picture the project shows of itself into `pub/img'."
  (fetch! project-picture
          (path-under-root "pub/img/wikimusic.jpg")))

(define (fetch-licences!)
  "Bring the licences of the files above in beside them."
  (for-each (lambda (licence)
              (fetch! (car licence)
                      (path-under-root "pub"
                                       (cdr licence)))) licence-files))

(define (fetch-theme-assets!)
  "Fetch every asset this instance serves but did not write."
  (format #t "vendoring the theme's assets into pub/~%")
  (for-each make-directory!
            (map (lambda (directory)
                   (path-under-root "pub" directory))
                 '("vendor" "vendor/fonts" "vendor/phosphor" "img")))
  (format #t "the three Lucida families:~%")
  (fetch-lucida-fonts!)
  (format #t "the two web families:~%")
  (fetch-google-fonts!)
  (format #t "the icon set:~%")
  (fetch-phosphor-icons!)
  (format #t "the project's picture:~%")
  (fetch-project-picture!)
  (format #t "the licences the files above travel under:~%")
  (fetch-licences!)
  (format #t "done~%"))

;; A script rather than a library: the job runs when this file is what Guile was
;; given to read, and not when something imports it for the parts it is built
;; from -- which is how the rewriting below is checked without a network.  Those
;; three procedures are exported for exactly that reason: they are what decides
;; where a refreshed tree points, and deciding it wrongly is a mistake that no
;; amount of fetching would show (see `test/veritas/unit/assets-spec.scm').
(define (run-when-main!)
  (when (any (lambda (argument)
               (and (string? argument)
                    (string-contains argument "assets/fetch.scm")))
             (command-line))
    (fetch-theme-assets!)))

(run-when-main!)
