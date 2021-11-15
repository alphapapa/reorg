;;; -*- lexical-binding: t; -*-

;;; TODO
;;;; deal with disappearing headings 

(defun reorg--goto-next-relative-level (&optional relative-level backward start-level no-error)
  "Goto the next branch that is at RELATIVE-LEVEL up to any branch that is a
lower level than the current branch."
  ;; Outline levels start at 1, so make sure the destination is not out of bounds. 
  (let* ((start-level (or start-level (reorg-outline-level)))
	 (point (point)))
    (cond  ((>= 0 (abs (+ (reorg-outline-level) (or relative-level 0))))
	    (if no-error nil
	      (error "Cannot move to relative-level %d from current level %d"
		     relative-level
		     start-level)))
	   (t
	    (cl-flet ((looking-for (thing)
				   (eq thing 
				       (pcase (or relative-level 0)
					 ((pred (< 0)) 'descendant)
					 ((pred (> 0)) 'ancestor)
					 ((pred (= 0)) 'sibling))))
		      (current-level () (reorg-outline-level))
		      (exit () (progn (setf (point) point) nil))
		      (goto-next () (reorg-tree--goto-next-property-field
				     'reorg-field-type
				     'branch
				     backward)))
	      
	      (cl-loop while (and (goto-next)
				  (if backward (not (bobp)) (not (eobp))))
		       if (if backward
			      (or (and (looking-for 'descendant)
				       (<= (current-level) start-level))
				  (and (looking-for 'sibling)
				       (< (current-level) start-level)))			    
			    (or (and (looking-for 'descendant)
				     (= (current-level) start-level))
				(and (looking-for 'sibling)
				     (< (current-level) start-level))))
		       return (exit)
		       else if (= (current-level)
				  (abs (+ start-level (or relative-level 0))))
		       return point
		       finally (exit)))))))

(defun reorg-into--need-to-make-new-branch? (data &optional point)
  "asdf"
  (let* ((children (reorg-into--get-list-of-child-branches-at-point)))
    (cl-loop with new-result = nil
	     with return = nil
	     for (func . results) in children
	     do (setq new-result (funcall func data))
	     if (and new-result
		     (member new-result results))
	     do (push (cons func new-result) return)
	     else do (push (cons func nil) return)
	     finally return (reverse return))))

(defun reorg-into--get-list-of-sibling-branches-at-point ()
  "Get a list of cons cells in the form (FUNCTION . RESULTS)."
  (save-excursion
    (let ((level (reorg-outline-level))
	  (disable-point-adjustment t))
      (while (reorg--goto-next-relative-level 0 t))
      (cl-loop with alist = nil
	       with current-func = nil
	       do (setq current-func (reorg--get-view-props nil 'reorg-data :grouper-list))
	       and do (setf (alist-get current-func
				       alist nil nil #'equal)			      
			    (append
			     (alist-get current-func
					alist nil nil #'equal)
			     (-list 
			      (reorg--get-view-props nil 'reorg-data :grouper-list-results))))
	       while (reorg--goto-next-relative-level 0)
	       finally return alist))))

(defun reorg-into--get-list-of-child-branches-at-point ()
  "Get a list of cons cells in the form (FUNCTION . RESULTS)."
  (save-excursion
    (let ((level (reorg-outline-level))
	  (disable-point-adjustment t))
      (when (reorg--goto-next-relative-level 1)
	(cl-loop with alist = nil
		 with current-func = nil
		 do (setq current-func (reorg--get-view-props nil 'reorg-data :grouper-list))
		 and do (setf (alist-get current-func
					 alist nil nil #'equal)			      
			      (append
			       (alist-get current-func
					  alist nil nil #'equal)
			       (-list 
				(reorg--get-view-props nil 'reorg-data :grouper-list-results))))
		 while (reorg--goto-next-relative-level 0)
		 finally return alist)))))

(defun reorg-tree--goto-first-sibling-in-current-group ()
  (cl-loop with current = (reorg--get-view-props nil 'reorg-data :branch-predicate)
	   with point = (point)
	   while (and (reorg--goto-next-relative-level 0 'previous)
		      (equal (reorg--get-view-props nil 'reorg-data :branch-predicate)
			     current))
	   do (setq point (point))
	   finally (goto-char point)))

(defun reorg-tree--goto-next-sibling-group (&optional previous)
  "adsf"
  (cl-loop with point = (point)
	   with current = (reorg--get-view-props nil 'reorg-data :branch-predicate)
	   while (reorg--goto-next-relative-level 0 previous)
	   when (not (equal (reorg--get-view-props nil 'reorg-data :branch-predicate)
			    current))
	   return (point)
	   finally return (progn (goto-char point) nil)))

(defun reorg-tree--map-siblings (func &optional pred pred-val test-fn)
  "Map all siblings at point, but restrict it using PRED, PRED-VAL,
and TEST-FN."
  (cl-loop initially (push (funcall func) results)
	   initially (when pred
		       (unless pred-val 
			 (setq pred-val
			       (funcall pred))))
	   with results = nil

	   for backward in '(t nil)
	   do (cl-loop with point = (point)
		       while (and (reorg--goto-next-relative-level 0 backward)
				  (or (not pred)
				      (funcall (or test-fn #'equal )
					       (funcall pred)
					       pred-val)))
		       do (push (funcall func) results)
		       finally (progn (setq results (reverse results))
				      (goto-char point)))
	   finally return results))

(defun reorg-tree--map-current-sibling-group (func)
  (reorg-tree--map-siblings func (lambda ()
				   (reorg--get-view-props nil
							  'reorg-data
							  :branch-predicate))))

(defun reorg-tree--get-current-group-members ()
  (reorg-tree--map-current-sibling-group
   (lambda ()
     (reorg--get-view-props nil 'reorg-data :branch-name))))

(defun reorg-tree--map-siblings-by-group (func)
  (reorg-tree--with-wide-buffer
   (cl-loop with results = nil
	    do (push (reorg-tree--map-siblings
		      func
		      (lambda ()
			(reorg--get-view-props nil
					       'reorg-data
					       :branch-predicate)))
		     results)
	    while (reorg-tree--goto-next-sibling-group)
	    finally return results)))

(defun reorg-tree--get-sibling-group-markers ()
  "Get the markers for the starting point of each
sibling group."
  (reorg-tree--with-wide-buffer
   (cl-loop with results = nil
	    do (push (point-marker)
		     results)
	    while (reorg-tree--goto-next-sibling-group)
	    finally return (reverse results))))

(defun reorg-tree--goto-next-property-field (prop val &optional backward pred transformer)
  "Move to the beginning of the next field of text property PROP that
matches VAL.

If PRED is specified, compare values using PRED instead of `eq'.

If BACKWARD is non-nil, move backward instead of forward. 

TRANSFORMER is an optional function that accepts one argument
(the value of the text property at point) and transforms it before
comparing it to VAL.

For example, if (get-text-property (point) PROP) returns a plist, but you
only want to see if one value is present, the TRANSFORMER:

(lambda (plist) (plist-get plist :interesting-property))

will extract the single value prior to comparing to VAL."
  (let ((func (if backward
		  #'previous-single-property-change
		#'next-single-property-change))
	(limit (if backward
		   (point-min)
		 (point-max)))
	(pred (or pred #'eq))
	(search-invisible t))

    (cl-loop with point = (point)
	     with origin = (point)
	     while point

	     do (setq point (funcall func point (car (-list prop))))
	     
	     if (and (null point)
		     (funcall pred
			      (funcall (or transformer #'identity)
				       (apply #'reorg--get-view-props limit (-list prop)))
			      val))
	     return (goto-char limit)

	     else if (null point)
	     return (progn (goto-char origin) nil)
	     
	     else if (funcall pred
			      val
			      (funcall (or transformer #'identity)
				       (apply #'reorg--get-view-props point (-list prop))))
	     return (goto-char point)

	     else do (forward-char (- point (point))))))

(defun reorg-tree--get-by-branch-predicate (prop val func)
  "Execute FUNC at each branch that has PROP equal to VAL and
make a list of the results."
  (let (results)
    (save-excursion
      (cl-loop with level = (reorg-outline-level)
	       while (and (reorg-tree--goto-next-property-field nil
								'reorg-data val nil #'equal
								(lambda (x) (plist-get x prop)))
			  (> (reorg-outline-level) level))
	       do (cl-pushnew (funcall func) results :test #'equal)))
    (reverse results)))


(defun reorg-tree--branch-insert--find-location (data)
  "insert into the branch at point."
  (save-excursion
    (reorg-tree--goto-first-sibling-in-current-group)
    (let* ((branch-predicate (reorg--get-view-props nil 'reorg-data :branch-predicate))
	   (name (funcall branch-predicate data))
	   (level (reorg-outline-level))
	   (format-string (reorg--get-view-props nil 'reorg-data :format-string))
	   (branch-sorter (reorg--get-view-props nil 'reorg-data :branch-sorter))
	   (branch-sort-getter (reorg--get-view-props nil 'reorg-data :branch-sort-getter))
	   (existing-data (copy-tree (reorg--get-view-props)))
	   (new-data (plist-put existing-data :branch-name name)))

      (if (and branch-sort-getter branch-sorter)
	  (cl-loop when (funcall branch-sorter
				 (funcall branch-sort-getter name)
				 (funcall branch-sort-getter (reorg--get-view-props nil 'reorg-data :branch-name)))
		   return (reorg-tree--branch-insert--insert-heading new-data)
		   while (reorg--goto-next-relative-level 0)
		   finally return (reorg-tree--branch-insert--insert-heading new-data 'after))
	(reorg-tree--branch-insert--insert-heading new-data)))))

;; ;;
(defun reorg-tree--branch-insert--insert-heading (data &optional after)
  "Insert a new branch using DATA at POINT or (point)."
  (let ((disable-point-adjustment t))
    (if after
	(progn (end-of-line) (insert "\n"))
      (beginning-of-line))
    (save-excursion 
      (insert (reorg--create-headline-string data
					     (plist-get data :format-string)
					     (plist-get data :level))
	      (if after "" "\n")))
    (reorg-dynamic-bullets--fontify-heading)
    (point)))

(cl-defun reorg--branch-insert--drop-into-outline (data template)
  (cl-labels
      ((doloop
	(data
	 template
	 &optional (n 0 np)
	 result-sorters
	 grouper-list
	 grouper-list-results
	 format-string
	 (level 1)
	 (before t))
	(let ((grouper `(lambda (x)
			  (reorg--let-plist x
					    ,(plist-get template :group))))
	      (children (plist-get template :children))
	      (heading-sorter (plist-get template :sort))
	      (heading-sort-getter (or (plist-get template :sort-getter)
				       #'car))
	      (format-string (or (plist-get template :format-string)
				 format-string
				 reorg-headline-format))
	      (result-sort (plist-get template :sort-results)))
	  (when result-sort
	    (setq result-sorters
		  (append result-sorters					  
			  (cl-loop for (form . pred) in result-sort
				   collect (cons `(lambda (x)
						    (reorg--let-plist x
								      ,form))
						 pred)))))
	  (let ((name (funcall grouper data))
		(members (reorg-tree--get-current-group-members)))
	    (when name
	      (if (member name members)
		  (unless (equal name (reorg--get-view-props nil 'reorg-data :branch-name))
		    (reorg-tree--goto-next-property-field 'reorg-data name
							  nil #'equal (lambda (x) (plist-get x :branch-name))))
		(if (and heading-sort-getter heading-sorter members)
		    (cl-loop with new-data = `( :name ,name
						:branch-name ,name
						:heading-sorter ,heading-sorter
						:heading-sort-getter ,heading-sort-getter
						:format-string ,format-string
						:level ,level
						:reorg-branch t
						:branch-predicate ,grouper)		  
			     when (funcall heading-sorter
					   (funcall heading-sort-getter name)
					   (funcall heading-sort-getter (reorg--get-view-props nil 'reorg-data :branch-name)))
			     return (reorg-tree--branch-insert--insert-heading new-data)
			     while (reorg--goto-next-relative-level 0)
			     finally return (reorg-tree--branch-insert--insert-heading new-data))
		  (reorg-tree--branch-insert--insert-heading `( :name ,name
								:branch-name ,name
								:heading-sorter ,heading-sorter
								:heading-sort-getter ,heading-sort-getter
								:format-string ,format-string
								:level ,level
								:reorg-branch t
								:branch-predicate ,grouper)
							     (not before))))	  
	      (if children 
		  (cl-loop 
		   with before = nil
		   for x below (length children)
		   for marker in (save-excursion
				   (setq before (reorg--goto-next-relative-level 1))
				   (reorg-tree--get-sibling-group-markers))
		   do (goto-char marker)
		   and do (doloop
			   data
			   (nth x children)
			   x
			   result-sorters
			   nil
			   nil
			   format-string
			   (1+ level)
			   before))
		(reorg--insert-into-leaves data
					   result-sorters
					   (if before (1+ level) level)
					   format-string)
		(redraw-display)
		

		))))))


    (goto-char (point-min))
    (doloop data template)))

(provide 'reorg-tree)
;;;; there 
;;; new drop into
;;;; Is HEADING present?
;;;; make a new HEADLINE
;;;; insert HEADLINE at LOCATION
;;;; 

(cl-defun reorg--drop-into (data template)
  (cl-labels ((doloop
	       (data
		template
		&optional (n 0 np)
		result-sorters
		grouper-list
		grouper-list-results
		format-string
		(level 1)
		(before t))
	       (let ((grouper `(lambda (x)
				 (reorg--let-plist x
						   ,(plist-get template :group))))
		     (children (plist-get template :children))
		     (heading-sorter (plist-get template :sort))
		     (heading-sort-getter (or (plist-get template :sort-getter)
					      #'car))
		     (format-string (or (plist-get template :format-string)
					format-string
					reorg-headline-format))
		     (result-sort (plist-get template :sort-results)))
		 (when result-sort
		   (setq result-sorters
			 (append result-sorters					  
				 (cl-loop for (form . pred) in result-sort
					  collect (cons `(lambda (x)
							   (reorg--let-plist x
									     ,form))
							pred)))))
		 (let ((name (funcall grouper data))
		       (members (reorg-tree--get-current-group-members))
		       (current-level (reorg-outline-level)))
		   (when name
		     (if (member name members)
			 (unless (equal name (reorg--get-view-props nil 'reorg-data :branch-name))
			   (reorg-tree--goto-next-property-field 'reorg-data name
								 nil #'equal (lambda (x) (plist-get x :branch-name))))
		       (if (and heading-sort-getter heading-sorter members)
			   (cl-loop with new-branch = `( :name ,name
							 :branch-name ,name
							 :heading-sorter ,heading-sorter
							 :heading-sort-getter ,heading-sort-getter
							 :format-string ,format-string
							 :level ,level
							 :reorg-branch t
							 :branch-predicate ,grouper)		  
				    when (funcall heading-sorter
						  (funcall heading-sort-getter name)
						  (funcall heading-sort-getter (reorg--get-view-props nil 'reorg-data :branch-name)))
				    return (reorg-tree--branch-insert--insert-heading new-branch)
				    while (reorg--goto-next-relative-level 0)
				    finally return (reorg-tree--branch-insert--insert-heading new-branch))
			 (reorg-tree--branch-insert--insert-heading `( :name ,name
								       :branch-name ,name
								       :heading-sorter ,heading-sorter
								       :heading-sort-getter ,heading-sort-getter
								       :format-string ,format-string
								       :level ,level
								       :reorg-branch t
								       :branch-predicate ,grouper)
								    (not before))))	  
		     (if children 
			 (cl-loop 
			  with before = nil
			  for x below (length children)
			  for marker in (save-excursion
					  (setq before (reorg--goto-next-relative-level 1))
					  (reorg-tree--get-sibling-group-markers))
			  do (goto-char marker)
			  and do (doloop
				  data
				  (nth x children)
				  x
				  result-sorters
				  nil
				  nil
				  format-string
				  (1+ level)
				  before))
		       (reorg--insert-into-leaves data
						  result-sorters
						  (if before (1+ level) level)
						  format-string)
		       (redraw-display)
		       

		       ))))))


    (goto-char (point-min))
    (doloop data template)))
