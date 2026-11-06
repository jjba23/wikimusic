;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(list (channel
       (name 'guix)
       (url "https://codeberg.org/guix/guix.git")
       (branch "master")
       (commit "973dbc8c00de826f3c38468b09519d30d064eea3")
       (introduction
        (make-channel-introduction "9edb3f66fd807b096b48283debdcddccfea34bad"
                                   (openpgp-fingerprint
                                    "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA"))))
      (channel
       (name 'jointhefreeworld)
       (url "https://github.com/jjba23/guix-jointhefreeworld")
       (branch "trunk")
       (commit "8f33453886027ab86ebec73aadea9d8c155bb3b4")
       (introduction
        (make-channel-introduction
         "b0ac3f05075d7959860fc9e1db5871acddea3986"
         (openpgp-fingerprint
          "83BC 6E1C 8726 B8C2 97F8  D16E 24F4 6738 CE11 4AF6")))))
