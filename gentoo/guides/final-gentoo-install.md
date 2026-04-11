# Gentoo Desktop Installation: ZFS Native Encryption, ZFSBootMenu, SELinux Targeted Policy, CachyOS Kernel, NVIDIA Open Modules & CUDA – A Unified Guide

**Revision Notes:** This document corrects critical ZFS structure issues (missing `rpool/ROOT`, missing `canmount=noauto`, broken encryption inheritance), fixes path inconsistencies (standardizing on `/mnt/gentoo`), resolves hostid persistence timing, encrypts the swap zvol, and integrates the mandatory `@world` update step for SELinux consistency before kernel compilation.

---

## ⚠️ Critical Decision Point: EFI System Partition (ESP) Mount Location

**Decision:** Mount the ESP at `/boot/efi`.
**Justification:**

- **ZFS Dataset Isolation:** ZFS manages `/` and sub-datasets natively. Mounting ESP at `/boot` pollutes the root dataset with firmware files and complicates ZFSBootMenu's boot environment detection.
- **systemd & installkernel Compliance:** Modern `sys-kernel/installkernel` and `systemd` expect `/boot/efi` as the canonical ESP mount. This ensures `efibootmgr` entries and fallback paths (`/boot/efi/EFI/BOOT/BOOTX64.EFI`) are handled without manual ZFS hook overrides.

All phases assume `ESP=/dev/nvme0n1p1` mounted at `/boot/efi`.

---

## Phase 0: Preparation & Environment Validation

```bash
set -e
ping -c2 8.8.8.8 || { echo "❌ No internet."; exit 1; }
lsblk | grep -q nvme || { echo "❌ NVMe drives missing."; exit 1; }
read -p "⚠️ Wipe /dev/nvme0n1 & /dev/nvme1n1? Type YES: " c
[[ "$c" != "YES" ]] && exit 1

zgenhostid -f 0x00bab10c

echo "✅ Environment validated and hostid generated on LiveCD."
```

---

## Phase 1: Partitioning

```bash
wipefs -a /dev/nvme0n1 /dev/nvme1n1
sgdisk -Z /dev/nvme0n1 /dev/nvme1n1

# Drive 1: ESP + ZFS
sgdisk -n 1:0:+600M -t 1:ef00 -c 1:"EFI_SYSTEM" /dev/nvme0n1
sgdisk -n 2:0:0    -t 2:bf01 -c 2:"ZFS_VDEV1"  /dev/nvme0n1

# Drive 2: ZFS only
sgdisk -n 1:0:0    -t 1:bf01 -c 1:"ZFS_VDEV2"  /dev/nvme1n1

partprobe /dev/nvme0n1 /dev/nvme1n1
sleep 2
echo "✅ Partitioning complete."
```

---

## Phase 2: ZFS Pool & Datasets (Encrypted Swap Included)

```bash
zpool create -f -o ashift=12 -o autotrim=on -O relatime=on \
  -O compression=zstd -O acltype=posixacl -O xattr=sa \
  -O mountpoint=none -R /mnt/gentoo \
  rpool /dev/nvme0n1p2 /dev/nvme1n1p1

zfs create -o mountpoint=none rpool/ROOT

zfs create -o encryption=aes-256-gcm -o keyformat=passphrase \
  -o keylocation=prompt -o mountpoint=/ -o canmount=noauto rpool/ROOT/gentoo

# Designate this dataset as the bootable root (required by ZFSBootMenu)
zpool set bootfs=rpool/ROOT/gentoo rpool
zfs create -o mountpoint=/home      rpool/ROOT/gentoo/home
zfs create -o mountpoint=/var       rpool/ROOT/gentoo/var
zfs create -o mountpoint=/opt       rpool/ROOT/gentoo/opt
zfs create -o mountpoint=/srv       rpool/ROOT/gentoo/srv
zfs create -o mountpoint=none       rpool/ROOT/gentoo/usr  # Parent for /usr/local
zfs create -o mountpoint=/usr/local rpool/ROOT/gentoo/usr/local
zfs create -o mountpoint=/nix -o compression=zstd rpool/ROOT/gentoo/nix
zfs create -o mountpoint=/var/log   rpool/ROOT/gentoo/var/log
zfs create -o mountpoint=/var/cache rpool/ROOT/gentoo/var/cache
zfs create -o mountpoint=/var/tmp   rpool/ROOT/gentoo/var/tmp

zfs create -V 32G -o volblocksize=16K -o compression=zle \
  -o logbias=throughput -o sync=always \
  -o primarycache=metadata -o secondarycache=none \
  -o com.sun:auto-snapshot=false rpool/ROOT/gentoo/swap
mkswap -L "zfs-swap" /dev/zvol/rpool/ROOT/gentoo/swap

# Format and mount the ESP
mkfs.fat -F32 /dev/nvme0n1p1
mkdir -p /mnt/gentoo/boot/efi
mount /dev/nvme0n1p1 /mnt/gentoo/boot/efi
echo "✅ ZFS layout & ESP mounted."
```

