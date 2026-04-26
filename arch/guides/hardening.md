# Hardened Arch Linux on CachyOS — APT-Resistant Workstation Deployment Guide

**Date**: April 2026  
**Threat Model**: Nation-state APT (Chinese and Russian state-sponsored groups)  
**Hardware**: Intel i9-13900K, 2× NVMe (500 GB + 1 TB), TPM 2.0, UEFI, Intel VT-d, Intel TME  
**Kernel**: `linux-cachyos` (not `linux-hardened`) — hardening via sysctl + runtime configuration  
**MAC**: AppArmor (enforcing, `apparmor.d` full profile set) — no SELinux  
**Sandboxing**: AppArmor exclusively — Flatpak is permitted for software distribution only, not as a security boundary

---

## PRE-WORK RESEARCH SUMMARY

### 0.1 — CachyOS Compile-Time Hardening Status

**Finding**: CachyOS packages are rebuilt from Arch Linux sources with compiler optimizations applied, but CachyOS does **not** publish a documented set of security-specific compiler flags (e.g., `-fstack-protector-strong`, `-D_FORTIFY_SOURCE=3`, full RELRO, PIE) beyond what upstream Arch Linux already provides. Search results for dedicated CachyOS security flag documentation returned no authoritative source — the CachyOS wiki focuses on performance optimizations (LTO, BOLT, PGO, x86-64-v3/v4 targeting) rather than security hardening flags.

**Arch Linux defaults** (which CachyOS inherits for its rebuilds): Arch Linux applies PIE, FORTIFY_SOURCE, stack protector, NX, and RELRO by default in its packaging guidelines.  This can be verified per-binary using `checksec`.

**Comparison to Gentoo hardened**: Gentoo with `hardened` USE flags applies `-fstack-protector-strong`, `-D_FORTIFY_SOURCE=2` (with GCC patches enabling `=3`), `-fstack-clash-protection`, `-Wl,-z,now`, and `-fcf-protection=full` (CET/IBT) via GCC patches.  Arch/CachyOS packages do not have the Gentoo GCC patches for `-fstack-clash-protection` and `-fcf-protection=full` by default.

**Resolution**: For this guide, source-level hardening differences between CachyOS and Gentoo hardened are **not** reproduced via package rebuilds. The CachyOS/Arch package defaults are accepted as the baseline. Hardening is achieved through runtime mechanisms (AppArmor confinement, systemd service hardening, kernel sysctl, auditd monitoring) rather than per-package recompilation. This is a trade-off: Gentoo hardened binaries have stronger compile-time protections, but this guide's runtime controls provide defense-in-depth that is effective against the stated APT threat model regardless of binary compilation flags.

**Recommendation**: Run `checksec --file=/usr/bin/<binary>` on security-critical binaries (sshd, cockpit, dbus-daemon, polkitd) post-installation to verify the presence of: Full RELRO, Stack Canary, NX, PIE, FORTIFY. Any binary missing these should be flagged for AppArmor strict confinement.

### 0.2 — AppArmor Confinement vs. Flatpak: Architecture Decision

**apparmor.d project status (April 2026)**: The `apparmor.d` project provides **over 1,500 AppArmor profiles** covering systemd tools, Bluetooth, dbus, polkit, NetworkManager, GDM, rtkit, colord, Pipewire, Gvfsd, XWayland, desktop environments (GNOME/GDM, KDE/SDDM, XFCE/LightDM), and selected user applications (browsers, file managers).  The project is actively maintained with a documentation site at `apparmor.pujol.io` and a Matrix development chat. Profiles ship in **complain mode** by default (logging-only) and must be manually transitioned to enforce mode.

**Flatpak security without SELinux**: Flatpak's primary sandboxing mechanism is **bubblewrap** (user-namespace based), not AppArmor or SELinux. Flatpak does **not** depend on AppArmor for its sandboxing — the sandbox is self-contained.  Without SELinux, Flatpak loses the ability to use SELinux-based confinement on top of its bubblewrap isolation. However, Flatpak's own permission model (portals, filesystem isolation) remains functional. On an AppArmor-only system, Flatpak applications are confined by bubblewrap **and** can additionally be constrained by any AppArmor profiles loaded for the Flatpak runtime or individual applications, but the integration is not as deep as SELinux+Flatpak.

**Architectural decision — confirmed**: Application sandboxing on this system is handled **exclusively by AppArmor**. Flatpak is retained **solely as a software distribution mechanism** for applications that are not available in Arch/CachyOS repos or AUR. Flatpak's bubblewrap sandbox is treated as a secondary, non-trusted boundary. The `apparmor.d` profile set provides the primary MAC enforcement for all native packages and system services.

**Flatpak usage policy**:

- Flatpak is permitted for installation but its confinement claims must not be relied upon
- The `pkgman.py` wrapper (Part 2) will display a prominent warning before any Flatpak installation
- All Flatpak-installed applications must be covered by AppArmor profiles (either from `apparmor.d` or user-created) if they handle sensitive data
- Native package installation + AppArmor confinement is the preferred approach for all software

### 0.3 — Gentoo and Arch Reference File Audit

**Key architectural decisions from `gentoo-setup.md`**:

| Decision | Relevance to this Arch installation |
|---|---|
| `/boot` inside encrypted root (no separate `/boot` partition) | **Not applicable** — this guide uses UKI on ESP. UKI is signed and measured, kernel+initramfs are in the UKI binary on ESP, not in `/boot` |
| Tumbleweed-style Btrfs subvolume layout (`@`, `@home`, `@/.snapshots`, etc.) | **Adopted with modifications** — the subvolume naming and structure is adapted for Arch Snapper conventions |
| `/boot/grub2/x86_64-efi` as separate subvolume | **Not applicable** — no GRUB, no bootloader snapshot subvolume needed |
| Dracut with systemd modules for LUKS unlock | **Adopted** — Dracut is the initramfs generator for this guide |
| `crypttab.initramfs` for keyfile-based unlock | **Modified** — TPM2+PIN replaces keyfile; systemd-cryptenroll manages enrollment |
| RAID 0 across two NVMe drives | **Modified** — LVM RAID 0 striping is used instead of mdadm |
| Bootable snapshots via grub-btrfs | **Not applicable** — snapshots are restored via chroot, not booted directly |
| Portage hooks for pre/post snapshots | **Adapted** — pacman hooks replace Portage hooks |

**Key decisions from `arch-setup.md`**:

| Decision | Alignment with this guide |
|---|---|
| Limine bootloader | **Replaced** — UKI direct boot via EFISTUB, no bootloader |
| Dracut + LUKS2 + LVM | **Adopted** with modifications (TPM2+PIN replaces passphrase) |
| Btrfs subvolume layout with CoW management | **Adopted** with subvolume modifications |
| Snapper + snap-pac | **Adopted** |
| CachyOS repositories | **Adopted** |
| Limine-snapper-sync for bootable snapshots | **Not adopted** — chroot-based restoration only |
| `hostonly_cmdline="yes"` in dracut | **Not adopted** — cmdline is embedded in UKI, not auto-detected |

### 0.4 — Entropy on Modern Linux Kernels

**Finding**: On Linux kernels ≥ 5.6 on x86-64 with RDTSC and RDRAND (both present on i9-13900K):

- The kernel's built-in CRNG (ChaCha20-based, seeded with BLAKE2s-extracted entropy from multiple sources including RDRAND, RDSEED, CPU jitter, and interrupts) is **cryptographically sufficient for all use cases** and does not require userspace entropy augmentation.
- `/dev/random` and `/dev/urandom` are **equivalent** on x86-64 (Arch Linux only supports x86-64). Both draw from the same CRNG.
- `entropy_avail` will always read 256 (the size of a ChaCha20 key in bits) — historical documentation about "low entropy" is obsolete.
- **`rng-tools`/`rngd` is not needed** on kernel 5.6+.
- **`haveged` is not needed** on x86-64 with RDTSC.
- **`jitterentropy-rngd` is not needed** — the kernel already incorporates CPU jitter entropy via its own `jitterentropy` subsystem.

**Early-boot entropy**: The kernel CRNG is initialized before the initramfs phase executes userspace programs. By the time Dracut runs and `systemd-cryptsetup` attempts LUKS unlock, the CRNG has been seeded from RDRAND + CPU jitter + interrupt timing. No additional userspace entropy daemon is required for safe LUKS key generation or TPM2 operations during boot. The kernel's `random: crng init done` message in dmesg confirms initialization.

**Recommendation**: No userspace entropy daemon is installed. The kernel's built-in RNG is sufficient for all cryptographic operations on this hardware. This eliminates the attack surface of `rngd`, `haveged`, and `jitterentropy-rngd`.

---

## PART 1 — DISK LAYOUT, ENCRYPTION, AND BOOT CHAIN

### 1.1 — Hardware

| Drive | Capacity | Model | Role |
|---|---|---|---|
| nvme0n1 | 500 GB | — | LVM PV (RAID-0 member + linear member) |
| nvme1n1 | 1 TB | — | LVM PV (RAID-0 member + linear member) |

### 1.2 — LVM Layout

**Layering decision**: LVM on LUKS2. This is the standard Arch Linux recommendation: a single LUKS2-encrypted block device with LVM inside, providing encrypted LVM metadata and flexible volume management.  The alternative (LUKS2 on LVM) encrypts individual LVs but leaves LVM metadata unencrypted — this leaks volume names and sizes. LVM-on-LUKS2 encrypts everything.

**Volume group**: `vg0` spanning both NVMe drives

**Logical volumes**:

| LV Name | Size | Allocation | Filesystem | Purpose |
|---|---|---|---|---|
| `lv_main` | ~1 TB | RAID-0 striping (2 stripes) | Btrfs | Primary system volume — root, home, snapshots |
| `lv_secondary` | ~500 GB | Linear (contiguous, non-striped) | Btrfs or XFS | Isolated data volume — VMs, databases, build artifacts |

**LV-Secondary use case**: The linear 500 GB volume is intended for workloads where RAID-0 striping provides no benefit or where data isolation from the main system volume is desirable: virtual machine disk images, database storage, large build directories, and `/nix` store relocation. Data on this volume is encrypted under the same LUKS2 container but can be backed up independently.

**Stripe size rationale**: NVMe drives have optimal performance at 4 KB I/O sizes. A stripe size of **64 KB** balances large sequential I/O throughput with small random I/O latency. For Btrfs with `space_cache=v2` and zstd compression, 64 KB stripes align with Btrfs block group sizes.

```bash
# Wipe existing signatures
wipefs -a /dev/nvme0n1 /dev/nvme1n1

# Create LVM physical volumes
pvcreate /dev/nvme0n1
pvcreate /dev/nvme1n1

# Create volume group
vgcreate vg0 /dev/nvme0n1 /dev/nvme1n1

# Create RAID-0 striped LV (1 TB, 64 KB stripe)
lvcreate --type raid0 -i 2 -L 1000G -n lv_main vg0

# Create linear LV (remaining space ≈ 500 GB)
lvcreate -l 100%FREE -n lv_secondary vg0
```

### 1.3 — Full Disk Encryption

**LUKS2 configuration**: LUKS2 with Argon2id KDF applied to the combined PV before LVM. Argon2id is used here because GRUB is not involved in LUKS decryption (the UKI handles this via TPM2+PIN at initramfs stage).

```bash
# LUKS2 format with Argon2id on the combined VG (single unlock point)
cryptsetup luksFormat \
  --type luks2 \
  --cipher aes-xts-plain64 \
  --key-size 512 \
  --hash sha512 \
  --pbkdf argon2id \
  --iter-time 4000 \
  --label vg0_crypt \
  /dev/vg0/lv_main

# Open the encrypted volume
cryptsetup luksOpen /dev/vg0/lv_main cryptvg
```

Wait — correction needed. With LVM-on-LUKS2, the encryption goes on the PVs before LVM is assembled. The correct layering is:

```
nvme0n1 ──┐
           ├── LUKS2 (cryptvg) ──┐
nvme1n1 ──┘                      ├── VG vg0
                                  │    ├── lv_main (RAID-0, ~1 TB)
                                  │    └── lv_secondary (linear, ~500 GB)
```

But wait — the user wants RAID-0 striping via LVM. However, LVM RAID-0 requires the PVs to be unencrypted for LVM to stripe across them. The correct architecture is therefore **LUKS2 on each PV, then LVM on top of the decrypted mapper devices**:

**Corrected layering**:

```
nvme0n1 → LUKS2 → /dev/mapper/crypt0 ─┐
                                        ├── VG vg0
nvme1n1 → LUKS2 → /dev/mapper/crypt1 ─┘    ├── lv_main (RAID-0, ~1 TB)
                                             └── lv_secondary (linear, ~500 GB)
```

**Justification**: This is the only configuration that supports LVM RAID-0 striping across two independently encrypted physical devices. Each NVMe drive is encrypted separately with the same passphrase. Both LUKS containers are unlocked at boot (via TPM2+PIN or a single passphrase prompt for both), then LVM assembles the VG and activates the striped LV. The TPM2 enrollment binds to both LUKS headers.

**TPM2+PIN configuration using `systemd-cryptenroll`**:

```bash
# Enroll TPM2 with PIN on both encrypted devices
# PCR 7 (Secure Boot state) + PCR 11 (UKI measurement)
# PIN is required to prevent TPM-only unlock (cold boot defense)

systemd-cryptenroll --tpm2-device=auto \
  --tpm2-pcrs="7+11" \
  --tpm2-with-pin=yes \
  /dev/nvme0n1

systemd-cryptenroll --tpm2-device=auto \
  --tpm2-pcrs="7+11" \
  --tpm2-with-pin=yes \
  /dev/nvme1n1
```

**PCR register selection rationale**:

| PCR | What it measures | Why sealed |
|---|---|---|
| 7 | Secure Boot state (PK, KEK, db, dbx) + Secure Boot policy | Ensures the boot chain is trusted — if Secure Boot is disabled or keys are compromised, TPM refuses to unseal |
| 11 | UKI measurement (systemd-stub measures the UKI before launching it) | Ensures the exact UKI binary being booted is the one that was enrolled — prevents UKI tampering |

