;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;;
;;; Every statement wikimusic sends to SQLite is built by (kracht sql) and
;;; handed to guile-dbi through the two runners below.  Kracht's builders
;;; return a <sql-query>: the statement text with `?' placeholders, plus the
;;; values to bind.  Wikimusic never writes a statement by hand any more, so
;;; no value is ever spliced into SQL text and no column name is ever spelled
;;; out twice.
;;;
;;; One wrinkle is worth stating plainly, because it shapes this file.
;;; guile-dbi 2.1.8 -- the driver Artanis' `(artanis db)' wraps -- has no bind
;;; step: `dbi-query' takes the statement and nothing else, and the SQLite DBD
;;; below it only ever calls sqlite3_prepare/step.  Real parameter binding is
;;; therefore not reachable from here, however the query was built.
;;;
;;; `sql-query->dbi-sql' closes that gap: it substitutes the bound values back
;;; into the statement, each one rendered by kracht's `value->sql-literal',
;;; which doubles every single quote.  That is strictly safer than the
;;; hand-written `format' calls it replaces, which quoted values without
;;; escaping them at all -- a search for `O'Brien' produced a syntax error,
;;; and a crafted one produced SQL.  The moment the driver grows a bind step,
;;; only this one function has to change.

(define-module (wikimusic sqlite util)
  #:declarative? #t
  #:use-module (ice-9 format)
  #:use-module (ice-9 string-fun)
  #:use-module (kracht prelude)
  #:use-module (kracht sql)
  #:use-module (artanis db)
  #:export (sql-query->dbi-sql order-by-clauses
                               sql-order-by-sql
                               attrs->row
                               sql-log?
                               log-sql
                               db-read
                               db-write
                               sql-rows
                               sql-execute!))

;;; ====== Logging ======
;;;
;;; kracht used to carry a logger and no longer does, so the statements are
;;; logged by the one module that runs them.  Set WIKIMUSIC_SQL_LOG to any
;;; value to see every statement wikimusic executes; leave it unset and the
;;; runner stays quiet.

(define (sql-log?)
  "Return #t when WIKIMUSIC_SQL_LOG asks for the executed statements to be
printed to the current error port."
  (let ((value (getenv "WIKIMUSIC_SQL_LOG")))
    (and value
         (not (string-null? value)))))

(define (log-sql name query)
  "Print QUERY, labelled NAME, when SQL logging is enabled."
  (when (sql-log?)
    (format (current-error-port) "[wikimusic sql] ~a~%~t~a~%" name query)))

(define (require-sql-query who q)
  "Return Q unchanged when it is a <sql-query> or a statement string, and
raise an error naming WHO otherwise."
  (unless (or (string? q)
              (sql-query? q))
    (error (format #f "~a: expected a kracht SQL query or a statement string"
                   who) q)) q)

