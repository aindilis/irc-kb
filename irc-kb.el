(global-set-key "\C-ciklu" 'irc-kb-list-urls-by-user)

(defun irc-kb-list-urls-by-user ()
 ""
 (interactive)
 (let ((agent (cmh-choose-agent)))
  (freekbs2-push-onto-stack
   (kmax-grep-list-regexp 
    (split-string
     (shell-command-to-string
      (concat "/var/lib/myfrdcsa/codebases/minor/irc-kb/scripts/list-urls-by-agent.pl " (shell-quote-argument agent)))
     "\n")
    ".")
   nil
   t))
 (freekbs2-view-ring))
  
