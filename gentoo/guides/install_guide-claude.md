# Gentoo Desktop Installation: ZFS Native Encryption, ZFSBootMenu, SELinux Targeted Policy, CachyOS Kernel, NVIDIA Open Modules & CUDA – A Unified Guide

> **Revision Notes:** This document corrects the following issues found in the original:
> - Removed invalid PGO flags (`-fprofile-use`, `-fauto-profile`, `-fprofile-correction`) from `COMMON_FLAGS`; PGO requires a two-pass instrumented build and cannot be applied globally in a standard `emerge` workflow without causing widespread compilation failures.
> - Removed `-fgraphite-identity` (a debugging-only flag) and `-floop-parallelize-all` (requires OpenMP and breaks many packages).
> - Added the critical `zgenhostid` step (Phase 0), which is mandatory before any ZFS operation; its omission causes pool-import failures at boot.
> - Added `resolv.conf` copy into chroot before `emerge --sync` (DNS required).
> - Added `app-admin/eselect-repository` installation before `eselect repository` use.
> - Corrected ZFSBootMenu deployment: hardcoded `v3.1.0` was likely hallucinated; guide now uses a variable set by the user and documents the correct EFI-binary release format.
> - Fixed `dracut.conf`: removed `force_drivers+=" nvidia "` (NVIDIA is not needed in early-boot initramfs for ZFS) and removed `crypt` and `dm` from `omit_dracutmodules` (omitting device-mapper breaks cryptsetup in fallback scenarios).
> - Fixed SELinux package list: `sec-policy/selinux-desktop` does not exist in Gentoo Portage; replaced with correct `sec-policy/selinux-base-policy` and `sec-policy/selinux-desktop-login`.
> - Added missing `zpool set bootfs` and `/etc/fstab` ESP entry.
> - Corrected pathway labels: DKMS = Pathway A (stable), kernel-builtin = Pathway B (experimental), consistent with upstream OpenZFS documentation.
> - Clarified chroot scope: all phases after Phase 3 run inside the chroot.
> - Added locale and timezone configuration.

---

## ⚠️ Critical Decision Point: EFI System Partition (ESP) Mount Location

**Decision:** Mount the ESP at `/boot/efi`.

**Justification:**
1. **ZFS Dataset Isolation:** ZFS manages `/` and sub-datasets natively. Mounting ESP at `/boot` pollutes the root dataset with firmware files and complicates ZFSBootMenu's boot environment detection.
2. **systemd & installkernel Compliance:** Modern `sys-kernel/installkernel` and `systemd` expect `/boot/efi` as the canonical ESP mount. This ensures `efibootmgr` entries and fallback paths (`/boot/efi/EFI/BOOT/BOOTX64.EFI`) are handled without manual ZFS hook overrides.

All phases assume `ESP=/dev/nvme0n1p1` mounted at `/boot/efi`.

---

## Phase 0: Preparation & Environment Validation

```bash
set -e
ping -c2 8.8.8.8 || { echo "❌ No internet."; exit 1; }
lsblk | grep -q nvme || { echo "❌ NVMe drives missing."; exit 1; }
read -p "⚠️ Wipe /dev/nvme0n1 & /dev/nvme1n1? Type YES: " c
[[ "$c" != "YES" ]] && exit 1

# CRITICAL: Generate and persist a stable host ID BEFORE any ZFS operations.
# ZFS embeds the hostid into pool metadata. If the hostid changes between boots
# (e.g., not persisted across reinstalls), the pool will fail to auto-import
# and the system will not boot.
zgenhostid -f 0x00bab10c
# Pre-create the target etc/ directory so the hostid can be written before
# the stage3 tarball is extracted into /mnt.
mkdir -p /mnt/etc
cp /etc/hostid /mnt/etc/hostid

echo "✅ Environment validated and hostid persisted."
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

## Phase 2: ZFS Pool & Datasets

```bash
# Note: ZFS stripes implicitly when multiple top-level vdevs are listed with
# no vdev-type keyword. There is no 'raid0' keyword in ZFS; listing two devices
# directly produces a stripe (equivalent to RAID-0).
zpool create -f -o ashift=12 -o autotrim=on \
  -O compression=zstd -O acltype=posixacl -O xattr=sa \
  -O mountpoint=none -R /mnt \
  rpool /dev/nvme0n1p2 /dev/nvme1n1p1

# Create encrypted root dataset
zfs create -o encryption=aes-256-gcm -o keyformat=passphrase \
  -o keylocation=prompt -o mountpoint=/ rpool/ROOT/gentoo

# Designate this dataset as the bootable root (required by ZFSBootMenu)
zpool set bootfs=rpool/ROOT/gentoo rpool

