# Home Manager configuration for tmux.

# This module provides a comprehensive tmux setup, including base configuration,
# plugins, project-specific session management, custom keybindings,
# and an enhanced status line for a "tab-like" window experience.
{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    # Specifies the default shell for new tmux panes/windows.
    shell = "${pkgs.fish}/bin/fish";
    # Allows tmux to aggressively resize windows when the terminal size changes.
    aggressiveResize = true;
    # Start window numbering from 1 instead of 0, which is more human-friendly.
    baseIndex = 1;
    # Time in milliseconds to wait for a second escape sequence byte.
    # Set to 0 for instant key-press recognition, avoiding delays for common shortcuts.
    escapeTime = 0;
    # Sets keybindings to vi mode, useful for users familiar with Vim.
    keyMode = "vi";
    # Enables mouse support for clicking panes, scrolling, and resizing.
    mouse = true;
    # Automatically creates a new session if none are active when tmux is launched.
    newSession = true;
    # Sets the tmux prefix key to 'a'. (e.g., Ctrl-a instead of Ctrl-b).
    shortcut = "a";
    # Sets the default terminal type for tmux. 'screen-256color' is common for full color support.
    terminal = "screen-256color";

    # All custom tmux configuration is placed here, directly embedded into the generated tmux.conf.
    extraConfig = ''
      # ===============================================
      # General Settings
      # ===============================================

      # Ensure true color support in terminals that advertise it.
      set -ga terminal-overrides ",*256col*:Tc"

      # ===============================================
      # Custom Keybindings for "Tab-like" Windows
      # ===============================================

      # Reload config with 'Prefix-r'
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"

      # Clear history/screen (useful for debugging, or just a quick clear of the current pane)
      # Uses 'Ctrl-l' to send a clear screen command to the active pane.
      bind -n C-l send-keys 'C-l'

      # Prompt for window name when creating a new window.
      # This makes new windows immediately feel like new "tabs" that you name.
      # When you press 'Prefix-a c', it will prompt you for the new window's name.
      bind c command-prompt -p "New window name:" "new-window -n '%%'"

      # Prompt to rename the current window.
      # When you press 'Prefix-a ,' (comma), it will prompt you to rename the current window.
      bind , command-prompt -p "Rename window:" "rename-window '%%'"

      # ===============================================
      # Status Line Customization for Tab-like Display
      # ===============================================

      # Set status bar position (top or bottom).
      set -g status-position bottom

      # Set refresh interval for status line (in seconds).
      set -g status-interval 1

      # Center window list in the status bar.
      set -g status-justify centre

      # Status bar colors (using Nord-like palette for readability).
      set -g status-bg '#2e3440' # Darker background
      set -g status-fg '#eceff4' # Lighter foreground

      # Left side of status bar (e.g., session name, hostname).
      # Display current session name and local hostname.
      set -g status-left '#[fg=#88c0d0][#S] #[fg=#8fbcbb]#H ' # Blueish session name, green hostname
      set -g status-left-length 30

      # Right side of status bar (e.g., date, time).
      set -g status-right '#[fg=#a3be8c]%Y-%m-%d #[fg=#ebcb8b]%H:%M #[default]' # Green date, yellow time
      set -g status-right-length 50

      # Window list format for inactive windows ("tabs").
      # I: window index, W: window name, F: flags (e.g., * for current, ! for bell, # for activity).
      set -g window-status-format " #I:#W#F "
      set -g window-status-bg '#4c566a' # Inactive window background (darker grey-blue)
      set -g window-status-fg '#d8dee9' # Inactive window foreground (light grey)

      # Current window format (active "tab").
      set -g window-status-current-format " #[fg=#2e3440,bg=#81a1c1]#I:#W#F " # Dark text on brighter blue
      set -g window-status-current-bg '#81a1c1' # Active window background (brighter blue)
      set -g window-status-current-fg '#2e3440' # Active window foreground (dark text)

      # Other window highlights (activity, bells).
      set -g window-status-activity-bg '#2e3440'   # Background for windows with activity
      set -g window-status-activity-fg '#ebcb8b'   # Foreground for windows with activity (yellow)
      set -g window-status-bell-bg '#2e3440'       # Background for windows with bell
      set -g window-status-bell-fg '#bf616a'       # Foreground for windows with bell (reddish)

      # Message styling (e.g., when showing prompts or info messages).
      set -g message-bg '#81a1c1' # Message background (blue)
      set -g message-fg '#2e3440' # Message foreground (dark text)

      # Command-prompt styling.
      set -g display-panes-active-colour '#ebcb8b' # Active pane color in display-panes mode (yellow)
      set -g display-panes-colour '#d8dee9'       # Inactive pane color in display-panes mode (light grey)
      set -g pane-active-border-style fg=#81a1c1  # Active pane border (blue)
      set -g pane-border-style fg=#4c566a         # Inactive pane border (grey-blue)

      # ===============================================
      # Plugin Specific Settings
      # ===============================================

      # tmux-resurrect settings
      set -g @resurrect-dir '~/.tmux/resurrect' # Directory to save/restore sessions
      set -g @resurrect-strategy 'default'      # Default strategy: saves panes, windows, sessions

      # tmux-continuum settings
      set -g @continuum-restore 'on'            # Restore sessions when tmux starts
      set -g @continuum-save-interval '15'      # Save sessions every 15 minutes
      set -g @continuum-boot 'on'               # Automatically start tmux server on system boot (if enabled by Continuum)
      set -g @continuum-boot-options 'iterm,fullscreen' # Options for Continuum's boot process (e.g. for iTerm2)
    '';

    # Lists tmux plugins to be managed by Home Manager.
    plugins = with pkgs; [
      # sensible: A set of common, sensible tmux options.
      tmuxPlugins.sensible
      # vim-tmux-navigator: Seamless navigation between Vim panes and tmux panes.
      tmuxPlugins.vim-tmux-navigator
      # yank: Easy copying to system clipboard from tmux.
      tmuxPlugins.yank
      # resurrect: Saves and restores tmux environment after a server restart.
      tmuxPlugins.resurrect
      # continuum: Automatically saves and restores tmux environments at intervals.
      tmuxPlugins.continuum
    ];
  };

  home.packages = [
    # Defines a custom shell application 'pux' to open tmux for the current project.
    (pkgs.writeShellApplication {
      name = "pux";
      # Ensures tmux and zoxide are available in the runtime environment of the script.
      runtimeInputs = [
        pkgs.tmux
        pkgs.zoxide
      ];
      # The actual script content.
      text = ''
        # Use zoxide to query for a project directory interactively.
        # This allows selecting a project by typing part of its path.
        PRJ_DIR="$(zoxide query -i)"

        if [ -z "$PRJ_DIR" ]; then
          echo "No project selected. Exiting."
          exit 1
        fi

        # Generate a session name based on the project directory's basename.
        # This ensures a clean name like "my-project" instead of a full path.
        PRJ_NAME="$(basename "$PRJ_DIR")"

        echo "Launching tmux for project: $PRJ_NAME (in $PRJ_DIR)"

        # Change to the selected project directory.
        cd "$PRJ_DIR" || { echo "Failed to change directory to $PRJ_DIR"; exit 1; }

        # Attach to a tmux session named after the project.
        # If the session doesn't exist, it will be created.
        # Using exec replaces the current shell process with tmux, which is efficient.
        exec tmux attach-session -t "$PRJ_NAME" || exec tmux new-session -s "$PRJ_NAME"
      '';
    })
  ];
}
