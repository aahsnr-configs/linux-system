#!/bin/bash
ln -sv "$HOME/Git/configs/arch-system/dots/bin/" "$HOME/"
ln -sv "$HOME/Git/configs/arch-system/dots/.zshrc" "$HOME/"
ln -sv "$HOME/Git/configs/arch-system/dots/.config/atuin/" "$HOME/.config/"
ln -sv "$HOME/Git/configs/arch-system/dots/.config/bat/" "$HOME/.config/"
ln -sv "$HOME/Git/configs/arch-system/dots/.config/btop/" "$HOME/.config/"
ln -sv "$HOME/Git/configs/arch-system/dots/.config/enchant/" "$HOME/.config/"
ln -sv "$HOME/Git/configs/arch-system/dots/.config/fd/" "$HOME/.config/"
ln -sv "$HOME/Git/configs/arch-system/dots/.config/imv/" "$HOME/.config/"
ln -sv "$HOME/Git/configs/arch-system/dots/.config/kitty/" "$HOME/.config/"
ln -sv "$HOME/Git/configs/arch-system/dots/.config/lazygit/" "$HOME/.config/"
ln -sv "$HOME/Git/configs/arch-system/dots/.config/niri/" "$HOME/.config/"
ln -sv "$HOME/Git/configs/arch-system/dots/.config/nvim/" "$HOME/.config/"
ln -sv "$HOME/Git/configs/arch-system/dots/.config/starship.toml" "$HOME/.config/"
ln -sv "$HOME/Git/configs/arch-system/dots/.config/swappy/" "$HOME/.config/"
ln -sv "$HOME/Git/configs/arch-system/dots/.config/environment.d/" "$HOME/.config"
ln -sv "$HOME/Git/configs/arch-system/dots/.config/tealdeer/" "$HOME/.config/"
ln -sv "$HOME/Git/configs/arch-system/dots/.config/tmux/" "$HOME/.config/"
ln -sv "$HOME/Git/configs/arch-system/dots/.config/yazi/" "$HOME/.config/"
ln -sv "$HOME/Git/configs/arch-system/dots/.config/zathura/" "$HOME/.config/"
sudo mkdir /root/.config
sudo ln -sv $HOME/Git/configs/arch-system/dots/.config/nvim /root/.config

# Configure User
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global"