# Sub-datasets
zfs create -o mountpoint=/home      rpool/home
zfs create -o mountpoint=/var       rpool/var
zfs create -o mountpoint=/opt       rpool/opt
zfs create -o mountpoint=/srv       rpool/srv
zfs create -o mountpoint=/usr/local rpool/usr/local
zfs create -o mountpoint=/var/log   rpool/var/log
zfs create -o mountpoint=/var/cache rpool/var/cache
zfs create -o mountpoint=/var/tmp   rpool/var/tmp

# Swap zvol (32 GB)
zfs create -V 32G -o volblocksize=16K -o compression=zle \
  -o logbias=throughput -o sync=always \
  -o primarycache=metadata -o secondarycache=none \
  -o com.sun:auto-snapshot=false rpool/swap
mkswap -L "zfs-swap" /dev/zvol/rpool/swap

# Format and mount the ESP
mkfs.fat -F32 /dev/nvme0n1p1
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi
echo "✅ ZFS layout & ESP mounted."
```

---

## Phase 3: Bootstrap & Chroot

```bash
cd /mnt

# Download and verify the hardened+SELinux+systemd stage3 tarball
# The mirror file lists a relative path; we must prepend the full base URL.
STAGE_BASE="https://distfiles.gentoo.org/releases/amd64/autobuilds"
STAGE_REL=$(curl -sL "${STAGE_BASE}/latest-stage3-amd64-hardened-selinux-systemd.txt" \
  | grep -v '^#' | grep '\.tar\.xz' | awk '{print $1}')
wget "${STAGE_BASE}/${STAGE_REL}"
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
rm -f stage3-*.tar.xz

# Copy DNS resolver config so emerge --sync works inside the chroot
cp /etc/resolv.conf /mnt/etc/resolv.conf

# Bind-mount virtual filesystems
for dir in dev proc sys run; do
  mount --rbind /$dir /mnt/$dir
  mount --make-rslave /mnt/$dir
done

# Handle /dev/shm correctly (may be a symlink on some live environments)
if [ -L /mnt/dev/shm ]; then
  rm /mnt/dev/shm
  mkdir -p /mnt/dev/shm
  mount -t tmpfs -o nosuid,nodev,noexec shm /mnt/dev/shm
  chmod 1777 /mnt/dev/shm
fi

# Mount efivarfs so efibootmgr works inside the chroot
mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars 2>/dev/null || true

echo "✅ Entering chroot. All subsequent phases run inside the chroot."
chroot /mnt /bin/bash
# ──────────────────────────────────────────────────────────────
# FROM THIS POINT ALL COMMANDS RUN INSIDE THE CHROOT
# ──────────────────────────────────────────────────────────────
source /etc/profile
export PS1="(chroot) ${PS1}"
```

---

## Phase 4: Portage Configuration

> All commands from this phase onward run **inside the chroot**.

### `/etc/portage/make.conf`

```conf
# Compiler flags
# NOTE: PGO flags (-fprofile-use, -fauto-profile) are intentionally omitted.
# They require a two-pass instrumented build and will cause widespread failures
# when set globally in CFLAGS for a standard emerge-based system.
COST="-fvect-cost-model=dynamic -fsimd-cost-model=dynamic"
DEVIRT="-fdevirtualize-speculatively -fdevirtualize-at-ltrans"
FIPA="-fipa-pta -fipa-icf"
FFAST="-fno-math-errno -fno-signed-zeros -fno-trapping-math -faggressive-loop-optimizations"
FORTRAN="-fstack-arrays"
# NOTE: -fgraphite-identity is a debugging flag and is excluded.
# -floop-parallelize-all requires OpenMP linkage and breaks non-OMP packages.
GRAPHITE="-floop-block"
SAFE_MATH="-ffinite-loops -fsplit-wide-types-early -ftree-vectorize"
MISC="-fwrapv -fno-semantic-interposition -fno-common -fPIC -fno-plt"
COMMON_FLAGS="-O3 -pipe -march=native -flto=thin ${COST} ${DEVIRT} ${FIPA} ${FFAST} ${FORTRAN} ${GRAPHITE} ${SAFE_MATH} ${MISC}"

CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
CPU_FLAGS_X86="aes avx avx2 f16c fma3 mmx mmxext pclmul popcnt rdrand sha sse sse2 sse3 sse4_1 sse4_2 sse4a ssse3 vpclmulqdq"
MAKEOPTS="-j$(nproc)"
EMERGE_DEFAULT_OPTS="--jobs=$(nproc) --keep-going=y"

