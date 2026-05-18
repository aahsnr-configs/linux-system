---

# Doom Emacs Translation

## Files go in `~/.config/doom/`. After writing them, run `doom sync` then restart Emacs.

## 1. `~/.config/doom/init.el`

```el
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
       dashboard
       hl-todo
       indent-guides
       (ligatures
         +extra)
       modeline
       ophints
       (popup
         +all
         +defaults)
       treemacs
       unicode
       (vc-gutter
         +pretty)
       workspaces

       :editor
       (evil +everywhere)
       file-templates
       fold
       (format +onsave)
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
```

---

## 2. `~/.config/doom/packages.el`

```elisp
;; -*- no-byte-compile: t; lexical-binding: t; -*-
;;; $DOOMDIR/packages.el
;; ───────────────────────────────────────────────────────────────────────────
;; Evil quality-of-life add-ons not bundled by :editor evil +everywhere
;; ───────────────────────────────────────────────────────────────────────────
(package! evil-exchange)
(package! evil-lion)
(package! evil-goggles)
(package! goto-chg)
(package! evil-tex)

;; ───────────────────────────────────────────────────────────────────────────
;; UI / aesthetics
;; ───────────────────────────────────────────────────────────────────────────
(package! solaire-mode)
(package! default-text-scale)
(package! ultra-scroll)
(package! posframe)
(package! visual-fill-column
  :recipe (:host codeberg :repo "joostkremers/visual-fill-column"))
(package! adaptive-wrap)
(package! eldoc-box)
(package! transient)
(package! anzu)
(package! evil-anzu)

;; ───────────────────────────────────────────────────────────────────────────
;; Editor helpers
;; ───────────────────────────────────────────────────────────────────────────
(package! buffer-terminator)
(package! stripspace)
(package! sudo-edit)
(package! iedit)
(package! dtrt-indent)
(package! indent-bars)

;; ───────────────────────────────────────────────────────────────────────────
;; Completion / Cape extras (yasnippet-capf is Doom-default; the rest aren't)
;; ───────────────────────────────────────────────────────────────────────────
(package! consult-dir)
(package! consult-project-extra)
(package! consult-yasnippet)
(package! consult-eglot)
(package! consult-eglot-embark)
(package! consult-todo)

;; ───────────────────────────────────────────────────────────────────────────
;; Org / Denote / GTD
;; ───────────────────────────────────────────────────────────────────────────
(package! org-modern)
(package! org-appear
  :recipe (:host github :repo "awth13/org-appear"))
(package! org-fragtog)
(package! org-super-agenda)
(package! org-remark)
(package! org-gtd)
(package! org-edna)

(package! denote)
(package! denote-journal)
(package! denote-org)
(package! consult-denote)
(package! citar-denote)

;; ───────────────────────────────────────────────────────────────────────────
;; Version control extras
;; ───────────────────────────────────────────────────────────────────────────
(package! git-timemachine)

;; ───────────────────────────────────────────────────────────────────────────
;; Languages not covered by stock Doom modules
;; ───────────────────────────────────────────────────────────────────────────
(package! kdl-mode
  :recipe (:host github :repo "taquangtrung/emacs-kdl-mode"))
(package! kbd-mode
  :recipe (:host github :repo "kmonad/kbd-mode"))
(package! yaml-pro)
(package! flymake-ruff)

;; ───────────────────────────────────────────────────────────────────────────
;; PDF / Org-Noter integration
;; ───────────────────────────────────────────────────────────────────────────
(package! org-pdftools)
(package! org-noter-pdftools)

;; ───────────────────────────────────────────────────────────────────────────
;; LaTeX extras (AUCTeX/cdlatex/reftex come with :lang latex)
;; ───────────────────────────────────────────────────────────────────────────
(package! citeproc)

;; ───────────────────────────────────────────────────────────────────────────
;; Local package: org-src-context.el lives in $DOOMDIR/lisp/
;; (declared with use-package! in config.org, not installed by straight)
;; ───────────────────────────────────────────────────────────────────────────
```

---

## 3. `~/.config/doom/config.org`

This is the literate file. Save your existing `lisp/org-src-context.el` to `~/.config/doom/lisp/org-src-context.el` — `(add-load-path! "lisp")` in the User Info block picks it up.

```org
#+TITLE: Doom Emacs Literate Configuration
#+AUTHOR: Ahsanur Rahman
#+PROPERTY: header-args:emacs-lisp :tangle yes :results none
#+STARTUP: overview

* Header & Lexical Binding
The literate module tangles all =emacs-lisp= blocks into =config.el= by default.
The first block sets up the file header.

#+begin_src emacs-lisp
;;; config.el -*- lexical-binding: t; -*-
;;; Commentary: Tangled from config.org. Do not edit by hand.
#+end_src

* User Info
#+begin_src emacs-lisp
(setq user-full-name    "Ahsanur Rahman"
      user-mail-address "ahsanur041@proton.me")

;; Pick up org-src-context.el from $DOOMDIR/lisp/
(add-load-path! "lisp")
#+end_src

* Core Defaults
** Frame title
#+begin_src emacs-lisp
(setq frame-title-format '("Emacs - %b")
      icon-title-format  frame-title-format)
#+end_src

** Editor behavior
Doom already enables ~delete-selection-mode~, ~y-or-n-p~, ~global-auto-revert~,
sane backups, UTF-8 defaults, ~savehist~ and ~saveplace~. We only override what
differs from your vanilla config.

#+begin_src emacs-lisp
(setq-default
 fill-column 80
 tab-width 4
 indent-tabs-mode nil
 major-mode 'text-mode
 bidi-paragraph-direction 'left-to-right
 bidi-inhibit-bpa t)

(setq
 ;; Performance / scrolling
 fast-but-imprecise-scrolling t
 redisplay-skip-fontification-on-input t
 inhibit-compacting-font-caches t
 highlight-nonselected-windows nil
 ;; Long-line handling
 long-line-threshold 1000
 large-hscroll-threshold 1000
 syntax-wholeline-max 1000
 ;; Undo (Doom uses undo-fu under :emacs undo +undo-fu)
 undo-limit 800000
 undo-strong-limit 1200000
 undo-outer-limit 120000000
 ;; Misc
 vc-handled-backends '(Git)
 vc-follow-symlinks t
 confirm-kill-processes nil
 echo-keystrokes 0.1
 require-final-newline t
 uniquify-buffer-name-style 'forward
 delete-by-moving-to-trash t
 sentence-end-double-space nil
 word-wrap-by-category t)

;; Auto-save visited files every 5s (Doom enables auto-revert but not visited save)
(setq auto-save-visited-interval 5)
(auto-save-visited-mode 1)

(put 'erase-buffer 'disabled nil)

;; File associations
(dolist (assoc '(("\\.in\\'"      . text-mode)
                 ("\\.out\\'"     . text-mode)
                 ("\\.args\\'"    . text-mode)
                 ("\\.bb\\'"      . shell-script-mode)
                 ("\\.bbclass\\'" . shell-script-mode)
                 ("\\.Rmd\\'"     . markdown-mode)))
  (add-to-list 'auto-mode-alist assoc))

;; Suppress beginning/end-of-buffer chatter
(setq command-error-function
      (lambda (data context caller)
        (unless (memq (car data) '(beginning-of-buffer end-of-buffer))
          (command-error-default-function data context caller))))
#+end_src

** Recentf tweaks
#+begin_src emacs-lisp
(after! recentf
  (setq recentf-max-saved-items 300
        recentf-filename-handlers '(file-truename abbreviate-file-name))
  (dolist (re '("\\.?cache" ".cask" "url" "COMMIT_EDITMSG\\'" "bookmarks"
                "\\.\\(?:gz\\|gif\\|svg\\|png\\|jpe?g\\|bmp\\|xpm\\)$"
                "^/tmp/" "^/var/folders/.+$" "^/ssh:" "/persp-confs/"))
    (add-to-list 'recentf-exclude re)))
#+end_src

** Savehist extras
#+begin_src emacs-lisp
(after! savehist
  (setq history-length 1000
        savehist-autosave-interval 300)
  (dolist (v '(mark-ring global-mark-ring search-ring
                         regexp-search-ring extended-command-history))
    (add-to-list 'savehist-additional-variables v)))
#+end_src

** Environment variables (daemon mode)
#+begin_src emacs-lisp
(after! exec-path-from-shell
  (dolist (var '("OPENAI_API_KEY" "ANTHROPIC_API_KEY" "XAI_API_KEY"
                 "DEEPSEEK_API_KEY" "OPENROUTER_API_KEY"
                 "GEMINI_API_KEY" "HF_TOKEN"))
    (add-to-list 'exec-path-from-shell-variables var)))
#+end_src

** GC magic hack
Doom already enables ~gcmh~. Just tune it.
#+begin_src emacs-lisp
(after! gcmh
  (setq gcmh-idle-delay 'auto
        gcmh-high-cons-threshold (* 128 1024 1024)))
#+end_src

* Appearance
** Theme
#+begin_src emacs-lisp
(setq doom-theme 'doom-tokyo-night)

(after! doom-themes
  (setq doom-themes-enable-bold   t
        doom-themes-enable-italic t
        doom-themes-treemacs-theme "doom-atom")
  (doom-themes-neotree-config)
  (doom-themes-treemacs-config)
  (doom-themes-org-config))
#+end_src

** Fonts
#+begin_src emacs-lisp
(setq doom-font          (font-spec :family "JetBrains Mono" :size 16 :weight 'medium)
      doom-variable-pitch-font (font-spec :family "JetBrains Mono" :size 16 :weight 'medium))

(setq-default line-spacing 0.02)

(custom-set-faces!
  '(font-lock-comment-face :slant italic)
  '(font-lock-keyword-face :weight bold :slant italic))
#+end_src

** Modeline
#+begin_src emacs-lisp
(after! doom-modeline
  (setq doom-modeline-height                  25
        doom-modeline-bar-width               3
        doom-modeline-icon                    t
        doom-modeline-major-mode-icon         t
        doom-modeline-modal                   t
        doom-modeline-modal-icon              t
        doom-modeline-buffer-file-name-style  'relative-from-project
        doom-modeline-buffer-encoding         nil
        doom-modeline-buffer-file-size        nil
        doom-modeline-percent-position        nil
        doom-modeline-column-zero-based       nil
        doom-modeline-vcs-max-length          0
        doom-modeline-github                  nil
        doom-modeline-persp-name              nil
        doom-modeline-minor-modes             nil))
#+end_src

** Line numbers
#+begin_src emacs-lisp
;; Doom uses `display-line-numbers-type'; nil = off, t = absolute, 'relative
(setq display-line-numbers-type t)
(setq display-line-numbers-width-start t)
#+end_src

