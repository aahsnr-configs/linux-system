**_To setup selinux for desktop (not yet running in my system), in two primary way: (1)the SELinux stage3 tarballs that are available and supported - this is significantly easier than performing the steps below. The tarballs can be simply unpacked onto a target system, relabel the entire system, add the initial user to the administration SELinux user and reboot; or (2) follow the guideline put forwared in <https://wiki.gentoo.org/wiki/SELinux/Installation>_**

# Disk Preparation

## Setup LVM

```sh
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
```

## Subvolumes

```sh
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
```

## Mount Drives

```sh
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
```

# Setup Host System for Installing Gentoo and its Packages

## Setup Base Environment

[!Note]: You may need update the source tar.xz file

```sh
cd /mnt/gentoo && wget https://distfiles.gentoo.org/releases/amd64/autobuilds/20250413T165021Z/stage3-amd64-desktop-openrc-20250413T165021Z.tar.xz && tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner && mkdir --parents /mnt/gentoo/etc/portage/repos.conf && cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf && cp --dereference /etc/resolv.conf /mnt/gentoo/etc/ && mount --types proc /proc /mnt/gentoo/proc && mount --rbind /sys /mnt/gentoo/sys && mount --make-rslave /mnt/gentoo/sys && mount --rbind /dev /mnt/gentoo/dev && mount --make-rslave /mnt/gentoo/dev && mount --bind /run /mnt/gentoo/run && mount --make-slave /mnt/gentoo/run && test -L /dev/shm && rm /dev/shm && mkdir /dev/shm && mount -t tmpfs -o nosuid,nodev,noexec shm /dev/shm && chmod 1777 /dev/shm
```

## Copy System Configuration Files to **/mnt/gentoo**

```sh
rm -R /mnt/gentoo/etc/portage/make.conf && rm -R /mnt/gentoo/etc/portage/package.accept_keywords && rm -R /mnt/gentoo/etc/portage/package.use && rm -R /mnt/gentoo/etc/portage/package.mask && cp -R /home/ahsan/.dots/gentoo/preconfig_files/with_selinux/etc/portage/* /mnt/gentoo/etc/portage/ && cp -R /home/ahsan/.dots/gentoo/preconfig_files/with_selinux/.nanorc /mnt/gentoo/root/  && cp -R /home/ahsan/.dots/gentoo/preconfig_files/with_selinux/tc-optimize /mnt/gentoo/root/
```

## Chroot into Gentoo

[!Note]: Run the following commands one-by-one

```sh
chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) ${PS1}"

mount /dev/nvme0n1p1 /boot
```

# Setting Up Chroot for Installing Packages

## Initial Sync

```sh
emerge-webrsync && emerge --sync && eselect profile list
```

## Setup Locales

```sh
ln -sf ../usr/share/zoneinfo/Asia/Dhaka /etc/localtime && nano /etc/locale.gen && locale-gen && eselect locale list && eselect locale set 4 && env-update && source /etc/profile && export PS1="(chroot) ${PS1}"
```

# PORTAGE && ITS REPOS

```sh
emerge -aq --jobs=5 app-eselect/eselect-repository dev-vcs/git && eselect repository remove gentoo && eselect repository add gentoo git https://github.com/gentoo-mirror/gentoo.git  && emaint sync -r gentoo && eselect repository enable guru pentoo edgets gentoo-zh CachyOS-kernels xarblu-overlay && eselect repository create custom && emerge --sync
```

# PERSONAL REPOS

- eselect repository create custom
- emerge pkgdev
- sudo cp -R /home/ahsan/.dots/gentoo/preconfig_files/repos/custom/\* /mnt/gentoo/var/db/repos/custom/
- cd var/db/repos/custom/
- pkgdev manifest

# MODIFICATIONS

- add pypy3_11 python3_13 to python targets
- re-emerge clang/llvm packages with compiler-clang-lto
- emerge dev-lang/python:3.13::custom with compiler-clang-lto

