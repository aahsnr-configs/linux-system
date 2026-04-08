# DISK PREPARATION
## LVM
cfdisk /dev/nvme0n1 &&
  mkfs.vfat -F 32 /dev/nvme0n1p1 &&
  cryptsetup --cipher aes-xts-plain64 --hash sha512 --use-random --verify-passphrase luksFormat /dev/nvme0n1p2 &&
  cryptsetup luksOpen /dev/nvme0n1p2 cryptlvm &&
  pvcreate /dev/mapper/cryptlvm &&
  vgcreate vg0 /dev/mapper/cryptlvm &&
  lvcreate -L 16G vg0 -n swap &&
  lvcreate -l 100%FREE vg0 -n root &&
  mkfs.btrfs -f  /dev/vg0/root &&
  mkswap  /dev/vg0/swap &&
  rm -rf /mnt/gentoo &&
  mkdir /mnt/gentoo &&
  mount /dev/vg0/root /mnt/gentoo &&
  swapon /dev/vg0/swap

Setting up swapspace version 1, size = 16 GiB (17179865088 bytes)
no label, UUID=50bca159-9688-4b18-be82-5423feb73ad6

## Without LVM
cfdisk /dev/nvme0n1 &&
  mkfs.vfat -F 32 /dev/nvme0n1p1 &&
  cryptsetup --cipher aes-xts-plain64 --hash sha512 --use-random --verify-passphrase luksFormat /dev/nvme0n1p2 &&
  cryptsetup luksOpen /dev/nvme0n1p2 cryptroot &&
  mkfs.btrfs -f  /dev/mapper/cryptroot &&
  rm -rf /mnt/gentoo &&
  mkdir /mnt/gentoo &&
  mount /dev/mapper/cryptroot /mnt/gentoo

## SUBVOLUMES
btrfs su cr /mnt/gentoo/@ &&
  btrfs su cr /mnt/gentoo/@home &&
  btrfs su cr /mnt/gentoo/@opt &&
  btrfs su cr /mnt/gentoo/@root &&
  btrfs su cr /mnt/gentoo/@srv &&
  btrfs su cr /mnt/gentoo/@nix &&
  btrfs su cr /mnt/gentoo/@usr@local &&
  btrfs su cr /mnt/gentoo/@var &&
  btrfs su cr /mnt/gentoo/@var@cache &&
  btrfs su cr /mnt/gentoo/@var@crash &&
  btrfs su cr /mnt/gentoo/@var@tmp &&
  btrfs su cr /mnt/gentoo/@var@spool &&
  btrfs su cr /mnt/gentoo/@var@log &&
  btrfs su cr /mnt/gentoo/@var@log@audit &&
  btrfs su cr /mnt/gentoo/@snapshots &&
  umount /mnt/gentoo

## MOUNTING
mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@ /dev/vg0/root /mnt/gentoo &&
  mkdir /mnt/gentoo/home &&
  mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@home /dev/vg0/root /mnt/gentoo/home &&
  mkdir /mnt/gentoo/opt &&
  mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@opt /dev/vg0/root /mnt/gentoo/opt &&
  mkdir /mnt/gentoo/root &&
  mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@root /dev/vg0/root /mnt/gentoo/root &&
  mkdir /mnt/gentoo/srv &&
  mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@srv /dev/vg0/root /mnt/gentoo/srv &&
  mkdir /mnt/gentoo/nix &&
  mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@nix /dev/vg0/root /mnt/gentoo/nix &&
  mkdir -p /mnt/gentoo/usr/local &&
  mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@usr@local /dev/vg0/root /mnt/gentoo/usr/local &&
  mkdir /mnt/gentoo/var &&
  mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@var /dev/vg0/root /mnt/gentoo/var &&
  mkdir /mnt/gentoo/var/cache &&
  mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@var@cache /dev/vg0/root /mnt/gentoo/var/cache &&
  mkdir /mnt/gentoo/var/crash &&
  mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@var@crash /dev/vg0/root /mnt/gentoo/var/crash &&
  mkdir /mnt/gentoo/var/tmp  &&
  mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@var@tmp /dev/vg0/root /mnt/gentoo/var/tmp &&
  mkdir /mnt/gentoo/var/spool  &&
  mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@var@spool /dev/vg0/root /mnt/gentoo/var/spool &&
  mkdir /mnt/gentoo/var/log &&
  mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@var@log /dev/vg0/root /mnt/gentoo/var/log &&
  mkdir /mnt/gentoo/var/log/audit &&
  mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@var@log@audit /dev/vg0/root /mnt/gentoo/var/log/audit &&
  mkdir /mnt/gentoo/.snapshots &&
  mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@snapshots /dev/vg0/root /mnt/gentoo/.snapshots

