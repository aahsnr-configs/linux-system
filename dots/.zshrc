### PLUGIN MANAGEMENT (Manual - No Plugin Manager)
# Plugin directory
ZSH_PLUGIN_DIR="${HOME}/.zsh_plugins"
ZSH_PLUGIN_LOCK="${ZSH_PLUGIN_DIR}/.update.lock"

# Function to find the correct plugin file to source
_zsh_plugin_find_source() {
    local plugin_path="$1"
    local plugin_name
    plugin_name="$(basename "${plugin_path}")"
    
    local patterns=(
        "${plugin_name}.plugin.zsh"
        "${plugin_name}.zsh"
        "${plugin_name}.zsh-theme"
        "init.zsh"
        "${plugin_name}.sh"
    )
    
    local pattern
    for pattern in "${patterns[@]}"; do
        if [[ -f "${plugin_path}/${pattern}" ]]; then
            echo "${plugin_path}/${pattern}"
            return 0
        fi
    done
    
    local zsh_file
    zsh_file=$(find "${plugin_path}" -maxdepth 1 \( -name "*.zsh" -o -name "*.plugin.zsh" \) -type f | head -n 1)
    if [[ -n "${zsh_file}" ]]; then
        echo "${zsh_file}"
        return 0
    fi
    
    return 1
}

# Function to install a plugin from git
zsh_plugin_install() {
    local plugin_name="$1"
    local git_url="$2"
    local plugin_path="${ZSH_PLUGIN_DIR}/${plugin_name}"
    
    if [[ -z "${plugin_name}" ]] || [[ -z "${git_url}" ]]; then
        echo "Usage: zsh_plugin_install <plugin_name> <git_url>"
        return 1
    fi
    
    if [[ -d "${plugin_path}" ]]; then
        echo "✓ ${plugin_name} is already installed."
        return 0
    fi
    
    echo "📦 Installing ${plugin_name}..."
    if git clone --depth=1 --quiet "${git_url}" "${plugin_path}" 2>/dev/null; then
        echo "✓ ${plugin_name} installed successfully!"
        
        # Try to find and display which file will be sourced
        local source_file
        source_file=$(_zsh_plugin_find_source "${plugin_path}")
        if [[ -n "${source_file}" ]]; then
            echo "  → Will source: $(basename "${source_file}")"
        else
            echo "  ⚠ Warning: No standard plugin file found"
        fi
        return 0
    else
        echo "✗ Failed to install ${plugin_name}"
        echo "  Check if the URL is correct: ${git_url}"
        return 1
    fi
}

