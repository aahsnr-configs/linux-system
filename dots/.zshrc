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

### ENVIRONMENT VARIABLES
export XDG_BIN_HOME="${HOME}/.local/bin"
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_STATE_HOME="${HOME}/.local/state"

export BACKUP_DIR="${HOME}/backup"

export TERMINAL="kitty"
export BROWSER="brave"
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"
export BAT_PAGER="less -R -F -K"

# Path Configuration
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

export QS_ICON_THEME=Papirus-Dark
export MANPAGER="nvim +Man!"
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/ssh-agent.socket"

### History Configuration
HISTFILE="${XDG_STATE_HOME}/zsh/history"
HISTSIZE=50000
SAVEHIST=50000

[[ ! -d "${XDG_STATE_HOME}/zsh" ]] && mkdir -p "${XDG_STATE_HOME}/zsh"

setopt EXTENDED_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt HIST_VERIFY
setopt HIST_REDUCE_BLANKS

### General Options
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt EXTENDED_GLOB
setopt NOMATCH
setopt NOTIFY
setopt PROMPT_SUBST
setopt INTERACTIVE_COMMENTS
setopt GLOB_DOTS

unsetopt BEEP

# ============================================================================
# PLUGIN PROVISIONING (Must happen before completion setup)
# ============================================================================
[[ ! -d "${ZSH_PLUGIN_DIR}" ]] && mkdir -p "${ZSH_PLUGIN_DIR}"

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
typeset i plugin_name plugin_url
for ((i = 1; i <= ${#ZSH_PLUGIN_NAMES[@]}; i++)); do
    plugin_name="${ZSH_PLUGIN_NAMES[$i]}"
    plugin_url="${ZSH_PLUGIN_URLS[$i]}"

    if [[ ! -d "${ZSH_PLUGIN_DIR}/${plugin_name}" ]]; then
        zsh_plugin_install "${plugin_name}" "${plugin_url}"
    fi
done

# ============================================================================
# COMPLETION SYSTEM INITIALIZATION
# ============================================================================

# 1. Extend fpath with third-party completions BEFORE calling compinit
if [[ -d "${ZSH_PLUGIN_DIR}/zsh-completions/src" ]]; then
    fpath=("${ZSH_PLUGIN_DIR}/zsh-completions/src" $fpath)
fi
fpath=(${ASDF_DATA_DIR:-$HOME/.asdf}/completions $fpath)

# 2. Run compinit ONCE with optimized 24-hour cache compilation
() {
    builtin setopt local_options extendedglob
    autoload -Uz compinit

    if [[ -n ${HOME}/.zcompdump(#qN.mh-24) ]]; then
        compinit -C
    else
        compinit
    fi
}

autoload -Uz bashcompinit && bashcompinit

# Completion styling
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
# shellcheck disable=SC2296
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' rehash true
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME}/zsh/zcompcache"
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' file-sort modification
zstyle ':completion:*' list-prompt '%SAt %p: Hit TAB for more, or the character to insert%s'
zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'

# Grouping and descriptions
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '[%d]'
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
setopt LIST_PACKED

# FIX: COMPLETE_ALIASES breaks complex completion maps like git. Turn off to avoid shell hangs.
unsetopt COMPLETE_ALIASES

unsetopt MENU_COMPLETE
unsetopt FLOW_CONTROL

zmodload zsh/complist

[[ ! -d "${XDG_CACHE_HOME}/zsh/zcompcache" ]] && mkdir -p "${XDG_CACHE_HOME}/zsh/zcompcache"

# Load fzf-tab (Immediately after completion system definitions)
if [[ -f "${ZSH_PLUGIN_DIR}/fzf-tab/fzf-tab.plugin.zsh" ]]; then
    source "${ZSH_PLUGIN_DIR}/fzf-tab/fzf-tab.plugin.zsh"

    zstyle ':completion:*:git-checkout:*' sort false
    zstyle ':completion:*:descriptions' format '[%d]'
    zstyle ':completion:*' menu no

    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons $realpath 2>/dev/null || ls -1 --color=always $realpath'
    zstyle ':fzf-tab:complete:*:*' fzf-preview 'if [[ -f $realpath ]]; then bat --color=always --style=numbers --line-range :500 $realpath 2>/dev/null; elif [[ -d $realpath ]]; then eza --tree --level=2 --color=always --icons $realpath 2>/dev/null || ls -1 --color=always $realpath; fi'
    zstyle ':fzf-tab:*' use-fzf-default-opts yes
    zstyle ':fzf-tab:*' switch-group ',' '.'
fi

# ============================================================================
# KEY BINDINGS & VI MODE
# ============================================================================
bindkey -v
export KEYTIMEOUT=1

function zle-keymap-select {
    if [[ ${KEYMAP} == vicmd ]] || [[ $1 = 'block' ]]; then
        echo -ne '\e[1 q'
    elif [[ ${KEYMAP} == main ]] || [[ ${KEYMAP} == viins ]] || [[ ${KEYMAP} = '' ]] || [[ $1 = 'beam' ]]; then
        echo -ne '\e[5 q'
    fi
}
zle -N zle-keymap-select

function zle-line-init {
    echo -ne '\e[5 q'
}
zle -N zle-line-init

function zle-line-finish {
    echo -ne '\e[1 q'
}
zle -N zle-line-finish

bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -M menuselect '^M' .accept-line

bindkey -v '^?' backward-delete-char
bindkey -v '^H' backward-delete-char
bindkey -v '^[[3~' delete-char
bindkey -v '^[[P' delete-char

bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[1;3C' forward-word
bindkey '^[[1;3D' backward-word

bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line

bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward
bindkey -M vicmd '/' history-incremental-search-backward
bindkey -M vicmd '?' history-incremental-search-forward

bindkey -M viins 'jk' vi-cmd-mode

autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'v' edit-command-line
bindkey '^X^E' edit-command-line

bindkey -M vicmd 'u' undo
bindkey -M vicmd '^R' redo

bindkey '^U' backward-kill-line
bindkey '^K' kill-line
bindkey '^W' backward-kill-word
bindkey '^Y' yank

# ============================================================================
# LOAD REMAINING PLUGINS
# ============================================================================

# Load zsh-autopair
if [[ -f "${ZSH_PLUGIN_DIR}/zsh-autopair/autopair.zsh" ]]; then
    source "${ZSH_PLUGIN_DIR}/zsh-autopair/autopair.zsh"
    AUTOPAIR_INHIBIT_INIT=1
    autopair-init
fi

# Load fast-syntax-highlighting (Must load before autosuggestions)
if [[ -f "${ZSH_PLUGIN_DIR}/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]]; then
    source "${ZSH_PLUGIN_DIR}/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
    FAST_HIGHLIGHT_STYLES[${FAST_THEME_NAME}path]='fg=cyan'
    FAST_HIGHLIGHT_STYLES[${FAST_THEME_NAME}command]='fg=green'
    FAST_HIGHLIGHT_STYLES[${FAST_THEME_NAME}alias]='fg=green'
    FAST_HIGHLIGHT_STYLES[${FAST_THEME_NAME}function]='fg=green'
fi

# Load zsh-autosuggestions
if [[ -f "${ZSH_PLUGIN_DIR}/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "${ZSH_PLUGIN_DIR}/zsh-autosuggestions/zsh-autosuggestions.zsh"

    # FIX: Removed 'completion' strategy. It causes severe performance lockups/deadlocks when paired with fzf-tab in git folders.
    ZSH_AUTOSUGGEST_STRATEGY=(history)
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
    ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
    ZSH_AUTOSUGGEST_USE_ASYNC=1
    ZSH_AUTOSUGGEST_MANUAL_REBIND=1

    bindkey '^ ' autosuggest-accept
    bindkey '^[[C' forward-char
    bindkey '^[[1;5C' forward-word
fi

# Load zsh-history-substring-search
if [[ -f "${ZSH_PLUGIN_DIR}/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
    source "${ZSH_PLUGIN_DIR}/zsh-history-substring-search/zsh-history-substring-search.zsh"

    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
    bindkey -M vicmd 'k' history-substring-search-up
    bindkey -M vicmd 'j' history-substring-search-down

    HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
    HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='bg=green,fg=black'
    HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='bg=red,fg=white'
fi

# ============================================================================
# CUSTOM FUNCTIONS & ALIASES
# ============================================================================
su() {
    command su --shell=/bin/zsh "$@"
}

sudo-command-line() {
    [[ -z $BUFFER ]] && LBUFFER="$(fc -ln -1)"
    if [[ $BUFFER == sudo\ * ]]; then
        LBUFFER="${LBUFFER#sudo }"
    else
        LBUFFER="sudo $LBUFFER"
    fi
}
zle -N sudo-command-line

bindkey '\e\e' sudo-command-line
bindkey -M vicmd '\e\e' sudo-command-line
bindkey -M viins '\e\e' sudo-command-line

extract() {
    if [[ -z "$1" ]]; then
        echo "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
        return 1
    fi

    if [[ -f "$1" ]]; then
        case "$1" in
        *.tar.bz2) tar xvjf "$1" ;;
        *.tar.gz) tar xvzf "$1" ;;
        *.tar.xz) tar xvJf "$1" ;;
        *.lzma) unlzma "$1" ;;
        *.bz2) bunzip2 "$1" ;;
        *.rar) unrar x -ad "$1" ;;
        *.gz) gunzip "$1" ;;
        *.tar) tar xvf "$1" ;;
        *.tbz2) tar xvjf "$1" ;;
        *.tgz) tar xvzf "$1" ;;
        *.zip) unzip "$1" ;;
        *.Z) uncompress "$1" ;;
        *.7z) 7z x "$1" ;;
        *.xz) unxz "$1" ;;
        *.exe) cabextract "$1" ;;
        *) echo "extract: '$1' - unknown archive method" ;;
        esac
    else
        echo "'$1' - file does not exist"
        return 1
    fi
}

