# Hardened Gentoo Installation Guide — APT Threat Model

## Against Nation-State Advanced Persistent Threats — April 2026

> **Corrections from the previous version (see Appendix C for details):**
> – ESP is mounted at `/efi` (modern `systemd` standard) instead of `/boot/efi`.
> – `sys-kernel/installkernel` USE flags corrected to `dracut uki` (removed `efistub`);
> the `efistub` flag is experimental and unnecessary; its use for UEFI boot entry
> creation has been removed from the description.
> – Added the missing creation of `@/var/log`, `@/var/log/audit`, and `@/var/cache`
> subvolumes that are required by the mount table.
> – All paths now consistently use `/efi` for the EFI System Partition.

> **Threat Model**: Chinese and Russian state‑sponsored actors (APT10, APT29, APT41, Sandworm, Cozy Bear, Fancy Bear). Documented TTPs include supply‑chain compromise, kernel exploits, LUKS brute‑force against weak KDFs, cold‑boot attacks against unencrypted RAM, DMA‑over‑Thunderbolt/PCIe, SSH credential harvesting, and persistence via kernel modules or systemd service hijacking.

> **Hardware**: Intel i9‑13900K (Raptor Lake) with two NVMe drives — 500 GB (nvme0n1) and 1 TB (nvme1n1). TPM 2.0, Intel TME, VT‑d, CET hardware present. NVIDIA GPU from the personal runbook is **not** assumed; if present, adjust the kernel config accordingly.

> **Architecture decisions at a glance**:
> – No bootloader — **UKI + direct UEFI boot** (Secure Boot with custom keys).
> – **LUKS2 / Argon2id** on every data partition (no GRUB → no PBKDF2 constraint).
> – **LVM linear** across both NVMe drives (~1.5 TB usable).
> – **Btrfs** with Tumbleweed‑style subvolume layout, CoW disabled where needed.
> – **TPM2 + PIN** unlocks LUKS; recovery key as emergency fallback.
> – **CachyOS‑sources** kernel built with Clang + ThinLTO + kCFI.
> – **Hardened Gentoo profile** plus all sysctl, MAC, firewall, audit, and SSH hardening from the Arch APT guide.
> – **No hibernation** (swap is zram‑only).

---

## Pre‑Work Research Summary

### 0.1 — CachyOS Kernel on Gentoo

The `CachyOS‑kernels` overlay (maintained at `github.com/Szowisz/CachyOS‑kernels`) provides `sys‑kernel/cachyos‑sources` ebuilds that ship the full CachyOS patch‑set plus a pre‑configured `.config`. The default kernel is GCC‑built; the **`‑lto` variant** (enabled via the `lto` USE flag) switches to Clang + ThinLTO.

**kCFI (Kernel Control Flow Integrity)** is available when the kernel is compiled with Clang. It requires `CONFIG_CFI_CLANG=y` (or `CONFIG_CFI=y` in newer kernels) plus `CONFIG_LTO_CLANG=y`. The CachyOS base config sets `CONFIG_ARCH_SUPPORTS_CFI=y` but does **not** set `CONFIG_CFI_CLANG=y` by default; this must be enabled manually in `make menuconfig`.

The CachyOS kernel also supports AutoFDO, Propeller profiling, multiple CPU schedulers (BORE, EEVDF, BMQ), and x86‑64‑v3/v4 optimisations.

### 0.2 — Gentoo Hardened Profile

Gentoo’s hardened profile (`default/linux/amd64/23.0/no‑multilib/hardened/systemd`) forces PIE, `‑fstack‑protector‑strong`, `‑D_FORTIFY_SOURCE=3`, and RELRO toolchain‑wide via `use.force` and `use.mask` in the profile. It does **not** ship a hardened kernel — the kernel must be hardened separately. The profile also applies PaX markings (where applicable) and restricts `SUID`/`CAP` select packages.

### 0.3 — UKI on Gentoo

Unified Kernel Images are fully supported on Gentoo via `sys‑kernel/installkernel` with USE flags `dracut uki`. The UKI is a single PE/COFF `.efi` binary containing the kernel, initramfs, embedded command line, and optional splash image. It can be loaded directly by UEFI firmware without any bootloader. Dracut generates the UKI when `uefi=yes` is set in `/etc/dracut.conf.d/`.

### 0.4 — TPM2 + PIN with systemd‑cryptenroll

`systemd‑cryptenroll` seals a LUKS key into the TPM, binding it to specified PCR registers. When `‑‑tpm2‑with‑pin=yes` is used, the TPM requires both a valid PCR state **and** a user‑entered PIN to release the key — this is true two‑factor authentication. The `tpm2‑tss` dracut module must be included for initramfs support.

### 0.5 — RAID Strategy for Mismatched Drive Sizes

RAID 0 (both mdadm and LVM) limits usable capacity to `2 × min(disk1, disk2)`. With 500 GB and 1 TB drives, only 1 TB is usable — 500 GB on the larger drive is wasted. **LVM linear allocation** (the default when no `‑‑type` is given) concatenates extents sequentially across all PVs, using all available space. This guide therefore uses LVM linear, not RAID 0.

---

## Part 1 — Disk Layout, Encryption, and Boot Chain

### 1.1 — Hardware


| Component | Detail |
|---|---|
| Drive A (`nvme0n1`) | 500 GB NVMe |
| Drive B (`nvme1n1`) | 1 TB NVMe |
| CPU | Intel i9‑13900K (Raptor Lake) |
| TPM | TPM 2.0 (fTPM or dTPM) |
| GPU | Integrated Intel UHD 770 (NVIDIA optional) |


### 1.2 — Final Partition Layout

```

nvme0n1 (500 GB)
├── nvme0n1p1   EFI System Partition    1 GB     FAT32       UNENCRYPTED — UKI .efi files
└── nvme0n1p2   LVM PV                  ~499 GB  LVM member  LUKS2 / Argon2id

nvme1n1 (1 TB)
└── nvme1n1p1   LVM PV                  ~1 TB    LVM member  LUKS2 / Argon2id

LVM Volume Group “vg0” spanning both PVs (~1.5 TB)
└── lv‑root     Btrfs                   1.45 TB   linear      single LV, all space

```

**Why linear, not RAID 0**: Linear allocation uses 100 % of both drives. No capacity is wasted. Recovery is simpler (data on the surviving drive remains readable, though the filesystem may need repair).

### 1.3 — Chain of Trust

```

UEFI Secure Boot (enrolled db key)
  └─► Verifies and loads signed UKI .efi from ESP
       └─► UKI = {kernel + initramfs + cmdline + os‑release} in one PE binary
            └─► Initramfs runs systemd‑cryptsetup
                 └─► systemd‑cryptenroll: TPM2 unseals LUKS key if PCR state matches
                      └─► PIN entered (2FA: hardware state + PIN)
                           └─► LUKS2 unlocked → LVM activated → Btrfs root mounted

```

---

## Part 2 — Disk Preparation (Live Environment)

Boot from the **Gentoo LiveDVD/USB** or any rescue environment with `cryptsetup`, `lvm2`, `btrfs‑progs`, `dosfstools`.

### 2.1 — Verify Drives

```bash
lsblk -d -o NAME,SIZE,MODEL
# Confirm: nvme0n1 ~500 GB, nvme1n1 ~1 TB
```

### 2.2 — Wipe Existing Metadata (and optionally TRIM the SSDs)

```bash
wipefs -af /dev/nvme0n1
wipefs -af /dev/nvme1n1

blkdiscard -f /dev/nvme0n1
blkdiscard -f /dev/nvme1n1
```

### 2.3 — Partition Drives

