# Org-Mode Scientific Document Templates with Modern Math Fonts

## Setup File System for Reusable Templates

Create these template files in `~/org/templates/` to avoid rewriting LaTeX headers for every document.

### Directory Structure
```
~/org/
├── templates/
│   ├── scientific-base.org       # Base configuration with STIX Two Math
│   ├── physics-twocol.org        # Two-column physics papers
│   ├── article-single.org        # Single-column articles
│   ├── presentation.org          # Beamer presentations
│   ├── notes.org                 # Quick notes/homework
│   └── thesis.org                # Thesis/dissertation
└── references/
    └── references.bib            # Your bibliography
```

---

## Template Files

### 1. Base Scientific Template (`~/org/templates/scientific-base.org`)

**Foundation for all scientific documents with modern Unicode math fonts.**

```org
# -*- mode: org; -*-
#+STARTUP: latexpreview

# === LATEX ENGINE (REQUIRED FOR UNICODE-MATH) ===
#+LATEX_COMPILER: lualatex
#+LATEX_CLASS: article
#+LATEX_CLASS_OPTIONS: [11pt,a4paper]

# === MODERN FONT SYSTEM ===
#+LATEX_HEADER: \usepackage{fontspec}
#+LATEX_HEADER: \usepackage{unicode-math}

# === MATH FONT SELECTION (choose ONE - STIX Two Math recommended) ===
#+LATEX_HEADER: \setmathfont{STIX Two Math}
# Alternative math fonts (uncomment to use):
# #+LATEX_HEADER: \setmathfont{Libertinus Math}
# #+LATEX_HEADER: \setmathfont{Fira Math}

# === TEXT FONT (optional - matches math font) ===
# #+LATEX_HEADER: \setmainfont{STIX Two Text}      # Pairs with STIX Two Math
# #+LATEX_HEADER: \setmainfont{Libertinus Serif}   # Pairs with Libertinus Math
# #+LATEX_HEADER: \setmainfont{Fira Sans}          # Pairs with Fira Math

# === CORE MATH PACKAGES ===
#+LATEX_HEADER: \usepackage{amsmath}
#+LATEX_HEADER: \usepackage{mathtools}
#+LATEX_HEADER: \usepackage{physics}
#+LATEX_HEADER: \usepackage{siunitx}

# === GRAPHICS ===
#+LATEX_HEADER: \usepackage{graphicx}
#+LATEX_HEADER: \usepackage{float}

# === REFERENCES AND LINKS ===
#+LATEX_HEADER: \usepackage{hyperref}
#+LATEX_HEADER: \hypersetup{colorlinks=true,linkcolor=blue,citecolor=blue,urlcolor=blue}
#+LATEX_HEADER: \usepackage{cleveref}

# === BIBLIOGRAPHY (biblatex with biber backend) ===
#+LATEX_HEADER: \usepackage[backend=biber,style=authoryear,natbib=true]{biblatex}
#+LATEX_HEADER: \addbibresource{~/org/references/references.bib}

# === FORMATTING ===
#+LATEX_HEADER: \setlength{\parskip}{0.5em}
#+LATEX_HEADER: \setlength{\parindent}{0pt}

# === ORG OPTIONS ===
#+OPTIONS: toc:nil num:t
#+OPTIONS: ^:{}  # Disable automatic sub/superscripts (use _{} and ^{} explicitly)
#+OPTIONS: author:t date:t title:t
```

---

### 2. Two-Column Physics Template (`~/org/templates/physics-twocol.org`)

**For journal submissions and physics papers with professional typography.**

