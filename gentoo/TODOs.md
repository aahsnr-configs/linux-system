# DOTFILES TO CONSIDER
- [-] https://github.com/Nisfeight8/Nisfere
- [-] https://github.com/end-4/dots-hyprland
- [-] https://end-4.github.io/dots-hyprland-wiki/en/general/showcase/
- [-] https://github.com/linkfrg/dotfiles/
- [-] https://github.com/rubiin/HyDePanel
- [-] https://github.com/rubiin/dotfiles
- [-] https://github.com/Axenide/Ax-Shell
- [-] https://github.com/xeji01/hyprstellar.git

# NEOVIM CONFIGURATION
- [ ] Use lunarvim and astronvim 
- [ ] Build a neovim config from scratch
- [ ] Add yazi.nvim to neovim  configuration
- [ ] Add tree-sitter-hyprlang for neovim
- [ ] Add indentation support to markdown headings
- [ ] Add iron.nvim to astronvim config

# CRON JOBS/SYSTEMD TIMERS
- [ ] add a cron job to automatically push to gitlab and/or github every 15 minutes
- [ ] add cron joba for updating the system once a week


# UPDATES SCRIPT
- [ ] Add to systemd timer service or cron job
- [ ] Add go packages, both release and source
- [ ] Add source packages
- [ ] Hyprland plugins
- [ ] texlive packages
- [ ] flatpak apps

# HYPRLAND DE
- [-] Use nisefere as base https://github.com/Nisfeight8/Nisfere and add weather widget from https://github.com/rubiin/HyDePanel
- [ ] Install Ianny as an ebuild using uwsm ebuild
- [ ] Setup a way to view my keybindings for all my programs in a floating window like awesome window manager using rofi. The scripts are written in python
- [x] Install and configure anyrun from my NixOS setup
- [ ] Ask chatgpt to create a lo of modules. First ask to create macOS-like using  waybar that autohides and only comes on mouse hover
- [x] Get Inspiractions from awesome-rices github-repo and whatsappm list repos
- [ ] Use linkfrg dotfiles animations
- [ ] Consider specific parts from configs jakoolit and end-d4
- [ ] Make browser pop-ups floating by identifying their class using `hyprctl clients | grep -i class`
- [ ] When setting up waybar, consider adding grouped-items following https://itsfoss.com/waybar-grouped-items/
- [ ] Install hyprls using go ebuild
- [ ] Autostart apps and services using systemd user services
- [ ] Use the following plugins:
    - [ ] hyprland-expo
    - [ ] hycov with hyprland-expo to see all open windows
    - [ ] hy3
    - [ ] hycov
    - [ ] hyprscroller
    - [ ] hyprslidr
    - [ ] hyprnome
    - [-] Consider if hyprspace conflicts with hypcov and expo
    - [-] Find out hyprland-easymotion does
    - [ ] Test hyprchroma to test transparency
- x Consider Ashell for bar
- [x] Consider nwg-shell for bar too.
- [ ] Consider very strongly if Walker Application Launcher
- [x] Install Hyprlux

- [-] See what hyprkool does since it is inspired by Kde-Plasma-activities

# GLOBAL CONFIGS
- [NISFERE Main] https://github.com/Nisfeight8/Nisfere 
  - [x] bpytop
  - [ ] fabric
  - [ ] fastfetch
  - [ ] hyprland
  - [ ] nisfere-gtk-theme [!NOTE] : See if catppuccin is available
  - [ ] scripts
  - [ ] zsh

- [HOME-NIX] https://gitlab.com/aahsnr/home-nix.git
  - [x] anyrun
  - [x] hyprlock
  - [x] hypridle
  - [ ] pyprland
  - [ ] scripts

- [DOTFILES] https://gitlab.com/aahsnr/dotfiles.git -b zephyrus
  - [ ] atuin
  - [ ] bat
  - [ ] btop
  - [ ] capsule
  - [-] for cliphist test if the /etc/portage part works or not; also setup a systemd timer for the command in cliphist.md
  - [ ] cliphist
  - [ ] cliphist-rofi
  - [ ] eza
  - [ ] fzf
  - [ ] hyprlock
  - [ ] hypridle
  - [ ] hyprland
  - [ ] hyprlux
  - [ ] imv
  - [ ] kitty
  - [ ] lazygit
  - [ ] man pages
  - [ ] nwg-drawer
  - [ ] nwg-menu
  - [ ] ripgrep
  - [ ] scripts
  - [ ] thefuck
  - [ ] sddm  
  - [-] for starship, test if cd into .dots directory takes time or certain commands take time or not
  - [ ] starship
  - [ ] tealdeer
  - [ ] yazi
  - [ ] zathura
  - [ ] zoxide
  - [ ] zsh