# SETUP USER

echo zephyrus > /etc/hostname && emerge app-admin/sudo genfstab && passwd && useradd -m -G users,wheel,audio,video -s /bin/bash ahsan && passwd ahsan && EDITOR=nvim visudo

# FSTAB

/swap/swapfile none swap defaults,subvol=@swap 0 0

mount /dev/nvme0n1p1 /boot
genfstab -U / >> /etc/fstab

emerge -ev @world --exclude gcc clang python llvm nodejs rust

# KERNEL

## Packages

emerge sys-kernel/gentoo-sources sys-kernel/linux-firmware sys-kernel/linux-headers sys-apps/fwupd sys-fs/cryptsetup sys-firmware/sof-firmware sys-fs/genfstab sys-kernel/installkernel sys-kernel/modprobed-db sys-fs/btrfs-progs sys-apps/rng-tools sys-apps/kbd dev-build/automake sys-apps/dbus && eselect kernel set 1 && ls -l /usr/src/linux

## Modules

\*\* gentoo config examples

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

[!NOTE] : Sample refind config
/usr/lib64/refind/refind/refind.conf-sample

`lsblk -o name,uuid`
# example
nvme0n1
└─nvme0n1p1 4bb45bd6-9ed9-44b3-b547-b411079f043b
└─root cb070f9e-da0e-4bc5-825c-b01bb2707704

kernel_cmdline+=" root=UUID=cb070f9e-da0e-4bc5-825c-b01bb2707704 rd.luks.uuid=4bb45bd6-9ed9-44b3-b547-b411079f043b "

kernel_cmdline+=" root=UUID=<UUID of /dev/mapper/cryptroot> rd.luks.uuid=<UUID of /dev/nvme0n1p2> "

# actual
nvme0n1
|-nvme0n1p1 1778-CF2B
|-nvme0n1p2 f6502e18-76b2-4e98-9f68-a082d6dc60ae
|\_\_cryptroot e8f3ea91-e5b8-4c25-9a52-bc789d90f3f4

# actual
nvme0n1
├─nvme0n1p1 6B7E-166F
└─nvme0n1p2 330a6486-116f-4c74-b282-319ab6c45c53
└─cryptlvm H2jC9K-5PZI-5RL6-EN7l-kaJl-oyM3-pGQoGN
├─vg0-swap 8ae4b3bb-2c21-4b4a-a2f6-d0a708d0a240
└─vg0-root 85b93843-925a-41ce-bc2c-b401f8e857a1

nvme0n1  
├─nvme0n1p1 26FC-E891
└─nvme0n1p2 84eaf03a-2d7a-440a-aa2f-cdf63d67b3da
└─cryptlvm hbyaUi-q9Zv-1q0b-mI7d-0LhM-yaXB-p1tppR
├─vg0-swap 5a4d6d84-9b4f-448a-9522-48897cd5be33
└─vg0-root ffedb9b8-db07-46e7-b4f1-b0ce0b9209b2

## DRACUT

### dracut --print-cmdline opensuse

rd.driver.pre=btrfs rd.luks.uuid=luks-70522737-f570-45c1-8173-7ffc6a7225d6 rd.lvm.lv=system/swap rd.lvm.lv=system/root resume=UUID=5241390b-0fe2-4273-bc97-ecc6e5f6a814 root=UUID=81df9190-81e6-4eaf-bff3-03238a72665e rootfstype=btrfs rootflags=rw,relatime,ssd,space_cache=v2,subvolid=266,subvol=/@/.snapshots/1/snapshot,subvol=@/.snapshots/1/snapshot

### dracut --print-cmdline gentoo

rd.driver.pre=btrfs rd.luks.uuid=luks-84eaf03a-2d7a-440a-aa2f-cdf63d67b3da rd.lvm.lv=vg0/swap rd.lvm.lv=vg0/root resume=UUID=5a4d6d84-9b4f-448a-9522-48897cd5be33 root=UUID=ffedb9b8-db07-46e7-b4f1-b0ce0b9209b2 rootfstype=btrfs