# SETUP ENVIRONMENT FOR GENTOO
cd /mnt/gentoo && wget https://distfiles.gentoo.org/releases/amd64/autobuilds/20250413T165021Z/stage3-amd64-desktop-systemd-20250413T165021Z.tar.xz && tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner && mkdir --parents /mnt/gentoo/etc/portage/repos.conf && cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf && cp --dereference /etc/resolv.conf /mnt/gentoo/etc/ && mount --types proc /proc /mnt/gentoo/proc && mount --rbind /sys /mnt/gentoo/sys && mount --make-rslave /mnt/gentoo/sys && mount --rbind /dev /mnt/gentoo/dev && mount --make-rslave /mnt/gentoo/dev && mount --bind /run /mnt/gentoo/run && mount --make-slave /mnt/gentoo/run && test -L /dev/shm && rm /dev/shm && mkdir /dev/shm && mount -t tmpfs -o nosuid,nodev,noexec shm /dev/shm && chmod 1777 /dev/shm

# PRECONFIG FILES
rm -R /mnt/gentoo/etc/portage/make.conf && rm -R /mnt/gentoo/etc/portage/package.accept_keywords && rm -R /mnt/gentoo/etc/portage/package.use && rm -R /mnt/gentoo/etc/portage/package.mask && cp -R /home/ahsan/.dots/gentoo/preconfig_files/etc/portage/* /mnt/gentoo/etc/portage/ && cp -R /home/ahsan/.dots/gentoo/preconfig_files/tc-optimize /mnt/gentoo/root/

# CHROOT
chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) ${PS1}"

mount /dev/nvme0n1p1 /boot

# INITIAL SYNC
emerge-webrsync && emerge --sync && eselect profile set 42 && eselect profile list && emerge --sync

# LOCALES
ln -sf ../usr/share/zoneinfo/Asia/Dhaka /etc/localtime && nano /etc/locale.gen && locale-gen && eselect locale list && eselect locale set 4 && env-update && source /etc/profile && export PS1="(chroot) ${PS1}"

# OPTIMIZAZTIONS

1. emerge linux-headers && emerge glibc && emerge binutils && env-update && source /etc/profile && export PS1="(chroot) ${PS1}" && emerge gcc && emerge glibc && emerge sys-libs/zlib dev-lang/tcl dev-tcltk/expect dev-util/dejagnu dev-libs/elfutils dev-util/sysprof dev-debug/valgrind dev-libs/mpfr dev-libs/mpc
 && emerge binutils && env-update && source /etc/profile && export PS1="(chroot) ${PS1}"
2. optimize cmake, then ( exit, chroot /mnt/gentoo /bin/bash, source /etc/profile, export PS1="(chroot) ${PS1}" ),
3. To optimize clang/llvm, first emerge lld without LDFLAGS, then re-emerge lld with LDFLAGS
4. optimize polly-19, clang/llvm-19, then ( exit, chroot /mnt/gentoo /bin/bash, source /etc/profile, export PS1="(chroot) ${PS1}" )
5. optimize clang/llvm-18
6. optimize python313/python312
7. optimize rust, nodejs
8. emerge -ev @world --exclude gcc

binutils: dev-tcltk/expect dev-util/dejagnu
gcc: dev-libs/gmp dev-libs/isl-0.26

libtool --finish /usr/lib/../lib64
libtool --finish /usr/lib64
libtool --finish /usr/libexec/gcc/x86_64-pc-linux-gnu


# CHECKS for Python - PGO & LTO
## LTO
    python3 -c "import sysconfig; print('lto' in (sysconfig.get_config_var('PY_CFLAGS') + sysconfig.get_config_var('PY_CFLAGS_NODIST')))"

## PGO
    python3 -c "import sysconfig; print('-fprofile-use' in (sysconfig.get_config_var('PY_CFLAGS') + sysconfig.get_config_var('PY_CFLAGS_NODIST')))"

## PY_CFLAGS
    python3 -c "import sysconfig; print(sysconfig.get_config_var('PY_CFLAGS') + sysconfig.get_config_var('PY_CFLAGS_NODIST'))"

# PORTAGE && ITS REPOS
emerge -aq --jobs=5 app-eselect/eselect-repository dev-vcs/git && eselect repository remove gentoo && eselect repository add gentoo git https://github.com/gentoo-mirror/gentoo.git  && emaint sync -r gentoo && eselect repository enable guru pentoo edgets gentoo-zh CachyOS-kernels xarblu-overlay && eselect repository create custom && emerge --sync


# PERSONAL REPOS
- eselect repository create custom
- emerge pkgdev
- sudo cp -R /home/ahsan/.dots/gentoo/preconfig_files/repos/custom/* /mnt/gentoo/var/db/repos/custom/
- cd var/db/repos/custom/
- pkgdev manifest

# MODIFICATIONS
- add pypy3_11 python3_13 to python targets
- re-emerge clang/llvm packages with compiler-clang-lto
- emerge dev-lang/python:3.13::custom with compiler-clang-lto


# SETUP USER
systemd-machine-id-setup && hostnamectl set-hostname zephyrus && emerge -a app-admin/sudo genfstab && passwd && useradd -m -G users,wheel,audio,video -s /bin/bash ahsan && passwd ahsan && EDITOR=nvim visudo

# FSTAB
/swap/swapfile none swap defaults,subvol=@swap 0 0

mount /dev/nvme0n1p1 /boot
genfstab -U / >> /etc/fstab

emerge -ev @world --exclude gcc clang python llvm nodejs rust

# KERNEL
## Packages
emerge sys-kernel/cachyos-sources sys-kernel/linux-firmware sys-kernel/linux-headers sys-apps/fwupd sys-fs/cryptsetup sys-firmware/sof-firmware sys-fs/genfstab sys-kernel/installkernel sys-kernel/modprobed-db sys-fs/btrfs-progs sys-apps/rng-tools sys-apps/kbd  dev-build/automake sys-apps/dbus sys-apps/dbus-broker && eselect kernel set 1 && ls -l /usr/src/linux

## Modules
** gentoo config examples
1. main handbook (done)
2. dracut (done)
3. systemd (done)
4. zram (done)
5. printing
6. systemd-boot
7. zstd (done)
8. bluetooth (done)
9. dm-crypt (done)
10. amd microcode (done)
11. input devices -> include asus g14
12. cups (done)
13. droidcam (done)
14. nvidia
15. sound
16. openrgb

lsblk -o name,uuid
#example
nvme0n1
└─nvme0n1p1 4bb45bd6-9ed9-44b3-b547-b411079f043b
  └─root    cb070f9e-da0e-4bc5-825c-b01bb2707704

kernel_cmdline+=" root=UUID=cb070f9e-da0e-4bc5-825c-b01bb2707704 rd.luks.uuid=4bb45bd6-9ed9-44b3-b547-b411079f043b "

kernel_cmdline+=" root=UUID=<UUID of /dev/mapper/cryptroot> rd.luks.uuid=<UUID of /dev/nvme0n1p2> "

#actual
nvme0n1
|-nvme0n1p1   1778-CF2B
|-nvme0n1p2   f6502e18-76b2-4e98-9f68-a082d6dc60ae
    |__cryptroot e8f3ea91-e5b8-4c25-9a52-bc789d90f3f4


#actual
nvme0n1
├─nvme0n1p1    6B7E-166F
└─nvme0n1p2    330a6486-116f-4c74-b282-319ab6c45c53
  └─cryptlvm   H2jC9K-5PZI-5RL6-EN7l-kaJl-oyM3-pGQoGN
    ├─vg0-swap 8ae4b3bb-2c21-4b4a-a2f6-d0a708d0a240
    └─vg0-root 85b93843-925a-41ce-bc2c-b401f8e857a1


## DRACUT
### dracut --print-cmdline opensuse
rd.driver.pre=btrfs rd.luks.uuid=luks-70522737-f570-45c1-8173-7ffc6a7225d6 rd.lvm.lv=system/swap   rd.lvm.lv=system/root   resume=UUID=5241390b-0fe2-4273-bc97-ecc6e5f6a814 root=UUID=81df9190-81e6-4eaf-bff3-03238a72665e rootfstype=btrfs rootflags=rw,relatime,ssd,space_cache=v2,subvolid=266,subvol=/@/.snapshots/1/snapshot,subvol=@/.snapshots/1/snapshot

### dracut --print-cmdline gentoo
rd.driver.pre=btrfs rd.luks.uuid=luks-<UUID from blkid /dev/nvme0n1p2> rd.lvm.lv=vg0/swap rd.lvm.lv=vg0/root resume=UUID=<UUID of vg0-swap> root=UUID=<UUID of the vg0-root>  rootfstype=btrfs

#### Without LVM
mkdir /etc/dracut.conf.d/ && nvim /etc/dracut.conf.d/dracut.conf
hostonly="yes"
compress="zstd"
add_dracutmodules+=" crypt dm rootfs-block "
omit_dracutmodules+=" network cifs nfs nbd brltty "
force_drivers+=" btrfs hid_asus asus_wmi asus_nb_wmi "
kernel_cmdline+=" root=UUID=e8f3ea91-e5b8-4c25-9a52-bc789d90f3f4 rd.luks.uuid=f6502e18-76b2-4e98-9f68-a082d6dc60ae "

#### Associated Grub
nvim /etc/default/grub
GRUB_CMDLINE_LINUX="init=/lib/systemd/systemd nvidia-drm.modeset=1 rootfstype=btrfs quiet loglevel=0 rw rd.vconsole.keymap=us root=UUID=e8f3ea91-e5b8-4c25-9a52-bc789d90f3f4"
GRUB_CMDLINE_LINUX_DEFAULT="apparmor=1 security=apparmor"


#### With LVM
mkdir /etc/dracut.conf.d/ && nvim /etc/dracut.conf.d/dracut.conf
hostonly="yes"
compress="zstd"
add_dracutmodules+=" crypt dm rootfs-block resume lvm "
omit_dracutmodules+=" network cifs nfs nbd brltty "
force_drivers+=" btrfs "
kernel_cmdline+=" rd.luks.uuid=5f714b5e-cc8f-4ff8-8c57-8e9b570b638b root=UUID=4c73b928-1210-4ff5-bd8c-9f77fb3e9e28 resume=UUID=61d7400e-dbba-47e1-84bd-a8af0594f6e8 rd.lvm.lv=vg0/swap rd.lvm.lv=vg0/root "

#### Associated Grub
nvim /etc/default/grub
GRUB_CMDLINE_LINUX="init=/lib/systemd/systemd rootfstype=btrfs quiet loglevel=0 rw rd.vconsole.keymap=us rd.luks.uuid=5f714b5e-cc8f-4ff8-8c57-8e9b570b638b root=UUID=4c73b928-1210-4ff5-bd8c-9f77fb3e9e28 resume=UUID=61d7400e-dbba-47e1-84bd-a8af0594f6e8 rd.lvm.lv=vg0/swap rd.lvm.lv=vg0/root"
GRUB_CMDLINE_LINUX_DEFAULT="apparmor=1 security=apparmor"


grub-install --target=x86_64-efi --efi-directory=/boot && grub-mkconfig -o /boot/grub/grub.cfg

<!--efibootmgr --create --disk /dev/nvme0n1 --label "Gentoo" --loader "vmlinuz-6.1.28-gentoo" --unicode "initrd=initramfs-6.1.28-gentoo rd.luks.uuid=8a848dda-43e9-4ca0-a44c-87e69fa5fc9e"-->

## Build with -O3
make menuconfig LLVM=1 KCFLAGS="-O3 -march=native -pipe -flto=thin"
make -j14 LLVM=1 KCFLAGS="-O3 -march=native -pipe -flto=thin"
make modules_install -j14 LLVM=1 KCFLAGS="-O3 -march=native -pipe -flto=thin"
emerge x11-drivers/nvidia-drivers gui-libs/egl-wayland gui-libs/egl-gbm gui-libs/egl-x11 media-libs/nvidia-vaapi-driver sys-process/nvtop x11-drivers/xf86-video-amdgpu
make install LLVM=1 KCFLAGS="-O3 -march=native -pipe -flto=thin"

### Build with -Ofast
make menuconfig LLVM=1 KCFLAGS="-Ofast -march=native -pipe -flto=thin"
make -j14 LLVM=1 KCFLAGS="-Ofast -march=native -pipe -flto=thin"
make modules_install -j14 LLVM=1 KCFLAGS="-O3 -march=native -pipe -flto=thin"
emerge x11-drivers/nvidia-drivers gui-libs/egl-wayland gui-libs/egl-gbm gui-libs/egl-x11 media-libs/nvidia-vaapi-driver sys-process/nvtop x11-drivers/xf86-video-amdgpu
make install LLVM=1 KCFLAGS="-Ofast -march=native -pipe -flto=thin"



# System Packages
emerge --ask --jobs=10 \
  app-admin/bitwarden-desktop-bin \
  app-admin/sysstat \
  app-alternatives/ninja \
  app-arch/7zip \
  app-arch/unzip \
  app-arch/unrar \
  app-arch/zip \
  app-backup/btrfs-assistant \
  app-backup/snapper \
  app-backup/snapper-gui \
  app-containers/containerd \
  app-containers/distrobox \
  app-containers/docker \
  app-containers/docker-cli \
  app-containers/docker-compose \
  app-containers/docker-credential-helpers \
  app-containers/lxc \
  app-containers/lxd \
  app-containers/podman \
  app-containers/podman-compose \
  app-containers/podman-tui \
  app-containers/pods \
  app-editors/emacs \
  app-editors/neovim \
  app-eselect/eselect-repository \
  app-forensics/aide \
  app-forensics/lynis \
  app-misc/brightnessctl \
  app-misc/czkawka \
  app-misc/jq \
  app-misc/yazi \
  app-office/obsidian \
  app-portage/eix \
  app-portage/gentoolkit \
  app-portage/smart-live-rebuild \
  app-shells/atuin \
  app-shells/fzf \
  app-shells/fzf-tab \
  app-shells/gentoo-zsh-completions \
  app-shells/gitstatus \
  app-shells/starship \
  app-shells/zoxide \
  app-shells/zsh \
  app-shells/zsh-autosuggestions \
  app-shells/zsh-completions \
  app-shells/zsh-history-substring-search \
  app-shells/zsh-syntax-highlighting \
  app-text/fzy \
  app-text/texlab \
  app-text/pandoc \
  app-text/xournalpp \
  app-text/zathura \
  app-text/zathura-meta \
  app-text/zotero-bin \
  dev-build/meson \
  dev-cpp/tomlplusplus \
  dev-libs/glib \
  dev-libs/hyprland-protocols \
  dev-libs/hyprgraphics \
  dev-libs/hyprlang \
  dev-libs/libinput \
  dev-libs/libliftoff \
  dev-libs/libzip \
  dev-libs/pugixml \
  dev-libs/re2 \
  dev-libs/udis86 \
  dev-libs/wayland \
  dev-libs/wayland-protocols \
  dev-python/babel \
  dev-python/black \
  dev-python/cython \
  dev-python/isort \
  dev-python/matplotlib \
  dev-python/notify2 \
  dev-python/pandas \
  dev-python/pip \
  dev-python/pipx \
  dev-python/psutil \
  dev-python/python-pam \
  dev-python/pynvim \
  dev-python/requests \
  dev-python/scipy \
  dev-python/setuptool \
  dev-python/wheel \
  dev-qt/qtbase \
  dev-qt/qtdeclarative \
  dev-qt/qtwayland \
  dev-util/git-delta \
  dev-util/dart-sass \
  dev-util/hyprwayland-scanner \
  dev-util/tree-sitter-cli \
  dev-util/vulkan-headers \
  dev-util/wayland-scanner \
  dev-vcs/git \
  dev-vcs/lazygit \
  dev-vcs/git-lfs \
  gnome-base/librsvg \
  gui-apps/alacritty-graphics \
  gui-apps/grim \
  gui-apps/hypridle \
  gui-apps/hyprlock \
  gui-apps/hyprpaper \
  gui-apps/hyprpicker \
  gui-apps/hyprsunset \
  gui-apps/uwsm \
  gui-apps/qt6ct \
  gui-apps/rofi-wayland \
  gui-apps/slurp \
  gui-apps/wf-recorder \
  gui-apps/wl-clipboard \
  gui-libs/aquamarine \
  gui-libs/hyprcursor \
  gui-libs/hyprutils \
  gui-libs/xdg-desktop-portal-hyprland \
  gui-wm/hyprland \
  gui-wm/hyprland-contrib \
  kde-frameworks/qqc2-desktop-style \
  media-fonts/jetbrains-mono \
  media-fonts/ubuntu-font-family \
  media-fonts/nerdfonts \
  media-gfx/maim \
  media-libs/libdisplay-info \
  media-libs/libglvnd \
  media-libs/libjpeg-turbo \
  media-libs/libjxl \
  media-libs/libwebp \
  media-libs/mesa \
  media-libs/vulkan-layers \
  media-libs/vulkan-loader \
  media-sound/spotify \
  media-video/mpv \
  net-im/discord \
  net-im/zoom \
  net-firewall/firewalld \
  net-misc/curl \
  net-misc/wget \
  sci-biology/biopython \
  sci-chemistry/pymol \
  sec-policy/apparmor-profiles \
  sys-apps/apparmor \
  sys-apps/apparmor-utils \
  sys-apps/bat \
  sys-apps/dbus-broker \
  sys-apps/eza \
  sys-apps/fd \
  sys-apps/file \
  sys-apps/grep \
  sys-apps/haveged \
  sys-apps/hwdata \
  sys-apps/mlocate \
  sys-apps/ripgrep \
  sys-apps/util-linux \
  sys-apps/yarn \
  sys-auth/seatd \
  sys-libs/libapparmor \
  sys-power/upower \
  sys-process/acct \
  sys-process/audit \
  sys-process/bottom \
  sys-process/btop \
  sys-process/lsof \
  virtual/libudev \
  virtual/pkgconfig \
  x11-base/xwayland \
  x11-libs/cairo \
  x11-libs/libdrm \
  x11-libs/libnotify \
  x11-libs/libxcb \
  x11-libs/libXcursor \
  x11-libs/libxkbcommon \
  x11-libs/pango \
  x11-libs/pixman \
  x11-libs/xcb-util-errors \
  x11-libs/xcb-util-wm \
  x11-misc/qt5ct \
  x11-misc/sddm \
  x11-themes/kvantum \
  xfce-base/thunar \
  xfce-base/thunar-volman \
  xfce-base/tumbler \
  xfce-extra/thunar-archive-plugin \
  xfce-extra/thunar-media-tags-plugin \
  www-apps/element \
  www-client/zen-browser \
  gnome-base/gvfs \
  sys-fs/genfstab \
  sys-fs/cryptsetup \
  app-backup/grub-btrfs

# SETUP NETWORK - DHPCD
  * Use the following guides to setup networking using dhcpcd
    - https://wiki.gentoo.org/wiki/Systemd/systemd-networkd
    - https://wiki.gentoo.org/wiki/Network_management_using_DHCPCD

## Packages
   emerge net-misc/dhcpcd net-wireless/wpa_supplicant

# SYSTEMD
* use systemd-networkd instead of network-manager
systemctl enable dhcpcd sysstat auditd rngd nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service nvidia-powerd.service systemd-timesyncd dhpc


## C setup snapper
sudo umount /.snapshots/ && sudo rm -r /.snapshots/ && sudo snapper -c root create-config / && sudo btrfs subvolume delete /.snapshots && sudo mkdir /.snapshots && sudo mount -a && sudo chmod 750 /.snapshots && sudo lvim /etc/snapper/configs/root && sudo systemctl enable --now snapper-timeline.timer && sudo systemctl enable --now snapper-cleanup.timer

## D Sysctl
sudo nvim /etc/sysctl.d/harden.conf
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.printk=3 3 3 3
kernel.unprivileged_bpf_disabled=1
net.core.bpf_jit_harden=2
dev.tty.ldisc_autoload=0
vm.unprivileged_userfaultfd=0
kernel.kexec_load_disabled=1
kernel.sysrq=4
kernel.unprivileged_userns_clone=0
kernel.perf_event_paranoid=3
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_rfc1337=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.icmp_echo_ignore_all=1
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_source_route=0
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.default.accept_ra=0
net.ipv4.tcp_sack=0
net.ipv4.tcp_dsack=0
net.ipv4.tcp_fack=0
kernel.yama.ptrace_scope=2
vm.mmap_rnd_bits=32
vm.mmap_rnd_compat_bits=16
fs.protected_symlinks=1
fs.protected_hardlinks=1
fs.protected_fifos=2
fs.protected_regular=2
vm.swappiness=35

## D Issue
-- WARNING -- This system is for the use of authorized users only. Individuals
using this computer system without authority or in excess of their authority
are subject to having all their activities on this system monitored and
recorded by system personnel. Anyone using this system expressly consents to
such monitoring and is advised that if such monitoring reveals possible
evidence of criminal activity system personal may provide the evidence of such
monitoring to law enforcement officials.

## G FILES
# G.1 gentoo.conf

nvim  /etc/portage/repos.conf/gentoo.conf
[DEFAULT]
main-repo = gentoo

[gentoo]
location = /var/db/repos/gentoo
sync-type = git
sync-uri = https://github.com/gentoo-mirror/gentoo.git
auto-sync = yes
sync-git-verify-commit-signature = yes
sync-openpgp-key-path = /usr/share/openpgp-keys/gentoo-release.asc

# G2 nvidia.conf
nvim /etc/modprobe.d/nvidia.conf
options nvidia-drm modeset=1
options nvidia NVreg_UsePageAttributeTable=1

# G3 nvidia-powermanagement.conf
nvim /etc/modprobe.d/nvidia-power-management.conf
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/tmp

# G4 /etc/security/limits.conf
nvim /etc/security/limits.conf
*    soft core 0
*    hard core 0
*    hard nproc 15
*    hard rss 10000
*    -    maxlogins 2
@dev hard core 100000
@dev soft nproc 20
@dev hard nproc 35
@dev -    maxlogins 10


## H Misc
#H1 scaling apps
--force-device-scale-factor=1.75 %U

# H2 setting password time
sudo chage --mindays 40 \
--maxdays 120 --warndays 30 ahsan

# H3 chrome sandbox
sudo chown root:root chrome-sandbox
sudo chmod 4755 chrome-sandbox

# TODOS - NORMAL NVIM & ASTRONVIM

# TODOS - Customizing Hyprland DE

- [ ] Get Inspiractions from awesome-rices github-repo and whatsappm list repos
- [ ] Combine waybar, HyprPanel - Ags (for bar widgets and osd), and rofi (launchers and android applets)
- [ ] Get waybar from https://github.com/raexera/yuki
- [ ] For rofi launchers-type-6-style-7
- [ ] Use linkfrg dotfiles animations

# TODOS - General

- [ ] Learn how to setup borg for automatic documents backup
- [ ] Copy configs from jakoolit and end-4
- [ ] Setup nvhpc later on worksation
- [ ] Setup gnome-software or discover to install flatpak and snap packages
- [ ] Install firewalld after finishing full system install
- [ ] Use Chatgpt to setup emacs config for latex setup
- [ ] Use foot terminal for pyprland and yazi
- [ ] Use alacritty as the main terminal
- [ ] Use tgpt to setup gpt
- [ ] go install github.com/hyprland-community/hyprls/cmd/hyprls@lates
- [ ] determine all rust based packages in gentoo and add compiler-clang-lto to it
  - [X] gui-apps/alacritty-graphics
  - [X] app-shells/atuin
  - [X] sys-apps/bat
  - [X] sys-process/bottom
  - [X] app-misc/czkawka
  - [x] sys-apps/eza
  - [X] sys-apps/fd
  - [X] dev-util/git-delta
  - [X] sys-apps/ripgrep
  - [x] app-shells/starship
  - [X] app-misc/yazi
  - [X] app-shells/zoxide
- [ ] Create ebuilds for apparmor and libraries in custom repo using ubuntu sources
    - [ ] sys-apps/apparmor
    - [ ] sys-apps/apparmor-utils
    - [ ] sys-libs/libapparmor
    - [ ] sec-policy/apparmor-profiles
- [ ] Create 9999 ebuilds for the following packages:
    - [x] gui-wm/hyprland
		- [x]	dev-libs/hyprgraphics
		- [x]	dev-libs/hyprlang
		- [x]	gui-libs/aquamarine
		- [x]	gui-libs/hyprcursor
		- [x]	gui-libs/hyprutils
		- [x]	dev-libs/hyprland-protocols
		- [x] dev-util/hyprwayland-scanner
		- [x]	gui-libs/xdg-desktop-portal-hyprland
		- [x]	gui-apps/hypridle
		- [x]	gui-apps/hyprlock
		- [x]	gui-apps/hyprpaper
		- [x]	gui-apps/hyprpicker
		- [x]	gui-wm/hyprland-contrib
		- [x]	gui-apps/hyprsunset
		- [x]	gui-apps/uwsm
    - [x] app-shells/zsh-autosuggestions
    - [x] app-shells/zsh-completions
    - [x] app-shells/zsh-history-substring-search
    - [x] app-shells/zsh-syntax-highlighting
    - [x] app-shells/fzf-tab
    - [x] dev-util/dart-sass
    - [x] gui-apps/alacritty-graphics
    - [ ] go packages ebuild - borrow from nwg-look
    - [ ] app-misc/pyprland
    - [ ] sys-kernel/cachyos-settings
    - [ ] sys-process/cachyos-ksm-settings
    - [ ] app-admin/ananicy-cpp
    - [ ] app-admin/ananicy-rules-cachyos
- [ ] Complete app-emacs/* packages list
- [ ] Create app-emacs/* ebuilds for packages not installing
- [ ] Add compile-angel to byte compile and native compile all emacs libraries
- [ ] Recreate all config files inside an org file that tangles files to appropriate location. Only this org file is required.
- [x] Remove traces of python 3.13 from the system
- [x] Remove 20 version llvm-core and llvm-runtimes
- [ ] Install apparmor profiles from https://github.com/roddhjav/apparmor.d inside sec-policy/apparmor-profiles
- [ ] Check gentoo's Hyprland page to setup  portals
- [X] Apply graphite optimization to gcc later on
- [ ] Setup Arpwatch later down the line
- [ ] Consider SecurityOnion for deploying in my house and look at youtube videos
- [ ] Start foot as a server
- [ ] Learn how to autostart cliphist on startup
- [ ] Setup zram using zram-init
- [ ] Add these asus modules to dracut: hid_asus asus_wmi asus_nb_wmi
- [X] Setup graphite flags in package.env like clang https://wiki.gentoo.org/wiki/Clang
- [ ] Add current neovim config to dotfiles
- [ ] Add kernel integrity subsystem support using https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/managing_monitoring_and_updating_the_kernel/enhancing-security-with-the-kernel-integrity-subsystem_managing-monitoring-and-updating-the-kernel#enhancing-security-with-the-kernel-integrity-subsystem_managing-monitoring-and-updating-the-kernel
- [ ] Add zsh plugins paths to zsh config
- [ ] Mark which repos to follow for package build
- [ ] Fix yank and paste in neovim
- [ ] Install tmux and look at vim-syntax scripts
- [ ] Follow lunarvim maintainer's astrovim config
- [ ] Create  a cron job using  to update packages weekly from different sources:
    - [ ]  update using emerge
    - [ ] update texlive packages
    - [ ] emacs packages
- [ ] Combine astronvim and normal nvim
- [ ] For normal nvim: paru -S --needed "luarocks" "python" "yazi" "fd" "git-delta" "grcov" "rustup" "yarn" "python-pytest" "gcc" "binutils" "dotnet-runtime" "dotnet-sdk" "aspnet-runtime" "mono" "jdk-openjdk" "dart" "kotlin" "elixir" "npm" "nodejs" "typescript" "make" "go" "nasm" "r" "nuitka" "python" "ruby" "perl" "lua" "pyinstaller" "swift-bin" "gcc-fortran" "fortran-fpm-bin" "doxygen" "ldoc" "ruby-yard"; yarn global add "jest" "jsdoc" "typedoc"; cargo install "cargo-nextest"; go install "golang.org/x/tools/cmd/godoc@latest"
- [ ] Switch to vivaldi browser
- [ ] Replace straight with emacs built-in package manager
- [ ] :pin org in (use-package org)
- [ ] Install yazi plugins
- [ ] Switch from catppuccin to gruvbox colorscheme
- [ ] Enable autopairs in neovim
- [ ] Use modprobed-db to use localmodconfig
- [X] Apply polly optimizations to clang/llvm and its packages
- [X] Add the following custom systemd user services:
      * polkit-mate
      * hyrpm reload -n
      * hyprtheme
      * ags themeing
      * xdg-desktop-portal-hyprland

 #NOTE: EGIT_REPO_URI="https://github.com/hyprwm/${PN^}.git"

# MISC
## Btrfs swap
btrfs su cr @swap
mkdir /swap
mount -o defaults,subvol=@swap /dev/mapper/cryptroot /swap
mkswap -U clear --size 16G --file /swap/swapfile
swapon /swap/swapfile

## Systemd-boot Setup
<!--bootclt install-->
<!--nvim /boot/loader/loader.conf-->
<!--default b1600d8c2083b7b59a984e1a673d4739*-->
<!--timeout 5-->
<!--console-mode auto-->

<!--nvim /boot/loader/entries/b1600d8c2083b7b59a984e1a673d4739-6.6.62-cachyos-6.6.62.conf (autogenerated)-->
<!--# Boot Loader Specification type#1 entry-->
<!--# File created by /usr/lib/kernel/install.d/90-loaderentry.install (systemd 256.7)-->
<!--title      Gentoo Linux-->
<!--version    6.6.62-cachyos-6.6.62-->
<!--machine-id b1600d8c2083b7b59a984e1a673d4739-->
<!--sort-key   gentoo-->
<!--options    nvme_load=YES nowatchdog rw rootflags=subvol=/@ rd.luks.uuid=be21e075-9797-43a1-8b51-856a11bc03a5 root=/dev/mapper/luks-be21e075-9797-43a1-8b51-856a11bc03a5 nvidia_drm.modeset=1 systemd.machine_id=8b0213fba2c14dc9a50d3ee41931eea0-->
<!--linux      /b1600d8c2083b7b59a984e1a673d4739/6.6.62-cachyos-6.6.62/linux-->
<!--initrd     /b1600d8c2083b7b59a984e1a673d4739/6.6.62-cachyos-6.6.62/initrd-->
<!---->

## Find class of an app
 - hyprctl clients | grep -i class

# POST-INSTALL CHROOT
## Without LVM
cryptsetup luksOpen /dev/nvme0n1p2 cryptroot  &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@ /dev/mapper/cryptroot /mnt/gentoo &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@home /dev/mapper/cryptroot /mnt/gentoo/home &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@opt /dev/mapper/cryptroot /mnt/gentoo/opt &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@root /dev/mapper/cryptroot /mnt/gentoo/root &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@nix /dev/mapper/cryptroot /mnt/gentoo/nix &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@usr@local /dev/mapper/cryptroot /mnt/gentoo/usr/local &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@var /dev/mapper/cryptroot /mnt/gentoo/var &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@var@cache /dev/mapper/cryptroot /mnt/gentoo/var/cache &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@var@crash /dev/mapper/cryptroot /mnt/gentoo/var/crash &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@var@log /dev/mapper/cryptroot /mnt/gentoo/var/log &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@var@log@audit /dev/mapper/cryptroot /mnt/gentoo/var/log/audit &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@var@tmp /dev/mapper/cryptroot /mnt/gentoo/var/tmp &&
  mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@var@spool /dev/mapper/cryptroot /mnt/gentoo/var/spool &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@snapshots /dev/mapper/cryptroot /mnt/gentoo/.snapshots &&
  mkdir --parents /mnt/gentoo/etc/portage/repos.conf &&
  cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf &&
  cp --dereference /etc/resolv.conf /mnt/gentoo/etc/ &&
  mount --types proc /proc /mnt/gentoo/proc &&
  mount --rbind /sys /mnt/gentoo/sys && mount --make-rslave /mnt/gentoo/sys &&
  mount --rbind /dev /mnt/gentoo/dev && mount --make-rslave /mnt/gentoo/dev &&
  mount --bind /run /mnt/gentoo/run && mount --make-slave /mnt/gentoo/run &&
  test -L /dev/shm &&
  rm /dev/shm && mkdir /dev/shm &&
  mount -t tmpfs -o nosuid,nodev,noexec shm /dev/shm && chmod 1777 /dev/shm

## With LVM
cryptsetup luksOpen /dev/nvme0n1p2 cryptlvm  &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@ /dev/vg0/root /mnt/gentoo &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@home /dev/vg0/root /mnt/gentoo/home &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@opt /dev/vg0/root /mnt/gentoo/opt &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@root /dev/vg0/root /mnt/gentoo/root &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@nix /dev/vg0/root /mnt/gentoo/nix &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@usr@local /dev/vg0/root /mnt/gentoo/usr/local &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@var /dev/vg0/root /mnt/gentoo/var &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@var@cache /dev/vg0/root /mnt/gentoo/var/cache &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@var@crash /dev/vg0/root /mnt/gentoo/var/crash &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@var@log /dev/vg0/root /mnt/gentoo/var/log &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@var@log@audit /dev/vg0/root /mnt/gentoo/var/log/audit &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@var@tmp /dev/vg0/root /mnt/gentoo/var/tmp &&
  mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@var@spool /dev/vg0/root /mnt/gentoo/var/spool &&
  mount -o noatime,compress=zstd,space_cache=v2,discard=async,subvol=@snapshots /dev/vg0/root /mnt/gentoo/.snapshots &&
  mkdir --parents /mnt/gentoo/etc/portage/repos.conf &&
  cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf &&
  cp --dereference /etc/resolv.conf /mnt/gentoo/etc/ &&
  mount --types proc /proc /mnt/gentoo/proc &&
  mount --rbind /sys /mnt/gentoo/sys && mount --make-rslave /mnt/gentoo/sys &&
  mount --rbind /dev /mnt/gentoo/dev && mount --make-rslave /mnt/gentoo/dev &&
  mount --bind /run /mnt/gentoo/run && mount --make-slave /mnt/gentoo/run &&
  test -L /dev/shm &&
  rm /dev/shm && mkdir /dev/shm &&
  mount -t tmpfs -o nosuid,nodev,noexec shm /dev/shm && chmod 1777 /dev/shm

## F Chroot into existing gentoo
cd /mnt/gentoo
chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) ${PS1}"

mount /dev/nvme0n1p1 /boot
swapon /dev/vg0/swap

