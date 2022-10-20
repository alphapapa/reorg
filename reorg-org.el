;; -*- lexical-binding: t; -*-

;;; syncing macro

(defmacro reorg--with-source-and-sync (&rest body)
  "Execute BODY in the source buffer and
update the heading at point."
  (declare (indent defun))
  `(progn
     (let (data)
       (reorg-view--tree-to-source--goto-heading)
       (org-with-wide-buffer
	(org-back-to-heading)
	,@body
	(setq data (reorg--parser nil 'org)))
       (reorg--select-tree-window)
       (reorg--map-id (alist-get 'id data)
		      (reorg-views--delete-leaf)
		      (reorg-views--delete-headers-maybe))
       (save-excursion 
	 (reorg--branch-insert--drop-into-outline data
						  reorg-current-template)))))

;;; parsing functions 

(defun reorg--ts-hhmm-p (ts)
  (string-match (rx (or (seq (** 1 2 digit)
			     ":"
			     (= 2 digit))
			(seq (** 1 2 digit)
			     (or "am"
				 "pm"
				 "AM"
				 "PM"))))
		ts))

(defun reorg--format-time-string (ts no-time-format &optional time-format)
  (format-time-string
   (if (reorg--ts-hhmm-p ts)
       (or time-format no-time-format)
     no-time-format)
   (org-read-date nil t ts )))


(defun reorg-parser--get-property-drawer ()
  "asdf"
  (save-excursion
    (org-back-to-heading)
    (let (seen-base props)
      (while (re-search-forward org-property-re (org-entry-end-position) t)
	(let* ((key (upcase (match-string-no-properties 2)))
	       (extendp (string-match-p "\\+\\'" key))
	       (key-base (if extendp (substring key 0 -1) key))
	       (value (match-string-no-properties 3)))
	  (cond
	   ((member-ignore-case key-base org-special-properties))
	   (extendp
	    (setq props
		  (org--update-property-plist key value props)))
	   ((member key seen-base))
	   (t (push key seen-base)
	      (let ((p (assoc-string key props t)))
		(if p (setcdr p (concat value " " (cdr p)))
		  (unless (or (null key)
			      (equal "" key)
			      (equal "PROPERTIES" key)
			      (equal "END" key))
		    (setq props (append (list
					 (reorg--add-remove-colon (intern (downcase key)))
					 value)
					props)))))))))
      props)))

(defun reorg--timestamp-parser (&optional inactive range)
  "Find the fist timestamp in the current heading and return it. 
if INACTIVE is non-nil, get the first inactive timestamp.  If 
RANGE is non-nil, only look for timestamp ranges."
  (save-excursion
    (cl-loop while (re-search-forward (pcase `(,inactive ,range)
					(`(nil t)
					 org-tr-regexp)
					(`(nil nil)
					 org-ts-regexp)
					(`(t nil)
					 org-ts-regexp-inactive)
					(`(t t)
					 (concat 
					  org-ts-regexp-inactive
					  "--?-?"
					  org-ts-regexp-inactive)))
				      (org-entry-end-position)
				      t)
	     when (save-match-data (not (eq (car (org-element-at-point))
					    'planning)))
	     return (org-no-properties (match-string 0)))))

