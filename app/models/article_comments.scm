;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(import (artanis mvc model))

;; The one comments table the schema lets anybody write to: `created_by' is
;; nullable and `author_name' is what a signed-out reader typed, so a comment
;; may arrive with either one and never with both.
(create-artanis-model article_comments
                      (:deps)
                      (identifier char-field
                                  (#:primary-key #:maxlen 36))
                      (parent_identifier char-field
                                         (#:maxlen 36))
                      (article_identifier char-field
                                          (#:not-null #:maxlen 36))
                      (author_name char-field
                                   (#:maxlen 80))
                      (created_by char-field
                                  (#:maxlen 36))
                      (visibility_status smallint
                                         (#:not-null))
                      (approved_by char-field
                                   (#:maxlen 36))
                      (contents char-field
                                (#:not-null #:maxlen 4096))
                      (created_at date-field
                                  (#:not-null))
                      (last_edited_at date-field))

