;; -*- lexical-binding: t; -*-

(defun reorg--set-up-capture-test ()
  "set up capture testing"
  (interactive)
  (setq org-capture-templates
	'(("t" "Task" entry (function org-legal-default-capture-find-func) "* TASK %?\n")
	  ("c" "Calendar" entry (function org-legal-calendar-capture-find-func) "* EVENT %?\n")
	  ("d" "Calendar" entry (function org-legal-calendar-capture-find-func) "* DEADLINE %?\n")
	  ("n" "Progress note" plain (function org-legal-notes-capture-find-func) "%U\n%?\n")
	  ("w" "Case review agenda" checkitem (id "ebd5bf86-9234-443a-bc90-9a11571d1424"))))

  (defun org-legal-default-capture-find-func (&optional file)
    "Prompt the user to select from the root headings in an agenda file."
    (interactive)
    (let* ((headings (org-ql-select "~/tmp/tmp.org"
		       `(level 1)
		       :action
		       (lambda ()
			 `(:file ,(buffer-file-name)
				 :point ,(org-element-property
					  :begin
					  (org-element-at-point))
				 :headline ,(org-no-properties (org-get-heading t t t t))))))
	   (candidate (completing-read "Task target: " 
				       (mapcar (lambda (heading) (plist-get heading :headline))
					       headings)))
	   (target (cl-loop for heading in headings
			    when (string= (plist-get heading :headline) candidate)
			    return heading)))
      (find-file (plist-get target :file))
      (widen)
      (goto-char (plist-get target :point))
      (if (re-search-forward "^\\*+[[:space:]]+_TASKS_"
			     (save-excursion (org-end-of-subtree)) t)
          (progn (goto-char (match-end 0)))
	(org-insert-heading-respect-content)
	(org-metaright)
	(insert "_TASKS_"))))


  (defun org-legal-calendar-capture-find-func (&optional file)
    "Prompt the user to select from the root headings in an agenda file, 
  then move to the first sub-heading called \"_CALENDAR_\"."
    (interactive)
    (let* ((headings (org-ql-select "~/tmp/tmp.org"
		       `(level 1)
		       :action
		       (lambda ()
			 `(:file ,(buffer-file-name)
				 :point ,(org-element-property
					  :begin
					  (org-element-at-point))
				 :headline ,(org-no-properties (org-get-heading t t t t))))))
	   (candidate (completing-read "Calendar target: " 
				       (mapcar (lambda (heading) (plist-get heading :headline))
					       headings)))
	   (target (cl-loop for heading in headings
			    when (string= (plist-get heading :headline) candidate)
			    return heading)))
      (find-file (plist-get target :file))
      (widen)
      (goto-char (plist-get target :point))
      (if (re-search-forward "^\\*+[[:space:]]+_CALENDAR_"
			     (save-excursion (org-end-of-subtree)) t)
	  (progn (goto-char (match-end 0)))
	(org-insert-heading-respect-content)
	(org-metaright)
	(insert "_CALENDAR_"))))

  (defun org-legal-notes-capture-find-func (&optional file)
    "Prompt the user to select from the root headings in an agenda file, 
  then move to the first sub-heading called \"_NOTES_\"."
    (interactive)
    (let* ((headings (org-ql-select "~/tmp/tmp.org"
		       `(level 1)
		       :action
		       (lambda ()
			 `(:file ,(buffer-file-name)
				 :point ,(org-element-property
                                          :begin
                                          (org-element-at-point))
				 :headline ,(org-no-properties (org-get-heading t t t t))))))
           (candidate (completing-read "Note: " 
				       (mapcar (lambda (heading) (plist-get heading :headline))
					       headings)))
           (target (cl-loop for heading in headings
			    when (string= (plist-get heading :headline) candidate)
			    return heading)))
      (find-file (plist-get target :file))
      (widen)
      (goto-char (plist-get target :point))
      (if (re-search-forward "^\\*+[[:space:]]+_NOTES_"
			     (save-excursion (org-end-of-subtree)) t)
          (progn (org-end-of-meta-data t))
	(org-insert-heading-respect-content)
	(org-metaright)
	(insert "_NOTES_"))))
  (reorg-org-capture-enable))

(defun reorg-test-1 ()
  (interactive)
  (reorg-open reorg-template--test-org)
  (reorg-open-sidebar))

