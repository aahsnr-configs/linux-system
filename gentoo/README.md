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
app-editors/emacs -X tree-sitter imagemagick mailutils sqlite
sys-devel/gcc default-stack-clash-protection graphite go
llvm-runtimes/compiler-rt-sanitizers orc profile
llvm-core/clang-runtime sanitize
dev-lang/python -jit
net-misc/networkmanager nftables gnutls -resolvconf
app-admin/cockpit firewalld pcp udisks
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

- [ ] `POST INSTALL`

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

## Part 19 — SSH Hardening

```bash
emerge --ask net-misc/openssh
```

> **Apply the complete SSH server and client hardening from `arch_hardening_setup.md` Part 10**: custom port 2222, Ed25519 and ECDSA P‑521 keys only, Curve25519 Kex, ChaCha20‑Poly1305 and AES‑256‑GCM ciphers, key‑only auth, no root login, `AllowGroups sshusers`, strict idle timeout, all forwarding disabled.

---

## Part 20 — PAM Hardening

```bash
emerge --ask sys-libs/pam sys-libs/libpwquality
```

> **Apply the PAM configuration from `arch_hardening_setup.md` Part 11**: `pam_faillock` (5 failures → 15‑minute lockout), `pam_pwquality` (16‑char minimum, 3+ character classes, dictionary check), hardened `/etc/pam.d/system-auth`, resource limits in `/etc/security/limits.conf`.

---

## Part 21 — Supply Chain Monitoring

### 21.1 — Portage Post‑Transaction Audit Logging

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

### 21.2 — CVE Scanning

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
eselect-repository enable guru
emaint-sync -r guru

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
-- WARNING -- This system is for the use of authorized users only. Individuals using this computer system without authority or in excess of their authority are subject to having all their activities on this system monitored and recorded by system personnel. Anyone using this system expressly consents to such monitoring and is advised that if such monitoring reveals possible evidence of criminal activity system personal may provide the evidence of such monitoring to law enforcement officials.
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

---

*Guide prepared April 2026. Architecture verified against: Gentoo Wiki (Hardened, UKI, Dracut, Installkernel, Secure Boot, systemd‑cryptenroll), Arch Wiki (dm‑crypt, Unified Kernel Image, Secure Boot), CachyOS Wiki (Kernel), and systemd documentation (systemd‑cryptenroll, systemd‑stub).*

```
