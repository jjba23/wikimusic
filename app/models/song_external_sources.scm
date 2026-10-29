;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(import (artanis mvc model))

(create-artanis-model song_external_sources
                      (:deps)
                      (identifier char-field
                                  (#:primary-key #:maxlen 36))
                      (song_identifier char-field
                                       (#:unique #:not-null #:maxlen 36))

                      (created_by char-field
                                  (#:not-null #:maxlen 36))
                      (souncloud_url char-field
                                     (#:maxlen 8192))
                      (spotify_url char-field
                                   (#:maxlen 8192))
                      (youtube_url char-field
                                   (#:maxlen 8192))
                      (wikipedia_url char-field
                                     (#:maxlen 8192))
                      (created_at date-field
                                  (#:not-null))
                      (last_edited_at date-field))

