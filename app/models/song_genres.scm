;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(import (artanis mvc model))

(create-artanis-model song_genres
                      (:deps)
                      (identifier char-field
                                  (#:primary-key #:maxlen 36))
                      (song_identifier char-field
                                       (#:not-null #:maxlen 36))
                      (genre_identifier char-field
                                        (#:not-null #:maxlen 36))
                      (created_by char-field
                                  (#:not-null #:maxlen 36))
                      (created_at date-field
                                  (#:not-null)))

