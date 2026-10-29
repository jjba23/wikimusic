;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(import (artanis mvc model))

(create-artanis-model genre_opinions
                      (:deps)
                      (identifier char-field
                                  (#:primary-key #:maxlen 36))
                      (genre_identifier char-field
                                        (#:not-null #:maxlen 36))

                      (created_by char-field
                                  (#:not-null #:maxlen 36))
                      (is_like tinyint
                               (#:not-null))
                      (is_dislike tinyint
                                  (#:not-null))
                      (created_at date-field
                                  (#:not-null))
                      (last_edited_at date-field))