#### With LVM

mkdir /etc/dracut.conf.d/ && nvim /etc/dracut.conf.d/dracut.conf
hostonly="yes"
compress="zstd"
add_dracutmodules+=" crypt dm rootfs-block resume lvm "
omit_dracutmodules+=" network cifs nfs nbd brltty "
force_drivers+=" btrfs "
kernel_cmdline+=" rd.luks.uuid=84eaf03a-2d7a-440a-aa2f-cdf63d67b3da root=UUID=ffedb9b8-db07-46e7-b4f1-b0ce0b9209b2 resume=UUID=5a4d6d84-9b4f-448a-9522-48897cd5be33 rd.lvm.lv=vg0/swap rd.lvm.lv=vg0/root "

#### Associated Grub

nvim /etc/default/grub
GRUB_CMDLINE_LINUX="rootfstype=btrfs quiet loglevel=0 rw rd.vconsole.keymap=us rd.luks.uuid=84eaf03a-2d7a-440a-aa2f-cdf63d67b3da root=UUID=ffedb9b8-db07-46e7-b4f1-b0ce0b9209b2 resume=UUID=5a4d6d84-9b4f-448a-9522-48897cd5be33 rd.lvm.lv=vg0/swap rd.lvm.lv=vg0/root"
GRUB_CMDLINE_LINUX_DEFAULT=""

grub-install --target=x86_64-efi --efi-directory=/boot && grub-mkconfig -o /boot/grub/grub.cfg

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

### Building the kernel

```sh
make nconfig LLVM=1 KCFLAGS="-O3 -march=native -pipe -flto=thin -fno-math-errno -fno-signed-zeros -fno-trapping-math -fcf-protection -D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS -fstack-protector-strong -fstack-clash-protection -fplugin=LLVMPolly.so -mllvm=-polly -mllvm=-polly-vectorizer=stripmine -mllvm=-polly-omp-backend=LLVM -mllvm=-polly-parallel -mllvm=-polly-num-threads=9 -mllvm=-polly-scheduling=dynamic"
```

```sh
make -j10 LLVM=1 KCFLAGS="-O3 -march=native -pipe -flto=thin -fno-math-errno -fno-signed-zeros -fno-trapping-math -fcf-protection -D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS -fstack-protector-strong -fstack-clash-protection -fplugin=LLVMPolly.so -mllvm=-polly -mllvm=-polly-vectorizer=stripmine -mllvm=-polly-omp-backend=LLVM -mllvm=-polly-parallel -mllvm=-polly-num-threads=9 -mllvm=-polly-scheduling=dynamic"
```

```sh
emerge x11-drivers/nvidia-drivers gui-libs/egl-wayland gui-libs/egl-gbm gui-libs/egl-x11 media-libs/nvidia-vaapi-driver sys-process/nvtop x11-drivers/xf86-video-amdgpu
```

```sh
make modules_install -j14 llvm=1 KCFLAGS="-O3 -march=native -pipe -flto=thin -fno-math-errno -fno-signed-zeros -fno-trapping-math -fcf-protection -d_fortify_source=3 -d_glibcxx_assertions -fstack-protector-strong -fstack-clash-protection -fplugin=llvmpolly.so -mllvm=-polly -mllvm=-polly-vectorizer=stripmine -mllvm=-polly-omp-backend=llvm -mllvm=-polly-parallel -mllvm=-polly-num-threads=9 -mllvm=-polly-scheduling=dynamic"
```

```sh
make install -j14 LLVM=1 KCFLAGS="-O3 -march=native -pipe -flto=thin -fno-math-errno -fno-signed-zeros -fno-trapping-math -fcf-protection -D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS -fstack-protector-strong -fstack-clash-protection -fplugin=LLVMPolly.so -mllvm=-polly -mllvm=-polly-vectorizer=stripmine -mllvm=-polly-omp-backend=LLVM -mllvm=-polly-parallel -mllvm=-polly-num-threads=9 -mllvm=-polly-scheduling=dynamic"
```