(define (sql-query->dbi-sql q)
  "Render Q into the single statement string guile-dbi can run.

Q is a <sql-query> -- as returned by `sql-select', `sql-insert', `sql-update',
`sql-delete', `sql-where-fragment' and friends -- or an already-complete
statement string, which is passed through untouched.

The values Q carries are substituted, left to right, for the `?' placeholders
its statement text holds, each rendered by `value->sql-literal', which quotes
strings and doubles their single quotes.  A count mismatch is an error rather
than a quietly wrong statement, which also means a template holding a literal
`?' is refused: kracht's `sql-parameterize' makes the same promise."
  (require-sql-query "sql-query->dbi-sql" q)
  (if (string? q) q
      (let loop
        ((chars (string->list (sql-query-sql q)))
         (params (sql-query-params q))
         (out '()))
        (cond
          ((null? chars)
           (when (pair? params)
             (error "sql-query->dbi-sql: more bound values than placeholders"
                    q))
           (list->string (reverse out)))
          ((char=? (car chars) #\?)
           (when (null? params)
             (error "sql-query->dbi-sql: fewer bound values than placeholders"
              q))
           (loop (cdr chars)
                 (cdr params)
                 (append (reverse (string->list (value->sql-literal (car
                                                                     params))))
                         out)))
          (else (loop (cdr chars) params
                      (cons (car chars) out)))))))

(define (order-by-clauses order-by)
  "Return ORDER-BY as the list of clause lists `sql-select' expects.

The page controllers keep a sort in the shape `entity-sort-from-query' gives
back -- one `(column direction)' list -- while a repository may want several
clauses, so both spellings are accepted:

  (order-by-clauses '(display-name asc))    ;=> ((display-name asc))
  (order-by-clauses '((views desc) (display-name asc)))
                                             ;=> ((views desc) (display-name asc))
  (order-by-clauses '())                    ;=> ()"
  (cond
    ((null? order-by)
     '())
    ((and (pair? (car order-by))
          (not (null? (car order-by))))
     order-by)
    (else (list order-by))))

(define (sql-order-by-sql clauses)
  "Render CLAUSES -- the clause list `sql-select' takes, as returned by
`order-by-clauses' -- as an `ORDER BY' fragment, without the keyword.

`sql-select' spells this itself, but kracht does not export that renderer, and
a search has to state its own statement to ask for `name LIKE ? OR summary
LIKE ?' at all: kracht joins conditions with AND and nothing else.  Every
clause here comes from `entity-sort-from-query', which maps one query string
onto a fixed list, so only columns wikimusic itself names can reach it.

Raise an error on a direction that is none of `asc', `desc' or absent."
  (string-join (map (lambda (clause)
                      (let ((column (quote-sql-identifier (symbol->sql-column (car
                                                                               clause))))
                            (direction (and (pair? (cdr clause))
                                            (cadr clause))))
                        (case direction
                          ((#f)
                           column)
                          ((asc asc!)
                           (string-append column " ASC"))
                          ((desc desc!)
                           (string-append column " DESC"))
                          (else (error
                                 "sql-order-by-sql: unknown ORDER BY direction"
                                 direction)))))
                    (order-by-clauses clauses)) ", "))

(define (attrs->row attrs columns)
  "Return ATTRS as the row `sql-insert' takes, keeping only COLUMNS and
following their order.

A caller may hand over more than the table holds -- a form body, say -- so the
columns wikimusic knows about decide what is written, and a key it never
mentions cannot become part of a statement.  A column ATTRS does not carry is
left to the table's own default, and ATTRS holding nothing at all is an error
rather than an empty insert."
  (let ((row (filter-map (lambda (column)
                           (assq column attrs)) columns)))
    (when (null? row)
      (error "attrs->row: none of the given columns is present" attrs)) row))

;;; ====== Running statements ======

(define (db-read conn)
  "Return a procedure of NAME and QUERY that runs QUERY as a read against CONN
and returns its rows as a list of association lists whose keys are Scheme
symbols."
  (lambda (name query)
    (let ((sql (sql-query->dbi-sql query)))
      (log-sql name sql)
      (let ((rows (map sql-row->scheme-alist
                       (DB-get-all-rows (DB-query conn sql)))))
        (log-sql (format #f "~a (rows)" name)
                 (format #f "~a rows"
                         (length rows))) rows))))

(define (db-write conn)
  "Return a procedure of NAME and QUERY that runs QUERY as a write against CONN.
A statement SQLite refuses raises Artanis' 500 error, as it should."
  (lambda (name query)
    (let ((sql (sql-query->dbi-sql query)))
      (log-sql name sql)
      (DB-query conn sql))))

;;; The two runners above are curried on the connection, because a repository
;;; holds one connection for its lifetime.  A controller has no repository to
;;; hold it, so these two take the request context instead, which is what the
;;; controllers below them already work with.

(define* (sql-rows rc query
                   #:key (name "sql-rows"))
  "Run QUERY as a read in request context RC and return its rows."
  ((db-read (DB-open rc))
   name query))

(define* (sql-execute! rc query
                       #:key (name "sql-execute!"))
  "Run QUERY as a write in request context RC."
  ((db-write (DB-open rc))
   name query))
