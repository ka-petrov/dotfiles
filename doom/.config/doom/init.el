;;; init.el -*- lexical-binding: t; -*-

(doom!
 :completion
 vertico

 :ui
 doom
 dashboard
 hl-todo
 modeline
 ophints
 (popup +defaults)
 treemacs
 vc-gutter
 vi-tilde-fringe
 workspaces
 zen

 :editor
 (evil +everywhere)
 file-templates
 fold
 snippets
 word-wrap

 :emacs
 dired
 electric
 undo
 vc

 :checkers
 syntax

 :tools
 (eval +overlay)
 lookup
 magit

 :lang
 emacs-lisp
 markdown

 :config
 (default +bindings +smartparens))