--------------------------------------------------

# DEEPSEEK MD
[!Note]: For all the deepseek created configs, systemd units and scripts, make sure all of them are working
  - [x] atuin
  - [x] bat
  - [ ] capsule
  - [x] kitty
  - [x] lazygit
  - [x] nwg-drawer
  - [x] nwg-menu
  - [x] sddm
  - [x] zsh
  - [x] borg-backup script
  - [x] eza
  - [x] fzf
  - [x] cliphist
  - [x] imv
  - [x] [[Home Configuration]] write an advanced and optimized configuration for ___zathura___ with catppuccin mocha theme integration, hyprland integration, vim keybindings integration and quality of life improvements for use in gentoo linux
  - [x] [[Home Configuration]] write an advanced and optimized configuration for ___thefuck___ with catppuccin mocha theme integration, zsh integration and quality of life improvements for use in gentoo linux
  - [x] tealdeer
  - [x] [[Home Configuration]] write an advanced and optimized configuration for ___ripgrep___ with catppuccin mocha theme integration, zsh integration and quality of life improvements for use in gentoo linux
  - [x] [[System Configuration]] write an advanced and optimized configuration for handling ___man pages___ in gentoo linux with quality of life improvements, zsh integration and catppuccin mocha theme integration
  - [x] write a secure systemd user configuration for running the following command weekly: ___cliphist optimize --compact___   
  - [x] [[Home Configuration]] write an advanced and optimizemized configuration for ___atuin___ in gentoo linux that has vim keybindings and zsh integration
  - [ ] [[Scripts]] write an advance, secure and optimized script in python that extract files in any format for gentoo linux and all linux distributions in general, has user-friendly features, zip bomb detection, parallel extraction using multiple CPU cores, color-coded output and custom extraction directory
  - [ ] [[Enterprise-Grade System Configuration]] Write an enterprise grade and security hardened ___auditd profile___ with apparmor, systemd and cron integration 
  - [x] [[Home Configuration]] write an advance, optimized and modular rofi configuration to use ___cliphist (text and images) as gui___, has catppuccin mocha theme, papirus icon and fzf integration
  - [x] write an advanced and optimized configuration for ___starship prompt___ with catppuccin mocha theme integration, zsh integration, support for broad range of languages, and git optimization for gentoo linux
  - [x] write an advance, optimzed and clean configuration for ___btop___ with catppuccin mocha theme, vim keybingings and quality of life improvements for use in gentoo linux 
  - [x] write an advanced and optimized configuration for ___zoxide___ with catppuccin mocha theme integration, zsh integration, git optimization and quality of life improvements for use in gentoo linux
  - [x] write an advance, optimized and beatiful configuration for ___yazi___ with catppuccin mocha theme, using nerd fons, vim keybindings, useful plugins integration and quality of life improvements for use in gentoo linux
  - [ ] write an advanced and optimized czkawka clone using python and gtk4 as gui
  - [ ] [[Important System Utilities]] write a suit of advance, optimized, and useful python programs for ___daily-driving and maintaining gentoo linux and non-gentoo related linux tasks___ with the following features and integrations: security hardened, systemd integration, email notifications for critical issues, database integration for tracking changes, gui using gtk4, wayland integration, detailed hardware monitoring, quality of life improvements, integration with Gentoo's own tools and other linux-related tools. Then add glade ui files for all the programs to have complex layouts Then write gentoo ebuild files to install the generated programs in gentoo.
  - [x] [[Important System Utilities]] ___write useful python scripts for use in linux___
  - [ ] [[Desktop Shell]] ___Use the awesome window manager configuration in  and replicate all the desktop widgets and elements using EWW, and hyprland animations and blur to all eww widgets, and have the following properties and modifications: modular, eww configurations, hyprland blur and animations added to eww, animation aware dock, volume control osd using pipewire, gentoo-specific integrations, catppuccin mocha theme and papirus icon theme integrations, animated and dynamic workspace indicator in panel, main panel at the bottom , Do Not Disturb support, JetBrainsMono Nerd Font for fonts, notification center using mako, kitty for the default terminal, zen-browser for default browser, without a lockscreen, all configurations being advance and optimized, and additional desktop elements to improve quality of life and desktop experience___
  - [ ] [[Important System Utilities]] write an advance, modular, and optimized ___duplicate file finder___ program using python and gtk4 for gui without libadwaita support and the following features: multiple scan modes, image similarity detection, advanced filtering options, saving/loading scan results, ML-based similarity detection using pytorch for various file types, sophisticated file management options, mass delete/move operations for duplicates, similarity detection for documents, videos,etc., and fzf integration. Use numba wherever possible to optimize the python code. Then add glade ui file for complex layouts, and ensure the program has wayland support. Then write a gentoo ebuild file for installing in gentoo.


