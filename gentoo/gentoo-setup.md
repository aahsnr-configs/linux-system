# Gentoo Linux Deployment Guide
## RAID 0 + Full Disk Encryption + Tumbleweed-Style Btrfs + Snapper + Bootable Snapshots

---

> **Warning — RAID 0 has zero redundancy.** Any single disk failure destroys all data on both volumes. Maintain off-site backups at all times.

---

## Corrections vs. Previous Drafts

This second review corrects all remaining errors found in the previous version:

| # | Issue | Fix |
|---|---|---|
| 1 | `/mnt` used throughout | Replaced with `/mnt/gentoo` (standard Gentoo convention) |
| 2 | `rd.luks.key` in `kernel_cmdline` when systemd module is active | Replaced with `/etc/crypttab.initramfs` (systemd-cryptsetup-generator approach) |
| 3 | `pre_emerge` / `post_emerge` are not valid Portage hook names | Replaced with correct `pre_pkg_preinst` / `post_pkg_postinst` hooks |
| 4 | `mdadm` as a global USE flag in `make.conf` | Removed; it is not a standard global USE flag |
| 5 | `sys-apps/systemd` missing `cryptsetup` USE flag | Added; required for systemd-cryptsetup-generator |
| 6 | `static-libs` USE flag on cryptsetup was wrong flag name | Replaced with correct `static` flag |
| 7 | `installkernel` not mentioned | Added with `dracut grub` USE flags to automate initramfs + grub-mkconfig after every kernel install |
| 8 | `/nix` subvolume absent | Added `@/nix` Btrfs subvolume with CoW disabled |
| 9 | Keyfile location unclear — host vs chroot | Explicitly documented: keyfile is created on the **live host**, then copied into chroot |
| 10 | Section 5.5 (LUKS header backup) had insufficient detail | Expanded with full explanation and restore procedure |

---

## Why `/boot` Must Be Inside the Encrypted Root

**The Tumbleweed FDE architecture:**

```
nvme1n1
├── nvme1n1p1   /boot/efi   512 MB   vfat      ← UNENCRYPTED — ESP (GRUB EFI binary only)
└── nvme1n1p2   LUKS root                       ← Everything else is here
                └── Btrfs
                     ├── /boot                 ← INSIDE encrypted root — kernel + initramfs here
                     ├── /boot/grub2/x86_64-efi ← separate subvolume (excluded from snapshots)
                     ├── /home                 ← @/home
                     └── ...
```

There is **no separate `/boot` partition**. The ESP holds only `grubx64.efi`.

**Why this matters for bootable snapshots:**

When grub-btrfs generates a menu entry for a snapshot, it finds the kernel at `<snapshot>/boot/vmlinuz-*`. If `/boot` were on a separate partition, all snapshots would share the same kernel — rolling back to a snapshot with older kernel modules while the newer kernel loads causes a **kernel/modules mismatch → kernel panic**. With `/boot` inside the snapshot, every snapshot contains its own matching kernel and modules.

**GRUB2 LUKS2 KDF constraint (GRUB 2.12 stable, April 2026):**

GRUB only supports **PBKDF2** for LUKS2. Argon2id is not supported without an unofficial patch.

