This configuration uses STIX Two Math (recommended), Libertinus Math, or
Fira Math with unicode-math for professional scientific typography.
Addresses baseline alignment, transparent backgrounds, and color matching.

```el
(after! org
  ;; Use LuaLaTeX for Org exports
  (setq org-latex-compiler "lualatex")

  ;; ============================================================================
  ;; SCALE ADJUSTMENT
  ;; ============================================================================
  ;; Adjust scale to match your text size. Test between 2.5-3.0
  (setq org-format-latex-options
        (plist-put org-format-latex-options :scale 2.8))

  ;; ============================================================================
  ;; TRANSPARENT BACKGROUND AND COLOR MATCHING
  ;; ============================================================================
  ;; Set transparent background for dark theme compatibility
  (plist-put org-format-latex-options :background "Transparent")
  
  ;; Match doom-tokyo-night theme foreground color
  ;; To find your exact color: M-: (face-foreground 'default)
  (plist-put org-format-latex-options :foreground "#a9b1d6")

  ;; ============================================================================
  ;; CRITICAL: LUALATEX + DVISVGM CONFIGURATION (BEST FOR ALIGNMENT)
  ;; ============================================================================
  ;; unicode-math REQUIRES LuaLaTeX or XeLaTeX, NOT regular LaTeX!
  ;; LuaLaTeX must output DVI format (--output-format=dvi) for dvisvgm to work
  (setq org-preview-latex-default-process 'dvisvgm)
  
  (setq org-preview-latex-process-alist
        '((dvipng
           :programs ("latex" "dvipng")
           :description "dvi > png"
           :message "Install latex and dvipng"
           :image-input-type "dvi"
           :image-output-type "png"
           :image-size-adjust (1.0 . 1.0)
           :latex-compiler ("latex -interaction nonstopmode -output-directory %o %f")
           :image-converter ("dvipng -D %D -T tight -o %O %f"))
          
          (dvisvgm
           :programs ("lualatex" "dvisvgm")
           :description "dvi > svg (LuaLaTeX - RECOMMENDED)"
           :message "Install lualatex and dvisvgm"
           :image-input-type "dvi"
           :image-output-type "svg"
           :image-size-adjust (1.0 . 1.0)
           :latex-compiler ("lualatex --output-format=dvi -interaction nonstopmode -output-directory %o %f")
           :image-converter ("dvisvgm %f -n -b min -c %S -o %O"))
          
          (imagemagick
           :programs ("lualatex" "convert")
           :description "pdf > png (LuaLaTeX fallback)"
           :message "Install lualatex and imagemagick"
           :image-input-type "pdf"
           :image-output-type "png"
           :image-size-adjust (1.0 . 1.0)
           :latex-compiler ("lualatex -interaction nonstopmode -output-directory %o %f")
           :image-converter ("convert -density %D -trim -antialias %f -quality 100 -background transparent %O"))))

  ;; Use latexmk for org-mode PDF export
  (setq org-latex-pdf-process
        '("latexmk -f -pdf -%latex -shell-escape -interaction=nonstopmode -output-directory=%o %f"))

  ;; ============================================================================
  ;; ENHANCED PREAMBLE WITH UNICODE-MATH AND MODERN FONTS
  ;; ============================================================================
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

  ;; ============================================================================
  ;; PACKAGE CONFIGURATION
  ;; ============================================================================
  ;; CRITICAL: Do NOT add amssymb or unicode-math to org-latex-packages-alist
  ;; They are already in org-format-latex-header above
  ;; Adding them here will cause conflicts!
  
  ;; For document exports, add these packages:
  (add-to-list 'org-latex-packages-alist '("" "fontspec" t ("lualatex" "xelatex")))
  (add-to-list 'org-latex-packages-alist '("" "unicode-math" t ("lualatex" "xelatex")))
  (add-to-list 'org-latex-packages-alist '("" "amsmath" t))
  (add-to-list 'org-latex-packages-alist '("" "physics" t))
  (add-to-list 'org-latex-packages-alist '("" "siunitx" t))
  (add-to-list 'org-latex-packages-alist '("authoryear,longnamesfirst" "natbib" t)))

;; ============================================================================
;; ORG-FRAGTOG FOR AUTOMATIC PREVIEW
;; ============================================================================
(use-package! org-fragtog
  :hook (org-mode . org-fragtog-mode)
  :config
  (setq org-fragtog-preview-delay 0.2))

;; ============================================================================
;; TROUBLESHOOTING GUIDE
;; ============================================================================
;; 1. CLEAR OLD PREVIEWS:
;;    Delete ~/.emacs.d/.local/cache/org-preview-ltximg/ folder
;;    Or run: M-x org-clear-latex-preview in your buffer
;;
;; 2. VERIFY REQUIRED SYSTEM DEPENDENCIES:
;;    - LuaLaTeX: brew install --cask mactex  (macOS) or install texlive (Linux)
;;    - dvisvgm: Usually included with texlive/mactex
;;    - Check: which lualatex && which dvisvgm
;;
;; 3. TEST SCALE VALUES:
;;    Adjust between 2.5-3.0 for best visual match:
;;    (plist-put org-format-latex-options :scale 2.8)
;;
;; 4. VERIFY YOUR THEME'S EXACT FOREGROUND COLOR:
;;    Run: M-: (face-foreground 'default)
;;    Then update both :foreground and \\definecolor{fgcolor} lines
;;
;; 5. CHOOSE YOUR MATH FONT:
;;    In org-format-latex-header, uncomment ONLY ONE \setmathfont line:
;;    - STIX Two Math (recommended - comprehensive, professional)
;;    - Libertinus Math (elegant, pairs well with serif text)
;;    - Fira Math (clean, modern, good for presentations)
;;
;; 6. INSTALL REQUIRED FONTS:
;;    All three fonts should be installed with texlive/mactex
;;    Verify: luaotfload-tool --list=stix2math
;;            luaotfload-tool --list=libertinus
;;            luaotfload-tool --list=fira
;;
;; 7. TEST WITH SIMPLE MATH:
;;    Type: $x^2 + \alpha = \sqrt{2}$
;;    Run: C-c C-x C-l
;;    Preview should align perfectly with text baseline
;;
;; 8. COMMON ISSUES AND SOLUTIONS:
;;    
;;    Problem: "dvisvgm: No SVG output generated"
;;    Solution: Ensure LuaLaTeX uses --output-format=dvi
;;    
;;    Problem: "unicode-math package not found"
;;    Solution: Update your LaTeX distribution (tlmgr update --all)
;;    
;;    Problem: Preview too large/small
;;    Solution: Adjust :scale value incrementally
;;    
;;    Problem: White background in preview
;;    Solution: Ensure :background "Transparent" is set
;;    
;;    Problem: Preview not aligned with text
;;    Solution: Use dvisvgm (SVG), not dvipng (PNG)
;;    
;;    Problem: Math font doesn't match text
;;    Solution: This is expected - math fonts are traditionally serif
;;              STIX Two Math is the most professional choice
;;
;; 9. DEBUGGING PREVIEW GENERATION:
;;    Check the LaTeX compilation in temporary files:
;;    - Look in /tmp/orgtex* for .tex, .dvi, .svg files
;;    - Compile manually: lualatex --output-format=dvi test.tex
;;    - Convert manually: dvisvgm test.dvi -n -b min -o test.svg
;;
;; 10. VERIFYING CONFIGURATION:
;;     Run: M-: org-preview-latex-default-process  (should show: dvisvgm)
;;     Run: M-: org-latex-compiler                 (should show: "lualatex")
;;     Run: M-: (plist-get org-format-latex-options :scale)  (should show: 2.8)

;; ============================================================================
;; WHY THESE SPECIFIC CHANGES
;; ============================================================================
;; 1. UNICODE-MATH REQUIREMENT: The physics package and modern math fonts
;;    require unicode-math, which ONLY works with LuaLaTeX or XeLaTeX.
;;    Regular LaTeX cannot use these fonts.
;;
;; 2. LUALATEX --OUTPUT-FORMAT=DVI: dvisvgm requires DVI input, not PDF.
;;    LuaLaTeX by default outputs PDF, so we must specify DVI format.
;;
;; 3. STIX TWO MATH FONT: Designed specifically for scientific/technical
;;    publishing with comprehensive Unicode math coverage (2400+ symbols).
;;    Created by consortium of major publishers (AMS, APS, AIP, IEEE, Elsevier).
;;
;; 4. TRANSPARENT BACKGROUND: Ensures previews blend with your dark theme
;;    instead of showing white boxes around math.
;;
;; 5. COLOR MATCHING: \\color{fgcolor} ensures math symbols match your
;;    theme's text color for visual consistency.
;;
;; 6. DVISVGM FOR ALIGNMENT: SVG format preserves baseline information
;;    better than PNG, resulting in perfect vertical alignment with text.
;;
;; 7. NO AMSSYMB WITH UNICODE-MATH: unicode-math already provides all
;;    AMS symbols natively, adding amssymb causes package conflicts.
```