** Smooth scrolling
#+begin_src emacs-lisp
(setq hscroll-step 1 hscroll-margin 2
      scroll-step 1  scroll-margin 0
      scroll-conservatively 100000
      scroll-preserve-screen-position t
      auto-window-vscroll nil
      mouse-wheel-scroll-amount-horizontal 1
      mouse-wheel-progressive-speed nil)

(use-package! ultra-scroll
  :when (fboundp 'pixel-scroll-precision-mode)
  :hook (doom-first-buffer . ultra-scroll-mode)
  :config
  (add-hook 'ultra-scroll-hide-functions #'diff-hl-flydiff-mode)
  (add-hook 'ultra-scroll-hide-functions #'hl-todo-mode)
  (add-hook 'ultra-scroll-hide-functions #'jit-lock-mode))
#+end_src

** Highlight current line
#+begin_src emacs-lisp
(after! hl-line
  ;; Disable hl-line when in visual selection (avoid color clash)
  (defvar-local +ar/hl-line-was-on nil)
  (add-hook 'evil-visual-state-entry-hook
            (lambda ()
              (when (bound-and-true-p hl-line-mode)
                (hl-line-mode -1)
                (setq-local +ar/hl-line-was-on t))))
  (add-hook 'evil-visual-state-exit-hook
            (lambda ()
              (when +ar/hl-line-was-on
                (hl-line-mode 1)
                (kill-local-variable '+ar/hl-line-was-on)))))
#+end_src

** Window dividers
#+begin_src emacs-lisp
(setq window-divider-default-places       t
      window-divider-default-bottom-width 1
      window-divider-default-right-width  1)
(add-hook 'doom-init-ui-hook #'window-divider-mode)
#+end_src

** Default text scale
#+begin_src emacs-lisp
(use-package! default-text-scale
  :hook (doom-first-buffer . default-text-scale-mode))
#+end_src

** Visual fill column (prose centering)
#+begin_src emacs-lisp
(use-package! visual-fill-column
  :hook ((org-mode markdown-mode text-mode) . +ar/visual-fill-setup)
  :config
  (setq visual-fill-column-width                       110
        visual-fill-column-center-text                 t
        visual-fill-column-enable-sensible-window-split t)
  (defun +ar/visual-fill-setup ()
    (visual-line-mode 1)
    (visual-fill-column-mode 1)))
#+end_src

** Posframe (child frame backend)
#+begin_src emacs-lisp
(use-package! posframe
  :defer t
  :config
  (defface posframe-border '((t (:inherit region))) "Posframe border."
    :group 'posframe)
  (setq posframe-border-width 1))
#+end_src

** Dashboard
Doom ships its own ~doom-dashboard~; keep it as-is. If files come in via the CLI, Doom already skips the dashboard automatically.

* Evil Tweaks
Doom's =:editor evil +everywhere= already pulls in evil, evil-collection,
evil-surround, evil-numbers, evil-args, evil-textobj-tree-sitter, etc.
We just layer behavioral preferences and add the few packages Doom doesn't bundle.

#+begin_src emacs-lisp
(after! evil
  (setq evil-want-fine-undo            t
        evil-move-beyond-eol           t
        evil-v$-excludes-newline       t
        evil-kill-on-visual-paste      nil
        evil-ex-search-vim-style-regexp t
        evil-ex-search-case            'smart
        evil-symbol-word-search        t
        evil-want-Y-yank-to-eol        t
        evil-split-window-below        t
        evil-vsplit-window-right       t)

  ;; Visual-line j/k by default
  (define-key evil-motion-state-map "j"  #'evil-next-visual-line)
  (define-key evil-motion-state-map "k"  #'evil-previous-visual-line)
  (define-key evil-motion-state-map "gj" #'evil-next-line)
  (define-key evil-motion-state-map "gk" #'evil-previous-line)

  ;; gc / gcc commenting (Doom's :editor evil already binds gc, but ensure consistency)
  (evil-define-operator +ar/evil-comment-or-uncomment (beg end)
    "Toggle comment for the region between BEG and END."
    (interactive "<r>")
    (comment-or-uncomment-region beg end))
  (evil-define-key 'normal 'global (kbd "gc") #'+ar/evil-comment-or-uncomment))
#+end_src

** Extra evil plugins
#+begin_src emacs-lisp
(use-package! evil-exchange :after evil :config (evil-exchange-install))
(use-package! evil-lion     :after evil :config (evil-lion-mode))
(use-package! evil-goggles
  :after evil
  :config
  (setq evil-goggles-duration 0.1)
  (evil-goggles-mode))

(use-package! goto-chg
  :after evil
  :commands (goto-last-change goto-last-change-reverse)
  :config
  (evil-define-key 'normal 'global (kbd "g;") #'goto-last-change)
  (evil-define-key 'normal 'global (kbd "g,") #'goto-last-change-reverse))
#+end_src

** Smart o/O comment continuation
#+begin_src emacs-lisp
(defcustom +ar/evil-o/O-continues-comments t
  "If non-nil, o/O continue comment lines."
  :type 'boolean :group 'evil)

(defun +ar/evil-open-below-smart ()
  (interactive)
  (if (and +ar/evil-o/O-continues-comments
           (save-excursion (comment-beginning)))
      (progn (end-of-line) (comment-indent-new-line) (evil-insert-state))
    (evil-open-below 1)))

(defun +ar/evil-open-above-smart ()
  (interactive)
  (if (and +ar/evil-o/O-continues-comments
           (save-excursion (comment-beginning)))
      (progn (beginning-of-line) (comment-indent-new-line)
             (forward-line -1) (indent-according-to-mode) (evil-insert-state))
    (evil-open-above 1)))

(after! evil
  (define-key evil-normal-state-map "o" #'+ar/evil-open-below-smart)
  (define-key evil-normal-state-map "O" #'+ar/evil-open-above-smart))
#+end_src

* Editor Behavior
** Anzu (search counter)
#+begin_src emacs-lisp
(use-package! anzu :hook (doom-first-input . global-anzu-mode))
(use-package! evil-anzu :after evil)
#+end_src

** Buffer terminator
#+begin_src emacs-lisp
(use-package! buffer-terminator
  :hook (doom-first-buffer . buffer-terminator-mode)
  :config
  (setq buffer-terminator-verbose nil
        buffer-terminator-inactivity-timeout (* 30 60)
        buffer-terminator-interval (* 10 60)))
#+end_src

** Stripspace
#+begin_src emacs-lisp
(use-package! stripspace
  :hook ((prog-mode text-mode conf-mode) . stripspace-local-mode)
  :config
  (setq stripspace-only-if-initially-clean nil
        stripspace-restore-column          t))
#+end_src

** Sudo-edit / iedit
#+begin_src emacs-lisp
(use-package! sudo-edit :defer t)
(use-package! iedit :defer t)
#+end_src

** Eldoc-box (hover docs)
#+begin_src emacs-lisp
(use-package! eldoc-box
  :hook (eglot-managed-mode . eldoc-box-hover-at-point-mode)
  :init
  (after! evil
    (evil-define-key '(normal visual) 'global (kbd "K") #'eldoc-box-help-at-point))
  :config
  (setq eldoc-box-max-pixel-width  800
        eldoc-box-max-pixel-height 600
        eldoc-box-only-multi-line  t
        eldoc-box-cleanup-interval 0.5
        eldoc-box-fringe-use-same-bg t
        eldoc-box-lighter          nil
        eldoc-box-offset           '(16 16 16)))
#+end_src

** Transient minor tweaks
#+begin_src emacs-lisp
(after! transient
  (setq resize-mini-windows t))
#+end_src

** Adaptive wrap (used by LaTeX)
#+begin_src emacs-lisp
(use-package! adaptive-wrap
  :hook (LaTeX-mode . adaptive-wrap-prefix-mode)
  :init (setq-default adaptive-wrap-extra-indent 0))
#+end_src

* Org Mode
Doom's =:lang org +pretty +noter +pomodoro +journal +habit= bundles
~org-modern~, ~org-pomodoro~, ~org-noter~, ~org-journal~, ~org-habit~, etc.
We override only what's specific to your workflow.

** Directory plumbing
#+begin_src emacs-lisp
(defvar my/org-directory (file-truename (expand-file-name "~/org/"))
  "Base directory for org files.")
(setq org-directory my/org-directory)

(defvar my/org-subdirs
  '("notes" "notes/journal" "notes/literature" "gtd" "reviews"
    "downloads" "noter" "archive" "attachments" "backups"))

(defun my/org-subdir (sub) (expand-file-name sub my/org-directory))
(defun my/ensure-org-dir (sub)
  (let ((d (my/org-subdir sub)))
    (unless (file-directory-p d) (make-directory d t))
    d))
(defun my/ensure-org-file (name &optional tmpl)
  (let ((f (expand-file-name name my/org-directory)))
    (unless (file-exists-p f)
      (with-temp-file f (when tmpl (insert tmpl))))
    f))

(mapc #'my/ensure-org-dir my/org-subdirs)

(my/ensure-org-file "journal.org"  "#+title: Journal\n#+filetags: :journal:\n\n* Journal Entries\n\n")
(my/ensure-org-file "habits.org"   "#+title: Habits\n#+filetags: :habit:\n\n* Daily Habits\n\n* Weekly Habits\n\n* Monthly Habits\n\n")
(my/ensure-org-file "goals.org"    "#+title: Goals\n#+filetags: :goals:\n\n* Life Goals\n\n* This Year\n\n* This Quarter\n\n* This Month\n\n")
(my/ensure-org-file "reading.org"  "#+title: Reading List\n#+filetags: :reading:\n\n* Currently Reading\n\n* To Read\n\n* Completed\n\n")
(my/ensure-org-file "meetings.org" "#+title: Meetings\n#+filetags: :meeting:\n\n* Meetings\n\n")

(defvar my/denote-directory      (my/org-subdir "notes/"))
(defvar my/org-gtd-directory     (my/org-subdir "gtd/"))
(defvar my/org-reviews-directory (my/org-subdir "reviews/"))
#+end_src

** Core org configuration
#+begin_src emacs-lisp
(after! org
  (setq org-log-done                     'time
        org-log-into-drawer              t
        org-return-follows-link          t
        org-pretty-entities              t
        org-hide-leading-stars           t
        org-hide-emphasis-markers        t
        org-fontify-whole-heading-line   t
        org-adapt-indentation            nil
        org-fontify-done-headline        t
        org-fontify-quote-and-verse-blocks t
        org-src-fontify-natively         t
        org-src-preserve-indentation     t
        org-src-tab-acts-natively        t
        org-edit-src-content-indentation 0
        org-element-use-cache            t
        org-element-cache-persistent     nil
        org-highlight-latex-and-related  nil
        org-startup-folded               'overview
        org-startup-with-inline-images   nil
        org-startup-with-latex-preview   nil
        org-cycle-separator-lines        2)

  (setq org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "PROG(p)" "WAIT(w@/!)" "|" "DONE(d)" "CANCEL(c@)")
          (sequence "PLAN(P)" "ACTIVE(A)" "PAUSED(x)" "|" "ACHIEVED(a)" "DROPPED(D)")
          (sequence "INBOX(i)" "GTD-NEXT(N)" "GTD-WAIT(W@/!)" "|" "GTD-DONE(D!)" "GTD-CNCL(C@)")
          (sequence "CRITICAL(!)" "COMMENT(M)" "|" "RESOLVED(R)" "DISABLED(d!)")))

  (setq org-tag-alist '(("@work" . ?w) ("@home" . ?h) ("@computer" . ?c)
                        ("@phone" . ?p) ("@errands" . ?e) ("read" . ?r)
                        ("meeting" . ?m) ("urgent" . ?u) ("someday" . ?s)))

  (setq org-priority-faces '((?A . error) (?B . warning) (?C . success)))

  (require 'org-tempo)
  (dolist (pair '(("sh"  . "src shell")
                  ("el"  . "src emacs-lisp")
                  ("py"  . "src python")
                  ("jpy" . "src jupyter-python")
                  ("dot" . "src dot")
                  ("plantuml" . "src plantuml")
                  ("tex" . "src latex")
                  ("yml" . "src yaml")
                  ("kbd" . "src kbd")
                  ("kdl" . "src kdl")))
    (add-to-list 'org-structure-template-alist pair))

  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t) (perl . t) (python . t) (ruby . t)
     (js . t) (css . t) (sass . t) (C . t) (java . t)
     (latex . t) (shell . t) (plantuml . t) (dot . t)))

  (setq org-confirm-babel-evaluate nil))

;; Font sizing for headings
(defun +ar/org-font-setup ()
  (font-lock-add-keywords nil
    '(("^ *\\([-]\\) "
       (0 (prog1 () (compose-region (match-beginning 1) (match-end 1) "•"))))))
  (dolist (face '((org-level-1 . 1.13) (org-level-2 . 1.11)
                  (org-level-3 . 1.10) (org-level-4 . 1.07)
                  (org-level-5 . 1.05) (org-level-6 . 1.03)
                  (org-level-7 . 1.02) (org-level-8 . 1.00)))
    (set-face-attribute (car face) nil
                        :font "JetBrainsMono Nerd Font"
                        :weight 'bold :height (cdr face))))

(add-hook 'org-mode-hook #'+ar/org-font-setup)
(add-hook 'org-mode-hook #'visual-line-mode)
#+end_src

** Org-modern
#+begin_src emacs-lisp
(use-package! org-modern
  :hook (org-mode . org-modern-mode)
  :hook (org-agenda-finalize . org-modern-agenda)
  :config
  (setq org-modern-hide-stars         nil
        org-modern-star               '("◉" "○" "✸" "✿" "✤" "✜" "◇" "▷")
        org-modern-checkbox           nil
        org-modern-todo               t
        org-modern-tag                t
        org-modern-priority           t
        org-modern-keyword            t
        org-modern-block-name         t
        org-modern-block-fringe       nil
        org-modern-horizontal-rule    t
        org-modern-timestamp          t
        org-modern-statistics         t
        org-modern-progress           t
        org-modern-list               '((43 . "➤") (45 . "–") (42 . "•"))
        org-modern-table              t
        org-modern-table-vertical     1
        org-modern-table-horizontal   0.2
        org-modern-block-name
        '(("src"     "»" "«")
          ("example" "»" "«")
          ("quote"   "\u201c" "\u201d"))))
#+end_src

** Org-appear / org-fragtog
#+begin_src emacs-lisp
(use-package! org-appear  :hook (org-mode . org-appear-mode))
(use-package! org-fragtog :hook (org-mode . org-fragtog-mode)
  :config (setq org-fragtog-preview-delay 0.2))
#+end_src

** Org src buffer name simplification
#+begin_src emacs-lisp
(defun +ar/org-src-simplify-name (_base _lang) "src code")
(advice-add 'org-src--construct-edit-buffer-name
            :override #'+ar/org-src-simplify-name)
#+end_src

** Org-habit / org-pomodoro tweaks
#+begin_src emacs-lisp
(after! org-habit
  (setq org-habit-graph-column            60
        org-habit-show-habits-only-for-today t
        org-habit-preceding-days          21
        org-habit-following-days          7))

(after! org-pomodoro
  (when (featurep 'alert)
    (alert-add-rule :category "org-pomodoro"
                    :style (cond (alert-growl-command    'growl)
                                 (alert-notifier-command 'notifier)
                                 (alert-libnotify-command 'libnotify)
                                 (t alert-default-style)))))
#+end_src

** Org-remark
#+begin_src emacs-lisp
(use-package! org-remark
  :after org
  :config (org-remark-global-tracking-mode +1))
#+end_src

** Org-Noter / org-pdftools / org-noter-pdftools
#+begin_src emacs-lisp
(after! org-noter
  (setq org-noter-default-notes-file-names '("notes.org")
        org-noter-notes-search-path        '("~/Documents/notes"
                                             "~/org/references/notes")
        org-noter-auto-save-last-location  t
        org-noter-doc-split-fraction       '(0.6 . 0.6)
        org-noter-notes-window-location    'horizontal-split
        org-noter-separate-notes-from-heading t))

(use-package! org-pdftools
  :hook (org-mode . org-pdftools-setup-link)
  :config
  (setq org-pdftools-link-prefix "pdf"
        org-pdftools-use-isearch-link t
        org-pdftools-use-freepointer-annot t))

(use-package! org-noter-pdftools
  :after (org-noter org-pdftools)
  :config
  (setq org-noter-pdftools-use-org-id t
        org-noter-pdftools-insert-content-heading t)
  (with-eval-after-load 'pdf-annot
    (add-hook 'pdf-annot-activate-handler-functions
              #'org-noter-pdftools-jump-to-note)))
#+end_src

** Org agenda + org-super-agenda
#+begin_src emacs-lisp
(after! org-agenda
  (setq org-agenda-block-separator   ?─
        org-agenda-compact-blocks    nil
        org-agenda-inhibit-startup   t
        org-agenda-dim-blocked-tasks nil
        org-agenda-use-tag-inheritance nil
        org-agenda-ignore-properties '(effort appt category)
        org-agenda-span 'day
        org-tags-column -80
        org-agenda-skip-scheduled-if-done t
        org-agenda-skip-deadline-if-done  t
        org-agenda-time-grid
        '((daily today require-timed)
          (800 1000 1200 1400 1600 1800 2000)
          " ┄┄┄┄┄ " "┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄")
        org-agenda-current-time-string
        "◀ now ─────────────────────────────────────────────────"))

(use-package! org-super-agenda
  :hook (org-agenda-mode . org-super-agenda-mode)
  :config
  (setq org-super-agenda-header-separator "─────────────────────────────────"
        org-super-agenda-groups
        '((:name "🔴 Overdue"  :deadline past :scheduled past :order 1)
          (:name "🔥 GTD Inbox"
           :todo "INBOX" :file-path "gtd/inbox.org" :order 2)
          (:name "⚡ Today"
           :time-grid t :date today :scheduled today :order 3)
          (:name "🎯 High Priority" :priority "A" :order 4)
          (:name "💻 @Computer"
           :and (:tag "@computer" :todo ("GTD-NEXT" "NEXT")) :order 5)
          (:name "🏠 @Home"
           :and (:tag "@home"     :todo ("GTD-NEXT" "NEXT")) :order 6)
          (:name "📞 @Phone"
           :and (:tag "@phone"    :todo ("GTD-NEXT" "NEXT")) :order 7)
          (:name "🚗 @Errands"
           :and (:tag "@errands"  :todo ("GTD-NEXT" "NEXT")) :order 8)
          (:name "⏳ Waiting"
           :todo ("GTD-WAIT" "WAIT") :order 9)
          (:name "📆 Due Soon" :deadline future :order 10)
          (:name "📋 Other"    :anything t      :order 99))))
#+end_src

** Org GTD
#+begin_src emacs-lisp
(use-package! org-gtd
  :after org
  :commands (org-gtd-capture org-gtd-process-inbox org-gtd-engage
             org-gtd-show-all-next org-gtd-show-stuck-projects org-gtd-organize)
  :init
  (setq org-gtd-update-ack "4.0.0"
        org-gtd-directory  my/org-gtd-directory)
  (my/ensure-org-dir "gtd")
  :config
  (setq org-gtd-keyword-mapping
        '((todo     . "INBOX")
          (next     . "GTD-NEXT")
          (wait     . "GTD-WAIT")
          (done     . "GTD-DONE")
          (canceled . "GTD-CNCL")))
  (org-edna-mode 1)
  (setq org-agenda-files (list my/org-directory my/org-gtd-directory))
  (run-with-idle-timer 30 nil
    (lambda ()
      (when (and (featurep 'org-gtd)
                 (not (bound-and-true-p org-gtd-mode)))
        (org-gtd-mode 1)))))
#+end_src

* Denote
#+begin_src emacs-lisp
(use-package! denote
  :hook (dired-mode . denote-dired-mode)
  :init
  (setq denote-directory       my/denote-directory
        denote-known-keywords  '("emacs" "philosophy" "reading"
                                 "project" "journal" "meeting"
                                 "idea" "physics")
        denote-org-capture-specifiers "%l\n%i\n%?")
  :config
  (setq denote-save-buffers nil
        denote-infer-keywords t
        denote-sort-keywords  t
        denote-prompts        '(title keywords)
        denote-rename-confirmations '(rewrite-front-matter modify-file-name)
        denote-date-prompt-use-org-read-date t)
  (denote-rename-buffer-mode 1))

(use-package! denote-journal
  :after denote
  :commands (denote-journal-new-entry
             denote-journal-new-or-existing-entry
             denote-journal-link-or-create-entry)
  :config (setq denote-journal-title-format 'day-date-month-year))

(use-package! denote-org :after (denote org))

(use-package! consult-denote
  :after (consult denote)
  :config
  (setq consult-denote-grep-command #'consult-ripgrep)
  (consult-denote-mode 1))

(use-package! citar-denote
  :after (citar denote)
  :config
  (setq citar-denote-subdir "literature")
  (citar-denote-mode 1))
#+end_src

* Per-Project Org Context
Same logic as your vanilla config, dropped in verbatim.
#+begin_src emacs-lisp
(defvar my/project-org-contexts '())
(defvar my/global-org-context  nil)
(defvar my/active-org-project  nil)

(defun my/register-project-org-context (root &rest plist)
  (let* ((truename (file-truename (expand-file-name root)))
         (name (or (plist-get plist :name)
                   (file-name-nondirectory (directory-file-name truename))))
         (ctx  (plist-put plist :name name)))
    (setq my/project-org-contexts
          (cons (cons truename ctx)
                (assoc-delete-all truename my/project-org-contexts)))))

(defun my/project-org--snapshot ()
  (setq my/global-org-context
        (list :name "global"
              :org-directory my/org-directory
              :denote-dir    my/denote-directory
              :gtd-dir       my/org-gtd-directory
              :agenda-files  (and (boundp 'org-agenda-files)
                                  (copy-sequence org-agenda-files))
              :capture-tpls  (and (boundp 'org-capture-templates)
                                  (copy-sequence org-capture-templates)))))

(defun my/project-org--set-dirs (ctx)
  (let ((odir (plist-get ctx :org-directory))
        (ddir (plist-get ctx :denote-dir))
        (gdir (plist-get ctx :gtd-dir))
        (af   (plist-get ctx :agenda-files)))
    (when odir (setq my/org-directory odir org-directory odir))
    (when ddir (make-directory ddir t)
               (setq my/denote-directory ddir denote-directory ddir))
    (when gdir (make-directory gdir t)
               (setq my/org-gtd-directory gdir org-gtd-directory gdir))
    (when af   (setq org-agenda-files af))))

(defun my/project-org--post-switch ()
  (when (and (featurep 'org-agenda)
             (get-buffer org-agenda-buffer-name))
    (with-current-buffer org-agenda-buffer-name (org-agenda-redo t))))

(defun my/project-org-activate (root)
  (unless my/global-org-context (my/project-org--snapshot))
  (let* ((ctx       (cdr (assoc root my/project-org-contexts)))
         (proj-tpls (plist-get ctx :capture-tpls))
         (base-tpls (plist-get my/global-org-context :capture-tpls)))
    (setq my/active-org-project root)
    (my/project-org--set-dirs ctx)
    (setq org-capture-templates
          (if proj-tpls (append proj-tpls base-tpls) base-tpls))
    (my/project-org--post-switch)
    (message "[org-ctx] ▶ %s" (plist-get ctx :name))))

(defun my/project-org-deactivate ()
  (when (and my/active-org-project my/global-org-context)
    (setq my/active-org-project nil)
    (my/project-org--set-dirs my/global-org-context)
    (setq org-capture-templates
          (copy-sequence (plist-get my/global-org-context :capture-tpls)))
    (my/project-org--post-switch)
    (message "[org-ctx] ▶ global")))

(defun my/project-org-maybe-switch ()
  (let* ((proj (ignore-errors (project-current nil)))
         (root (and proj (file-truename (project-root proj)))))
    (cond
     ((and root (assoc root my/project-org-contexts)
           (not (equal root my/active-org-project)))
      (my/project-org-activate root))
     ((and my/active-org-project
           (not (equal root my/active-org-project)))
      (my/project-org-deactivate)))))

(add-hook 'find-file-hook  #'my/project-org-maybe-switch)
(add-hook 'dired-mode-hook #'my/project-org-maybe-switch)

;; Example registration — physics project
(my/register-project-org-context "~/physics/"
  :name          "physics"
  :org-directory (file-truename (expand-file-name "~/physics/"))
  :denote-dir    (file-truename (expand-file-name "~/physics/notes/"))
  :gtd-dir       (file-truename (expand-file-name "~/physics/gtd/"))
  :agenda-files  (list (file-truename (expand-file-name "~/physics/"))
                       (file-truename (expand-file-name "~/physics/gtd/"))))
#+end_src

* Org Capture Templates
Same templates and helpers as your vanilla setup. Doom doesn't override
~org-capture-templates~ so we just ~setq~ inside ~after! org~.

#+begin_src emacs-lisp
(defun +ar/capture-goto-inbox ()
  (find-file (expand-file-name "gtd/inbox.org" my/org-directory))
  (goto-char (point-max)))

(defun +ar/capture-url-from-clipboard ()
  (let ((clip (or (when interprogram-paste-function
                    (funcall interprogram-paste-function))
                  (car kill-ring) "")))
    (if (string-match-p "^https?://" clip) clip (read-string "URL: "))))

(defun +ar/capture-url-as-org-link ()
  (let* ((url  (+ar/capture-url-from-clipboard))
         (desc (read-string (format "Description [%s]: " url) nil nil url)))
    (format "[[%s][%s]]" url desc)))

(defun +ar/capture-habit-range-schedule ()
  (let* ((ideal   (read-string "Ideal interval days (e.g. 1): " "1"))
         (ideal-n (string-to-number ideal))
         (max-def (number-to-string (* 2 ideal-n)))
         (max     (read-string (format "Max interval days (default %s): " max-def) max-def)))
    (format-time-string (format "<%%Y-%%m-%%d %%a .+%sd/%sd>" ideal max))))

(after! org-capture
  (setq org-capture-templates
        `(("i" "Inbox" entry
           (function +ar/capture-goto-inbox)
           ,(string-join
             '("* INBOX %?"
               ":PROPERTIES:" ":CREATED:  %U" ":CONTEXT:  %a" ":END:") "\n")
           :empty-lines 1)

          ("j" "Journal")
          ("jd" "Daily" entry
           (file denote-journal-path-to-new-or-existing-entry)
           ,(string-join '("* %<%H:%M> %?"
                           ":PROPERTIES:" ":CREATED: %U" ":END:") "\n")
           :empty-lines 1 :kill-buffer t)
          ("jl" "Daily + context" entry
           (file denote-journal-path-to-new-or-existing-entry)
           ,(string-join '("* %<%H:%M> %?"
                           ":PROPERTIES:" ":CREATED: %U"
                           ":CONTEXT:  %a" ":END:") "\n")
           :empty-lines 1 :kill-buffer t)

          ("m" "Meeting" entry
           (file+headline ,(expand-file-name "journal.org" my/org-directory) "Meetings")
           ,(string-join '("* %^{Meeting title} :meeting:"
                           ":PROPERTIES:" ":CREATED:   %U"
                           ":ATTENDEES: %^{Attendees}"
                           ":LOCATION:  %^{Location|Remote}" ":END:"
                           "" "** Agenda" "- %?" "" "** Notes" ""
                           "** Action Items" "- [ ] " "" "** Follow-up") "\n")
           :empty-lines 1 :clock-in t :clock-resume t)

          ("b" "Book / Article" entry
           (file+headline ,(expand-file-name "reading.org" my/org-directory) "To Read")
           ,(string-join '("* TODO %^{Title} :read:"
                           ":PROPERTIES:" ":CREATED: %U"
                           ":AUTHOR:  %^{Author}"
                           ":TYPE:    %^{Type|Book|Article|Paper|Video|Podcast}"
                           ":URL:     %^{URL or DOI|}"
                           ":STATUS:  Unread" ":END:"
                           "" "** Why this matters" "%?"
                           "" "** Key ideas") "\n")
           :empty-lines 1))))
#+end_src

* Dirvish (Dired)
Doom's =:emacs dired +dirvish= already pulls in dirvish, diredfl, wdired, dired-x,
and ~dirvish-override-dired-mode~. We just tune.

#+begin_src emacs-lisp
(after! dired
  (setq dired-listing-switches
        "-l --almost-all --human-readable --time-style=long-iso --group-directories-first --no-group"
        dired-recursive-copies   'always
        dired-recursive-deletes  'top
        delete-by-moving-to-trash t
        dired-dwim-target        t
        dired-auto-revert-buffer t
        dired-kill-when-opening-new-dired-buffer t))

(after! dirvish
  (setq dirvish-default-layout '(1 0.11 0.55)
        dirvish-attributes     '(subtree-state nerd-icons collapse vc-state)
        dirvish-use-header-line  t
        dirvish-use-mode-line    t
        dirvish-mode-line-height 25
        dirvish-header-line-height '(25 . 35)
        dirvish-reuse-session    nil
        dirvish-hide-cursor      t
        dirvish-hide-details     '(dirvish dirvish-side)
        dirvish-side-width       30
        dirvish-side-follow-buffer-file t
        dirvish-preview-dispatchers
        '(image gif video audio epub archive pdf dired)
        dirvish-quick-access-entries
        `(("h" "~/" "Home")
          ("e" ,doom-user-dir "Doom")
          ("d" "~/Downloads/" "Downloads")
          ("D" "~/Documents/" "Documents")
          ("p" "~/projects/" "Projects")
          ("o" ,my/org-directory "Org")
          ("c" "~/.config/" "Config"))))
#+end_src

* Workspaces & Treemacs
Doom's =:ui workspaces= (persp-mode) gives you per-tab buffers. Doom's =:ui treemacs +lsp= bundles treemacs, treemacs-nerd-icons, treemacs-magit, treemacs-evil and treemacs-persp.

#+begin_src emacs-lisp
(after! treemacs
  (setq treemacs-width            33
        treemacs-position         'left
        treemacs-is-never-other-window t
        treemacs-space-between-root-nodes t
        treemacs-silent-refresh   t
        treemacs-silent-filewatch t
        treemacs-file-follow-delay 0.2
        treemacs-show-cursor      nil))
#+end_src

* Completion (Vertico + Corfu + Consult + Cape)
Doom's =:completion vertico +icons= and =:completion corfu +icons +orderless +dabbrev= give you everything in your vanilla config. We just tune.

#+begin_src emacs-lisp
(after! vertico
  (setq vertico-count  12
        vertico-resize nil
        vertico-cycle  t))

(after! marginalia
  (setq marginalia-max-relative-age 0
        marginalia-align            'right))

(after! orderless
  (setq completion-styles '(orderless basic)
        completion-category-overrides '((file (styles partial-completion)))
        completion-pcm-leading-wildcard t))

(after! corfu
  (setq corfu-auto             t
        corfu-auto-delay       0.1
        corfu-cycle            t
        corfu-quit-at-boundary t
        corfu-quit-no-match    t
        corfu-count            12
        corfu-preselect        'prompt
        corfu-preview-current  nil
        corfu-on-exact-match   'insert)
  (corfu-history-mode 1)
  (add-hook 'before-save-hook #'corfu-quit))

(after! consult
  (consult-customize
   consult-line consult-line-multi consult-imenu consult-imenu-multi
   :preview-key 'any
   consult-theme :preview-key '(:debounce 0.2 any)
   consult-buffer consult-recent-file
   :preview-key '(:debounce 0.4 any)
   consult-ripgrep consult-git-grep consult-grep consult-find
   :preview-key '(:debounce 0.4 any)
   consult-goto-line consult-mark consult-global-mark
   consult-outline consult-bookmark
   :preview-key '(:debounce 0.4 any))
  (setq consult-narrow-key "<"))

;; Cape extras for richer CAPF
(after! cape
  (add-hook 'completion-at-point-functions #'cape-tex)
  (add-hook 'completion-at-point-functions #'cape-dict)
  (add-hook 'completion-at-point-functions #'cape-dabbrev)
  (add-hook 'completion-at-point-functions #'cape-file)
  (add-hook 'completion-at-point-functions #'cape-keyword))
#+end_src

** Consult extras
#+begin_src emacs-lisp
(use-package! consult-dir           :defer t)
(use-package! consult-project-extra :defer t)
(use-package! consult-yasnippet     :after (consult yasnippet))
(use-package! consult-todo          :defer t :after (consult hl-todo))

(use-package! consult-eglot
  :after consult
  :bind (:map eglot-mode-map ("C-M-." . consult-eglot-symbols)))
(use-package! consult-eglot-embark :after consult-eglot)
#+end_src

* LSP — Eglot
Doom's =:tools lsp +eglot= bundles eglot, consult-eglot. We add the booster and override defaults.

#+begin_src emacs-lisp
(after! eglot
  (setq eglot-events-buffer-size       0
        eglot-send-changes-idle-time   0.5
        eglot-autoshutdown             nil
        eglot-sync-connect             0
        eglot-extend-to-xref           nil
        eglot-ignored-server-capabilities
        '(:documentFormattingProvider
          :documentRangeFormattingProvider
          :documentOnTypeFormattingProvider
          :foldingRangeProvider
          :documentHighlightProvider))

  ;; Server programs
  (add-to-list 'eglot-server-programs '(markdown-mode . ("marksman")))
  (add-to-list 'eglot-server-programs
               '((nix-mode nix-ts-mode) . ("nixd")))
  (add-to-list 'eglot-server-programs
               '((bash-mode bash-ts-mode) . ("bash-language-server" "start")))
  (add-to-list 'eglot-server-programs
               '((yaml-ts-mode) . ("yaml-language-server" "--stdio")))
  (add-to-list 'eglot-server-programs
               '((c-mode c-ts-mode c++-mode c++-ts-mode)
                 . ("clangd" "--background-index" "--clang-tidy"
                    "--header-insertion=never"
                    "--completion-style=detailed"
                    "--function-arg-placeholders=0")))
  (add-to-list 'eglot-server-programs
               '((python-ts-mode python-mode)
                 "basedpyright-langserver" "--stdio"))
  (add-to-list 'eglot-server-programs '(LaTeX-mode . ("texlab")))

  (setq-default eglot-workspace-configuration
                '(:basedpyright
                  ( :typeCheckingMode      "standard"
                    :disableOrganizeImports t)
                  :basedpyright.analysis
                  ( :autoImportCompletions  t
                    :autoSearchPaths        t
                    :diagnosticMode         "workspace"
                    :useLibraryCodeForTypes t))))

(use-package! eglot-booster
  :after eglot
  :init
  (setq eglot-booster-io-only
        (and (> emacs-major-version 29)
             (not (functionp 'json-rpc-connection))))
  :config (eglot-booster-mode))
#+end_src

* org-src-context (Local Package)
Loads ~lisp/org-src-context.el~ that you ship beside this config.
#+begin_src emacs-lisp
(use-package! org-src-context
  :hook (doom-first-buffer . org-src-context-mode)
  :config
  (setq org-src-context-narrow-p     nil
        org-src-context-max-filesize 500000)
  (after! apheleia
    (add-hook 'org-src-mode-hook (lambda () (apheleia-mode 1)))))
#+end_src

* Flymake + Apheleia
Doom's =:checkers syntax +flymake= and =:editor format +onsave= already wire flymake-mode and apheleia globally.

#+begin_src emacs-lisp
(after! flymake
  (setq flymake-fringe-indicator-position 'right-fringe
        flymake-wrap-around                t
        flymake-suppress-zero-counters     t
        flymake-no-changes-timeout         0.5
        flymake-start-on-save-buffer       t)

  (define-fringe-bitmap '+ar/flymake-double-arrow
    [#b00000000 #b00010000 #b00011000 #b00011100 #b00011110
     #b00011100 #b00011000 #b00010000 #b00000000])
  (setq flymake-error-bitmap   '(+ar/flymake-double-arrow flymake-error)
        flymake-warning-bitmap '(+ar/flymake-double-arrow flymake-warning)
        flymake-note-bitmap    '(+ar/flymake-double-arrow flymake-note))

  (defun +ar/flymake-next-error () (interactive)
         (flymake-goto-next-error 1 '(:error :warning) t))
  (defun +ar/flymake-prev-error () (interactive)
         (flymake-goto-prev-error 1 '(:error :warning) t)))

(use-package! flymake-ruff
  :hook (eglot-managed-mode . flymake-ruff-load))

(after! apheleia
  (setq apheleia-log-only-errors t)
  (push '(ruff . ("ruff" "format" "--quiet"
                  "--stdin-filename" filepath "-"))
        apheleia-formatters)
  (setf (alist-get 'python-ts-mode apheleia-mode-alist) '(ruff-isort ruff))
  (setf (alist-get 'python-mode    apheleia-mode-alist) '(ruff-isort ruff))
  (push '(alejandra . ("alejandra" "-q" "-")) apheleia-formatters)
  (setf (alist-get 'nix-mode    apheleia-mode-alist) '(alejandra))
  (setf (alist-get 'nix-ts-mode apheleia-mode-alist) '(alejandra))
  (setf (alist-get 'c-mode      apheleia-mode-alist) '(clang-format))
  (setf (alist-get 'c-ts-mode   apheleia-mode-alist) '(clang-format))
  (setf (alist-get 'c++-mode    apheleia-mode-alist) '(clang-format))
  (setf (alist-get 'c++-ts-mode apheleia-mode-alist) '(clang-format))
  (setf (alist-get 'yaml-ts-mode apheleia-mode-alist) '(prettier))
  (push '(bibtex-tidy . ("bibtex-tidy" "--curly" "--numeric"
                         "--align=14" "--blank-lines"
                         "--sort=id" "--duplicates" "--quiet" "-"))
        apheleia-formatters)
  (setf (alist-get 'bibtex-mode apheleia-mode-alist) '(bibtex-tidy)))
#+end_src

* Magit / Forge / diff-hl / git-timemachine
Doom's =:tools magit= and =:ui vc-gutter +diff-hl= bundle these. We override.

#+begin_src emacs-lisp
(after! magit
  (setq magit-display-buffer-function #'magit-display-buffer-fullframe-status-v1
        magit-bury-buffer-function    #'magit-restore-window-configuration
        magit-save-repository-buffers 'dontask
        magit-commit-ask-to-stage     'stage
        magit-commit-show-diff        t
        magit-revision-show-gravatars nil
        magit-diff-refine-hunk        'all
        magit-diff-paint-whitespace   t
        magit-diff-highlight-trailing t))

(after! forge
  (setq forge-database-connector 'sqlite-builtin))

(after! diff-hl
  (define-fringe-bitmap '+ar/diff-hl-insert [224] nil nil '(center repeated))
  (define-fringe-bitmap '+ar/diff-hl-modify [224] nil nil '(center repeated))
  (define-fringe-bitmap '+ar/diff-hl-delete [128 192 224 240] nil nil 'bottom)
  (setq diff-hl-draw-borders nil
        diff-hl-flydiff-delay 0.1
        diff-hl-fringe-bmp-function
        (lambda (type _pos)
          (pcase type
            ('delete '+ar/diff-hl-delete)
            ('insert '+ar/diff-hl-insert)
            ('change '+ar/diff-hl-modify)
            (_       '+ar/diff-hl-insert))))
  (custom-set-faces!
    '(diff-hl-insert :foreground "#9ece6a" :background unspecified)
    '(diff-hl-change :foreground "#e0af68" :background unspecified)
    '(diff-hl-delete :foreground "#f7768e" :background unspecified))
  (diff-hl-flydiff-mode 1))

(use-package! git-timemachine
  :defer t
  :config
  (setq git-timemachine-abbreviation-length 7
        git-timemachine-show-minibuffer-details t))

(after! magit-todos
  (setq magit-todos-scanner (if (executable-find "rg")
                                'magit-todos--scan-with-rg
                              'magit-todos--scan-with-git-grep)
        magit-todos-keywords-list
        '("TODO" "FIXME" "BUG" "ISSUE" "PROG" "TRICK" "WORKAROUND"
          "BENCHMARK" "REVIEW" "NOTE" "DEPRECATED" "HACK" "DEBUG" "STUB")
        magit-todos-keyword-suffix ":"
        magit-todos-exclude-globs
        '("*.map" "*.min.*" ".git/" "node_modules/"
          "dist/" "build/" "vendor/")
        magit-todos-group-by '(magit-todos-item-keyword
                               magit-todos-item-filename)
        magit-todos-auto-group-items 20
        magit-todos-update-remote nil))
#+end_src

* Highlight TODO
#+begin_src emacs-lisp
(after! hl-todo
  (setq hl-todo-require-punctuation     t
        hl-todo-highlight-punctuation   "")
  (setq hl-todo-keyword-faces
        '(("TODO"       . "#e0af68")
          ("COMMENT"    . "#e0af68")
          ("FIXME"      . "#f7768e")
          ("BUG"        . "#f7768e")
          ("ISSUE"      . "#f7768e")
          ("PROG"       . "#7aa2f7")
          ("TRICK"      . "#ff9e64")
          ("WORKAROUND" . "#ff9e64")
          ("BENCHMARK"  . "#9ece6a")
          ("REVIEW"     . "#7dcfff")
          ("NOTE"       . "#bb9af7")
          ("DEPRECATED" . "#73daca")
          ("HACK"       . "#db4b4b")
          ("DEBUG"      . "#e0af68")
          ("STUB"       . "#e0af68"))))
#+end_src

* PDF Tools
Doom's =:tools pdf= already loads pdf-tools and saveplace-pdf-view.
#+begin_src emacs-lisp
(after! pdf-view
  (setq pdf-view-use-scaling           t
        pdf-view-use-imagemagick       nil
        pdf-annot-activate-created-annotations t
        pdf-view-midnight-colors       '("#c0caf5" . "#1a1b26"))
  (custom-set-faces!
    '(pdf-view-region            :background "#364a82")
    '(pdf-isearch-match          :background "#e0af68" :foreground "#1a1b26")
    '(pdf-isearch-lazy           :background "#414868" :foreground "#c0caf5")
    '(pdf-view-rectangle-face    :background "#7aa2f7" :foreground "#1a1b26")))
#+end_src

* Tree-sitter & Folding
Doom's =:tools tree-sitter= installs grammars on demand via ~treesit-auto~ or manually. =:editor fold= bundles treesit-fold + vimish-fold.

#+begin_src emacs-lisp
(after! treesit
  (setq treesit-font-lock-level 4)
  (dolist (entry
           '((python     "https://github.com/tree-sitter/tree-sitter-python")
             (bash       "https://github.com/tree-sitter/tree-sitter-bash")
             (c          "https://github.com/tree-sitter/tree-sitter-c")
             (cpp        "https://github.com/tree-sitter/tree-sitter-cpp")
             (dockerfile "https://github.com/camdencheek/tree-sitter-dockerfile.git")
             (json       "https://github.com/tree-sitter/tree-sitter-json")
             (latex      "https://github.com/latex-lsp/tree-sitter-latex")
             (bibtex     "https://github.com/latex-lsp/tree-sitter-bibtex")
             (nix        "https://github.com/nix-community/tree-sitter-nix")
             (yaml       "https://github.com/tree-sitter-grammars/tree-sitter-yaml")
             (typescript "https://github.com/tree-sitter/tree-sitter-typescript" "master" "typescript/src")
             (tsx        "https://github.com/tree-sitter/tree-sitter-typescript" "master" "tsx/src")))
    (add-to-list 'treesit-language-source-alist entry))

  (setq major-mode-remap-alist
        '((python-mode     . python-ts-mode)
          (json-mode       . json-ts-mode)
          (js-mode         . js-ts-mode)
          (bash-mode       . bash-ts-mode)
          (sh-mode         . bash-ts-mode)
          (typescript-mode . typescript-ts-mode)
          (conf-toml-mode  . toml-ts-mode)
          (c-mode          . c-ts-mode)
          (c++-mode        . c++-ts-mode))))
#+end_src

* Indent Bars
#+begin_src emacs-lisp
(use-package! indent-bars
  :hook ((prog-mode text-mode conf-mode yaml-mode) . indent-bars-mode)
  :config
  (require 'seq)
  (setq indent-bars-treesit-support     t
        indent-bars-starting-column     0
        indent-bars-no-descend-lists    'skip
        indent-bars-color               '(highlight :face-bg t :blend 0.185)
        indent-bars-no-descend-string   'all
        indent-bars-highlight-current-depth '(:face default :blend 0.85)
        indent-bars-prefer-character    t))

(use-package! dtrt-indent
  :hook (doom-first-file . dtrt-indent-global-mode)
  :config
  (setq dtrt-indent-verbosity      1
        dtrt-indent-min-quality    80.0
        dtrt-indent-mode-exclude-list '(org-mode)))
#+end_src

* Markdown
Doom's =:lang markdown= already configures markdown-mode. We override behavior.
#+begin_src emacs-lisp
(after! markdown-mode
  (setq markdown-italic-underscore         t
        markdown-asymmetric-header         t
        markdown-fontify-code-blocks-natively t
        markdown-gfm-uppercase-checkbox    t
        markdown-enable-math               nil
        markdown-header-scaling            t
        markdown-header-scaling-values     '(1.2 1.15 1.1 1.05 1.0 1.0)
        markdown-display-message           nil
        markdown-hide-urls                 t
        markdown-hide-markup               t
        markdown-list-indent-width         2
        markdown-fontify-whole-heading-line nil
        markdown-fontify-quote-and-verse-blocks nil)

  (add-hook 'markdown-mode-hook #'visual-line-mode)
  (add-hook 'markdown-mode-hook #'eglot-ensure))
#+end_src

* LaTeX
Doom's =:lang latex +cdlatex +fold +latexmk +lsp= bundles AUCTeX, cdlatex, reftex, etc. We override.

#+begin_src emacs-lisp
(after! tex
  (setq TeX-engine                 'luatex
        TeX-parse-self             t
        TeX-auto-save              t
        TeX-source-correlate-method 'synctex
        TeX-source-correlate-mode  t
        TeX-save-query             nil
        TeX-process-asynchronous   t
        TeX-display-help           'expert
        TeX-master                 t
        TeX-electric-math          nil
        TeX-electric-sub-and-superscript t
        TeX-fold-auto-reveal       t
        font-latex-fontify-script  'invisible
        font-latex-fontify-sectioning 'color
        TeX-brace-indent-level     2
        TeX-clean-confirm          nil)

  (add-to-list 'TeX-command-list
               '("LuaLaTeXmk"
                 "latexmk -pdflua -pdflualatex='lualatex -shell-escape -interaction=nonstopmode' -f -outdir=%o %S"
                 TeX-run-TeX nil t
                 :help "Run latexmk with LuaLaTeX") t)
  (setq-default TeX-command-default "LuaLaTeXmk")

  (add-hook 'TeX-after-compilation-finished-functions
            #'TeX-revert-document-buffer))

(after! latex
  (setq LaTeX-command-style    '(("" "%(latex)"))
        LaTeX-indent-level     2
        LaTeX-item-indent      0
        LaTeX-fill-break-at-separators nil
        LaTeX-section-hook
        '(LaTeX-section-heading LaTeX-section-title
          LaTeX-section-toc     LaTeX-section-section
          LaTeX-section-label)))

(after! cdlatex
  (setq cdlatex-math-symbol-prefix ?~
        cdlatex-use-dollar-to-ensure-math nil)
  (define-key cdlatex-mode-map (kbd "`") nil)
  (define-key cdlatex-mode-map (kbd "~") #'cdlatex-math-symbol))

(after! org
  (define-key org-cdlatex-mode-map (kbd "`") nil)
  (define-key org-cdlatex-mode-map (kbd "~") #'org-cdlatex-math-symbol))

(use-package! evil-tex
  :hook (LaTeX-mode . evil-tex-mode))

;; Citar/Citeproc
(after! citar
  (setq citar-bibliography  '("~/references.bib")
        citar-library-paths '("~/Zotero/storage")))

(after! oc
  (require 'oc-natbib)
  (setq org-cite-insert-processor   'citar
        org-cite-follow-processor   'citar
        org-cite-activate-processor 'citar
        org-cite-export-processors  '((latex natbib) (t csl))))
#+end_src

* Languages
** PlantUML
#+begin_src emacs-lisp
(after! plantuml-mode
  (defvar +ar/plantuml-jar-locations
    '("~/.config/plantuml/plantuml.jar"
      "~/plantuml.jar"
      "/usr/share/plantuml/plantuml.jar"
      "/usr/local/share/plantuml/plantuml.jar"
      "/opt/plantuml/plantuml.jar"))
  (let ((jar (seq-find #'file-exists-p
                       (mapcar #'expand-file-name
                               +ar/plantuml-jar-locations))))
    (cond (jar (setq plantuml-jar-path jar
                     plantuml-default-exec-mode 'jar))
          ((executable-find "plantuml")
           (setq plantuml-executable-path (executable-find "plantuml")
                 plantuml-default-exec-mode 'executable))
          (t (setq plantuml-default-exec-mode 'server))))
  (setq plantuml-output-type   "png"
        plantuml-indent-level  2
        plantuml-jar-args      '("-charset" "utf-8")))

(after! ob-plantuml
  (setq org-plantuml-jar-path        plantuml-jar-path
        org-plantuml-executable-path plantuml-executable-path
        org-plantuml-exec-mode       plantuml-default-exec-mode
        org-babel-default-header-args:plantuml
        '((:results . "file")
          (:exports . "results")
          (:cmdline . "-charset utf-8"))))
#+end_src

** Python
#+begin_src emacs-lisp
(after! python
  (setq python-shell-completion-native-enable nil
        python-shell-interpreter              "python3"
        python-indent-offset                  4))
#+end_src

** Nix / KDL / KBD / YAML
#+begin_src emacs-lisp
(use-package! kdl-mode :mode "\\.kdl\\'")

(use-package! kbd-mode
  :commands kbd-mode
  :mode "\\.kbd\\'"
  :config
  (after! org
    (add-to-list 'org-src-lang-modes '("kbd" . kbd))))

(use-package! yaml-pro
  :hook (yaml-ts-mode . yaml-pro-ts-mode))

(after! org
  (add-to-list 'org-src-lang-modes '("yaml" . yaml-ts)))
#+end_src

* Keybindings
Doom already provides SPC leader and a Spacemacs-flavored binding scheme via
=:config default +bindings=. Below we layer your additional keys on top using
the ~map!~ macro (which is what Doom uses everywhere — equivalent to your
~general-create-definer~).

#+begin_src emacs-lisp
(map! :leader
      ;; ──────────────── File / Reload ────────────────
      (:prefix-map ("f" . "file")
       :desc "Reload doom"      "l" #'doom/reload
       :desc "Open doomdir"     "e d" (lambda () (interactive) (doom-project-find-file doom-user-dir)))

      ;; ──────────────── Toggles ────────────────
      (:prefix-map ("t" . "toggle")
       :desc "Rainbow mode"     "r" #'rainbow-mode
       :desc "Prettify symbols" "s" #'prettify-symbols-mode
       :desc "Visual-line"      "v" #'visual-line-mode)

      ;; ──────────────── Org ────────────────
      (:prefix-map ("X" . "capture")
       :desc "Smart capture"    "X" #'org-capture)

      ;; ──────────────── GTD ────────────────
      (:prefix-map ("G" . "gtd")
       :desc "Capture inbox"    "c" #'org-gtd-capture
       :desc "Process inbox"    "p" #'org-gtd-process-inbox
       :desc "Engage"           "e" #'org-gtd-engage
       :desc "Show NEXT"        "n" #'org-gtd-show-all-next
       :desc "Stuck projects"   "s" #'org-gtd-show-stuck-projects)

      ;; ──────────────── Notes / Denote ────────────────
      (:prefix-map ("n" . "notes")
       :desc "New note"             "n" #'denote
       :desc "New note (subdir)"    "N" #'denote-subdirectory
       :desc "Journal today"        "j" #'denote-journal-new-or-existing-entry
       :desc "New journal entry"    "J" #'denote-journal-new-entry
       :desc "Find note"            "f" #'consult-denote-find
       :desc "Search notes"         "s" #'consult-denote-grep
       :desc "Insert link"          "l" #'denote-link
       :desc "Backlinks"            "b" #'denote-backlinks
       :desc "Link or create"       "i" #'denote-link-or-create
       :desc "Rename file"          "r" #'denote-rename-file
       :desc "Bib note"             "B" #'citar-denote-open-note)

      ;; ──────────────── Window helpers (extras) ────────────────
      (:prefix-map ("w" . "window")
       :desc "Winner undo"      "u" #'winner-undo
       :desc "Winner redo"      "U" #'winner-redo))

;; Global zoom keys (browser-style)
(map! "C-=" #'text-scale-increase
      "C--" #'text-scale-decrease)

;; Flymake navigation in motion state
(map! :map flymake-mode-map
      :n "] e" #'+ar/flymake-next-error
      :n "[ e" #'+ar/flymake-prev-error)

;; PDF-view (matches your vanilla bindings)
(map! :map pdf-view-mode-map
      :n "j"  #'pdf-view-next-line-or-next-page
      :n "k"  #'pdf-view-previous-line-or-previous-page
      :n "h"  #'image-backward-hscroll
      :n "l"  #'image-forward-hscroll
      :n "J"  #'pdf-view-next-page
      :n "K"  #'pdf-view-previous-page
      :n "gg" #'pdf-view-first-page
      :n "G"  #'pdf-view-last-page
      :n "gt" #'pdf-view-goto-page
      :n "+"  #'pdf-view-enlarge
      :n "-"  #'pdf-view-shrink
      :n "0"  #'pdf-view-scale-reset
      :n "W"  #'pdf-view-fit-width-to-window
      :n "H"  #'pdf-view-fit-height-to-window
      :n "P"  #'pdf-view-fit-page-to-window
      :n "d"  #'pdf-view-midnight-minor-mode
      :n "o"  #'pdf-outline
      :n "q"  #'quit-window)
#+end_src

* Auto-Tangle on Save
Tangle =config.org= automatically when saved.

#+begin_src emacs-lisp
(defun +ar/auto-tangle-doom-config ()
  "Tangle config.org if we're saving it."
  (when (and buffer-file-name
             (string-equal (file-truename buffer-file-name)
                           (file-truename
                            (expand-file-name "config.org" doom-user-dir))))
    (let ((org-confirm-babel-evaluate nil))
      (org-babel-tangle))))

(add-hook 'org-mode-hook
          (lambda ()
            (add-hook 'after-save-hook #'+ar/auto-tangle-doom-config nil t)))
#+end_src
```

---

## doom/lisp/org-src-context.el

```el
;;; org-src-context.el --- LSP and Context support for org-src buffers -*- lexical-binding: t; -*-

;; Copyright (C) 2025  Ahsanur Rahman
;; Author: Ahsanur Rahman
;; Keywords: tools, languages, extensions, lsp
;; Package-Requires: ((emacs "30.1") (org "9.6"))
;; Version: 0.9.3

;;; Commentary:
;; This package injects surrounding source blocks into the `org-edit-special'
;; buffer to provide context for LSP servers (Eglot).
;;
;; ARCHITECTURAL OVERVIEW & DESIGN DECISIONS:
;;
;; 1. Unified Collector Strategy:
;;    Previous versions relied on `org-babel-tangle-collect-blocks`, which relies
;;    on cached properties and can fail if the file isn't saved.
;;    This version uses `org-babel-map-src-blocks` to scan the buffer directly.
;;    It explicitly matches blocks based on:
;;    a) Language: (e.g., Python blocks only see other Python blocks).
;;    b) Tangle Target: Handles complex inheritance. If a block inherits
;;       ":tangle script.py" from a property drawer, it is correctly grouped
;;       with other blocks targeting "script.py".
;;
;; 2. Lazy Execution & Command Whitelisting (Robustness):
;;    The package advises `org-edit-src-code`. This function is frequently called
;;    internally by Org Mode (for indentation/evaluation) and by external
;;    packages (like `evil-commentary`).
;;    To prevent breaking these operations or hanging the editor:
;;    a) Arg Check: If the `code` argument is present, SKIP (Transient op).
;;    b) Command Check: We strictly whitelist `org-edit-special` and its aliases.
;;       If the user did not explicitly ask to open the Edit Buffer, we do NOT
;;       run the conhttps://z.ai/blog/glm-5.1text injection logic.
;;
;; 3. Marker-Based Tracking (Stability):
;;    We use Emacs Markers instead of integer positions to track the boundaries
;;    of injected context. Markers automatically update their indices when text
;;    is inserted or deleted. This prevents "off-by-one" errors where the
;;    narrowing window would snap to the wrong line during editing.
;;
;; 4. Safe Exit (Data Integrity):
;;    We attach cleanup hooks to both `org-edit-src-exit` (Save) and `abort`.
;;    This ensures the injected "ghost text" is deleted before Org writes the
;;    buffer content back to the main Org file, preventing code duplication.
;;
;; 5. Extension Mapping & Elisp Exclusion:
;;    LSP servers (like Pyright) require valid file extensions to activate.
;;    We map the Org language (e.g., "python") to its extension (".py").
;;    Crucially, we EXCLUDE Emacs Lisp from Eglot activation to prevent conflicts.

;;; Code:

(require 'org)
(require 'ob)
(require 'ob-tangle)
(require 'org-src)
(require 'cl-lib)

(defgroup org-src-context nil
  "Provide LSP support in org-src buffers."
  :group 'org)

;;; --- Customization Variables ---

(defcustom org-src-context-narrow-p t
  "Non-nil means org-src buffers should be narrowed to the editable block.
We recommend T to keep the context visual noise low, while still allowing
LSP to 'see' the invisible text.
If set to nil, the injected context is visible but read-only."
  :type 'boolean
  :group 'org-src-context)

(defcustom org-src-context-max-filesize 500000
  "Max size (in bytes) of an Org file to attempt context collection.
If the buffer is larger than this, context injection is skipped to prevent
editor freeze (lag) during the context collection phase."
  :type 'integer
  :group 'org-src-context)

;;; --- Internal State ---

;; We use Markers to define the editable region.
;; HEAD marker: Placed at the end of the injected header (Context Above).
;; TAIL marker: Placed at the start of the injected footer (Context Below).
(defvar-local org-src-context--head-marker nil)
(defvar-local org-src-context--tail-marker nil)

;;; --- Core Logic: Context Collection ---

(defun org-src-context--get-context-blocks (src-info)
  "Collect relevant context blocks (PREV . NEXT) for SRC-INFO.
Uses a unified strategy: scan buffer and match Language + Tangle target.
This function executes inside the ORIGINAL Org buffer.

Arguments:
  SRC-INFO: The list returned by `org-babel-get-src-block-info'.
            Format: (language body arguments switches name start inner-start inner-end)"
  (let* ((target-lang (nth 0 src-info))
         (target-params (nth 2 src-info))
         ;; Resolve the :tangle parameter. This handles inheritance from
         ;; file-wide properties (e.g. #+PROPERTY: header-args :tangle yes).
         ;; Defaults to "no" if not specified.
         (target-tangle (or (alist-get :tangle target-params) "no"))
         ;; Use Buffer Position (index 5 in light info), not Line Number.
         ;; Integer comparison is faster and less error-prone than line calculations.
         (current-blk-start (nth 5 src-info)))

    ;; OPTIMIZATION: Safety check for massive files.
    (if (> (buffer-size) org-src-context-max-filesize)
        (progn
          (message "Org-Src-Context: File too large (%d bytes), skipping context." (buffer-size))
          nil)

      (let ((prev nil)
            (next nil))
        ;; Scan entire buffer for matching blocks.
        ;; We scan the file on disk/buffer to ensure we catch all blocks,
        ;; even those not explicitly tangled yet (Literate workflow).
        (org-babel-map-src-blocks (buffer-file-name)
          (let* ((info (org-babel-get-src-block-info 'light))
                 (lang (nth 0 info))
                 (params (nth 2 info))
                 (tangle (or (alist-get :tangle params) "no"))
                 (blk-start (nth 5 info)))

            ;; MATCHING LOGIC:
            ;; 1. Language must match (e.g., Python vs Python).
            ;; 2. Tangle target must match.
            ;;    - If both are "no", they belong to the same 'notebook'.
            ;;    - If both are "script.py", they belong to that file.
            (when (and (string= lang target-lang)
                       (string= tangle target-tangle))

              ;; DEDUPLICATION LOGIC:
              ;; We strictly separate blocks into Previous or Next lists based on position.
              ;; IMPORTANT: We explicitly exclude the current block (where blk-start == current-blk-start)
              ;; to prevent code duplication in the edit buffer (LSP would see double definitions).
              (when (and (integerp blk-start) (integerp current-blk-start))
                (cond
                 ;; Previous Block
                 ((< blk-start current-blk-start)
                  (push info prev))
                 ;; Next Block
                 ((> blk-start current-blk-start)
                  (push info next))
                 ;; Current Block (Equal) -> Ignore/Exclude
                 (t nil))))))

        ;; Ordering Fix:
        ;; `org-babel-map-src-blocks` traverses the file top-down (A, B, C).
        ;; `push` adds to the front of the list, reversing the order (C, B, A).
        ;; We need `nreverse` to restore the correct file order (A, B, C) for injection.
        (cons (nreverse prev) (nreverse next))))))

(defun org-src-context--format-block (block)
  "Format a BLOCK list into a string for injection.
Takes the body (nth 1) and ensures it ends with a newline."
  (let ((body (nth 1 block)))
    (if (stringp body)
        (concat body "\n")
      "")))

;;; --- Core Logic: Injection & Properties ---

(defun org-src-context--inject (prev-blocks next-blocks)
  "Inject PREV-BLOCKS and NEXT-BLOCKS into the current (edit) buffer.
This function handles the delicate text properties required to prevent
'ghost newlines' and cursor jumping at boundaries."
  (let ((inhibit-read-only t)
        (inhibit-modification-hooks t))

    (save-excursion
      ;; 1. INJECT HEADER (Previous blocks)
      (goto-char (point-min))
      (let ((start (point)))
        (dolist (b prev-blocks)
          (insert (org-src-context--format-block b)))

        (unless (= start (point))
          (insert "\n") ;; Separator
          ;; STICKINESS EXPLANATION (The "Cursor Jump" Fix):
          ;; We set `rear-nonsticky (read-only)`.
          ;; If the user is at `point-min` (start of their code) and presses Backspace,
          ;; normally they would hit the read-only property of the header and get an error.
          ;; `rear-nonsticky` prevents the read-only property from "sticking" to the cursor
          ;; when moving backwards, allowing backspace to work at the boundary.
          (add-text-properties start (point)
                               '(read-only t
                                           font-lock-face shadow
                                           front-sticky t
                                           rear-nonsticky (read-only)
                                           org-src-context-block t))))

      ;; Set HEAD marker at the end of the injected header.
      ;; Insertion type NIL means: if text is inserted *at* this marker,
      ;; the marker stays *before* the new text. (Context stays above).
      (setq org-src-context--head-marker (point-marker))
      (set-marker-insertion-type org-src-context--head-marker nil)

      ;; 2. INJECT FOOTER (Next blocks)
      (goto-char (point-max))
      (let ((start (point)))
        (unless (bolp) (insert "\n")) ;; Ensure newline before footer
        (dolist (b next-blocks)
          (insert (org-src-context--format-block b)))

        (when (> (point) start)
          ;; STICKINESS EXPLANATION (The "Ghost Newline" Fix):
          ;; We set `front-sticky nil`.
          ;; If the user is at `point-max` (end of their code) and types text or RET,
          ;; normally the new characters might inherit the properties of the following text (the footer).
          ;; `front-sticky nil` ensures new text typed at this boundary is NOT read-only.
          (add-text-properties start (point)
                               '(read-only t
                                           font-lock-face shadow
                                           front-sticky nil
                                           rear-nonsticky t
                                           org-src-context-block t))))

      ;; Set TAIL marker at the start of the footer.
      ;; We scan backwards to find the exact boundary where the 'org-src-context-block' property starts.
      (let ((p (point-max)))
        (while (and (> p (point-min))
                    (get-text-property (1- p) 'org-src-context-block))
          (setq p (1- p)))
        (setq org-src-context--tail-marker (copy-marker p)))

      ;; Insertion type T means: if text is inserted *at* this marker,
      ;; the marker moves *after* the new text. (Context stays below).
      (set-marker-insertion-type org-src-context--tail-marker t)))

  ;; NARROWING
  ;; We narrow the buffer to the region between HEAD and TAIL markers.
  ;; This hides the context visually (if configured) but keeps it available for LSP.
  (when org-src-context-narrow-p
    (when (and org-src-context--head-marker org-src-context--tail-marker)
      (narrow-to-region org-src-context--head-marker org-src-context--tail-marker))))

;;; --- Core Logic: LSP Mocking ---

(defun org-src-context--setup-lsp (info original-dir original-file)
  "Configure buffer-local variables so Eglot can find the root.
Since org-src buffers are temporary and not file-backed, Eglot normally
refuses to start. We fix this by mocking a file path based on the Tangle target
or Language extension."
  (let* ((lang (nth 0 info))
         (params (nth 2 info))
         (tangle-file (alist-get :tangle params))
         ;; Determine correct extension (e.g., python -> .py) using Org's internal map
         (lang-ext (or (cdr (assoc lang org-babel-tangle-lang-exts)) "txt"))

         ;; EXTENSION LOGIC:
         ;; 1. Use extension from tangle file if available.
         ;; 2. Fallback to language extension if tangle is "no" or "yes".
         (file-ext (if (and tangle-file
                            (not (member tangle-file '("yes" "no")))
                            (file-name-extension tangle-file))
                       (file-name-extension tangle-file)
                     lang-ext))

         ;; FILENAME LOGIC:
         ;; 1. Use the explicit tangle filename if provided.
         ;; 2. Construct a mock name "original_src.ext" for literate notebooks.
         ;;    The file doesn't need to exist on disk, but the path must be inside the project.
         (mock-name (if (and tangle-file
                             (not (member tangle-file '("yes" "no"))))
                        tangle-file
                      (concat (file-name-base original-file) "_src." file-ext))))

    ;; Set default-directory to the project root (where the Org file lives).
    (setq-local default-directory original-dir)

    ;; Set buffer-file-name to the mocked path.
    ;; This allows Eglot to walk up the directory tree to find .git or project.toml.
    (setq-local buffer-file-name (expand-file-name mock-name original-dir))

    ;; Trigger Eglot initialization now that the "file" appears valid.
    ;; FIX: We EXCLUDE Emacs Lisp buffers. Elisp has native support and
    ;; forcing Eglot often causes errors or unnecessary server prompts.
    (when (and (fboundp 'eglot-ensure)
               (not (member lang '("emacs-lisp" "elisp"))))
      (eglot-ensure))))

;;; --- Advice & Hooks ---

(defun org-src-context--advice (orig-fn &rest args)
  "Advice for `org-edit-src-code'.
This is the entry point for the package.

1. PERF CHECK: Checks `(car args)` (the CODE argument).
   If CODE is non-nil, it means Org is performing an automated task
   (like indentation or export). We MUST return immediately.

2. COMMAND CHECK: We strictly whitelist the interactive commands `org-edit-special`
   and `org-edit-src-code` (and their aliases).
   If `this-command` is anything else (e.g., `org-return`, `comment-region`,
   `evil-commentary`), we SKIP context injection.
   This prevents the package from interfering with internal Org operations,
   specifically solving the 'Read-Only' bug when editing Elisp blocks in place.

3. COLLECT: If it is an interactive edit, we collect context blocks.

4. EXECUTE: We let `org-edit-src-code` create the buffer.

5. INJECT: We switch to the new buffer and inject the collected context."

  ;; ROBUSTNESS CHECK 1: Ignore transient calls (CODE arg present)
  ;; ROBUSTNESS CHECK 2: Command Whitelist (Only allow user-initiated edits)
  (if (or (car args)
          (not (memq this-command '(org-edit-special
                                    org-edit-src-code
                                    evil-org-edit-src-code))))
      (apply orig-fn args)

    ;; REAL EDIT SESSION
    (let* ((datum (org-element-context))
           (type (org-element-type datum)))
      ;; Only proceed if we are actually at a source block
      (if (not (eq type 'src-block))
          (apply orig-fn args)

        (let* ((info (org-babel-get-src-block-info 'light))
               ;; 1. Collect Context (While still in Org Buffer)
               ;; This will respect inherited PROPERTIES automatically.
               (context-blocks (org-src-context--get-context-blocks info))
               (orig-dir default-directory)
               (orig-file (buffer-file-name)))

          ;; 2. Create Edit Buffer (standard Org behavior)
          (apply orig-fn args)

          ;; 3. We are now in the Edit Buffer. Inject!
          (when context-blocks
            (org-src-context--inject (car context-blocks) (cdr context-blocks)))

          ;; 4. Setup LSP Mocking
          (org-src-context--setup-lsp info orig-dir orig-file))))))

(defun org-src-context--cleanup (&rest _)
  "Clean up narrowing and markers before exiting or aborting.
This is CRITICAL: We must remove injected text before Org saves the buffer
back to the main Org file. If we don't, the injected context will be
pasted into your source block, duplicating code."
  (let ((inhibit-read-only t)
        (inhibit-modification-hooks t))
    (ignore-errors
      (widen)
      ;; Delete the header region
      (when (and org-src-context--head-marker (marker-buffer org-src-context--head-marker))
        (delete-region (point-min) org-src-context--head-marker)
        (set-marker org-src-context--head-marker nil))

      ;; Delete the footer region
      (when (and org-src-context--tail-marker (marker-buffer org-src-context--tail-marker))
        (delete-region org-src-context--tail-marker (point-max))
        (set-marker org-src-context--tail-marker nil)))))

;;;###autoload
(define-minor-mode org-src-context-mode
  "Global mode to inject context into Org Src buffers for LSP.

**Performance Optimized** version by Ahsanur Rahman.

When enabled:
1. Advise `org-edit-src-code` to inject context and setup LSP.
2. Advise `org-edit-src-exit` and `abort` to cleanup injected context."
  :global t
  :group 'org-src-context
  (if org-src-context-mode
      (progn
        ;; Add the main logic
        (advice-add 'org-edit-src-code :around #'org-src-context--advice)
        ;; Add safety cleanup hooks on both exit paths (Save or Abort)
        (advice-add 'org-edit-src-exit :before #'org-src-context--cleanup)
        (advice-add 'org-edit-src-abort :before #'org-src-context--cleanup))
    ;; Remove everything on disable
    (advice-remove 'org-edit-src-code #'org-src-context--advice)
    (advice-remove 'org-edit-src-exit #'org-src-context--cleanup)
    (advice-remove 'org-edit-src-abort #'org-src-context--cleanup)))

(provide 'org-src-context)
;;; org-src-context.el ends here

```

## Installation steps

```bash
# 1. Install Doom Emacs (if you haven't)
git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
~/.config/emacs/bin/doom install

# 2. Place files
mkdir -p ~/.config/doom/lisp
# Save init.el, packages.el, config.org into ~/.config/doom/
# Save org-src-context.el into ~/.config/doom/lisp/

# 3. Sync packages and tangle
doom sync
```

After that, start Emacs. On first startup the `literate` module tangles `config.org → config.el`.

---