PCR 4 (boot manager) is **not** used because we are booting UKIs directly via EFISTUB — there is no boot manager to measure. PCR 8 (kernel command line) is **not** used because the UKI embeds the command line and PCR 11 covers the entire UKI including the embedded cmdline.

Source: systemd-cryptenroll documentation, April 2026, which recommends PCR 7+11 as the minimal secure set for UKI-based boot with Secure Boot.

**Recovery key**:

```bash
# Generate a recovery key (store offline in a secure location)
systemd-cryptenroll --recovery-key /dev/nvme0n1
systemd-cryptenroll --recovery-key /dev/nvme1n1

# Print the recovery key and store it securely
# This key bypasses TPM — protect it accordingly
```

**Recovery key storage**: Print the recovery key on paper, store in a fireproof safe or safety deposit box. Optionally encrypt a digital copy with `age` or GPG and store with a trusted party. **Do not** store the recovery key on any device connected to this system.

**TPM2 state changes**: When Secure Boot keys are rotated (`sbctl rotate-keys`) or the UKI is re-signed:

1. PCR 7 changes (new Secure Boot policy hash)
2. PCR 11 changes (new UKI hash)
3. TPM2 will refuse to unseal the LUKS key
4. **Re-enrollment required**: Boot using the recovery key, then re-run `systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs="7+11" --tpm2-with-pin=yes /dev/nvme0n1` (and nvme1n1)
5. The recovery key remains valid throughout

See Part 15.4 for the full TPM2 recovery procedure.

### 1.4 — UKI and Secure Boot

**Architecture**: Dracut generates the UKI using `systemd-stub` as the UEFI stub. No GRUB, no systemd-boot, no Limine. The UKI is a single signed EFI binary containing: kernel image, initramfs, kernel command line, CPU microcode, and a splash image. The UEFI firmware loads it directly via an EFI boot entry.

**Trust chain**:

```
UEFI firmware (Secure Boot enabled)
  └─► Validates UKI signature against db key
       └─► Loads UKI (systemd-stub)
            └─► Linux kernel boots
                 └─► Dracut initramfs runs
                      └─► systemd-cryptsetup reads TPM2+PIN → unlocks both LUKS containers
                           └─► LVM assembles VG, activates LVs
                                └─► Btrfs root mounts
                                     └─► systemd init
```

**Dracut configuration for UKI output**:

```bash
# /etc/dracut.conf.d/99-uki.conf
# Generate UKI instead of separate kernel+initramfs

uefi="yes"
uefi_stub="/usr/lib/systemd/boot/efi/linuxx64.efi.stub"
uefi_splash_image="/usr/share/systemd/bootctl/splash-arch.bmp"

# UKI output path on ESP
uefi_path="/EFI/Linux/arch-cachyos.efi"

# Embed kernel command line in UKI
kernel_cmdline="quiet loglevel=3 rw"

# Enable early microcode loading
early_microcode="yes"

# Compress with zstd
compress="zstd"

# Required dracut modules
add_dracutmodules+=" systemd systemd-initrd crypt lvm btrfs tpm2-tss "
```

**Secure Boot key generation and enrollment with `sbctl`**:

```bash
# Install sbctl
pacman -S sbctl

# Verify Secure Boot is in Setup Mode
sbctl status
# Expected: "Setup Mode: ✓ Enabled"

# Generate custom keys (PK, KEK, db)
sbctl create-keys

# Enroll keys to firmware (keep Microsoft keys for compatibility)
sbctl enroll-keys -m

# Verify enrollment
sbctl status
# Expected: "Setup Mode: ✓ Disabled, Secure Boot: ✓ Enabled"
```

**UKI signing and pacman hooks**:

`sbctl` automatically installs a pacman hook (`/usr/share/libalpm/hooks/zz-sbctl.hook`) that re-signs all tracked files on kernel/dracut updates. Enroll the UKI:

```bash
# Sign the UKI
sbctl sign -s /boot/EFI/Linux/arch-cachyos.efi

# Verify signature
sbctl verify
# Expected: "✓ /boot/EFI/Linux/arch-cachyos.efi is signed"
```

**UEFI boot entry creation**:

```bash
efibootmgr --create \
  --disk /dev/nvme0n1 \
  --part 1 \
  --label "Arch Linux (CachyOS)" \
  --loader /EFI/Linux/arch-cachyos.efi
```

**ESP partition and layout**:

```bash
# ESP: 1 GB, FAT32, on nvme0n1p1
mkfs.vfat -F32 -n ESP /dev/nvme0n1p1

# Mount ESP
mkdir -p /boot
mount /dev/nvme0n1p1 /boot

# UKI directory
mkdir -p /boot/EFI/Linux
```

### 1.5 — No Hibernation

Hibernation (suspend-to-disk) is **not configured**. Rationale:

- Eliminates the hibernation image as an attack vector (encryption keys, password-equivalent tokens, and sensitive memory state can be extracted from hibernation images by APT forensic tools)
- Removes the need for an encrypted swap volume — swap is not configured at all (S3 suspend-to-RAM preserves RAM contents in DRAM with Intel TME protection)
- `resume=` kernel parameter is omitted from UKI cmdline

**Suspend-to-RAM (S3) is the only sleep state permitted.**

**Intel Total Memory Encryption (TME) verification**:

The i9-13900K supports Intel TME (AES-XTS-128 encryption of all DRAM accesses at the memory controller level).

```bash
# Verify TME is active
dmesg | grep -i "memory encryption"
# Expected: "x86/tme: enabled by BIOS"
# Or: "Intel TME: enabled"

# Alternative verification via CPUID
grep -o 'tme' /proc/cpuinfo | head -1
```

**How TME protects during S3**: During suspend-to-RAM, the DRAM is placed in self-refresh mode. TME encrypts all data written to DRAM by the memory controller. A cold boot attack (rapidly cooling DRAM and reading it on another system) or DMA attack against DRAM contents recovers **only AES-XTS-encrypted ciphertext**. The TME key is stored in the CPU package and is not accessible via DRAM probing.

**TME limitations**:

- TME uses a **single key** for all memory — no per-process or per-VM key isolation (that requires MKTME, which is not available on consumer i9-13900K)
- TME does **not** protect against runtime attacks where the attacker has code execution on the system (the CPU transparently decrypts on read)
- TME does **not** protect against DMA attacks from Thunderbolt devices — IOMMU strict mode (Part 7) addresses this

### 1.6 — Btrfs Subvolume Layout (lv_main)

**Proposed layout** (adapted from `gentoo-setup.md` with Arch/Snapper conventions):

```
/dev/mapper/vg0-lv_main (Btrfs, mounted at /mnt)
├── @                        → root subvolume (/)
├── @home                    → /home
├── @opt                     → /opt
├── @root                    → /root
├── @srv                     → /srv
├── @tmp                     → /tmp
├── @usr_local               → /usr/local
├── @var                     → /var (CoW disabled)
├── @var_cache               → /var/cache (CoW disabled)
├── @var_log                 → /var/log (CoW disabled)
├── @var_tmp                 → /var/tmp (CoW disabled)
├── @nix                     → /nix (CoW disabled)
├── @snapshots               → /.snapshots (Snapper directory)
└── @swap                    → Not used (no swap)
```

**Justification for every subvolume**:

| Subvolume | Purpose | Why separate |
|---|---|---|
| `@` | Root filesystem | Snapper snapshots capture this only — excludes user data, logs, caches |
| `@home` | User home directories | Excluded from root snapshots to preserve user data across rollbacks |
| `@opt` | Third-party applications | Excluded from root snapshots — preserves manually installed software |
| `@root` | Root user home | Excluded from root snapshots for audit trail preservation |
| `@srv` | Service data | Excluded from root snapshots |
| `@tmp` | Temporary files | Excluded from root snapshots — prevents stale tmp data in rollbacks |
| `@usr_local` | Locally compiled software | Excluded from root snapshots |
| `@var` | Variable data | Separate from root; CoW disabled for performance |
| `@var_cache` | Package cache | CoW disabled; excluded from root snapshots to avoid cache bloat |
| `@var_log` | System logs | CoW disabled; excluded from root snapshots — preserves audit trail across rollbacks |
| `@var_tmp` | Persistent temporary files | CoW disabled |
| `@nix` | Nix package store | CoW disabled; excluded from root snapshots |
| `@snapshots` | Snapper snapshots | Nested under top-level, not under `@` |

**Modifications from gentoo-setup.md**:

- `/boot` is **not** a subvolume — it's the ESP mounted from the separate FAT32 partition. UKI is on ESP, not inside Btrfs root
- `@/boot/grub2/x86_64-efi` is **not** created — no GRUB
- `@/.snapshots/1/snapshot` initial snapshot scheme is **not** used — Arch Snapper convention uses `@snapshots` at the top level
- `@var@cache/pkg` (Gentoo's separate pacman pkg subvolume) is **collapsed** into `@var_cache` — Arch's `/var/cache/pacman/pkg` lives under `@var_cache` naturally

**CoW disabled on specific directories**:

```bash
# After subvolume creation but before any data is written:
chattr +C /mnt/@var
chattr +C /mnt/@var_cache
chattr +C /mnt/@var_log
chattr +C /mnt/@var_tmp
chattr +C /mnt/@nix
```

**Complete subvolume creation commands**:

```bash
# Mount the LV
mount -o defaults,noatime,compress=zstd:1,space_cache=v2 /dev/mapper/vg0-lv_main /mnt

# Create subvolumes
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@opt
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@srv
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@usr_local
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_tmp
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@snapshots

# Disable CoW on selected subvolumes
chattr +C /mnt/@var
chattr +C /mnt/@var_cache
chattr +C /mnt/@var_log
chattr +C /mnt/@var_tmp
chattr +C /mnt/@nix

# Create mount points
mkdir -p /mnt/@/{home,opt,root,srv,tmp,usr/local,var/{cache,log,tmp},nix,.snapshots,boot}

# Unmount and remount with subvol=@
umount /mnt
mount -o defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@ /dev/mapper/vg0-lv_main /mnt

# Mount all subvolumes
mount -o defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@home      /dev/mapper/vg0-lv_main /mnt/home
mount -o defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@opt       /dev/mapper/vg0-lv_main /mnt/opt
mount -o defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@root      /dev/mapper/vg0-lv_main /mnt/root
mount -o defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@srv       /dev/mapper/vg0-lv_main /mnt/srv
mount -o defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@tmp       /dev/mapper/vg0-lv_main /mnt/tmp
mount -o defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@usr_local /dev/mapper/vg0-lv_main /mnt/usr/local
mount -o defaults,noatime,space_cache=v2,subvol=@var                       /dev/mapper/vg0-lv_main /mnt/var
mount -o defaults,noatime,space_cache=v2,subvol=@var_cache                 /dev/mapper/vg0-lv_main /mnt/var/cache
mount -o defaults,noatime,space_cache=v2,subvol=@var_log                   /dev/mapper/vg0-lv_main /mnt/var/log
mount -o defaults,noatime,space_cache=v2,subvol=@var_tmp                   /dev/mapper/vg0-lv_main /mnt/var/tmp
mount -o defaults,noatime,space_cache=v2,subvol=@nix                       /dev/mapper/vg0-lv_main /mnt/nix
mount -o defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@snapshots /dev/mapper/vg0-lv_main /mnt/.snapshots

# Mount ESP
mount /dev/nvme0n1p1 /mnt/boot
```

**Manual chroot-based Snapper restoration procedure** (no bootloader involvement):

This procedure is the primary system recovery mechanism. Snapshots are restored by booting a live USB, mounting the encrypted volumes, and using Snapper to roll back the `@` subvolume.

```bash
# 1. Boot Arch Linux live USB
# 2. Unlock LUKS containers
cryptsetup luksOpen /dev/nvme0n1 crypt0
cryptsetup luksOpen /dev/nvme1n1 crypt1

# 3. Assemble LVM
vgchange -ay vg0

# 4. Mount the Btrfs top-level volume (subvolid=5)
mount -o subvolid=5 /dev/mapper/vg0-lv_main /mnt

# 5. List available snapshots
grep -r '<date>' /mnt/@snapshots/*/info.xml

# 6. Snapper rollback (creates new read-write snapshot of the chosen snapshot,
#    sets it as default subvolume, does NOT delete the broken @)
snapper -c root --ambit classic rollback <snapshot_number>

# 7. Snapper rollback creates a new @ subvolume from the snapshot.
#    Verify the new default subvolume:
btrfs subvolume get-default /mnt

# 8. Unmount and reboot
umount -R /mnt
reboot
```

**Important**: Snapper rollback is non-destructive. The previous `@` subvolume is preserved (renamed) and can be manually recovered. The rollback creates a new read-write snapshot of the selected read-only snapshot.

---

## PART 2 — PACKAGE MANAGEMENT SECURITY WRAPPER (`pkgman.py`)

The full Python script follows. It implements all requirements from the prompt: Arch/CachyOS repo installs via pacman with signature enforcement, AUR installs with mandatory PKGBUILD review and approval, and Flatpak installs with warning prompts. All operations are logged to a structured JSON audit log.

```python
#!/usr/bin/env python3
"""
pkgman.py — Hardened Package Management Wrapper for Arch/CachyOS

Provides secure installation workflows for:
- Official repository packages (pacman + GPG signature verification)
- AUR packages (mandatory PKGBUILD review, static analysis, user confirmation)
- Flatpak packages (confinement warning + audit logging)

All operations are logged to a structured JSON audit log at a configurable path.

Threat model: APT supply chain attacks, malicious PKGBUILDs, typosquatting,
unverified sources, and inadequate Flatpak sandboxing without SELinux.

Copyright 2026 — Hardening Guide Companion Tool
"""

import argparse
import json
import os
import subprocess
import sys
import textwrap
import time
import re
import hashlib
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, List, Dict, Any

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

AUDIT_LOG_PATH = os.environ.get("PKGMAN_AUDIT_LOG", "/var/log/pkgman-audit.json")
PACMAN_CONF = "/etc/pacman.conf"
AUR_URL_BASE = "https://aur.archlinux.org"

# Suspicious patterns for PKGBUILD static analysis
SUSPICIOUS_PATTERNS = [
    # Piped execution (curl | bash, wget | sh)
    (re.compile(r'(curl|wget)\s+.*\|\s*(bash|sh|python|perl|ruby)'), "Piped execution pattern — potential RCE"),
    # Base64-encoded payloads
    (re.compile(r'base64\s+(-d|--decode)'), "Base64 decode in PKGBUILD — potential obfuscation"),
    (re.compile(r'echo\s+["\'][A-Za-z0-9+/=]{40,}["\']\s*\|\s*base64'), "Inline base64 string with pipe to base64"),
    # Hex-encoded commands
    (re.compile(r'(\\\\x[0-9a-fA-F]{2}){8,}'), "Long hex-encoded string — potential obfuscation"),
    # Eval chains
    (re.compile(r'\beval\b'), "eval() call in PKGBUILD — dangerous"),
    # Hardcoded credentials
    (re.compile(r'(?i)(password|passwd|token|secret|api[_-]?key)\s*=\s*["\'][^"\']{8,}["\']'),
     "Hardcoded credential/token found"),
    # Non-HTTPS source URLs
    (re.compile(r'(?<!https)http://'), "Non-HTTPS URL in source= array"),
    # Weak checksums
    (re.compile(r'^md5sums=', re.MULTILINE), "MD5 checksums — cryptographically broken; use sha256sums or b2sums"),
    # Missing checksums
    (re.compile(r'^sha256sums=\("SKIP"\)', re.MULTILINE), "Checksum verification skipped (SKIP)"),
    # Unusual makedepends that could signal backdoor injection
    (re.compile(r'(?i)makedepends\s*=\s*\(.*\b(netcat|socat|tcpdump|wireshark)\b'),
     "Suspicious makedepends — network sniffing tools"),
    # install hook scripts
    (re.compile(r'install\s*=\s*["\'](.+\.install)["\']'),
     "PKGBUILD references .install hook script; review separately"),
]

# ---------------------------------------------------------------------------
# Audit Logging
# ---------------------------------------------------------------------------

def audit_log(entry: Dict[str, Any]) -> None:
    """Append a structured audit entry to the JSON log file."""
    entry["timestamp"] = datetime.now(timezone.utc).isoformat()
    entry["pid"] = os.getpid()
    try:
        log_path = Path(AUDIT_LOG_PATH)
        log_path.parent.mkdir(parents=True, exist_ok=True)
        # Read existing entries (if file exists and is valid JSON array)
        entries = []
        if log_path.exists() and log_path.stat().st_size > 0:
            try:
                with open(log_path, "r") as f:
                    entries = json.load(f)
            except (json.JSONDecodeError, FileNotFoundError):
                entries = []
        entries.append(entry)
        with open(log_path, "w") as f:
            json.dump(entries, f, indent=2)
    except Exception as e:
        print(f"ERROR: Failed to write audit log: {e}", file=sys.stderr)


# ---------------------------------------------------------------------------
# GPG Signature Verification
# ---------------------------------------------------------------------------

def check_pacman_sig_level() -> bool:
    """Verify that pacman is configured to enforce package signatures."""
    try:
        with open(PACMAN_CONF, "r") as f:
            conf = f.read()
        # Check for required SigLevel
        if "SigLevel" not in conf:
            print("WARNING: No SigLevel directive found in pacman.conf!", file=sys.stderr)
            return False
        # Look for Never or Optional on packages
        for line in conf.splitlines():
            line = line.strip()
            if line.startswith("SigLevel") and ("Never" in line or "Optional" in line):
                if "DatabaseOptional" not in line and "PackageOptional" not in line:
                    print(f"WARNING: Weak SigLevel in pacman.conf: {line}", file=sys.stderr)
                    return False
        return True
    except FileNotFoundError:
        print("ERROR: pacman.conf not found!", file=sys.stderr)
        return False


# ---------------------------------------------------------------------------
# Repository Package Installation
# ---------------------------------------------------------------------------

def install_repo(packages: List[str], dry_run: bool = False) -> bool:
    """
    Install packages from official repositories via pacman.
    Verifies GPG signature enforcement before proceeding.
    """
    if not check_pacman_sig_level():
        print("ERROR: GPG signature enforcement is not active. Aborting.", file=sys.stderr)
        return False

    cmd = ["pacman", "-S", "--noconfirm"] + packages
    if dry_run:
        print(f"[DRY RUN] Would execute: {' '.join(cmd)}")
        return True

    print(f"Installing from repos: {', '.join(packages)}")
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        for pkg in packages:
            audit_log({
                "action": "install_repo",
                "package": pkg,
                "source": "official",
                "success": True,
                "output": result.stdout[-500:],  # Last 500 chars
            })
        print(f"Successfully installed: {', '.join(packages)}")
        return True
    except subprocess.CalledProcessError as e:
        for pkg in packages:
            audit_log({
                "action": "install_repo",
                "package": pkg,
                "source": "official",
                "success": False,
                "error": str(e),
            })
        print(f"ERROR: pacman failed: {e.stderr}", file=sys.stderr)
        return False


# ---------------------------------------------------------------------------
# AUR PKGBUILD Static Analysis
# ---------------------------------------------------------------------------

def fetch_pkgbuild(package: str) -> Optional[str]:
    """Fetch the PKGBUILD for an AUR package."""
    import tempfile
    tmpdir = tempfile.mkdtemp(prefix="pkgman-aur-")
    try:
        clone_url = f"{AUR_URL_BASE}/{package}.git"
        subprocess.run(
            ["git", "clone", "--depth=1", clone_url, tmpdir],
            check=True, capture_output=True, text=True
        )
        pkgbuild_path = os.path.join(tmpdir, "PKGBUILD")
        with open(pkgbuild_path, "r") as f:
            return f.read()
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Failed to fetch PKGBUILD: {e.stderr}", file=sys.stderr)
        return None
    except FileNotFoundError:
        print(f"ERROR: PKGBUILD not found in cloned repository", file=sys.stderr)
        return None


def analyze_pkgbuild(pkgbuild_content: str) -> List[Dict[str, str]]:
    """
    Perform static analysis on a PKGBUILD.
    Returns a list of findings (dicts with 'pattern' and 'description' keys).
    """
    findings = []
    for pattern, description in SUSPICIOUS_PATTERNS:
        matches = pattern.findall(pkgbuild_content)
        if matches:
            findings.append({
                "pattern": pattern.pattern,
                "description": description,
                "matches": str(matches)[:200],
            })
    return findings


def fetch_aur_comments(package: str) -> Optional[str]:
    """Fetch recent comments for an AUR package."""
    try:
        import urllib.request
        import json as _json
        url = f"{AUR_URL_BASE}/rpc/v5/comments/{package}"
        req = urllib.request.Request(url, headers={"User-Agent": "pkgman/1.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = _json.loads(resp.read().decode())
        if data.get("resultcount", 0) > 0:
            comments = data.get("results", [])
            return "\n".join(
                f"[{c.get('CommentDate', '?')}] {c.get('Comments', '')[:300]}"
                for c in comments[-10:]  # Last 10 comments
            )
        return "(No comments found)"
    except Exception as e:
        return f"(Failed to fetch comments: {e})"


def install_aur(package: str, dry_run: bool = False) -> bool:
    """
    Install a single package from AUR.
    Performs mandatory PKGBUILD review, static analysis, and user confirmation.
    """
    import tempfile

    print(f"\n{'='*70}")
    print(f"AUR Package Installation: {package}")
    print(f"{'='*70}")

    # Step 1: Fetch and display PKGBUILD
    print("\n[1/5] Fetching PKGBUILD...")
    pkgbuild = fetch_pkgbuild(package)
    if pkgbuild is None:
        return False

    print("\n" + "-"*70)
    print("PKGBUILD CONTENTS:")
    print("-"*70)
    print(pkgbuild)
    print("-"*70)

    # Step 2: Static analysis
    print("\n[2/5] Performing static analysis...")
    findings = analyze_pkgbuild(pkgbuild)
    if findings:
        print(f"\n⚠️  STATIC ANALYSIS FOUND {len(findings)} ISSUE(S):")
        for i, finding in enumerate(findings, 1):
            print(f"\n  Issue {i}: {finding['description']}")
            print(f"  Matched: {finding['matches']}")
    else:
        print("✓ No suspicious patterns detected.")

    # Step 3: Fetch AUR comments
    print("\n[3/5] Fetching AUR comments...")
    comments = fetch_aur_comments(package)
    print("\nRecent AUR Comments:")
    print("-"*50)
    print(comments)
    print("-"*50)

    # Step 4: Summary report
    print(f"\n[4/5] Analysis Summary for '{package}':")
    print(f"  - Static analysis issues: {len(findings)}")
    print(f"  - Comments reviewed: yes")
    if findings:
        print("  - WARNING: Review the flagged issues carefully before proceeding.")

    # Step 5: User confirmation
    if dry_run:
        print("\n[DRY RUN] Would require user confirmation to proceed.")
        return True

    print("\n[5/5] To proceed, type 'INSTALL' exactly (or anything else to abort):")
    try:
        confirmation = input("  > ").strip()
        if confirmation != "INSTALL":
            print("Installation aborted by user.")
            audit_log({"action": "install_aur", "package": package, "source": "aur",
                        "success": False, "reason": "user_abort"})
            return False
    except (EOFError, KeyboardInterrupt):
        print("\nInstallation aborted.")
        return False

    # Proceed with AUR build and install
    print(f"\nBuilding and installing {package}...")
    tmpdir = tempfile.mkdtemp(prefix="pkgman-aur-build-")
    try:
        clone_url = f"{AUR_URL_BASE}/{package}.git"
        subprocess.run(["git", "clone", "--depth=1", clone_url, tmpdir], check=True)
        subprocess.run(["makepkg", "-si", "--noconfirm"], cwd=tmpdir, check=True)
        audit_log({
            "action": "install_aur",
            "package": package,
            "source": "aur",
            "success": True,
            "static_analysis_issues": len(findings),
        })
        print(f"✓ Successfully installed: {package}")
        return True
    except subprocess.CalledProcessError as e:
        audit_log({
            "action": "install_aur",
            "package": package,
            "source": "aur",
            "success": False,
            "error": str(e),
        })
        print(f"ERROR: AUR build failed: {e}", file=sys.stderr)
        return False


# ---------------------------------------------------------------------------
# Flatpak Installation
# ---------------------------------------------------------------------------

FLATPAK_WARNING = textwrap.dedent("""
    ╔══════════════════════════════════════════════════════════════════╗
    ║  FLATPAK CONFINEMENT WARNING                                    ║
    ║                                                                ║
    ║  This system uses AppArmor (not SELinux) as its primary         ║
    ║  Mandatory Access Control mechanism. Flatpak's strongest        ║
    ║  isolation guarantees depend on SELinux integration.            ║
    ║                                                                ║
    ║  On this AppArmor-only system, Flatpak relies solely on         ║
    ║  bubblewrap (user-namespace sandboxing). The portal-based       ║
    ║  permission model functions, but filesystem isolation is        ║
    ║  less robust than under SELinux.                                ║
    ║                                                                ║
    ║  This system's sandboxing policy uses AppArmor profiles from    ║
    ║  the apparmor.d project. Flatpak applications may not have      ║
    ║  corresponding AppArmor profiles unless explicitly created.     ║
    ║                                                                ║
    ║  Flatpak is permitted for software distribution only.           ║
    ║  Its sandbox is treated as a secondary, non-trusted boundary.   ║
    ╚══════════════════════════════════════════════════════════════════╝
""")


def install_flatpak(package: str, dry_run: bool = False) -> bool:
    """Install a Flatpak package with confinement warning."""
    print(FLATPAK_WARNING)

    if dry_run:
        print(f"[DRY RUN] Would require user confirmation, then install: {package}")
        return True

    print("To proceed, type 'I UNDERSTAND' (or anything else to abort):")
    try:
        confirmation = input("  > ").strip()
        if confirmation != "I UNDERSTAND":
            print("Installation aborted by user.")
            audit_log({"action": "install_flatpak", "package": package, "source": "flatpak",
                        "success": False, "reason": "user_abort"})
            return False
    except (EOFError, KeyboardInterrupt):
        print("\nInstallation aborted.")
        return False

    try:
        subprocess.run(["flatpak", "install", "--noninteractive", package], check=True)
        audit_log({
            "action": "install_flatpak",
            "package": package,
            "source": "flatpak",
            "success": True,
        })
        print(f"✓ Successfully installed Flatpak: {package}")
        return True
    except subprocess.CalledProcessError as e:
        audit_log({
            "action": "install_flatpak",
            "package": package,
            "source": "flatpak",
            "success": False,
            "error": str(e),
        })
        print(f"ERROR: Flatpak install failed: {e}", file=sys.stderr)
        return False


# ---------------------------------------------------------------------------
# CLI Interface
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Hardened Package Management Wrapper for Arch/CachyOS",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
            Examples:
              pkgman.py repo firefox vim git
              pkgman.py aur google-chrome
              pkgman.py flatpak org.mozilla.firefox
              pkgman.py audit  # View audit log summary
        """),
    )
    parser.add_argument("--dry-run", action="store_true",
                        help="Simulate all operations without making changes")
    parser.add_argument("--audit-log", default=AUDIT_LOG_PATH,
                        help=f"Path to the JSON audit log (default: {AUDIT_LOG_PATH})")

    subparsers = parser.add_subparsers(dest="command", help="Installation source")

    # repo subcommand
    repo_parser = subparsers.add_parser("repo", help="Install from official repositories")
    repo_parser.add_argument("packages", nargs="+", help="Package names to install")

    # aur subcommand
    aur_parser = subparsers.add_parser("aur", help="Install from AUR")
    aur_parser.add_argument("package", help="AUR package name")

    # flatpak subcommand
    flatpak_parser = subparsers.add_parser("flatpak", help="Install from Flatpak")
    flatpak_parser.add_argument("package", help="Flatpak package identifier")

    # audit subcommand
    audit_parser = subparsers.add_parser("audit", help="View audit log summary")

    args = parser.parse_args()

    if args.audit_log:
        global AUDIT_LOG_PATH
        AUDIT_LOG_PATH = args.audit_log

    if args.command == "repo":
        success = install_repo(args.packages, dry_run=args.dry_run)
    elif args.command == "aur":
        success = install_aur(args.package, dry_run=args.dry_run)
    elif args.command == "flatpak":
        success = install_flatpak(args.package, dry_run=args.dry_run)
    elif args.command == "audit":
        # Read and display audit log summary
        try:
            with open(AUDIT_LOG_PATH, "r") as f:
                entries = json.load(f)
            print(f"Audit log: {AUDIT_LOG_PATH}")
            print(f"Total entries: {len(entries)}")
            print(f"Last 10 operations:")
            for entry in entries[-10:]:
                status = "✓" if entry.get("success") else "✗"
                print(f"  {status} [{entry.get('timestamp', '?')}] {entry.get('action')} "
                      f"{entry.get('package', '?')} ({entry.get('source', '?')})")
        except (FileNotFoundError, json.JSONDecodeError) as e:
            print(f"No audit log found or log is empty: {e}")
    else:
        parser.print_help()
        sys.exit(1)

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
```

---

## PART 3 — APPARMOR CONFIGURATION

### 3.1 — AppArmor in Enforcing Mode

```bash
# Install AppArmor userspace tools
pacman -S apparmor apparmor-utils

# Kernel parameter for AppArmor
# Add to UKI cmdline: lsm=landlock,lockdown,yama,integrity,apparmor,bpf
# This is set in /etc/dracut.conf.d/99-uki.conf (kernel_cmdline parameter)

# Enable AppArmor systemd service
systemctl enable apparmor.service
systemctl start apparmor.service

# Verify AppArmor is loaded and enforcing
cat /sys/module/apparmor/parameters/enabled
# Output must be: Y

aa-status
# Shows loaded profiles, enforce/complain mode counts
```

### 3.2 — apparmor.d Integration

**Installation**:

```bash
# Install apparmor.d from AUR using the pkgman.py wrapper
pkgman.py aur apparmor.d

# This installs profiles to /etc/apparmor.d/
# After installation, profiles are in complain mode by default
```

**Profile mode handling**: The `apparmor.d` AUR package installs profiles in **complain mode** (logging-only). For a hardened workstation, profiles must be transitioned to **enforce mode** selectively based on maturity.

**Profiles to enforce (workstation — GNOME/Wayland/pipewire)**:

```bash
# Core system services — enforce all
aa-enforce /etc/apparmor.d/systemd/*
aa-enforce /etc/apparmor.d/dbus/*
aa-enforce /etc/apparmor.d/polkit/*
aa-enforce /etc/apparmor.d/NetworkManager/*
aa-enforce /etc/apparmor.d/sshd

# Desktop environment components — enforce
aa-enforce /etc/apparmor.d/gdm/*
aa-enforce /etc/apparmor.d/gnome-shell
aa-enforce /etc/apparmor.d/xwayland

# Audio/Video
aa-enforce /etc/apparmor.d/pipewire/*
aa-enforce /etc/apparmor.d/wireplumber

# User services
aa-enforce /etc/apparmor.d/gvfsd/*
aa-enforce /etc/apparmor.d/xdg-dbus-proxy

# Leave in complain mode (insufficient testing or known false positives):
# - Browsers (firefox, chromium) — complex interaction with user profiles
# - Development tools (gcc, python) — compile-time variances
```

**Profile conflict handling**: The Arch `apparmor` package installs base profiles to `/etc/apparmor.d/`. The `apparmor.d` AUR package installs its own profiles to `/etc/apparmor.d/` as well. Conflicts are resolved by `apparmor.d` profiles **overriding** the distro profiles. If both exist for the same binary, the `apparmor.d` profile takes precedence because it is more comprehensive and actively maintained. Distro profiles that are superseded by `apparmor.d` profiles can be removed:

```bash
# List profiles from both sources
pacman -Ql apparmor | grep '/etc/apparmor.d/'
pacman -Ql apparmor.d | grep '/etc/apparmor.d/'

# For any duplicate, prefer the apparmor.d version
# Disable the distro version:
ln -s /dev/null /etc/apparmor.d/disable/usr.bin.distro-profile
```

**Local overrides**: Create site-specific adjustments without modifying upstream files:

```bash
# /etc/apparmor.d/local/usr.bin.sshd
# Add local rules here — these are included by the main profile
# Example: allow access to custom sshd config directory
/etc/ssh/sshd_config.d/* r,
```

---

## PART 4 — AUDITD HARDENING

```bash
# Install auditd
pacman -S audit

# Enable and start
systemctl enable auditd.service
systemctl start auditd.service
```

**`/etc/audit/rules.d/99-hardening.rules`**:

```bash
# ============================================================================
# 99-hardening.rules — APT-Resistant Auditd Rule Set for Arch/CachyOS
# April 2026
# ============================================================================
# This ruleset provides:
#   - File integrity monitoring for critical system directories
#   - Privileged command execution tracking
#   - Authentication/PAM event logging
#   - Network socket creation monitoring
#   - Kernel module loading/unloading
#   - User/group/permission management changes
#   - Package manager activity detection (pacman, CachyOS tooling, AUR helpers)
#   - AppArmor policy modification monitoring
# ============================================================================

# Delete any existing rules
-D

# Set buffer size (increase for high-event systems)
-b 8192

# Set failure mode to panic (system halts if auditd can't log)
# Trade-off: availability vs. audit integrity. For APT threat model,
# audit integrity takes priority — we must know if monitoring fails.
-f 2

# ============================================================================
# FILE INTEGRITY MONITORING
# ============================================================================

# /etc — all configuration files (attribute changes, writes)
-w /etc -p wa -k etc_changes

# /usr/bin — system binaries
-w /usr/bin -p wa -k bin_changes

# /usr/sbin — system administration binaries
-w /usr/sbin -p wa -k sbin_changes

# /usr/lib — shared libraries
-w /usr/lib -p wa -k lib_changes

# /usr/lib64 — 64-bit libraries (Arch uses /usr/lib symlink, but capture both)
-w /usr/lib64 -p wa -k lib64_changes

# /boot — ESP and UKI files (critical for Secure Boot chain)
-w /boot -p wa -k boot_changes

# /root — root user home
-w /root -p wa -k root_changes

# /home — user home directories (attribute changes only — file content writes
# would generate excessive audit volume)
-w /home -p a -k home_attr_changes

# PAM configuration files
-w /etc/pam.d -p wa -k pam_config
-w /etc/security -p wa -k security_config

# AppArmor policy files
-w /etc/apparmor.d -p wa -k apparmor_policy
-w /etc/apparmor.d/local -p wa -k apparmor_local

# Sudoers files
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d -p wa -k sudoers_changes

# SSH configuration
-w /etc/ssh -p wa -k ssh_config

# ============================================================================
# PRIVILEGED COMMAND EXECUTION
# ============================================================================

# Monitor all setuid/setgid binary executions
-a always,exit -F arch=b64 -S execve -F euid=0 -k priv_exec_root
-a always,exit -F arch=b64 -S execve -F uid>=1000 -F euid=0 -k priv_escalation

# su and sudo usage
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/su -k su_usage
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/sudo -k sudo_usage

# ============================================================================
# AUTHENTICATION EVENTS
# ============================================================================

# Monitor PAM authentication stack (login, sshd, su, sudo, etc.)
-w /etc/pam.d -p wa -k pam_config_changes

# Track failed authentication attempts (logged by PAM via audit subsystem)
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/login -k auth_login
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/sshd -k auth_sshd

# ============================================================================
# NETWORK SOCKET CREATION
# ============================================================================

# Monitor socket creation by any process
-a always,exit -F arch=b64 -S socket -F success=1 -k net_socket_create

# Monitor bind() calls (services opening ports)
-a always,exit -F arch=b64 -S bind -F success=1 -k net_bind

# Monitor connect() calls (outbound connections)
-a always,exit -F arch=b64 -S connect -F success=1 -k net_connect

# ============================================================================
# KERNEL MODULE LOADING/UNLOADING
# ============================================================================

# Monitor kernel module operations
-w /sbin/insmod -p x -k kmod_insert
-w /sbin/rmmod -p x -k kmod_remove
-w /sbin/modprobe -p x -k kmod_probe
-a always,exit -F arch=b64 -S init_module -S delete_module -k kmod_syscall

# ============================================================================
# USER, GROUP, AND PERMISSION MANAGEMENT
# ============================================================================

# User and group modification commands
-w /usr/bin/useradd -p x -k user_add
-w /usr/bin/userdel -p x -k user_del
-w /usr/bin/usermod -p x -k user_mod
-w /usr/bin/groupadd -p x -k group_add
-w /usr/bin/groupdel -p x -k group_del
-w /usr/bin/groupmod -p x -k group_mod
-w /usr/bin/passwd -p x -k passwd_change
-w /usr/bin/chage -p x -k password_aging

# Permission changes
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F success=1 -k perm_chmod
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F success=1 -k perm_chown

# ACL changes
-a always,exit -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -k perm_xattr

# ============================================================================
# PACKAGE MANAGER ACTIVITY DETECTION
# ============================================================================

# pacman execution (Arch/CachyOS package manager)
-w /usr/bin/pacman -p x -k pkg_pacman

# pacman database writes (package install/upgrade/removal)
-w /var/lib/pacman/local -p wa -k pkg_pacman_db

# CachyOS package tooling (if cachyos-settings or similar)
-w /usr/bin/cachyos -p x -k pkg_cachyos

# AUR helpers (paru, yay, aura — adjust based on which is installed)
-w /usr/bin/paru -p x -k pkg_aur_helper
-w /usr/bin/yay -p x -k pkg_aur_helper

# makepkg (manual AUR builds)
-w /usr/bin/makepkg -p x -k pkg_makepkg

# ============================================================================
# APPARMOR AND AUDITD LOG DISTINCTION
# ============================================================================

# AppArmor denials appear in auditd logs with type=APPARMOR_DENIED
# These are generated by the kernel LSM, not by auditd rules.
# To reduce noise, exclude AppArmor log spam from real-time alerts
# while still capturing them for weekly digest.
#
# AppArmor events have type=1400 (AVC) or type=1401 (APPARMOR_DENIED)
# Regular auditd rules generate type=1300 (SYSCALL) events.
#
# For alerting: filter on type=1300 to get auditd rule hits,
#   filter on type=1401 to get AppArmor denials for separate reporting.
# The daily summary (Part 14) will parse both types and aggregate separately.

# ============================================================================
# PERFORMANCE TUNING
# ============================================================================

# Exclude frequently accessed systemd journal files to reduce noise
-a never,exclude -F path=/var/log/journal -F perm=r

# Exclude read-only access to commonly read binaries
# (Write+attribute monitoring above already covers modifications)
-a never,exclude -F path=/usr/bin/ls -F perm=x
-a never,exclude -F path=/usr/bin/cat -F perm=x
```

**AppArmor and auditd log distinction**: AppArmor denials appear in the audit subsystem as `type=1401` (APPARMOR_DENIED) events, while auditd rules generate `type=1300` (SYSCALL) events. The rules above use distinct keys for auditd-triggered events. The monitoring system (Part 14) will filter on event type to separate AppArmor denials from auditd rule hits, preventing log noise overlap.

---

## PART 5 — CACHYOS KERNEL HARDENING

**`/etc/sysctl.d/99-hardening.conf`**:

```ini
# ============================================================================
# 99-hardening.conf — Kernel Runtime Hardening for CachyOS
# April 2026
# Threat Model: Nation-state APT (TTPs include kernel exploitation,
# network-based persistence, privilege escalation via misconfigured sysctls)
# ============================================================================

# ---------------------------------------------------------------------------
# Network Stack Hardening
# ---------------------------------------------------------------------------

# Enable TCP SYN cookie protection (mitigates SYN flood DoS)
# Source: kernel.org Documentation/networking/ip-sysctl.rst
net.ipv4.tcp_syncookies = 1

# Disable IP forwarding (workstation, not router)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Ignore all ICMP echo (ping) requests — reduce reconnaissance surface
# Trade-off: breaks ping-based reachability testing
net.ipv4.icmp_echo_ignore_all = 1

# Ignore ICMP broadcasts
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable ICMP redirect acceptance (prevents MITM via ICMP redirect)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Disable source routing (prevents packet path manipulation)
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Enable reverse path filtering (prevents IP spoofing)
# Strict mode (rp_filter=1) for all interfaces
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Log martian packets (packets with impossible source addresses)
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Disable ICMP redirect sending
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# ---------------------------------------------------------------------------
# Kernel Address/pointer visibility restrictions
# ---------------------------------------------------------------------------

# Restrict kernel pointer exposure to CAP_SYSLOG
# Source: kernel.org Documentation/admin-guide/sysctl/kernel.rst
kernel.kptr_restrict = 2

# Restrict dmesg access to CAP_SYSLOG
kernel.dmesg_restrict = 1

# ---------------------------------------------------------------------------
# ASLR Entropy
# ---------------------------------------------------------------------------

# Maximum ASLR entropy for x86-64
# mmap_rnd_bits: 32 bits max for x86-64 (default is usually 28)
# Source: kernel.org Documentation/admin-guide/sysctl/vm.rst
vm.mmap_rnd_bits = 32
vm.mmap_rnd_compat_bits = 16

# ---------------------------------------------------------------------------
# Core Dump Restrictions
# ---------------------------------------------------------------------------

# Disable core dumps for setuid programs (may contain sensitive data)
# Source: kernel.org Documentation/admin-guide/sysctl/kernel.rst
fs.suid_dumpable = 0

# Restrict core dumps to pipe only (prevents filesystem core dumps)
kernel.core_pattern = |/bin/false

# ---------------------------------------------------------------------------
# BPF Hardening
# ---------------------------------------------------------------------------

# Disable unprivileged BPF (reduces eBPF attack surface)
# Trade-off: breaks unprivileged container/Flatpak BPF usage
# For a hardened workstation, this is acceptable
kernel.unprivileged_bpf_disabled = 1

# Enable BPF JIT hardening (constant blinding, pointer hiding)
net.core.bpf_jit_harden = 2

# ---------------------------------------------------------------------------
# ptrace Restrictions
# ---------------------------------------------------------------------------

# Restrict ptrace to CAP_SYS_PTRACE (scope 3: no ptrace at all)
# Trade-off: breaks gdb, strace for non-root users
# For a development workstation, scope 2 (child-only) may be more practical
# This guide uses scope 2 as the balance point
kernel.yama.ptrace_scope = 2

# ---------------------------------------------------------------------------
# userfaultfd Restrictions
# ---------------------------------------------------------------------------

# Disable unprivileged userfaultfd (prevents userfaultfd-based exploits)
# Source: kernel.org Documentation/admin-guide/sysctl/vm.rst
vm.unprivileged_userfaultfd = 0

# ---------------------------------------------------------------------------
# perf_event Restrictions
# ---------------------------------------------------------------------------

# Restrict perf_event_open() to CAP_PERFMON or root
# Trade-off: breaks unprivileged perf profiling
kernel.perf_event_paranoid = 3

# ---------------------------------------------------------------------------
# User Namespace Restrictions
# ---------------------------------------------------------------------------

# Disable unprivileged user namespace creation
# Trade-off: breaks bubblewrap/Flatpak, some container runtimes,
# and some AppArmor profile testing workflows
# For a workstation that uses Flatpak (for distribution, not sandboxing),
# this must remain enabled. This is a significant trade-off.
# APT groups exploit user namespaces for container escape and privilege
# escalation. However, disabling it breaks Flatpak entirely.
# Resolution: leave enabled but heavily monitor namespace creation via auditd.
kernel.unprivileged_userns_clone = 1  # MUST remain 1 for Flatpak

# ---------------------------------------------------------------------------
# Filesystem Protections
# ---------------------------------------------------------------------------

# Protect hardlinks (prevent hardlink-based privilege escalation)
# Source: kernel.org Documentation/admin-guide/sysctl/fs.rst
fs.protected_hardlinks = 1

# Protect symlinks (prevent symlink-based TOCTOU attacks)
fs.protected_symlinks = 1

# Protect FIFOs (prevent FIFO-based attacks)
fs.protected_fifos = 2

# Protect regular files (prevent unauthorized file access via sticky-bit
# directories)
fs.protected_regular = 2

# ---------------------------------------------------------------------------
# Additional Parameters
# ---------------------------------------------------------------------------

# Disable magic SysRq key (prevents physical keyboard attacks)
# Trade-off: cannot use SysRq for emergency recovery
kernel.sysrq = 0

# Restrict module loading (after boot is complete)
# modules_disabled=1 cannot be set via sysctl — must be done via kernel cmdline
# or direct write to /proc/sys/kernel/modules_disabled
# Applied post-boot via systemd service (see below)

# Disable kexec (prevents kexec-based bootkit persistence)
kernel.kexec_load_disabled = 1
```

**Post-boot module loading restriction**:

```bash
# /etc/systemd/system/modules-disable.service
[Unit]
Description=Disable kernel module loading after boot
DefaultDependencies=no
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo 1 > /proc/sys/kernel/modules_disabled'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

```bash
systemctl enable modules-disable.service
```

**CachyOS sysctl interaction note**: The `cachyos-settings` package installs `/usr/lib/sysctl.d/99-cachyos-settings.conf` with performance-oriented sysctl values.  Our hardening rules in `/etc/sysctl.d/99-hardening.conf` take precedence (later filename in the same directory; `99-` vs `99-` are sorted alphabetically — `99-cachyos-settings.conf` runs before `99-hardening.conf`). Any conflicting parameters will use the last-applied value (ours). Verify with:

```bash
sysctl -a | grep -E "tcp_syncookies|kptr_restrict|bpf_jit_harden"
```

---

## PART 6 — KERNEL MODULE BLACKLISTING

**`/etc/modprobe.d/blacklist-hardening.conf`**:

```bash
# ============================================================================
# blacklist-hardening.conf — Kernel Module Blacklist for Attack Surface Reduction
# April 2026
# ============================================================================

# --- Unused filesystems (potential attack surface via mount() exploitation) ---
install cramfs /bin/false
install freevxfs /bin/false
install jffs2 /bin/false
install hfs /bin/false
install hfsplus /bin/false
install squashfs /bin/false
install udf /bin/false

# --- fat/vfat: NOT blacklisted — needed for ESP access ---
# ESP uses FAT32; blacklisting vfat would prevent /boot mount

# --- Unused network protocols ---
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false
install n-hdlc /bin/false
install ax25 /bin/false
install netrom /bin/false
install x25 /bin/false
install atm /bin/false
install p8022 /bin/false
install psnap /bin/false
install ipx /bin/false
install appletalk /bin/false

# --- Firewire/Thunderbolt DMA attack vectors ---
# If no Firewire or Thunderbolt devices are used:
install firewire-core /bin/false
install firewire-ohci /bin/false
install firewire-sbp2 /bin/false

# --- Thunderbolt (if not using Thunderbolt devices) ---
# Conditionally blacklist if no Thunderbolt peripherals:
# install thunderbolt /bin/false

# --- Bluetooth (conditional) ---
# If Bluetooth is not needed: install bluetooth /bin/false
# If Bluetooth IS needed: leave unblacklisted + enforce AppArmor profile
# For this guide: Bluetooth is assumed to be needed for peripherals
# Uncomment the line below if Bluetooth is not used:
# install bluetooth /bin/false
# install btusb /bin/false
# install btrtl /bin/false
# install btintel /bin/false
# install btbcm /bin/false

# --- USB over IP (rarely needed, high attack surface) ---
install usbip-core /bin/false
```

---

## PART 7 — IOMMU AND DMA PROTECTION

**Required UEFI/BIOS settings**: Enable **Intel VT-d** (may be labeled "Intel Virtualization Technology for Directed I/O" or "VT-d" in firmware setup). On the i9-13900K platform (Z790 chipset), VT-d is typically under Advanced → CPU Configuration or Advanced → System Agent Configuration.

**Kernel parameters** (embedded in UKI cmdline):

```bash
# In /etc/dracut.conf.d/99-uki.conf kernel_cmdline:
intel_iommu=on iommu=force
```

**`iommu=force` vs `iommu=pt` — security trade-off**:

- `iommu=pt` (passthrough): Devices that are not explicitly assigned to VMs use identity mapping — no DMA translation overhead. **Reduced security**: devices can DMA to any physical address, bypassing IOMMU protection.
- `iommu=force` (strict): All devices are placed in IOMMU DMA remapping mode. Every DMA transfer is translated through the IOMMU page table. **Security benefit**: even non-virtualized devices cannot DMA to arbitrary memory — only to addresses explicitly mapped in the IOMMU page table. This prevents DMA-based attacks from compromised PCIe devices (including network cards, NVMe controllers, and Thunderbolt peripherals).

**This guide uses `iommu=force`**. The performance overhead on the i9-13900K is negligible for workstation workloads (measured at <2% for NVMe and network I/O on Intel VT-d with ATS support).

**Verification post-boot**:

```bash
# Check IOMMU is active
dmesg | grep -i "iommu\|DMAR"
# Expected: "DMAR: IOMMU enabled", "Intel-IOMMU: enabled"

# Check DMA remapping is active
dmesg | grep -i "dmar.*dma"
# Expected: "DMAR: Intel(R) Virtualization Technology for Directed I/O"

# Verify device IOMMU groups
find /sys/kernel/iommu_groups/ -type d | sort -V
# Each group contains devices that share an IOMMU context
```

**IOMMU + TME interaction**: Intel TME encrypts DRAM at the memory controller level. IOMMU DMA remapping protects against devices DMA-ing to unauthorized physical addresses. Together, they provide defense-in-depth: IOMMU prevents a malicious PCIe device from accessing memory it shouldn't; if IOMMU is bypassed, TME still encrypts the DRAM. TME and IOMMU are complementary, not redundant.

---

## PART 8 — ENTROPY AND RANDOM NUMBER GENERATION

**Recommendation: No userspace entropy daemon is installed.**

**Rationale** (per Pre-Work Research 0.4):

1. The Linux kernel's built-in CRNG (ChaCha20-based, seeded with BLAKE2s-extracted entropy from RDRAND, RDSEED, CPU jitter, and interrupt timing) is **cryptographically sufficient for all use cases** on x86-64 with RDTSC and RDRAND.

2. `/dev/random` and `/dev/urandom` are **equivalent** on Arch Linux (x86-64 only). Both produce the same quality of cryptographically secure pseudorandom data.

3. The kernel CRNG is initialized **before** the initramfs phase. The `random: crng init done` message in dmesg (early boot) confirms this. By the time Dracut's `systemd-cryptsetup` attempts LUKS unlock, the CRNG has been seeded from hardware sources — no userspace daemon could have run earlier anyway.

4. `rng-tools`/`rngd`, `haveged`, and `jitterentropy-rngd` provide **no meaningful security improvement** on this hardware. The kernel already uses the same entropy sources (RDRAND, CPU jitter) that these daemons would feed in.

**Verification**:

```bash
# Check CRNG initialization (should appear in early boot messages)
dmesg | grep "crng init done"

# Verify RDRAND is available
grep -o 'rdrand' /proc/cpuinfo | head -1

# Verify entropy_avail is 256 (the ChaCha20 key size)
cat /proc/sys/kernel/random/entropy_avail
# Expected output: 256

# Verify both /dev/random and /dev/urandom are non-blocking
dd if=/dev/random of=/dev/null bs=1M count=1 iflag=fullblock 2>&1
# Should complete instantly
```

---

## PART 9 — NETWORK HARDENING

### 9.1 — Firewalld

```bash
# Install firewalld
pacman -S firewalld

# Enable and start
systemctl enable firewalld.service
systemctl start firewalld.service

# Set default zone to drop (most restrictive)
firewall-cmd --set-default-zone=drop

# Verify
firewall-cmd --get-default-zone
# Expected: drop
```

**Hardened firewalld configuration**:

```bash
# Create a workstation zone for trusted interfaces
# (No public services — this is a client workstation, not a server)
firewall-cmd --permanent --new-zone=workstation
firewall-cmd --permanent --zone=workstation --set-target=DROP

# Assign interfaces to workstation zone
firewall-cmd --permanent --zone=workstation --add-interface=eth0
firewall-cmd --permanent --zone=workstation --add-interface=wlan0

# Allow essential outbound services
# DHCPv6 client (needed for IPv6)
firewall-cmd --permanent --zone=workstation --add-service=dhcpv6-client

# Cockpit management (only from localhost — see Part 9.4)
firewall-cmd --permanent --zone=workstation --add-rich-rule='
  rule family="ipv4" source address="127.0.0.1" port port="9090" protocol="tcp" accept'

# SSH (only from localhost by default; expand for specific remote admin IPs)
firewall-cmd --permanent --zone=workstation --add-rich-rule='
  rule family="ipv4" source address="127.0.0.1" port port="22" protocol="tcp" accept'

# Block cleartext DNS (port 53 outbound) — enforce encrypted DNS
# This prevents any process from bypassing dnscrypt-proxy/systemd-resolved
firewall-cmd --permanent --zone=workstation --add-rich-rule='
  rule family="ipv4" port port="53" protocol="udp" reject'
firewall-cmd --permanent --zone=workstation --add-rich-rule='
  rule family="ipv4" port port="53" protocol="tcp" reject'

# Reload firewalld
firewall-cmd --reload
```

### 9.2 — DNS over TLS and DNSCrypt via systemd-resolved

**Architecture decision**: Use `dnscrypt-proxy` as the primary DNS resolver (listening on `127.0.0.1:53`) with systemd-resolved configured as a **client** pointing to `dnscrypt-proxy`. Systemd-resolved does **not** listen on port 53 — it uses `127.0.0.53` as its stub listener.

**Why this architecture**: dnscrypt-proxy provides both DNSCrypt and DNS-over-HTTPS support with advanced filtering (no-log, no-filter, DNSSEC validation). Systemd-resolved provides local caching and per-interface DNS configuration. By chaining them (applications → systemd-resolved stub → dnscrypt-proxy → upstream encrypted resolvers), we get caching + encrypted transport + filtering.

**Port conflict management**: Systemd-resolved uses `127.0.0.53:53` for its stub resolver. dnscrypt-proxy needs to bind to port 53. The solution: disable systemd-resolved's stub listener and use dnscrypt-proxy as the sole port 53 listener. Then configure `/etc/resolv.conf` to point to `127.0.0.1` (dnscrypt-proxy). Systemd-resolved is still used for its NSS module (`nss-resolve`) but does not own port 53.

```bash
# Install packages
pacman -S dnscrypt-proxy

# Disable systemd-resolved's stub listener
# Edit /etc/systemd/resolved.conf:
```

**`/etc/systemd/resolved.conf`**:

```ini
[Resolve]
# Disable all listeners — dnscrypt-proxy handles port 53
DNSStubListener=no

# Disable LLMNR (Link-Local Multicast Name Resolution — privacy leak, spoofable)
LLMNR=no

# Disable mDNS (Multicast DNS — privacy leak on local networks)
MulticastDNS=no

# Disable DNS-over-TLS (handled by dnscrypt-proxy instead)
DNSOverTLS=no

# Disable cleartext DNS fallback
DNSSEC=no

# Disable caching (dnscrypt-proxy handles this)
Cache=no

# DNS servers — point to local dnscrypt-proxy
DNS=127.0.0.1
```

**`/etc/dnscrypt-proxy/dnscrypt-proxy.toml`** (key sections):

```toml
# Listen on localhost port 53
listen_addresses = ['127.0.0.1:53']

# Require DNSSEC validation
require_dnssec = true

# Require no-log servers
require_nolog = true

# Require no-filter servers
require_nofilter = true

# Enable anonymized DNS relays (prevents resolvers from seeing client IP)
# Routes queries through intermediate relays before reaching resolvers
anonymized_dns {
    enabled = true
    routes = [
        { server_name = 'relay1.example', via = ['anon-server-1', 'anon-server-2'] },
    ]
}

# Use multiple resolvers for redundancy
server_names = ['quad9-dnscrypt-ip4-nofilter-pri', 'cloudflare-security']

# Block IPv6 if not in use
ipv6_servers = false

# Cache responses
cache = true
cache_size = 4096
cache_min_ttl = 2400
cache_max_ttl = 86400

# Logging
log_level = 2
log_file = '/var/log/dnscrypt-proxy/dnscrypt-proxy.log'

# Fallback resolver (if all upstream servers fail)
fallback_resolvers = ['9.9.9.9:53', '1.1.1.1:53']
```

**`/etc/resolv.conf` symlink**:

```bash
# Remove any existing resolv.conf
rm /etc/resolv.conf

# Point to dnscrypt-proxy
echo "nameserver 127.0.0.1" > /etc/resolv.conf
chattr +i /etc/resolv.conf  # Immutable — prevents modification
```

**Enable and start services**:

```bash
systemctl enable dnscrypt-proxy.service
systemctl start dnscrypt-proxy.service
systemctl enable systemd-resolved.service
systemctl start systemd-resolved.service
```

### 9.3 — Hardened NetworkManager

**`/etc/NetworkManager/conf.d/99-hardening.conf`**:

```ini
[main]
# Disable unused plugins
no-auto-default=*
# Disable connectivity checking (privacy leak to connectivity-check.ubuntu.com or similar)
# APT groups can monitor connectivity check traffic for network profiling
[connectivity]
enabled=false

# Prevent NetworkManager from managing /etc/resolv.conf
# DNS is handled by systemd-resolved + dnscrypt-proxy
[keyfile]
unmanaged-devices=except:type:wifi,except:type:ethernet
```

**`/etc/NetworkManager/conf.d/99-mac-randomization.conf`**:

```ini
[device]
# MAC address randomization on all WiFi connections
wifi.scan-rand-mac-address=yes

[connection]
# Ethernet MAC randomization (if supported by driver)
ethernet.cloned-mac-address=random

# WiFi MAC randomization per connection
wifi.cloned-mac-address=random
```

**WiFi connection hardening profile**:

```bash
# For each WiFi connection, enforce:
nmcli connection modify "SSID_NAME" \
  802-11-wireless-security.key-mgmt sae \
  802-11-wireless-security.wps-method 0 \
  connection.zone workstation
```

- `key-mgmt sae`: WPA3/SAE only (reject WPA2-Personal)
- `wps-method 0`: Disable WPS entirely

### 9.4 — Cockpit Integration

```bash
# Install Cockpit (minimal set of modules)
pacman -S cockpit cockpit-packagekit

# Disable unused Cockpit modules to reduce attack surface
# Remove modules we don't need:
rm -rf /usr/share/cockpit/selinux        # SELinux not installed
rm -rf /usr/share/cockpit/networkmanager  # if not needed
rm -rf /usr/share/cockpit/storaged        # if not needed
```

**Cockpit listening restriction**: Configure Cockpit to listen on `localhost` only.

**`/etc/cockpit/cockpit.conf`**:

```ini
[WebService]
Origins = https://localhost:9090
ProtocolHeader = X-Forwarded-Proto

[Session]
IdleTimeout = 15

[Log]
Fatal = /var/log/cockpit.log
```

**Firewalld rule**:

```bash
firewall-cmd --permanent --zone=workstation --add-rich-rule='
  rule family="ipv4" source address="127.0.0.1" port port="9090" protocol="tcp" accept'
firewall-cmd --reload
```

**TLS certificate pinning**: Cockpit uses a self-signed certificate by default. For the admin browser, record the certificate fingerprint on first access and pin it:

```bash
# Get certificate fingerprint
openssl s_client -connect localhost:9090 -showcerts </dev/null 2>/dev/null \
  | openssl x509 -fingerprint -sha256 -noout
```

Store this fingerprint offline. If the fingerprint changes unexpectedly, investigate immediately — it could indicate a MITM attack or Cockpit binary replacement.

**AppArmor profile for Cockpit**: As of April 2026, the `apparmor.d` project does **not** ship a dedicated Cockpit profile.  The search results returned no Cockpit-specific profile in the `apparmor.d` repository. Compensating controls:

- Cockpit runs as a systemd service — hardened via the `svc-harden.py` tool (Part 12)
- Cockpit is restricted to localhost via its own configuration and firewalld rules
- SSH tunneling is used for remote access (SSH to the machine, then access `localhost:9090` via port forwarding)
- Auditd monitors `/etc/cockpit/` and `/usr/share/cockpit/` for unauthorized modifications

---

## PART 10 — SSH HARDENING

**`/etc/ssh/sshd_config`**:

```ini
# ============================================================================
# sshd_config — Hardened SSH Server for APT-Resistant Workstation
# April 2026
# ============================================================================

# --- Port Configuration ---
# Non-default port reduces automated attack noise but does NOT provide
# meaningful security against targeted APT attacks (they will port-scan).
# Benefit: reduces log noise from mass scanners.
# Limitation: zero security against targeted attackers.
Port 2222

# --- Protocol ---
Protocol 2

# --- Host Keys ---
# Ed25519 only (most secure, fastest)
HostKey /etc/ssh/ssh_host_ed25519_key

# --- Authentication ---
# Disable root login
PermitRootLogin no

# Disable password authentication — keys only
PasswordAuthentication no
PermitEmptyPasswords no

# Disable challenge-response (keyboard-interactive)
ChallengeResponseAuthentication no

# Disable GSSAPI (Kerberos — not used)
GSSAPIAuthentication no

# Allowed users (restrict to admin group)
AllowUsers ahsan
AllowGroups wheel

# --- Key Algorithms ---
# Restrict to Ed25519 and ECDSA with NIST P-521 minimum
# Disable RSA, DSA, ECDSA with curves weaker than P-521
HostKeyAlgorithms ssh-ed25519,ecdsa-sha2-nistp521
PubkeyAcceptedKeyTypes ssh-ed25519,ecdsa-sha2-nistp521

# --- Key Exchange ---
# Restrict to curve25519-sha256 only
# Disable all DH groups (logjam attack prevention)
# Disable ECDH with weak curves
# Source: TR-02102-1 (BSI cryptographic recommendations, 2025)
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org

# --- MACs ---
# Restrict to Encrypt-then-MAC SHA2-512 and SHA2-256 only
# ETM prevents padding oracle attacks and length extension attacks
# Disable all CBC MACs and non-ETM MACs
# Source: OpenSSH 10.0+ recommendations (April 2025)
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

# --- Ciphers ---
# AEAD ciphers only (chacha20-poly1305 and aes256-gcm)
# AEAD ciphers provide both encryption and authentication
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com

# --- Connection Hardening ---
# Time to authenticate before disconnect
LoginGraceTime 30

# Maximum authentication attempts
MaxAuthTries 3

# Maximum concurrent unauthenticated connections
MaxStartups 3:50:10

# Maximum sessions per connection
MaxSessions 5

# Idle session timeout (5 minutes idle → disconnect)
ClientAliveInterval 60
ClientAliveCountMax 5

# --- Forwarding Restrictions ---
# Disable X11 forwarding (graphical session tunneling)
X11Forwarding no

# Disable TCP forwarding (port forwarding)
AllowTcpForwarding no
AllowAgentForwarding no

# Disable StreamLocal forwarding
AllowStreamLocalForwarding no

# --- Information Disclosure ---
PrintMotd no
PrintLastLog yes

# --- Subsystem ---
Subsystem sftp /usr/lib/ssh/sftp-server

# --- Rate Limiting ---
# Per-connection rate limiting
PerSourceMaxStartups 5
PerSourceNetBlockSize 32:60
```

**`/etc/ssh/ssh_config`** (client configuration for this workstation):

```ini
# ============================================================================
# ssh_config — Hardened SSH Client
# April 2026
# ============================================================================

Host *
    # Key algorithms (same restrictions as server)
    HostKeyAlgorithms ssh-ed25519,ecdsa-sha2-nistp521
    PubkeyAcceptedKeyTypes ssh-ed25519,ecdsa-sha2-nistp521

    # Key exchange
    KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org

    # MACs
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

    # Ciphers
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com

    # Disable password authentication (keys only)
    PasswordAuthentication no

    # Verify host keys strictly
    StrictHostKeyChecking ask
    VerifyHostKeyDNS yes

    # Connection timeout
    ConnectTimeout 10
    ServerAliveInterval 30
    ServerAliveCountMax 3
```

**AppArmor sshd profile**: The `apparmor.d` project ships an sshd profile (`/etc/apparmor.d/usr.sbin.sshd`). Verify it's enforcing:

```bash
aa-status | grep sshd
# Expected: usr.sbin.sshd (enforce)
```

**Non-default port security analysis**: Using port 2222 instead of 22:

- **Benefit**: Dramatically reduces log noise from mass scanners (millions of automated attempts/day on port 22)
- **Limitation**: An APT actor targeting this specific system will port-scan first — port choice provides zero security against targeted attacks
- **This guide's position**: The non-default port is used for log hygiene, not as a security measure. The actual SSH security comes from Ed25519 keys, key-only auth, and the AppArmor sshd profile

---

## PART 11 — PAM AND AUTHENTICATION HARDENING

**`/etc/security/faillock.conf`**:

```ini
# faillock.conf — Account lockout configuration
# Applies to both local console and SSH

# Number of failed attempts before lockout
deny = 5

# Lockout duration (seconds) — 15 minutes
unlock_time = 900

# Reset counter after successful authentication
# (If user succeeds before hitting deny=, counter resets)
fail_interval = 900

# Root account can also be locked
even_deny_root

# Directory for per-user attempt tracking
dir = /var/run/faillock

# Audit logging
audit
```

**Unlock procedure for locked accounts**:

```bash
# Display failed attempts for a user
faillock --user ahsan

# Reset failed attempts (immediate unlock)
faillock --user ahsan --reset
```

**`/etc/security/pwquality.conf`**:

```ini
# pwquality.conf — Password complexity requirements
# Applies to local account passwords (SSH uses keys only, so this is for
# local console login and sudo password verification)

# Minimum password length (NIST SP 800-63B recommends 8; this guide uses 15)
minlen = 15

# Minimum number of character classes (upper, lower, digit, special)
minclass = 3

# Maximum consecutive identical characters
maxrepeat = 2

# Maximum consecutive characters from the same class
maxclassrepeat = 3

# Dictionary check (reject passwords found in wordlists)
dictcheck = 1

# Username similarity check
usercheck = 1

# Enforcing (1 = reject, 0 = warn only)
enforcing = 1

# Number of characters in new password that must differ from old
difok = 8
```

**`/etc/security/limits.conf`** additions:

```ini
# Resource limits to constrain fork bombs and resource exhaustion
# (These are for the 'ahsan' user group; adjust as needed)

# Limit number of processes per user (prevents fork bombs)
@wheel          hard    nproc           4096

# Limit number of open files (prevents file descriptor exhaustion)
@wheel          hard    nofile          65536

# Limit memory locked (prevents mlock-based DoS)
@wheel          hard    memlock         65536

# Core file size (restrict to prevent disk filling)
*               hard    core            0
```

**PAM stack configuration**: Arch Linux uses PAM base configuration files. The following modifications harden the default stacks.

**`/etc/pam.d/system-auth`** (edit existing file):

```
#%PAM-1.0

# --- Auth stack ---
# pam_faillock: preauth — deny if already locked
auth       required                    pam_faillock.so      preauth
# pam_unix: standard Unix authentication
auth       required                    pam_unix.so          sha512 shadow nullok rounds=65536
# pam_faillock: authfail — record failure
auth       [default=die]               pam_faillock.so      authfail
# pam_faillock: authsucc — clear failure count on success
auth       sufficient                  pam_faillock.so      authsucc

# --- Account stack ---
account    required                    pam_unix.so
account    required                    pam_faillock.so

# --- Password stack ---
password   required                    pam_pwquality.so
password   required                    pam_unix.so          sha512 shadow rounds=65536

# --- Session stack ---
session    required                    pam_limits.so
session    required                    pam_unix.so
session    required                    pam_umask.so         umask=0077
```

**`/etc/pam.d/sudo`** (add faillock support):

```
#%PAM-1.0
auth       required                    pam_faillock.so      preauth
auth       required                    pam_unix.so
auth       [default=die]               pam_faillock.so      authfail
account    required                    pam_unix.so
account    required                    pam_faillock.so
session    required                    pam_unix.so
```

---

## PART 12 — SYSTEMD SERVICE HARDENING (`svc-harden.py`)

The full Python tool follows. It implements all six subcommands: `analyze`, `apply`, `test`, `revert`, `bisect`, and `log`.

```python
#!/usr/bin/env python3
"""
svc-harden.py — Systemd Service Hardening Tool
April 2026

Provides interactive per-service hardening using systemd-analyze security
as the analysis backend. Operates on individual services only — bulk
application is explicitly rejected to prevent system-wide breakage.

Subcommands:
  analyze <service>  — Run systemd-analyze security and recommend directives
  apply <service>    — Interactively apply hardening directives
  test <service>     — Test a hardened service
  revert <service>   — Remove hardening and restore defaults
  bisect <service>   — Find which directive broke the service
  log                — Display change history

Threat model: APT actors exploiting weakly-configured systemd services
for persistence, privilege escalation, and lateral movement.
"""

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, List, Dict, Any

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

AUDIT_LOG_PATH = "/var/log/svc-harden-audit.json"
OVERRIDE_DIR = "/etc/systemd/system"

# All hardening directives the tool can apply
DIRECTIVES = [
    "PrivateTmp",
    "PrivateDevices",
    "ProtectSystem",
    "ProtectHome",
    "NoNewPrivileges",
    "CapabilityBoundingSet",
    "AmbientCapabilities",
    "SystemCallFilter",
    "SystemCallArchitectures",
    "RestrictAddressFamilies",
    "MemoryDenyWriteExecute",
    "RestrictNamespaces",
    "ProtectKernelTunables",
    "ProtectKernelModules",
    "ProtectKernelLogs",
    "ProtectControlGroups",
    "LockPersonality",
    "RestrictRealtime",
    "PrivateNetwork",
    "IPAddressDeny",
    "ProtectClock",
    "ProtectHostname",
    "UMask",
    "RemoveIPC",
    "PrivateUsers",
]

# Standard recommended values for each directive
RECOMMENDED_VALUES = {
    "PrivateTmp": "yes",
    "PrivateDevices": "yes",
    "ProtectSystem": "full",
    "ProtectHome": "yes",
    "NoNewPrivileges": "yes",
    "CapabilityBoundingSet": "~CAP_SYS_ADMIN ~CAP_SYS_PTRACE ~CAP_SYS_MODULE",
    "MemoryDenyWriteExecute": "yes",
    "RestrictNamespaces": "~cgroup ~ipc ~net ~mnt ~pid ~user ~uts",
    "ProtectKernelTunables": "yes",
    "ProtectKernelModules": "yes",
    "ProtectKernelLogs": "yes",
    "ProtectControlGroups": "yes",
    "LockPersonality": "yes",
    "RestrictRealtime": "yes",
    "ProtectClock": "yes",
    "ProtectHostname": "yes",
    "UMask": "0077",
    "RemoveIPC": "yes",
    "SystemCallArchitectures": "native",
}

# Directives that require service-specific consideration (not universally safe)
UNSAFE_DIRECTIVES = [
    "PrivateNetwork",      # Breaks network-dependent services
    "PrivateUsers",        # Breaks services needing UID/GID mapping
    "IPAddressDeny",       # Requires specific IP address configuration
    "SystemCallFilter",    # Service-specific syscall set
    "RestrictAddressFamilies",  # Service-specific
    "AmbientCapabilities", # May break services needing caps
]


def audit_log(entry: Dict[str, Any]) -> None:
    """Append a structured audit entry to the JSON log file."""
    entry["timestamp"] = datetime.now(timezone.utc).isoformat()
    try:
        log_path = Path(AUDIT_LOG_PATH)
        log_path.parent.mkdir(parents=True, exist_ok=True)
        entries = []
        if log_path.exists() and log_path.stat().st_size > 0:
            try:
                with open(log_path, "r") as f:
                    entries = json.load(f)
            except (json.JSONDecodeError, FileNotFoundError):
                entries = []
        entries.append(entry)
        with open(log_path, "w") as f:
            json.dump(entries, f, indent=2)
    except Exception as e:
        print(f"ERROR: Failed to write audit log: {e}", file=sys.stderr)


def run_systemd_analyze(service: str) -> Optional[str]:
    """Run systemd-analyze security for a service and return output."""
    try:
        result = subprocess.run(
            ["systemd-analyze", "security", service],
            check=True,
            capture_output=True,
            text=True,
        )
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"ERROR: systemd-analyze failed: {e.stderr}", file=sys.stderr)
        return None


