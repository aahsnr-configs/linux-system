#!/bin/bash
sudo pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
sudo pacman-key --finger 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
sudo pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
sudo pacman-key --finger 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35

wget "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x8b15a6b0e9a3fa35" -O g14.sec
sudo pacman-key -a g14.sec

# insert the following lines at the end of pacman.conf
[g14]
Server = https://arch.asus-linux.org

paru -S asusctl power-profiles-daemon rog-control-center
sudo systemctl enable --now power-profiles-daemon.service

git clone https://gitlab.com/asus-linux/nvidia-laptop-power-cfg.git
cd nvidia-laptop-power-cfg
makepkg -sfi
