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

(import (artanis mvc model))

(create-artanis-model songs
                      (:deps)
                      (identifier char-field
                                  (#:primary-key #:maxlen 36))
                      (display_name char-field (#:maxlen 256))
                      (music_key char-field (#:maxlen 64))
                      (music_tuning char-field (#:maxlen 256))
                      (music_creation_date char-field (#:maxlen 256))
                      (album_name char-field (#:maxlen 512))
                      (album_info_link char-field (#:maxlen 512))
                      (created_by char-field (#:not-null #:maxlen 36))
                      (visibility_status smallint (#:not-null))
                      (approved_by char-field (#:maxlen 36))
                      (views bigint (#:not-null))
                      (description char-field (#:maxlen 2048))
                      (created_at date-field
                                  (#:not-null))
                      (last_edited_at date-field))

