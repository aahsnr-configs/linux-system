# Changes Required for Ubuntu 24.04

## ubuntu.sources

```
Types: deb deb-src
URIs: http://archive.ubuntu.com/ubuntu
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb deb-src
URIs: http://security.ubuntu.com/ubuntu/
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

## devel-pinning

```
# Noble (24.04 LTS) stable - high priority
# "n=" matches ALL pockets: noble, noble-security, noble-updates
Package: *
Pin: release n=noble
Pin-Priority: 700

# Resolute (26.04 dev) - very low priority by default
Package: *
Pin: release n=resolute
Pin-Priority: 100

# Specific packages from resolute - ALWAYS use and upgrade from resolute
Package: greetd tuigreet wlsunset pymol sqlite3 transmission-gtk gnome-tweaks nautilus kitty kitty-shell-integration kitty-terminfo imv qt5ct qt6ct nwg-look swappy mpv gnome-keyring distrobox podman zsh zsh-common cronie bleachbit slurp grim zathura zathura-pdf-poppler xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk file-roller
Pin: release n=resolute
Pin-Priority: 900
```

## install-pyprland

Line 4: Change to:

```bash
# Pyprland Installation Script for Ubuntu 24.04
```

Line 413: Change to:

```
Pyprland Installation Script for Ubuntu 24.04
```

Line 447: Change to:

```
    - Ubuntu 24.04 (or compatible)
```
