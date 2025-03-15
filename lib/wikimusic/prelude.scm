;;; wikimusic - the free music knowledge encyclopaedia

;; Copyright © 2025 "Josep Bigorra" known as "jjba23" <jjbigorra@gmail.com>

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

(define-module (wikimusic prelude)
  #:use-module (ice-9 popen)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 time)
  #:use-module (ice-9 format)
  #:use-module (ice-9 string-fun)
  #:use-module (ice-9 iconv)
  #:use-module (ice-9 hash-table)
  #:use-module (ice-9 threads)
  #:use-module (srfi srfi-19)
  #:use-module (ice-9 textual-ports))

(begin
  (define* (build-asset-library assets)
    (display "\nBuilding static asset cache...\n")
    (let ((lib '()))
      (for-each (lambda (f)
                  (let* ((file-contents (get-string-all (open-input-file f)))
                         (min-contents (cond
                                        ((string-suffix? ".css" f)
                                         (string-replace-substring
                                          file-contents "\n" ""))
                                        (else file-contents))))
                    (set! lib
                          (assoc-set! lib f min-contents)))) assets) lib))
  (export build-asset-library))

(define-public asset-library
  (build-asset-library '("pub/css/fonts.css" "pub/css/phosphor.css"
                         "pub/js/tailwind.js" "pub/js/tailwind.config.js")))