```org
# -*- mode: org; -*-
#+SETUPFILE: ~/org/templates/scientific-base.org

# === OVERRIDE CLASS OPTIONS FOR TWO-COLUMN ===
#+LATEX_CLASS_OPTIONS: [twocolumn,11pt,a4paper]

# === TWO-COLUMN GEOMETRY ===
#+LATEX_HEADER: \usepackage[margin=1in]{geometry}
#+LATEX_HEADER: \setlength{\columnsep}{1.5em}

# === PHYSICS-SPECIFIC PACKAGES ===
#+LATEX_HEADER: \usepackage{braket}
#+LATEX_HEADER: \usepackage{tensor}
# For Feynman diagrams (requires additional setup):
# #+LATEX_HEADER: \usepackage{feynmf}

# === THEOREM ENVIRONMENTS ===
#+LATEX_HEADER: \newtheorem{theorem}{Theorem}[section]
#+LATEX_HEADER: \newtheorem{lemma}[theorem]{Lemma}
#+LATEX_HEADER: \newtheorem{proposition}[theorem]{Proposition}
#+LATEX_HEADER: \newtheorem{corollary}[theorem]{Corollary}
#+LATEX_HEADER: \theoremstyle{definition}
#+LATEX_HEADER: \newtheorem{definition}[theorem]{Definition}
#+LATEX_HEADER: \theoremstyle{remark}
#+LATEX_HEADER: \newtheorem{remark}{Remark}
#+LATEX_HEADER: \newtheorem{example}{Example}

# === DOCUMENT METADATA ===
#+TITLE: Quantum Dynamics in Coupled Systems
#+AUTHOR: Ahsanur Rahman
#+DATE: \today
#+EMAIL: ahsanur041@proton.me

# === ABSTRACT ===
#+BEGIN_abstract
This article investigates the dynamics of quantum systems with environmental coupling. 
We derive master equations and analyze steady-state solutions using modern computational methods.
#+END_abstract

#+KEYWORDS: quantum mechanics, open quantum systems, master equation
```

---

### 3. Single-Column Article Template (`~/org/templates/article-single.org`)

**For reports, essays, and standard academic documents.**

```org
# -*- mode: org; -*-
#+SETUPFILE: ~/org/templates/scientific-base.org

# === SINGLE-COLUMN GEOMETRY ===
#+LATEX_HEADER: \usepackage[margin=1in]{geometry}
#+LATEX_HEADER: \linespread{1.5}  # 1.5 line spacing

# === ENHANCED SECTION FORMATTING ===
#+LATEX_HEADER: \usepackage{titlesec}
#+LATEX_HEADER: \titleformat{\section}{\Large\bfseries}{\thesection}{1em}{}
#+LATEX_HEADER: \titleformat{\subsection}{\large\bfseries}{\thesubsection}{1em}{}

# === TABLES AND LISTS ===
#+LATEX_HEADER: \usepackage{booktabs}  # Professional tables
#+LATEX_HEADER: \usepackage{enumitem}  # Better lists

# === DOCUMENT METADATA ===
#+TITLE: Article Title
#+AUTHOR: Ahsanur Rahman
#+DATE: \today

#+OPTIONS: toc:t num:t
```

---

### 4. Presentation/Beamer Template (`~/org/templates/presentation.org`)

**For academic presentations and talks with modern math rendering.**

```org
# -*- mode: org; -*-
#+STARTUP: beamer latexpreview

#+LATEX_CLASS: beamer
#+LATEX_CLASS_OPTIONS: [presentation,aspectratio=169]
#+BEAMER_THEME: metropolis
#+BEAMER_COLOR_THEME: default
#+BEAMER_FONT_THEME: professionalfonts

# === MODERN FONT SYSTEM FOR BEAMER ===
#+LATEX_HEADER: \usepackage{fontspec}
#+LATEX_HEADER: \usepackage{unicode-math}
#+LATEX_HEADER: \setmathfont{STIX Two Math}

# === CORE MATH PACKAGES ===
#+LATEX_HEADER: \usepackage{amsmath}
#+LATEX_HEADER: \usepackage{physics}
#+LATEX_HEADER: \usepackage{siunitx}
#+LATEX_HEADER: \usepackage{graphicx}

# === PRESENTATION METADATA ===
#+TITLE: Your Presentation Title
#+AUTHOR: Ahsanur Rahman
#+DATE: \today
#+INSTITUTE: Your Institution
#+EMAIL: ahsanur041@proton.me

#+OPTIONS: H:2 toc:t num:t

# Usage:
# - Top level (*)     = Sections (appear in navigation)
# - Second level (**) = Frames (individual slides)
# - Use *** for columns within frames
#
# Example frame with math:
# ** Quantum Harmonic Oscillator
# The Hamiltonian is:
# \begin{equation}
# \hat{H} = \frac{\hat{p}^2}{2m} + \frac{1}{2}m\omega^2\hat{x}^2
# \end{equation}
```