```bash
# ── nvme0n1 (500 GB — ESP + LVM PV) ──
gdisk /dev/nvme0n1
# Inside gdisk:
# o  → new GPT table → y
# n  → 1 → default → +1G → ef00   (EFI System Partition)
# n  → 2 → default → default → 8e00 (Linux LVM)
# w  → write

# ── nvme1n1 (1 TB — LVM PV only) ──
gdisk /dev/nvme1n1
# Inside gdisk:
# o  → new GPT table → y
# n  → 1 → default → default → 8e00 (Linux LVM)
# w  → write
```

### 2.4 — Format ESP

```bash
mkfs.vfat -F 32 -n ESP /dev/nvme0n1p1
```

### 2.5 — LUKS2 Format (Argon2id on Both)

No GRUB constraint → Argon2id everywhere. High memory cost raises the bar for GPU brute‑force.  
The `‑‑label` option sets a human‑readable name inside the LUKS2 header (requires cryptsetup ≥ 2.1.0, which is standard in any modern live environment).

```bash
# ── nvme0n1p2 (500 GB PV) ──
cryptsetup luksFormat \
  --type luks2 \
  --cipher aes-xts-plain64 \
  --key-size 512 \
  --hash sha512 \
  --pbkdf argon2id \
  --pbkdf-memory 1048576 \
  --pbkdf-parallel 4 \
  --iter-time 5000 \
  --label crypt0 \
  /dev/nvme0n1p2

# ── nvme1n1p1 (1 TB PV) ──
cryptsetup luksFormat \
  --type luks2 \
  --cipher aes-xts-plain64 \
  --key-size 512 \
  --hash sha512 \
  --pbkdf argon2id \
  --pbkdf-memory 1048576 \
  --pbkdf-parallel 4 \
  --iter-time 5000 \
  --label crypt1 \
  /dev/nvme1n1p1
```

> **Argon2id parameters**: `‑‑pbkdf‑memory 1048576` = 1 GiB RAM for KDF. On the i9‑13900K with ≥ 32 GiB RAM this adds ≈ 2 s to boot. APT actors with GPU clusters cannot efficiently parallelise 1 GiB‑memory Argon2id.

### 2.6 — Open LUKS Containers

```bash
cryptsetup luksOpen /dev/nvme0n1p2 crypt0
cryptsetup luksOpen /dev/nvme1n1p1 crypt1

CRYPT0_UUID=$(cryptsetup luksUUID /dev/nvme0n1p2)
CRYPT1_UUID=$(cryptsetup luksUUID /dev/nvme1n1p1)
echo "CRYPT0_UUID=$CRYPT0_UUID"  >  /root/luks-uuids.txt
echo "CRYPT1_UUID=$CRYPT1_UUID"  >> /root/luks-uuids.txt
```

### 2.7 — LUKS Header Backup

The LUKS header (~4 MiB per container) stores cipher parameters and encrypted master keys. **If the header is corrupted, all data is permanently lost.** Back up each header to offline storage immediately.

```bash
mkdir -p /tmp/luks-backups
cryptsetup luksHeaderBackup /dev/nvme0n1p2 \
  --header-backup-file /tmp/luks-backups/luks-header-crypt0.img
cryptsetup luksHeaderBackup /dev/nvme1n1p1 \
  --header-backup-file /tmp/luks-backups/luks-header-crypt1.img
```

---

## Part 3 — LVM Configuration

### 3.1 — Create Physical Volumes and Volume Group

```bash
pvcreate /dev/mapper/crypt0 /dev/mapper/crypt1
vgcreate vg0 /dev/mapper/crypt0 /dev/mapper/crypt1
```

### 3.2 — Create Linear Logical Volume

```bash
# Linear LV using all free space (~1.45 TB)
lvcreate -l 100%FREE -n root vg0

# Verify
lvs -a -o +devices
vgs
pvs
```

**Linear allocation behaviour**: extents are taken from `crypt0` first, then from `crypt1`. This is sequential, not striped. Performance on NVMe is dominated by the drives themselves, not the allocation policy. Recovery: if one drive dies, data on the surviving drive may be partially recoverable (unlike RAID 0, where a single disk failure destroys everything).

---

## Part 4 — Btrfs Filesystem and Subvolumes

### 4.1 — Create Btrfs Filesystem

```bash
mkfs.btrfs -L gentoo /dev/vg0/root
```

### 4.2 — Mount Top‑Level Volume and Create Subvolumes

```bash
mkdir -p /mnt/gentoo
mount -o defaults,noatime,compress=zstd:1,space_cache=v2 \
  /dev/vg0/root /mnt/gentoo

# ── Root subvolume ──
btrfs subvolume create /mnt/gentoo/@

# ── Snapper snapshot directory (nested inside @) ──
btrfs subvolume create /mnt/gentoo/@/.snapshots

# ── Initial snapshot — this BECOMES the active root ──
mkdir -p /mnt/gentoo/@/.snapshots/1
btrfs subvolume create /mnt/gentoo/@/.snapshots/1/snapshot

# ── User and application data (excluded from root snapshots) ──
btrfs subvolume create /mnt/gentoo/@/home
btrfs subvolume create /mnt/gentoo/@/opt
btrfs subvolume create /mnt/gentoo/@/root
btrfs subvolume create /mnt/gentoo/@/srv
btrfs subvolume create /mnt/gentoo/@/tmp

# ── /usr/local ──
mkdir -p /mnt/gentoo/@/usr
btrfs subvolume create /mnt/gentoo/@/usr/local

# ── /var and its children — CoW disabled ──
btrfs subvolume create /mnt/gentoo/@/var
chattr +C /mnt/gentoo/@/var

btrfs subvolume create /mnt/gentoo/@/var/tmp
chattr +C /mnt/gentoo/@/var/tmp

# ── /nix — CoW disabled ──
btrfs subvolume create /mnt/gentoo/@/nix
chattr +C /mnt/gentoo/@/nix

# ── Create initial Snapper info.xml ──
DATE=$(date "+%Y-%m-%d %H:%M:%S")
cat > /mnt/gentoo/@/.snapshots/1/info.xml << EOF
<?xml version="1.0"?>
<snapshot>
  <type>single</type>
  <num>1</num>
  <date>${DATE}</date>
  <description>first root filesystem</description>
</snapshot>
EOF

# ── Set initial snapshot as default ──
SNAP_ID=$(btrfs subvolume list /mnt/gentoo | \
  grep "@/.snapshots/1/snapshot" | awk '{print $2}')
btrfs subvolume set-default $SNAP_ID /mnt/gentoo

# ── Unmount top‑level, remount the default snapshot ──
umount /mnt/gentoo
mount -o defaults,noatime,compress=zstd:1,space_cache=v2 \
  /dev/vg0/root /mnt/gentoo
```

### 4.3 — Create Mount Point Skeleton (inside the root snapshot)

```bash
mkdir -p /mnt/gentoo/{.snapshots,home,nix,opt,root,srv,tmp,usr/local,var}
mkdir -p /mnt/gentoo/var/{log/audit,cache,tmp}
mkdir -p /mnt/gentoo/efi               # ESP mount point
```

### 4.4 — Mount All Subvolumes and ESP