# Function to update all plugins
zsh_plugins_update() {
    if [[ -f "${ZSH_PLUGIN_LOCK}" ]]; then
        echo "⚠ Update already in progress (lock file exists)"
        echo "  If this is an error, remove: ${ZSH_PLUGIN_LOCK}"
        return 1
    fi
    
    # Create lock file
    touch "${ZSH_PLUGIN_LOCK}" 2>/dev/null
    
    echo "🔄 Updating all ZSH plugins..."
    local updated=0
    local failed=0
    local skipped=0
    
    local plugin_dir plugin_name current_dir
    for plugin_dir in "${ZSH_PLUGIN_DIR}"/*; do
        [[ ! -d "${plugin_dir}" ]] && continue
        [[ "${plugin_dir}" == *"/.update.lock" ]] && continue
        
        plugin_name="$(basename "${plugin_dir}")"
        
        if [[ ! -d "${plugin_dir}/.git" ]]; then
            echo "⊘ Skipping ${plugin_name} (not a git repository)"
            ((skipped++))
            continue
        fi
        
        echo "  Updating ${plugin_name}..."
        
        # Save current directory
        current_dir="$(pwd)"
        
        # Try to update
        if (cd "${plugin_dir}" && git pull --rebase --autostash --quiet 2>/dev/null); then
            echo "  ✓ ${plugin_name} updated"
            ((updated++))
        else
            echo "  ✗ ${plugin_name} failed to update"
            ((failed++))
        fi
        
        # Return to original directory
        cd "${current_dir}" || return 1
    done
    
    # Remove lock file
    rm -f "${ZSH_PLUGIN_LOCK}"
    
    echo ""
    echo "Update Summary:"
    echo "  ✓ Updated: ${updated}"
    echo "  ✗ Failed:  ${failed}"
    echo "  ⊘ Skipped: ${skipped}"
    echo ""
    
    if [[ ${updated} -gt 0 ]]; then
        echo "💡 Run 'exec zsh' or 'source ~/.zshrc' to reload configuration"
    fi
}

# Function to list installed plugins
zsh_plugins_list() {
    echo "📦 Installed ZSH plugins:"
    echo ""
    
    local count=0
    local plugin_dir plugin_name source_file
    for plugin_dir in "${ZSH_PLUGIN_DIR}"/*; do
        [[ ! -d "${plugin_dir}" ]] && continue
        
        plugin_name="$(basename "${plugin_dir}")"
        source_file=$(_zsh_plugin_find_source "${plugin_dir}")
        
        if [[ -d "${plugin_dir}/.git" ]]; then
            echo "  • ${plugin_name} [git]"
        else
            echo "  • ${plugin_name}"
        fi
        
        if [[ -n "${source_file}" ]]; then
            echo "    → $(basename "${source_file}")"
        fi
        
        ((count++))
    done
    
    if [[ ${count} -eq 0 ]]; then
        echo "  (no plugins installed)"
    else
        echo ""
        echo "Total: ${count} plugins"
    fi
}

# Function to remove a plugin
zsh_plugin_remove() {
    local plugin_name="$1"
    local plugin_path="${ZSH_PLUGIN_DIR}/${plugin_name}"
    
    if [[ -z "${plugin_name}" ]]; then
        echo "Usage: zsh_plugin_remove <plugin_name>"
        return 1
    fi
    
    if [[ ! -d "${plugin_path}" ]]; then
        echo "✗ ${plugin_name} is not installed"
        return 1
    fi
    
    echo "Removing ${plugin_name}..."
    if rm -rf "${plugin_path}"; then
        echo "✓ ${plugin_name} removed successfully!"
        echo "💡 Run 'exec zsh' to complete removal"
        return 0
    else
        echo "✗ Failed to remove ${plugin_name}"
        return 1
    fi
}

#eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"

### ENVIRONMENT VARIABLES
# XDG Base Directory Specification
export XDG_BIN_HOME="${HOME}/.local/bin"
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_STATE_HOME="${HOME}/.local/state"

# Backup Directory
export BACKUP_DIR="${HOME}/backup"

# Default Applications
export TERMINAL="kitty"
export BROWSER="brave-browser"
export EDITOR="emacsclient -t -a 'emacs'"
export VISUAL="emacsclient -t -a 'emacs'"
export PAGER="bat --paging=always --style=plain"

# Path Configuration - Use typeset -U to keep unique entries
typeset -U path PATH
path=(
    "${HOME}/bin"
    "${HOME}/.cargo/bin"
    "${HOME}/go/bin"
    "${HOME}/.bun/bin"
    "${HOME}/.cache/.bun/bin"
    "${HOME}/.local/bin"
    "${HOME}/.config/emacs/bin"
    "${HOME}/.npm-global/bin"
    $path
)
export PATH

# Theming
export QS_ICON_THEME=Papirus-Dark

# Tool Configuration
export MANPAGER="nvim +Man!"

# SSH Agent
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/ssh-agent.socket"

### History Configuration
HISTFILE="${XDG_STATE_HOME}/zsh/history"
HISTSIZE=50000
SAVEHIST=50000

# Create history directory if it doesn't exist
[[ ! -d "${XDG_STATE_HOME}/zsh" ]] && mkdir -p "${XDG_STATE_HOME}/zsh"

# History Options
setopt EXTENDED_HISTORY          # Write the history file in the ':start:elapsed;command' format
setopt INC_APPEND_HISTORY        # Write to the history file immediately, not when the shell exits
setopt SHARE_HISTORY             # Share history between all sessions
setopt HIST_EXPIRE_DUPS_FIRST    # Expire a duplicate event first when trimming history
setopt HIST_IGNORE_DUPS          # Do not record an event that was just recorded again
setopt HIST_IGNORE_ALL_DUPS      # Delete an old recorded event if a new event is a duplicate
setopt HIST_FIND_NO_DUPS         # Do not display a previously found event
setopt HIST_IGNORE_SPACE         # Do not record an event starting with a space
setopt HIST_SAVE_NO_DUPS         # Do not write a duplicate event to the history file
setopt HIST_VERIFY               # Do not execute immediately upon history expansion
setopt HIST_REDUCE_BLANKS        # Remove superfluous blanks from each command line

# General Options
setopt AUTO_CD                   # Change directory by typing directory name
setopt AUTO_PUSHD                # Make cd push old directory onto directory stack
setopt PUSHD_IGNORE_DUPS         # Don't push multiple copies of the same directory
setopt PUSHD_SILENT              # Don't print directory stack after pushd/popd
setopt EXTENDED_GLOB             # Use extended globbing syntax
setopt NOMATCH                   # Print error if pattern has no matches
setopt NOTIFY                    # Report status of background jobs immediately
setopt PROMPT_SUBST              # Enable parameter expansion, command substitution, and arithmetic expansion in prompts
setopt INTERACTIVE_COMMENTS      # Allow comments in interactive shell
setopt GLOB_DOTS                 # Match hidden files without explicitly specifying the dot

# Disable beep
unsetopt BEEP

# ============================================================================
# COMPLETION SYSTEM
# ============================================================================

# Initialize completion system
autoload -Uz compinit

# Completion initialization
# Only regenerate .zcompdump once a day for faster startup
() {
    builtin setopt local_options extendedglob
    autoload -Uz compinit
    
    # Check if .zcompdump exists AND is younger than 24 hours (mh-24)
    if [[ -n ${HOME}/.zcompdump(#qN.mh-24) ]]; then
        # File is fresh: use cache, skip security checks (-C) for speed
        compinit -C
    else
        # File is old or missing: run full initialization and regenerate
        compinit
    fi
}

# Load bashcompinit for bash completion compatibility
autoload -Uz bashcompinit && bashcompinit

# Completion styling
zstyle ':completion:*' menu select                          # Enable menu selection
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # Case insensitive completion
# shellcheck disable=SC2296
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"    # Colorize completion lists
zstyle ':completion:*' rehash true                          # Automatically find new executables
zstyle ':completion:*' accept-exact '*(N)'                  # Speed up by accepting exact matches
zstyle ':completion:*' use-cache on                         # Use completion cache
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME}/zsh/zcompcache"
zstyle ':completion:*' squeeze-slashes true                 # Remove duplicate slashes
zstyle ':completion:*' file-sort modification               # Sort files by modification time
zstyle ':completion:*' list-prompt '%SAt %p: Hit TAB for more, or the character to insert%s'
zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'

# Grouping and descriptions
zstyle ':completion:*' group-name ''                        # Group completions by type
zstyle ':completion:*:descriptions' format '[%d]'           # Format for group descriptions
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
zstyle ':completion:*:corrections' format ' %F{green}-- %d (errors: %e) --%f'

# Better completion for kill command
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm -w -w"

# Ignore completion for unwanted files
zstyle ':completion:*:*:vim:*:*files' ignored-patterns '*~' '*.o' '*.pyc'
zstyle ':completion:*:*:nvim:*:*files' ignored-patterns '*~' '*.o' '*.pyc'

# Completion options
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END 
setopt AUTO_MENU 
setopt AUTO_LIST 
setopt AUTO_PARAM_SLASH 
setopt COMPLETE_ALIASES          # Complete aliases
setopt LIST_PACKED               # Make completion lists more compact

unsetopt MENU_COMPLETE           # Don't autoselect the first completion entry
unsetopt FLOW_CONTROL            # Disable start/stop characters (Ctrl+S/Ctrl+Q)

# Load complist module for menu selection
zmodload zsh/complist

# Create cache directory if it doesn't exist
[[ ! -d "${XDG_CACHE_HOME}/zsh/zcompcache" ]] && mkdir -p "${XDG_CACHE_HOME}/zsh/zcompcache"

# Load fzf-tab (after compinit, before autosuggestions and syntax highlighting)
if [[ -f "${ZSH_PLUGIN_DIR}/fzf-tab/fzf-tab.plugin.zsh" ]]; then
    source "${ZSH_PLUGIN_DIR}/fzf-tab/fzf-tab.plugin.zsh"
    
    # Configuration for fzf-tab
    # Disable sort when completing git checkout
    zstyle ':completion:*:git-checkout:*' sort false
    
    # Set descriptions format to enable group support
    zstyle ':completion:*:descriptions' format '[%d]'
    
    # Force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
    zstyle ':completion:*' menu no
    
    # Preview directory's content with eza when completing cd
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons $realpath 2>/dev/null || ls -1 --color=always $realpath'
    
    # Preview files with bat
    zstyle ':fzf-tab:complete:*:*' fzf-preview 'if [[ -f $realpath ]]; then bat --color=always --style=numbers --line-range :500 $realpath 2>/dev/null; elif [[ -d $realpath ]]; then eza --tree --level=2 --color=always --icons $realpath 2>/dev/null || ls -1 --color=always $realpath; fi'
    
    # Use FZF_DEFAULT_OPTS for fzf-tab
    zstyle ':fzf-tab:*' use-fzf-default-opts yes
    
    # Switch group using `,` and `.`
    zstyle ':fzf-tab:*' switch-group ',' '.'
    
    # Custom fzf flags (optional)
    # zstyle ':fzf-tab:*' fzf-flags --height=80% --layout=reverse
fi

# ============================================================================
# KEY BINDINGS
# ============================================================================

# Vi mode
bindkey -v

# Reduce ESC delay for vi mode (10ms)
export KEYTIMEOUT=1

# Change cursor shape for different vi modes
function zle-keymap-select {
    if [[ ${KEYMAP} == vicmd ]] || [[ $1 = 'block' ]]; then
        echo -ne '\e[1 q'  # Block cursor
    elif [[ ${KEYMAP} == main ]] || [[ ${KEYMAP} == viins ]] || [[ ${KEYMAP} = '' ]] || [[ $1 = 'beam' ]]; then
        echo -ne '\e[5 q'  # Beam cursor
    fi
}
zle -N zle-keymap-select

# Initialize cursor to beam on startup
function zle-line-init {
    echo -ne '\e[5 q'  # Beam cursor
}
zle -N zle-line-init

# Reset cursor to block on exit
function zle-line-finish {
    echo -ne '\e[1 q'  # Block cursor
}
zle -N zle-line-finish

# Use vim keys in tab complete menu
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -M menuselect '^M' .accept-line  # Enter to accept

# Fix backspace and delete
bindkey -v '^?' backward-delete-char
bindkey -v '^H' backward-delete-char
bindkey -v '^[[3~' delete-char
bindkey -v '^[[P' delete-char

# Navigate word by word
bindkey '^[[1;5C' forward-word      # Ctrl+Right
bindkey '^[[1;5D' backward-word     # Ctrl+Left
bindkey '^[[1;3C' forward-word      # Alt+Right
bindkey '^[[1;3D' backward-word     # Alt+Left

# Home and End keys
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line

# Search history (works in both vi insert and command mode)
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward
bindkey -M vicmd '/' history-incremental-search-backward
bindkey -M vicmd '?' history-incremental-search-forward

# Bind 'jk' to escape insert mode (like in fish config)
# Using a more robust method that works better
bindkey -M viins 'jk' vi-cmd-mode

# Alternative: Use 'jj' as well for those who prefer it
# bindkey -M viins 'jj' vi-cmd-mode

# Edit command line in $EDITOR
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'v' edit-command-line
bindkey '^X^E' edit-command-line  # Emacs-style binding too

# Undo/Redo in vi mode
bindkey -M vicmd 'u' undo
bindkey -M vicmd '^R' redo

# Ctrl+U to delete line
bindkey '^U' backward-kill-line

# Ctrl+K to delete to end of line
bindkey '^K' kill-line

# Ctrl+W to delete word
bindkey '^W' backward-kill-word

# Ctrl+Y to paste (yank)
bindkey '^Y' yank

# ============================================================================
# LOAD PLUGINS
# ============================================================================

# Ensure plugin directory exists
[[ ! -d "${ZSH_PLUGIN_DIR}" ]] && mkdir -p "${ZSH_PLUGIN_DIR}"

# Plugin list: name and git URL
# Fixed: Changed to indexed arrays for better bash compatibility
declare -a ZSH_PLUGIN_NAMES=(
    "zsh-autosuggestions"
    "fast-syntax-highlighting"
    "zsh-completions"
    "zsh-history-substring-search"
    "fzf-tab"
    "zsh-autopair"
)

declare -a ZSH_PLUGIN_URLS=(
    "https://github.com/zsh-users/zsh-autosuggestions.git"
    "https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
    "https://github.com/zsh-users/zsh-completions.git"
    "https://github.com/zsh-users/zsh-history-substring-search.git"
    "https://github.com/Aloxaf/fzf-tab.git"
    "https://github.com/hlissner/zsh-autopair.git"
)

# Auto-install missing plugins on first run
# Fixed: Use C-style for loop for better shellcheck compatibility
typeset i plugin_name plugin_url
for ((i=1; i<=${#ZSH_PLUGIN_NAMES[@]}; i++)); do
    plugin_name="${ZSH_PLUGIN_NAMES[$i]}"
    plugin_url="${ZSH_PLUGIN_URLS[$i]}"
    
    if [[ ! -d "${ZSH_PLUGIN_DIR}/${plugin_name}" ]]; then
        zsh_plugin_install "${plugin_name}" "${plugin_url}"
    fi
done

# Load zsh-completions (must be before compinit)
if [[ -d "${ZSH_PLUGIN_DIR}/zsh-completions" ]]; then
    # shellcheck disable=SC2206
    fpath=("${ZSH_PLUGIN_DIR}/zsh-completions/src" $fpath)
fi

# Load fzf-tab (must be after compinit but before autosuggestions and syntax highlighting)
# Note: We'll load it after compinit in the completion section

# Load zsh-autopair (auto-close brackets, quotes, etc.)
if [[ -f "${ZSH_PLUGIN_DIR}/zsh-autopair/autopair.zsh" ]]; then
    source "${ZSH_PLUGIN_DIR}/zsh-autopair/autopair.zsh"
    
    # Configuration
    AUTOPAIR_INHIBIT_INIT=1
    autopair-init
fi

# Load fast-syntax-highlighting (should be loaded before zsh-autosuggestions)
if [[ -f "${ZSH_PLUGIN_DIR}/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]]; then
    source "${ZSH_PLUGIN_DIR}/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
    
    # Configuration - use custom highlighters
    FAST_HIGHLIGHT_STYLES[${FAST_THEME_NAME}path]='fg=cyan'
    FAST_HIGHLIGHT_STYLES[${FAST_THEME_NAME}command]='fg=green'
    FAST_HIGHLIGHT_STYLES[${FAST_THEME_NAME}alias]='fg=green'
    FAST_HIGHLIGHT_STYLES[${FAST_THEME_NAME}function]='fg=green'
fi

# Load zsh-autosuggestions
if [[ -f "${ZSH_PLUGIN_DIR}/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "${ZSH_PLUGIN_DIR}/zsh-autosuggestions/zsh-autosuggestions.zsh"
    
    # Configuration
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
    ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
    ZSH_AUTOSUGGEST_USE_ASYNC=1
    ZSH_AUTOSUGGEST_MANUAL_REBIND=1  # Better performance
    
    # Accept autosuggestion with Ctrl+Space
    bindkey '^ ' autosuggest-accept
    
    # Accept autosuggestion with right arrow (fish-like)
    bindkey '^[[C' forward-char
    
    # Accept one word at a time with Ctrl+Right Arrow
    bindkey '^[[1;5C' forward-word
fi

# Load zsh-history-substring-search
if [[ -f "${ZSH_PLUGIN_DIR}/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
    source "${ZSH_PLUGIN_DIR}/zsh-history-substring-search/zsh-history-substring-search.zsh"
    
    # Bind UP and DOWN arrow keys (must be after plugin is loaded)
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
    
    # Bind k and j for Vi mode
    bindkey -M vicmd 'k' history-substring-search-up
    bindkey -M vicmd 'j' history-substring-search-down
    
    # Configuration
    HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
    HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='bg=green,fg=black'
    HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='bg=red,fg=white'
fi

### CUSTOM FUNCTIONS

# Make su launch zsh
su() {
    command su --shell=/bin/zsh "$@"
}

# Sudo plugin functionality - press ESC twice to add sudo to the current/previous command
sudo-command-line() {
    [[ -z $BUFFER ]] && LBUFFER="$(fc -ln -1)"
    
    # Check if command starts with sudo
    if [[ $BUFFER == sudo\ * ]]; then
        # If it does, remove it
        LBUFFER="${LBUFFER#sudo }"
    else
        # If it doesn't, add it
        LBUFFER="sudo $LBUFFER"
    fi
}
zle -N sudo-command-line

# Bind ESC ESC to sudo-command-line
bindkey '\e\e' sudo-command-line
bindkey -M vicmd '\e\e' sudo-command-line
bindkey -M viins '\e\e' sudo-command-line

# Extract function - extract various archive types
extract() {
    if [[ -z "$1" ]]; then
        echo "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
        return 1
    fi
    
    if [[ -f "$1" ]]; then
        case "$1" in
            *.tar.bz2)   tar xvjf "$1"    ;;
            *.tar.gz)    tar xvzf "$1"    ;;
            *.tar.xz)    tar xvJf "$1"    ;;
            *.lzma)      unlzma "$1"      ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x -ad "$1" ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xvf "$1"     ;;
            *.tbz2)      tar xvjf "$1"    ;;
            *.tgz)       tar xvzf "$1"    ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *.xz)        unxz "$1"        ;;
            *.exe)       cabextract "$1"  ;;
            *)           echo "extract: '$1' - unknown archive method" ;;
        esac
    else
        echo "'$1' - file does not exist"
        return 1
    fi
}

# Create directory and cd into it
mkcd() {
    mkdir -p "$@" && cd "${@: -1}"
}

# Quickly go up multiple directories
up() {
    local d=""
    local limit="$1"
    
    # Default to 1 level up if no argument
    if [[ -z "$limit" ]] || [[ "$limit" -le 0 ]]; then
        limit=1
    fi
    
    local i
    for ((i=1;i<=limit;i++)); do
        d="../$d"
    done
    
    # Remove trailing slash
    d="${d%/}"
    
    # If no limit was passed, use ../
    if [[ -z "$d" ]]; then
        d=".."
    fi
    
    cd "$d" || return 1
}

# Command-not-found handler
command_not_found_handler() {
    local cmd="$1"
    local suggestions
    suggestions=($(compgen -c | grep -i "^$cmd"))
    
    printf "zsh: command not found: %s\n" "$cmd" >&2
    
    if [[ ${#suggestions[@]} -gt 0 ]]; then
        echo "\nDid you mean one of these?" >&2
        printf "  %s\n" "${suggestions[@]:0:5}" >&2
    fi
    
    return 127
}

### ALIASES
alias upgrade="topgrade"
alias listPkgs='paru -Qq > packages.list'
alias delOrphans='paru -Rns $(paru -Qtdq)'
alias delCache='paru -Scc'
alias tuimacs="emacsclient -t -a 'emacs'"
alias cat='bat --paging=never'
alias du='dust'
alias eza='eza --icons auto --git --group-directories-first --header'
alias fd='fd --hidden --no-ignore --absolute-path'
alias gg='lazygit'
alias hm-switch='home-manager switch'
alias la='eza -a'
alias ll='eza -l'
alias lla='eza -la'
alias ls='eza'
alias lt='eza --tree'
alias vi='nvim'
alias box-stop='distrobox-stop --all --yes'
alias box-rm='distrobox-rm --all --force'
alias zsh-update='zsh_plugins_update'
alias zsh-plugins='zsh_plugins_list'

### FZF CONFIGURATION
# Setup fzf (if installed)
if command -v fzf &> /dev/null; then
    # Try to source fzf key bindings and completion from various locations
    local fzf_locations=(
        "/usr/share/fzf/key-bindings.zsh"
        "/usr/share/fzf/completion.zsh"
        "/usr/share/doc/fzf/examples/key-bindings.zsh"
        "/usr/share/doc/fzf/examples/completion.zsh"
        "${HOME}/.fzf/shell/key-bindings.zsh"
        "${HOME}/.fzf/shell/completion.zsh"
        "/usr/local/opt/fzf/shell/key-bindings.zsh"
        "/usr/local/opt/fzf/shell/completion.zsh"
    )
    
    local location
    for location in "${fzf_locations[@]}"; do
        [[ -f "$location" ]] && source "$location"
    done
    
    # FZF default options (matching fish config)
    export FZF_DEFAULT_OPTS="\
        --layout=reverse \
        --exact \
        --border=bold \
        --border=rounded \
        --margin=5%  \
        --height=85% \
        --info=inline \
        --preview-window=right:50%:wrap \
        --color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8 \
        --color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC \
        --color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8 \
        --color=selected-bg:#45475A \
        --color=border:#6C7086,label:#CDD6F4"
    
    # FZF preview command (matching fish config)
    export FZF_PREVIEW_COMMAND='
    if [[ -f {} ]]; then
        bat --color=always --style=numbers --line-range :500 {} 2>/dev/null || cat {}
    else
        eza --tree --level=2 --color=always --icons {} 2>/dev/null || ls -l {}
    fi'
    
    # Use fd for FZF if available (faster than find)
    if command -v fd &> /dev/null; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --no-ignore --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --hidden --no-ignore --follow --exclude .git'
    elif command -v rg &> /dev/null; then
        export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    fi
    
    # FZF file preview (Ctrl+T)
    export FZF_CTRL_T_OPTS="--preview '$FZF_PREVIEW_COMMAND' --bind 'ctrl-/:toggle-preview' --bind 'ctrl-y:execute-silent(echo -n {+} | xclip -selection clipboard)'"
    
    # FZF directory preview (Alt+C)
    export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always --icons {} 2>/dev/null || ls -l {}' --bind 'ctrl-/:toggle-preview'"
    
    # FZF history configuration (Ctrl+R)
    export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window up:3:hidden:wrap --bind 'ctrl-/:toggle-preview' --bind 'ctrl-y:execute-silent(echo -n {2..} | xclip -selection clipboard)+abort' --color header:italic --header 'Press CTRL-Y to copy command into clipboard'"
    
    # Custom FZF functions
    
    # fkill - kill process
    fkill() {
        local pid
        pid=$(ps -ef | sed 1d | fzf -m --header='Select process to kill' | awk '{print $2}')
        
        if [[ -n "$pid" ]]; then
            echo "$pid" | xargs kill -"${1:-9}"
        fi
    }
    
    # fcd - cd to selected directory
    fcd() {
        local dir
        dir=$(find ${1:-.} -path '*/\.*' -prune -o -type d -print 2> /dev/null | fzf +m --header='Select directory') && cd "$dir"
    }
    
    # fvim - open file in vim/nvim
    fvim() {
        local file
        file=$(fzf --preview="$FZF_PREVIEW_COMMAND" --header='Select file to edit')
        [[ -n "$file" ]] && ${EDITOR:-vim} "$file"
    }
    
    # fh - repeat history
    fh() {
        print -z $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed -E 's/ *[0-9]*\*? *//' | sed -E 's/\\/\\\\/g')
    }
