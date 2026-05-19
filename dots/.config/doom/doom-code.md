# Needed Doom Elisp Config Files from https://github.com/doomemacs/doomemacs

[NOTE:] I have only attached the modules files as they are the ones I need you to see

## completion/corfu

### completion/corfu/README.org

```org
#+title:    :completion corfu
#+subtitle: Complete with cap(f), cape, and a flying feather
#+created:  September 9, 2022
#+since:    3.0.0 (#7002)

* Description :unfold:
This module provides code completion, powered by [[doom-package:corfu]].

It is recommended to enable either this or [[doom-module::completion company]] in
case you desire pre-configured auto-completion. Corfu is much lighter weight and
focused, plus it's built on native Emacs functionality, whereas Company is heavy
and highly non-native, but has some extra features and more maturity.

If you choose Corfu, we also highly recomend reading [[https://github.com/minad/corfu][its README]] and [[https://github.com/minad/cape][cape's
README]], as the backend is very configurable and provides many power-user
utilities for fine-tuning. Only some of common behaviors are documented here.

** Maintainers
- [[doom-user:][@LuigiPiucco]]
- [[doom-user:][@LemonBreezes]]

[[doom-contrib-maintainer:][Become a maintainer?]]

** Module flags
- +icons ::
  Display icons beside completion suggestions.
- +orderless ::
  Pull in [[doom-package:orderless]] if necessary and apply multi-component
  completion (still needed if [[doom-module::completion vertico]] is active).
- +dabbrev ::
  Enable and configure [[doom-package:dabbrev]] as a close-to-universal CAPF
  fallback.

** Packages
- [[doom-package:corfu]]
- [[doom-package:cape]]
- [[doom-package:nerd-icons-corfu]] if [[doom-module::completion corfu +icons]]
- [[doom-package:orderless]] if [[doom-module::completion corfu +orderless]]
- [[doom-package:corfu-terminal]] if [[doom-module::os tty]]
- [[doom-package:yasnippet-capf]] if [[doom-module::editor snippets]]

** Hacks
/No hacks documented for this module./

** TODO Changelog
# This section will be machine generated. Don't edit it by hand.
/This module does not have a changelog yet./

* Installation
Enable this module in your ~doom!~ block.

This module has no direct requirements, but some languages may have their own
requirements to fulfill before you get code completion in them (and some
languages may lack code completion support altogether). Run ~$ doom doctor~ to
find out if you're missing any dependencies. Note that Corfu may have support
for completions in languages that have no development intelligence, since it
supports generic, context insensitive candidates such as file names or recurring
words. Snippets may also appear in the candidate list if available.

* TODO Usage
#+begin_quote
 🔨 /This module's usage documentation is incomplete./ [[doom-contrib-module:][Complete it?]]
#+end_quote

By default, completion gets triggered after typing 2 non-space consecutive
characters, by means of [[kbd:][C-SPC]] at any moment or [[kbd:][TAB]] on a line with proper
indentation. Many styles of completion are documented below, which can be
composed to suit the user. The following keybindings are generally available:

| Keybind | Description                                |
|---------+--------------------------------------------|
| [[kbd:][C-n]]     | Go to next candidate                       |
| [[kbd:][C-p]]     | Go to previous candidate                   |
| [[kbd:][C-S-n]]   | Go to next doc line                        |
| [[kbd:][C-S-p]]   | Go to previous doc line                    |
| [[kbd:][C-S-s]]   | Export to minibuffer                       |
| [[kbd:][TAB]]     | (when not completing) Indent or complete   |
| [[kbd:][C-SPC]]   | (when not completing) Complete             |
| [[kbd:][C-u]]     | (evil) Go to next candidate page           |
| [[kbd:][C-d]]     | (evil) Go to previous candidate page       |
| [[kbd:][C-h]]     | (evil) Toggle documentation (if available) |
| [[kbd:][M-t]]     | (emacs) (when not completing) Complete     |

Bindings in the following sections are additive, and unless otherwise noted, are
enabled by default with configurable behavior. Additionally, for users of evil,
[[kdb:][C-SPC]] is smart regarding your state. In normal-like states, enter insert then
start corfu; in visual-like states, perform [[help:evil-change][evil-change]] (which leaves you in
insert state) then start corfu; in insert-like states, start corfu immediatelly.

** Commit preview on type
When the completion popup is visible, by default the current candidate is
previewed into the buffer, and further input commits that candidate as previewed
(note it does not perform candidate exit actions, such as expanding snippets).

The feature is in line with other common editors, but if you prefer the preview
to be only visual or for there to be no preview, configure
[[var:corfu-preview-current]].

#+begin_src emacs-lisp
;; Non-inserting preview
(setq corfu-preview-current t)
;; No preview
(setq corfu-preview-current nil)
#+end_src

** Commit on [[kbd:][RET]] with pass-through
A lot of people like to use [[kbd:][RET]] to commit, so here we bind it to Corfu's
insertion function. Note that Corfu allows "no candidate" to be selected, and in
that case, we have a custom binding to quit completion and pass-through. To make
it less obtrusive by default, the popup starts in this unselected state. See
[[var:corfu-preselect]] to alter the initial behavior; it can start with the first
one selected, for instance. Then, you have to move one candidate backwards to
pass-through The exact action of [[kbd:][RET]] can be changed via
[[var:+corfu-want-ret-to-confirm]].

| Keybind | Description           |
|---------+-----------------------|
| [[kbd:][RET]]     | Insert candidate DWIM |

** Cycle directionally
If you'd rather think in directions rather than next/previous, arrow keys and vi
movements to control the selection and documentation view are bound by default.
You may unbind them by setting to nil, see ~map!~'s documentation.

| Keybind  | Description                     |
|----------+---------------------------------|
| [[kbd:][<down>]]   | Go to next candidate            |
| [[kbd:][<up>]]     | Go to previous candidate        |
| [[kbd:][C-j]]      | (evil) Go to next candidate     |
| [[kbd:][C-k]]      | (evil) Go to previous candidate |
| [[kbd:][C-<down>]] | Go to next doc line             |
| [[kbd:][C-<up>]]   | Go to previous doc line         |
| [[kbd:][C-S-j]]    | (evil) Go to next doc line      |
| [[kbd:][C-S-k]]    | (evil) Go to previous doc line  |

** Cycle with [[kbd:][TAB]]
[[kbd:][TAB]]-based cycling alternatives are also bound according to the table below:

| Keybind | Description              |
|---------+--------------------------|
| [[kbd:][TAB]]     | Go to next candidate     |
| [[kbd:][S-TAB]]   | Go to previous candidate |

** Searching with multiple keywords (~+orderless~)
If the [[doom-module::completion corfu +orderless]] flag is enabled, users can
perform code completion with multiple search keywords by use of space as the
separator. More information can be found [[https://github.com/oantolin/orderless#company][here]]. Pressing [[kdb:][C-SPC]] again while
completing inserts a space as separator. This allows searching with
space-separated terms; each piece will match individually and in any order, with
smart casing. Pressing just [[kbd:][SPC]] acts as normal and quits completion, so that
when typing sentences it doesn't try to complete the whole sentence instead of
just the word. Pressing [[kdb:][C-SPC]] with point after a separator escapes it with a
backslash, including the space in the search term, and pressing it with an
already escaped separator before point deletes it. Thus, you can cycle back if
you accidentaly press more than needed.

| Keybind | Description                                     |
|---------+-------------------------------------------------|
| [[kbd:][C-SPC]]   | (evil) (when completing) Insert separator DWIM  |
| [[kbd:][M-SPC]]   | (emacs) (when completing) Insert separator DWIM |
| [[kbd:][SPC]]     | (when completing) Quit autocompletion           |
| [[kbd:][SPC]]     | (when completing with separators) Self-insert   |

** Exporting to the minibuffer
The entries shown in the completion popup can be exported to a ~completing-read~
minibuffer, giving access to all the manipulations that suite allows. Using
Vertico for instance, one could use this to export with [[doom-package:embark]] via
[[kbd:][C-c C-l]] and get a buffer with all candidates.

* Configuration
A few variables may be set to change behavior of this module:

- [[var:completion-at-point-functions]] ::
  This is not a module/package variable, but a builtin Emacs one. Even so, it's
  very important to how Corfu works, so we document it here. It contains a list
  of functions that are called in turn to generate completion candidates. The
  regular (non-lexical) value should contain few entries and they should
  generally be context aware, so as to predict what you need. Additional
  functions can be added as you get into more and more specific contexts. Also,
  there may be cases where you know beforehand the kind of candidate needed, and
  want to enable only that one. For this, the variable may be lexically bound to
  the correct value, or you may call the CAPF interactively if a single function
  is all you need.
- [[var:corfu-auto-delay]] ::
  Number of seconds till completion occurs automatically. Defaults to 0.1.
- [[var:corfu-auto-prefix]] ::
  Number of characters till auto-completion starts to happen. Defaults to 2.
- [[var:corfu-on-exact-match]] ::
  Configures behavior for exact matches.
- [[var:corfu-preselect]] ::
  Configures startup selection, choosing between the first candidate or the
  prompt.
- [[var:corfu-preview-current]] ::
  Configures current candidate preview.
- [[var:+corfu-want-ret-to-confirm]] ::
  Controls the behavior of [[kbd:][RET]] when the popup is visible - whether it confirms
  the selected candidate, and whether [[kbd:][RET]] is passed through (ie. the normal
  behavior of [[kbd:][RET]] is performed). The default value of ~t~ enables confirmation
  and disables pass-through. Other variations are ~nil~ for pass-through and no
  confirmation and ~both~ for confirmation followed by pass-through. Finally,
  the value of ~minibuffer~ will both confirm and pass-through (like ~both~)
  when in the minibuffer, and only confirm (like ~t~) otherwise.
- [[var:+corfu-buffer-scanning-size-limit]]  ::
  Sets the maximum buffer size to be scanned by ~cape-dabbrev~. Defaults to 1 MB.
  Set this if you are having performance problems using the CAPF.
- [[var:+corfu-want-minibuffer-completion]] ::
  Whether to enable Corfu in the minibuffer. See its documentation for
  additional tweaks.
- [[var:+corfu-want-tab-prefer-expand-snippets]] ::
  Whether to prefer expanding snippets over cycling candidates when pressing
  [[kbd:][TAB]].
- [[var:+corfu-want-tab-prefer-navigating-snippets]] ::
  Whether to prefer navigating snippets over cycling candidates when pressing
  [[kbd:][TAB]] and [[kbd:][S-TAB]].
- [[var:+corfu-want-tab-prefer-navigating-org-tables]] ::
  Whether to prefer navigating org tables over cycling candidates when pressing
  [[kbd:][TAB]] and [[kbd:][S-TAB]].

** Turning off auto-completion
To disable idle (as-you-type) completion, unset ~corfu-auto~:
#+begin_src emacs-lisp
;;; in $DOOMDIR/config.el
(with-eval-after-load 'corfu-auto
  (setq corfu-auto nil))
#+end_src

** Adding CAPFs to a mode
To add other CAPFs on a mode-per-mode basis, put either of the following in your
~config.el~:

#+begin_src emacs-lisp
(add-hook! some-mode (add-hook 'completion-at-point-functions #'some-capf depth t))
;; OR, but note the different call signature
(add-hook 'some-mode-hook (lambda () (add-hook 'completion-at-point-functions #'some-capf depth t)))
#+end_src

~DEPTH~ above is an integer between -100, 100, and defaults to 0 if nil. Also
see ~add-hook!~'s documentation for additional ways to call it. ~add-hook~ only
accepts the quoted arguments form above.

** Adding CAPFs to a key
To add other CAPFs to keys, adapt the snippet below into your ~config.el~:

#+begin_src emacs-lisp
(map! :map some-mode-map
      "C-x e" #'cape-emoji)
#+end_src

It's okay to add to the mode directly because ~completion-at-point~ works
regardless of Corfu (the latter is an enhanced UI for the former). Just note not
all CAPFs are interactive to be called this way, in which case you can use
[[doom-package:cape]]'s adapter to enable this.

* Troubleshooting
[[doom-report:][Report an issue?]]

** Troubleshooting ~cape-dabbrev~

If you have performance issues with ~cape-dabbrev~, the first thing I recommend
doing is to look at the list of buffers Dabbrev is scanning:

#+begin_src emacs-lisp
(dabbrev--select-buffers) ; => (#<buffer README.org> #<buffer config.el<3>> #<buffer cape.el> ...)
(length (dabbrev--select-buffers)) ; => 37
#+end_src

... and modify ~dabbrev-ignored-buffer-regexps~ or ~dabbrev-ignored-buffer-modes~
accordingly.

If you see garbage completion candidates, you can use the following command to
debug the issue:

#+begin_src emacs-lisp
;;;###autoload
(defun search-in-dabbrev-buffers (search-string)
  "Search for SEARCH-STRING in all buffers returned by `dabbrev--select-buffers'."
  (interactive "sSearch string: ")
  (let ((buffers (dabbrev--select-buffers)))
    (multi-occur buffers search-string)))

;; Example usage:
;; Why are these weird characters appearing in my completions?
(search-in-dabbrev-buffers "\342\200\231")
#+end_src

** Fixing TAB Keybindings

If you encounter an issue where your ~TAB~ keybindings are not responding in Doom
Emacs while the ~:editor evil~ module is active, it's likely caused by a conflict
where ~<tab>~ keybindings and insert state bindings are overriding your ~TAB~ key
assignments.

In Evil mode, keybinding priorities are set such that:
1. ~<tab>~ keybindings supersede ~TAB~ keybindings and only work in GUI Emacs.
2. Bindings in insert state take precedence whenever the insert state is active.

To resolve this conflict and to assign your desired command to the ~TAB~ key, you
must redefine the keybindings with insert state set explicitly. You can do this
by configuring your ~evil~ keybindings for the insert state as follows:

