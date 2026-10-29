;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(import (artanis mvc model))

(create-artanis-model users
                      (:deps)
                      (identifier char-field
                                  (#:primary-key #:maxlen 36))
                      (username char-field
                                (#:not-null #:maxlen 256))
                      (email char-field
                             (#:not-null #:unique #:maxlen 256))
                      (password char-field
                                (#:maxlen 2048))
                      (salt char-field
                            (#:maxlen 36))
                      (permissions char-field
                                   (#:maxlen 4096)))

