```el
(after! org
  ;; Use LuaLaTeX for Org exports
  (setq org-latex-compiler "lualatex")

  (setq org-format-latex-options
        (plist-put org-format-latex-options :scale 2.8))

  ;; Set transparent background for dark theme compatibility
  (plist-put org-format-latex-options :background "Transparent")
  (plist-put org-format-latex-options :foreground "#a9b1d6")

  ;; Use latexmk for org-mode PDF export
  (setq org-latex-pdf-process
        '("latexmk -f -pdf -%latex -shell-escape -interaction=nonstopmode -output-directory=%o %f"))

  (add-to-list 'org-preview-latex-process-alist
               '(lualatex-svg
                 :programs ("lualatex" "dvisvgm")
                 :description "pdf > svg (LuaLaTeX - RECOMMENDED)"
                 :message "Install lualatex, dvisvgm, and ghostscript"
                 :image-input-type "pdf"
                 :image-output-type "svg"
                 :image-size-adjust (1.0 . 1.0)
                 :latex-compiler ("lualatex -interaction nonstopmode -output-directory %o %f")
                 :image-converter ("dvisvgm --pdf %f -n -b min -c %S -o %O")))
  
  (add-to-list 'org-preview-latex-process-alist
               '(lualatex-png
                 :programs ("lualatex" "convert")
                 :description "pdf > png (LuaLaTeX fallback)"
                 :message "Install lualatex and imagemagick"
                 :image-input-type "pdf"
                 :image-output-type "png"
                 :image-size-adjust (1.0 . 1.0)
                 :latex-compiler ("lualatex -interaction nonstopmode -output-directory %o %f")
                 :image-converter ("convert -density %D -background transparent %f -trim -quality 100 %O")))
  
  ;; Set the custom LuaLaTeX+SVG process as default
  (setq org-preview-latex-default-process 'lualatex-svg)

  (setq org-format-latex-header
        "\\documentclass{article}
\\usepackage[usenames]{color}
[PACKAGES]
[DEFAULT-PACKAGES]
\\pagestyle{empty}             % do not remove
% The settings below are copied from fullpage.sty
\\setlength{\\textwidth}{\\paperwidth}
\\addtolength{\\textwidth}{-3cm}
\\setlength{\\oddsidemargin}{1.5cm}
\\addtolength{\\oddsidemargin}{-2.54cm}
\\setlength{\\evensidemargin}{\\oddsidemargin}
\\setlength{\\textheight}{\\paperheight}
\\addtolength{\\textheight}{-\\headheight}
\\addtolength{\\textheight}{-\\headsep}
\\addtolength{\\textheight}{-\\footskip}
\\addtolength{\\textheight}{-3cm}
\\setlength{\\topmargin}{1.5cm}
\\addtolength{\\topmargin}{-2.54cm}
% Modern font configuration with unicode-math
\\usepackage{fontspec}
\\usepackage{unicode-math}
\\usepackage{amsmath}
\\usepackage{physics}
\\usepackage{siunitx}
\\usepackage{xcolor}
% Match doom-tokyo-night theme colors
\\definecolor{fgcolor}{HTML}{a9b1d6}
\\color{fgcolor}
% Set modern math font (choose ONE of the following):
\\setmathfont{STIX Two Math}      % RECOMMENDED: Professional, comprehensive
% \\setmathfont{Libertinus Math}  % Alternative: Elegant, Times-like
% \\setmathfont{Fira Math}        % Alternative: Clean, modern")

 
  (add-to-list 'org-latex-packages-alist '("" "fontspec" nil ("lualatex" "xelatex")))
  (add-to-list 'org-latex-packages-alist '("" "unicode-math" nil ("lualatex" "xelatex")))
  (add-to-list 'org-latex-packages-alist '("" "amsmath" t))
  (add-to-list 'org-latex-packages-alist '("" "physics" t))
  (add-to-list 'org-latex-packages-alist '("" "siunitx" t))
  (add-to-list 'org-latex-packages-alist '("authoryear,longnamesfirst" "natbib" t)))

;; ============================================================================
;; ORG-FRAGTOG FOR AUTOMATIC PREVIEW
;; ============================================================================
(use-package! org-fragtog
  :hook (org-mode . org-fragtog-mode))
```
