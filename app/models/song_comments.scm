;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(import (artanis mvc model))

(create-artanis-model song_comments
                      (:deps)
                      (identifier char-field
                                  (#:primary-key #:maxlen 36))
                      (parent_identifier char-field
                                         (#:maxlen 36))
                      (song_identifier char-field
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