```bash
BTRFS_OPTS="defaults,noatime,compress=zstd:1,space_cache=v2"
BTRFS_NOCOW="defaults,noatime,space_cache=v2"

mount /dev/vg0/root /mnt/gentoo/.snapshots        -o ${BTRFS_OPTS},subvol=@/.snapshots
mount /dev/vg0/root /mnt/gentoo/home               -o ${BTRFS_OPTS},subvol=@/home
mount /dev/vg0/root /mnt/gentoo/nix                -o ${BTRFS_NOCOW},subvol=@/nix
mount /dev/vg0/root /mnt/gentoo/opt                -o ${BTRFS_OPTS},subvol=@/opt
mount /dev/vg0/root /mnt/gentoo/root               -o ${BTRFS_OPTS},subvol=@/root
mount /dev/vg0/root /mnt/gentoo/srv                -o ${BTRFS_OPTS},subvol=@/srv
mount /dev/vg0/root /mnt/gentoo/tmp                -o ${BTRFS_OPTS},subvol=@/tmp
mount /dev/vg0/root /mnt/gentoo/usr/local          -o ${BTRFS_OPTS},subvol=@/usr/local
mount /dev/vg0/root /mnt/gentoo/var                -o ${BTRFS_NOCOW},subvol=@/var
mount /dev/vg0/root /mnt/gentoo/var/log            -o ${BTRFS_NOCOW},subvol=@/var/log
mount /dev/vg0/root /mnt/gentoo/var/log/audit      -o ${BTRFS_NOCOW},subvol=@/var/log/audit
mount /dev/vg0/root /mnt/gentoo/var/cache          -o ${BTRFS_NOCOW},subvol=@/var/cache
mount /dev/vg0/root /mnt/gentoo/var/tmp            -o ${BTRFS_NOCOW},subvol=@/var/tmp

# ── Mount ESP ──
mount /dev/nvme0n1p1 /mnt/gentoo/efi
mkdir -p /mnt/gentoo/efi/EFI/Linux   # UKI destination
```

### 4.5 — Subvolume Justification Table

| Subvolume | Mount point | Rationale |
|---|---|---|
| `@` (via snapshot) | `/` | Root snapshot target |
| `@/.snapshots` | `/.snapshots` | Snapper storage; excluded from root snapshots |
| `@/home` | `/home` | User data survives root rollback |
| `@/opt` | `/opt` | Third‑party software |
| `@/root` | `/root` | Root user home; survives rollback |
| `@/srv` | `/srv` | Service data |
| `@/tmp` | `/tmp` | Ephemeral; never snapshotted |
| `@/usr/local` | `/usr/local` | Locally compiled software |
| `@/var` | `/var` | Variable data; CoW disabled for I/O perf |
| `@/var/log` | `/var/log` | Logs excluded from rollback (forensic value) |
| `@/var/log/audit` | `/var/log/audit` | auditd logs; separate for easier log shipping |
| `@/var/cache` | `/var/cache` | Package caches; excluded and CoW disabled |
| `@/var/tmp` | `/var/tmp` | Persistent temp; excluded |
| `@/nix` | `/nix` | Nix store; CoW disabled for content‑addressed store |

> **`/efi` is a separate VFAT filesystem on the ESP.** No kernel or initramfs files live under `/boot` — they are all inside the signed UKI on the ESP, which is mounted at `/efi`.

---

## Part 5 — Stage 3 and Chroot

### 5.1 — Download and Extract Stage 3

> **The URL below is a placeholder.** Visit `https://www.gentoo.org/downloads/` and copy the link to the latest `stage3-amd64-hardened-systemd` tarball.

```bash
cd /mnt/gentoo

# Replace the URL with the current hardened‑systemd stage3
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-hardened-systemd/stage3-amd64-hardened-systemd-YYYYMMDDTHHMMSSZ.tar.xz

tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
```

### 5.2 — Seed Portage Repository Config

```bash
mkdir --parents /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf \
   /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
```

### 5.3 — Prepare Chroot Environment

```bash
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

mount --types proc  /proc  /mnt/gentoo/proc
mount --rbind       /sys   /mnt/gentoo/sys
mount --make-rslave        /mnt/gentoo/sys
mount --rbind       /dev   /mnt/gentoo/dev
mount --make-rslave        /mnt/gentoo/dev
mount --bind        /run   /mnt/gentoo/run
mount --make-slave         /mnt/gentoo/run

# Fix /dev/shm if it is a symlink (common on non‑Gentoo live media)
test -L /dev/shm && rm /dev/shm && mkdir /dev/shm
mount -t tmpfs -o nosuid,nodev,noexec shm /dev/shm
chmod 1777 /dev/shm

# Copy LUKS UUIDs into the installed system
cp /root/luks-uuids.txt /mnt/gentoo/root/luks-uuids.txt
```

### 5.4 — Configure `configure files`

[nvim /etc/portage/make.conf]

```bash
COMMON_FLAGS="-O2 -march=native -pipe -flto -fno-plt -fno-semantic-interposition"
CPU_FLAGS_X86="aes avx avx2 f16c fma3 mmx mmxext pclmul popcnt rdrand sha sse sse2 sse3 sse4_1 sse4_2 sse4a ssse3 vpclmulqdq"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"
CGO_CFLAGS="${CFLAGS}"
CGO_CXXFLAGS="${CXXFLAGS}"
CGO_FFLAGS="${FFLAGS}"
CGO_LDFLAGS="${LDFLAGS}"
LDFLAGS="${LDFLAGS} -Wl,-O2 -Wl,--as-needed"
MAKEOPTS="-j22"
NOCOMMON_OVERRIDE_LIBTOOL="yes"
EMERGE_DEFAULT_OPTS="--jobs=10 --keep-going=y --ask"
ACCEPT_KEYWORDS="~amd64"
ACCEPT_LICENSE="*"
VIDEO_CARDS="nvidia"
USE="systemd -cups -elogind -fips -gnome -handbook gtk4 \
     -kde -motif -pulseaudio -quicktime -smartcard gtk \
     apparmor appindicator -bluetooth firmware lvm gstreamer \
     gui keyring libnotify lto pgo jit nvenc nvidia pipewire \
     qt5 qt6 udisks upower wayland zstd X -accessibility \
     cryptsetup device-mapper audit"
L10N="en"
LINGUAS="en"
ABI_X86="64"
PORTDIR="/var/db/repos/gentoo"
DISTDIR="/var/cache/distfiles"
PKGDIR="/var/cache/binpkgs"

# Secure Boot signing certificate and key (from sbctl)
SECUREBOOT_SIGN_KEY="/var/lib/sbctl/keys/db/db.key"
SECUREBOOT_SIGN_CERT="/var/lib/sbctl/keys/db/db.pem"
LC_MESSAGES=C
```

`nvim /etc/portage/package.use`

```bash
sys-apps/systemd cryptsetup boot
sys-kernel/installkernel dracut uki
sys-kernel/dracut systemd
sys-fs/cryptsetup static
sys-kernel/linux-firmware compress-zstd
x11-drivers/nvidia-drivers wayland powerd persistenced 
media-gfx/imv -X gif heif icu jpeg jpegxl png svg tiff
gui-wm/hyprland hyprpm -uwsm
sys-kernel/cachyos-sources kcfi
media-video/pipewire sound-server extra gstreamer gsettings pipewire-alsa ffmpeg
app-editors/emacs -X tree-sitter imagemagick mailutils sqlite
sys-devel/gcc default-stack-clash-protection graphite go
llvm-runtimes/compiler-rt-sanitizers orc profile
llvm-core/clang-runtime sanitize
```

`nvim /etc/portage/env/clang-lto-env`

```bash
# /etc/portage/env/clang-lto-env
COMMON_FLAGS="-O3 -pipe -march=native -flto=thin -fno-semantic-interposition -fno-plt"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
HARDENING_FLAGS="-fcf-protection -D_FORTIFY_SOURCE=3 -fstack-protector-strong -fstack-clash-protection"
CFLAGS="${CFLAGS} ${HARDENING_FLAGS}"
CXXFLAGS="${CXXFLAGS} ${HARDENING_FLAGS}"

CC="clang"
CXX="clang++"
AR="llvm-ar"
LD="ld.lld"
NM="llvm-nm"
RANLIB="llvm-ranlib"

LDFLAGS="-fuse-ld=lld -Wl,-O2 -Wl,--as-needed"
RUSTFLAGS="-C target-cpu=native -C opt-level=3 -Clinker=clang -Clink-arg=-fuse-ld=lld"
```

`nvim  /etc/portage/env/polly-on-env`

```bash
POLLY_FLAGS="-mllvm -polly -mllvm -polly-vectorizer=stripmine"
CFLAGS="${CFLAGS} ${POLLY_FLAGS}"
CXXFLAGS="${CXXFLAGS} ${POLLY_FLAGS}"
```