fi

### TOOL INTEGRATIONS
# Zoxide (better cd)
if command -v zoxide &> /dev/null; then
   eval "$(zoxide init zsh)"
   export _ZO_EXCLUDE_DIRS="$HOME:$HOME/private/*:/tmp/*:*/.git/*"
   export _ZO_ECHO=1
   alias zz='zi'
fi

# Starship prompt
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# Pay-respects (modern sudo replacement with better UX)
if command -v pay-respects &> /dev/null; then
    eval "$(pay-respects zsh --alias)"
fi

# Atuin (magical shell history)
if command -v atuin &> /dev/null; then
    eval "$(atuin init zsh)"
fi

# UV (Python package manager)
if command -v uv &> /dev/null; then
    eval "$(uv generate-shell-completion zsh)"
fi

# UVX (UV tool runner)
if command -v uvx &> /dev/null; then
    eval "$(uvx --generate-shell-completion zsh)"
fi

# Direnv (environment switcher)
if command -v direnv &> /dev/null; then
    eval "$(direnv hook zsh)"
fi

# pixi
if command -v piri &> /dev/null; then
    eval "$(pixi completion --shell zsh)"
fi


### ADDITIONAL QUALITY OF LIFE FEATURES
# Colored man pages (multiple methods for compatibility)
# Method 1: Using LESS_TERMCAP (works with most pagers)
export LESS_TERMCAP_mb=$'\e[1;32m'      # Begin bold
export LESS_TERMCAP_md=$'\e[1;34m'      # Begin blink
export LESS_TERMCAP_me=$'\e[0m'         # Reset bold/blink
export LESS_TERMCAP_so=$'\e[01;47;34m'  # Begin reverse video
export LESS_TERMCAP_se=$'\e[0m'         # Reset reverse video
export LESS_TERMCAP_us=$'\e[1;4;31m'    # Begin underline
export LESS_TERMCAP_ue=$'\e[0m'         # Reset underline

