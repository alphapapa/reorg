;; -*- lexical-binding: t;-*-

(defface reorg-actions-face '((t ( :foreground "black"
				   :background "orange")))
  "reorg mark overlay face")

(defvar reorg-actions--overlay-stack nil
  "overlay stack")

(defun reorg-actions-clear-overlays ()
  "clear all overlays"
  (interactive)
  (cl-loop for overlay in reorg-actions--overlay-stack
	   do (delete-overlay overlay)
	   finally do (setq reorg-actions--overlay-stack nil)))

(defun reorg-actions--map-marks (func)
  "run FUN at each mark, then clear the marks."
  (prog1 (cl-loop for overlay in reorg-actions--overlay-stack
		  do (goto-char (overlay-start overlay))
		  and collect (funcall func))
    (reorg-actions-clear-overlays)))

(defun reorg-actions-mark-entry ()
  "mark the current entry"
  (interactive)
  (if (reorg--at-leaf-p)
      (let ((overlay (reorg-action--draw-overlay)))
	(push overlay reorg-actions--overlay-stack)
	(forward-line)
	(run-hooks 'reorg--navigation-hook))
    (message "You can't mark a branch.")))

(defun reorg-action--draw-overlay ()
  "draw a mark overlay"
  (let ((overlay (make-overlay (point-at-bol) (point-at-eol))))
    (overlay-put overlay 'font-lock-face 'reorg-actions-face)
    (overlay-put overlay 'reorg t)
    overlay))

(define-key reorg-main-mode-map (kbd "m") #'reorg-actions-mark-entry)
(define-key reorg-main-mode-map (kbd "M") #'reorg-actions-clear-overlays)


(provide 'reorg-actions)