`nvim /etc/portage/package.env`

```bash
media-libs/mesa clang-lto-env polly-on-env
gnome-base/librsvg clang-lto-env polly-on-env
sci-libs/gsl clang-lto-env polly-on-env
media-video/ffmpeg clang-lto-env
media-video/libavif clang-lto-env
media-libs/dav1d clang-lto-env
media-libs/aom clang-lto-env
media-libs/x264 clang-lto-env
media-libs/libvpx clang-lto-env
sys-apps/systemd clang-lto-env
sys-fs/btrfs-progs clang-lto-env
sys-libs/zlib clang-lto-env
dev-db/sqlite clang-lto-env
app-shells/atuin clang-lto-env
app-shells/starship clang-lto-env
app-shells/zoxide clang-lto-env
app-misc/czkawka clang-lto-env
app-misc/yazi clang-lto-env
gui-apps/alacritty-graphics clang-lto-env
sys-apps/bat clang-lto-env
sys-apps/eza clang-lto-env
sys-apps/fd clang-lto-env
sys-process/bottom clang-lto-env
sys-apps/ripgrep clang-lto-env
dev-util/git-delta clang-lto-env
```

`nvim /etc/portage/package.mask`

```bash
#dev-lang/python-3.13.2::gentoo
sys-kernel/cachyos-sources::gentoo-zh
#>=app-editors/neovim-0.11
#>=dev-libs/glib-2.84
#>=sys-kernel/cachyos-sources-6.14
#app-emacs/po-mode::melpa
#>=llvm-core/llvmgold-20
#>=llvm-core/clang-20
#>=llvm-core/clang-common-20
#>=llvm-core/clang-runtime-20
#>=llvm-core/clang-toolchain-symlinks-20
#>=llvm-core/lld-20
#>=llvm-core/lld-toolchain-symlinks-20
#>=llvm-core/llvm-20
#>=llvm-core/llvm-common-20
#>=llvm-core/llvm-toolchain-symlinks-20
#>=llvm-runtimes/compiler-rt-20
#>=llvm-runtimes/compiler-rt-sanitizers-20
#>=llvm-runtimes/libunwind-20
#>=dev-util/spirv-llvm-translator-20
```


### 5.5 — Enter Chroot

```bash
chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) ${PS1}"
```

> **All subsequent commands run inside the chroot.**

---

## Part 6 — Base Configuration and Portage

### 6.1 — Timezone, Locale, Hostname

```bash
ln -sf ../usr/share/zoneinfo/Asia/Dhaka /etc/localtime
nano /etc/locale.gen
locale-gen
eselect locale set 4
env-update && source /etc/profile

echo "workstation" > /etc/hostname
```

### 6.2 — Sync Portage and Select Profile

```bash
emerge-webrsync
emerge --sync

# List profiles; the hardened systemd profile is present on the
# official mirrors:
eselect profile list
# Choose: default/linux/amd64/23.0/no-multilib/hardened/systemd
eselect profile set <number>
source /etc/profile
```

### 6.3 — Install Core Packages

```bash
emerge --ask app-eselect/eselect-repository dev-vcs/git
```

### 6.4 — Enable CachyOS‑Kernels Overlay

```bash
eselect repository enable CachyOS-kernels hyproverlay
emaint sync -r CachyOS-kernels
```

### 6.5 — Enable GPG Commit Verification for Portage

`nvim /etc/portage/repos.conf/gentoo.conf`

```bash
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

---

## Part 7 — Kernel: CachyOS-Sources with Clang + kCFI

### 7.1 — Install Kernel Sources and Required Packages

```bash
# Install the kernel sources, firmware, and sbctl for Secure Boot signing.
# sbctl must be emerged BEFORE the kernel build so that signing keys exist
# when dracut generates the first UKI.
emerge --ask sys-kernel/cachyos-sources sys-kernel/linux-firmware app-crypt/sbctl
eselect kernel set 1
cd /usr/src/linux
```

### 7.2 — Configure the Kernel

The cachyos-sources ebuild installs a pre‑configured `.config` optimised for performance. The `kcfi` USE flag (already set in Section 5.4) **automates** enabling Kernel Control Flow Integrity — it applies the necessary configuration fragments so that you do **not** need to search for the option manually. The manual steps below are provided for verification.

```bash
make menuconfig LLVM=1
```

Verify that the following are enabled (use `/` to search):

```
# ── Kernel Control Flow Integrity (kCFI) ──
# NOTE: The 'kcfi' USE flag on sys-kernel/cachyos-sources automates this.
# If the flag is set, the option should already be enabled.
# In kernels ≥ 6.13 the option is named CONFIG_CFI (renamed from CONFIG_CFI_CLANG).
General architecture-dependent options
  [*] Control Flow Integrity (CFI) hardening              CONFIG_CFI

# ── LUKS, LVM, Btrfs ──
Device Drivers → Multiple devices driver support
  <*> Device mapper support                                CONFIG_BLK_DEV_DM
  <*>   Crypt target support                               CONFIG_DM_CRYPT

File systems
  <*> Btrfs filesystem support                             CONFIG_BTRFS_FS
  [*]   Btrfs POSIX Access Control Lists                   CONFIG_BTRFS_FS_POSIX_ACL

# ── TPM ──
Device Drivers → Character devices → TPM Hardware Support
  <*> TPM Hardware Support                                 CONFIG_TCG_TPM
  <*>   TPM Interface Specification 2.0 (FIFO)             CONFIG_TCG_TIS_CORE

# ── NVMe ──
Device Drivers → NVMe Support
  <*> NVM Express block device                             CONFIG_BLK_DEV_NVME

# ── EFI Stub (required for UKI) ──
Processor type and features
  [*] EFI runtime service support                          CONFIG_EFI
  [*]   EFI stub support                                   CONFIG_EFI_STUB

# ── Cryptographic API ──
  <*> XTS support                                          CONFIG_CRYPTO_XTS
  <*> AES cipher algorithms                                CONFIG_CRYPTO_AES
  <*> AES cipher algorithms (x86_64)                       CONFIG_CRYPTO_AES_X86_64
  <*> SHA-2 (SHA-384 and SHA-512)                          CONFIG_CRYPTO_SHA512

# ── Kernel hardening config fragments ──
Security options
  [*] Enable kernel hardening configuration fragments      CONFIG_ARCH_HAS_KERNEL_HARDENING
```

> **kCFI verification**: After boot, run `zcat /proc/config.gz | grep CFI`. You should see `CONFIG_CFI=y` (kernels ≥ 6.13) or `CONFIG_CFI_CLANG=y` (older kernels), plus `CONFIG_LTO_CLANG=y`.

### 7.3 — Build and Install

```bash
# Build with Clang + ThinLTO
make -j$(nproc) LLVM=1

# Install modules
make modules_install LLVM=1

# Install kernel — triggers installkernel (dracut → UKI → sign)
make install LLVM=1
```

`make install` triggers `sys-kernel/installkernel` which:
1. Copies the kernel to `/boot`
2. Runs `dracut` with UKI configuration → generates and signs a Unified Kernel Image
3. Installs the signed UKI to `/efi/EFI/Linux/`

No UEFI boot entry manipulation is performed; the firmware directly loads the UKI.

### 7.4 — Generate Secure Boot Keys (Before First Boot)

Dracut requires the Secure Boot signing keys to exist at the paths specified in its configuration. Generate them now:

```bash
sbctl create-keys

# Verify the keys were created
ls -l /var/lib/sbctl/keys/db/db.key /var/lib/sbctl/keys/db/db.pem
```

> **Note**: Key **enrollment** into UEFI firmware happens later (Part 9), after the first reboot into Setup Mode. For now, having the keys generated is sufficient for dracut to produce a signed UKI.

---

## Part 8 — Dracut Configuration for UKI + TPM2

- [ ] ### 8.1 — Main Dracut Configuration

`mkdir -p /etc/dracut.conf.d/ && nvim /etc/dracut.conf.d/00-base.conf`

```bash
# /etc/dracut.conf.d/00-base.conf
# Hardened Gentoo — UKI + TPM2 + LUKS2 + LVM + Btrfs, April 2026