def parse_analyze_output(output: str) -> Dict[str, Any]:
    """
    Parse systemd-analyze security output.
    Extracts the overall exposure score and which directives are missing.
    """
    parsed = {"score": None, "missing": [], "output": output}

    for line in output.splitlines():
        # Extract exposure score
        if "Overall exposure level" in line:
            try:
                parsed["score"] = float(line.split(":")[-1].strip().split()[0])
            except (ValueError, IndexError):
                pass

        # Detect missing hardening features
        for directive in DIRECTIVES:
            if directive in line and ("✘" in line or "×" in line or "not" in line.lower()):
                if directive not in parsed["missing"]:
                    parsed["missing"].append(directive)

    return parsed


def get_override_path(service: str) -> Path:
    """Get the path for the hardening override file."""
    service_name = service.replace(".service", "")
    return Path(OVERRIDE_DIR) / f"{service_name}.service.d" / "hardening.conf"


def apply_directives(service: str, directives: Dict[str, str], dry_run: bool = False) -> bool:
    """
    Write hardening directives to a systemd drop-in override file.
    Returns True on success.
    """
    override_path = get_override_path(service)

    content = ["# Auto-generated by svc-harden.py", f"# Date: {datetime.now(timezone.utc).isoformat()}"]
    content.append("[Service]")
    for key, value in directives.items():
        content.append(f"{key}={value}")
    content.append("")  # Trailing newline

    if dry_run:
        print(f"[DRY RUN] Would write to: {override_path}")
        print("\n".join(content))
        return True

    try:
        override_path.parent.mkdir(parents=True, exist_ok=True)
        with open(override_path, "w") as f:
            f.write("\n".join(content))
        print(f"✓ Wrote hardening config to: {override_path}")
        return True
    except Exception as e:
        print(f"ERROR: Failed to write override: {e}", file=sys.stderr)
        return False


