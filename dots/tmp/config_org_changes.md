# config.org Changes

## Change 1 — Fill the empty `** Python` section

The `** Python` heading (line 7056, inside `* Languages`) is currently empty.
Replace it with the full block below.  `* Study` must immediately follow the
closing `#+end_src`.

```org
** Python
#+begin_src emacs-lisp
;; ─────────────────────────────────────────────────────────────────────────────
;; Python Programming Configuration
;;
;; Tool roles — strict division, no overlap:
;;
;;   basedpyright (LSP via eglot)
;;     • Type inference, narrowing, generics, overloads        ← exclusive
;;     • Completions with auto-import suggestions              ← exclusive
;;     • Hover / signature help                                ← exclusive
;;     • Go-to-definition / find-references                   ← exclusive
;;     • Inlay hints (return types, parameter names)          ← exclusive
;;     • Code actions (type-based fixes)                      ← exclusive
;;     • Import organiser disabled — ruff-isort owns this
;;
;;   ruff (CLI via flymake-ruff + apheleia)
;;     • Style / lint diagnostics: E/W/F/B/UP/SIM/…           ← exclusive
;;     • Import sorting (ruff-isort, isort-compatible)        ← exclusive
;;     • Code formatting (ruff format, replaces black)        ← exclusive
;;
;;   The two tools are complementary.  The only overlap is import organisation,
;;   which is resolved by disabling basedpyright's organizeImports (see below).
;;
;; Required tools on PATH — provided by pixi.toml:
;;   basedpyright-langserver   (conda-forge: basedpyright ≥ 1.14)
;;   ruff                      (conda-forge: ruff ≥ 0.4)
;;
;; python-mode is already remapped to python-ts-mode via major-mode-remap-alist
;; in ** Treesit, so both modes are listed in eglot-server-programs only as a
;; belt-and-suspenders fallback.
;; ─────────────────────────────────────────────────────────────────────────────

;; 1. Register basedpyright as the eglot server for all Python modes.
;;    The prog-mode hook in ** LSP already calls eglot-ensure for every
;;    prog-mode derivative not in the exclusion list, so no extra hook is needed.
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '((python-ts-mode python-mode) "basedpyright-langserver" "--stdio")))

;; 2. basedpyright workspace configuration.
;;
;;    WHY setq-default: the official eglot manual documents setq-default as the
;;    correct mechanism for user-specific (global) server settings. Setting this
;;    in a major-mode hook via setq-local is explicitly warned against by the
;;    eglot manual ("It usually does not make sense to set it file-locally or in
;;    a major-mode hook") because eglot-workspace-configuration is project-wide,
;;    not per-buffer. setq-default is safe because each server reads only the
;;    keys it recognises and silently ignores the rest.
;;
;;    WHY dotted-key format (:basedpyright.analysis as a top-level key):
;;    This is the format shown in both the official basedpyright eglot docs and
;;    the eglot manual itself.  The nested form (:basedpyright (:analysis (…)))
;;    sends the wrong JSON structure and does not work.
;;
;;    Key-by-key rationale:
;;
;;    :basedpyright :typeCheckingMode "standard"
;;      Comprehensive checks without the extreme noise of "strict" / "recommended".
;;      Good signal-to-noise ratio for everyday development.
;;
;;    :basedpyright :disableOrganizeImports t
;;      Prevents basedpyright's import organiser from running, because apheleia
;;      runs ruff-isort on every save.  ruff-isort is isort-compatible, faster,
;;      and covers more rules.  Letting both run would cause import order fights.
;;
;;    :basedpyright.analysis :autoImportCompletions t
;;      Suggests missing imports as completion candidates.  This is one of
;;      basedpyright's biggest advantages over ruff; keep it on.
;;
;;    :basedpyright.analysis :autoSearchPaths t
;;      Adds src/ and similar directories to the search path automatically when
;;      no pyrightconfig.json execution environment is present.
;;
;;    :basedpyright.analysis :diagnosticMode "workspace"
;;      Default is "openFilesOnly", which misses errors in files not currently
;;      open.  "workspace" analyses the entire project, giving a fuller picture.
;;
;;    :basedpyright.analysis :useLibraryCodeForTypes t
;;      Falls back to reading library source when type stubs are absent.
;;      Required for many third-party packages that ship no .pyi stubs.
(setq-default eglot-workspace-configuration
              '(:basedpyright
                ( :typeCheckingMode      "standard"
                  :disableOrganizeImports t)
                :basedpyright.analysis
                ( :autoImportCompletions  t
                  :autoSearchPaths        t
                  :diagnosticMode         "workspace"
                  :useLibraryCodeForTypes t)))

;; 3. flymake-ruff — second flymake backend alongside basedpyright.
;;    Diagnostics are complementary: basedpyright → type errors;
;;    ruff → style (E/W), unused imports (F401), pyupgrade (UP), bugbear (B),
;;    simplify (SIM), and the many other rules it consolidates.
;;
;;    WHY eglot-managed-mode-hook:
;;      eglot resets flymake-diagnostic-functions when it connects, silently
;;      discarding any backend added earlier (e.g. via python-ts-mode-hook).
;;      Hooking here runs AFTER eglot's reset, so the backend survives.
;;
;;    WHY no lambda / derived-mode-p guard:
;;      flymake-ruff-load already contains an internal guard and is a no-op
;;      outside Python buffers.  The official README shows the bare form; the
;;      extra wrapping seen in blog posts is unnecessary boilerplate.
;;
;;    flymake-ruff is on MELPA.  With straight-use-package-by-default t, the
;;    plain use-package form installs it without a custom :straight recipe.
(use-package flymake-ruff
  :defer t
  :init
  (add-hook 'eglot-managed-mode-hook #'flymake-ruff-load))

;; 4. python built-in — minimal settings only.
;;    • No remap:    already in ** Treesit (major-mode-remap-alist).
;;    • No eglot hook: already in ** LSP (prog-mode lambda).
(use-package python
  :straight (:type built-in)
  :defer t
  :custom
  (python-shell-completion-native-enable nil) ; prevent interference with corfu/eglot
  (python-shell-interpreter "python3")
  (python-indent-offset 4))

;; 5. Apheleia — ruff as the Python formatter, shfmt as the bash formatter.
;;
;;    Python:
;;      ruff-isort → ruff check --select I --fix --fix-only   (import sorting)
;;      ruff       → ruff format                               (code formatting)
;;    Both formatter definitions are built into apheleia; no custom definition
;;    needed.  We only update the mode-alist to override the default (black).
;;    Both entries are kept: python-ts-mode is the active mode post-remap;
;;    python-mode is a belt-and-suspenders fallback (e.g. org-src blocks).
;;
;;    Bash:
;;      shfmt is defined in apheleia-formatters but was deliberately removed
;;      from the default mode-alist to prevent corruption of zsh scripts
;;      (apheleia CHANGELOG).  It is safe to add it back for bash-ts-mode
;;      specifically, because bash-ts-mode is only ever activated for bash
;;      files (via the treesit remap for sh-mode/bash-mode → bash-ts-mode).
(with-eval-after-load 'apheleia
  ;; Python
  (setf (alist-get 'python-ts-mode apheleia-mode-alist) '(ruff-isort ruff))
  (setf (alist-get 'python-mode    apheleia-mode-alist) '(ruff-isort ruff))
  ;; Bash — shfmt respects sh-basic-offset for indentation width automatically
  (setf (alist-get 'bash-ts-mode   apheleia-mode-alist) '(shfmt)))
#+end_src
```

