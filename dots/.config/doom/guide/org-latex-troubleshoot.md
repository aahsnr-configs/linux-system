============================================================================
# TROUBLESHOOTING GUIDE
============================================================================
1. CLEAR OLD PREVIEWS:
   Delete ~/.emacs.d/.local/cache/org-preview-ltximg/ folder
   Or run: M-x org-clear-latex-preview in your buffer

2. VERIFY REQUIRED SYSTEM DEPENDENCIES:
   - LuaLaTeX: brew install --cask mactex  (macOS) or install texlive (Linux)
   - dvisvgm: Usually included with texlive/mactex
   - Check: which lualatex && which dvisvgm

3. TEST SCALE VALUES:
   Adjust between 2.5-3.0 for best visual match:
   (plist-put org-format-latex-options :scale 2.8)

4. VERIFY YOUR THEME'S EXACT FOREGROUND COLOR:
   Run: M-: (face-foreground 'default)
   Then update both :foreground and \\definecolor{fgcolor} lines

5. CHOOSE YOUR MATH FONT:
   In org-format-latex-header, uncomment ONLY ONE \setmathfont line:
   - STIX Two Math (recommended - comprehensive, professional)
   - Libertinus Math (elegant, pairs well with serif text)
   - Fira Math (clean, modern, good for presentations)

6. INSTALL REQUIRED FONTS:
   All three fonts should be installed with texlive/mactex
   Verify: luaotfload-tool --list=stix2math
           luaotfload-tool --list=libertinus
           luaotfload-tool --list=fira

7. TEST WITH SIMPLE MATH:
   Type: $x^2 + \alpha = \sqrt{2}$
   Run: C-c C-x C-l
   Preview should align perfectly with text baseline

8. COMMON ISSUES AND SOLUTIONS:
   
   Problem: "dvisvgm: No SVG output generated"
   Solution: Ensure LuaLaTeX uses --output-format=dvi (already configured)
             Our custom 'lualatex-svg process handles this correctly
   
   Problem: "unicode-math package not found"
   Solution: Update your LaTeX distribution (tlmgr update --all)
   
   Problem: Preview too large/small
   Solution: Adjust :scale value incrementally
   
   Problem: White background in preview
   Solution: Ensure :background "Transparent" is set
   
   Problem: Preview not aligned with text
   Solution: Use 'lualatex-svg (SVG), not dvipng (PNG)
             SVG format preserves baseline information better
   
   Problem: Math font doesn't match text
   Solution: This is expected - math fonts are traditionally serif
             STIX Two Math is the most professional choice

9. DEBUGGING PREVIEW GENERATION:
   Check the LaTeX compilation in temporary files:
   - Look in /tmp/orgtex* for .tex, .dvi, .svg files
   - Compile manually: lualatex --output-format=dvi test.tex
   - Convert manually: dvisvgm test.dvi -n -b min -o test.svg

10. VERIFYING CONFIGURATION:
    Run: M-: org-preview-latex-default-process  (should show: lualatex-svg)
    Run: M-: org-latex-compiler                 (should show: "lualatex")
    Run: M-: (plist-get org-format-latex-options :scale)  (should show: 2.8)

============================================================================
WHY THESE SPECIFIC CHANGES
============================================================================
1. UNICODE-MATH REQUIREMENT: The physics package and modern math fonts
   require unicode-math, which ONLY works with LuaLaTeX or XeLaTeX.
   Regular LaTeX cannot use these fonts.

2. LUALATEX --OUTPUT-FORMAT=DVI: dvisvgm requires DVI input, not PDF.
   LuaLaTeX by default outputs PDF, so we must specify DVI format.

3. STIX TWO MATH FONT: Designed specifically for scientific/technical
   publishing with comprehensive Unicode math coverage (2400+ symbols).
   Created by consortium of major publishers (AMS, APS, AIP, IEEE, Elsevier).

4. TRANSPARENT BACKGROUND: Ensures previews blend with your dark theme
   instead of showing white boxes around math.

5. COLOR MATCHING: \\color{fgcolor} ensures math symbols match your
   theme's text color for visual consistency.

6. DVISVGM FOR ALIGNMENT: SVG format preserves baseline information
   better than PNG, resulting in perfect vertical alignment with text.
   Our custom 'lualatex-svg process uses dvisvgm for this purpose.

7. NO AMSSYMB WITH UNICODE-MATH: unicode-math already provides all
   AMS symbols natively, adding amssymb causes package conflicts.
