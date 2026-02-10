#!/bin/sh

sudo dnf copr enable lukenukem/asus-linux
sudo dnf update

rpm-ostree install dnf-automatic npm neovim python3-neovim tree-sitter-cli file-roller npm zathura zathura-zsh-completion zathura-pdf-poppler kvantum papirus-icon-theme qt5ct qt6ct imv grim slurp swappy asusctl asusctl-rog-gui kitty mpv codium transmission-gtk

sudo dnf copr enable avengemedia/dms
sudo dnf install dms --setopt=install_weak_deps=True

sudo systemctl enable supergfxd.service power-profiles-daemon

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install atuin bat btop fd ripgrep lazygit basedpyright ruff yazi tmux tealdeer starship eza fzf

systemctl --user enable --now wireplumber.service pipewire-pulse.socket pipewire.socket pipewire-pulse.service pipewire.service