- `root12` (md1) → **LUKS2 with PBKDF2** (GRUB must open this to read the kernel)
- `swap12` (md0) → **LUKS2 with Argon2id** (GRUB never opens swap)

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites and Live Environment Setup](#2-prerequisites-and-live-environment-setup)
3. [Disk Partitioning](#3-disk-partitioning)
4. [RAID 0 Array Creation](#4-raid-0-array-creation)
5. [LUKS2 Encryption Setup](#5-luks2-encryption-setup)
6. [Btrfs Filesystem and Tumbleweed-Style Subvolumes](#6-btrfs-filesystem-and-tumbleweed-style-subvolumes)
7. [Swap Configuration](#7-swap-configuration)
8. [Gentoo Stage 3 Installation](#8-gentoo-stage-3-installation)
9. [Chroot and Base Configuration](#9-chroot-and-base-configuration)
10. [Kernel Configuration, installkernel, and Compilation](#10-kernel-configuration-installkernel-and-compilation)
11. [Dracut Initramfs Configuration (Single-Password Unlock)](#11-dracut-initramfs-configuration-single-password-unlock)
12. [GRUB Bootloader Configuration](#12-grub-bootloader-configuration)
13. [fstab Configuration](#13-fstab-configuration)
14. [Snapper Integration](#14-snapper-integration)
15. [grub-btrfs for Bootable Snapshots](#15-grub-btrfs-for-bootable-snapshots)
16. [Hibernation Support](#16-hibernation-support)
17. [Final System Services and Boot](#17-final-system-services-and-boot)
18. [Post-Install Verification](#18-post-install-verification)
19. [Rollback Procedure](#19-rollback-procedure)
20. [Troubleshooting](#20-troubleshooting)

---

## 1. Architecture Overview

### Disk Layout

```
nvme1n1 (500 GB — Boot Disk)
├── nvme1n1p1   EFI System Partition    512 MB    FAT32       UNENCRYPTED — GRUB EFI binary only
├── nvme1n1p2   swap1                  16384 MB  Linux RAID  RAID 0 member for swap
└── nvme1n1p3   root1                  ~464 GB   Linux RAID  RAID 0 member for root

nvme0n1 (1 TB — Data Disk)
├── nvme0n1p1   swap2                  16384 MB  Linux RAID  RAID 0 member for swap
└── nvme0n1p2   root2                  ~980 GB   Linux RAID  RAID 0 member for root

Software RAID 0 Arrays (mdadm)
├── /dev/md0    swap12 (swap1+swap2)    ~32 GB   LUKS2/Argon2id → /dev/mapper/swap12 → swap
└── /dev/md1    root12 (root1+root2)   ~1.44 TB  LUKS2/PBKDF2  → /dev/mapper/root12 → Btrfs

Btrfs Volume on /dev/mapper/root12 — Tumbleweed-style subvolume layout
├── @                          → root subvolume
│   ├── boot/                  → /boot (plain dir — kernel+initramfs captured in snapshots)
│   └── boot/grub2/            → parent dir inside @
├── @/.snapshots               → Snapper snapshot dir (mounted at /.snapshots)
│   └── 1/snapshot             → initial snapshot → becomes / after set-default
├── @/boot/grub2/x86_64-efi   → GRUB EFI subvol (EXCLUDED from snapshots)
├── @/home                    → /home
├── @/nix                     → /nix  (CoW disabled — Nix store)
├── @/opt                     → /opt
├── @/root                    → /root (root user home)
├── @/srv                     → /srv
├── @/tmp                     → /tmp
├── @/usr/local               → /usr/local
└── @/var                     → /var  (CoW disabled)
```

### Single-Password Boot Flow

```
Power on
  └─► GRUB EFI binary loads from ESP (unencrypted FAT32)
       └─► GRUB loads mdraid1x module → assembles md1 from nvme1n1p3 + nvme0n1p2
            └─► GRUB loads cryptodisk+luks2 → runs cryptomount on md1
                 └─► ONE passphrase prompt ────────────────────────────────────────┐
                      └─► GRUB reads grub.cfg + kernel + initramfs from Btrfs     │
                           └─► Kernel boots → dracut initramfs runs               │
                                ├─► mdadm assembles md0 and md1                   │
                                ├─► systemd-cryptsetup reads /etc/crypttab         │
                                │   (embedded in initramfs by dracut from          │
                                │   /etc/crypttab.initramfs) with keyfile          │
                                ├─► md1 (root12) unlocked silently via keyfile     │
                                ├─► md0 (swap12) unlocked silently via keyfile     │
                                └─► Btrfs root mounted → systemd init starts      │
                                                                                   │
Total passphrase entries: exactly ONE ─────────────────────────────────────────────┘
```

---

## 2. Prerequisites and Live Environment Setup

Boot from the **Gentoo LiveDVD/USB** (any rescue environment with `mdadm`, `cryptsetup`, `btrfs-progs`).

### 2.1 Verify NVMe Devices

```bash
lsblk -d -o NAME,SIZE,MODEL
# Confirm: nvme1n1 (~500 GB), nvme0n1 (~1 TB)
```

### 2.2 Zero Out Any Existing Metadata

```bash
mdadm --zero-superblock /dev/nvme1n1
mdadm --zero-superblock /dev/nvme0n1
wipefs -a /dev/nvme1n1
wipefs -a /dev/nvme0n1
```

---

## 3. Disk Partitioning

### 3.1 Partition nvme1n1 (500 GB — Boot Disk)

```bash
gdisk /dev/nvme1n1
```

Inside `gdisk`:

```
o       # New GPT partition table — confirm with y

n       # Partition 1 — EFI System Partition
        # Number: 1
        # First sector: default
        # Last sector: +512M
        # Type: ef00  (EFI System)

n       # Partition 2 — swap1 (RAID 0 member)
        # Number: 2
        # First sector: default
        # Last sector: +16384M
        # Type: fd00  (Linux RAID)

n       # Partition 3 — root1 (RAID 0 member)
        # Number: 3
        # First sector: default
        # Last sector: default (all remaining space)
        # Type: fd00  (Linux RAID)

w       # Write and exit
```

> **Note:** There is no separate `/boot` partition. The ESP holds only `grubx64.efi`. All other boot-related files (GRUB config, kernel, initramfs) live inside the encrypted Btrfs root.

```bash
gdisk -l /dev/nvme1n1    # Verify
```

### 3.2 Partition nvme0n1 (1 TB — Data Disk)

```bash
gdisk /dev/nvme0n1
```

Inside `gdisk`:

```
o       # New GPT partition table — confirm with y

n       # Partition 1 — swap2 (RAID 0 member)
        # Number: 1
        # First sector: default
        # Last sector: +16384M
        # Type: fd00  (Linux RAID)

n       # Partition 2 — root2 (RAID 0 member)
        # Number: 2
        # First sector: default
        # Last sector: default (all remaining space)
        # Type: fd00  (Linux RAID)

w       # Write and exit
```

```bash
gdisk -l /dev/nvme0n1    # Verify
```

### 3.3 Format the EFI Partition

```bash
mkfs.vfat -F32 -n EFI /dev/nvme1n1p1
```

---

## 4. RAID 0 Array Creation

### 4.1 Create swap RAID 0 (md0 = swap12)

```bash
mdadm --create --verbose /dev/md0 \
  --level=0 \
  --raid-devices=2 \
  --name=swap12 \
  --metadata=1.2 \
  /dev/nvme0n1p2 /dev/nvme1n1p1
```

### 4.2 Create root RAID 0 (md1 = root12)

```bash
mdadm --create --verbose /dev/md1 \
  --level=0 \
  --raid-devices=2 \
  --name=root12 \
  --metadata=1.2 \
  /dev/nvme0n1p3 /dev/nvme1n1p2
```

Verify both arrays are active and clean:

```bash
cat /proc/mdstat
mdadm --detail /dev/md0
mdadm --detail /dev/md1
```

### 4.3 Save mdadm Configuration

```bash
mdadm --detail --scan >> /etc/mdadm.conf
cat /etc/mdadm.conf
```

---

## 5. LUKS2 Encryption Setup

> **All commands in Section 5 are run on the LIVE HOST** — not inside the chroot. The keyfile is generated here and will be copied into the installed system in Section 9.

**Critical constraint:** GRUB 2.12 (stable, April 2026) only supports **PBKDF2** for LUKS2 decryption. Argon2id on the root partition causes a boot failure at the GRUB stage. Use PBKDF2 for root12 (which GRUB decrypts) and Argon2id for swap12 (which GRUB never touches).

### 5.1 Optional: Wipe Arrays with Random Data

Wiping prevents an attacker from distinguishing used from unused sectors on the encrypted volume. Recommended for fresh deployments, especially on SSDs that have stored plaintext data previously.

```bash
# Wipe swap array (~32 GB — fast)
cryptsetup open --type plain --key-file /dev/urandom /dev/md0 wipe_swap
dd if=/dev/zero of=/dev/mapper/wipe_swap bs=4M status=progress
cryptsetup close wipe_swap

# Wipe root array (~1.44 TB — slow; use screen or tmux)
cryptsetup open --type plain --key-file /dev/urandom /dev/md1 wipe_root
dd if=/dev/zero of=/dev/mapper/wipe_root bs=4M status=progress
cryptsetup close wipe_root
```

### 5.2 Format root12 with LUKS2/PBKDF2

```bash
# PBKDF2 is mandatory — GRUB must decrypt this partition to read the kernel
cryptsetup luksFormat \
  --type luks2 \
  --cipher aes-xts-plain64 \
  --key-size 512 \
  --hash sha512 \
  --pbkdf pbkdf2 \
  --iter-time 5000 \
  --label root12 \
  /dev/md1
```

Type `YES` and enter your **passphrase**. Choose a long, high-entropy passphrase (20+ characters) to compensate for PBKDF2's lower GPU-brute-force resistance compared to Argon2id.

### 5.3 Format swap12 with LUKS2/Argon2id

```bash
# Argon2id is fine here — GRUB never opens swap
cryptsetup luksFormat \
  --type luks2 \
  --cipher aes-xts-plain64 \
  --key-size 512 \
  --hash sha512 \
  --pbkdf argon2id \
  --iter-time 4000 \
  --label swap12 \
  /dev/md0
```

Type `YES` and enter a passphrase (can be the same as root12 for simpler recovery; dracut uses a keyfile at boot regardless).

### 5.4 Generate and Add a Shared Keyfile

> **Location: this keyfile is created on the LIVE HOST** (`/root/luks-keyfile.bin` in the live environment). It will be copied into the installed system at `/mnt/gentoo/etc/cryptsetup-keys.d/root12.key` in Section 9, and dracut will embed it into the initramfs. The initramfs lives inside the encrypted Btrfs root — so the keyfile is only accessible after GRUB has already unlocked the LUKS container with your passphrase.

```bash
# Generate 4096 bytes of random data as the keyfile
dd if=/dev/urandom of=/root/luks-keyfile.bin bs=512 count=8 iflag=fullblock
chmod 0400 /root/luks-keyfile.bin

# Add keyfile as a second keyslot on root12
# (You will be prompted for the passphrase you set in step 5.2 to authorize the addition)
cryptsetup luksAddKey /dev/md1 /root/luks-keyfile.bin

# Add the same keyfile to swap12
# (Prompted for swap12's passphrase from step 5.3)
cryptsetup luksAddKey /dev/md0 /root/luks-keyfile.bin
```

Confirm two keyslots exist on each volume:

```bash
cryptsetup luksDump /dev/md1 | grep -A10 "Keyslots"
cryptsetup luksDump /dev/md0 | grep -A10 "Keyslots"
```

You should see Keyslot 0 (your passphrase) and Keyslot 1 (the keyfile) on both devices.

### 5.5 Back Up LUKS Headers — Do Not Skip

**What a LUKS header is and why it matters:**

The LUKS header is the first ~4 MB of each LUKS container. It stores:
- The cipher and key derivation parameters
- Encrypted master key copies, one per keyslot (slot 0 = your passphrase, slot 1 = keyfile)

If the LUKS header is corrupted or overwritten (e.g., by accidental `dd`, filesystem expansion, or disk error), the encrypted data becomes **permanently inaccessible** — no matter how strong your passphrase is, without the header the key cannot be recovered. There is no way to reconstruct a lost LUKS header from the data alone.

**What these backups are:**

`luksHeaderBackup` creates an exact binary copy of the LUKS header. If the on-disk header is ever damaged, you can restore it with `luksHeaderRestore` and decrypt your data again. **These are the most critical files you will create during this installation.**

```bash
# Create the backup directory (on the live host, in RAM)
mkdir -p /tmp/luks-backups

# Back up both LUKS headers
cryptsetup luksHeaderBackup /dev/md1 --header-backup-file /tmp/luks-backups/luks-header-root12.img
cryptsetup luksHeaderBackup /dev/md0 --header-backup-file /tmp/luks-backups/luks-header-swap12.img

# Verify the backups are valid binary files
file /tmp/luks-backups/luks-header-root12.img    # Should say: LUKS encrypted file, ver 2
file /tmp/luks-backups/luks-header-swap12.img

ls -lh /tmp/luks-backups/
```

**Copy both backup files and the keyfile to at least one offline location NOW** — a USB drive, a different computer, or encrypted cloud storage — before continuing. If you lose these and the on-disk header is damaged later, your data is gone.

```bash
# Example: copy to a USB drive mounted at /media/backup
cp /tmp/luks-backups/luks-header-root12.img /mnt/usb/LUKS-headers
cp /tmp/luks-backups/luks-header-swap12.img /mnt/usb/LUKS-headers
cp /root/luks-keyfile.bin /mnt/usb/LUKS-headers
```

**How to restore a damaged header (reference for later):** [DO NOT RUN NOW]

```bash
# From a live environment, if the on-disk header is corrupted:
# Assemble the RAID array first:
mdadm --assemble --scan

# Restore the header (WARNING: this overwrites whatever is currently in the header area):
cryptsetup luksHeaderRestore /dev/md1 --header-backup-file /path/to/luks-header-root12.img
cryptsetup luksHeaderRestore /dev/md0 --header-backup-file /path/to/luks-header-swap12.img

# Then open normally:
cryptsetup luksOpen /dev/md1 root12
```

### 5.6 Open Both Volumes and Record UUIDs

```bash
cryptsetup luksOpen /dev/md1 root12
cryptsetup luksOpen /dev/md0 swap12

# Record UUIDs — these are needed throughout the guide
ROOT12_UUID=$(cryptsetup luksUUID /dev/md1) && SWAP12_UUID=$(cryptsetup luksUUID /dev/md0) && echo "ROOT12 LUKS UUID: $ROOT12_UUID" && echo "SWAP12 LUKS UUID: $SWAP12_UUID" && echo "ROOT12_UUID=$ROOT12_UUID" >  /root/luks-uuids.txt && echo "SWAP12_UUID=$SWAP12_UUID" >> /root/luks-uuids.txt
```

---

## 6. Btrfs Filesystem and Tumbleweed-Style Subvolumes

### 6.1 Create the Btrfs Filesystem

```bash
mkfs.btrfs -L root12 /dev/mapper/root12
```

### 6.2 Mount the Top-Level Btrfs Volume

```bash
mkdir -p /mnt/gentoo && mount -o defaults,noatime,compress=zstd:1,space_cache=v2 /dev/mapper/root12 /mnt/gentoo
```

### 6.3 Create the Tumbleweed-Style Subvolume Layout

```bash
# Main root subvolume — all of / lives here
btrfs subvolume create /mnt/gentoo/@

# Snapper snapshot directory (nested inside @)
btrfs subvolume create /mnt/gentoo/@/.snapshots

# Initial snapshot — this BECOMES the active root filesystem
mkdir -p /mnt/gentoo/@/.snapshots/1
btrfs subvolume create /mnt/gentoo/@/.snapshots/1/snapshot

# GRUB EFI subvolume — excluded from root snapshots so GRUB config survives rollbacks
# Note: /boot itself is NOT a subvolume. It is a plain directory inside @,
# so /boot/vmlinuz-* and /boot/initramfs-* ARE captured in every snapshot.
# Only the GRUB config dir is a separate subvolume.
mkdir -p /mnt/gentoo/@/boot/grub2/
btrfs subvolume create /mnt/gentoo/@/boot/grub2/x86_64-efi

# User and application data subvolumes (excluded from root snapshots)
btrfs subvolume create /mnt/gentoo/@/home
btrfs subvolume create /mnt/gentoo/@/opt
btrfs subvolume create /mnt/gentoo/@/root
btrfs subvolume create /mnt/gentoo/@/srv
btrfs subvolume create /mnt/gentoo/@/tmp

# /usr/local subvolume (parent dir must exist first)
mkdir -p /mnt/gentoo/@/usr/
btrfs subvolume create /mnt/gentoo/@/usr/local

# /var — disable Copy-on-Write for database files, journals, and log performance
btrfs subvolume create /mnt/gentoo/@/var
chattr +C /mnt/gentoo/@/var

# /nix — Nix package manager store
# Disable CoW: Nix writes many small files; CoW creates excessive metadata fragmentation.
# Kept outside root snapshots so the Nix store is not rolled back with the OS.
btrfs subvolume create /mnt/gentoo/@/nix
chattr +C /mnt/gentoo/@/nix
```

> **Why `/boot` is a plain directory, not a subvolume:** Btrfs subvolumes are excluded from parent subvolume snapshots. If `/boot` were a subvolume, Snapper snapshots of `@` would not capture the kernel and initramfs — defeating the entire purpose of bootable snapshots. As a plain directory inside `@`, every snapshot of `@` includes the exact kernel and initramfs that were present at snapshot time, guaranteeing kernel/modules version consistency when you boot into that snapshot.
>
> **Why `/boot/grub2/x86_64-efi` IS a subvolume:** GRUB updates its configuration files (adding new snapshot entries, updating kernel paths) in this directory. If it were part of `@`, rolling back `@` would also roll back GRUB's configuration — potentially losing knowledge of the new kernel. As a separate subvolume, GRUB's state is independent of the root rollback.

### 6.4 Create the Initial Snapper info.xml

```bash
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
```

### 6.5 Set Snapshot 1 as the Default Btrfs Subvolume

Setting the default subvolume causes the kernel to mount `@/.snapshots/1/snapshot` as `/` when no `subvol=` option is given. This is how Snapper rollback works — it changes the default subvolume pointer.

```bash
SNAP_ID=$(btrfs subvolume list /mnt/gentoo | grep "@/.snapshots/1/snapshot" | awk '{print $2}')
echo "Setting default subvolume to ID: $SNAP_ID"
btrfs subvolume set-default $SNAP_ID /mnt/gentoo

# Unmount top-level and remount — now mounts the default snapshot
umount /mnt/gentoo
mount -o defaults,noatime,compress=zstd:1,space_cache=v2 /dev/mapper/root12 /mnt/gentoo

# /mnt/gentoo should now appear empty (you are inside @/.snapshots/1/snapshot)
ls /mnt/gentoo
```

### 6.6 Create the Mount Point Skeleton Inside the Active Snapshot

```bash
mkdir -p /mnt/gentoo/.snapshots
mkdir -p /mnt/gentoo/boot/grub2/x86_64-efi
mkdir -p /mnt/gentoo/boot/efi              # Mount point for the ESP
mkdir -p /mnt/gentoo/home
mkdir -p /mnt/gentoo/nix
mkdir -p /mnt/gentoo/opt
mkdir -p /mnt/gentoo/root
mkdir -p /mnt/gentoo/srv
mkdir -p /mnt/gentoo/tmp
mkdir -p /mnt/gentoo/usr/local
mkdir -p /mnt/gentoo/var
```

### 6.7 Mount All Subvolumes

```bash
BTRFS_OPTS="defaults,noatime,compress=zstd:1,space_cache=v2"

mount /dev/mapper/root12 /mnt/gentoo/.snapshots             -o ${BTRFS_OPTS},subvol=@/.snapshots
mount /dev/mapper/root12 /mnt/gentoo/boot/grub2/x86_64-efi -o ${BTRFS_OPTS},subvol=@/boot/grub2/x86_64-efi
mount /dev/mapper/root12 /mnt/gentoo/home                   -o ${BTRFS_OPTS},subvol=@/home
mount /dev/mapper/root12 /mnt/gentoo/nix                    -o defaults,noatime,space_cache=v2,subvol=@/nix
mount /dev/mapper/root12 /mnt/gentoo/opt                    -o ${BTRFS_OPTS},subvol=@/opt
mount /dev/mapper/root12 /mnt/gentoo/root                   -o ${BTRFS_OPTS},subvol=@/root
mount /dev/mapper/root12 /mnt/gentoo/srv                    -o ${BTRFS_OPTS},subvol=@/srv
mount /dev/mapper/root12 /mnt/gentoo/tmp                    -o ${BTRFS_OPTS},subvol=@/tmp
mount /dev/mapper/root12 /mnt/gentoo/usr/local              -o ${BTRFS_OPTS},subvol=@/usr/local
mount /dev/mapper/root12 /mnt/gentoo/var                    -o defaults,noatime,space_cache=v2,subvol=@/var
```

> **Note on `/nix` and `compress=zstd`:** The Nix store stores many binary files that are already compressed. Applying zstd to them wastes CPU without saving space. Omit `compress=zstd:1` for the `/nix` mount.

### 6.8 Mount the ESP

```bash
mount /dev/nvme1n1p1 /mnt/gentoo/boot/efi
```

Verify everything is mounted correctly:

```bash
findmnt --real
```

---

## 7. Swap Configuration

```bash
mkswap -L swap12 /dev/mapper/swap12
swapon /dev/mapper/swap12
swapon --show
```

---

## 8. Gentoo Stage 3 Installation

### 8.1 Download and Verify Stage 3

```bash
cd /mnt/gentoo && wget https://distfiles.gentoo.org/releases/amd64/autobuilds/20260412T164603Z/stage3-amd64-hardened-systemd-20260412T164603Z.tar.xz && tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

```

> **Why the systemd stage3?** This guide uses dracut with systemd modules. The systemd-based initramfs handles the crypttab.initramfs approach (Section 11) cleanly and is the modern Gentoo recommended path for LUKS+Btrfs installations.


### 8.3 Configure the Portage Repository

Seed Portage's ebuild repository config from the template bundled inside the stage3. Without this file, `emerge-webrsync` and `emerge --sync` cannot locate the Gentoo repository:

```bash
mkdir --parents /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf \
   /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
```

---

## 9. Chroot and Base Configuration

### 9.1 Prepare the Chroot Environment

```bash
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

mount --types proc  /proc  /mnt/gentoo/proc
mount --rbind       /sys   /mnt/gentoo/sys
mount --make-rslave        /mnt/gentoo/sys
mount --rbind       /dev   /mnt/gentoo/dev
mount --make-rslave        /mnt/gentoo/dev
mount --bind        /run   /mnt/gentoo/run
mount --make-slave         /mnt/gentoo/run

# Fix /dev/shm if the live environment made it a symlink (common on non-Gentoo live media
# such as Arch or Ubuntu ISOs). After chrooting, a symlink pointing into /run/shm on the
# host becomes a dangling reference inside the chroot.
test -L /dev/shm && rm /dev/shm && mkdir /dev/shm
mount -t tmpfs -o nosuid,nodev,noexec shm /dev/shm
chmod 1777 /dev/shm

# Copy the LUKS keyfile from the live host into the installed system.
# This is the keyfile that dracut will embed in the initramfs.
# It will be stored inside the encrypted Btrfs root — accessible only after GRUB
# has already unlocked the LUKS container with your passphrase.
mkdir -p /mnt/gentoo/etc/cryptsetup-keys.d/
cp /root/luks-keyfile.bin /mnt/gentoo/etc/cryptsetup-keys.d/root12.key
chmod 0400 /mnt/gentoo/etc/cryptsetup-keys.d/root12.key

# Copy the mdadm configuration
cp /etc/mdadm.conf /mnt/gentoo/etc/mdadm.conf

# Save the LUKS UUIDs inside the chroot for later use
cp /root/luks-uuids.txt /mnt/gentoo/root/luks-uuids.txt
```

### 9.2 Copy System Configuration Files to /mnt/gentoo

Before entering the chroot, replace the default stage3 Portage config files with your personalised ones from your dotfiles repo, and seed the root user's home directory with your preferred nano config and the `tc-optimize` script:

```bash
# Remove the default stage3 Portage config files
rm -R /mnt/gentoo/etc/portage/make.conf
rm -R /mnt/gentoo/etc/portage/package.accept_keywords
rm -R /mnt/gentoo/etc/portage/package.use
rm -R /mnt/gentoo/etc/portage/package.mask

# Copy personalised Portage config from dotfiles
# IMPORTANT: Ensure your dotfiles repo now contains a package.use/ directory
# with the themed files (00_system_boot, 10_graphics_display, etc.)
cp -R /home/ahsan/Git/configs/linux-system/gentoo/preconfig/etc/portage/* /mnt/gentoo/etc/portage/

# Copy nanorc and tc-optimize script into root's home inside the new system
cp /home/ahsan/.dots/gentoo/preconfig_files/without_selinux/.nanorc \
   /mnt/gentoo/root/
cp -R /home/ahsan/Git/configs/linux-system/gentoo/preconfig/tc-optimize /mnt/gentoo/root/

```

> **Note:** The `tc-optimize` script and `.nanorc` land at `/root/` inside the installed system. They are accessible immediately after you enter the chroot in the next step.

### 9.3 Enter the Chroot

```bash
chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) $PS1"
```

> **You are now inside the installed system.** All subsequent commands in Sections 9–17 run inside the chroot, unless explicitly marked otherwise.

### 9.4 Sync Portage and Select Profile

```bash
emerge-webrsync
emerge --sync

export TERM=xterm-256color

# List available profiles and select the systemd variant
eselect profile list
eselect profile set 22
emerge --sync

ln -sf ../usr/share/zoneinfo/Asia/Dhaka /etc/localtime && nano /etc/locale.gen && locale-gen && eselect locale list && eselect locale set 4 && env-update && source /etc/profile && export PS1="(chroot) ${PS1}"


emerge sys-apps/portage dev-vcs/git app-eselect/eselect-repository 


ls -d /var/db/pkg/*/* | sed 's|/var/db/pkg/||' > /root/installed-packages.txt
```

### 9.5 Configure /etc/portage/make.conf

```bash
nano /etc/portage/make.conf
```



Replace the file contents with:

```ini
# /etc/portage/make.conf — Gentoo RAID 0 + LUKS + Btrfs, April 2026

# Compiler optimizations
COMMON_FLAGS="-march=native -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"

# Parallel compilation
MAKEOPTS="-j$(nproc) -l$(nproc)"

# Global USE flags for this setup:
#   btrfs        — enable Btrfs support in packages that use it
#   cryptsetup   — enables systemd-cryptsetup-generator (critical for LUKS at boot)
#   device-mapper — enables device-mapper support in packages
#   systemd      — use systemd as the init system
#
# NOTE: 'mdadm' is NOT a standard global USE flag; sys-fs/mdadm is installed explicitly.
# NOTE: 'elogind' is intentionally absent to avoid conflict with systemd-logind.
USE="btrfs cryptsetup device-mapper systemd"

# GRUB_PLATFORMS: Explicit EFI-64 support.
# Gentoo's amd64 profile does not set this to efi-64 by default (it defaults to 'pc').
# Without this, grub-install will not install EFI support correctly.
GRUB_PLATFORMS="efi-64"

ACCEPT_KEYWORDS="amd64"

# These are set by Portage; do not change:
PORTDIR="/var/db/repos/gentoo"
DISTDIR="/var/cache/distfiles"
PKGDIR="/var/cache/binpkgs"
```

Now add CPU-specific flags:

```bash
emerge --ask app-portage/cpuid2cpuflags
echo "*/* $(cpuid2cpuflags)" >> /etc/portage/package.use/cpuflags
```

### 9.6 Configure Package-Specific USE Flags and Install Required Packages

Create the necessary per-package USE flag files:

```bash
mkdir -p /etc/portage/package.use

# sys-apps/systemd: 'cryptsetup' installs systemd-cryptsetup-generator,
# which processes /etc/crypttab (and /etc/crypttab in initramfs) at boot.
# This is REQUIRED for automated LUKS unlock via crypttab.initramfs.
cat > /etc/portage/package.use/systemd << 'EOF'
sys-apps/systemd cryptsetup
EOF

# sys-boot/grub: 'device-mapper' enables support for dm-crypt/LUKS in grub-install
cat > /etc/portage/package.use/grub << 'EOF'
sys-boot/grub:2 device-mapper
EOF

# sys-kernel/dracut: 'device-mapper' + 'systemd' ensure dm-crypt and systemd-initrd
# module support are compiled in
cat > /etc/portage/package.use/dracut << 'EOF'
sys-kernel/dracut device-mapper systemd
EOF

# sys-fs/cryptsetup: 'static' flag allows cryptsetup to be statically linked,
# which is needed for dracut to embed it correctly in the initramfs
cat > /etc/portage/package.use/cryptsetup << 'EOF'
sys-fs/cryptsetup static
EOF

# sys-kernel/installkernel: 'dracut' runs dracut after kernel install;
# 'grub' runs grub-mkconfig after kernel install.
# Together these automate the entire kernel update workflow.
cat > /etc/portage/package.use/installkernel << 'EOF'
sys-kernel/installkernel dracut grub
EOF
```

Now emerge all required packages:

```bash
emerge --ask \
  sys-fs/mdadm \
  sys-fs/cryptsetup \
  sys-fs/btrfs-progs \
  sys-boot/grub:2 \
  sys-kernel/dracut \
  sys-kernel/gentoo-sources \
  sys-kernel/installkernel \
  app-backup/snapper \
  app-misc/inotify-tools \
  sys-firmware/linux-firmware
```

---

## 10. Kernel Configuration, installkernel, and Compilation

### 10.1 What sys-kernel/installkernel Does

`sys-kernel/installkernel` is a hook that runs automatically when a kernel is installed via `make install`. With `USE="dracut grub"`:

- After `make install` copies the kernel to `/boot`, installkernel runs **dracut** to generate a new initramfs for that kernel version
- Then it runs **`grub-mkconfig`** to regenerate `/boot/grub/grub.cfg`

This automates the entire kernel update workflow. You compile and install a kernel once, and both the initramfs and GRUB config are updated without manual intervention.

**Is installkernel required in our setup?** No — it is not strictly required. You could run `dracut --force` and `grub-mkconfig` manually after each `make install`. However, installkernel is strongly recommended because:
- It ensures the initramfs is always rebuilt when a new kernel is installed
- It eliminates a common mistake (forgetting to rebuild the initramfs after a kernel update)
- It is the modern, documented Gentoo approach

> **Important caveat:** installkernel's dracut invocation uses the configuration in `/etc/dracut.conf.d/`. Our custom configuration files (Section 11) must be in place before the first `make install` is run. If you run `make install` before configuring dracut, installkernel will generate an initramfs with the wrong settings. **Configure dracut first (Section 11), then compile and install the kernel (Section 10.2–10.3).**

The guide is structured accordingly: dracut configuration (Section 11) is written to disk before `make install` is executed.

### 10.2 Select Kernel Sources

```bash
eselect kernel list
eselect kernel set 1
cd /usr/src/linux
```

### 10.3 Configure the Kernel

#### Build with llvm 03
```bash
make menuconfig LLVM=1 KCFLAGS="-O3 -march=native -pipe -flto=thin"
make -j14 LLVM=1 KCFLAGS="-O3 -march=native -pipe -flto=thin"
make modules_install -j14 LLVM=1 KCFLAGS="-O3 -march=native -pipe -flto=thin"
emerge x11-drivers/nvidia-drivers gui-libs/egl-wayland gui-libs/egl-gbm gui-libs/egl-x11 media-libs/nvidia-vaapi-driver sys-process/nvtop x11-drivers/xf86-video-amdgpu
make install LLVM=1 KCFLAGS="-O3 -march=native -pipe -flto=thin"
```

```bash
make menuconfig
```

Enable the following options (use `/` to search by CONFIG name):

**RAID and Device Mapper:**
```
Device Drivers → Multiple devices driver support (RAID and LVM):
  [*] Multiple devices driver support (RAID and LVM)      CONFIG_MD
  <*>   RAID support                                       CONFIG_BLK_DEV_MD
  [*]     Autodetect RAID arrays during kernel boot        CONFIG_MD_AUTODETECT
  <*>     RAID-0 (striping) mode                           CONFIG_MD_RAID0
  <*>   Device mapper support                              CONFIG_BLK_DEV_DM
  <*>     Crypt target support                             CONFIG_DM_CRYPT
```

**Filesystems:**
```
File systems:
  <*> Btrfs filesystem support                 CONFIG_BTRFS_FS
  [*]   Btrfs POSIX Access Control Lists       CONFIG_BTRFS_FS_POSIX_ACL

General setup:
  [*] Initial RAM filesystem and RAM disk support   CONFIG_BLK_DEV_INITRD

Device Drivers → Generic Driver Options:
  [*] Maintain a devtmpfs filesystem to mount at /dev  CONFIG_DEVTMPFS
  [*]   Automount devtmpfs at /dev                     CONFIG_DEVTMPFS_MOUNT
```

**Cryptographic API:**
```
Cryptographic API:
  <*> SHA384 and SHA512 digest algorithm        CONFIG_CRYPTO_SHA512
  <*> XTS support                               CONFIG_CRYPTO_XTS
  <*> AES cipher algorithms                     CONFIG_CRYPTO_AES
  <*> AES cipher algorithms (x86_64)            CONFIG_CRYPTO_AES_X86_64
```

**Power Management (required for hibernation):**
```
Power management and ACPI options:
  [*] Suspend to RAM and standby     CONFIG_SUSPEND
  [*] Hibernation (suspend to disk)  CONFIG_HIBERNATION
```

**NVMe:**
```
Device Drivers → NVME Support:
  <*> NVM Express block device      CONFIG_BLK_DEV_NVME
```

**EFI:**
```
Firmware Drivers:
  [*] EFI Runtime service support    CONFIG_EFI
  [*] EFI stub support               CONFIG_EFI_STUB
```

### 10.4 Configure Dracut Before Installing the Kernel

**Do this now, before `make install`**, so that installkernel's automatic dracut invocation picks up the correct configuration.

Complete Section 11 (all of it) before running `make install` in step 10.5.

### 10.5 Compile and Install the Kernel

```bash
# Compile kernel and modules
make -j$(nproc)

# Install kernel modules to /lib/modules/
make modules_install

# Install kernel — this triggers installkernel, which:
# 1. Copies vmlinuz to /boot/
# 2. Runs dracut with your config from /etc/dracut.conf.d/ → generates initramfs
# 3. Runs grub-mkconfig → regenerates /boot/grub/grub.cfg
make install

# Confirm the kernel, initramfs, and updated grub.cfg are present
ls -lh /boot/vmlinuz-* /boot/initramfs-* /boot/grub/grub.cfg
```

If `make install` completes successfully, both the initramfs and GRUB config are already generated. You can verify the initramfs contents:

```bash
KVER=$(ls /lib/modules/ | sort -V | tail -1)
lsinitrd /boot/initramfs-${KVER}.img | grep -E "(root12\.key|mdadm\.conf|crypttab|crypt)"
```

---

## 11. Dracut Initramfs Configuration (Single-Password Unlock)

> **Complete this section BEFORE running `make install` in Section 10.5.** installkernel's automatic dracut invocation reads these files.

Dracut runs after GRUB has already unlocked the root partition and loaded the kernel. Its jobs are:

1. Reassemble the RAID arrays (`mdraid` module)
2. Silently unlock both LUKS volumes using a keyfile embedded in the initramfs
3. Mount the Btrfs root and hand off to systemd

**Module and keyfile strategy (verified):**

This guide uses the `crypt` + `systemd` + `systemd-initrd` dracut modules. The `systemd-cryptsetup-generator` in the initramfs reads `/etc/crypttab` (which dracut populates from `/etc/crypttab.initramfs`) and creates `cryptsetup@*.service` units to unlock each LUKS volume using the embedded keyfile.

> **Why NOT `rd.luks.key` in kernel_cmdline when using the systemd dracut module?** The dracut man page explicitly states: *"If you do need `rd.luks.key` to work, you will have to exclude the 'systemd' dracut module and any modules that depend on it."* Using `rd.luks.key` alongside the systemd module can cause keyfile-based unlock to be silently ignored, resulting in unexpected password prompts. The `crypttab.initramfs` approach is the correct, supported method for systemd-based initramfs.
>
> **Do NOT use both `crypt` and `sd-encrypt`** in `add_dracutmodules`. They serve the same purpose and conflict. This guide uses `crypt` together with `systemd`/`systemd-initrd`.

### 11.1 Main Dracut Configuration

```bash
mkdir -p /etc/dracut.conf.d/

cat > /etc/dracut.conf.d/00-gentoo.conf << 'EOF'
# /etc/dracut.conf.d/00-gentoo.conf
# Gentoo — RAID 0 + LUKS2 + Btrfs + Snapper, April 2026

# Build only for this machine's hardware (smaller, faster image)
hostonly="yes"
hostonly_cmdline="yes"

# Dracut modules to include:
#   crypt        — LUKS support (reads /etc/crypttab in initramfs, uses keyfiles)
#   mdraid       — software RAID assembly via mdadm
#   btrfs        — Btrfs filesystem support
#   systemd      — use systemd as the initramfs PID 1
#   systemd-initrd — systemd generator support in initramfs (runs cryptsetup generator)
#
# IMPORTANT: Do NOT add 'sd-encrypt' — it conflicts with 'crypt'.
# Do NOT add 'dmraid' — that is for hardware RAID (fakeRAID), not mdadm software RAID.
add_dracutmodules+=" crypt mdraid btrfs systemd systemd-initrd "

# Kernel modules to explicitly include
add_drivers+=" raid0 dm_crypt dm_mod aes_x86_64 sha512_generic sha256_generic xts "

# Filesystems
filesystems+=" btrfs "

# Include the mdadm.conf (array definitions) in the initramfs
mdadmconf="yes"

# Include the LUKS keyfile in the initramfs.
# This keyfile is stored in the initramfs, which is itself inside the encrypted Btrfs root.
# It cannot be accessed without first providing the GRUB passphrase.
install_items+=" /etc/cryptsetup-keys.d/root12.key "

# Include /etc/crypttab.initramfs as /etc/crypttab in the initramfs.
# systemd-cryptsetup-generator reads this and creates unlock service units.
# (dracut handles this automatically when crypttab.initramfs is present)

# Use /etc/fstab as a hint for the root filesystem
use_fstab="yes"

# Compression
compress="zstd"

# Include CPU microcode updates (applied before kernel starts via initramfs split)
early_microcode="yes"
EOF
```

### 11.2 Create /etc/crypttab.initramfs

This file is the systemd-correct replacement for `rd.luks.key`. Dracut embeds it as `/etc/crypttab` in the initramfs. The `systemd-cryptsetup-generator` inside the initramfs reads it and creates `systemd-cryptsetup@root12.service` and `systemd-cryptsetup@swap12.service`, each configured to use the keyfile.

```bash
# Load UUIDs saved from Section 5.6
cat /root/luks-uuids.txt
export ROOT12_UUID=$(grep ROOT12 /root/luks-uuids.txt | cut -d= -f2)
export SWAP12_UUID=$(grep SWAP12 /root/luks-uuids.txt | cut -d= -f2)
echo "root12 UUID: $ROOT12_UUID"
echo "swap12 UUID: $SWAP12_UUID"

# Create the initramfs-specific crypttab
# Syntax: name   UUID=<LUKS UUID>   keyfile   options
cat > /etc/crypttab.initramfs << EOF
root12    UUID=${ROOT12_UUID}    /etc/cryptsetup-keys.d/root12.key    luks,discard
swap12    UUID=${SWAP12_UUID}    /etc/cryptsetup-keys.d/root12.key    luks,discard
EOF

chmod 600 /etc/crypttab.initramfs
cat /etc/crypttab.initramfs   # Verify UUIDs are correct
```

### 11.3 Kernel Command Line Parameters

```bash
cat > /etc/dracut.conf.d/01-luks.conf << EOF
# /etc/dracut.conf.d/01-luks.conf
# Kernel command line parameters embedded in the initramfs.

# rd.luks=1: enable LUKS support in dracut
# rd.luks.uuid: identify which LUKS devices to activate
#   (dracut strips 'luks-' prefix before UUID comparison)
# rd.luks.allow-discards: pass TRIM/discard to underlying NVMe devices
# rootfstype=btrfs: filesystem type hint for the initramfs

kernel_cmdline+=" rd.luks=1 "
kernel_cmdline+=" rd.luks.uuid=luks-${ROOT12_UUID} "
kernel_cmdline+=" rd.luks.uuid=luks-${SWAP12_UUID} "
kernel_cmdline+=" rd.luks.allow-discards "
kernel_cmdline+=" rootfstype=btrfs "
EOF
```

> **Important:** `rootflags=subvol=...` is intentionally **not** embedded here. It is managed by GRUB via `grub-mkconfig`, which auto-detects the active Btrfs default subvolume. Hardcoding the subvolume path here would break boot after every Snapper rollback (since the path changes).

### 11.4 Generate the Initramfs Manually (First Time)

The first initramfs generation is triggered manually. Subsequent regenerations happen automatically via `installkernel` after each `make install`.

```bash
KVER=$(ls /lib/modules/ | sort -V | tail -1)
echo "Building initramfs for kernel: $KVER"

dracut --force --verbose /boot/initramfs-${KVER}.img ${KVER}

ls -lh /boot/initramfs-${KVER}.img
```

Verify the critical components are embedded:

```bash
# Check keyfile is present
lsinitrd /boot/initramfs-${KVER}.img | grep "root12.key"

# Check crypttab.initramfs was embedded as /etc/crypttab
lsinitrd /boot/initramfs-${KVER}.img | grep "crypttab"

# Check mdadm.conf is present
lsinitrd /boot/initramfs-${KVER}.img | grep "mdadm.conf"

# Check crypt module is included
lsinitrd /boot/initramfs-${KVER}.img | grep "90crypt"
```

---

## 12. GRUB Bootloader Configuration

Since `/boot` is inside the encrypted LUKS root, GRUB must decrypt the container before it can read its own config and the kernel. This requires `GRUB_ENABLE_CRYPTODISK=y` and preloaded modules for mdadm RAID, LUKS2, and Btrfs.

### 12.1 Configure /etc/default/grub

```bash
# Load UUIDs in case they fell out of scope
export ROOT12_UUID=$(grep ROOT12 /root/luks-uuids.txt | cut -d= -f2)
export SWAP12_UUID=$(grep SWAP12 /root/luks-uuids.txt | cut -d= -f2)

cat > /etc/default/grub << 'EOF'
# /etc/default/grub — April 2026
# /boot is inside the LUKS2-encrypted Btrfs root on RAID 0 (md1)

GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Gentoo"

# CRITICAL: Required because /boot is inside the encrypted root.
# This embeds a cryptomount stub in grubx64.efi.
GRUB_ENABLE_CRYPTODISK=y

# Modules GRUB must preload before it can find and read the kernel:
#   part_gpt     — read GPT partition tables on NVMe drives
#   mdraid1x     — assemble mdadm RAID arrays with metadata version 1.x
#   cryptodisk   — dm-crypt / LUKS container support
#   luks2        — LUKS2 format support (requires PBKDF2 on the root partition)
#   gcry_rijndael — AES (Rijndael) decryption
#   gcry_sha512  — SHA-512 (used by PBKDF2 key derivation)
#   btrfs        — read Btrfs filesystem and navigate subvolumes
GRUB_PRELOAD_MODULES="part_gpt mdraid1x cryptodisk luks2 gcry_rijndael gcry_sha512 btrfs"

# Kernel parameters:
#   resume= points to the decrypted swap device for hibernate/resume
#   loglevel=3: suppress most kernel messages on boot
GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3"
GRUB_CMDLINE_LINUX="resume=/dev/mapper/swap12"
EOF
```

### 12.2 Install GRUB to the ESP

```bash
# Verify ESP is mounted
ls /boot/efi/EFI 2>/dev/null || mount /dev/nvme1n1p1 /boot/efi

grub-install \
  --target=x86_64-efi \
  --efi-directory=/boot/efi \
  --bootloader-id=Gentoo \
  --modules="part_gpt mdraid1x cryptodisk luks2 gcry_rijndael gcry_sha512 btrfs" \
  --recheck
```

**How GRUB decrypts the root at boot (step by step):**

1. UEFI firmware loads `grubx64.efi` from the ESP
2. GRUB loads `mdraid1x` and assembles `md1` from `nvme1n1p3` + `nvme0n1p2`
3. GRUB loads `cryptodisk` + `luks2` and runs `cryptomount` on `md1`
4. **One passphrase prompt** — the user enters the LUKS passphrase
5. GRUB reads `grub.cfg` from the now-unlocked Btrfs (at the default subvolume path)
6. GRUB loads the kernel and initramfs from `/boot/` inside that snapshot
7. The kernel starts; dracut's systemd-initramfs unlocks both LUKS volumes via keyfile (no prompt)

### 12.3 Generate grub.cfg

```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

Verify the generated config contains the essential crypto and RAID modules:

```bash
grep -E "(insmod cryptodisk|insmod luks|insmod mdraid)" /boot/grub/grub.cfg | head -5
```

If these lines are absent, GRUB cannot decrypt the root at boot. Re-run `grub-install` with the `--modules` flag and regenerate.

### 12.4 Set Btrfs Relative Path for Snapshot Booting

GRUB requires `btrfs_relative_path="yes"` when the default Btrfs subvolume is a snapshot rather than the top-level volume. Add this to a custom file that survives `grub-mkconfig` regeneration:

```bash
cat >> /etc/grub.d/40_custom << 'EOF'
set btrfs_relative_path="yes"
EOF

grub-mkconfig -o /boot/grub/grub.cfg
```

---

## 13. fstab Configuration

```bash
# Get the UUIDs of the mapper devices
ROOT_BTRFS_UUID=$(blkid -s UUID -o value /dev/mapper/root12)
SWAP_MAPPER_UUID=$(blkid -s UUID -o value /dev/mapper/swap12)
EFI_UUID=$(blkid -s UUID -o value /dev/nvme1n1p1)

cat > /etc/fstab << EOF
# /etc/fstab — Gentoo RAID 0 + LUKS2 + Btrfs (Tumbleweed-style), April 2026
# /boot lives inside the encrypted Btrfs root — there is no separate /boot entry

# --- Encrypted root Btrfs subvolumes ---
# Active root snapshot. Update subvol= after every Snapper rollback (see Section 19).
UUID=${ROOT_BTRFS_UUID}  /                       btrfs  defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@/.snapshots/1/snapshot  0 0

# Snapper snapshot directory — always @/.snapshots, independent of the active root
UUID=${ROOT_BTRFS_UUID}  /.snapshots             btrfs  defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@/.snapshots  0 0

# GRUB EFI config subvolume — excluded from snapshots, survives rollbacks
UUID=${ROOT_BTRFS_UUID}  /boot/grub2/x86_64-efi  btrfs  defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@/boot/grub2/x86_64-efi  0 0

# User and application data subvolumes
UUID=${ROOT_BTRFS_UUID}  /home                   btrfs  defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@/home  0 0
UUID=${ROOT_BTRFS_UUID}  /nix                    btrfs  defaults,noatime,space_cache=v2,subvol=@/nix  0 0
UUID=${ROOT_BTRFS_UUID}  /opt                    btrfs  defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@/opt  0 0
UUID=${ROOT_BTRFS_UUID}  /root                   btrfs  defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@/root  0 0
UUID=${ROOT_BTRFS_UUID}  /srv                    btrfs  defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@/srv  0 0
UUID=${ROOT_BTRFS_UUID}  /tmp                    btrfs  defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@/tmp  0 0
UUID=${ROOT_BTRFS_UUID}  /usr/local              btrfs  defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@/usr/local  0 0
UUID=${ROOT_BTRFS_UUID}  /var                    btrfs  defaults,noatime,space_cache=v2,subvol=@/var  0 0

# --- EFI System Partition (unencrypted, GRUB EFI binary only) ---
UUID=${EFI_UUID}          /boot/efi               vfat   defaults,noatime  0 2

# --- Encrypted swap (LUKS RAID 0, for hibernation) ---
UUID=${SWAP_MAPPER_UUID}  none                    swap   defaults,pri=100  0 0
EOF

cat /etc/fstab    # Verify
```

> **After every Snapper rollback:** The root entry's `subvol=@/.snapshots/1/snapshot` must be updated to match the new active snapshot path (e.g., `@/.snapshots/5/snapshot`). See Section 19 for the rollback procedure.
>
> **The `/nix` entry** has no `compress=zstd:1` because the Nix store primarily contains already-compressed binary data. Applying zstd would waste CPU cycles.

---

## 14. Snapper Integration

### 14.1 Initialize Snapper Root Configuration

```bash
# --no-dbus is required — D-Bus is not running inside the chroot
snapper --no-dbus -c root create-config /
```

### 14.2 Customize the Snapper Configuration

```bash
nano /etc/snapper/configs/root
```

Set these values (the defaults for most fields are fine; adjust the limits to taste):

```ini
SUBVOLUME="/"
FSTYPE="btrfs"

# Timeline snapshots — created automatically by snapper-timeline.timer
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="3"
TIMELINE_LIMIT_YEARLY="0"

# Number-based cleanup for pre/post pairs
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="25"
NUMBER_LIMIT_IMPORTANT="10"
```

### 14.3 Portage Hooks for Automatic Pre/Post Snapshots

The following adds pre/post snapshot pairs around each package installation. This uses the correct Portage phase hook API — `pre_pkg_preinst` runs just before files are installed to the live filesystem, and `post_pkg_postinst` runs just after the install finishes.

> **Why `pre_pkg_preinst` and `post_pkg_postinst` and not `pre_emerge`/`post_emerge`?** Portage does not have `pre_emerge` or `post_emerge` hook names. The valid hook names follow the pattern `{pre_,post_}phase_name` where `phase_name` is an ebuild phase (`pkg_setup`, `src_compile`, `pkg_preinst`, `pkg_postinst`, etc.). The `pre_pkg_preinst` / `post_pkg_postinst` pair captures the system state just before and just after files are written to disk — which is exactly the correct moment for a Btrfs snapshot.
>
> This creates one pre/post pair per package. For busy systems doing large upgrades, this generates many snapshots. The `NUMBER_LIMIT` in the Snapper config controls how many are retained.

```bash
cat > /etc/portage/bashrc << 'BASHRC'
# /etc/portage/bashrc — Snapper pre/post snapshot hooks for Portage
# Uses correct Portage phase hook API (pre_pkg_preinst / post_pkg_postinst)

pre_pkg_preinst() {
    # Create a pre-snapshot before any package files are written to the filesystem.
    # CATEGORY, PF are standard Portage environment variables available in all hooks.
    if command -v snapper &>/dev/null; then
        SNAPPER_PRE_NUM=$(snapper -c root create \
            --type pre \
            --print-number \
            --cleanup-algorithm number \
            --description "portage pre: ${CATEGORY}/${PF}" 2>/dev/null)
        export SNAPPER_PRE_NUM
    fi
}

post_pkg_postinst() {
    # Create a post-snapshot after the package is fully installed.
    # Only create if a pre-snapshot exists for this package.
    if command -v snapper &>/dev/null && [[ -n "${SNAPPER_PRE_NUM}" ]]; then
        snapper -c root create \
            --type post \
            --pre-number "${SNAPPER_PRE_NUM}" \
            --cleanup-algorithm number \
            --description "portage post: ${CATEGORY}/${PF}" 2>/dev/null
        unset SNAPPER_PRE_NUM
    fi
}
BASHRC
```

### 14.4 Enable Snapper Timers

```bash
systemctl enable snapper-timeline.timer   # Creates timeline snapshots
systemctl enable snapper-cleanup.timer    # Purges old snapshots per config limits
systemctl enable snapper-boot.timer       # Creates a snapshot on each boot
```

### 14.5 Set Correct Permissions on /.snapshots

```bash
chmod 750 /.snapshots
```

---

## 15. grub-btrfs for Bootable Snapshots

### 15.1 Enable the GURU Overlay and Install

`app-backup/grub-btrfs` is only available in the Gentoo GURU overlay, not the main Portage tree:

```bash
emerge --ask app-eselect/eselect-repository
eselect repository enable guru
emaint sync -r guru

# Set the systemd USE flag to install the systemd daemon (grub-btrfsd.service)
# instead of the OpenRC init script
echo "app-backup/grub-btrfs systemd" >> /etc/portage/package.use/grub-btrfs

emerge --ask app-backup/grub-btrfs
```

### 15.2 Configure grub-btrfs

```bash
nano /etc/default/grub-btrfs/config
```

Key settings:

```ini
# Snapshot directory (Snapper default)
GRUB_BTRFS_SNAPSHOT_DIRNAME=".snapshots"

# GRUB submenu name for snapshot entries
GRUB_BTRFS_SUBMENUNAME="Btrfs Snapshots"

# Standard Gentoo GRUB paths
GRUB_BTRFS_GRUB_DIRNAME="/boot/grub"
GRUB_BTRFS_MKCONFIG=/usr/sbin/grub-mkconfig
GRUB_BTRFS_SCRIPT_CHECK=grub-script-check
GRUB_BTRFS_MKCONFIG_LIB=/usr/share/grub/grub-mkconfig_lib

# Boot directory location inside snapshots
GRUB_BTRFS_BOOT_DIRNAME="/boot"

# Show snapshot timestamps and descriptions in GRUB menu
GRUB_BTRFS_SHOW_SNAPSHOTS_FOUND="true"
```

### 15.3 Enable the grub-btrfsd Daemon

```bash
systemctl enable grub-btrfsd.service
```

`grub-btrfsd` watches `/.snapshots` for changes. When Snapper creates or deletes a snapshot, it automatically regenerates `grub.cfg` to update the boot menu.

### 15.4 Generate the Initial GRUB Config with Snapshot Entries

```bash
grub-mkconfig -o /boot/grub/grub.cfg

# Verify snapshot entries were added
grep -c "snapshot" /boot/grub/grub.cfg
```

---

## 16. Hibernation Support

Hibernation works because:
- `rd.luks.uuid=luks-<SWAP12_UUID>` in the initramfs (via `crypttab.initramfs`) causes dracut to unlock `swap12` during early boot — before the resume mechanism tries to read the hibernation image
- `resume=/dev/mapper/swap12` in `GRUB_CMDLINE_LINUX` tells the kernel where the hibernation image is stored
- `CONFIG_HIBERNATION=y` is enabled in the kernel

### 16.1 Verify Resume Configuration

```bash
grep resume /boot/grub/grub.cfg
```

### 16.2 Enable Hibernate Target

```bash
systemctl enable hibernate.target
systemctl status hibernate.target
```

---

## 17. Final System Services and Boot

### 17.1 Set Root Password

```bash
passwd && emerge app-admin/sudo genfstab && useradd -m -G users,wheel,audio,video -s /bin/bash ahsan && passwd ahsan && EDITOR=nvim visudo
```

### 17.2 Set Hostname

```bash
echo "workstation" > /etc/hostname
```

### 17.3 Configure /etc/crypttab for the Running System

The running system's `/etc/crypttab` is separate from `/etc/crypttab.initramfs`. The initramfs version unlocks LUKS at early boot. The running system's crypttab can also reference these entries, but doing so causes systemd to try unlocking already-open devices — which produces errors.

The strategy: write the entries (with keyfile) so systemd knows the device names, but mark them with `noauto` so systemd does not try to open them itself.

```bash
cat > /etc/crypttab << EOF
# /etc/crypttab — Running system (NOT the initramfs version)
# LUKS volumes are opened by dracut in initramfs using /etc/crypttab.initramfs.
# Entries here use 'noauto' to prevent systemd from re-opening them at runtime.
# name    device                          keyfile                               options
root12    UUID=${ROOT12_UUID}    /etc/cryptsetup-keys.d/root12.key    luks,discard,noauto
swap12    UUID=${SWAP12_UUID}    /etc/cryptsetup-keys.d/root12.key    luks,discard,noauto
EOF
```

> **Why `noauto`?** Without `noauto`, systemd-cryptsetup-generator reads `/etc/crypttab` at runtime and attempts to open the LUKS containers. They are already open (dracut opened them in the initramfs), so systemd's attempt fails. With `noauto`, systemd records the mapping but does not try to open it.

### 17.4 Rebuild Initramfs (With crypttab.initramfs in Place)

If you followed the recommended order (Section 11 before Section 10.5), the initramfs was already built correctly by `make install`. If you need to rebuild manually:

```bash
KVER=$(ls /lib/modules/ | sort -V | tail -1)
dracut --force --verbose /boot/initramfs-${KVER}.img ${KVER}
grub-mkconfig -o /boot/grub/grub.cfg
```

### 17.5 Enable Essential Services

```bash
# RAID monitoring — correct service name on systemd is mdmonitor.service
# (NOT mdadm.service, which does not exist on systemd-based Gentoo)
systemctl enable mdmonitor.service

systemctl preset-all

# Network management (choose one)
systemctl enable NetworkManager
# OR for minimal server setups:
# systemctl enable systemd-networkd systemd-resolved
```

### 17.6 Final Sanity Check

```bash
# Verify crypto modules appear in grub.cfg
grep "insmod cryptodisk\|insmod luks\|insmod mdraid" /boot/grub/grub.cfg | head -5

# Verify keyfile is in initramfs
KVER=$(ls /lib/modules/ | sort -V | tail -1)
lsinitrd /boot/initramfs-${KVER}.img | grep "root12.key"

# Verify crypttab.initramfs is in initramfs as /etc/crypttab
lsinitrd /boot/initramfs-${KVER}.img | grep -E "etc/crypttab"
```

### 17.7 Exit Chroot and Reboot

```bash
exit  # Exit chroot

# Unmount in reverse order
umount -l /mnt/gentoo/dev /mnt/gentoo/sys /mnt/gentoo/proc /mnt/gentoo/run
umount /mnt/gentoo/boot/efi
umount /mnt/gentoo/.snapshots
umount /mnt/gentoo/boot/grub2/x86_64-efi
umount /mnt/gentoo/home /mnt/gentoo/nix /mnt/gentoo/opt /mnt/gentoo/root
umount /mnt/gentoo/srv /mnt/gentoo/tmp /mnt/gentoo/usr/local /mnt/gentoo/var
umount /mnt/gentoo

swapoff /dev/mapper/swap12
cryptsetup close swap12
cryptsetup close root12
mdadm --stop /dev/md0
mdadm --stop /dev/md1

reboot
```

---

## 18. Post-Install Verification

After the first successful boot:

```bash
# RAID status
cat /proc/mdstat
mdadm --detail /dev/md0
mdadm --detail /dev/md1

# LUKS status — both should show 'is active and is in use'
cryptsetup status root12
cryptsetup status swap12

# Btrfs layout
btrfs subvolume list /
btrfs subvolume get-default /    # Should show @/.snapshots/1/snapshot

# Confirm /boot is inside the encrypted root (not a separate partition)
df -h /boot                       # Should show /dev/mapper/root12
ls /boot/vmlinuz-* /boot/initramfs-*

# /nix subvolume
btrfs subvolume show /nix
df -h /nix

# Snapper
snapper -c root list

# grub-btrfsd
systemctl status grub-btrfsd

# Create a baseline snapshot and verify it appears in GRUB
snapper -c root create --description "post-install baseline"
grub-mkconfig -o /boot/grub/grub.cfg
grep "snapshot" /boot/grub/grub.cfg | head -5

# Hibernation capability
cat /sys/power/state    # Should include 'disk'
```

---

## 19. Rollback Procedure

### 19.1 Boot into a Snapshot (Non-Destructive Test)

At GRUB → **"Btrfs Snapshots"** submenu → select a snapshot. GRUB prompts for the LUKS passphrase, loads the kernel **from inside that snapshot**, and mounts it read-only. Because both the kernel and its modules come from the same snapshot, there is no version mismatch.

### 19.2 Commit a Rollback via Snapper

```bash
# List snapshots
snapper -c root list

# Roll back to snapshot N
snapper -c root rollback N

reboot
```

After rebooting into the new active snapshot, update `/etc/fstab` to reflect the new subvolume path:

```bash
# Change the root entry's subvol= from @/.snapshots/1/snapshot to @/.snapshots/N/snapshot
nano /etc/fstab

# Regenerate GRUB config (now points to the new default subvolume)
grub-mkconfig -o /boot/grub/grub.cfg
```

### 19.3 Manual Rollback from a Live Environment

```bash
# Assemble RAID and open LUKS
mdadm --assemble --scan
cryptsetup luksOpen /dev/md1 root12

# Mount top-level Btrfs (subvolid=5 = top-level volume)
mkdir -p /mnt/gentoo
mount -o subvolid=5 /dev/mapper/root12 /mnt/gentoo

# List snapshots
btrfs subvolume list /mnt/gentoo | grep snapshots

# Set desired snapshot as default (replace <ID> with the subvolume ID from the list above)
btrfs subvolume set-default <ID> /mnt/gentoo

umount /mnt/gentoo
cryptsetup close root12
reboot
```

After booting into the rolled-back snapshot, update `/etc/fstab` as described above.

---

## 20. Troubleshooting

### GRUB drops to `grub>` shell — cannot find encrypted device

```grub
insmod mdraid1x
insmod cryptodisk
insmod luks2
insmod btrfs
ls
cryptomount -u <ROOT12_UUID_no_dashes>
set root=(crypto0)
set prefix=(crypto0)/boot/grub
configfile $prefix/grub.cfg
```

If this works, GRUB's installed modules are incomplete. Re-run `grub-install` with the full `--modules` list from Section 12.2.

### GRUB error: "LUKS2 only supports PBKDF2, Argon2 is not supported"

root12 was formatted with Argon2id. Fix from a live environment (data is preserved):

```bash
mdadm --assemble --scan
# Convert PBKDF on root12 keyslot to PBKDF2 (enter your passphrase when prompted)
cryptsetup luksConvertKey /dev/md1 --pbkdf pbkdf2
cryptsetup luksDump /dev/md1 | grep PBKDF    # Verify
```

### dracut drops to emergency shell — RAID not assembled

```bash
# Inside emergency shell:
mdadm --assemble --scan
lsblk
```

Rebuild the initramfs with explicit mdraid support:

```bash
dracut --force --add mdraid /boot/initramfs-$(uname -r).img $(uname -r)
```

### dracut prompts for LUKS password (second prompt after GRUB)

The `crypttab.initramfs` approach is not working. Diagnose:

```bash
# Check /etc/crypttab is present in the initramfs (it was embedded from crypttab.initramfs)
lsinitrd /boot/initramfs-$(uname -r).img | grep -E "etc/crypttab$"

# Check keyfile is present
lsinitrd /boot/initramfs-$(uname -r).img | grep "root12.key"

# Check the UUIDs in the embedded crypttab match the actual LUKS UUIDs
lsinitrd -f /etc/crypttab /boot/initramfs-$(uname -r).img
cryptsetup luksUUID /dev/md1
cryptsetup luksUUID /dev/md0
```

If the embedded `/etc/crypttab` is absent, ensure `/etc/crypttab.initramfs` exists and rebuild:

```bash
cat /etc/crypttab.initramfs   # Should have root12 and swap12 entries
dracut --force --verbose /boot/initramfs-$(uname -r).img $(uname -r)
```

### systemd prompts for LUKS password on the running system

The running system's `/etc/crypttab` has active (non-noauto) entries. Systemd finds them and tries to open already-open devices:

```bash
# Add 'noauto' to both entries
sed -i 's/luks,discard$/luks,discard,noauto/' /etc/crypttab
cat /etc/crypttab   # Verify noauto is present
```

### Snapshot boot entries don't appear in GRUB

```bash
systemctl status grub-btrfsd

# Manually trigger regeneration
/etc/grub.d/41_snapshots-btrfs
grub-mkconfig -o /boot/grub/grub.cfg

# Verify snapshots exist with correct info.xml
ls /.snapshots/
cat /.snapshots/1/info.xml
btrfs subvolume list / | grep snapshots
```

### Snapper rollback fails — `.snapshots is not a btrfs subvolume`

```bash
grep snapshots /etc/fstab
mount -a
btrfs subvolume show /.snapshots
```

### Kernel/modules mismatch when booting a snapshot

This should not occur with `/boot` inside the snapshot. If it does:

```bash
# Boot into the snapshot, check versions
ls /boot/vmlinuz-*      # Kernel in this snapshot
ls /lib/modules/        # Modules should match the kernel above
```

If they differ, the snapshot was taken at a time when `/boot` had a different kernel than `/lib/modules/`. This can happen if the kernel was updated but modules were not yet installed before the snapshot. The solution is to roll back to a snapshot where both match, or rebuild the initramfs from within the snapshot.

---

## Appendix A: Kernel Update Workflow (with installkernel)

After the initial install, updating the kernel is fully automated:

```bash
cd /usr/src/linux

# Copy previous config as starting point
cp /boot/config-$(uname -r) .config
make olddefconfig    # Accept new options with defaults

# Optional: review new options
make menuconfig

# Build
make -j$(nproc)
make modules_install

# make install triggers installkernel, which:
# 1. Copies the kernel to /boot
# 2. Runs: dracut --force /boot/initramfs-<newver>.img <newver>
# 3. Runs: grub-mkconfig -o /boot/grub/grub.cfg
make install

# Snapper pre/post hooks fire automatically via /etc/portage/bashrc
# (not applicable here since this is a manual kernel install)
# Optionally take a manual snapshot before rebooting:
snapper -c root create --description "pre kernel $(uname -r) → $(ls /lib/modules/ | tail -1)"
```

---

## Appendix B: Important File Locations

| File | Location | Purpose |
|---|---|---|
| LUKS keyfile (on host) | `/root/luks-keyfile.bin` | Created on live host, copied to system |
| LUKS keyfile (in system) | `/etc/cryptsetup-keys.d/root12.key` | Used by dracut to build initramfs |
| initramfs crypttab | `/etc/crypttab.initramfs` | Embedded as /etc/crypttab in initramfs |
| Running system crypttab | `/etc/crypttab` | Has `noauto` — does not unlock at runtime |
| mdadm config | `/etc/mdadm.conf` | Embedded in initramfs by dracut |
| Dracut main config | `/etc/dracut.conf.d/00-gentoo.conf` | Modules, keyfile, compression |
| Dracut LUKS config | `/etc/dracut.conf.d/01-luks.conf` | LUKS UUIDs, kernel cmdline |
| Snapper root config | `/etc/snapper/configs/root` | Snapshot policy |
| grub-btrfs config | `/etc/default/grub-btrfs/config` | Snapshot GRUB menu settings |
| GRUB config | `/boot/grub/grub.cfg` | Generated by grub-mkconfig (inside encrypted root) |
| GRUB EFI binary | `/boot/efi/EFI/Gentoo/grubx64.efi` | On unencrypted ESP |
| Portage hooks | `/etc/portage/bashrc` | Pre/post snapshot hooks |
| LUKS header backups | Offline storage | Critical for recovery |

## Appendix C: Dracut Module Reference for This Setup

| Module | Role in this guide |
|---|---|
| `crypt` | LUKS unlock using `/etc/crypttab` in initramfs; supports keyfile entries |
| `mdraid` | Assembles mdadm RAID arrays from `/etc/mdadm.conf` |
| `btrfs` | Btrfs filesystem support including subvolumes |
| `systemd` | Systemd as PID 1 in the initramfs |
| `systemd-initrd` | Runs systemd generators in initramfs, including `systemd-cryptsetup-generator` |

`systemd-cryptsetup-generator` reads `/etc/crypttab` (embedded from `crypttab.initramfs`) and creates `systemd-cryptsetup@root12.service` and `systemd-cryptsetup@swap12.service`. Each service calls `cryptsetup open` with the keyfile, unlocking both LUKS volumes silently.

## Appendix D: Security Notes

1. **Single passphrase, single prompt:** GRUB unlocks `root12` via PBKDF2. All subsequent unlocking (both `root12` and `swap12` by dracut's systemd-cryptsetup) is done silently via the keyfile embedded in the encrypted initramfs.

2. **Keyfile security model:** The keyfile is inside the initramfs, which is inside the encrypted Btrfs root. It is not accessible without first providing the GRUB passphrase. This is fundamentally more secure than having the keyfile on an unencrypted `/boot` partition.

3. **PBKDF2 trade-off:** PBKDF2 is less GPU-brute-force resistant than Argon2id. Use a passphrase of 20+ random characters to compensate. The swap partition retains Argon2id since GRUB never opens it.

4. **RAID 0 risk:** Any single disk failure means permanent data loss on both LUKS volumes. Maintain regular off-site backups that are independent of this system.

5. **ESP attack surface (Evil Maid):** `grubx64.efi` on the ESP is unencrypted and could be replaced by an attacker with physical access. Mitigate with UEFI Secure Boot + signed GRUB binary if your threat model requires it.

6. **TRIM/discard:** `rd.luks.allow-discards` enables TRIM passthrough from LUKS to the underlying NVMe drives. This marginally leaks information about which sectors are in use but significantly improves NVMe performance over time. Remove this flag if operating in an adversarial environment.

---

*Guide prepared April 2026. Architecture verified against: Gentoo wiki (Dracut, Rootfs_encryption, Full_Disk_Encryption_From_Scratch, Full_Encrypted_Btrfs/Native_System_Root_Guide, Installkernel, GRUB, Systemd, /etc/portage/bashrc), dracut.cmdline(7) man page, Arch Linux wiki (Dm-crypt/System_configuration), openSUSE SDB:Encrypted_root_file_system, GRUB manual (gnu.org/software/grub), and grub-btrfs project (github.com/Antynea/grub-btrfs).*
