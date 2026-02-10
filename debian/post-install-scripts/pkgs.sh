#!/bin/sh
# ASUS Linux setup
sudo pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
sudo pacman-key --finger 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
sudo pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
sudo pacman-key --finger 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35

wget "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x8b15a6b0e9a3fa35" -O g14.sec
sudo pacman-key -a g14.sec
sudo rm -rf g14.sec

paru -Syu
paru -S --noconfim --needed asusctl power-profiles-daemon rog-control-center

paru -S --noconfim --needed accountsservice \
  adw-gtk-theme \
  ananicy-cpp \
  arch-audit \
  atuin \
  audit \
  bat \
  bibata-cursor-theme-bin \
  bitwarden \
  bleachbit \
  bpf \
  bpftune-git \
  brave-bin \
  journalctl-desktop-notification \
  brightnessctl \
  btop \
  chafa \
  cliphist \
  ddcutil \
  dgop \
  direnv \
  distrobox \
  dms-shell-git \
  dgop-git \
  dsearch-git \
  dosfstools \
  dust \
  egl-gbm \
  egl-wayland \
  egl-wayland2 \
  egl-x11 \
  eza \
  firewalld \
  flatpak \
  fwupd \
  fwupd-efi \
  fzf \
  github-cli \
  git-lfs \
  gnome-keyring \
  gvfs \
  gzip \
  haveged \
  hwdata \
  imv \
  inotify-tools \
  jitterentropy \
  jq \
  lazygit \
  logrotate \
  lynis \
  matugen \
  niri \
  noto-color-emoji-fontconfig \
  noto-fonts \
  noto-fonts-cjk \
  noto-fonts-emoji \
  nwg-look \
  onlyoffice-bin \
  opencl-nvidia \
  org.freedesktop.secrets \
  papirus-folders \
  papirus-icon-theme \
  pay-respects-bin \
  pkgconf \
  pkgfile \
  planify \
  plocate \
  plymouth \
  poppler \
  poppler-glib \
  profile-sync-daemon \
  python-notify2 \
  python-psutil \
  qt5ct \
  qt6ct-kde \
  quickshell-git \
  rate-mirrors \
  rebuild-detector \
  reflector \
  rng-tools \
  seatd \
  sed \
  sound-theme-freedesktop \
  starship \
  switcheroo-control \
  sysstat \
  tar \
  tealdeer \
  tk \
  tpm2-tss \
  transmission-gtk \
  trash-cli \
  udiskie \
  wl-clipboard \
  wpa_supplicant \
  x264 \
  x265 \
  xdg-desktop-portal \
  xdg-desktop-portal-gnome \
  xdg-desktop-portal-gtk \
  xdg-user-dirs \
  xdg-user-dirs-gtk \
  xdg-utils \
  xorg-xwayland \
  xournalpp \
  xwayland-satellite \
  yazi \
  zathura \
  zathura-pdf-poppler \
  zen-browser-bin \
  zoxide
