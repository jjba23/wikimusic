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

(import (artanis mvc model))

(create-artanis-model user_roles
                      (:deps)
                      (identifier char-field
                                  (#:primary-key #:maxlen 36))
                      (user_identifier char-field
                                       (#:maxlen 36))
                      (role_id char-field
                               (#:not-null #:maxlen 512))
                      (created_at date-field
                                  (#:not-null)))

