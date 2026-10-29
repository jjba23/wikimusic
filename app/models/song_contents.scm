;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(import (artanis mvc model))

(create-artanis-model song_contents
                      (:deps)
                      (identifier char-field
                                  (#:primary-key #:not-null #:maxlen 36))
                      (song_identifier char-field
                                       (#:not-null #:maxlen 36))
                      (version_name char-field
                                    (#:not-null #:maxlen 256))
                      (created_by char-field
                                  (#:not-null #:maxlen 36))
                      (visibility_status smallint
                                         (#:not-null))
                      (approved_by char-field
                                   (#:maxlen 36))
                      (instrument_type char-field
                                       (#:not-null #:maxlen 256))
                      (ascii_legend char-field
                                    (#:maxlen 4096))
                      (ascii_contents char-field
                                      (#:maxlen 32768))
                      (pdf_contents char-field
                                    (#:maxlen 32768))
                      (guitarpro_contents char-field
                                          (#:maxlen 32768))
                      (created_at date-field
                                  (#:not-null))
                      (last_edited_at date-field))