---

## Phase 3: Bootstrap & Chroot

```bash
cd /mnt/gentoo

# Download and verify the hardened+SELinux+systemd stage3 tarball
# The mirror file lists a relative path; we must prepend the full base URL.
STAGE_BASE="https://distfiles.gentoo.org/releases/amd64/autobuilds"
STAGE_REL=$(curl -sL "${STAGE_BASE}/latest-stage3-amd64-hardened-selinux-systemd.txt" \
  | grep -v '^#' | grep '\.tar\.xz' | awk '{print $1}')
wget "${STAGE_BASE}/${STAGE_REL}"
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
rm -f stage3-*.tar.xz

# CRITICAL: Copy hostid AFTER stage3 extraction.
# This ensures the hostid is written to the ZFS pool at /mnt/gentoo/etc,
# not buried by the mount process or overwritten by the tarball extraction.
mkdir -p /mnt/gentoo/etc
cp /etc/hostid /mnt/gentoo/etc/hostid

# Copy DNS resolver config so emerge --sync works inside the chroot
cp /etc/resolv.conf /mnt/gentoo/etc/resolv.conf

# Copy portage repository configuration (required for emerge --sync)
mkdir -p /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf

# Bind-mount virtual filesystems
for dir in dev proc sys run; do
  mount --rbind /$dir /mnt/gentoo/$dir
  mount --make-rslave /mnt/gentoo/$dir
done

# Handle /dev/shm correctly (may be a symlink on some live environments)
if [ -L /mnt/gentoo/dev/shm ]; then
  rm /mnt/gentoo/dev/shm
  mkdir -p /mnt/gentoo/dev/shm
  mount -t tmpfs -o nosuid,nodev,noexec shm /mnt/gentoo/dev/shm
  chmod 1777 /mnt/gentoo/dev/shm
fi

# Mount efivarfs so efibootmgr works inside the chroot
mount -t efivarfs efivarfs /mnt/gentoo/sys/firmware/efi/efivars 2>/dev/null || true

echo "✅ Entering chroot. All subsequent phases run inside the chroot."
chroot /mnt/gentoo /bin/bash
# ──────────────────────────────────────────────────────────────
# FROM THIS POINT ALL COMMANDS RUN INSIDE THE CHROOT
# ──────────────────────────────────────────────────────────────
source /etc/profile
export PS1="(chroot) ${PS1}"
```

---

## Phase 4: Portage Configuration

### `/etc/portage/make.conf`

