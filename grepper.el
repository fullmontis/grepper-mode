;;;
;;; grepper-mode: A major mode for fast grep searching
;;; Copyright 2020 Andrea Montagna
;;;

;;; @Bug: searching in large directories without many matches will hang the program even with limited results
;;; @Bug: searching for '\"' doesn't work (jumbles up the shell string)
;;; @Todo: make the whole buffer read only except for the first line
;;; @Todo: allow use of base grep

(defconst grepper-version "0.0.1"
  "Current grepper-mode version number")

(defgroup grepper nil
  "Quick grep mode."
  :group 'applications
  :link '(emacs-commentary-link :tag "Help" "grepper"))

(define-derived-mode grepper-mode fundamental-mode "Grepper"
  "Major mode for interactive grep.

First line contains the string to search. Editing it will change the
rest of the buffer with a list of the search results.

\\{grepper-mode-map}"
  (add-hook 'post-self-insert-hook 'grepper-update nil t))

(setq grepper-previous-search "")
(setq grepper-result-number 30)

(defun grepper ()
  (interactive)
  (let ((buffer  (get-buffer-create "*Grepper*")))
    (switch-to-buffer-other-window buffer)
    (grepper-mode)
    (erase-buffer)
    (beginning-of-buffer)
    (open-line 2)
    (forward-line 1)
    (beginning-of-line)
    (insert default-directory)
    (beginning-of-buffer)))

(defun grepper-get-current-grep-line ()
  (save-excursion
    (beginning-of-buffer)
    (buffer-substring-no-properties (line-beginning-position) (line-end-position))))

(defun grepper-cd ()
  (interactive)
  (call-interactively 'cd)
  
  (save-excursion
    (beginning-of-buffer)
    (forward-line 1)
    (delete-region (line-beginning-position) (line-end-position))
    (insert default-directory)))

(defun grepper-open-file (event)
  (interactive "e")
  (let* ((pos (posn-point (event-end event)))
         (file-name (get-text-property pos 'file-name))
         (file-line (get-text-property pos 'file-line))
         (file-column (get-text-property pos 'file-column)))
    (find-file-other-window file-name)
    (goto-line file-line)
    (goto-char (+ (point) file-column))
    (recenter-top-bottom)))

(defun grepper-escape-quotes (string)
  (replace-regexp-in-string "\"" "\\\\\"" string))

(defun grepper-update ()
  (save-excursion
    (let ((current-search (grepper-get-current-grep-line)))
      (if (and (> (length current-search) 2)
               (not (equal grepper-previous-search current-search)))
          (progn
            (setq grepper-previous-search current-search)
            (beginning-of-buffer)
            (if (= (line-end-position) (point-max))
                (progn
                  (end-of-line)
                  (open-line 1)))
            (forward-line 2)
            (delete-region (line-beginning-position) (point-max))
            (let* ((escaped-search (grepper-escape-quotes current-search))
                   (search-result (shell-command-to-string (concat "rg 2>/dev/null -n \"" escaped-search "\" | head -" (number-to-string grepper-result-number)))))
              (if (= (length search-result) 0)
                  (insert "No Results")
                (progn
                  (save-excursion (insert search-result))
                  (while (not (= (point) (point-max)))
                    (let* ((current-line (buffer-substring-no-properties (line-beginning-position)
                                                                         (line-end-position)))
                           (name-start 0)
                           (name-end (string-match-p (regexp-quote ":") current-line))
                           (name-string (substring current-line name-start name-end))
                           (line-num-start (+ name-end 1))
                           (line-num-end (string-match-p (regexp-quote ":") current-line line-num-start))
                           (line-num (string-to-number (substring current-line line-num-start line-num-end)))
                           (search-string-pos (string-match-p (regexp-quote current-search) current-line line-num-end))
                           (map (make-sparse-keymap))
                           (select-overlay (make-overlay (+ (point) search-string-pos) (+ (point) search-string-pos (length current-search)))))
                      
                      (define-key map [mouse-1] 'grepper-open-file);(find-file name-string)(goto-line line-num)))
                      (add-text-properties (point) (+ (point) line-num-end)
                                           '(face button
                                                  mouse-face highlight))
                      (put-text-property (point) (+ (point) line-num-end) 'keymap map)
                      (put-text-property (point) (+ (point) line-num-end) 'file-name name-string )
                      (put-text-property (point) (+ (point) line-num-end) 'file-line line-num )
                      (put-text-property (point) (+ (point) line-num-end) 'file-column (- search-string-pos line-num-end 1))
                      (overlay-put select-overlay 'face '(:background "dodger blue"))
                      (forward-line 1)))))))))))

(provide 'grepper)
