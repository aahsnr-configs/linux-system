# Hardened Gentoo Installation Guide — APT Threat Model

## Against Nation-State Advanced Persistent Threats — April 2026

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
COMMON_FLAGS="-O3 -march=native -pipe -flto -fno-plt -fno-semantic-interposition"
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
#ACCEPT_KEYWORDS="~amd64"
ACCEPT_LICENSE="*"
VIDEO_CARDS="nvidia"
USE="systemd -cups -elogind -fips -gnome -handbook gtk4 \
     -kde -motif -pulseaudio -quicktime -smartcard gtk \
     apparmor appindicator -bluetooth firmware lvm gstreamer \
     gui keyring libnotify lto pgo jit nvenc nvidia pipewire \
     qt5 qt6 udisks upower wayland zstd X -accessibility \
     cryptsetup device-mapper audit policykit"
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
sys-apps/systemd cryptsetup boot tpm
sys-kernel/installkernel dracut uki
sys-kernel/dracut systemd
sys-fs/cryptsetup static
sys-kernel/linux-firmware compress-zstd
x11-drivers/nvidia-drivers wayland powerd persistenced 
media-gfx/imv -X gif heif icu jpeg jpegxl png svg tiff
gui-wm/hyprland hyprpm -uwsm
sys-kernel/cachyos-sources kcfi
media-video/pipewire sound-server extra gstreamer gsettings pipewire-alsa ffmpeg
app-editors/emacs -X tree-sitter imagemagick mailutils jit dynamic-loading gtk gui
sys-devel/gcc default-stack-clash-protection graphite go
llvm-runtimes/compiler-rt-sanitizers orc profile
llvm-core/clang-runtime sanitize
dev-lang/python -jit tk
net-misc/networkmanager nftables gnutls -resolvconf
app-admin/cockpit firewalld pcp udisks
sys-auth/pambase pwquality
app-text/aspell unicode l10n_en
app-shells/atuin server system-sqlite
sys-apps/rng-tools jitterentropy
gnome-base/gvfs keyring
x11-terms/kitty -X wayland
app-office/obsidian appindicator
app-text/papers djvu gnome-keyring nautilus
app-editors/neovim lua_single_target_luajit
app-text/enchant aspell nuspell voikko
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

`nvim /etc/portage/package.accept_keywords`

```bash
##/etc/portage/package.accept_keywords
=gui-apps/noctalia-shell-9999 ** ~amd64
=gui-apps/noctalia-qs-9999 ** ~amd64
app-admin/bitwarden-desktop-bin ~amd64
app-admin/sysstat ~amd64
app-arch/7zip ~amd64
app-arch/unzip ~amd64
app-arch/unrar ~amd64
app-arch/zip ~amd64
app-backup/btrfs-assistant ~amd64
app-backup/snapper ~amd64
app-backup/snapper-gui ~amd64
app-containers/* ~amd64
app-containers/distrobox ~amd64
app-containers/docker ~amd64
app-containers/docker-cli ~amd64
app-containers/docker-compose ~amd64
app-containers/docker-credential-helpers ~amd64
app-containers/lxc ~amd64
app-containers/lxd ~amd64
app-containers/podman ~amd64
app-containers/podman-compose ~amd64
app-containers/podman-tui ~amd64
app-containers/pods ~amd64
dev-cpp/sdbus-c++ ~amd64
app-crypt/johntheripper ~amd64
app-editors/emacs ~amd64
app-editors/neovim ~amd64
app-emacs/* ~amd64
app-emacs/all-the-icons ~amd64
app-emacs/emacs-common ~amd64
app-emacs/nerd-icons ~amd64
app-emacs/nerd-icons-corfu ~amd64
app-emacs/org-mode ~amd64
app-eselect/eselect-repository ~amd64
app-forensics/aide ~amd64
app-forensics/lynis ~amd64
app-misc/brightnessctl ~amd64
app-misc/yazi ~amd64
app-office/obsidian ~amd64
app-portage/gemato ~amd64
app-portage/gentoolkit ~amd64
app-portage/smart-live-rebuild ~amd64
app-shells/fzf ~amd64
app-shells/fzf-tab ~amd64
app-shells/gentoo-zsh-completions ~amd64
app-shells/gitstatus ~amd64
app-shells/zoxide ~amd64
app-shells/zsh ~amd64
app-text/fzy ~amd64
app-text/texlab ~amd64
app-text/xournalpp ~amd64
app-text/zathura ~amd64
app-text/zathura-meta ~amd64
app-text/zotero-bin ~amd64
dev-build/meson ~amd64
dev-lang/sassc ~amd64
dev-lang/typescript ~amd64
dev-libs/girara ~amd64
dev-libs/libutf8proc ~amd64
dev-libs/mmtf-cpp ~amd64
dev-libs/nss ~amd64
dev-libs/tree-sitter ~amd64
dev-libs/tree-sitter-lua ~amd64
dev-libs/tree-sitter-markdown ~amd64
dev-libs/tree-sitter-query ~amd64
dev-libs/tree-sitter-vim ~amd64
dev-libs/unibilium ~amd64
dev-libs/wayland-protocols ~amd64
dev-lua/luv ~amd64
dev-python/* ~amd64
dev-python/black ~amd64
dev-python/gpep517 ~amd64
dev-python/isort ~amd64
dev-python/matplotlib ~amd64
dev-python/pandas ~amd64
dev-python/pipx ~amd64
dev-python/python-pam ~amd64
dev-python/pynvim ~amd64
dev-python/scipy ~amd64
dev-python/userpath ~amd64
dev-util/dart-sass ~amd64
dev-util/git-delta ~amd64
dev-util/lua-language-server ~amd64
dev-util/pkgdev ~amd64
dev-util/glslang ~amd64
dev-util/tree-sitter-cli ~amd64
dev-util/spirv-headers ~amd64
dev-util/spirv-tools ~amd64
dev-util/vulkan-headers ~amd64
dev-util/vulkan-tools ~amd64
dev-util/vulkan-utility-libraries ~amd64
dev-vcs/git ~amd64
dev-vcs/lazygit ~amd64
dev-vcs/git-lfs ~amd64
dev-tex/texlab ~amd64
gui-apps/anyrun ~amd64
gui-apps/alacritty-graphics ~amd64
gui-apps/foot ~amd64
gui-apps/foot-terminfo ~amd64
gui-apps/grim ~amd64
gui-apps/qt6ct ~amd64
gui-apps/rofi-wayland ~amd64
gui-apps/slurp ~amd64
gui-apps/tuigreet ~amd64
gui-apps/wf-recorder ~amd64
gui-apps/wl-clipboard ~amd64
gui-libs/egl-gbm
gui-libs/egl-x11
gui-libs/egl-wayland ~amd64
gui-libs/greetd ~amd64
gui-libs/gtk ~amd64
gui-libs/libadwaita ~amd64
gui-libs/wlroots ~amd64
media-fonts/jetbrains-mono ~amd64
media-fonts/ubuntu-font-family ~amd64
media-fonts/nerdfonts ~amd64
media-gfx/maim ~amd64
media-libs/fcft ~amd64
media-libs/gst-plugins-bad ~amd64
media-libs/gst-plugins-base ~amd64
media-libs/gst-plugins-good ~amd64
media-libs/gst-plugins-ugly ~amd64
media-libs/mesa ~amd64
media-libs/nvidia-vaapi-driver ~amd64
media-libs/libpulse ~amd64
media-libs/vulkan-layers ~amd64
media-libs/vulkan-loader ~amd64
media-plugins/gst-plugins-meta  ~amd64
media-plugins/gst-plugins-oss ~amd64
media-sound/spotify ~amd64
media-video/ffmpeg ~amd64
media-video/mpv ~amd64
media-video/pipewire ~amd64
media-video/wireplumber ~amd64
net-analyzer/nmap ~amd64
net-analyzer/wireshark ~amd64
net-firewall/firewalld ~amd64
net-im/discord ~amd64
net-im/zoom ~amd64
net-misc/curl ~amd64
net-misc/dhcpcd ~amd64
net-misc/dhcpcd-ui ~amd64
net-misc/dropbox ~amd64
net-misc/wget ~amd64
net-wireless/aircrack-ng ~amd64
net-wireless/wpa_supplicant ~amd64
sci-biology/biopython ~amd64
sci-chemistry/pymol ~amd64
sec-keys/* ~amd64
sec-policy/apparmor-profiles ~amd64
sys-apps/apparmor ~amd64
sys-apps/apparmor-utils ~amd64
sys-apps/bat ~amd64
sys-apps/eza ~amd64
sys-apps/fd ~amd64
sys-apps/fwupd ~amd64
sys-apps/grep ~amd64
sys-apps/haveged ~amd64
sys-apps/mlocate ~amd64
sys-apps/ripgrep ~amd64
sys-apps/rng-tools ~amd64
sys-apps/portage ~amd64
sys-apps/systemd ~amd64
sys-apps/zram-generator ~amd64
sys-auth/seatd ~amd64
sys-firmware/sof-firmware ~amd64
sys-fs/btrfs-progs ~amd64
sys-fs/dosfstools ~amd64
sys-kernel/cachyos-sources ~amd64
sys-kernel/dracut ~amd64
sys-kernel/installkernel ~amd64
sys-kernel/linux-firmware ~amd64
sys-kernel/linux-headers ~amd64
sys-kernel/modprobed-db ~amd64
sys-libs/libapparmor ~amd64
sys-power/upower ~amd64
sys-process/acct ~amd64
sys-process/audit ~amd64
sys-process/bottom ~amd64
sys-process/btop ~amd64
sys-process/nvtop ~amd64
x11-base/xwayland ~amd64
x11-drivers/nvidia-drivers ~amd64
x11-drivers/xf86-video-amdgpu ~amd64
x11-libs/libnotify ~amd64
x11-misc/qt5ct ~amd64
x11-themes/kvantum ~amd64
xfce-base/thunar ~amd64
xfce-base/thunar-volman ~amd64
xfce-base/tumbler ~amd64
xfce-extra/thunar-archive-plugin ~amd64
xfce-extra/thunar-media-tags-plugin ~amd64
www-apps/element ~amd64
www-apps/beef ~amd64
www-client/zen-browser ~amd64
www-client/firefox ~amd64
#gnome-base/gvfs ~amd64
#sys-fs/genfstab ~amd64
#sys-fs/cryptsetup ~amd64
#sys-apps/file ~amd64
#net-misc/networkmanager ~amd64
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

### 6.3 — Portage and Its REPOS 

```bash
emerge -aq --jobs=5 app-eselect/eselect-repository dev-vcs/git app-admin/sudo && eselect repository remove gentoo && eselect repository add gentoo git https://github.com/gentoo-mirror/gentoo.git  && emaint sync -r gentoo && eselect repository enable guru hyproverlay CachyOS-kernels xarblu-overlay && eselect repository create custom && emerge --sync
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

## Section 5.6 — Set Root Password and Create Administrative User


```bash
passwd root

# Lock the root account: prevents all direct root login via console,SSH (already disabled), su, or display manager, while retaining the ability to use sudo.
passwd -l root

# Create the administrative user “ahsan” that will be used for all
# daily work.  Groups:
#   wheel  – sudo access
#   audio  – sound device nodes
#   video  – GPU access (including nvidia)
#   tss    – TPM access (required for tpm2‑pkcs11 SSH keys)
useradd -m -G users,wheel,audio,video,tss -s /bin/bash ahsan
passwd ahsan
EDITOR=nvim visudo
```

> **Why lock root?**  
> A locked root account cannot be logged into interactively, which eliminates the most valuable authentication target on the system.  The `passwd -l` command prepends a `!` to the password hash; the password still exists for emergency use (e.g., rescue shell) but direct login is refused.  The `ahsan` user obtains admin privileges via `sudo`.

> **Chroot recovery with a locked root account**  
> If you need to re‑enter the installed system from a live USB (Part 28), you become root on the live environment and `chroot` without needing the installed system’s root password.  Inside the chroot the root account is still locked, but you can temporarily unlock it:  

> ```bash
> passwd -u root
> # ... perform recovery tasks as root ...
> passwd -l root    # re-lock when done
> ```  
> Alternatively, become root via `sudo -i` from the `ahsan` account if it is still accessible.  The locked root account does not hinder offline recovery.

---
## Section 5.7 — Rebuild gcc and then @world

```bash
emerge gcc && emerge -ev @world

```


## Part 7 — Kernel: CachyOS-Sources with Clang + kCFI

### 7.1 — Install Kernel Sources and Required Packages
[NOTE:] All ananicy packages must be installed from xarblu-overlay
[NOTE:] Mask ananicy-cpp from mask from CachyOS-kernels, guru

```bash
# Install the kernel sources, firmware, and sbctl for Secure Boot signing. sbctl must be emerged BEFORE the kernel build so that signing keys exist when dracut generates the first UKI.
emerge --ask sys-kernel/cachyos-sources sys-kernel/linux-firmware app-crypt/sbctl sys-firmware/intel-microcode sys-fs/btrfs-progs sys-auth/cachyos-ananicy-rules sys-auth/ananicy-cpp
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

## Part 7B — NVIDIA Driver Setup

This section covers the installation and configuration of the proprietary NVIDIA driver stack, ensuring it is compatible with Secure Boot, the Wayland compositor, and the system's hardening measures.

### 7B.1 — Kernel Configuration for NVIDIA

The cachyos-sources `.config` already enables most of the required options, but verify the following with `make menuconfig` before building the kernel:

```
Bus options (PCI etc.) --->
  [*] PCI Express support
  [*] VGA Arbitration                                   CONFIG_VGA_ARB

Device Drivers --->
  Graphics support --->
    <*/M> Direct Rendering Manager (XFree86 …)          CONFIG_DRM
    [*]   Enable legacy fbdev support for your …        CONFIG_DRM_FBDEV_EMULATION
    < >   Nouveau (NVIDIA) cards                        CONFIG_DRM_NOUVEAU

  Firmware Drivers --->
    [*] Mark VGA/VBE/EFI FB as generic system …         CONFIG_SYSFB_SIMPLEFB
```

*   `CONFIG_DRM_FBDEV_EMULATION` is essential for `nvidia-drm` to provide a framebuffer console.
*   `CONFIG_VGA_ARB` ensures correct handoff between multiple GPU drivers (e.g., `simpledrm` and `nvidia-drm`) at boot.

### 7B.2 — Kernel Command Line and Modesetting

For NVIDIA driver versions 560 and later, modesetting is enabled by default for Wayland. No additional kernel command-line parameters are required. The driver will automatically set `modeset=1` and `fbdev=1`. This behavior is confirmed by the Arch Linux wiki and the official NVIDIA documentation for the 580 series.

### 7B.3 — USE Flags

The relevant USE flags for `x11-drivers/nvidia-drivers` are evaluated for this specific desktop setup (RTX 2080 Ti). The key flags are `kernel-open` and `modules-sign`.

*   **`kernel-open`**: This flag is enabled by default and uses the open-source kernel modules. It is recommended for Turing (RTX 20-series) and newer GPUs, and is mandatory for the NVIDIA 50-series "Blackwell" GPUs.
*   **`modules-sign`**: This flag is critical for Secure Boot. Its role is elaborated in section 7B.4.
*   **`persistenced`**: Enables the `nvidia-persistenced` daemon, which is useful for keeping the GPU state initialized, reducing latency for CUDA applications.
*   **`powerd`**: This flag is **not needed** for desktops. It is specifically for laptops with NVIDIA Dynamic Boost technology. The Gentoo package description explicitly states it is "only useful with specific laptops, ignore if unsure".

Configure the necessary flags. If you already have an entry for `x11-drivers/nvidia-drivers` in your file, merge the flags to avoid duplication.

```bash
# /etc/portage/package.use/nvidia
x11-drivers/nvidia-drivers modules-sign persistenced
```

### 7B.4 — Secure Boot and Module Signing

Since this system uses Secure Boot with custom keys, all kernel modules must be signed to load. The `modules-sign` USE flag automates this process in Gentoo, leveraging the same keys used for the kernel and UKI.

1.  **Ensure Keys Exist**: The `sbctl` keys must exist. If you followed Part 9, they are at `/var/lib/sbctl/keys/db/db.key` and `/var/lib/sbctl/keys/db/db.pem`.
2.  **Module Signing in `make.conf`**: Add the following to `/etc/portage/make.conf` to tell Portage where the signing keys are. These variables are used by the `modules-sign` eclass.

    ```bash
    # /etc/portage/make.conf
    MODULES_SIGN_KEY="/var/lib/sbctl/keys/db/db.key"
    MODULES_SIGN_CERT="/var/lib/sbctl/keys/db/db.pem"
    ```

3.  **Kernel Configuration**: Ensure `CONFIG_MODULE_SIG=y` is set in the kernel. This is usually already enabled by cachyos-sources.
4.  **Verification**: After installing the driver, verify the modules are signed.

    ```bash
    modinfo nvidia | grep '^sig_key'
    ```
    Running `modinfo nvidia` should show a signature key, confirming the module has been signed. The output should include the signer and key fingerprint, indicating the module's integrity is protected.

### 7B.5 — Install the Driver

```bash
emerge --ask x11-drivers/nvidia-drivers
```

After the emerge completes, verify the key components:

```bash
# Check that modules are present
modinfo nvidia nvidia-modeset nvidia-uvm nvidia-drm

# Verify that the modules are signed
modinfo nvidia | grep -E 'sig_|signer'
# Expected output should show a signer and signature info, not be empty.
```

### 7B.6 — Module Parameters and Blacklisting

Create the main NVIDIA module configuration file:

```bash
cat > /etc/modprobe.d/nvidia.conf << 'EOF'
# Maintained by: Hardened Gentoo Setup Guide
# Enable kernel mode setting (required for Wayland)
options nvidia-drm modeset=1
# Use the Page Attribute Table for memory allocation (performance)
options nvidia NVreg_UsePageAttributeTable=1
# Preserve video memory allocations across suspend/resume
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/tmp
EOF
```

As noted in 7B.2, `modeset=1` is the default for newer drivers. The explicit option is kept as a precaution for older branches and serves as a clear document of the requirement.

Prevent the open-source `nouveau` driver from binding to the GPU:

```bash
cat > /etc/modprobe.d/blacklist-nouveau.conf << 'EOF'
# Prevent the nouveau driver from binding to NVIDIA GPUs
install nouveau /bin/true
blacklist nouveau
EOF
```

### 7B.7 — TPM and NVIDIA

The TPM is used primarily for boot-time integrity verification (PCR sealing of the LUKS key) and for SSH key storage. There is no direct integration between the TPM and the NVIDIA driver. The driver's operation is unaffected by the TPM, and it does not interact with the TPM for functionality. Its security on this system is ensured through module signing (Secure Boot) and confinement via AppArmor.

### 7B.8 — Enable Services

```bash
# Persistence daemon – keeps GPU state alive (reduces initialization latency)
systemctl enable nvidia-persistenced.service
```

### 7B.9 — Rebuild the Initramfs and UKI

The NVIDIA kernel modules must be included in the initramfs to load early enough for a graphical boot and Wayland.

```bash
KVER=$(ls /lib/modules/ | sort -V | tail -1)
dracut --force --verbose /efi/EFI/Linux/gentoo-${KVER}.efi ${KVER}
```

Verify the NVIDIA modules are embedded:

```bash
lsinitrd /efi/EFI/Linux/gentoo-${KVER}.efi | grep -E "nvidia"
```

Re-sign the new UKI:

```bash
sbctl sign -s /efi/EFI/Linux/gentoo-${KVER}.efi
```

---

### 7B.10 — AppArmor Integration for NVIDIA

The `apparmor.d` project includes an `abstractions/nvidia` file that can be used to mediate access to NVIDIA device files and libraries. This abstraction defines rules for common NVIDIA resources, including device nodes (`/dev/nvidia*`), library paths, and shared memory. To integrate it into your security policy, `#include <abstractions/nvidia>` to the profiles of any application that requires GPU access.

1.  **Identify Profiles**: Start with applications that have existing AppArmor profiles, such as Firefox (in complain mode) or your display manager (SDDM).
2.  **Add the Abstraction**: Edit the relevant profile in `/etc/apparmor.d/`. For example, to allow SDDM to manage the display, add the include line to its profile:

    ```bash
    # In /etc/apparmor.d/usr.sbin.sddm
    profile sddm /usr/bin/sddm {
      # ... existing rules ...
      #include <abstractions/nvidia>
      # ...
    }
    ```

3.  **Test**: After making changes, run your system in complain mode for these profiles and monitor the AppArmor logs (`aa-logprof`) to identify any additional rules needed.

### 7B.11 — Hardening `nvidia-persistenced` with `svc-harden.py`

The `nvidia-persistenced` service can be hardened using `svc-harden.py`, as referenced in Part 23 of the main guide. The script applies security directives such as `NoNewPrivileges`, `ProtectSystem=strict`, and `MemoryDenyWriteExecute` to reduce the attack surface of the service.

After ensuring the service runs correctly in its default configuration, apply the hardening:

```bash
# Analyze the current security posture
svc-harden.py analyze nvidia-persistenced.service

# Apply hardening directives interactively
svc-harden.py apply nvidia-persistenced.service
```

During the `apply` process, you can enable directives such as `ProtectSystem=strict` and `PrivateTmp=true`. It is important to test the GPU's functionality after applying each directive to ensure it does not interfere with driver operations.

---

### 7B.12 — Post-Install Verification

After the first successful boot:

```bash
# 1. Verify the NVIDIA kernel module is loaded and signed
lsmod | grep nvidia
# Expected output should include: nvidia_drm, nvidia_modeset, nvidia_uvm, nvidia

# 2. Check DRM KMS is active
cat /sys/module/nvidia_drm/parameters/modeset
# Should print: Y

# 3. Verify GPU status
nvidia-smi
```

If `nvidia-smi` reports the GPU and driver version, the setup is complete.


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
# Install snapper (can be done after first boot)
emerge --ask app-backup/snapper

# Create root config — auto-generates /etc/snapper/configs/root
# (the default values are fine; no manual editing is required)
snapper --no-dbus -c root create-config /

# create-config creates its own .snapshots subvolume.
# Replace it with the pre-created @/.snapshots that is already in fstab.
umount /.snapshots 2>/dev/null
rm -rf /.snapshots
btrfs subvolume delete /.snapshots 2>/dev/null
mkdir /.snapshots
mount -a
chmod 750 /.snapshots

# Enable periodic snapshot timers
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer
systemctl enable snapper-boot.timer
```

### Portage Hooks for Pre/Post Snapshots

```bash
# Append the snapper pre/post hooks to /etc/portage/bashrc.
# (tee -a preserves any existing bashrc content.)
cat >> /etc/portage/bashrc << 'BASHRC'

