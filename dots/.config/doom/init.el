;;; init.el -*- lexical-binding: t; -*-

;; This file controls what Doom modules are enabled and what order they load in.
;; Remember to run 'doom sync' after modifying it.
;;
;; Press 'K' on a module to view its documentation, and 'gd' to browse its
;; directory.

(doom! :input
       ;;bidi
       ;;chinese
       ;;japanese
       ;;layout

       :completion
       (corfu
         +icons
         +orderless
         +dabbrev)
       (vertico +icons)

       :ui
       doom
       doom-dashboard
       hl-todo
       (ligatures +extra)
       indent-guides
       modeline
       nav-flash
       ophints                              ; highlight operator regions
       (popup +all +defaults)               ; window rule manager (your `popper` analog)
       treemacs
       unicode
       (vc-gutter +pretty)
       window-select
       workspaces                           ; tab-bar + perspective workspaces (your perspective.el)
       zen

       :editor
       (evil +everywhere)                   ; evil, evil-collection, evil-surround, evil-numbers, evil-args, etc.
       file-templates                       ; your file-templates section
       fold                                 ; treesit-fold + vimish-fold integration
       (format +onsave)                     ; apheleia
       multiple-cursors
       snippets                             ; yasnippet + doom-snippets + yasnippet-capf
       word-wrap

       :emacs
       (dired +icons +dirvish)              ; dired + dirvish
       electric
       (ibuffer +icons)
       undo
       vc

       :term
       vterm

       :checkers
       (syntax
         +flymake
         +icons)

       :tools
       biblio
       direnv
       editorconfig
       debugger
       (eval +overlay)
       (lookup +dictionary)
       (lsp
         +eglot
         +booster)
       (magit +forge)
       pdf
       tree-sitter
       llm

       :os
       tty

       :lang
       (cc +tree-sitter +lsp)
       data
       emacs-lisp
       (json +tree-sitter +lsp)
       (latex
         +cdlatex
         +fold
         +lsp)
       (markdown
         +grip
         +tree-sitter)
       (nix
         +tree-sitter
         +lsp)
       (org
         +dragndrop
         +gnuplot
         +pandoc
         +pretty
         +noter
         +journal
         +jupyter)
       plantuml
       (python
         +tree-sitter
         +lsp
         +uv)
       (sh +lsp)
       (yaml +tree-sitter +lsp)

       :config
       literate
       (default +bindings +smartparens))
