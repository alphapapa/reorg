;; -*- lexical-binding: t; -*-

;;; requires

(eval-when-compile
  (require 'cl-lib))
(require 'outline)
(require 'org)
(require 'org-agenda) ;; needed for `org-with-remote-undo'
(require 'seq)
(require 'let-alist)
(require 'dash)
(require 's)
(require 'org-visual-indent nil t)

;;; constants

(defconst reorg--data-property-name 'reorg-data)

(defconst reorg--field-property-name 'reorg-field-type)

(defconst reorg--valid-template-keys '(:sources
				       :group
				       :children
				       :overrides
				       :post-overrides
				       :sort-results
				       :bullet
				       :format-results
				       :sort-groups)
  "Allowable template keys.")

;;; customs

(defcustom reorg-toggle-shortcut "C-; r"
  "shortcut to open tree side window")

(defcustom reorg-parser-use-id-p t
  "use id or markers?")

(defcustom reorg-buffer-name "*REORG*"
  "Default buffer name for tree view window.")

(defcustom reorg-buffer-side 'left
  "Which side for the tree buffer?")

(defcustom reorg-face-text-prop 'font-lock-face
  "When setting a face, use this text property.")

(defcustom reorg-headline-format '(.stars " " .headline)
  "Default headline format.")

(defcustom reorg-default-bullet  "->" "")

(defcustom reorg-default-face 'default "")

(defcustom reorg-default-result-sort nil "")

;;; variables 

(defvar reorg--field-property-name 'reorg-field-name "")

(defvar reorg--extra-prop-list nil "")

(defvar reorg--grouper-action-function
  #'reorg--create-headline-string
  "")

(defvar reorg--current-template nil
  "the current template in this buffer")

(defvar reorg--current-sources nil
  "the current template in this buffer")

(defvar reorg--navigation-hook nil
  "Post-navigation hook.")

(defvar reorg--extra-prop-list nil "")

(defvar reorg--getter-list nil "")

(defvar reorg--parser-list nil "")

(defvar reorg--render-func-list nil "")

;;; reorg requires

(require 'reorg-dynamic-bullets)

;;; reorg data types

(defun reorg--create-symbol (&rest args)
  "Create a symbol from ARGS which can be
numbers, strings, symbols."
  (cl-loop for arg in args
	   if (stringp arg)
	   concat arg into ret
	   else if (numberp arg)
	   concat (number-to-string arg) into ret
	   else if (symbolp arg)
	   concat (symbol-name arg) into ret
	   finally return (intern ret)))

;; (defun reorg--get-parser-func-name (class name)
;;   "Create `reorg--CLASS--parse-NAME' symbol."
;;   (reorg--create-symbol 'reorg--
;; 			class
;; 			'--parse-
;; 			name))

(defun reorg--get-display-func-name (class name)
  "Create `reorg--CLASS--display-NAME' symbol."
  (reorg--create-symbol 'reorg--
			class
			'--display-
			name))


(cl-defmacro reorg-create-class-type (&key name
					   getter
					   follow
					   keymap
					   extra-props
					   render-func
					   display-buffer)
  "Create a new class type"
  (let ((func-name (reorg--create-symbol 'reorg--
					 name
					 '--get-from-source)))
    `(progn
       (defun ,func-name
	   (&rest sources)
	 (cl-flet ((PARSER (&optional d)
			   (reorg--parser d ',name)))
	   (cl-loop
	    for SOURCE in sources
	    append ,getter)))
       (if (boundp 'reorg--getter-list)
	   (setf (alist-get ',name reorg--getter-list) nil)
	 (defvar reorg--getter-list nil "Getter list for all classes"))
       (cl-pushnew  #',func-name
		    (alist-get ',name reorg--getter-list))
       (if (boundp 'reorg--parser-list)
	   (setf (alist-get ',name reorg--parser-list) nil)
	 (defvar reorg--parser-list nil "Parser list for all classes."))     
       (cl-pushnew (cons 'class (lambda (&optional _ __) ',name))
		   (alist-get ',name reorg--parser-list))
       ;; (setf (alist-get ',name reorg--parser-list)
       ;; 	   (cons 'class (lambda () ',(name)))
       (setf (alist-get ',name reorg--extra-prop-list)
	     ',extra-props)
       (when ',keymap
	 (setf (alist-get ',name reorg--extra-prop-list)
	       (append (alist-get ',name reorg--extra-prop-list)
		       (list 
	     		'keymap
			',(let ((map (make-sparse-keymap)))
			    (cl-loop for (key . func) in keymap
				     collect (define-key map (kbd key) func))
			    map)))))
       (when ',render-func
	 (setf (alist-get ',name reorg--render-func-list)
	       ',render-func)))))

(cl-defmacro reorg-create-data-type (&optional ;
				     &key
				     class
				     name
				     parse
				     disable
				     display
				     append)
  "Create a new class"
  (let* ((parsing-func (reorg--create-symbol 'reorg--
					     class
					     '--parse-
					     name))
	 (display-func (reorg--create-symbol 'reorg--
					     class
					     '--display-
					     name)))
    `(progn
       (cond ((not ,disable)
	      (defun ,parsing-func (&optional data DATA)
		(let-alist DATA 
		  ,parse))
	      (setf (alist-get ',class reorg--parser-list)
		    (assoc-delete-all ',name
				      (alist-get
				       ',class
				       reorg--parser-list)))
	      (if ',append		     
		  (setf (alist-get ',class reorg--parser-list)
			(append (alist-get ',class reorg--parser-list)
				(list 
				 (cons ',name #',parsing-func))))
		(cl-pushnew (cons ',name #',parsing-func)
			    (alist-get ',class reorg--parser-list)))
	      (if ',display 
		  (defun ,display-func (data)
		    (let-alist data 
		      ,display))
		(fmakunbound ',display-func)))
	     (t ;;if disabled 
	      (setf (alist-get ',class reorg--parser-list)
		    (assoc-delete-all ',name
				      (alist-get ',class reorg--parser-list)))
	      (fmakunbound ',display-func)
	      (fmakunbound ',parsing-func))))))

;;; Reorg modules 

(require 'reorg-org)
(require 'reorg-files)
(require 'reorg-leo)
(require 'reorg-email)
(require 'reorg-elisp)

;;; completion at point function

(require 'reorg-completion)

;;; testing require

(require 'reorg-test)

;;; code 

;;;; window control

(defun reorg--open-side-window ()
  "Open a side window to display the tree."
  (display-buffer-in-side-window (get-buffer-create reorg-buffer-name)
				 `((side . ,reorg-buffer-side)
				   (dedicated . t)
				   (slot . nil)
				   (window-parameters . ((reorg . t)))))
  (reorg--select-tree-window)
  ;; TODO figure out a dwim method of setting sidebar size
  ;; or make it a defcustom. See `reorg--get-longest-line-length'
  ;; It's apparently tricky to calculate the length of a line that
  ;; includes :align-to display text props and includes fonts of a different
  ;; height.  There must be an easier way.
  ;; For now, balance the windows
  ;; (setf (window-width) 150))
  (balance-windows))

(defun reorg--select-main-window (&optional buffer)
  "Select the source window. If BUFFER is non-nil,
switch to that buffer in the window." 
  (select-window (window-main-window))
  (when buffer
    (switch-to-buffer buffer)))

(defun reorg--select-tree-window ()
  "Select the tree window."
  (when-let ((window (--first 
		      (window-parameter it 'reorg)
		      (window-at-side-list nil reorg-buffer-side))))
    (select-window window)))

(defun reorg--render-source ()
  "Render the heading at point."
  (when-let ((func (alist-get
		    (reorg--get-view-prop 'class)
		    reorg--render-func-list)))
    (funcall func)
    (when (reorg--buffer-in-side-window-p)
      (reorg--select-tree-window))))

(defun reorg--goto-source ()
  "Goto rendered source buffer."
  (interactive)
  (reorg--render-source)
  (when (reorg--buffer-in-side-window-p)
    (reorg--select-main-window)))

;;;; Tree buffer functions 

(defun reorg--insert-all (data)
  "Insert grouped and sorted data into outline."
  (let (results)
    (cl-labels ((recurse (data)
			 (cond ((stringp data)
				(insert data))
			       (data (cl-loop for entry in data
					      do (recurse entry))))))
      (recurse data))))

(defun reorg--get-all-sources-from-template (template)
  "Walk the template tree and make a list of all unique template
sources.  This is used for updating the reorg tree, e.g., as part
of an org-capture hook to make sure the captured entry belongs to
one of the sources."
  (cl-labels ((get-sources (template)
			   (append (cl-loop for each in template
					    when (plist-get each :sources)
					    append (plist-get each :sources)
					    append (get-sources (plist-get template :children)))
				   (plist-get template :sources))))
    (-uniq (get-sources template))))


;;;###autoload
(defun reorg-open-in-current-window (&optional template point)
  "open the reorg buffer here"
  (interactive)
  (reorg-open (or template reorg--current-template) point)
  (set-window-buffer nil reorg-buffer-name))

;;;###autoload
(defun reorg-open-sidebar (&optional template point)
  "open reorg in sidebar"
  (interactive)
  (reorg-open (or template reorg--current-template) point)
  (reorg--open-side-window)
  (reorg--select-tree-window))

(defun reorg-open (template &optional point)
  "Open this shit in the sidebar."
  (interactive)
  (when (get-buffer reorg-buffer-name)
    (kill-buffer reorg-buffer-name))
  (with-current-buffer (get-buffer-create reorg-buffer-name)
    (erase-buffer)
    (reorg--insert-all
     (reorg--get-group-and-sort nil template 1 nil))
    (setq reorg--current-sources
	  (reorg--get-all-sources-from-template template)
	  reorg--current-template
	  template)
    (reorg-mode)
    (goto-char (or point (point-min)))
    (run-hooks 'reorg--navigation-hook)))

;;;; Tree buffer movement 

(defun reorg--move-to-next-entry-follow ()
  "move to next entry"
  (interactive)
  (reorg--goto-next-visible-heading)
  (reorg--render-source)
  (reorg--select-tree-window)
  (run-hooks 'reorg--navigation-hook))

(defun reorg--move-to-previous-entry-follow ()
  "move to previous entry"
  (interactive)
  (reorg--goto-previous-visible-heading)
  (reorg--render-source)
  (reorg--select-tree-window)
  (run-hooks 'reorg--navigation-hook))

(defun reorg--move-to-next-entry-no-follow ()
  "next entry"
  (interactive)
  (reorg--goto-next-visible-heading)
  (reorg--render-source)
  (reorg--select-tree-window)
  (run-hooks 'reorg--navigation-hook))

(defun reorg--move-to-previous-entry ()
  "move to previous entry"
  (interactive)
  (reorg--goto-previous-visible-heading)
  (run-hooks 'reorg--navigation-hook))

(defun reorg--move-to-next-entry ()
  "next entry"
  (interactive)
  (reorg--goto-next-visible-heading)
  (run-hooks 'reorg--navigation-hook))

(defun reorg--move-to-previous-entry-no-follow ()
  "previous entry"
  (interactive)
  (reorg--goto-previous-visible-heading)
  (reorg--render-source)
  (reorg--select-tree-window)
  (run-hooks 'reorg--navigation-hook))


;;;; NEW WINDOW SELECTOR

(defun reorg--buffer-in-side-window-p ()
  "Is the reorg buffer in a side window?"
  (cl-loop for window in (window-at-side-list nil reorg-buffer-side)
	   when (window-parameter window 'reorg)
	   return window))
;; (--first 
;;  (window-parameter it 'reorg)
;;  ))

(defun reorg--select-window-run-func-maybe (window &optional func switch-back)
  "WINDOW is either 'main or 'tree. FUNC is a function with no args."
  (when-let ((win
	      (seq-find
	       (lambda (x)
		 (window-parameter x 'reorg))
	       (window-at-side-list nil reorg-buffer-side))))
    (pcase window
      ('tree (progn (reorg--select-tree-window)
		    (funcall func)
		    (when switch-back
		      (reorg--select-main-window))))
      ('main (progn (funcall func)
		    (when switch-back
		      (reorg--select-tree-window)))))))

(defun reorg--render-maybe ()
  "maybe render if we are in a tree window."
  (reorg--select-window-run-func-maybe 'main #'reorg--render-source t))


;;;; updating the tree

(defun reorg-reload ()
  "reload the current template"
  (interactive)
  (if (reorg--buffer-in-side-window-p)
      (reorg-open-sidebar nil (point))
    (reorg-open-in-current-window nil (point))))

(defun reorg--buffer-p ()
  "Are you in the reorg buffer?"
  (string= (buffer-name)
	   reorg-buffer-name))

(defvar reorg-main-mode-map 
  (let ((map (make-keymap)))
    (suppress-keymap map)
    (define-key map (kbd "RET") #'reorg--goto-source)
    (define-key map (kbd "u") #'reorg--goto-parent)
    (define-key map (kbd "<left>") #'reorg--goto-parent)
    (define-key map (kbd "g") #'reorg--update-heading-at-point)
    (define-key map (kbd "G") (lambda () (interactive)
				(reorg--close-tree-buffer)
				(kill-buffer reorg-buffer-name)
				(save-excursion (reorg-open-main-window
						 reorg--current-template))))
    (define-key map (kbd "c") #'reorg--goto-next-clone)
    (define-key map (kbd "R") #'reorg-reload)
    (define-key map (kbd "f") #'reorg--goto-next-sibling)
    (define-key map (kbd "b") #'reorg--goto-previous-sibling)
    (define-key map (kbd "C") #'reorg--goto-previous-clone)
    (define-key map (kbd "U") #'reorg--goto-next-parent)
    (define-key map [remap undo] #'org-agenda-undo)
    (define-key map (kbd "q") #'bury-buffer)
    (define-key map (kbd "n") #'reorg--move-to-next-entry)
    (define-key map (kbd "<down>") #'reorg--move-to-next-entry)
    (define-key map (kbd "p") #'reorg--move-to-previous-entry)
    (define-key map (kbd "<up>") #'reorg--move-to-previous-entry)
    (define-key map (kbd "TAB") #'outline-cycle)
    (define-key map (kbd "<backtab>") #'outline-cycle-buffer)
    (define-key map (kbd "l") #'recenter-top-bottom)
    map)
  "keymap")

(defun reorg--close-tree-buffer ()
  "Close the tree buffer."
  (interactive)
  (let* ((window (seq-find
		  (lambda (x)
		    (window-parameter x 'reorg))
		  (window-at-side-list nil reorg-buffer-side)))
	 (buffer (window-buffer window)))
    (mapc #'delete-window (seq-filter (lambda (x) (window-parameter x 'reorg))
				      (window-at-side-list nil reorg-buffer-side)))))

(defun reorg--toggle-tree-buffer ()
  "toggle tree buffer"
  (interactive)
  (if (seq-find
       (lambda (x)
	 (window-parameter x 'reorg))
       (window-at-side-list nil reorg-buffer-side))
      (reorg--close-tree-buffer)
    (reorg--open-side-window)
    (reorg--select-tree-window)))

(define-derived-mode reorg-mode
  fundamental-mode
  "Reorg"
  "Reorganize your life. \{keymap}"
  (setq cursor-type nil)
  (use-local-map reorg-main-mode-map)
  (reorg-dynamic-bullets-mode)
  (if (fboundp #'org-visual-indent-mode)
      (org-visual-indent-mode)
    (org-indent-mode))
  (toggle-truncate-lines 1)
  (setq-local cursor-type nil)
  ;; (reorg--map-all-branches #'reorg--delete-headers-maybe)  
  (add-hook 'reorg--navigation-hook #'org-show-context nil t)  
  (add-hook 'reorg--navigation-hook #'reorg-edits--update-box-overlay nil t)
  (add-hook 'reorg--navigation-hook #'reorg--render-maybe nil t)
  (global-set-key (kbd reorg-toggle-shortcut) #'reorg--toggle-tree-buffer)
  (goto-char (point-min))
  (run-hooks 'reorg--navigation-hook))

(defvar reorg-edits--current-field-overlay
  (let ((overlay (make-overlay 1 2)))
    (overlay-put overlay 'face `( :box (:line-width -1)
				  :foreground ,(face-foreground 'default)))
    (overlay-put overlay 'priority 1000)
    overlay)
  "Overlay for field at point.")

;;;; field navigation 

(defun reorg--unfold-at-point (&optional point)
  "Unfold so the heading at point is visible."
  (save-excursion 
    (reorg--goto-parent)
    (outline-show-subtree)
    (goto-char point)
    (outline-show-subtree)
    (goto-char point)))

(let ((point nil))
  (defun reorg-edits--update-box-overlay ()
    "Tell the user what field they are on."
    (unless (= (point) (or point 0))
      (when-let ((field (get-text-property (point) reorg--field-property-name)))
	(delete-overlay reorg-edits--current-field-overlay)
	(move-overlay reorg-edits--current-field-overlay
		      (car (reorg-edits--get-field-bounds))
		      (let ((inhibit-field-text-motion t))
			(if (= (point) (point-at-bol))
			    (point-at-eol)
			  (cdr (reorg-edits--get-field-bounds))))))
      (setq point (point)))))

;;;; utilities

(defun reorg--add-number-suffix (num)
  "create the suffix for a number"
  (pcase (if (numberp num) 
	     (number-to-string num)
	   num)
    ((pred (s-ends-with-p "11")) "th")
    ((pred (s-ends-with-p "12")) "th")
    ((pred (s-ends-with-p "13")) "th")
    ((pred (s-ends-with-p "1")) "st")
    ((pred (s-ends-with-p "2")) "nd")
    ((pred (s-ends-with-p "3")) "rd")
    (_ "th")))

(defun reorg--add-remove-colon (prop &optional remove)
  "PROP is a symbol with or without a colon prefix.
Returns PROP with a colon prefix. If REMOVE is t,
then return PROP with no colon prefix."
  (pcase `(,remove ,(keywordp prop))
    (`(t t) (intern (substring (symbol-name prop) 1)))
    (`(nil nil) (intern (concat ":" (symbol-name prop))))
    (_ prop)))

(defun reorg-edits--get-field-bounds ()
  "Get the bounds of the field at point."
  (let ((match (save-excursion (text-property--find-end-forward
				(point)
				'reorg-data
				(reorg--get-view-prop)
				#'equal))))
    (cons
     (prop-match-beginning match)
     (prop-match-end match))))

;;;; finding functions

(defun reorg--get-view-prop (&optional property point)
  "Get PROPERTY from the current heading.  If PROPERTY
is omitted or nil, get the 'reorg-data' prop.  If it is
supplied, get that property from 'reorg-data'."
  (let ((props (get-text-property (or point (point)) 'reorg-data)))
    (if property
	(alist-get property props)
      props)))

;; (defun reorg--get-view-props (&optional point &rest props)
;;   "Get text property PROPS at point. If there are multiple PROPS,
;; get nested properties."
;;   (cl-labels ((get-props (props &optional payload)
;; 			 (if props 
;; 			     (let ((props (if (listp props) props (list props))))
;; 			       (if (not payload)
;; 				   (->> (get-text-property (or point (point)) (car props))
;; 					(get-props (cdr props)))
;; 				 (->> (alist-get (car props) payload)
;; 				      (get-props (cdr props)))))
;; 			   payload)))
;;     (if props 
;; 	(get-props props)
;;       (let ((inhibit-field-text-motion t))
;; 	(reorg--get-view-prop nil (or point (point)))))))

(defun reorg--goto-next-prop (property &optional
				       value
				       limit
				       predicate
				       visible-only)
  "Aassume we are getting 'reorg-data and PROPERTY is the key of that alist.
DOES NOT RUN 'reorg--navigation-hooks'." 
  (cond
   ((eobp)
    nil)
   ((if limit
	(> (point) limit)
      (= (point) (point-max)))
    nil)
   (t    
    (let ((origin (point))
          (ended nil)
	  (limit (or limit (point-max)))
          pos)
      (cl-loop with found = nil
	       while (not ended)
	       do (setq pos (next-single-property-change
			     (point)
			     'reorg-data nil limit))
	       if (or (not pos)		
		      (> pos limit))
	       return
	       (progn (reorg--goto-char origin)
		      (run-hooks 'reorg--navigation-hook)
		      (setq ended t)
		      nil)
	       else do
	       (progn (goto-char pos)
		      (if (and (< (point) limit)
			       (if visible-only
				   (not (org-invisible-p (point) t))
				 t)
			       (funcall (or predicate #'equal)
					value
					(if property 
					    (alist-get property 
						       (get-text-property
							(point)
							'reorg-data))
					  (get-text-property (point)
							     'reorg-data))))
			  (progn 
			    (setq ended t)
			    (setq found t))
			(when (or (not pos)
				  (>= pos limit))
			  (goto-char origin)
			  (setq ended t))))
	       finally return (if (not found)
				  nil
				(point)))))))

(defun reorg--goto-previous-prop (property &optional value limit
					   predicate visible-only)
  "See 'reorg--goto-next-prop'"
  (cond
   ((bobp)
    nil)
   ((< (point) (or limit (point-min)))
    nil)
   (t    
    (let ((origin (point))
          (ended nil)
	  (limit (or limit (point-min)))
          pos)
      (cl-loop with found = nil
	       with pos = nil 
	       while (not ended)
	       do (setq pos
			(previous-single-property-change
			 (point)
			 'reorg-data
			 nil
			 limit))
	       if (or (not pos)		
		      (< pos limit))
	       return
	       (progn (reorg--goto-char origin)
		      (setq ended t)
		      nil)
	       else do
	       (progn (goto-char pos)
		      (if (and (>= (point) limit)
			       (funcall
				(or predicate #'equal)
				value
				(if property 
				    (alist-get
				     property
				     (get-text-property
				      (point)
				      'reorg-data))
				  (get-text-property
				   (point)
				   'reorg-data)))
			       (if visible-only
				   (not (org-invisible-p (point) t))
				 t))
			  (progn 
			    (setq ended t)
			    (setq found t))
			(when (or (not pos)
				  (bobp)
				  (<= pos limit))
			  (goto-char origin)
			  (setq ended t))))
	       finally return (if (not found)
				  nil
				(point)))))))

(defun reorg--get-previous-prop (property &optional
					  value
					  limit
					  predicate
					  visible-only)
  "Return the point instead of moving it."
  (save-excursion (reorg--goto-previous-prop
		   property
		   value
		   limit
		   predicate
		   visible-only)))

(defun reorg--get-next-prop (property &optional
				      value
				      limit
				      predicate
				      visible-only)
  "get next instead of moving it."
  (save-excursion (reorg--goto-next-prop
		   property
		   value
		   limit
		   predicate
		   visible-only)))

(defun reorg--goto-char (point)
  "Goto POINT and run hook funcs."
  (goto-char point)
  (run-hooks 'reorg--navigation-hook)
  (point))

;;; Navigation commands 

(defmacro reorg--create-navigation-commands (alist)
  "Create navigation commands. ALIST is a list in the form of (NAME . FORM)
where NAME is the name of what you are moving to, e.g., \"next-heading\"
and FORM is evaluated to see if that target exists.

This creates two functions: reorg--get-NAME and reorg--goto-NAME."
  `(progn 
     ,@(cl-loop
	for (name . form) in alist
	append (list `(defun ,(reorg--create-symbol 'reorg--goto- name)
			  (&optional no-update)
			,(concat "Move point to "
				 (s-replace "-" " " (symbol-name name))
				 " and run navigation hook.")
			(interactive)
			(when-let ((point ,form))
			  (if no-update
			      (goto-char point)
			    (reorg--goto-char point))))
		     `(defun ,(reorg--create-symbol 'reorg--get- name) nil
			,(concat "Get the point of "
				 (s-replace "-" " " (symbol-name name))
				 ".")
			,form)))))

(reorg--create-navigation-commands
 ((next-heading . (reorg--get-next-prop
		   nil
		   nil
		   nil
		   (lambda (a b) t)))
  (next-visible-heading . (reorg--get-next-prop
			   nil
			   nil
			   nil
			   (lambda (a b) t) t))
  (previous-heading . (reorg--get-previous-prop
		       nil
		       nil
		       nil
		       (lambda (a b) t)))
  (next-branch . (reorg--get-next-prop
		  'reorg-branch
		  t
		  nil
		  nil
		  nil))
  (next-visible-branch . (reorg--get-next-prop
			  'reorg-branch
			  t
			  nil
			  nil
			  t))
  (previous-visible-heading . (reorg--get-previous-prop
			       nil
			       nil
			       nil
			       (lambda (a b) t) t))
  (next-sibling . (reorg--get-next-prop
		   'reorg-level
		   (reorg--get-view-prop 'reorg-level)
		   (reorg--get-next-prop 'reorg-level
					 (reorg--get-view-prop
					  'reorg-level)
					 nil
					 (lambda (a b)
					   (< b a)))))
  (previous-sibling . (reorg--get-previous-prop
		       'reorg-level
		       (reorg--get-view-prop 'reorg-level)
		       (reorg--get-previous-prop
			'reorg-level
			(reorg--get-view-prop 'reorg-level)
			nil
			(lambda (a b) (< b a)))))
  (next-clone . (reorg--get-next-prop
		 'id
		 (reorg--get-view-prop 'id)))
  (previous-clone . (reorg--get-previous-prop
		     'id
		     (reorg--get-view-prop 'id)))
  (next-parent . (reorg--get-next-prop
		  'reorg-level
		  (reorg--get-view-prop 'reorg-level)
		  nil
		  (lambda (a b) (> a b))))
  (parent . (reorg--get-previous-prop
	     'reorg-level
	     (1- (reorg--get-view-prop 'reorg-level))))
  (root . (and (/= 1 (reorg--get-view-prop 'reorg-level))
	       (reorg--get-previous-prop 'reorg-level 1)))
  (next-child . (and
		 (reorg--get-view-prop
		  'reorg-branch)
		 (reorg--get-next-prop
		  'reorg-level
		  (1+ (reorg--get-view-prop 'reorg-level))
		  (reorg--get-next-prop
		   'reorg-level
		   (reorg--get-view-prop 'reorg-level)
		   nil
		   (lambda (a b)
		     (>= a b))))))
  (next-visible-child . (and
			 (reorg--get-view-prop 'reorg-branch)
			 (reorg--get-next-prop
			  'reorg-level
			  (1+ (reorg--get-view-prop 'reorg-level))
			  (reorg--get-next-prop
			   'reorg-level
			   (reorg--get-view-prop 'reorg-level)
			   nil
			   (lambda (a b)
			     (>= a b)))
			  nil
			  t)))))

(defun reorg-list-modules ()
  "Let the modules available."
  (interactive)
  (cl-loop for (module . parsers) in reorg--parser-list
	   collect module))

(defun reorg-list-data-types ()
  "list data types for a given module"
  (interactive)
  (let ((module
	 (completing-read "Select module: " (reorg-list-modules))))
    (cl-loop for (name . func) in (alist-get (intern module)
					     reorg--parser-list)
	     collect name into results
	     finally (message (format "%s" results)))))
(defun reorg--get-longest-line-length ()
  "get longest line length"
  (save-excursion
    (goto-char (point-min))
    (cl-loop until (eobp)
	     collect (reorg--line-length) into lengths
	     do (forward-line)
	     finally return (apply #'max lengths))))

(defun reorg--line-length ()
  "get the line length including align-to"
  (interactive)
  (save-excursion 
    (goto-char (line-beginning-position))
    (let ((point (point))
	  (start (point))
	  (length 0)
	  found)
      (cl-loop while (and (setq point (next-single-property-change
				       (point)
				       'display
				       nil
				       (line-end-position)))
			  (/= (line-end-position) point))
	       do (progn 
		    (setq found t)
		    (let ((l (- point start)))
		      (if-let* ((display (get-char-property point 'display))
				(align-to (plist-get (cdr display) :align-to)))
			  (if (< l align-to)
			      (progn 
				(cl-incf length align-to)
				(setq start point)
				(setf (point) point))
			    (cl-incf length l)
			    (setf start point)
			    (setf (point) point))
			(setf start point)
			(setf (point) point)
			(cl-incf length l))))
	       finally (cl-incf length (- (line-end-position) (point))))
      (unless found
	(setq length (- (line-end-position)
			(line-beginning-position))))
      length)))

(defun reorg--sort-by-list (a b seq &optional predicate list-predicate)
  "Provide a sequence SEQ and return the earlier of A or B."
  (let ((a-loc (seq-position seq a (or list-predicate #'equal)))
	(b-loc (seq-position seq b (or list-predicate #'equal))))
    (cond
     ((and (null a-loc) (null b-loc)) nil)
     ((null a-loc) nil)
     ((null b-loc) t)
     (t (funcall (or predicate #'<) a-loc b-loc)))))

(defun reorg--turn-at-dot-to-dot (elem &rest _ignore)
  "turn .@symbol into .symbol."
  (if (and (symbolp elem)
	   (string-match "\\`\\.@" (symbol-name elem)))
      (intern (concat "." (substring (symbol-name elem) 2)))
    elem))

(defmacro reorg--create-string-comparison-funcs ()
  "string<, etc., while ignoring case."
  `(progn 
     ,@(cl-loop for each in '("<" ">" "=" )
		collect `(defun ,(intern (concat "reorg-string" each)) (a b)
			   ,(concat "like string" each " but ignore case")
			   (,(intern (concat "string" each))
			    (if a (downcase a) "")
			    (if b (downcase b) ""))))))

(reorg--create-string-comparison-funcs)

(defun reorg-views--delete-leaf ()
  "delete the heading at point"
  (delete-region (point-at-bol)
		 (line-beginning-position 2)))

(defmacro reorg--map-id (id &rest body)
  "Execute BODY at each entry that matches ID."
  `(org-with-wide-buffer 
    (goto-char (point-min))
    (let ((id ,id))
      (while (reorg--goto-next-prop 'id id)
	,@body))))

(defun reorg--map-all-branches (func)
  "map all"
  (save-excursion 
    (goto-char (point-min))
    (while (reorg--goto-next-branch)
      (funcall func))))

(defun reorg--delete-headers-maybe ()
  "delete headers at point if it has no children.
assume the point is at a branch." 
  (cl-loop with p = nil
	   if (reorg--get-next-child)
	   return t
	   else
	   do (setq p (reorg--get-parent))
	   do (reorg--delete-header-at-point)
	   if (null p)
	   return t
	   else do (goto-char p)))

(defun reorg--multi-sort (functions-and-predicates sequence)
  "FUNCTIONS-AND-PREDICATES is an alist of functions and predicates.

FUNCTIONS should not be functions.  Use a form that can contain dotted symbols
as used by `let-alist'."
  (seq-sort 
   (lambda (a b)
     (cl-loop for (form . pred) in functions-and-predicates	      
	      unless (equal (funcall `(lambda (a) (let-alist a ,form)) a)
			    (funcall `(lambda (b) (let-alist b ,form)) b))
	      return (funcall pred
			      (funcall `(lambda (a) (let-alist a ,form)) a)
			      (funcall `(lambda (b) (let-alist b ,form)) b))))
   sequence))



(defun reorg--get-group-and-sort (data
				  template
				  level
				  ignore-sources
				  &rest
				  inherited-props)
  "Fetching, grouping, and sorting function to prepare
data to be inserted into buffer."
  (when-let ((invalid-keys
	      (seq-difference 
	       (cl-loop for key in template by #'cddr
			collect key)
	       reorg--valid-template-keys)))
    (error "Invalid keys in entry in tempate: %s" invalid-keys))
  (cl-flet ((get-header-metadata
	     (header groups sorts bullet)
	     (let ((id (org-id-new)))
	       (list
		(cons 'branch-name header)
		(cons 'reorg-branch t)
		(cons 'branch-type 'branch)
		(cons 'result-sorters sorts)
		(cons 'bullet bullet)
		(cons 'reorg-level level)
		(cons 'parent-id (plist-get inherited-props :parent-id))
		(cons 'group-id
		      (md5
		       (concat 
			(pp-to-string (plist-get
				       inherited-props
				       :parent-template))
			(pp-to-string (plist-get inherited-props :header)))))
		(cons 'id id)))))
    (let ((format-results (or (plist-get template :format-results)
			      (plist-get inherited-props :format-results)
			      reorg-headline-format))
	  (result-sorters (or (append (plist-get inherited-props :sort-results)
				      (plist-get template :sort-results))
			      reorg-default-result-sort))
	  (sources (plist-get template :sources))
	  (action-function (or (plist-get inherited-props :action-function)
			       reorg--grouper-action-function))
	  (bullet (or (plist-get template :bullet)
		      (plist-get inherited-props :bullet)))
	  (face (or (plist-get template :face)
		    (plist-get inherited-props :face)
		    reorg-default-face))
	  (group (plist-get template :group))
	  (header-sort (plist-get template :sort-groups))
	  (level (or level 0))
	  results metadata)
      (setq inherited-props (car inherited-props))
      (when (and sources (not ignore-sources))
	(cl-loop for each in sources
		 do (push each reorg--current-sources))
	(setq data (append data (reorg--getter sources))))
      (setq results
	    (pcase group 
	      ((pred functionp)
	       (reorg--seq-group-by group data))
	      ((pred stringp)
	       (list (cons group data)))
	      ((pred (not null))
	       (when-let ((at-dots (seq-uniq 
				    (reorg--at-dot-search
				     group))))
		 (setq data (cl-loop
			     for d in data 
			     append
			     (cl-loop
			      for at-dot in at-dots
			      if (listp (alist-get at-dot d))
			      return
			      (cl-loop for x in (alist-get at-dot d)
				       collect
				       (let ((ppp (copy-alist d)))
					 (setf (alist-get at-dot ppp) x)
					 ppp))
			      finally return data))))
	       (reorg--seq-group-by (reorg--walk-tree
				     group
				     #'reorg--turn-at-dot-to-dot
				     data)
				    data))))
      (if (null results)
	  (cl-loop for child in (plist-get template :children)
		   collect (reorg--get-group-and-sort
			    data
			    child
			    level
			    ignore-sources
			    (list :header nil
				  :parent-id nil
				  :parent-template template
				  :bullet bullet
				  :face face)))
	(when header-sort
	  (setq results 
		(cond ((functionp header-sort)
		       (seq-sort-by #'car
				    header-sort
				    results))
		      (t (seq-sort-by #'car
				      `(lambda (x)
					 (let-alist x
					   ,header-sort))
				      results)))))

	;; If there are children, recurse 
	(cond ((and (plist-get template :children)
		    results)
	       (cl-loop
		for (header . children) in results
		append
		(cons
		 (funcall action-function
			  (setq metadata
				(get-header-metadata header
						     group
						     result-sorters
						     bullet))
			  nil
			  level
			  (list 
			   (cons 'header header)
			   (cons 'bullet bullet)
			   (cons 'reorg-face face)))
		 (cl-loop for child in (plist-get template :children)
			  collect 
			  (reorg--get-group-and-sort			  
			   children
			   child
			   (1+ level)
			   ignore-sources
			   (list :header header
				 :parent-template template
				 :parent-id (alist-get 'id metadata)
				 :bullet bullet
				 :face face))))))
	      ((plist-get template :children)
	       (cl-loop for child in (plist-get template :children)
			collect
			(reorg--get-group-and-sort
			 data
			 child
			 (1+ level)
			 ignore-sources
			 (progn 
			   (setq metadata (get-header-metadata nil
							       group
							       result-sorters
							       bullet))
			   (cl-loop for (key . val) in metadata
				    append (list (reorg--add-remove-colon key)
						 val))))))
	      (t 
	       (cl-loop for (header . children) in results
			append
			(cons				
			 (funcall
			  action-function
			  (setq metadata
				(get-header-metadata header
						     group
						     result-sorters
						     bullet))
			  nil
			  level
			  (plist-get template :overrides)
			  (plist-get template :post-overrides))
			 (list 
			  (cl-loop
			   with
			   children = 
			   (if result-sorters
			       (reorg--multi-sort result-sorters
						  children)
			     children)
			   for result in children
			   collect
			   (funcall
			    action-function
			    (append result
				    (list 
				     (cons 'group-id
					   (alist-get 'id metadata))
				     (cons 'parent-id
					   (alist-get 'id metadata))))
			    format-results
			    (1+ level)
			    (plist-get template :overrides)
			    (plist-get template :post-overrides))))))))))))

(defun reorg--create-headline-string (data
				      format-string
				      &optional
				      level
				      overrides
				      post-overrides)
  "Create a headline string from DATA using FORMAT-STRING as the
template.  Use LEVEL number of leading stars.  Add text properties
`reorg--field-property-name' and  `reorg--data-property-name'."
  (cl-flet ((create-stars (num &optional data)
			  (make-string (if (functionp num)
					   (funcall num data)
					 num)
				       ?*)))
    ;; update the DATA that will be stored in
    ;; `reorg-data'    
    (push (cons 'reorg-level level) data)
    (cl-loop for (prop . val) in overrides
	     do (setf (alist-get prop data)
		      (if (let-alist--deep-dot-search val)
			  (funcall `(lambda ()
				      (let-alist ',data 
					,val)))
			val)))
    (let (headline-text)
      (apply
       #'propertize
       ;; get the headline text 
       (setq headline-text
	     (if (alist-get 'reorg-branch data)
		 (concat (create-stars level)
			 " "
			 (alist-get 'branch-name data)
			 "\n")
	       (let* ((new (reorg--walk-tree
			    format-string
			    #'reorg--turn-dot-to-display-string
			    data))
		      (result (funcall `(lambda (data)
					  (concat ,@new "\n"))
				       data)))
		 result)))
       'reorg-data ;; property1
       (progn (setq data (append data
				 (list
				  (cons 'reorg-headline
					headline-text)
				  (cons 'reorg-class
					(alist-get 'class data))
				  (cons 'parent-id
					(alist-get 'parent-id data))
				  (cons 'reorg-field-type
					(if (alist-get
					     'reorg-branch data)
					    'branch 'leaf)))))
	      (cl-loop for (prop . val) in post-overrides
		       do (setf (alist-get prop data)
				(alist-get prop post-overrides)))
	      data)
       reorg--field-property-name ;; property2
       (if (alist-get 'reorg-branch data)
	   'branch 'leaf)
       (alist-get (alist-get 'class data) ;; extra props 
		  reorg--extra-prop-list)))))

(defun reorg--seq-group-by (func sequence)
  "Apply FUNCTION to each element of SEQUENCE.
Separate the elements of SEQUENCE into an alist using the results as
keys.  Keys are compared using `equal'.  Do not group results
that return nil."
  (seq-reduce
   (lambda (acc elt)
     (let* ((key (if (functionp func)
		     (funcall func elt)
		   (funcall `(lambda (e)
			       (let-alist e ,func))
			    elt)))
	    (cell (assoc key acc)))
       (if cell
	   (setcdr cell (push elt (cdr cell)))
	 (when key
	   (push (list key elt) acc)))
       acc))
   (seq-reverse sequence)
   nil))

(defun reorg--walk-tree (tree func &optional data)
  "apply func to each element of tree and return the results" 
  (cl-labels
      ((walk
	(tree d)
	(cl-loop for each in tree
		 if (listp each)
		 collect (walk each d)
		 else
		 collect (if d
			     (funcall func each d)
			   (funcall func each)))))
    (if (listp tree)
	(walk tree data)
      (if data 
	  (funcall func tree data)
	(funcall func tree)))))

(defun reorg--code-search (func code)
  "Return alist of symbols inside CODE that match REGEXP.
See `let-alist--deep-dot-search'."
  (let (acc)
    (cl-labels ((walk (code)
		      (cond ((symbolp code)
			     (when (funcall func code)
			       (push code acc)))
			    ((listp code)
			     (walk (car code))
			     (walk (cdr code) )))))
      (walk code)
      (cl-delete-duplicates acc))))

(defun reorg--at-dot-search (data)
  "Return alist of symbols inside DATA that start with a `.@'.
Perform a deep search and return a alist of any symbol
same symbol without the `@'.

See `let-alist--deep-dot-search'."
  (cond
   ((symbolp data)
    (let ((name (symbol-name data)))
      (when (string-match "\\`\\.@" name)
	;; Return the cons cell inside a list, so it can be appended
	;; with other results in the clause below.
	(list (intern (replace-match "" nil nil name))))))
   ;; (list (cons data (intern (replace-match "" nil nil name)))))))
   ((vectorp data)
    (apply #'nconc (mapcar #'reorg--at-dot-search data)))
   ((not (consp data)) nil)
   ((eq (car data) 'let-alist)
    ;; For nested ‘let-alist’ forms, ignore symbols appearing in the
    ;; inner body because they don’t refer to the alist currently
    ;; being processed.  See Bug#24641.
    (reorg--at-dot-search (cadr data)))
   (t (append (reorg--at-dot-search (car data))
	      (reorg--at-dot-search (cdr data))))))

(defun reorg--turn-dot-to-display-string (elem data)
  "turn .symbol to a string using a display function."
  (if (and (symbolp elem)
	   (string-match "\\`\\." (symbol-name elem)))
      (let* ((sym (intern (substring (symbol-name elem) 1)))
	     (fu (reorg--get-display-func-name
		  (alist-get 'class data)
		  (substring (symbol-name elem) 1))))
	(cond ((eq sym 'stars)
	       (make-string (alist-get 'reorg-level data) ?*))
	      ((fboundp fu) (funcall fu data))
	      (t
	       (funcall `(lambda ()
			   (let-alist ',data
			     ,elem))))))
    elem))

(defun reorg--goto-next-sibling-same-group (&optional data)
  "goot next sibing same group"
  (let ((id (or
	     (and data (alist-get 'group-id data))
	     (reorg--get-view-prop 'group-id))))
    (reorg--goto-next-prop 'group-id id)))

(defun reorg--goto-next-leaf-sibling ()
  "goto next sibling"
  (reorg--goto-next-prop 'reorg-field-type
			 'leaf
			 (reorg--get-next-parent)))

;;TODO move these into `reorg--create-navigation-commands'
(defun reorg--goto-first-leaf ()
  "goto the first leaf of the current group"
  (reorg--goto-next-prop 'reorg-field-type
			 'leaf
			 (let ((sib (reorg--get-next-sibling))
			       (par (reorg--get-next-parent)))
			   (if (and sib par)
			       (if (< sib par) sib par)
			     (if sib sib par)))))

(defun reorg--goto-id (header &optional group)
  "goto ID that matches the header string"
  (let ((point (point)))
    (goto-char (point-min))
    (if (reorg--goto-next-prop
	 (if group 'group-id 'id)
	 (alist-get (if group 'group-id 'id) header))
	(point)
      (reorg--goto-char point)
      nil)))

(defun reorg--delete-header-at-point ()
  "delete the header at point"
  (delete-region (point-at-bol)
		 (line-beginning-position 2)))

(defun reorg--insert-header-at-point (header-string &optional next-line)
  "insert header at point"
  (when next-line
    (forward-line))
  (save-excursion 
    (insert header-string))
  (reorg-dynamic-bullets--fontify-heading)
  (run-hooks 'reorg--navigation-hook))

(defun reorg--find-header-location-within-groups (header-string)
  "assume the point is on the first header in the group"
  (let-alist (get-text-property 0 'reorg-data header-string)
    (if .sort-groups
	(cl-loop with point = (point)
		 if (equal .branch-name
			   (reorg--get-view-prop 'branch-name))
		 return (point)
		 else if (funcall .sort-groups
				  .branch-name
				  (reorg--get-view-prop 'branch-name))
		 return nil
		 while (reorg--goto-next-sibling-same-group
			(get-text-property 0 'reorg-data header-string))
		 finally return (progn (goto-char point)
				       nil))
      (cl-loop with point = (point)
	       when (equal .branch-name
			   (reorg--get-view-prop 'branch-name))
	       return t
	       while (reorg--goto-next-sibling-same-group
		      (get-text-property 0 'reorg-data header-string))
	       finally return (progn (goto-char point)
				     nil)))))

(defun reorg--find-first-header-group-member (header-data)
  "goto the first header that matches the group-id of header-data"
  (let ((point (point)))
    (if (equal (reorg--get-view-prop 'group-id)
	       (alist-get 'group-id header-data))
	(point)
      (if (reorg--goto-next-prop 'group-id
				 (alist-get 'group-id header-data)
				 (or (reorg--get-next-parent)
				     (point-max)))
	  (point)
	(goto-char point)
	nil))))

(defun reorg--find-leaf-location (leaf-string &optional result-sorters)
  "find the location for LEAF-DATA among the current leaves. put the
point where the leaf should be inserted (ie, insert before)"
  ;; goto the first leaf if at a branch 
  (unless (eq 'leaf (reorg--get-view-prop 'reorg-field-type))
    (if (reorg--goto-first-leaf)
	(when-let ((result-sorters
		    (or result-sorters
			(save-excursion 
			  (reorg--goto-parent)
			  (reorg--get-view-prop 'result-sorters))))) 
	  (let ((leaf-data (get-text-property 0 'reorg-data leaf-string)))
	    (cl-loop
	     with point = (point)
	     when (cl-loop for (func . pred) in result-sorters
			   unless (equal (funcall
					  `(lambda (x) (let-alist x ,func))
					  leaf-data)
					 (funcall
					  `(lambda (x) (let-alist x ,func))
					  (reorg--get-view-prop)))
			   return (funcall pred
					   (funcall
					    `(lambda (x) (let-alist x ,func))
					    leaf-data)
					   (funcall
					    `(lambda (x) (let-alist x ,func))
					    (reorg--get-view-prop))))
	     return (point)
	     while (reorg--goto-next-leaf-sibling)
	     finally (goto-char (line-beginning-position 2)))))
      (reorg--goto-next-heading))))

(defun reorg--get-next-group-id-change ()
  "get next group id change"
  (reorg--get-next-prop 'group-id
			(reorg--get-view-prop)
			nil
			(lambda (a b)
			  (not (equal a b)))))

(defun reorg--update-heading-at-point ()
  "update the current heading"
  (interactive)
  (reorg--insert-new-heading
   (reorg--with-point-at-orig-entry nil
				    nil
				    (reorg--parser
				     nil
				     (reorg--get-view-prop 'class)))
   reorg--current-template))

(defun reorg--insert-new-heading (data template)
  "insert an individual heading"
  (save-excursion 
    (goto-char (point-min))
    (reorg--map-id (alist-get 'id data)
		   (let ((parent (reorg--get-parent)))
		     (reorg-views--delete-leaf)
		     (when parent
		       (goto-char parent)
		       (reorg--delete-headers-maybe))))
    (cl-loop with header-groups = (reorg--get-all-tree-paths
				   (reorg--get-group-and-sort
				    (list data) template 1 t)
				   (lambda (x)
				     (and (listp x)
					  (stringp (car x))
					  (eq
					   'leaf
					   (get-text-property
					    0
					    'reorg-field-type
					    (car x))))))
	     for headers in header-groups
	     do (goto-char (point-min))
	     collect
	     (cl-loop
	      with leaf = (car (last headers))
	      with leaf-props = (get-text-property 0 'reorg-data leaf)
	      for header in (butlast headers)
	      when (eq 'leaf (alist-get 'reorg-field-type leaf-props))
	      do (let* ((header-props (get-text-property 0 'reorg-data header))
			(group-id (alist-get 'group-id header-props))
			(id (alist-get 'id header-props)))
		   (unless (or (reorg--goto-id header-props)
			       (equal id (reorg--get-view-prop 'id)))
		     (if (reorg--find-first-header-group-member header-props)
			 (unless (reorg--find-header-location-within-groups
				  header)
			   (reorg--insert-header-at-point header))
		       (reorg--insert-header-at-point header t))))
	      finally (progn (setq point (point))
			     (when (eq 'leaf (alist-get
					      'reorg-field-type
					      leaf-props))
			       (reorg--find-leaf-location leaf)
			       (reorg--insert-header-at-point leaf))
			     (goto-char point))))
    (org-indent-refresh-maybe (point-min) (point-max) nil))
  (run-hooks 'reorg--navigation-hook))

(defun reorg--get-all-tree-paths (tree leaf-func)
  "Get a list of all paths in tree.
LEAF-FUNC is a function run on each member to determine
whether it terminates the branch.

For example:

(reorg--get-all-tree-paths '((1 (2 (- 3 4 5))
				(6 (7 (- 8 9))
				   (10 (- 11)
                                        (- 12)))))
			   (lambda (x) (eq '- (car x))))
returns:

((1 2 - 3 4 5)
 (1 6 7 - 8 9)
 (1 6 10 - 11)
 (1 6 10 - 12))
"  
  (let (paths)
    (cl-labels ((doloop (tree &optional path)
			(cond ((funcall leaf-func tree)
			       (push (append (reverse path) tree) paths))
			      ((or (stringp (car tree))
				   (numberp (car tree))
				   (symbolp (car tree)))
			       (push (car tree) path)
			       (cl-loop for child in (cdr tree)
					do (doloop child path)))
			      (tree (cl-loop for child in tree
					     do (doloop child path))))))
      (doloop tree)
      (reverse paths))))

;;; parser and getter

(defun reorg--parser (data class &optional type)
  "Call each parser in CLASS on DATA and return
the result.  If TYPE is provided, only run the
parser for that data type."
  (if type
      (cons type 
	    (funcall (alist-get
		      type
		      (alist-get class
				 reorg--parser-list))
		     data))
    (cl-loop with DATA = nil
	     for (type . func) in (alist-get class reorg--parser-list)
	     collect (cons type (funcall func data DATA)) into DATA
	     finally return DATA)))

(defun reorg--getter (sources)
  "Get entries from SOURCES, whih is an alist
in the form of (CLASS . SOURCE)."
  (cl-loop for (class . source) in sources
	   append (funcall (car (alist-get class reorg--getter-list))
			   source)))


(provide 'reorg)