mkcd() {
    mkdir -p "$@" && cd "${@: -1}"
}

up() {
    local d=""
    local limit="$1"

    if [[ -z "$limit" ]] || [[ "$limit" -le 0 ]]; then
        limit=1
    fi

    local i
    for ((i = 1; i <= limit; i++)); do
        d="../$d"
    done

    d="${d%/}"
    if [[ -z "$d" ]]; then
        d=".."
    fi

    cd "$d" || return 1
}

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

alias suse="podman run --rm -it suse-checker"
alias gc="git clone"
alias ga="git add"
alias gp="git push"
alias aic="aicommits"
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
alias clr='clear'

# ============================================================================
# FZF CONFIGURATION
# ============================================================================
if command -v fzf &>/dev/null; then
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

    export FZF_PREVIEW_COMMAND='
    if [[ -f {} ]]; then
        bat --color=always --style=numbers --line-range :500 {} 2>/dev/null || cat {}
    else
        eza --tree --level=2 --color=always --icons {} 2>/dev/null || ls -l {}
    fi'

    if command -v fd &>/dev/null; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --no-ignore --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --hidden --no-ignore --follow --exclude .git'
    elif command -v rg &>/dev/null; then
        export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    fi

    export FZF_CTRL_T_OPTS="--preview '$FZF_PREVIEW_COMMAND' --bind 'ctrl-/:toggle-preview' --bind 'ctrl-y:execute-silent(echo -n {+} | xclip -selection clipboard)'"
    export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always --icons {} 2>/dev/null || ls -l {}' --bind 'ctrl-/:toggle-preview'"
    export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window up:3:hidden:wrap --bind 'ctrl-/:toggle-preview' --bind 'ctrl-y:execute-silent(echo -n {2..} | xclip -selection clipboard)+abort' --color header:italic --header 'Press CTRL-Y to copy command into clipboard'"

    fkill() {
        local pid
        pid=$(ps -ef | sed 1d | fzf -m --header='Select process to kill' | awk '{print $2}')
        if [[ -n "$pid" ]]; then
            echo "$pid" | xargs kill -"${1:-9}"
        fi
    }

    fcd() {
        local dir
        dir=$(find ${1:-.} -path '*/\.*' -prune -o -type d -print 2>/dev/null | fzf +m --header='Select directory') && cd "$dir"
    }

    fvim() {
        local file
        file=$(fzf --preview="$FZF_PREVIEW_COMMAND" --header='Select file to edit')
        [[ -n "$file" ]] && ${EDITOR:-vim} "$file"
    }

    fh() {
        print -z $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed -E 's/ *[0-9]*\*? *//' | sed -E 's/\\/\\\\/g')
    }