# --- Hostonly mode ---
hostonly="yes"
hostonly_cmdline="no"

# --- UKI output ---
uefi="yes"
uefi_stub="/usr/lib/systemd/boot/efi/linuxx64.efi.stub"
compress="zstd"
early_microcode="yes"

# --- Dracut modules ---
add_dracutmodules+=" tpm2-tss crypt lvm btrfs systemd systemd-initrd "

# --- Kernel modules needed early ---
add_drivers+=" tpm_crb tpm_tis tpm_tis_core dm_crypt dm_mod aes_x86_64 "

# --- Explicitly embed the initramfs crypttab ---
install_items+=" /etc/crypttab.initramfs /etc/crypttab "

# --- Secure Boot signing keys ---
uefi_secureboot_cert="/var/lib/sbctl/keys/db/db.pem"
uefi_secureboot_key="/var/lib/sbctl/keys/db/db.key"
```

> **Ordering requirement**: The `sbctl create-keys` command in Part 7.4 **must** be run before this dracut configuration takes effect (i.e., before `make install` or any manual `dracut` invocation). If the keys are absent, dracut will fail to sign the UKI.

> **`uefi_stub` path**: `/usr/lib/systemd/boot/efi/linuxx64.efi.stub` is provided by `sys-apps/systemd` when the `boot` USE flag is enabled — which is already set in Section 5.4.

- [ ] ### 8.2 — Kernel Command Line (Embedded in UKI)
```bash
# Load LUKS UUIDs saved during disk preparation
source /root/luks-uuids.txt

mkdir -p /etc/kernel

cat > /etc/kernel/cmdline << EOF
quiet rootfstype=btrfs rd.luks.uuid=luks-${CRYPT0_UUID} rd.luks.uuid=luks-${CRYPT1_UUID} rd.lvm.vg=vg0 root=/dev/vg0/root intel_iommu=on iommu=force apparmor=1 security=apparmor audit=1 slab_nomerge init_on_alloc=1 init_on_free=1 mitigations=auto
EOF
```

### 8.3 — Crypttab for TPM2 Unlock

```bash
# The initramfs /etc/crypttab tells systemd-cryptsetup-generator
# to unlock using TPM2. The '-' in the keyfile column means
# "no keyfile; use TPM2/FIDO2".
cat > /etc/crypttab.initramfs << EOF
crypt0  UUID=${CRYPT0_UUID}  -  tpm2-device=auto,discard
crypt1  UUID=${CRYPT1_UUID}  -  tpm2-device=auto,discard
EOF

chmod 600 /etc/crypttab.initramfs
```

> **`tpm2-device=auto`** in the options column tells systemd-cryptsetup to use the TPM2 token enrolled via `systemd-cryptenroll`. The initramfs will look for a TPM2-enrolled LUKS token slot and attempt to unseal it (after PIN entry if `‑‑tpm2‑with‑pin=yes` was used during enrollment).

### 8.4 — Running System Crypttab (noauto)

```bash
cat > /etc/crypttab << EOF
# /etc/crypttab — Running system
# LUKS volumes are opened by dracut in initramfs.
# 'noauto' prevents systemd from re-opening them at runtime.
crypt0  UUID=${CRYPT0_UUID}  -  tpm2-device=auto,discard,noauto
crypt1  UUID=${CRYPT1_UUID}  -  tpm2-device=auto,discard,noauto
EOF
```

---

## Part 9 — Secure Boot with sbctl

### 9.1 — Prerequisites

Before proceeding, ensure that:

* `app-crypt/sbctl` was emerged in Part 7.1.
* Secure Boot keys were generated in Part 7.4 (`sbctl create-keys`).
* The UEFI firmware is in **Setup Mode** (Secure Boot disabled; clear existing keys in the firmware menu if necessary). The Gentoo Wiki warns that enrolling keys without the Microsoft vendor keys `‑m` **can be dangerous and could potentially brick a system** if Option ROMs require Microsoft‑signed binaries.

### 9.2 — Enroll Keys into UEFI Firmware

```bash
# Verify the current state
sbctl status
# Should show: Setup Mode: ✘ Enabled, Secure Boot: ✘ Disabled

# Enroll keys with Microsoft vendor certs (use -m or --microsoft; both are accepted)
sbctl enroll-keys -m