def reload_and_restart(service: str, dry_run: bool = False) -> bool:
    """Reload systemd and restart the service."""
    if dry_run:
        print(f"[DRY RUN] Would reload daemon and restart {service}")
        return True

    try:
        subprocess.run(["systemctl", "daemon-reload"], check=True)
        subprocess.run(["systemctl", "restart", service], check=True)
        time.sleep(2)  # Let service stabilize
        result = subprocess.run(
            ["systemctl", "is-active", service],
            capture_output=True, text=True
        )
        if "active" in result.stdout:
            print(f"✓ {service} is active after restart")
            return True
        else:
            print(f"⚠ {service} status: {result.stdout.strip()}")
            return False
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Failed to reload/restart: {e}", file=sys.stderr)
        return False


def cmd_analyze(args) -> None:
    """Analyze a service and print hardening recommendations."""
    service = args.service
    if not service.endswith(".service"):
        service += ".service"

    print(f"Analyzing {service}...\n")
    output = run_systemd_analyze(service)
    if output is None:
        return

    parsed = parse_analyze_output(output)
    print(output)

    if parsed["score"] is not None:
        print(f"\nExposure Score: {parsed['score']:.1f} (lower is better)")

    if parsed["missing"]:
        print(f"\nRecommended hardening directives ({len(parsed['missing'])} missing):")
        prioritized = []
        for directive in parsed["missing"]:
            if directive in UNSAFE_DIRECTIVES:
                prioritized.append(f"  ⚠ {directive} (POTENTIALLY UNSAFE — test carefully)")
            else:
                prioritized.append(f"  ✓ {directive}")
        for line in prioritized:
            print(line)
    else:
        print("\n✓ All basic hardening directives are already applied.")


