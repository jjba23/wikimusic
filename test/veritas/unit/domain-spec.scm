;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;;
;;; The two rules (wikimusic domain) holds that decide something about a
;;; request without touching a database: which contribution of a related table
;;; belongs to the entry being shown, and what a reader's sort control means as
;;; an ORDER BY clause.
;;;
;;; The second is the one with a security edge.  A sort arrives as a query
;;; string, so a reader writes it; the rule maps it onto a fixed list of clauses
;;; and answers with a default for anything else, which is what keeps the query
;;; string out of the statement.  The tests below therefore state that an
;;; unknown sort is not passed through, including an unknown sort that is
;;; spelled like SQL.

(define-module (veritas unit domain-spec)
  #:use-module (veritas veritas)
  #:use-module (ice-9 format)
  #:use-module (srfi srfi-1)
  #:use-module (wikimusic domain)
  #:export (spec))

(define artist
  '((identifier . "artist-1")))

(define song
  '((identifier . "song-1")))

(define genre
  '((identifier . "genre-1")))

(define related
  '((artist-identifier . "artist-1") (genre-identifier . "genre-1")
    (song-identifier . "song-1")
    (display-name . "the one that matches")))

(define unrelated
  '((artist-identifier . "artist-2") (genre-identifier . "genre-2")
    (song-identifier . "song-2")
    (display-name . "the one that does not")))

(define relation-suite
  (suite "Which related rows belong to an entry"
         (test "a song is matched on the song's identifier"
               (assert-equal #:name "the row naming this song"
                             #:expect (list related)
                             #:got (relevant-entities 'song
                                                      (list related unrelated)
                                                      song)))

         (test "an artist is matched on the artist's identifier"
               (assert-equal #:name "the row naming this artist"
                             #:expect (list related)
                             #:got (relevant-entities 'artist
                                                      (list related unrelated)
                                                      artist)))

         (test "a genre is matched on the genre's identifier"
               (assert-equal #:name "the row naming this genre"
                             #:expect (list related)
                             #:got (relevant-entities 'genre
                                                      (list related unrelated)
                                                      genre)))

         (test "the identifier compared against is the entry's own"
               ;; Which key of a related row is read is the whole of the rule,
               ;; and an entry's rows are exactly the rows naming it: a row
               ;; that names some *other* entry is nobody's here.
               (assert-equal #:name
                             "a row naming a song is not the artist's row"
                             #:expect '()
                             #:got (relevant-entities 'artist
                                                      (list '((song-identifier . "song-1")))
                                                      artist))
               (assert-equal #:name "nor is another entry's row this one's"
                             #:expect '()
                             #:got (relevant-entities 'song
                                                      (list unrelated) song)))))

(define sort-suite
  (suite "What a sort control means"
         (test "every sort the pages offer maps onto its own clause"
               (assert-equal #:name "newest first"
                             #:expect '((created-at desc))
                             #:got (entity-sort-from-query "created-at-desc"))
               (assert-equal #:name "oldest first"
                             #:expect '((created-at asc))
                             #:got (entity-sort-from-query "created-at-asc"))
               (assert-equal #:name "edited most recently"
                             #:expect '((last-edited-at desc))
                             #:got (entity-sort-from-query
                                    "last-edited-at-desc"))
               (assert-equal #:name "edited longest ago"
                             #:expect '((last-edited-at asc))
                             #:got (entity-sort-from-query
                                    "last-edited-at-asc"))
               (assert-equal #:name "by name, descending"
                             #:expect '((display-name desc))
                             #:got (entity-sort-from-query "display-name-desc"))
               (assert-equal #:name "by name, ascending"
                             #:expect '((display-name asc))
                             #:got (entity-sort-from-query "display-name-asc"))
               (assert-equal #:name "most viewed first"
                             #:expect '((views desc))
                             #:got (entity-sort-from-query "views-desc"))
               (assert-equal #:name "least viewed first"
                             #:expect '((views asc))
                             #:got (entity-sort-from-query "views-asc")))

         (test "something the page does not offer sorts the default way"
               (assert-equal #:name "an unknown sort falls back"
                             #:expect '((last-edited-at desc))
                             #:got (entity-sort-from-query "whatever"))
               (assert-equal #:name "so does an empty one"
                             #:expect '((last-edited-at desc))
                             #:got (entity-sort-from-query "")))

         (test "a sort that is spelled like SQL is not passed through"
               ;; The rule answers with one of its own clauses whatever the
               ;; string says, so the query string can never reach the
               ;; statement: what a reader types is only ever looked up.
               (for-each (lambda (hostile)
                           (let ((clause (entity-sort-from-query hostile)))
                             (assert-equal #:name (format #f
                                                   "~s sorts by default"
                                                   hostile)
                                           #:expect '((last-edited-at desc))
                                           #:got clause)))
                         '("views desc; DROP TABLE songs"
                           "display-name asc --" "(drop-table)"
                           "views\") desc")))

         (test "the clause names a column and a direction, and nothing else"
               (let ((clause (car (entity-sort-from-query "views-desc"))))
                 (assert-equal #:name "the column is a symbol"
                               #:expect #t
                               #:got (symbol? (car clause)))
                 (assert-equal #:name "the direction is one of the two words"
                               #:expect #t
                               #:got (and (memq (cadr clause)
                                                '(asc desc)) #t))
                 (assert-equal #:name "and a clause is all there is to it"
                               #:expect 2
                               #:got (length clause))))))

(define (spec)
  (veritas-run relation-suite sort-suite))