(defun reorg--get-body ()
  "get headings body text"
  (org-element-interpret-data
   (org-element--parse-elements (save-excursion (org-back-to-heading)
						(org-end-of-meta-data t)
						(point))
				(or (save-excursion (outline-next-heading))
				    (point-max))
				'first-section nil nil nil nil)))

(defmacro reorg--with-point-at-orig-entry (id buffer &rest body)
  "Execute BODY with point at the heading with ID at point."
  `(when-let ((id (or ,id (reorg--get-view-prop :id))))
     (with-current-buffer (or ,buffer (reorg--get-view-prop :buffer))
       (reorg--with-restore-state
	(goto-char (point-min))
	;; NOTE: Can't use `org-id-goto' here or it will keep the
	;;       buffer open after the edit.  Getting the buffer
	;;       and searching for the ID should ensure the buffer
	;;       stays hidden.  It also avoids using `org-id'
	;;       for anything other than ID generation. 
	(save-match-data
	  (if (re-search-forward id)
	      (progn 
		,@body)
	    (error "Heading with ID %s not found." id)))))))

(defmacro reorg--with-restore-state (&rest body)
  "do BODY while saving, excursion, restriction, etc."
  (declare (debug (body)))
  `(save-excursion
     (save-restriction       
       (widen)
       (let ((inhibit-field-text-motion t))
	 ,@body))))

;;; org custom data type

(reorg-create-class-type
 :name org
 :keymap (("h" . (lambda (&optional arg)					   
		   (interactive)
		   (reorg--with-source-and-sync 
		     (org-edit-headline (read-string "New headline: "
						     (org-get-heading t t t t))))))
	  ("t" . (lambda (&optional arg) (interactive "P")
		   (reorg--with-source-and-sync
		     (funcall-interactively #'org-todo arg))))
	  ("a" . (lambda (&optional arg) (interactive "P")
		   (reorg--with-source-and-sync
		     (funcall-interactively #'org-set-tags-command arg))))
	  ("d" . (lambda (&optional arg) (interactive "P")
		   (reorg--with-source-and-sync
		     (funcall-interactively #'org-deadline arg))))
	  ("s" . (lambda (&optional arg) (interactive "P")
		   (reorg--with-source-and-sync
		     (funcall-interactively #'org-schedule arg))))
	  ("r" . (lambda (&optional arg) (interactive )
		   (reorg--with-source-and-sync
		     (funcall-interactively #'org-set-property))))
	  ("i" . (lambda (&optional arg) (interactive "P")
		   (reorg--with-source-and-sync
		     (funcall-interactively #'org-priority arg))))
	  ("g" . (lambda (&optional arg) (interactive)
		   (reorg--with-source-and-sync))))
 :getter (with-current-buffer (find-file-noselect SOURCE)
	   (widen)
	   (org-show-all)
	   (org-map-entries
	    #'PARSER)))

(reorg-create-data-type
 :name headline
 :class org
 ;; :set (lambda ()
 ;;        (let ((val (field-string-no-properties)))
 ;; 	 (reorg--with-source-and-sync val
 ;; 	   (org-edit-headline val))))
 ;; :face org-level-3
 :parse (->> (org-no-properties
	      (org-get-heading t t t t))
	     (replace-regexp-in-string reorg-org--org-link-regexp "")
	     (s-trim)
	     (s-replace " \\." "")))

(reorg-create-data-type
 :name ts
 :class org
 :parse (or
	 (org-entry-get (point) "DEADLINE")
	 (when (reorg--timestamp-parser)
	   (org-no-properties (reorg--timestamp-parser)))
	 (when (reorg--timestamp-parser nil t)
	   (org-no-properties (reorg--timestamp-parser nil t))))
 :display (if-let ((ts (alist-get 'ts alist)))
	      (if (=
		   (string-to-number
		    (format-time-string "%Y"))
		   (ts-year (ts-parse-org ts)))
		  (reorg--format-time-string ts
					     "%a, %b %d"
					     "%a, %b %d at %-l:%M%p")
		(reorg--format-time-string ts
					   "%a, %b %d, %Y"
					   "%a, %b %d, %Y at %-l:%M%p"))
	    ""))

(reorg-create-data-type
 :name ts-type
 :class org
 :parse (cond 
	 ((org-entry-get (point) "DEADLINE") "deadline")
	 ((reorg--timestamp-parser) "active")
	 ((org-no-properties (reorg--timestamp-parser nil t)) "range")
	 ((org-entry-get (point) "SCHEDULED") "scheduled"))
 :display (pcase (alist-get 'ts-type alist)
	    ("deadline" "≫")
	    ("active" "⊡")
	    ("range" "➥")
	    ("scheduled" "⬎")
	    (_ " ")))

(reorg-create-data-type :name priority
			:class org
			:parse (org-entry-get (point) "PRIORITY")
			:display (pcase (alist-get 'priority alist)
				   ("A" "⚡")
				   ("B" "➙")
				   ("C" "﹍")
				   (_ " ")))

;; (reorg-create-data-type :name body
;; 			:class org
;; 			:parse (reorg--get-body))

(reorg-create-data-type :name deadline
			:class org
			:parse (org-entry-get (point) "DEADLINE")
			;; :set (lambda ()
			;;        (reorg--with-source-and-sync
			;; 	 (if val (org-deadline nil val)
			;; 	   (org-deadline '(4)))))
			;; :display (if (plist-get plist :deadline)
			;; 	     (concat 
			;; 	      (propertize "DEADLINE: "

			;; 			  'font-lock-face 'org-special-keyword)
			;; 	      (propertize (plist-get plist :deadline)
			;; 			  'font-lock-face 'org-date))
			;; 	   "__________")
			:display (when (alist-get 'deadline alist)
				   (string-pad 
				    (ts-format "%B %e, %Y" ;
					       (ts-parse-org (alist-get 'deadline alist)))
				    18
				    nil t)))

(reorg-create-data-type :name scheduled
			:class org 
			:parse (org-entry-get (point) "SCHEDULED")
			;; :set (lambda ()
			;;        (reorg--with-source-and-sync
			;; 	 (if val (org-scheduled nil val)
			;; 	   (org-scheduled '(4)))))
			:display (if (alist-get 'scheduled alist)
				     (concat 
				      (propertize "SCHEDULED: "

						  'font-lock-face 'org-special-keyword)
				      (propertize (alist-get 'scheduled alist)
						  'font-lock-face 'org-date))
				   "__________"))

(reorg-create-data-type :name headline
			:class org
			;; :set (lambda ()
			;;        (let ((val (field-string-no-properties)))
			;; 	 (reorg--with-source-and-sync val
			;; 	   (org-edit-headline val))))
			;; :face org-level-3
			:display (alist-get 'headline alist)
			:parse (s-replace
				
				(org-no-properties
				 (org-get-heading t t t t)))

;; (reorg-create-data-type
;;  :name property
;;  :class org
;;  :parse (reorg-parser--get-property-drawer)
;;  ;; :set (lambda ()
;;  ;;        (reorg--with-source-and-sync
;;  ;; 	 (let* ((pair (split-string val ":" t " "))
;;  ;; 		(key (upcase (car pair)))
;;  ;; 		(val (cadr pair)))
;;  ;; 	   (org-set-property key val))))
;;  :display (let* ((key (reorg--add-remove-colon (car args) t))
;; 		 (val (plist-get (plist-get plist :property)
;; 				 (reorg--add-remove-colon key))))
;; 	    (concat
;; 	     (propertize (format "%s:" key) 'font-lock-face 'org-special-keyword)
;; 	     " "
;; 	     (propertize (format "%s" val) 'font-lock-face 'org-property-value))))
;; ;; :field-keymap (("C-c C-x p" . org-set-property)))

(reorg-create-data-type
 :name tags
 :class org
 :parse (org-get-tags-string))
;; :get (org-get-tags-string)
;; :set (org-set-tags val)
;; :face org-tag-group
;; :heading-keymap (("C-c C-c" . org-set-tags-command)))

(reorg-create-data-type
 :name todo
 :class org
 :parse (org-entry-get (point) "TODO")
 ;; :get (org-entry-get (point) "TODO")			
 ;; :set (org-todo val)
 :display (when-let ((s (alist-get 'todo alist)))
	    (propertize
	     s
	     'font-lock-face
	     (org-get-todo-face s))))
;; :heading-keymap (("C-c C-t" . org-todo)
;; 		  ("S-<right>" . org-shiftright)
;; 		  ("S-<left>" . org-shiftleft)))

(reorg-create-data-type
 :name timestamp
 :class org
 :parse (when (reorg--timestamp-parser)
	  (org-no-properties (reorg--timestamp-parser)))
 ;; :get (reorg--timestamp-parser)
 ;; :set (if-let* ((old-val (reorg--timestamp-parser)))
 ;; 	 (when (search-forward old-val (org-entry-end-position) t)
 ;; 	   (replace-match (concat val)))
 ;;        (when val
 ;; 	 (org-end-of-meta-data t)
 ;; 	 (insert (concat val "\n"))
 ;; 	 (delete-blank-lines)))
 :display
 (if (alist-get 'timestamp alist)
     (concat 
      (propertize (alist-get 'timestamp alist)
		  'font-lock-face 'org-date))
   "____"))
;; :field-keymap (("S-<up>" . org-timestamp-up)
;; 		("S-<down>" . org-timestamp-down))
;; :header-keymap (("C-c ." . org-time-stamp))
;; :validate (with-temp-buffer
;; 	     (insert val)
;; 	     (beginning-of-buffer)
;; 	     (org-timestamp-change 0 'day)
;; 	     (buffer-string)))

(defvar reorg-org--org-link-regexp
  (rx
   "[["
   (group (+? not-newline))
   "]["
   (group (+? not-newline))
   "]]")
  "Org link regexp.")

(defun reorg-org--link-parser ()
  "the first link in the current heading and return an alist."
  (save-excursion 
    (let ((limit (or (save-excursion (when (re-search-forward
					    org-heading-regexp
					    nil t)
				       (point)))
		     (point-max))))
      (when (re-search-forward
	     reorg-org--org-link-regexp
	     limit
	     t)
	(list 
	 (cons 'link (match-string-no-properties 1))
	 (cons 'text (match-string-no-properties 2)))))))

(reorg-create-data-type :name link
			:class org
			:parse (reorg-org--link-parser))

(reorg-create-data-type :name link-file-name
			:class org
			:parse (when-let* ((data (reorg-org--link-parser))
					   (path (alist-get 'link data))
					   (name (f-filename path)))
				 (car (s-split "::" name))))

(reorg-create-data-type :name link-file-path
			:class org
			:parse (when-let* ((data (reorg-org--link-parser))
					   (data (alist-get 'link data))
					   (data (cadr (s-split (rx (one-or-more alnum)
								    ":/")
								data)))
					   (data (car (s-split "::" data))))
				 (concat "/" data)))

(reorg-create-data-type :name timestamp-ia
			:class org
			:parse (when (reorg--timestamp-parser t)
				 (org-no-properties (reorg--timestamp-parser t))))
;; :get (reorg--timestamp-parser t)
;; :set (if-let* ((old-val (reorg--timestamp-parser t)))
;; 	 (when (search-forward old-val (org-entry-end-position) t)
;; 	   (replace-match (concat val)))
;;        (when val
;; 	 (org-end-of-meta-data t)
;; 	 (insert (concat val "\n"))
;; 	 (delete-blank-lines)))
;; :face org-date
;; :field-keymap (("S-<up>" . org-timestamp-up)
;; 		("S-<down>" . org-timestamp-down))
;; :header-keymap (("C-c ." . org-time-stamp))
;; :validate (with-temp-buffer
;; 	     (insert val)
;; 	     (beginning-of-buffer)
;; 	     (org-timestamp-change 0 'day)
;; 	     (buffer-string)))

(reorg-create-data-type :name timestamp-ia-range
			:class org
			:parse (when (reorg--timestamp-parser t t)
				 (org-no-properties (reorg--timestamp-parser t t))))
;; :get (reorg--timestamp-parser t)
;; :set (if-let* ((old-val (reorg--timestamp-parser t)))
;; 	 (when (search-forward old-val (org-entry-end-position) t)
;; 	   (replace-match (concat val)))
;;        (when val
;; 	 (org-end-of-meta-data t)
;; 	 (insert (concat val "\n"))
;; 	 (delete-blank-lines)))
;; :face org-date
;; :keymap (("S-<up>" . org-timestamp-up)
;; 	 ("S-<down>" . org-timestamp-down))
;; :validate (with-temp-buffer
;; 	    (insert val)
;; 	    (beginning-of-buffer)
;; 	    (org-timestamp-change 0 'day)
;; 	    (buffer-string)))

(reorg-create-data-type :name timestamp-range
			:class org
			:parse (when (reorg--timestamp-parser nil t)
				 (org-no-properties (reorg--timestamp-parser nil t))))
;; :get (reorg--timestamp-parser t)
;; ;; :set (if-let* ((old-val (reorg--timestamp-parser t)))
;; ;; 	 (when (search-forward old-val (org-entry-end-position) t)
;; ;; 	   (replace-match (concat val)))
;; ;;        (when val
;; ;; 	 (org-end-of-meta-data t)
;; ;; 	 (insert (concat val "\n"))
;; ;; 	 (delete-blank-lines)))
;; :face org-date
;; :keymap (("S-<up>" . org-timestamp-up)
;; 	 ("S-<down>" . org-timestamp-down))
;; :validate (with-temp-buffer
;; 	    (insert val)
;; 	    (beginning-of-buffer)
;; 	    (org-timestamp-change 0 'day)
;; 	    (buffer-string))
;; :disabled nil)

(reorg-create-data-type :name id
			:class org
			:parse (org-id-get-create))

(reorg-create-data-type :name category-inherited
			:class org
			:parse (org-entry-get-with-inheritance "CATEGORY"))

(reorg-create-data-type :name category
			:class org
			:parse (org-get-category))
;; :set (org-set-property "CATEGORY" val))

(reorg-create-data-type :name filename
			:class org
			:parse (buffer-file-name))

(reorg-create-data-type :name buffer-name
			:class org
			:parse (buffer-name))

(reorg-create-data-type :name buffer
			:class org
			:parse (current-buffer))

(reorg-create-data-type :name order
			:class org
			:parse (point))


(reorg-create-data-type :name level
			:class org
			:parse (org-current-level)
			:display (number-to-string (alist-get 'level alist)))

;; (reorg-create-data-type :name root
;; 			:class org
;; 			:parse (save-excursion (while (org-up-heading-safe))
;; 					       (org-no-properties
;; 						(org-get-heading t t t t))))
(reorg-create-data-type
 :name root-ts-inactive
 :class org
 :parse (save-excursion (cl-loop while (org-up-heading-safe)
				 when (reorg--timestamp-parser t nil)
				 return (reorg--timestamp-parser t nil))))

(provide 'reorg-org)
