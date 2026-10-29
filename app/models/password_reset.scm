;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(import (artanis mvc model))

(create-artanis-model password_reset
                      (:deps users)
                      (user_id char-field
                               (#:unique #:not-null #:maxlen 36))
                      (reset_token char-field
                                   (#:not-null #:maxlen 2048))
                      (created_at date-field
                                  (#:not-null)))
