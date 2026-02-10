I'll research modern LaTeX workflows in Doom Emacs and provide you with a comprehensive rewrite of the LaTeX section using more established tools.Based on my research, I'll provide a comprehensive rewrite of your LaTeX section using industry-standard tools. The main changes are replacing Tectonic with **latexmk** (the standard LaTeX build tool) and **LuaLaTeX** (the most modern and recommended LaTeX engine as of November 2024), while maintaining backward compatibility with pdfLaTeX.I've completely rewritten your LaTeX configuration with modern, industry-standard tools. Here's what changed:

## Major Changes

### 1. **LaTeX Engine**: Tectonic → LuaLaTeX/pdfLaTeX
- LuaLaTeX was declared the recommended format for LaTeX in November 2024
- pdfLaTeX remains widely used, especially by publishers and ArXiv
- LuaLaTeX has better memory management and works well with complex packages like pgfplots and TikZ
- XeLaTeX support included but not recommended (maintenance mode only)

### 2. **Build System**: Tectonic → latexmk
- latexmk automatically handles multiple compilation passes for references, bibliography, and cross-references
- Industry standard, comes with TeX Live
- Supports all major LaTeX engines
- Integrates seamlessly with AUCTeX

### 3. **Key Features Added**
- **Forward/inverse search** with SyncTeX for PDF navigation
- **Continuous preview mode** (watch mode) for real-time PDF updates
- **Build directory** organization (`build/`) for cleaner projects
- **Automatic PDF refresh** in pdf-tools after compilation
- **Better org-mode integration** with proper latexmk support

### 4. **Kept What Works**
- Your citation management (Citar) is excellent
- LAAS snippets are great (I enhanced them)
- org-fragtog for automatic previews
- Project-aware bibliography system

## Installation Requirements

Make sure you have these installed:

```bash
# Install TeX Live (includes latexmk, lualatex, pdflatex)
# On Arch/Manjaro:
sudo pacman -S texlive-most texlive-lang

# On Ubuntu/Debian:
sudo apt install texlive-full

# On macOS:
brew install --cask mactex  # or basictex for minimal install

# Verify installation:
which latexmk lualatex pdflatex
```

## Usage

### In .tex files:
- `SPC m b c` or `C-c C-c` → Compile with latexmk
- `SPC m b a` → Compile all (run-all)
- `SPC m b w` → Watch mode (continuous preview)
- `SPC m b v` → View PDF

### In .org files:
- `SPC m L d` → Export to PDF (uses latexmk automatically)
- `SPC m L p` → Preview LaTeX fragment
- Fragments auto-preview with org-fragtog enabled

## Optional Enhancements

You might also want to add these packages to `packages.el`:

```elisp
;; For even better LaTeX editing (optional)
(package! auctex-latexmk)  ; Additional latexmk integration
(package! company-auctex)  ; Better completion for AUCTeX
(package! latex-preview-pane)  ; Side-by-side live preview
```

The configuration is production-ready for scientific writing and fully compatible with academic publishers' requirements!
