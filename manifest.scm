;;; wikimusic - the free music knowledge encyclopaedia

;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;; wikimusic is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; wikimusic is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU Affero General Public License for more details.

;; You should have received a copy of the GNU Affero General Public License
;; along with wikimusic.  If not, see <https://www.gnu.org/licenses/>.

(use-modules (guix packages)
             (gnu)
             (guix utils)
             (guix git-download)
             (guix download)
             (guix build-system gnu)
             (gnu packages guile)
             (gnu packages curl)
             (gnu packages bash)
             (gnu packages nss)
             (gnu packages gnupg)
             (gnu packages guile-xyz)
             (gnu packages pkg-config)
             (gnu packages rust-apps)
             (guix build-system guile)
             (gnu packages linux)
             (gnu packages emacs)
             (gnu packages vim)
             (gnu packages tls)
             (gnu packages perl)
             (gnu packages compression)
             (gnu packages sqlite)
             (gnu packages texinfo)
             (gnu packages autotools)
             ((guix licenses)
              #:prefix license:))

(define-public guile-uuid
  (package
    (name "guile-uuid")
    (version "0.9.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://codeberg.org/elb/guile-uuid.git")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0g508aajkyi513wbhm1rhs03ilnb701lwlrvppkmc0vynydlk9ws"))))
    (build-system guile-build-system)
    (native-inputs (list guile-3.0 guile-gcrypt))
    (home-page "https://codeberg.org/elb/guile-uuid")
    (synopsis "UUID generation and manipulation library for Guile Scheme")
    (description
     "This package implements RFC 9562 UUIDs, and can generate versions
1 and 3–8 from that specification. It also provides parsing for UUIDs in
standard hex-and-dash format of any variant and version. Simple routines for converting
between binary and hex-and-dash string UUIDs are included.")
    (license license:gpl3+)))

(define-public guile-hygguile
  (package
    (name "guile-hygguile")
    (version "2.0.21")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://codeberg.org/jjba23/hygguile.git")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "04fpf46ibjb4x2qpzgwdhnjh7cjvzvn5fry0j4macdijhbwd59yf"))))
    (build-system guile-build-system)
    (native-inputs (list guile-3.0))
    (arguments
     (list
      #:source-directory "src"))
    (home-page "https://codeberg.org/jjba23/hygguile")
    (synopsis "Web UI component library for Guile Scheme projects")
    (description
     "Hygguile is a library that allows you to create cozy web user-interfaces
using Guile Scheme, by defining an expressive domain-specific language (DSL),
and by leveraging the power of S-expressions, SXML and TailwindCSS.

The project aims to provide reusable, professional-looking and accessible
web components, whose names resemble the HTML counterparts, thus
easing the learning curve, and reducing the cognitive load.")
    (license license:lgpl3+)))

(define-public guile-kracht
  (package
    (name "guile-kracht")
    (version "0.2.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://codeberg.org/jjba23/kracht.git")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0mcyi3a6vpqm4z01rcmv6fqhf7gayppa9yib76jqrihxv8w70m5g"))))
    (build-system guile-build-system)
    (native-inputs (list guile-3.0))
    (arguments
     (list
      #:source-directory "src"))
    (home-page "https://codeberg.org/jjba23/kracht")
    (synopsis
     "Utility methods and functionalities for Guile Scheme programming")
    (description
     "Kracht provides helpful and convenient functionalities that can help you
develop more comfortably in your Guile Scheme project. You can see it as a
batteries-included addition to the (already great) standard library
of Guile Scheme, complementing it, and helping developers write cleaner,
more efficient, and more powerful code.")
    (license license:lgpl3+)))

(define-public guile-orgwebalchemy
  (package
    (name "guile-orgwebalchemy")
    (version "0.1.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://codeberg.org/jjba23/orgwebalchemy.git")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0mzm3rbldfhzlj5mg70w11v2givpgl0bzlpw513vw1cg85l7vkf9"))))
    (build-system guile-build-system)
    (native-inputs (list guile-3.0))
    (arguments
     (list
      #:source-directory "src"))
    (home-page "https://codeberg.org/jjba23/orgwebalchemy")
    (synopsis
     "Convert Org markup to pretty HTML with a Lisp (Guile Scheme) library")
    (description
     "Convert Org markup to pretty HTML with a Lisp (Guile Scheme) library")
    (license license:lgpl3+)))

(define-public guile-bewaking
  (package
    (name "guile-bewaking")
    (version "0.1.5")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://codeberg.org/jjba23/bewaking.git")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "15yz25b8bfi58lrb1kgfg5sq84pim04rfjqs87qzl655rfifxjq3"))))
    (build-system guile-build-system)
    (native-inputs (list guile-uuid guile-gcrypt guile-3.0))
    (propagated-inputs (list openssl xxd))
    (arguments
     (list
      #:source-directory "src"))
    (home-page "https://codeberg.org/jjba23/bewaking")
    (synopsis "Authentication / Authorization library for Guile Scheme")
    (description
     "bewaking is a library that helps you with secure tokens.
It allows you to create and verify lifetime-limited encrypted digital
credentials that carry information securely.

Tokens are protected through multiple layers of cryptography techniques
and obfuscation tricks, producing secure tokens you can use for example for
user sessions on the web or authenticating API calls.")
    (license license:lgpl3+)))

(packages->manifest (list (specification->package "make")
                          (specification->package "gettext")
                          guile-3.0-latest
                          guile-uuid
                          guile-ares-rs
                          artanis
                          guile-hygguile
                          guile-kracht
                          guile-orgwebalchemy
                          guile-bewaking
                          guile-curl
                          sqlite
                          guile-gcrypt
                          guile-dbi
                          guile-dbd-sqlite3
                          watchexec
                          emacs-no-x))

