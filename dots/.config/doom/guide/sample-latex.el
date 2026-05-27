(after! org
  ;; Use LuaLaTeX for Org exports
  (setq org-latex-compiler "lualatex")

  ;; Calculate proper scale to match 13pt JetBrains Mono
  ;; Lower scale value since we're using image-size-adjust
  (setq org-format-latex-options
        (plist-put org-format-latex-options :scale 1.2))

  ;; Use latexmk for org-mode PDF export
  (setq org-latex-pdf-process
        '("latexmk -f -pdf -%latex -shell-escape -interaction=nonstopmode -output-directory=%o %f"))

  ;; Add LuaLaTeX preview process with corrected size settings
  (add-to-list 'org-preview-latex-process-alist
               '(lualatex
                 :programs ("lualatex" "magick")
                 :description "pdf > png (lualatex)"
                 :message "you need to install lualatex and imagemagick"
                 :image-input-type "pdf"
                 :image-output-type "png"
                 :image-size-adjust (1.0 . 1.0)  ; Reset to 1.0 to avoid over-scaling
                 :latex-compiler
                 ("lualatex -interaction nonstopmode -output-directory %o %f")
                 :image-converter
                 ("magick -density %D %f -trim -antialias -quality 100 %O")))

  ;; Use LuaLaTeX for previews
  (setq org-preview-latex-default-process 'lualatex)

  ;; Add packages needed for LaTeX preview
  (add-to-list 'org-latex-packages-alist '("" "amsmath" t))
  (add-to-list 'org-latex-packages-alist '("" "physics" t))
  (add-to-list 'org-latex-packages-alist '("authoryear,longnamesfirst" "natbib" t))

  ;; Ensure preview uses the same packages as export
  (setq org-latex-preview-preamble (concat
                                    "\\documentclass{article}\n"
                                    "\\usepackage{amsmath}\n"
                                    "\\usepackage{geometry}\n"
                                    "\\usepackage{physics}\n"
                                    "\\usepackage{siunitx}\n"
                                    "[PACKAGES]\n"
                                    "[DEFAULT-PACKAGES]\n"))

  ;; Clear cache if you've had preview errors before
  (setq org-latex-preview-cache 'temp))

;; Org-fragtog for automatic LaTeX fragment preview
(use-package! org-fragtog
  :hook (org-mode . org-fragtog-mode)
  :config
  (setq org-fragtog-preview-delay 0.1))