fi

# ============================================================================
# TOOL INTEGRATIONS & QUALITY OF LIFE
# ============================================================================
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
    export _ZO_EXCLUDE_DIRS="$HOME:$HOME/private/*:/tmp/*:*/.git/*"
    export _ZO_ECHO=1
    alias zz='zi'
fi

if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi

if command -v pay-respects &>/dev/null; then
    eval "$(pay-respects zsh --alias)"
fi

if command -v atuin &>/dev/null; then
    eval "$(atuin init zsh)"
fi

# if command -v mise &>/dev/null; then
#     eval "$(mise activate zsh)"
# fi

if command -v uv &>/dev/null; then
    eval "$(uv generate-shell-completion zsh)"
fi

if command -v uvx &>/dev/null; then
    eval "$(uvx --generate-shell-completion zsh)"
fi

if command -v direnv &>/dev/null; then
    eval "$(direnv hook zsh)"
fi

if command -v pixi &>/dev/null; then
    eval "$(pixi completion --shell zsh)"
fi

export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;34m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;47;34m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'
export LESS_TERMCAP_ue=$'\e[0m'

export GROFF_NO_SGR=1
export LESS='-R -i -M -F -X'

autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic

zshcache_time="$(date +%s%N)"
autoload -Uz add-zsh-hook
autoload -Uz zmv

