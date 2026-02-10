# --- Environment Variables ---
# Ported from 99-custom-env.sh
# Using -gx to make them global and exported

# XDG Base Directory Specification
set -gx XDG_BIN_HOME $HOME/.local/bin
set -gx XDG_CACHE_HOME $HOME/.cache
set -gx XDG_CONFIG_HOME $HOME/.config
set -gx XDG_DATA_HOME $HOME/.local/share
set -gx XDG_STATE_HOME $HOME/.local/state

# Backup Directory
set -gx BACKUP_DIR $HOME/backup

# Default Applications
set -gx TERMINAL kitty
set -gx BROWSER brave
set -gx EDITOR nvim
set -gx VISUAL "emacsclient -c -a emacs"
set -gx PAGER "bat --paging=always --style=plain"

fish_add_path $HOME/.cargo/bin
fish_add_path $HOME/go/bin
fish_add_path $HOME/.bun/bin
fish_add_path $HOME/.local/bin
fish_add_path $HOME/.config/emacs/bin
fish_add_path $HOME/.npm-global/bin
fish_add_path $HOME/.local/share/flatpak/exports/bin
fish_add_path /usr/local/texlive/2025/bin/x86_64-linux
fish_add_path $HOME/.bun/bin

set -gx MANPATH $MANPATH /usr/local/texlive/2025/texmf-dist/doc/man
set -gx INFOPATH $INFOPATH /usr/local/texlive/2025/texmf-dist/doc/info

# --- Tool Configuration ---

# "nvim" as manpager
set -x MANPAGER "nvim +Man!"

# SET EITHER DEFAULT EMACS MODE OR VI MODE ###
function fish_user_key_bindings
    # fish_default_key_bindings
    fish_vi_key_bindings
end

# Function for org-agenda
function org-search -d "send a search string to org-mode"
    set -l output (/usr/bin/emacsclient -a "" -e "(message \"%s\" (mapconcat #'substring-no-properties \
        (mapcar #'org-link-display-format \
        (org-ql-query \
        :select #'org-get-heading \
        :from  (org-agenda-files) \
        :where (org-ql--query-string-to-sexp \"$argv\"))) \
        \"
    \"))")
    printf $output
end

# Make su launch fish
function su
    command su --shell=/usr/bin/fish $argv
end

# Aliases
alias listPkgs='paru -Qq > packages.list'
alias cat='bat --paging=never'
alias du='dust'
alias eza='eza --icons auto --git --group-directories-first --header'
alias fd='fd --hidden --no-ignore --absolute-path'
alias gg='lazygit'
alias grep='rg'
alias hm-switch='home-manager switch'
alias la='eza -a'
alias ll='eza -l'
alias lla='eza -la'
alias ls='eza'
alias lt='eza --tree'
alias nixs='nix-shell -p'
alias rmi='safe-rm'
alias sctl='systemctl'
alias sctle='sudo systemctl enable'
alias sctls='sudo systemctl start'
alias vi='nvim'
alias box-stop='distrobox-stop --all --yes'
alias box-rm='distrobox-rm --all --force'
alias brave='flatpak run com.brave.Browser'

# Options
set fish_greeting
set -g fish_key_bindings fish_vi_key_bindings

# Bind 'jk' to escape insert mode
bind -M insert jk 'set fish_bind_mode default; commandline -f repaint'

# Setup fzf
fzf --fish | source
set FZF_DEFAULT_OPTS "--layout=reverse --exact --border=bold --border=rounded --margin=3% --color=dark"

# Configure fzf previews for files (bat) and directories (eza)
set -x FZF_PREVIEW_COMMAND '
if test -f {};
  bat --color=always --style=numbers --line-range :500 {};
else;
  eza --tree --level=2 {};
 end'

# More Tools
zoxide init fish | source
starship init fish | source
pay-respects fish --alias | source
atuin init fish | source

echo 'uv generate-shell-completion fish | source' > ~/.config/fish/completions/uv.fish
echo 'uvx --generate-shell-completion fish | source' > ~/.config/fish/completions/uvx.fish
#direnv hook fish | source

set -x SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