- write an advanced and optimized eww configuration that creates a desktop shell with the following properties: macOS-like desktop elements, catppuccin mocha theme integration, hyprland integration with animations and blur effects and quality of life improvements for use in gentoo
- Expand the above EWW macOS-like Desktop Shell Configuration by adding more desktop elements to improve quality of life and add hyrpland blur and animations integrations to eww
- For the above EWW macOS-like Desktop Shell Configuration, setup an advanced notification center and advanced volume control osd using pipewire
- For the notication center use mako instead of dunst for the above configurations
- Modularize the above configurations [TODO]

# SYSTEMD USER UNITS
- [x] cliphist
- [x] cliphist-images
- [ ] hyrpm reload -n
- [x] pyprland
- [x] hyprtheme
- [x] hyprpaper
- [x] xdg-desktop-portal-hyprland
- [x] ianny
- [ ] fabric
- [x] pypr
- [x] hyprtheme
- [x] hypridle


# DOTFILES 

[[IMPORTANT]] ___Recreate all config files inside an org file that tangles files to appropriate location. Only this org file is required.___

ln -sv $HOME/.dots/gentoo_setup $HOME/
ln -sv $HOME/.dots/org $HOME/
ln -sv $HOME/.dots/.config/bat $HOME/.config/
ln -sv $HOME/.dots/.config/btop $HOME/.config/
ln -sv $HOME/.dots/.config/capsule $HOME/.config/
ln -sv $HOME/.dots/.config/hypr $HOME/.config/
ln -sv $HOME/.dots/.config/Thunar $HOME/.config/
ln -sv $HOME/.dots/.config/gtk-3.0 $HOME/.config/
ln -sv $HOME/.dots/.config/gtk-4.0 $HOME/.config/
ln -sv $HOME/.dots/.config/Kvantum $HOME/.config/
ln -sv $HOME/.dots/.config/lazygit $HOME/.config/
ln -sv $HOME/.dots/.themes $HOME/
ln -sv $HOME/.dots/.config/nvim $HOME/.config/
ln -sv $HOME/.dots/.config/qalculate $HOME/.config/
ln -sv $HOME/.dots/.config/qt5ct $HOME/.config/
ln -sv $HOME/.dots/.config/qt6ct $HOME/.config/
ln -sv $HOME/.dots/.config/yazi $HOME/.config/
ln -sv $HOME/.dots/.config/wallpapers $HOME/.config/
ln -sv $HOME/.dots/.config/zathura $HOME/.config/
ln -sv $HOME/.dots/.gtkrc-2.0 $HOME/