# System Packages

```sh
emerge --ask  \
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
  dev-libs/tree-sitter-bash \
  dev-libs/tree-sitter-html \
  dev-libs/re2 \
  dev-libs/udis86 \
  dev-libs/wayland \
  dev-libs/wayland-protocols \
  dev-lua/luarocks \
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
  dev-python/setuptools \
  dev-python/wheel \
  dev-qt/qtbase \
  dev-qt/qtdeclarative \
  dev-qt/qtwayland \
  dev-util/git-delta \
  dev-util/dart-sass \
  dev-util/hyprwayland-scanner \
  dev-util/lua-language-server \
  dev-util/tree-sitter-cli \
  dev-util/vulkan-headers \
  dev-util/wayland-scanner \
  dev-vcs/git \
  dev-vcs/lazygit \
  dev-vcs/git-lfs \
  gnome-base/librsvg \
  gui-apps/grim \
  gui-apps/hypridle \
  gui-apps/hyprlock \
  gui-apps/hyprpaper \
  gui-apps/hyprpicker \
  gui-apps/hyprsunset \
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
  sys-apps/bat \
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
  x11-themes/papirus-icon-theme \
  xfce-base/thunar \
  xfce-base/thunar-volman \
  xfce-base/tumbler \
  xfce-extra/thunar-archive-plugin \
  xfce-extra/thunar-media-tags-plugin \
  www-apps/element \
  www-client/zen-browser-bin \
  gnome-base/gvfs \
  sys-fs/genfstab \
  sys-fs/cryptsetup \
  app-backup/grub-btrfs \
  net-wireless/iwd
```

# OPENRC

rc-update add dhcpcd default && rc-service dhcpcd start && \
 rc-update delete wpa_supplicant && rc-service wpa_supplicant stop

# SYSTEMD

systemctl enable dhcpcd iwd auditd apparmor rngd

# SETUP NETWORK - DHPCD

- Use the following guides to setup networking using dhcpcd
  - <https://wiki.gentoo.org/wiki/Systemd/systemd-networkd>
  - <https://wiki.gentoo.org/wiki/Network_management_using_DHCPCD>

- [-] To get the name of network interface, use `ifconfig -a`

cd /etc/init.d &&
ln -s net.lo net.wlan0 &&
rc-update add net.wlan0 default && cd

## Packages

emerge net-misc/dhcpcd net-wireless/wpa_supplicant

# SYSTEMD

- use systemd-networkd instead of network-manager
  systemctl enable dhcpcd sysstat auditd rngd nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service nvidia-powerd.service systemd-timesyncd dhpc

## C setup snapper

sudo umount /.snapshots/ && sudo rm -r /.snapshots/ && sudo snapper -c root create-config / && sudo btrfs subvolume delete /.snapshots && sudo mkdir /.snapshots && sudo mount -a && sudo chmod 750 /.snapshots && sudo lvim /etc/snapper/configs/root && sudo systemctl enable --now snapper-timeline.timer && sudo systemctl enable --now snapper-cleanup.timer

## D Sysctl

`sudo nvim /etc/sysctl.d/harden.conf`

```sh
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.printk=3
kernel.unprivileged_bpf_disabled=1
net.core.bpf_jit_harden=2
dev.tty.ldisc_autoload=0
vm.unprivileged_userfaultfd=0
kernel.kexec_load_disabled=1
kernel.kptr_restrict=2
kernel.sysrq=0
net.ipv4.conf.all.log_martians=1
kernel.unprivileged_userns_clone=0
kernel.perf_event_paranoid=3
net.ipv4.tcp_syncookies=1
net.ipv4.conf.default.log_martians=1
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
kernel.yama.ptrace_scope=1
vm.mmap_rnd_bits=32
vm.mmap_rnd_compat_bits=16
fs.protected_symlinks=1
fs.protected_hardlinks=1
fs.protected_fifos=2
fs.protected_regular=2
fs.suid_dumpable=0
vm.swappiness=35
```

