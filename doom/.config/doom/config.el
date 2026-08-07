;;; config.el -*- lexical-binding: t; -*-

(require 'project)

(defvar my/notes-font-family "Inter"
  "Proportional font family used for note prose.")

(defvar my/notes-code-font-family "JetBrains Mono"
  "Monospaced font family used for code in notes.")

(defvar my/notes-text-width 120
  "Fallback note width in columns and the preferred fill column.")

(defvar my/notes-canvas-width-pixels 1200
  "Maximum visual width of the centered note canvas in pixels.")

(defvar my/notes-fd-ignore-patterns '(".*")
  "Glob patterns excluded from notes file-name searches.")

(defvar my/notes-weekly-template "Weekly/Template.md"
  "Weekly template path, relative to the notes vault or absolute.")

(defvar my/notes-tree-sort-mode 'alphabetical
  "Current file sorting mode in the notes Treemacs pane.")

(defvar my/notes-tree--birth-time-cache (make-hash-table :test #'equal)
  "Cached filesystem birth timestamps used by the notes tree sorter.")

(setq doom-theme 'doom-one
      doom-font (font-spec :family "JetBrains Mono" :size 15 :weight 'regular)
      doom-variable-pitch-font (font-spec :family my/notes-font-family :size 15)
      display-line-numbers-type nil
      select-enable-clipboard t
      select-enable-primary nil
      save-interprogram-paste-before-kill t)

(defun my/toggle-light-dark-theme ()
  "Switch smoothly between Doom One's dark and light variants."
  (interactive)
  (setq doom-theme
        (if (eq doom-theme 'doom-one) 'doom-one-light 'doom-one))
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme doom-theme t)
  (message "Theme: %s" doom-theme))

;; The vault path is deliberately machine-local and excluded from dotfiles.
(defvar my/notes-directory nil
  "Absolute path to the private Markdown notes vault.")

(let ((local-config
       (expand-file-name
        "notes-emacs/local.el"
        (or (getenv "XDG_CONFIG_HOME") "~/.config"))))
  (when (file-readable-p local-config)
    (load local-config nil 'nomessage)))

(unless my/notes-directory
  (setq my/notes-directory (expand-file-name "~/Notes")))

(setq my/notes-directory
      (file-name-as-directory (expand-file-name my/notes-directory)))

;; Start in the vault instead of requiring a path argument at launch.
(setq initial-buffer-choice
      (lambda () (dired-noselect my/notes-directory)))

(defun my/notes--require-vault ()
  "Signal a useful error unless the configured vault exists."
  (unless (file-directory-p my/notes-directory)
    (user-error
     "Notes vault does not exist: %s; configure ~/.config/notes-emacs/local.el"
     my/notes-directory)))

;; Teach project.el that the private, non-Git vault is a project.
(cl-defmethod project-root ((project (head my-notes-project)))
  (cdr project))

(defun my/notes-project-try (directory)
  "Return a project object when DIRECTORY belongs to the notes vault."
  (when (file-directory-p my/notes-directory)
    (let ((root (file-name-as-directory (file-truename my/notes-directory)))
          (dir (file-name-as-directory (file-truename directory))))
      (when (or (string-equal dir root)
                (file-in-directory-p dir root))
        (cons 'my-notes-project root)))))

(add-hook 'project-find-functions #'my/notes-project-try)

(defun my/notes-find-file ()
  "Fuzzy-find a file anywhere in the notes vault."
  (interactive)
  (my/notes--require-vault)
  (require 'consult)
  (let ((consult-fd-args
         (append consult-fd-args
                 (mapcan (lambda (pattern)
                           (list "--exclude" pattern))
                         my/notes-fd-ignore-patterns))))
    (+vertico/consult-fd-or-find my/notes-directory)))

(defun my/notes-search ()
  "Live full-text search across the notes vault with ripgrep."
  (interactive)
  (my/notes--require-vault)
  (consult-ripgrep my/notes-directory))

(defun my/notes-tree ()
  "Toggle a Treemacs pane showing only the notes vault."
  (interactive)
  (my/notes--require-vault)
  (require 'treemacs)
  (if-let ((window (treemacs-get-local-window)))
      (with-selected-window window
        (treemacs-quit))
    (let ((default-directory my/notes-directory))
      (treemacs-add-and-display-current-project-exclusively))))

(defun my/notes-tree--alphabetical-p (path-a path-b)
  "Return non-nil when PATH-A sorts before PATH-B alphabetically."
  (string-lessp (downcase path-a) (downcase path-b)))

(defun my/notes-tree--modified-time (path)
  "Return PATH's modification time as a numeric timestamp."
  (float-time
   (file-attribute-modification-time (file-attributes path 'string))))

(defun my/notes-tree--birth-time (path)
  "Return PATH's filesystem birth time as a numeric timestamp."
  (or (gethash path my/notes-tree--birth-time-cache)
      (let ((timestamp
             (with-temp-buffer
               (if (zerop
                    (process-file
                     "stat" nil t nil "--format=%W" "--" path))
                   (string-to-number (buffer-string))
                 0))))
        ;; Some filesystems do not expose birth time; modification time is the
        ;; least surprising fallback for those files.
        (when (zerop timestamp)
          (setq timestamp (my/notes-tree--modified-time path)))
        (puthash path timestamp my/notes-tree--birth-time-cache)
        timestamp)))

(defun my/notes-tree-sorter (path-a path-b)
  "Sort directories alphabetically and notes by the selected file mode."
  (let ((dir-a (file-directory-p path-a))
        (dir-b (file-directory-p path-b)))
    (cond
     ((and dir-a dir-b)
      (my/notes-tree--alphabetical-p path-a path-b))
     (dir-a t)
     (dir-b nil)
     ((eq my/notes-tree-sort-mode 'alphabetical)
      (my/notes-tree--alphabetical-p path-a path-b))
     (t
      (let ((time-a (if (eq my/notes-tree-sort-mode 'updated)
                        (my/notes-tree--modified-time path-a)
                      (my/notes-tree--birth-time path-a)))
            (time-b (if (eq my/notes-tree-sort-mode 'updated)
                        (my/notes-tree--modified-time path-b)
                      (my/notes-tree--birth-time path-b))))
        (if (= time-a time-b)
            (my/notes-tree--alphabetical-p path-a path-b)
          (> time-a time-b)))))))

(defun my/notes-tree-cycle-sort ()
  "Cycle note files through alphabetical, updated, and created ordering."
  (interactive)
  (setq my/notes-tree-sort-mode
        (pcase my/notes-tree-sort-mode
          ('alphabetical 'updated)
          ('updated 'created)
          (_ 'alphabetical)))
  (clrhash my/notes-tree--birth-time-cache)
  (when-let ((window (treemacs-get-local-window)))
    (with-selected-window window
      (treemacs-without-messages (treemacs-refresh))))
  (message "Notes tree files sorted by %s%s"
           my/notes-tree-sort-mode
           (if (eq my/notes-tree-sort-mode 'alphabetical)
               ""
             " (newest first)")))

(after! treemacs
  (setq treemacs-sorting #'my/notes-tree-sorter))

(defun my/notes--open-periodic-note
    (subdirectory filename-format title-format &optional template)
  "Open or create a dated note under SUBDIRECTORY."
  (my/notes--require-vault)
  (let* ((directory (expand-file-name subdirectory my/notes-directory))
         (filename (concat (format-time-string filename-format) ".md"))
         (path (expand-file-name filename directory))
         (new-file (not (file-exists-p path)))
         (template-path
          (and template (expand-file-name template my/notes-directory))))
    (when (and new-file template-path (not (file-readable-p template-path)))
      (user-error "Note template is not readable: %s" template-path))
    (make-directory directory t)
    (find-file path)
    (when (and new-file (= (buffer-size) 0))
      (if template-path
          (insert-file-contents template-path)
        (insert "# " (format-time-string title-format) "\n\n")))))

(defun my/notes-open-daily ()
  "Open or create today's daily note."
  (interactive)
  (my/notes--open-periodic-note
   "Daily" "%Y-%m-%d" "%A, %B %d, %Y"))

(defun my/notes-open-weekly ()
  "Open or create the current ISO week note."
  (interactive)
  (my/notes--open-periodic-note
   "Weekly" "%Y-%m W%V" "Week %V, %G" my/notes-weekly-template))

(defun my/markdown-refresh-inline-images ()
  "Refresh inline image overlays in the current Markdown buffer."
  (interactive)
  (markdown-remove-inline-images)
  (markdown-display-inline-images))

(after! markdown-mode
  (setq markdown-header-scaling t
        markdown-header-scaling-values '(1.80 1.55 1.35 1.20 1.10 1.00)
        markdown-hide-markup t
        markdown-fontify-code-blocks-natively t
        markdown-enable-math t
        markdown-enable-wiki-links t
        markdown-wiki-link-alias-first nil
        markdown-wiki-link-search-type '(project)
        markdown-max-image-size '(1000 . 800))
  (markdown-update-header-faces
   markdown-header-scaling markdown-header-scaling-values)

  (defun my/markdown-note-setup ()
    "Apply the default visual note-editing behavior."
    ;; Load Doom's mixed-pitch configuration before narrowing its face list.
    (require 'mixed-pitch)
    (setq-local fill-column my/notes-text-width
                +word-wrap-fill-style 'soft
                visual-fill-column-width my/notes-text-width
                visual-fill-column-center-text t
                visual-fill-column-adjust-for-text-scale nil
                mixed-pitch-fixed-pitch-faces
                '(markdown-code-face
                  markdown-inline-code-face
                  markdown-pre-face
                  markdown-language-info-face
                  markdown-language-keyword-face))
    (mixed-pitch-mode 1)
    (face-remap-add-relative 'default :family my/notes-font-family)
    (dolist (face mixed-pitch-fixed-pitch-faces)
      (face-remap-add-relative face :family my/notes-code-font-family))
    (+word-wrap-mode 1)
    (markdown-display-inline-images))

  (add-hook 'markdown-mode-hook #'my/markdown-note-setup))

(defun my/markdown-update-canvas-width (&optional window)
  "Keep the Markdown canvas at a fixed pixel width in WINDOW."
  (setq window (or window (selected-window)))
  (when (window-live-p window)
    (with-current-buffer (window-buffer window)
      (when (derived-mode-p 'markdown-mode)
        (let ((font-width (or (window-font-width window)
                              (frame-char-width (window-frame window)))))
          (setq-local
           visual-fill-column-width
           (max 1 (round (/ (float my/notes-canvas-width-pixels)
                            font-width)))))))))

(after! visual-fill-column
  (advice-add #'visual-fill-column--adjust-window
              :before #'my/markdown-update-canvas-width))

(map! :leader
      (:prefix ("n" . "notes")
       :desc "Today's note"          "d" #'my/notes-open-daily
       :desc "This week's note"      "w" #'my/notes-open-weekly
       :desc "Find note file"        "f" #'my/notes-find-file
       :desc "Search note contents"  "s" #'my/notes-search
       :desc "Notes tree"            "t" #'my/notes-tree
       :desc "Cycle tree file sort"  "o" #'my/notes-tree-cycle-sort
       :desc "Toggle inline images"  "i" #'markdown-toggle-inline-images
       :desc "Refresh inline images" "r" #'my/markdown-refresh-inline-images
       :desc "Toggle markup hiding"  "m" #'markdown-toggle-markup-hiding)
      (:prefix ("t" . "toggle")
       :desc "Toggle line numbers" "l" #'doom/toggle-line-numbers
       :desc "Toggle light/dark theme" "T" #'my/toggle-light-dark-theme))

(map! :g "C-c d" #'my/notes-open-daily
      :g "C-c t" #'my/toggle-light-dark-theme)

;; Example custom periodic note type (not enabled):
;; (defun my/notes-open-monthly ()
;;   (interactive)
;;   (my/notes--open-periodic-note "monthly" "%Y-%m" "%B %Y"))
;; (map! :leader :prefix ("n" . "notes")
;;       :desc "This month's note" "M" #'my/notes-open-monthly)
