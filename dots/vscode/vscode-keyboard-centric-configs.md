Here's a good spread of real, publicly-posted keyboard-centric VS Code configs — several explicitly modeled on Doom Emacs / Spacemacs.

## Full Spacemacs/Doom-emulation projects (not just configs — actual extensions people built)

- **VSpaceCode** — the most complete Spacemacs-style layer for VS Code. It started as a settings.json config by StreakyCobra, was later merged with stevenguh's separate spacecode project, and is now maintained as a shared extension with a documented settings.json/keybindings.json pair. Repo: github.com/VSpaceCode/VSpaceCode (also see the `vscode-vim` branch, which is the original "just merge this JSON into your settings" approach with no extension needed).
- **HSpaceCode** — a fork of VSpaceCode that swaps VSCodeVim for the Dance extension to get Helix-style modal editing while keeping the Spacemacs-inspired space-triggered action menu.
- **VimCode** (wojukasz) — a LazyVim-style config for VS Code and forks (Cursor, Windsurf, Antigravity), using space as leader with a which-key popup, full LSP integration, and GitLens-backed git bindings, over 50 keybindings organized by prefix. There's also a companion gist with copy-paste-ready `settings.json`/`keybindings.json`.

## Individual dotfiles repos with real, working config files

- **dandavison/dotfiles** — github.com/dandavison/dotfiles/blob/main/vscode/keybindings.json — a real personal keybindings.json in a well-known dotfiles repo.
- **verhovsky/dotfiles** — Dvorak-based settings for macOS/Linux where the author explicitly uses both VS Code and Doom Emacs, so the VS Code bindings are tuned to feel consistent with their Doom setup.
- **noctuid/dotfiles** ("Mouseless Workflow") — keyboard-based configs across vim-inspired programs and Emacs, built around keyboard ergonomics and Colemak — broader than just VS Code but a good ideological match.
- **Allaman/dotfiles** — public dotfiles heavily focused on a terminal-based, keyboard-centric workflow, including editor configs meant as copy-paste inspiration rather than a turnkey install.
- **zenzes/dotfiles (Codeberg)** — stow-managed dotfiles with a vim leader set to Space and a dedicated vscode/ directory with an extensions manager script — a nice example outside GitHub/GitLab proper (Codeberg), if that counts for your search.

## Gists people specifically wrote to be "Spacemacs/Doom in VS Code"

- **"Config your VSCode like Spacemacs"** gist by zilongshanren — gist.github.com/zilongshanren/b9199cbe51ebf0d08aa11a0eac1e8fc1 — paired keybindings.json/settings.json aimed directly at recreating Spacemacs.
- **wojukasz's WhichKey+Vim gist** — a copy-paste-ready settings.json (leader bindings + which-key menu tree) and keybindings.json (modifier-key bindings) for VS Code and its forks.

## Blog posts with linked personal configs (good narrative + actual files)

- **daniebker** — describes setting up VS Code as a keyboard-centric editor mimicking Emacs niceties, with the bindings published in their own dotfiles on GitHub.
- **Davis Haupt ("Configuring VS Code as a Keyboard-Centric IDE")** — explicitly rebuilt VS Code to match a prior Doom Emacs setup: VSCodeVim + VSpaceCode + WhichKey to replicate Doom/Spacemacs leader-key chords, with tabs disabled to force keyboard-only navigation.
- **Patrick McCartney** — a Vim-centric VS Code writeup with a full annotated `vim.normalModeKeyBindings` config, leader set to space.If you want, I can pull the actual JSON content from any of these (e.g., dandavison's keybindings.json or the VSpaceCode settings.json) and walk through the specific bindings, or synthesize a starter config combining the best ideas from a few of these.