# GENERAL
- [ ] Need to port over firefox config 
- [x] Configure anyrun like home-nix
- [ ] Update zsh config and borrow certain elements from Nisfere
- [ ] Setup yazi and its plugins and optimize it
- [ ] Setup docker and podman in gentoo 
- [x] Learn how to setup borg for automatic documents backup
- [ ] Setup ccache in gentoo
- [x] Install python-fabric via python ebuilds
- [ ] Write ebuilds for go packages following nwg-drawer ebuild as an examples
- [-] Follow this guide https://wiki.gentoo.org/wiki/Zswap to setup zswap in gentoo
- [ ] Setup nvhpc later on worksation
- [x] Setup gnome-software or discover to install flatpak and snap packages
- [ ] Setup apparmor in gentoo
- [ ] Install firewalld after finishing full system install
- [ ] Use kitty terminal for everything
- [ ] Use tgpt to setup gpt, deepseek,etc
- [ ] Install apparmor profiles from https://github.com/roddhjav/apparmor.d inside sec-policy/apparmor-profiles
- [ ] Setup Arpwatch later down the line
- [ ] Consider SecurityOnion for deploying in my house and look at youtube videos
- [ ] Set up default applications using https://wiki.gentoo.org/wiki/Default_applications
- [ ] Add these asus modules to dracut: hid_asus asus_wmi asus_nb_wmi
- [X] Setup graphite flags in package.env like clang https://wiki.gentoo.org/wiki/Clang
- [x] Add current neovim config to dotfiles
- [ ] Add kernel integrity subsystem support using https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/managing_monitoring_and_updating_the_kernel/enhancing-security-with-the-kernel-integrity-subsystem_managing-monitoring-and-updating-the-kernel#enhancing-security-with-the-kernel-integrity-subsystem_managing-monitoring-and-updating-the-kernel
- [x] install yarn and npm
- [ ] add fuji fox to firefox
- [ ] Consider https://github.com/xeji01/hyprstellar.git for some of its elements
- [ ] Find out which repos need to be followed to update versioned ebuild packages
- [ ] Find out which repos need to be followed for to update packages built from source
- [ ] Fix yank and paste in neovim
- [ ] Install tmux and look at vim-syntax scripts
- [ ] Find out which git repos you need to follow
- [ ] Switch to vivaldi browser
- [ ] Replace straight with emacs built-in package manager
- [ ] :pin org in (use-package org)
- [ ] Install yazi plugins
- [ ] Setup cliphist rofi
- [ ] Use modprobed-db to use localmodconfig
- [ ] Need to setup winapps using https://github.com/winapps-org/winapps for certain windows applications
- [ ] Remove tree-sitter packages 
       dev-libs/tree-sitter-markdown dev-libs/tree-sitter-vimdoc dev-libs/tree-sitter-lua dev-libs/tree-sitter-vim dev-libs/tree-sitter-query dev-libs/tree-sitter-c dev-libs/tree-sitter-bash dev-libs/tree-sitter-html
- [X] Apply polly optimizations to clang/llvm and its packages
- [ ] Setup zram using zram-init after booting into gentoo
- [ ] Setup nwg-wrapper to display the following items: Date, Temperature, user, minimal linux info


# `EBUILDS`
[!NOTE] : EGIT_REPO_URI="https://github.com/hyprwm/${PN^}.git"
- [ ] gui-apps/alacritty-graphics [versioned]
- [ ] app-misc/czkawka [versioned] using pycargoebuild and https://devmanual.gentoo.org/eclass-reference/rust.eclass/index.html
- [x] sys-apps/apparmor [versioned]
- [x] sys-apps/apparmor-utils [versioned]
- [x] sys-libs/libapparmor [versioned]
- [x] sec-policy/apparmor-profiles [versioned]
- [x] gui-wm/hyprland [9999]
- [ ] gui-libs/hyprland-qtutils 
- [x]	dev-libs/hyprgraphics [9999]
- [x]	dev-libs/hyprlang [9999]
- [x]	gui-libs/aquamarine [9999]
- [x]	gui-libs/hyprcursor [9999]
- [x]	gui-libs/hyprutils [9999]
- [x]	dev-libs/hyprland-protocols [9999]
- [x] dev-util/hyprwayland-scanner [9999]
- [x]	gui-libs/xdg-desktop-portal-hyprland [9999]
- [x]	gui-apps/hypridle [9999]
- [x]	gui-apps/hyprlock [9999]
- [x]	gui-apps/hyprpaper [9999]
- [x]	gui-apps/hyprpicker [9999]
- [x]	gui-wm/hyprland-contrib [9999]
- [x]	gui-apps/hyprsunset [9999]
- [x]	gui-apps/uwsm [9999]
- [x] dev-util/dart-sass [9999]
- [ ] pyprland [9999] using https://devmanual.gentoo.org/eclass-reference/python-r1.eclass/index.html 
- [X] sys-kernel/cachyos-settings
- [x] sys-process/cachyos-ksm-settings
- [ ] app-admin/ananicy-cpp
- [ ] app-admin/ananicy-rules-cachyos
- [ ] sec-policy/apparmor-profiles-roddhjay https://github.com/roddhjav/apparmor.d [9999]
- [x] gui-apps/anyrun using git commit
- [ ] ianny
- [ ] czkawka  
- [ ] fabric-cli