```bash
COMMON_FLAGS="-O2 -pipe -march=native -flto"
CPU_FLAGS_X86="aes avx avx2 f16c fma3 mmx mmxext pclmul popcnt rdrand sha sse sse2 sse3 sse4_1 sse4_2 ssse3 vpclmulqdq bmi1 bmi2 erms invpcid rdseed adx smap clflushopt xsaveopt xsaves"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"
CGO_CFLAGS="${CFLAGS}"
CGO_CXXFLAGS="${CXXFLAGS}"
CGO_FFLAGS="${FFLAGS}"
CGO_LDFLAGS="${LDFLAGS}"
RUSTFLAGS="-C opt-level=3 -C target-cpu=native"
MAKEOPTS="-j22"
NOCOMMON_OVERRIDE_LIBTOOL="yes"
EMERGE_DEFAULT_OPTS="--keep-going=y"
EMERGE_DEFAULT_OPTS="--jobs=10 --keep-going=y"
ACCEPT_KEYWORDS="~amd64"
ACCEPT_LICENSE="*"
VIDEO_CARDS="nvidia intel"
USE="-elogind systemd -gnome -kde -ccache -tpm zstd pipewire orc \
 -motif gtk gtk4 pulseaudio qt5 qt6 sound-server app-i18n seccomp appindicator \
 -smartcard wayland pam clang policykit keyring sqlite hardened libnotify \
 cups -quicktime nvidia udev alsa jit audit nvenc cryptsetup numpy \
 pie gui X upower dbus lto pgo firmware python ffmpeg vulkan \
 -accessibility bluetooth -handbook fontconfig udisks gstreamer"
RUBY_TARGETS="ruby33 ruby34"
PYTHON_TARGETS="python3_13 python3_14"
PYTHON_SINGLE_TARGET="python3_13"
LLVM_SLOT="19 20"
L10N="en en_US en-US"
LINGUAS="${L10N}"
ABI_X86="64 32"

# NOTE: This stage was built with the bindist Use flag enabled

PORTDIR="/var/db/repos/gentoo"
DISTDIR="/var/cache/distfiles"
PKGDIR="/var/cache/binpkgs"

LC_MESSAGES=C
#GRUB_PLATFORMS="efi-64"
```

### `/etc/portage/package.use`

```bash
*/* INPUT_DEVICES:        -* libinput synaptics
sys-libs/ncurses gpm
media-libs/mesa vaapi vdpau vulkan wayland
media-video/libva-utils vainfo
sys-apps/fwupd -dell nvme spi synaptics uefi lzma gnutls
sys-kernel/cachyos-sources -hardened kcfi
virtual/secret-service libsecret
sys-firmware/intel-microcode initramfs
sys-kernel/linux-firmware compress-zstd initramfs
sys-kernel/installkernel dracut
dev-vcs/git keyring
net-libs/nodejs npm lto
net-p2p/transmission gtk -qt5 -qt6
dev-util/cmake -emacs ncurses -qt5
app-text/xmlto text
gnome-base/gvfs udisks
sys-apps/kmod zstd tools
app-admin/sysstat lto lm-sensors
dev-lang/python pgo ensurepip tk hardened -jit bluetooth
sys-devel/gcc lto pgo default-stack-clash-protection jit graphite
app-editors/emacs tree-sitter jit gtk gui -X dynamic-loading -acl -alsa mailutils dbus -gmp gtk gui -harfbuzz inotify -jpeg sqlite -ssl -tiff -xattr xpm -zlib
media-sound/pulseaudio -daemon
media-video/pipewire sound-server extra
sys-apps/xdg-desktop-portal screencast geolocation
app-arch/zstd static-libs
sys-apps/xdg-desktop-portal geolocation
media-fonts/nerdfonts jetbrainsmono nerdfontssymbolsonly
net-libs/libssh server
virtual/wine staging
dev-libs/boost nls
sys-auth/polkit gtk daemon
net-analyzer/snort threads
app-portage/eix optimization strong-security tools
app-misc/fdupes ncurses
x11-drivers/nvidia-drivers modules powerd tools kernel-open wayland
media-gfx/imv -X wayland gif heif icu jpeg jpegxl png svg tiff
sys-apps/rng-tools jitterentropy
llvm-core/clang-runtime sanitize llvm-libunwind
sys-fs/squashfs-tools lzma
media-video/pipewire gstreamer gsettings pipewire-alsa
x11-base/xwayland xcsecurity
www-client/firefox -X clang -telemetry openh264 hwaccel
gui-libs/gtk -X
sys-devel/clang-common llvm-libunwind
sci-chemistry/pymol web
Rui-wm/hyprland hyprpm
dev-lang/rust lto rust-analyzer rustfmt
dev-qt/qtbase opengl
dev-qt/qttools opengl
dev-qt/qtdeclarative opengl

```

### Repository Setup

