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
  "Filters a list of related entities based on a matching identifier.\n\n  ENTITY: A symbol representing the type of the primary entity ('artist, 'genre, or 'song).\n  RELATED-ENTITIES: A list of association lists, where each association list\n                    represents a related entity and contains key-value pairs.\n  X: An association list representing the primary entity, containing an\n     'identifier' key.\n\n  Returns a new list containing only the related entities whose identifier\n  matches the identifier of the primary entity (X), based on the ENTITY type.\n  For 'artist', it compares against the 'artist_identifier' in related entities.\n  For 'genre', it compares against the 'genre_identifier'.\n  For 'song' (or any other ENTITY), it compares against the 'song_identifier'."
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
  "Translates a user-provided sort query string into a database-friendly sort specification.\n\n  USER-SORT: A string representing the user's sorting preference.\n             Possible values include:\n               - created-at-desc\n               - created-at-asc\n               - last-edited-at-desc\n               - last-edited-at-asc\n               - display-name-desc\n               - display-name-asc\n               - views-desc\n               - views-asc\n             Any other string will default to sorting by 'last_edited_at' descending.\n\n  Returns a list containing two elements: the field to sort by (a symbol)\n  and the sort order (the symbol 'asc' for ascending or 'desc' for descending)."
  (cond
    ((equal? "created-at-desc" user-sort)
     '(created_at desc))
    ((equal? "created-at-asc" user-sort)
     '(created_at asc))
    ((equal? "last-edited-at-desc" user-sort)
     '(last_edited_at desc))
    ((equal? "last-edited-at-asc" user-sort)
     '(last_edited_at asc))
    ((equal? "display-name-desc" user-sort)
     '(display_name desc))
    ((equal? "display-name-asc" user-sort)
     '(display_name asc))
    ((equal? "views-desc" user-sort)
     '(views desc))
    ((equal? "views-asc" user-sort)
     '(views asc))
    (else '(last_edited_at desc))))