# Method 2: For groff/man (alternative)
export GROFF_NO_SGR=1

# Better less options
export LESS='-R -i -M -F -X'  # -R: raw control chars, -i: ignore case, -M: long prompt, -F: quit if one screen, -X: no init

# Enable automatic URL quoting
autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic

# Rehash automatically when new executables are installed
zshcache_time="$(date +%s%N)"

autoload -Uz add-zsh-hook

# Enable zmv for advanced file renaming
autoload -Uz zmv

# Use modern command colors with LS_COLORS
if command -v dircolors >/dev/null 2>&1; then
    eval "$(dircolors -b)"
fi

# Colorize ls output
export CLICOLOR=1
export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd

# Better history command output
alias history='fc -li 1'

# Auto-correct typos in cd commands
#setopt CORRECT
#setopt CORRECT_ALL

# Don't hang up background jobs on exit
setopt NO_HUP
setopt NO_CHECK_JOBS

# URL encoding/decoding functions
urlencode() {
    python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$1"
}

urldecode() {
    python3 -c "import sys, urllib.parse; print(urllib.parse.quote_plus(sys.argv[1]))" "$1"
}

### PERFORMANCE TWEAKS
DISABLE_AUTO_TITLE="true"
ZSH_DISABLE_COMPFIX="true"

# # Lazy load conda/mamba
# function conda() {
#     unset -f conda mamba
#     if [ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]; then
#         . "$HOME/miniforge3/etc/profile.d/conda.sh"
#     fi
#     conda "$@"
# }
#
# function mamba() {
#     unset -f conda mamba
#     if [ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]; then
#         . "$HOME/miniforge3/etc/profile.d/conda.sh"
#     fi
#     mamba "$@"
# }

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

export PATH="/home/ahsan/.pixi/bin:$PATH"

# bun completions
[ -s "/home/ahsan/.bun/_bun" ] && source "/home/ahsan/.bun/_bun"