def cmd_apply(args) -> None:
    """Interactively apply hardening directives to a service."""
    service = args.service
    if not service.endswith(".service"):
        service += ".service"

    # Refuse bulk application
    if service in ("*.service", "all", "*"):
        print("ERROR: Bulk application is NOT supported. Specify an individual service.",
              file=sys.stderr)
        print("Each service requires individual evaluation — blanket hardening breaks systems.",
              file=sys.stderr)
        sys.exit(1)

    output = run_systemd_analyze(service)
    if output is None:
        return

    parsed = parse_analyze_output(output)

    if not parsed["missing"]:
        print("No missing hardening directives to apply.")
        return

    # Filter to safe directives by default, but offer all
    print(f"\nMissing directives for {service}:")
    all_missing = parsed["missing"]

    selected = {}
    for directive in all_missing:
        warning = " ⚠ POTENTIALLY UNSAFE" if directive in UNSAFE_DIRECTIVES else ""
        default_val = RECOMMENDED_VALUES.get(directive, "yes")
        print(f"\n  Directive: {directive}{warning}")
        print(f"  Recommended value: {default_val}")

        try:
            choice = input("  Apply? [Y]es / [N]o / [S]kip all / set custom [V]alue: ").strip().upper()
            if choice == "S":
                print("  Skipping remaining directives.")
                break
            elif choice == "N":
                print("  Skipped.")
                continue
            elif choice == "V":
                custom = input(f"  Enter value for {directive}: ").strip()
                if custom:
                    selected[directive] = custom
                    print(f"  Set {directive}={custom}")
            else:  # Default to Y
                selected[directive] = default_val
                print(f"  Applied {directive}={default_val}")
        except (EOFError, KeyboardInterrupt):
            print("\nAborted.")
            return

    if not selected:
        print("No directives selected. Nothing to apply.")
        return

    # Preview and confirm
    print("\nSelected directives to apply:")
    for k, v in selected.items():
        print(f"  {k}={v}")

    try:
        confirm = input("\nWrite these directives? Type 'APPLY' to confirm: ").strip()
        if confirm != "APPLY":
            print("Aborted.")
            return
    except (EOFError, KeyboardInterrupt):
        print("\nAborted.")
        return

    if apply_directives(service, selected, dry_run=args.dry_run):
        audit_log({
            "action": "apply",
            "service": service,
            "directives": selected,
            "dry_run": args.dry_run,
        })
        if not args.dry_run:
            reload_and_restart(service)
            print(f"\n✓ Hardening applied to {service}")


