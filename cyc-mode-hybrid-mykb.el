(global-set-key "\C-ccmpP" 'cmh-load-prolog-kb-about-agent)
(global-set-key "\C-ccmps" 'cmh-search-prolog-kbs-about-agents)
(global-set-key "\C-ccmpp" 'cmh-load-subl-kb-about-agent)
(global-set-key "\C-ccmpS" 'cmh-search-subl-kbs-about-agents)

(global-set-key "\C-ccmpd" 'cmh-add-to-agents-dossier)
(global-set-key "\C-ccmpD" 'cmh-add-region-to-agents-dossier)

(global-set-key "\C-ccmpn" 'cmh-push-person-having-irc-alias-fn-onto-tos)


;; could have it automatically pop up the dossiers when people join a
;; channel or are on a channel

;; look at TKB for example dossiers

(defvar cmh-mykb-people-data-dir "<REDACTED>")

(defun cmh-choose-agent ()
 ""
 (interactive)
 (completing-read
  "Agent?: "
  (kmax-directory-files-no-hidden cmh-mykb-people-data-dir)))

(defun cmh-load-subl-kb-about-agent (&optional arg tmp-agent skip-complete-predicate)
 ""
 (interactive "P")
 (let* ((agent (if arg
		(thing-at-point 'symbol)
		(or tmp-agent
		 (cmh-choose-agent))))
	(file (frdcsa-el-concat-dir (list cmh-mykb-people-data-dir agent (concat agent ".subl")))))

  (if (not (file-exists-p file))
   (if (yes-or-no-p (concat "Create new Agent with name " agent "?: "))
    (progn
     (kmax-find-file-or-create-including-parent-directories file)
     (insert "(f \"" agent "-IRCAlias\")\n")
     (insert "(am '(#$isa #$" agent "-IRCAlias #$IRCAlias) #$IRCMt)\n\n"))))
   
  (if (file-exists-p file)
   (progn
    (find-file file)
    (end-of-buffer)
    (unless skip-complete-predicate (flp-complete-from-predicates-in-current-buffer))))))

(defun cmh-search-subl-kbs-about-agents (&optional arg search)
 ""
 (interactive "P")
 (let ((search (or search (read-from-minibuffer "Search?: "))))
  (kmax-search-files
   search
   (kmax-grep-list-regexp
    (kmax-find-name-dired cmh-mykb-people-data-dir ".subl$")
    "[^~]$")
   "*IRC KB Search*")))

(defun cmh-load-prolog-kb-about-agent (&optional arg tmp-agent skip-complete-predicate)
 ""
 (interactive "P")
 (let* ((agent (if arg
		(thing-at-point 'symbol)
		(or tmp-agent
		 (cmh-choose-agent))))
	(file (frdcsa-el-concat-dir (list cmh-mykb-people-data-dir agent (concat agent ".pl")))))

  (if (not (file-exists-p file))
   (if (yes-or-no-p (concat "Create new Agent with name " agent "?: "))
    (progn
     (kmax-find-file-or-create-including-parent-directories file)
     (insert "isa(" agent "_IRCAlias,iRCAlias).\n"))))
  (if (file-exists-p file)
   (progn
    (find-file file)
    (end-of-buffer)
    (unless skip-complete-predicate (flp-complete-from-predicates-in-current-buffer))))))

(defun cmh-search-prolog-kbs-about-agents (&optional arg search)
 ""
 (interactive "P")
 (let ((search (or search (read-from-minibuffer "Search?: "))))
  (kmax-search-files
   search
   (kmax-grep-list-regexp
    (kmax-find-name-dired cmh-mykb-people-data-dir ".pl$")
    "[^~]$")
   "*IRC KB Search*")))

(defun cmh-add-to-agents-dossier ()
 ""
 (interactive)
 ;; search backward for the first timestamp, search forward to the next timestamp
 ;; (re-search-backward "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}")
 (save-excursion
  (re-search-backward "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]")
  (save-excursion
   (re-search-forward "<")
   (set-mark (point))
   (re-search-forward ">")
   (backward-char 1)
   (setq cmh-current-handle-reference (buffer-substring-no-properties (mark) (point))))
  (set-mark (point))
  (forward-char 1)
  (re-search-forward "\\([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]\\|ERC>\\)")
  (beginning-of-line)
  (backward-char 1)
  (setq cmh-current-message (buffer-substring-no-properties (mark) (point)))
  (cmh-add-to-agents-dossier-data cmh-current-handle-reference cmh-current-message)
  (setq cmh-current-handle-reference nil)
  (setq cmh-current-message nil)))

(defun cmh-add-to-agents-dossier-data (handle message)
 (save-excursion
  (cmh-load-prolog-kb-about-agent nil handle t)
  (end-of-buffer)
  (set-mark (point))
  (insert message)
  (comment-region (point) (mark))
  (insert "\n\n")
  (set-mark (point))
  (save-buffer)))

(defun cmh-add-region-to-agents-dossier ()
 ""
 (interactive)
 ;; search backward for the first timestamp, search forward to the next timestamp
 ;; (re-search-backward "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}")
 (save-excursion
  (let* ((contents (buffer-substring-no-properties (mark) (point))))
   (cmh-load-prolog-kb-about-agent)
   (end-of-buffer)
   (set-mark (point))
   (delete-blank-lines)
   (open-line 1)
   (end-of-buffer)
   (insert (concat "\n\n" contents))
   (comment-region (mark) (point))
   (insert "\n")
   (set-mark (point))
   (save-buffer))))

(defun cmh-get-irc-alias-for-current-subl-file ()
 ""
 (interactive)
 (assert (kmax-mode-is-derived-from 'subl-mode))
 (let* ((file-name buffer-file-name)
	(alias (progn
		(string-match "^\\(.*\\)\/\\(.*\\)\.subl$" file-name)
		(substring-no-properties (match-string 2 file-name)))))
  alias))

(defun cmh-push-person-having-irc-alias-fn-onto-tos (&optional arg)
 ""
 (interactive "P")
 (cmh-get-irc-alias-for-current-subl-file)
 (let* ((alias (cmh-get-irc-alias-for-current-subl-file)))
  (freekbs2-push-onto-stack
   (list "#$personHavingIRCAliasFn" (concat "#$" alias "-IRCAlias"))
   arg)))

(provide 'cyc-mode-hybrid-mykb)
