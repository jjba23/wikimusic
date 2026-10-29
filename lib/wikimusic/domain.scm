;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (wikimusic domain)
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
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (ice-9 textual-ports)
  #:use-module (artanis route))

(define-public (relevant-entities entity related-entities x)
  "Filters a list of related entities based on a matching identifier.

  ENTITY: A symbol representing the type of the primary entity ('artist, 'genre, or 'song).
  RELATED-ENTITIES: A list of association lists, where each association list
                    represents a related entity and contains key-value pairs.
  X: An association list representing the primary entity, containing an
     'identifier' key.

  Returns a new list containing only the related entities whose identifier
  matches the identifier of the primary entity (X), based on the ENTITY type.
  For 'artist', it compares against the 'artist_identifier' in related entities.
  For 'genre', it compares against the 'genre_identifier'.
  For 'song' (or any other ENTITY), it compares against the 'song_identifier'."
  (let* ((k (cond
              ((eq? entity
                    'artist)
               'artist-identifier)
              ((eq? entity
                    'genre)
               'genre-identifier)
              ((eq? entity
                    'song)
               'song-identifier)
              (else 'song-identifier))))
    (filter (lambda (related-entity)
              (equal? (assq-ref x
                                'identifier)
                      (assq-ref related-entity k))) related-entities)))

(define-public (entity-sort-from-query user-sort)
  "Translates a user-provided sort query string into a database-friendly sort specification.

  USER-SORT: A string representing the user's sorting preference.
             Possible values include:
               - created-at-desc
               - created-at-asc
               - last-edited-at-desc
               - last-edited-at-asc
               - display-name-desc
               - display-name-asc
               - views-desc
               - views-asc
             Any other string will default to sorting by 'last_edited_at' descending.

  Returns it as the clause list kracht's `sql-select' takes: a list holding one
  `(column direction)' clause, where the column is a hyphenated Scheme symbol
  (`display-name', which kracht spells display_name in SQL) and the direction is
  `asc' or `desc'.  The repository hands the result straight to `sql-select',
  so no query string is ever built out of it."
  (cond
    ((equal? "created-at-desc" user-sort)
     '((created-at desc)))
    ((equal? "created-at-asc" user-sort)
     '((created-at asc)))
    ((equal? "last-edited-at-desc" user-sort)
     '((last-edited-at desc)))
    ((equal? "last-edited-at-asc" user-sort)
     '((last-edited-at asc)))
    ((equal? "display-name-desc" user-sort)
     '((display-name desc)))
    ((equal? "display-name-asc" user-sort)
     '((display-name asc)))
    ((equal? "views-desc" user-sort)
     '((views desc)))
    ((equal? "views-asc" user-sort)
     '((views asc)))
    (else '((last-edited-at desc)))))