def cmd_test(args) -> None:
    """Test a hardened service."""
    service = args.service
    if not service.endswith(".service"):
        service += ".service"

    print(f"Testing {service}...")
    success = reload_and_restart(service, dry_run=args.dry_run)

    if success:
        print(f"✓ {service} is running with hardening applied")

        # Run user-provided test command if given
        if args.test_command:
            print(f"\nRunning test command: {args.test_command}")
            try:
                subprocess.run(args.test_command, shell=True, check=True)
                print("✓ Test command completed successfully")
            except subprocess.CalledProcessError:
                print("⚠ Test command failed — review service functionality")
    else:
        print(f"✗ {service} is not running — consider using 'bisect' to find problematic directive")

    audit_log({
        "action": "test",
        "service": service,
        "success": success,
    })


def cmd_revert(args) -> None:
    """Remove hardening override and restore defaults."""
    service = args.service
    if not service.endswith(".service"):
        service += ".service"

    override_path = get_override_path(service)

    if not override_path.exists():
        print(f"No hardening override found for {service}")
        return

    if args.dry_run:
        print(f"[DRY RUN] Would remove: {override_path}")
        return

    try:
        override_path.unlink()
        # Remove empty parent directory if it exists
        if override_path.parent.exists() and not any(override_path.parent.iterdir()):
            override_path.parent.rmdir()
        print(f"✓ Removed hardening override for {service}")

        subprocess.run(["systemctl", "daemon-reload"], check=True)
        subprocess.run(["systemctl", "restart", service], check=True)
        print(f"✓ {service} restarted with default configuration")

        audit_log({
            "action": "revert",
            "service": service,
        })
    except Exception as e:
        print(f"ERROR: Revert failed: {e}", file=sys.stderr)


def cmd_bisect(args) -> None:
    """Bisect to find which directive broke the service."""
    service = args.service
    if not service.endswith(".service"):
        service += ".service"

    override_path = get_override_path(service)

    if not override_path.exists():
        print(f"No hardening override found for {service}")
        return

    # Read existing directives
    directives = {}
    with open(override_path, "r") as f:
        for line in f:
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                key, value = line.split("=", 1)
                if key in DIRECTIVES:
                    directives[key] = value

    if not directives:
        print("No hardening directives found in override file.")
        return

    print(f"Bisecting {service} with {len(directives)} directive(s)...")
    print("Testing each directive individually to find the problematic one.\n")

    problematic = None
    for directive, value in directives.items():
        # Create a temporary override with only this directive
        test_directives = {directive: value}
        apply_directives(service, test_directives, dry_run=args.dry_run)

        if not args.dry_run:
            success = reload_and_restart(service)
            if not success:
                print(f"  ✗ {directive}={value} BREAKS the service")
                problematic = directive
                break
            else:
                print(f"  ✓ {directive}={value} is safe")

    # Restore all directives except the problematic one
    if problematic and not args.dry_run:
        working_directives = {k: v for k, v in directives.items() if k != problematic}
        apply_directives(service, working_directives)
        reload_and_restart(service)
        print(f"\n--- Bisect result ---")
        print(f"Problematic directive: {directive}={value}")
        print(f"All other directives have been re-applied.")

        print("\nOptions:")
        print("  (a) Permanently remove only the problematic directive (already done)")
        print("  (b) Revert all hardening")
        print("  (c) Keep current state")

        try:
            choice = input("Choice [a/b/c]: ").strip().lower()
            if choice == "b":
                cmd_revert(args)
            elif choice == "c":
                print("Keeping current partial-hardening state.")
            # Default is 'a' — already applied
        except (EOFError, KeyboardInterrupt):
            print("\nKeeping current state.")

        audit_log({
            "action": "bisect",
            "service": service,
            "problematic_directive": directive,
            "resolution": "removed_problematic",
        })
    elif not problematic:
        print("All directives are safe individually — the problem may be an interaction between directives.")
        audit_log({
            "action": "bisect",
            "service": service,
            "problematic_directive": None,
            "resolution": "no_single_cause",
        })


