;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(import (artanis mvc model))

(create-artanis-model genres
                      (:deps)
                      (identifier char-field
                                  (#:primary-key #:maxlen 36))
                      (display_name char-field
                                    (#:maxlen 256))
                      (created_by char-field
                                  (#:not-null #:maxlen 36))
                      (visibility_status smallint
                                         (#:not-null))
                      (approved_by char-field
                                   (#:maxlen 36))
                      (views bigint
                             (#:not-null))
                      (description char-field
                                   (#:maxlen 2048))
                      (created_at date-field
                                  (#:not-null))
                      (last_edited_at date-field))

