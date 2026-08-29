;;; config.el -*- lexical-binding: t; -*-

(require 'project)

(defvar my/fixed-pitch-font-family "Monospace"
  "Monospaced font family used by Doom.")

(defvar my/fixed-pitch-font-size 15
  "Default monospaced font size.")

(defvar my/notes-font-family "Sans Serif"
  "Proportional font family used for note prose.")

(defvar my/notes-font-size 17
  "Proportional font size used for note prose.")

(defvar my/notes-code-font-family nil
  "Monospaced font family used for code in notes.")

(defvar my/notes-directory (expand-file-name "~/Notes")
  "Absolute path to the private Markdown notes vault.")

(defvar my/notes-text-width 80
  "Fallback note width in columns and the preferred fill column.")

(defvar my/notes-canvas-width-pixels 800
  "Maximum visual width of the centered note canvas in pixels.")

(defvar my/notes-fd-ignore-patterns '(".*")
  "Glob patterns excluded from notes file-name searches.")

(defvar my/notes-weekly-template "Weekly/Template.md"
  "Weekly template path, relative to the notes vault or absolute.")

(defvar my/notes-auto-save-interval 10
  "Seconds between saves of modified buffers in the notes vault.")

(defvar my/notes--auto-save-timer nil)
(defvar my/notes--last-selected-buffer nil)

(defvar my/notes-tree-sort-mode 'alphabetical
  "Current file sorting mode in the notes Treemacs pane.")

(defvar my/notes-tree--birth-time-cache (make-hash-table :test #'equal)
  "Cached filesystem birth timestamps used by the notes tree sorter.")

(let ((local-config (expand-file-name "local.el" doom-user-dir)))
  (when (file-readable-p local-config)
    (load local-config nil 'nomessage)))

(unless my/notes-code-font-family
  (setq my/notes-code-font-family my/fixed-pitch-font-family))

(setq doom-theme 'doom-one
      doom-font (font-spec :family my/fixed-pitch-font-family
                           :size my/fixed-pitch-font-size
                           :weight 'regular)
      doom-variable-pitch-font (font-spec :family my/notes-font-family
                                          :size my/notes-font-size)
      display-line-numbers-type nil
      select-enable-clipboard t
      select-enable-primary nil
      save-interprogram-paste-before-kill t)

(defun my/reload-fonts-and-note-remaps ()
  "Reload Doom fonts used by frames and dynamic note remaps."
  (doom/reload-font))

(add-hook 'doom-after-reload-hook #'my/reload-fonts-and-note-remaps)

(defun my/toggle-light-dark-theme ()
  "Switch smoothly between Doom One's dark and light variants."
  (interactive)
  (setq doom-theme
        (if (eq doom-theme 'doom-one) 'doom-one-light 'doom-one))
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme doom-theme t)
  (message "Theme: %s" doom-theme))

(setq my/notes-directory
      (file-name-as-directory (expand-file-name my/notes-directory)))

;; Start in the vault instead of requiring a path argument at launch.
(setq initial-buffer-choice
      (lambda () (dired-noselect my/notes-directory)))

(defun my/notes--require-vault ()
  "Signal a useful error unless the configured vault exists."
  (unless (file-directory-p my/notes-directory)
    (user-error
     "Notes vault does not exist: %s; configure ~/.config/doom/local.el"
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

(defun my/notes-buffer-p (buffer)
  "Return non-nil when BUFFER visits a file in the notes vault."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (and buffer-file-name
           (file-in-directory-p
            (expand-file-name buffer-file-name)
            my/notes-directory)))))

(defun my/notes-save-buffer-if-needed (buffer)
  "Save BUFFER when it is a modified note with no external changes."
  (when (and (my/notes-buffer-p buffer)
             (buffer-modified-p buffer))
    (with-current-buffer buffer
      (if (verify-visited-file-modtime buffer)
          (condition-case error-data
              (save-buffer)
            (error
             (message "Could not auto-save note %s: %s"
                      (buffer-name buffer)
                      (error-message-string error-data))))
        (message "Skipped auto-saving externally changed note: %s"
                 (buffer-name buffer))))))

(defun my/notes-auto-save-all ()
  "Save all modified file buffers belonging to the notes vault."
  (dolist (buffer (buffer-list))
    (my/notes-save-buffer-if-needed buffer)))

(defun my/notes-auto-save-on-buffer-switch ()
  "Save the previous note when the selected buffer changes."
  (let ((current (window-buffer (selected-window)))
        (previous my/notes--last-selected-buffer))
    (unless (eq current previous)
      (setq my/notes--last-selected-buffer current)
      (my/notes-save-buffer-if-needed previous))))

(add-hook 'buffer-list-update-hook #'my/notes-auto-save-on-buffer-switch)

(when (timerp my/notes--auto-save-timer)
  (cancel-timer my/notes--auto-save-timer))
(setq my/notes--auto-save-timer
      (run-with-timer my/notes-auto-save-interval
                      my/notes-auto-save-interval
                      #'my/notes-auto-save-all))

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

(evil-define-motion my/evil-next-blank-line (count)
  "Move to the COUNTth next blank line, like Vim's `}'."
  :jump t
  :type exclusive
  (let ((count (or count 1)))
    (dotimes (_ count)
      (forward-line 1)
      (while (and (not (eobp))
                  (not (looking-at-p "[[:blank:]]*$")))
        (forward-line 1)))))

(evil-define-motion my/evil-previous-blank-line (count)
  "Move to the COUNTth previous blank line, like Vim's `{'."
  :jump t
  :type exclusive
  (let ((count (or count 1)))
    (dotimes (_ count)
      (forward-line -1)
      (while (and (not (bobp))
                  (not (looking-at-p "[[:blank:]]*$")))
        (forward-line -1)))))

(after! markdown-mode
  (custom-theme-set-faces! 'doom-one
      '(markdown-header-face
         :foreground "#cccccc"
         :weight extra-bold)
      '(markdown-bold-face
         :foreground "#cccccc"
         :weight bold)
      '(markdown-italic-face
         :foreground "#cccccc"
         :slant italic)
      '(markdown-list-face
         :foreground "#be8234"
         :weight bold)
  )
  (custom-theme-set-faces! 'doom-one-light
      '(markdown-header-face
         :foreground "#30343b"
         :weight extra-bold)
      '(markdown-bold-face
         :foreground "#30343b"
         :weight bold)
      '(markdown-italic-face
         :foreground "#30343b"
         :slant italic)
      '(markdown-list-face
         :foreground "#7b5421"
         :weight bold)
  )
  (setq markdown-list-item-bullets
      '("⦁"))
  (setq markdown-header-scaling t
        markdown-header-scaling-values '(1.80 1.55 1.35 1.20 1.10 1.00)
        markdown-fontify-code-blocks-natively t
        markdown-enable-math t
        markdown-enable-wiki-links t
        markdown-wiki-link-alias-first nil
        markdown-wiki-link-search-type '(project)
        markdown-max-image-size '(1000 . 800))
  (setq-default markdown-hide-markup t)
  (markdown-update-header-faces
   markdown-header-scaling markdown-header-scaling-values)

  (defvar my/markdown--source-buffer nil)
  (defvar my/markdown--source-beg nil)
  (defvar my/markdown--source-end nil)
  (defvar my/markdown--source-overlay nil)
  (defvar my/markdown--source-image-displays nil)
  (defvar my/markdown--source-tick nil)
  (defvar my/markdown--inhibit-source-stripping nil)

  (defun my/markdown--restore-source-line ()
    "Render the Markdown line most recently exposed as source."
    (when (and (buffer-live-p my/markdown--source-buffer)
               (markerp my/markdown--source-beg)
               (marker-position my/markdown--source-beg))
      (with-current-buffer my/markdown--source-buffer
        (let ((beg (marker-position my/markdown--source-beg))
              (end (marker-position my/markdown--source-end)))
          (when (and font-lock-mode beg end)
            (let ((my/markdown--inhibit-source-stripping t))
              (font-lock-flush beg end))))
        (dolist (entry my/markdown--source-image-displays)
          (when (overlay-buffer (car entry))
            (overlay-put (car entry) 'display (cdr entry))))))
    (when (overlayp my/markdown--source-overlay)
      (delete-overlay my/markdown--source-overlay))
    (when (markerp my/markdown--source-beg)
      (set-marker my/markdown--source-beg nil))
    (when (markerp my/markdown--source-end)
      (set-marker my/markdown--source-end nil))
    (setq my/markdown--source-buffer nil
          my/markdown--source-beg nil
          my/markdown--source-end nil
          my/markdown--source-overlay nil
          my/markdown--source-image-displays nil
          my/markdown--source-tick nil))

  (defun my/markdown--expose-source-line (beg end)
    "Display the Markdown source from BEG to END."
    (my/markdown--strip-source-properties beg end)
    (unless (overlayp my/markdown--source-overlay)
      (setq my/markdown--source-overlay (make-overlay beg end nil nil t))
      (overlay-put my/markdown--source-overlay 'priority 1001)
      (overlay-put my/markdown--source-overlay 'face 'default))
    (move-overlay my/markdown--source-overlay beg end (current-buffer))
    (dolist (overlay markdown-inline-image-overlays)
      (when (and (overlay-buffer overlay)
                 (< (overlay-start overlay) end)
                 (> (overlay-end overlay) beg)
                 (not (assq overlay my/markdown--source-image-displays)))
        (push (cons overlay (overlay-get overlay 'display))
              my/markdown--source-image-displays)
        (overlay-put overlay 'display nil))))

  (defun my/markdown--strip-source-properties (beg end)
    "Remove visual rendering properties between BEG and END."
    (with-silent-modifications
      (remove-list-of-text-properties
       beg end '(face font-lock-face composition display invisible
                       keymap help-echo mouse-face))
      ;; Prevent jit-lock from immediately putting the rendering back.
      (put-text-property beg end 'fontified t)))

  (defun my/markdown--keep-source-line-visible (&rest _)
    "Keep the active source line plain after jit-lock fontification."
    (when (and (not my/markdown--inhibit-source-stripping)
               (eq (current-buffer) my/markdown--source-buffer)
               (markerp my/markdown--source-beg))
      (my/markdown--strip-source-properties
       (marker-position my/markdown--source-beg)
       (marker-position my/markdown--source-end))))

  (unless (advice-member-p #'my/markdown--keep-source-line-visible
                           #'jit-lock-fontify-now)
    (advice-add #'jit-lock-fontify-now :after
                #'my/markdown--keep-source-line-visible))
  (unless (advice-member-p #'my/markdown--keep-source-line-visible
                           #'font-lock-fontify-region)
    (advice-add #'font-lock-fontify-region :after
                #'my/markdown--keep-source-line-visible))

  (defun my/markdown-reveal-current-line ()
    "Render Markdown except for the logical line containing point."
    (let ((source-p (and (derived-mode-p 'markdown-mode)
                         markdown-hide-markup)))
      (unless (and source-p (eq (current-buffer) my/markdown--source-buffer))
        (my/markdown--restore-source-line))
      (when source-p
        (let ((beg (line-beginning-position))
              (end (min (point-max) (1+ (line-end-position))))
              (tick (buffer-chars-modified-tick)))
          (if (and (markerp my/markdown--source-beg)
                   (= beg (marker-position my/markdown--source-beg))
                   (= end (marker-position my/markdown--source-end)))
              (unless (equal tick my/markdown--source-tick)
                (my/markdown--expose-source-line beg end))
            (my/markdown--restore-source-line)
            (setq my/markdown--source-buffer (current-buffer)
                  my/markdown--source-beg (copy-marker beg)
                  my/markdown--source-end (copy-marker end t))
            (my/markdown--expose-source-line beg end))
          (setq my/markdown--source-tick tick)))))

  (add-hook 'post-command-hook #'my/markdown-reveal-current-line)

  (defun my/markdown-note-setup ()
    "Apply the default visual note-editing behavior."
    (when (bound-and-true-p solaire-mode)
      (solaire-mode -1))
    (setq-local fill-column my/notes-text-width
                +word-wrap-fill-style 'soft
                visual-fill-column-width my/notes-text-width
                visual-fill-column-center-text t
                visual-fill-column-adjust-for-text-scale nil)
    ;; Remap complete faces, including height, so prose and code sizes are
    ;; independent and follow Doom's live font reloads.
    (variable-pitch-mode 1)
    (dolist (face '(markdown-code-face
                    markdown-inline-code-face
                    markdown-pre-face
                    markdown-language-info-face
                    markdown-language-keyword-face))
      (face-remap-add-relative face 'fixed-pitch))
    (+word-wrap-mode 1)
    (markdown-display-inline-images)
    (my/markdown-reveal-current-line))

  (add-hook 'markdown-mode-hook #'my/markdown-note-setup))

(after! evil-markdown
  (evil-define-key '(normal visual operator motion) evil-markdown-mode-map
    (kbd "}") #'my/evil-next-blank-line
    (kbd "{") #'my/evil-previous-blank-line))

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
