;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(import (artanis mvc model))

(create-artanis-model artist_artworks
                      (:deps)
                      (identifier char-field
                                  (#:primary-key #:maxlen 36))
                      (artist_identifier char-field
                                         (#:not-null #:maxlen 36))

                      (created_by char-field
                                  (#:not-null #:maxlen 36))
                      (visibility_status smallint
                                         (#:not-null))
                      (approved_by char-field
                                   (#:maxlen 36))
                      (content_url char-field
                                   (#:not-null #:maxlen 4096))
                      (content_caption char-field
                                       (#:maxlen 4096))
                      (order_value smallint
                                   (#:not-null))
                      (created_at date-field
                                  (#:not-null))
                      (last_edited_at date-field))