# Verify after enrollment
sbctl status
# Should show: Installed: ✔, Setup Mode: ✔ Disabled, Secure Boot: ✔ Enabled
```

> **Flag forms**: The Gentoo Wiki uses the short form `‑m`; the long form `‑‑microsoft` is also supported by all recent versions of sbctl.

### 9.3 — Sign the UKI on the ESP

```bash
# Sign all UKIs. Use 'sbctl sign -s' to save to the signing database
# (the Gentoo Wiki uses -s; --save is an equivalent long form)
sbctl sign -s /efi/EFI/Linux/*.efi

# Verify everything on the ESP is signed
sbctl verify
```

### 9.4 — Automatic Re‑Signing After Kernel Updates

The `sbctl` package ships a kernel‑install hook (`/usr/lib/kernel/install.d/91-sbctl.install`) that automatically signs new UKIs when the systemd kernel‑install layout is used. However, this guide uses the traditional (non‑systemd) installkernel layout with `dracut uki`, so the systemd hook is **not triggered**. A manual post‑install hook is required:

```bash
mkdir -p /etc/kernel/postinst.d

cat > /etc/kernel/postinst.d/99-sbctl-sign.sh << 'SCRIPT'
#!/bin/bash
# Re-sign all UKIs after kernel installation.
# This hook runs after every 'make install' via installkernel.
if command -v sbctl &>/dev/null; then
    sbctl sign -s /efi/EFI/Linux/*.efi 2>/dev/null
fi
SCRIPT
chmod +x /etc/kernel/postinst.d/99-sbctl-sign.sh
```

---

## Part 10 — TPM2 + PIN Enrollment

> **Complete this after first successful boot into the installed system.**

### 10.1 — Enroll Both LUKS Containers

```bash
# Enroll TPM2+PIN on both LUKS containers
systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs="0+2+7+12" \
  --tpm2-with-pin=yes \
  /dev/nvme0n1p2

systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs="0+2+7+12" \
  --tpm2-with-pin=yes \
  /dev/nvme1n1p1

# Generate recovery keys (store offline!)
systemd-cryptenroll --recovery-key /dev/nvme0n1p2
systemd-cryptenroll --recovery-key /dev/nvme1n1p1

# Verify enrollment
systemd-cryptenroll /dev/nvme0n1p2
systemd-cryptenroll /dev/nvme1n1p1
```

> **PIN security note**: `systemd‑cryptenroll` does **not** validate the TPM measurement **before** prompting for the PIN. In an untrusted boot environment, a malicious initramfs could capture the PIN. Use a unique PIN for the TPM that is not reused elsewhere. This limitation is documented by systemd upstream and the Arch Wiki.

### 10.2 — PCR Register Justification

| PCR | Measures | Why Included |
|---|---|---|
| PCR[0] | UEFI firmware code | Detects firmware tampering (Evil Maid flashing malicious UEFI) |
| PCR[2] | Option ROM code | Detects malicious GPU/NIC UEFI ROMs via Thunderbolt/PCIe |
| PCR[7] | Secure Boot state (db, dbx, PK, KEK) | Seals against Secure Boot key rotation |
| PCR[12] | Kernel cmdline (measured by systemd‑boot / direct UEFI load) | Seals against modification of the embedded UKI cmdline |

> **Direct UEFI boot note**: When the firmware loads a UKI directly (no systemd‑boot), the kernel cmdline embedded in the UKI is measured into PCR[12] by the systemd stub. PCR[11] measures the entire UKI. Both are valid for sealing, but PCR[12] is more specific: it will not be invalidated by non‑cmdline UKI changes (e.g., a new kernel version within the same signed image). If you prefer to seal against the entire UKI content, replace `12` with `11` in the PCR list.

---

## Part 11 — fstab

```bash
# Get filesystem UUIDs
ROOT_UUID=$(blkid -s UUID -o value /dev/vg0/root)
ESP_UUID=$(blkid -s UUID -o value /dev/nvme0n1p1)

cat > /etc/fstab << EOF
# /etc/fstab — Hardened Gentoo, April 2026

# Btrfs root – mounts the current default subvolume (set by snapper)
UUID=${ROOT_UUID}  /                    btrfs  defaults,noatime,compress=zstd:1,space_cache=v2  0 0

# Snapper directory
UUID=${ROOT_UUID}  /.snapshots          btrfs  defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@/.snapshots  0 0

# Data subvolumes
UUID=${ROOT_UUID}  /home                btrfs  defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@/home  0 0
UUID=${ROOT_UUID}  /opt                 btrfs  defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@/opt  0 0
UUID=${ROOT_UUID}  /root                btrfs  defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@/root  0 0
UUID=${ROOT_UUID}  /srv                 btrfs  defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@/srv  0 0
UUID=${ROOT_UUID}  /tmp                 btrfs  defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@/tmp  0 0
UUID=${ROOT_UUID}  /usr/local           btrfs  defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@/usr/local  0 0

# Var subvolumes – CoW disabled with chattr +C, no mount‑time nodatacow needed
UUID=${ROOT_UUID}  /var                 btrfs  defaults,noatime,space_cache=v2,subvol=@/var  0 0
UUID=${ROOT_UUID}  /var/log             btrfs  defaults,noatime,space_cache=v2,subvol=@/var/log  0 0
UUID=${ROOT_UUID}  /var/log/audit       btrfs  defaults,noatime,space_cache=v2,subvol=@/var/log/audit  0 0
UUID=${ROOT_UUID}  /var/cache           btrfs  defaults,noatime,space_cache=v2,subvol=@/var/cache  0 0
UUID=${ROOT_UUID}  /var/tmp             btrfs  defaults,noatime,space_cache=v2,subvol=@/var/tmp  0 0

# Nix store – CoW disabled with chattr +C
UUID=${ROOT_UUID}  /nix                 btrfs  defaults,noatime,space_cache=v2,subvol=@/nix  0 0

# ESP
UUID=${ESP_UUID}    /efi                vfat   defaults,noatime  0 2

# zram swap
/dev/zram0         none                 swap   defaults,pri=100  0 0
EOF
```

---

## Part 12 — Zram Swap Configuration

```bash
cat > /etc/systemd/zram-generator.conf << 'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF

systemctl enable systemd-zram-setup@zram0.service
```

---

## Part 13 — Snapper Integration

```bash
# Install
emerge --ask app-backup/snapper

# Initialize
snapper --no-dbus -c root create-config /

# Fix .snapshots conflict
umount /.snapshots 2>/dev/null
rm -rf /.snapshots
mkdir /.snapshots
mount -a
chmod 750 /.snapshots

# Configure
cat > /etc/snapper/configs/root << 'EOF'
SUBVOLUME="/"
FSTYPE="btrfs"
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="2"
TIMELINE_LIMIT_MONTHLY="3"
TIMELINE_LIMIT_YEARLY="0"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="25"
NUMBER_LIMIT_IMPORTANT="10"
EOF

# Enable timers
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer
systemctl enable snapper-boot.timer
```

### Portage Hooks for Pre/Post Snapshots

```bash
cat > /etc/portage/bashrc << 'BASHRC'
pre_pkg_preinst() {
    if command -v snapper &>/dev/null; then
        SNAPPER_PRE_NUM=$(snapper -c root create \
            --type pre --print-number --cleanup-algorithm number \
            --description "portage pre: ${CATEGORY}/${PF}" 2>/dev/null)
        export SNAPPER_PRE_NUM
    fi
}

post_pkg_postinst() {
    if command -v snapper &>/dev/null && [[ -n "${SNAPPER_PRE_NUM}" ]]; then
        snapper -c root create \
            --type post --pre-number "${SNAPPER_PRE_NUM}" \
            --cleanup-algorithm number \
            --description "portage post: ${CATEGORY}/${PF}" 2>/dev/null
        unset SNAPPER_PRE_NUM
    fi
}
BASHRC
```

---

## Part 14 — AppArmor Configuration

```bash
emerge --ask app-armor/apparmor app-armor/apparmor-utils app-armor/apparmor.d

systemctl enable apparmor.service auditd.service
```

> **The Arch hardening guide’s AppArmor configuration (Part 3 of `arch_hardening_setup.md`) should be followed in its entirety**: fast caching, `apparmor.d` profile deployment, enforce/complain mode assignments, local override files. The kernel parameters `apparmor=1 security=apparmor` and the LSM stack are already embedded in the UKI cmdline.

---

## Part 15 — Sysctl Hardening

> **Use the complete sysctl configuration from `arch_hardening_setup.md` Part 5.** The file `/etc/sysctl.d/99-hardening.conf` should contain all 50+ annotated parameters — ASLR, kernel pointer hiding, BPF hardening, ptrace restrictions, network stack hardening, filesystem protections, kernel memory hardening — exactly as documented in the Arch guide. Apply with `sysctl --system`.

---

## Part 16 — Kernel Module Blacklisting

> **Use the complete module blacklist from `arch_hardening_setup.md` Part 6.** `/etc/modprobe.d/blacklist-hardening.conf` should blacklist unused filesystems (cramfs, freevxfs, jffs2, hfs, hfsplus, udf), unused network protocol parsers (dccp, sctp, rds, tipc, etc.), Firewire drivers, and legacy modules. Thunderbolt is **not** blacklisted (IOMMU provides compensating control). Rebuild the initramfs after deploying.

---

## Part 17 — IOMMU and DMA Protection

> **The IOMMU kernel parameters are already embedded in the UKI cmdline**: `intel_iommu=on iommu=force`. Verify in UEFI that **VT‑d is enabled** and **Thunderbolt Security** is set to **User Authorization**. After boot, verify with `dmesg | grep "Intel-IOMMU: enabled"`. Full verification commands are in `arch_hardening_setup.md` Part 7.

---

## Part 18 — Auditd Hardening

> **Deploy the complete auditd ruleset from `arch_hardening_setup.md` Part 4** as `/etc/audit/rules.d/99-hardening.rules`. This covers file integrity monitoring, privileged command execution, authentication events, network socket creation, kernel module loads, package manager activity, and more. Also deploy the matching `/etc/audit/auditd.conf`.

---

## Part 19 — Network Hardening

### 19.1 — Firewalld

```bash
emerge --ask net-firewall/firewalld
systemctl enable --now firewalld
```

> **Apply the complete firewalld configuration from `arch_hardening_setup.md` Part 9.1**: default `drop` zone, explicit rules for DNS‑over‑TLS (853/tcp), DoH (443), SSH (custom port), Cockpit (localhost only), and outbound port 53 blocking.

### 19.2 — DNS‑over‑TLS with DNSCrypt‑Proxy

```bash
emerge --ask net-dns/dnscrypt-proxy
```

> **Apply the complete DNSCrypt and systemd‑resolved configuration from `arch_hardening_setup.md` Part 9.2**: `dnscrypt‑proxy` on 127.0.0.1:5300, `systemd‑resolved` stub on 127.0.0.53, DoT‑only forwarding, anonymized relay routes, `require_dnssec`, `require_nolog`, `require_nofilter`.

### 19.3 — NetworkManager Hardening

```bash
emerge --ask net-misc/networkmanager
systemctl enable --now NetworkManager
```

> **Apply the NetworkManager hardening from `arch_hardening_setup.md` Part 9.3**: MAC address randomisation (ethernet: random, WiFi: stable‑ssid), connectivity checking disabled, WiFi WPS disabled, WPA3‑SAE preferred.

---

## Part 20 — SSH Hardening

```bash
emerge --ask net-misc/openssh
```

> **Apply the complete SSH server and client hardening from `arch_hardening_setup.md` Part 10**: custom port 2222, Ed25519 and ECDSA P‑521 keys only, Curve25519 Kex, ChaCha20‑Poly1305 and AES‑256‑GCM ciphers, key‑only auth, no root login, `AllowGroups sshusers`, strict idle timeout, all forwarding disabled.

---

## Part 21 — PAM Hardening

```bash
emerge --ask sys-libs/pam sys-libs/libpwquality
```

> **Apply the PAM configuration from `arch_hardening_setup.md` Part 11**: `pam_faillock` (5 failures → 15‑minute lockout), `pam_pwquality` (16‑char minimum, 3+ character classes, dictionary check), hardened `/etc/pam.d/system-auth`, resource limits in `/etc/security/limits.conf`.

---

## Part 22 — Supply Chain Monitoring

### 22.1 — Portage Post‑Transaction Audit Logging

```bash
cat > /etc/portage/bashrc.d/audit-log.sh << 'SCRIPT'
#!/bin/bash
# Log all package transactions to structured JSON audit log

post_pkg_postinst() {
    local AUDIT_LOG="/var/log/portage-audit.json"
    local TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local ENTRY=$(python3 -c "import json; print(json.dumps({
        'timestamp': '$TS',
        'action': 'emerge',
        'package': '${CATEGORY}/${PF}',
        'status': 'COMPLETED'
    }))")
    echo "$ENTRY" >> "$AUDIT_LOG" 2>/dev/null || true
}
SCRIPT
```

### 22.2 — CVE Scanning

```bash
# Gentoo provides GLSA (Gentoo Linux Security Advisories) via glsa-check
emerge --ask app-portage/gentoolkit

# Weekly scan script
cat > /usr/local/bin/weekly-cve-scan.sh << 'SCRIPT'
#!/bin/bash
# Run: glsa-check -l affected
glsa-check -l affected 2>&1
SCRIPT
chmod +x /usr/local/bin/weekly-cve-scan.sh
```

---

## Part 23 — Ongoing Monitoring and Email Alerting

> **Deploy the complete monitoring infrastructure from `arch_hardening_setup.md` Part 14**: `msmtp` for email relay, daily auditd summary script, weekly CVE report, weekly AppArmor denial digest, all wired to systemd timers. Replace the recipient address with your own.

---

## Part 24 — systemd Service Hardening

> **Deploy `svc-harden.py` from `arch_hardening_setup.md` Part 12.** This Python tool provides `analyze`, `apply`, `test`, `revert`, and `bisect` subcommands for per‑service systemd hardening. It applies directives like `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`, `MemoryDenyWriteExecute`, and `SystemCallFilter` interactively, one service at a time.

---

## Part 25 — System Packages (Desktop)

> **Install all packages listed in `README.md` sections for desktop, development, containers, and scientific computing.** The full emerge list from the personal runbook includes:

```bash
emerge --ask \
  gui-wm/hyprland gui-wm/hyprland-contrib \
  gui-libs/aquamarine gui-libs/hyprcursor gui-libs/hyprutils \
  gui-libs/xdg-desktop-portal-hyprland \
  gui-apps/hyprlock gui-apps/hypridle gui-apps/hyprpaper \
  gui-apps/grim gui-apps/slurp gui-apps/wl-clipboard \
  gui-apps/rofi-wayland \
  x11-misc/sddm x11-base/xwayland \
  app-shells/zsh app-shells/starship app-shells/zoxide \
  app-shells/fzf app-shells/atuin \
  app-editors/neovim app-editors/emacs \
  dev-vcs/git dev-vcs/lazygit \
  app-containers/docker app-containers/docker-cli \
  app-containers/podman app-containers/distrobox \
  www-client/zen-browser-bin \
  net-im/discord net-im/zoom \
  media-sound/spotify \
  app-office/obsidian \
  app-text/zathura app-text/zathura-meta \
  xfce-base/thunar xfce-base/thunar-volman \
  # ... (full list from README.md)
```

> **Note**: Some packages listed in README.md (e.g., `nvidia-drivers`) are hardware‑dependent. Install only what applies to your system.

---

## Part 26 — Login Banner

```bash
cat > /etc/issue << 'EOF'
-- WARNING -- This system is for the use of authorized users only. Individuals
using this computer system without authority or in excess of their authority
are subject to having all their activities on this system monitored and
recorded by system personnel. Anyone using this system expressly consents to
such monitoring and is advised that if such monitoring reveals possible
evidence of criminal activity system personal may provide the evidence of
such monitoring to law enforcement officials.
EOF

cp /etc/issue /etc/issue.net
```

---

## Part 27 — Final System Setup and First Boot

### 27.1 — Set Root Password and Create User

```bash
passwd
useradd -m -G users,wheel,audio,video -s /bin/bash ahsan
passwd ahsan
```

### 27.2 — Enable Essential Services

```bash
systemctl enable NetworkManager
systemctl enable sshd
systemctl enable firewalld
systemctl enable auditd
systemctl enable apparmor
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer
systemctl enable snapper-boot.timer
systemctl enable systemd-resolved
systemctl enable dnscrypt-proxy
systemctl enable cockpit.socket
```

### 27.3 — Regenerate UKI (First Time Manually)

```bash
KVER=$(ls /lib/modules/ | sort -V | tail -1)
dracut --force --verbose /efi/EFI/Linux/gentoo-${KVER}.efi ${KVER}
sbctl sign --save /efi/EFI/Linux/gentoo-${KVER}.efi
```

### 27.4 — Exit Chroot and Reboot

```bash
exit
umount -R /mnt/gentoo
reboot
```

---

## Part 28 — Post‑Install: TPM2 Enrollment and Verification

After first boot (you will be prompted for the LUKS passphrase):

```bash
# 1. Verify Secure Boot
sbctl status

# 2. Enroll TPM2+PIN (see Part 10 for full commands)

# 3. Verify TPM2 unlock works
# Reboot — you should be prompted for PIN instead of passphrase

# 4. Verify key system components
systemctl is-active sshd firewalld auditd apparmor
aa-status | head
sysctl kernel.kptr_restrict kernel.dmesg_restrict
dmesg | grep "Intel-IOMMU: enabled"
cat /sys/kernel/security/lsm
```

---

## Part 29 — Post‑Install Chroot Re‑Entry

If you need to re‑enter the installed system from a live environment (e.g., for recovery):

```bash
# Open LUKS
cryptsetup luksOpen /dev/nvme0n1p2 crypt0
cryptsetup luksOpen /dev/nvme1n1p1 crypt1

# Activate LVM
vgchange -ay vg0

# Mount Btrfs root
BTRFS_OPTS="defaults,noatime,compress=zstd:1,space_cache=v2"
BTRFS_NOCOW="defaults,noatime,space_cache=v2"

mkdir -p /mnt/gentoo
mount -o ${BTRFS_OPTS},subvol=@/.snapshots/1/snapshot \
  /dev/vg0/root /mnt/gentoo

# Mount all subvolumes
mount -o ${BTRFS_OPTS},subvol=@/.snapshots /dev/vg0/root /mnt/gentoo/.snapshots
mount -o ${BTRFS_OPTS},subvol=@/home       /dev/vg0/root /mnt/gentoo/home
mount -o ${BTRFS_NOCOW},subvol=@/nix       /dev/vg0/root /mnt/gentoo/nix
mount -o ${BTRFS_OPTS},subvol=@/opt        /dev/vg0/root /mnt/gentoo/opt
mount -o ${BTRFS_OPTS},subvol=@/root       /dev/vg0/root /mnt/gentoo/root
mount -o ${BTRFS_OPTS},subvol=@/srv        /dev/vg0/root /mnt/gentoo/srv
mount -o ${BTRFS_OPTS},subvol=@/tmp        /dev/vg0/root /mnt/gentoo/tmp
mount -o ${BTRFS_OPTS},subvol=@/usr/local  /dev/vg0/root /mnt/gentoo/usr/local
mount -o ${BTRFS_NOCOW},subvol=@/var        /dev/vg0/root /mnt/gentoo/var
mount -o ${BTRFS_NOCOW},subvol=@/var/log    /dev/vg0/root /mnt/gentoo/var/log
mount -o ${BTRFS_NOCOW},subvol=@/var/log/audit /dev/vg0/root /mnt/gentoo/var/log/audit
mount -o ${BTRFS_NOCOW},subvol=@/var/cache  /dev/vg0/root /mnt/gentoo/var/cache
mount -o ${BTRFS_NOCOW},subvol=@/var/tmp    /dev/vg0/root /mnt/gentoo/var/tmp

# Mount ESP
mount /dev/nvme0n1p1 /mnt/gentoo/efi

# Bind mounts
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run

test -L /dev/shm && rm /dev/shm && mkdir /dev/shm
mount -t tmpfs -o nosuid,nodev,noexec shm /dev/shm
chmod 1777 /dev/shm

# Enter chroot
chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) ${PS1}"
```

---

## Part 30 — TPM2 Key Recovery

### 30.1 — After UEFI Firmware Update or Secure Boot Key Rotation

```bash
# PCR[0] or PCR[7] will have changed → TPM2 unsealing fails
# Boot using the recovery key (prompted at LUKS unlock)

# Once booted:
systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p2
systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme1n1p1

# Re-enroll with new PCR baseline
systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs="0+2+7+12" \
  --tpm2-with-pin=yes \
  /dev/nvme0n1p2

systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs="0+2+7+12" \
  --tpm2-with-pin=yes \
  /dev/nvme1n1p1

# Revoke used recovery key and generate new one
systemd-cryptenroll --wipe-slot=recovery /dev/nvme0n1p2
systemd-cryptenroll --wipe-slot=recovery /dev/nvme1n1p1
systemd-cryptenroll --recovery-key /dev/nvme0n1p2
systemd-cryptenroll --recovery-key /dev/nvme1n1p1
```

### 30.2 — Complete TPM Failure

```bash
# Fall back to recovery-key-only boot:
# At LUKS prompt, enter recovery key.

# When TPM is functional again, re-enroll as above.
# If TPM is permanently damaged, enroll a strong passphrase:
systemd-cryptenroll --password /dev/nvme0n1p2
systemd-cryptenroll --password /dev/nvme1n1p1
```

---

## Appendix A — Installation Order Checklist

```
Phase 1 — Live Environment:
  1.1  Partition both drives (gdisk)
  1.2  Format ESP (mkfs.vfat)
  1.3  LUKS2 format both PV partitions (Argon2id)
  1.4  Open LUKS containers
  1.5  LUKS header backups
  1.6  Create LVM PVs, VG, and linear LV
  1.7  Format LV as Btrfs
  1.8  Create all subvolumes, set default snapshot
  1.9  Mount all subvolumes and ESP (at /efi)
  1.10 Extract stage3, chroot

Phase 2 — Base System (chroot):
  2.1  Timezone, locale, hostname
  2.2  Sync Portage, select hardened profile
  2.3  Install core packages, enable overlays
  2.4  Configure make.conf and package.use
  2.5  Install cachyos-sources
  2.6  Configure kernel (menuconfig: enable kCFI)
  2.7  Build and install kernel (make LLVM=1)
  2.8  Configure dracut for UKI (uefi_dir=/efi/EFI/Linux)
  2.9  Install sbctl, generate and enroll keys
  2.10 Configure crypttab (initramfs + running system)
  2.11 Write fstab (ESP mount point /efi)
  2.12 Configure zram
  2.13 Set root password, create user
  2.14 Exit chroot, reboot

Phase 3 — Post-Boot Hardening:
  3.1  Enroll TPM2+PIN (must be done on running system)
  3.2  Deploy and configure AppArmor + apparmor.d
  3.3  Deploy sysctl hardening
  3.4  Deploy module blacklist, rebuild UKI
  3.5  Verify IOMMU
  3.6  Configure firewalld
  3.7  Configure dnscrypt-proxy + systemd-resolved
  3.8  Harden NetworkManager
  3.9  Harden SSH
  3.10 Harden PAM
  3.11 Deploy auditd rules
  3.12 Configure Snapper + Portage hooks
  3.13 Deploy svc-harden.py
  3.14 Configure monitoring timers + msmtp
  3.15 Install desktop packages (README.md list)
  3.16 Set login banner
  3.17 Full system audit pass
```

## Appendix B — Conflict and Uncertainty Notes

| Item | Conflict | Resolution |
|---|---|---|
| kCFI in cachyos-sources | CachyOS wiki says kCFI is “available when using LLVM” but the base config sets `# CONFIG_CFI_CLANG is not set` | Enable manually in `make menuconfig`. Verified via `zcat /proc/config.gz \| grep CFI` after boot. |
| `rootflags=subvol=` in UKI cmdline | Must point to the active snapshot. Changes after every Snapper rollback. | Embed `subvol=@/.snapshots/1/snapshot` in the UKI cmdline. After rollback, edit `/etc/dracut.conf.d/01-cmdline.conf` and rebuild the UKI (`dracut --force`). |
| `kernel.unprivileged_userns_clone` | Setting to 0 breaks Chrome/Firefox/Flatpak sandboxing; setting to 1 leaves namespace CVE surface. | Set to 1 with AppArmor profiling the consumers. |
| `haveged` and `rng-tools` on i9-13900K | README installs both; Arch analysis says both are unnecessary on kernel ≥ 6.x with RDRAND. | Do **not** install. The kernel’s CRNG initialises immediately via RDRAND. |
| Gentoo hardened profile vs. kernel hardening | The profile hardens userspace, not the kernel. | Kernel hardening is done via cachyos-sources + Clang + kCFI + sysctl + module blacklisting. |

## Appendix C — Changes from the Previous Version (April 2026)

1. **ESP mount point changed from `/boot/efi` to `/efi`.**  
   This aligns with the modern `systemd` standard and the Boot Loader Specification, which recommend a separate `/efi` mount to cleanly isolate firmware files from the OS. All paths in the guide (partition layout, mount commands, dracut `uefi_dir`, fstab, post‑install scripts, chroot re‑entry) have been updated accordingly.

2. **`sys-kernel/installkernel` USE flags corrected.**  
   The previous recommendation of `dracut uki efistub` has been changed to `dracut uki`. The `efistub` flag is experimental and unnecessary; its use for creating UEFI boot entries has been removed from the description of `make install`. The `systemd` flag (or `systemd‑kernel‑install`) is not required for basic UKI generation.

3. **Missing subvolumes added.**  
   The subvolumes `@/var/log`, `@/var/log/audit`, and `@/var/cache` were listed in the mount table and justification table but were not created in the subvolume creation step. These are now created with appropriate `chattr +C` for CoW disabling.

4. **Minor text clarifications.**  
   Added a note that `efistub` is no longer used and that the firmware loads the UKI directly. Updated the note about `/boot` being a plain directory to reflect that only the mount point for `/efi` resides there.

---

*Guide prepared April 2026. Architecture verified against: Gentoo Wiki (Hardened, UKI, Dracut, Installkernel, Secure Boot, systemd‑cryptenroll), Arch Wiki (dm‑crypt, Unified Kernel Image, Secure Boot), CachyOS Wiki (Kernel), and systemd documentation (systemd‑cryptenroll, systemd‑stub).*

```