(setq reorg-template--test-org '( :sources ((org . "~/tmp/tmp.org"))
				  :children
				  (( :group "By client"
				     ;; :bullet "It's a tarp!"
				     :children
				     (( :group
					.category-inherited
					:sort-groups
					reorg-string<
					:children
					(( :group
					   (when
					       (and
						.todo
						(not (string= "DONE" .todo))
						(not (string= "EVENT" .todo))
						(not (string= "DEADLINE" .todo))
						(not (string= "OPP_DUE" .todo)))
					     "Tasks")
					   :sort-groups
					   reorg-string<
					   :format-results
					   (.priority
					    " "
					    (s-pad-right 15 " " .todo)
					    " " .headline)
					   :sort-results
					   ((.priority . reorg-string<)
					    (.headline . reorg-string<)))
					 ( :group (when (and .ts-ts
							     (ts> .ts-ts (ts-now))
							     (not (string= "DONE" .todo)))
						    "Calendar")
					   :format-results
					   (.ts-type
					    " "
					    (s-pad-right 30 " " .ts)
					    " " .headline)
					   :sort-results
					   (( .ts . reorg-string<)))))))
				   ( :group "By delegatee"
				     ;; :bullet "This should be different."
				     :children (( :group
						  .delegatee
						  :sort-groups
						  reorg-string<)))		 
				   ( :group "Calendar"
				     :children (( :group
						  .ts-year
						  ;; :bullet "Year: "
						  :sort-groups
						  string<
						  :children
						  (( :group
						     .ts-month
						     ;; :bullet "       "
						     :sort-groups
						     (lambda (a b)
						       (let ((seq '("January"
								    "February"
								    "March"
								    "April"
								    "May"
								    "June"
								    "July"
								    "August"
								    "September"
								    "October"
								    "November"
								    "December")))
							 (< (seq-position seq a 'string=)
							    (seq-position seq b 'string=))))
						     :sort-results
						     ((.ts-day . <))
						     :format-results
						     ("                             "
						      " "
						      (s-pad-left 2 " "
								  (number-to-string
								   .ts-day))
						      " "
						      (s-pad-right 12 " "
								   .ts-day-name)
						      (s-pad-right
						       20
						       " "
						       .category-inherited)
						      .headline)))))))))
(defun reorg-test-all ()
  (interactive)
  (reorg-open reorg-template--test-all))

(setq reorg-template--test-all '( :sources ((org . "~/tmp/tmp.org"))
				  :children
				  (( :group "By client"
				     :children
				     (( :group
					.category-inherited
					:sort-groups
					reorg-string<			
					:children
					(( :group
					   (when
					       (and
						.todo
						(not (string= "DONE" .todo))
						(not (string= "EVENT" .todo))
						(not (string= "DEADLINE" .todo)))
					     "Tasks")
					   :sort-groups
					   reorg-string<
					   :format-results
					   (.priority
					    " "
					    (s-pad-right 15 " " .todo)
					    " " .headline)
					   :sort-results
					   ((.priority . string<)
					    (.headline . string<)))
					 ( :group (when (and .ts-ts
							     (ts> .ts-ts (ts-now)))
						    "Calendar")
					   :format-results
					   (.ts-type
					    " "
					    (s-pad-right 30 " " .ts)
					    " " .headline)
					   :sort-results
					   (( .ts . string<)))))))
				   ( :group "By delegatee"
				     :children (( :group
						  .delegatee
						  :sort-groups
						  (lambda (a b)
						    (string< a b)))))		 
				   ( :group "Calendar"
				     :children (( :group
						  .ts-year
						  :sort-groups
						  (lambda (a b) (string< a b))
						  :children
						  (( :group
						     .ts-month
						     :sort-groups
						     (lambda (a b)
						       (let ((seq '("January"
								    "February"
								    "March"
								    "April"
								    "May"
								    "June"
								    "July"
								    "August"
								    "September"
								    "October"
								    "November"
								    "December")))
							 (< (seq-position seq a 'string=)
							    (seq-position seq b 'string=))))
						     :sort-results
						     ((.ts-day . <))
						     :format-results
						     (.stars
						      " "
						      (s-pad-left 2 " "
								  (number-to-string
								   .ts-day))
						      " "
						      (s-pad-right 12 " "
								   .ts-day-name)
						      (s-pad-right
						       20
						       " "
						       .category-inherited)
						      .headline))))))
				   ( :sources ((email . "subject:allums"))
				     :group (when (eq .class 'email)
					      "Emails")
				     :format-results (.stars
						      " "
						      .date
						      "\t\t"
						      .subject))
				   ( :sources ((files . "find ~/legal/Dropbox/Allums\\,\\ Matthew/docket -type f"))
				     :group "Files"
				     :children (( :group "By extension"
						  :children (( :group .extension
							       :sort-groups (lambda (a b) (string< (downcase a)
												   (downcase b)))
							       :sort-results (((downcase .filename) . string<))
							       :format-results (.filename))))
						( :group "by parent"
						  :children (( :group (when .depth (number-to-string .depth ))
							       :sort-groups string<
							       :format-results (.stars " " .fullname)))))))))

(defun reorg-user--test-all ()
  (interactive)
  (reorg-open-main-window
   '( :sources ((org . "~/tmp/tmp.org"))
      :children
      (( :group "By client"
	 :children
	 (( :group
	    .category-inherited
	    :sort-groups
	    (lambda (a b)
	      (string< (downcase a)
		       (downcase b)))			
	    :children
	    (( :group
	       (when
		   (and
		    .todo
		    (not (string= "DONE" .todo))
		    (not (string= "EVENT" .todo))
		    (not (string= "DEADLINE" .todo)))
		 "Tasks")
	       :sort-group
	       string<
	       :format-results
	       (.priority
		" "
		(s-pad-right 15 " " .todo)
		" " .headline)
	       :sort-results
	       ((.priority . string<)
		(.headline . string<)))
	     ( :group (when (and .ts-ts
				 (ts> .ts-ts (ts-now)))
			"Calendar")
	       :format-results
	       (.ts-type
		" "
		(s-pad-right 30 " " .ts)
		" " .headline)
	       :sort-results
	       (( .ts . string<)))))))
       ( :group "By delegatee"
	 :children (( :group
		      .delegatee
		      :sort-group
		      (lambda (a b)
			(string< a b)))))		 
       ( :group "Calendar"
	 :children (( :group
		      .ts-year
		      :sort-groups
		      (lambda (a b) (string< a b))
		      :children
		      (( :group
			 .ts-month
			 :sort-groups
			 (lambda (a b)
			   (let ((seq '("January"
					"February"
					"March"
					"April"
					"May"
					"June"
					"July"
					"August"
					"September"
					"October"
					"November"
					"December")))
			     (< (seq-position seq a 'string=)
				(seq-position seq b 'string=))))
			 :sort-results
			 ((.ts-day . <))
			 :format-results
			 (.stars
			  " "
			  (s-pad-left 2 " "
				      (number-to-string
				       .ts-day))
			  " "
			  (s-pad-right 12 " "
				       .ts-day-name)
			  (s-pad-right
			   20
			   " "
			   .category-inherited)
			  .headline))))))
       ( :sources ((email . "subject:allums"))
	 :group (when (eq .class 'email)
		  "Emails")
	 :format-results (.stars
			  " "
			  .date
			  "\t\t"
			  .subject))
       ( :sources ((files . "find ~/legal/Dropbox/Allums\\,\\ Matthew/docket -type f"))
	 :group "Files"
	 :children (( :group "By extension"
		      :children (( :group .extension
				   :sort-groups (lambda (a b) (string< (downcase a)
								       (downcase b)))
				   :sort-results (((downcase .filename) . string<))
				   :format-results (.filename))))
		    ( :group "by parent"
		      :children (( :group (when .depth (number-to-string .depth ))
				   :sort-groups string<
				   :format-results (.stars " " .fullname))))))))))

(defun reorg-user--test-main-view ()
  (interactive)
  (reorg-open-main-window
   '( :sources ((org . "~/tmp/tmp.org"))
      :children
      (( :group "By client"
	 :children
	 (( :group
	    .category-inherited
	    :sort-groups
	    (lambda (a b)
	      (string< (downcase a)
		       (downcase b)))			
	    :children
	    (( :group
	       (when
		   (and
		    .todo
		    (not (string= "DONE" .todo))
		    (not (string= "EVENT" .todo))
		    (not (string= "DEADLINE" .todo)))
		 "Tasks")
	       :sort-group
	       string<
	       :format-results
	       (.priority
		" "
		(s-pad-right 15 " " .todo)
		" " .headline)
	       :sort-results
	       ((.priority . string<)
		(.headline . string<)))
	     ( :group (when (and .ts-ts
				 (ts> .ts-ts (ts-now)))
			"Calendar")
	       :format-results
	       (.ts-type
		" "
		(s-pad-right 30 " " .ts)
		" " .headline)
	       :sort-results
	       (( .ts . string<)))))))
       ( :group "By delegatee"
	 :children (( :group
		      .delegatee
		      :sort-group
		      (lambda (a b)
			(string< a b)))))		 
       ( :group "Calendar"
	 :children (( :group
		      .ts-year
		      :sort-groups
		      (lambda (a b) (string< a b))
		      :children
		      (( :group
			 .ts-month
			 :sort-groups
			 (lambda (a b)
			   (let ((seq '("January"
					"February"
					"March"
					"April"
					"May"
					"June"
					"July"
					"August"
					"September"
					"October"
					"November"
					"December")))
			     (< (seq-position seq a 'string=)
				(seq-position seq b 'string=))))
			 :sort-results
			 ((.ts-day . <))
			 :format-results
			 (.stars
			  " "
			  (s-pad-left 2 " "
				      (number-to-string
				       .ts-day))
			  " "
			  (s-pad-right 12 " "
				       .ts-day-name)
			  (s-pad-right
			   20
			   " "
			   .category-inherited)
			  .headline))))))))))

(defun reorg-user--test-email ()
  (interactive)
  (reorg-open-main-window
   '( :sources ((email . "subject:allums"))
      :children (( :group "Allums emails"
		   :children (( :group (when (eq .class 'email)
					 "Emails")
				:format-results (.stars
						 " "
						 .date
						 "\t\t"
						 .subject))))))))

(defun reorg-user--test-allums-view ()
  (interactive)
  (reorg-open-main-window
   '( :sources ((org . "~/org/Allums.org")
		(org . "~/tmp/tmp.org")
		(email . "subject:allums")
		(files . "find ~/legal/Dropbox/Allums\,\\ Matthew/docket -type f"))
      :children (( :group "Allums"
		   :children (( :group (when (and .todo
						  (equal .category-inherited
							 "Allums")
						  (equal .todo "TASK"))
					 "TASKS")
				:format-results (.stars " " .task " " .headline))
			      ( :group (when (and (equal .category-inherited
							 "Allums")
						  .ts-ts)
					 "CALENDAR")
				:format-results (.stars " " .headline))
			      ( :group (when (eq .class 'files)
					 "Docket")
				:format-results (.stars " " .filename))
			      ( :group (when (eq .class 'email)
					 "Emails")
				:format-results (.stars
						 " "
						 .date
						 "\t\t"
						 .subject)
				:sort-results ((.date . string>)))))))))

(defun reorg-user--leo ()
  (interactive)
  (reorg-open-main-window
   '( :sources ((leo . "~/.leo/workbook.leo"))
      :group "workbook.leo"
      :format-results (.stars " " .headline)
      :overrides (
		  (reorg-level . (1+ (or .leo-level 0))))
      :post-overrides ((reorg-branch . t)))))

(defun reorg-user--clone-file ()
  (interactive)
  (reorg-open-main-window
   '( :group "tmp.org"
      :sources ((org . "~/tmp/tmp.org"))
      :overrides ((reorg-level . (or .org-level 1)))
      :format-results (.stars " " .headline)
      :post-overrides ((reorg-branch . t)))))

(defun reorg-test--at-names ()
  (interactive)
  (reorg-open-main-window
   '( :sources ((org . "~/.emacs.d/lisp/reorg/TESTS/new.org"))
      :children (( :group .@at-names
		   :format-results
		   (.stars " " .headline))))))

(defun reorg-test--tag-list ()
  (interactive)
  (reorg-open-main-window
   '(
     :sources ((org . "~/.emacs.d/lisp/reorg/TESTS/new.org"))
     :format-string (.stars " " .headline)
     :children (( :group .@tag-list
		  :sort-groups (lambda (a b)
				 (string< (downcase a)
					  (downcase b)))
		  :children (( :group .@at-names )))))))

(defun reorg-test--file-view ()
  (interactive)
  (reorg-open-main-window
   '(
     :sources ((files . "find ~/Desktop -type f"))
     :children (( :group "By extension"
		  :children (( :group .extension
			       :sort-groups (lambda (a b) (string< (downcase a)
								   (downcase b)))
			       :sort-results (((downcase .filename) . string<))
			       :format-results (.filename)))
		  ( :group "by parent"
		    :children (( :group (when .depth (number-to-string .depth ))
				 :sort-groups string<
				 :format-results (.stars " " .fullname)))))))))



  
(provide 'reorg-test)