---

### 5. Quick Notes/Homework Template (`~/org/templates/notes.org`)

**For class notes, homework, and quick calculations with fast compilation.**

```org
# -*- mode: org; -*-
#+STARTUP: latexpreview

# === MINIMAL SETUP FOR FAST COMPILATION ===
#+LATEX_COMPILER: lualatex
#+LATEX_CLASS: article
#+LATEX_CLASS_OPTIONS: [11pt]

# === ESSENTIAL PACKAGES ONLY ===
#+LATEX_HEADER: \usepackage{fontspec}
#+LATEX_HEADER: \usepackage{unicode-math}
#+LATEX_HEADER: \setmathfont{STIX Two Math}
#+LATEX_HEADER: \usepackage{amsmath}
#+LATEX_HEADER: \usepackage{physics}
#+LATEX_HEADER: \usepackage{siunitx}

# === COMPACT FORMATTING ===
#+LATEX_HEADER: \usepackage[margin=0.75in]{geometry}
#+LATEX_HEADER: \setlength{\parskip}{0.3em}
#+LATEX_HEADER: \setlength{\parindent}{0pt}

#+TITLE: Notes
#+AUTHOR: Ahsanur Rahman
#+DATE: 

#+OPTIONS: toc:nil num:nil
```

---

### 6. Thesis/Dissertation Template (`~/org/templates/thesis.org`)

**For long-form academic writing with comprehensive formatting.**

```org
# -*- mode: org; -*-
#+SETUPFILE: ~/org/templates/scientific-base.org

# === BOOK CLASS FOR LONG DOCUMENTS ===
#+LATEX_CLASS: report
#+LATEX_CLASS_OPTIONS: [12pt,oneside,a4paper]

# === THESIS-SPECIFIC GEOMETRY ===
#+LATEX_HEADER: \usepackage[top=1in,bottom=1in,left=1.5in,right=1in]{geometry}
#+LATEX_HEADER: \linespread{2.0}  # Double spacing

# === CHAPTER FORMATTING ===
#+LATEX_HEADER: \usepackage{titlesec}
#+LATEX_HEADER: \titleformat{\chapter}[display]{\normalfont\huge\bfseries}{\chaptertitlename\ \thechapter}{20pt}{\Huge}
#+LATEX_HEADER: \titlespacing*{\chapter}{0pt}{-20pt}{40pt}

# === ENHANCED TABLES AND FIGURES ===
#+LATEX_HEADER: \usepackage{booktabs}
#+LATEX_HEADER: \usepackage{longtable}
#+LATEX_HEADER: \usepackage{caption}
#+LATEX_HEADER: \usepackage{subcaption}

# === APPENDICES ===
#+LATEX_HEADER: \usepackage[toc,page]{appendix}

# === HEADERS AND FOOTERS ===
#+LATEX_HEADER: \usepackage{fancyhdr}
#+LATEX_HEADER: \pagestyle{fancy}
#+LATEX_HEADER: \fancyhf{}
#+LATEX_HEADER: \fancyhead[R]{\thepage}
#+LATEX_HEADER: \fancyhead[L]{\leftmark}

# === DOCUMENT METADATA ===
#+TITLE: Thesis Title
#+AUTHOR: Ahsanur Rahman
#+DATE: \today

#+OPTIONS: toc:t num:t H:3
```

---

## Doom Emacs Integration

Add this to your `config.org` to quickly insert templates:

```elisp
(after! org
  ;; Quick template insertion
  (defun +org-insert-scientific-template ()
    "Insert a scientific document template with interactive selection."
    (interactive)
    (let* ((templates '(("physics-twocol" . "Two-column physics paper")
                       ("article-single" . "Single-column article")
                       ("presentation" . "Beamer presentation")
                       ("notes" . "Quick notes/homework")
                       ("thesis" . "Thesis/dissertation")))
           (choice (completing-read "Select template: "
                                   (mapcar (lambda (x) (format "%s - %s" (car x) (cdr x))) templates)))
           (template (car (split-string choice " -"))))
      (goto-char (point-min))
      (insert (format "#+SETUPFILE: ~/org/templates/%s.org\n\n" template))
      (unless (string= template "notes")
        (insert "#+TITLE: \n")
        (insert "#+AUTHOR: Ahsanur Rahman\n")
        (insert (format "#+DATE: %s\n\n" (format-time-string "%Y-%m-%d"))))
      (when (string= template "physics-twocol")
        (insert "#+BEGIN_abstract\n\n#+END_abstract\n\n"))
      (insert "* Introduction\n\n")
      (search-backward "#+TITLE: " nil t)
      (end-of-line)))
  
  ;; Keybinding
  (map! :leader
        (:prefix ("i" . "insert")
         :desc "Scientific template" "t" #'+org-insert-scientific-template)))
```

---

## Usage Examples

### Basic Article
```org
#+SETUPFILE: ~/org/templates/article-single.org

#+TITLE: Analysis of Quantum Entanglement
#+AUTHOR: Ahsanur Rahman
#+DATE: 2024-11-25

* Introduction

The phenomenon of quantum entanglement is described by the Bell states:

\begin{equation}
|\Phi^{\pm}\rangle = \frac{1}{\sqrt{2}}(|00\rangle \pm |11\rangle)
\end{equation}

where $\ket{0}$ and $\ket{1}$ are computational basis states.
```

### Physics Paper with Citations
```org
#+SETUPFILE: ~/org/templates/physics-twocol.org

#+TITLE: Master Equation Approach to Open Quantum Systems
#+AUTHOR: Ahsanur Rahman

#+BEGIN_abstract
We derive the Lindblad master equation using the Born-Markov approximation.
#+END_abstract

* Theory

Following cite:breuer2002, the Lindblad equation takes the form:

\begin{equation}
\frac{d\rho}{dt} = -\frac{i}{\hbar}[\hat{H}, \rho] + \mathcal{L}[\rho]
\end{equation}

bibliography:~/org/references/references.bib
```

### Quick Homework Notes
```org
#+SETUPFILE: ~/org/templates/notes.org

* Problem 1

Find the eigenvalues of $\hat{H} = \hat{p}^2/(2m) + V(x)$.

Solution: The time-independent Schrödinger equation is:

$$-\frac{\hbar^2}{2m}\frac{d^2\psi}{dx^2} + V(x)\psi = E\psi$$
```

---

## Font Selection Guide

### STIX Two Math (Default - Recommended)
- **Best for**: Professional publications, journal submissions
- **Coverage**: 2400+ math symbols, comprehensive Unicode support
- **Style**: Traditional, authoritative, widely recognized
- **Pairs with**: STIX Two Text, Times-like serif fonts
- **Use when**: Submitting to academic journals, formal documents

### Libertinus Math
- **Best for**: Books, theses, elegant documents
- **Coverage**: Comprehensive with refined aesthetics
- **Style**: Elegant, classical, inspired by Times Roman
- **Pairs with**: Libertinus Serif (excellent match)
- **Use when**: Writing a thesis, book manuscript, or elegant report

### Fira Math
- **Best for**: Presentations, modern documents
- **Coverage**: Good coverage with clean design
- **Style**: Modern, clean, geometric
- **Pairs with**: Fira Sans (perfect match for presentations)
- **Use when**: Creating presentations, modern technical documents

---

## Advanced Customizations

