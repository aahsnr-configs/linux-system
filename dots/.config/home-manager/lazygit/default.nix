# ~/.config/home-manager/lazygit/default.nix
{ pkgs, ... }:
{
  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        scrollHeight = 2;
        scrollPastBottom = true;
        mouseEvents = true;
        skipDiscardChangeWarning = false;
        skipStashWarning = false;
        showFileTree = true;
        showListFooter = true;
        showRandomTip = true;
        showBranchCommitHash = true;
        showBottomLine = true;
        showPanelJumps = true;
        showCommandLog = true;
        nerdFontsVersion = "3";
        commitLength.show = true;
        splitDiff = "auto";
        border = "rounded";
        animateExpansion = true;
      };
      os = {
        editCommand = "nvim";
        editCommandTemplate = ''{{editor}} "{{filename}}"'';
        openCommand = "xdg-open";
        openLinkCommand = "xdg-open {{link}}";
        copyToClipboardCmd = "wl-copy";
        readFromClipboardCmd = "wl-paste";
      };
      keybinding = {
        universal = {
          quit = "q";
          "quit-alt1" = "<c-c>";
          "return" = "<esc>";
          quitWithoutChangingDirectory = "Q";
          togglePanel = "<tab>";
          prevItem = "k";
          nextItem = "j";
          "prevItem-alt" = "<up>";
          "nextItem-alt" = "<down>";
          prevPage = "<c-u>";
          nextPage = "<c-d>";
          gotoTop = "<home>";
          gotoBottom = "<end>";
          prevBlock = "h";
          nextBlock = "l";
          nextTab = "]";
          prevTab = "[";
          undo = "z";
          redo = "<c-z>";
          filteringMenu = "<c-s>";
          diffingMenu = "W";
          copyToClipboard = "<c-o>";
          openRecentRepos = "<c-r>";
        };
        files = {
          commitChanges = "c";
          commitChangesWithoutHook = "C";
          amendLastCommit = "A";
          commitChangesWithEditor = "<c-o>";
          confirmDiscard = "x";
          ignoreFile = "i";
          refreshFiles = "r";
          stashAllChanges = "s";
          viewStashOptions = "S";
          toggleStagedAll = "a";
          viewResetOptions = "D";
          fetch = "f";
        };
        branches = {
          createPullRequest = "o";
          checkoutBranch = "<space>";
          forceCheckoutBranch = "F";
          rebaseBranch = "r";
          renameBranch = "R";
          mergeIntoCurrentBranch = "m";
          fastForward = "f";
          push = "P";
          pull = "p";
          setUpstream = "u";
          deleteBranch = "d";
        };
        commits = {
          squashDown = "s";
          renameCommit = "r";
          renameCommitWithEditor = "R";
          viewResetOptions = "g";
          markCommitAsFixup = "f";
          createFixupCommit = "F";
          squashAboveCommits = "S";
          moveDownCommit = "<c-j>";
          moveUpCommit = "<c-k>";
          amendToCommit = "A";
          pickCommit = "p";
          revertCommit = "t";
          cherryPickCopy = "c";
          pasteCommits = "v";
          tagCommit = "T";
          checkoutCommit = "<space>";
          openInBrowser = "o";
          startInteractiveRebase = "i";
        };
        stash = {
          popStash = "g";
          renameStash = "r";
          applyStash = "a";
          dropStash = "d";
        };
      };
      customCommands = [
        {
          key = "E";
          command = "git commit --amend --no-edit";
          context = "commits";
          description = "Amend commit without editing message";
        }
        {
          key = "n";
          command = "${pkgs.neovim}/bin/nvim {{.SelectedFile.Name}}";
          context = "files";
          description = "Open file in Neovim";
          output = "terminal";
        }
        {
          key = "T";
          command = ''${pkgs.neovim}/bin/nvim -c "lua require(\"telescope.builtin\").git_files()"'';
          context = "global";
          description = "Open AstroNvim with Telescope git files";
          output = "terminal";
        }
        {
          key = "P";
          command = "git push --force-with-lease";
          context = "global";
          description = "Force push with lease (safer)";
        }
        {
          key = "S";
          command = ''git stash push -m "{{.Form.Message}}"'';
          context = "files";
          description = "Stash with custom message";
          prompts = [
            {
              type = "input";
              key = "Message";
              title = "Stash Message";
              initialValue = "WIP: ";
            }
          ];
        }
        {
          key = "o";
          command = "${pkgs.neovim}/bin/nvim .";
          context = "global";
          description = "Open current repository in Neovim";
          output = "terminal";
        }
        {
          key = "N";
          command = "git checkout -b {{.Form.BranchName}}";
          context = "localBranches";
          description = "Create new branch";
          prompts = [
            {
              type = "input";
              key = "BranchName";
              title = "Branch Name";
              initialValue = "feature/";
            }
          ];
        }
      ];
    };
  };
}