VIDEO_CARDS="nvidia amdgpu"
GRUB_PLATFORMS="efi-64"
L10N="en en_US en-US"
LINGUAS="${L10N}"
PYTHON_TARGETS="python3_13 python3_12 pypy3_11"
PYTHON_SINGLE_TARGET="python3_13"
LLVM_SLOT="19"
RUBY_TARGETS="ruby33 ruby34"
ACCEPT_LICENSE="*"
PORTDIR="/var/db/repos/gentoo"
DISTDIR="/var/cache/distfiles"
PKGDIR="/var/cache/binpkgs"
LC_MESSAGES=C

USE="systemd selinux elogind zfs pipewire profile orc clamav gtk gtk4 pulseaudio \
qt5 qt6 sound-server app-i18n seccomp appindicator wayland pam clang policykit \
keyring sqlite hardened libnotify cups nvidia udev alsa jit audit udisks nvenc \
cryptsetup numpy pie gui X upower dbus lto pgo firmware python ffmpeg fips \
vulkan -accessibility -bluetooth -handbook fontconfig gstreamer cuda kernel-open"
```

### `/etc/portage/package.accept_keywords/00-zfs-cachyos-nvidia.conf`

```conf
sys-kernel/cachyos-sources ~amd64
sys-fs/zfs ~amd64
x11-drivers/nvidia-drivers ~amd64
dev-util/nvidia-cuda-toolkit ~amd64
net-firewall/firewalld ~amd64
sec-policy/selinux-base-policy ~amd64
gui-wm/hyprland ~amd64
```

### `/etc/portage/package.use/00-globals.conf`

```conf
*/* INPUT_DEVICES: libinput synaptics
sys-kernel/linux-firmware compress-zstd initramfs
sys-kernel/installkernel dracut
sys-apps/kmod zstd
app-admin/sysstat lto lm-sensors
dev-lang/python pgo ensurepip tk hardened -jit bluetooth
sys-devel/gcc lto pgo default-stack-clash-protection jit graphite
dev-vcs/git keyring
net-libs/nodejs npm lto
media-fonts/nerdfonts jetbrainsmono ubuntu ubuntumono
x11-drivers/nvidia-drivers modules powerd tools kernel-open wayland -X
sys-apps/xdg-desktop-portal screencast geolocation flatpak
sys-apps/flatpak policykit seccomp
gui-wm/hyprland X qtutils
dev-lang/rust lto rust-analyzer rust-src rustfmt system-llvm
media-video/pipewire sound-server flatpak extra gstreamer pipewire-alsa
dev-qt/qtbase opengl
dev-qt/qtdeclarative opengl
```

```bash
# Install eselect-repository before using it
emerge --oneshot app-admin/eselect-repository dev-vcs/git

# Add CachyOS kernel overlay
eselect repository add cachyos-kernels git \
  https://github.com/CachyOS/cachyos-kernel-overlay.git
eselect repository enable cachyos-kernels

# Also enable the guru overlay if desired (optional)
eselect repository enable guru

emerge-webrsync && emerge --sync
echo "✅ Portage synced & configured."
```

---

## Phase 4b: Locale & Timezone

```bash
# Set timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
# Or replace UTC with your actual timezone, e.g., America/New_York

# Set locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set en_US.utf8
env-update && source /etc/profile
```

---

## Phase 5: Core Dependencies

> **Note:** `sys-fs/zfs` is intentionally **not** emerged here. DKMS builds ZFS
> modules against the running kernel's headers at emerge time, so `sys-fs/zfs`
> must be emerged **after** the kernel is compiled and installed in Phase 6.
> Emerging it now would build against the live-environment kernel instead of
> your new CachyOS kernel.

```bash
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

# ZFS services are enabled in Phase 6 after sys-fs/zfs is emerged
systemctl enable NetworkManager firewalld auditd haveged
echo "✅ Core packages installed."
```

---

## Phase 6: Kernel Compilation (CachyOS + SELinux + NVIDIA)

**Pathway Decision: DKMS (Pathway A, Stable) vs. Kernel-Builtin ZFS (Pathway B, Experimental)**

- **Pathway A (DKMS) — Recommended:** ZFS modules are built out-of-tree via DKMS against the running kernel's headers. Well-tested and officially supported. Use this for production systems.
- **Pathway B (Kernel-Builtin) — Experimental:** Compiles ZFS directly into the kernel via the `kernel-builtin-zfs` USE flag on `sys-fs/zfs`. Depends on CachyOS sources exposing the necessary in-kernel ZFS symbols. If compilation fails, fall back to Pathway A.

_This guide proceeds with **Pathway A (DKMS)** for guaranteed ZFSBootMenu compatibility._

### `make menuconfig` Verification

Ensure these are set (`y` = built-in, `m` = module):

```text
[*] Enable loadable module support
[*]   Automatic kernel module loading
-*- Cryptographic API
      <*>   AES cipher algorithms (x86_64)
      <*>   XTS support
      <*>   SHA512 digest algorithm
[*] EFI runtime service support
[*]   EFI stub support
-*- Security options
      <*>   SELinux Support
      [*]   Enable runtime disabling of SELinux
-*- Device Drivers
      Graphics support
          <*>   Direct Rendering Manager
          [*]   NVIDIA DRM modesetting support
      File systems
          <*>   FUSE support
-*- Processor type and features
      [*]   AMD/Intel microcode loading support
```

### Build & Install

```bash
eselect kernel set 1
cd /usr/src/linux
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

```conf
hostonly="no"
compress="zstd"
add_dracutmodules+=" zfs "
# Do NOT omit 'crypt' or 'dm' — device-mapper is required by cryptsetup
# in fallback initramfs scenarios. NVIDIA drivers are NOT needed at early boot.
omit_dracutmodules+=" btrfs lvm "
```

```bash
KERNEL_VER=$(ls /lib/modules | sort -V | tail -n1)
dracut --force --kver "${KERNEL_VER}"
echo "✅ Initramfs built."
```

### ZFSBootMenu Deployment

ZFSBootMenu publishes two release types: a combined EFI executable (`zfsbootmenu.EFI`) and a split vmlinuz + initramfs pair. Check the [official releases page](https://github.com/zbm-dev/zfsbootmenu/releases) and set `ZBM_VER` to the latest stable version before running.

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

## Phase 8: SELinux, Network & User

```bash
# Install SELinux base policy and desktop-login policy
# Note: 'sec-policy/selinux-desktop' does not exist in Gentoo Portage.
# Use selinux-base-policy and selinux-desktop-login instead.
emerge --ask \
  sec-policy/selinux-base-policy \
  sec-policy/selinux-desktop-login

# Set SELinux mode to permissive initially to allow relabeling to complete
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config

# Relabel the filesystem
fixfiles -F relabel
touch /.autorelabel   # Triggers a full relabel on first boot (~5–15 min)

# Switch to enforcing after first successful boot (do this post-reboot)
# sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config

# Network & Firewall
# NOTE: nmcli device wifi connect cannot be run inside the chroot because
# NetworkManager is not actively running in a chroot environment.
# Run network configuration commands after the first boot instead.
# Here we only enable the services so they start on first boot:
firewall-cmd --set-default-zone=trusted 2>/dev/null || true   # may also fail in chroot; re-run post-boot
firewall-cmd --runtime-to-permanent 2>/dev/null || true
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
semanage fcontext -a -t xdm_exec_t \
  "/usr/lib64/libnvidia-egl-wayland\.so(\..*)?"
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
umount -R /mnt

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

| Component           | Reference                                          |
|---------------------|----------------------------------------------------|
| Gentoo ZFS          | https://wiki.gentoo.org/wiki/ZFS                  |
| ZFSBootMenu         | https://zfsbootmenu.org/                          |
| Gentoo SELinux      | https://wiki.gentoo.org/wiki/SELinux              |
| CachyOS Kernel      | https://wiki.cachyos.org/                         |
| NVIDIA Open Modules | https://wiki.gentoo.org/wiki/NVIDIA/nvidia-drivers |
| ZFSBootMenu Releases| https://github.com/zbm-dev/zfsbootmenu/releases   |

---

## ⚠️ Final Verification Notes

1. **Kernel Updates:** When `sys-kernel/cachyos-sources` updates, recompile the kernel. After `make install`, run `emerge @module-rebuild` to recompile ZFS (DKMS) and NVIDIA modules against the new headers, then run `dracut --force`.

2. **SELinux Relabel:** The first boot triggers `fixfiles relabel` via `/.autorelabel`. This is mandatory and will take 5–15 minutes. Do not interrupt power. After it completes, switch `SELINUX=enforcing` in `/etc/selinux/config` and reboot.

3. **ZFSBootMenu Flow:** Firmware loads ZBM from ESP → ZBM prompts for the pool passphrase → ZBM imports `rpool` → ZBM presents a boot-environment menu → ZBM `kexec`s into your CachyOS kernel. This is the only reliable path for native ZFS encryption on Gentoo without custom initramfs patches.

4. **NVIDIA Open Modules:** The `kernel-open` USE flag compiles the open-source kernel modules. Proprietary user-space libraries remain closed. Fully supported on Ampere/Ada/Hopper and integrates natively with Wayland/Hyprland.

5. **hostid:** The `zgenhostid` step in Phase 0 is non-negotiable. Without a persistent `/etc/hostid`, ZFS treats each boot as a different machine and refuses to auto-import the root pool, causing an unbootable system.
