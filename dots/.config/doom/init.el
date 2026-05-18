;;; init.el -*- lexical-binding: t; -*-

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
       ophints
       (popup +all +defaults)
       treemacs
       unicode
       (vc-gutter +pretty)
       window-select
       workspaces
       zen

       :editor
       (evil +everywhere)
       file-templates
       fold
       (format +onsave)
       multiple-cursors
       snippets
       word-wrap

       :emacs
       (dired
         +icons
         +dirvish)
       electric
       (ibuffer
         +icons)
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
       (cc
         +tree-sitter
         +lsp)
       data
       emacs-lisp
       (json
         +tree-sitter
         +lsp)
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
       (yaml
         +tree-sitter
         +lsp)

       :config
       literate
       (default +bindings +smartparens))
