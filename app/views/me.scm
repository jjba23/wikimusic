;; wikimusic - the free music knowledge encyclopaedia
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (app views me)
  #:use-module (wikimusic html)
  #:use-module (artanis artanis)
  #:use-module (artanis i18n)
  #:use-module (artanis i18n sxml)
  #:use-module (artanis i18n locale)
  #:use-module (hygguile hygguile)
  #:use-module (ice-9 i18n)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 string-fun)
  #:export (me-page users-page reset-password-page new-user-page
                    edit-user-page))

(define* (me-page G_
                  #:key is-logged-in token user)
  
  (let* ((user-details `((div (@ (class ,(mk-class '(py-8 px-4 max-w-prose))))
                              ,(h3 (format #f "~a &lt;~a&gt;"
                                           (assoc-ref user "username")
                                           (assoc-ref user "email")))
                              (div (@ (class ,(mk-class '(flex flex-row
                                                               flex-wrap
                                                               gap-2
                                                               items-center
                                                               justify-start
                                                               my-4))))
                                   ,(em (G_ "my unique id:"))
                                   ,(mono (assoc-ref user "identifier")
                                          #:size '(text-xs)))
                              (div (@ (class ,(mk-class '(flex flex-row
                                                               flex-wrap
                                                               gap-2
                                                               items-center
                                                               justify-start
                                                               my-4))))
                                   ,(em (G_ "my permissions (in database):"))
                                   ,(pre (assoc-ref user "permissions")
                                         #:size '(text-xs)))
                              (div (@ (class ,(mk-class '(flex flex-row
                                                               flex-wrap
                                                               gap-2
                                                               items-center
                                                               justify-start
                                                               my-4))))
                                   ,(em (G_
                                         "current session permissions (in token):"))
                                   ,(pre (format #f "~s"
                                                 (assoc-ref token
                                                            'owner-permissions))
                                         #:size '(text-xs)))
                              (div (@ (class ,(mk-class '(max-w-prose))))
                                   ,(em (G_
                                         "tip: if your session permissions don't match the DB consider logging out and logging in again"))))))
         (has-modify-permissions (member 'wikimusic:modify-permissions
                                         (assoc-ref token
                                                    'owner-permissions)))
         (session-duration `((div (@ (class ,(mk-class '(py-8 px-4))))
                                  ,(em (format #f "~a: ~a"
                                               (G_ "logged in until")
                                               (strftime "%c"
                                                         (localtime (assoc-ref
                                                                     token
                                                                     'token-expires-at)))))))))
    (html-template G_
                   #:title "Your account · WikiMusic"
                   #:robots "noindex, nofollow"
                   #:is-logged-in is-logged-in
                   #:body `((div (@ (class ,(mk-class '())))
                                 (div (@ (class ,(mk-class '(flex flex-col
                                                                  gap-6))))
                                      ,user-details
                                      ,session-duration)
                                 (div (@ (class ,(mk-class '(py-6 flex
                                                                  flex-row
                                                                  flex-wrap
                                                                  gap-6))))
                                      ,(if has-modify-permissions
                                           `((a (@ (href "/users/manage"))
                                                ,(icon-button #:icon 'user-switch
                                                              #:content (G_
                                                                         "go to user management"))))
                                           '())
                                      (a (@ (href "/logout"))
                                         ,(icon-button #:icon 'sign-out
                                                       #:content (G_ "logout")))

                                      (form (@ (action "/password/reset")
                                               (method POST))
                                            ,(icon-button #:icon 'password
                                                          #:type 'submit
                                                          #:content (G_
                                                                     "reset password")))

                                      (a (@ (href "/login"))
                                         ,(icon-button #:icon 'sign-in
                                                       #:content (G_ "login")))

                                      ))))))

(define row-class
  (mk-class '(flex flex-row gap-4)))

(define* (render-user G_ u)
  `((div (@ (class ,(mk-class '(flex flex-col gap-4))))
         (div (@ (class ,(mk-class '(flex flex-col gap-2))))
              ,(em (G_ "username"))
              ,(p (assoc-ref u "username")
                  #:size '(text-sm)))

         (div (@ (class ,(mk-class '(flex flex-col gap-2))))
              ,(em (G_ "email"))
              ,(p (assoc-ref u "email")
                  #:size '(text-sm)))
         (div (@ (class ,(mk-class '(flex flex-col gap-2))))
              ,(em (G_ "id"))
              ,(mono (assoc-ref u "identifier")
                     #:size '(text-xs)))

         (div (@ (class ,(mk-class '(flex flex-col gap-2))))
              ,(em (G_ "permissions"))
              ,(mono (assoc-ref u "permissions")
                     #:size '(text-xs)))
         (div (@ (class ,(mk-class '(flex flex-row gap-3))))
              (div (@ (class ,(mk-class '(flex flex-row gap-3 flex-wrap))))
                   (form (@ (method POST)
                            (action "/users/delete"))
                         (input (@ (name identifier)
                                   (value ,(assoc-ref u "identifier"))
                                   (hidden "")))
                         ,(button (G_ "delete")
                                  #:on-click (format #f
                                              "return confirm('~a: ~a')"
                                              (assoc-ref u "email")
                                              (G_
                                               "are you sure you want to delete this user?"))
                                  #:type 'submit
                                  #:background '(bg-redwood-700)
                                  #:color '(text-stone-100)
                                  #:hover-background '(hover:bg-redwood-900
                                                       dark:hover:bg-redwood-500)))
                   (a (@ (href ,(format #f "/users/edit/~a"
                                        (assoc-ref u "identifier"))))
                      ,(icon-button #:icon 'pencil
                                    #:content (G_ "edit"))))))
    ,(hr)))

(define* (users-page G_
                     #:key users)
  (html-template G_
                 #:title "Your account · WikiMusic"
                 #:robots "noindex, nofollow"
                 #:is-logged-in #t
                 #:body `((div (@ (class ,(mk-class '())))
                               ,(h2 (G_ "User management"))
                               (div (@ (class ,(mk-class '(my-6))))
                                    (a (@ (href "/users/new"))
                                       ,(icon-button #:icon 'user-plus
                                                     #:content (G_ "new user"))))
                               (div (@ (class ,(mk-class '(flex flex-col
                                                           gap-4
                                                           my-8
                                                           py-8
                                                           px-4
                                                           rounded-xl
                                                           bg-stone-300
                                                           dark:bg-stone-900))))
                                    ,(map (lambda (u)
                                            (render-user G_ u)) users))))))

(define (make-permission-checkbox p)
  `((div ,(input #:type 'checkbox
                 #:input-flex-css '(my-2 flex flex-row gap-1)
                 #:label (format #f "~a" p)
                 #:name (format #f "~a" p)))))

(define* (new-user-page G_)
  (html-template G_
                 #:title "Your account · WikiMusic"
                 #:robots "noindex, nofollow"
                 #:is-logged-in #t
                 #:body `((div (@ (class ,(mk-class '())))
                               (div ,(h2 (G_ "New User")))
                               (div (@ (class ,(mk-class '(flex flex-col
                                                           gap-4
                                                           my-8
                                                           py-8
                                                           px-4
                                                           rounded-xl
                                                           bg-stone-300
                                                           dark:bg-stone-900))))
                                    (form (@ (method POST)
                                             (action "/users/new"))
                                          (div ,(input #:label (G_ "username")
                                                       #:name 'username
                                                       #:required #t))
                                          (div ,(input #:label (G_ "email")
                                                       #:name 'email
                                                       #:type 'email
                                                       #:required #t))
                                          (div (@ (class ,(mk-class '(my-6))))
                                               ,(sub-h4 (G_ "user permissions"))
                                               (div (@ (class ,(mk-class '(flex
                                                                           flex-col
                                                                           gap-1))))

                                                    ,(map
                                                      make-permission-checkbox
                                                      '(wikimusic:song-create
                                                        wikimusic:song-delete
                                                        wikimusic:artist-create
                                                        wikimusic:artist-delete
                                                        wikimusic:genre-create
                                                        wikimusic:genre-delete
                                                        wikimusic:user-create
                                                        wikimusic:user-delete
                                                        wikimusic:modify-permissions)))
                                               (div ,(submit-button (G_
                                                                     "create"))))))))))

(define* (make-edit-permission-checkbox p
                                        #:key label
                                        name
                                        (type 'checkbox)
                                        (checked #f)
                                        (input-css '(p-3 max-w-prose
                                                     rounded-xl
                                                     border-stone-100
                                                     dark:border-stone-700
                                                     dark:text-stone-300
                                                     bg-stone-300/75
                                                     dark:bg-stone-700/75
                                                     border-2
                                                     shadow-md))
                                        (label-css '(text-sm font-bold
                                                     text-stone-500
                                                     dark:text-stone-300))
                                        (input-flex-css '(my-2 flex flex-row
                                                               gap-1)))
  
  `((div (@ (class ,(mk-class input-flex-css)))
         (label (@ (class ,(mk-class label-css))
                   (for ,name))
                ,label)
         (input (@ (class ,(mk-class input-css))
                   (name ,name)
                   ,(if checked
                        '(checked "")
                        '(not-checked ""))
                   (type ,(symbol->string type))) ""))))

(define* (edit-user-page G_ u)
  (html-template G_
                 #:title "Your account · WikiMusic"
                 #:robots "noindex, nofollow"
                 #:is-logged-in #t
                 #:body `((div (@ (class ,(mk-class '())))
                               (div ,(h2 (G_ "Edit User")))
                               (div (@ (class ,(mk-class '(flex flex-col
                                                           gap-4
                                                           my-8
                                                           py-8
                                                           px-4
                                                           rounded-xl
                                                           bg-stone-300
                                                           dark:bg-stone-900))))
                                    (form (@ (method POST)
                                             (action ,(format #f
                                                       "/users/edit/~a"
                                                       (assoc-ref u
                                                        "identifier"))))
                                          (input (@ (hidden "")
                                                    (value ,(assoc-ref u
                                                             "identifier"))))
                                          (div ,(input #:label (G_ "username")
                                                       #:value (assoc-ref u
                                                                "username")
                                                       #:name 'username
                                                       #:required #t))
                                          (div ,(input #:label (G_ "email")
                                                       #:name 'email
                                                       #:value (assoc-ref u
                                                                "email")
                                                       #:type 'email
                                                       #:required #t))
                                          (div (@ (class ,(mk-class '(my-6))))
                                               ,(sub-h4 (G_ "user permissions"))
                                               (div (@ (class ,(mk-class '(flex
                                                                           flex-col
                                                                           gap-1))))

                                                    ,(map (lambda (p)
                                                            (make-edit-permission-checkbox
                                                             p
                                                             #:label (symbol->string
                                                                      p)
                                                             #:name p
                                                             #:checked (not (nil?
                                                                             (member
                                                                              p

                                                                              
                                                                              (eval-string
                                                                               (assoc-ref
                                                                                u
                                                                                "permissions")))))))
                                                          '(wikimusic:song-create
                                                            wikimusic:song-delete
                                                            wikimusic:artist-create
                                                            wikimusic:artist-delete
                                                            wikimusic:genre-create
                                                            wikimusic:genre-delete
                                                            wikimusic:user-create
                                                            wikimusic:user-delete
                                                            wikimusic:modify-permissions)))
                                               (div ,(submit-button (G_ "edit"))))))))))

;; The page a reset link leads to, and the one a rejected password comes back
;; to.  REJECTED is the reason the last submission did not take -- `weak' or
;; `mismatch' -- and is #f on a first visit, which is what makes saying so
;; possible at all: a reader sent back to the same form with no explanation
;; types the same password again.
;;
;; The rule is stated rather than described.  The server takes a password that
;; `strong-password?' calls strong, which is an estimate of sixty bits or more,
;; and no sentence about that is exact -- so the page says what sort of
;; password passes and lets the meter beside the field show where one is.
(define* (reset-password-page G_
                              #:key token email rejected)
  (let ((rejection (cond
                     ((equal? rejected "mismatch")
                      (G_ "the two passwords you typed are not the same"))
                     ((equal? rejected "weak")
                      (G_
                       "that password is too easy to guess, so it was not accepted; the rule below is what it has to pass"))
                     (else #f))))
    (html-template G_
                   #:title "Choose a new password · WikiMusic"
                   #:robots "noindex, nofollow"
                   #:is-logged-in #f
                   #:body `((div (@ (class ,(mk-class '(py-6 px-4))))
                                 ,(h2 (G_ "Reset your password"))
                                 ,(sub-h3 (format #f "~a: ~a"
                                                  (G_
                                                   "perform a password reset for")
                                                  email))
                                 (form (@ (method POST)
                                          (action "/password/do-reset"))
                                       (div (@ (class ,(mk-class '(rounded-xl
                                                                   my-6
                                                                   py-6
                                                                   px-4
                                                                   shadow-md
                                                                   max-w-prose
                                                                   bg-stone-300
                                                                   dark:bg-stone-900))))
                                            (input (@ (hidden true)
                                                      (name email)
                                                      (value ,email)) "")
                                            (input (@ (hidden true)
                                                      (name reset-token)
                                                      (value ,token)) "")
                                            ;; A submission that came back is
                                            ;; announced, not silently
                                            ;; repeated: the reader is owed
                                            ;; the reason while they retype.
                                            ,(when rejection
                                               `(p (@ (role alert)
                                                      (class ,(mk-class '(text-persia-pink-900
                                                                          dark:text-persia-pink-300
                                                                          font-bold
                                                                          py-2))))
                                                   ,rejection))
                                            ;; The meter is decoration on top
                                            ;; of a form that already works:
                                            ;; the fields are ordinary
                                            ;; password fields, the rule is
                                            ;; written out beside them, and
                                            ;; the server is what decides.
                                            ;; All this does is say, while a
                                            ;; reader is typing, where the
                                            ;; password stands.
                                            (div (@ (data-password-strength "")
                                                    (data-label-very-weak ,(G_
                                                                            "very weak"))
                                                    (data-label-weak ,(G_
                                                                       "weak"))
                                                    (data-label-fair ,(G_
                                                                       "fair"))
                                                    (data-label-strong ,(G_
                                                                         "strong"))
                                                    (data-label-very-strong ,(G_
                                                                              "very strong"))
                                                    (data-mismatch ,(G_
                                                                     "the two passwords you typed are not the same"))
                                                    (class ,(mk-class '(flex
                                                                        flex-col
                                                                        gap-2))))
                                                 (p (@ (class ,(mk-class '(text-sm
                                                                           font-light
                                                                           text-onyx-300
                                                                           dark:text-stone-300))))
                                                    ,(G_
                                                      "a password of at least a dozen characters, mixing upper and lower case with digits or symbols; a dozen plain lower-case letters is not enough on its own, and a common password is refused however long it is"))
                                                 ,(input #:label (G_
                                                                  "new password")
                                                         #:name "new-password"
                                                         #:value ""
                                                         #:type 'password
                                                         #:required #t
                                                         #:autocomplete
                                                         "new-password")
                                                 (progress (@ (max "4")
                                                              (value "0")
                                                              (class ,(mk-class '
                                                                       (hg-progress)))))
                                                 (p (@ (data-password-strength-saying
                                                        "")
                                                       (aria-live polite)
                                                       (class ,(mk-class '(text-sm
                                                                           font-bold
                                                                           text-onyx-500
                                                                           dark:text-stone-300))))
                                                    "")
                                                 ,(input #:label (G_
                                                                  "confirm password")
                                                         #:name
                                                         "confirm-password"
                                                         #:value ""
                                                         #:type 'password
                                                         #:required #t
                                                         #:autocomplete
                                                         "new-password"))
                                            (div ,(submit-button (G_ "reset"))))))))))