```bash
emerge-webrsync
emerge --sync
eselect profile list

emerge --oneshot app-eselect/eselect-repository dev-vcs/git

# Full sync to ensure all repositories are up to date
eselect repository enable CachyOS-kernels guru

echo "✅ Portage synced & configured."
```

---

## Phase 4b: Locale & Timezone

```bash
# Set timezone (replace Asia/Dhaka with your actual timezone)
ln -sf ../usr/share/zoneinfo/Asia/Dhaka /etc/localtime

# Set locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set en_US.utf8

env-update && source /etc/profile
export PS1="(chroot) ${PS1}"
```

---

## Phase 5a: SELinux Base Policies (Pre-World Update)

```bash
# Install SELinux base policy and runtime BEFORE the world update.
# This ensures the base system rebuilds with SELinux awareness.
# Note: sec-policy/selinux-desktop-login does NOT exist.
# We use selinux-base-policy and specific domain policies.
emerge --ask \
  sec-policy/selinux-base-policy \
  sec-policy/selinux-base \
  sec-policy/selinux-xserver \
  sec-policy/selinux-mozilla \
  sec-policy/selinux-pulseaudio \
  sec-policy/selinux-networkmanager

# Configure SELinux mode to permissive initially to allow relabeling to complete
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
sed -i 's/^SELINUXTYPE=.*/SELINUXTYPE=targeted/' /etc/selinux/config

echo "✅ SELinux policies installed. Proceeding to World Update."
```

---

## Phase 5b: World Update & Base System Alignment

```bash
# CRITICAL: Rebuild ALL packages with new SELinux USE flags.
# This must happen AFTER selinux-base-policy but BEFORE kernel/ZFS.
emerge -auqDN @world --keep-going=y

# Merge any config file updates (critical for systemd/pam/selinux)
dispatch-conf

echo "✅ Base system updated with SELinux support."
```

---

## Phase 6: Core Dependencies & Kernel Compilation

```bash
# Note: sys-fs/zfs is intentionally not emerged here.
# DKMS builds ZFS modules against the running kernel's headers at emerge time,
# so sys-fs/zfs must be emerged after the kernel is compiled.

emerge --ask \
  sys-kernel/cachyos-sources \
  sys-kernel/linux-firmware \
  sys-firmware/intel-microcode \
  sys-apps/zram-generator \
  app-admin/sudo \
  sys-kernel/dracut \
  net-misc/networkmanager \
  net-firewall/firewalld \
  sys-apps/haveged \
  sys-apps/audit

systemctl enable NetworkManager firewalld auditd haveged
echo "✅ Core packages installed."

# --- Kernel Compilation (CachyOS + SELinux + NVIDIA) ---

eselect kernel set 1
cd /usr/src/linux

# Configure kernel (ensure SELinux, EFI Stub, ZFS options are set)
make LLVM=1 -j$(nproc) olddefconfig
make LLVM=1 -j$(nproc)
make LLVM=1 modules_install
make LLVM=1 install

# NOW emerge sys-fs/zfs — DKMS will build modules against the kernel just installed
emerge --ask sys-fs/zfs

# Enable ZFS systemd services
systemctl enable zfs-import-cache zfs-mount zfs-zed

# Rebuild NVIDIA modules (and any other DKMS modules) against the new headers
emerge @module-rebuild

echo "✅ Kernel compiled & installed, ZFS modules built."
```

---

## Phase 7: Initramfs & ZFSBootMenu

### `/etc/dracut.conf.d/10-zfs.conf`

```bash
hostonly="no"
compress="zstd"
add_dracutmodules+=" zfs "
# Do NOT omit 'crypt' or 'dm' — device-mapper is required by cryptsetup
omit_dracutmodules+=" btrfs lvm "

KERNEL_VER=$(ls /lib/modules | sort -V | tail -n1)
dracut --force --kver "${KERNEL_VER}"
echo "✅ Initramfs built."
```

### ZFSBootMenu Deployment