# --- Snapper pre/post emerge snapshots ---
# Portage automatically calls pre_pkg_preinst() before the pkg_preinst
# phase and post_pkg_postinst() after pkg_postinst.
# Each call is per-package — a multi-package emerge therefore creates
# one pre/post pair per package.  The number-based cleanup policy in
# /etc/snapper/configs/root prevents unlimited growth.

pre_pkg_preinst() {
    if command -v snapper &>/dev/null; then
        SNAPPER_PRE_NUM=$(snapper -c root create \
            --type pre --print-number --cleanup-algorithm number \
            --description "portage pre: ${CATEGORY}/${PF}" 2>/dev/null)
        export SNAPPER_PRE_NUM
    fi
}

post_pkg_postinst() {
    # Called per-package after each pkg_postinst phase.
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

### 14.1 — Installation and Kernel Setup

AppArmor is a Mandatory Access Control (MAC) system implemented upon LSM (Linux Security Modules). It is supported on Gentoo as a first‑class citizen.

#### Kernel Configuration

Ensure the following kernel options are enabled. The cachyos-sources `.config` sets most of these already; verify with `make menuconfig` in Part 7:

```
General setup --->
  [*] Auditing support
Security options --->
  [*] Enable the securityfs filesystem
  [*] Socket and Networking Security Hooks
  [*] Enable different security models
  [*] AppArmor support
  [*] Enable introspection of sha1 hashes for loaded profiles
  [*] Enable policy hash introspection by default
  First legacy 'major LSM' to be initialized (AppArmor) --->
  Ordered List of enabled LSMs: "yama,apparmor"
```

The `CONFIG_LSM="yama,apparmor"` string is the Gentoo‑recommended approach and makes the Arch‑style `lsm=` kernel command‑line parameter unnecessary.

#### Boot Parameters (Already in UKI cmdline)

```
apparmor=1 security=apparmor
```

These are already embedded in the UKI cmdline (Part 8). No `lsm=` parameter is needed or should be added.

#### Install Userspace Tools

```bash
emerge --ask sys-apps/apparmor sys-apps/apparmor-utils
emerge --ask sec-policy/apparmor-profiles

# Enable AppArmor service
systemctl enable apparmor.service
```

`sec-policy/apparmor-profiles` provides the default abstractions shipped by upstream; it is a dependency required by apparmor.d.

---

### 14.2 — AppArmor Parser Configuration

With ~1500 profiles totaling ~100 000 lines, fast caching compression is recommended. Early policy load is also required for UKI‑based systems.

```bash
echo 'write-cache' | tee -a /etc/apparmor/parser.conf
echo 'cache-loc /etc/apparmor/earlypolicy/' | tee -a /etc/apparmor/parser.conf
echo 'Optimize=compress-fast' | tee -a /etc/apparmor/parser.conf
echo 'early_policy=yes' | tee -a /etc/apparmor/parser.conf
```

> **UKI note**: `early_policy=yes` requires the `apparmor` dracut module. Add `apparmor` to the `add_dracutmodules+=` line in `/etc/dracut.conf.d/00-base.conf`:
>
> ```bash
> add_dracutmodules+=" tpm2-tss crypt lvm btrfs systemd systemd-initrd apparmor "
> ```

---

### 14.3 — apparmor.d Integration

The `apparmor.d` project provides a set of over 1500 AppArmor profiles aiming to confine most Linux‑based applications and processes. It confines all root processes such as all systemd tools, bluetooth, dbus, polkit, NetworkManager, OpenVPN, GDM, rtkit, and colord.

#### Installation

The project is not yet packaged in Gentoo's main repository. Install it manually from source:

```bash
# Install build dependencies. The apparmor.d build uses either
# 'make' (GNU Make) or 'just' (a modern command runner).
# The Makefile is the primary build system; 'just' is optional
# and not required for a basic install.
emerge --ask dev-build/just

# Clone the repository
git clone https://github.com/roddhjav/apparmor.d.git
cd apparmor.d

# Verify the commit signature
git log --show-signature -1

# Build — the default target installs all profiles in COMPLAIN MODE.
# This is deliberate: it lets you test the profiles for a week
# before switching to enforce, as recommended by the project.
make
sudo make install
```

> **Installation philosophy**: The project strongly recommends installing in complain mode first, checking logs for a week, and only then switching to enforce mode. This prevents a broken system on initial installation.

---

### 14.4 — Configure Personal Directories

The profiles heavily use the XDG directory variables. All the variables are lists you can append. This part is vital; failure to configure it correctly will cause breakage.

The apparmor.d project installs tunables in `/etc/apparmor.d/tunables/home.d/`. On Ubuntu the file is named `ubuntu`; on Gentoo the project may not create a distribution‑specific file. Review what was installed:

```bash
ls /etc/apparmor.d/tunables/home.d/
```

If no Gentoo‑specific file exists, create your own:

```bash
cat > /etc/apparmor.d/tunables/home.d/gentoo << 'EOF'
# Gentoo-specific XDG directory overrides.
# Append additional paths to the default variables.
# Default values are defined in /etc/apparmor.d/tunables/home.

@{XDG_DESKTOP_DIR}+="Desktop"
@{XDG_DOCUMENTS_DIR}+="Documents"
@{XDG_DOWNLOAD_DIR}+="Downloads"
@{XDG_MUSIC_DIR}+="Music"
@{XDG_PICTURES_DIR}+="Pictures"
@{XDG_VIDEOS_DIR}+="Videos"
@{XDG_PROJECTS_DIR}+="Projects"
EOF
```

Key XDG variables and their defaults (defined in `/etc/apparmor.d/tunables/home`):

| Variable | Default |
|---|---|
| `@{XDG_DESKTOP_DIR}` | `Desktop` |
| `@{XDG_DOCUMENTS_DIR}` | `Documents` |
| `@{XDG_DOWNLOAD_DIR}` | `Downloads` |
| `@{XDG_MUSIC_DIR}` | `Music` |
| `@{XDG_PICTURES_DIR}` | `Pictures` |
| `@{XDG_VIDEOS_DIR}` | `Videos` |
| `@{XDG_PROJECTS_DIR}` | `Projects` |
| `@{XDG_CACHE_DIR}` | `.cache` |
| `@{XDG_CONFIG_DIR}` | `.config` |
| `@{XDG_DATA_DIR}` | `.local/share` |
| `@{XDG_STATE_DIR}` | `.local/state` |
| `@{XDG_BIN_DIR}` | `.local/bin` |

If your home directory layout differs (e.g., `~/dev` for projects, `~/media` for music), append your paths to the corresponding variables here.

---

### 14.5 — Testing in Complain Mode and Switching to Enforce

After installation, follow this workflow:

1. **Reboot** with all profiles in complain mode.
2. **Check** AppArmor logs daily:
   ```bash
   aa-log
   ```
3. **Run** in complain mode for at least a week.
4. **Report** any raised logs to the project.
5. **Only if no logs are raised** for your daily usage, switch to enforce mode.

```bash
cd apparmor.d
sudo make uninstall
make clean
make enforce
sudo make install
```

---

### 14.6 — Recommended Enforce/Complain Mode Assignments

**Enforce — these profiles are mature and stable:**

| Profile | Application | Rationale |
|---|---|---|
| `systemd` | systemd PID 1 | Extremely well‑tested |
| `systemd-journald` | Journal daemon | High‑value target |
| `systemd-logind` | Login session management | Stable profile |
| `NetworkManager` | Network management | Internet‑facing |
| `bluetoothd` | Bluetooth daemon | High attack surface |
| `dbus-system` | System D‑Bus | IPC broker |
| `dbus-session` | Session D‑Bus | User IPC |
| `polkit` | Policy kit | Privilege escalation broker |
| `sshd` | SSH daemon | Internet‑facing |
| `cups` | Print daemon | Legacy protocol attack surface |
| `avahi-daemon` | mDNS daemon | Network‑facing |
| `rtkit-daemon` | Real‑time scheduler | Privilege escalation vector |
| `colord` | Color management | D‑Bus accessible |
| `sddm` | Display manager | Authentication boundary |

**Complain mode — needs site‑specific tuning:**

| Profile | Reason |
|---|---|
| Firefox, Chromium | Rapidly evolving permissions |
| Electron apps | Vary per‑app |
| Code editors (VSCode, etc.) | Plugin system requires broad file access |
| Python, Node.js interpreters | Too broad to confine without per‑script profiles |
| Steam, Wine | Game executables have arbitrary permission requirements |
| Flatpak + bwrap | Conditional on usage |

---

### 14.7 — Handling Profile Conflicts

The `sec-policy/apparmor-profiles` package ships base profiles. apparmor.d ships 1500+ profiles covering the same namespace. When both are installed, apparmor.d profiles take precedence.

```bash
# Check for conflicts
find /etc/apparmor.d/ -maxdepth 1 -type f | while read f; do
    name=$(basename "$f")
    if ls /etc/apparmor.d/abstractions/ | grep -q "^${name}$" 2>/dev/null; then
        echo "Potential conflict: $f"
    fi
done

# Disable conflicting distro profiles
mkdir -p /etc/apparmor.d/disable
ln -sf /dev/null /etc/apparmor.d/disable/usr.sbin.sshd
```

---

### 14.8 — Local Override Files

For site‑specific adjustments that survive apparmor.d updates:

```bash
# Allow NetworkManager to access a site-specific VPN plugin
cat > /etc/apparmor.d/local/NetworkManager << 'EOF'
# Site-specific NetworkManager overrides
/etc/vpn/corporate/ r,
/etc/vpn/corporate/** r,
EOF

# Allow sshd to read a non-standard authorized_keys location
cat > /etc/apparmor.d/local/sshd << 'EOF'
# Site-specific sshd overrides
/etc/ssh/authorized_keys.d/ r,
/etc/ssh/authorized_keys.d/** r,
EOF

# Reload all profiles after changes
apparmor_parser -r /etc/apparmor.d/
```

---

### 14.9 — Verification

```bash
aa-status
# Expected:
#   apparmor module is loaded.
#   N profiles are loaded.
#   N profiles are in enforce mode.
#   N profiles are in complain mode.
#   N processes have profiles defined.
```

---

## Part 14B — Confining Development Tools and Editors with AppArmor

This section covers how to extend AppArmor confinement to editors, interpreters, build tools, and package managers within a development environment. It assumes the `apparmor.d` profile set has already been installed (Part 14) and provides practical, tested workflows.

### 14B.1 — Understanding the `apparmor.d` Confinement Model

The `apparmor.d` project ships over 1500 profiles with a clear design philosophy: **confine all core system processes and leave non‑core user applications to be sandboxed by other means**. Core processes include all `systemd` tools, `bluetooth`, `dbus`, `polkit`, `NetworkManager`, display managers, and desktop environment components. Non‑core user applications—web browsers, text editors, development tools—are generally out of scope for the project. This means you must build or supplement editor and developer‑tool confinement yourself.

### 14B.2 — Profile Availability for Development Tools

A systematic review of the `apparmor.d` repository as of April 2026 reveals the following coverage:

| Tool | Pre‑built Profile? | Location | Notes |
|------|--------------------|----------|-------|
| `git` | ✅ Yes | `apparmor.d/profiles-g-l/` | Mature profile; ready for enforce after testing |
| `gcc` | ✅ Yes | `apparmor.d/profiles-g-l/` | Covers the C compiler; C++ is handled by the same binary |
| `make` | ✅ Yes | `apparmor.d/profiles-m-r/` | Covers GNU Make; other build tools (ninja, cmake) are not profiled |
| `python3` | ✅ Yes | `apparmor.d/profiles-m-r/` | Confines the interpreter itself; see §14B.3 for scripting limitations |
| `npm` | ✅ Yes | `apparmor.d/profiles-m-r/` | Covers the Node.js package manager |
| `emacs` | ❌ No | — | Must be generated from scratch; see §14B.6 |
| `neovim` | ❌ No | — | Must be generated from scratch; see §14B.5 |
| `cargo` | ❌ No | — | Rust package manager is not yet profiled |
| `cmake` | ❌ No | — | Must be generated if needed |
| `ninja` | ❌ No | — | Must be generated if needed |

The profiles that do exist are installed in `/etc/apparmor.d` when you run `make install` from the `apparmor.d` source tree. Verify their presence:

```bash
ls /etc/apparmor.d/usr.bin.git
ls /etc/apparmor.d/usr.bin.make
ls /etc/apparmor.d/usr.bin.gcc
ls /etc/apparmor.d/usr.bin.python3*
ls /etc/apparmor.d/usr.bin.npm
```

### 14B.3 — The Interpreter Problem

This is the single most important technical limitation to understand before confining development tools. AppArmor attaches profiles to **executable files by path**. When you run `./script.sh` and that file has a profile at `/path/to/script.sh`, the profile attaches. When you run `python3 ./script.py`, AppArmor sees only the interpreter (`/usr/bin/python3`) being executed and attaches **its** profile—not any profile that may exist for the script file.

This has two consequences:
1. Confining `python3` globally affects every Python script on the system—including package managers, build scripts, and system services—and will almost certainly break functionality.
2. It is **not possible to provide a per‑script profile** when scripts are invoked through an interpreter.

The practical implication is that you should **not** enforce a broad `python3` profile on a development machine. The `apparmor.d` project ships a `python3` profile, but it should be used only in complain mode or not at all unless you are prepared to extensively customise it.

### 14B.4 — Workflow: Deploying Existing Profiles

For tools that _do_ have pre‑built profiles from `apparmor.d`, the deployment workflow is standard:

```bash
# 1. Set the profile to complain mode — it will log violations but not block anything
sudo aa-complain git
sudo aa-complain make
sudo aa-complain gcc
sudo aa-complain npm

# 2. Use the tools normally for at least one week. Exercise all common operations:
#    - git clone, push, pull, rebase
#    - make with various targets
#    - gcc across C and C++ compilation units
#    - npm install, npm run, npm test

# 3. After the testing period, scan the logs and interactively build allow rules
sudo aa-logprof
# aa-logprof will prompt you for each access violation and offer options
# (Allow, Deny, Glob, etc.). Answer based on your understanding of the tool.

# 4. Once aa-logprof reports no new violations, switch to enforce mode
sudo aa-enforce git
sudo aa-enforce make
sudo aa-enforce gcc
sudo aa-enforce npm
```

If a profile breaks your workflow after enforcement, switch it back to complain mode and re‑run `aa-logprof`:

```bash
sudo aa-complain git
# ... exercise the broken workflow ...
sudo aa-logprof
sudo aa-enforce git
```

### 14B.5 — Creating a Profile for Neovim

Neovim is the more straightforward editor to confine. Its runtime dependencies are relatively predictable, and it does not use the unusual bootstrap architecture Emacs does.

Neovim locates its runtime files under `/usr/share/nvim/runtime/` (system‑wide) and `~/.local/share/nvim/` (user plugins). LSP servers are launched as sub‑processes and must be allowed to execute.

```bash
# 1. Start profile generation
sudo aa-genprof /usr/bin/nvim

# 2. aa-genprof creates a minimal baseline profile using aa-autodep
#    and sets it to complain mode. It then prompts you to exercise the program.
#    Open a second terminal and run nvim through its normal workflows:
#    - Open and edit files in various directories (/etc, /home, /tmp)
#    - Install/update plugins (:Lazy sync)
#    - Use LSP features (completion, go-to-definition)
#    - Execute :terminal and run shell commands

# 3. Return to the first terminal. At the (S)can prompt, press Enter.
#    aa-genprof will iterate through violations using aa-logprof.
#    Answer each prompt. Common accesses include:
#    - /usr/share/nvim/runtime/** (read)
#    - ~/.local/share/nvim/** (read, write)
#    - ~/.config/nvim/** (read, write)
#    - ~/.cache/nvim/** (read, write)
#    - LSP server binaries (execute permissions for each server)

# 4. Repeat the (S)can cycle until no new violations appear.
#    Then press (F)inish. aa-genprof will switch the profile to enforce mode.
```

The generated profile lives at `/etc/apparmor.d/usr.bin.nvim`. After testing, you may want to add local overrides in `/etc/apparmor.d/local/usr.bin.nvim` to survive `apparmor.d` updates.

### 14B.6 — The Challenge of Confining Emacs

Emacs is significantly harder to confine than Neovim for several architectural reasons:

1. **Pre‑dump binary generation**: During the Gentoo build, a bare Emacs binary (`temacs`) is created, bootstrapped, and then dumped into the final `emacs` binary. This unique lifecycle means the binary on disk does not directly correspond to the running process in the way AppArmor expects.

2. **Extensive runtime dependencies**: Emacs can act as a mail client (`mu4e`, `notmuch`), a web browser (`eww`, `xwidget-webkit`), an image viewer and editor, a terminal emulator (`vterm`, `eat`), an IRC client, a file manager, and a development environment. A single profile that covers all these use cases is impossible to write generically.

3. **Native compilation**: Emacs 28+ can natively compile Elisp into shared libraries. This requires write access to the eln cache (`~/.emacs.d/eln-cache/`) and execution of compiled `.so` files, which AppArmor treats as code execution from a user directory.

4. **Sub‑process model**: Emacs spawns external tools extensively—`git`, `make`, `grep`, `find`, `aspell`, language servers, formatters—each of which may or may not have its own AppArmor profile. Stacking and nesting profiles correctly is challenging.

**Recommendation**: Rather than attempting AppArmor confinement, use a **dedicated sandbox** for Emacs when processing untrusted content:
* Run Emacs inside `bubblewrap` (`bwrap`) with a restricted view of the filesystem.
* Use `distrobox` or `podman` to isolate a development environment that includes Emacs.
* For MUA (mail) workflows, use the already‑profiled `thunderbird` or `evolution` instead of Emacs‑based mail clients.

### 14B.7 — Confining Language‑Specific Package Managers

Package managers are high‑value targets: they download untrusted code and execute it. The `apparmor.d` project profiles `npm` but not `cargo`, `pip`, or `go`. Where no profile exists, generate one:

```bash
# Example: generate a profile for cargo (Rust package manager)
sudo aa-genprof /usr/bin/cargo

# Exercise in a second terminal:
#   cargo new test-project && cd test-project
#   cargo build
#   cargo run
#   cargo test
#   cargo install some-crate
#   cargo update

# Then scan and finish as usual.
```

For `pip`, the interpreter problem (§14B.3) applies: `pip` is a Python script. If you confine `/usr/bin/python3`, every Python invocation is constrained. The safer approach is to use a dedicated virtual environment or container for Python development and confine the virtual environment's specific binaries rather than the system interpreter.

### 14B.8 — Sandboxing Untrusted Code with Bubblewrap

For one‑off scripts, experimental code, or debugging untrusted binaries, a full AppArmor profile is overkill. `bubblewrap` (`bwrap`) provides lightweight, ephemeral confinement using Linux namespaces:

```bash
# Install bubblewrap
emerge --ask sys-apps/bubblewrap

# Sandbox a command: network blocked, filesystem read-only, only cwd writable
bwrap \
  --ro-bind /usr /usr \
  --ro-bind /etc /etc \
  --ro-bind /lib64 /lib64 \
  --bind /tmp /tmp \
  --dev /dev \
  --proc /proc \
  --unshare-net \
  --unshare-pid \
  --die-with-parent \
  /bin/bash -c "cd $(pwd) && ./untrusted-binary"
```

`bwrapwrap` (a Python wrapper) simplifies this to a one‑liner:

```bash
pip install bwrapwrap
bwrapwrap ./untrusted-binary
```

### 14B.9 — Practical Integration into the Workflow

The tables below summarise the recommended approach for each category of development tool.

**Tools with existing `apparmor.d` profiles — deploy directly:**

| Tool | Command | Initial Mode |
|------|---------|-------------|
| `git` | `sudo aa-complain git` | complain → test → `aa-logprof` → enforce |
| `make` | `sudo aa-complain make` | complain → test → `aa-logprof` → enforce |
| `gcc` | `sudo aa-complain gcc` | complain → test → `aa-logprof` → enforce |
| `npm` | `sudo aa-complain npm` | complain → test → `aa-logprof` → enforce |

**Tools without profiles — generate first:**

| Tool | Command |
|------|---------|
| `neovim` | `sudo aa-genprof /usr/bin/nvim` |
| `cargo` | `sudo aa-genprof /usr/bin/cargo` |
| `cmake` | `sudo aa-genprof /usr/bin/cmake` |

**Tools where confinement is not recommended:**

| Tool | Reason | Alternative |
|------|--------|-------------|
| `python3` | Interpreter problem — affects all scripts | Use `bwrap`, containers, or virtual environments |
| `node` | Same interpreter problem | Use `npm` profile + per‑project `bwrap` |
| `emacs` | Architectural complexity | Use `bwrap`, `distrobox`, or `podman` |

### 14B.10 — Ongoing Maintenance

AppArmor profiles are not static. After each system update, re‑check logs:

```bash
# After a major Portage upgrade:
sudo aa-logprof

# If a tool has been updated (new features, new paths), re‑run aa-logprof
# for that specific tool:
sudo aa-logprof -d /etc/apparmor.d/ /usr/bin/git
```

For profiles you generated yourself, periodically review the local override files in `/etc/apparmor.d/local/`. The `apparmor.d` project updates its upstream profiles regularly; your local overrides ensure your modifications survive those updates.


---

## Part 15 — Auditd Hardening

### 15.1 — Installation

Auditd records system‑call events and is required for AppArmor profile generation and security monitoring.

```bash
emerge --ask sys-process/audit

# Enable the auditd service
systemctl enable auditd.service
```

> **No separate `augenrules.service` exists on Gentoo.** Gentoo uses `/etc/conf.d/auditd` to control whether `augenrules` merges component rule files from `/etc/audit/rules.d/` into `/etc/audit/audit.rules` at startup. The default is `USE_AUGENRULES="no"`; we change it below to `"yes"`.

---

### 15.2 — Auditd Configuration

```bash
cat > /etc/audit/auditd.conf << 'EOF'
log_file = /var/log/audit/audit.log
log_format = ENRICHED
log_group = audit
priority_boost = 4
flush = INCREMENTAL_ASYNC
freq = 50
max_log_file = 50
num_logs = 20
space_left = 75
space_left_action = SYSLOG
admin_space_left = 50
admin_space_left_action = HALT
disk_full_action = HALT
disk_error_action = SYSLOG
max_log_file_action = KEEP_LOGS
name_format = HOSTNAME
EOF
```

---

### 15.3 — Audit Rules

Place custom rules in `/etc/audit/rules.d/`. Files must end with `.rules`. The `augenrules` program (enabled via `/etc/conf.d/auditd`) merges them into `/etc/audit/audit.rules` at service startup.

`nvim /etc/audit/rules.d/99-hardening.rules`


```bash
## ============================================================
## /etc/audit/rules.d/99-hardening.rules
## Gentoo Hardened — Auditd Ruleset — April 2026
## ============================================================

## --- Performance tuning ---
-b 8192
-f 1

## ============================================================
## SECTION 1: FILE INTEGRITY MONITORING
## ============================================================

-w /etc/ -p wa -k etc_changes

## Critical authentication configs
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity

## PAM configuration
-w /etc/pam.d/ -p wa -k pam_config
-w /etc/security/ -p wa -k security_config

## sudoers
-w /etc/sudoers -p wa -k sudoers_change
-w /etc/sudoers.d/ -p wa -k sudoers_change

## SSH server configuration
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /etc/ssh/sshd_config.d/ -p wa -k sshd_config

## System binaries and libraries
-w /usr/bin/ -p wa -k bin_change
-w /usr/sbin/ -p wa -k sbin_change
-w /usr/lib/ -p wa -k lib_change
-w /usr/lib64/ -p wa -k lib_change
-w /usr/local/bin/ -p wa -k local_bin_change
-w /usr/local/sbin/ -p wa -k local_sbin_change

## Boot files and ESP
-w /boot/ -p wa -k boot_change
-w /efi/ -p wa -k esp_change

## Home directory attribute changes
-w /home/ -p a -k home_attr_change
-w /root/ -p wa -k root_home_change

## AppArmor policy files
-w /etc/apparmor/ -p wa -k apparmor_policy
-w /etc/apparmor.d/ -p wa -k apparmor_policy

## systemd service files — detect persistence via service installation
-w /etc/systemd/ -p wa -k systemd_config
-w /usr/lib/systemd/ -p wa -k systemd_config

## ============================================================
## SECTION 2: PRIVILEGED COMMAND EXECUTION (setuid/setgid)
## ============================================================

-a always,exit -F arch=b64 -S execve -C uid!=euid -F euid=0 -k setuid_exec
-a always,exit -F arch=b64 -S execve -C gid!=egid -F egid=0 -k setgid_exec

-a always,exit -F path=/usr/bin/sudo -F perm=x -k sudo_exec
-a always,exit -F path=/usr/bin/su -F perm=x -k su_exec
-a always,exit -F path=/usr/bin/newgrp -F perm=x -k newgrp_exec
-a always,exit -F path=/usr/bin/chsh -F perm=x -k chsh_exec
-a always,exit -F path=/usr/bin/chfn -F perm=x -k chfn_exec
-a always,exit -F path=/usr/bin/passwd -F perm=x -k passwd_change_exec
-a always,exit -F path=/usr/bin/gpasswd -F perm=x -k passwd_change_exec
-a always,exit -F path=/usr/bin/chage -F perm=x -k user_mgmt_exec
-a always,exit -F path=/usr/sbin/usermod -F perm=x -k user_mgmt_exec
-a always,exit -F path=/usr/sbin/useradd -F perm=x -k user_mgmt_exec
-a always,exit -F path=/usr/sbin/userdel -F perm=x -k user_mgmt_exec
-a always,exit -F path=/usr/sbin/groupmod -F perm=x -k user_mgmt_exec
-a always,exit -F path=/usr/sbin/groupadd -F perm=x -k user_mgmt_exec
-a always,exit -F path=/usr/sbin/groupdel -F perm=x -k user_mgmt_exec

## ============================================================
## SECTION 3: AUTHENTICATION AND SESSION EVENTS
## ============================================================

-w /var/log/wtmp -p wa -k login_logout
-w /var/log/btmp -p wa -k failed_login
-w /run/utmp -p wa -k session_tracking

-w /root/.ssh/ -p wa -k root_ssh
-w /home/ -p wa -k user_ssh

-a always,exit -F arch=b64 -S execve -F path=/usr/bin/sudo -k sudo_cmd
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/su -k su_cmd

## ============================================================
## SECTION 4: NETWORK SOCKET CREATION
## ============================================================

-a always,exit -F arch=b64 -S socket -F a0=2 -F auid>=1000 -F auid!=4294967295 -k socket_ipv4
-a always,exit -F arch=b64 -S socket -F a0=10 -F auid>=1000 -F auid!=4294967295 -k socket_ipv6
-a always,exit -F arch=b64 -S socket -F a0=1 -F auid>=1000 -F auid!=4294967295 -k socket_unix
-a always,exit -F arch=b64 -S connect -F auid>=1000 -F auid!=4294967295 -k network_connect

## ============================================================
## SECTION 5: KERNEL MODULE LOADING/UNLOADING
## ============================================================

-a always,exit -F arch=b64 -S init_module -S finit_module -k module_load
-a always,exit -F arch=b64 -S delete_module -k module_unload
-w /usr/bin/kmod -p x -k kmod_exec
-w /usr/sbin/modprobe -p x -k kmod_exec

-w /etc/modprobe.d/ -p wa -k modprobe_config

## ============================================================
## SECTION 6: USER, GROUP, AND PERMISSION MANAGEMENT
## ============================================================

-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -k perm_change
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -k owner_change
-a always,exit -F arch=b64 -S setuid -S setgid -S setreuid -S setregid -k setuid_syscall
-a always,exit -F arch=b64 -S setresuid -S setresgid -k setuid_syscall

## ============================================================
## SECTION 7: PACKAGE MANAGER ACTIVITY (Portage)
## ============================================================

-a always,exit -F arch=b64 -S execve -F path=/usr/bin/emerge -k emerge_exec

-w /var/db/repos/gentoo/ -p wa -k portage_db_change
-w /etc/portage/ -p wa -k portage_config
-w /var/cache/distfiles/ -p wa -k distfiles_change

-a always,exit -F arch=b64 -S execve -F path=/usr/bin/ebuild -k ebuild_exec

-w /etc/portage/env/ -p wa -k portage_env_change
-w /etc/portage/package.use/ -p wa -k package_use_change

## ============================================================
## SECTION 8: ADDITIONAL HIGH-VALUE RULES
## ============================================================

-w /proc/sysrq-trigger -p w -k sysrq
-w /proc/sys/kernel/ -p w -k kernel_param_change

-a always,exit -F arch=b64 -S sysctl -k sysctl_change

-a always,exit -F arch=b64 -S adjtimex -S settimeofday -S clock_settime -k time_change
-w /etc/localtime -p wa -k timezone_change

-a always,exit -F arch=b64 -S capset -F auid>=1000 -k capabilities_set

-w /dev/mem -p rwxa -k memory_dev_access
-w /dev/kmem -p rwxa -k memory_dev_access

-a always,exit -F arch=b64 -S mount -S umount2 -F auid>=1000 -k mount_ops

-a always,exit -F arch=b64 -S ptrace -k ptrace_use

## ============================================================
## LOCK RULES (uncomment after thorough testing)
## ============================================================
-e 2
```

---

### 15.4 — Enable augenrules and Load Rules

```bash
# Enable augenrules to merge component rules from /etc/audit/rules.d/
sed -i 's/USE_AUGENRULES="no"/USE_AUGENRULES="yes"/' /etc/conf.d/auditd

# Restart auditd; augenrules runs automatically at startup
systemctl restart auditd

# Verify rules are loaded
auditctl -l | wc -l
```

> **Locking rules**: After thorough testing (at least one full boot cycle with all services running), uncomment the `-e 2` line at the end of the rules file. This makes the ruleset immutable until next reboot, preventing unauthorized modification of audit rules at runtime.

---

### 15.5 — Log Correlation

AppArmor denial events appear in the audit log with:

```
type=AVC msg=audit(...): apparmor="DENIED" operation="..." profile="..."
```

Our auditd rules produce events with `type=SYSCALL` or `type=PATH` plus a key tag. Both types coexist without collision.

```bash
# Find AppArmor policy file modifications
ausearch -k apparmor_policy

# Find AppArmor denials
journalctl -t audit | grep 'apparmor="DENIED"'

# Find kernel module loads
ausearch -k module_load
```

---

## Part 16 — Kernel Module Blacklisting

`mkdir -p /etc/modprobe.d/ && nvim /etc/modprobe.d/blacklist-hardening.conf`

```bash
## Unused / Attack‑Surface Filesystems
##############################################################

# cramfs — compressed ROM filesystem; has known vulnerabilities
install cramfs /bin/true
blacklist cramfs

# freevxfs — Veritas VxFS; no legitimate use on modern Linux workstations
install freevxfs /bin/true
blacklist freevxfs

# jffs2 — Journaling Flash File System; multiple CVEs in 2025
# (CVE‑2025‑38194, CVE‑2025‑38328)
install jffs2 /bin/true
blacklist jffs2

# hfs — original Mac filesystem (pre‑HFS+); no modern use
install hfs /bin/true
blacklist hfs

# hfsplus — HFS+ (modern Mac filesystem); attack surface, rarely needed
# EXCEPTION: comment out if you connect macOS‑formatted drives
install hfsplus /bin/true
blacklist hfsplus

# squashfs — Read‑only compressed filesystem
# ACTIVELY EXPLOITED in 2025–2026 (CVE‑2025‑38415, CVE‑2025‑40049,
# CVE‑2025‑40200).  OVERLAYFS and container runtimes sometimes
# depend on squashfs.  If you use Flatpak, snap, AppImage, or Docker,
# comment out the two lines below:
install squashfs /bin/true
blacklist squashfs

# udf — DVD/Blu‑ray filesystem; attack surface
install udf /bin/true
blacklist udf

## Unused Network Protocols
##############################################################

# Datagram Congestion Control Protocol
install dccp /bin/true
blacklist dccp

# Stream Control Transmission Protocol
install sctp /bin/true
blacklist sctp

# Reliable Datagram Sockets
install rds /bin/true
blacklist rds

# Transparent Inter‑Process Communication
install tipc /bin/true
blacklist tipc

# Amateur radio / legacy serial protocols
install ax25 /bin/true
blacklist ax25

install netrom /bin/true
blacklist netrom

install x25 /bin/true
blacklist x25

install atm /bin/true
blacklist atm

# Obsolete LAN protocols
install ipx /bin/true
blacklist ipx

install appletalk /bin/true
blacklist appletalk

# CAN bus (automotive networking — no use on workstations)
install can /bin/true
blacklist can

## DMA Attack Surface — Firewire
##############################################################

install firewire-core /bin/true
blacklist firewire-core

install firewire-ohci /bin/true
blacklist firewire-ohci

install firewire-sbp2 /bin/true
blacklist firewire-sbp2

## Bluetooth
##############################################################

install bluetooth /bin/true
blacklist bluetooth
install btusb /bin/true
blacklist btusb

## Misc High‑Risk Modules
##############################################################

# USB storage — if USB drives should not be mounted by non‑root
# EXCEPTION: required for recovery USB boot.
# install usb-storage /bin/true
# blacklist usb-storage

# PCMCIA — legacy card format, no modern use
install pcmcia /bin/true
blacklist pcmcia
install pcmcia_core /bin/true
blacklist pcmcia_core

# Speakup — screen reader for accessibility
# Only blacklist if this system has no accessibility needs
install speakup /bin/true
blacklist speakup

# CDC‑ACM — USB modem emulation; rarely needed
install cdc-acm /bin/true
blacklist cdc-acm

# CD‑ROM / optical drive — if not physically present
install cdrom /bin/true
blacklist cdrom
install sr_mod /bin/true
blacklist sr_mod

##############################################################
## Mount tracking and verification
##############################################################

# To verify a module is blocked:
#   modprobe <module> && echo "LOADED (should not happen)" || echo "BLOCKED"
# Rebuild initramfs to apply blacklist in early boot
```

---

## Part 17 — IOMMU and DMA Protection

### Required UEFI/BIOS Settings

Before configuring the kernel, verify in UEFI/BIOS firmware (Intel Z790 platform for i9-13900K):

- **VT-d** (Intel Virtualization for Directed I/O): **ENABLED**
- **Thunderbolt Security**: Set to **User Authorization** or **Secure Connect** (not "No Security")
- **CSM (Compatibility Support Module)**: **DISABLED** (required for full UEFI Secure Boot)
- **Secure Boot**: **ENABLED** with custom keys (Part 1.4)

### Kernel Parameters (already embedded in UKI cmdline in Part 1.4)

```
intel_iommu=on
iommu=force
```

**`iommu=pt` vs `iommu=force` trade-off:**

| Parameter | Behavior | Performance | Security |
|---|---|---|---|
| `iommu=pt` | Passthrough mode: only devices with explicit IOMMU groups get DMA isolation | Higher (no translation overhead for most devices) | Weaker: untranslated devices can access all physical memory |
| `iommu=force` | All DMA transactions go through the IOMMU | Lower (~5-10% I/O overhead on heavy workloads) | Stronger: every DMA transaction is validated against the IOMMU page table |

**Decision**: `iommu=force` for this threat model. Nation-state actors with physical access can connect a malicious Thunderbolt/PCIe device specifically to exploit DMA paths that passthrough mode leaves unprotected. The 5-10% I/O performance hit is acceptable on a workstation with NVMe drives (still vastly outperforms any spinning disk).

### Verification After Boot

```bash
# Verify IOMMU is active and enabled
dmesg | grep -E "(IOMMU|iommu)"
# Expected: "DMAR: IOMMU enabled" or similar

# Check Intel DMAR (DMA Remapping) is active
dmesg | grep "Intel-IOMMU"
# Expected: "Intel-IOMMU: enabled"

# Verify the i9-13900K's IOMMU groups are properly assigned
find /sys/kernel/iommu_groups/ -type l | sort -V | head -20

# Check that all PCIe devices are in IOMMU groups (none in the "catch-all" group 0 without isolation)
for group in $(find /sys/kernel/iommu_groups/ -maxdepth 1 -type d | sort -V); do
    echo "Group $(basename $group):"
    ls $group/devices/ 2>/dev/null | while read dev; do
        lspci -s $dev -nn 2>/dev/null
    done
done

# Verify strict mode is active
cat /sys/class/iommu/dmar*/intel-iommu/cap 2>/dev/null || \
    dmesg | grep -i "dmar.*passthrough"
# Absence of "passthrough mode" in output confirms strict mode
```

### IOMMU + TME Interaction

Both IOMMU and TME operate independently:
- TME encrypts DRAM contents (protects against physical memory extraction)
- IOMMU restricts which physical memory addresses each DMA master can access (protects against DMA attacks from malicious PCIe devices)

They are complementary: IOMMU prevents a malicious device from reading arbitrary memory; TME ensures that even if a device could read physical memory (e.g., before IOMMU is initialized), it sees encrypted data.

**Gap**: There is a brief window during early boot (before IOMMU is initialized by the kernel) where DMA attacks are theoretically possible. This window is minimized by:
1. The i9-13900K's UEFI firmware pre-programming the IOMMU before OS handoff (Intel DMAR tables in ACPI)
2. The `intel_iommu=on` parameter instructing the kernel to activate IOMMU as early as possible

---

## Part 18 — Network Hardening

### 18.1 — Hardened Firewalld Configuration

```bash
# Install firewalld (nftables backend is the default on Gentoo)
emerge --ask net-firewall/firewalld

# Enable the service and start it immediately
systemctl enable --now firewalld.service

# Set the default zone to 'drop' – all unsolicited incoming packets are
# silently discarded.  Outbound traffic is unaffected; the drop zone only
# controls the INPUT chain.
firewall-cmd --set-default-zone=drop
firewall-cmd --get-default-zone   # must return "drop"

# Move all active physical interfaces to the drop zone.
# Replace 'eno1' and 'wlan0' with the names shown by `ip link` or `nmcli device`.
for iface in eno1 wlan0; do
    firewall-cmd --zone=drop --change-interface=$iface --permanent 2>/dev/null || true
done

# --- Inbound rules (drop zone targets DROP; explicit accepts below) ---

# DNS‑over‑TLS (DoT) – required by dnscrypt‑proxy and systemd‑resolved
firewall-cmd --zone=drop --add-rich-rule='rule family="ipv4" port port="853" protocol="tcp" accept' --permanent
firewall-cmd --zone=drop --add-rich-rule='rule family="ipv6" port port="853" protocol="tcp" accept' --permanent

# HTTPS – DoH / QUIC fallback for dnscrypt‑proxy
firewall-cmd --zone=drop --add-rich-rule='rule family="ipv4" port port="443" protocol="tcp" accept' --permanent
firewall-cmd --zone=drop --add-rich-rule='rule family="ipv4" port port="443" protocol="udp" accept' --permanent

# Block cleartext DNS (port 53) to any external host.
# dnscrypt‑proxy listens on 127.0.0.1:5300; systemd‑resolved stub on 127.0.0.53.
# Applications must never send raw DNS to the outside.
firewall-cmd --zone=drop --add-rich-rule='rule family="ipv4" destination NOT address="127.0.0.0/8" port port="53" protocol="udp" drop' --permanent
firewall-cmd --zone=drop --add-rich-rule='rule family="ipv4" destination NOT address="127.0.0.0/8" port port="53" protocol="tcp" drop' --permanent

# SSH on non‑default port (see Part 20)
firewall-cmd --zone=drop --add-rich-rule='rule family="ipv4" port port="2222" protocol="tcp" accept' --permanent

# Cockpit – localhost only (see Section 19.4)
firewall-cmd --zone=drop --add-rich-rule='rule family="ipv4" source address="127.0.0.1" port port="9090" protocol="tcp" accept' --permanent

# --- Apply the permanent configuration ---
firewall-cmd --reload

# --- Verification ---
echo "=== Default zone ==="
firewall-cmd --get-default-zone
echo
echo "=== Rich rules (drop zone) ==="
firewall-cmd --zone=drop --list-rich-rules
echo
echo "=== Active zones ==="
firewall-cmd --get-active-zones
```

> **Note on backends:** On Gentoo, firewalld uses **nftables** as its default backend.  
> No additional USE flags are required unless you explicitly need the legacy iptables backend.

`NOTES`

---

You only need to adjust the **interface identifiers** used in the firewalld configuration. The rules and the `drop` zone policy itself are hardware-agnostic, but we must tell firewalld which of *your* network cards those rules should apply to.

## What to change (two items)

### ① Ethernet interface name
The configuration currently mentions `eno1` as a placeholder. On your MSI Pro Z790‑P motherboard, the onboard Ethernet controller will have a predictable name such as `eno1`, `enp3s0`, or `enp4s0`.

**What to do:**
Run `ip link show` or `nmcli device status` and note the exact name of the wired interface. Replace `eno1` in the firewalld script with that name.

```bash
# Check your interface names
ip link show
```

The line to change:
```bash
for iface in eno1 wlan0; do   # ← change eno1 to your actual Ethernet interface
```

### ② Wi‑Fi interface name (if you have a wireless card)
The configuration includes `wlan0` as a placeholder. Modern systems use the predictable naming scheme, so your Wi‑Fi interface is likely named something like `wlp2s0`, `wlp1s0`, or similar.

**What to do:**
Use `ip link show` as above and replace `wlan0` with your actual Wi‑Fi interface name if you have a wireless adapter.

> **If you have no Wi‑Fi card**, simply remove `wlan0` from the loop. Nothing breaks — the `2>/dev/null || true` supplies a silent no‑op for any non‑existent interface.

---

## Nothing else needs to change

| Configuration object | Hardware‑specific? | Action required |
|----------------------|--------------------|-----------------|
| `--set-default-zone=drop` | No | None |
| Rich rules (port 853, 443, 53, 2222, 9090) | No | None |
| Interface assignment | **Yes** | Replace the placeholder names with those from `ip link` |
| `--reload` / verification commands | No | None |

Once you replace the placeholder interface names with the ones actually present on your machine, the firewalld configuration is fully ready for your hardened Gentoo system.

---

## 18.2 – DNS over TLS and DNSCrypt

```bash
# Emerge dnscrypt‑proxy (systemd‑resolved is included in sys‑apps/systemd)
emerge --ask net-dns/dnscrypt-proxy
```

### Architecture

```
Application
  └─► systemd‑resolved stub (127.0.0.53:53)
        └─► dnscrypt‑proxy (127.0.0.1:5300)
              └─► Anonymized relay (optional, DNSCrypt‑only)
                    └─► Encrypted resolver (DNSCrypt / DoH)
                          └─► Authoritative DNS
```

* `dnscrypt‑proxy` listens on `127.0.0.1:5300` (not port 53, so it never competes with systemd‑resolved).
* `systemd‑resolved` listens on `127.0.0.53:53` (the standard stub address).
* `systemd‑resolved` forwards every upstream query to `dnscrypt‑proxy`.
* Applications use `127.0.0.53` via the `/etc/resolv.conf` symlink.

### systemd‑resolved

```bash
cat > /etc/systemd/resolved.conf << 'EOF'
[Resolve]
# Forward every query to the local dnscrypt‑proxy
DNS=127.0.0.1:5300
FallbackDNS=
# Disable mDNS and LLMNR – privacy leak + attack surface
LLMNR=no
MulticastDNS=no
# DNSSEC validation is delegated to dnscrypt‑proxy
DNSSEC=no
# Never fall back to cleartext DNS
DNSOverTLS=no
# Cache responses locally
Cache=yes
CacheFromLocalhost=no
ReadEtcHosts=yes
EOF

# Point the system resolver to the systemd‑resolved stub
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

systemctl restart systemd-resolved
systemctl enable systemd-resolved
```

### dnscrypt‑proxy

`mkdir -p /etc/dnscrypt-proxy && nvim /etc/dnscrypt-proxy/dnscrypt-proxy.toml`

```bash
##############################################################
# dnscrypt‑proxy.toml – Hardened Configuration, April 2026
##############################################################

# Listen on localhost port 5300 (systemd‑resolved uses 53)
listen_addresses = ['127.0.0.1:5300', '[::1]:5300']

max_clients = 250

# Protocol support
ipv4_servers      = true
ipv6_servers      = false
dnscrypt_servers  = true
doh_servers       = true

# Only use resolvers that validate DNSSEC, commit to no logging,
# and do not filter content.
require_dnssec   = true
require_nolog    = true
require_nofilter = true

disabled_server_names = []

timeout   = 2500
keepalive = 30

# Cache
cache            = true
cache_size       = 4096
cache_min_ttl    = 2400
cache_max_ttl    = 86400
cache_neg_min_ttl = 60
cache_neg_max_ttl = 600

# Anonymised DNS – prevents the resolver from seeing the client IP.
# Only works with the DNSCrypt protocol.
[anonymized_dns]
  skip_incompatible = true

  routes = [
    { server_name='*', via=['anon-ams-dnscrypt-nl', 'anon-cs-fr', 'anon-dnscrypt-ch-ipv4'] },
  ]

# Resolver and relay lists (downloaded and verified on first start)
[sources]
  [sources.public-resolvers]
    urls = [
      'https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md',
      'https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md'
    ]
    cache_file    = '/var/cache/dnscrypt-proxy/public-resolvers.md'
    minisign_key  = 'RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3'
    refresh_delay = 72
    prefix        = ''

  [sources.relays]
    urls = [
      'https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/relays.md',
      'https://download.dnscrypt.info/resolvers-list/v3/relays.md'
    ]
    cache_file    = '/var/cache/dnscrypt-proxy/relays.md'
    minisign_key  = 'RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3'
    refresh_delay = 72
    prefix        = ''

# Logging
[log]
  level = 2

[query_log]
  file = '/var/log/dnscrypt-proxy/query.log'
```

```bash
# --- Permissions & directories ---
mkdir -p /var/cache/dnscrypt-proxy /var/log/dnscrypt-proxy
chown -R dnscrypt-proxy:dnscrypt-proxy /var/cache/dnscrypt-proxy /var/log/dnscrypt-proxy
chmod 750 /var/cache/dnscrypt-proxy /var/log/dnscrypt-proxy
chmod 640 /etc/dnscrypt-proxy/dnscrypt-proxy.toml

systemctl enable --now dnscrypt-proxy
systemctl enable --now systemd-resolved
```


### Verification

```bash
resolvectl status
resolvectl query gentoo.org
```

Both `dnscrypt-proxy` and `systemd-resolved` should be `active (running)`. Check the initial boot log of dnscrypt‑proxy; it should report `Source [public-resolvers] loaded` and `Source [relays] loaded`. If you see `[ERROR]` lines about file permissions or missing cache directories, re‑run the `chown` and `chmod` lines above.

---

## 18.3 — Hardened NetworkManager

`emerge --ask net-misc/networkmanager && mkdir -p /etc/NetworkManager/conf.d/ && nvim /etc/NetworkManager/conf.d/00-hardening.conf`

```bash
[main]
plugins = keyfile
# Never touch /etc/resolv.conf — systemd‑resolved manages it
dns = none
systemd-resolved = true
# Note: dns=none implies rc-manager=unmanaged, so rc-manager is not set separately.

[connection]
# MAC address randomisation
# Supported globally for both Ethernet and Wi‑Fi (see NetworkManager.conf(5))
ethernet.cloned-mac-address = random
wifi.cloned-mac-address     = stable-ssid

[device]
# Randomise the MAC address used during Wi‑Fi scanning (per‑device setting)
wifi.scan-rand-mac-address = yes

[connectivity]
# Disable connectivity checking (phone‑home requests leak metadata)
uri=

[logging]
level  = INFO
domains = ALL
```

`mkdir -p /etc/NetworkManager/dispatcher.d && nvim /etc/NetworkManager/dispatcher.d/99-wifi-security` 

```bash
#!/bin/bash
# /etc/NetworkManager/dispatcher.d/99-wifi-security
# Enforce Wi‑Fi security defaults on every connection activation.

# --- Apply Wi‑Fi security defaults via a dispatcher script ---
# wifi-sec.key-mgmt, wifi-sec.wps-method, and wifi-sec.pmf cannot be set as global defaults in NetworkManager.conf; they are only valid as per‑profile settings. The official NetworkManager documentation recommends using a dispatcher script to enforce them on every new Wi‑Fi connection activation


# This script is called by NetworkManager-dispatcher on every network event.
# It applies wifi-sec settings to all Wi‑Fi connections that are being brought up.
#
# Variables provided by NetworkManager:
#   DEVICE_IFACE  – interface name (e.g. wlan0)
#   ACTION        – event type ("up", "down", etc.)
#   CONNECTION_UUID – unique identifier of the connection profile

INTERFACE="$1"
ACTION="$2"

# Only act when a Wi‑Fi interface comes up
if [[ "$ACTION" == "up" ]]; then
    CONNECTION_TYPE="$CONNECTION_TYPE"

    if [[ "$CONNECTION_TYPE" == "802-11-wireless" ]]; then
        nmcli connection modify uuid "$CONNECTION_UUID" \
            wifi-sec.pmf        1 \
            wifi-sec.wps-method disabled \
            wifi-sec.key-mgmt   sae 2>/dev/null
    fi
fi
exit 0
```

```bash
chown root:root /etc/NetworkManager/dispatcher.d/99-wifi-security
chmod 755 /etc/NetworkManager/dispatcher.d/99-wifi-security

systemctl restart NetworkManager
systemctl enable NetworkManager
```

> **PMF (Protected Management Frames):** Setting `pmf = 1` enables PMF when the AP supports it.  
> `pmf = 2` (required) is stronger but may cause connectivity issues with older access points; evaluate after testing.

> **WPA3‑SAE:** The dispatcher script enforces `sae` (WPA3) for all Wi‑Fi connections.  
> Connections to WPA2‑only access points will require manual adjustment—use `nmcli connection modify <con‑name> wifi-sec.key-mgmt wpa-psk` to fall back.

> **Dispatcher script note:** The `99-wifi-security` script runs as root on every connection state change and enforces the Wi‑Fi security settings that are not valid as global defaults in `NetworkManager.conf`.

---

## 18.4 — Cockpit Integration (Optional)

```bash
# Enable inode64-overlay (hosts the app-admin/cockpit package)
eselect repository enable inode64-overlay
emaint sync -r inode64-overlay

emerge --ask app-admin/cockpit
```

Once installed, harden Cockpit with the following configuration:

```bash
mkdir -p /etc/cockpit

cat > /etc/cockpit/cockpit.conf << 'EOF'
[WebService]
# Bind only to localhost — never expose Cockpit on external interfaces
Origins = https://localhost:9090 https://127.0.0.1:9090
# ProtocolHeader is only needed when Cockpit is behind a reverse proxy;
# here it is harmless but unnecessary for direct local connections.
AllowUnencrypted = false

[Session]
# Automatically log out after 15 minutes of inactivity
IdleTimeout = 15
# Display the warning banner on the login screen
Banner = /etc/cockpit/banner.txt

[Log]
Fatal = criticals-and-warnings
EOF

cat > /etc/cockpit/banner.txt << 'EOF'
WARNING: This system is monitored. Unauthorized access is prohibited. All actions are logged and subject to security review.
EOF

# Generate a self‑signed certificate for TLS
mkdir -p /etc/cockpit/ws-certs.d

openssl req -x509 -newkey rsa:4096 \
  -keyout /etc/cockpit/ws-certs.d/cockpit.key \
  -out /etc/cockpit/ws-certs.d/cockpit.crt \
  -days 3650 -nodes \
  -subj "/C=BD/ST=Dhaka/L=Dhaka/O=Workstation/CN=localhost" \
  -addext "subjectAltName = IP:127.0.0.1,DNS:localhost"

chmod 600 /etc/cockpit/ws-certs.d/cockpit.key
chmod 644 /etc/cockpit/ws-certs.d/cockpit.crt

systemctl enable --now cockpit.socket
```

> **Certificate pinning:** After the first login to `https://localhost:9090`, export the certificate’s SHA‑256 fingerprint and pin it in your browser for an additional layer of trust.

> **AppArmor note:** As of April 2026 the apparmor.d project does **not** ship a Cockpit profile.  
> Compensating controls: Cockpit is bound to localhost only, socket‑activated by systemd, and should be hardened with `svc-harden.py apply cockpit` (see Part 24).

---

# Part 19 — SSH Hardening with TPM‑Backed Keys

A TPM can store SSH private keys, making them much harder for an attacker—or malware—to extract: the key never leaves the TPM. This is comparable in security to a YubiKey but uses the TPM already on your motherboard.

The integration uses `app‑crypt/tpm2‑pkcs11`, which provides a PKCS#11 library that OpenSSH can talk to directly.

[NOTE] Will the ssh setup affect my git-setup bash script

### 19.1 — Install Required Packages

```bash
# Install the PKCS#11 interface for TPM2 hardware, the TSS library,
# and OpenSSH.  dbus is required for the TPM resource manager that
# allows unprivileged users to access the TPM.
emerge --ask app-crypt/tpm2-pkcs11 app-crypt/tpm2-tss net-misc/openssh sys-apps/dbus

# The tss group grants unprivileged users access to the TPM.
# Add your user (replace "ahsan" if different).
gpasswd -a ahsan tss
```

> **Note:** `app‑crypt/tpm2‑tss` is pulled in automatically by the `tpm` USE flag on `sys‑apps/systemd`, so you may already have it. Re‑running emerge is harmless.

---

### 19.2 — Create the TPM‑Backed SSH Key (as the user, **not root**)

```bash
# Initialise the PKCS#11 token store (do this once)
tpm2_ptool init

# Create a token.  Change --userpin to a PIN of your choice.
# The PIN provides a second factor: something you know (PIN) +
# something you have (the TPM chip).
tpm2_ptool addtoken --pid=1 --label=ssh --userpin=YourPinHere --sopin=AdminPinHere

# Create a key inside that token.
# ecc256 is an ECDSA P‑256 key; RSA 2048 is also supported.
tpm2_ptool addkey --label=ssh --userpin=YourPinHere --algorithm=ecc256
```

The `‑‑userpin` can be empty (`‑‑userpin=""`), but that means physical possession of the computer is sufficient to use the key. Setting a PIN achieves true two‑factor authentication.

---

### 19.3 — Retrieve the Public Key

```bash
ssh-keygen -D /usr/lib64/libtpm2_pkcs11.so > ~/.ssh/tpm_key.pub
```

Copy the contents of `~/.ssh/tpm_key.pub` to the `authorized_keys` file on any server you want to connect to. `ssh‑copy‑id` does **not** work with `libtpm2_pkcs11.so` at this time.

---

### 19.4 — SSH Client Configuration (system‑wide)

Add the PKCS#11 provider globally so that SSH will try to use TPM keys by default on every connection:

```bash
cat >> /etc/ssh/ssh_config << 'EOF'

# Use TPM-backed keys via PKCS#11 by default.
# The library path is architecture-specific:
#   /usr/lib64/libtpm2_pkcs11.so  (amd64)
#   /usr/lib/libtpm2_pkcs11.so    (x86)
PKCS11Provider /usr/lib64/libtpm2_pkcs11.so
EOF
```

You may also limit it to specific hosts:

```
Host git.example.com
    PKCS11Provider /usr/lib64/libtpm2_pkcs11.so
```

---

### 19.5 — Complete `/etc/ssh/ssh_config` (Hardened Client)

```bash
cat > /etc/ssh/ssh_config << 'EOF'
##############################################################
# /etc/ssh/ssh_config — Hardened SSH Client Configuration
# Gentoo Hardened — April 2026
##############################################################

Host *
    # Only Ed25519 and ECDSA P-521 host keys trusted
    HostKeyAlgorithms ssh-ed25519,ecdsa-sha2-nistp521

    # Key exchange: Curve25519 + post‑quantum hybrids
    KexAlgorithms sntrup761x25519-sha512,mlkem768x25519-sha256,curve25519-sha256,curve25519-sha256@libssh.org

    # Strong ciphers and MACs
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

    # Prefer Ed25519 keys when authenticating
    IdentityFile ~/.ssh/id_ed25519
    IdentityFile ~/.ssh/id_ecdsa

    # Automatically add server to known_hosts but do not silently accept
    # changed host keys (prevents MITM via re‑key)
    StrictHostKeyChecking ask
    UpdateHostKeys ask

    # Do not hash known_hosts (hashing obscures hosts connected to, but
    # makes it impossible to detect when a host key changes to a known bad key)
    HashKnownHosts no

    # Disable forwarding client‑side
    ForwardAgent no
    ForwardX11 no

    # Connection reuse (ControlMaster) — disabled in high‑security contexts
    ControlMaster no

    # Server alive settings (matches server‑side ClientAliveInterval)
    ServerAliveInterval 60
    ServerAliveCountMax 3

    # Compression
    Compression yes

    # Visual host key fingerprint (SAS for manual verification)
    VisualHostKey yes

    # Use TPM‑backed keys via PKCS#11 by default
    PKCS11Provider /usr/lib64/libtpm2_pkcs11.so
EOF
```

---

### 19.6 — ssh-agent Integration (Optional)

To load the TPM key into your running SSH agent (so you are not prompted for the PIN on every connection):

```bash
ssh-add -s /usr/lib64/libtpm2_pkcs11.so
```

This command is necessary after every reboot—or whenever the agent session expires.

---

### 19.7 — Hardened sshd Configuration (Server)

```bash
cat > /etc/ssh/sshd_config << 'EOF'
##############################################################
# /etc/ssh/sshd_config
# Gentoo Hardened — Hardened SSH Server Configuration
# April 2026 — Against nation-state APT threat model
#
# apparmor.d ships a mature sshd profile. After installing
# apparmor.d, verify it is loaded in enforce mode:
#   aa-status | grep sshd
##############################################################

## --- Port and Address Binding ---
# Non-default port reduces automated scanner noise and blunt-force attempts.
# Security benefit: eliminates script-kiddie and automated scanning traffic;
# does NOT stop targeted APT actors who perform port scanning before attack.
# Limitation: some corporate firewalls block non-22 egress; document this.
Port 2222

# Listen on all interfaces by default; restrict if management NIC is separate
# ListenAddress 127.0.0.1  ## Uncomment to restrict to localhost only

## --- Protocol and Key Algorithms ---
# Permit only Ed25519 (preferred) and ECDSA P-521
# Rationale: RSA ≤ 3072 is approaching sunset per NIST SP 800-131A Rev 3 (draft).
# Nation-state actors with quantum capabilities target RSA first.
# Ed25519 (Curve25519) has no NIST involvement and is not susceptible to
# the potential NSA backdoor concerns raised about NIST P-curves.
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_ecdsa_key  # P-521; regenerated below with -b 521

# Key exchange: Curve25519 + post‑quantum hybrids
# sntrup761x25519-sha512: hybrid post‑quantum (OpenSSH 8.5+)
# mlkem768x25519-sha256:  NIST-standardised hybrid post‑quantum (OpenSSH 9.9+)
# This is the default KexAlgorithms list in OpenSSH 10.0+; explicitly
# listing it ensures the same behaviour on older versions.
KexAlgorithms sntrup761x25519-sha512,mlkem768x25519-sha256,curve25519-sha256,curve25519-sha256@libssh.org

# Host key algorithms presented to clients
HostKeyAlgorithms ssh-ed25519,ecdsa-sha2-nistp521

# Ciphers: ChaCha20-Poly1305 and AES-256-GCM (authenticated)
# Disables all CBC ciphers (CBC padding oracle attacks) and AES-128
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr

# MACs: ETM (encrypt-then-MAC) only
# Disables all encrypt-and-MAC patterns (vulnerable to Lucky13 and
# similar timing attacks)
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

## --- Authentication ---
# Disable root login — root access must be via sudo from an unprivileged account
PermitRootLogin no

# Keys only — no password authentication
# Password auth is vulnerable to brute-force and credential-stuffing attacks
PasswordAuthentication no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no

# Disable empty passwords
PermitEmptyPasswords no

# Use PAM stack (for account lockout via pam_faillock)
UsePAM yes

# Only allow members of the 'sshusers' group to authenticate
# Create this group and add admin users:
#   groupadd sshusers; usermod -aG sshusers ahsan
AllowGroups sshusers

## --- Session and Connection Limits ---
# Time allowed to authenticate before connection is closed
# Short window prevents connection-holding resource exhaustion
# (OpenSSH default is 120 seconds; 30 is stricter)
LoginGraceTime 30

# Maximum auth attempts per connection (disconnect after 3 failures)
MaxAuthTries 3

# Maximum concurrent sessions per connection
MaxSessions 3

# Maximum simultaneous pending (unauthenticated) connections
# Format: start:rate:full
# Throttles connection storms from scanners/brute-force
# (OpenSSH default is 10:30:100; 10:30:60 is stricter at the top end)
MaxStartups 10:30:60

## --- Session Idle Timeout ---
# After 10 minutes of inactivity, send a keepalive packet
ClientAliveInterval 600
# Disconnect after 1 unanswered keepalive (10 minutes total idle timeout)
ClientAliveCountMax 1

## --- Forwarding and Tunneling ---
# X11 forwarding disabled — X11 protocol has exploitable legacy vulns
X11Forwarding no

# TCP forwarding disabled — prevents use as an anonymous pivot/proxy
# EXCEPTION: if you genuinely need SSH port-forwarding (e.g., database tunnels),
# set AllowTcpForwarding local (allows only local forwards, not remote)
AllowTcpForwarding no

# Disable agent forwarding — prevents agent-forwarding credential theft attacks
AllowAgentForwarding no

# Disable stream local forwarding (UNIX socket forwarding)
AllowStreamLocalForwarding no

# Do not permit tunneling
PermitTunnel no

## --- Miscellaneous ---
# Hide MOTD (contains OS/version info useful for fingerprinting)
PrintMotd no

# Legal banner displayed before authentication
Banner /etc/ssh/banner

# Strict mode — check permissions on key files and home directories
StrictModes yes

# Log level for authentication — VERBOSE logs accepted/rejected keys
# Useful for detecting key-based brute force
LogLevel VERBOSE

# Accept only known environment variables
# PermitUserEnvironment is explicitly set to its default (no) to ensure
# user‑controlled environment files (~/.ssh/environment, ~/.ssh/rc)
# are never sourced.
PermitUserEnvironment no
AcceptEnv LANG LC_*

# Compression: delayed (after authentication)
Compression delayed

# Subsystem for SFTP — internal-sftp is the recommended, distribution‑agnostic
# approach that avoids needing to know the exact sftp‑server binary path.
# It was introduced in OpenSSH 4.8 and is available on all modern systems.
Subsystem sftp internal-sftp
EOF

# Create legal banner
cat > /etc/ssh/banner << 'EOF'
**********************************************************************
 AUTHORIZED ACCESS ONLY
 This system is monitored. All connections are logged.
 Unauthorized access is prohibited and will be prosecuted.
**********************************************************************
EOF

# Regenerate host keys — Ed25519 and ECDSA P-521 only
# Step 1: Remove the old default-generated RSA, DSA, and (weaker) ecdsa keys
rm -f /etc/ssh/ssh_host_rsa_key* /etc/ssh/ssh_host_dsa_key* /etc/ssh/ssh_host_ecdsa_key*
# Step 2: Generate fresh Ed25519 and ECDSA P-521 keys
ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
ssh-keygen -t ecdsa -b 521 -f /etc/ssh/ssh_host_ecdsa_key -N ""

# Create sshusers group and add admin
groupadd -f sshusers
usermod -aG sshusers ahsan

# Restart sshd
systemctl restart sshd

# Verify AppArmor sshd profile is in enforce mode
aa-status | grep -E "sshd|enforce"
```

---

### 19.8 — TPM‑Based Key Usage Cheat Sheet

| Task | Command |
|------|---------|
| Initialise store | `tpm2_ptool init` |
| Create token | `tpm2_ptool addtoken --pid=1 --label=ssh --userpin=… --sopin=…` |
| Create key (ecc256) | `tpm2_ptool addkey --label=ssh --userpin=… --algorithm=ecc256` |
| List keys | `tpm2_ptool list` |
| Show public key | `ssh‑keygen -D /usr/lib64/libtpm2_pkcs11.so` |
| Connect once | `ssh -I /usr/lib64/libtpm2_pkcs11.so user@host` |
| Load into agent | `ssh‑add -s /usr/lib64/libtpm2_pkcs11.so` |

---

### 19.9 — Verification

```bash
# Verify that the TPM PKCS#11 library is present
ls -l /usr/lib64/libtpm2_pkcs11.so

# Verify your user is in the tss group
groups ahsan | grep tss

# List the keys stored in the TPM
tpm2_ptool list

# Display the public key
ssh-keygen -D /usr/lib64/libtpm2_pkcs11.so

# Test a connection
ssh -I /usr/lib64/libtpm2_pkcs11.so user@remote.host.tld
```

---

## Part 20 — PAM and Authentication Hardening

### Gentoo‑Specific PAM Notes

Gentoo, like Arch, does not use a PAM configuration manager. PAM stack files in `/etc/pam.d/` must be edited directly. However, Gentoo has a unique architecture: the central file is `/etc/pam.d/system-auth`, which is **included** by `/etc/pam.d/system-login` (used by `login`, `sshd`, display managers) rather than being a standalone login stack. This means modifications to `system-auth` automatically affect all PAM‑aware services.

Additionally, Gentoo provides `sys-auth/pambase`, which ships the default PAM configuration. Its `pwquality` USE flag controls whether `pam_pwquality.so` is integrated into the system auth stack for password quality validation.

The key files are:
* `/etc/pam.d/system-auth` — core PAM stack, included by most services
* `/etc/pam.d/system-login` — login‑specific stack (includes `system-auth`)
* `/etc/security/faillock.conf` — `pam_faillock` configuration (preferred method over inline arguments)
* `/etc/security/pwquality.conf` — `pam_pwquality` configuration
* `/etc/security/limits.conf` — resource limits

### Installation

```bash
# Install PAM (part of base system) and libpwquality for password strength checking. Enable the pwquality USE flag on pambase to integrate pam_pwquality.so into system-auth.
emerge sys-auth/pambase sys-libs/libpwquality

# pam_faillock is included with sys-libs/pam (no separate package needed). Verify the module is present:
ls /lib64/security/pam_faillock.so
```

> **Note on `pam_umask.so`:** As of April 2026, `pam_umask.so` is not yet part of the default Gentoo `pambase` package (tracked in [Bug 938574](https://bugs.gentoo.org/938574)). To set a default umask, add `session optional pam_umask.so umask=0027` to `/etc/pam.d/system-login` in the `session` block.

### pam_faillock Configuration

`pam_faillock` locks accounts after repeated authentication failures. Since PAM 1.4.0, the preferred method is to configure it via `/etc/security/faillock.conf` rather than inline module arguments — this avoids duplication across multiple service files and provides a single source of truth.

```bash
cat > /etc/security/faillock.conf << 'EOF'
# /etc/security/faillock.conf
# Account lockout after repeated authentication failures.
# This file is read by pam_faillock.so and is the preferred method
# over configuring pam_faillock directly.

# Lock account after 5 consecutive failures (default: 3)
deny = 5

# Failure window: count failures within 10 minutes (default: 900)
fail_interval = 600

# Lock duration: 15 minutes. 0 means "never" (requires manual reset).
# Default: 600 (10 minutes).
unlock_time = 900

# Even root can be locked out — prevents targeted root brute-force
even_deny_root = true
root_unlock_time = 60

# Store failure data in /var/run/faillock/ (tmpfs — cleared on reboot).
# For persistent lockout across reboots, change to /var/lib/faillock/.
# Default: /var/run/faillock.
dir = /var/run/faillock

# Audit all authentication events to the system log
audit = true

# Track only local users (ignore centralized AD, LDAP, etc.).
# Set to true if using a centralized authentication service.
local_users_only = false

# When 'true', suppresses informative messages to the user.
# Set to 'false' so administrators can read failure details in logs.
silent = false
EOF
```

> **Note on `silent`:** When `silent = false`, `pam_faillock` reports whether the user exists or not (a slight information leak). For maximum stealth, set `silent = true`, but this makes debugging authentication failures harder. The `audit` option logs to the system log regardless of the `silent` setting.

### pam_pwquality Configuration

`pam_pwquality.so` (successor to the deprecated `pam_cracklib`) enforces password complexity rules. It reads its settings from `/etc/security/pwquality.conf` by default.

```bash
cat > /etc/security/pwquality.conf << 'EOF'
# /etc/security/pwquality.conf
# Password quality requirements for local accounts.
# SSH uses key‑only auth (Part 19); these requirements apply to
# local console login, sudo password changes, and passwd.

# Minimum length: 16 characters
minlen = 16

# Require at least N characters of each class.
# Negative numbers mean "at least this many".
# 0 means "no requirement".
ucredit = -1   # at least 1 uppercase
lcredit = -1   # at least 1 lowercase
dcredit = -1   # at least 1 digit
ocredit = -1   # at least 1 special character

# Maximum consecutive same characters
maxrepeat = 3

# Maximum consecutive characters from the same class
maxclassrepeat = 4

# Minimum number of character classes required
# (uppercase, lowercase, digit, special)
minclass = 3

# Reject passwords containing the username
usercheck = 1

# Number of characters in the new password that must not be
# present in the old password
difok = 8

# Dictionary check — reject common/dictionary words
dictcheck = 1

# Reject simple sequences (abc, 123, etc.)
enforcing = 1

# Number of retries before giving up
retry = 3

# Reject passwords containing these words.
# This is a space‑separated list; each word longer than 3 characters
# is individually searched for and forbidden in new passwords.
badwords = password passwd letmein qwerty
EOF
```

> **Note on `badwords`:** The `pwquality.conf` file uses `name = value` syntax and accepts a space‑separated list. This differs from the inline PAM argument format, which uses a different quoting model. The upstream issue tracker confirms that inline PAM arguments do not handle multi‑word values well, but the dedicated config file does.

### Hardened `/etc/pam.d/system-auth`

This is the core PAM stack included by `system-login`, `sshd`, `sudo`, `su`, and most other services. The `pam_faillock` lines use the `faillock.conf` file (via no extra arguments), which is the modern, maintainable approach.

```bash
cat > /etc/pam.d/system-auth << 'EOF'
#%PAM-1.0
# /etc/pam.d/system-auth
# Hardened PAM stack for Gentoo — April 2026
#
# Included by: /etc/pam.d/system-login, sshd, sudo, su, and most other services.
# Modifications here affect all PAM‑aware authentication on the system.

## AUTH STACK
# pam_faillock: preauth — check if account is locked BEFORE password prompt.
# This prevents timing attacks that reveal account existence.
auth      required  pam_faillock.so preauth

# pam_unix: authenticate via /etc/shadow (sha512, try_first_pass avoids a
# second prompt if a password was already entered by a previous module).
auth      [success=1 default=bad] pam_unix.so try_first_pass nullok

# pam_faillock: authfail — record failure if pam_unix above failed
auth      [default=die] pam_faillock.so authfail

# pam_faillock: authsucc — record success if pam_unix above succeeded
auth      sufficient pam_faillock.so authsucc

# Deny if none of the above succeeded
auth      required  pam_deny.so

## ACCOUNT STACK
# pam_faillock: check account lockout status
account   required  pam_faillock.so

# pam_unix: standard account checks (expiry, validity)
account   required  pam_unix.so

## PASSWORD STACK
# pam_pwquality: enforce password quality on changes
password  required  pam_pwquality.so

# pam_unix: update the password with sha512.
# rounds=65536 makes offline brute-force 65536× more expensive.
# use_authtok passes the password from pam_pwquality without re‑prompting.
password  required  pam_unix.so sha512 shadow rounds=65536 use_authtok

## SESSION STACK
# pam_limits: enforce resource limits (prevents fork bombs, etc.)
session   required  pam_limits.so

# pam_unix: standard session setup
session   required  pam_unix.so

# pam_env: set environment variables from /etc/security/pam_env.conf
session   required  pam_env.so

# pam_umask: set default umask for login sessions
# Note: this may need to be added to /etc/pam.d/system-login as well
# if not already included there. See Gentoo Bug 938574.
session   optional  pam_umask.so umask=0027

# systemd-logind session tracking
session   optional  pam_systemd.so
EOF
```

> **SHA512 rounds note:** Starting with Linux‑PAM 1.6.0, the `rounds` option can also be configured globally via `SHA_CRYPT_MAX_ROUNDS` in `/etc/login.defs` instead of (or in addition to) the PAM `rounds=` argument. If both are set, the PAM argument takes precedence. The value 65536 was chosen to balance security and login latency on modern hardware.

### pam_limits Configuration

```bash
cat > /etc/security/limits.conf << 'EOF'
# /etc/security/limits.conf
# Resource limits to constrain fork-bomb and resource exhaustion attacks.
# See limits.conf(5) for syntax details.

# Defaults for all users
*        soft    nproc           4096
*        hard    nproc           8192
*        soft    nofile          65536
*        hard    nofile          1048576
*        soft    stack           8192
*        hard    stack           65536
*        soft    core            0
*        hard    core            0

# Root: slightly higher limits for administrative tasks
root     soft    nproc           unlimited
root     hard    nproc           unlimited
root     soft    nofile          1048576
root     hard    nofile          1048576
EOF
```

### Unlocking a Locked Account

```bash
# Reset faillock counters for a user
faillock --user ahsan --reset

# Check current lockout status
faillock --user ahsan

# To unlock manually (if faillock is not available):
rm -f /var/run/faillock/ahsan
```

### Verification

```bash
# Verify all PAM modules are available
for mod in pam_faillock.so pam_pwquality.so pam_limits.so pam_umask.so pam_systemd.so; do
    ls /lib64/security/$mod 2>/dev/null && echo "  ✓ $mod" || echo "  ✗ $mod MISSING"
done

# Test password quality enforcement (as a regular user)
passwd
# Should reject weak passwords per pwquality.conf

# Test faillock after deliberate failure (as root, monitor another TTY)
faillock --user ahsan
```

---

## Part 21 — Supply Chain Monitoring

A nation-state supply-chain adversary targets the package distribution pipeline — tampered ebuilds, malicious source tarballs, or compromised repository metadata — to inject code before it ever reaches the compiler. The controls below make every link in that chain cryptographically verifiable and auditable.

---

### 21.1 — Portage ELOG: Build and Post‑Install Logging

Portage’s native **ELOG** framework captures every `einfo`, `ewarn`, and `eerror` message emitted by ebuilds and saves them to a structured, machine‑parseable log. Enable it in `/etc/portage/make.conf`:

```bash
# Per‑ebuild build logs (full stdout/stderr of the build process)
PORT_LOGDIR="/var/log/portage"

# Automatically delete build logs older than 30 days
FEATURES="clean-logs"

# ELOG saves important messages to /var/log/portage/elog/
PORTAGE_ELOG_SYSTEM="save"
PORTAGE_ELOG_CLASSES="warn info error log qa"
```

After applying these settings, every `emerge` produces:
* A full build log at `/var/log/portage/<category>:<package>:<timestamp>.log`.
* An ELOG summary at `/var/log/portage/elog/<category>:<package>:<timestamp>.log`.

The `PORTAGE_ELOG_SYSTEM` variable accepts any space‑separated combination of `save`, `custom`, `syslog`, `mail`, `save_summary`, and `mail_summary`; `save` is the minimum required to write these logs to disk. The ELOG logs can be browsed with `app-portage/elogv`.

---

### 21.2 — Repository Integrity Verification

Portage verifies all Manifest checksums by default. Two additional layers guarantee that the ebuild repository itself has not been tampered with.

#### 21.2.1 — Git Commit Signature Verification

Already configured in Section 6.7. The `repos.conf` entry for `::gentoo` includes:

```ini
sync-git-verify-commit-signature = yes
sync-openpgp-key-path = /usr/share/openpgp-keys/gentoo-release.asc
```

Every `emerge --sync` verifies a valid OpenPGP signature from a Gentoo developer before accepting new commits.

#### 21.2.2 — Full‑Tree Manifest Verification with Gemato

`app-portage/gemato` (Gentoo Manifest Tool) recursively verifies the entire repository tree against the top‑level `Manifest`, which is itself OpenPGP‑signed. This catches any tampering at the file level that a git‑commit signature might miss.

```bash
emerge --ask app-portage/gemato

# Manual verification of the current repository state:
gemato verify -K /usr/share/openpgp-keys/gentoo-release.asc \
  "$(portageq get_repo_path / gentoo)"
```

A successful verification ends with `INFO:root:<repo_path> verified in <N> seconds`. If the command exits non‑zero or reports signature mismatches, the repository must be re‑synced immediately.

> **Note:** The `sync-rsync-verify-metamanifest` directive was proposed but is not a supported Portage configuration option as of April 2026. For rsync‑based repos, use `gemato verify` manually or via the weekly timer below. For git‑based repos (as in this guide), git‑commit verification provides equivalent integrity guarantees.

---

### 21.3 — Package Transaction Audit Logging

This hook writes a structured JSON record to `/var/log/portage-audit.json` for every successfully merged package and every failure. It uses the `register_success_hook` and `register_die_hook` mechanism documented in the Gentoo wiki.

```bash
# Append the audit hook to the existing bashrc (preserves Snapper hooks)
cat >> /etc/portage/bashrc << 'BASHRC'

# --- Supply‑chain audit logging ---
# Logs every emerge operation as a newline‑delimited JSON record.
# Requires python3 (always present on a Gentoo installation).
register_success_hook audit_emerge_success
register_die_hook    audit_emerge_failure

audit_emerge_success() {
    local AUDIT_LOG="/var/log/portage-audit.json"
    python3 -c "
import json, os, datetime
entry = {
    'timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'action': 'emerge',
    'package': '${CATEGORY}/${PF}',
    'status': 'SUCCESS',
    'uid': os.getuid(),
    'pid': os.getpid()
}
print(json.dumps(entry))
" >> "$AUDIT_LOG" 2>/dev/null || true
}

audit_emerge_failure() {
    local AUDIT_LOG="/var/log/portage-audit.json"
    python3 -c "
import json, os, datetime
entry = {
    'timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'action': 'emerge',
    'package': '${CATEGORY}/${PF}',
    'status': 'FAILED',
    'uid': os.getuid(),
    'pid': os.getpid()
}
print(json.dumps(entry))
" >> "$AUDIT_LOG" 2>/dev/null || true
}
BASHRC
```

> **Important caveat:** `register_success_hook` fires only when an ebuild is merged without any error — a file collision or a QA warning is sufficient for the hook **not** to fire. The corresponding `register_die_hook` captures failures that would otherwise be silent.

---

### 21.4 — GLSA Vulnerability Scanning

Gentoo publishes **Gentoo Linux Security Advisories (GLSAs)** through the `app-portage/gentoolkit` package. The `glsa-check` tool compares installed packages against published advisories and can automatically remediate affected packages.

```bash
emerge --ask app-portage/gentoolkit

# List all installed packages affected by any GLSA
glsa-check --list affected

# Show what would be done to fix affected packages (dry‑run)
glsa-check --pretend affected

# Apply fixes for all affected packages
glsa-check --fix affected
```

The `--fix` flag is marked **experimental** in the GLSA‑CHECK man page and should be used with caution. Always run `--pretend` first.

---

### 21.5 — Log Rotation for the Audit Log

```bash
cat > /etc/logrotate.d/portage-audit << 'EOF'
/var/log/portage-audit.json {
    monthly
    rotate 6
    compress
    missingok
    notifempty
    create 0640 root audit
}
EOF
```

---

### 21.6 — Weekly Security Automation

A systemd timer runs GLSA scanning, repository integrity verification, and reports results to the monitoring pipeline (Part 23).

#### 21.6.1 — Weekly Security Scan Script

```bash
cat > /usr/local/bin/weekly-security-scan.sh << 'SCRIPT'
#!/bin/bash
# /usr/local/bin/weekly-security-scan.sh
# Weekly GLSA scan + repository integrity check.
# Designed to run as a systemd oneshot service.

set -euo pipefail
HOSTNAME=$(hostname)
DATE=$(date -u +"%Y-%m-%d")

echo "[${DATE}] Weekly security scan for ${HOSTNAME}"
echo ""

# 1. GLSA scan
echo "--- GLSA: affected packages ---"
if command -v glsa-check &>/dev/null; then
    glsa-check --list affected 2>&1 || echo "(glsa-check completed)"
else
    echo "glsa-check not installed; emerge app-portage/gentoolkit"
fi

# 2. Repository integrity
echo ""
echo "--- Repository integrity (gemato) ---"
if command -v gemato &>/dev/null; then
    gemato verify -K /usr/share/openpgp-keys/gentoo-release.asc \
      "$(portageq get_repo_path / gentoo)" 2>&1
else
    echo "gemato not installed; emerge app-portage/gemato"
fi

# 3. Kernel and boot state
echo ""
echo "--- Boot chain ---"
echo "Running kernel: $(uname -r)"
echo "Last UKI: $(stat -c %y /efi/EFI/Linux/*.efi 2>/dev/null | head -1 || echo 'unknown')"
SCRIPT

chmod +x /usr/local/bin/weekly-security-scan.sh
```

#### 21.6.2 — Weekly Timer and Service Units

```bash
cat > /etc/systemd/system/weekly-security-scan.service << 'EOF'
[Unit]
Description=Weekly GLSA and Repository Integrity Scan
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/weekly-security-scan.sh
User=root
EOF

cat > /etc/systemd/system/weekly-security-scan.timer << 'EOF'
[Unit]
Description=Run weekly security scan every Monday at 07:00 UTC

[Timer]
OnCalendar=Mon *-*-* 07:00:00 UTC
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now weekly-security-scan.timer
```

---

### 21.7 — Verification

```bash
# Confirm ELOG is active
ls /var/log/portage/elog/*.log 2>/dev/null | head -5 || echo "No ELOG files yet (run an emerge to generate them)"

# Confirm the timer is active
systemctl is-active weekly-security-scan.timer

# Check the audit log after an emerge
cat /var/log/portage-audit.json 2>/dev/null | tail -3 || echo "No audit entries yet (run an emerge to generate them)"
```


---

## Part 22 — Ongoing Monitoring, Log Review, and Vulnerability Alerting

### 22.1 — Mail Relay with msmtp

`msmtp` is a lightweight SMTP relay client that forwards local mail to an upstream SMTP server. It is well‑suited for sending automated security reports without running a full MTA, and on Gentoo it lives in `mail-mta/msmtp`.

```bash
emerge --ask mail-mta/msmtp

# --- Option A: Proton Mail Bridge (requires Proton paid plan) ---
# The Bridge runs a local SMTP proxy on 127.0.0.1:1025 with end‑to‑end
# encryption before the message leaves your machine.
cat > /etc/msmtprc << 'EOF'
# /etc/msmtprc — msmtp configuration for Proton Mail Bridge
defaults
  auth           on
  tls            on
  tls_trust_file /etc/ssl/certs/ca-certificates.crt
  logfile        /var/log/msmtp.log

account        proton
host           127.0.0.1
port           1025
# Pin the Bridge's self‑signed certificate fingerprint.
# Obtain: openssl s_client -connect 127.0.0.1:1025 </dev/null 2>/dev/null |
#           openssl x509 -noout -fingerprint -sha256
tls_fingerprint <BRIDGE_CERT_FINGERPRINT>
from           your-address@proton.me
user           your-address@proton.me
passwordeval   cat /etc/msmtp-password

account default : proton
EOF

chmod 600 /etc/msmtprc
echo "<bridge_smtp_password>" > /etc/msmtp-password
chmod 600 /etc/msmtp-password

# --- Option B: External SMTP relay (Mailgun, Sendgrid, etc.) ---
# Replace the account block above with your relay's credentials.
# Always use implicit TLS (tls = on); avoid STARTTLS where possible.

# Test the configuration
echo "Test mail from $(hostname)" | msmtp your-address@proton.me
```

> **Note on `tls_fingerprint`**: The Bridge’s self‑signed certificate is pinned by its SHA‑256 fingerprint. If the Bridge daemon is updated or restarted, the certificate may be regenerated, requiring this value to be updated. Schedule a monthly check of the fingerprint.

---

### 22.2 — Daily Auditd Summary

The script below extracts key metrics from the audit log and emails a summary. All audit keys reference the hardened ruleset deployed in Part 18. Recipient addresses and alert thresholds are defined at the top of the script so they can be changed without modifying complex shell logic.

This script uses `ausearch --start today --end now` and `journalctl --since="today"`, both of which are well‑known patterns confirmed in the Red Hat documentation  and the `ausearch` man page reference .

```bash
cat > /usr/local/bin/daily-audit-summary.sh << 'SCRIPT'
#!/bin/bash
# Daily auditd log summary — run via systemd timer
set -euo pipefail

RECIPIENT="aahsnr041@proton.me"
HOST=$(hostname)
DATE=$(date -u +%Y-%m-%d)

# ── Gather statistics from audit log ──
# Use ausearch -m USER_AUTH for authentication events (the generic message type).
# The specific key "auth_fail" was used in the original Arch ruleset but does not
# exist in the Gentoo-adapted rules (Part 18). Searching by message type captures
# all PAM authentication attempts regardless of key.
AUTH_FAILURES=$(ausearch -m USER_AUTH --success no \
                  --start today --end now -i 2>/dev/null | grep -c "type=USER_AUTH" || echo 0)

PRIV_ESCALATIONS=$(ausearch -k sudo_cmd --start today --end now -i 2>/dev/null |
                     grep -c "type=SYSCALL" || echo 0)

MODULE_LOADS=$(ausearch -k module_load --start today --end now -i 2>/dev/null |
                 grep -c "type=SYSCALL" || echo 0)

EMERGE_EXEC=$(ausearch -k emerge_exec --start today --end now -i 2>/dev/null |
                grep -c "type=SYSCALL" || echo 0)

AA_DENIALS=$(journalctl --since="today" -t audit 2>/dev/null |
               grep -c 'apparmor="DENIED"' || echo 0)

# ── Thresholds for immediate alert ──
ALERT_THRESHOLD=10
NEEDS_ALERT=0
[[ $AUTH_FAILURES -gt $ALERT_THRESHOLD ]] && NEEDS_ALERT=1
[[ $AA_DENIALS   -gt 50              ]] && NEEDS_ALERT=1

# ── Daily summary ──
{
cat << EOF
Subject: [DAILY AUDIT] ${HOST} — ${DATE}

Daily Security Audit Summary
==============================
Host    : ${HOST}
Date    : ${DATE} UTC
Kernel  : $(uname -r)

Authentication Events:
  Failed authentications today : ${AUTH_FAILURES}
  Privilege escalations (sudo) : ${PRIV_ESCALATIONS}

Package Management:
  emerge executions today      : ${EMERGE_EXEC}

Kernel Security:
  Module load events           : ${MODULE_LOADS}

AppArmor:
  DENIED events today          : ${AA_DENIALS}

--- Recent AppArmor Denials ---
$(journalctl --since="today" -t audit 2>/dev/null |
    grep 'apparmor="DENIED"' | tail -20)

--- Recent Authentication Failures ---
$(ausearch -m USER_AUTH --success no --start today --end now -i 2>/dev/null | tail -10)

--- Recent Privilege Escalations ---
$(ausearch -k sudo_cmd --start today --end now -i 2>/dev/null | tail -10)
EOF
} | msmtp "$RECIPIENT"

# ── Immediate alert if thresholds are exceeded ──
if [[ $NEEDS_ALERT -eq 1 ]]; then
  {
  cat << ALERT
Subject: [IMMEDIATE ALERT] Security thresholds exceeded on ${HOST}

REAL-TIME SECURITY ALERT
=========================
Host: ${HOST}
Time: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

THRESHOLDS EXCEEDED:
  Auth failures today   : ${AUTH_FAILURES} (threshold: ${ALERT_THRESHOLD})
  AppArmor denials      : ${AA_DENIALS} (threshold: 50)

Immediate investigation recommended.
Run: ausearch -m USER_AUTH --start today
     journalctl -t audit | grep 'apparmor="DENIED"'
ALERT
  } | msmtp "$RECIPIENT"
fi
SCRIPT

chmod +x /usr/local/bin/daily-audit-summary.sh
```

---

### 22.3 — Weekly Security Report

The weekly GLSA scan and repository integrity check are performed by `/usr/local/bin/weekly-security-scan.sh`, which was already deployed in Part 21. That script already contains its own systemd timer and emails its results directly. No additional wrapper is needed. To verify:

```bash
systemctl status weekly-security-scan.timer
```

If the timer is not active, enable it now:

```bash
systemctl enable --now weekly-security-scan.timer
```

---

### 22.4 — Weekly AppArmor Denial Digest

Grouping AppArmor denials by profile and operation reveals patterns — a profile that suddenly generates hundreds of denials may indicate a targeted attack or a misconfiguration that needs immediate attention. The `aa-logprof` tool (from `app‑armor/apparmor‑utils`) is the recommended interactive tool for inspecting denials and suggesting profile updates .

```bash
cat > /usr/local/bin/weekly-apparmor-digest.sh << 'SCRIPT'
#!/bin/bash
# Weekly AppArmor denial digest — run via systemd timer
set -euo pipefail

RECIPIENT="aahsnr041@proton.me"
HOST=$(hostname)
WEEK_START=$(date -u -d "7 days ago" +"%Y-%m-%d")
WEEK_END=$(date -u +"%Y-%m-%d")

# Collect and group denials by profile → operation
DENIALS=$(journalctl --since="${WEEK_START}" --until="${WEEK_END}" \
            -t audit 2>/dev/null |
            grep 'apparmor="DENIED"' |
            sed 's/.*profile="\([^"]*\)".*operation="\([^"]*\)".*/\1 → \2/' |
            sort | uniq -c | sort -rn | head -50)

{
cat << EOF
Subject: [WEEKLY APPARMOR] Denial Digest — ${HOST} — ${WEEK_END}

Weekly AppArmor Denial Digest
================================
Host  : ${HOST}
Period: ${WEEK_START} to ${WEEK_END}

Denials grouped by profile → operation (count):
-------------------------------------------------
${DENIALS}

To investigate a specific profile:
  journalctl -t audit | grep 'profile="<name>"' | grep DENIED
  aa-logprof

To view full denial details:
  ausearch --start week --end now | grep AVC
EOF
} | msmtp "$RECIPIENT"
SCRIPT

chmod +x /usr/local/bin/weekly-apparmor-digest.sh
```

---

### 22.5 — Systemd Timers for Automated Reports

```bash
# ── Daily audit report (06:00 UTC) ──
cat > /etc/systemd/system/daily-audit-report.service << 'EOF'
[Unit]
Description=Daily Security Audit Report
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/daily-audit-summary.sh
User=root
EOF

cat > /etc/systemd/system/daily-audit-report.timer << 'EOF'
[Unit]
Description=Run daily audit report at 06:00 UTC

[Timer]
OnCalendar=*-*-* 06:00:00 UTC
Persistent=true

[Install]
WantedBy=timers.target
EOF

# ── Weekly AppArmor digest (Monday 07:30 UTC) ──
cat > /etc/systemd/system/weekly-apparmor-digest.service << 'EOF'
[Unit]
Description=Weekly AppArmor Denial Digest

[Service]
Type=oneshot
ExecStart=/usr/local/bin/weekly-apparmor-digest.sh
User=root
EOF

cat > /etc/systemd/system/weekly-apparmor-digest.timer << 'EOF'
[Unit]
Description=Run weekly AppArmor digest every Monday at 07:30 UTC

[Timer]
OnCalendar=Mon *-*-* 07:30:00 UTC
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now daily-audit-report.timer
systemctl enable --now weekly-apparmor-digest.timer
```

> **Note on `Persistent=true`**: This option ensures that if the system was powered off at the scheduled time, the timer will fire immediately after the next boot . This is the systemd equivalent of `anacron` and is available since systemd 212 .

---

### 22.6 — Verification

```bash
# List all enabled timers
systemctl list-timers --all | grep -E "audit|apparmor|security"

# Trigger the daily summary manually (for testing)
systemctl start daily-audit-report.service

# Verify msmtp works
echo "Test from $(hostname)" | msmtp -v your-address@proton.me

# Verify AppArmor logging is active
aa-status | head -5
```


---

## Part 23 – systemd Service Hardening

System‑level service confinement complements AppArmor and bubblewrap by restricting daemons at the service‑manager level, before the binary even starts. This tool automates analysis, interactive hardening, SHH‑based profiling, testing, rollback, and bisection.

### 24.1 – Prerequisites

| Component | Package / Install Command | Purpose |
|-----------|--------------------------|---------|
| Python 3.11+ | already present | Runtime for the script |
| `systemd‑analyze` | part of `sys‑apps/systemd` | Security analysis |
| `strace` ≥ 6.6 | `emerge --ask dev-util/strace` | Required by SHH |
| SHH (optional) | `cargo install --root /usr/local systemd-hardening-helper` | Behaviour‑based profiler |

If SHH is not installed, the `profile` subcommand will print an error with the exact installation instructions and exit.

---

### 24.2 – The Integrated `svc‑harden.py` Script

Save to `/usr/local/bin/svc‑harden.py` and make it executable:

```bash
nano /usr/local/bin/svc‑harden.py
chmod +x /usr/local/bin/svc‑harden.py
```

```python
#!/usr/bin/env python3
"""
svc‑harden.py – systemd Service Security Hardening Tool
Gentoo Hardened – APT‑Level Hardening Guide, April 2026

Subcommands
───────────
  analyze <service>    Print exposure score and missing directives.
  apply <service>      Interactively apply hardening directives via a drop‑in.
  profile <service>    Profile the running service with SHH (Systemd Hardening
                       Helper) and review the generated recommendations.
  test <service>       Restart the service and (optionally) run a validation
                       command to verify functionality.
  revert <service>     Remove the hardening drop‑in and restore the service.
  bisect <service>     Identify which directive broke a service.
  log                  Show the NDJSON audit log of all changes.

Examples
────────
  svc‑harden.py analyze sshd.service
  svc‑harden.py apply cockpit.service
  svc‑harden.py profile nginx.service --apply
  svc‑harden.py test cockpit.service --test‑cmd "curl ‑k https://localhost:9090"
  svc‑harden.py revert NetworkManager.service
  svc‑harden.py bisect sshd.service
  svc‑harden.py log

Important
─────────
  This tool REFUSES to operate on ‘all’ or wildcard service patterns.
  Hardening directives are service‑specific; blanket application causes
  breakage.  All changes are recorded in an NDJSON audit log at
  /var/log/svc‑harden‑audit.json.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import textwrap
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

# ──────────────────────────────────────────────────────────────────────────────
# Data structures
# ──────────────────────────────────────────────────────────────────────────────

@dataclass(frozen=True)
class HardeningDirective:
    """One systemd hardening directive with compatibility hints.

    Attributes:
        name:             systemd.exec(5) directive name
        default_value:    suggested value (both ‘yes’ and ‘true’ are valid
                          booleans per systemd.syntax(7))
        description:      human‑readable purpose
        incompatible_with: categories of services that may break if this
                          directive is applied
    """
    name: str
    default_value: str
    description: str
    incompatible_with: list[str] = field(default_factory=list)


# ──────────────────────────────────────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────────────────────────────────────

DROPIN_BASE: Path = Path("/etc/systemd/system")
AUDIT_LOG: Path = Path("/var/log/svc‑harden‑audit.json")
SHH_BINARY: str = "shh"

# All directives are documented in systemd.exec(5).
# Boolean values ‘yes’/‘no’ (preferred) and ‘true’/‘false’ are both valid;
# we normalise to ‘yes’/‘no’ in the drop‑in because systemd‑analyze displays
# them that way and gentoo systemd uses the same convention.
HARDENING_DIRECTIVES: list[HardeningDirective] = [
    HardeningDirective("NoNewPrivileges", "yes",
                       "Prevent gaining new privileges via setuid/setgid/capabilities"),
    HardeningDirective("PrivateTmp", "yes",
                       "Give the service a private /tmp and /var/tmp"),
    HardeningDirective("PrivateDevices", "yes",
                       "Restrict /dev access",
                       ["bluetooth", "audio", "video", "gpu"]),
    HardeningDirective("PrivateNetwork", "yes",
                       "Disconnect from all network interfaces",
                       ["network", "dns", "web", "mail"]),
    HardeningDirective("PrivateUsers", "yes",
                       "Separate UID namespace",
                       ["setuid", "chown", "CAP_SETUID"]),
    HardeningDirective("ProtectSystem", "strict",
                       "Mount /usr, /boot, /efi read‑only; /etc read‑only"),
    HardeningDirective("ProtectHome", "yes",
                       "Make /home, /root, /run/user inaccessible",
                       ["home_access", "user_data"]),
    HardeningDirective("ProtectHostname", "yes",
                       "Prevent hostname changes"),
    HardeningDirective("ProtectClock", "yes",
                       "Prevent clock changes",
                       ["ntp", "time_sync"]),
    HardeningDirective("ProtectKernelTunables", "yes",
                       "Make /proc/sys read‑only"),
    HardeningDirective("ProtectKernelModules", "yes",
                       "Prevent loading/unloading kernel modules"),
    HardeningDirective("ProtectKernelLogs", "yes",
                       "Prevent access to /proc/kmsg and /dev/kmsg"),
    HardeningDirective("ProtectControlGroups", "yes",
                       "Make cgroup filesystem read‑only"),
    HardeningDirective("RestrictAddressFamilies", "AF_UNIX AF_INET AF_INET6",
                       "Restrict socket address families"),
    HardeningDirective("RestrictNamespaces", "yes",
                       "Prevent creation of new namespaces",
                       ["containers", "bubblewrap"]),
    HardeningDirective("RestrictRealtime", "yes",
                       "Prevent real‑time scheduling",
                       ["realtime", "audio_pro", "pipewire"]),
    HardeningDirective("RestrictSUIDSGID", "yes",
                       "Prevent creation of setuid/setgid files"),
    HardeningDirective("LockPersonality", "yes",
                       "Prevent changing ABI personality"),
    HardeningDirective("MemoryDenyWriteExecute", "yes",
                       "Prevent W^X memory",
                       ["jit", "mono", "java", "llvm_jit"]),
    HardeningDirective("RemoveIPC", "yes",
                       "Remove SysV IPC objects when service stops"),
    HardeningDirective("SystemCallArchitectures", "native",
                       "Only allow native‑architecture syscalls",
                       ["wine", "32bit_compat"]),
    HardeningDirective("SystemCallFilter", "@system‑service",
                       "Whitelist only standard service syscalls"),
    HardeningDirective("CapabilityBoundingSet", "",
                       "Drop ALL capabilities",
                       ["caps_needed"]),
    HardeningDirective("AmbientCapabilities", "",
                       "Clear ambient capabilities"),
    HardeningDirective("UMask", "0077",
                       "Owner‑only new files/dirs"),
    HardeningDirective("IPAddressDeny", "any",
                       "Block all IP communication",
                       ["network", "dns"]),
    HardeningDirective("ProtectProc", "invisible",
                       "Hide other processes’ /proc entries"),
    HardeningDirective("ProcSubset", "pid",
                       "Only expose PID subtree of /proc"),
]

# Mapping of SHH output keys to canonical directive names (for the ‘profile’
# subcommand).  Keys not in this mapping are displayed in an ‘additional
# recommendations’ block for manual review.
SHH_KEY_MAP: dict[str, str] = {
    "ProtectSystem":           "ProtectSystem",
    "ProtectHome":             "ProtectHome",
    "PrivateTmp":              "PrivateTmp",
    "PrivateDevices":          "PrivateDevices",
    "PrivateNetwork":          "PrivateNetwork",
    "ProtectKernelTunables":   "ProtectKernelTunables",
    "ProtectKernelModules":    "ProtectKernelModules",
    "ProtectKernelLogs":       "ProtectKernelLogs",
    "ProtectControlGroups":    "ProtectControlGroups",
    "ProtectClock":            "ProtectClock",
    "ProtectProc":             "ProtectProc",
    "LockPersonality":         "LockPersonality",
    "RestrictRealtime":        "RestrictRealtime",
    "MemoryDenyWriteExecute":  "MemoryDenyWriteExecute",
    "RestrictAddressFamilies": "RestrictAddressFamilies",
    "SystemCallFilter":        "SystemCallFilter",
    "SystemCallArchitectures": "SystemCallArchitectures",
    "CapabilityBoundingSet":   "CapabilityBoundingSet",
    "NoNewPrivileges":         "NoNewPrivileges",
    "UMask":                   "UMask",
    "IPAddressDeny":           "IPAddressDeny",
    "ProcSubset":              "ProcSubset",
}

# Patterns refused by all subcommands that accept a service name.
BULK_PATTERNS: frozenset[str] = frozenset({"all", "*", "*.service",
                                           "everything"})


# ──────────────────────────────────────────────────────────────────────────────
# Utility helpers
# ──────────────────────────────────────────────────────────────────────────────

def log_action(action: str, service: str, details: dict[str, object],
               *, dry_run: bool = False) -> None:
    """Append a single NDJSON record to the audit log.

    *dry_run* being True suppresses writing and only prints what would be
    recorded.
    """
    if dry_run:
        print(f"[DRY‑RUN] Would log: action={action} service={service}")
        return
    entry = {
        "timestamp": datetime.datetime.now(tz=datetime.timezone.utc).isoformat(),
        "action": action,
        "service": service,
        "uid": os.getuid(),
        "pid": os.getpid(),
        "details": details,
    }
    try:
        AUDIT_LOG.parent.mkdir(parents=True, exist_ok=True)
        with open(AUDIT_LOG, "a", encoding="utf‑8") as fh:
            fh.write(json.dumps(entry) + "\n")
    except OSError as exc:
        print(f"[WARN] Cannot write audit log: {exc}", file=sys.stderr)


def _resolve_service(service: str) -> str:
    """Ensure *service* ends with a recognised systemd unit suffix."""
    if not service.endswith((".service", ".socket", ".timer", ".mount")):
        return service + ".service"
    return service


def dropin_path(service: str) -> Path:
    """Return the filesystem path to the hardening drop‑in for *service*."""
    return DROPIN_BASE / f"{_resolve_service(service)}.d" / "hardening.conf"


def run(cmd: list[str], *, check: bool = True,
        capture: bool = False,
        timeout: int | None = None) -> subprocess.CompletedProcess[str]:
    """Thin wrapper around subprocess.run with default text=True and
    shell=False (security best practice)."""
    print(f"  $ {' '.join(cmd)}")
    return subprocess.run(cmd, check=check, capture_output=capture,
                          text=True, timeout=timeout)


def reload_systemd() -> None:
    """Tell systemd to reload its unit database."""
    run(["systemctl", "daemon‑reload"])


def service_status(service: str) -> str:
    """Return the current ActiveState of *service*."""
    res = subprocess.run(
        ["systemctl", "is‑active", service],
        capture_output=True, text=True, check=False,
    )
    return res.stdout.strip()


def restart_service(service: str) -> bool:
    """Restart *service* and return True if it came back ‘active’."""
    run(["systemctl", "restart", service], check=False)
    time.sleep(2)
    state = service_status(service)
    if state == "active":
        print(f"  ✅  {service} is active after restart")
        return True
    print(f"  ❌  {service} is {state} after restart")
    return False


def _read_choice(prompt: str) -> str:
    """Read a single line of user input, handling EOF and SIGINT."""
    try:
        return input(prompt).strip().lower()
    except (EOFError, KeyboardInterrupt):
        print("\n  Aborted.")
        return ""


def _parse_exposure_score(text: str) -> str | None:
    """Extract the numeric exposure score from systemd‑analyze output.

    The output format is explicitly documented as *not* stable
    (systemd‑analyze(1)), so we use a robust regex that matches several
    observed patterns:
        → 5.2 EXPOSED
        → 1.4 OK
        → 7.8 MEDIUM
    """
    m = re.search(r"→\s*([\d]+(?:\.[\d]+)?)\s+(EXPOSED|OK|MEDIUM|UNSAFE|SAFE)",
                  text, re.IGNORECASE)
    if m is None:
        return None
    return m.group(1)


# ──────────────────────────────────────────────────────────────────────────────
# SHH helpers (used by the ‘profile’ subcommand)
# ──────────────────────────────────────────────────────────────────────────────

def _shh_available() -> bool:
    """Return True if the shh binary can be found on PATH."""
    return shutil.which(SHH_BINARY) is not None


def _parse_shh_output(text: str) -> dict[str, str]:
    """Extract SHH recommendations from its stdout/stderr.

    SHH emits recommendations between two markers:
        -------- Start of suggested service options --------
        ProtectSystem=strict
        ProtectHome=true
        ...
        -------- End of suggested service options --------

    The marker text may include an invocation ID in newer versions:
        -------- Start of suggested service options for a1b2c3d4... --------
    We therefore use a substring match on ``"Start of suggested"``.
    """
    recs: dict[str, str] = {}
    in_block = False
    for line in text.splitlines():
        stripped = line.strip()
        if "Start of suggested" in stripped:
            in_block = True
            continue
        if "End of suggested" in stripped:
            break
        if in_block and "=" in stripped:
            key, _, value = stripped.partition("=")
            recs[key.strip()] = value.strip()
    return recs


def _run_shh_profile(service: str, mode: str, *, filesystem: bool,
                     network: bool) -> dict[str, str]:
    """Profile *service* with SHH and return the parsed recommendations.

    The service is restarted twice: once to begin profiling and once to
    finish profiling and generate the recommended options.
    """
    service = _resolve_service(service)

    if not _shh_available():
        print("ERROR: SHH (Systemd Hardening Helper) is not installed.",
              file=sys.stderr)
        print("  Install Rust toolchain and then:", file=sys.stderr)
        print("  cargo install --root /usr/local systemd‑hardening‑helper",
              file=sys.stderr)
        print("  Ensure dev‑util/strace is emerged (≥ 6.6).",
              file=sys.stderr)
        sys.exit(1)

    print(f"\n  Starting SHH profiling for {service} …")
    run(["shh", "service", "start‑profile", service])

    print("\n  ═══ PROFILING ACTIVE ═══")
    print(f"  {service} is now being traced with strace.")
    print("  Please exercise the service – perform all its normal operations.")
    _ = input("  Press ENTER when you are finished …")

    finish_cmd = ["shh", "service", "finish‑profile", service]
    if mode == "aggressive":
        finish_cmd += ["‑‑mode", "aggressive"]
    if filesystem:
        finish_cmd.append("‑‑filesystem‑whitelisting")
    if network:
        finish_cmd.append("‑‑network‑firewalling")

    print(f"\n  Finishing profiling …")
    result = run(finish_cmd, check=False, capture=True)
    combined = (result.stdout or "") + (result.stderr or "")

    recs = _parse_shh_output(combined)
    if not recs:
        print("  WARNING: SHH did not produce any recommendations.")
    else:
        print(f"  SHH produced {len(recs)} recommendation(s).")
    return recs


# ──────────────────────────────────────────────────────────────────────────────
# Subcommand: analyze
# ──────────────────────────────────────────────────────────────────────────────

def cmd_analyze(service: str, *, dry_run: bool = False) -> int:
    """Show current exposure score and list missing directives."""
    service = _resolve_service(service)
    print(f"\n{'═'*70}\n  SECURITY ANALYSIS: {service}\n{'═'*70}\n")

    res = subprocess.run(
        ["systemd‑analyze", "security", "‑‑no‑pager", service],
        capture_output=True, text=True, check=False,
    )
    print(res.stdout)
    if res.returncode != 0:
        print(res.stderr, file=sys.stderr)

    score = _parse_exposure_score(res.stdout)
    if score is not None:
        print(f"\n  Current exposure score: {score}/10.0")

    print(f"\n  {'─'*66}")
    print("  RECOMMENDED HARDENING DIRECTIVES (in priority order)")
    print(f"  {'─'*66}\n")

    for i, d in enumerate(HARDENING_DIRECTIVES, 1):
        check = subprocess.run(
            ["systemctl", "show", service, f"‑‑property={d.name}"],
            capture_output=True, text=True, check=False,
        )
        current = check.stdout.strip().partition("=")[2] \
                  if "=" in check.stdout else ""
        if current in ("", "(not set)") \
           or current.lower() in ("no", "false", "0"):
            compat = ""
            if d.incompatible_with:
                compat = (f" [CAUTION: may break "
                          f"{', '.join(d.incompatible_with)}]")
            print(f"  {i:2d}. {d.name}={d.default_value}")
            print(f"      {d.description}{compat}\n")

    log_action("analyze", service, {}, dry_run=dry_run)
    return 0


# ──────────────────────────────────────────────────────────────────────────────
# Shared commit logic
# ──────────────────────────────────────────────────────────────────────────────

def _write_and_restart(service: str, dropin: Path,
                       selected: dict[str, str], *, dry_run: bool) -> int:
    """Write the drop‑in file, reload systemd, and restart the service."""
    ts = datetime.datetime.now().isoformat()
    header = textwrap.dedent(f"""\
        # {dropin}
        # Generated by svc‑harden.py at {ts}
        # Remove with: svc‑harden.py revert {service}

        [Service]
    """)
    content = header + "".join(f"{k}={v}\n" for k, v in selected.items())

    print(f"\n  {'─'*66}")
    print("  PREVIEW OF DROP‑IN CONTENT")
    print(f"  {'─'*66}")
    print(content)

    confirm = _read_choice(
        "  Write this drop‑in and restart the service? [y/N]: ")
    if confirm != "y":
        print("  Aborted – nothing written.")
        return 0

    if dry_run:
        print(f"  [DRY‑RUN] Would write {dropin} and restart {service}")
        log_action("apply_dry_run", service, {"directives": selected},
                   dry_run=True)
        return 0

    dropin.parent.mkdir(parents=True, exist_ok=True)
    dropin.write_text(content, encoding="utf‑8")
    print(f"  ✅  Written: {dropin}")

    reload_systemd()
    success = restart_service(service)

    log_action("apply", service, {
        "directives": selected,
        "dropin": str(dropin),
        "restart_success": success,
    })

    if not success:
        print(f"\n  ⚠️  Service failed after hardening.")
        print(f"  Run: svc‑harden.py bisect {service}")
        return 1

    print("\n  Running post‑apply security analysis …")
    run(["systemd‑analyze", "security", "‑‑no‑pager", service], check=False)
    return 0


# ──────────────────────────────────────────────────────────────────────────────
# Subcommand: apply
# ──────────────────────────────────────────────────────────────────────────────

def _interactive_select(service: str) -> dict[str, str]:
    """Run the interactive prompt loop and return selected directives."""
    selected: dict[str, str] = {}
    for d in HARDENING_DIRECTIVES:
        compat = ""
        if d.incompatible_with:
            compat = (f"\n  ⚠️  May break: "
                      f"{', '.join(d.incompatible_with)}")
        print(f"\n  Directive : {d.name}")
        print(f"  Value     : {d.default_value}")
        print(f"  Purpose   : {d.description}{compat}")

        choice = _read_choice("  Apply? [y/N/e(dit)]: ")
        if choice == "y":
            selected[d.name] = d.default_value
            print(f"  ✅  {d.name}={d.default_value}")
        elif choice == "e":
            custom = _read_choice(f"  Enter value for {d.name}: ")
            if custom:
                selected[d.name] = custom
                print(f"  ✅  {d.name}={custom} (custom)")
            else:
                print("  ⏭   Skipped")
        else:
            print("  ⏭   Skipped")
    return selected


def cmd_apply(service: str, *, dry_run: bool = False) -> int:
    """Interactively apply hardening directives via a drop‑in file."""
    service = _resolve_service(service)
    dropin = dropin_path(service)

    print(f"\n{'═'*70}\n  APPLY HARDENING: {service}\n{'═'*70}")
    print(f"\n  Drop‑in: {dropin}")
    print("  Review each directive.  [y] apply  [N] skip  [e] edit value.\n")

    selected = _interactive_select(service)
    if not selected:
        print("\n  No directives selected. Nothing to write.")
        return 0

    return _write_and_restart(service, dropin, selected, dry_run=dry_run)


# ──────────────────────────────────────────────────────────────────────────────
# Subcommand: profile  (SHH‑based)
# ──────────────────────────────────────────────────────────────────────────────

def cmd_profile(service: str, *, apply: bool = False,
                mode: str = "safe", filesystem: bool = False,
                network: bool = False, dry_run: bool = False) -> int:
    """Profile a service with SHH and review the generated recommendations
    before applying."""
    service = _resolve_service(service)

    if dry_run:
        print(f"[DRY‑RUN] Would profile {service} with SHH")
        return 0

    recs = _run_shh_profile(service, mode, filesystem=filesystem,
                            network=network)
    if not recs:
        return 1

    # Separate recognised (matched) SHH keys from unrecognised ones.
    matched: dict[str, str] = {}
    unmatched: dict[str, str] = {}
    for key, val in recs.items():
        canonical = SHH_KEY_MAP.get(key)
        if canonical is not None:
            matched[canonical] = val
        else:
            unmatched[key] = val

    # Display SHH recommendations.
    print(f"\n  {'─'*66}")
    print("  SHH RECOMMENDATIONS (automatically pre‑selected)")
    print(f"  {'─'*66}")
    for name in sorted(matched):
        print(f"  ✅  {name} = {matched[name]}")

    if unmatched:
        print(f"\n  {'─'*66}")
        print("  ADDITIONAL SHH DIRECTIVES (review carefully)")
        print(f"  {'─'*66}")
        for key in sorted(unmatched):
            print(f"  ⬜  {key} = {unmatched[key]}")
        print("\n  These advanced path / socket directives are not part of")
        print("  the standard interactive list but can be applied as‑is.")

    # Allow the user to edit the final set before applying.
    print(f"\n  {'─'*66}")
    print("  REVIEW AND EDIT BEFORE APPLYING")
    print(f"  {'─'*66}")

    final: dict[str, str] = dict(matched)

    while True:
        print("\n  Current selection:")
        if not final:
            print("    (none)")
        else:
            for k, v in sorted(final.items()):
                print(f"    {k} = {v}")

        print("\n  [a]pply   [t]oggle a directive   "
              "[r]eset to SHH defaults   [q]uit")
        choice = _read_choice("  Choice: ")
        if choice == "a":
            break
        elif choice == "t":
            target = input("  Directive name (or unmatched key): ").strip()
            if target in final:
                print(f"  Removing {target}")
                del final[target]
            elif target in matched:
                final[target] = matched[target]
                print(f"  Added {target} = {matched[target]}")
            elif target in unmatched:
                val = unmatched[target]
                final[target] = val
                print(f"  Added {target} = {val}")
            else:
                print(f"  Unknown directive ‘{target}’")
        elif choice == "r":
            final = dict(matched)
            print("  Reset to SHH defaults.")
        elif choice == "q":
            print("  Aborted.")
            return 0
        else:
            print("  Unknown choice.")

    if not final:
        print("\n  No directives selected. Nothing to write.")
        return 0

    if not apply:
        print("\n  Use ‑‑apply to write this configuration.")
        return 0

    dropin = dropin_path(service)
    return _write_and_restart(service, dropin, final, dry_run=dry_run)


# ──────────────────────────────────────────────────────────────────────────────
# Subcommand: test
# ──────────────────────────────────────────────────────────────────────────────

def cmd_test(service: str, test_cmd: str | None = None,
             *, dry_run: bool = False) -> int:
    """Restart the service and optionally run a validation command."""
    service = _resolve_service(service)
    print(f"\n{'═'*70}\n  TESTING: {service}\n{'═'*70}\n")

    if dry_run:
        print(f"  [DRY‑RUN] Would restart {service} and check status")
        return 0

    if not restart_service(service):
        log_action("test", service, {"status": "failed",
                                      "test_cmd": test_cmd})
        return 1

    print(f"\n  Recent journal entries for {service}:")
    run(["journalctl", "‑u", service, "‑‑no‑pager", "‑n", "20"],
        check=False)

    if test_cmd:
        print(f"\n  Running test command: {test_cmd}")
        success = False
        try:
            res = subprocess.run(test_cmd, shell=True, check=False,
                                 timeout=30)
            success = res.returncode == 0
            if success:
                print("  ✅  Test command succeeded")
            else:
                print(f"  ❌  Test command failed (rc={res.returncode})")
        except subprocess.TimeoutExpired:
            print("  ❌  Test command timed out after 30 s")
        log_action("test", service, {"status": "passed" if success
                                      else "failed", "test_cmd": test_cmd})
        return 0 if success else 1

    log_action("test", service, {"status": "passed_restart_only",
                                  "test_cmd": None})
    return 0


# ──────────────────────────────────────────────────────────────────────────────
# Subcommand: revert
# ──────────────────────────────────────────────────────────────────────────────

def cmd_revert(service: str, *, dry_run: bool = False) -> int:
    """Remove the hardening drop‑in and restore the original service state."""
    service = _resolve_service(service)
    dropin = dropin_path(service)

    print(f"\n{'═'*70}\n  REVERTING HARDENING: {service}\n{'═'*70}\n")
    if not dropin.exists():
        print(f"  No hardening drop‑in found at {dropin}")
        return 0

    print("  Current drop‑in contents:")
    print(dropin.read_text())

    if _read_choice(f"  Delete {dropin} and restart {service}? [y/N]: ") \
       != "y":
        print("  Aborted.")
        return 0

    if dry_run:
        print(f"  [DRY‑RUN] Would delete {dropin} and restart {service}")
        return 0

    dropin.unlink()
    try:
        dropin.parent.rmdir()
    except OSError:
        pass  # directory not empty – keep it

    reload_systemd()
    success = restart_service(service)
    log_action("revert", service, {"dropin_removed": str(dropin),
                                   "restart_success": success})
    return 0 if success else 1


# ──────────────────────────────────────────────────────────────────────────────
# Subcommand: bisect
# ──────────────────────────────────────────────────────────────────────────────

def cmd_bisect(service: str, *, dry_run: bool = False) -> int:
    """Identify which hardening directive caused a service failure."""
    service = _resolve_service(service)
    dropin = dropin_path(service)

    print(f"\n{'═'*70}\n  BISECT MODE: {service}\n{'═'*70}\n")
    if not dropin.exists():
        print(f"  No hardening drop‑in found at {dropin}")
        return 0

    original = dropin.read_text(encoding="utf‑8")
    directives: list[tuple[str, str]] = []
    for line in original.splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith("#") and "=" in stripped:
            k, v = stripped.split("=", 1)
            if k.strip() not in ("[Service]", "[Unit]", "[Install]"):
                directives.append((k.strip(), v.strip()))

    if not directives:
        print("  Drop‑in contains no directives to bisect.")
        return 0

    print(f"  Found {len(directives)} directive(s).")
    culprit: tuple[str, str] | None = None

    for i, (name, _) in enumerate(directives, 1):
        print(f"  [{i}/{len(directives)}] Testing with ‘{name}’ DISABLED …")
        new_lines: list[str] = []
        skipped = False
        for line in original.splitlines():
            stripped = line.strip()
            if not skipped and stripped.startswith(name + "="):
                new_lines.append(f"# BISECT_DISABLED: {line}")
                skipped = True
            else:
                new_lines.append(line)

        if not dry_run:
            dropin.write_text("\n".join(new_lines), encoding="utf‑8")
            reload_systemd()
            success = restart_service(service)
        else:
            success = True

        if success:
            print(f"  ✅  Service recovered when ‘{name}’ was disabled.")
            culprit = (name, directives[i‑1][1])
            if not dry_run:
                dropin.write_text(original, encoding="utf‑8")
                reload_systemd()
            break
        else:
            if not dry_run:
                dropin.write_text(original, encoding="utf‑8")
                reload_systemd()
            print("  ❌  Service still broken. Continuing …\n")

    if culprit is None:
        print("\n  ⚠️  Could not isolate a single culprit directive.")
        print(f"  Use ‘svc‑harden.py revert {service}’ to remove all "
              f"hardening.")
        log_action("bisect", service, {"result": "no_culprit_found"})
        return 1

    print(f"\n  CULPRIT IDENTIFIED: {culprit[0]} = {culprit[1]}")
    print("  [a] Remove only this directive")
    print("  [b] Revert ALL hardening")
    print("  [c] Leave as‑is")
    choice = _read_choice("  Choice [a/b/c]: ")

    if choice == "a":
        if dry_run:
            print(f"  [DRY‑RUN] Would remove ‘{culprit[0]}’")
            return 0
        new_lines = [l for l in original.splitlines()
                     if not l.strip().startswith(culprit[0] + "=")]
        dropin.write_text("\n".join(new_lines), encoding="utf‑8")
        reload_systemd()
        restart_service(service)
        log_action("bisect_partial_revert", service,
                   {"removed_directive": culprit[0]})
        print(f"  ✅  Removed ‘{culprit[0]}’; service running.")
        return 0
    elif choice == "b":
        return cmd_revert(service, dry_run=dry_run)
    else:
        print("  Drop‑in unchanged.")
        log_action("bisect_no_action", service, {"culprit": culprit[0]})
        return 0


# ──────────────────────────────────────────────────────────────────────────────
# Subcommand: log
# ──────────────────────────────────────────────────────────────────────────────

def cmd_log() -> int:
    """Display the NDJSON audit log."""
    if not AUDIT_LOG.exists():
        print(f"No audit log found at {AUDIT_LOG}")
        return 0
    try:
        lines = AUDIT_LOG.read_text(encoding="utf‑8").splitlines()
    except OSError as exc:
        print(f"Cannot read audit log: {exc}", file=sys.stderr)
        return 1

    print(f"\n{'═'*70}\n  SVC‑HARDEN AUDIT LOG ({len(lines)} entries)"
          f"\n{'═'*70}\n")
    for line in lines:
        try:
            entry = json.loads(line)
            ts = entry.get("timestamp", "?")
            action = entry.get("action", "?")
            service = entry.get("service", "?")
            details = entry.get("details", {})
            print(f"  {ts}  [{action:25s}] {service}")
            for k, v in details.items():
                print(f"              {k}: {v}")
        except json.JSONDecodeError:
            print(f"  [PARSE ERROR] {line[:80]}")
    print()
    return 0


# ──────────────────────────────────────────────────────────────────────────────
# CLI entry point
# ──────────────────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    """Construct the full argparse hierarchy."""
    parser = argparse.ArgumentParser(
        prog="svc‑harden.py",
        description="systemd service hardening tool – single services only",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
            Bulk hardening is REFUSED.  Always specify a single service unit.

            Examples:
              svc‑harden.py analyze sshd.service
              svc‑harden.py apply cockpit.service
              svc‑harden.py profile nginx.service ‑‑apply
              svc‑harden.py test cockpit.service ‑‑test‑cmd "curl ‑k https://localhost:9090"
              svc‑harden.py revert NetworkManager.service
              svc‑harden.py bisect sshd.service
              svc‑harden.py log
        """),
    )
    parser.add_argument("‑‑dry‑run", action="store_true",
                        help="Simulate without making changes")

    sub = parser.add_subparsers(dest="command", required=True)

    # analyze
    pa = sub.add_parser("analyze",
                         help="Show exposure score and missing directives")
    pa.add_argument("service")

    # apply
    pap = sub.add_parser("apply",
                         help="Interactively apply hardening directives")
    pap.add_argument("service")

    # profile (SHH)
    ppr = sub.add_parser("profile",
                         help="Profile with SHH and review recommendations")
    ppr.add_argument("service")
    ppr.add_argument("‑‑apply", action="store_true",
                     help="Write the drop‑in after review "
                          "(otherwise preview only)")
    ppr.add_argument("‑‑mode", choices=("safe", "aggressive"),
                     default="safe",
                     help="SHH hardening mode (default: safe)")
    ppr.add_argument("‑‑filesystem‑whitelisting", action="store_true",
                     help="Use SHH filesystem whitelisting (very strict)")
    ppr.add_argument("‑‑network‑firewalling", action="store_true",
                     help="Use SHH network firewalling (very strict)")

    # test
    pt = sub.add_parser("test", help="Test a hardened service")
    pt.add_argument("service")
    pt.add_argument("‑‑test‑cmd", metavar="CMD",
                    help="Shell command to validate functionality")

    # revert
    pr = sub.add_parser("revert", help="Remove hardening drop‑in")
    pr.add_argument("service")

    # bisect
    pb = sub.add_parser("bisect",
                        help="Find which directive broke the service")
    pb.add_argument("service")

    # log
    sub.add_parser("log", help="Show audit log of all changes")

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    dry_run: bool = args.dry_run

    if args.command == "log":
        return cmd_log()

    service: str = args.service
    if service in BULK_PATTERNS or "*" in service or service == "":
        print("❌  REFUSED: bulk / wildcard service hardening is not "
              "supported.",
              file=sys.stderr)
        return 1

    if (os.geteuid() != 0
            and args.command in ("apply", "profile", "revert", "bisect")
            and not dry_run):
        print("ERROR: This command requires root (use sudo).",
              file=sys.stderr)
        return 1

    match args.command:
        case "analyze":
            return cmd_analyze(service, dry_run=dry_run)
        case "apply":
            return cmd_apply(service, dry_run=dry_run)
        case "profile":
            return cmd_profile(
                service,
                apply=getattr(args, "apply", False),
                mode=getattr(args, "mode", "safe"),
                filesystem=getattr(args, "filesystem_whitelisting", False),
                network=getattr(args, "network_firewalling", False),
                dry_run=dry_run,
            )
        case "test":
            return cmd_test(service, getattr(args, "test_cmd", None),
                            dry_run=dry_run)
        case "revert":
            return cmd_revert(service, dry_run=dry_run)
        case "bisect":
            return cmd_bisect(service, dry_run=dry_run)
        case _:
            parser.print_help()
            return 1


if __name__ == "__main__":
    sys.exit(main())
```

---

### 24.3 – Detailed Usage Walkthrough

Below is a step‑by‑step guide through every subcommand of `svc‑harden.py`.  All examples assume you are root (use `sudo`) and that the script is installed at `/usr/local/bin/svc‑harden.py`.  For brevity, the service `cockpit.service` is used as a running example, but the same workflow applies to any systemd service.

---

#### 24.3.1 – Preliminaries

1.  **Ensure the service is running** – `svc‑harden.py apply`, `profile`, and `test` will restart the service; it must be in a working baseline state first.
    ```bash
    systemctl start cockpit.service
    systemctl status cockpit.service
    ```

2.  **Verify SHH availability (if you plan to profile)**:
    ```bash
    shh --version   # should print "Systemd hardening helper X.Y.Z"
    ```
    If it is missing, install it with `cargo install --root /usr/local systemd-hardening-helper` and ensure `dev-util/strace` is emerged.

---

#### 24.3.2 – `analyze` – See What Can Be Improved

This is the first command to run on any service.  It does **not** modify anything; it only prints the current exposure score and lists every directive from our hardening table that is currently absent or set to an insecure value.

```bash
sudo svc‑harden.py analyze cockpit.service
```

**Expected output** (truncated):
```
══════════════════════════════════════════════════════════════════════
  SECURITY ANALYSIS: cockpit.service
══════════════════════════════════════════════════════════════════════

  Exposure score: 7.2 EXPOSED  (or similar)

  ──────────────────────────────────────────────────
  RECOMMENDED HARDENING DIRECTIVES (in priority order)
  ──────────────────────────────────────────────────

   1. NoNewPrivileges=yes
      Prevent gaining new privileges via setuid/setgid/capabilities

   2. PrivateTmp=yes
      Give the service a private /tmp and /var/tmp

   3. PrivateDevices=yes
      Restrict /dev access
      [CAUTION: may break bluetooth, audio, video, gpu]

   ...
```

**How to read this**:  
- The **exposure score** is a unit‑less number between 0 (best) and 10 (worst).  Our goal is to drive it as low as possible without breaking the service.  
- Every listed directive is missing – the service is currently not protected by it.  
- Directives with a caution note (e.g., `PrivateDevices`) may break services that legitimately need those resources.  When you later use `apply`, you can skip them.

Repeat `analyze` after each hardening step to see the score change.

---

#### 24.3.3 – `apply` – Interactive, Manual Hardening

When you understand the service well enough to decide which directives are safe, use `apply`:

```bash
sudo svc‑harden.py apply cockpit.service
```

You will see one directive after another, for example:

```
  Directive : NoNewPrivileges
  Value     : yes
  Purpose   : Prevent gaining new privileges via setuid/setgid/capabilities

  Apply? [y/N/e(dit)]:
```

- `y` – accept the suggested value (`yes`).  
- `N` (or just Enter) – skip this directive.  
- `e` – enter a different value (e.g., `NoNewPrivileges=no` or `ProtectSystem=full` instead of `strict`).

After you go through all 28 directives, the tool shows a preview of the drop‑in file that will be written, then asks for confirmation:

```
  ──────────────────────────────────────────────────
  PREVIEW OF DROP-IN CONTENT
  ──────────────────────────────────────────────────
  # /etc/systemd/system/cockpit.service.d/hardening.conf
  # Generated by svc‑harden.py at 2026‑04‑29T...
  # Remove with: svc‑harden.py revert cockpit.service

  [Service]
  NoNewPrivileges=yes
  PrivateTmp=yes
  ProtectSystem=strict
  ...

  Write this drop‑in and restart the service? [y/N]:
```

Answer `y` and the service will be restarted immediately with the new restrictions.  If it fails to start, the tool prints an error message and advises you to run `bisect`.

---

#### 24.3.4 – `profile` – Auto‑Hardening via SHH (Behaviour‑Based)

For complex services whose behaviour you may not fully know, use runtime profiling:

```bash
sudo svc‑harden.py profile cockpit.service
```

**What happens step‑by‑step**:

1.  **The tool checks that `shh` and `strace` are available**; if not, it prints installation instructions and exits.
2.  It runs `shh service start‑profile cockpit.service`, which restarts the service under `strace`.
3.  You see:
    ```
    ═══ PROFILING ACTIVE ═══
    cockpit.service is now being traced with strace.
    Please exercise the service – perform all its normal operations.
    Press ENTER when you are finished …
    ```
4.  **Now interact with the service** – for Cockpit, you might open `https://localhost:9090`, log in, browse storage, check logs, and even run a few terminal commands inside the web UI.  The more operations you perform, the more complete the profile will be.
5.  Press Enter when done.
6.  SHH finishes profiling and prints its recommendations.  The tool parses them and shows:
    ```
    ──────────────────────────────────────────────────
    SHH RECOMMENDATIONS (automatically pre‑selected)
    ──────────────────────────────────────────────────
    ✅  NoNewPrivileges = yes
    ✅  ProtectSystem = strict
    ✅  ProtectHome = true
    ...
    ```

7.  If SHH suggested any directives that are not in our standard table (e.g., advanced path restrictions like `ReadOnlyPaths=/etc`), they appear in an **ADDITIONAL SHH DIRECTIVES** block for your review.

8.  You now enter an **interactive review** loop where you can toggle any directive on or off, or reset to just SHH’s defaults.  For instance:
    ```
    Current selection:
      NoNewPrivileges = yes
      ProtectSystem = strict
      ...

    [a]pply   [t]oggle a directive   [r]eset to SHH defaults   [q]uit
    Choice:
    ```
    - `t` asks for a directive name; if it is currently selected, it is removed; if not, it is added (if it was in the SHH recommendations).  
    - `r` discards your edits and goes back to what SHH suggested.  
    - `a` proceeds to write the drop‑in.

9.  After choosing `a`, you see the preview and confirm writing, exactly as in `apply`.

> **Tip**: Run `profile` a second time later (e.g., after a major software update) to refresh the profile.  The tool will overwrite the existing drop‑in, so the old manual configuration will be replaced by the new profiled one.

---

#### 24.3.5 – `test` – Validate That the Hardening Didn’t Break Anything

After applying a hardening profile, always verify that the service works as expected:

```bash
sudo svc‑harden.py test cockpit.service --test-cmd "curl -s -o /dev/null -w '%{http_code}' https://localhost:9090"
```

- The service is restarted.  
- If the restart fails, the command immediately reports failure.  
- If the restart succeeds, the last 20 lines of the journal are printed, and then the optional `--test‑cmd` is executed.  
- A return code of `0` from the test command means success; any non‑zero code or a timeout is reported as failure.

**Without `--test‑cmd`**, the tool only checks that the service came back as `active` – a quick sanity check.

---

#### 24.3.6 – `revert` – Roll Back to the Original State

If the hardened profile causes problems and `bisect` isn’t needed (or you just want to start over), undo all changes with:

```bash
sudo svc‑harden.py revert cockpit.service
```

The drop‑in file is deleted and the service is restarted with its original unit file.  All previous manual or SHH‑based hardening is gone.

---

#### 24.3.7 – `bisect` – Find the Culprit Directive

When a service fails to start after hardening, but you are unsure which directive is responsible, use the automated bisection:

```bash
sudo svc‑harden.py bisect cockpit.service
```

The tool reads the current hardening drop‑in, disables one directive at a time, and tries to restart the service.  As soon as the service becomes `active` again, it reports the culprit:

```
  CULPRIT IDENTIFIED: ProtectHome = yes
  [a] Remove only this directive
  [b] Revert ALL hardening
  [c] Leave as‑is
```

- **`a`** – remove the offending directive while keeping all others.  The drop‑in is updated and the service is restarted.  
- **`b`** – calls `revert` (remove everything).  
- **`c`** – leaves the broken configuration unchanged (useful if you want to fix it manually).

---

#### 24.3.8 – `log` – Audit Trail

Every action (`analyze`, `apply`, `profile`, `test`, `revert`, `bisect`) is recorded in a newline‑delimited JSON file at `/var/log/svc‑harden‑audit.json`.  To review all changes ever made:

```bash
sudo svc‑harden.py log
```

Each entry shows a timestamp, the action, the affected service, and further details (e.g., which directives were applied, whether the restart succeeded, etc.).  This log can be shipped alongside auditd logs for long‑term monitoring.

---

#### 24.3.9 – Workflow Summary

For each service you want to harden, follow this general flow:

1.  `analyze` – see what’s missing.  
2.  Either:  
    - `apply` (if you know the service well), **or**  
    - `profile` (if you want behaviour‑based recommendations).  
3.  `test` – confirm the service still works.  
4.  If the test fails, `bisect` to isolate the problem, then `revert` if necessary.  
5.  Repeat for the next service.

Always `test` critical services before rebooting the system, so you can catch failures in a controlled state.  A broken `sshd` or `firewalld` after a reboot can be disastrous on a remote machine.

---

### 24.4 – Recommended Services for Hardening

Run `svc‑harden.py analyze` (or `profile`) on every active system service. Priorities:

| Priority | Service | Suggested Workflow | Reason |
|----------|---------|---------------------|--------|
| 1 | `sshd.service` | manual `apply` | Internet‑facing; high‑value target |
| 2 | `cockpit.service` | manual `apply` | Management UI on localhost |
| 3 | `NetworkManager.service` | manual `apply` | Controls all networking |
| 4 | `firewalld.service` | manual `apply` | Firewall daemon runs as root |
| 5 | `auditd.service` | `profile` (SHH) | Complex runtime behaviour |
| 6 | `dnscrypt‑proxy.service` | `profile` (SHH) | Network daemon with dynamic patterns |
| 7 | `systemd‑resolved.service` | `profile` (SHH) | DNS stub resolver |
| 8 | `nvidia‑persistenced.service` | manual `apply` | Simple, well‑understood service |

For complex network daemons, prefer SHH profiling because it captures the exact runtime behaviour. For simple, well‑understood services, interactive `apply` is faster.

---

### 24.5 – Learning Python with This Script

This script is a real‑world, production‑grade example of a modern Python CLI application. It uses:

- **`dataclasses`** for structured, immutable data objects
- **`pathlib`** for safe, cross‑platform filesystem manipulation
- **Comprehensive type hints** (`dict[str, str]`, `Optional`, `list[HardeningDirective]`, `str | None`) for self‑documenting code
- **`match` / `case`** (Python 3.10+) for clean, exhaustiveness‑checkable dispatch
- **`subprocess.run`** with `capture_output=True` and explicit error handling — the recommended secure API, never using `shell=True` for arguments
- **NDJSON** audit logging for machine‑parseable, append‑only records
- **`shutil.which()`** to discover external tools safely
- **`re`** with robust, commented regex patterns

If you are learning Python, studying this script alongside the `systemd.exec(5)` documentation will teach you how to write secure, maintainable, and well‑tested administration tools. The code favours explicitness over cleverness — every function has a purpose, every type is declared, and every error path is handled.

---


## Part 25 — System Packages (Desktop)

> **Install all packages listed in `README.md` sections for desktop, development, containers, and scientific computing.** The full emerge list from the personal runbook includes:

```bash
emerge --ask \
  gui-wm/hyprland gui-libs/xdg-desktop-portal-hyprland \
  gui-apps/grim gui-apps/slurp gui-apps/wl-clipboard \
  x11-misc/sddm x11-base/xwayland \
  app-shells/zsh app-shells/starship app-shells/zoxide \
  app-shells/fzf app-shells/atuin \
  app-editors/neovim app-editors/emacs \
  dev-vcs/git dev-vcs/lazygit \
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

## Part 25 — Login Banner

```bash
cat > /etc/issue << 'EOF'
-- WARNING -- This system is for the use of authorized users only. Individuals using this computer system without authority or in excess of their authority are subject to having all their activities on this system monitored and recorded by system personnel. Anyone using this system expressly consents to such monitoring and is advised that if such monitoring reveals possible evidence of criminal activity system personal may provide the evidence of such monitoring to law enforcement officials.
EOF

cp /etc/issue /etc/issue.net
```

---

## Part 26 — Final System Setup and First Boot

### 26.1 — User Account (already configured)

The root password was set and locked, and the `ahsan` user was created in Section 5.6. No further action is needed here.

```bash
# Verify the user exists and groups are correct
id ahsan
# Should show: uid=…(ahsan) gid=…(ahsan) groups=…(ahsan),…wheel,audio,video,tss
```

### 26.2 — Enable Essential Services

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

### 26.3 — Regenerate UKI (First Time Manually)

```bash
KVER=$(ls /lib/modules/ | sort -V | tail -1)
dracut --force --verbose /efi/EFI/Linux/gentoo-${KVER}.efi ${KVER}
sbctl sign --save /efi/EFI/Linux/gentoo-${KVER}.efi
```

### 26.4 — Exit Chroot and Reboot

```bash
exit
umount -R /mnt/gentoo
reboot
```

---

## Part 27 — Post‑Install: TPM2 Enrollment and Verification

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

## Part 28 — Post‑Install Chroot Re‑Entry

If you need to re‑enter the installed system from a live environment (e.g., for boot repair, UKI regeneration, or `snapper rollback`), the procedure below remounts the entire LUKS‑LVM‑Btrfs stack independently of the running kernel’s
fstab.  **All commands assume you have booted from a Gentoo Live‑DVD/USB** (or any rescue environment with `cryptsetup`, `lvm2`, and `btrfs‑progs`).

### 28.1 — Open LUKS and Activate LVM

```bash
# Open both LUKS containers. You will be prompted for the LUKS passphrase or recovery key – the TPM is NOT available in a live environment.
cryptsetup luksOpen /dev/nvme0n1p2 crypt0
cryptsetup luksOpen /dev/nvme1n1p1 crypt1

# Activate the volume group (this scans all PVs and brings every LV online)
vgchange -ay vg0
lvs                 # verify vg0/root is visible
```

### 28.2 — Mount the Btrfs Root

The root subvolume is mounted **without a `subvol=` option** so that the kernel automatically selects the current default subvolume — the one that `snapper` would have set during the last rollback.  This guarantees you always mount the active, running root.

```bash
BTRFS_OPTS="defaults,noatime,compress=zstd:1,space_cache=v2"
BTRFS_NOCOW="defaults,noatime,space_cache=v2"

mkdir -p /mnt/gentoo
mount -o ${BTRFS_OPTS} /dev/vg0/root /mnt/gentoo
```

> **Why no `subvol=`?**  When the `subvol=` option is omitted, Btrfs mounts the
> *current default* subvolume (the one set by `btrfs subvolume set-default`).
> This is the same behaviour that the running system’s fstab uses, and it means
> you never accidentally mount a stale snapshot.

### 28.3 — Mount All Subvolumes and the ESP

```bash
# ── Btrfs subvolumes ──
mount -o ${BTRFS_OPTS},subvol=@/.snapshots   /dev/vg0/root /mnt/gentoo/.snapshots
mount -o ${BTRFS_OPTS},subvol=@/home          /dev/vg0/root /mnt/gentoo/home
mount -o ${BTRFS_NOCOW},subvol=@/nix           /dev/vg0/root /mnt/gentoo/nix
mount -o ${BTRFS_OPTS},subvol=@/opt            /dev/vg0/root /mnt/gentoo/opt
mount -o ${BTRFS_OPTS},subvol=@/root           /dev/vg0/root /mnt/gentoo/root
mount -o ${BTRFS_OPTS},subvol=@/srv            /dev/vg0/root /mnt/gentoo/srv
mount -o ${BTRFS_OPTS},subvol=@/tmp            /dev/vg0/root /mnt/gentoo/tmp
mount -o ${BTRFS_OPTS},subvol=@/usr/local      /dev/vg0/root /mnt/gentoo/usr/local
mount -o ${BTRFS_NOCOW},subvol=@/var            /dev/vg0/root /mnt/gentoo/var
mount -o ${BTRFS_NOCOW},subvol=@/var/log        /dev/vg0/root /mnt/gentoo/var/log
mount -o ${BTRFS_NOCOW},subvol=@/var/log/audit  /dev/vg0/root /mnt/gentoo/var/log/audit
mount -o ${BTRFS_NOCOW},subvol=@/var/cache      /dev/vg0/root /mnt/gentoo/var/cache
mount -o ${BTRFS_NOCOW},subvol=@/var/tmp        /dev/vg0/root /mnt/gentoo/var/tmp

# ── ESP (run fsck first to avoid “dirty volume” warnings) ──
fsck.vfat -a /dev/nvme0n1p1 || true
mount /dev/nvme0n1p1 /mnt/gentoo/efi

# Verify the layout
findmnt --real --target /mnt/gentoo
```

> **About `BTRFS_NOCOW`:** These subvolumes had CoW disabled at creation time
> via `chattr +C` (Part 4).  The `BTRFS_NOCOW` variable simply omits
> `compress=zstd:1` because compression is incompatible with `nodatacow`, but
> it does **not** pass a `nodatacow` mount option — that is handled at the
> attribute level.

### 28.4 — Bind‑Mount Pseudo‑Filesystems

```bash
mount --types proc  /proc  /mnt/gentoo/proc
mount --rbind       /sys   /mnt/gentoo/sys
mount --make-rslave        /mnt/gentoo/sys
mount --rbind       /dev   /mnt/gentoo/dev
mount --make-rslave        /mnt/gentoo/dev
mount --bind        /run   /mnt/gentoo/run
mount --make-slave         /mnt/gentoo/run

# Fix /dev/shm if the live environment made it a symlink (common on
# non‑Gentoo live media such as Arch or Ubuntu ISOs):
test -L /dev/shm && rm /dev/shm && mkdir /dev/shm
mount -t tmpfs -o nosuid,nodev,noexec shm /dev/shm
chmod 1777 /dev/shm

# Mount binfmt_misc – required by Python and the AppArmor parser
mount -t binfmt_misc none /mnt/gentoo/proc/sys/fs/binfmt_misc 2>/dev/null || true
```

> **Why `--make-rslave`?**  When `systemd` later unmounts something inside the
> chroot (e.g. a stale `/sys/fs/cgroup`), `rslave` prevents that unmount from
> propagating backward to the live environment’s `/sys`, which would otherwise
> tear down the host’s cgroup hierarchy.  This is the standard Gentoo Handbook
> recommendation.

### 28.5 — Copy DNS Configuration and Enter the Chroot

```bash
# Copy the live environment’s resolv.conf so the chroot has network access
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/resolv.conf

# Enter the chroot (standard method)
chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) ${PS1}"

# Optionally remount all fstab entries inside the chroot:
# mount -a
```

> **Alternative:** If your rescue ISO ships `arch‑chroot` (Arch‑based media),
> you can use `arch‑chroot /mnt/gentoo` instead of the manual `chroot` command.
> It automatically handles `/dev/shm`, `/run`, and `resolv.conf`.

### 28.6 — Perform Recovery Tasks

Once inside the chroot you can, for example:

* **Rebuild a broken UKI:**
  ```bash
  KVER=$(ls /lib/modules/ | sort -V | tail -1)
  dracut --force /efi/EFI/Linux/gentoo-${KVER}.efi ${KVER}
  sbctl sign -s /efi/EFI/Linux/gentoo-${KVER}.efi
  ```

* **Roll back with Snapper (if the root was mounted with a specific snapshot):**
  ```bash
  snapper -c root list
  snapper -c root rollback <N>
  ```

* **Fix a broken `/etc/fstab`:**
  ```bash
  nano /etc/fstab
  ```

* **Reset a forgotten root password:**
  ```bash
  passwd -u root   # unlock (if locked)
  passwd root      # set new password
  ```

### 28.7 — Graceful Exit

When you are finished, leave the chroot cleanly:

```bash
exit                      # leave the chroot

# Unmount in reverse order
umount -l /mnt/gentoo/dev/shm 2>/dev/null || true
umount -l /mnt/gentoo/proc/sys/fs/binfmt_misc 2>/dev/null || true
umount -l /mnt/gentoo/dev
umount -l /mnt/gentoo/sys
umount -l /mnt/gentoo/proc
umount -l /mnt/gentoo/run

# Unmount Btrfs subvolumes and the ESP
umount -R /mnt/gentoo

# Deactivate the volume group and close LUKS
vgchange -an vg0
cryptsetup close crypt1
cryptsetup close crypt0

reboot
```

> **`umount -l` (lazy unmount)** is used for safety; it detaches the
> filesystem immediately but finishes pending operations in the background.
> This avoids “target is busy” errors if a process (e.g. `systemd-journald`
> from the chroot) still holds a file descriptor.
```

### 📋 Audit Change Log

| # | Original | Corrected | Rationale |
|---|---|---|---|
| 1 | `mount -o … subvol=@/.snapshots/1/snapshot` | `mount -o … /dev/vg0/root /mnt/gentoo` (no `subvol=`) | After a `snapper rollback`, the default subvolume changes, but the hard‑coded path would mount a stale snapshot. Omitting `subvol=` always mounts the current default. |
| 2 | `mount /dev/nvme0n1p1 /mnt/gentoo/efi` | Added `fsck.vfat -a` before the mount | Prevents “dirty volume” warnings that can occur if the system was not shut down cleanly. |
| 3 | No `binfmt_misc` mount | Added `mount -t binfmt_misc …` | Required by Python and the AppArmor parser; without it, profile loading fails silently. |
| 4 | No graceful exit procedure | Added Section 28.7 | An incomplete unmount can leave LVM volumes active, preventing a clean reboot. |
| 5 | No `resolv.conf` copy | Added Section 28.5 with `cp --dereference /etc/resolv.conf` | Without this the chroot cannot resolve hostnames, which breaks `emerge --sync`. |

---

## Part 30 — TPM2 Key Recovery

PCR sealing is what makes TPM2‑backed LUKS unlock secure: the TPM will only release the disk‑encryption key if the measured boot chain matches the value that was recorded at enrollment time. Any change to a sealed PCR — a UEFI firmware update, a Secure Boot key rotation, a dbx update, or even a kernel command‑line modification — will cause the TPM to refuse to unseal the key. This is a security feature, not a bug: a PCR mismatch can signal either a legitimate update or a sophisticated evil‑maid attack.

When the TPM refuses to unseal, the initramfs falls back to prompting for a passphrase. This is the moment you reach for the recovery key that you generated during enrollment (Part 10) and stored securely offline.

---

### 30.1 — Why This Process Must Remain Manual

For a nation‑state threat model, the inconvenience of typing a few commands after a firmware update is trivial compared to the risk of silently accepting a compromised boot chain:

| Scenario | Risk of full automation |
|---|---|
| **Legitimate UEFI firmware update** | Low — but you still want to verify the update was signed and intentional. |
| **Malicious firmware implant (evil‑maid)** | Very high — an attacker replaces the UEFI firmware or dbx; automation would silently accept the new PCR and unlock the disk for them. |
| **Secure Boot key compromise** | Very high — if your db key is stolen and replaced, you must not re‑enroll until you have rotated the keys. |
| **Kernel command‑line injection** | High — a modified UKI cmdline could weaken other hardening layers; automation would seal the key to the weakened state. |

**Principle: every re‑enrollment must be preceded by a conscious human decision that the change was legitimate.** The script below makes the process quicker and less error‑prone, but it still requires you to explicitly invoke it.

---

### 30.2 — Recovery Procedure

#### Step 1: Boot with the Recovery Key

When the TPM fails to unseal the LUKS key, the `systemd‑cryptsetup` initramfs service prompts for a passphrase. Enter the recovery key that you generated and stored offline during Part 10.

```
🔐 Please enter passphrase for disk /dev/nvme0n1p2 (crypt0): ********
🔐 Please enter passphrase for disk /dev/nvme1n1p1 (crypt1): ********
```

> **If you lost the recovery key**, there is no way to recover the data. The LUKS header contains no back‑door. This is why Part 2.7 insists on an offline header backup and Part 10 insists on storing the recovery key in at least two physically‑separate locations (paper + encrypted USB, safe‑deposit box + home safe).

#### Step 2: Verify the system booted correctly

```bash
# Confirm Secure Boot state matches your expectation
sbctl status

# Confirm the running kernel and UKI are the ones you expect
uname -r
sbctl verify | grep /efi/EFI/Linux
```

If anything looks wrong — an unsigned UKI, a kernel version you don’t recognise, missing Secure Boot enforcement — stop here and investigate before re‑enrolling the TPM.

---

### 30.3 — The `tpm‑re‑enroll` Convenience Script

The script below performs the full wipe → re‑enroll → recovery‑key‑rotation cycle on both LUKS containers. Save it to `/usr/local/sbin/tpm‑re‑enroll` and make it executable.

```bash
#!/bin/bash
# /usr/local/sbin/tpm‑re‑enroll — refresh TPM2 PCR seal after firmware
# or Secure Boot key changes.
#
# This script:
#   1.  Wipes the old TPM2 token from each LUKS container.
#   2.  Re‑enrolls a fresh TPM2 + PIN token against the current PCR
#       baseline (0 + 2 + 7 + 12).
#   3.  Revokes the used recovery key and generates a new one.
#
#  The new recovery keys are printed to stdout — save them offline
#  IMMEDIATELY.  If the script is interrupted, you may lose access
#  to the encrypted drives.  Run it only after you have confirmed
#  that the boot chain changes are legitimate.

set -euo pipefail
PCRS="0+2+7+12"

for dev in /dev/nvme0n1p2 /dev/nvme1n1p1; do
    echo "==> Wiping old TPM2 slot on $dev …"
    systemd-cryptenroll --wipe-slot=tpm2 "$dev"

    echo "==> Enrolling new TPM2 + PIN on $dev (PCRs: $PCRS) …"
    systemd-cryptenroll \
        --tpm2-device=auto \
        --tpm2-pcrs="$PCRS" \
        --tpm2-with-pin=yes \
        "$dev"

    echo "==> Revoking used recovery key on $dev …"
    systemd-cryptenroll --wipe-slot=recovery "$dev"
    echo "==> Generating new recovery key on $dev …"
    systemd-cryptenroll --recovery-key "$dev"
done

echo ""
echo "══════════════════════════════════════════"
echo "  SAVE THE NEW RECOVERY KEYS IMMEDIATELY"
echo "══════════════════════════════════════════"
echo "  1.  Write them on paper.  Store the paper in a safe place."
echo "  2.  Copy them to an encrypted, air‑gapped USB drive."
echo "  3.  Verify both copies before closing this terminal."
```

**Make it executable and owned by root only:**

```bash
chown root:root /usr/local/sbin/tpm‑re‑enroll
chmod 700 /usr/local/sbin/tpm‑re‑enroll
```

#### Step 3: Run the re‑enrollment script

```bash
# After you have confirmed the boot chain is legitimate:
sudo /usr/local/sbin/tpm‑re‑enroll
```

The script prints the new recovery keys to stdout. Write them down **immediately**, store one copy on a FIDO2‑protected encrypted USB drive, and another copy as a paper backup in a physically secure location. Do not store them on the encrypted system disk — if the TPM fails permanently, you will not be able to read them.

---

### 30.4 — What Happens During Re‑Enrollment

| Step | Command | Effect |
|------|---------|--------|
| Wipe TPM2 token | `systemd-cryptenroll --wipe-slot=tpm2` | Removes the old (now‑invalid) PCR‑sealed key. The LUKS passphrase and recovery key remain untouched, so the volume is still accessible. |
| Enroll new token | `systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7+12 --tpm2-with-pin=yes` | Generates a fresh key inside the TPM and seals it against the current PCR values. |
| Revoke old recovery key | `systemd-cryptenroll --wipe-slot=recovery` | Deletes the used recovery key. A used recovery key must be treated as compromised — anyone who saw it over your shoulder now possesses it. |
| Generate new recovery key | `systemd-cryptenroll --recovery-key` | Creates a new high‑entropy recovery key and prints it to stdout. |

After the script completes, run `systemd-cryptenroll /dev/nvme0n1p2` to verify that each LUKS container shows exactly one `tpm2` slot and one `recovery` slot:

```bash
systemd-cryptenroll /dev/nvme0n1p2
systemd-cryptenroll /dev/nvme1n1p1
```

---

### 30.5 — Complete TPM Failure

If the TPM chip is physically damaged, has been cleared by a firmware bug, or has been reset to factory defaults, TPM‑based unlock is permanently unavailable.

**Immediate action:** Boot using the recovery key (as in Section 30.2, Step 1).

**Long‑term options:**

| Option | Command | Security |
|--------|---------|----------|
| **Replace the TPM** (if discrete) | Hardware replacement; then re‑enroll | Best — restores hardware‑backed two‑factor unlock |
| **Fall back to passphrase** | `systemd-cryptenroll --password /dev/nvme0n1p2` | Acceptable only with a strong (≥ 25‑character), high‑entropy passphrase generated by a password manager |
| **Use FIDO2 token** | `systemd-cryptenroll --fido2-device=auto /dev/nvme0n1p2` | Requires a separate hardware token (YubiKey, Nitrokey); still provides two‑factor authentication |

If you fall back to a passphrase, increase the Argon2id memory parameter to at least `‑‑pbkdf‑memory 2097152` (2 GiB) to raise the brute‑force cost, since you have lost the hardware‑based rate‑limiting that the TPM provides.

---

### 30.6 — PCR Justification (Repeated from Part 10)

| PCR | Measures | Why Included | What changes it |
|-----|----------|-------------|-----------------|
| PCR[0] | UEFI firmware code | Detects firmware tampering | UEFI firmware update |
| PCR[2] | Option ROM code | Detects malicious GPU/NIC UEFI ROMs via Thunderbolt/PCIe | Option ROM updates, GPU firmware updates |
| PCR[7] | Secure Boot state (db, dbx, PK, KEK) | Seals against Secure Boot key rotation | Secure Boot key enrollment, dbx updates, shim updates |
| PCR[12] | Kernel cmdline (measured by systemd‑stub) | Seals against modification of the embedded UKI cmdline | UKI rebuild with new cmdline |

> **Choosing fewer PCRs**: If you find yourself re‑enrolling too often (e.g., after every kernel update because of PCR 12 changes), you can drop specific PCRs from the list. Dropping PCR 12 gives up protection against cmdline injection; dropping PCR 7 gives up protection against Secure Boot key replacement. For an APT threat model, the four‑PCR set above provides the best balance of security and manageability.

### 30.7 — Automated Alternative: `systemd‑pcrlock` (Experimental)

`systemd‑pcrlock` is a newer tool (available in systemd ≥ 255) that can **predict** what PCR values will look like after a legitimate firmware update and store a policy in TPM non‑volatile memory that allows unlocking across those predicted changes. It is designed to reduce the manual burden of firmware updates while still refusing to unlock the disk for unpredicted PCR states.

The workflow is:
```bash
# Before a firmware update:
systemd-pcrlock unlock-firmware-code
# Perform the firmware update and reboot.
# After reboot, refresh the policy:
systemd-pcrlock make-policy
```

**Limitations as of April 2026:**
- The tool is explicitly marked **experimental** by the systemd project and "might still change in behaviour and interface".
- It cannot predict all possible firmware changes (a dbx update from your motherboard vendor may not be in the prediction model).
- It still requires a recovery key as a fallback for truly unexpected PCR changes.
- It requires a TPM 2.0 that implements the `PolicyAuthorizeNV` command (TPM 2.0 version 1.38 or newer).
- There is an open issue with `fwupd` to integrate `systemd‑pcrlock` for seamless firmware‑update workflows, but it has not been resolved as of early 2026.

**Recommendation:** For this APT‑hardened guide, `systemd‑pcrlock` is not yet mature enough to replace the manual recovery procedure. Monitor the project's status and re‑evaluate in mid‑2026 when it may stabilise into a regular systemd component. If you choose to adopt it, always keep a recovery key as a fallback — a `pcrlock` policy that fails to generate after a firmware update leaves you with no TPM‑based unlock at all.

---

### 30.8 — Recovery Workflow Summary

```
PCR mismatch detected at boot
  └─► Enter recovery key when prompted
       └─► System boots with recovered LUKS keys
            └─► VERIFY: sbctl status, uname -r, sbctl verify
                 │
                 ├─► Boot chain is legitimate (intentional update)?
                 │     └─► YES → run /usr/local/sbin/tpm‑re‑enroll
                 │            └─► Save new recovery keys offline
                 │
                 └─► Boot chain is unexpected?
                       └─► STOP.  Investigate immediately.
                            • Check UEFI firmware version against vendor's site.
                            • Check Secure Boot keys for unknown entries.
                            • Re‑provision the system from known‑good backups
                              if tampering is confirmed.
```
---

*Guide prepared April 2026. Architecture verified against: Gentoo Wiki (Hardened, UKI, Dracut, Installkernel, Secure Boot, systemd‑cryptenroll), Arch Wiki (dm‑crypt, Unified Kernel Image, Secure Boot), CachyOS Wiki (Kernel), and systemd documentation (systemd‑cryptenroll, systemd‑stub).*
