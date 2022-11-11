;; -*- lexical-binding: t; -*-


(defun reorg-company--get-candidates (arg)
  "Get company candidates."
  (let* ((all-dots (sort
		    (delete-dups 
		     (cl-loop for (class . rest) in reorg--parser-list
			      append 
			      (cl-loop for (type . func)
				       in rest
				       collect
				       (concat "." (symbol-name type)))))
		    #'string<)))
    (if (equal arg "..")
	all-dots
      (let ((target (and (string-match "\\(^\\.\\.?\\)\\(.+\\)" arg)
			 (match-string 2 arg))))
	(if-let ((class (alist-get (intern target) reorg--parser-list)))
	    (sort (cl-loop for (type . func) in class
			   collect (concat "." (symbol-name type))) #'string<) 
	  (let ((root (concat "." (match-string 2 arg))))
	    (cl-remove-if-not (lambda (x) (s-starts-with-p root x))
			      all-dots)))))))

(defun reorg-company (command &optional arg &rest ignored)
  "company backend"
  (cl-case command
    (interactive (company-begin-backend 'reorg-company))
    (prefix
     (and (eq major-mode 'emacs-lisp-mode)
	  (when-let ((sym (thing-at-point 'symbol)))
	    (when (equal "."
			 (substring sym 0 1))
	      sym))))
    (candidates (reorg-company--get-candidates arg))
    (sorted t)
    (no-cache t)))

(add-to-list 'company-backends #'reorg-company)

(provide 'reorg-devel)




