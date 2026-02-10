```elisp
(after! org
  ;; Use LuaLaTeX for Org exports
  (setq org-latex-compiler "lualatex")

  ;; Set scale to match 13pt JetBrains Mono
  (setq org-format-latex-options
        (plist-put org-format-latex-options :scale 2.9))

  ;; Use latexmk for org-mode PDF export
  (setq org-latex-pdf-process
        '("latexmk -f -pdf -%latex -shell-escape -interaction=nonstopmode -output-directory=%o %f"))

  ;; Create custom LuaLaTeX + ImageMagick process for previews
  (setq luamagick
        '(luamagick
          :programs ("lualatex" "magick")
          :description "pdf > png"
          :message "you need to install lualatex and imagemagick."
          :use-xcolor t
          :image-input-type "pdf"
          :image-output-type "png"
          :image-size-adjust (1.0 . 1.0)
          :latex-compiler ("lualatex -interaction nonstopmode -output-directory %o %f")
          :image-converter ("magick -density %D %f -trim -antialias -quality 100 %O")))
  
  ;; Add to the process list and set as default
  (add-to-list 'org-preview-latex-process-alist luamagick)
  (setq org-preview-latex-default-process 'luamagick)
  
  ;; Configure transparent background with Catppuccin Mocha colors
  (plist-put org-format-latex-options :background "Transparent")
  (plist-put org-format-latex-options :foreground "#cdd6f4")  ; Catppuccin Mocha text

  ;; Add packages needed for LaTeX preview
  (add-to-list 'org-latex-packages-alist '("" "amsmath" t))
  (add-to-list 'org-latex-packages-alist '("" "physics" t))
  (add-to-list 'org-latex-packages-alist '("authoryear,longnamesfirst" "natbib" t))

  ;; Simplified preview preamble with modern math font
  ;; IMPORTANT: No geometry package - causes full page layouts
  (setq org-latex-preview-preamble
        (concat
         "\\documentclass{article}\n"
         "\\usepackage{amsmath}\n"
         "\\usepackage{physics}\n"
         "\\usepackage{siunitx}\n"
         "\\usepackage{xcolor}\n"
         "\\definecolor{fgcolor}{HTML}{cdd6f4}\n"  ; Catppuccin Mocha text
         "\\color{fgcolor}\n"
         "\\usepackage{unicode-math}\n"
         "\\setmathfont{STIX Two Math}\n"  ; Modern math font - or use Libertinus Math, Fira Math
         "[PACKAGES]\n"
         "[DEFAULT-PACKAGES]\n"))

  ;; Clear cache if you've had preview errors before
  (setq org-latex-preview-cache 'temp))

;; Org-fragtog for automatic LaTeX fragment preview
(use-package! org-fragtog
  :hook (org-mode . org-fragtog-mode)
  :config
  (setq org-fragtog-preview-delay 0.1))
```
