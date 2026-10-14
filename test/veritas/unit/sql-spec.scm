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

;;; Commentary:
;;;
;;; Every statement wikimusic sends to SQLite is built by (kracht sql) and
;;; rendered by (wikimusic sqlite util).  The builders themselves are kracht's
;;; and are tested there; what is tested here is wikimusic's half of the
;;; bargain -- the rendering of a statement into the one string guile-dbi can
;;; run, and the three shapers the repositories hand to it.
;;;
;;; That rendering is the security-critical step, so the tests below are
;;; mostly about a value that means to escape its quotes: the driver has no
;;; bind step (see the commentary in (wikimusic sqlite util)), so this is the
;;; one place a reader-supplied string becomes statement text.

(define-module (veritas unit sql-spec)
  #:use-module (veritas veritas)
  #:use-module (srfi srfi-13)
  #:use-module (kracht sql)
  #:use-module (wikimusic sqlite util)
  #:export (spec))

(define (raises? thunk)
  "Return #t when THUNK raises, whatever the key and arguments are."
  (catch #t
         (lambda ()
           (thunk) #f)
         (lambda (key . args)
           #t)))

(define (count-char char string)
  "Return how many times CHAR appears in STRING."
  (let loop
    ((chars (string->list string))
     (n 0))
    (cond
      ((null? chars)
       n)
      ((char=? (car chars) char)
       (loop (cdr chars)
             (+ n 1)))
      (else (loop (cdr chars) n)))))

(define rendering-suite
  (suite "Rendering a statement for the driver"
         (test "a statement string is passed through untouched"
               (assert-equal #:name "a plain string"
                             #:expect "SELECT 1"
                             #:got (sql-query->dbi-sql "SELECT 1"))
               (assert-equal #:name
                             "a statement with a quoted value of its own"
                             #:expect "SELECT 'x'"
                             #:got (sql-query->dbi-sql "SELECT 'x'")))

         (test "a value is rendered as a literal, and its quotes are doubled"
               (assert-equal #:name "a string is quoted"
                #:expect
                "SELECT * FROM \"songs\" WHERE \"display_name\" = 'x'"
                #:got (sql-query->dbi-sql (sql-select 'songs
                                                      #:where '((display-name . "x")))))
               (assert-equal #:name "an apostrophe inside a value is doubled"
                #:expect
                "SELECT * FROM \"songs\" WHERE \"display_name\" = 'O''Brien'"
                #:got (sql-query->dbi-sql (sql-select 'songs
                                                      #:where '((display-name . "O'Brien")))))
               (assert-equal #:name
                "a value that means to end the string cannot"
                #:expect
                "SELECT * FROM \"songs\" WHERE \"display_name\" = '''; DROP TABLE users; --'"
                #:got (sql-query->dbi-sql (sql-select 'songs
                                                      #:where '((display-name . "'; DROP TABLE users; --")))))
               (assert-equal #:name "so every quote it carries is paired"
                             #:expect 4
                             #:got (count-char #\'
                                               (sql-query->dbi-sql (sql-select 'songs
                                                                    #:where '((display-name . "'; DROP TABLE users; --")))))))

         (test "a number and a boolean are not quoted"
               (assert-equal #:name "a number is written as itself"
                             #:expect
                             "SELECT * FROM \"songs\" WHERE \"views\" = 3"
                             #:got (sql-query->dbi-sql (sql-select 'songs
                                                                   #:where '((views . 3)))))
               (assert-equal #:name "a true value is written as 1"
                             #:expect
                             "SELECT * FROM \"songs\" WHERE \"views\" = 1"
                             #:got (sql-query->dbi-sql (sql-select 'songs
                                                                   #:where '((views . #t))))))

         (test "column names are quoted as identifiers"
               (assert-equal #:name
                "a hyphenated symbol is spelled underscore"
                #:expect
                "UPDATE \"users\" SET \"password\" = 'argon2id$x' WHERE \"identifier\" = 'id-1'"
                #:got (sql-query->dbi-sql (sql-update 'users
                                                      '((password . "argon2id$x"))
                                                      #:where '((identifier . "id-1"))))))))

(define accounting-suite
  (suite "Accounting for placeholders"
         (test "the number of values has to match the number of placeholders"
               (assert-true (raises? (lambda ()
                                       (sql-query->dbi-sql (make-sql-query
                                                            "SELECT ? ?"
                                                            '(1)))))
                            #:name
                            "a value too few is an error rather than a guess")
               (assert-true (raises? (lambda ()
                                       (sql-query->dbi-sql (make-sql-query
                                                            "SELECT ?"
                                                            '(1 2)))))
                            #:name "a value too many is an error too")
               (assert-true (raises? (lambda ()
                                       (sql-query->dbi-sql (make-sql-query
                                                            "SELECT * WHERE a = ?"
                                                            '()))))
                #:name
                "a placeholder with no value is refused, not left behind"))

         (test "a rendered statement holds no placeholder any more"
               (let ((rendered (sql-query->dbi-sql (sql-select 'songs
                                                               #:where '((display-name . "x"))
                                                               #:limit 1))))
                 (assert-equal #:name
                               "no question mark survives the substitution"
                               #:expect #f
                               #:got (string-index rendered #\?))
                 (assert-true (and (string-contains rendered "LIMIT 1") #t)
                              #:name "and the rest of the statement is intact")))

         (test "something that is neither a query nor a string is refused"
               (assert-true (raises? (lambda ()
                                       (sql-query->dbi-sql 42)))
                            #:name "a number is not a statement")
               (assert-true (raises? (lambda ()
                                       (sql-query->dbi-sql 'songs)))
                            #:name "nor is a symbol"))))

(define order-by-suite
  (suite "Sorting"
         (test "both spellings of a sort are accepted"
               (assert-equal #:name "one clause, not yet wrapped"
                             #:expect '((display-name asc))
                             #:got (order-by-clauses '(display-name asc)))
               (assert-equal #:name "a clause list is left as it is"
                             #:expect '((views desc)
                                        (display-name asc))
                             #:got (order-by-clauses '((views desc)
                                                       (display-name asc))))
               (assert-equal #:name "and nothing sorts by nothing"
                             #:expect '()
                             #:got (order-by-clauses '())))

         (test "a clause renders its column and its direction"
               (assert-equal #:name "two clauses, in order"
                             #:expect "\"views\" DESC, \"display_name\" ASC"
                             #:got (sql-order-by-sql '((views desc)
                                                       (display-name asc))))
               (assert-equal #:name "a column with no direction renders bare"
                             #:expect "\"display_name\""
                             #:got (sql-order-by-sql '(display-name)))
               (assert-equal #:name
                             "and a hyphen becomes an underscore there too"
                             #:expect "\"last_edited_at\" DESC"
                             #:got (sql-order-by-sql '((last-edited-at desc)))))

         (test "a direction that is not a direction is an error"
               (assert-true (raises? (lambda ()
                                       (sql-order-by-sql '((views sideways)))))
                            #:name
                            "so an unknown word cannot reach the statement"))))

(define row-suite
  (suite "Shaping a row"
         (test "only the named columns survive, in the named order"
               (assert-equal #:name "the columns decide, not the attributes"
                             #:expect '((views . 2) (display-name . "x"))
                             #:got (attrs->row '((display-name . "x")
                                                 (extra . "y")
                                                 (views . 2))
                                               '(views display-name))))

         (test
          "an attribute for an unlisted column cannot reach the statement"
          (assert-equal #:name "a key wikimusic never names is dropped"
                        #:expect '((display-name . "x"))
                        #:got (attrs->row '((display-name . "x")
                                            (permissions . "(all)"))
                                          '(display-name))))

         (test "a row holding none of the columns is an error"
               (assert-true (raises? (lambda ()
                                       (attrs->row '((extra . "y"))
                                                   '(views))))
                            #:name "an insert with no columns is refused"))
         (test "a column the attributes do not carry is simply left out"
               (assert-equal #:name "so the table's own default can stand"
                             #:expect '((display-name . "x"))
                             #:got (attrs->row '((display-name . "x"))
                                               '(views display-name))))))

(define in-suite
  (suite "Matching a set of identifiers"
         (test "an IN clause binds one value per identifier, in order"
               (assert-equal #:name "two identifiers"
                #:expect
                "SELECT * FROM \"songs\" WHERE \"identifier\" IN ('a', 'b')"
                #:got (sql-query->dbi-sql (sql-select 'songs
                                                      #:where '((identifier in
                                                                 ("a" "b")))))))

         (test "an empty set matches nothing rather than everything"
               ;; `IN ()' cannot be written, so kracht collapses it.  A
               ;; repository that asks about no identifiers at all -- a song
               ;; with no artists, say -- must answer with no rows, not with
               ;; the whole table.
               (assert-equal #:name "IN () becomes a false predicate"
                             #:expect "SELECT * FROM \"songs\" WHERE 1 = 0"
                             #:got (sql-query->dbi-sql (sql-select 'songs
                                                                   #:where '((identifier
                                                                              in
                                                                              ()))))))

         (test "and a NOT IN over an empty set matches everything"
               (assert-equal #:name "NOT IN () becomes a true predicate"
                             #:expect "SELECT * FROM \"songs\" WHERE 1 = 1"
                             #:got (sql-query->dbi-sql (sql-select 'songs
                                                                   #:where '((identifier
                                                                              not-in
                                                                              ()))))))))

(define like-suite
  (suite "Matching a term"
         (test "a LIKE condition renders as LIKE, with its term bound"
               (assert-equal #:name "a wildcard term"
                #:expect
                "SELECT * FROM \"songs\" WHERE \"display_name\" LIKE '%x%'"
                #:got (sql-query->dbi-sql (sql-select 'songs
                                                      #:where '((display-name
                                                                 like "%x%"))))))

         (test "the search statement a builder cannot write is still kracht's"
          ;; kracht joins conditions with `AND' only, so a search asking
          ;; about either of two columns is spelled with
          ;; `sql-parameterize' -- kracht's own escape hatch.  What is
          ;; pinned here is that the term is bound and escaped, not
          ;; spliced: the driver has no bind step, so this is the one
          ;; place a reader's string becomes statement text.
          (let ((rendered (sql-query->dbi-sql (sql-parameterize
                                               "SELECT display_name FROM songs WHERE (display_name LIKE ? OR description LIKE ?) ORDER BY display_name DESC LIMIT ? OFFSET ?"
                                               (list "%O'Brien%" "%O'Brien%"
                                                     10 0)))))
            (assert-true (and (string-contains rendered "'%O''Brien%'") #t)
                         #:name "the apostrophe in the term is doubled")
            (assert-equal #:name "no placeholder survives the substitution"
                          #:expect #f
                          #:got (string-index rendered #\?))
            (assert-true (and (string-contains rendered "LIMIT 10 OFFSET 0")
                              #t)
                         #:name "and the paging is written as numbers")))))

(define (spec)
  (veritas-run rendering-suite
               accounting-suite
               order-by-suite
               row-suite
               in-suite
               like-suite))