---

## Change 2 — `eglot-ignored-server-capabilities` (** LSP, line ~4369)

**No change needed.**  All five ignored capabilities are correct.  Reference table:

| Capability | Decision | Rationale |
|---|---|---|
| `:documentFormattingProvider` | ✅ Ignore | Apheleia owns formatting globally. basedpyright never advertises this (pyright team permanently rejected it). Acts as a useful global guard against other servers fighting apheleia. |
| `:documentRangeFormattingProvider` | ✅ Ignore | basedpyright doesn't advertise this. `ruff server` does, but we do not use `ruff server` as an LSP server — only as a CLI tool. Apheleia formats the whole buffer on save, so LSP range-formatting is unused in this setup. |
| `:documentOnTypeFormattingProvider` | ✅ Ignore | Neither basedpyright nor ruff server advertise on-type formatting. Ruff's formatting mode is on-save, not on-type. Ignoring prevents any future server from causing disruptive mid-keystroke reformatting. |
| `:foldingRangeProvider` | ✅ Ignore | treesit-fold with full indicator support is more capable and language-aware than LSP folding. |
| `:documentHighlightProvider` | ✅ Ignore | Tree-sitter provides superior, syntax-level symbol highlighting. |

---

## Complete list of corrections vs. the previous version

| Correction | Explanation |
|---|---|
| `setq-default` instead of `setq-local` in a mode hook | The official eglot manual explicitly warns against setting `eglot-workspace-configuration` in a mode hook. `setq-default` is the documented user-specific config mechanism. Each server ignores keys it doesn't recognise, so global placement is safe. |
| `:basedpyright.analysis :diagnosticMode "workspace"` added | The default `"openFilesOnly"` means basedpyright only analyses open files, missing errors in the rest of the project. |
| `flymake-ruff` `:straight` recipe simplified | flymake-ruff is on MELPA. With `straight-use-package-by-default t`, the plain `use-package` form is sufficient — no `:straight (:host github …)` needed. |
| `shfmt` for `bash-ts-mode` added to apheleia | shfmt was deliberately removed from apheleia's default mode-alist. Explicitly re-enabling it only for bash-ts-mode is safe and completes the bash formatting story. |

---

## Nothing else changes

- `** Bash` (line 6784) — untouched as requested
- `** LSP` eglot setup — untouched (ignored capabilities confirmed correct)
- `** Syntax Checking` flymake setup — untouched
- `** Formatting` apheleia setup — untouched (the `eglot` bridge for markdown remains intact; the Python/bash additions are append-only via `setf alist-get`)