#+begin_src emacs-lisp
(map! :gi "TAB"   #'your-command
      :gi "<tab>" #'your-command)
#+end_src

Place this code in your Doom Emacs configuration file to set the function ~your-command~ as the response to pressing ~TAB~ during insert mode.

Remember to replace ~#'your-command~ with the actual command you wish to invoke
with the ~TAB~ key.

If ever in a situation like this, use ~describe-key~ with ~C-h k~ and look at what
command is being called as well as what keymaps the command is defined in.

* Frequently asked questions
/This module has no FAQs yet./ [[doom-suggest-faq:][Ask one?]]

* TODO Appendix
#+begin_quote
 🔨 This module has no appendix yet. [[doom-contrib-module:][Write one?]]
#+end_quote

```

### completion/corfu/autoload.el

```elisp
;;; completion/corfu/autoload.el -*- lexical-binding: t; -*-

;;;###autoload
(defun +corfu-dabbrev-friend-buffer-p (other-buffer)
  (< (buffer-size other-buffer) +corfu-buffer-scanning-size-limit))


;;
;;; Commands

;;;###autoload
(defun +corfu/move-to-minibuffer ()
  "Move list of candidates to your choice of minibuffer completion UI."
  (interactive)
  (unless completion-in-region--data
    (user-error "No completion active"))
  (pcase-let ((`(,beg ,end ,table ,pred ,extras)
               completion-in-region--data))
    (let ((completion-extra-properties extras)
          completion-cycle-threshold
          completion-cycling)
      (cond ((and (modulep! :completion vertico)
                  (fboundp #'consult-completion-in-region))
             (consult-completion-in-region beg end table pred))
            ;; DEPRECATED: ivy module is deprecated
            ((and (modulep! :completion ivy)
                  (fboundp #'ivy-completion-in-region))
             (ivy-completion-in-region (marker-position beg) (marker-position end) table pred))
            ;; Important: `completion-in-region-function' is set to corfu at
            ;; this moment, so `completion-in-region' (single -) doesn't work
            ;; below.
            ((modulep! :completion helm)
             ;; Helm is special and wants to _wrap_ `completion--in-region'
             ;; instead of replacing it in `completion-in-region-function'.  But
             ;; because the advice is too unreliable we "fake" the wrapping.
             (helm--completion-in-region #'completion--in-region beg end table pred))
            ((modulep! :completion ido)
             (completion--in-region beg end table pred))
            ((user-error "No minibuffer completion UI available for moving to!"))))))

;;;###autoload
(defun +corfu/smart-sep-toggle-escape ()
  "Insert `corfu-separator' or toggle escape if it's already there."
  (interactive)
  (cond ((and (char-equal (char-before) corfu-separator)
              (char-equal (char-before (1- (point))) ?\\))
         (save-excursion (delete-char -2)))
        ((char-equal (char-before) corfu-separator)
         (save-excursion (backward-char 1)
                         (insert-char ?\\)))
        ((call-interactively #'corfu-insert-separator))))

;;;###autoload
(defun +corfu/dabbrev-this-buffer ()
  "Like `cape-dabbrev', but only scans current buffer."
  (interactive)
  (require 'cape)
  (let ((cape-dabbrev-buffer-function #'current-buffer))
    (cape-dabbrev t)))

;;;###autoload
(defun +corfu/toggle-auto-complete (&optional interactive)
  "Toggle as-you-type completion in Corfu."
  (interactive (list 'interactive))
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when corfu-mode
        (if corfu-auto
            (remove-hook 'post-command-hook #'corfu-auto--post-command 'local)
          (add-hook 'post-command-hook #'corfu-auto--post-command nil 'local)))))
  (when interactive
    (message "Corfu auto-complete %s" (if corfu-auto "disabled" "enabled")))
  (setq corfu-auto (not corfu-auto)))

;;;###autoload
(defun +corfu/dabbrev-or-next (&optional arg)
  "Invoke `cape-dabbrev' but respect `evil-complete-all-buffers'.

Intended to mimic `evil-complete-next', unless the popup is already open."
  (interactive "p")
  (if corfu--candidates
      (corfu-next arg)
    (require 'cape)
    (let ((cape-dabbrev-buffer-function
           (if (bound-and-true-p evil-complete-all-buffers)
               #'cape-same-mode-buffers
             #'current-buffer)))
      (cape-dabbrev t)
      (when (> corfu--total 0)
        (corfu--goto (or arg 0))))))

;;;###autoload
(defun +corfu/dabbrev-or-last (&optional arg)
  "Invoke `cape-dabbrev' but respect `evil-complete-all-buffers'.

Intended to mimic `evil-complete-previous', unless the popup is already open."
  (interactive "p")
  (if corfu--candidates
      (corfu-previous arg)
    (require 'cape)
    (let ((cape-dabbrev-buffer-function
           (if (bound-and-true-p evil-complete-all-buffers)
               #'cape-same-mode-buffers
             #'current-buffer)))
      (cape-dabbrev t)
      (when (> corfu--total 0)
        (corfu--goto (- corfu--total (or arg 1)))))))

;;; end of autoload.el

```

### completion/corfu/config.el

```
;;; completion/corfu/config.el -*- lexical-binding: t; -*-

(defcustom +corfu-want-ret-to-confirm t
  "Configure how the user expects RET to behave.

Possible values are:
- t (default): Insert candidate if one is selected, pass-through otherwise;
- nil: Pass-through without inserting;
- `both': Insert candidate if one is selected, then pass-through;
- `minibuffer': Behaves like `both` in the minibuffer and `t` otherwise."
  :type '(choice (const :tag "Insert if selected, passthrough otherwise" t)
                 (const :tag "Passthrough without insertion" nil)
                 (const :tag "Insert if selected, then passthrough" both)
                 (const :tag "Behaves like `both' in minibuffer, `t' otherwise" minibuffer))
  :group '+corfu)

(defcustom +corfu-buffer-scanning-size-limit (* 1 1024 1024) ; 1 MB
  "Size limit in bytes for a buffer to be scanned by `cape-dabbrev'."
  :type 'integer
  :group '+corfu)

(defcustom +corfu-want-minibuffer-completion t
  "Whether to enable Corfu in the minibuffer.

Possible values are:
- t: enable Corfu only if `completion-at-point' is bound in the minibuffer's
  `current-local-map'.
- nil: Corfu is disabled in the minibuffer.
- aggressive: enable Corfu even when no recognized completion framework is
  active."
  :type '(choice (const :tag "Disabled" nil)
                 (const :tag "Aggressive" aggressive)
                 (const :tag "Only when bound" t))
  :group '+corfu)

(defcustom +corfu-want-tab-prefer-expand-snippets nil
  "If non-nil, expand snippets over cycling candidates with TAB."
  :type 'boolean
  :group '+corfu)

(defcustom +corfu-want-tab-prefer-navigating-snippets nil
  "If non-nil, navigate snippets over cycling candidates with TAB/S-TAB."
  :type 'boolean
  :group '+corfu)

(defcustom +corfu-want-tab-prefer-navigating-org-tables nil
  "If non-nil, navigate org tables over cycling candidates with TAB/S-TAB."
  :type 'boolean
  :group '+corfu)

(defcustom +corfu-inhibit-auto-functions ()
  "A list of predicate functions that take no arguments.

If any return non-nil, `corfu-auto' will not invoke as-you-type completion."
  :type 'hook
  :group '+corfu)


;;
;;; Packages

(use-package! corfu
  :hook (doom-first-input . global-corfu-mode)
  :config
  (setq corfu-auto t
        global-corfu-modes
        '((not erc-mode
               circe-mode
               help-mode
               gud-mode
               vterm-mode)
          t)
        corfu-cycle t
        corfu-preselect 'prompt
        corfu-count 16
        corfu-max-width 120
        corfu-on-exact-match nil
        corfu-quit-at-boundary (if (or (modulep! :completion vertico)
                                       (modulep! +orderless))
                                   'separator t)
        corfu-quit-no-match corfu-quit-at-boundary)

  (add-to-list 'completion-category-overrides `(lsp-capf (styles ,@completion-styles)))
  (add-to-list 'corfu-continue-commands #'+corfu/move-to-minibuffer)
  (add-to-list 'corfu-continue-commands #'+corfu/smart-sep-toggle-escape)
  (add-hook 'evil-insert-state-exit-hook #'corfu-quit)

  (defun +corfu--other-completion-active-p ()
    "Return non-nil if another completion framework is already active.

This checks for several completion systems such as mct, vertico,
auth-source’s read-passwd-map, helm, ido, and ivy. When one of these
systems is active, Corfu should not enable its own completion."
    (or (bound-and-true-p mct--active)
        (bound-and-true-p vertico--input)
        (and (featurep 'auth-source)
             (eq (current-local-map) read-passwd-map))
        (and (featurep 'helm-core)
             (helm--alive-p))
        (and (featurep 'ido)
             (ido-active))
        (where-is-internal 'minibuffer-complete (list (current-local-map)))
        (memq #'ivy--queue-exhibit post-command-hook)))

  (defun +corfu-enable-in-minibuffer-p ()
    "Return non-nil if Corfu should be enabled in the minibuffer.

See `+corfu-want-minibuffer-completion'."
    (pcase +corfu-want-minibuffer-completion
      ('nil nil)
      ('aggressive (not (+corfu--other-completion-active-p)))
      (_ (and (where-is-internal #'completion-at-point
                                 (list (current-local-map)))
              (not (+corfu--other-completion-active-p))))))

  (setq global-corfu-minibuffer #'+corfu-enable-in-minibuffer-p)

  ;; HACK: If you want to update the visual hints after completing minibuffer
  ;;   commands with Corfu and exiting, you have to do it manually.
  (defadvice! +corfu--insert-before-exit-minibuffer-a ()
    :before #'exit-minibuffer
    (when (or (and (frame-live-p corfu--frame)
                   (frame-visible-p corfu--frame))
              (and (featurep 'corfu-terminal)
                   (popon-live-p corfu-terminal--popon)))
      (when (member isearch-lazy-highlight-timer timer-idle-list)
        (apply (timer--function isearch-lazy-highlight-timer)
               (timer--args isearch-lazy-highlight-timer)))
      (when (member (bound-and-true-p anzu--update-timer) timer-idle-list)
        (apply (timer--function anzu--update-timer)
               (timer--args anzu--update-timer)))
      (when (member (bound-and-true-p evil--ex-search-update-timer)
                    timer-idle-list)
        (apply (timer--function evil--ex-search-update-timer)
               (timer--args evil--ex-search-update-timer)))))

  ;; HACK: If your dictionaries aren't set up in text-mode buffers, ispell will
  ;;   continuously pester you about errors. This ensures it only happens once
  ;;   per session.
  (defadvice! +corfu--auto-disable-ispell-capf-a (fn &rest args)
    "If ispell isn't properly set up, only complain once per session."
    :around #'ispell-completion-at-point
    (condition-case-unless-debug e
        (apply fn args)
      ('error
       (message "Error: %s" (error-message-string e))
       (message "Auto-disabling `text-mode-ispell-word-completion'")
       (setq text-mode-ispell-word-completion nil)
       (remove-hook 'completion-at-point-functions #'ispell-completion-at-point t)))))


(use-package! corfu-auto
  :defer t
  :config
  (setq corfu-auto-delay
        (if (featurep :system 'macos)
            0.4  ; MacOS is slower, so go easy on it
          0.24)
        corfu-auto-prefix 2)
  (add-to-list 'corfu-auto-commands #'lispy-colon)

  (when (modulep! :editor evil)
    ;; Modifying the buffer while in replace mode can be janky.
    (add-to-list '+corfu-inhibit-auto-functions #'evil-replace-state-p))

  ;; HACK: Augments Corfu to respect `+corfu-inhibit-auto-functions'.
  (defadvice! +corfu--post-command-a (fn &rest args)
    "Refresh Corfu after last command."
    :around #'corfu--popup-support-p
    (let ((corfu-auto
           (if corfu-auto
               (not (run-hook-with-args-until-success '+corfu-inhibit-auto-functions)))))
      (apply fn args))))


(use-package! cape
  :defer t
  :init
  (add-hook! 'prog-mode-hook
    (defun +corfu-add-cape-file-h ()
      (add-hook 'completion-at-point-functions #'cape-file -10 t)))
  (add-hook! '(org-mode-hook markdown-mode-hook)
    (defun +corfu-add-cape-elisp-block-h ()
      (add-hook 'completion-at-point-functions #'cape-elisp-block 0 t)))
  ;; Enable Dabbrev completion basically everywhere as a fallback.
  (when (modulep! +dabbrev)
    (setq cape-dabbrev-check-other-buffers t)
    ;; Set up `cape-dabbrev' options.
    (add-hook! '(prog-mode-hook
                 text-mode-hook
                 conf-mode-hook
                 comint-mode-hook
                 minibuffer-setup-hook
                 eshell-mode-hook)
      (defun +corfu-add-cape-dabbrev-h ()
        (add-hook 'completion-at-point-functions #'cape-dabbrev 20 t)))
    (after! dabbrev
      (setq dabbrev-friend-buffer-function #'+corfu-dabbrev-friend-buffer-p
            dabbrev-ignored-buffer-regexps
            '("\\` "
              "\\(?:\\(?:[EG]?\\|GR\\)TAGS\\|e?tags\\|GPATH\\)\\(<[0-9]+>\\)?")
            dabbrev-upcase-means-case-search t)
      (add-to-list 'dabbrev-ignored-buffer-modes 'pdf-view-mode)
      (add-to-list 'dabbrev-ignored-buffer-modes 'doc-view-mode)
      (add-to-list 'dabbrev-ignored-buffer-modes 'tags-table-mode)))

  ;; Make these capfs composable.
  (advice-add #'lsp-completion-at-point :around #'cape-wrap-noninterruptible)
  (advice-add #'lsp-completion-at-point :around #'cape-wrap-nonexclusive)
  (advice-add #'comint-completion-at-point :around #'cape-wrap-nonexclusive)
  (advice-add #'eglot-completion-at-point :around #'cape-wrap-nonexclusive)
  (advice-add #'pcomplete-completions-at-point :around #'cape-wrap-nonexclusive)

  (when (modulep! :lang latex)
    ;; Allow file completion on latex directives.
    (setq-hook! '(tex-mode-local-vars-hook
                  latex-mode-local-vars-hook
                  LaTeX-mode-local-vars-hook)
      cape-file-prefix "{")))

(use-package! yasnippet-capf
  :when (modulep! :editor snippets)
  :defer t
  :init
  (add-hook! 'yas-minor-mode-hook
    (defun +corfu-add-yasnippet-capf-h ()
      (add-hook 'completion-at-point-functions #'yasnippet-capf 30 t))))

(use-package! corfu-terminal
  :when (modulep! :os tty)
  :unless (featurep 'tty-child-frames)
  :hook ((corfu-mode . corfu-terminal-mode)))


;;
;;; Extensions

(use-package! corfu-history
  :hook ((corfu-mode . corfu-history-mode))
  :config
  (after! savehist (add-to-list 'savehist-additional-variables 'corfu-history)))

(use-package! corfu-popupinfo
  :hook ((corfu-mode . corfu-popupinfo-mode))
  :config
  (setq corfu-popupinfo-delay '(0.5 . 1.0)))

(use-package! nerd-icons-corfu
  :when (modulep! +icons)
  :defer t
  :init
  (after! corfu
    (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter)))

;; If vertico is not enabled, orderless will be installed but not configured.
;; That may break smart separator behavior, so we conditionally configure it.
(use-package! orderless
  :when (not (modulep! :completion vertico))
  :when (modulep! +orderless)
  :config
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides '((file (styles orderless partial-completion)))
        orderless-component-separator #'orderless-escapable-split-on-space))
```

### completion/corfu/packages.el

```
;; -*- no-byte-compile: t; -*-
;;; completion/corfu/packages.el

(package! corfu :pin "80b3e0264b840c98a131534c2cfd585659ad1372")
(package! cape :pin "9a93d13e223ca3fc469bce4b2932d9e74bdfae57")
(when (modulep! +icons)
  (package! nerd-icons-corfu :pin "f821e953b1a3dc9b381bc53486aabf366bf11cb1"))
(when (and (not (modulep! :completion vertico))
           (modulep! +orderless))
  ;; Enabling +orderless without vertico should be fairly niche enough that to
  ;; save contributor headaches we should only pin vertico's orderless and leave
  ;; this one unpinned.
  (package! orderless))
(when (and (modulep! :os tty)
           (not (featurep 'tty-child-frames)))
  (package! corfu-terminal :pin "501548c3d51f926c687e8cd838c5865ec45d03cc"))
(when (modulep! :editor snippets)
  (package! yasnippet-capf :pin "f53c42a996b86fc95b96bdc2deeb58581f48c666"))
```

## completion/vertico

### completion/vertico/README.org

```org
#+title:    :completion vertico
#+subtitle: Tomorrow's search engine
#+created:  July 25, 2021
#+since:    21.12.0 (#4664)

* Description :unfold:
This module enhances the Emacs search and completion experience, and also
provides a united interface for project search and replace, powered by [[https://github.com/BurntSushi/ripgrep/][ripgrep]].

It does this with several modular packages focused on enhancing the built-in
~completing-read~ interface, rather than replacing it with a parallel ecosystem
like [[doom-package:ivy]] and [[doom-package:helm]] do. The primary packages are:

- Vertico, which provides the vertical completion user interface
- Consult, which provides a suite of useful commands using ~completing-read~
- Embark, which provides a set of minibuffer actions
- Marginalia, which provides annotations to completion candidates
- Orderless, which provides better filtering methods

** Maintainers
- [[doom-user:][@iyefrat]]

[[doom-contrib-maintainer:][Become a maintainer?]]

** Module flags
- +childframe ::
  Display completion candidates in a [[https://www.gnu.org/software/emacs/manual/html_node/elisp/Child-Frames.html][child frame]] rather than an overlay or
  tooltip. *Requires GUI Emacs.*

- +icons ::
  Add icons to =file= and =buffer= category completion selections.

** Packages
- [[doom-package:nerd-icons-completion]] if [[doom-module:+icons]]
- [[doom-package:consult]]
- [[doom-package:consult-flycheck]] if [[doom-module::checkers syntax]]
- [[doom-package:embark]]
- [[doom-package:embark-consult]]
- [[doom-package:marginalia]]
- [[doom-package:orderless]]
- [[doom-package:vertico]]
- [[doom-package:vertico-posframe]] if [[doom-module:+childframe]]
- [[doom-package:wgrep]]

** Hacks
/No hacks documented for this module./

** TODO Changelog
# This section will be machine generated. Don't edit it by hand.
/This module does not have a changelog yet./

* Installation
[[id:01cffea4-3329-45e2-a892-95a384ab2338][Enable this module in your ~doom!~ block.]]

This module has only one requirement: [[https://github.com/BurntSushi/ripgrep][Ripgrep]] (built with [[https://www.pcre.org/][PCRE]] support; run ~$
doom doctor~ to determine if your build meets this requirement), which is a hard
dependency of Doom itself, so you should already have it installed.

Otherwise, Consult (a plugin this module installs) provides many commands to
interface with a variety of programs from [[https://github.com/junegunn/fzf][fzf]] to [[https://kapeli.com/dash][Dash docsets]] to [[https://www.passwordstore.org/][pass]] and /much/
more. These programs are optional for this module, but must be installed if you
intend to use their associated Helm command or plugin.

* TODO Usage
#+begin_quote
 󱌣 /This module's usage documentation is incomplete./ [[doom-contrib-module:][Complete it?]]
#+end_quote

The packages in this module modify and use the built-in ~completing-read~
function, which is used by any function that requires completion. Due to this
the full scope of these packages is too large to cover here and you are
encouraged to go and read their excellent documentation. We will detail
Doom-specific additions:

** Vertico keybindings
When in an active Vertico completion session, the following doom added
keybindings are available:

| Keybind                               | Description                                                  |
|---------------------------------------+--------------------------------------------------------------|
| [[kbd:][C-k]]                         | (evil) Go to previous candidate                              |
| [[kbd:][C-j]]                         | (evil) Go to next candidate                                  |
| [[kbd:][C-M-k]]                       | (evil) Go to previous group                                  |
| [[kbd:][C-M-j]]                       | (evil) Go to next group                                      |
| [[kbd:][C-;]] or [[kbd:][<leader> a]] | Open an ~embark-act~ menu to chose a useful action             |
| [[kbd:][C-c C-;]]                     | export the current candidate list to a buffer                |
| [[kbd:][C-c C-l]]                     | ~embark-collect~ the current candidate list (collect verbatim) |
| [[kbd:][C-SPC]]                       | Preview the current candidate                                |

~embark-act~ will prompt you with a =which-key= menu with useful commands on the
selected candidate or candidate list, depending on the completion category. Note
that you can press [[kbd:][C-h]] instead of choosing a command to filter through the
options with a Vertico buffer, that also has slightly more detailed descriptions
due to Marginalia annotations.

** Jump-to navigation
This module provides an interface to navigate within a project using
[[doom-package:projectile]]:

https://assets.doomemacs.org/completion/vertico/projectile.png

| Keybind                              | Description                         |
|--------------------------------------+-------------------------------------|
| [[kbd:][SPC p f]], [[kbd:][SPC SPC]] | Jump to file in project             |
| [[kbd:][SPC f f]], [[kbd:][SPC .]]   | Jump to file from current directory |
| [[kbd:][SPC s i]]                    | Jump to symbol in file              |

** Project search & replace
This module provides interactive text search and replace using ripgrep.

| Keybind                | Description              |
|------------------------+--------------------------|
| [[kbd:][<leader> s p]] | Search project           |
| [[kbd:][<leader> s P]] | Search another project   |
| [[kbd:][<leader> s d]] | Search this directory    |
| [[kbd:][<leader> s D]] | Search another directory |

https://assets.doomemacs.org/completion/vertico/search.png

Prefixing these keys with the universal argument ([[kbd:][SPC u]] for evil users; [[kbd:][C-u]]
otherwise) changes the behavior of these commands, instructing the underlying
search engine to include ignored files.

This module also provides Ex Commands for evil users:
| Ex command           | Description                                                    |
|----------------------+----------------------------------------------------------------|
| ~:pg[rep][!] [QUERY]~  | Search project (if ~!~, include hidden files)                    |
| ~:pg[rep]d[!] [QUERY]~ | Search from current directory (if ~!~, don't search recursively) |

The optional ~!~ is equivalent to the universal argument for the previous
commands.

-----

On top of the usual Vertico keybindings, search commands also offer support for
exporting the current candidate list to an editable buffer [[kbd:][C-c C-e]]. After
editing the changes can be committed with [[kbd:][C-c C-c]] and aborted with [[kbd:][C-c C-k]]
(alternatively [[kbd:][ZZ]] and [[kbd:][ZQ]], for evil users). It uses [[doom-package:wgrep]] for grep searches,
[[doom-package:wdired]] for file searches, and =occur= for buffer searches.

https://assets.doomemacs.org/completion/vertico/search-replace.png

** In-buffer searching
This module provides some in buffer searching bindings:

- [[kbd:][SPC s s]] (~isearch~)
- [[kbd:][SPC s S]] (~+vertico/search-symbol-at-point~ via ~consult-line~)
- [[kbd:][SPC s b]] (~consult-line~)

https://assets.doomemacs.org/completion/vertico/buffer-search.png

An ~occur-edit~ buffer can be opened from ~consult-line~ with [[kbd:][C-c C-e]].

** Vertico integration for various completing commands
*** General
| Keybind                        | Description                 |
|--------------------------------+-----------------------------|
| [[kbd:][M-x]], [[kbd:][SPC :]] | Enhanced M-x                |
| [[kbd:][SPC ']]                | Resume last Vertico session |

*** Jump to files, buffers or projects
| Keybind                              | Description                           |
|--------------------------------------+---------------------------------------|
| [[kbd:][SPC RET]]                    | Find bookmark                         |
| [[kbd:][SPC f f]], [[kbd:][SPC .]]   | Browse from current directory         |
| [[kbd:][SPC p f]], [[kbd:][SPC SPC]] | Find file in project                  |
| [[kbd:][SPC f r]]                    | Find recently opened file             |
| [[kbd:][SPC p p]]                    | Open another project                  |
| [[kbd:][SPC b b]], [[kbd:][SPC ,]]   | Switch to buffer in current workspace |
| [[kbd:][SPC b B]], [[kbd:][SPC <]]   | Switch to buffer                      |

[[kbd:][SPC b b]] and [[kbd:][SPC ,]] support changing the workspace you're selecting a buffer from
via [[https://github.com/minad/consult#narrowing-and-grouping][Consult narrowing]], e.g. if you're on the first workspace, you can switch to
selecting a buffer from the third workspace by typing [[kbd:][3 SPC]] into the prompt, or
the last workspace by typing [[kbd:][0 SPC]].

[[kbd:][SPC f f]] and [[kbd:][SPC .]] support exporting to a [[kbd:][wdired]] buffer using [[kbd:][C-c C-e]].

*** Search
| Keybind           | Description                               |
|-------------------+-------------------------------------------|
| [[kbd:][SPC p t]] | List all TODO/FIXMEs in project           |
| [[kbd:][SPC s b]] | Search the current buffer                 |
| [[kbd:][SPC s d]] | Search this directory                     |
| [[kbd:][SPC s D]] | Search another directory                  |
| [[kbd:][SPC s i]] | Search for symbol in current buffer       |
| [[kbd:][SPC s p]] | Search project                            |
| [[kbd:][SPC s P]] | Search another project                    |
| [[kbd:][SPC s s]] | Search the current buffer (incrementally) |

*** File Path Completion
Note that Emacs allows you to switch directories with shadow paths, for example
starting at =/foo/bar/baz=, typing =/foo/bar/baz/~/= will switch the searched
path to the home directory. For more information see ~substitute-in-file-name~
and ~file-name-shadow-mode~. This module will erase the "shadowed" portion of
the path from the minibuffer, so in the previous example the path will be reset
to =~/=.

** Consult
*** Multiple candidate search
This module modifies the default keybindings used in
~consult-completing-read-multiple~:
| Keybind       | Description                                                 |
|---------------+-------------------------------------------------------------|
| [[kbd:][TAB]] | Select or deselect current candidate                        |
| [[kbd:][RET]] | Enters selected candidates (also toggles current candidate) |

*** Async search commands
:PROPERTIES:
:ID:       4ab16bf0-f9e8-4798-8632-ee7b13d2291e
:END:
Consult async commands (e.g. ~consult-ripgrep~) will have a preceding separator
character (usually ~#~) before the search input. This is known as the =perl=
splitting style. Input typed after the separator will be fed to the async
command until you type a second separator, afterwhich the candidate list will be
filtered with Emacs instead (and can be filtered using [[doom-package:orderless]], for example).
The specific separator character can be changed by editing it, and might be
different if the initial input already contains =#=.

Note that grep-like async commands translate the input (between the first and
second =#=) to an Orderless-light expression: space separated inputs are all
matched in any order. If the grep backend does not support PCRE lookahead, it'll
only accept 3 space separated inputs to prevent long lookup times, and further
filtering should be done after a second =#=.

For more information [[https://github.com/minad/consult#asynchronous-search][see here]].

** Marginalia
| Keybind       | Description                     |
|---------------+---------------------------------|
| [[kbd:][M-A]] | Cycle between annotation levels |

Marginalia annotations for symbols (e.g. [[kbd:][SPC h f]] and [[kbd:][SPC h v]]) come with extra
information the nature of the symbol. For the meaning of the annotations see
~marginalia--symbol-class~.

** Orderless filtering
When using orderless to filter through candidates, the default behaviour is for
each space separated input to match the candidate as a regular expression or
literally.

Note that due to this style of matching, pressing tab does not expand the input
to the longest matching prefix (like shell completion), but rather uses the
first matched candidate as input. Filtering further is instead achieved by
pressing space and entering another input. In essence, when trying to match
=foobar.org=, instead of option 1., use option 2.:

1. (BAD) Enter ~foo TAB~, completes to =foobar.=, enter ~org RET~
2. (GOOD) Enter ~foo SPC org RET~

Doom has some builtin [[https://github.com/oantolin/orderless#style-dispatchers][style dispatchers]] for more fine-grained filtering, which
you can use to further specify each space separated input in the following ways:
| Input        | Description                              |
|--------------+------------------------------------------|
| ~!foo~         | match without literal input =foo=          |
| ~%foo~ or ~foo%~ | perform ~char-fold-to-regexp~ on input =foo= |
| ~`foo~ or ~foo`~ | match input =foo= as an initialism         |
| ~=foo~ or ~foo=~ | match only with literal input =foo=        |
| ~~foo~ or ~foo~~ | match input =foo= with fuzzy/flex matching |

* TODO Configuration
#+begin_quote
 󱌣 /This module's configuration documentation is incomplete./ [[doom-contrib-module:][Complete it?]]
#+end_quote

If you want to further configure this module, here are some good places to
start:

** Vertico
 Vertico provides several [[https://github.com/minad/vertico#extensions][extentions]] that can be used to extend it's interface

** Consult
Much of the behaviour of Consult commands can be changed with
~consult-customize~. The =vertico= module already does this, if you want to
override the module's modifications, do:
#+begin_src emacs-lisp
(setq consult--customize-alist nil)
(consult-customize ...)
#+end_src

If you are changing the preview key (set to [[kbd:][C-SPC]]), remember to change the
binding on ~vertico-map~ as well, as the binding there gets previews to work to
an extent on non-consult commands as well.

** Marginalia
You can add more Marginalia annotation levels and change the existing ones by
editing ~marginalia-annotator-registry~

** Embark
You can change the available commands in Embark for category ~$cat~ by editing
~embark-$cat-map~, and even add new categories. Note that you add categories by
defining them [[https://github.com/minad/marginalia/#adding-custom-annotators-or-classifiers][through marginalia]], and embark picks up on them.

* Troubleshooting
/There are no known problems with this module./ [[doom-report:][Report one?]]

* Frequently asked questions
[[doom-suggest-faq:][Ask a question?]]

** Helm vs Ivy vs Ido vs Vertico
See [[id:4f36ae11-1da8-4624-9c30-46b764e849fc][this answer]].

* TODO Appendix
#+begin_quote
 󱌣 This module has no appendix yet. [[doom-contrib-module:][Write one?]]
#+end_quote
```

### completion/vertico/config.el

```el
;;; completion/vertico/config.el -*- lexical-binding: t; -*-

(defvar +vertico-company-completion-styles '(basic partial-completion orderless)
  "Completion styles for company to use.

The completion/vertico module uses the orderless completion style by default,
but this returns too broad a candidate set for company completion. This variable
overrides `completion-styles' during company completion sessions.")

(defvar +vertico-consult-dir-container-executable "docker"
  "Command to call for listing container hosts.")

(defvar +vertico-consult-dir-container-args nil
  "Command to call for listing container hosts.")


;;
;;; Packages

(use-package! vertico
  :hook (doom-first-input . vertico-mode)
  :init
  (defadvice! +vertico-crm-indicator-a (args)
    :filter-args #'completing-read-multiple
    (cons (format "[CRM%s] %s"
                  (replace-regexp-in-string
                   "\\`\\[.*?]\\*\\|\\[.*?]\\*\\'" ""
                   crm-separator)
                  (car args))
          (cdr args)))
  :config
  (setq vertico-resize nil
        vertico-count 17
        vertico-cycle t)

  (setq-default completion-in-region-function
                (lambda (&rest args)
                  (apply (if vertico-mode
                             #'consult-completion-in-region
                           #'completion--in-region)
                         args)))

  (map! :when (modulep! :editor evil +everywhere)
        :map vertico-map
        "M-RET" #'vertico-exit-input
        "C-SPC" #'+vertico/embark-preview
        "C-j"   #'vertico-next
        "C-M-j" #'vertico-next-group
        "C-k"   #'vertico-previous
        "C-M-k" #'vertico-previous-group
        "C-h" (cmds! (eq 'file (vertico--metadata-get 'category)) #'vertico-directory-up)
        "C-l" (cmds! (eq 'file (vertico--metadata-get 'category)) #'+vertico/enter-or-preview))

  ;; Cleans up path when moving directories with shadowed paths syntax, e.g.
  ;; cleans ~/foo/bar/// to /, and ~/foo/bar/~/ to ~/.
  (add-hook 'rfn-eshadow-update-overlay-hook #'vertico-directory-tidy)
  (add-hook 'minibuffer-setup-hook #'vertico-repeat-save)
  (map! :map vertico-map "DEL" #'vertico-directory-delete-char)

  ;; These commands are problematic and automatically show the *Completions* buffer
  (advice-add #'tmm-add-prompt :after #'minibuffer-hide-completions)
  (defadvice! +vertico--suppress-completion-help-a (fn &rest args)
    :around #'ffap-menu-ask
    (letf! ((#'minibuffer-completion-help #'ignore))
      (apply fn args))))


(use-package! orderless
  :after-call doom-first-input-hook
  :config
  (setq orderless-affix-dispatch-alist
        '((?! . orderless-without-literal)
          (?& . orderless-annotation)
          (?% . char-fold-to-regexp)
          (?` . orderless-initialism)
          (?= . orderless-literal)
          (?^ . orderless-literal-prefix)
          (?~ . orderless-flex))
        orderless-style-dispatchers
        '(+vertico-orderless-dispatch
          +vertico-orderless-disambiguation-dispatch))

  (add-to-list
   'completion-styles-alist
   '(+vertico-basic-remote-try-completion
     +vertico-basic-remote-all-completions
     "Use basic completion on remote files only"))
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        ;; note that despite override in the name orderless can still be used in
        ;; find-file etc.
        completion-category-overrides '((file (styles orderless partial-completion)))
        orderless-component-separator #'orderless-escapable-split-on-space)
  ;; ...otherwise find-file gets different highlighting than other commands
  (set-face-attribute 'completions-first-difference nil :inherit nil)

  (defadvice! +vertico--company-capf--candidates-a (fn &rest args)
    "Highlight company matches correctly and try default styles before
orderless."
    :around #'company-capf--candidates
    (let ((orderless-match-faces [completions-common-part])
          (completion-styles +vertico-company-completion-styles))
      (apply fn args))))


(use-package! consult
  :defer t
  :preface
  (define-key!
    [remap bookmark-jump]                 #'consult-bookmark
    [remap evil-show-marks]               #'consult-mark
    [remap evil-show-jumps]               #'+vertico/jump-list
    [remap evil-show-registers]           #'consult-register
    [remap goto-line]                     #'consult-goto-line
    [remap imenu]                         #'consult-imenu
    [remap Info-search]                   #'consult-info
    [remap locate]                        #'consult-locate
    [remap load-theme]                    #'consult-theme
    [remap recentf-open-files]            #'consult-recent-file
    [remap switch-to-buffer]              #'consult-buffer
    [remap switch-to-buffer-other-window] #'consult-buffer-other-window
    [remap switch-to-buffer-other-frame]  #'consult-buffer-other-frame
    [remap yank-pop]                      #'consult-yank-pop
    [remap persp-switch-to-buffer]        #'+vertico/switch-workspace-buffer)
  :config
  (setq consult-project-function #'doom-project-root
        consult-narrow-key "<"
        consult-line-numbers-widen t
        consult-async-min-input 2
        consult-async-refresh-delay  0.15
        consult-async-input-throttle 0.2
        consult-async-input-debounce 0.1
        consult-fd-args
        '((if (executable-find "fdfind" 'remote) "fdfind" "fd")
          "--color=never"
          ;; https://github.com/sharkdp/fd/issues/839
          "--full-path --absolute-path"
          "--hidden --exclude .git"
          (if (featurep :system 'windows) "--path-separator=/")))

  (consult-customize
   consult-ripgrep consult-git-grep consult-grep
   consult-bookmark consult-recent-file
   consult-source-recent-file consult-source-project-recent-file consult-source-bookmark
   :preview-key "C-SPC")
  (when (modulep! :config default)
    (consult-customize
     +default/search-project +default/search-other-project
     +default/search-project-for-symbol-at-point
     +default/search-cwd +default/search-other-cwd
     +default/search-notes-for-symbol-at-point
     +default/search-emacsd
     :preview-key "C-SPC"))
  (consult-customize
   consult-theme
   :preview-key '("C-SPC" :debounce 0.5 any))

  (when (modulep! :lang org)
    (defvar +vertico--consult-org-source
      (list :name     "Org Buffer"
            :category 'buffer
            :narrow   ?o
            :hidden   t
            :face     'consult-buffer
            :history  'buffer-name-history
            :state    #'consult--buffer-state
            :new
            (lambda (name)
              (with-current-buffer (get-buffer-create name)
                (insert "#+title: " name "\n\n")
                (org-mode)
                (consult--buffer-action (current-buffer))))
            :items
            (lambda ()
              (mapcar #'buffer-name
                      (if (featurep 'org)
                          (org-buffer-list)
                        (seq-filter
                         (lambda (x)
                           (eq (buffer-local-value 'major-mode x) 'org-mode))
                         (buffer-list)))))))
    (add-to-list 'consult-buffer-sources '+vertico--consult-org-source 'append))

  (defadvice! +vertico--consult-recentf-a (&rest _args)
    "`consult-recent-file' needs to have `recentf-mode' on to work correctly.
`consult-buffer' needs `recentf-mode' to show file candidates."
    :before #'consult-recent-file
    :before #'consult-buffer
    (recentf-mode +1))

  ;; HACK: Merge Evil's registers into `consult-register' register list.
  (when (modulep! :editor evil +everywhere)
    (advice-add #'consult-register--alist :around #'+evil--propagate-registers-a)))


(use-package! consult-dir
  :defer t
  :init
  (map! [remap list-directory] #'consult-dir
        (:after vertico
         :map vertico-map
         "C-x C-d" #'consult-dir
         "C-x C-j" #'consult-dir-jump-file))
  :config
  ;; DEPRECATED: Remove when projectile is replaced with project.el
  (setq consult-dir-project-list-function #'consult-dir-projectile-dirs)

  (when (modulep! :tools docker)
    ;; TODO: Replace with `tramp-container--completion-function' when we drop
    ;;   support for <29
    (defun +vertico--consult-dir-container-hosts (host)
      "Get a list of hosts from HOST."
      (cl-loop for line in (cdr
                            (ignore-errors
                              (apply #'process-lines +vertico-consult-dir-container-executable
                                     (append +vertico-consult-dir-container-args (list "ps")))))
               for cand = (split-string line "[[:space:]]+" t)
               collect (format "/%s:%s:/" host (car (last cand)))))

    (defun +vertico--consult-dir-podman-hosts ()
      (let ((+vertico-consult-dir-container-executable "podman"))
        (+vertico--consult-dir-container-hosts "podman")))

    (defun +vertico--consult-dir-docker-hosts ()
      (let ((+vertico-consult-dir-container-executable "docker"))
        (+vertico--consult-dir-container-hosts "docker")))

    (defvar +vertico--consult-dir-source-tramp-podman
      `(:name     "Podman"
        :narrow   ?p
        :category file
        :face     consult-file
        :history  file-name-history
        :items    ,#'+vertico--consult-dir-podman-hosts)
      "Podman candidate source for `consult-dir'.")

    (defvar +vertico--consult-dir-source-tramp-docker
      `(:name     "Docker"
        :narrow   ?d
        :category file
        :face     consult-file
        :history  file-name-history
        :items    ,#'+vertico--consult-dir-docker-hosts)
      "Docker candidate source for `consult-dir'.")

    (add-to-list 'consult-dir-sources '+vertico--consult-dir-source-tramp-podman t)
    (add-to-list 'consult-dir-sources '+vertico--consult-dir-source-tramp-docker t))

  (add-to-list 'consult-dir-sources 'consult-dir--source-tramp-ssh t)
  (add-to-list 'consult-dir-sources 'consult-dir--source-tramp-local t))


(use-package! consult-flycheck
  :when (modulep! :checkers syntax -flymake)
  :after (consult flycheck))


(use-package! consult-yasnippet
  :when (modulep! :editor snippets)
  :defer t
  :init (map! [remap yas-insert-snippet] #'consult-yasnippet))


(use-package! embark
  :defer t
  :init
  (setq which-key-use-C-h-commands nil
        prefix-help-command #'embark-prefix-help-command)
  (map! [remap describe-bindings] #'embark-bindings
        "C-;"               #'embark-act  ; to be moved to :config default if accepted
        (:map minibuffer-local-map
         "C-;"               #'embark-act
         "C-c C-;"           #'embark-export
         "C-c C-l"           #'embark-collect
         :desc "Export to writable buffer" "C-c C-e" #'+vertico/embark-export-write)
        (:leader
         :desc "Actions" "a" #'embark-act)) ; to be moved to :config default if accepted
  :config
  (require 'consult)

  (set-popup-rule! "^\\*Embark Export:" :size 0.35 :ttl 0 :quit nil)

  (after! which-key
    (defadvice! +vertico--embark-which-key-prompt-a (fn &rest args)
      "Hide the which-key indicator immediately when using the completing-read prompter."
      :around #'embark-completing-read-prompter
      (which-key--hide-popup-ignore-command)
      (let ((embark-indicators
             (remq #'embark-which-key-indicator embark-indicators)))
        (apply fn args)))
    (cl-nsubstitute #'+vertico-embark-which-key-indicator #'embark-mixed-indicator embark-indicators))

  ;; add the package! target finder before the file target finder,
  ;; so we don't get a false positive match.
  (cl-callf2 cons
      '+vertico-embark-target-package-fn
      (nthcdr (or (cl-position 'embark-target-file-at-point embark-target-finders)
                  (length embark-target-finders))
              embark-target-finders))
  (defvar-keymap +vertico-embark-doom-package-map
    :doc "Keymap for Embark package actions for packages installed by Doom."
    :parent embark-general-map
    "h" #'doom/help-packages
    "b" #'doom/bump-package
    "c" #'doom/help-package-config
    "u" #'doom/help-package-homepage)
  (setf (alist-get 'package embark-keymap-alist) #'+vertico-embark-doom-package-map)
  (map! (:map embark-file-map
         :desc "Open target with sudo"         "s"   #'doom/sudo-find-file
         (:when (modulep! :tools magit)
           :desc "Open magit-status of target" "g"   #'+vertico/embark-magit-status)
         (:when (modulep! :ui workspaces)
           :desc "Open in new workspace"       "TAB" #'+vertico/embark-open-in-new-workspace
           :desc "Open in new workspace"       [tab] #'+vertico/embark-open-in-new-workspace))))


(use-package! marginalia
  :hook (doom-first-input . marginalia-mode)
  :init
  (map! :map minibuffer-local-map
        :desc "Cycle marginalia views" "M-A" #'marginalia-cycle)
  :config
  (dolist (cat '((flycheck-error-list-set-filter . builtin)
                 (persp-switch-to-buffer . buffer)
                 (projectile-switch-to-buffer . buffer)))
    (add-to-list 'marginalia-command-categories cat))

  (when (modulep! +icons)
    (add-hook 'marginalia-mode-hook #'nerd-icons-completion-marginalia-setup))

  ;; HACK: Use `doom-project-root' (insert of `project-root') without
  ;;   circumventing marginalia's project root cache.
  (defadvice! +vertico--marginalia-project-root-a (&rest _)
    :override #'marginalia--project-root
    (marginalia--in-minibuffer
      (when (eq marginalia--project-root 'unset)
        (setq marginalia--project-root
              (or (let ((prompt (minibuffer-prompt))
                        case-fold-search)
                    (and (string-match
                          "\\`\\(?:Dired\\|Find file\\) in \\(.*\\): \\'"
                          prompt)
                         (match-string 1 prompt)))
                  (doom-project-root))))
      marginalia--project-root)))


(use-package! wgrep
  :commands wgrep-change-to-wgrep-mode
  :config (setq wgrep-auto-save-buffer t))


(use-package! vertico-posframe
  :when (modulep! +childframe)
  :hook (vertico-mode . vertico-posframe-mode))


;; From https://github.com/minad/vertico/wiki#candidate-display-transformations-custom-candidate-highlighting
;;
;; Uses `add-face-text-property' instead of `propertize' unlike the above
;; snippet because `append' is necessary to not override the match font lock.
;; See: minad/vertico#389
(use-package! vertico-multiform
  :hook (vertico-mode . vertico-multiform-mode)
  :config
  (defvar +vertico-transform-functions nil)

  (cl-defmethod vertico--format-candidate :around
    (cand prefix suffix index start &context ((not +vertico-transform-functions) null))
    (dolist (fun (ensure-list +vertico-transform-functions))
      (setq cand (funcall fun cand)))
    (cl-call-next-method cand prefix suffix index start))

  (defun +vertico-highlight-directory-fn (file)
    "If FILE ends with a slash, highlight it as a directory."
    (when (string-suffix-p "/" file)
      (add-face-text-property 0 (length file) 'marginalia-file-priv-dir 'append file))
    file)

  (defun +vertico-highlight-enabled-mode-fn (cmd)
    "If MODE is enabled, highlight it as font-lock-constant-face."
    (let ((sym (intern cmd)))
      (with-current-buffer (nth 1 (buffer-list))
        (if (or (eq sym major-mode)
                (and
                 (memq sym minor-mode-list)
                 (boundp sym)
                 (symbol-value sym)))
            (add-face-text-property 0 (length cmd) 'font-lock-constant-face 'append cmd)))
      cmd))

  (add-to-list 'vertico-multiform-categories
               '(file
                 (+vertico-transform-functions . +vertico-highlight-directory-fn)))
  (add-to-list 'vertico-multiform-commands
               '(execute-extended-command
                 (+vertico-transform-functions . +vertico-highlight-enabled-mode-fn))))
```

### completion/vertico/packages.el

```el
;; -*- no-byte-compile: t; -*-
;;; completion/vertico/packages.el

(package! vertico :pin "9e09fdddd6d3d995173cae0904347f46c2cdc55d")

(package! orderless :pin "a5e960f5a9a080d982aba86378da1d12641cae5c")

(package! consult :pin "8ffa37d7cb577fab68ab580889412b9363235a05")
(package! consult-dir :pin "1497b46d6f48da2d884296a1297e5ace1e050eb5")
(when (modulep! :checkers syntax -flymake)
  (package! consult-flycheck :pin "16fa53d2cc31a2689dfb5d012575c81399f6669d"))
(package! embark :pin "ec5dd1475595277ef908567d0a18d32f1c40bc91")
(package! embark-consult :pin "ec5dd1475595277ef908567d0a18d32f1c40bc91")

(package! marginalia :pin "8d87d2aedcefe0b157204f5c936dce3d0eacdf27")

(package! wgrep :pin "49f09ab9b706d2312cab1199e1eeb1bcd3f27f6f")

(when (modulep! +icons)
  (package! nerd-icons-completion :pin "45b585d972192a3eaeb239e15e55de7f46f8920a"))

(when (modulep! +childframe)
  (package! vertico-posframe
    :recipe (:host github :repo "tumashu/vertico-posframe")
    :pin "d6e06a4f1b34d24cc0ca6ec69d2d6c965191b23e"))

(when (modulep! :editor snippets)
  (package! consult-yasnippet :pin "a3482dfbdcbe487ba5ff934a1bb6047066ff2194"))
```

### completion/vertico/autoload/evil.el

```el
;; completion/vertico/autoload/evil.el -*- lexical-binding: t; -*-
;;;###if (modulep! :editor evil)

;;;###autoload (autoload '+vertico:project-search "completion/vertico/autoload/evil" nil t)
(evil-define-command +vertico:project-search (query &optional all-files-p)
  "Ex interface for `+vertico/project-search'."
  (interactive "<a><!>")
  (+vertico/project-search all-files-p query))

;;;###autoload (autoload '+vertico:project-search-from-cwd "completion/vertico/autoload/evil" nil t)
(evil-define-command +vertico:project-search-from-cwd (query &optional recurse-p)
  "Ex interface for `+vertico/project-search-from-cwd'."
  (interactive "<a><!>")
  (+vertico/project-search-from-cwd (not recurse-p) query))

;;; evil.el ends here
```

### completion/vertico/autoload/magit.el

```el
;;; completion/vertico/autoload/magit.el -*- lexical-binding: t; -*-
;;;###if (modulep! :tools magit)

;;;###autoload
(defun +vertico/embark-magit-status (file)
  "Run `magit-status` on repo containing the embark target."
  (interactive "GFile: ")
  (magit-status (locate-dominating-file file ".git")))

;;; magit.el ends here
```

### completion/vertico/autoload/vertico.el

```el
;;; completion/vertico/autoload/vertico.el -*- lexical-binding: t; -*-

(defvar consult-ripgrep-args)
(defvar embark-quit-after-action)
(defvar embark-after-export-hook)

;;;###autoload
(cl-defun +vertico-file-search (&key query in all-files (recursive t) prompt args)
  "Conduct a file search using ripgrep.

:query STRING
  Determines the initial input to search for.
:in PATH
  Sets what directory to base the search out of. Defaults to the current
  project's root.
:recursive BOOL
  Whether or not to search files recursively from the base directory.
:args LIST
  Arguments to be appended to `consult-ripgrep-args'."
  (declare (indent defun))
  (unless (executable-find "rg" t)
    (user-error "Couldn't find ripgrep in your PATH"))
  (require 'consult)
  (setq deactivate-mark t)
  (let* ((project-root (or (doom-project-root) default-directory))
         (directory (or in project-root))
         (consult-ripgrep-args
          (concat "rg "
                  (if all-files "-uu ")
                  (unless recursive "--maxdepth 1 ")
                  "--null --line-buffered --color=never --max-columns=1000 "
                  "--path-separator /   --smart-case --no-heading "
                  "--with-filename --line-number --search-zip "
                  "--hidden -g !.git -g !.svn -g !.hg "
                  (mapconcat #'identity args " ")))
         (prompt (if (stringp prompt) (string-trim prompt) "Search"))
         (query (or query
                    (when (doom-region-active-p)
                      (regexp-quote (doom-region)))))
         (consult-async-split-style consult-async-split-style)
         (consult-async-split-styles-alist
          (copy-sequence consult-async-split-styles-alist)))
    ;; Change the split style if the initial query contains the separator.
    (when query
      (cl-destructuring-bind (&key separator initial function)
          (alist-get consult-async-split-style consult-async-split-styles-alist)
        ;; Perl async split style starts with an #. If the query contains #,
        ;; then use oneof the alternative delimiters instead.
        (if (eq consult-async-split-style 'perl)
            (when (string-match-p (char-to-string initial) query)
              (setf (alist-get 'perlalt consult-async-split-styles-alist)
                    `(:initial ,(or (cl-loop for char in (list "%" "@" "!" "&" "/" ";")
                                             unless (string-match-p char query)
                                             return char)
                                    "%")
                      :separator ,separator
                      :function ,function)
                    consult-async-split-style 'perlalt))
          ;; If the separator character is present *in* the query, escape them.
          (when separator
            (setq query
                  (replace-regexp-in-string (regexp-quote (char-to-string separator))
                                            (concat "\\" (char-to-string separator))
                                            query t t))))))
    (consult--grep prompt #'consult--ripgrep-make-builder directory query)))

;;;###autoload
(defun +vertico/project-search (&optional arg initial-query directory)
  "Performs a live project search from the project root using ripgrep.
If ARG (universal argument), include all files, even hidden or compressed ones,
in the search."
  (interactive "P")
  (+vertico-file-search :query initial-query :in directory :all-files arg))

;;;###autoload
(defun +vertico/project-search-from-cwd (&optional arg initial-query)
  "Performs a live project search from the current directory.
If ARG (universal argument), include all files, even hidden or compressed ones."
  (interactive "P")
  (+vertico/project-search arg initial-query default-directory))

;;;###autoload
(defun +vertico/search-symbol-at-point ()
  "Performs a search in the current buffer for thing at point."
  (interactive)
  (consult-line (thing-at-point 'symbol)))

;;;###autoload
(defun +vertico-embark-target-package-fn ()
  "Targets Doom's package! statements and returns the package name"
  (when (or (derived-mode-p 'emacs-lisp-mode) (derived-mode-p 'org-mode))
    (save-excursion
      (when (and (search-backward "(" nil t)
                 (looking-at "(\\s-*package!\\s-*\\(\\(\\sw\\|\\s_\\)+\\)\\s-*"))
        (let ((pkg (match-string 1)))
          (set-text-properties 0 (length pkg) nil pkg)
          `(package . ,pkg))))))

;;;###autoload
(defun +vertico/embark-export-write ()
  "Export the current vertico results to a writable buffer if possible.

Supports exporting consult-grep to wgrep, file to wdired, and consult-location
to occur-edit"
  (interactive)
  (require 'embark)
  (require 'wgrep)
  (let* ((edit-command
          (pcase-let ((`(,type . _)
                       (run-hook-with-args-until-success 'embark-candidate-collectors)))
            (pcase type
              ('consult-grep #'wgrep-change-to-wgrep-mode)
              ('file #'wdired-change-to-wdired-mode)
              ('consult-location #'occur-edit-mode)
              (x (user-error "embark category %S doesn't support writable export" x)))))
         (embark-after-export-hook `(,@embark-after-export-hook ,edit-command)))
    (embark-export)))

;;;###autoload
(defun +vertico/embark-preview ()
  "Previews candidate in vertico buffer, unless it's a consult command"
  (interactive)
  (unless (bound-and-true-p consult--preview-function)
    (unless (require 'embark nil t)
      (user-error "Embark not installed, aborting..."))
    (save-selected-window
      (let (embark-quit-after-action)
        (embark-dwim)))))

;;;###autoload
(defun +vertico/enter-or-preview ()
  "Enter directory or embark preview on current candidate."
  (interactive)
  (when (> 0 vertico--index)
    (user-error "No vertico session is currently active"))
  (if (and (let ((cand (vertico--candidate)))
             (or (string-suffix-p "/" cand)
                 (and (vertico--remote-p cand)
                      (string-suffix-p ":" cand))))
           (not (equal vertico--base ""))
           (eq 'file (vertico--metadata-get 'category)))
      (vertico-insert)
    (condition-case _
        (+vertico/embark-preview)
      (user-error (vertico-directory-enter)))))

;;;###autoload
(defun +vertico/jump-list (jump)
  "Go to an entry in evil's (or better-jumper's) jumplist."
  (interactive
   (let (buffers)
     (require 'consult)
     (unwind-protect
         (list
          (consult--read
           ;; REVIEW: Refactor me
           (nreverse
            (delete-dups
             (delq
              nil (mapcar
                   (lambda (mark)
                     (when mark
                       (cl-destructuring-bind (path pt _id) mark
                         (let* ((visiting (find-buffer-visiting path))
                                (buf (or visiting (find-file-noselect path t)))
                                (dir default-directory))
                           (unless visiting
                             (push buf buffers))
                           (with-current-buffer buf
                             (goto-char pt)
                             (font-lock-fontify-region
                              (line-beginning-position) (line-end-position))
                             (format "%s:%d: %s"
                                     (car (cl-sort (list (abbreviate-file-name (buffer-file-name buf))
                                                         (file-relative-name (buffer-file-name buf) dir))
                                                   #'< :key #'length))
                                     (line-number-at-pos)
                                     (string-trim-right (or (thing-at-point 'line) ""))))))))
                   (cddr (better-jumper-jump-list-struct-ring
                          (better-jumper-get-jumps (better-jumper--get-current-context))))))))
           :prompt "jumplist: "
           :sort nil
           :require-match t
           :category 'jump-list))
       (mapc #'kill-buffer buffers))))
  (if (not (string-match "^\\([^:]+\\):\\([0-9]+\\): " jump))
      (user-error "No match")
    (let ((file (match-string-no-properties 1 jump))
          (line (match-string-no-properties 2 jump)))
      (find-file file)
      (goto-char (point-min))
      (forward-line (string-to-number line)))))

;;;###autoload
(defun +vertico-embark-which-key-indicator ()
  "An embark indicator that displays keymaps using which-key.
The which-key help message will show the type and value of the
current target followed by an ellipsis if there are further
targets."
  (lambda (&optional keymap targets prefix)
    (if (null keymap)
        (which-key--hide-popup-ignore-command)
      (which-key--show-keymap
       (if (eq (plist-get (car targets) :type) 'embark-become)
           "Become"
         (if (> (or (plist-get (car targets) :multi) 0) 1)
             (format "Act on %s '%ss'"
                 (plist-get (car targets) :multi)
                 (plist-get (car targets) :type))
             (format "Act on %s '%s'%s"
                 (plist-get (car targets) :type)
                 (embark--truncate-target (plist-get (car targets) :target))
                 (if (cdr targets) "…" ""))))
       (if prefix
           (pcase (lookup-key keymap prefix 'accept-default)
             ((and (pred keymapp) km) km)
             (_ (key-binding prefix 'accept-default)))
         keymap)
       nil nil t (lambda (binding)
                   (not (string-suffix-p "-argument" (cdr binding))))))))

;;;###autoload
(defun +vertico/consult-fd-or-find (&optional dir initial)
  "Runs consult-fd if fd version > 8.6.0 exists, consult-find otherwise.
See minad/consult#770."
  (interactive "P")
  ;; REVIEW: This condition was adapted from a similar one in
  ;;   lisp/doom-projects.el, to be replaced with a more robust check post v3
  (if (when-let*
          ((bin (if (ignore-errors (file-remote-p default-directory nil t))
                    (cl-find-if (doom-rpartial #'executable-find t)
                                (list "fdfind" "fd"))
                  doom-fd-executable))
           (version (with-memoization (get 'doom-fd-executable 'version)
                      (cadr (split-string (cdr (doom-call-process bin "--version"))
                                          " " t))))
           ((ignore-errors (version-to-list version))))
        ;; REVIEW: Remove once fd 8.6.0 is widespread enough.
        (version< "8.6.0" version))
      (consult-fd dir initial)
    (consult-find dir initial)))

;;;###autoload
(defun +vertico-basic-remote-try-completion (string table pred point)
  (and (vertico--remote-p string)
       (completion-basic-try-completion string table pred point)))

;;;###autoload
(defun +vertico-basic-remote-all-completions (string table pred point)
  (and (vertico--remote-p string)
       (completion-basic-all-completions string table pred point)))

;;;###autoload
(defun +vertico-orderless-dispatch (pattern _index _total)
  "Like `orderless-affix-dispatch', but allows affixes to be escaped."
  (let ((len (length pattern))
        (alist orderless-affix-dispatch-alist))
    (when (> len 0)
      (cond
       ;; Ignore single dispatcher character
       ((and (= len 1) (alist-get (aref pattern 0) alist)) #'ignore)
       ;; Prefix
       ((when-let* ((style (alist-get (aref pattern 0) alist))
                    ((not (char-equal (aref pattern (max (1- len) 1)) ?\\))))
          (cons style (substring pattern 1))))
       ;; Suffix
       ((when-let* ((style (alist-get (aref pattern (1- len)) alist))
                    ((not (char-equal (aref pattern (max 0 (- len 2))) ?\\))))
          (cons style (substring pattern 0 -1))))))))

;;;###autoload
(defun +vertico-orderless-disambiguation-dispatch (pattern _index _total)
  "Ensure $ works with Consult commands, which add disambiguation suffixes."
  (let ((len (length pattern)))
    (when (and (> len 0)
               (char-equal (aref pattern (1- len)) ?$))
      `(orderless-regexp . ,(concat (substring pattern 0 -1) "[\x200000-\x300000]*$")))))

;;; vertico.el ends here

```

### completion/vertico/autoload/workspaces.el

```el
;;; completion/vertico/autoload/workspaces.el -*- lexical-binding: t; -*-
;;;###if (modulep! :ui workspaces)

(defun +vertico--workspace-buffer-state ()
  (let ((preview
         ;; Only preview in current window and other window. Preview in frames
         ;; and tabs is not possible since these don't get cleaned up.
         (if (memq consult--buffer-display
                   '(switch-to-buffer switch-to-buffer-other-window))
             (let ((orig-buf (current-buffer))
                   other-win
                   cleanup-buffers)
               (lambda (action cand)
                 (when (eq action 'preview)
                   (when (and (eq consult--buffer-display #'switch-to-buffer-other-window)
                              (not other-win))
                     (switch-to-buffer-other-window orig-buf)
                     (setq other-win (selected-window)))
                   (let ((win (or other-win (selected-window))))
                     (when (window-live-p win)
                       (with-selected-window win
                         (cond
                          ((and cand (get-buffer cand))
                           (unless (+workspace-contains-buffer-p cand)
                             (cl-pushnew cand cleanup-buffers))
                           (switch-to-buffer cand 'norecord))
                          ((buffer-live-p orig-buf)
                           (switch-to-buffer orig-buf 'norecord)
                           (mapc #'persp-remove-buffer cleanup-buffers)))))))))
           #'ignore)))
    (lambda (action cand)
      (funcall preview action cand))))

(defun +vertico--workspace-generate-sources ()
  "Generate list of consult buffer sources for all workspaces"
  (let* ((active-workspace (+workspace-current-name))
         (key-range (append (cl-loop for i from ?1 to ?9 collect i)
                            (cl-loop for i from ?a to ?z collect i)
                            (cl-loop for i from ?A to ?Z collect i)))
         (i 0))
    (mapcar (lambda (name)
              (cl-incf i)
              `(:name     ,name
                :hidden   ,(not (string= active-workspace name))
                :narrow   ,(nth (1- i) key-range)
                :category buffer
                :state    +vertico--workspace-buffer-state
                :items    ,(lambda ()
                             (consult--buffer-query
                              :sort 'visibility
                              :as #'buffer-name
                              :predicate
                              (lambda (buf)
                                (when-let* ((workspace (+workspace-get name t)))
                                  (+workspace-contains-buffer-p buf workspace)))))))
            (+workspace-list-names))))


;;
;;; Commands

(autoload 'consult--multi "consult")
;;;###autoload
(defun +vertico/switch-workspace-buffer (&optional force-same-workspace)
  "Switch to another buffer in the same or a specified workspace.

Type the workspace's number (starting from 1) followed by a space to display its
buffer list. Selecting a buffer in another workspace will switch to that
workspace instead. If FORCE-SAME-WORKSPACE (the prefix arg) is non-nil, that
buffer will be opened in the current workspace instead."
  (interactive "P")
  (when-let* ((buffer (consult--multi (+vertico--workspace-generate-sources)
                                      :require-match
                                      (confirm-nonexistent-file-or-buffer)
                                      :prompt (format "Switch to buffer (%s): "
                                                      (+workspace-current-name))
                                      :history 'consult--buffer-history
                                      :sort nil)))
    (let ((origin-workspace (plist-get (cdr buffer) :name)))
      ;; Switch to the workspace the buffer belongs to, maybe
      (if (or (equal origin-workspace (+workspace-current-name))
              force-same-workspace)
          (funcall consult--buffer-display (car buffer))
        (+workspace-switch origin-workspace)
        (message "Switched to %S workspace" origin-workspace)
        (if-let* ((window (get-buffer-window (car buffer))))
            (select-window window)
          (funcall consult--buffer-display (car buffer)))))))

;;;###autoload
(defun +vertico/embark-open-in-new-workspace (file)
  "Open file in a new workspace."
  (interactive "GFile:")
  (+workspace/new)
  (find-file file))

;;; workspaces.el ends here


```

## ui/doom

### ui/doom/README.org

```org
#+title:    :ui doom
#+subtitle: Make Doom fabulous again
#+created:  February 20, 2017
#+since:    2.0.0

* Description :unfold:
This module gives Doom its signature look: powered by the [[doom-package:doom-themes][doom-one]] theme
(loosely inspired by [[https://github.com/atom/one-dark-syntax][Atom's One Dark theme]]) and [[doom-package:solaire-mode]]. Includes:

- A custom folded-region indicator for [[doom-package:hideshow]].
- File-visiting buffers are slightly brighter (thanks to [[doom-package:solaire-mode]]).

** Maintainers
- [[doom-user:][@hlissner]]

[[doom-contrib-maintainer:][Become a maintainer?]]

** Module flags
/This module has no flags./

** Packages
- [[doom-package:doom-themes]]
- [[doom-package:solaire-mode]]

** Hacks
/No hacks documented for this module./

** TODO Changelog
# This section will be machine generated. Don't edit it by hand.
/This module does not have a changelog yet./

* Installation
[[id:01cffea4-3329-45e2-a892-95a384ab2338][Enable this module in your ~doom!~ block.]]

/This module has no external requirements./

* TODO Usage
#+begin_quote
 󱌣 This module has no usage documentation yet. [[doom-contrib-module:][Write some?]]
#+end_quote

* TODO Configuration
#+begin_quote
 󱌣 /This module's configuration documentation is incomplete./ [[doom-contrib-module:][Complete it?]]
#+end_quote

** Changing theme
Although this module uses the ~doom-one~ theme by default, [[https://github.com/hlissner/emacs-doom-theme/][doom-themes]] offers a
number of alternatives:

- *doom-one:* doom-themes' flagship theme, inspired by [[https://atom.io/][Atom's]] One Dark themes
- *doom-vibrant:* a more vibrant version of doom-one
- *doom-molokai:* based on Textmate's monokai
- *doom-nova:* adapted from [[https://github.com/trevordmiller/nova-colors][Nova]]
- *doom-one-light:* light version of doom-one
- *doom-peacock:* based on Peacock from [[https://daylerees.github.io/][daylerees' themes]]
- *doom-tomorrow-night:* by [[https://github.com/ChrisKempson/Tomorrow-Theme][Chris Kempson]]
- And /many/ more...

This can be changed by changing the ~doom-theme~ variable, e.g.
#+begin_src emacs-lisp
;; in $DOOMDIR/config.el
(setq doom-theme 'doom-molokai)
#+end_src

** Changing fonts
core/core-ui.el has four relevant variables:

- ~doom-font~ :: the default font to use in Doom Emacs.
- ~doom-big-font~ :: the font to use when ~doom-big-font-mode~ is enabled.
- ~doom-variable-pitch-font~ :: the font to use when ~variable-pitch-mode~ is active
  (or where the ~variable-pitch~ face is used).
- ~doom-symbol-font~ :: the font used to display unicode symbols. This is
  ignored if the [[doom-module::ui unicode]] module is enabled.

#+begin_src emacs-lisp
(setq doom-font (font-spec :family "Fira Mono" :size 12)
      doom-variable-pitch-font (font-spec :family "Fira Sans")
      doom-symbol-font (font-spec :family "JuliaMono")
      doom-big-font (font-spec :family "Fira Mono" :size 19))
#+end_src

* Troubleshooting
[[doom-report:][Report an issue?]]

** Strange font symbols
If you're seeing strange unicode symbols, this is likely because you don't have
~nerd-icons~'s font icon installed. You can install them with ~M-x
nerd-icons-install-fonts~.

** Ugly background colors in tty Emacs for daemon users
[[doom-package:solaire-mode]] is an aesthetic plugin that makes non-file-visiting buffers darker
than the rest of the Emacs' frame (to visually differentiate temporary windows
or sidebars from editing windows). This looks great in GUI Emacs, but can look
questionable in the terminal.

It disables itself if you start tty Emacs with ~$ emacs -nw~, but if you create
a tty frame from a daemon (which solaire-mode cannot anticipate), you'll get an
ugly background instead.

If you only use Emacs in the terminal, your best bet is to disable the
solaire-mode package:
#+begin_src emacs-lisp
;; in $DOOMDIR/packages.el
(package! solaire-mode :disable t)
#+end_src

* Frequently asked questions
/This module has no FAQs yet./ [[doom-suggest-faq:][Ask one?]]

* TODO Appendix
#+begin_quote
 󱌣 This module has no appendix yet. [[doom-contrib-module:][Write one?]]
#+end_quote

```

### ui/doom/config.el

```el
;;; ui/doom/config.el -*- lexical-binding: t; -*-

;;;###package pos-tip
(setq pos-tip-internal-border-width 6
      pos-tip-border-width 1)


(use-package! doom-themes
  ;; improve integration w/ org-mode
  :hook (doom-load-theme . doom-themes-org-config)
  :init (setq doom-theme 'doom-one)
  ;; more Atom-esque file icons for neotree/treemacs
  ;; (when (modulep! :ui neotree)
  ;;   (add-hook 'doom-load-theme-hook #'doom-themes-neotree-config)
  ;;   (setq doom-themes-neotree-enable-variable-pitch t
  ;;         doom-themes-neotree-file-icons 'simple
  ;;         doom-themes-neotree-line-spacing 2))
  )


(use-package! solaire-mode
  :hook (doom-load-theme . solaire-global-mode)
  :hook (+popup-buffer-mode . turn-on-solaire-mode))

```

### ui/doom/packages.el

```el
;; -*- no-byte-compile: t; -*-
;;; ui/doom/packages.el

(package! doom-themes :pin "53645a905dfb3055db52f5d418d5ef612027e062")
(package! solaire-mode :pin "1bd0134194e48c8fe4089e9d505517935b2b15e3")

```

## ui/dashboard

### ui/dashboard/README.org

```el
#+title:    :ui dashboard
#+subtitle: A pretty face for your doom
#+created:  February 20, 2017
#+since:    2.0.0

* Description :unfold:
This module adds a minimalistic, Atom-inspired dashboard to Emacs.

Besides eye candy, the dashboard serves two other purposes:

1. To improve Doom's startup times (the dashboard is lighter than the scratch
   buffer in many cases).

2. And to preserve the "last open directory" you were in. Occasionally, I kill
   the last buffer in my project and I end up who-knows-where (in the working
   directory of another buffer/project). It can take some work to find my way
   back to where I was. Not with the Dashboard.

   Since the dashboard cannot be killed, and it remembers the working directory
   of the last open buffer, ~M-x find-file~ will work from the directory I
   expect.

** Maintainers
- [[doom-user:][@hlissner]]

[[doom-contrib-maintainer:][Become a maintainer?]]

** Module flags
/This module has no flags./

** Packages
/This module doesn't install any packages./

** Hacks
/No hacks documented for this module./

** TODO Changelog
# This section will be machine generated. Don't edit it by hand.
/This module does not have a changelog yet./

* Installation
[[id:01cffea4-3329-45e2-a892-95a384ab2338][Enable this module in your ~doom!~ block.]]

This module only requires that ~nerd-icons~'s icon fonts are installed, which
should've been installed when you ran ~$ doom install~. Otherwise, use ~M-x
nerd-icons-install-fonts~ to install them.

* Usage
Once this module is enabled, the dashboard will present itself after opening a
fresh instance of Emacs, or after killing all real buffers.

You can forcibly open the dashboard with ~M-x +dashboard/open~.

* TODO Configuration
#+begin_quote
 󱌣 /This module's configuration documentation is incomplete./ [[doom-contrib-module:][Complete it?]]
#+end_quote

** A custom banner
To use a custom image as your banner, change ~fancy-splash-image~:
#+begin_src emacs-lisp
(setq fancy-splash-image "~/my/banners/image.png")
#+end_src

#+begin_quote
 󰐃 Doom will fall back to its ASCII banner in Terminal Emacs. To replace the
    ASCII banner, replace the ~+dashboard-widget-banner~ function in
    ~+dashboard-functions~ with a function that inserts your new banner
    into the current file.
#+end_quote

** Adding text to the dashboard
Doom's dashboard iterates over ~+dashboard-functions~ when it is told to
redraw. Add your own functions to operate on the buffer and potentially add
whatever you like to Doom's splash screen.

#+begin_quote
  Keep in mind that inserting text from expensive sources, e.g. your org
    agenda, will negate most of Doom's startup benefits.
#+end_quote

** Customizing Faces
Doom's dashboard defaults to inheriting faces set by the current theme. If you
wish to customize it independently of the theme (or just inherit a different
color from the theme) you can make use of ~custom-set-faces!~ or
~custom-theme-set-faces!~:
#+begin_src emacs-lisp
(custom-set-faces!
  '(+dashboard-banner :foreground "red" :background "#000000" :weight bold)
  '(+dashboard-footer :inherit font-lock-constant-face)
  '(+dashboard-footer-icon :inherit nerd-icons-red)
  '(+dashboard-loaded :inherit font-lock-warning-face)
  '(+dashboard-menu-desc :inherit font-lock-string-face)
  '(+dashboard-menu-title :inherit font-lock-function-name-face))
#+end_src

or for a per-theme setting
#+begin_src emacs-lisp
(custom-theme-set-faces! 'doom-tomorrow-night
  '(+dashboard-banner :foreground "red" :background "#000000" :weight bold)
  '(+dashboard-footer :inherit font-lock-constant-face)
  '(+dashboard-footer-icon :inherit nerd-icons-red)
  '(+dashboard-loaded :inherit font-lock-warning-face)
  '(+dashboard-menu-desc :inherit font-lock-string-face)
  '(+dashboard-menu-title :inherit font-lock-function-name-face))
#+end_src

* Troubleshooting
/There are no known problems with this module./ [[doom-report:][Report one?]]

* Frequently asked questions
/This module has no FAQs yet./ [[doom-suggest-faq:][Ask one?]]

* TODO Appendix
#+begin_quote
 󱌣 This module has no appendix yet. [[doom-contrib-module:][Write one?]]
#+end_quote
```

### ui/dashboard/autoload.el

```el
;;; ui/dashboard/autoload.el -*- lexical-binding: t; -*-

(defun +dashboard--help-echo ()
  (when-let* ((btn (button-at (point)))
              (msg (button-get btn 'help-echo)))
    (message "%s" msg)))

;;;###autoload
(defun +dashboard/open (frame)
  "Switch to the dashboard in the current window, of the current FRAME."
  (interactive (list (selected-frame)))
  (with-selected-frame frame
    (switch-to-buffer (doom-fallback-buffer))
    (+dashboard-reload t)))

;;;###autoload
(defun +dashboard/forward-button (n)
  "Like `forward-button', but don't wrap."
  (interactive "p")
  (forward-button n nil)
  (+dashboard--help-echo))

;;;###autoload
(defun +dashboard/backward-button (n)
  "Like `backward-button', but don't wrap."
  (interactive "p")
  (backward-button n nil)
  (+dashboard--help-echo))

```

### ui/dashboard/config.el

```el
;;; ui/dashboard/config.el -*- lexical-binding: t; -*-

(defgroup +dashboard nil
  "Manage how Doom's dashboard is coloured and themed."
  :group 'doom+)

(defcustom +dashboard-name "*doom*"
  "The name of the dashboard buffer."
  :type 'string
  :group '+dashboard)

(defcustom +dashboard-functions
  `(+dashboard-widget-banner
    +dashboard-widget-shortmenu
    +dashboard-widget-footer
    +dashboard-widget-loaded)
  "List of widget functions to run to construct the dashboard buffer.

These functions take no arguments and the dashboard buffer is current while they
run."
  :type 'hook
  :group '+dashboard)

(defcustom +dashboard-banner-file "default.png"
  "The path to the image file to be used in on the dashboard. The path is
relative to `+dashboard-banner-dir'. If nil, always use the ASCII banner."
  :type 'string
  :group '+dashboard)

(defcustom +dashboard-banner-dir (concat (dir!) "/banners/")
  "Where to look for `+dashboard-banner-file'."
  :type 'directory
  :group '+dashboard)

(defcustom +dashboard-ascii-banner-fn #'+dashboard-draw-ascii-banner-fn
  "The function used to generate the ASCII banner on Doom's dashboard."
  :type 'function
  :group '+dashboard)

(defcustom +dashboard-banner-vertical-padding '(2 . 2)
  "Number of newlines to pad the banner with, above and below, respectively."
  :type '(cons integer integer)
  :group '+dashboard)

(defcustom +dashboard-anchor '(center . center)
  "How to vertically and horizontally align dashboard widgets."
  :type '(cons (choice (const :tag "Top" top)
                       (const :tag "Bottom" bottom)
                       (const :tag "Centered" center))
               (choice (const :tag "Left" left)
                       (const :tag "Right" right)
                       (const :tag "Centered" center)))
  :group '+dashboard)

(defcustom +dashboard-pwd-policy 'last-project
  "The policy to use when setting the `default-directory' in the dashboard.

Possible values:
  \\='last-project
    The `doom-project-root' of the last open buffer. Falls back to
    `default-directory' if not in a project.
  \\='last
    The `default-directory' of the last open buffer
  a FUNCTION
    A function run with the `default-directory' of the last open buffer, that
    returns a directory path
  a STRING
    A fixed path
  nil
    `default-directory' will never change"
  :type '(radio
          (const :tag "The project root of the last open buffer (or `default-directory')" last-project)
          (const :tag "The `default-directory' of the last open buffer." last)
          (function :tag "Return what directory to use")
          (directory :tag "A fixed directory path")
          (const :tag "Never change the dashboard's `default-directory'" nil))
  :group '+dashboard)

(defcustom +dashboard-menu-sections
  '(("Recently opened files"
     :icon (nerd-icons-faicon "nf-fa-file_text" :face '+dashboard-menu-title)
     :action recentf-open-files)
    ("Reload last session"
     :icon (nerd-icons-octicon "nf-oct-history" :face '+dashboard-menu-title)
     :when (cond ((modulep! :ui workspaces)
                  (file-exists-p (expand-file-name persp-auto-save-fname persp-save-dir)))
                 ((require 'desktop nil t)
                  (file-exists-p (desktop-full-file-name))))
     :action doom/quickload-session)
    ("Open org-agenda"
     :icon (nerd-icons-octicon "nf-oct-calendar" :face '+dashboard-menu-title)
     :when (fboundp 'org-agenda)
     :action org-agenda)
    ("Open project"
     :icon (nerd-icons-octicon "nf-oct-briefcase" :face '+dashboard-menu-title)
     :action projectile-switch-project)
    ("Jump to bookmark"
     :icon (nerd-icons-octicon "nf-oct-bookmark" :face '+dashboard-menu-title)
     :action bookmark-jump)
    ("Open private configuration"
     :icon (nerd-icons-octicon "nf-oct-tools" :face '+dashboard-menu-title)
     :when (file-directory-p doom-user-dir)
     :action doom/open-private-config)
    ("Open documentation"
     :icon (nerd-icons-octicon "nf-oct-book" :face '+dashboard-menu-title)
     :action doom/help))
  "An alist of menu buttons used by `+dashboard-widget-shortmenu'. Each
element is a cons cell (LABEL . PLIST). LABEL is a string to display after the
icon and before the key string.

PLIST can have the following properties:

  :icon FORM
    Uses the return value of FORM as an icon (can be literal string).
  :key STRING
    The keybind displayed next to the button.
  :when FORM
    If FORM returns nil, don't display this button.
  :face FACE
    Displays the icon and text with FACE (a face symbol).
  :action FORM
    Run FORM when the button is pushed."
  :type 'alist
  :group '+dashboard)

;;
(defvar +dashboard-inhibit-refresh nil
  "If non-nil, the doom buffer won't be refreshed.")

(defvar +dashboard-inhibit-functions ()
  "A list of functions which take no arguments. If any of them return non-nil,
dashboard reloading is inhibited.")

(defvar +dashboard--last-cwd nil)
(defvar +dashboard--reload-timer nil)


;;
;;; Faces

(defface +dashboard-banner '((t (:inherit font-lock-comment-face)))
  "Face used for the DOOM banner on the dashboard"
  :group '+dashboard)

(defface +dashboard-footer '((t (:inherit font-lock-keyword-face)))
  "Face used for the footer on the dashboard"
  :group '+dashboard)

(defface +dashboard-footer-icon '((t (:inherit nerd-icons-green)))
  "Face used for the icon of the footer on the dashboard"
  :group '+dashboard)

(defface +dashboard-loaded '((t (:inherit font-lock-comment-face)))
  "Face used for the loaded packages benchmark"
  :group '+dashboard)

(defface +dashboard-menu-desc '((t (:inherit font-lock-constant-face)))
  "Face used for the key description of menu widgets on the dashboard"
  :group '+dashboard)

(defface +dashboard-menu-title '((t (:inherit font-lock-keyword-face)))
  "Face used for the title of menu widgets on the dashboard"
  :group '+dashboard)


;;
;;; Major mode

(define-derived-mode +dashboard-mode special-mode
  (format "DOOM v%s" doom-version)
  "Major mode for the DOOM dashboard buffer."
  :syntax-table nil
  :abbrev-table nil
  (buffer-disable-undo)
  (setq-local revert-buffer-function #'+dashboard-revert-buffer-fn)
  (setq truncate-lines t)
  (setq-local whitespace-style nil)
  (setq-local show-trailing-whitespace nil)
  (setq-local hscroll-margin 0)
  (setq-local tab-width 2)
  ;; Don't scroll to follow cursor
  (setq-local scroll-preserve-screen-position nil)
  (setq-local auto-hscroll-mode nil)
  ;; Line numbers are ugly with large margins
  (setq-local display-line-numbers-type nil)
  ;; Ensure the ever-changing margins don't screw with the mode-line's
  ;; right-alignment (see #8114).
  (setq-local mode-line-right-align-edge 'right-margin)
  ;; Ensure point is always on a button
  (add-hook 'post-command-hook #'+dashboard-reposition-point-h nil 'local)
  ;; hl-line produces an ugly cut-off line highlight in the dashboard, so don't
  ;; activate it there (by pretending it's already active).
  (setq-local hl-line-mode t)
  ;; Local variables are never important in the dashboard, and may cause repeat
  ;; prompts about unsafe/risky variables.
  (setq-local enable-local-variables nil))

(define-key! +dashboard-mode-map
  [left-margin mouse-1]   #'ignore
  [remap forward-button]  #'+dashboard/forward-button
  [remap backward-button] #'+dashboard/backward-button
  "n"       #'forward-button
  "p"       #'backward-button
  "C-n"     #'forward-button
  "C-p"     #'backward-button
  [down]    #'forward-button
  [up]      #'backward-button
  [tab]     #'forward-button
  [backtab] #'backward-button

  ;; Evil remaps
  [remap evil-next-line]     #'forward-button
  [remap evil-previous-line] #'backward-button
  [remap evil-next-visual-line]     #'forward-button
  [remap evil-previous-visual-line] #'backward-button
  [remap evil-paste-pop-next] #'forward-button
  [remap evil-paste-pop]      #'backward-button
  [remap evil-delete]         #'ignore
  [remap evil-delete-line]    #'ignore
  [remap evil-insert]         #'ignore
  [remap evil-append]         #'ignore
  [remap evil-replace]        #'ignore
  [remap evil-enter-replace-state] #'ignore
  [remap evil-change]         #'ignore
  [remap evil-change-line]    #'ignore
  [remap evil-visual-char]    #'ignore
  [remap evil-visual-line]    #'ignore)


;;
;;; Bootstrap

(defun +dashboard-init-h ()
  "Initializes Doom's dashboard."
  (unless noninteractive
    (setq doom-fallback-buffer-name +dashboard-name
          initial-buffer-choice #'doom-fallback-buffer)
    ;; Ensure the dashboard becomes Emacs' go-to buffer when there's nothing
    ;; else to show.
    (unless fancy-splash-image
      (setq fancy-splash-image
            (expand-file-name +dashboard-banner-file
                              +dashboard-banner-dir)))
    (+dashboard-reload)
    (add-hook 'doom-load-theme-hook #'+dashboard-reload-on-theme-change-h)
    ;; Ensure the dashboard is up-to-date whenever it is switched to or resized.
    (add-hook 'window-size-change-functions #'+dashboard-resize-h)
    (add-hook 'doom-switch-buffer-hook #'+dashboard-reload-maybe-h)
    (add-hook 'delete-frame-functions #'+dashboard-reload-frame-h)
    ;; `persp-mode' integration: update `default-directory' when switching perspectives
    (add-hook 'persp-created-functions #'+dashboard--persp-record-project-h)
    (add-hook 'persp-activated-functions #'+dashboard--persp-detect-project-h)
    ;; Fix #2219 where, in GUI daemon frames, the dashboard loses center
    ;; alignment after switching (or killing) workspaces.
    (when (daemonp)
      (add-hook 'persp-activated-functions #'+dashboard-reload-maybe-h))
    (add-hook 'persp-before-switch-functions #'+dashboard--persp-record-project-h)))

(add-hook 'doom-init-ui-hook #'+dashboard-init-h 'append)

;; PERF: Make sure the dashboard is ready early, so as to avoid triggering
;;   `doom-first-buffer-hook' later, when switching to it.
(when (and (doom-context-p 'startup)
           (equal (buffer-name) "*scratch*"))
  (let (buffer-list-update-hook
        doom-first-buffer-hook)
    (switch-to-buffer +dashboard-name)))


;;
;;; Hooks

(defun +dashboard-revert-buffer-fn (&optional _ignore-auto _no-confirm)
  "`revert-buffer-function' for `+dashboard-mode'."
  (+dashboard-reload t))

(defun +dashboard-reposition-point-h ()
  "Trap the point in the buttons."
  (when (region-active-p)
    (setq deactivate-mark t)
    (when (bound-and-true-p evil-local-mode)
      (evil-change-to-previous-state)))
  (or (ignore-errors
        (if (button-at (point))
            (forward-button 0)
          (backward-button 1)))
      (ignore-errors
        (goto-char (point-min))
        (forward-button 1)))
  ;; Hide the cursor if there are no buttons
  (unless (button-at (point))
    (setq-local cursor-type nil
                ;; We need (list nil) as a workaround for emacs-evil/evil#2016.
                evil-normal-state-cursor (list nil))))

(defun +dashboard-reload-maybe-h (&rest _)
  "Reload the dashboard or its state.

If this isn't a dashboard buffer, move along, but record its `default-directory'
if the buffer is real. See `doom-real-buffer-p' for an explanation for what
\\='real' means.

If this is the dashboard buffer, reload it completely."
  (cond ((+dashboard-buffer-p (current-buffer))
         (let (+dashboard-inhibit-refresh)
           (ignore-errors (+dashboard-reload))))
        ((and (not (file-remote-p default-directory))
              (doom-real-buffer-p (current-buffer)))
         (setq +dashboard--last-cwd default-directory)
         (+dashboard-update-pwd-h))))

(defun +dashboard-reload-frame-h (_frame)
  "Reload the dashboard after a brief pause. This is necessary for new frames,
whose dimensions may not be fully initialized by the time this is run."
  (when (timerp +dashboard--reload-timer)
    (cancel-timer +dashboard--reload-timer)) ; in case this function is run rapidly
  (setq +dashboard--reload-timer
        (run-with-timer 0.1 nil #'+dashboard-reload t)))

(defun +dashboard-resize-h (&rest _)
  "Recenter the dashboard, and reset its margins and fringes."
  (let (buffer-list-update-hook
        window-configuration-change-hook
        window-size-change-functions)
    (when-let* ((windows (get-buffer-window-list (doom-fallback-buffer) nil t)))
      (dolist (w windows)
        (unless (= (window-start w) 1)
          (set-window-start w 0))
        (cl-destructuring-bind (left right &rest) (window-fringes w)
          (unless (and (= left 0)
                       (= right 0))
            (set-window-fringes w 0 0))))
      (with-current-buffer (doom-fallback-buffer)
        (save-excursion
          (with-silent-modifications
            (goto-char (point-min))
            (delete-region (line-beginning-position)
                           (save-excursion (skip-chars-forward "\n")
                                           (point)))
            (insert
             (make-string
              (max
               0 (pcase (car-safe +dashboard-anchor)
                   (`top 0)
                   (`center
                    (- (/ (window-height (get-buffer-window)) 2)
                       (round (/ (count-lines (point-min) (point-max))
                                 2))))
                   (`bottom
                    (- (window-height (get-buffer-window))
                       (count-lines (point-min) (point-max))
                       1))
                   (_ 0)))
              ?\n))))))))

(defun +dashboard--persp-detect-project-h (&rest _)
  "Set dashboard's PWD to current persp's `last-project-root', if it exists.

This and `+dashboard--persp-record-project-h' provides `persp-mode'
integration with the Doom dashboard. It ensures that the dashboard is always in
the correct project (which may be different across perspective)."
  (when (bound-and-true-p persp-mode)
    (when-let* ((pwd (persp-parameter 'last-project-root)))
      (+dashboard-update-pwd-h pwd))))

(defun +dashboard--persp-record-project-h (&optional persp &rest _)
  "Record the last `doom-project-root' for the current persp.
See `+dashboard--persp-detect-project-h' for more information."
  (when (bound-and-true-p persp-mode)
    (set-persp-parameter
     'last-project-root (doom-project-root)
     (if (persp-p persp)
         persp
       (get-current-persp)))))


;;
;;; Library

(defun +dashboard-buffer-p (buffer)
  "Returns t if BUFFER is the dashboard buffer."
  (eq buffer (get-buffer +dashboard-name)))

(defun +dashboard-update-pwd-h (&optional pwd)
  "Update `default-directory' in the Doom dashboard buffer.
What it is set to is controlled by `+dashboard-pwd-policy'."
  (if pwd
      (with-current-buffer (doom-fallback-buffer)
        (doom-log "Changed dashboard's PWD to %s" pwd)
        (setq-local default-directory pwd))
    (let ((new-pwd (+dashboard--pwd)))
      (when (and new-pwd (file-accessible-directory-p new-pwd))
        (+dashboard-update-pwd-h
         (concat (directory-file-name new-pwd)
                 "/"))))))

(defun +dashboard-reload-on-theme-change-h ()
  "Forcibly reload the Doom dashboard when theme changes post-startup."
  (when after-init-time
    (+dashboard-reload 'force)))

(defun +dashboard-reload (&optional force)
  "Update the DOOM scratch buffer (or create it, if it doesn't exist)."
  (when (or (and (not +dashboard-inhibit-refresh)
                 (get-buffer-window (doom-fallback-buffer))
                 (not (window-minibuffer-p (frame-selected-window)))
                 (not (run-hook-with-args-until-success '+dashboard-inhibit-functions)))
            force)
    (with-current-buffer (doom-fallback-buffer)
      (doom-log "Reloading dashboard at %s" (format-time-string "%T"))
      (with-silent-modifications
        (let ((pt (point)))
          (unless (eq major-mode '+dashboard-mode)
            (+dashboard-mode))
          (erase-buffer)
          (run-hooks '+dashboard-functions)
          (goto-char pt)
          (+dashboard-reposition-point-h))
        (+dashboard-resize-h)
        (+dashboard--persp-detect-project-h)
        (+dashboard-update-pwd-h)
        (current-buffer)))))

;; helpers
(defun +dashboard-strlen (s)
  "Return the unicode-aware string width of S."
  (let ((width (frame-char-width))
        (len (string-pixel-width s)))
    (+ (/ len width)
       (if (zerop (% len width)) 0 1))))

(defun +dashboard-maxlen (str)
  "Return the length of the longest line in multiline STR."
  (with-temp-buffer
    (insert str)
    (goto-char (point-min))
    (let ((width 0))
      (while (< (point) (point-max))
        (let* ((line (buffer-substring (pos-bol) (pos-eol)))
               (len (+dashboard-strlen line)))
          (setq width (max width len)))
        (forward-line 1))
      width)))

(defun +dashboard-center (str)
  "Return STR centered with `line-prefix' and `indent-prefix' text properties."
  (declare (obsolete "Use `+dashboard-insert' and `+dashboard-anchor' set instead" "26.05"))
  (let* ((width (+dashboard-maxlen str))
         (prefix (propertize " " 'display `(space :align-to (- center ,(/ (float width) 2))))))
    (propertize str 'line-prefix prefix 'indent-prefix prefix)))

(defun +dashboard-insert (&rest lines)
  "Insert LINES into the dashboard buffer.

Applies line-prefix and indent-prefix text properties to respect
`+dashboard-anchor'."
  (let ((lines (delq nil lines)))
    (if-let* ((halign (cdr-safe +dashboard-anchor)))
        (let* ((width (+dashboard-maxlen (string-join lines "\n")))
               (prefix `(space :align-to
                         (- ,halign ,(if (eq halign 'right)
                                         (+ 2 width)
                                       (/ width 2))))))
          (add-text-properties
           (point) (progn (mapc (lambda (l) (insert l "\n")) lines)
                          (point))
           `(line-prefix ,prefix indent-prefix ,prefix)))
      (insert (string-join lines "\n")))))

(defun +dashboard-insert-centered (&rest lines)
  "Insert LINES into the dashboard buffer, centered with text properties."
  (declare (obsolete "Use `+dashboard-insert' and `+dashboard-anchor' instead" "26.05"))
  (let ((+dashboard-anchor (cons (car-safe +dashboard-anchor) 'center)))
    (apply #'+dashboard-insert lines)))

(defun +dashboard--pwd ()
  (let ((lastcwd +dashboard--last-cwd)
        (policy +dashboard-pwd-policy))
    (cond ((null policy)
           default-directory)
          ((stringp policy)
           (expand-file-name policy lastcwd))
          ((functionp policy)
           (funcall policy lastcwd))
          ((null lastcwd)
           default-directory)
          ((eq policy 'last-project)
           (or (doom-project-root lastcwd)
               lastcwd))
          ((eq policy 'last)
           lastcwd)
          ((warn "`+dashboard-pwd-policy' has an invalid value of '%s'"
                 policy)))))


;;
;;; Widgets

(defun +dashboard-draw-ascii-banner-fn ()
  "Return Doom's default ASCII logo banner."
  (propertize
   (string-join
    '("=================     ===============     ===============   ========  ========"
      "\\\\ . . . . . . .\\\\   //. . . . . . .\\\\   //. . . . . . .\\\\  \\\\. . .\\\\// . . //"
      "||. . ._____. . .|| ||. . ._____. . .|| ||. . ._____. . .|| || . . .\\/ . . .||"
      "|| . .||   ||. . || || . .||   ||. . || || . .||   ||. . || ||. . . . . . . ||"
      "||. . ||   || . .|| ||. . ||   || . .|| ||. . ||   || . .|| || . | . . . . .||"
      "|| . .||   ||. _-|| ||-_ .||   ||. . || || . .||   ||. _-|| ||-_.|\\ . . . . ||"
      "||. . ||   ||-'  || ||  `-||   || . .|| ||. . ||   ||-'  || ||  `|\\_ . .|. .||"
      "|| . _||   ||    || ||    ||   ||_ . || || . _||   ||    || ||   |\\ `-_/| . ||"
      "||_-' ||  .|/    || ||    \\|.  || `-_|| ||_-' ||  .|/    || ||   | \\  / |-_.||"
      "||    ||_-'      || ||      `-_||    || ||    ||_-'      || ||   | \\  / |  `||"
      "||    `'         || ||         `'    || ||    `'         || ||   | \\  / |   ||"
      "||            .===' `===.         .==='.`===.         .===' /==. |  \\/  |   ||"
      "||         .=='   \\_|-_ `===. .==='   _|_   `===. .===' _-|/   `==  \\/  |   ||"
      "||      .=='    _-'    `-_  `='    _-'   `-_    `='  _-'   `-_  /|  \\/  |   ||"
      "||   .=='    _-'          '-__\\._-'         '-_./__-'         `' |. /|  |   ||"
      "||.=='    _-'                                                     `' |  /==.||"
      "=='    _-'                         E M A C S                          \\/   `=="
      "\\   _-'                                                                `-_   /"
      " `''                                                                      ``'")
    "\n")
   'face '+dashboard-banner))

(defun +dashboard-widget-banner ()
  "Draw text and image banner widget in the dashboard buffer."
  (when-let*
      ((banner (and (functionp +dashboard-ascii-banner-fn)
                    (funcall +dashboard-ascii-banner-fn))))
    (let* ((halign (cdr +dashboard-anchor))
           (width (+dashboard-maxlen banner))
           (text-prefix
            `(space
              :align-to (- ,halign
                           ,(if (eq halign 'right)
                                (+ 2 width)
                              (/ width 2)))))
           (top-pad (or (car-safe +dashboard-banner-vertical-padding) 0))
           (bot-pad (or (cdr-safe +dashboard-banner-vertical-padding) 0))
           (beg (point)))
      (when (> top-pad 0)
        (insert (propertize "\n" 'display `(space :height ,top-pad))))

      (insert banner)
      (if-let* (((stringp fancy-splash-image))
                ((file-readable-p fancy-splash-image))
                (image (create-image (fancy-splash-image-file)))
                (image-prefix
                 `(space :align-to (- ,halign
                                      ,@(if (eq halign 'right)
                                            `(,image 1) `((0.5 . ,image))))))
                (prefix
                 (propertize
                  " " 'display `((when (display-graphic-p) . ,image-prefix)
                                 (when (not (display-graphic-p)) . ,text-prefix)))))
          (progn
            (add-text-properties
             beg (point) `(display ,image line-prefix ,prefix wrap-prefix ,prefix))
            (insert "\n"))
        (add-text-properties
         beg (point) `(line-prefix ,text-prefix indent-prefix ,text-prefix)))

      ;; If the user's ASCII banner doesn't end in a newline, the last line
      ;; could be inflated by the following display property.
      (unless (and (bolp) (eolp)) (insert "\n"))

      (when (> bot-pad 0)
        (insert (propertize "\n" 'display `(space :height ,bot-pad)))))))

(defun +dashboard-widget-loaded ()
  "Draw number of modules and packages loaded, and the session's startup time."
  (when doom-init-time
    (+dashboard-insert
     (propertize (doom-display-benchmark-h 'return)
                 'face '+dashboard-loaded))))

(defun +dashboard-widget-shortmenu ()
  "Draw dashboard menu items and keybindings.

See `+dashboard-menu-sections' to change the contents of the menu."
  (insert "\n")
  (dolist (section +dashboard-menu-sections)
    (cl-destructuring-bind (label &key icon action when face key) section
      (when (and (fboundp action)
                 (or (null when)
                     (eval when t)))
        (+dashboard-insert
         (let ((icon (if (stringp icon) icon (eval icon t))))
           (format (format "%s%%s%%10s" (if icon "%3s\t" "%3s"))
                   (or icon "")
                   (with-temp-buffer
                     (insert-text-button
                      label
                      'action
                      `(lambda (_)
                         (call-interactively (or (command-remapping #',action)
                                                 #',action)))
                      'face (or face '+dashboard-menu-title)
                      'follow-link t
                      'help-echo
                      (format "%s (%s)" label
                              (propertize (symbol-name action) 'face '+dashboard-menu-desc)))
                     (format "%-38s" (buffer-string)))
                   ;; Lookup command keys dynamically
                   (propertize
                    (or key
                        (when-let*
                            ((keymaps
                              (delq
                               nil (list (when (bound-and-true-p evil-local-mode)
                                           (evil-get-auxiliary-keymap +dashboard-mode-map 'normal))
                                         +dashboard-mode-map)))
                             (key
                              (or (when keymaps
                                    (where-is-internal action keymaps t))
                                  (where-is-internal action nil t))))
                          (with-temp-buffer
                            (save-excursion (insert (key-description key)))
                            (while (re-search-forward "<\\([^>]+\\)>" nil t)
                              (let ((str (match-string 1)))
                                (replace-match
                                 (upcase (if (< (length str) 3)
                                             str
                                           (substring str 0 3))))))
                            (buffer-string)))
                        "")
                    'face '+dashboard-menu-desc)))
         (propertize "\n" 'display '(space . (:relative-height 0.01))))))))

(defun +dashboard-widget-footer ()
  "Draw project links."
  (+dashboard-insert
   (with-temp-buffer
     (insert (propertize " " 'display '(space . (:relative-height 2.0))) "\n")
     (insert-text-button (or (nerd-icons-codicon "nf-cod-octoface" :face '+dashboard-footer-icon :height 1.3 :v-adjust -0.15)
                             (propertize "github" 'face '+dashboard-footer))
                         'action (lambda (_) (browse-url "https://github.com/doomemacs/doomemacs"))
                         'follow-link t
                         'help-echo "Open Doom Emacs github page")
     (insert "\n")
     (buffer-string))))

(defun +dashboard-widget-spacer ()
  (+dashboard-insert
   (propertize "\n" 'display `(space . (:relative-height 0.5)))))

```

## ui/hl-todo

### ui/hl-todo/README.org

```org
#+title:    :ui hl-todo
#+subtitle: TODO FIXME NOTE DEPRECATED HACK REVIEW
#+created:  February 19, 2017
#+since:    1.3

* Description :unfold:
This module adds syntax highlighting for various tags in code comments, such as
=TODO=, =FIXME=, and =NOTE=, among others.

** Maintainers
- [[doom-user:][@hlissner]]

[[doom-contrib-maintainer:][Become a maintainer?]]

** Module flags
/This module has no flags./

** Packages
- [[doom-package:hl-todo]]

** Hacks
/No hacks documented for this module./

** TODO Changelog
# This section will be machine generated. Don't edit it by hand.
/This module does not have a changelog yet./

* Installation
[[id:01cffea4-3329-45e2-a892-95a384ab2338][Enable this module in your ~doom!~ block.]]

/This module has no external requirements./

* TODO Usage
#+begin_quote
 󱌣 /This module's usage documentation is incomplete./ [[doom-contrib-module:][Complete it?]]
#+end_quote

By enabling this module, the following keywords will be highlighted if they
occur in code comments:

- =TODO=: For things that need to be done, just not today.
- =HACK=: For tidbits that are unconventional and not intended uses of the
  constituent parts, and may break in a future update.
- =FIXME=: For problems that will become bigger problems later if not fixed
  ASAP.
- =REVIEW=: for things that were done hastily and/or hasn't been thoroughly
  tested. it may not even be necessary!
- =NOTE=: For especially important gotchas with a given implementation, directed
  at another user other than the author.
- =DEPRECATED=: For things that just gotta go and will soon be gone.
- =BUG=: For a known bug that needs a workaround.
- =XXX=: For warning about a problematic or misguiding code.

** Keybindings
| keybind | description                      |
|---------+----------------------------------|
| [[kbd:][]t]]      | go to next TODO item             |
| [[kbd:][[t]]      | go to previous TODO item         |
| [[kbd:][SPC s p]] | search project for a string      |
| [[kbd:][SPC s b]] | search buffer for string         |

* TODO Configuration
#+begin_quote
 󱌣 /This module's configuration documentation is incomplete./ [[doom-contrib-module:][Complete it?]]
#+end_quote

To add your own ITEMS you would need to configure them using
~hl-todo-keyword-faces~:
#+begin_src emacs-lisp
;; in $DOOMDIR/config.el
(with-eval-after-load 'hl-todo
  (setq hl-todo-keyword-faces
        `(("FOO"  . ,(face-foreground "MY COLOUR HEX CODE"))
          ("BAR" . ,(face-foreground 'my-colour-var)))))
#+end_src

* Troubleshooting
/There are no known problems with this module./ [[doom-report:][Report one?]]

* Frequently asked questions
/This module has no FAQs yet./ [[doom-suggest-faq:][Ask one?]]

* TODO Appendix
#+begin_quote
 󱌣 This module has no appendix yet. [[doom-contrib-module:][Write one?]]
#+end_quote

```

### ui/hl-todo/config.el

```el
;;; ui/hl-todo/packages.el -*- lexical-binding: t; -*-

(use-package! hl-todo
  :hook (doom-first-buffer . global-hl-todo-mode)
  :config
  (setq hl-todo-highlight-punctuation ":"
        ;; Don't highlight todo keywords in text-mode derivatives unless in
        ;; comments (e.g. data formats like yaml, json, etc).
        hl-todo-text-modes nil
        hl-todo-keyword-faces
        '(;; For reminders to change or add something at a later date.
          ("TODO" warning bold)
          ;; For code (or code paths) that are broken, unimplemented, or slow,
          ;; and may become bigger problems later.
          ("FIXME" error bold)
          ;; For code that needs to be revisited later, either to upstream it,
          ;; improve it, or address non-critical issues.
          ("REVIEW" font-lock-keyword-face bold)
          ;; For code smells where questionable practices are used intentionally
          ;; and is likely to break in a future update.
          ("HACK" font-lock-constant-face bold)
          ;; For sections of code that just gotta go, and will be gone soon.
          ;; Specifically, this means the code is deprecated, not necessarily
          ;; the feature it enables.
          ("DEPRECATED" font-lock-doc-face bold)
          ;; Extra keywords commonly found in the wild, whose meaning may vary
          ;; from project to project. Doom doesn't use BUG.
          ("BUG" error bold)
          ;; Doom uses XXX solely to highlight changes to the source in large
          ;; :override advice functions.
          ("XXX" font-lock-constant-face bold)
          ;; Doom uses NOTE to indicate either A) this comment is about a code
          ;; omission, e.g. "I *would've* put X here, but I didn't because Y",
          ;; or B) it's a comment about a large section of code beyond the scope
          ;; of adjacent lines.
          ("NOTE" success bold)))

  (defadvice! +hl-todo-clamp-font-lock-fontify-region-a (fn &rest args)
    "Fix an `args-out-of-range' error in some modes."
    :around #'hl-todo-mode
    (letf! (defun font-lock-fontify-region (beg end &optional loudly)
             (funcall font-lock-fontify-region (max beg 1) end loudly))
      (apply fn args)))

  ;; Use a more primitive todo-keyword detection method in major modes that
  ;; don't use/have a valid syntax table entry for comments.
  (add-hook! '(pug-mode-hook haml-mode-hook)
    (defun +hl-todo--use-face-detection-h ()
      "Use a different, more primitive method of locating todo keywords."
      (set (make-local-variable 'hl-todo-keywords)
           '(((lambda (limit)
                (let (case-fold-search)
                  (and (re-search-forward hl-todo-regexp limit t)
                       (memq 'font-lock-comment-face (ensure-list (get-text-property (point) 'face))))))
              (1 (hl-todo-get-face) t t))))
      (when hl-todo-mode
        (hl-todo-mode -1)
        (hl-todo-mode +1)))))

```

### ui/hl-todo/packages.el

```el
;; -*- no-byte-compile: t; -*-
;;; ui/hl-todo/packages.el

(package! hl-todo :pin "9a147b9a306471d156dbf8f53af7724061806f80")
```

## ui/indent-guides

### ui/indent-guides/README.org

```org
#+title:    :ui indent-guides
#+subtitle: Line up them indent columns
#+created:  March 11, 2019
#+since:    21.12.0

* TODO Description :unfold:
/(No description yet)/

** Maintainers
/This module has no dedicated maintainers./ [[doom-contrib-maintainer:][Become a maintainer?]]

** Module flags
/This module has no flags./

** Packages
- [[doom-package:indent-bars]]

** Hacks
/No hacks documented for this module./

** TODO Changelog
# This section will be machine generated. Don't edit it by hand.
/This module does not have a changelog yet./

* Installation
[[id:01cffea4-3329-45e2-a892-95a384ab2338][Enable this module in your ~doom!~ block.]]

/This module has no external requirements./

* TODO Usage
#+begin_quote
 󱌣 This module has no usage documentation yet. [[doom-contrib-module:][Write some?]]
#+end_quote

* TODO Configuration
#+begin_quote
 󱌣 This module has no configuration documentation yet. [[doom-contrib-module:][Write some?]]
#+end_quote

* Troubleshooting
/There are no known problems with this module./ [[doom-report:][Report one?]]

* Frequently asked questions
/This module has no FAQs yet./ [[doom-suggest-faq:][Ask one?]]

* TODO Appendix
#+begin_quote
 󱌣 This module has no appendix yet. [[doom-contrib-module:][Write one?]]
#+end_quote

```

### ui/indent-guides/config.el

```el
;;; ui/indent-guides/config.el -*- lexical-binding: t; -*-

(defcustom +indent-guides-inhibit-functions ()
  "A list of predicate functions.

Each function will be run in the context of a buffer where `indent-bars' should
be enabled. If any function returns non-nil, the mode will not be activated."
  :type 'hook
  :group '+indent-guides)


;;
;;; Packages

(use-package! indent-bars
  :unless noninteractive
  :hook (doom-first-buffer . +indent-guides-startup-h)
  :init
  (defun +indent-guides-startup-h ()
    "Set up indent-bars to activate after startup."
    (add-hook 'after-change-major-mode-hook #'+indent-guides-init-maybe-h 95))

  (defun +indent-guides-init-maybe-h ()
    "Enable `indent-bars-mode' depending on `+indent-guides-inhibit-functions'."
    (unless (or (eq major-mode 'fundamental-mode)
                (doom-temp-buffer-p (current-buffer))
                (run-hook-with-args-until-success '+indent-guides-inhibit-functions))
      (indent-bars-mode +1)))

  :config
  (setq indent-bars-treesit-support (modulep! :tools tree-sitter)
        indent-bars-prefer-character
        (or
         ;; Bitmaps are far slower on MacOS, inexplicably, but this needs more
         ;; testing to see if it's specific to ns or emacs-mac builds, or is
         ;; just a general MacOS issue.
         (featurep :system 'macos)
         ;; FIX: A bitmap init bug in emacs-pgtk (before v30) could cause
         ;; crashes (see jdtsmith/indent-bars#3).
         (and (featurep 'pgtk)
              (< emacs-major-version 30)))

        ;; Show indent guides starting from the first column.
        indent-bars-starting-column 0
        ;; Make indent guides subtle; the default is too distractingly colorful.
        indent-bars-width-frac 0.15  ; make bitmaps thinner
        indent-bars-color-by-depth nil
        indent-bars-color '(font-lock-comment-face :face-bg nil :blend 0.425)
        ;; Don't highlight current level indentation; it's distracting and is
        ;; unnecessary overhead for little benefit.
        indent-bars-highlight-current-depth nil
        ;; The default is `t', which shows indent-bars even on blank lines
        ;; beyond the end of an indented block. Setting it to `nil' will cause
        ;; gaps in the indent guides, which looks odd. `least' is a good
        ;; compromise, and doesn't suffer the scrolling issue.
        indent-bars-display-on-blank-lines 'least)

  ;; indent-bars adds this to `enable-theme-functions', which was introduced in
  ;; 29.1, which will be redundant with `doom-load-theme-hook'.
  (unless (boundp 'enable-theme-functions)
    (add-hook 'doom-load-theme-hook #'indent-bars-reset-styles))

  (add-hook! '+indent-guides-inhibit-functions
    ;; Buffers that may have special fontification or may be invisible to the
    ;; user. Particularly src blocks, org agenda, or special modes like magit.
    (defun +indent-guides-in-special-buffers-p ()
      (and (not (derived-mode-p 'text-mode 'prog-mode 'conf-mode))
           (or buffer-read-only
               (bound-and-true-p cursor-intangible-mode)
               (doom-special-buffer-p (current-buffer) t))))
    ;; Org's virtual indentation messes up indent-guides.
    (defun +indent-guides-in-org-indent-mode-p ()
      (bound-and-true-p org-indent-mode))
    ;; Don't display indent guides in childframe popups (which are almost always
    ;; used for completion or eldoc popups).
    #'frame-parent)

  ;; HACK: The way `indent-bars-display-on-blank-lines' functions, it places
  ;;   text properties with a display property containing a newline, which
  ;;   confuses `move-to-column'. This breaks `next-line' and `evil-next-line'
  ;;   without this advice (See jdtsmith/indent-bars#22). Advising
  ;;   `line-move-to-column' isn't enough for `move-to-column' calls in various
  ;;   Evil operators (`evil-delete', `evil-change', etc).
  (defadvice! +indent-guides--prevent-passing-newline-a (fn col &rest args)
    :around #'move-to-column
    (if-let* ((indent-bars-mode)
              (indent-bars-display-on-blank-lines)
              (nlp (line-end-position))
              (dprop (get-text-property nlp 'display))
              ((seq-contains-p dprop ?\n))
              ((> col (- nlp (point)))))
        (goto-char nlp)
      (apply fn col args)))

  ;; HACK: `indent-bars-mode' interacts with some packages poorly, often
  ;;   flooding whole sections of the buffer with indent guides. This section is
  ;;   dedicated to fixing interop with those packages.
  (when (modulep! :tools magit)
    (after! magit-blame
      (add-to-list 'magit-blame-disable-modes 'indent-bars-mode)))

  (let ((hide
         (lambda (beg end)
           (save-excursion
             (let ((indent-bars--display-function #'ignore)
                   (indent-bars--display-blank-lines-function #'ignore))
               (indent-bars--fontify beg (1+ end) nil)))))
        (restore
         (lambda (beg end)
           (save-excursion
             (indent-bars--fontify beg (1+ end) nil)))))
    (when (modulep! :tools lsp)
      ;; REVIEW: Report this upstream to `indent-bars'?
      (defadvice! +indent-guides--remove-after-lsp-ui-peek-a (&rest _)
        :after #'lsp-ui-peek--peek-new
        (when (and indent-bars-mode
                   (not indent-bars-prefer-character)
                   (overlayp lsp-ui-peek--overlay))
          (funcall hide
                   (overlay-start lsp-ui-peek--overlay)
                   (overlay-end lsp-ui-peek--overlay))))
      (defadvice! +indent-guides--restore-after-lsp-ui-peek-a (&rest _)
        :before #'lsp-ui-peek--peek-hide
        (when (and indent-bars-mode indent-bars-prefer-character)
          (funcall restore
                   (overlay-start lsp-ui-peek--overlay)
                   (overlay-end lsp-ui-peek--overlay)))))

    (when (modulep! :editor fold)
      (defadvice! +indent-guides--remove-overlays-in-vimish-fold-a (beg end)
        :after #'vimish-fold
        (when (and indent-bars-mode (not indent-bars-prefer-character))
          (cl-destructuring-bind (beg . end) (vimish-fold--correct-region beg end)
            (dolist (ov (vimish-fold--folds-in beg end))
              (funcall hide (overlay-start ov) (overlay-end ov))))))
      (defadvice! +indent-guides--fix-overlays-after-unfold-a (fn overlay)
        :around #'vimish-fold--unfold
        (when (vimish-fold--vimish-overlay-folded-p overlay)
          (let ((beg (overlay-start overlay))
                (end (overlay-end overlay)))
            (prog1 (funcall fn overlay)
              (when (and indent-bars-mode (not indent-bars-prefer-character))
                (funcall restore beg end)))))))))

```

### ui/indent-guides/packages.el

```el
;; -*- no-byte-compile: t; -*-
;;; ui/indent-guides/packages.el

(package! indent-bars
  :recipe (:host github :repo "jdtsmith/indent-bars")
  :pin "f95fee11d9932cba71d686807025239be0319e91")
```

## ui/ligatures

### ui/ligatures/README.org

```org
#+title:    :ui ligatures
#+subtitle: Distract folks from your code
#+created:  June 16, 2018
#+since:    21.12.0

* Description :unfold:
* Table of Contents :TOC_3:noexport:
- [[#description][Description]]
  - [[#maintainers][Maintainers]]
  - [[#module-flags][Module flags]]
  - [[#packages][Packages]]
  - [[#hacks][Hacks]]
  - [[#changelog][Changelog]]
- [[#installation][Installation]]
- [[#usage][Usage]]
  - [[#mathematical-symbols-replacement][Mathematical symbols replacement]]
  - [[#coding-ligatures][Coding ligatures]]
    - [[#details][Details]]
- [[#configuration][Configuration]]
  - [[#symbol-replacements-λ-for-lambda][Symbol replacements (λ for "lambda"...)]]
  - [[#font-ligatures-turning--into-an-arrow][Font ligatures (turning "=>" into an arrow...)]]
    - [[#setting-ligatures-for-specific-font-or-major-mode][Setting ligatures for specific font or major mode]]
    - [[#overwriting-all-default-ligatures][Overwriting all default ligatures]]
- [[#troubleshooting][Troubleshooting]]
  - [[#some-symbols-are-not-rendering-correctly][Some symbols are not rendering correctly]]
- [[#frequently-asked-questions][Frequently asked questions]]
- [[#appendix][Appendix]]

** Maintainers
- [[doom-user:][@gagbo]]

[[doom-contrib-maintainer:][Become a maintainer?]]

** Module flags
- +extra ::
  Enables extra symbol substitutions in certain modes, for example ~lambda~ in
  lisps are replaced with ~λ~.

** Packages
- [[https://github.com/mickeynp/ligature.el][ligature.el]] (on Emacs 28+ with Harfbuzz)

** Hacks
/No hacks documented for this module./

** TODO Changelog
# This section will be machine generated. Don't edit it by hand.
/This module does not have a changelog yet./

* Installation
[[id:01cffea4-3329-45e2-a892-95a384ab2338][Enable this module in your ~doom!~ block.]]

This module requires one of three setups for ligatures to work:

- A recent enough version of Emacs which will compose ligatures automatically
  (Emacs 28 with Harfbuzz support), or
- Mitsuharu's =emacs-mac= build on macOS (available on Homebrew), or
- A patched font for Doom's fallback ligature support.

  /This module does not have specific installation instructions/

  ~doom doctor~ will tell you if the module is incompatible with your current
  Emacs version, and what you can do to remediate.

* Usage
#+begin_quote
 󱌣 /This module's usage documentation is incomplete./ [[doom-contrib-module:][Complete it?]]
#+end_quote

** Mathematical symbols replacement
If you want to set symbol replacements for modules that don't have them by
default you can use the ~set-ligatures!~ function in your config.el file
#+BEGIN_SRC emacs-lisp
(with-eval-after-load 'PACKAGE
  (set-ligatures! 'MAJOR-MODE
    :symbol "keyword"))
#+end_src

E.g.
#+begin_src emacs-lisp
(with-eval-after-load 'go-mode ; in this case the major mode and package named the same thing
  (set-ligatures! 'go-mode
    :def "func" ; function keyword
    :true "true" :false "false"
    ; this will replace not only definitions
    ; but coresponding functions aswell
    :int "int" :str "string"
    :float "float" :bool "bool"
    :for "for"
    :return "return" :yield "yield"))
#+end_src

You can set these symbols out of the box:
#+begin_src emacs-lisp
(set-ligatures! 'MAJOR-MODE
    ;; Functional
    :lambda        "lambda keyword"
    :def           "function keyword"
    :composition   "composition"
    :map           "map/dictionary keyword"
    ;; Types
    :null          "null type"
    :true          "true keyword"
    :false         "false keyword"
    :int           "int keyword"
    :float         "float keyword"
    :str           "string keyword"
    :bool          "boolean keyword"
    :list          "list keyword"
    ;; Flow
    :not           "not operator"
    :in            "in operator"
    :not-in        "not in operator"
    :and           "and keyword"
    :or            "or keyword"
    :for           "for keyword"
    :some          "some keyword"
    :return        "return"
    :yield         "yeild"
    ;; Other
    :union         "Union keyword"
    :intersect     "Intersect keyword"
    :diff          "diff keyword"
    :tuple         "Tuple Keyword "
    :pipe          "Pipe Keyword"
    :dot           "Dot operator")
#+end_src

If you have multiple versions of the same keyword you can set the symbol twice:
#+begin_src emacs-lisp
(set-ligatures! scala-mode
  :null "none"
  :null "None")
#+end_src


** Coding ligatures
This module includes configuration to compose combinations like =->= or =::=
into prettier glyphs (called a ligature), specific for your font, or specific
for the major modes that you want to use.

As these ligatures come from the font itself instead of elisp symbols, we use
=set-font-ligatures!=

#+begin_src elisp
(set-font-ligatures! '(haskell-mode clojure-mode) ">>=" ">>-")
#+end_src

*** Details
Ligatures are implemented using a **composition-function-table** method: regexps are
used to match all the usual sequences which are composed into ligatures. These
regexps are passed to emacs directly, which asks Harfbuzz to shape it. Ligatures
are obtained automatically depending on the capabilities of the font, and no
font-specific configuration is necessary.

Emacs-mac port implements the same method natively in [[https://bitbucket.org/mituharu/emacs-mac/src/26c8fd9920db9d34ae8f78bceaec714230824dac/lisp/term/mac-win.el?at=master#lines-345:805][its code]], nothing is
necessary on Doom side; otherwise, Doom uses the [[https://github.com/mickeynp/ligature.el][ligature.el]] package that
implements this method for Emacs 28+ built with Harfbuzz support. Therefore, the
module will not work with Emacs 27 or previous.

Even though harfbuzz has been included in emacs 27, there is currently a
[[https://lists.gnu.org/archive/html/bug-gnu-emacs/2020-04/msg01121.html][bug
(#40864)]] which prevents a safe usage of the /composition-function-table/ method in
Emacs 27.

* Configuration
** Symbol replacements (λ for "lambda"...)
if you don't like the symbols chosen you can change them by using:
#+begin_src emacs-lisp
;; you don't need to include all of them you can pick and mix
(plist-put! +ligatures-extra-symbols
  ;; org
  :name          "»"
  :src_block     "»"
  :src_block_end "«"
  :quote         "“"
  :quote_end     "”"
  ;; Functional
  :lambda        "λ"
  :def           "ƒ"
  :composition   "∘"
  :map           "↦"
  ;; Types
  :null          "∅"
  :true          "𝕋"
  :false         "𝔽"
  :int           "ℤ"
  :float         "ℝ"
  :str           "𝕊"
  :bool          "𝔹"
  :list          "𝕃"
  ;; Flow
  :not           "￢"
  :in            "∈"
  :not-in        "∉"
  :and           "∧"
  :or            "∨"
  :for           "∀"
  :some          "∃"
  :return        "⟼"
  :yield         "⟻"
  ;; Other
  :union         "⋃"
  :intersect     "∩"
  :diff          "∖"
  :tuple         "⨂"
  :pipe          ""
  :dot           "•")  ;; you could also add your own if you want
#+end_src

** Font ligatures (turning "=>" into an arrow...)
*** Setting ligatures for specific font or major mode
As the [[https://github.com/mickeynp/ligature.el][README]] for ligature.el states, you can manipulate the ligatures that you
want to enable, specific for your font, or specific for the major modes that you
want to use. =set-font-ligatures!= is a thin wrapper around =ligature.el= to control these.

#+begin_src elisp
(set-font-ligatures! '(haskell-mode clojure-mode) ">>=" ">>-")
#+end_src

This call will:
- overwrite all preceding calls to =set-font-ligatures!=
  for =haskell-mode= and =clojure-mode= specifically, but
- keep the inheritance to ligatures set for all modes, or parent modes like =prog-mode=

*** Overwriting all default ligatures
If you want to "start from scratch" and get control over all ligatures that
happen in all modes, you can use

#+begin_src elisp
;; Set all your custom ligatures for all prog-modes here.
;; This section is *outside* the `with-eval-after-load' block.
;; Example: only get ligatures for "==" and "===" in programming modes by
;; default, and get only "www" in all buffers by default.
(set-font-ligatures! 'prog-mode :append "==" "===")
(set-font-ligatures! 't :append "www")
;; Set any of those variables to nil to wipe all defaults.

;; Set all your additional custom ligatures for other major modes here.
;; Example: enable traditional ligature support in eww-mode, if the
;; `variable-pitch' face supports it
(set-font-ligatures! 'eww-mode "ff" "fi" "ffi")
#+end_src

* Troubleshooting
[[doom-report:][Report an issue?]]

** Some symbols are not rendering correctly
This can usually be fixed by doing one of the following:

- Set [[var:doom-symbol-font]].
- Disable the [[doom-module::ui unicode]] module. It overrides [[var:doom-symbol-font]]
  and should only be used as a last resort.

* Frequently asked questions
/This module has no FAQs yet./ [[doom-suggest-faq:][Ask one?]]

* TODO Appendix
#+begin_quote
 󱌣 This module has no appendix yet. [[doom-contrib-module:][Write one?]]
#+end_quote
```

### ui/ligatures/config.el

```el
;;; ui/ligatures/config.el -*- lexical-binding: t; -*-

(defvar +ligatures-extra-symbols
  '(;; org
    :name          "»"
    :src_block     "»"
    :src_block_end "«"
    :quote         "“"
    :quote_end     "”"
    ;; Functional
    :lambda        "λ"
    :def           "ƒ"
    :composition   "∘"
    :map           "↦"
    ;; Types
    :null          "∅"
    :true          "𝕋"
    :false         "𝔽"
    :int           "ℤ"
    :float         "ℝ"
    :str           "𝕊"
    :bool          "𝔹"
    :list          "𝕃"
    ;; Flow
    :not           "￢"
    :in            "∈"
    :not-in        "∉"
    :and           "∧"
    :or            "∨"
    :for           "∀"
    :some          "∃"
    :return        "⟼"
    :yield         "⟻"
    ;; Other
    :union         "⋃"
    :intersect     "∩"
    :diff          "∖"
    :tuple         "⨂"
    :pipe          "" ;; FIXME: find a non-private char
    :dot           "•")
  "Maps identifiers to symbols, recognized by `set-ligatures'.

This should not contain any symbols from the Unicode Private Area! There is no
universal way of getting the correct symbol as that area varies from font to
font.")

(defvar +ligatures-alist
  '((prog-mode "|||>" "<|||" "<==>" "<!--" "####" "~~>" "***" "||=" "||>"
               ":::" "::=" "=:=" "===" "==>" "=!=" "=>>" "=<<" "=/=" "!=="
               "!!." ">=>" ">>=" ">>>" ">>-" ">->" "->>" "-->" "---" "-<<"
               "<~~" "<~>" "<*>" "<||" "<|>" "<$>" "<==" "<=>" "<=<" "<->"
               "<--" "<-<" "<<=" "<<-" "<<<" "<+>" "</>" "###" "#_(" "..<"
               "..." "+++" "/==" "///" "_|_" "www" "&&" "^=" "~~" "~@" "~="
               "~>" "~-" "**" "*>" "*/" "||" "|}" "|]" "|=" "|>" "|-" "{|"
               "[|" "]#" "::" ":=" ":>" ":<" "$>" "==" "=>" "!=" "!!" ">:"
               ">=" ">>" ">-" "-~" "-|" "->" "--" "-<" "<~" "<*" "<|" "<:"
               "<$" "<=" "<>" "<-" "<<" "<+" "</" "#{" "#[" "#:" "#=" "#!"
               "##" "#(" "#?" "#_" "%%" ".=" ".-" ".." ".?" "+>" "++" "?:"
               "?=" "?." "??" ";;" "/*" "/=" "/>" "//" "__" "~~" "(*" "*)"
               "\\\\" "://")
    (t))
  "A alist of ligatures to enable in specific modes.

To configure this variable, use `set-ligatures!'.")

(defvar +ligatures-in-modes nil
  "List of major modes where ligatures should be enabled.")
(make-obsolete-variable '+ligatures-in-modes "Use `ligature-ignored-major-modes' instead" "24.10.0")

(defvar +ligatures-prog-mode-list nil
  "A list of ligatures to enable in all `prog-mode' buffers.")
(make-obsolete-variable '+ligatures-prog-mode-list "Use `+ligatures-alist' instead" "24.09.0")

(defvar +ligatures-all-modes-list nil
  "A list of ligatures to enable in all buffers.")
(make-obsolete-variable '+ligatures-all-modes-list "Use `+ligatures-alist' instead" "24.09.0")

(defvar +ligatures-extra-alist '((t))
  "A map of major modes to symbol lists (for `prettify-symbols-alist').

To configure this variable, use `set-ligatures!'.")

(defvar +ligatures-extras-in-modes t
  "List of major modes where extra ligatures should be enabled.

Extra ligatures are mode-specific substituions, defined in
`+ligatures-extra-symbols' and assigned with `set-ligatures!'. This variable
controls where these are enabled.

  If t, enable it everywhere (except `fundamental-mode').
  If the first element is not, enable it in any mode besides what is listed.
  If nil, don't enable these extra ligatures anywhere (though it's more
efficient to remove the `+extra' flag from the :ui ligatures module instead).")

(defun +ligatures--enable-p (modes)
  "Return t if ligatures should be enabled in this buffer depending on MODES."
  (unless (eq major-mode 'fundamental-mode)
    (or (eq modes t)
        (if (eq (car modes) 'not)
            (not (apply #'derived-mode-p (cdr modes)))
          (apply #'derived-mode-p modes)))))

(defun +ligatures-init-extra-symbols-h ()
  "Set up `prettify-symbols-mode' for the current buffer.

Overwrites `prettify-symbols-alist' and activates `prettify-symbols-mode' if
(and only if) there is an associated entry for the current major mode (or a
parent mode) in `+ligatures-extra-alist' AND the current mode (or a parent mode)
isn't disabled in `+ligatures-extras-in-modes'."
  (when after-init-time
    (when-let*
        (((+ligatures--enable-p +ligatures-extras-in-modes))
         (symbols
          (if-let* ((symbols (assq major-mode +ligatures-extra-alist)))
              (cdr symbols)
            (cl-loop for (mode . symbols) in +ligatures-extra-alist
                     if (derived-mode-p mode)
                     return symbols))))
      (setq prettify-symbols-alist
            (append symbols
                    ;; Don't overwrite global defaults
                    (default-value 'prettify-symbols-alist)))
      (when (bound-and-true-p prettify-symbols-mode)
        (prettify-symbols-mode -1))
      (prettify-symbols-mode +1))))


;;
;;; Bootstrap

;;;###package prettify-symbols
;; When you get to the right edge, it goes back to how it normally prints
(setq prettify-symbols-unprettify-at-point 'right-edge)

(when (modulep! +extra)
  (add-hook 'after-change-major-mode-hook #'+ligatures-init-extra-symbols-h))

(cond
 ;; The emacs-mac build of Emacs appears to have built-in support for ligatures,
 ;; using the same composition-function-table method
 ;; https://bitbucket.org/mituharu/emacs-mac/src/26c8fd9920db9d34ae8f78bceaec714230824dac/lisp/term/mac-win.el?at=master#lines-345:805
 ;; so use that instead if this module is enabled.
 ((if (featurep :system 'macos)
      (fboundp 'mac-auto-operator-composition-mode))
  (add-hook 'doom-init-ui-hook #'mac-auto-operator-composition-mode 'append))

 ((and (or (featurep 'ns)
           (string-match-p "HARFBUZZ" system-configuration-features))
       (featurep 'composite))   ; Emacs loads `composite' at startup

  (after! ligature
    ;; DEPRECATED: For backwards compatibility. Remove later.
    (with-no-warnings
      (when +ligatures-prog-mode-list
        (setf (alist-get 'prog-mode +ligatures-alist) +ligatures-prog-mode-list))
      (when +ligatures-all-modes-list
        (setf (alist-get t +ligatures-alist) +ligatures-all-modes-list)))
    (dolist (lig +ligatures-alist)
      (ligature-set-ligatures (car lig) (cdr lig))))

  (add-hook 'doom-init-ui-hook #'global-ligature-mode 'append)))
```

### ui/ligatures/packages.el

```el
;; -*- no-byte-compile: t; -*-
;;; ui/ligatures/packages.el

(when (and (or (featurep 'ns)
               (string-match-p "HARFBUZZ" system-configuration-features))
           (featurep 'composite))
  (package! ligature :pin "6ac1634612dbd42f7eb81ecaf022bd239aabb954"))
```

### ui/ligatures/autoload/ligatures.el

```el
;;; ui/ligatures/autoload/ligatures.el -*- lexical-binding: t; -*-

;; DEPRECATED
;;;###autodef
(define-obsolete-function-alias 'set-pretty-symbols! 'set-ligatures! "2.1.0")

;;;###autodef
(defun set-ligatures! (modes &rest plist)
  "Associates string patterns with icons in certain major-modes.

  MODES is a major mode symbol or a list of them.
  PLIST is a property list whose keys must match keys in
`+ligatures-extra-symbols', and whose values are strings representing the text
to be replaced with that symbol.

If the car of PLIST is nil, then unset any
pretty symbols and ligatures previously defined for MODES.

For example, the rule for emacs-lisp-mode is very simple:

  (after! elisp-mode
    (set-ligatures! \\='emacs-lisp-mode
      :lambda \"lambda\"))

This will replace any instances of \"lambda\" in emacs-lisp-mode with the symbol
associated with :lambda in `+ligatures-extra-symbols'.

Pretty symbols can be unset by passing `nil':

  (after! rustic
    (set-ligatures! \\='rustic-mode nil))

Note that this will keep all ligatures in `+ligatures-prog-mode-list' active, as
`emacs-lisp-mode' is derived from `prog-mode'."
  (declare (indent defun))
  (if (null (car-safe plist))
      (dolist (mode (ensure-list modes))
        (setf (alist-get mode +ligatures-extra-alist nil t) nil))
    (let ((results))
      (while plist
        (let ((key (pop plist)))
            (when-let* ((char (plist-get +ligatures-extra-symbols key)))
              (push (cons (pop plist) char) results))))
      (dolist (mode (ensure-list modes))
        (setf (alist-get mode +ligatures-extra-alist)
              (if-let* ((old-results (alist-get mode +ligatures-extra-alist)))
                  (dolist (cell results old-results)
                    (setf (alist-get (car cell) old-results) (cdr cell)))
                results))))))

;;;###autodef
(defun set-font-ligatures! (modes &rest ligatures)
  "Associates string patterns with ligatures in certain major-modes.

  MODES is a major mode symbol or a list of them.
  LIGATURES is a list of ligatures that should be handled by the font,
    like \"==\" or \"-->\". LIGATURES is a list of strings.

For example, the rule for emacs-lisp-mode is very simple:

  (set-font-ligatures! \\='emacs-lisp-mode \"->\")

This will ligate \"->\" into the arrow of choice according to your font.

All font ligatures for emacs-lisp-mode can be unset with:

  (set-font-ligatures! \\='emacs-lisp-mode nil)

However, ligatures for any parent modes (like `prog-mode') will still be in
effect, as `emacs-lisp-mode' is derived from `prog-mode'."
  (declare (indent defun))
  (after! ligature
    (if (or (null ligatures) (equal ligatures '(nil)))
        (dolist (table ligature-composition-table)
          (let ((modes (ensure-list modes))
                (tmodes (car table)))
            (cond ((and (listp tmodes) (cl-intersection modes tmodes))
                   (let ((tmodes (cl-nset-difference tmodes modes)))
                     (setq ligature-composition-table
                           (if tmodes
                               (cons tmodes (cdr table))
                             (delete table ligature-composition-table)))))
                  ((memq tmodes modes)
                   (setq ligature-composition-table (delete table ligature-composition-table))))))
      (ligature-set-ligatures modes ligatures))))

```

## ui/modeline

### ui/modeline/README.org

```org
#+title:    :ui modeline
#+subtitle: Snazzy, Atom-inspired modeline, plus API
#+created:  February 20, 2017
#+since:    2.0.0

* Description :unfold:
This module provides an Atom-inspired, minimalistic modeline for Doom Emacs,
powered by the [[doom-package:doom-modeline]] package (where you can find screenshots).

** Maintainers
- [[doom-user:][@hlissner]]

[[doom-contrib-maintainer:][Become a maintainer?]]

** Module flags
- +light ::
  Enable a lighter, less featureful version of the modeline that does not depend
  on [[doom-package:doom-modeline]], which has performances issues in some cases.

** Packages
- [[doom-package:anzu]]
- [[doom-package:doom-modeline]] unless [[doom-module:+light]]
- [[doom-package:evil-anzu]] if [[doom-module::editor evil]]

** Hacks
/No hacks documented for this module./

** TODO Changelog
# This section will be machine generated. Don't edit it by hand.
/This module does not have a changelog yet./

* Installation
[[id:01cffea4-3329-45e2-a892-95a384ab2338][Enable this module in your ~doom!~ block.]]

/This module has no external requirements./

* TODO Usage
#+begin_quote
 󱌣 /This module's usage documentation is incomplete./ [[doom-contrib-module:][Complete it?]]
#+end_quote

** Hiding the modeline
- You can use ~M-x mode-line-invisible-mode RET~ to hide modeline for the current
  buffer.

** TODO Switching the modeline and header line

* TODO Configuration
#+begin_quote
 󱌣 /This module's configuration documentation is incomplete./ [[doom-contrib-module:][Complete it?]]
#+end_quote

** TODO Changing the default modeline

** TODO Activating a format

** TODO Defining a modeline format

** TODO Defining a modeline segment

** TODO Extracting Doom's modeline into your config

* Troubleshooting
[[doom-report:][Report an issue?]]

** Where are my minor modes?
I rarely need to know what minor modes are active, so I removed them. ~M-x
doom/describe-active-minor-mode~ was written to substitute for it.

** Icons in my modeline look strange
1. Check whether ~nerd-icons~ are installed. Run ~M-x
   nerd-icons-install-fonts~ to install the resource fonts. Note that
   ~nerd-icons~ only support GUI. See [[https://github.com/domtronn/nerd-icons.el][nerd-icons]] for details.

2. ~cnfonts~ will conflict with ~nerd-icons~. You can refer the following
   workaround:
    #+begin_src emacs-lisp
    ;; See https://github.com/seagle0128/doom-modeline/issues/278#issuecomment-569510336
    ;; Add to $DOOMDIR/packages.el
    (package! cnfonts)
    ;; Add to $DOOMDIR/config.el
    (add-hook 'after-setting-font-hook #'cnfonts-set-font)
    #+end_src

** The right side of the modeline is cut off
I believe the consensus is: this is due to oversized icons, i.e. a font issue.
Some possible solutions:

1. Add some padding to the modeline definition:
    #+begin_src emacs-lisp
    (with-eval-after-load 'doom-modeline
      (doom-modeline-def-modeline 'main
        '(bar matches buffer-info remote-host buffer-position parrot selection-info)
        '(misc-info minor-modes check input-method buffer-encoding major-mode process vcs "  "))) ; <-- added padding here
    #+end_src

2. Use another font for the mode line (or a different ~:height~) (source)
    #+begin_src emacs-lisp
    (custom-set-faces!
      '(mode-line :family "Noto Sans" :height 0.9)
      '(mode-line-inactive :family "Noto Sans" :height 0.9))
    #+end_src

(Mentioned in [[doom-ref:][#1680]], [[doom-ref:][#278]] and [[https://github.com/seagle0128/doom-modeline/issues/334][seagle0128/doom-modeline#334]])

4. Change the width of icon characters in ~char-width-table~:
    #+begin_src emacs-lisp
    (add-hook! 'doom-modeline-mode-hook
      (let ((char-table char-width-table))
        (while (setq char-table (char-table-parent char-table)))
        (dolist (pair doom-modeline-rhs-icons-alist)
          (let ((width 2)  ; <-- tweak this
                (chars (cdr pair))
                (table (make-char-table nil)))
            (dolist (char chars)
              (set-char-table-range table char width))
            (optimize-char-table table)
            (set-char-table-parent table char-table)
            (setq char-width-table table)))))
    #+end_src

   If this doesn't help, try different values for ~width~ such as ~width 1~ or
   ~width 3~.

* Frequently asked questions
/This module has no FAQs yet./ [[doom-suggest-faq:][Ask one?]]

* TODO Appendix
#+begin_quote
 󱌣 /This module's appendix is incomplete./ [[doom-contrib-module:][Write more?]]
#+end_quote

** Autodefs
- ~def-modeline-format! NAME LEFT &optional RIGHT~
- ~def-modeline-segment! NAME &rest REST~
- ~set-modeline! NAME &optional DEFAULT~

** Variables
- doom-modeline-height
- doom-modeline-bar-width
- doom-modeline-buffer-file-name-style
- doom-modeline-icon
- doom-modeline-major-mode-icon
- doom-modeline-major-mode-color-icon
- doom-modeline-buffer-state-icon
- doom-modeline-buffer-modification-icon
- doom-modeline-minor-modes
- doom-modeline-enable-word-count
- doom-modeline-buffer-encoding
- doom-modeline-indent-info
- doom-modeline-checker-simple-format
- doom-modeline-vcs-max-length
- doom-modeline-persp-name
- doom-modeline-lsp
- doom-modeline-github
- doom-modeline-github-interval
- doom-modeline-env-version
- doom-modeline-mu4e
- doom-modeline-irc
- doom-modeline-irc-stylize

** Faces
- doom-modeline-buffer-path
- doom-modeline-buffer-file
- doom-modeline-buffer-modified
- doom-modeline-buffer-major-mode
- doom-modeline-buffer-minor-mode
- doom-modeline-project-parent-dir
- doom-modeline-project-dir
- doom-modeline-project-root-dir
- doom-modeline-highlight
- doom-modeline-panel
- doom-modeline-debug
- doom-modeline-info
- doom-modeline-warning
- doom-modeline-urgent
- doom-modeline-unread-number
- doom-modeline-bar
- doom-modeline-inactive-bar
- doom-modeline-evil-emacs-state
- doom-modeline-evil-insert-state
- doom-modeline-evil-motion-state
- doom-modeline-evil-normal-state
- doom-modeline-evil-operator-state
- doom-modeline-evil-visual-state
- doom-modeline-evil-replace-state
- doom-modeline-persp-name
- doom-modeline-persp-buffer-not-in-persp
```

### ui/modeline/autoload.el

```el
;;; ui/modeline/autoload/modeline.el -*- lexical-binding: t; -*-

(defvar +modeline--old-bar-height nil)
;;;###autoload
(defun +modeline-resize-for-font-h ()
  "Adjust the modeline's height when the font size is changed by
`doom/increase-font-size' or `doom/decrease-font-size'.

Meant for `doom-change-font-size-hook'."
  (unless +modeline--old-bar-height
    (setq +modeline--old-bar-height doom-modeline-height))
  (let ((default-height +modeline--old-bar-height)
        (scale (or (frame-parameter nil 'font-scale) 0)))
    (setq doom-modeline-height
          (if (> scale 0)
              (+ default-height (* scale doom-font-increment))
            default-height))))

;;;###autoload
(defun +modeline-update-env-in-all-windows-h (&rest _)
  "Update version strings in all buffers."
  (dolist (window (window-list))
    (with-selected-window window
      (when (fboundp 'doom-modeline-update-env)
        (doom-modeline-update-env))
      (force-mode-line-update))))

;;;###autoload
(defun +modeline-clear-env-in-all-windows-h (&rest _)
  "Blank out version strings in all buffers."
  (unless (modulep! +light)
    (dolist (buffer (buffer-list))
      (with-current-buffer buffer
        (setq doom-modeline-env--version
              (bound-and-true-p doom-modeline-load-string)))))
  (force-mode-line-update t))
```

### ui/modeline/config.el

```el
;;; ui/modeline/config.el -*- lexical-binding: t; -*-

(when (modulep! +light)
  (load! "+light"))


(use-package! doom-modeline
  :unless (modulep! +light)
  :hook (doom-after-init . doom-modeline-mode)
  :hook (doom-modeline-mode . size-indication-mode) ; filesize in modeline
  :hook (doom-modeline-mode . column-number-mode)   ; cursor column in modeline
  :init
  ;; We display project info in the modeline ourselves
  (setq projectile-dynamic-mode-line nil)
  ;; Set these early so they don't trigger variable watchers
  (setq doom-modeline-bar-width 3
        doom-modeline-github nil
        doom-modeline-mu4e nil
        doom-modeline-persp-name nil
        doom-modeline-minor-modes nil
        doom-modeline-major-mode-icon nil
        doom-modeline-check 'simple  ; default is too busy
        doom-modeline-buffer-file-name-style 'relative-from-project
        ;; Only show file encoding if it's non-UTF-8 and different line endings
        ;; than the current OSes preference
        doom-modeline-buffer-encoding 'nondefault
        doom-modeline-default-eol-type (if (featurep :system 'windows) 1 0))

  :config
  ;; Fix an issue where these two variables aren't defined in TTY Emacs on MacOS
  (defvar mouse-wheel-down-event nil)
  (defvar mouse-wheel-up-event nil)

  (add-hook 'after-setting-font-hook #'+modeline-resize-for-font-h)
  (add-hook 'doom-load-theme-hook #'doom-modeline-refresh-bars)

  (add-to-list 'doom-modeline-mode-alist '(+doom-dashboard-mode . dashboard)) ; DEPRECATED
  (add-to-list 'doom-modeline-mode-alist '(+dashboard-mode . dashboard))
  (add-hook! 'magit-mode-hook
    (defun +modeline-hide-in-non-status-buffer-h ()
      "Show minimal modeline in magit-status buffer, no modeline elsewhere."
      (if (eq major-mode 'magit-status-mode)
          (doom-modeline-set-modeline 'magit)
        (mode-line-invisible-mode))))


  ;;
  ;;; Extensions
  (use-package! anzu
    :after-call isearch-mode)

  (use-package! evil-anzu
    :when (modulep! :editor evil)
    :after-call evil-ex-start-search evil-ex-start-word-search evil-ex-search-activate-highlight
    :config (global-anzu-mode +1)))
```

### ui/modeline/packages.el

```el
;; -*- no-byte-compile: t; -*-
;;; ui/modeline/packages.el

(unless (modulep! +light)
  (package! doom-modeline :pin "871f91fad58aefa9e549cbff1929e0dd328021c7"))
(package! anzu :pin "21cb5ab2295614372cb9f1a21429381e49a6255f")
(when (modulep! :editor evil)
  (package! evil-anzu :pin "7309650425797420944075c9c1556c7c1ff960b3"))
```

## ui/ophints

### ui/ophints/README.org

```org
#+title:    :ui ophints
#+subtitle: An indicator for “what did I just do?”
#+created:  June 04, 2017
#+since:    2.0.0

* Description :unfold:
This module provides op-hints (operation hinting), i.e. visual feedback for
certain editing operations. It highlights regions of text that the last
operation (like yank) acted on.

Uses [[doom-package:evil-goggles]] for evil users and [[doom-package:goggles]]
otherwise.

** Maintainers
- [[doom-user:][@hlissner]]

[[doom-contrib-maintainer:][Become a maintainer?]]

** Module flags
/This module has no flags./

** Packages
- [[doom-package:evil-goggles]] if [[doom-module::editor evil]]
- [[doom-package:goggles]] unless [[doom-module::editor evil]]

** Hacks
/No hacks documented for this module./

** TODO Changelog
# This section will be machine generated. Don't edit it by hand.
/This module does not have a changelog yet./

* Installation
[[id:01cffea4-3329-45e2-a892-95a384ab2338][Enable this module in your ~doom!~ block.]]

/This module has no external requirements./

* TODO Usage
#+begin_quote
 󱌣 This module has no usage documentation yet. [[doom-contrib-module:][Write some?]]
#+end_quote

* TODO Configuration
#+begin_quote
 󱌣 This module has no configuration documentation yet. [[doom-contrib-module:][Write some?]]
#+end_quote

* Troubleshooting
/There are no known problems with this module./ [[doom-report:][Report one?]]

* Frequently asked questions
/This module has no FAQs yet./ [[doom-suggest-faq:][Ask one?]]

* TODO Appendix
#+begin_quote
 󱌣 This module has no appendix yet. [[doom-contrib-module:][Write one?]]
#+end_quote
```

### ui/ophints/config.el

```el
;;; ui/ophints/config.el -*- lexical-binding: t; -*-

(use-package! evil-goggles
  :when (modulep! :editor evil)
  :hook (doom-first-input . evil-goggles-mode)
  :init
  (setq evil-goggles-duration 0.1
        evil-goggles-pulse nil ; too slow
        ;; evil-goggles provides a good indicator of what has been affected.
        ;; delete/change is obvious, so I'd rather disable it for these.
        evil-goggles-enable-delete nil
        evil-goggles-enable-change nil)
  :config
  (dolist (cmd `((evil-magit-yank-whole-line
                  :face evil-goggles-yank-face
                  :switch evil-goggles-enable-yank
                  :advice evil-goggles--generic-async-advice)
                 (+evil:yank-unindented
                  :face evil-goggles-yank-face
                  :switch evil-goggles-enable-yank
                  :advice evil-goggles--generic-async-advice)
                 (+eval:region
                  :face evil-goggles-yank-face
                  :switch evil-goggles-enable-yank
                  :advice evil-goggles--generic-async-advice)
                 ,@(when (modulep! :editor lispy)
                     '((lispyville-delete
                        :face evil-goggles-delete-face
                        :switch evil-goggles-enable-delete
                        :advice evil-goggles--generic-blocking-advice)
                       (lispyville-delete-line
                        :face evil-goggles-delete-face
                        :switch evil-goggles-enable-delete
                        :advice evil-goggles--delete-line-advice)
                       (lispyville-yank
                        :face evil-goggles-yank-face
                        :switch evil-goggles-enable-yank
                        :advice evil-goggles--generic-async-advice)
                       (lispyville-yank-line
                        :face evil-goggles-yank-face
                        :switch evil-goggles-enable-yank
                        :advice evil-goggles--generic-async-advice)
                       (lispyville-change
                        :face evil-goggles-change-face
                        :switch evil-goggles-enable-change
                        :advice evil-goggles--generic-blocking-advice)
                       (lispyville-change-line
                        :face evil-goggles-change-face
                        :switch evil-goggles-enable-change
                        :advice evil-goggles--generic-blocking-advice)
                       (lispyville-change-whole-line
                        :face evil-goggles-change-face
                        :switch evil-goggles-enable-change
                        :advice evil-goggles--generic-blocking-advice)
                       (lispyville-indent
                        :face evil-goggles-indent-face
                        :switch evil-goggles-enable-indent
                        :advice evil-goggles--generic-async-advice)
                       (lispyville-join
                        :face evil-goggles-join-face
                        :switch evil-goggles-enable-join
                        :advice evil-goggles--join-advice)))))
    (add-to-list 'evil-goggles--commands cmd)))

(use-package! goggles
  :unless (modulep! :editor evil)
  :hook ((prog-mode text-mode) . goggles-mode)
  :config
  (goggles-delete 'disable) ; Consistent with `evil-goggles-enable-delete' setting
  (goggles-define +goggles-general-undo undo) ; goggles only supports `primitive-undo' by default
  (goggles-define +goggles-register-paste insert-register)
  (goggles-define +goggles-kill-word backward-kill-word kill-word)
  (goggles-define +goggles-undo-fu undo-fu-only-undo undo-fu-only-redo))
```

### ui/ophints/packages.el

```el
;; -*- no-byte-compile: t; -*-
;;; ui/ophints/packages.el

(if (modulep! :editor evil)
    (package! evil-goggles :pin "34ca276a85f615d2b45e714c9f8b5875bcb676f3")
  (package! goggles :pin "68d9909dab6b1a0f64f7888b2b2e74cda78faf1e"))
```

## ui/popup

### ui/popup/README.org

```org
#+title:    :ui popup
#+subtitle: Tame sudden yet inevitable temporary windows
#+created:  January 06, 2018
#+since:    21.12.0

* Description :unfold:
This module provides a customizable popup window management system.

Not all windows are created equally. Some are less important. Some I want gone
once they have served their purpose, like code output or a help buffer. Others I
want to stick around, like a scratch buffer or org-capture popup.

More than that, popups ought to be the second class citizens of my editor;
spawned off to the side, discarded with the push of a button (e.g. [[kbd:][ESC]] or [[kbd:][C-g]]),
and easily restored if I want to see them again. Of course, this system should
clean up after itself and kill off buffers I mark as transient.

** Maintainers
- [[doom-user:][@hlissner]]

[[doom-contrib-maintainer:][Become a maintainer?]]

** Module flags
- +all ::
  Enable fallback rules to ensure all temporary/special buffers (whose name
  begins with a space or asterix) are treated as popups.
- +defaults ::
  Enable reasonable default popup rules for a variety of buffers.

** Packages
/This module doesn't install any packages./

** Hacks
- [[doom-package:help-mode]] has been advised to follow file links in the buffer you were in
  before entering the popup, rather than in a new window.
- [[doom-package:wgrep]] buffers are advised to close themselves when aborting or committing
  changes.
- [[doom-package:persp-mode]] is advised to restore popup windows when loading a session from
  file.
- Interactive calls to ~windmove-*~ commands (used by ~evil-window-*~ commands)
  will ignore the ~no-other-window~ window parameter, allowing you to switch to
  popup windows as if they're ordinary windows.
- ~balance-windows~ has been advised to close popups while it does its business,
  then restore them afterwards.
- [[doom-package:neotree]] advises ~balance-windows~, which causes major slow-downs when paired
  with our ~balance-window~ advice, so we removes neotree's advice.
- [[doom-package:org-mode]] is an ongoing (and huge) effort. It has a scorched-earth window
  management system I'm not fond of. ie. it kills all windows and monopolizes
  the frame. On top of that, it /really/ likes to use ~switch-to-buffer~ for
  most of its buffer management, which completely bypasses
  ~display-buffer-alist~. Some work has gone into reversing this.

** TODO Changelog
# This section will be machine generated. Don't edit it by hand.
/This module does not have a changelog yet./

* Installation
[[id:01cffea4-3329-45e2-a892-95a384ab2338][Enable this module in your ~doom!~ block.]]

/This module has no external requirements./

* TODO Usage
#+begin_quote
 󱌣 This module has no usage documentation yet. [[doom-contrib-module:][Write some?]]
#+end_quote

* TODO Configuration
#+begin_quote
 󱌣 /This module's configuration documentation is incomplete./ [[doom-contrib-module:][Complete it?]]
#+end_quote

** ~set-popup-rule!~ and ~set-popup-rules!~
This module has two functions for defining your own rules for popups:
#+begin_src emacs-lisp
(set-popup-rule! PREDICATE &key IGNORE ACTIONS SIDE SIZE WIDTH HEIGHT SLOT VSLOT TTL QUIT SELECT MODELINE AUTOSAVE PARAMETERS)
(set-popup-rules! &rest RULESETS)
#+end_src

~PREDICATE~ is a predicate function or regexp string to match against the
buffer's name. You'll find comprehensive documentation on the other keywords in
~set-popup-rule!~'s docstring ([[kbd:][SPC h f set-popup-rule!]]).

#+begin_quote
 󰐃 Popup rules end up in ~display-buffer-alist~, which instructs
    ~display-buffer~ calls on how to set up windows for buffers that meet
    certain conditions. However, some plugins can avoid it entirely if they use
    ~set-buffer~ or ~switch-to-buffer~, which don't obey ~display-buffer-alist~.
#+end_quote

Multiple popup rules can be defined with ~set-popup-rules!~:
#+begin_src emacs-lisp
(set-popup-rules!
 '(("^ \\*" :slot -1) ; fallback rule for special buffers
   ("^\\*" :select t)
   ("^\\*Completions" :slot -1 :ttl 0)
   ("^\\*\\(?:scratch\\|Messages\\)" :ttl t)
   ("^\\*Help" :slot -1 :size 0.2 :select t)
   ("^\\*doom:"
    :size 0.35 :select t :modeline t :quit t :ttl t)))
#+end_src

Omitted parameters in a ~set-popup-rules!~ will use the defaults set in
~+popup-defaults~.

** Disabling hidden mode-line in popups
By default, the mode-line is hidden in popups. To disable this, you can either:

1. Change the default ~:modeline~ property in ~+popup-defaults~:
   #+begin_src emacs-lisp
   ;; in $DOOMDIR/config.el
   (plist-put +popup-defaults :modeline t)
   #+end_src

   A value of ~t~ will instruct popups to use the default mode-line. Any popup
   rule with a ~:modeline~ property can still override this.

2. Completely disable management of the mode-line in popups:
   #+begin_src emacs-lisp
   ;; in $DOOMDIR/config.el
   (remove-hook '+popup-buffer-mode-hook #'+popup-set-modeline-on-enable-h)
   #+end_src

* Troubleshooting
/There are no known problems with this module./ [[doom-report:][Report one?]]

* Frequently asked questions
/This module has no FAQs yet./ [[doom-suggest-faq:][Ask one?]]

* TODO Appendix
#+begin_quote
 󱌣 /This module's appendix is incomplete./ [[doom-contrib-module:][Write more?]]
#+end_quote

** Commands
- ~+popup/other~ (aliased to ~other-popup~, bound to [[kbd:][C-x p]])
- ~+popup/toggle~
- ~+popup/close~
- ~+popup/close-all~
- ~+popup/toggle~
- ~+popup/restore~
- ~+popup/raise~
** Library
- Functions
  - ~+popup-window-p WINDOW~
  - ~+popup-buffer-p BUFFER~
  - ~+popup-buffer BUFFER &optional ALIST~
  - ~+popup-parameter PARAMETER &optional WINDOW~
  - ~+popup-parameter-fn PARAMETER &optional WINDOW~
  - ~+popup-windows~
- Macros
  - ~without-popups!~
  - ~save-popups!~
- Hooks
  - ~+popup-adjust-fringes-h~
  - ~+popup|set-modeline~
  - ~+popup-close-on-escape-h~
  - ~+popup-cleanup-rules-h~
- Minor modes
  - ~+popup-mode~
  - ~+popup-buffer-mode~

```

### ui/popup/config.el

```el

```

### ui/popup/+hacks.el

```el

```

### ui/popup/autoload/popup.el

```el

```

### ui/popup/autoload/settings.el

```el
;;; ui/popup/autoload/settings.el -*- lexical-binding: t; -*-

;;;###autoload
(defvar +popup--display-buffer-alist nil)

;;;###autoload
(defvar +popup-defaults
  (list :side   'bottom
        :height 0.16
        :width  40
        :quit   t
        :select #'ignore
        :ttl    5)
  "Default properties for popup rules defined with `set-popup-rule!'.")

;;;###autoload
(defun +popup-make-rule (predicate plist)
  (if (plist-get plist :ignore)
      (list predicate nil)
    (let* ((plist (append plist +popup-defaults))
           (alist
            `((actions       . ,(plist-get plist :actions))
              (side          . ,(plist-get plist :side))
              (size          . ,(plist-get plist :size))
              (window-width  . ,(plist-get plist :width))
              (window-height . ,(plist-get plist :height))
              (slot          . ,(plist-get plist :slot))
              (vslot         . ,(plist-get plist :vslot))))
           (params
            `((ttl      . ,(plist-get plist :ttl))
              (quit     . ,(plist-get plist :quit))
              (select   . ,(plist-get plist :select))
              (modeline . ,(plist-get plist :modeline))
              (autosave . ,(plist-get plist :autosave))
              ,@(plist-get plist :parameters))))
      `(,predicate (+popup-buffer)
                   ,@alist
                   (window-parameters ,@params)))))

;;;###autodef
(defun set-popup-rule! (predicate &rest plist)
  "Define a popup rule.

These rules affect buffers displayed with `pop-to-buffer' and `display-buffer'
(or their siblings). Buffers displayed with `switch-to-buffer' (and its
variants) will not be affected by these rules (as they are unaffected by
`display-buffer-alist', which powers the popup management system).

PREDICATE accepts anything that the CONDITION argument in `buffer-match-p' takes
(if you're on Emacs 29 or newer). On Emacs 28 or older, it can either be a) a
regexp string (matched against the buffer's name) or b) a function that takes
two arguments (a buffer name and the ACTION argument of `display-buffer') and
returns a boolean.

PLIST can be made up of any of the following properties:

:ignore BOOL
  If BOOL is non-nil, popups matching PREDICATE will not be handled by the popup
  system. Use this for buffers that have their own window management system like
  magit or helm.

:actions ACTIONS
  ACTIONS is a list of functions or an alist containing (FUNCTION . ALIST). See
  `display-buffer''s second argument for more information on its format and what
  it accepts. If omitted, `+popup-default-display-buffer-actions' is used.

:side 'bottom|'top|'left|'right
  Which side of the frame to open the popup on. This is only respected if
  `+popup-display-buffer-stacked-side-window-fn' or `display-buffer-in-side-window'
  is in :actions or `+popup-default-display-buffer-actions'.

:size/:width/:height FLOAT|INT|FN
  Determines the size of the popup. If more than one of these size properties are
  given :size always takes precedence, and is mapped with window-width or
  window-height depending on what :side the popup is opened. Setting a height
  for a popup that opens on the left or right is harmless, but comes into play
  if two popups occupy the same :vslot.

  If a FLOAT (0 < x < 1), the number represents how much of the window will be
    consumed by the popup (a percentage).
  If an INT, the number determines the size in lines (height) or units of
    character width (width).
  If a function, it takes one argument: the popup window, and can do whatever it
    wants with it, typically resize it, like `+popup-shrink-to-fit'.

:slot/:vslot INT
  (This only applies to popups with a :side and only if :actions is blank or
  contains the `+popup-display-buffer-stacked-side-window-fn' action) These control
  how multiple popups are laid out. INT can be any integer, positive and
  negative.

  :slot controls lateral positioning (e.g. the horizontal positioning for
    top/bottom popups, or vertical positioning for left/right popups).
  :vslot controls popup stacking (from the edge of the frame toward the center).

  Let's assume popup A and B are opened with :side 'bottom, in that order.
    If they possess the same :slot and :vslot, popup B will replace popup A.
    If popup B has a higher :slot, it will open to the right of popup A.
    If popup B has a lower :slot, it will open to the left of popup A.
    If popup B has a higher :vslot, it will open above popup A.
    If popup B has a lower :vslot, it will open below popup A.

:ttl INT|BOOL|FN
  Stands for time-to-live. It can be t, an integer, nil or a function. This
  controls how (and if) the popup system will clean up after the popup.

  If any non-zero integer, wait that many seconds before killing the buffer (and
    any associated processes).
  If 0, the buffer is immediately killed.
  If nil, the buffer won't be killed and is left to its own devices.
  If t, resort to the default :ttl in `+popup-defaults'. If none exists, this is
    the same as nil.
  If a function, it takes one argument: the target popup buffer. The popup
    system does nothing else and ignores the function's return value.

:quit FN|BOOL|'other|'current
  Can be t, 'other, 'current, nil, or a function. This determines the behavior
  of the ESC/C-g keys in or outside of popup windows.

  If t, close the popup if ESC/C-g is pressed anywhere.
  If 'other, close this popup if ESC/C-g is pressed outside of any popup. This
    is great for popups you may press ESC/C-g a lot in.
  If 'current, close the current popup if ESC/C-g is pressed from inside of the
    popup. This makes it harder to accidentally close a popup until you really
    want to.
  If nil, pressing ESC/C-g will never close this popup.
  If a function, it takes one argument: the to-be-closed popup window, and is
    run when ESC/C-g is pressed while that popup is open. It must return one of
    the other values to determine the fate of the popup.

:select BOOL|FN
  Can be a boolean or function. The boolean determines whether to focus the
  popup window after it opens (non-nil) or focus the origin window (nil).

  If a function, it takes two arguments: the popup window and originating window
    (where you were before the popup opened). The popup system does nothing else
    and ignores the function's return value.

:modeline BOOL|FN|LIST
  Can be t (show the default modeline), nil (show no modeline), a function that
  returns a modeline format or a valid value for `mode-line-format' to be used
  verbatim. The function takes no arguments and is run in the context of the
  popup buffer.

:autosave BOOL|FN
  This parameter determines what to do with modified buffers when closing popup
  windows. It accepts t, 'ignore, a function or nil.

  If t, no prompts. Just save them automatically (if they're file-visiting
    buffers). Same as 'ignore for non-file-visiting buffers.
  If nil (the default), prompt the user what to do if the buffer is
    file-visiting and modified.
  If 'ignore, no prompts, no saving. Just silently kill it.
  If a function, it is run with one argument: the popup buffer, and must return
    non-nil to save or nil to do nothing (but no prompts).

:parameters ALIST
  An alist of custom window parameters. See `(elisp)Window Parameters'.

If any of these are omitted, defaults derived from `+popup-defaults' will be
used.

\(fn PREDICATE &key IGNORE ACTIONS SIDE SIZE WIDTH HEIGHT SLOT VSLOT TTL QUIT SELECT MODELINE AUTOSAVE PARAMETERS)"
  (declare (indent defun))
  (push (+popup-make-rule predicate plist) +popup--display-buffer-alist)
  ;; TODO: Don't overwrite user entries in `display-buffer-alist'
  (when (bound-and-true-p +popup-mode)
    (setq display-buffer-alist +popup--display-buffer-alist))
  +popup--display-buffer-alist)

;;;###autodef
(defun set-popup-rules! (&rest rulesets)
  "Defines multiple popup rules.

Every entry in RULESETS should be a list of alists where the CAR is the
predicate and CDR is a plist. See `set-popup-rule!' for details on the predicate
and plist.

Example:

  (set-popup-rules!
    '((\"^ \\*\" :slot 1 :vslot -1 :size #'+popup-shrink-to-fit)
      (\"^\\*\"  :slot 1 :vslot -1 :select t))
    '((\"^\\*Completions\" :slot -1 :vslot -2 :ttl 0)
      (\"^\\*Compil\\(?:ation\\|e-Log\\)\" :size 0.3 :ttl 0 :quit t)))"
  (declare (indent 0))
  (dolist (rules rulesets)
    (dolist (rule rules)
      (push (+popup-make-rule (car rule) (cdr rule))
            +popup--display-buffer-alist)))
  (when (bound-and-true-p +popup-mode)
    (setq display-buffer-alist +popup--display-buffer-alist))
  +popup--display-buffer-alist)
```
