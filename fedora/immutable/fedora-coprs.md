Write a custom ublue image based on bazzite linux with the following requirements:

- you must bazzite gnome nvidia image as the base image
- everything should be optimized for fedora 44
- it must strip of all gui features since I will be relying on Hyprland, but make sure to keep everything else the services, network management, gaming related packages, bazaar and other stuff that usually comes by default with bazzite as part of the ublue project.
- it must keep all the gaming related settings and stuff as well.
- it should retain all the fonts need to use
- it must install all the nvidia and nvidia-related packages as well, as well as hdr related stuff for gaming.
- it must keep all homebrew related stuff as well
- hyprland and related packages will be installed from sdegler/hyprland copr
- kitty terminal must not be installed from sdegler/hyprland copr
- eza will be installed from alternateved/eza, yazi will be install lihaohong/yazi and starship will be atim/starship, lazygit will be installed from atim/lazygit coprs respectively
- it must install the following packages from fedora default repos:
  `git bleachbit bluez bluez-tools brightnessctl cliphist cronie curl ddcutil direnv distrobox evolution-data-server fail2ban file-roller fontconfig fonts-filesystem gnome-keyring gnome-tweaks  go google-noto-color-emoji-fonts google-noto-sans-symbols-fonts google-noto-sans-symbols2-fonts grim gsettings-desktop-schemas gtk4-layer-shell gzip haveged hunspell ImageMagick imv inotify-tools ispell jq kitty kitty-shell-integration kitty-terminfo liberation-fonts logrotate luajit lynis mpv neovim node npm nwg-look papers papirus-icon-theme pipewire pipewire-alsa pipewire-gstreamer pipewire-pulseaudio pipewire-utils pipx policycoreutils-python-utils pymol qt5ct qt6ct slurp sqlite swappy transmission-gtk udiskie xdg-desktop-portal xdg-desktop-portal-hyprland xdg-user-dirs xdg-user-dirs-gtk xorg-x11-server-Xorg xorg-x11-server-Xwayland zathura zathura-pdf-mupdf `

- homebrew should install the following packages:
  `brew topgrade gh ripgrep tealdeer tmux yazi starship eza gh git-lfs fastfetch fd fzf atuin bat btop cava chafa du-dust gnuplot node pandoc`

`brew install --cask font-jetbrains-mono`
`brew install --cask font-jetbrains-mono-nerd-font`
`brew install --cask font-symbols-only-nerd-font`
Keep in mind that fedora silverblue will be used to install the based immutable fedora distribution with full disk encryption. Search the web and think longer for these tasks.