### Custom Math Font Combinations
```org
# Use STIX Two Math but with specific glyphs from other fonts
#+LATEX_HEADER: \setmathfont{STIX Two Math}
#+LATEX_HEADER: \setmathfont[range={\mathcal,\mathbfcal},StylisticSet=1]{XITS Math}
```

### Upright vs Italic Greek Letters
```org
# French math style: italic Latin, upright Greek
#+LATEX_HEADER: \usepackage[math-style=french]{unicode-math}
#+LATEX_HEADER: \setmathfont{STIX Two Math}

# ISO math style: italic for both (default)
#+LATEX_HEADER: \usepackage[math-style=ISO]{unicode-math}
#+LATEX_HEADER: \setmathfont{STIX Two Math}
```

### Customize Bibliography Style
```org
# Numeric citations
#+LATEX_HEADER: \usepackage[backend=biber,style=numeric,sorting=none]{biblatex}

# IEEE style
#+LATEX_HEADER: \usepackage[backend=biber,style=ieee]{biblatex}

# APS (Physical Review) style
#+LATEX_HEADER: \usepackage[backend=biber,style=phys]{biblatex}
```

### Custom Colors for Links
```org
#+LATEX_HEADER: \usepackage{xcolor}
#+LATEX_HEADER: \definecolor{darkblue}{RGB}{0,0,139}
#+LATEX_HEADER: \hypersetup{colorlinks=true,linkcolor=darkblue,citecolor=darkblue,urlcolor=darkblue}
```

---

## Troubleshooting Templates

### Problem: Font not found
**Solution**: Verify font installation
```bash
luaotfload-tool --list=stix2math
luaotfload-tool --list=libertinus  
luaotfload-tool --list=fira
```
If not found, update your LaTeX distribution:
```bash
tlmgr update --all  # TeX Live
```

### Problem: Template not loading
**Solution**: Check file path
```elisp
;; Run in Emacs:
(file-exists-p (expand-file-name "~/org/templates/scientific-base.org"))
```

### Problem: Bibliography not compiling
**Solution**: Ensure three compilation passes
```bash
lualatex document.tex
biber document
lualatex document.tex
```
Or use latexmk (already configured in your config):
```bash
latexmk -lualatex document.tex
```

### Problem: Math preview shows old font
**Solution**: Clear preview cache
```elisp
;; In Emacs:
M-x org-clear-latex-preview
;; Or delete: ~/.emacs.d/.local/cache/org-preview-ltximg/
```

### Problem: Slow compilation with thesis template
**Solution**: Use draft mode during editing
```org
#+LATEX_CLASS_OPTIONS: [12pt,oneside,a4paper,draft]
```

---

## Project-Local Bibliography

For projects with their own bibliography, create `.dir-locals.el` in project root:

```elisp
((org-mode . ((org-latex-packages-alist . 
               (("" "siunitx" t)
                ("" "tikz" t)))
              (eval . (setq-local 
                       org-latex-pdf-process
                       '("latexmk -pdf -lualatex -shell-escape %f"))))))
```

---

## Template Maintenance Best Practices

1. **Version Control**: Keep `~/org/templates/` in git
2. **Test Changes**: Always test in a scratch file first
3. **Document Modifications**: Add comments explaining custom packages
4. **Keep Base Stable**: Minimize changes to `scientific-base.org`
5. **Update Bibliography Path**: Adjust `\addbibresource{}` to match your setup
6. **Font Consistency**: Use one math font consistently across a project

---

## Quick Reference: Template Usage

| Template | Command | Best For | Compile Time |
|----------|---------|----------|--------------|
| `physics-twocol` | `SPC i t` → physics-twocol | Journal papers | Medium |
| `article-single` | `SPC i t` → article-single | Reports, essays | Fast |
| `presentation` | `SPC i t` → presentation | Talks, lectures | Fast |
| `notes` | `SPC i t` → notes | Homework, quick notes | Fastest |
| `thesis` | `SPC i t` → thesis | Dissertations | Slow |

---

This template system with modern Unicode math fonts provides professional typography for all your scientific documents while maintaining consistency and eliminating repetitive configuration!