```bash
# Set to the latest stable release from https://github.com/zbm-dev/zfsbootmenu/releases
ZBM_VER="2.3.0"   # ← Update this to the current release before running

# The EFI-only binary is the simplest deployment method
ZBM_URL="https://github.com/zbm-dev/zfsbootmenu/releases/download/v${ZBM_VER}/zfsbootmenu-release-x86_64-v${ZBM_VER}.tar.gz"
wget -q "${ZBM_URL}"
mkdir -p /tmp/zbm
tar xzf zfsbootmenu-release-*.tar.gz -C /tmp/zbm

mkdir -p /boot/efi/EFI/zbm
# ZBM releases include vmlinuz + initramfs OR a single .EFI; copy whichever is present
if ls /tmp/zbm/vmlinuz* &>/dev/null; then
  cp /tmp/zbm/vmlinuz* /boot/efi/EFI/zbm/vmlinuz-zbm
  cp /tmp/zbm/initramfs* /boot/efi/EFI/zbm/initramfs-zbm.img
  # Register the vmlinuz+initramfs pair with UEFI
  efibootmgr --create --disk /dev/nvme0n1 --part 1 \
    --label "ZFSBootMenu" \
    --loader '\EFI\zbm\vmlinuz-zbm' \
    --unicode "initrd=\EFI\zbm\initramfs-zbm.img zbm.skip=0 quiet"
else
  # Single EFI executable (simpler; preferred when available)
  cp /tmp/zbm/*.EFI /boot/efi/EFI/zbm/zfsbootmenu.efi 2>/dev/null || \
    cp /tmp/zbm/*.efi /boot/efi/EFI/zbm/zfsbootmenu.efi
  efibootmgr --create --disk /dev/nvme0n1 --part 1 \
    --label "ZFSBootMenu" \
    --loader '\EFI\zbm\zfsbootmenu.efi'
fi

# UEFI fallback path (firmware may use this if the primary entry is lost)
mkdir -p /boot/efi/EFI/BOOT
cp /boot/efi/EFI/zbm/vmlinuz-zbm /boot/efi/EFI/BOOT/BOOTX64.EFI 2>/dev/null || \
  cp /boot/efi/EFI/zbm/zfsbootmenu.efi /boot/efi/EFI/BOOT/BOOTX64.EFI

echo "✅ ZFSBootMenu deployed."
```

### `/etc/fstab` — ESP Entry

```bash
cat >> /etc/fstab <<'EOF'
# EFI System Partition
LABEL=EFI_SYSTEM  /boot/efi  vfat  umask=0077  0 2
EOF
```

---

## Phase 8: SELinux Relabel, Network & User

```bash
# Relabel the filesystem
fixfiles -F relabel
touch /.autorelabel   # Triggers a full relabel on first boot (~5–15 min)

# Switch to enforcing after first successful boot (do this post-reboot)
# sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config

# Network & Firewall
# NOTE: nmcli device wifi connect cannot be run inside the chroot because
# NetworkManager is not actively running in a chroot environment.
systemctl enable firewalld NetworkManager

# ZRAM
cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram, 32768)
compression-algorithm = zstd
EOF
systemctl daemon-reload
systemctl enable --now systemd-zram-setup@zram0.service

# Hardened sysctl
cat > /etc/sysctl.d/99-hardened.conf <<'EOF'
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.printk=3 4 1 7
kernel.unprivileged_bpf_disabled=1
net.core.bpf_jit_harden=2
vm.unprivileged_userfaultfd=0
kernel.kexec_load_disabled=1
kernel.sysrq=0
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.rp_filter=1
fs.protected_symlinks=1
fs.protected_hardlinks=1
vm.swappiness=15
EOF
sysctl --system

# User account
useradd -m -G wheel,audio,video,plugdev,input,render,network,power,users,systemd-journal \
  -s /bin/bash ahsan
passwd ahsan
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chage -M 90 -W 14 ahsan

systemctl set-default graphical.target
echo "✅ System hardened & user created."
```

---

## Phase 9: NVIDIA Open Modules & CUDA

