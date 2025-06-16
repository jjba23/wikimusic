(create-artanis-migration user_20250103093008)

(use-modules (artanis artanis)
             (artanis security nss))

(define* (add-test-user! #:key name
                         email
                         password
                         salt
                         permissions)
  (let ((mt (map-table-from-DB (get-conn-from-pool!)))
        (real-pass (string->sha-256 (string-append password salt))))
    (mt 'set
        'user
        #:username name
        #:email email
        #:password real-pass
        #:salt salt
        #:permissions permissions)))

(migrate-up (display "Adding user...")
            (add-test-user! #:name "Joe"
             #:email "jjbigorra@gmail.com"
             #:password ""
             #:salt ""
             ;; note: the ` is important due to Lisp quasi-quotation
             ;; so as to have it interpreted as a list of symbols
             #:permissions
             "`(wikimusic:modify-permissions
                                             wikimusic:song-create wikimusic:song-delete
                                             wikimusic:artist-create wikimusic:artist-delete
                                             wikimusic:genre-create wikimusic:genre-delete
                                             wikimusic:users-create wikimusic:users-delete)")
            (display "done.\n"))

