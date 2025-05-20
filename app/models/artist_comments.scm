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

(import (artanis mvc model))

(create-artanis-model artist_comments
                      (:deps)
                      (identifier char-field
                                  (#:primary-key #:maxlen 36))
                      (parent_identifier char-field
                                         (#:maxlen 36))
                      (artist_identifier char-field
                                         (#:not-null #:maxlen 36))
                      (visibility_status smallint
                                         (#:not-null))
                      (approved_by char-field
                                   (#:maxlen 36))
                      (created_by char-field
                                  (#:not-null #:maxlen 36))
                      (contents char-field
                                (#:not-null #:maxlen 4096))
                      (created_at date-field
                                  (#:not-null))
                      (last_edited_at date-field))

