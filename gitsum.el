;;; gitsum.el --- basic darcsum feelalike for Git
;; Copyright (C) 2008  Christian Neukirchen <purl.org/net/chneukirchen>
;; Licensed under the same terms as Emacs.

;; Repository: http://github.com/chneukirchen/gitsum
;;              git://github.com/chneukirchen/gitsum.git
;; Patches to: chneukirchen@gmail.com

;; Version: 0.2
;; 04feb2008  +chris+

(eval-when-compile (require 'cl))

(easy-mmode-defmap gitsum-diff-mode-shared-map
  '(("c" . gitsum-commit)
    ("u" . gitsum-undo)
    ("g" . gitsum-refresh))
  "Basic keymap for `gitsum-diff-mode', bound to various prefix keys.")

(define-derived-mode gitsum-diff-mode diff-mode "gitsum"
  "Git summary mode is for preparing patches to a Git repository.
This mode is meant to be activated by `M-x gitsum' or pressing `s' in git-status.
\\{gitsum-diff-mode-map}"
  ;; magic...
  (lexical-let ((ro-bind (cons 'buffer-read-only gitsum-diff-mode-shared-map)))
    (add-to-list 'minor-mode-overriding-map-alist ro-bind))
  (setq buffer-read-only t))

(define-key gitsum-diff-mode-map (kbd "C-c C-c") 'gitsum-commit)
(define-key gitsum-diff-mode-map (kbd "C-/") 'gitsum-undo)
(define-key gitsum-diff-mode-map (kbd "C-_") 'gitsum-undo)

;; When git.el is loaded, hack into keymap.
(when (boundp 'git-status-mode-map)
  (define-key git-status-mode-map "s" 'gitsum))

;; Undo doesn't work in read-only buffers else.
(defun gitsum-undo ()
  "Undo some previous changes.
Repeat this command to undo more changes.
A numeric argument serves as a repeat count."
  (interactive)
  (let ((inhibit-read-only t))
    (undo)))

(defun gitsum-refresh ()
  "Regenerate the patch based on the current state of the index."
  (interactive)
  (let ((inhibit-read-only t))
    (erase-buffer)
    (insert "# Directory:  " default-directory "\n")
    (insert "# Use n and p to navigate and k to kill a hunk.  u is undo, g will refresh.\n")
    (insert "# Edit the patch as you please and press 'c' to commit.\n\n")
    (let ((diff (shell-command-to-string "git diff")))
      (if (zerop (length diff))
          (insert "## No changes. ##")
        (insert diff)))
    (set-buffer-modified-p nil)
    (goto-char (point-min))))

(defun gitsum-commit ()
  "Commit the patch as-is, asking for a commit message."
  (interactive)
  (shell-command-on-region (point-min) (point-max) "git apply --check --cached")
  (let ((buffer (get-buffer-create "*gitsum-commit*")))
    (shell-command-on-region (point-min) (point-max) "(cat; git diff --cached) | git apply --stat" buffer)
    (with-current-buffer buffer
      (goto-char (point-min))
      (insert "\n")
      (while (re-search-forward "^" nil t)
        (replace-match "# " nil nil))
      (forward-line 0)
      (forward-char -1)
      (delete-region (point) (point-max))
      (goto-char (point-min)))
    (log-edit 'gitsum-do-commit nil nil buffer)))

(defun gitsum-do-commit ()
  "Perform the actual commit using the current buffer as log message."
  (interactive)
  (with-current-buffer log-edit-parent-buffer
    (shell-command-on-region (point-min) (point-max)
                             "git apply --cached"))
  (shell-command-on-region (point-min) (point-max)
                           "git commit -F- --cleanup=strip")
  (with-current-buffer log-edit-parent-buffer
    (gitsum-refresh)))

(defun gitsum ()
  "Entry point into gitsum-diff-mode."
  (interactive)
  (switch-to-buffer (generate-new-buffer "*gitsum*"))
  (gitsum-diff-mode)
  (gitsum-refresh))