if command -v dircolors >/dev/null 2>&1; then
    eval "$(dircolors -b)"
fi

export CLICOLOR=1
export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd

alias history='fc -li 1'

setopt NO_HUP
setopt NO_CHECK_JOBS

urlencode() {
    python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$1"
}

urldecode() {
    python3 -c "import sys, urllib.parse; print(urllib.parse.quote_plus(sys.argv[1]))" "$1"
}

### PERFORMANCE TWEAKS
DISABLE_AUTO_TITLE="true"
ZSH_DISABLE_COMPFIX="true"

function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    command yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd <"$tmp"
    [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
}
export GPG_TTY=$(tty)

export npm_config_prefix="$HOME/.local"

export PATH="/home/ahsan/.pixi/bin:$PATH"

# pnpm
export PNPM_HOME="/home/ahsan/.local/share/pnpm"
case ":$PATH:" in
*":$PNPM_HOME/bin:"*) ;;
*) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

# Ghostel IDE Integration
if [[ "${INSIDE_EMACS%%,*}" = 'ghostel' ]]; then
    # Open a file in Emacs from the terminal (e.g., `e main.py`)
    alias e='ghostel_cmd find-file-other-window'

    # Open Dired in another window at the current directory
    alias dow='ghostel_cmd dired-other-window'

    # Open Magit for the current directory
    alias gst='ghostel_cmd magit-status-setup-buffer'
fi

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
