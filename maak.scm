;;; wikimusic

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

(define-module (maak)
  #:use-module (maak maak)
  #:declarative? #t)

;; ====== Maak constants ======

;; The TCP port on which the web server will listen.
(define http-port
  50050)

(define deploy-dir
  "/srv/http/jointhefreeworld.org")

;; The file where the Wikimusic DB is located.
(define wikimusic-db
  "wikimusic.db")

;; The SQL migrations.  Mutastructura reads this directory itself and applies
;; the files in it oldest first, as the file names sort, so this is the directory
;; rather than a shell glob.
(define migrations-dir
  "resources/migrations/sqlite")

;; The main copyright holders of the project.
(define copyright-holders
  '("Josep Bigorra"))

;; The path to the directory where the i18n resources are located.
(define i18n-dir
  "./sys/i18n/locale")

;; The text domain for the i18n translations.
(define i18n-textdomain
  "translate")

(define i18n-locales
  '(en_US nl_NL es_ES ja_JP))

(define hot-reload-file-types
  '(scm css js))

;; The Emacs Lisp script to run for publishing the manual.
;;
;; The manual is the README: one document, read on the forge and published as
;; HTML, rather than two that say the same thing and drift apart.  The export
;; lands beside it, as `README.html', and the deploy task below is what moves it
;; in front of the instance that serves it.
;; The manual's figures and example blocks carry a `#+name:', and this makes the
;; exporter use those names as the HTML ids instead of inventing a fresh
;; `orgXXXXXX' one on every build -- an id that changes on every build is an
;; anchor no reader can keep.
(define emacs-lisp-manual-publish-cmd
  '(progn (require 'ox-html)
          (setq org-html-prefer-user-labels t)
          (find-file "./README.org")
          (org-html-export-to-html)
          (message "finished publishing Wikimusic manual")))

;; ====== Maak i18n abstractions ======

(define (i18n-compile* lang)
  "Compile the translation file (.po) into a machine-readable (.mo) format

Args: lang represents the language code (e.g., en_US, nl_NL, etc.)

Use msgfmt to compile the .po file into a .mo file for the specified language
The output .mo file will be placed in the LC_MESSAGES directory under the language's folder."
  ($ (list (~ "msgfmt -v -o ~a/~a/LC_MESSAGES/~a.mo" i18n-dir lang
              i18n-textdomain)
           (~ "~a/~a/LC_MESSAGES/~a.po" i18n-dir lang i18n-textdomain))))

(define (i18n-init* lang)
  "Initialize a new translation file from a template (.pot) for a specific language.

Args: lang represents the language code (e.g., en_US, nl_NL, etc.)

Use msginit to generate a .po file from the .pot template for the specified language
The -l option sets the language, and --no-translator means no translator is pre-filled in the .po file
The generated .po file is placed in the LC_MESSAGES directory for the given language"
  (mkdir-p (~ "~a/~a/LC_MESSAGES" i18n-dir lang))
  ($ (list (~ "msginit -l ~a.UTF8 -o" lang)
           (~ "~a/~a/LC_MESSAGES/~a.po" i18n-dir lang i18n-textdomain)
           (~ "-i ~a/~a.pot --no-translator" i18n-dir i18n-textdomain))
     #:verbose? #t))

(define (i18n-merge* lang)
  "Merge translation updates from the template (.pot) into an existing .po file.

Args: lang represents the language code (e.g., en_US, nl_NL, etc.)

Use msgmerge to update the specified language's .po file with new translations from the template (.pot)
The -U flag updates the .po file in place
This ensures the .po file stays up-to-date with the latest changes in the template"
  ($ (list "msgmerge -U"
           (~ "~a/~a/LC_MESSAGES/~a.po" i18n-dir lang i18n-textdomain)
           (~ "~a/~a.pot" i18n-dir i18n-textdomain))))

(define (i18n-source-globs)
  "Return the source file patterns xgettext should read, existing ones only.

A glob that matches nothing is handed to xgettext as itself, and xgettext
refuses the whole invocation over the missing file -- writing no template at
all rather than the strings it did find.  The directories are therefore asked
for only when they are there, so adding or removing a source directory is all a
translation refresh ever needs."
  (append (if (file-exists? "lib/wikimusic/job")
              '("lib/wikimusic/job/*.scm")
              '())
          '("lib/wikimusic/*.scm" "app/controllers/*.scm" "app/views/*.scm")
          (if (file-exists? "app/api")
              '("app/api/*.scm")
              '())
          '("ENTRY")))

(define* (i18n-extract* #:key (update? #t))
  "Extract translatable strings from Scheme source files using xgettext.
Args: update? represents whether we should update a template or create a new one."
  ($ (append (list (~ "xgettext --default-domain=~a" i18n-textdomain)
                   (~ "--output=~a/~a.pot" i18n-dir i18n-textdomain)
                   "--language=Scheme --keyword=G_" "--sort-by-file")
             (if update?
                 (list "--join-existing")
                 '())
             (list (~ "--copyright-holder=\"~a\""
                      (string-join copyright-holders ","))
                   (~ "--package-name=~a" i18n-textdomain))
             (i18n-source-globs)
             (list "--from-code UTF-8"))
     #:verbose? #t))

;; ====== Maak tasks ======

(define (repl)
  "Development REPL."
  (time-machine-manifest-shell '("guile -L ./lib -L ."
                                 "-c '((@ (ares server) run-nrepl-server))'")))

(define (default)
  "Default task to be run, list available tasks."
  ($ '("maak --list")))

;; The key file has to be loaded before the runner forks a worker for each
;; spec: the modules under test import (wikimusic env), and a worker inherits
;; what the parent had loaded.  The server does the same thing from ENTRY, so
;; this is the test run reading the project's keys the way the server does.
(define (test)
  "Run the project's test suite, one spec at a time, from test/veritas."
  (time-machine-manifest-shell '("guile  --fresh-auto-compile -L ./lib -L ./test -L ."
                                 "-c '(load \"env.scm\")(begin (setlocale LC_ALL \"C.UTF-8\") (use-modules (veritas runner)) (run-tests))'")))

(define (build-manual)
  "Render the project's manual, which is the README."
  (time-machine-manifest-shell (list (~ "emacs -Q --batch --eval '~s'"
                                        emacs-lisp-manual-publish-cmd))
                               #:verbose? #t))

(define (deploy)
  "Deploy the project's documentation.

The manual is rendered from the README and served under `manuals/wikimusic',
which is where a reader of the site is sent."
  (build-manual)
  (mkdir-p (~ "~a/manuals/wikimusic" deploy-dir))
  (delete-file-recursively (~ "~a/manuals/wikimusic/index.html" deploy-dir))
  (mv "README.html"
      (~ "~a/manuals/wikimusic/index.html" deploy-dir)))

(define (fmt)
  "Format Scheme source code files according to the Guix style guide."
  ($ '("find . -maxdepth 8 -name '*.scm'" "-type f -exec guix style -f {} \\;")))

(define (hot-reload)
  "Hot-reloading developer's setup."
  (time-machine-manifest-shell (list "watchexec"
                                     "--clear"
                                     (~ "--exts ~a"
                                        (string-join (map symbol->string
                                                      hot-reload-file-types)
                                                     ","))
                                     "--on-busy-update=restart"
                                     "--shell bash"
                                     "--watch . --"
                                     "maak server")))

(define (hr)
  "Alias to hot-reloading."
  (hot-reload))

(define (dev)
  "Developer's setup."
  (hot-reload))

(define (kill-server)
  "Kill any running HTTP server in the same port."
  ($ (list (~ "fuser -k ~a/tcp || true" http-port)))
  ($ '("sleep 2")))

(define (server)
  "Target to start the wikimusic server with the default configuration."
  (kill-server)
  (time-machine-manifest-shell '("art work")))

(define (production-server)
  "Target to start the wikimusic server with the production configuration."
  (kill-server)
  (time-machine-manifest-shell '("art work -c conf/production.conf")))

(define (migrate)
  "Apply the SQL migrations to the database in this directory with mutastructura.

Mutastructura does the applying: it keeps a ledger of what it has run in the
`migrations_history' table of the database, runs only the migrations that are
not in it and records each one with a SHA256 of its file, all inside a single
transaction.  That is what makes this safe to run at any time, and it is also
the way to bring a database made by an earlier deployment up to what the source
in front of it expects.  Mutastructura is the only thing that applies
migrations; no task reads the SQL files and hands them to sqlite3 itself."
  (time-machine-manifest-shell (list (format #f
                                      "mutastructura --database sqlite3 --connection ~a --migrations ~a"
                                      wikimusic-db migrations-dir))
                               #:verbose? #t))

(define (init-db)
  "Initialize a new database, enable WAL mode, and apply the schema.

WAL mode is what gives SQLite 3 the concurrent writes the web workers want.
The database that comes out is otherwise ready for the server: every migration
under resources/migrations/sqlite has been applied to it, by mutastructura
(`maak migrate').  It deletes whatever wikimusic.db is already there, which is
why a deployment that has data runs `maak migrate' instead."
  (delete-file-recursively wikimusic-db)
  (delete-file-recursively (~ "~a-shm" wikimusic-db))
  (delete-file-recursively (~ "~a-wal" wikimusic-db))
  ;; The command list, not the bare string: `time-machine-manifest-shell'
  ;; appends what it is given to the `guix time-machine ... shell' it builds,
  ;; so a string here would make the whole command an improper list.
  (time-machine-manifest-shell (list (~
                                      "sqlite3 ~a 'PRAGMA journal_mode=WAL;'"
                                      wikimusic-db)))
  (migrate))

;; ====== Maak i18n tasks ======

(define (i18n-compile)
  "Compile the translation files for all locales."
  (for-each i18n-compile* i18n-locales))

(define (i18n-init-en)
  "Initialize a new translation file for en_US."
  (i18n-init* 'en_US))

(define (i18n-init-nl)
  "Initialize a new translation file for nl_NL."
  (i18n-init* 'nl_NL))

(define (i18n-init-es)
  "Initialize a new translation file for es_ES."
  (i18n-init* 'es_ES))

(define (i18n-init-ja)
  "Initialize a new translation file for ja_JP."
  (i18n-init* 'ja_JP))

(define (i18n-merge)
  "Merge translation updates for all locales."
  (for-each i18n-merge* i18n-locales))

(define (i18n-new-template)
  "Create a new i18n template based on strings extracted from source code."
  (i18n-extract* #:update? #f))

(define (i18n-update-template)
  "Update the i18n template based on strings extracted from source code."
  (i18n-extract* #:update? #t))

(define (olive-css)
  ($ '("curl --output \"./pub/css/wikimusic.olive.min.css\""
       "\"https://codeberg.org/jjba23/olive-css/raw/branch/trunk/resources/css/wikimusic.olive.min.css\"")))

;; The type and the glyphs are fetched rather than written: the three Lucida
;; families, the two web families and the Phosphor set are somebody else's work,
;; and the files a page reads are copies of it kept in `pub/' and served by this
;; instance itself (see `resources/assets/fetch.scm').  Running this is only
;; needed to refresh those copies -- they are checked in, because they are what
;; an instance serves -- and it fetches every one of them, from the addresses
;; the stylesheets themselves name.
(define (vendor-assets)
  "Fetch the assets the interface is painted with into `pub/'."
  (time-machine-manifest-shell '("guile -L ./lib -L . resources/assets/fetch.scm")))

;; ====== The vendored Guitar Pro renderer ======

;; The release of alphaTab whose files are kept under `pub/vendor/alphatab'.
;; The files are fetched rather than installed, the way the stylesheet above
;; is, so that the site carries them itself and reaches no CDN at run time.
;; Pinning the release is what keeps the vendored files and the code that
;; drives them in step: alphaTab loads the worker it renders with and the
;; music font it draws with from paths its own release decides.
(define alphatab-version
  "1.8.4")

(define* (alphatab-fetch #:key url destination)
  "Fetch URL into DESTINATION, creating the directory it belongs in first.

The download fails loudly -- `--fail' turns an HTTP error into a non-zero
status -- because a run that quietly left a page's asset missing would be found
by a reader looking at a tab that will not render."
  ($ (list "curl --fail --location --silent --show-error"
           (~ "--output \"~a\"" destination)
           (~ "\"~a\"" url))))

(define (alphatab)
  "Vendor alphaTab, the Guitar Pro renderer, into `pub/vendor/alphatab'.

What is fetched is what the site serves: alphaTab's browser build, which also
holds the worker it renders a score in; Bravura, the music font a tab is drawn
with; and sonivox, the SoundFont a tab is played back with.  Their licences
travel beside them, and the release they came from is written down in the
directory's README, so what is vendored can be explained and re-fetched rather
than being a blob of unknown age."
  (let ((base (~ "https://cdn.jsdelivr.net/npm/@coderline/alphatab@~a/dist"
                 alphatab-version))
        (vendor "pub/vendor/alphatab"))
    (mkdir-p (~ "~a/font" vendor))
    (mkdir-p (~ "~a/soundfont" vendor))
    (alphatab-fetch #:url (~ "~a/alphaTab.min.js" base)
                    #:destination (~ "~a/alphaTab.min.js" vendor))
    (alphatab-fetch #:url (~ "~a/font/Bravura.woff2" base)
                    #:destination (~ "~a/font/Bravura.woff2" vendor))
    (alphatab-fetch #:url (~ "~a/font/Bravura-OFL.txt" base)
                    #:destination (~ "~a/font/Bravura-OFL.txt" vendor))
    (alphatab-fetch #:url (~ "~a/soundfont/sonivox.sf2" base)
                    #:destination (~ "~a/soundfont/sonivox.sf2" vendor))
    (alphatab-fetch #:url (~ "~a/soundfont/LICENSE" base)
                    #:destination (~ "~a/soundfont/LICENSE" vendor))
    (alphatab-fetch #:url (~
                           "https://raw.githubusercontent.com/CoderLine/alphaTab/v~a/LICENSE"
                           alphatab-version)
                    #:destination (~ "~a/LICENSE" vendor))))

(define (import-production-database)
  "Import production env's database to local workspace via SSH/SCP"
  ($ '("scp wolk-jjba:/etc/byggsteg/job-clone/wikimusic/trunk/wikimusic.db* .")))

(define (import-production-env)
  "Import production env's database to local workspace via SSH/SCP"
  ($ '("scp wolk-jjba:/etc/byggsteg/job-clone/wikimusic/trunk/env.scm .")))