```bash
emerge --ask \
  x11-drivers/nvidia-drivers \
  dev-util/nvidia-cuda-toolkit \
  gui-wm/hyprland \
  x11-misc/sddm \
  media-libs/mesa

# NVIDIA DRM and power management options
cat > /etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia-drm modeset=1 fbdev=1
options nvidia NVreg_UsePageAttributeTable=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp
EOF
echo 'nvidia-drm' > /etc/modules-load.d/nvidia.conf

# SELinux contexts for NVIDIA and CUDA
semanage fcontext -a -t xdm_exec_t "/usr/lib64/libnvidia-egl-wayland\.so(\..*)?"
restorecon -Rv /dev/nvidia* /dev/dri/
setsebool -P selinuxuser_execmod 1

# CUDA environment
cat > /etc/env.d/02cuda <<'EOF'
CUDA_PATH=/opt/cuda
PATH=/opt/cuda/bin:/opt/cuda/bin/targets/x86_64-linux
LDPATH=/opt/cuda/lib64
EOF
env-update && source /etc/profile

echo "✅ NVIDIA & CUDA installed. Verify with: nvidia-smi && nvcc --version"
```

---

## Phase 10: Finalization & Reboot

```bash
# Exit the chroot
exit

# Unmount everything cleanly
umount -R /mnt/gentoo

# Export the pool before reboot so it is cleanly imported by ZFSBootMenu
zpool export rpool
echo "🔄 Rebooting in 5 seconds..."
sleep 5
reboot
```

---

## Post-Boot Verification

```bash
# 1. SELinux — should return 'Permissive' on first boot (relabeling in progress)
#    After relabeling completes and you switch to enforcing:
getenforce   # Target: Enforcing

# 2. ZFS pool health
zpool status
zfs get encryption rpool/ROOT/gentoo

# 3. GPU & desktop
hyprctl version
nvidia-smi | grep "Driver Version"

# 4. ZFS snapshots for recovery
zfs snapshot rpool/ROOT/gentoo@pre-desktop
# To roll back:
# zfs rollback -r rpool/ROOT/gentoo@pre-desktop

# 5. Routine update workflow
emerge --sync && emerge -uvDN @world --keep-going=y
emerge @module-rebuild   # Rebuilds NVIDIA/ZFS modules after any kernel update
dracut --force           # Rebuilds initramfs after kernel or ZFS module changes
```

---

## Cross-References

| Component            | Reference                                          |
| :------------------- | :------------------------------------------------- |
| Gentoo ZFS           | https://wiki.gentoo.org/wiki/ZFS                   |
| ZFSBootMenu          | https://zfsbootmenu.org/                           |
| Gentoo SELinux       | https://wiki.gentoo.org/wiki/SELinux               |
| CachyOS Kernel       | https://wiki.cachyos.org/                          |
| NVIDIA Open Modules  | https://wiki.gentoo.org/wiki/NVIDIA/nvidia-drivers |
| ZFSBootMenu Releases | https://github.com/zbm-dev/zfsbootmenu/releases    |

---

## ⚠️ Final Verification Notes

- **Kernel Updates:** When `sys-kernel/cachyos-sources` updates, recompile the kernel. After `make install`, run `emerge @module-rebuild` to recompile ZFS (DKMS) and NVIDIA modules against the new headers, then run `dracut --force`.
- **SELinux Relabel:** The first boot triggers `fixfiles relabel` via `/.autorelabel`. This is mandatory and will take 5–15 minutes. Do not interrupt power. After it completes, switch `SELINUX=enforcing` in `/etc/selinux/config` and reboot.
- **ZFSBootMenu Flow:** Firmware loads ZBM from ESP → ZBM prompts for the pool passphrase → ZBM imports `rpool` → ZBM presents a boot-environment menu → ZBM `kexec`s into your CachyOS kernel.
- **hostid:** The `zgenhostid` step in Phase 0 and the copy in Phase 3 are non-negotiable. Without a persistent `/etc/hostid`, ZFS treats each boot as a different machine and refuses to auto-import the root pool.
- **Encryption Inheritance:** All sub-datasets (`/home`, `/var`, etc.) AND the swap zvol (`/dev/zvol/rpool/ROOT/gentoo/swap`) are now created under `rpool/ROOT/gentoo`. This ensures they automatically inherit the AES-256-GCM encryption of the root dataset.
