{ pkgs, ... }:

{
  programs.vscodium = {
    enable = true;
    package = pkgs.vscodium;
    mutableExtensionsDir = false;

    profiles.default = {
      userSettings = {
        # CORE COPILOT & INLINE SUGGESTIONS
        "github.copilot.enable" = {
          "*" = false;
          "plaintext" = false;
          "markdown" = false;
          "scminput" = false;
        };
        "editor.inlineSuggest.enabled" = false;
        "editor.inlineSuggest.showToolbar" = "never";
        "editor.inlineSuggest.syntaxHighlightingEnabled" = false;

        # CHAT & INLINE CHAT UI
        "chat.commandCenter.enabled" = false;
        "chat.titleBar.openInAgentsWindow.enabled" = false;
        "inlineChat.mode" = "hidden";
        "inlineChat.holdToSpeech" = false;

        # TERMINAL AI
        "terminal.integrated.suggest.enabled" = false;
        "terminal.integrated.shellIntegration.decorationsEnabled" = "never";

        # VOICE & ACCESSIBILITY AI
        "accessibility.voice.keywordActivation" = false;
        "accessibility.voice.speechTimeout" = 0;

        # SCM & NOTEBOOKS
        "notebook.experimental.cellChat" = false;
        "notebook.experimental.generate" = false;
        "workbench.commandPalette.experimental.suggestCommands" = false;

        # PREVENT AI FROM SNEAKING BACK IN
        "extensions.autoUpdate" = false;
        "extensions.autoCheckUpdates" = false;
        "extensions.ignoreRecommendations" = true;
        "telemetry.telemetryLevel" = "off";

        # PERFORMANCE — Electron/Chromium will never fully match a native,
        # GPU-accelerated Rust editor like Zed, but most of the day-to-day gap
        # is animation/rendering work, not the editor core. This strips it out.
        "editor.minimap.enabled" = true;
        "editor.smoothScrolling" = true;
        "workbench.list.smoothScrolling" = false;
        "editor.cursorSmoothCaretAnimation" = "off";
        "editor.occurrencesHighlight" = "off";
        "workbench.reduceMotion" = "on";
        "git.autofetch" = false;
        "files.hotExit" = "off";

        # --- YOUR ORIGINAL SETTINGS (Fixed spaces and glob patterns) ---
        "editor.fontFamily" = "'JetBrainsMono Nerd Font Mono', 'JetBrainsMono Nerd Font', monospace";
        "editor.fontLigatures" = true;
        "terminal.integrated.fontFamily" =
          "'JetBrainsMono Nerd Font Mono', 'JetBrainsMono Nerd Font', monospace";
        "window.titleBarStyle" = "custom";
        "workbench.editor.showTabs" = "none";
        "window.zoomLevel" = 1;
        "editor.fontSize" = 14;
        "terminal.integrated.fontSize" = 14;
        "editor.formatOnSave" = true;
        "editor.snippetSuggestions" = "top";
        "editor.suggest.snippetsPreventQuickSuggestions" = false;
        "files.trimTrailingWhitespace" = true;
        "files.insertFinalNewline" = true;
        "files.trimFinalNewlines" = true;
        "files.encoding" = "utf8";
        "files.associations" = {
          "*.tex" = "latex";
          "*.sty" = "latex";
          "*.cls" = "latex";
          "*.bib" = "bibtex";
          "*.bst" = "bibtex";
        };
        "workbench.editor.enablePreview" = false;
        "workbench.activityBar.location" = "hidden";
        "workbench.startupEditor" = "none";
        "breadcrumbs.enabled" = true;
        "workbench.layoutControl.enabled" = false;
        "vim.easymotion" = true;
        "vim.useSystemClipboard" = true;
        "vim.hlsearch" = true;
        "vim.timeout" = 300;
        "vim.normalModeKeyBindingsNonRecursive" = [
          {
            before = [ "<space>" ];
            commands = [ "vspacecode.space" ];
          }
          {
            before = [ "," ];
            commands = [
              "vspacecode.space"
              {
                command = "whichkey.triggerKey";
                args = "m";
              }
            ];
          }
        ];
        "vim.visualModeKeyBindingsNonRecursive" = [
          {
            before = [ "<space>" ];
            commands = [ "vspacecode.space" ];
          }
          {
            before = [ "," ];
            commands = [
              "vspacecode.space"
              {
                command = "whichkey.triggerKey";
                args = "m";
              }
            ];
          }
          {
            before = [ ">" ];
            commands = [ "editor.action.indentLines" ];
          }
          {
            before = [ "<" ];
            commands = [ "editor.action.outdentLines" ];
          }
        ];
        "extensions.experimental.affinity" = {
          "vscodevim.vim" = 1;
          "ltex-plus.vscode-ltex-plus" = 2; # Java-backed LSP; keep it off vim's thread
        };
        "whichkey.delay" = 200;
        "whichkey.sortOrder" = "alphabetically";
        "vspacecode.bindingOverrides" = [
          {
            keys = "n";
            name = "Notebook...";
            type = "bindings";
            bindings = [
              {
                key = "x";
                name = "Execute cell";
                type = "command";
                command = "notebook.cell.execute";
              }
              {
                key = "n";
                name = "Execute + next";
                type = "command";
                command = "notebook.cell.executeAndSelectBelow";
              }
              {
                key = "i";
                name = "Execute + insert below";
                type = "command";
                command = "notebook.cell.executeAndInsertBelow";
              }
              {
                key = "a";
                name = "Insert cell above";
                type = "command";
                command = "notebook.cell.insertCodeCellAbove";
              }
              {
                key = "b";
                name = "Insert cell below";
                type = "command";
                command = "notebook.cell.insertCodeCellBelow";
              }
              {
                key = "d";
                name = "Delete cell";
                type = "command";
                command = "notebook.cell.delete";
              }
            ];
          }
          {
            keys = "t";
            name = "Toggle...";
            type = "bindings";
            bindings = [
              {
                key = "s";
                name = "Sidebar";
                type = "command";
                command = "workbench.action.toggleSidebarVisibility";
              }
              {
                key = "p";
                name = "Panel (terminal/problems/output)";
                type = "command";
                command = "workbench.action.togglePanel";
              }
              {
                key = "b";
                name = "Status bar";
                type = "command";
                command = "workbench.action.toggleStatusbarVisibility";
              }
              {
                key = "z";
                name = "Zen mode";
                type = "command";
                command = "workbench.action.toggleZenMode";
              }
              {
                key = "f";
                name = "Full screen";
                type = "command";
                command = "workbench.action.toggleFullScreen";
              }
              {
                key = "w";
                name = "Word wrap";
                type = "command";
                command = "editor.action.toggleWordWrap";
              }
              {
                key = "m";
                name = "Minimap";
                type = "command";
                command = "editor.action.toggleMinimap";
              }
            ];
          }
          {
            keys = "o";
            name = "Open view...";
            type = "bindings";
            bindings = [
              {
                key = "p";
                name = "Project explorer";
                type = "command";
                command = "workbench.view.explorer";
              }
              {
                key = "t";
                name = "Terminal";
                type = "command";
                command = "workbench.action.terminal.toggleTerminal";
              }
              {
                key = "s";
                name = "Search";
                type = "command";
                command = "workbench.view.search";
              }
              {
                key = "g";
                name = "Source control";
                type = "command";
                command = "workbench.view.scm";
              }
              {
                key = "d";
                name = "Debug";
                type = "command";
                command = "workbench.view.debug";
              }
              {
                key = "x";
                name = "Extensions";
                type = "command";
                command = "workbench.extensions.action.showInstalledExtensions";
              }
            ];
          }
          {
            keys = "m";
            name = "LaTeX...";
            type = "bindings";
            bindings = [
              {
                key = "b";
                name = "Build LaTeX project";
                type = "command";
                command = "latex-workshop.build";
              }
              {
                key = "v";
                name = "View PDF";
                type = "command";
                command = "latex-workshop.view";
              }
              {
                key = "j";
                name = "SyncTeX from cursor";
                type = "command";
                command = "latex-workshop.synctex";
              }
              {
                key = "c";
                name = "Clean auxiliary files";
                type = "command";
                command = "latex-workshop.clean";
              }
              {
                key = "k";
                name = "Kill LaTeX compiler process";
                type = "command";
                command = "latex-workshop.kill";
              }
              {
                key = "r";
                name = "Build with recipe";
                type = "command";
                command = "latex-workshop.recipes";
              }
              {
                key = "l";
                name = "View compiler log";
                type = "command";
                command = "latex-workshop.compilerlog";
              }
            ];
          }
        ];
        "files.watcherExclude" = {
          "**/.venv/**" = true;
          "**/venv/**" = true;
          "**/__pycache__/**" = true;
          "**/.pytest_cache/**" = true;
          "**/.mypy_cache/**" = true;
          "**/.git/objects/**" = true;
          "**/*.aux" = true;
          "**/*.log" = true;
          "**/*.out" = true;
          "**/*.toc" = true;
          "**/*.lof" = true;
          "**/*.lot" = true;
          "**/*.fls" = true;
          "**/*.fdb_latexmk" = true;
          "**/*.synctex.gz" = true;
          "**/*.bbl" = true;
          "**/*.blg" = true;
          "**/*.bcf" = true;
          "**/*.run.xml" = true;
        };
        "search.exclude" = {
          "**/.venv" = true;
          "**/venv" = true;
          "**/__pycache__" = true;
          "**/.pytest_cache" = true;
          "**/.mypy_cache" = true;
          "**/*.aux" = true;
          "**/*.log" = true;
          "**/*.out" = true;
          "**/*.toc" = true;
          "**/*.lof" = true;
          "**/*.lot" = true;
          "**/*.fls" = true;
          "**/*.fdb_latexmk" = true;
          "**/*.synctex.gz" = true;
          "**/*.bbl" = true;
          "**/*.blg" = true;
          "**/*.bcf" = true;
          "**/*.run.xml" = true;
        };
        "files.exclude" = {
          "**/__pycache__" = true;
          "**/.pytest_cache" = true;
          "**/.mypy_cache" = true;
        };
        "search.followSymlinks" = false;
        "python.analysis.diagnosticMode" = "openFilesOnly";
        "update.mode" = "none";
        "notebook.formatOnSave.enabled" = true;
        "[python]" = {
          "editor.formatOnSave" = true;
          "editor.defaultFormatter" = "charliermarsh.ruff";
        };
        "python.analysis.typeCheckingMode" = "basic";
        "python.analysis.autoImportCompletions" = true;
        "workbench.browser.showInTitleBar" = false;
        "workbench.editor.editorActionsLocation" = "hidden";
        "workbench.browser.searchEngine" = "google";
        "workbench.colorTheme" = "Catppuccin Mocha";
        "doom.dashboard.openOnActivation" = false;
        "json.schemaDownload.trustedDomains" = {
          "https://developer.microsoft.com/json-schemas/" = true;
          "https://json-schema.org/" = true;
          "https://json.schemastore.org/" = true;
          "https://raw.githubusercontent.com" = true;
          "https://raw.githubusercontent.com/devcontainers/spec/" = true;
          "https://raw.githubusercontent.com/microsoft/vscode/" = true;
          "https://schemastore.azurewebsites.net/" = true;
          "https://www.schemastore.org/" = true;
        };
        "[latex]" = {
          "editor.tabSize" = 2;
          "editor.wordWrap" = "on";
          "editor.defaultFormatter" = "James-Yu.latex-workshop";
          "editor.quickSuggestions" = {
            "other" = true;
            "comments" = false;
            "strings" = true;
          };
        };
        "[bibtex]" = {
          "editor.tabSize" = 2;
          "editor.wordWrap" = "on";
        };
        "latex-workshop.latex.autoBuild.run" = "onSave";
        "latex-workshop.latex.recipe.default" = "lastUsed";
        "latex-workshop.latex.outDir" = "%DIR%";
        "latex-workshop.latex.autoClean.run" = "onFailed";
        "latex-workshop.latex.clean.fileTypes" = [
          ".aux"
          ".bbl"
          ".blg"
          ".idx"
          ".ind"
          ".lof"
          ".lot"
          ".out"
          ".toc"
          ".acn"
          ".acr"
          ".alg"
          ".glg"
          ".glo"
          ".gls"
          ".fls"
          ".log"
          ".fdb_latexmk"
          ".snm"
          ".nav"
          ".dvi"
          ".run.xml"
          ".bcf"
          ".synctex.gz"
        ];
        "latex-workshop.latex.build.enableMagicComments" = true;
        "latex-workshop.view.pdf.viewer" = "tab";
        "latex-workshop.view.pdf.internal.synctex.keybinding" = "double-click";
        "latex-workshop.synctex.afterBuild.enabled" = true;
        "latex-workshop.hover.preview.enabled" = true;
        "latex-workshop.hover.preview.mathjax.enabled" = true;
        "latex-workshop.hover.command.enabled" = true;
        "latex-workshop.intellisense.package.enabled" = true;
        "latex-workshop.intellisense.citation.enabled" = true;
        "latex-workshop.intellisense.label.enabled" = true;
        "latex-workshop.message.error.show" = true;
        "latex-workshop.message.warning.show" = false;
        "latex-workshop.latexindent.enabled" = true;
        "latex-workshop.latexindent.path" = "latexindent";
        "latex-workshop.linting.chktex.enabled" = true;
        "latex-workshop.latex.tools" = [
          {
            name = "latexmk-pdf";
            command = "latexmk";
            args = [
              "-synctex=1"
              "-interaction=nonstopmode"
              "-file-line-error"
              "-pdf"
              "-outdir=%OUTDIR%"
              "%DOC%"
            ];
            env = { };
          }
          {
            name = "latexmk-xelatex";
            command = "latexmk";
            args = [
              "-synctex=1"
              "-interaction=nonstopmode"
              "-file-line-error"
              "-xelatex"
              "-outdir=%OUTDIR%"
              "%DOC%"
            ];
            env = { };
          }
          {
            name = "latexmk-lualatex";
            command = "latexmk";
            args = [
              "-synctex=1"
              "-interaction=nonstopmode"
              "-file-line-error"
              "-lualatex"
              "-outdir=%OUTDIR%"
              "%DOC%"
            ];
            env = { };
          }
          {
            name = "pdflatex";
            command = "pdflatex";
            args = [
              "-synctex=1"
              "-interaction=nonstopmode"
              "-file-line-error"
              "%DOC%"
            ];
            env = { };
          }
          {
            name = "xelatex";
            command = "xelatex";
            args = [
              "-synctex=1"
              "-interaction=nonstopmode"
              "-file-line-error"
              "%DOC%"
            ];
            env = { };
          }
          {
            name = "lualatex";
            command = "lualatex";
            args = [
              "-synctex=1"
              "-interaction=nonstopmode"
              "-file-line-error"
              "%DOC%"
            ];
            env = { };
          }
          {
            name = "biber";
            command = "biber";
            args = [ "%DOCFILE%" ];
            env = { };
          }
          {
            name = "bibtex";
            command = "bibtex";
            args = [ "%DOCFILE%" ];
            env = { };
          }
        ];
        "latex-workshop.latex.recipes" = [
          {
            name = "latexmk pdflatex";
            tools = [ "latexmk-pdf" ];
          }
          {
            name = "latexmk xelatex";
            tools = [ "latexmk-xelatex" ];
          }
          {
            name = "latexmk lualatex";
            tools = [ "latexmk-lualatex" ];
          }
          {
            name = "pdflatex -> bibtex -> pdflatex x2";
            tools = [
              "pdflatex"
              "bibtex"
              "pdflatex"
              "pdflatex"
            ];
          }
          {
            name = "xelatex -> biber -> xelatex x2";
            tools = [
              "xelatex"
              "biber"
              "xelatex"
              "xelatex"
            ];
          }
        ];
        "ltex.language" = "en-US";
        "ltex.checkFrequency" = "save";
        "ltex.diagnosticSeverity" = "information";
      };

      # --- 2. KEYBINDINGS (Fixed broken '&&' syntax & Added AI Nukes) ---
      keybindings = [
        {
          key = "space";
          command = "vspacecode.space";
          when = "activeEditorGroupEmpty && focusedView == '' && !whichkeyActive && !inputFocus";
        }
        {
          key = "space";
          command = "vspacecode.space";
          when = "sideBarFocus && !inputFocus && !whichkeyActive";
        }
        {
          key = "tab";
          command = "extension.vim_tab";
          when = "editorTextFocus && vim.active && !inDebugRepl && vim.mode != 'Insert' && editorLangId != 'magit'";
        }
        {
          key = "tab";
          command = "-extension.vim_tab";
          when = "editorTextFocus && vim.active && !inDebugRepl && vim.mode != 'Insert'";
        }
        {
          key = "x";
          command = "magit.discard-at-point";
          when = "editorTextFocus && editorLangId == 'magit' && vim.mode =~ /^(?!SearchInProgressMode|CommandlineInProgress).*$/";
        }
        {
          key = "k";
          command = "-magit.discard-at-point";
        }
        {
          key = "-";
          command = "magit.reverse-at-point";
          when = "editorTextFocus && editorLangId == 'magit' && vim.mode =~ /^(?!SearchInProgressMode|CommandlineInProgress).*$/";
        }
        {
          key = "v";
          command = "-magit.reverse-at-point";
        }
        {
          key = "shift+-";
          command = "magit.reverting";
          when = "editorTextFocus && editorLangId == 'magit' && vim.mode =~ /^(?!SearchInProgressMode|CommandlineInProgress).*$/";
        }
        {
          key = "shift+v";
          command = "-magit.reverting";
        }
        {
          key = "shift+o";
          command = "magit.resetting";
          when = "editorTextFocus && editorLangId == 'magit' && vim.mode =~ /^(?!SearchInProgressMode|CommandlineInProgress).*$/";
        }
        {
          key = "shift+x";
          command = "-magit.resetting";
        }
        {
          key = "x";
          command = "-magit.reset-mixed";
        }
        {
          key = "ctrl+u x";
          command = "-magit.reset-hard";
        }
        {
          key = "y";
          command = "-magit.show-refs";
        }
        {
          key = "y";
          command = "vspacecode.showMagitRefMenu";
          when = "editorTextFocus && editorLangId == 'magit' && vim.mode == 'Normal'";
        }
        {
          key = "g";
          command = "-magit.refresh";
          when = "editorTextFocus && editorLangId == 'magit' && vim.mode =~ /^(?!SearchInProgressMode|CommandlineInProgress).*$/";
        }
        {
          key = "g";
          command = "vspacecode.showMagitRefreshMenu";
          when = "editorTextFocus && editorLangId == 'magit' && vim.mode =~ /^(?!SearchInProgressMode|CommandlineInProgress).*$/";
        }
        {
          key = "ctrl+j";
          command = "workbench.action.quickOpenSelectNext";
          when = "inQuickOpen";
        }
        {
          key = "ctrl+k";
          command = "workbench.action.quickOpenSelectPrevious";
          when = "inQuickOpen";
        }
        {
          key = "ctrl+j";
          command = "selectNextSuggestion";
          when = "suggestWidgetMultipleSuggestions && suggestWidgetVisible && textInputFocus";
        }
        {
          key = "ctrl+k";
          command = "selectPrevSuggestion";
          when = "suggestWidgetMultipleSuggestions && suggestWidgetVisible && textInputFocus";
        }
        {
          key = "ctrl+l";
          command = "acceptSelectedSuggestion";
          when = "suggestWidgetMultipleSuggestions && suggestWidgetVisible && textInputFocus";
        }
        {
          key = "ctrl+j";
          command = "showNextParameterHint";
          when = "editorFocus && parameterHintsMultipleSignatures && parameterHintsVisible";
        }
        {
          key = "ctrl+k";
          command = "showPrevParameterHint";
          when = "editorFocus && parameterHintsMultipleSignatures && parameterHintsVisible";
        }
        {
          key = "ctrl+j";
          command = "selectNextCodeAction";
          when = "codeActionMenuVisible";
        }
        {
          key = "ctrl+k";
          command = "selectPrevCodeAction";
          when = "codeActionMenuVisible";
        }
        {
          key = "ctrl+l";
          command = "acceptSelectedCodeAction";
          when = "codeActionMenuVisible";
        }
        {
          key = "ctrl+h";
          command = "file-browser.stepOut";
          when = "inFileBrowser";
        }
        {
          key = "alt+x";
          command = "workbench.action.showCommands";
        }
        {
          key = "alt+space";
          command = "whichkey.show";
          when = "editorTextFocus";
        }
        {
          key = "ctrl+l";
          command = "file-browser.stepIn";
          when = "inFileBrowser";
        }

        # Aggressive AI keybinding removals
        {
          key = "ctrl+i";
          command = "-inlineChat.start";
        }
        {
          key = "ctrl+k ctrl+i";
          command = "-inlineChat.start";
        }
        {
          key = "alt+\\";
          command = "-editor.action.inlineSuggest.trigger";
        }
        {
          key = "alt+]";
          command = "-editor.action.inlineSuggest.showNext";
        }
        {
          key = "alt+[";
          command = "-editor.action.inlineSuggest.showPrevious";
        }
        {
          key = "ctrl+enter";
          command = "-editor.action.inlineSuggest.commit";
        }
        {
          key = "ctrl+alt+shift+i";
          command = "-workbench.action.chat.open";
        }
        {
          key = "ctrl+shift+alt+i";
          command = "-workbench.action.chat.openInEditor";
        }
      ];

      # --- 3. EXTENSIONS FROM nix-vscode-extensions ---
      extensions = with pkgs.vscode-marketplace; [
        vscodevim.vim
        vspacecode.vspacecode
        vspacecode.whichkey
        james-yu.latex-workshop
        charliermarsh.ruff
        ltex-plus.vscode-ltex-plus
        catppuccin.catppuccin-vsc
        bearylabs.doom
        bodil.file-browser
        kahole.magit
        ms-python.python
        ms-python.vscode-pylance
        ms-toolsai.jupyter
      ];
    };
  };

  # The activation script that used to live here (force-disabling
  # GitHub.copilot / copilot-chat / ms-vscode.vscode-copilot via `codium
  # --disable-extension` on every `home-manager switch`) has been removed:
  #   - VSCodium doesn't inherit bundled AI extensions from upstream VS
  #     Code binaries in the first place — Copilot is never pre-installed
  #     in either VS Code or VSCodium, it's always a separate extension
  #     the person installs themselves, and stripping exactly that kind of
  #     Microsoft-proprietary/telemetry-tied component is the entire
  #     reason VSCodium exists.
  #   - Even if it were bundled, `mutableExtensionsDir = false;` above
  #     already guarantees the only extensions that can ever be present
  #     are the ones declared in the `extensions` list — there is no path
  #     for Copilot to "sneak back in" for this to guard against.
  #   - Launching a full Electron GUI binary synchronously from inside a
  #     home-manager activation script is itself risky: activation can
  #     run with no WAYLAND_DISPLAY/DISPLAY set (e.g. over SSH, or before
  #     the compositor starts), so the launch can hang or fail and slow
  #     down every `home-manager switch`.
  # If an AI extension is ever added to the `extensions` list above, the
  # `userSettings` block already disables/hides the relevant UI surfaces
  # (see the top of `userSettings` above) — that's the correct place to
  # control this, not an activation-time process kill.
}