## D Issue

nvim /etc/issue && nvim /etc/issue.net

```
-- WARNING -- This system is for the use of authorized users only. Individuals
using this computer system without authority or in excess of their authority
are subject to having all their activities on this system monitored and
recorded by system personnel. Anyone using this system expressly consents to
such monitoring and is advised that if such monitoring reveals possible
evidence of criminal activity system personal may provide the evidence of such
monitoring to law enforcement officials.
```

## G FILES

# G.1 gentoo.conf

nvim /etc/portage/repos.conf/gentoo.conf

```sh
[DEFAULT]
main-repo = gentoo

[gentoo]
location = /var/db/repos/gentoo
sync-type = git
sync-uri = https://github.com/gentoo-mirror/gentoo.git
auto-sync = yes
sync-git-verify-commit-signature = yes
sync-openpgp-key-path = /usr/share/openpgp-keys/gentoo-release.asc
```

# G2 nvidia.conf

nvim /etc/modprobe.d/nvidia.conf
options nvidia-drm modeset=1
options nvidia NVreg_UsePageAttributeTable=1

# G3 nvidia-powermanagement.conf

nvim /etc/modprobe.d/nvidia-power-management.conf
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/tmp

# G4 /etc/security/limits.conf

nvim /etc/security/limits.conf

```
*    soft core 0
*    hard core 0
*    hard nproc 15
*    hard rss 10000
*    -    maxlogins 2
@dev hard core 100000
@dev soft nproc 20
@dev hard nproc 35
@dev -    maxlogins 10
```

## H Misc

# H1 scaling apps
--force-device-scale-factor=1.75 %U

# H2 setting password time

sudo chage --mindays 40 \
--maxdays 120 --warndays 30 ahsan

# H3 chrome sandbox

sudo chown root:root chrome-sandbox
sudo chmod 4755 chrome-sandbox

# MISC

## Find class of an app

- hyprctl clients | grep -i class

## Messages for package sys-fs/btrfsmaintenance-0.5.2

```
 * Installing default btrfsmaintenance scripts
 * Now edit cron periods and mount points in /etc/default/btrfsmaintenance
 * then run /usr/share/btrfsmaintenance/btrfsmaintenance-refresh-cron.sh to
 * update cron symlinks or run
 * /usr/share/btrfsmaintenance/btrfsmaintenance-refresh-cron.sh systemd-timer
 * to update systemd timers.
 * You can also enable btrfsmaintenance-refresh.path service in order to
 * monitor the config files changes and update systemd timers accordl
```

# POST-INSTALL CHROOT

## Without LVM

```sh
cryptsetup luksOpen /dev/nvme0n1p2 cryptroot

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
```

## With LVM

```sh
cryptsetup luksOpen /dev/nvme0n1p2 cryptlvm

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
```

## F Chroot into existing gentoo

```sh
cd /mnt/gentoo
chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) ${PS1}"

mount /dev/nvme0n1p1 /boot
swapon /dev/vg0/swap
```

# GENERAL COMMANDS

```sh
- emacs --batch --eval "(require 'org)" --eval '(org-babel-tangle-file "file-to-tangle.org")'
- #+begin_src python  :shebang "#!/usr/bin/env python"

- grep 'app-emacs/' /var/lib/portage/world | xargs --open-tty emerge --ask --deselect; emerge --ask --depclean

- esearch esearch -I emacs #list all installed emacs packages

- :shebang #!/usr/bin/env bash

- PY_CFLAGS:
python3 -c "import sysconfig; print(sysconfig.get_config_var('PY_CFLAGS') + sysconfig.get_config_var('PY_CFLAGS_NODIST'))"

- find / -name ".git"


```
