;;; private/rschmukler/functions.el -*- lexical-binding: t; -*-

(defun rschmukler/neotree-project-root-dir-or-current-dir ()
  "Open NeoTree using the project root, using projectile, or the
current buffer directory."
  (interactive)
  (let ((project-dir (ignore-errors (projectile-project-root)))
        (file-name (buffer-file-name))
        (neo-smart-open t))
    (if (neo-global--window-exists-p)
        (neotree-hide)
      (progn
        (neotree-show)
        (if project-dir
            (neotree-dir project-dir))
        (if file-name
            (neotree-find file-name))))))

(defun wc/switch-to-mru-buffer ()
  "Switches to the most recently used buffer, including visible buffers."
  (interactive)
  (setq current-buffer-name (buffer-name (current-buffer)))
  (setq buffer-candidates (remove-if #'(lambda (buffer) (string-match-p current-buffer-name (buffer-name buffer))) (buffer-list)))
  (wc/do-switch-to-mru-buffer buffer-candidates))


(defun wc/do-switch-to-mru-buffer (buffer-candidates)
  (setq buffer-candidate (car buffer-candidates))
  (setq rest (cdr buffer-candidates))
  (if (string-match-p current-buffer-name (buffer-name buffer-candidate))
      (wc/do-switch-to--buffer rest)
    (if (eq 0 (list-length buffer-candidates))
        (message "No more buffer candidates.")
      (if (wc/file-buffer-p buffer-candidate)
          (switch-to-buffer buffer-candidate)
        (wc/do-switch-to-mru-buffer rest)))))


(defun wc/file-buffer-p (buffer-candidate)
  "Returns t if the buffer argument is backed by a file and is therefore presumably a code buffer."
  (interactive)
  (let ((buff-name (buffer-name buffer-candidate))
        (buff-mode (wc/buffer-major-mode buffer-candidate)))
    (not (or (string-match-p "*" buff-name)
             (member buff-mode '(neotree-mode dired-mode))))))

(defun wc/buffer-major-mode (buffer-handle)
  "Returns a buffer's active major-mode."
  (with-current-buffer buffer-handle major-mode))

(defun wpc/find-or-create-clojure-or-clojurescript-repl ()
  (interactive)
  (require 'projectile)
  (with-current-buffer (current-buffer)
    (let ((buffer-name   (wpc/buffer-name-for-clojure-mode major-mode))
          (repl-function (wpc/repl-function-for-clojure-mode major-mode)))
      (if (get-buffer buffer-name)
          (switch-to-buffer buffer-name)
        (funcall repl-function)))))

(defun wpc/buffer-name-for-clojure-mode (mode)
  (require 'projectile)
  (let* ((project-name (projectile-project-name))
         (cljs-name (concat "*cider-repl CLJS " project-name "*"))
         (clj-name  (concat "*cider-repl " project-name "*")))
    (cond ((eq mode 'clojurescript-mode) cljs-name)
          ((eq mode 'clojure-mode) clj-name)
          ((eq mode 'clojurec-mode) cljs-name))))

(defun wpc/repl-function-for-clojure-mode (mode)
  (require 'projectile)
  (let ((project-name (projectile-project-name))
        (cljs-fn #'cider-jack-in-clojurescript)
        (clj-fn  #'cider-jack-in))
    (cond ((eq mode 'clojurescript-mode) cljs-fn)
          ((eq mode 'clojure-mode) clj-fn)
          ((eq mode 'clojurec-mode) cljs-fn))))

(defun wpc/reindent-defun-and-align-clojure-map ()
  (interactive)
  (call-interactively #'paredit-reindent-defun)
  (call-interactively #'clojure-align))

(defun rs/projectile-switch-project-workspace ()
  "Use projectile prompt to find or switch projects in a workspace tab."
  (interactive)
  (require 'projectile)
  (ivy-read
   (projectile-prepend-project-name "Switch to project: ") projectile-known-projects
   :preselect (and (projectile-project-p)
                   (abbreviate-file-name (projectile-project-root)))
   :action
   (lambda (project-path)
     (let ((project-name
            (file-name-nondirectory
             (directory-file-name (file-name-directory project-path)))
            ))
       (progn
         (if (+workspace-exists-p project-name)
             (+workspace-switch project-name)
           (progn (+workspace-switch project-name t)
                  (counsel-projectile-switch-project-action project-path)))
         (+tmux/run (concat "tt " project-name)))))))

(defun urbint/format-haskell-source ()
  (interactive)
  (let ((output-buffer (generate-new-buffer "brittany-out"))
        (config-file-path
         (concat (string-trim
                  (shell-command-to-string "stack path --project-root"))
                 "/brittany.yaml")))
    (when (= 0 (call-process-region
                (point-min) (point-max)
                "stack"
                nil output-buffer nil
                "exec" "--" "brittany" "--config-file" config-file-path))
      (let ((pt (point))
            (wst (window-start))
            (formatted-source (with-current-buffer output-buffer
                                (buffer-string))))
        (erase-buffer)
        (insert formatted-source)
        (goto-char pt)
        (set-window-start nil wst)))))
