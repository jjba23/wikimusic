;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (maak)
  #:use-module (maak maak)
  #:use-module ((ice-9 rdelim) #:select (read-line))
  ;; The i18n helpers are imported under a prefix because two of the tasks
  ;; below are named `i18n-compile' and `i18n-merge', and a task may not shadow
  ;; the helper it calls.
  #:use-module ((maak i18n) #:prefix i18n:)
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
  (i18n:i18n-compile lang #:dir i18n-dir #:textdomain i18n-textdomain))

(define (i18n-init* lang)
  "Initialize a new translation file from a template (.pot) for a specific language.

Args: lang represents the language code (e.g., en_US, nl_NL, etc.)

Use msginit to generate a .po file from the .pot template for the specified language
The -l option sets the language, and --no-translator means no translator is pre-filled in the .po file
The generated .po file is placed in the LC_MESSAGES directory for the given language"
  (i18n:i18n-init lang #:dir i18n-dir #:textdomain i18n-textdomain
                  #:verbose? #t))

(define (i18n-merge* lang)
  "Merge translation updates from the template (.pot) into an existing .po file.

Args: lang represents the language code (e.g., en_US, nl_NL, etc.)

Use msgmerge to update the specified language's .po file with new translations from the template (.pot)
The -U flag updates the .po file in place
This ensures the .po file stays up-to-date with the latest changes in the template"
  (i18n:i18n-merge lang #:dir i18n-dir #:textdomain i18n-textdomain))

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
  ;; The source globs are words the shell has to expand, so this stays a shell
  ;; line -- with one part per word, so a path with a space in it still reads as
  ;; one word and the quoting around the copyright holders stays as written.
  ($ (append (list "xgettext"
                   (~ "--default-domain=~a" i18n-textdomain)
                   (~ "--output=~a/~a.pot" i18n-dir i18n-textdomain)
                   "--language=Scheme" "--keyword=G_" "--sort-by-file")
             (if update?
                 (list "--join-existing")
                 '())
             (list (~ "--copyright-holder=\"~a\""
                      (string-join copyright-holders ","))
                   (~ "--package-name=~a" i18n-textdomain))
             (i18n-source-globs)
             (list "--from-code" "UTF-8"))
     #:verbose? #t))

;; ====== Maak tasks ======

(define (repl)
  "Development REPL."
  (time-machine-manifest-shell
   (list "guile" "-L" "./lib" "-L" "."
         "-c" "'((@ (ares server) run-nrepl-server))'")))

(define (default)
  "Default task to be run, list available tasks."
  (list-tasks))

;; The key file has to be loaded before the runner forks a worker for each
;; spec: the modules under test import (wikimusic env), and a worker inherits
;; what the parent had loaded.  The server does the same thing from ENTRY, so
;; this is the test run reading the project's keys the way the server does.
(define (test)
  "Run the project's test suite, one spec at a time, from test/veritas."
  (time-machine-manifest-shell
   (list "guile" "--fresh-auto-compile"
         "-L" "./lib" "-L" "./test" "-L" "."
         "-c"
         "'(load \"env.scm\")(begin (setlocale LC_ALL \"C.UTF-8\") (use-modules (veritas runner)) (run-tests))'")))

(define (build-manual)
  "Render the project's manual, which is the README."
  (time-machine-manifest-shell (list "emacs" "-Q" "--batch" "--eval"
                                     (~ "'~s'" emacs-lisp-manual-publish-cmd))
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
  (run (list "find" "." "-maxdepth" "8" "-name" "*.scm" "-type" "f"
             "-exec" "guix" "style" "-f" "{}" ";")
       #:verbose? #t))

(define (hot-reload)
  "Hot-reloading developer's setup."
  (time-machine-manifest-shell (list "watchexec"
                                     "--clear"
                                     "--exts"
                                     (string-join (map symbol->string
                                                       hot-reload-file-types)
                                                  ",")
                                     "--on-busy-update=restart"
                                     "--shell" "bash"
                                     "--watch" "." "--"
                                     "maak" "server")))

(define (hr)
  "Alias to hot-reloading."
  (hot-reload))

(define (dev)
  "Developer's setup."
  (hot-reload))

(define (kill-server)
  "Kill any running HTTP server in the same port."
  ;; Nothing listening is not a failure, so the command is allowed to say so
  ;; instead of the task dying on `fuser''s non-zero exit.
  (run (list "fuser" "-k" (~ "~a/tcp" http-port))
       #:allow-failure? #t)
  (run (list "sleep" "2")))

(define (server)
  "Target to start the wikimusic server with the default configuration."
  (kill-server)
  (time-machine-manifest-shell (list "art" "work")))

(define (production-server)
  "Target to start the wikimusic server with the production configuration."
  (kill-server)
  (time-machine-manifest-shell (list "art" "work"
                                     "-c" "conf/production.conf")))

(define (migrate)
  "Apply the SQL migrations to the database in this directory with mutastructura.

Mutastructura does the applying: it keeps a ledger of what it has run in the
`migrations_history' table of the database, runs only the migrations that are
not in it and records each one with a SHA256 of its file, all inside a single
transaction.  That is what makes this safe to run at any time, and it is also
the way to bring a database made by an earlier deployment up to what the source
in front of it expects.  Mutastructura is the only thing that applies
migrations; no task reads the SQL files and hands them to sqlite3 itself."
  (time-machine-manifest-shell (list "mutastructura"
                                     "--database" "sqlite3"
                                     "--connection" wikimusic-db
                                     "--migrations" migrations-dir)
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
  ;; One word per part, and the pragma keeps the single quotes it needs to
  ;; reach sqlite3 whole: `time-machine-manifest-shell' joins what it is given
  ;; into a shell line, so the quoting is part of the argument.
  (time-machine-manifest-shell (list "sqlite3" wikimusic-db
                                     "'PRAGMA journal_mode=WAL;'"))
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
  (curl-download
   "https://codeberg.org/jjba23/olive-css/raw/branch/trunk/resources/css/wikimusic.olive.min.css"
   #:output "./pub/css/wikimusic.olive.min.css"))

;; The type and the glyphs are fetched rather than written: the three families
;; the interface is set in and the Phosphor set are somebody else's work, and
;; the files a page reads are copies of it kept in `pub/' and served by this
;; instance itself (see `resources/assets/fetch.scm').  Running this is only
;; needed to refresh those copies -- they are checked in, because they are what
;; an instance serves -- and it fetches every one of them, from the addresses
;; the stylesheets themselves name.
(define (vendor-assets)
  "Fetch the assets the interface is painted with into `pub/'."
  (time-machine-manifest-shell (list "guile" "-L" "./lib" "-L" "."
                                     "resources/assets/fetch.scm")))

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

The download fails loudly -- the request carries `--fail', which turns an HTTP
error into a non-zero status -- because a run that quietly left a page's asset
missing would be found by a reader looking at a tab that will not render."
  (curl-download url #:output destination))

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
  ;; The `*' is scp's, naming the database and the `-wal'/`-shm' files beside
  ;; it, and it belongs to the remote side: handed over as one word, no local
  ;; shell tries to expand it first.
  (run (list "scp"
             "wolk-jjba:/etc/byggsteg/job-clone/wikimusic/trunk/wikimusic.db*"
             ".")))

(define (import-production-env)
  "Import production env's database to local workspace via SSH/SCP"
  (run (list "scp"
             "wolk-jjba:/etc/byggsteg/job-clone/wikimusic/trunk/env.scm"
             ".")))

;; ====== Agent skills ======

;; AGENTS.md is generated, never edited by hand.  The section has two halves:
;; the data below, which is this project's, and the task itself, which is not.
;; Another repository copies the whole section and replaces the data - the
;; header, the pinned skills (repository, commit, path, licence) and the
;; practices - and `maak agents' writes its own AGENTS.md.  Regeneration is
;; deterministic: the same pins and the same text produce the same file, byte
;; for byte, and it needs nothing but curl.  The skill URLs assume GitHub, so a
;; skill hosted elsewhere needs a URL of its own.

(define ponytail-commit
  "96608e078b2d5ea607c5c3b8b5a54d1c1fba6846")

(define tdd-commit
  "22f0b463e7a5e579904dd6211a520321035526f7")

;; Name, repository, commit, the path the repository keeps the skill at and the
;; licence.  A skill arrives whole: trimming it means scanning for headings, and
;; such a scan cannot tell a heading from a `##' line inside a code fence.
(define agent-skills
  (list (list "ponytail"
              "DietrichGebert/ponytail"
              ponytail-commit
              "skills/ponytail/SKILL.md"
              "MIT")
        (list "test-driven-development"
              "obra/superpowers"
              tdd-commit
              "skills/test-driven-development/SKILL.md"
              "MIT")))

(define agent-skills-dir
  "reports/agent-skills")

(define agents-header
  "# AGENTS.md

Generated by `maak agents` from the pinned skills and the practices in
`maak.scm`; edit that task, never this file.  The pins and the text are the whole
input, so regenerating gives the same document.  The repository's own rules win
over general advice, and the narrowest rule here wins over the broadest.
")

;; Practices this project keeps.  They are short on purpose: a rule a reader
;; checks in a second is a rule that gets followed.  The pinned skills are the
;; long form of the same habits.
(define agent-practices
  (list
   "## Documentation

- Every user-visible change reaches the documentation: the page that owns the
  feature, the manual page for a flag or an environment variable, and the
  release notes under the unreleased heading.
- Keep the table of contents in step with the headings.  A section with no entry
  is a section nobody finds.
- The guide is Org: one `*` heading per page, `**` for sections, `#+TITLE` and
  `#+EMAIL` at the top, a `CUSTOM_ID` on anything linked from elsewhere, and
  `file:` links between pages.
- Explain why and when, never what: the code already says what.  A docstring's
  first line works as a summary on its own.
- Spell an identifier the way the code spells it - the exact name, not a
  description of it.
- An example must run as written, copied from a real invocation.
- No promises about the future and no changelog in the guide; history lives in
  the release notes.
"
   "## Security

- No secrets in the tree.  Tokens, keys and passwords arrive through the
  environment, and no recipe, workflow or example embeds one.
- Validate at the edge: anything from a file, a report, a path or a subprocess
  is untrusted until it has been checked.
- Never build a shell string out of data.  Tasks pass argument lists, and Guile
  calls `(system \"program\" \"arg\")` or `open-pipe*`, never a command
  assembled with `string-append`.
- Do not `eval` or `read` input you did not write; parse with `(json)` or a
  reader built for the format.
- Escape what leaves the process: a name that came from input is escaped when
  it is written to XML, HTML or a data file.
- Fail closed.  A file that cannot be read is an error, not an empty result.
- Input never chooses the path of a written file; writes stay inside the
  directory reserved for them.
- A dependency is a security decision: it must be needed, MIT compatible and
  pinned.
- Report a vulnerability privately, not in a public issue.
"
   "## Performance

- Measure first.  A before and after belongs in the benchmark, and a speedup
  claimed without a number is not a speedup.
- Prefer not doing the work: cache it, skip it, batch it, or delete the call,
  before making the call faster.
- Then the algorithm, then the data structure (hash table, vector), then the
  micro-optimisation.  In that order, for that reason.
- Guile specifics: keep module resolution and long `assoc` chains out of loops,
  use `#:declarative?` modules and compiled `.go` files at startup, and reach
  for `statprof` instead of guessing where the time goes.
- A shortcut that buys speed costs clarity; it gets a measurement and a
  `shortcut:` comment saying what it costs and when to revisit it.
- Coverage instrumentation is slow by design: iterate without it, and measure
  before finishing.
"
   "## Architecture decisions

- A decision that is expensive to reverse gets a short record: the context, the
  decision, the consequences, and the alternatives that lost.  A small decision
  belongs in the commit body instead.
- Two paragraphs beat a design document; record the choice while it is still a
  choice, not after it has become a fact.
- An accepted record is not rewritten.  Supersede it with a new one and link the
  two directions.
- The record lives next to its subject: the documentation for anything a user
  would notice, the release notes for the release-level result.
- Changes to the public API, a file format, the pipeline or the licence get this
  treatment at a minimum in the commit body.
"
   "## Semantic versioning

- The project follows SemVer 2.0.0 for its public API: the exported functions,
  the CLI flags and environment variables, and the shape of its file formats.
- A breaking change bumps MAJOR, a new feature MINOR, a fix PATCH.  A new export
  is MINOR; removing or changing one is MAJOR.
- One version string, named everywhere it appears: the source, the build
  recipes, the manual page and the packaging.
- A release is a dated release-notes section, an annotated `vX.Y.Z` tag on the
  release commit, and a packaging checksum updated afterwards from the published
  archive.
"
   "## Conventional commits

- `type(scope): summary`, imperative, lower case, no full stop, about seventy
  characters.
- Types in use: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `build`, `ci`,
  `chore`.  A `!` after the type or a `BREAKING CHANGE:` footer marks a MAJOR
  change, and says what breaks.
- The subject says what changed.  The body says why, and what was rejected.
- One logical change per commit: a refactor and a fix travel apart, so either
  can be reverted alone.
- Run the full validation task before committing, and never commit a red suite
  without saying so in the message.
- Reference the issue in the footer - `Closes #12` - not in the subject.
"
   "## Functional programming and immutability

- Pure functions in the core, effects at the edges.  Whatever touches the file
  system or the clock sits at the edge; the core does not.
- Prefer `let` and new values to `set!`.  Build results with `map`, `filter`,
  `fold` and named `let`, not with index loops that push into a list.
- A record is a value: construct a new one instead of mutating a shared one, and
  pass configuration as arguments or parameters rather than as globals.
- Handle an exception at the boundary: catch it there, turn it into a result
  record, and let the caller decide what it means.
- A function that both computes and prints is two functions.
- Temporary effects - a changed directory, a bound environment variable - go
  through `dynamic-wind`.
- Prefer the expression style: `if` and `cond` that return a value, not a branch
  that assigns one.
"
   "## Do not reinvent the wheel

- Guile's standard library first: `(ice-9 ...)` for the runtime, `(srfi srfi-1)`
  for lists, `(srfi srfi-9)` for records, `(srfi srfi-13)` for strings, `(json)`
  for JSON.  The project already depends on all of them.
- Then this codebase: read the existing modules before writing a helper, and use
  the one that is nearly right instead of adding a second one.
- A new dependency needs a reason the standard library cannot meet, a licence
  the project can carry, and a paragraph in the commit body.
- Prefer deleting a special case to writing code that handles it.
- The best diff removes lines and keeps the behaviour; the second best is a
  small diff that is obvious a year later.
"))

(define (slurp path)
  "Return the whole of @var{path} as a string."
  (call-with-input-file path
    (lambda (port)
      (let loop ((lines '())
                 (line (read-line port)))
        (if (eof-object? line)
            (string-concatenate-reverse lines)
            (loop (cons (string-append line "\n") lines)
                  (read-line port)))))))

(define (fetch-skill name repository commit path)
  "Download one skill pinned at @var{commit}, into the reports tree.

  Returns the skill's text."
  (let ((target (~ "~a/~a.md" agent-skills-dir name))
        (url (~ "https://raw.githubusercontent.com/~a/~a/~a"
                repository commit path)))
    (run (list "curl" "--fail" "--silent" "--show-error" "--location"
               "--output" target url)
         #:verbose? #t)
    (slurp target)))

(define (agents)
  "Regenerate AGENTS.md from the pinned skills and the practices."
  (run (list "mkdir" "-p" agent-skills-dir))
  ;; Every download happens before the file is opened, so a fetch that fails
  ;; leaves the previous AGENTS.md in place rather than a half-written one.
  (let ((skills (map (lambda (skill)
                       (append skill
                               (list (fetch-skill (list-ref skill 0)
                                                  (list-ref skill 1)
                                                  (list-ref skill 2)
                                                  (list-ref skill 3)))))
                     agent-skills)))
    (call-with-output-file "AGENTS.md"
      (lambda (port)
        (display agents-header port)
        (for-each (lambda (skill)
                    (format port
                            "~%## ~a~%~%`~a` at `~a`, `~a`, ~a licensed.~%~%"
                            (list-ref skill 0)
                            (list-ref skill 1)
                            (list-ref skill 2)
                            (list-ref skill 3)
                            (list-ref skill 4))
                    (display (list-ref skill 5) port))
                  skills)
        (for-each (lambda (practice)
                    (newline port)
                    (display practice port))
                  agent-practices)))))
