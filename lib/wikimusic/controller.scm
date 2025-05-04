;;; wikimusic - the free music knowledge encyclopaedia

;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;; wikimusic is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; wikimusic is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with wikimusic.  If not, see <https://www.gnu.org/licenses/>.

(define-module (wikimusic controller)
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
  #:use-module (hygguile abstraction)
  #:use-module (hygguile components input)
  #:use-module (hygguile components button)
  #:use-module (srfi srfi-19)
  #:use-module (ice-9 textual-ports)
  #:use-module (artanis route)
  #:use-module (artanis db)
  #:use-module (artanis ssql)
  #:use-module (artanis artanis)
  #:export (delete-artwork))

(define* (delete-artwork #:key rc
                         conn
                         entity
                         delete-condition
                         redirect-url)
  (DB-query conn
            (->sql delete from
                   (string->symbol (format #f "~a_artworks" entity))
                   delete-condition))

  (redirect-to rc
               (string->uri redirect-url)
               #:status 302))