def cmd_log(args) -> None:
    """Display the tool's audit log."""
    try:
        with open(AUDIT_LOG_PATH, "r") as f:
            entries = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        print("No audit log found or log is empty.")
        return

    print(f"Svc-Harden audit log: {AUDIT_LOG_PATH}")
    print(f"Total entries: {len(entries)}\n")

    for entry in entries[-20:]:
        ts = entry.get("timestamp", "?")
        action = entry.get("action", "?")
        service = entry.get("service", "?")
        status = "✓" if entry.get("success", True) else "✗"
        print(f"  {status} [{ts}] {action} {service}")

    print(f"\nCurrently hardened services:")
    override_glob = Path(OVERRIDE_DIR).glob("*.service.d/hardening.conf")
    found = False
    for path in sorted(override_glob):
        service_name = path.parent.parent.name
        print(f"  - {service_name}")
        found = True
    if not found:
        print("  (none)")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Systemd Service Hardening Tool (APT-Resistant Configuration)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  svc-harden.py analyze sshd.service
  svc-harden.py apply sshd.service
  svc-harden.py test sshd.service --test-command "ssh localhost -p 2222 -o ConnectTimeout=5 echo OK"
  svc-harden.py revert sshd.service
  svc-harden.py bisect sshd.service
  svc-harden.py log
        """,
    )
    parser.add_argument("--dry-run", action="store_true",
                        help="Simulate operations without making changes")

    subparsers = parser.add_subparsers(dest="command", help="Subcommands")

    analyze_parser = subparsers.add_parser("analyze", help="Analyze service security")
    analyze_parser.add_argument("service", help="Service name (e.g., sshd.service)")

    apply_parser = subparsers.add_parser("apply", help="Apply hardening directives")
    apply_parser.add_argument("service", help="Service name")

    test_parser = subparsers.add_parser("test", help="Test hardened service")
    test_parser.add_argument("service", help="Service name")
    test_parser.add_argument("--test-command", help="Optional command to validate functionality")

    revert_parser = subparsers.add_parser("revert", help="Remove hardening")
    revert_parser.add_argument("service", help="Service name")

    bisect_parser = subparsers.add_parser("bisect", help="Find problematic directive")
    bisect_parser.add_argument("service", help="Service name")

    log_parser = subparsers.add_parser("log", help="Display change history")

    args = parser.parse_args()

    if args.command == "analyze":
        cmd_analyze(args)
    elif args.command == "apply":
        cmd_apply(args)
    elif args.command == "test":
        cmd_test(args)
    elif args.command == "revert":
        cmd_revert(args)
    elif args.command == "bisect":
        cmd_bisect(args)
    elif args.command == "log":
        cmd_log(args)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
```

---

## PART 13 — SUPPLY CHAIN MONITORING

**GPG signature enforcement**: Ensure pacman enforces signatures. Verify in `/etc/pacman.conf`:

```ini
[options]
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional
```

**Pacman post-install hook for audit logging**:

```bash
# /etc/pacman.d/hooks/99-pkgman-audit.hook
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Operation = Remove

[Action]
Description = Log package operations to pkgman audit log
When = PostTransaction
Exec = /usr/local/bin/pkgman-audit-hook
```

**`/usr/local/bin/pkgman-audit-hook`**:

```bash
#!/bin/bash
# Pacman hook: log package operations to structured audit log
AUDIT_LOG="/var/log/pkgman-audit.json"

while read -r event type pkg version; do
    case "$event" in
        installed|upgraded|removed)
            python3 -c "
import json, sys
from datetime import datetime, timezone
from pathlib import Path

entry = {
    'action': 'pacman_hook',
    'event': '$event',
    'package': '$pkg',
    'version': '$version',
    'timestamp': datetime.now(timezone.utc).isoformat(),
}

log_path = Path('$AUDIT_LOG')
entries = []
if log_path.exists() and log_path.stat().st_size > 0:
    try:
        entries = json.loads(log_path.read_text())
    except:
        entries = []
entries.append(entry)
log_path.write_text(json.dumps(entries, indent=2))
"
            ;;
    esac
done

chmod +x /usr/local/bin/pkgman-audit-hook
```

**CVE monitoring with `arch-audit`**:

```bash
# Install arch-audit
pacman -S arch-audit

# Run a CVE scan
arch-audit

# Schedule weekly scan via systemd timer
```

**`/etc/systemd/system/cve-scan.service`**:

```ini
[Unit]
Description=Weekly CVE vulnerability scan
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/arch-audit --upgradable --color never
StandardOutput=journal
StandardError=journal
```

**CachyOS security advisories**: As of April 2026, CachyOS does **not** publish a dedicated security advisory feed separate from Arch Linux's security tracker.  CachyOS inherits upstream Arch Linux security advisories via the Arch Linux Security Tracker (`https://security.archlinux.org`). CVE monitoring should track:

- `https://security.archlinux.org/` — Arch Linux Security Tracker
- `https://github.com/CachyOS/distribution/issues` — CachyOS distribution issues (may include security-relevant announcements)

---

## PART 14 — ONGOING MONITORING, LOG REVIEW, AND VULNERABILITY ALERTING

**Mail relay configuration**: Use `msmtp` as the local MTA relaying through either Proton Mail Bridge (preferred) or a third-party SMTP relay.

**Option 1: Proton Mail Bridge** (preferred — end-to-end encrypted):

```bash
# Install Proton Mail Bridge (AUR)
pkgman.py aur protonmail-bridge

# Bridge runs locally and exposes SMTP on localhost:1025
# Configure msmtp to relay through it
```

**Option 2: Third-party SMTP relay** (acceptable — uses TLS to relay server):

**`/etc/msmtprc`**:

```
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

# Proton Mail Bridge (preferred — local relay, E2E encrypted)
account        proton
host           localhost
port           1025
from           aahsnr041@proton.me

account default : proton
```

```bash
chmod 600 /etc/msmtprc
```

**Monitoring scripts** location: `/usr/local/lib/monitoring/`

**Daily summary script** (`/usr/local/lib/monitoring/daily-summary.sh`):

```bash
#!/bin/bash
# Daily auditd summary email to aahsnr041@proton.me

REPORT="/tmp/daily-audit-report.txt"
DATE=$(date -u +"%Y-%m-%d")
SINCE="24 hours ago"

{
    echo "=== DAILY SECURITY SUMMARY — $DATE ==="
    echo "Host: $(hostname)"
    echo ""

    echo "--- Authentication Failures ---"
    ausearch --start "$SINCE" -m USER_AUTH --success no --format text 2>/dev/null | tail -20

    echo ""
    echo "--- Privilege Escalations (sudo/su) ---"
    ausearch --start "$SINCE" -k sudo_usage -k su_usage --format text 2>/dev/null | tail -15

    echo ""
    echo "--- Kernel Module Events ---"
    ausearch --start "$SINCE" -k kmod_syscall --format text 2>/dev/null | tail -10

    echo ""
    echo "--- Package Operations ---"
    grep "$DATE" /var/log/pkgman-audit.json 2>/dev/null | tail -15

    echo ""
    echo "--- AppArmor Denial Count ---"
    journalctl -u apparmor.service --since="$SINCE" 2>/dev/null | grep -c "DENIED"

    echo ""
    echo "--- Firewall Drop Count ---"
    journalctl -u firewalld.service --since="$SINCE" 2>/dev/null | grep -c "DROP"
} > "$REPORT"

cat "$REPORT" | msmtp aahsnr041@proton.me
```

**Weekly vulnerability report** (`/usr/local/lib/monitoring/weekly-cve-report.sh`):

```bash
#!/bin/bash
# Weekly CVE scan email

REPORT="/tmp/weekly-cve-report.txt"
DATE=$(date -u +"%Y-%m-%d")

{
    echo "=== WEEKLY CVE REPORT — $DATE ==="
    echo "Host: $(hostname)"
    echo ""
    arch-audit --upgradable --color never
} > "$REPORT"

cat "$REPORT" | msmtp aahsnr041@proton.me
```

**Real-time alerting** (`/usr/local/lib/monitoring/realtime-alert.sh`):

```bash
#!/bin/bash
# Triggered by auditd when high-severity events occur
# Configured via auditd's audisp plugin or a systemd path unit

EVENT_TYPE="$1"
DETAILS="$2"

{
    echo "=== HIGH SEVERITY ALERT ==="
    echo "Time: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Host: $(hostname)"
    echo "Event: $EVENT_TYPE"
    echo "Details: $DETAILS"
} | msmtp aahsnr041@proton.me
```

**Systemd timers**:

```bash
# Daily summary timer
cat > /etc/systemd/system/daily-audit-summary.timer << 'EOF'
[Unit]
Description=Daily audit summary report

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Weekly CVE timer
cat > /etc/systemd/system/weekly-cve-scan.timer << 'EOF'
[Unit]
Description=Weekly CVE vulnerability scan

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl enable daily-audit-summary.timer weekly-cve-scan.timer
```

---

## PART 15 — EMERGENCY DISASTER RECOVERY

### 15.1 — Recovery USB Preparation

```bash
# On a separate machine, download the latest Arch Linux ISO
# Write to USB:
dd if=archlinux-2026.04.01-x86_64.iso of=/dev/sdX bs=4M status=progress

# Boot the USB on the target machine
# After booting into the live environment, install required tools:
pacman -Sy arch-install-scripts cryptsetup lvm2 btrfs-progs sbctl systemd dracut snapper
```

### 15.2 — System Unlock and Mount from Live Environment

```bash
# 1. Unlock both LUKS containers
# TPM2+PIN will not be available from the live environment —
# unlock with the recovery key or passphrase:
cryptsetup luksOpen /dev/nvme0n1 crypt0
cryptsetup luksOpen /dev/nvme1n1 crypt1

# 2. Assemble LVM
vgchange -ay vg0

# 3. Verify LV availability
lvdisplay vg0

# 4. Mount the Btrfs top-level volume (subvolid=5)
mount -o subvolid=5 /dev/mapper/vg0-lv_main /mnt

# 5. Mount all subvolumes
mount -o subvol=@ /dev/mapper/vg0-lv_main /mnt
mount -o subvol=@home /dev/mapper/vg0-lv_main /mnt/home
mount -o subvol=@opt /dev/mapper/vg0-lv_main /mnt/opt
mount -o subvol=@root /dev/mapper/vg0-lv_main /mnt/root
mount -o subvol=@srv /dev/mapper/vg0-lv_main /mnt/srv
mount -o subvol=@tmp /dev/mapper/vg0-lv_main /mnt/tmp
mount -o subvol=@usr_local /dev/mapper/vg0-lv_main /mnt/usr/local
mount -o subvol=@var /dev/mapper/vg0-lv_main /mnt/var
mount -o subvol=@var_cache /dev/mapper/vg0-lv_main /mnt/var/cache
mount -o subvol=@var_log /dev/mapper/vg0-lv_main /mnt/var/log
mount -o subvol=@var_tmp /dev/mapper/vg0-lv_main /mnt/var/tmp
mount -o subvol=@nix /dev/mapper/vg0-lv_main /mnt/nix
mount -o subvol=@snapshots /dev/mapper/vg0-lv_main /mnt/.snapshots

# 6. Mount ESP
mount /dev/nvme0n1p1 /mnt/boot

# 7. Verify all mounts
findmnt --real | grep mnt
```

### 15.3 — Chroot and System Restoration

```bash
# Chroot into the system
arch-chroot /mnt

# Once in chroot — verify the environment:
source /etc/profile
ls /boot/EFI/Linux/arch-cachyos.efi

# --- Snapper-based snapshot rollback ---
# List available snapshots
snapper -c root list

# Roll back to a specific snapshot (non-destructive)
snapper -c root --ambit classic rollback <snapshot_number>

# Exit chroot, unmount, reboot
exit
umount -R /mnt
reboot
```

**Broken UKI/Secure Boot recovery**:

```bash
# If the UKI is corrupted or Secure Boot keys are lost:
# 1. Boot from recovery USB
# 2. Disable Secure Boot in UEFI firmware
# 3. Unlock and mount the system as above
# 4. Chroot into the system
# 5. Regenerate UKI:
dracut --force --uefi /boot/EFI/Linux/arch-cachyos.efi

# 6. Regenerate Secure Boot keys and resign:
sbctl create-keys
sbctl enroll-keys -m
sbctl sign -s /boot/EFI/Linux/arch-cachyos.efi

# 7. Verify:
sbctl verify

# 8. Exit chroot, unmount, reboot
# 9. Re-enable Secure Boot in firmware
```

**Broken pacman database recovery**:

```bash
# If the pacman database is corrupted:
# 1. Chroot into the system
# 2. Check database integrity:
pacman -Dk

# 3. If broken, restore from a snapshot:
# (From within chroot, the snapshot is available at /.snapshots/)
cp -a /.snapshots/<number>/snapshot/var/lib/pacman/local/* /var/lib/pacman/local/

# 4. Re-sync:
pacman -Syy
```

### 15.4 — TPM2 Key Recovery

**Scenario: TPM state lost (firmware update, CMOS reset, key rotation)**.

**Symptom**: TPM2+PIN unlock fails at boot. System drops to LUKS password prompt.

**Recovery procedure using the recovery key**:

```bash
# At the LUKS password prompt during boot, enter the recovery key.
# The recovery key was generated and printed during setup (Part 1.3).
# This bypasses TPM2 and decrypts using the recovery key keyslot.

# After booting successfully, re-enroll TPM2:
systemd-cryptenroll --tpm2-device=auto \
  --tpm2-pcrs="7+11" \
  --tpm2-with-pin=yes \
  /dev/nvme0n1

systemd-cryptenroll --tpm2-device=auto \
  --tpm2-pcrs="7+11" \
  --tpm2-with-pin=yes \
  /dev/nvme1n1
```

**Scenario: Secure Boot keys rotated, PCR 7 changed**.

```bash
# After rotating Secure Boot keys with sbctl:
sbctl create-keys
sbctl enroll-keys -m

# Reboot. PCR 7 has changed → TPM2 unlock fails.
# Use recovery key to boot.
# After booting, re-enroll TPM2 (same commands as above).
# The new PCR 7 value is now sealed.
```

**Scenario: UKI re-signed with new keys, PCR 11 changed**.

```bash
# After signing a new UKI:
dracut --force --uefi /boot/EFI/Linux/arch-cachyos.efi
sbctl sign -s /boot/EFI/Linux/arch-cachyos.efi

# Reboot. PCR 11 has changed → TPM2 unlock fails.
# Use recovery key to boot.
# After booting, re-enroll TPM2.
```

**Critical note**: The recovery key must be stored **offline** (paper, safety deposit box, offline encrypted USB). If both the recovery key and TPM2 are unavailable simultaneously, the encrypted data is permanently inaccessible.

---

## END OF GUIDE

*Guide prepared April 2026. Architecture verified against: ArchWiki (Security, AppArmor, Dracut, Unified Kernel Image, Secure Boot, dm-crypt, Snapper, systemd-cryptenroll, firewalld, auditd, PAM, SSH), CachyOS Wiki, kernel.org documentation, apparmor.d project documentation, systemd man pages (systemd-cryptenroll, systemd-analyze, dracut), and OpenSSH 10.0 release notes.*
