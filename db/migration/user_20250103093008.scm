(create-artanis-migration user_20250103093008)

(use-modules (artanis artanis)
             (artanis security nss))

;; (define* (add-test-user! #:key name email password salt)
;;   (let ((mt (map-table-from-DB (get-conn-from-pool!)))
;;         (real-pass (string->sha-256 (string-append password salt))))
;;     (mt 'set
;;         'users
;;         #:display_name name
;;         #:email_address email
;;         #:password_hash real-pass
;;         #:salt salt)))

(define* (reset-user! #:key display_name email_address password salt)
  (let ((real-pass (string->sha-256 (string-append password salt))))
    (DB-query (get-conn-from-pool!)
              (->sql update
                     'users set
                     `((salt ,salt)
                       (password_hash ,real-pass))
                     (where #:email_address email_address)))))

;; (migrate-up (display "Adding user...")
;;             (add-test-user! #:name "Joe"
;;                             #:email "jjbigorra@gmail.com"
;;                             #:password ""
;;                             #:salt "asdf")
;;             (display "done.\n"))

(migrate-up (display "Resetting user...")
            (reset-user! #:display_name "Joe"
                         #:email_address "jjbigorra@gmail.com"
                         #:password ""
                         #:salt "asdf")
            (display "done.\n"))
