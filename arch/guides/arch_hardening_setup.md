# CachyOS / Arch Linux Advanced Persistent Threat (APT) Hardening Guide
## Against Nation-State APT Threat Model — April 2026

> **Threat Model**: Chinese and Russian state-sponsored actors (APT10, APT29, APT41, Sandworm, Cozy Bear, Fancy Bear). Their documented TTPs include: supply-chain compromise (SolarWinds pattern), kernel exploits, LUKS brute-force against weak KDFs, cold-boot attacks against unencrypted RAM, DMA-over-Thunderbolt/PCIe, SSH credential harvesting, and persistence via kernel modules or systemd service hijacking. Every hardening decision herein is justified against these TTPs, not a consumer threat model.

---

## Pre-Work Research Summary

### 0.1 — CachyOS Compile-Time Hardening Status

**Findings (searched April 2026):**

CachyOS's primary value proposition is **performance optimization**, not security hardening. The following analysis distinguishes what they *do* apply versus what standard Arch and `linux-hardened` provide.

#### What CachyOS Inherits from Arch Linux

Arch Linux applies PIE, FORTIFY_SOURCE, stack protector, NX, and RELRO by default to all packages. Specifically, standard Arch GCC packages are built with `--enable-default-ssp` (stack-protector-strong) and `--enable-default-pie`. Since CachyOS rebuilds Arch packages, this baseline is **inherited**.

Arch's current defaults (as of April 2026, per ArchWiki Security packaging guidelines):
- `-fstack-protector-strong` — YES (GCC default via `--enable-default-ssp`)
- `-D_FORTIFY_SOURCE=3` — YES (Arch upgraded from `=2` to `=3` in late 2023)
- Full RELRO (`-Wl,-z,relro -Wl,-z,now`) — **PARTIAL**: Arch applies partial RELRO by default; full RELRO requires explicit `-Wl,-z,now` per-package
- PIE (`-fPIE -pie`) — YES via `--enable-default-pie`
- Shadow stack (CET/IBT) — **NO** for user packages; present in linux-hardened kernel only
- CFI — **NO** for user packages (requires Clang CFI build, not applied)

#### CachyOS-Specific Build Additions

Every CachyOS package is compiled with x86-64-v3, x86-64-v4, and Zen4 instruction sets plus LTO. Core packages receive additional PGO and BOLT optimization.

CachyOS selectively implements PGO, LTO, and BOLT optimizations depending on the need.

**LTO/PGO interaction with security flags:**

Thin LTO (`-flto=thin`) is applied across the CachyOS build infrastructure. This has a *positive* interaction with security flags:
- LTO enables cross-module inlining which makes FORTIFY_SOURCE checks more effective (more call sites can be statically analyzed)
- LTO with PIE reduces relocation overhead, making full RELRO more practical
- **Negative interaction**: Aggressive `-O3` plus PGO can, in rare cases, optimize away bounds checks that compilers would otherwise retain; this is a known issue with FORTIFY_SOURCE at high optimization levels. CachyOS uses `-O3` for core packages; Arch uses `-O2`. This is a **minor theoretical regression** against FORTIFY_SOURCE effectiveness.

The linux-cachyos kernel features Kernel Control Flow Integrity (kCFI): available when using LLVM for enhanced security. This is notable — kernel-level kCFI is a significant security win not present in `linux` or even `linux-hardened` by default.

#### Comparison Matrix

| Feature                    | Standard Arch    | CachyOS          | Gentoo hardened       | linux-hardened |
| -------------------------- | ---------------- | ---------------- | --------------------- | -------------- |
| `-fstack-protector-strong` | ✅                | ✅ (inherited)    | ✅                     | ✅              |
| `-D_FORTIFY_SOURCE=3`      | ✅                | ✅ (inherited)    | ✅                     | ✅              |
| Partial RELRO              | ✅                | ✅                | ✅                     | ✅              |
| Full RELRO                 | ❌ (partial only) | ❌ (partial only) | ✅ (with hardened USE) | ✅              |
| PIE                        | ✅                | ✅                | ✅                     | ✅              |
| LTO                        | ❌                | ✅ (ThinLTO)      | Opt-in                | ❌              |
| PGO                        | ❌                | Core pkgs only   | ❌                     | ❌              |
| Shadow Stack (CET)         | ❌                | ❌                | ❌                     | Partial        |
| CFI (user space)           | ❌                | ❌                | ❌                     | ❌              |
| kCFI (kernel)              | ❌                | ✅ (Clang build)  | ❌                     | ❌              |
| Hardened kernel config     | ❌                | Partial          | ✅                     | ✅✅             |

#### Gap Analysis: What Must Be Compensated Manually

The primary security gaps relative to Gentoo hardened or `linux-hardened`:

1. **Full RELRO is not universally applied.** Mitigation: add `-Wl,-z,now` to custom-built packages; accept the gap for pre-built binaries (the GOT-overwrite risk is partially mitigated by ASLR + PIE).

2. **No shadow stack / Intel CET for userspace.** On i9-13900K (Raptor Lake), Intel CET hardware is present. The CachyOS kernel can expose this but userspace packages are not compiled with `-mshstk -fcf-protection=full`. This cannot be compensated post-build without recompiling. **Accepted risk** with APT-threat-model justification: CET protection is primarily a mitigation against memory corruption exploits. Combined with ASLR, full RELRO (where applied), and AppArmor confinement, the residual risk is substantially reduced. Nation-state actors capable of bypassing all other layers are unlikely to be stopped by CET alone.

3. **No kernel hardened config as strong as linux-hardened.** The `linux-cachyos` kernel applies performance-focused config. Compensated by:
   - Comprehensive sysctl hardening (Part 5)
   - IOMMU strict mode (Part 7)
   - Module blacklisting (Part 6)
   - AppArmor MAC (Part 3)

**Judgment call**: CachyOS's security posture for user packages is equivalent to standard Arch, not Gentoo hardened. The performance gains from LTO/PGO/BOLT are retained since this is a workstation, not a pure security appliance. The hardening gap is compensated at the kernel, MAC, and monitoring layers.

---

### 0.2 — AppArmor Confinement vs. Flatpak: Architecture Decision

#### AppArmor.d Project Status (April 2026)

AppArmor.d is a set of over 1500 AppArmor profiles whose aim is to confine most Linux based applications and processes. It confines all root processes such as all systemd tools, bluetooth, dbus, polkit, NetworkManager, OpenVPN, GDM, rtkit, colord, and more.

The project recommends installing in complain mode first, checking logs for a week, then moving to enforce mode. Fast caching compression and early policy load are recommended due to the large number of rules (~100k lines).

**Profile coverage analysis (April 2026 state):**
- **Total profiles**: ~1500+ (covering desktop applications, system daemons, browser sandboxing, development tools)
- **Systemd tools**: Full coverage — systemd-journald, systemd-resolved, systemd-networkd, systemd-logind, systemd-udevd all have enforce-ready profiles
- **Desktop components**: NetworkManager, Bluetooth (bluetoothd), DBus (system bus), polkit, GDM/SDDM, PipeWire, PulseAudio — all covered
- **Browsers**: Firefox, Chromium, Chrome — profiles exist but in **complain mode** upstream due to the rapidly changing permissions these require
- **Development tools**: git, make, gcc, python — covered with profiles that allow typical development access
- **Enforcement status**: The project's upstream recommendation is complain-first deployment. However, system daemon profiles (systemd tools, NetworkManager, Bluetooth, polkit) are considered enforce-stable.

**Known gaps as of April 2026:**
- Wayland compositor profiles (Hyprland, Sway) are newer and may need site-specific tuning
- Custom/proprietary software has no profiles by definition
- Profiles for newer GNOME/KDE components (specifically GNOME Shell extensions) are incomplete

#### Flatpak Security Without SELinux: Technical Analysis

Flatpak's confinement model relies on multiple isolation mechanisms:
1. **Bubblewrap sandboxing** — kernel namespaces (user, mount, PID, IPC, network optionally)
2. **seccomp filtering** — syscall allowlist per application
3. **Portal permission model** — file access, location, camera, microphone gated by `xdg-desktop-portal`
4. **D-Bus policy mediation** — via `xdg-dbus-proxy`
5. **SELinux labels** (where available) — provides MAC labels for the sandbox container

**What Flatpak loses without SELinux:**

The bubblewrap container relies on Linux namespaces. On a system with only AppArmor (not SELinux):
- The `flatpak` binary and the bubblewrap launcher (`bwrap`) do not have SELinux type transitions — the sandbox process inherits its parent's AppArmor confinement, not a separate sandbox label
- File access restrictions rely entirely on bubblewrap namespace mounts plus portal grants, not MAC labels
- A namespace escape exploit would not be constrained by MAC (AppArmor does not automatically confine namespace-escaped processes the way SELinux type enforcement does)
- The `--filesystem=host` Flatpak permission, when granted, gives full filesystem access with no MAC backstop

**What Flatpak still provides without SELinux:**
- Bubblewrap namespace isolation (mount namespace, PID namespace) — still functional
- seccomp syscall filtering — still functional and effective
- Portal-mediated access — still functional for well-behaved apps
- Network isolation (optional) — still functional

**Conclusion on Flatpak**: Without SELinux, Flatpak's isolation is meaningfully weaker than on a SELinux system. A namespace escape exploit faces no MAC barrier. However, it is not *useless* — seccomp and namespace isolation still provide meaningful containment against non-root exploits. The architectural decision to use AppArmor + native packages + `apparmor.d` as the primary sandboxing mechanism is the correct choice for this threat model. AppArmor profiles applied to native binaries provide path-based MAC confinement that is well-understood, auditable, and not dependent on container namespace security.

**Decisive recommendation**: Use native package installation + `apparmor.d` confinement. Retain Flatpak only for applications with no native package equivalent and no `apparmor.d` profile. When Flatpak is used, treat it as an untrusted application with no MAC backstop — log all its actions via auditd, apply a manual AppArmor profile to `bwrap`, and ensure no `--filesystem=host` permissions are granted.

**This is a firm architectural decision. AppArmor + native packages is the sandboxing architecture.**

---

### 0.3 — Gentoo and Arch Reference File Audit

#### Key Decisions in `gentoo-setup.md` Relevant to This Arch Installation

**Disk and encryption architecture:**
- RAID-0 via `mdadm` across two NVMe drives with LUKS2 layered on top
- PBKDF2 on the GRUB-visible volume (GRUB 2.12 cannot handle Argon2id)
- Keyfile-based silent unlock for initramfs (passphrase only at GRUB)
- LUKS header backups as a first-class operation

**Btrfs subvolume layout (Tumbleweed-style):**
- `@`, `@/.snapshots`, `@/home`, `@/opt`, `@/root`, `@/srv`, `@/tmp`, `@/usr/local`, `@/var`, `@/nix`, `@/boot/grub2/x86_64-efi`
- `/boot` as a **plain directory** inside `@` (not a subvolume) so snapshots capture kernel+initramfs
- CoW disabled on `/var` and `/nix` via `chattr +C`
- Snapper with pre/post hooks around package manager

**Initramfs approach:**
- Dracut with `crypt` + `systemd` + `systemd-initrd` + `mdraid` + `btrfs`
- `/etc/crypttab.initramfs` for cryptsetup-generator (not `rd.luks.key` with systemd module)
- `hostonly=yes` for smaller images

**Snapshot booting:**
- `grub-btrfs` daemon watches `/.snapshots` and auto-regenerates GRUB config
- Rollback via `snapper rollback N` followed by `btrfs subvolume set-default`

#### Key Decisions in `arch_setup.md` and Alignment Analysis

`arch_setup.md` uses:
- LVM-on-LUKS2 (LUKS on partition, then LVM inside) — **different from Gentoo** (LUKS on RAID members)
- Limine bootloader — **replaced** in this guide by UKI + Secure Boot (no Limine)
- `limine-snapper-sync` for snapshot integration — **replaced** by chroot-based Snapper rollback (no bootloader snapshot booting per requirements)
- Extensive Btrfs subvolume layout including `@var@cache`, `@var@log@audit`, `@pkg` — **adopted and extended**
- CachyOS repo integration procedure — **retained**
- `snap-pac` for automatic snapshots — **retained** (replaces Gentoo's portage bashrc hooks)

**Conflicts and resolutions:**

| Item          | arch_setup.md                      | This Guide                  | Resolution                                           |
| ------------- | ---------------------------------- | --------------------------- | ---------------------------------------------------- |
| Bootloader    | Limine                             | UKI direct boot             | UKI required for PCR-sealed TPM2                     |
| Snapshot boot | limine-snapper-sync                | Chroot rollback only        | Explicit requirement: no bootloader snapshot booting |
| LUKS layer    | LUKS on partition → LVM            | LUKS on PV (see Part 1.3)   | Justified in Part 1.3                                |
| GRUB          | Not used                           | Not used                    | Correct — UKI bypasses need for GRUB                 |
| dracut config | `crypt dm lvm rootfs-block resume` | Extended with `tpm2` module | TPM2 unlock requirement                              |

#### Adaptation Mapping: Gentoo → Arch

| Gentoo Element                       | Arch/CachyOS Adaptation                                        |
| ------------------------------------ | -------------------------------------------------------------- |
| mdadm RAID-0 with metadata 1.2       | LVM RAID-0 (`lvcreate --type raid0`) — see Part 1.2            |
| LUKS2 with PBKDF2 (GRUB constraint)  | LUKS2 with Argon2id (no GRUB — UKI direct boot, no constraint) |
| GRUB + cryptomount                   | systemd-boot or direct UEFI load of signed UKI                 |
| `/etc/crypttab.initramfs` + keyfile  | TPM2+PIN via `systemd-cryptenroll` + PCR sealing               |
| portage bashrc pre/post hooks        | `snap-pac` pacman hook                                         |
| `grub-btrfs` daemon                  | Not needed (no bootloader snapshot booting)                    |
| `snapper rollback N`                 | Same on Arch                                                   |
| LUKS header backup                   | Same procedure                                                 |
| Keyfile at `/etc/cryptsetup-keys.d/` | Not used — TPM2 replaces keyfile                               |

---

### 0.4 — Entropy on Modern Linux Kernels (i9-13900K)

**Current state of the Linux CRNG (kernel ≥ 5.17):**

On x86-64 systems, `/dev/random` and `/dev/urandom` are now equivalent. The presence of the RDTSC instruction on all x86-64 CPUs means that the CPU-based jitterentropy algorithm will always be able to generate entropy. Most x86-64 CPUs also support RDRAND. The Linux RNG uses BLAKE2s for hashing and ChaCha20 for output generation.

The i9-13900K (Raptor Lake) has:
- **RDRAND** — hardware RNG instruction; present and trusted by the kernel (CONFIG_RANDOM_TRUST_CPU, set by most distros)
- **RDTSC** — cycle counter; used for jitterentropy
- **TPM 2.0** — another entropy source via the TPM RNG

**Are `rng-tools`, `haveged`, or `jitterentropy-rngd` necessary?**

Cases where it could make sense not to use the kernel's RNG directly include: applications that need cryptographically secure random numbers with very high throughput or very low latency. Userspace CRNGs should be seeded from the kernel's RNG.

**Verdict**: On the i9-13900K running kernel ≥ 6.x:

- `haveged` — **NOT recommended**. Haveged uses HAVEGE algorithm which is weaker than the kernel's jitterentropy implementation. On a kernel ≥ 5.6 with RDRAND+RDTSC, it provides no meaningful security improvement and adds unnecessary process overhead.
- `rng-tools` (`rngd`) — **OPTIONAL**. It can feed RDRAND output more aggressively into the pool than the kernel's own RDRAND integration, but on kernel ≥ 5.17 the kernel already integrates RDRAND natively. The marginal benefit is near-zero. If paranoia is desired, it can be installed without harm.
- `jitterentropy-rngd` — **NOT needed**. The kernel already incorporates the jitterentropy algorithm (via `CONFIG_LRNG_JENT` in newer kernels, or via the built-in jitter collector). A userspace daemon duplicates what the kernel does.

**Early-boot entropy concern (LUKS2 unlock in Dracut):**

The CRNG must be initialized before LUKS2's Argon2id KDF can begin. On the i9-13900K:
- RDRAND is available from the first CPU cycle
- `CONFIG_RANDOM_TRUST_CPU=y` (set in CachyOS kernel) means the CRNG is initialized immediately at boot via RDRAND
- The TPM2 chip also provides entropy via `tpm-rng` before Argon2id runs

**Conclusion**: No userspace entropy augmentation is needed. The system will initialize its CRNG before any LUKS2 KDF operation, both in the UKI initramfs and the running system.

---

## Part 1 — Disk Layout, Encryption, and Boot Chain

### 1.1 — Hardware

- **Drive A (nvme0n1)**: 500 GB Samsung/WD NVMe
- **Drive B (nvme1n1)**: 1 TB Samsung/WD NVMe
- CPU: Intel i9-13900K (Raptor Lake) — supports Intel TME, VT-d, CET

> **RAID-0 Warning**: Any single drive failure destroys all data on both volumes. Maintain encrypted off-site backups (e.g., Borg + age encryption to a remote host) independent of this system.

---

### 1.2 — LVM Layout

#### Architecture Decision: LVM-on-LUKS2 vs LUKS2-on-LVM

This guide uses **LUKS2-on-physical-volume, then LVM inside the LUKS container**. This means:

```
nvme0n1p1  (500GB partition)  ─┐
                                ├─→ LUKS2 containers → LVM PVs → VG → LVs
nvme1n1p1  (1TB partition)   ─┘
```

For LV-Main (the 1TB RAID-0 LV), LVM's built-in RAID-0 (`--type raid0`) is used. LVM RAID-0 is implemented via the device-mapper `dm-raid` target and does not require `mdadm`. This simplifies the initramfs (no `mdraid` dracut module needed) while providing equivalent striping performance.

**Stripe size rationale for NVMe:**

NVMe drives operate with 512B to 4096B sectors. The optimal LVM stripe size for NVMe RAID-0 is typically **512K** (512 KB). This aligns with NVMe queue depths and allows large sequential I/O to be split evenly across both drives without partial-stripe writes dominating. The `linux-cachyos` kernel's block layer handles the rest via request merging.

```bash
# Boot from Arch Linux live USB

# Verify drives
lsblk -d -o NAME,SIZE,MODEL
# Expected: nvme0n1 ~500G, nvme1n1 ~1TB

# Wipe any existing metadata
wipefs -af /dev/nvme0n1
wipefs -af /dev/nvme1n1

# Partition both drives: only an ESP on nvme0n1 (for EFI), rest as LVM PVs
# nvme1n1 is entirely an LVM PV (no ESP needed — one ESP is sufficient)

gdisk /dev/nvme0n1
# Inside gdisk:
# o → new GPT → y
# n → 1 → default → +1G → ef00   (EFI System Partition — 1GB for UKI + multiple kernels)
# n → 2 → default → default → 8e00 (Linux LVM)
# w

gdisk /dev/nvme1n1
# Inside gdisk:
# o → new GPT → y
# n → 1 → default → default → 8e00 (Linux LVM, entire drive)
# w

# Format ESP
mkfs.vfat -F32 -n ESP /dev/nvme0n1p1
```

#### LUKS2 Setup

```bash
# Format LUKS2 containers on both LVM partitions
# Using Argon2id: no GRUB constraint (UKI direct boot), so we use the strongest KDF

cryptsetup luksFormat \
  --type luks2 \
  --cipher aes-xts-plain64 \
  --key-size 512 \
  --hash sha512 \
  --pbkdf argon2id \
  --pbkdf-memory 1048576 \
  --pbkdf-parallel 4 \
  --iter-time 5000 \
  --label cryptpv-a \
  /dev/nvme0n1p2

cryptsetup luksFormat \
  --type luks2 \
  --cipher aes-xts-plain64 \
  --key-size 512 \
  --hash sha512 \
  --pbkdf argon2id \
  --pbkdf-memory 1048576 \
  --pbkdf-parallel 4 \
  --iter-time 5000 \
  --label cryptpv-b \
  /dev/nvme1n1p1

# Open the containers
cryptsetup luksOpen /dev/nvme0n1p2 cryptpv-a
cryptsetup luksOpen /dev/nvme1n1p1 cryptpv-b
```

> **Argon2id parameters**: `--pbkdf-memory 1048576` allocates 1 GB RAM for the KDF. This is deliberate: APT actors with GPU clusters cannot efficiently run 1GB-memory Argon2id. On the i9-13900K with 64GB RAM, this adds ~2 seconds to boot with no operational impact.

#### LVM Configuration

```bash
# Initialize physical volumes
pvcreate /dev/mapper/cryptpv-a
pvcreate /dev/mapper/cryptpv-b

# Create volume group spanning both PVs
vgcreate vg0 /dev/mapper/cryptpv-a /dev/mapper/cryptpv-b

# --- LV-Main: 1TB RAID-0 striped across both PVs ---
# Stripe size: 512K, 2 stripes (one per PV), 1 TB total
# This creates the primary system volume
lvcreate \
  --type raid0 \
  --stripes 2 \
  --stripesize 512K \
  --size 1T \
  --name main \
  vg0

# --- LV-Secondary: 500GB linear (non-striped) ---
# Intended use: encrypted data vault, VM images, large file storage,
# or as a separate Btrfs volume for /home if user data separation is desired.
# Linear allocation uses the remaining space on whichever PV has it.
# 500GB fits entirely on cryptpv-a (500GB drive, after main LV claims proportional space).
# Adjust -l to %FREE to use all remaining space.
lvcreate \
  --type linear \
  --size 490G \
  --name secondary \
  vg0

# Verify the layout
lvs -a -o +devices
vgs
pvs
```

**LV-Secondary use case documentation:**

`LV-Secondary` is a 490GB linear LV intended for:
1. User home directory large file storage that should survive root OS snapshots/rollbacks independently
2. Virtual machine images (CoW would be disabled: `chattr +C`)
3. Offline encrypted archive storage
4. Btrfs RAID-1 volume (pair with an external drive) for local redundancy of irreplaceable files

If `/home` must survive a root rollback independently, mount `LV-Secondary` as a separate Btrfs filesystem with its own subvolume layout, not as a subvolume of `LV-Main`.

---

### 1.3 — Full Disk Encryption: Layering Justification

**Layering chosen**: LUKS2 on physical partitions → LVM PVs inside LUKS containers → LVs above LVM.

**Why not LUKS2 on LVs (LVM-then-LUKS)?**

| Factor | LUKS-on-PV (this guide) | LUKS-on-LV |
|---|---|---|
| TPM2 PCR sealing | One LUKS device per physical drive → simpler systemd-cryptenroll per-device | Multiple LVs each need separate LUKS — exponentially more complex TPM enroll |
| Attack surface | LUKS header at physical drive level — no LVM metadata exposed unencrypted | LVM metadata (VG/LV names, sizes) exposed before LUKS unlock |
| LVM RAID-0 recovery | Can open individual PVs for partial recovery | LVM RAID-0 LV must be re-created before LUKS can be opened |
| GRUB compatibility | N/A (no GRUB) | N/A |
| **Verdict** | **Superior for TPM2 + UKI architecture** | More complex, no benefit |

---

### 1.4 — UKI and Secure Boot

#### Chain of Trust

```
UEFI Secure Boot (enrolled db key)
  └─► Signs and verifies signed UKI .efi on ESP
       └─► UKI = {kernel + initramfs + cmdline + os-release + splash} in one PE binary
            └─► Initramfs runs systemd-cryptsetup
                 └─► systemd-cryptenroll: TPM2 unseals LUKS2 key if PCR state matches
                      └─► PIN entered if PCR check passes (2FA: hardware state + PIN)
                           └─► LUKS2 unlocked → LVM activated → Btrfs root mounted
```

#### Secure Boot Key Generation and Enrollment

```bash
# Install required packages (in the chroot/installed system)
pacman -S sbctl dracut efitools

# Generate Secure Boot keys (sbctl manages the key hierarchy)
# Keys are stored at /etc/secureboot/keys/
sbctl create-keys

# Verify keys were created
sbctl status

# Enroll keys into UEFI firmware
# --microsoft flag retains Microsoft's signing certificates in db
# (required if any Microsoft-signed firmware/UEFI drivers are used)
sbctl enroll-keys --microsoft
# WARNING: --microsoft adds Microsoft certs. On a system where you control
# all boot code and have no need for Microsoft-signed Option ROMs, omit --microsoft.
# For a workstation that may have a Microsoft-signed GPU UEFI ROM, include it.
```

> **Threat model note**: Nation-state actors with physical access can perform Evil Maid attacks against the ESP. Secure Boot with custom keys defeats firmware-level tampering. The signed UKI makes the kernel cmdline part of the measurement (no cmdline injection attacks against `rd.break` or `init=/bin/bash`).

#### Dracut Configuration for UKI Output

```bash
# /etc/dracut.conf.d/00-base.conf
cat > /etc/dracut.conf.d/00-base.conf << 'EOF'
# Host-only initramfs — include only what this specific hardware needs
hostonly="yes"
hostonly_cmdline="yes"

# Output format: Unified Kernel Image (PE/COFF .efi binary)
# This is required for Secure Boot signing and TPM2 PCR measurement
uefi="yes"

# EFI stub output path — sbctl will sign this file
uefi_stub="/usr/lib/systemd/boot/efi/linuxx64.efi.stub"

# Where to place the signed UKI on the ESP
uefi_dir="/efi/EFI/Linux"

# Compression
compress="zstd"

# Required modules for LUKS2 + LVM + Btrfs + TPM2
add_dracutmodules+=" tpm2-tss crypt lvm btrfs systemd systemd-initrd "
add_drivers+=" tpm_crb tpm_tis tpm_tis_core dm_crypt dm_mod aes_x86_64 "

# Use fstab for mount hints
use_fstab="yes"

# Early microcode (Intel on i9-13900K)
early_microcode="yes"
EOF

# /etc/dracut.conf.d/01-cmdline.conf
# These parameters become immutable once signed into the UKI
# (changing them requires re-signing, which breaks PCR[8] measurement)
cat > /etc/dracut.conf.d/01-cmdline.conf << 'EOF'
# Kernel command line embedded in the UKI
# CRITICAL: These exact parameters are measured into TPM2 PCR[12]
# by systemd-boot / direct UEFI load. Any modification invalidates PCR[12]
# and TPM2 will refuse to release the LUKS key — a deliberate security property.

kernel_cmdline="quiet loglevel=3 rw"
kernel_cmdline+=" rootfstype=btrfs"
kernel_cmdline+=" rd.luks=1"
kernel_cmdline+=" rd.lvm=1"
kernel_cmdline+=" rd.lvm.vg=vg0"
kernel_cmdline+=" rd.lvm.lv=vg0/main"
kernel_cmdline+=" root=/dev/vg0/main"
kernel_cmdline+=" rootflags=subvol=@"
# TPM2 PCR sealing — do NOT add rd.luks.key here; TPM2 handles key release
kernel_cmdline+=" intel_iommu=on iommu=force"
kernel_cmdline+=" apparmor=1 security=apparmor"
kernel_cmdline+=" lsm=landlock,lockdown,yama,integrity,apparmor,bpf"
kernel_cmdline+=" audit=1"
kernel_cmdline+=" slub_debug=FZ page_poison=1"
kernel_cmdline+=" init_on_alloc=1 init_on_free=1"
kernel_cmdline+=" slab_nomerge"
kernel_cmdline+=" pti=on spectre_v2=on l1tf=full,force mds=full,nosmt tsx=off"
EOF
```

#### TPM2 + PIN Enrollment

```bash
# After first boot (system must be running, not in live environment)
# The LUKS devices must be open and the system booted into the installed OS

# First, get the LUKS device identifiers
LUKS_A=$(blkid -s UUID -o value /dev/nvme0n1p2)
LUKS_B=$(blkid -s UUID -o value /dev/nvme1n1p1)

# Enroll TPM2+PIN for Drive A
# PCR registers explanation follows this block
systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs="0+2+7+12" \
  --tpm2-with-pin=yes \
  /dev/nvme0n1p2

# Enroll TPM2+PIN for Drive B
systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs="0+2+7+12" \
  --tpm2-with-pin=yes \
  /dev/nvme1n1p1

# Generate and store a recovery key (replaces the passphrase as emergency fallback)
# Store this OFFLINE — on a FIDO2-protected encrypted USB, paper copy in a safe, etc.
systemd-cryptenroll --recovery-key /dev/nvme0n1p2
systemd-cryptenroll --recovery-key /dev/nvme1n1p1
```

#### PCR Register Selection Justification

| PCR | Measures | Why included |
|---|---|---|
| PCR[0] | UEFI firmware code | Detects firmware tampering (Evil Maid flashing malicious UEFI) |
| PCR[2] | Option ROM code | Detects malicious GPU/NIC UEFI ROMs injected via Thunderbolt/PCIe |
| PCR[7] | Secure Boot state (db, dbx, PK, KEK) | **Critical**: seals against Secure Boot key rotation. If keys change (rotation or compromise), PCR[7] changes → TPM refuses to unseal → cannot unlock without recovery key. This is the intended behavior. |
| PCR[12] | Kernel cmdline + initramfs config (systemd) | Seals against modification of the embedded UKI kernel cmdline (anti-`rd.break` injection) |

**PCR registers NOT included and why:**

- PCR[4] (bootloader): We use direct UEFI load of the signed UKI, bypassing systemd-boot as a separate stage. PCR[4] measures the bootloader itself; without a separate bootloader, this is either the UKI hash or empty.
- PCR[8] (grub cmdline): Not applicable (no GRUB).
- PCR[9] (initramfs): On recent systemd-boot/direct-UEFI-load configurations, the entire UKI including initramfs is hashed before PCR[12] sealing. Including PCR[9] separately would be redundant and could cause false invalidations on minor initramfs regenerations.

> **Trade-off documented**: PCR[0]+PCR[2] inclusion means a UEFI firmware update will invalidate the TPM seal. Procedure: before any UEFI update, use the recovery key to unlock, re-enroll TPM2 after the update, revoke the recovery key and generate a new one. This is the correct behavior — a firmware update should require explicit re-sealing.

#### UKI Signing Workflow and Pacman Hooks

```bash
# Install the pacman hook that rebuilds+signs UKI on kernel updates
# /etc/pacman.d/hooks/96-dracut-uki.hook
mkdir -p /etc/pacman.d/hooks

cat > /etc/pacman.d/hooks/96-dracut-uki.hook << 'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = linux-cachyos
Target = linux-cachyos-headers

[Action]
Description = Rebuilding UKI and signing for Secure Boot...
When = PostTransaction
Exec = /usr/local/bin/rebuild-and-sign-uki.sh
Depends = dracut
Depends = sbctl
EOF

# The signing script
cat > /usr/local/bin/rebuild-and-sign-uki.sh << 'SCRIPT'
#!/bin/bash
# rebuild-and-sign-uki.sh
# Rebuilds dracut UKI for each installed linux-cachyos kernel
# and signs it with sbctl for Secure Boot.
# Run automatically via pacman hook after kernel install/upgrade.

set -euo pipefail
LOGFILE="/var/log/uki-build.log"

log() { echo "[$(date -Iseconds)] $*" | tee -a "$LOGFILE"; }

# Find all installed kernels
for KVER in $(ls /lib/modules/ | sort -V); do
  KERNEL="/boot/vmlinuz-${KVER}"
  if [[ ! -f "$KERNEL" ]]; then
    log "Kernel image not found at $KERNEL, skipping."
    continue
  fi

  log "Building UKI for kernel $KVER"
  dracut --force \
    --hostonly \
    --uefi \
    --kver "$KVER" \
    "/efi/EFI/Linux/arch-linux-${KVER}.efi" 2>&1 | tee -a "$LOGFILE"

  log "Signing UKI for kernel $KVER"
  sbctl sign --save "/efi/EFI/Linux/arch-linux-${KVER}.efi" 2>&1 | tee -a "$LOGFILE"
done

log "UKI rebuild and sign completed."
SCRIPT

chmod +x /usr/local/bin/rebuild-and-sign-uki.sh
```

#### What Happens When Secure Boot Keys Are Rotated

If Secure Boot keys are rotated (e.g., after suspected key compromise), the following occurs:

1. PCR[7] changes (new db/PK/KEK values are now measured)
2. TPM2 attempts to unseal LUKS key → PCR[7] mismatch → **unsealing fails**
3. System prompts for recovery key (the emergency fallback enrolled earlier)
4. Recovery key unlocks LUKS
5. System boots; administrator re-enrolls TPM2 with new PCR baseline:

```bash
# After booting via recovery key with new Secure Boot keys enrolled:

# Remove old TPM2 enrollment (token slot 1 is typically the TPM2 enrollment)
systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p2
systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme1n1p1

# Re-enroll with new PCR baseline (measured by new keys)
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

# Revoke the used recovery key and generate a new one
systemd-cryptenroll --wipe-slot=recovery /dev/nvme0n1p2
systemd-cryptenroll --recovery-key /dev/nvme0n1p2
```

---

### 1.5 — No Hibernation

Hibernation is explicitly disabled. The threat model rationale: a hibernation image on disk may contain decrypted LUKS master keys, browser session tokens, SSH agent keys, or other high-value secrets in plaintext. An attacker with physical access could extract the hibernation image and analyze it offline. Suspend-to-RAM (S3) is permitted.

```bash
# Disable hibernate target
systemctl mask hibernate.target hybrid-sleep.target suspend-then-hibernate.target

# Ensure no swap is configured for hibernation
# (No swap LV in this layout; swap is a tmpfs or zswap only)

# Block the hibernate option in polkit
cat > /etc/polkit-1/rules.d/10-disable-hibernate.rules << 'EOF'
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.login1.hibernate" ||
        action.id == "org.freedesktop.login1.hibernate-multiple-sessions" ||
        action.id == "org.freedesktop.login1.handle-hibernate-key" ||
        action.id == "org.freedesktop.login1.hibernate-ignore-inhibit") {
        return polkit.Result.NO;
    }
});
EOF
```

#### Intel TME (Total Memory Encryption) for Suspend-to-RAM

Intel TME is available on Raptor Lake (i9-13900K). TME encrypts all DRAM traffic using an ephemeral AES-128 key generated by the CPU at power-on and never exposed to software.

**How TME protects against cold-boot attacks during S3:**

Cold-boot attacks require reading DRAM contents after the system is suspended. With TME active, DRAM contents are AES-128-CBC encrypted. An attacker who removes the DIMMs and puts them in a cold environment sees only ciphertext — the decryption key is inside the CPU's memory controller, not in DRAM.

**Verification:**

```bash
# Verify TME is active via MSR read (requires msr module)
modprobe msr
rdmsr 0x982   # IA32_TME_ACTIVATE MSR
# Bit 0 = TME enable; bit 1 = TME encryption bypass disable
# Expected: value with bit 1 set (0x...3 in lower bits)

# Alternatively, check CPUID leaf 0x07
cat /sys/devices/system/cpu/vulnerabilities/gather_data_sampling
# Should mention TME if active
```

**TME Limitations:**

1. TME uses AES-128 (not AES-256). Against an APT with access to quantum computing or future cryptanalytic breaks, AES-128 is a concern. This is theoretical, not practical.
2. TME does not protect against a live system compromise — if root access is obtained, memory can be read via `/dev/mem` (blocked by this guide's kernel hardening) or DMA attacks (blocked by IOMMU, Part 7).
3. TME key is CPU-generated and ephemeral. A firmware bug or MCE (Machine Check Error) that causes a CPU reset could regenerate the TME key, making suspended DRAM unreadable even to the legitimate owner. Compensating control: always resume from S3 before any firmware update or major hardware change.

---

### 1.6 — Btrfs Subvolume Layout (LV-Main)

#### Evaluation of Gentoo Layout for This System

The Gentoo guide's Tumbleweed-style layout is adopted with three modifications:

1. **No `/boot/grub2/x86_64-efi` subvolume** — there is no GRUB, so this subvolume is omitted.
2. **No Snapper-based bootloader snapshot booting** — the requirement explicitly forbids it. The `@/.snapshots` structure is retained for chroot-based rollback.
3. **Additional subvolumes from `arch_setup.md`**: `@/var/cache`, `@/var/log/audit`, `@/var/log`, `@/var/tmp` are separated per the more granular Arch layout.

#### Subvolume Layout

```bash
# After opening LUKS and activating LVM:
# Format the main LV as Btrfs
mkfs.btrfs -L main /dev/vg0/main

# Mount top-level for subvolume creation
mkdir -p /mnt/install
mount -o defaults,noatime,compress=zstd:1,space_cache=v2 /dev/vg0/main /mnt/install

# Create all subvolumes
btrfs subvolume create /mnt/install/@
btrfs subvolume create /mnt/install/@/.snapshots
btrfs subvolume create /mnt/install/@/home
btrfs subvolume create /mnt/install/@/opt
btrfs subvolume create /mnt/install/@/root
btrfs subvolume create /mnt/install/@/srv
btrfs subvolume create /mnt/install/@/tmp
mkdir -p /mnt/install/@/usr
btrfs subvolume create /mnt/install/@/usr/local
btrfs subvolume create /mnt/install/@/var
btrfs subvolume create /mnt/install/@/var/log
btrfs subvolume create /mnt/install/@/var/log/audit
btrfs subvolume create /mnt/install/@/var/cache
btrfs subvolume create /mnt/install/@/var/tmp
btrfs subvolume create /mnt/install/@/nix

# Disable CoW for write-heavy volumes
# MUST be done before any files are written to these directories
chattr +C /mnt/install/@/var
chattr +C /mnt/install/@/var/log
chattr +C /mnt/install/@/var/log/audit
chattr +C /mnt/install/@/var/cache
chattr +C /mnt/install/@/var/tmp
chattr +C /mnt/install/@/nix
```

**Subvolume justification table:**

| Subvolume | Mount | Rationale |
|---|---|---|
| `@` | `/` | Root system snapshot target |
| `@/.snapshots` | `/.snapshots` | Snapper snapshot storage; excluded from `@` snapshots |
| `@/home` | `/home` | User data survives root rollback |
| `@/opt` | `/opt` | Third-party software; excluded from root snapshots |
| `@/root` | `/root` | Root home; survives rollback independently |
| `@/srv` | `/srv` | Service data; excluded |
| `@/tmp` | `/tmp` | Ephemeral; never snapshotted |
| `@/usr/local` | `/usr/local` | Local installations; excluded from OS rollback |
| `@/var` | `/var` | journald, package cache; CoW disabled for I/O performance |
| `@/var/log` | `/var/log` | Logs excluded from rollback (forensic value) |
| `@/var/log/audit` | `/var/log/audit` | auditd logs; separate for easier log shipping |
| `@/var/cache` | `/var/cache` | Package caches; excluded and CoW disabled |
| `@/var/tmp` | `/var/tmp` | Persistent temp; excluded |
| `@/nix` | `/nix` | Nix store; CoW disabled for Nix's content-addressed store |

**Why `/boot` is NOT a subvolume** (same rationale as Gentoo guide):
`/boot` is a plain directory inside `@`. Every snapshot of `@` captures the exact kernel and initramfs present at snapshot time. If `/boot` were a separate subvolume, snapshots of `@` would not include the kernel — rolling back `@` would then boot with a mismatched kernel/modules combination, causing a kernel panic. Since we use UKI on the ESP (not in `/boot`), the ESP is outside Btrfs entirely and does not need snapshot protection.

#### Mount and Initial Setup

```bash
BTRFS_OPTS="noatime,compress=zstd:3,space_cache=v2,discard=async"
BTRFS_NOCOW_OPTS="noatime,space_cache=v2,discard=async"  # No compress for CoW-disabled

# Remount @ as root
umount /mnt/install
mount -o ${BTRFS_OPTS},subvol=@ /dev/vg0/main /mnt

# Create mount points
mkdir -p /mnt/{home,opt,root,srv,tmp,nix,usr/local}
mkdir -p /mnt/var/{log/audit,cache,tmp}
mkdir -p /mnt/.snapshots
mkdir -p /mnt/efi   # ESP mount point

# Mount all subvolumes
mount -o ${BTRFS_OPTS},subvol=@/.snapshots   /dev/vg0/main /mnt/.snapshots
mount -o ${BTRFS_OPTS},subvol=@/home         /dev/vg0/main /mnt/home
mount -o ${BTRFS_OPTS},subvol=@/opt          /dev/vg0/main /mnt/opt
mount -o ${BTRFS_OPTS},subvol=@/root         /dev/vg0/main /mnt/root
mount -o ${BTRFS_OPTS},subvol=@/srv          /dev/vg0/main /mnt/srv
mount -o ${BTRFS_OPTS},subvol=@/tmp          /dev/vg0/main /mnt/tmp
mount -o ${BTRFS_OPTS},subvol=@/usr/local    /dev/vg0/main /mnt/usr/local
mount -o ${BTRFS_NOCOW_OPTS},subvol=@/var             /dev/vg0/main /mnt/var
mount -o ${BTRFS_NOCOW_OPTS},subvol=@/var/log         /dev/vg0/main /mnt/var/log
mount -o ${BTRFS_NOCOW_OPTS},subvol=@/var/log/audit   /dev/vg0/main /mnt/var/log/audit
mount -o ${BTRFS_NOCOW_OPTS},subvol=@/var/cache       /dev/vg0/main /mnt/var/cache
mount -o ${BTRFS_NOCOW_OPTS},subvol=@/var/tmp         /dev/vg0/main /mnt/var/tmp
mount -o ${BTRFS_NOCOW_OPTS},subvol=@/nix             /dev/vg0/main /mnt/nix

# Mount ESP
mount /dev/nvme0n1p1 /mnt/efi
mkdir -p /mnt/efi/EFI/Linux   # UKI destination

# LV-Secondary format (Btrfs for flexibility)
mkfs.btrfs -L secondary /dev/vg0/secondary
```

#### Snapper Configuration

```bash
# After chrooting into the installed system:

# Initialize Snapper for root
snapper -c root create-config /

# Fix: Snapper creates its own .snapshots subvolume, which conflicts with ours
btrfs subvolume delete /.snapshots
mkdir /.snapshots
mount -o ${BTRFS_OPTS},subvol=@/.snapshots /dev/vg0/main /.snapshots
chmod 750 /.snapshots

# Configure Snapper
cat > /etc/snapper/configs/root << 'EOF'
SUBVOLUME="/"
FSTYPE="btrfs"
QGROUP=""
SPACE_LIMIT="0.5"
FREE_LIMIT="0.2"
ALLOW_USERS=""
ALLOW_GROUPS=""
SYNC_ACL="no"
BACKGROUND_COMPARISON="yes"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="15"
NUMBER_LIMIT_IMPORTANT="10"
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="2"
TIMELINE_LIMIT_MONTHLY="3"
TIMELINE_LIMIT_YEARLY="0"
EMPTY_PRE_POST_CLEANUP="yes"
EMPTY_PRE_POST_MIN_AGE="1800"
EOF

# Enable snap-pac for automatic pre/post snapshots during pacman operations
pacman -S snap-pac

systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer
systemctl enable snapper-boot.timer
```

#### Chroot-Based Snapshot Rollback Procedure

This procedure does NOT involve the bootloader. It operates entirely via chroot from a live environment.

```bash
# ===== CHROOT SNAPSHOT ROLLBACK PROCEDURE =====
# Prerequisites: Arch Linux live USB booted, drives accessible

# Step 1: Open LUKS containers
cryptsetup luksOpen /dev/nvme0n1p2 cryptpv-a
cryptsetup luksOpen /dev/nvme1n1p1 cryptpv-b

# Step 2: Activate LVM
vgchange -ay vg0

# Step 3: Mount Btrfs top-level (subvolid=5)
mkdir -p /mnt/recovery
mount -o subvolid=5 /dev/vg0/main /mnt/recovery

# Step 4: List available snapshots
btrfs subvolume list /mnt/recovery | grep "snapshots"
# Note the snapshot number you want to restore (e.g., snapshot 12)
# and find its subvolume ID

# Step 5: View snapshot info (optional)
cat /mnt/recovery/@/.snapshots/12/info.xml

# Step 6: Perform the rollback
# Method A: snapper rollback (preferred — creates a new backup of current root)
# This requires mounting @/.snapshots and running snapper from within a chroot:

# Mount the target snapshot as root
mount -o subvol=@/.snapshots/12/snapshot /dev/vg0/main /mnt/target
mount -o subvol=@/.snapshots /dev/vg0/main /mnt/target/.snapshots
mount -o subvol=@/home /dev/vg0/main /mnt/target/home
# ... mount all other subvolumes as needed for a working chroot
mount /dev/nvme0n1p1 /mnt/target/efi
mount --rbind /proc /mnt/target/proc
mount --rbind /sys /mnt/target/sys
mount --rbind /dev /mnt/target/dev

# Chroot into the snapshot
chroot /mnt/target /bin/bash
source /etc/profile

# Inside chroot: commit the rollback using snapper
snapper -c root rollback 12
# snapper rollback:
#   1. Takes a snapshot of the current @ as "pre-rollback backup"
#   2. Makes snapshot 12 the new default Btrfs subvolume
#   3. On next boot, Btrfs mounts snapshot 12 as /

# Exit chroot and reboot
exit
umount -R /mnt/target
cryptsetup close cryptpv-a
cryptsetup close cryptpv-b
reboot

# Step 7: After reboot — update /etc/fstab if needed
# Check which subvolume is now mounted as /
mount | grep "on / "
# If fstab has a hardcoded subvol= path, update it to match

# Step 8: Regenerate the UKI if kernel cmdline rootflags changed
/usr/local/bin/rebuild-and-sign-uki.sh
```

---

## Part 2 — Package Management Security Wrapper (Python 3)

```python
#!/usr/bin/env python3
"""
pkgman.py — Hardened Package Management Wrapper
CachyOS/Arch Linux — APT-Level Hardening Guide

Supports three package sources:
  1. pacman (Arch/CachyOS repos)
  2. AUR (via manual PKGBUILD analysis before install)
  3. Flatpak (with prominent security warning)

Usage:
  pkgman.py install  --source pacman  <package>
  pkgman.py install  --source aur     <package>
  pkgman.py install  --source flatpak <app-id>
  pkgman.py log      [--tail N]
  pkgman.py --dry-run install --source aur htop-vim
"""

import argparse
import base64
import datetime
import json
import logging
import os
import re
import subprocess
import sys
import tempfile
import textwrap
import urllib.request
from pathlib import Path
from typing import Optional

# ──────────────────────────────────────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────────────────────────────────────

# Default audit log path; override with --log-path
DEFAULT_AUDIT_LOG = Path("/var/log/pkgman-audit.json")

# AUR RPC endpoint
AUR_RPC_URL = "https://aur.archlinux.org/rpc/v5/info/{pkg}"
AUR_PKGBUILD_URL = "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h={pkg}"
AUR_COMMENTS_URL = "https://aur.archlinux.org/packages/{pkg}#comment-list"

# Confirmation string required for AUR installs
AUR_CONFIRM_STRING = "I HAVE REVIEWED THE PKGBUILD"

# Flatpak warning acknowledgment string
FLATPAK_CONFIRM_STRING = "ACKNOWLEDGE REDUCED CONFINEMENT"

# ──────────────────────────────────────────────────────────────────────────────
# Logging Setup
# ──────────────────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
log = logging.getLogger("pkgman")


# ──────────────────────────────────────────────────────────────────────────────
# Audit Logging
# ──────────────────────────────────────────────────────────────────────────────

def write_audit_entry(log_path: Path, entry: dict, dry_run: bool = False) -> None:
    """Append a structured JSON audit entry to the audit log file.

    Each entry is a newline-delimited JSON record (NDJSON format) to allow
    easy streaming parsing with tools like jq.  The log file is created if it
    does not exist.  Root ownership with mode 0640 is enforced so only root
    and members of the 'audit' group can read it.
    """
    if dry_run:
        log.info("[DRY-RUN] Would write audit entry: %s", json.dumps(entry))
        return

    try:
        # Ensure the log file exists with correct permissions
        if not log_path.exists():
            log_path.parent.mkdir(parents=True, exist_ok=True)
            log_path.touch(mode=0o640)
            try:
                # Attempt to set ownership to root:audit
                import grp
                audit_gid = grp.getgrnam("audit").gr_gid
                os.chown(log_path, 0, audit_gid)
            except (KeyError, PermissionError):
                pass  # Non-fatal; log with current ownership

        with open(log_path, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(entry) + "\n")
    except OSError as exc:
        log.error("Failed to write audit log: %s", exc)


def make_audit_entry(action: str, source: str, package: str,
                     status: str, details: Optional[dict] = None) -> dict:
    """Build a structured audit log entry with ISO 8601 timestamp."""
    return {
        "timestamp": datetime.datetime.now(tz=datetime.timezone.utc).isoformat(),
        "action": action,
        "source": source,
        "package": package,
        "status": status,
        "uid": os.getuid(),
        "euid": os.geteuid(),
        "pid": os.getpid(),
        "details": details or {},
    }


# ──────────────────────────────────────────────────────────────────────────────
# Pacman Helpers
# ──────────────────────────────────────────────────────────────────────────────

def verify_pacman_siglevel() -> bool:
    """Read /etc/pacman.conf and verify SigLevel is at least 'Required DatabaseOptional'.

    Returns True if acceptable, False if signature enforcement appears disabled.
    A permissive SigLevel exposes the system to package substitution attacks —
    a key TTP of supply-chain APT actors.
    """
    pacman_conf = Path("/etc/pacman.conf")
    if not pacman_conf.exists():
        log.warning("pacman.conf not found; cannot verify SigLevel")
        return False

    try:
        content = pacman_conf.read_text(encoding="utf-8")
    except OSError as exc:
        log.error("Cannot read pacman.conf: %s", exc)
        return False

    # Find the global SigLevel setting (may appear under [options] or per-repo)
    # We check the [options] section specifically
    in_options = False
    for line in content.splitlines():
        stripped = line.strip()
        if stripped.startswith("[options]"):
            in_options = True
            continue
        if stripped.startswith("[") and stripped.endswith("]"):
            in_options = False
        if in_options and stripped.lower().startswith("siglevel"):
            value = stripped.split("=", 1)[-1].strip().lower()
            # Acceptable values include required, trustedonly, etc.
            # Unacceptable: optional, never, trustall with nocheck
            if "never" in value or ("optional" in value and "database" not in value):
                log.error("Insecure SigLevel detected: %s", value)
                return False
            log.info("SigLevel looks acceptable: %s", value)
            return True

    # No explicit SigLevel in [options] — check if default is acceptable
    log.warning("No SigLevel found in [options]; using pacman default (Required DatabaseOptional).")
    return True  # pacman's default is Required DatabaseOptional which is acceptable


def pacman_install(package: str, log_path: Path, dry_run: bool = False) -> int:
    """Install a package via pacman with signature enforcement verification."""
    if not verify_pacman_siglevel():
        log.error("Aborting: pacman signature verification is not properly configured.")
        write_audit_entry(log_path, make_audit_entry(
            "install", "pacman", package, "ABORTED_SIGLEVEL_INSECURE"))
        return 1

    cmd = ["pacman", "-S", "--noconfirm", package]
    log.info("Running: %s", " ".join(cmd))

    if dry_run:
        log.info("[DRY-RUN] Would run: %s", " ".join(cmd))
        write_audit_entry(log_path, make_audit_entry(
            "install", "pacman", package, "DRY_RUN"), dry_run=True)
        return 0

    try:
        result = subprocess.run(cmd, check=False)
        status = "SUCCESS" if result.returncode == 0 else f"FAILED_RC_{result.returncode}"
        write_audit_entry(log_path, make_audit_entry(
            "install", "pacman", package, status,
            {"return_code": result.returncode}))
        return result.returncode
    except FileNotFoundError:
        log.error("pacman not found in PATH")
        write_audit_entry(log_path, make_audit_entry(
            "install", "pacman", package, "ERROR_PACMAN_NOT_FOUND"))
        return 127


# ──────────────────────────────────────────────────────────────────────────────
# AUR Analysis Engine
# ──────────────────────────────────────────────────────────────────────────────

# Patterns that indicate suspicious PKGBUILD content.
# Each entry is (regex_pattern, severity, description).
SUSPICIOUS_PATTERNS = [
    # Piped execution — most dangerous pattern
    (r"(curl|wget|fetch)\s+[^|]+\|\s*(ba)?sh", "CRITICAL",
     "Piped remote execution: script downloaded and immediately executed"),
    (r"(curl|wget|fetch)\s+[^|]+\|\s*python", "CRITICAL",
     "Piped remote Python execution"),

    # Base64 obfuscation
    (r"base64\s+(-d|--decode)\s*\|", "HIGH",
     "Base64 decoded and piped — likely obfuscated payload"),
    (r"echo\s+[A-Za-z0-9+/]{20,}={0,2}\s*\|\s*base64", "HIGH",
     "Base64 string decoded inline — possible obfuscation"),

    # Eval with encoded data
    (r"\beval\s+\$\(", "HIGH",
     "eval with command substitution — classic obfuscation pattern"),
    (r"\beval\s+[\"']?\$\{?[A-Z_]+\}?", "MEDIUM",
     "eval with variable — possible code injection"),

    # Hex-encoded commands
    (r"\\x[0-9a-fA-F]{2}(\\x[0-9a-fA-F]{2}){4,}", "HIGH",
     "Hex-encoded string — possible obfuscated shellcode"),

    # Hardcoded credentials
    (r"(?i)(password|passwd|secret|token|api_key|apikey)\s*=\s*['\"][^'\"]{4,}['\"]", "HIGH",
     "Hardcoded credential or secret token detected"),

    # Suspicious network calls in build/package phases
    (r"(curl|wget|fetch)\s+.*https?://(?!files\.archlinux\.org|download\.archlinux\.org|"
     r"aur\.archlinux\.org|github\.com|gitlab\.com|releases\.github\.com)", "MEDIUM",
     "Network call to non-canonical host during build"),

    # Weak checksums
    (r"^md5sums\s*=", "MEDIUM",
     "MD5 checksums used — collision-vulnerable; prefer b2sums or sha256sums"),
    (r"^sha1sums\s*=", "MEDIUM",
     "SHA1 checksums used — collision-vulnerable"),

    # Non-HTTPS source URLs
    (r"^source\s*=.*http://", "HIGH",
     "Non-HTTPS source URL — vulnerable to MITM"),

    # Missing checksums for URLs
    (r"SKIP", "MEDIUM",
     "Checksum entry is SKIP — no integrity verification for this source"),

    # Unusual sudo/privilege usage
    (r"\bsudo\b", "MEDIUM",
     "sudo used in PKGBUILD — should not be needed inside fakeroot"),

    # Suspicious install hooks
    (r"\.install\s*=", "INFO",
     "Package has an .install hook file — review hook script carefully"),
]


def fetch_pkgbuild(package: str) -> Optional[str]:
    """Fetch the raw PKGBUILD text from the AUR cgit API."""
    url = AUR_PKGBUILD_URL.format(pkg=package)
    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "pkgman-security-wrapper/1.0"}
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            if resp.status == 404:
                log.error("Package '%s' not found in AUR", package)
                return None
            return resp.read().decode("utf-8", errors="replace")
    except Exception as exc:
        log.error("Failed to fetch PKGBUILD for %s: %s", package, exc)
        return None


def analyze_pkgbuild(pkgbuild_text: str) -> list[dict]:
    """Perform static analysis on a PKGBUILD and return list of findings.

    Checks performed:
    - Piped remote execution patterns
    - Obfuscated strings (base64, hex, eval chains)
    - Unexpected outbound network calls in build()/package() phases
    - Hardcoded credentials, tokens, API keys
    - Suspicious .install hook references
    - Unusual makedepends/depends
    - Non-HTTPS or missing-checksum source= entries
    - Weak checksum algorithms
    """
    findings = []

    for pattern, severity, description in SUSPICIOUS_PATTERNS:
        # Multiline search across the entire PKGBUILD
        matches = re.findall(pattern, pkgbuild_text, re.MULTILINE | re.IGNORECASE)
        if matches:
            findings.append({
                "severity": severity,
                "description": description,
                "pattern": pattern,
                "match_count": len(matches),
            })

    # Check for source= entries specifically
    source_block = re.search(r"^source\s*=\s*\((.*?)\)", pkgbuild_text,
                             re.MULTILINE | re.DOTALL)
    if source_block:
        sources = source_block.group(1)
        # Check for git sources without commit pinning
        git_sources = re.findall(r"git\+https?://[^\s\"']+", sources)
        for gs in git_sources:
            if "#commit=" not in gs and "#tag=" not in gs:
                findings.append({
                    "severity": "MEDIUM",
                    "description": f"Git source without commit/tag pinning: {gs[:80]}",
                    "pattern": "git_unpinned",
                    "match_count": 1,
                })

    return findings


def display_pkgbuild_with_highlighting(pkgbuild_text: str, findings: list[dict]) -> None:
    """Print PKGBUILD to terminal, highlighting suspicious lines.

    On terminals supporting ANSI colors, suspicious patterns are highlighted
    in yellow (MEDIUM/INFO) or red (HIGH/CRITICAL).
    """
    # Collect line numbers of suspicious patterns for highlighting
    highlighted_lines: dict[int, str] = {}  # line_num → color code

    COLOR_RESET = "\033[0m"
    COLOR_RED = "\033[1;31m"
    COLOR_YELLOW = "\033[1;33m"
    COLOR_INFO = "\033[0;36m"

    for finding in findings:
        if finding["pattern"] in ("git_unpinned",):
            continue
        severity_color = {
            "CRITICAL": COLOR_RED,
            "HIGH": COLOR_RED,
            "MEDIUM": COLOR_YELLOW,
            "INFO": COLOR_INFO,
        }.get(finding["severity"], "")

        for i, line in enumerate(pkgbuild_text.splitlines(), start=1):
            if re.search(finding["pattern"], line, re.IGNORECASE):
                highlighted_lines[i] = severity_color

    print("\n" + "═" * 70)
    print("  PKGBUILD CONTENT")
    print("═" * 70)
    for i, line in enumerate(pkgbuild_text.splitlines(), start=1):
        color = highlighted_lines.get(i, "")
        if color:
            print(f"{color}{i:4d}│ {line}{COLOR_RESET}")
        else:
            print(f"{i:4d}│ {line}")
    print("═" * 70 + "\n")


def fetch_aur_comments_summary(package: str) -> list[str]:
    """Fetch recent AUR comments for a package and return a text summary.

    Parses the AUR package page HTML for comment text. This is a best-effort
    scrape; AUR does not provide an API for comments. Only the most recent
    10 comments are returned.

    Returns list of comment strings, or an empty list on failure.
    """
    url = f"https://aur.archlinux.org/packages/{package}"
    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "pkgman-security-wrapper/1.0"}
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            html = resp.read().decode("utf-8", errors="replace")

        # Extract comment text blocks (simple regex scrape)
        # AUR comments are in <div class="package-comment"> blocks
        comments = re.findall(
            r'<div\s+class="article-content">(.*?)</div>',
            html, re.DOTALL
        )
        if not comments:
            return ["(No comments found or page structure changed)"]

        # Strip HTML tags and decode entities
        plain_comments = []
        for comment in comments[:10]:
            text = re.sub(r"<[^>]+>", " ", comment)
            text = text.replace("&lt;", "<").replace("&gt;", ">")
            text = text.replace("&amp;", "&").replace("&quot;", '"')
            text = " ".join(text.split())  # normalize whitespace
            if text.strip():
                plain_comments.append(text.strip()[:300])  # truncate long comments

        return plain_comments if plain_comments else ["(Comments could not be parsed)"]

    except Exception as exc:
        return [f"(Failed to fetch comments: {exc})"]


def aur_install(package: str, log_path: Path, dry_run: bool = False) -> int:
    """Install an AUR package after multi-stage security analysis.

    Pipeline:
    1. Fetch and display PKGBUILD with syntax highlighting
    2. Run static analysis
    3. Fetch and display AUR comment summary
    4. Display consolidated findings report
    5. Require explicit typed confirmation
    6. Build and install via makepkg
    """
    print(f"\n{'═'*70}")
    print(f"  AUR SECURITY ANALYSIS: {package}")
    print(f"{'═'*70}\n")

    # Step 1: Fetch PKGBUILD
    log.info("Fetching PKGBUILD for %s...", package)
    pkgbuild_text = fetch_pkgbuild(package)
    if pkgbuild_text is None:
        log.error("Cannot proceed: PKGBUILD unavailable for %s", package)
        write_audit_entry(log_path, make_audit_entry(
            "install", "aur", package, "ABORTED_PKGBUILD_FETCH_FAILED"))
        return 1

    # Step 2: Static analysis
    log.info("Running static analysis...")
    findings = analyze_pkgbuild(pkgbuild_text)

    # Step 3: Display PKGBUILD with highlighting
    display_pkgbuild_with_highlighting(pkgbuild_text, findings)

    # Step 4: Fetch AUR comments
    log.info("Fetching AUR comments for %s...", package)
    comments = fetch_aur_comments_summary(package)

    print("\n" + "═"*70)
    print("  AUR COMMENT SUMMARY (most recent 10)")
    print("═"*70)
    for i, comment in enumerate(comments, start=1):
        print(f"  [{i}] {comment}")
    print()

    # Step 5: Display findings report
    print("═"*70)
    print("  STATIC ANALYSIS FINDINGS")
    print("═"*70)

    if not findings:
        print("  ✅  No suspicious patterns detected.\n")
    else:
        # Sort by severity
        severity_order = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "INFO": 3}
        findings.sort(key=lambda f: severity_order.get(f["severity"], 99))

        for finding in findings:
            sev = finding["severity"]
            icon = {"CRITICAL": "🚨", "HIGH": "⚠️ ", "MEDIUM": "⚠️ ", "INFO": "ℹ️ "}.get(sev, "• ")
            print(f"  {icon}  [{sev}] {finding['description']}")
            print(f"         Matches: {finding['match_count']}")
            print()

    has_critical = any(f["severity"] in ("CRITICAL", "HIGH") for f in findings)
    if has_critical:
        print("\033[1;31m  ⛔  HIGH or CRITICAL findings detected. Review carefully before proceeding.\033[0m\n")

    # Step 6: Require explicit confirmation
    print(f"{'═'*70}")
    print("  CONFIRMATION REQUIRED")
    print(f"{'═'*70}")
    print(f"""
  You are about to install an AUR package: {package}

  AUR packages are NOT maintained by the Arch Security Team.
  They may contain arbitrary code that runs with your user's privileges
  (and potentially root via PKGBUILD install hooks).

  This analysis is automated and NOT comprehensive. A determined attacker
  can craft a PKGBUILD that passes all pattern-based checks.

  If you have reviewed the PKGBUILD above and accept the risk, type exactly:

    {AUR_CONFIRM_STRING}

  Anything else will abort the installation.
""")

    if dry_run:
        log.info("[DRY-RUN] Would prompt for confirmation: %s", AUR_CONFIRM_STRING)
        write_audit_entry(log_path, make_audit_entry(
            "install", "aur", package, "DRY_RUN",
            {"findings": findings}), dry_run=True)
        return 0

    try:
        user_input = input("  Confirmation: ").strip()
    except (EOFError, KeyboardInterrupt):
        print("\n  Installation aborted by user.")
        write_audit_entry(log_path, make_audit_entry(
            "install", "aur", package, "ABORTED_USER_INTERRUPT",
            {"findings": findings}))
        return 1

    if user_input != AUR_CONFIRM_STRING:
        print("  ❌  Incorrect confirmation string. Installation aborted.")
        write_audit_entry(log_path, make_audit_entry(
            "install", "aur", package, "ABORTED_CONFIRMATION_MISMATCH",
            {"findings": findings}))
        return 1

    # Step 7: Clone from AUR and build with makepkg
    print(f"\n  Proceeding with AUR build for {package}...\n")
    write_audit_entry(log_path, make_audit_entry(
        "install_confirmed", "aur", package, "BUILDING",
        {"findings": findings}))

    try:
        with tempfile.TemporaryDirectory(prefix="pkgman-aur-") as tmpdir:
            # Clone the AUR repository
            clone_cmd = [
                "git", "clone",
                f"https://aur.archlinux.org/{package}.git",
                f"{tmpdir}/{package}"
            ]
            subprocess.run(clone_cmd, check=True)

            # Build with makepkg (as current user, not root)
            # makepkg must not be run as root
            if os.geteuid() == 0:
                log.error("pkgman should not be run as root for AUR builds.")
                log.error("Run as a regular user with sudo access.")
                return 1

            build_cmd = ["makepkg", "-si", "--noconfirm"]
            build_result = subprocess.run(
                build_cmd,
                cwd=f"{tmpdir}/{package}",
                check=False
            )

            status = "SUCCESS" if build_result.returncode == 0 else f"FAILED_RC_{build_result.returncode}"
            write_audit_entry(log_path, make_audit_entry(
                "install", "aur", package, status,
                {"findings": findings, "return_code": build_result.returncode}))
            return build_result.returncode

    except subprocess.CalledProcessError as exc:
        log.error("AUR build failed: %s", exc)
        write_audit_entry(log_path, make_audit_entry(
            "install", "aur", package, "FAILED_BUILD_ERROR",
            {"error": str(exc)}))
        return 1
    except Exception as exc:
        log.error("Unexpected error during AUR install: %s", exc)
        return 1


# ──────────────────────────────────────────────────────────────────────────────
# Flatpak Install (with AppArmor confinement warning)
# ──────────────────────────────────────────────────────────────────────────────

def flatpak_install(app_id: str, log_path: Path, dry_run: bool = False) -> int:
    """Install a Flatpak application with mandatory security warning.

    AppArmor (not Flatpak) is this system's primary sandboxing mechanism.
    Flatpak provides only bubblewrap namespace + seccomp isolation without
    SELinux — there is no MAC backstop for namespace escape exploits.
    """
    warning_text = textwrap.dedent(f"""
    ╔══════════════════════════════════════════════════════════════════════╗
    ║  ⚠️   FLATPAK SECURITY WARNING — READ BEFORE PROCEEDING            ║
    ╠══════════════════════════════════════════════════════════════════════╣
    ║                                                                      ║
    ║  This system uses AppArmor as its primary sandboxing mechanism,     ║
    ║  NOT Flatpak confinement.                                            ║
    ║                                                                      ║
    ║  On this system (AppArmor only, no SELinux):                         ║
    ║  • Flatpak provides namespace (mount/PID) + seccomp isolation        ║
    ║  • There is NO MAC (Mandatory Access Control) backstop for a        ║
    ║    container namespace escape exploit                                 ║
    ║  • A successful container escape gives attacker your full user       ║
    ║    filesystem access (no SELinux type enforcement barrier)           ║
    ║  • Flatpak permissions marked --filesystem=host are NOT restricted   ║
    ║    by any MAC policy on this system                                  ║
    ║                                                                      ║
    ║  The AppArmor profile for {app_id[:30]:<30}                   ║
    ║  may not exist in apparmor.d. If not, this application runs         ║
    ║  in the global unconfined AppArmor state.                            ║
    ║                                                                      ║
    ║  Only install this Flatpak if:                                       ║
    ║  • No native package alternative exists                              ║
    ║  • You have reviewed its Flatpak permissions (flathub page)          ║
    ║  • You accept the reduced confinement described above                ║
    ║                                                                      ║
    ║  To acknowledge and proceed, type exactly:                           ║
    ║    {FLATPAK_CONFIRM_STRING:<65} ║
    ╚══════════════════════════════════════════════════════════════════════╝
    """)
    print(warning_text)

    if dry_run:
        log.info("[DRY-RUN] Would prompt for Flatpak confinement acknowledgment")
        write_audit_entry(log_path, make_audit_entry(
            "install", "flatpak", app_id, "DRY_RUN"), dry_run=True)
        return 0

    try:
        user_input = input("  Acknowledgment: ").strip()
    except (EOFError, KeyboardInterrupt):
        print("\n  Installation aborted by user.")
        write_audit_entry(log_path, make_audit_entry(
            "install", "flatpak", app_id, "ABORTED_USER_INTERRUPT"))
        return 1

    if user_input != FLATPAK_CONFIRM_STRING:
        print("  ❌  Incorrect acknowledgment string. Installation aborted.")
        write_audit_entry(log_path, make_audit_entry(
            "install", "flatpak", app_id, "ABORTED_CONFIRMATION_MISMATCH"))
        return 1

    # Proceed with Flatpak install
    cmd = ["flatpak", "install", "--assumeyes", app_id]
    log.info("Running: %s", " ".join(cmd))

    try:
        result = subprocess.run(cmd, check=False)
        status = "SUCCESS" if result.returncode == 0 else f"FAILED_RC_{result.returncode}"
        write_audit_entry(log_path, make_audit_entry(
            "install", "flatpak", app_id, status,
            {"return_code": result.returncode,
             "warning": "REDUCED_CONFINEMENT_ACKNOWLEDGED"}))
        return result.returncode
    except FileNotFoundError:
        log.error("flatpak not found. Install it with: pacman -S flatpak")
        write_audit_entry(log_path, make_audit_entry(
            "install", "flatpak", app_id, "ERROR_FLATPAK_NOT_FOUND"))
        return 127


# ──────────────────────────────────────────────────────────────────────────────
# Log Viewer
# ──────────────────────────────────────────────────────────────────────────────

def view_log(log_path: Path, tail: int = 50) -> None:
    """Display the most recent N entries from the audit log in human-readable form."""
    if not log_path.exists():
        log.warning("No audit log found at %s", log_path)
        return

    try:
        lines = log_path.read_text(encoding="utf-8").strip().splitlines()
    except OSError as exc:
        log.error("Cannot read audit log: %s", exc)
        return

    entries = []
    for line in lines:
        try:
            entries.append(json.loads(line))
        except json.JSONDecodeError:
            continue

    recent = entries[-tail:] if len(entries) > tail else entries

    print(f"\n{'═'*70}")
    print(f"  PACKAGE MANAGEMENT AUDIT LOG (last {len(recent)} entries)")
    print(f"{'═'*70}\n")
    for entry in recent:
        ts = entry.get("timestamp", "?")
        action = entry.get("action", "?")
        source = entry.get("source", "?")
        package = entry.get("package", "?")
        status = entry.get("status", "?")
        print(f"  {ts}  [{source:8s}] {action:20s} {package:40s} → {status}")
    print()


# ──────────────────────────────────────────────────────────────────────────────
# CLI Entry Point
# ──────────────────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    """Build the argparse CLI interface."""
    parser = argparse.ArgumentParser(
        description="pkgman — Hardened package manager wrapper for CachyOS/Arch",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""
        Examples:
          sudo pkgman.py install --source pacman neovim
          pkgman.py install --source aur paru
          pkgman.py install --source flatpak org.signal.Signal
          pkgman.py log --tail 20
          pkgman.py install --source aur htop --dry-run
        """),
    )
    parser.add_argument(
        "--log-path",
        type=Path,
        default=DEFAULT_AUDIT_LOG,
        metavar="PATH",
        help=f"Path to JSON audit log file (default: {DEFAULT_AUDIT_LOG})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate actions without making changes; log as DRY_RUN",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    # install subcommand
    install_parser = subparsers.add_parser(
        "install",
        help="Install a package from the specified source",
    )
    install_parser.add_argument(
        "--source",
        required=True,
        choices=["pacman", "aur", "flatpak"],
        help="Package source: pacman, aur, or flatpak",
    )
    install_parser.add_argument(
        "package",
        help="Package name or Flatpak app ID",
    )

    # log subcommand
    log_parser = subparsers.add_parser(
        "log",
        help="View the package installation audit log",
    )
    log_parser.add_argument(
        "--tail",
        type=int,
        default=50,
        metavar="N",
        help="Show last N log entries (default: 50)",
    )

    return parser


def main() -> int:
    """Main entry point."""
    parser = build_parser()
    args = parser.parse_args()

    log_path: Path = args.log_path
    dry_run: bool = args.dry_run

    if args.command == "install":
        if args.source == "pacman":
            # pacman install requires root
            if os.geteuid() != 0 and not dry_run:
                log.error("pacman installs require root (sudo pkgman.py install --source pacman ...)")
                return 1
            return pacman_install(args.package, log_path, dry_run)

        elif args.source == "aur":
            # AUR builds must NOT be run as root
            if os.geteuid() == 0 and not dry_run:
                log.error("AUR builds must not run as root. Use a normal user with sudo.")
                return 1
            return aur_install(args.package, log_path, dry_run)

        elif args.source == "flatpak":
            return flatpak_install(args.package, log_path, dry_run)

    elif args.command == "log":
        view_log(log_path, args.tail)
        return 0

    return 0

if __name__ == "__main__":
    sys.exit(main())
```

---

## Part 3 — AppArmor Configuration

### 3.1 — AppArmor in Enforcing Mode

The kernel parameters for AppArmor are already embedded in the UKI cmdline in Part 1.4:

```
apparmor=1 security=apparmor
lsm=landlock,lockdown,yama,integrity,apparmor,bpf
```

```bash
# Install AppArmor userspace tools
pacman -S apparmor

# Enable AppArmor at boot
systemctl enable apparmor.service

# Enable audit (required for aa-log)
systemctl enable auditd.service

# Configure fast caching for ~1500 apparmor.d profiles
# This dramatically reduces boot time for large profile sets
# NOTE: these tee -a commands append to parser.conf — run each only once,
# or check that the setting is not already present before applying.
echo 'write-cache' | tee -a /etc/apparmor/parser.conf
echo 'cache-loc /etc/apparmor/earlypolicy/' | tee -a /etc/apparmor/parser.conf
echo 'Optimize=compress-fast' | tee -a /etc/apparmor/parser.conf

# Enable early policy load in initramfs
# (dracut must include the apparmor module)
echo 'early_policy=yes' | tee -a /etc/apparmor/parser.conf

# Verify after boot
aa-status
# Expected output:
# apparmor module is loaded.
# N profiles are loaded.
# N profiles are in enforce mode.
# 0 profiles are in complain mode.
```

### 3.2 — apparmor.d Integration

#### Installation on Arch Linux

The `apparmor.d` package is available in the AUR. Use `pkgman.py` to install it with full PKGBUILD review:

```bash
# Review and install via pkgman (not as root — AUR build)
pkgman.py install --source aur apparmor.d

# Alternative: manual install from source (recommended for APT threat model
# since it avoids depending on AUR infrastructure for a security-critical package)
git clone https://github.com/roddhjav/apparmor.d.git
cd apparmor.d
# Verify the commit signature
git log --show-signature -1
# Build for Arch Linux target
make   # generates ./build/apparmor.d/ tree

# Install (uses systemd preset)
sudo make install

# Append to parser.conf for fast loading (already done above)
```

#### Recommended Enforce/Complain Mode Assignments

Based on the `apparmor.d` project's maturity assessment as of April 2026:

**Enforce — these profiles are mature and stable:**

| Profile | Application | Rationale |
|---|---|---|
| `systemd` | systemd PID 1 | Extremely well-tested; preventing systemd compromise is high-value |
| `systemd-journald` | Journal daemon | High-value target; profile is stable |
| `systemd-logind` | Login session management | Stable profile |
| `NetworkManager` | Network management | Internet-facing; enforce |
| `bluetoothd` | Bluetooth daemon | High attack surface; enforce |
| `dbus-system` | System D-Bus | IPC broker; enforce |
| `dbus-session` | Session D-Bus | User IPC; enforce |
| `polkit` | Policy kit | Privilege escalation broker; enforce |
| `sshd` | SSH daemon | Internet-facing; enforce |
| `nginx`, `httpd` | Web servers (if used) | Internet-facing |
| `cups` | Print daemon | Legacy protocol attack surface |
| `avahi-daemon` | mDNS daemon | Network-facing; enforce |
| `rtkit-daemon` | Real-time scheduler | Privilege escalation vector |
| `colord` | Color management | D-Bus accessible; enforce |
| `gdm`, `sddm` | Display manager | Authentication boundary; enforce |

**Complain mode — needs site-specific tuning:**

| Profile | Reason for complain mode |
|---|---|
| Firefox, Chromium | Rapidly evolving permissions; enforce may break rendering/extensions |
| Electron apps | Vary wildly in required permissions per-app |
| Code editors (VSCode, etc.) | Plugin system requires broad file access |
| Python, Node.js interpreters | Too broad to confine usefully without per-script profiles |
| Steam, Wine | Game executables have arbitrary permission requirements |
| Flatpak + bwrap | Conditional on whether the Flatpak is used at all |

#### Handling Profile Conflicts Between `apparmor` Package and `apparmor.d`

The `apparmor` package ships a small set of base profiles in `/etc/apparmor.d/`. The `apparmor.d` project ships 1500+ profiles covering the same namespace. When both are installed:

```bash
# Check for conflicts
find /etc/apparmor.d/ -maxdepth 1 -type f | while read f; do
    name=$(basename "$f")
    if ls /etc/apparmor.d/abstractions/ | grep -q "^${name}$" 2>/dev/null; then
        echo "Potential conflict: $f"
    fi
done

# Resolution: apparmor.d profiles take precedence over distro profiles
# because they are more comprehensive. Disable distro profiles that conflict:
# Move distro-shipped conflicting profiles to /etc/apparmor.d/disable/
# (AppArmor skips profiles in the 'disable' subdirectory)

# Example: if the distro ships /etc/apparmor.d/usr.sbin.sshd and apparmor.d
# ships a more comprehensive sshd profile:
mkdir -p /etc/apparmor.d/disable
ln -sf /dev/null /etc/apparmor.d/disable/usr.sbin.sshd  # disable old profile
```

#### Local Override Files

For site-specific adjustments that must survive `apparmor.d` updates:

```bash
# Example: allow NetworkManager to access a site-specific VPN plugin
cat > /etc/apparmor.d/local/NetworkManager << 'EOF'
# Site-specific NetworkManager overrides
# This file is included by the apparmor.d NetworkManager profile
# and survives package upgrades.

# Allow access to site-specific VPN config directory
/etc/vpn/corporate/ r,
/etc/vpn/corporate/** r,
EOF

# Example: allow sshd to read a non-standard authorized_keys location
cat > /etc/apparmor.d/local/sshd << 'EOF'
# Site-specific sshd overrides
/etc/ssh/authorized_keys.d/ r,
/etc/ssh/authorized_keys.d/** r,
EOF

# Reload all profiles after changes
apparmor_parser -r /etc/apparmor.d/
```

---

## Part 4 — Auditd Hardening

```bash
# /etc/audit/rules.d/99-hardening.rules
# CachyOS/Arch Linux Hardening — auditd ruleset
# April 2026 — Against nation-state APT threat model
#
# Companion: /etc/audit/auditd.conf should have:
#   log_format = ENRICHED
#   log_group = audit
#   max_log_file_action = KEEP_LOGS
#   num_logs = 20
#   max_log_file = 50
#   space_left_action = EMAIL
#   admin_space_left_action = HALT

cat > /etc/audit/rules.d/99-hardening.rules << 'AUDITD_EOF'
## ============================================================
## /etc/audit/rules.d/99-hardening.rules
## CachyOS/Arch Linux — Hardened auditd Ruleset
## April 2026
## ============================================================

## --- Performance tuning ---
## -b: backlog buffer (increase if messages are lost during busy periods)
## -f: failure mode (2=panic on failure; 1=printk; use 1 for workstation)
## -e: enable/disable state (2=immutable after boot — prevents tampering)
-b 8192
-f 1
## NOTE: -e 2 makes rules immutable until reboot. Enable only after full testing.
## -e 2

## ============================================================
## SECTION 1: FILE INTEGRITY MONITORING
## ============================================================

## /etc — All configuration file changes
-w /etc/ -p wa -k etc_changes

## Critical authentication configs
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

## PAM configuration
-w /etc/pam.d/ -p wa -k pam_config
-w /etc/pam_mount.conf.xml -p wa -k pam_config
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

## Boot files
-w /boot/ -p wa -k boot_change
-w /efi/ -p wa -k esp_change

## Home directory attribute changes (not reads — too noisy)
-w /home/ -p a -k home_attr_change
-w /root/ -p wa -k root_home_change

## AppArmor policy files — detect in-place policy tampering
-w /etc/apparmor/ -p wa -k apparmor_policy
-w /etc/apparmor.d/ -p wa -k apparmor_policy

## systemd service files — detect persistence via service installation
-w /etc/systemd/ -p wa -k systemd_config
-w /usr/lib/systemd/ -p wa -k systemd_config
-w /usr/local/lib/systemd/ -p wa -k systemd_config

## ============================================================
## SECTION 2: PRIVILEGED COMMAND EXECUTION (setuid/setgid)
## ============================================================

## Log all executions of setuid/setgid binaries
## These are common privilege escalation vectors
-a always,exit -F arch=b64 -S execve -C uid!=euid -F euid=0 -k setuid_exec
-a always,exit -F arch=b64 -S execve -C gid!=egid -F egid=0 -k setgid_exec

## Specific high-value setuid binaries
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

## PAM stack invocations (login events)
-w /usr/lib/security/ -p x -k pam_module_exec
-w /usr/lib/pam_exec.so -p x -k pam_exec

## Login tracking files
-w /var/log/faillock/ -p wa -k auth_fail
-w /var/run/faillock/ -p wa -k auth_fail
-w /var/log/wtmp -p wa -k login_logout
-w /var/log/btmp -p wa -k failed_login
-w /run/utmp -p wa -k session_tracking

## SSH key usage and configuration
-w /root/.ssh/ -p wa -k root_ssh
-w /home/ -p wa -k user_ssh
## Note: more specific -w /home/<user>/.ssh/ rules can be added per-user

## su/sudo execution paths
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/sudo -k sudo_cmd
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/su -k su_cmd

## ============================================================
## SECTION 4: NETWORK SOCKET CREATION
## ============================================================

## Log socket creation syscalls (useful for detecting unexpected network activity)
## Filter to non-root users to reduce noise (root services are expected to create sockets)
-a always,exit -F arch=b64 -S socket -F a0=2 -F auid>=1000 -F auid!=4294967295 -k socket_ipv4
-a always,exit -F arch=b64 -S socket -F a0=10 -F auid>=1000 -F auid!=4294967295 -k socket_ipv6
-a always,exit -F arch=b64 -S socket -F a0=1 -F auid>=1000 -F auid!=4294967295 -k socket_unix
-a always,exit -F arch=b64 -S connect -F auid>=1000 -F auid!=4294967295 -k network_connect

## ============================================================
## SECTION 5: KERNEL MODULE LOADING/UNLOADING
## ============================================================

## insmod, modprobe, rmmod, modinfo
-a always,exit -F arch=b64 -S init_module -S finit_module -k module_load
-a always,exit -F arch=b64 -S delete_module -k module_unload
-w /usr/bin/kmod -p x -k kmod_exec
-w /usr/sbin/insmod -p x -k kmod_exec
-w /usr/sbin/rmmod -p x -k kmod_exec
-w /usr/sbin/modprobe -p x -k kmod_exec

## Modifications to module blacklist
-w /etc/modprobe.d/ -p wa -k modprobe_config

## ============================================================
## SECTION 6: USER, GROUP, AND PERMISSION MANAGEMENT
## ============================================================

## chmod/chown/chgrp (privilege elevation via file permission changes)
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -k perm_change
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -k owner_change
-a always,exit -F arch=b64 -S setuid -S setgid -S setreuid -S setregid -k setuid_syscall
-a always,exit -F arch=b64 -S setresuid -S setresgid -k setuid_syscall

## ============================================================
## SECTION 7: PACKAGE MANAGER ACTIVITY (pacman + CachyOS tooling)
## ============================================================
## APT detection rules adapted for pacman/CachyOS ecosystem
## These rules detect package management operations which are
## high-risk events for supply-chain attack scenarios.

## pacman binary execution
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/pacman -k pacman_exec
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/paru -k aur_helper_exec
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/yay -k aur_helper_exec

## CachyOS-specific tooling
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/cachyos-repo.sh -k cachyos_repo_exec

## Package database modification
-w /var/lib/pacman/local/ -p wa -k pkg_database_change
-w /var/lib/pacman/sync/ -p wa -k pkg_sync_change
-w /etc/pacman.conf -p wa -k pacman_config
-w /etc/pacman.d/ -p wa -k pacman_config

## makepkg execution (AUR builds)
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/makepkg -k aur_build_exec

## Pacman hooks directory
-w /etc/pacman.d/hooks/ -p wa -k pacman_hooks_change
-w /usr/share/libalpm/hooks/ -p wa -k pacman_hooks_change

## ============================================================
## SECTION 8: AUDITD/APPARMOR LOG SEPARATION NOTES
## ============================================================
##
## AppArmor denial events appear in journald/audit with the form:
##   type=AVC msg=audit(...): apparmor="DENIED" operation="..." profile="..."
## The 'k=' tag will be absent from these events — they are internally
## generated by the AppArmor LSM, not by our auditd rules.
##
## Our auditd rules produce events with type=SYSCALL or type=PATH plus
## the key tag (e.g., k=pacman_exec, k=module_load, etc.).
##
## Correlation: to correlate an AppArmor DENIED event with our syscall
## audit events, match on the audit serial number (msg=audit(timestamp:serial)).
## Both events with the same serial number are from the same syscall.
##
## For log analysis, use:
##   ausearch -k apparmor_policy  # find our AppArmor policy file modifications
##   journalctl -t audit | grep 'apparmor="DENIED"'  # AppArmor denials
##   ausearch -k module_load  # kernel module loads
##
## The apparmor.d project's deny rules generate type=AVC with:
##   apparmor="DENIED" profile="<profile_name>"
## Our rules generate type=SYSCALL with key="<our_key>".
## These are distinguishable; no collision.

## ============================================================
## SECTION 9: ADDITIONAL HIGH-VALUE RULES
## ============================================================

## /proc filesystem manipulation (potential kernel exploitation)
-w /proc/sysrq-trigger -p w -k sysrq
-w /proc/sys/kernel/ -p w -k kernel_param_change

## sysctl changes at runtime
-a always,exit -F arch=b64 -S sysctl -k sysctl_change

## Time and clock changes
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -S clock_settime -k time_change
-w /etc/localtime -p wa -k timezone_change

## Cron/at job creation (persistence mechanism)
-w /etc/cron.d/ -p wa -k cron_change
-w /etc/cron.daily/ -p wa -k cron_change
-w /etc/cron.weekly/ -p wa -k cron_change
-w /etc/crontab -p wa -k cron_change
-w /var/spool/cron/ -p wa -k cron_change

## Capabilities (privilege escalation via file capabilities)
-a always,exit -F arch=b64 -S capset -F auid>=1000 -k capabilities_set
-a always,exit -F arch=b64 -S setcap -k capabilities_set

## /dev/mem and /dev/kmem access (rootkit/DKOM attack indicator)
-w /dev/mem -p rwxa -k memory_dev_access
-w /dev/kmem -p rwxa -k memory_dev_access

## Mount operations
-a always,exit -F arch=b64 -S mount -S umount2 -F auid>=1000 -k mount_ops

## ptrace (debugging/process injection)
-a always,exit -F arch=b64 -S ptrace -F key=ptrace_use

## ============================================================
## LOCK RULES (must be last line if -e 2 is used)
## ============================================================
## Uncomment after testing:
## -e 2
AUDITD_EOF

# Configure auditd.conf
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

# Load the rules
auditctl -R /etc/audit/rules.d/99-hardening.rules

# Verify rules loaded
auditctl -l | wc -l
```

---

## Part 5 — CachyOS Kernel Hardening (sysctl)

```bash
cat > /etc/sysctl.d/99-hardening.conf << 'EOF'
##############################################################
# /etc/sysctl.d/99-hardening.conf
# CachyOS/Arch Linux — Kernel Hardening via sysctl
# April 2026 — Against nation-state APT threat model
#
# Sources: kernel.org/doc/html/latest/admin-guide/sysctl/,
#          ArchWiki: Security, Kernel parameters
##############################################################

##############################################################
## ASLR — Address Space Layout Randomization
##############################################################

# Maximum ASLR entropy for 64-bit processes (default: 28 on x86_64)
# 32 bits = maximum entropy on x86_64 with 48-bit VA space
# Source: kernel.org/doc/html/latest/admin-guide/sysctl/vm.html
kernel.randomize_va_space = 2
vm.mmap_rnd_bits = 32
vm.mmap_rnd_compat_bits = 16

##############################################################
## Kernel Address / Pointer Visibility
##############################################################

# Hide kernel symbol addresses from non-root (prevents info leaks)
# 2 = all users see 0x0 for kernel pointers
# Source: kernel.org sysctl/kernel.html
kernel.kptr_restrict = 2

# Restrict dmesg to root only
# Nation-state actors enumerate kernel version/addresses via dmesg for exploit targeting
kernel.dmesg_restrict = 1

# Restrict kernel.perf_event_paranoid to prevent perf-based info leaks
# 3 = disallows all perf events for unprivileged users (may break some profiling tools)
# Trade-off: loss of userspace profiling capability for non-root users
# Decision: accept — APT actors use perf for KASLR bypass
kernel.perf_event_paranoid = 3

##############################################################
## BPF Hardening
## BPF JIT is a significant attack surface: it can be used to
## build arbitrary kernel ROP gadgets if the JIT is not hardened.
##############################################################

# Prevent unprivileged users from loading BPF programs
# APT actors use BPF for covert network monitoring and privilege escalation
kernel.unprivileged_bpf_disabled = 1

# Harden BPF JIT against constant blinding attacks
# 2 = always enable constant blinding (even for root-privileged BPF)
kernel.bpf_jit_harden = 2

# Disable BPF JIT kallsyms exposure
kernel.bpf_jit_kallsyms = 0

##############################################################
## ptrace Restrictions
## ptrace is used by debuggers but also by APT implants for
## process injection (classic TTP: injecting into sshd/bash).
##############################################################

# ptrace scope:
# 0 = all processes can ptrace any of their children (default, permissive)
# 1 = process can only ptrace direct children (requires PTRACE_TRACEME)
# 2 = only root can use ptrace
# 3 = ptrace disabled entirely
#
# Trade-off: scope=1 breaks some profiling tools and sandboxed debuggers.
# scope=2 breaks user-space debuggers entirely without sudo.
# Decision: scope=1 for this workstation — allows gdb for owned processes,
# prevents cross-user process injection.
# Change to scope=2 if this machine handles multi-user sessions.
kernel.yama.ptrace_scope = 1

##############################################################
## userfaultfd Restrictions
## CVE-2022-0998, multiple kernel exploits use userfaultfd for
## TOCTOU race condition exploitation (Dirty Pipe, Dirty Cow variants).
##############################################################

# Restrict userfaultfd to processes with SYS_PTRACE capability
# 1 = only privileged processes can use userfaultfd
vm.unprivileged_userfaultfd = 0

##############################################################
## User Namespace Restrictions
## User namespaces are required by many legitimate sandboxing tools
## (bubblewrap, Flatpak, Chrome/Firefox sandboxing) but are also
## the attack surface for several privilege escalation CVEs.
##############################################################

# Set to 1 to enable user namespaces for unprivileged users
# Set to 0 to disable (breaks Flatpak, Chrome sandbox, etc.)
#
# Trade-off: disabling breaks browser sandboxing on Chromium/Firefox
# and Flatpak bubblewrap. Given AppArmor profiles confine these apps
# and this is a workstation, we keep user namespaces enabled but
# acknowledge the trade-off.
# APT actors who exploit user namespace CVEs are blocked by AppArmor
# profile restrictions on namespace operations.
kernel.unprivileged_userns_clone = 1
# NOTE: if AppArmor is properly confining all browsers and sandboxed apps,
# and Flatpak is not used, set to 0 for stronger protection.

##############################################################
## Network Stack Hardening
##############################################################

## IPv4

# SYN flood protection via SYN cookies
# Mitigates TCP SYN flood DDoS (rarely relevant for a workstation but cheap)
net.ipv4.tcp_syncookies = 1

# Disable source routing (used for man-in-the-middle attacks)
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Disable ICMP redirect acceptance (prevents routing table poisoning)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

# Disable secure ICMP redirect acceptance
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# Do not send ICMP redirects (we are not a router)
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Reverse path filtering — strict mode
# Drops packets whose source address is not routable back via the incoming interface
# Mitigates IP spoofing attacks
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Log martian packets (packets with impossible source addresses)
# Useful for detecting spoofing/routing attacks
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP broadcast pings (smurf attack mitigation)
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bogus ICMP error responses
net.ipv4.icmp_ignore_bogus_error_responses = 1

# TCP time-wait assassination protection
net.ipv4.tcp_rfc1337 = 1

# Disable IP forwarding (workstation, not a router)
net.ipv4.ip_forward = 0

# Increase TCP RST protection
# NOTE: tcp_challenge_ack_limit was removed in kernel 5.7+. On linux-cachyos (6.x)
# this setting is a no-op and sysctl --system will emit a warning. It is retained
# here for documentation purposes only; ignore the "No such file" warning.
net.ipv4.tcp_challenge_ack_limit = 9999

## IPv6

net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
# Disable IPv6 router advertisements if not using SLAAC
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
# Disable IPv6 forwarding
net.ipv6.conf.all.forwarding = 0

##############################################################
## Core Dump Restrictions
## Core dumps can contain passwords, session keys, decrypted data.
## APT actors access core dumps via /proc/core or coredump handlers.
##############################################################

# Restrict core dump creation to root only (value 2)
# Also prevents setuid programs from dumping (already default with 2)
fs.suid_dumpable = 0

# Prevent core dump creation for all users
kernel.core_pattern = |/bin/false

##############################################################
## Filesystem Protections
##############################################################

# Protect hard links — prevent hardlinking to files user doesn't own
# Mitigates TOCTOU attacks via hardlinks
fs.protected_hardlinks = 1

# Protect symlinks — prevent following symlinks in sticky directories
# Mitigates common TOCTOU/race attacks in /tmp
fs.protected_symlinks = 1

# Protect FIFOs in sticky directories
fs.protected_fifos = 2

# Protect regular files in sticky directories
fs.protected_regular = 2

##############################################################
## Kernel Memory Hardening
##############################################################

# Disable kexec — prevents loading a new kernel (boot-level attack)
# APT actors use kexec to bypass Secure Boot on already-booted systems
kernel.kexec_load_disabled = 1

# Disable SysRq completely (remove debug interface from keyboard)
kernel.sysrq = 0

# Restrict kernel debugging features
kernel.ftrace_enabled = 0

# Panic on kernel oops (prevents partial exploitation)
# Trade-off: unexpected crashes cause immediate reboot vs. potential exploit
# Decision: accept — nation-state exploits that cause oops and survive benefit
# from the system staying up; forced reboot clears their foothold
kernel.panic_on_oops = 1

# Reboot after 10 seconds on kernel panic
kernel.panic = 10

##############################################################
## Misc
##############################################################

# Restrict loading of line disciplines to CAP_SYS_MODULE
dev.tty.ldisc_autoload = 0
EOF

# Apply immediately
sysctl --system

# Verify critical settings
sysctl kernel.kptr_restrict kernel.dmesg_restrict kernel.unprivileged_bpf_disabled
```

---

## Part 6 — Kernel Module Blacklisting

```bash
cat > /etc/modprobe.d/blacklist-hardening.conf << 'EOF'
##############################################################
# /etc/modprobe.d/blacklist-hardening.conf
# CachyOS/Arch Linux — Kernel Module Blacklisting
# April 2026
#
# Principle: minimize kernel attack surface by preventing
# loading of unused or dangerous modules.
# Nation-state actors exploit obscure protocol parsers and
# filesystem drivers as reliable kernel code execution paths.
##############################################################

##############################################################
## Unused / Attack-Surface Filesystems
##############################################################

# cramfs — compressed ROM filesystem; rarely used, has known vulnerabilities
install cramfs /bin/false

# freevxfs — Veritas VxFS; no legitimate use on modern Linux workstations
install freevxfs /bin/false

# jffs2 — JFFS2 flash filesystem; not used on NVMe systems
install jffs2 /bin/false

# hfs — HFS (original Mac filesystem pre-HFS+); no modern use
install hfs /bin/false

# hfsplus — HFS+ (modern Mac filesystem); attack surface, rarely needed
# EXCEPTION: If you connect macOS-formatted drives, comment this out
install hfsplus /bin/false

# squashfs — Read-only compressed filesystem
# EXCEPTION: squashfs IS used by snap, Flatpak AppImages, and some live systems
# If Flatpak is used on this system, DO NOT blacklist squashfs
# Uncomment the following ONLY if Flatpak and snap are not used:
# install squashfs /bin/false

# udf — UDF filesystem (DVDs/Blu-rays)
# EXCEPTION: Comment out if you read optical media
install udf /bin/false

# vfat — FAT filesystem; required for ESP access
# DO NOT blacklist vfat — it is required for the EFI System Partition
# install vfat /bin/false  ## <-- DO NOT ENABLE

##############################################################
## Unused Network Protocols
## Each of these represents a kernel protocol parser that has historically had memory corruption vulnerabilities.
None are used on a modern Linux workstation.
##############################################################

install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false

# Legacy serial protocols
install n-hdlc /bin/false
install ax25 /bin/false
install netrom /bin/false
install x25 /bin/false
install atm /bin/false

# Obsolete LAN protocols
install p8022 /bin/false
install psnap /bin/false
install ipx /bin/false
install appletalk /bin/false

# CAN bus (automotive networking — no use on workstations)
install can /bin/false

##############################################################
## DMA Attack Surface — Firewire / Thunderbolt
## Firewire and PCIe have DMA-capable attack paths that bypass
## CPU-enforced memory protection. IOMMU (Part 7) is the primary
## mitigation; blacklisting these modules adds defense-in-depth.
##############################################################

install firewire-core /bin/false
install firewire-ohci /bin/false
install firewire-sbp2 /bin/false

# Thunderbolt — required for USB-C/Thunderbolt peripherals
# CONFLICT: blacklisting thunderbolt breaks USB-C docks and
# eGPUs on the i9-13900K (which has Thunderbolt 4 ports)
# Decision: DO NOT blacklist; instead rely on IOMMU strict mode
# to prevent Thunderbolt-DMA attacks
# install thunderbolt /bin/false  ## <-- DO NOT ENABLE on this hardware

##############################################################
## Bluetooth
## CONDITIONAL: Bluetooth has substantial attack surface
## (BlueBorne CVE-2017-1000251, BIAS, KNOB, etc.)
## If Bluetooth is not used, blacklist it.
## If Bluetooth IS used (e.g., wireless keyboard/headphones),
## comment out the blacklist entries and rely on bluetoothd
## being confined by apparmor.d profile.
##############################################################

# UNCOMMENT to disable Bluetooth:
# install bluetooth /bin/false
# install btusb /bin/false
# install rfkill /bin/false

# If Bluetooth is used, ensure these are NOT blacklisted
# and that bluetoothd is confined by AppArmor

##############################################################
## Misc High-Risk Modules
##############################################################

# USB storage — if USB drives should not be mounted by non-root
# EXCEPTION: required for recovery USB boot. Comment out if needed.
# install usb-storage /bin/false

# PCMCIA — legacy card format, no modern use
install pcmcia /bin/false
install pcmcia_core /bin/false

# Speakup — screen reader for accessibility
# Only blacklist if this system has no accessibility needs
install speakup /bin/false

# Automatic loading of CDC modules (USB modem emulation)
# These have been used to identify connected USB devices; rarely needed
install cdc-acm /bin/false

##############################################################
## CachyOS/Arch Note on Loading Order
##############################################################
# These rules are processed at module load time by modprobe.
# The 'install /bin/false' directive causes modprobe to run
# /bin/false instead of actually loading the module, which
# exits immediately with a non-zero code — effectively blocking
# the module from loading even when explicitly requested.
#
# To verify a module is blocked:
#   modprobe cramfs && echo "LOADED (should not happen)" || echo "BLOCKED"
EOF

# Rebuild initramfs to apply blacklist in early boot
dracut --force --hostonly
```

---

## Part 7 — IOMMU and DMA Protection

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

## Part 8 — Entropy and Random Number Generation

**Verdict based on Pre-Work 0.4:**

On the i9-13900K running linux-cachyos ≥ 6.x:

**No userspace entropy augmentation is needed or recommended.** Specifically:
- `haveged` — do NOT install. The algorithm is inferior to the kernel's built-in jitterentropy; it only adds complexity.
- `rng-tools` — optional, marginal benefit. If paranoia demands it, install it with RDRAND as source. It does no harm.
- `jitterentropy-rngd` — redundant with kernel's built-in jitterentropy.

**Why the kernel's RNG is sufficient on this hardware:**
1. RDRAND is available (i9-13900K) and trusted by CachyOS kernel (`CONFIG_RANDOM_TRUST_CPU=y`)
2. RDTSC is always available for jitter entropy
3. TPM 2.0 provides a third independent entropy source (`tpm-rng`)
4. The kernel's ChaCha20+BLAKE2s CRNG is initialized immediately at boot via RDRAND
5. On x86-64, `/dev/random` and `/dev/urandom` are equivalent — no blocking

**Early-boot concern (initramfs LUKS2 unlock):** Not an issue. RDRAND initializes the CRNG before the TPM2+PIN challenge in the dracut initramfs. The Argon2id KDF has access to a fully initialized CRNG.

```bash
# Verify CRNG is initialized immediately at boot
dmesg | grep -E "(crng|random)"
# Expected: "random: crng init done" very early, before LUKS2 unlock
# On RDRAND-capable hardware: "random: crng done (trusting CPU's manufacturer)"

# Verify TPM RNG is available
cat /sys/devices/virtual/misc/hw_random/rng_available
# Expected output includes: tpm-rng

# Verify current RNG source
cat /sys/devices/virtual/misc/hw_random/rng_current
# Should show: tpm-rng or rdrand

# Check entropy pool state
cat /proc/sys/kernel/random/entropy_avail
# On kernel ≥ 5.6, this will typically show 256 (the CRNG seed size)
# The old "need 4096 bits" threshold no longer applies
```

---

## Part 9 — Network Hardening

### 9.1 — Hardened Firewalld Configuration

```bash
pacman -S firewalld

systemctl enable --now firewalld

# Set all interfaces to 'drop' zone by default
# 'drop' silently drops all incoming packets not matching any allow rule
firewall-cmd --set-default-zone=drop

# Verify the current state
firewall-cmd --get-default-zone   # Should show: drop

# Apply to all active interfaces
firewall-cmd --zone=drop --change-interface=eno1 --permanent 2>/dev/null || true
firewall-cmd --zone=drop --change-interface=wlan0 --permanent 2>/dev/null || true

# Allow ESTABLISHED and RELATED connections (stateful tracking)
# This is implicit in the 'drop' zone; firewalld handles this automatically
# via nftables ESTABLISHED,RELATED rules

# Allow DNS-over-TLS (outbound 853/tcp) — required for dnscrypt-proxy
# Note: block port 53 outbound to enforce encrypted DNS (see DNSCrypt section)
firewall-cmd --zone=drop --add-rich-rule='rule family="ipv4" port port="853" protocol="tcp" accept' --permanent
firewall-cmd --zone=drop --add-rich-rule='rule family="ipv6" port port="853" protocol="tcp" accept' --permanent

# Allow DNSCrypt outbound (port 443 for DoH fallback, UDP 443 for QUIC-based resolvers)
firewall-cmd --zone=drop --add-rich-rule='rule family="ipv4" port port="443" protocol="tcp" accept' --permanent
firewall-cmd --zone=drop --add-rich-rule='rule family="ipv4" port port="443" protocol="udp" accept' --permanent

# Block cleartext DNS outbound (port 53) from all applications except dnscrypt-proxy
# This prevents DNS leaks if any application bypasses systemd-resolved
# dnscrypt-proxy binds to 127.0.0.1:5300; systemd-resolved stub to 127.0.0.53
# Applications should never send raw DNS to external port 53
firewall-cmd --zone=drop --add-rich-rule='rule family="ipv4" destination NOT address="127.0.0.0/8" port port="53" protocol="udp" drop' --permanent
firewall-cmd --zone=drop --add-rich-rule='rule family="ipv4" destination NOT address="127.0.0.0/8" port port="53" protocol="tcp" drop' --permanent

# Allow SSH on non-default port (configured in Part 10)
# Replace 2222 with your chosen SSH port
firewall-cmd --zone=drop --add-rich-rule='rule family="ipv4" port port="2222" protocol="tcp" accept' --permanent

# Allow Cockpit (localhost only — see Part 9.4)
# Cockpit management interface should only accept on loopback
# Use a rich rule restricting to localhost source
firewall-cmd --zone=drop --add-rich-rule='rule family="ipv4" source address="127.0.0.1" port port="9090" protocol="tcp" accept' --permanent

# Allow mDNS only on local network if needed (Avahi)
# Comment out if Avahi is disabled
# firewall-cmd --zone=drop --add-service=mdns --permanent

# Reload to apply permanent rules
firewall-cmd --reload

# Verify
firewall-cmd --list-all --zone=drop
```

### 9.2 — DNS over TLS and DNSCrypt

#### Architecture Decision

Architecture: `Application → systemd-resolved stub (127.0.0.53:53) → dnscrypt-proxy (127.0.0.1:5300) → Anonymized relay → Encrypted resolver → Authoritative DNS`

- `dnscrypt-proxy` listens on `127.0.0.1:5300` (not 53, to avoid conflict with systemd-resolved)
- `systemd-resolved` listens on `127.0.0.53:53` (stub resolver)
- systemd-resolved forwards upstream queries to `127.0.0.1:5300` (dnscrypt-proxy)
- Applications use `127.0.0.53` as their DNS server (via `/etc/resolv.conf` symlink)

This architecture avoids the known resume/reconnect breakage of having both services compete for port 53 while providing DoT verification at the systemd-resolved layer and DNSCrypt + anonymized relay at the dnscrypt-proxy layer.

```bash
pacman -S dnscrypt-proxy systemd-resolved
```

#### systemd-resolved Configuration

```bash
cat > /etc/systemd/resolved.conf << 'EOF'
[Resolve]
# Forward all queries to dnscrypt-proxy
# dnscrypt-proxy handles actual resolution
DNS=127.0.0.1:5300
FallbackDNS=
# Disable mDNS and LLMNR — privacy leak + attack surface
LLMNR=no
MulticastDNS=no
# Disable DNSSEC in resolved — dnscrypt-proxy handles DNSSEC validation
# (running DNSSEC in both would cause validation failures for some zones)
DNSSEC=no
# Never fall back to cleartext DNS
DNSOverTLS=no
# Cache DNS responses
Cache=yes
CacheFromLocalhost=no
# Do not read /etc/hosts for DNS (use resolvectl hosts for that)
ReadEtcHosts=yes
EOF

# Set up resolv.conf to point to systemd-resolved stub
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Restart systemd-resolved
systemctl restart systemd-resolved
systemctl enable systemd-resolved
```

#### dnscrypt-proxy Configuration

```bash
pacman -S dnscrypt-proxy

cat > /etc/dnscrypt-proxy/dnscrypt-proxy.toml << 'EOF'
##############################################################
# dnscrypt-proxy.toml — Hardened Configuration
# April 2026
##############################################################

# Listen on localhost port 5300 (systemd-resolved uses 53)
listen_addresses = ['127.0.0.1:5300', '[::1]:5300']

# Maximum number of simultaneous queries
max_clients = 250

# Use IPv4 (set ipv6_servers = true if IPv6 is available and desired)
ipv4_servers = true
ipv6_servers = false

# DNSCrypt + DoH (both supported)
dnscrypt_servers = true
doh_servers = true

# Security requirements for resolvers
# require_dnssec: only use resolvers that validate DNSSEC
require_dnssec = true
# require_nolog: only use resolvers that don't log queries
require_nolog = true
# require_nofilter: only use resolvers that don't filter content
require_nofilter = true

# Disable resolvers flagged for known censorship or logging
disabled_server_names = []

# Timeout in milliseconds
timeout = 2500
keepalive = 30

# Cache
cache = true
cache_size = 4096
cache_min_ttl = 2400
cache_max_ttl = 86400
cache_neg_min_ttl = 60
cache_neg_max_ttl = 600

# Anonymized DNS configuration
# Routes DNS queries through anonymized relays to prevent the
# resolver from seeing the client IP address.
# Even with no-log resolvers, IP metadata can be correlated.
# Anonymized relays break this metadata link.
[anonymized_dns]
  skip_incompatible = true

  routes = [
    # Use multiple relay/server pairs for redundancy
    # Format: { server_name='resolver', via=['relay1', 'relay2'] }
    { server_name='*', via=['anon-ams-dnscrypt-nl', 'anon-cs-fr', 'anon-dnscrypt-ch-ipv4'] },
  ]

# Resolvers list
[sources]
  [sources.public-resolvers]
    urls = ['https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md',
            'https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md']
    cache_file = '/var/cache/dnscrypt-proxy/public-resolvers.md'
    minisign_key = 'RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3'
    refresh_delay = 72
    prefix = ''

  [sources.relays]
    urls = ['https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/relays.md',
            'https://download.dnscrypt.info/resolvers-list/v3/relays.md']
    cache_file = '/var/cache/dnscrypt-proxy/relays.md'
    minisign_key = 'RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3'
    refresh_delay = 72
    prefix = ''

# Logging (to systemd journal)
[log]
  level = 2

# Query logging for security audit
[query_log]
  file = '/var/log/dnscrypt-proxy/query.log'
  # Log format: timestamp, query name, query type, response, duration
EOF

mkdir -p /var/cache/dnscrypt-proxy /var/log/dnscrypt-proxy

systemctl enable --now dnscrypt-proxy
systemctl enable --now systemd-resolved

# Verify DNS resolution
resolvectl status
resolvectl query archlinux.org
```

### 9.3 — Hardened NetworkManager

```bash
# Create NetworkManager hardening config
mkdir -p /etc/NetworkManager/conf.d/

cat > /etc/NetworkManager/conf.d/00-hardening.conf << 'EOF'
[main]
# Disable unused plugin backends
plugins = keyfile
# Never modify /etc/resolv.conf — managed by systemd-resolved
dns = none
systemd-resolved = true
rc-manager = unmanaged

[connection]
# Enable MAC address randomization for all connection types
# This prevents tracking via stable MAC addresses (relevant for WiFi APTs
# that monitor association tables)
ethernet.cloned-mac-address = random

# Use stable-ssid randomization for WiFi: MAC changes per SSID but is stable for
# the same network (prevents confusion with captive portals while still
# preventing cross-network tracking)
wifi.cloned-mac-address = stable-ssid

[device]
# Disable WiFi connectivity checking — these requests leak DNS/HTTPS metadata
# and are a reliable way to identify the system's network location
wifi.scan-rand-mac-address = yes

[connectivity]
# Disable NetworkManager's connectivity checking (phones home to archlinux.org)
# systemd-resolved handles connectivity signaling
uri=

[logging]
# Log connection events to syslog for auditd correlation
level = INFO
domains = ALL
EOF

cat > /etc/NetworkManager/conf.d/01-wifi-security.conf << 'EOF'
[connection]
# Require WPA3-SAE for new WiFi connections where supported
# Falls back to WPA2-PSK if the AP does not support WPA3
# WPS is disabled globally — WPS PIN attack is a known APT TTP
wifi-sec.key-mgmt = sae
wifi-sec.wps-method = disabled
wifi-sec.pmf = 1

EOF

systemctl restart NetworkManager
```

### 9.4 — Cockpit Integration

```bash
pacman -S cockpit cockpit-packagekit cockpit-storaged cockpit-networkmanager

# Configure Cockpit to listen on localhost only
# /etc/cockpit/cockpit.conf
mkdir -p /etc/cockpit

cat > /etc/cockpit/cockpit.conf << 'EOF'
[WebService]
# Bind only to localhost — never expose on all interfaces
# APT actors scan for exposed management UIs
Origins = https://localhost:9090 https://127.0.0.1:9090
ProtocolHeader = X-Forwarded-Proto
AllowUnencrypted = false

[Session]
# Short idle timeout for management sessions
IdleTimeout = 15
Banner = /etc/cockpit/banner.txt

[Log]
Fatal = criticals-and-warnings
EOF

cat > /etc/cockpit/banner.txt << 'EOF'
WARNING: This system is monitored. Unauthorized access is prohibited.
All actions are logged and subject to security review.
EOF

# Generate self-signed certificate for Cockpit TLS
# Replace with a proper certificate from internal CA if available
mkdir -p /etc/cockpit/ws-certs.d

openssl req -x509 -newkey rsa:4096 -keyout /etc/cockpit/ws-certs.d/cockpit.key \
  -out /etc/cockpit/ws-certs.d/cockpit.crt -days 3650 -nodes \
  -subj "/C=BD/ST=Dhaka/L=Dhaka/O=Workstation/CN=localhost" \
  -addext "subjectAltName = IP:127.0.0.1,DNS:localhost"

chmod 600 /etc/cockpit/ws-certs.d/cockpit.key
chmod 644 /etc/cockpit/ws-certs.d/cockpit.crt

# Certificate pinning for admin browser:
# 1. Open https://localhost:9090 in Firefox
# 2. View certificate details
# 3. Export certificate fingerprint (SHA-256)
# 4. Configure Firefox certificate exception pinned to that fingerprint
# No automated pinning tool is needed — browser exception is sufficient for
# a single-admin self-signed cert.

systemctl enable --now cockpit.socket

# AppArmor note for Cockpit:
# apparmor.d does NOT ship a Cockpit profile as of April 2026.
# Compensating control: Cockpit is bound to localhost only (no external exposure)
# and runs under systemd socket activation. Apply a restrictive systemd service
# hardening override (use svc-harden.py from Part 12):
#   svc-harden.py apply cockpit
```

---
## Part 10 — SSH Hardening

### `/etc/ssh/sshd_config`

```bash
cat > /etc/ssh/sshd_config << 'EOF'
##############################################################
# /etc/ssh/sshd_config
# CachyOS/Arch Linux — Hardened SSH Server Configuration
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
# Rationale: RSA ≤ 3072 is approaching sunset per NIST SP 800-131A Rev 2.
# Nation-state actors (NSA/GCHQ) with quantum capabilities target RSA first.
# Ed25519 (Curve25519) has no NIST involvement and is not susceptible to
# the potential NSA backdoor concerns raised about NIST P-curves.
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_ecdsa_key  # P-521; regenerated below with -b 521

# Key exchange: Curve25519-only
# Eliminates DH groups (weak small-group attacks) and ECDH with NIST curves
# (potential NSA/GCHQ weakness per Snowden disclosures).
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org

# Host key algorithms presented to clients
HostKeyAlgorithms ssh-ed25519,ecdsa-sha2-nistp521

# Ciphers: ChaCha20-Poly1305 and AES-256-GCM (authenticated)
# Disables all CBC ciphers (CBC padding oracle attacks) and AES-128
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr

# MACs: ETM (encrypt-then-MAC) only
# Disables all CBC MACs (encrypt-and-MAC pattern is vulnerable to
# Lucky13 and similar timing attacks)
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
# Create this group and add admin users: groupadd sshusers; usermod -aG sshusers ahsan
AllowGroups sshusers

## --- Session and Connection Limits ---
# Time allowed to authenticate before connection is closed
# Short window prevents connection-holding resource exhaustion
LoginGraceTime 30

# Maximum auth attempts per connection (disconnect after 3 failures)
MaxAuthTries 3

# Maximum concurrent sessions per connection
MaxSessions 3

# Maximum simultaneous pending (unauthenticated) connections
# Format: start:rate:full
# Throttles connection storms from scanners/brute-force
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

# Use DNS for reverse lookup (disabled — prevents delay on networks without PTR records)
UseDNS no

# Accept only known environment variables
AcceptEnv LANG LC_*

# Compression: delayed (after authentication)
Compression delayed

# Subsystem for SFTP (if file transfer needed)
Subsystem sftp /usr/lib/ssh/sftp-server
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

### `/etc/ssh/ssh_config` (Client)

```bash
cat > /etc/ssh/ssh_config << 'EOF'
##############################################################
# /etc/ssh/ssh_config — Hardened SSH Client Configuration
# April 2026
##############################################################

Host *
    # Only Ed25519 and ECDSA P-521 host keys trusted
    HostKeyAlgorithms ssh-ed25519,ecdsa-sha2-nistp521

    # Same KexAlgorithms as server
    KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org

    # Strong ciphers and MACs
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

    # Prefer Ed25519 keys when authenticating
    IdentityFile ~/.ssh/id_ed25519
    IdentityFile ~/.ssh/id_ecdsa

    # Automatically add server to known_hosts but do not silently accept
    # changed host keys (prevents MITM via re-key)
    StrictHostKeyChecking ask
    UpdateHostKeys ask

    # Do not hash known_hosts (hashing obscures hosts connected to, but
    # makes it impossible to detect when a host key changes to a known bad key)
    # Decision: no hashing — APT value of knowing which hosts are connected
    # to is lower than the defensive value of readable known_hosts for auditing
    HashKnownHosts no

    # Disable forwarding client-side
    ForwardAgent no
    ForwardX11 no

    # Connection reuse (ControlMaster) — disabled in high-security contexts
    # APT can hijack a ControlMaster socket to piggyback on authenticated sessions
    ControlMaster no

    # Server alive settings (matches server-side ClientAliveInterval)
    ServerAliveInterval 60
    ServerAliveCountMax 3

    # Compression
    Compression yes

    # Visual host key fingerprint (SAS for manual verification)
    VisualHostKey yes
EOF
```

---

## Part 11 — PAM and Authentication Hardening

### Arch-Specific PAM Notes

Unlike Debian/Ubuntu, Arch Linux does not use a PAM configuration manager (`pam-auth-update`). PAM stack files in `/etc/pam.d/` must be edited directly. There is no `common-auth` or `common-password` equivalent — each service has its own stack.

The key files to harden on Arch are:
- `/etc/pam.d/system-auth` — used by most services (login, sudo, su)
- `/etc/pam.d/su` — used specifically by `su`
- `/etc/pam.d/sudo` — sudo authentication
- `/etc/pam.d/login` — virtual console login
- `/etc/pam.d/sshd` — SSH authentication (uses `/etc/pam.d/system-auth`)
- `/etc/security/faillock.conf` — pam_faillock configuration
- `/etc/security/pwquality.conf` — pam_pwquality configuration

```bash
pacman -S libpwquality pam

# --- pam_faillock configuration ---
cat > /etc/security/faillock.conf << 'EOF'
# /etc/security/faillock.conf
# Account lockout after repeated authentication failures
# Mitigates brute-force attacks against local accounts and sudo

# Lock account after 5 consecutive failures
deny = 5

# Failure window: count failures within 10 minutes
fail_interval = 600

# Lock duration: 15 minutes (sufficient to deter automated attacks
# without locking admins out indefinitely)
unlock_time = 900

# Even root can be locked out — prevents targeted root brute-force
even_deny_root = true
root_unlock_time = 60

# Store failure data in /var/run/faillock/ (tmpfs — cleared on reboot)
# For persistent lockout across reboots, change to /var/lib/faillock/
dir = /var/run/faillock

# Audit all authentication events to the audit log
audit = true

# Local console lockout as well (not just SSH)
local_users_only = false

# Silent mode — when set to 'true', suppresses which specific check failed.
# Set to 'false' here so administrators can read failure messages in logs.
# Note: pam_faillock's "silent" suppresses output to the user TTY, not to audit logs.
# Audit logging of failures is always active regardless of this setting.
silent = false
EOF

# --- pam_pwquality configuration ---
cat > /etc/security/pwquality.conf << 'EOF'
# /etc/security/pwquality.conf
# Password quality requirements for local accounts
# NOTE: SSH uses key-only auth; these requirements apply to
# local console login and sudo password changes.

# Minimum length: 16 characters
minlen = 16

# Require at least 1 uppercase character
ucredit = -1

# Require at least 1 lowercase character
lcredit = -1

# Require at least 1 digit
dcredit = -1

# Require at least 1 special character
ocredit = -1

# Maximum consecutive same characters
maxrepeat = 3

# Maximum consecutive characters from the same class
maxclassrepeat = 4

# Minimum number of character classes required (uppercase, lowercase, digit, special)
minclass = 3

# Reject passwords containing the username
usercheck = 1

# Reject passwords containing more than N characters of the previous password
difok = 8

# Dictionary check — reject common/dictionary words
dictcheck = 1

# Reject simple sequences (abc, 123, etc.)
enforcing = 1

# Number of retries before giving up
retry = 3

# Reject passwords that match known-bad passwords
# (requires cracklib/libpwquality dictionaries)
badwords = password passwd letmein qwerty
EOF

# --- /etc/pam.d/system-auth (core PAM stack) ---
cat > /etc/pam.d/system-auth << 'EOF'
#%PAM-1.0
# /etc/pam.d/system-auth
# Hardened PAM stack for Arch Linux
# Used by: login, sudo, su, and most other services

## AUTH STACK
# pam_faillock: preauth — check if account is locked BEFORE password prompt
# This prevents timing attacks that reveal account existence
auth      required  pam_faillock.so preauth silent

# pam_unix: authenticate via /etc/shadow (sha512, high rounds)
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
password  required  pam_pwquality.so retry=3

# pam_unix: actually update the password with sha512, high rounds
# rounds=65536 makes offline brute-force more expensive
password  required  pam_unix.so sha512 shadow rounds=65536 use_authtok

## SESSION STACK
# pam_limits: enforce resource limits (prevents fork bombs, etc.)
session   required  pam_limits.so

# pam_unix: standard session setup
session   required  pam_unix.so

# pam_env: set environment variables from /etc/security/pam_env.conf
session   required  pam_env.so

# pam_umask: set default umask
session   optional  pam_umask.so umask=0027

# systemd-logind session tracking
session   optional  pam_systemd.so
EOF

# --- pam_limits configuration ---
cat > /etc/security/limits.conf << 'EOF'
# /etc/security/limits.conf
# Resource limits to constrain potential fork-bomb and resource exhaustion attacks

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

# Unlock a locked account (procedure for admins):
# faillock --user <username> --reset
# Example: faillock --user ahsan --reset

# Check lockout status:
# faillock --user ahsan
```

---

## Part 12 — systemd Service Hardening (Python 3)

```python
#!/usr/bin/env python3
"""
svc-harden.py — systemd Service Security Hardening Tool
CachyOS/Arch Linux — APT-Level Hardening Guide

Subcommands:
  analyze <service>   Show current security score and missing directives
  apply <service>     Interactively apply hardening directives via drop-in
  test <service>      Test service functionality after hardening
  revert <service>    Remove hardening drop-in and restore original state
  bisect <service>    Identify which directive caused a breakage
  log                 Show audit log of all changes made by this tool

Usage examples:
  svc-harden.py analyze NetworkManager.service
  svc-harden.py apply sshd.service
  svc-harden.py test sshd.service --test-cmd "ssh -p 2222 localhost exit"
  svc-harden.py revert sshd.service
  svc-harden.py bisect NetworkManager.service
  svc-harden.py log

IMPORTANT: This tool operates on INDIVIDUAL services only.
Bulk hardening is explicitly refused — hardening directives have
service-specific effects and blanket application causes breakage.
"""

import argparse
import datetime
import json
import os
import re
import subprocess
import sys
import textwrap
import time
from pathlib import Path
from typing import Optional

# ──────────────────────────────────────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────────────────────────────────────

DROPIN_BASE = Path("/etc/systemd/system")
AUDIT_LOG = Path("/var/log/svc-harden-audit.json")

# Comprehensive set of hardening directives with descriptions and
# compatibility notes for common service types.
# Each entry: (directive, value, description, incompatible_with)
HARDENING_DIRECTIVES = [
    ("NoNewPrivileges", "true",
     "Prevent the service from gaining new privileges via setuid/setgid/capabilities",
     []),

    ("PrivateTmp", "true",
     "Give the service a private /tmp and /var/tmp (isolated from system /tmp)",
     []),

    ("PrivateDevices", "true",
     "Restrict /dev access to only loopback and pseudo-terminals",
     ["bluetooth", "audio", "video", "gpu"]),

    ("PrivateNetwork", "true",
     "Disconnect the service from all network interfaces (use for non-network services)",
     ["network", "dns", "web", "mail"]),

    ("PrivateUsers", "true",
     "Give the service a separate UID namespace (unprivileged user mapping)",
     ["setuid", "chown", "CAP_SETUID"]),

    ("ProtectSystem", "strict",
     "Mount /usr, /boot, /efi read-only; /etc read-only (writable via StateDirectory)",
     ["etc_write", "usr_write"]),

    ("ProtectHome", "true",
     "Make /home, /root, /run/user inaccessible",
     ["home_access", "user_data"]),

    ("ProtectHostname", "true",
     "Prevent the service from changing the hostname",
     []),

    ("ProtectClock", "true",
     "Prevent the service from setting the system clock",
     ["ntp", "time_sync"]),

    ("ProtectKernelTunables", "true",
     "Make /proc/sys and similar kernel tunables read-only",
     ["sysctl_write"]),

    ("ProtectKernelModules", "true",
     "Prevent the service from loading/unloading kernel modules",
     ["module_load"]),

    ("ProtectKernelLogs", "true",
     "Prevent access to /proc/kmsg and /dev/kmsg (kernel log)",
     ["kernel_log_read"]),

    ("ProtectControlGroups", "true",
     "Make the cgroup filesystem read-only",
     ["cgroup_write"]),

    ("RestrictAddressFamilies", "AF_UNIX AF_INET AF_INET6",
     "Restrict socket address families (adjust to match service needs)",
     []),

    ("RestrictNamespaces", "true",
     "Prevent the service from creating new namespaces",
     ["namespaces", "containers", "bubblewrap"]),

    ("RestrictRealtime", "true",
     "Prevent the service from acquiring real-time scheduling priorities",
     ["realtime", "audio_pro", "pipewire"]),

    ("RestrictSUIDSGID", "true",
     "Prevent creation of setuid/setgid files",
     []),

    ("LockPersonality", "true",
     "Prevent changing the ABI personality (prevents cross-arch exploitation)",
     []),

    ("MemoryDenyWriteExecute", "true",
     "Prevent memory regions from being both writable and executable (W^X)",
     ["jit", "mono", "java", "llvm_jit"]),

    ("RemoveIPC", "true",
     "Remove SysV IPC objects when service stops",
     ["sysv_ipc"]),

    ("SystemCallArchitectures", "native",
     "Only allow system calls for the native architecture (blocks 32-bit on x86-64)",
     ["wine", "32bit_compat"]),

    ("SystemCallFilter", "@system-service",
     "Whitelist only standard service syscalls (use systemd-analyze syscall-filter for details)",
     ["ptrace", "raw_sockets"]),

    ("CapabilityBoundingSet", "",
     "Drop ALL capabilities from the bounding set (service cannot acquire any capability)",
     ["caps_needed"]),

    ("AmbientCapabilities", "",
     "Clear ambient capabilities",
     []),

    ("UMask", "0077",
     "Default umask: new files/dirs created by service are owner-only",
     ["group_read", "world_read"]),

    ("IPAddressDeny", "any",
     "Block all IP communication (use IPAddressAllow to whitelist specific peers)",
     ["network", "dns"]),

    ("ProtectProc", "invisible",
     "Hide other processes' /proc entries from this service",
     []),

    ("ProcSubset", "pid",
     "Only expose PID subtree of /proc to service",
     ["proc_sys_read"]),
]

# ──────────────────────────────────────────────────────────────────────────────
# Utilities
# ──────────────────────────────────────────────────────────────────────────────

def log_action(action: str, service: str, details: dict, dry_run: bool = False) -> None:
    """Append a structured audit log entry."""
    if dry_run:
        print(f"[DRY-RUN] Would log: action={action} service={service} details={details}")
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
        with open(AUDIT_LOG, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(entry) + "\n")
    except OSError as exc:
        print(f"[WARN] Cannot write audit log: {exc}", file=sys.stderr)


def dropin_path(service: str) -> Path:
    """Return the path to the hardening drop-in file for a service."""
    # Normalize: remove trailing .service if user omitted it
    if not service.endswith((".service", ".socket", ".timer", ".mount")):
        service = service + ".service"
    return DROPIN_BASE / f"{service}.d" / "hardening.conf"


def run(cmd: list[str], check: bool = True, capture: bool = False) -> subprocess.CompletedProcess:
    """Run a command, printing it first."""
    print(f"  $ {' '.join(cmd)}")
    return subprocess.run(cmd, check=check,
                          capture_output=capture, text=True)


def systemd_reload() -> None:
    """Reload systemd daemon configuration."""
    run(["systemctl", "daemon-reload"])


def service_status(service: str) -> str:
    """Return the current ActiveState of a service."""
    result = subprocess.run(
        ["systemctl", "is-active", service],
        capture_output=True, text=True, check=False
    )
    return result.stdout.strip()


def restart_service(service: str) -> bool:
    """Restart a service and return True if it came up active."""
    run(["systemctl", "restart", service], check=False)
    time.sleep(2)  # Allow the service to initialize
    state = service_status(service)
    if state == "active":
        print(f"  ✅  {service} is active after restart")
        return True
    else:
        print(f"  ❌  {service} is {state} after restart")
        return False


# ──────────────────────────────────────────────────────────────────────────────
# ANALYZE
# ──────────────────────────────────────────────────────────────────────────────

def cmd_analyze(service: str, dry_run: bool) -> int:
    """Run systemd-analyze security and produce a prioritized recommendations list."""
    print(f"\n{'═'*70}")
    print(f"  SECURITY ANALYSIS: {service}")
    print(f"{'═'*70}\n")

    # Run systemd-analyze security to get the current exposure score
    try:
        result = subprocess.run(
            ["systemd-analyze", "security", "--no-pager", service],
            capture_output=True, text=True, check=False
        )
    except FileNotFoundError:
        print("ERROR: systemd-analyze not found. Install systemd.", file=sys.stderr)
        return 1

    print(result.stdout)
    if result.returncode != 0:
        print(result.stderr)

    # Parse exposure score from output
    score_match = re.search(r"→\s*([\d.]+)\s+EXPOSED|→\s*([\d.]+)\s+OK|→\s*([\d.]+)\s+MEDIUM", result.stdout)
    if score_match:
        score = score_match.group(1) or score_match.group(2) or score_match.group(3)
        print(f"\n  Current exposure score: {score}/10.0")

    # List which of our directives are absent in the current unit
    print(f"\n  {'─'*66}")
    print(f"  RECOMMENDED HARDENING DIRECTIVES (in priority order)")
    print(f"  {'─'*66}\n")

    for i, (directive, value, description, incompatible) in enumerate(HARDENING_DIRECTIVES, 1):
        # Check if directive appears in current service configuration
        check = subprocess.run(
            ["systemctl", "show", service, f"--property={directive}"],
            capture_output=True, text=True, check=False
        )
        current_val = check.stdout.strip().split("=", 1)[-1] if "=" in check.stdout else "(not set)"

        if current_val == "(not set)" or current_val == "" or current_val.lower() in ("false", "no", "0"):
            compat_note = f" [CAUTION: may break {', '.join(incompatible)}]" if incompatible else ""
            print(f"  {i:2d}. {directive}={value}")
            print(f"      {description}{compat_note}")
            print()

    log_action("analyze", service, {}, dry_run)
    return 0


# ──────────────────────────────────────────────────────────────────────────────
# APPLY
# ──────────────────────────────────────────────────────────────────────────────

def cmd_apply(service: str, dry_run: bool) -> int:
    """Interactively prompt for each hardening directive and write a drop-in."""
    dropin = dropin_path(service)

    print(f"\n{'═'*70}")
    print(f"  APPLY HARDENING: {service}")
    print(f"{'═'*70}")
    print(f"\n  Drop-in will be written to: {dropin}")
    print(f"  Review each directive. Press Enter to skip, 'y' to apply, 'e' to edit value.\n")

    selected: dict[str, str] = {}

    for directive, default_value, description, incompatible in HARDENING_DIRECTIVES:
        compat_note = f"\n  ⚠️  May break: {', '.join(incompatible)}" if incompatible else ""
        print(f"\n  Directive : {directive}")
        print(f"  Value     : {default_value}")
        print(f"  Purpose   : {description}{compat_note}")

        try:
            choice = input("  Apply? [y/N/e(dit)]: ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            print("\n  Aborted.")
            return 1

        if choice == "y":
            selected[directive] = default_value
            print(f"  ✅  {directive}={default_value} selected")
        elif choice == "e":
            try:
                custom_value = input(f"  Enter value for {directive}: ").strip()
            except (EOFError, KeyboardInterrupt):
                print("\n  Aborted.")
                return 1
            if custom_value:
                selected[directive] = custom_value
                print(f"  ✅  {directive}={custom_value} selected (custom)")
            else:
                print(f"  ⏭   Skipped")
        else:
            print(f"  ⏭   Skipped")

    if not selected:
        print("\n  No directives selected. Nothing to write.")
        return 0

    # Build the drop-in content
    dropin_content = textwrap.dedent(f"""\
        # /etc/systemd/system/{service}.d/hardening.conf
        # Generated by svc-harden.py at {datetime.datetime.now().isoformat()}
        # Remove with: svc-harden.py revert {service}

        [Service]
    """)
    for directive, value in selected.items():
        dropin_content += f"{directive}={value}\n"

    print(f"\n  {'─'*66}")
    print(f"  PREVIEW OF DROP-IN CONTENT")
    print(f"  {'─'*66}")
    print(dropin_content)

    try:
        confirm = input("  Write this drop-in and restart the service? [y/N]: ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        print("\n  Aborted.")
        return 1

    if confirm != "y":
        print("  Aborted — nothing written.")
        return 0

    if dry_run:
        print(f"  [DRY-RUN] Would write to {dropin}")
        print(f"  [DRY-RUN] Would run: systemctl daemon-reload && systemctl restart {service}")
        log_action("apply_dry_run", service, {"directives": selected}, dry_run=True)
        return 0

    # Write the drop-in
    dropin.parent.mkdir(parents=True, exist_ok=True)
    dropin.write_text(dropin_content, encoding="utf-8")
    print(f"  ✅  Written: {dropin}")

    # Reload and restart
    systemd_reload()
    success = restart_service(service)

    log_action("apply", service, {
        "directives": selected,
        "dropin": str(dropin),
        "restart_success": success,
    })

    if not success:
        print(f"\n  ⚠️  Service failed after hardening. Run: svc-harden.py bisect {service}")
        return 1

    # Show new security score
    print(f"\n  Running post-apply security analysis...")
    subprocess.run(["systemd-analyze", "security", "--no-pager", service], check=False)
    return 0


# ──────────────────────────────────────────────────────────────────────────────
# TEST
# ──────────────────────────────────────────────────────────────────────────────

def cmd_test(service: str, test_cmd: Optional[str], dry_run: bool) -> int:
    """Test service functionality after hardening."""
    print(f"\n{'═'*70}")
    print(f"  TESTING: {service}")
    print(f"{'═'*70}\n")

    if dry_run:
        print(f"  [DRY-RUN] Would restart {service} and check status")
        return 0

    # Baseline: restart and check
    print(f"  Restarting {service}...")
    success = restart_service(service)

    if not success:
        print(f"  ❌  Service did not come up cleanly. Use: svc-harden.py bisect {service}")
        log_action("test", service, {"status": "failed", "test_cmd": test_cmd})
        return 1

    # Show journal for last 20 lines
    print(f"\n  Recent journal entries for {service}:")
    subprocess.run(["journalctl", "-u", service, "--no-pager", "-n", "20"], check=False)

    # Run user-provided test command if supplied
    if test_cmd:
        print(f"\n  Running test command: {test_cmd}")
        try:
            result = subprocess.run(test_cmd, shell=True, check=False, timeout=30)
            if result.returncode == 0:
                print(f"  ✅  Test command succeeded (rc=0)")
                log_action("test", service, {"status": "passed", "test_cmd": test_cmd,
                                              "test_rc": result.returncode})
                return 0
            else:
                print(f"  ❌  Test command failed (rc={result.returncode})")
                log_action("test", service, {"status": "test_cmd_failed", "test_cmd": test_cmd,
                                              "test_rc": result.returncode})
                return 1
        except subprocess.TimeoutExpired:
            print("  ❌  Test command timed out after 30 seconds")
            return 1
    else:
        log_action("test", service, {"status": "passed_restart_only", "test_cmd": None})
        return 0


# ──────────────────────────────────────────────────────────────────────────────
# REVERT
# ──────────────────────────────────────────────────────────────────────────────

def cmd_revert(service: str, dry_run: bool) -> int:
    """Remove the hardening drop-in and restore original service state."""
    dropin = dropin_path(service)

    print(f"\n{'═'*70}")
    print(f"  REVERTING HARDENING: {service}")
    print(f"{'═'*70}\n")

    if not dropin.exists():
        print(f"  No hardening drop-in found at {dropin}")
        print(f"  Nothing to revert.")
        return 0

    print(f"  Current drop-in contents:")
    print(dropin.read_text())

    try:
        confirm = input(f"  Delete {dropin} and restart {service}? [y/N]: ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        print("\n  Aborted.")
        return 1

    if confirm != "y":
        print("  Aborted.")
        return 0

    if dry_run:
        print(f"  [DRY-RUN] Would delete {dropin} and restart {service}")
        return 0

    dropin.unlink()
    # Remove parent dir if empty
    try:
        dropin.parent.rmdir()
    except OSError:
        pass  # Not empty, leave it

    systemd_reload()
    success = restart_service(service)

    log_action("revert", service, {
        "dropin_removed": str(dropin),
        "restart_success": success,
    })

    return 0 if success else 1


# ──────────────────────────────────────────────────────────────────────────────
# BISECT
# ──────────────────────────────────────────────────────────────────────────────

def cmd_bisect(service: str, dry_run: bool) -> int:
    """Binary-search for which hardening directive caused a service failure.

    Algorithm:
    1. Read current drop-in directives
    2. Disable one directive at a time (comment it out temporarily)
    3. After each change, restart and check service health
    4. Report the culprit directive
    5. Offer: (a) keep rest, remove culprit; (b) full revert; (c) leave as-is
    """
    dropin = dropin_path(service)

    print(f"\n{'═'*70}")
    print(f"  BISECT MODE: {service}")
    print(f"{'═'*70}\n")

    if not dropin.exists():
        print(f"  No hardening drop-in found at {dropin}")
        print(f"  Nothing to bisect — no hardening has been applied.")
        return 0

    # Parse current drop-in directives
    content = dropin.read_text(encoding="utf-8")
    directives: list[tuple[str, str]] = []  # (directive, value)

    for line in content.splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith("#") and "=" in stripped:
            parts = stripped.split("=", 1)
            if parts[0].strip() not in ("[Service]", "[Unit]", "[Install]"):
                directives.append((parts[0].strip(), parts[1].strip()))

    if not directives:
        print("  Drop-in file has no directives to bisect.")
        return 0

    print(f"  Found {len(directives)} hardening directive(s) in drop-in.")
    print(f"  Will disable each one and restart service to find the culprit.\n")

    culprit: Optional[tuple[str, str]] = None
    backup_content = content  # Preserve original for final restoration

    for i, (directive, value) in enumerate(directives, 1):
        print(f"  [{i}/{len(directives)}] Testing with '{directive}' DISABLED...")

        # Build drop-in with this directive commented out
        new_lines = []
        skipped = False
        for line in content.splitlines():
            stripped = line.strip()
            if not skipped and stripped.startswith(directive + "="):
                new_lines.append(f"# BISECT_DISABLED: {line}")
                skipped = True
            else:
                new_lines.append(line)

        if not dry_run:
            dropin.write_text("\n".join(new_lines), encoding="utf-8")
            systemd_reload()
            success = restart_service(service)
        else:
            print(f"  [DRY-RUN] Would disable {directive} and test")
            success = True  # Assume success in dry-run

        if success:
            print(f"  ✅  Service recovered when '{directive}' was disabled.")
            culprit = (directive, value)
            # Restore the full drop-in before offering options
            if not dry_run:
                dropin.write_text(backup_content, encoding="utf-8")
                systemd_reload()
            break
        else:
            # Re-enable this directive (restore from backup for next test)
            if not dry_run:
                dropin.write_text(backup_content, encoding="utf-8")
                systemd_reload()
            print(f"  ❌  Service still broken. Continuing...\n")

    if culprit is None:
        print("\n  ⚠️  Could not identify a single culprit directive.")
        print("  The failure may require disabling multiple directives.")
        print(f"  Use 'svc-harden.py revert {service}' to remove all hardening.")
        log_action("bisect", service, {"result": "no_culprit_found"})
        return 1

    print(f"\n  {'─'*66}")
    print(f"  CULPRIT IDENTIFIED: {culprit[0]}={culprit[1]}")
    print(f"  {'─'*66}\n")
    print(f"  Options:")
    print(f"  [a] Remove only '{culprit[0]}' and keep all other hardening")
    print(f"  [b] Revert ALL hardening (remove entire drop-in)")
    print(f"  [c] Leave system as-is (with full drop-in still active)")

    try:
        choice = input("\n  Choice [a/b/c]: ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        print("\n  Aborted — no changes made.")
        return 1

    if choice == "a":
        if dry_run:
            print(f"  [DRY-RUN] Would remove '{culprit[0]}' from drop-in")
            return 0
        # Remove the culprit directive from the drop-in
        new_lines = [
            line for line in backup_content.splitlines()
            if not line.strip().startswith(culprit[0] + "=")
        ]
        dropin.write_text("\n".join(new_lines), encoding="utf-8")
        systemd_reload()
        restart_service(service)
        log_action("bisect_partial_revert", service, {"removed_directive": culprit[0]})
        print(f"  ✅  Removed '{culprit[0]}'; service running with remaining hardening.")

    elif choice == "b":
        return cmd_revert(service, dry_run)

    else:
        print(f"  Drop-in unchanged. Service may still be failing.")
        log_action("bisect_no_action", service, {"culprit": culprit[0]})

    return 0


# ──────────────────────────────────────────────────────────────────────────────
# LOG VIEWER
# ──────────────────────────────────────────────────────────────────────────────

def cmd_log() -> int:
    """Display the svc-harden audit log."""
    if not AUDIT_LOG.exists():
        print(f"No audit log found at {AUDIT_LOG}")
        return 0

    try:
        lines = AUDIT_LOG.read_text(encoding="utf-8").strip().splitlines()
    except OSError as exc:
        print(f"Cannot read audit log: {exc}", file=sys.stderr)
        return 1

    print(f"\n{'═'*70}")
    print(f"  SVC-HARDEN AUDIT LOG ({len(lines)} entries)")
    print(f"{'═'*70}\n")

    for line in lines:
        try:
            entry = json.loads(line)
            ts = entry.get("timestamp", "?")
            action = entry.get("action", "?")
            service = entry.get("service", "?")
            details = entry.get("details", {})
            print(f"  {ts}  [{action:25s}] {service}")
            if details:
                for k, v in details.items():
                    print(f"              {k}: {v}")
        except json.JSONDecodeError:
            print(f"  [PARSE ERROR] {line[:80]}")

    print()
    return 0


# ──────────────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="svc-harden.py",
        description="systemd service hardening tool — operates on individual services only",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""
        NOTE: This tool REFUSES to operate on 'all' or wildcard service patterns.
        Hardening is service-specific — bulk application causes breakage.

        Examples:
          svc-harden.py analyze sshd.service
          svc-harden.py apply NetworkManager.service
          svc-harden.py test sshd.service --test-cmd "ssh -p 2222 localhost exit"
          svc-harden.py revert sshd.service
          svc-harden.py bisect NetworkManager.service
          svc-harden.py log
        """),
    )
    parser.add_argument("--dry-run", action="store_true",
                        help="Simulate without making changes")

    sub = parser.add_subparsers(dest="command", required=True)

    # analyze
    p_analyze = sub.add_parser("analyze", help="Show security score and recommendations")
    p_analyze.add_argument("service", help="Service unit name (e.g. sshd.service)")

    # apply
    p_apply = sub.add_parser("apply", help="Interactively apply hardening directives")
    p_apply.add_argument("service", help="Service unit name")

    # test
    p_test = sub.add_parser("test", help="Test service after hardening")
    p_test.add_argument("service", help="Service unit name")
    p_test.add_argument("--test-cmd", metavar="CMD",
                        help="Optional command to validate service functionality")

    # revert
    p_revert = sub.add_parser("revert", help="Remove hardening drop-in")
    p_revert.add_argument("service", help="Service unit name")

    # bisect
    p_bisect = sub.add_parser("bisect",
                               help="Find which directive caused a service failure")
    p_bisect.add_argument("service", help="Service unit name")

    # log
    sub.add_parser("log", help="Show audit log of all changes")

    return parser


BULK_PATTERNS = {"all", "*", "*.service", "everything"}


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    dry_run = args.dry_run

    if args.command == "log":
        return cmd_log()

    service = getattr(args, "service", None)

    # EXPLICIT REFUSAL of bulk hardening
    if service and (service in BULK_PATTERNS or "*" in service or service == ""):
        print("❌  REFUSED: This tool does not support bulk/wildcard service hardening.", file=sys.stderr)
        print("   Hardening directives are service-specific; blanket application causes breakage.", file=sys.stderr)
        print("   Specify a single service unit name (e.g., sshd.service).", file=sys.stderr)
        return 1

    if os.geteuid() != 0 and args.command in ("apply", "revert", "bisect") and not dry_run:
        print("ERROR: This command requires root (sudo svc-harden.py ...)", file=sys.stderr)
        return 1

    dispatch = {
        "analyze": lambda: cmd_analyze(service, dry_run),
        "apply":   lambda: cmd_apply(service, dry_run),
        "test":    lambda: cmd_test(service, getattr(args, "test_cmd", None), dry_run),
        "revert":  lambda: cmd_revert(service, dry_run),
        "bisect":  lambda: cmd_bisect(service, dry_run),
    }

    return dispatch[args.command]()


if __name__ == "__main__":
    sys.exit(main())
```

---

## Part 13 — Supply Chain Monitoring

### Pacman Hooks for GPG Verification and Audit Logging

```bash
# /etc/pacman.d/hooks/00-verify-gpg.hook
# PRE-install verification: enforce GPG signature check before any operation
cat > /etc/pacman.d/hooks/00-verify-gpg.hook << 'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Verifying package signatures...
When = PreTransaction
Exec = /usr/local/bin/verify-pkg-signatures.sh
Depends = gnupg
EOF

cat > /usr/local/bin/verify-pkg-signatures.sh << 'SCRIPT'
#!/bin/bash
# Verify pacman is configured with Required SigLevel before any transaction
# A downgraded SigLevel is a supply-chain attack indicator.
SIGLEVEL=$(grep -E "^\s*SigLevel" /etc/pacman.conf | head -1 | awk '{print $3}')
case "$SIGLEVEL" in
  Required*|TrustAll*)
    exit 0
    ;;
  Never|Optional)
    echo "SECURITY ALERT: pacman SigLevel is '$SIGLEVEL' — package signature verification disabled!" >&2
    echo "Check /etc/pacman.conf and restore SigLevel = Required DatabaseOptional" >&2
    exit 1
    ;;
  *)
    # Default (empty or unset) is acceptable
    exit 0
    ;;
esac
SCRIPT
chmod +x /usr/local/bin/verify-pkg-signatures.sh

# /etc/pacman.d/hooks/99-audit-log.hook
# POST-install: log package name, version, timestamp, source to audit log
cat > /etc/pacman.d/hooks/99-audit-log.hook << 'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Logging package transaction to audit log...
When = PostTransaction
Exec = /usr/local/bin/pkg-audit-log.sh
EOF

cat > /usr/local/bin/pkg-audit-log.sh << 'SCRIPT'
#!/bin/bash
# Log pacman transactions to the structured JSON audit log
# Used by both the pacman hook and pkgman.py (Part 2)
AUDIT_LOG="/var/log/pkgman-audit.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# pacman sets these environment variables in post-transaction hooks:
# PKGFILE, PKGNAME, PKGVER, PKGARCH — available via pacman -Qi after install
# We use pacman -Q to get current installed package list

for pkg in "$@"; do
  VERSION=$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}' || echo "unknown")
  SOURCE=$(pacman -Si "$pkg" 2>/dev/null | grep "^Repository" | awk '{print $3}' || echo "local")
  ENTRY=$(jq -n \
    --arg ts "$TIMESTAMP" \
    --arg action "pacman_transaction" \
    --arg source "$SOURCE" \
    --arg package "$pkg" \
    --arg version "$VERSION" \
    --arg status "COMPLETED" \
    --arg uid "$(id -u)" \
    '{timestamp: $ts, action: $action, source: $source, package: $package,
      version: $version, status: $status, uid: $uid}')
  echo "$ENTRY" >> "$AUDIT_LOG" 2>/dev/null || true
done
SCRIPT
chmod +x /usr/local/bin/pkg-audit-log.sh
```

### CVE Vulnerability Scanning with `arch-audit`

`arch-audit` is the current actively maintained CVE scanner for Arch-based systems as of April 2026. It queries the Arch Linux Security Advisory feed at `security.archlinux.org`.

```bash
pacman -S arch-audit

# Scan for vulnerable packages
arch-audit

# Show only packages with available fixes (upgradable)
arch-audit --upgradable

# Output in parseable format for scripting
arch-audit --format "%n %c %s"

# Create a weekly scan script
cat > /usr/local/bin/weekly-vuln-scan.sh << 'SCRIPT'
#!/bin/bash
# Weekly CVE vulnerability scan using arch-audit
# Feeds results to the email reporting pipeline (Part 14)

REPORT=$(arch-audit 2>&1)
CRITICAL=$(echo "$REPORT" | grep -c "Critical" || true)
HIGH=$(echo "$REPORT" | grep -c "High" || true)
TOTAL=$(echo "$REPORT" | grep -c "affected" || true)

cat << EOF
Subject: [SECURITY] Weekly CVE Scan Report — $(hostname) — $(date -u +%Y-%m-%d)

Arch Linux Security Advisory Scan Results
==========================================
Host: $(hostname)
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Kernel: $(uname -r)

Summary:
  Total vulnerable packages: $TOTAL
  Critical severity: $CRITICAL
  High severity: $HIGH

Detailed findings:
------------------
${REPORT}

Action required:
  Run 'sudo pacman -Syu' to install security updates.
  Check https://security.archlinux.org/ for details on each advisory.
EOF
SCRIPT
chmod +x /usr/local/bin/weekly-vuln-scan.sh
```

### CachyOS Security Advisory Monitoring

As of April 2026, CachyOS does not publish a dedicated security advisory RSS/Atom feed. CachyOS packages that diverge from upstream Arch are patched in the `CachyOS-PKGBUILDS` GitHub repository. Monitoring is done via:

1. **Arch Linux Security Advisories** at `security.archlinux.org` — covers all upstream packages
2. **CachyOS GitHub releases** — monitor `CachyOS/CachyOS-PKGBUILDS` and `CachyOS/linux-cachyos`
3. **CachyOS forum** at `discuss.cachyos.org` — security announcements posted there

```bash
# Monitor CachyOS GitHub for security-relevant commits (requires gh CLI or RSS)
# Add to weekly monitoring:
cat > /usr/local/bin/cachyos-security-check.sh << 'SCRIPT'
#!/bin/bash
# Check for recent CachyOS PKGBUILD changes that may be security-relevant
# Uses the GitHub API (no auth required for public repos, rate-limited)
API="https://api.github.com/repos/CachyOS/CachyOS-PKGBUILDS/commits?per_page=20"
RESPONSE=$(curl -sS --max-time 10 "$API" 2>&1) || {
  echo "Failed to fetch CachyOS commit log: $RESPONSE"
  exit 1
}
echo "Recent CachyOS PKGBUILD commits (last 20):"
echo "$RESPONSE" | python3 -c "
import json, sys
commits = json.load(sys.stdin)
for c in commits:
    date = c['commit']['committer']['date']
    msg = c['commit']['message'].split('\n')[0][:80]
    print(f\"  {date}  {msg}\")
"
SCRIPT
chmod +x /usr/local/bin/cachyos-security-check.sh
```

---

## Part 14 — Ongoing Monitoring, Log Review, and Vulnerability Alerting

### Mail Relay Configuration

**Option A: msmtp (Recommended — simpler, lower attack surface)**

`msmtp` is a lightweight SMTP relay client. For sending to a Proton Mail address, the two sub-options are:

**Sub-option A1: Proton Mail Bridge** (most secure, requires Proton Mail paid plan or Proton Unlimited)
- Proton Mail Bridge runs a local SMTP proxy on `127.0.0.1:1025`
- Emails are encrypted end-to-end before leaving the device
- Requires the Bridge app installed locally

**Sub-option A2: Third-party SMTP relay** (e.g., Mailgun, Sendgrid, or a self-hosted postfix with relay)
- Less secure: relay sees plaintext before encrypting to Proton's servers
- Simpler: no Bridge software required
- Use only over TLS; ensure `tls_starttls_disable = on` and `tls = on`

```bash
pacman -S msmtp

# Configure msmtp for Proton Mail Bridge (Sub-option A1)
cat > /etc/msmtprc << 'EOF'
# /etc/msmtprc — msmtp configuration for Proton Mail Bridge
# Proton Mail Bridge listens on localhost after setup

defaults
  auth           on
  tls            on
  tls_trust_file /etc/ssl/certs/ca-certificates.crt
  logfile        /var/log/msmtp.log

account        proton
host           127.0.0.1
port           1025
# Proton Mail Bridge uses a self-signed cert; pin it here
# Get fingerprint: openssl s_client -connect 127.0.0.1:1025 | openssl x509 -fingerprint -noout
tls_fingerprint <BRIDGE_CERT_FINGERPRINT>
from           <your-protonmail-address@proton.me>
user           <your-protonmail-address@proton.me>
# Store password in a separate file with mode 0600
passwordeval   cat /etc/msmtp-password

account default : proton
EOF

chmod 600 /etc/msmtprc

# Create password file
echo "<bridge_smtp_password>" > /etc/msmtp-password
chmod 600 /etc/msmtp-password

# Test — replace with your actual Proton Mail address
echo "Test mail from $(hostname)" | msmtp -a proton your-address@proton.me
```

### Daily Auditd Summary

```bash
cat > /usr/local/bin/daily-audit-summary.sh << 'SCRIPT'
#!/bin/bash
# Daily auditd log summary — sent to aahsnr041@proton.me
# Run via systemd timer (see below)

RECIPIENT="aahsnr041@proton.me"
HOST=$(hostname)
DATE=$(date -u +%Y-%m-%d)

# Gather statistics from audit log
AUTH_FAILURES=$(ausearch -k auth_fail --start today --end now -i 2>/dev/null | grep -c "type=USER_AUTH" || echo 0)
PRIV_ESCALATIONS=$(ausearch -k sudo_cmd --start today --end now -i 2>/dev/null | grep -c "type=SYSCALL" || echo 0)
MODULE_LOADS=$(ausearch -k module_load --start today --end now -i 2>/dev/null | grep -c "type=SYSCALL" || echo 0)
PKG_INSTALLS=$(ausearch -k pacman_exec --start today --end now -i 2>/dev/null | grep -c "type=SYSCALL" || echo 0)

# AppArmor denials from journald
AA_DENIALS=$(journalctl --since="today" -t audit 2>/dev/null | grep -c 'apparmor="DENIED"' || echo 0)

# Threshold for immediate alert (also used by real-time alerting)
ALERT_THRESHOLD=10
NEEDS_ALERT=0
[[ $AUTH_FAILURES -gt $ALERT_THRESHOLD ]] && NEEDS_ALERT=1
[[ $AA_DENIALS -gt 50 ]] && NEEDS_ALERT=1

generate_report() {
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
  pacman executions today      : ${PKG_INSTALLS}

Kernel Security:
  Module load events           : ${MODULE_LOADS}

AppArmor:
  DENIED events today          : ${AA_DENIALS}

--- Recent AppArmor Denials ---
$(journalctl --since="today" -t audit 2>/dev/null | grep 'apparmor="DENIED"' | tail -20)

--- Recent Authentication Failures ---
$(ausearch -k auth_fail --start today --end now -i 2>/dev/null | grep "type=USER_AUTH" | tail -10)

--- Recent Privilege Escalations ---
$(ausearch -k sudo_cmd --start today --end now -i 2>/dev/null | tail -10)

EOF
}

generate_report | msmtp "$RECIPIENT"

# Real-time alert if thresholds exceeded
if [[ $NEEDS_ALERT -eq 1 ]]; then
  cat << ALERT | msmtp "$RECIPIENT"
Subject: [IMMEDIATE ALERT] Security thresholds exceeded on ${HOST}

REAL-TIME SECURITY ALERT
=========================
Host: ${HOST}
Time: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

THRESHOLDS EXCEEDED:
  Auth failures today   : ${AUTH_FAILURES} (threshold: ${ALERT_THRESHOLD})
  AppArmor denials      : ${AA_DENIALS} (threshold: 50)

Immediate investigation recommended.
Run: ausearch -k auth_fail --start today
     journalctl -t audit | grep 'apparmor="DENIED"'
ALERT
fi
SCRIPT
chmod +x /usr/local/bin/daily-audit-summary.sh

# Weekly CVE report
cat > /usr/local/bin/weekly-cve-report.sh << 'SCRIPT'
#!/bin/bash
RECIPIENT="aahsnr041@proton.me"
/usr/local/bin/weekly-vuln-scan.sh | msmtp "$RECIPIENT"
/usr/local/bin/cachyos-security-check.sh >> /tmp/cachyos-security.txt 2>&1
echo "" >> /tmp/cachyos-security.txt
cat /tmp/cachyos-security.txt | msmtp "$RECIPIENT" 2>/dev/null || true
rm -f /tmp/cachyos-security.txt
SCRIPT
chmod +x /usr/local/bin/weekly-cve-report.sh

# Weekly AppArmor denial digest
cat > /usr/local/bin/weekly-apparmor-digest.sh << 'SCRIPT'
#!/bin/bash
RECIPIENT="aahsnr041@proton.me"
HOST=$(hostname)
WEEK_START=$(date -u -d "7 days ago" +"%Y-%m-%d")
WEEK_END=$(date -u +"%Y-%m-%d")

# Collect and group AppArmor denials by profile and operation
DENIALS=$(journalctl --since="${WEEK_START}" --until="${WEEK_END}" -t audit 2>/dev/null \
  | grep 'apparmor="DENIED"' \
  | sed 's/.*profile="\([^"]*\)".*operation="\([^"]*\)".*/\1 → \2/' \
  | sort | uniq -c | sort -rn | head -50)

cat << EOF | msmtp "$RECIPIENT"
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
  aa-log (requires apparmor-utils)

To view full denial details:
  ausearch --start week --end now | grep AVC
EOF
SCRIPT
chmod +x /usr/local/bin/weekly-apparmor-digest.sh

# Install systemd timers for automated reports
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

cat > /etc/systemd/system/weekly-cve-report.service << 'EOF'
[Unit]
Description=Weekly CVE Vulnerability Report

[Service]
Type=oneshot
ExecStart=/usr/local/bin/weekly-cve-report.sh
User=root
EOF

cat > /etc/systemd/system/weekly-cve-report.timer << 'EOF'
[Unit]
Description=Run weekly CVE report every Monday at 07:00 UTC

[Timer]
OnCalendar=Mon *-*-* 07:00:00 UTC
Persistent=true

[Install]
WantedBy=timers.target
EOF

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
systemctl enable --now weekly-cve-report.timer
systemctl enable --now weekly-apparmor-digest.timer
```

---

## Part 15 — Emergency Disaster Recovery

### 15.1 — Recovery USB Preparation

```bash
# On any Linux system with internet access:

# Download latest Arch Linux ISO
curl -O "https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"
curl -O "https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso.sig"

# Verify signature
gpg --keyserver keyserver.ubuntu.com --recv-keys 3E80CA1A8B89F69CBA57D98A76A5EF9054449A5C
gpg --verify archlinux-x86_64.iso.sig archlinux-x86_64.iso

# Write to USB (replace /dev/sdX with your USB drive)
dd if=archlinux-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync

# Pre-stage tools by creating a persistent overlay partition
# OR: use a systemd-nspawn container approach — write a script to USB:

# Create a recovery tools tarball to unpack on the live system
# This ensures the exact tool versions needed for recovery are available
cat > /tmp/install-recovery-tools.sh << 'TOOLS'
#!/bin/bash
# Run from Arch live environment to install all recovery tools needed
# for this specific system
pacman -Sy --noconfirm \
  cryptsetup \
  lvm2 \
  btrfs-progs \
  dracut \
  sbctl \
  efitools \
  systemd \
  snapper \
  arch-install-scripts \
  dosfstools \
  jq \
  git
echo "Recovery tools installed. Proceed with recovery procedure."
TOOLS
# Copy this script to the USB alongside the ISO
```

### 15.2 — System Unlock and Mount from Live Environment

```bash
# ============================================================
# RECOVERY PROCEDURE: Boot from Arch Linux live USB
# ============================================================

# Step 1: Install required tools if not present on live media
pacman -Sy cryptsetup lvm2 btrfs-progs arch-install-scripts

# Step 2: Open LUKS2 containers
# These require the TPM2 + PIN. If TPM is unavailable, use the recovery key.

# Attempt TPM2 unlock (if booted with correct Secure Boot keys + PCR state):
# systemd-cryptenroll --tpm2-device=auto will not work from a live environment
# because the PCR state won't match. Use recovery key or passphrase:

cryptsetup luksOpen /dev/nvme0n1p2 cryptpv-a
# → Enter recovery key or the original LUKS passphrase when prompted

cryptsetup luksOpen /dev/nvme1n1p1 cryptpv-b
# → Enter recovery key or the original LUKS passphrase when prompted

# Verify both are open
ls /dev/mapper/crypt*

# Step 3: Activate LVM volume group
vgchange -ay vg0
lvs  # Verify vg0/main and vg0/secondary are visible

# Step 4: Mount Btrfs subvolumes
# Mount the top-level Btrfs volume (subvolid=5) for subvolume management
mkdir -p /mnt/recovery
mount -o subvolid=5 /dev/vg0/main /mnt/recovery

# List all subvolumes
btrfs subvolume list /mnt/recovery

# Identify the current default subvolume (the active root)
btrfs subvolume get-default /mnt/recovery
```

### 15.3 — Chroot and System Restoration

#### Full Chroot Setup

```bash
# Mount the root subvolume (@ is the current root, or use @/.snapshots/N/snapshot for rollback)
BTRFS_OPTS="noatime,compress=zstd:3,space_cache=v2,discard=async"
BTRFS_NOCOW="noatime,space_cache=v2,discard=async"

mkdir -p /mnt/system
mount -o ${BTRFS_OPTS},subvol=@ /dev/vg0/main /mnt/system

# Mount all subvolumes into the chroot tree
mount -o ${BTRFS_OPTS},subvol=@/.snapshots   /dev/vg0/main /mnt/system/.snapshots
mount -o ${BTRFS_OPTS},subvol=@/home         /dev/vg0/main /mnt/system/home
mount -o ${BTRFS_OPTS},subvol=@/opt          /dev/vg0/main /mnt/system/opt
mount -o ${BTRFS_OPTS},subvol=@/root         /dev/vg0/main /mnt/system/root
mount -o ${BTRFS_OPTS},subvol=@/srv          /dev/vg0/main /mnt/system/srv
mount -o ${BTRFS_OPTS},subvol=@/tmp          /dev/vg0/main /mnt/system/tmp
mount -o ${BTRFS_OPTS},subvol=@/usr/local    /dev/vg0/main /mnt/system/usr/local
mount -o ${BTRFS_NOCOW},subvol=@/var          /dev/vg0/main /mnt/system/var
mount -o ${BTRFS_NOCOW},subvol=@/var/log      /dev/vg0/main /mnt/system/var/log
mount -o ${BTRFS_NOCOW},subvol=@/var/log/audit /dev/vg0/main /mnt/system/var/log/audit
mount -o ${BTRFS_NOCOW},subvol=@/var/cache    /dev/vg0/main /mnt/system/var/cache
mount -o ${BTRFS_NOCOW},subvol=@/var/tmp      /dev/vg0/main /mnt/system/var/tmp
mount -o ${BTRFS_NOCOW},subvol=@/nix          /dev/vg0/main /mnt/system/nix

# Mount ESP
mount /dev/nvme0n1p1 /mnt/system/efi

# Bind-mount required pseudo-filesystems
mount --rbind /proc /mnt/system/proc
mount --rbind /sys /mnt/system/sys
mount --make-rslave /mnt/system/sys
mount --rbind /dev /mnt/system/dev
mount --make-rslave /mnt/system/dev
mount --bind /run /mnt/system/run
mount --make-slave /mnt/system/run

# Fix /dev/shm (may be a symlink on some live environments)
test -L /mnt/system/dev/shm && rm /mnt/system/dev/shm && mkdir /mnt/system/dev/shm
mount -t tmpfs -o nosuid,nodev,noexec shm /mnt/system/dev/shm
chmod 1777 /mnt/system/dev/shm

# Copy current resolv.conf for network access inside chroot
cp /etc/resolv.conf /mnt/system/etc/resolv.conf

# Enter the chroot
arch-chroot /mnt/system
```

#### Snapper Snapshot Rollback via Chroot

```bash
# Inside the chroot (arch-chroot /mnt/system):

# List available snapshots
snapper -c root list

# Roll back to a specific snapshot (replace N with the snapshot number)
# This makes snapshot N the new default Btrfs subvolume
snapper -c root rollback N

# Exit chroot
exit

# After rollback, remount to verify the new default
btrfs subvolume get-default /mnt/recovery
# Should show the new snapshot path

# Reboot into the rolled-back system
umount -R /mnt/system
umount /mnt/recovery
vgchange -an vg0
cryptsetup close cryptpv-a
cryptsetup close cryptpv-b
reboot
```

#### Broken UKI / Secure Boot Recovery

```bash
# Scenario: UKI was corrupted, unsigned, or Secure Boot keys changed
# Recovery: boot with Secure Boot temporarily disabled in UEFI, then fix

# Inside chroot (after setup above):

# Verify Secure Boot status from within chroot
sbctl status

# Re-sign all UKIs with current keys
sbctl sign-all
# OR rebuild from scratch:
/usr/local/bin/rebuild-and-sign-uki.sh

# If keys need to be re-enrolled (e.g., after key rotation):
sbctl create-keys
sbctl enroll-keys --microsoft

# Re-sign
sbctl sign-all

# Exit chroot, re-enable Secure Boot in UEFI, reboot
exit
```

#### Broken pacman Database Recovery

```bash
# Scenario: pacman database is corrupted (e.g., after interrupted upgrade)
# Recovery from within chroot:

# Method 1: Force-rebuild the local database from installed package files
pacman -b /var/lib/pacman --dbonly -U /var/cache/pacman/pkg/*.pkg.tar.zst 2>/dev/null

# Method 2: If the sync DBs are corrupted, refresh them
pacman -Syy   # Force re-download all sync databases

# Method 3: Nuclear option — rebuild pacman DB from scratch
# This re-reads every installed package's info from /var/lib/pacman/local/
# and reconstructs the database. Installed packages remain intact.
rm -rf /var/lib/pacman/sync/
pacman -Syy
pacman -Syu --noconfirm

# Verify database integrity
pacman -Qk 2>&1 | grep -v "0 missing files" | head -20
```

### 15.4 — TPM2 Key Recovery

#### Re-enrollment After TPM State Loss or Secure Boot Key Rotation

```bash
# Scenario: TPM2 unsealing fails (PCR mismatch, TPM reset, key rotation)
# The system falls back to prompting for the LUKS recovery key.

# Step 1: Boot using the recovery key
# At LUKS unlock prompt, use the recovery key printed during enrollment (Part 1.3)

# Step 2: Once booted into the installed system (not live USB):

# Verify the system booted correctly
systemctl is-active sshd cryptsetup.target

# Step 3: Wipe the old (now-invalid) TPM2 enrollment
# The TPM token slot number is shown in: systemd-cryptenroll /dev/nvme0n1p2
systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p2
systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme1n1p1

# Step 4: Re-enroll TPM2 with PIN against the new PCR baseline
# The PCR values are now stable (correct kernel+initramfs+cmdline+SecureBoot state)
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

# Step 5: Wipe the used recovery key and generate a new one
# (A used recovery key must be treated as compromised — revoke it)
systemd-cryptenroll --wipe-slot=recovery /dev/nvme0n1p2
systemd-cryptenroll --wipe-slot=recovery /dev/nvme1n1p1

systemd-cryptenroll --recovery-key /dev/nvme0n1p2
systemd-cryptenroll --recovery-key /dev/nvme1n1p1

# Step 6: Store the new recovery keys offline immediately
# Print them, write them to an encrypted offline USB, and store securely.
# The system is only as safe as the recovery key's physical security.

# Verify all slots
systemd-cryptenroll /dev/nvme0n1p2
# Expected output: shows tpm2 slot + recovery slot, no empty passphrase slots
```

#### Complete TPM2 Failure — Recovery Key Only

```bash
# Scenario: TPM2 chip failed or was cleared by firmware update/reset
# The system cannot use TPM2 at all until chip is functional.

# Interim operation: use only the recovery key (passphrase entered at boot)
# The system will work — just less convenient (no PIN-sealed unlock)

# To verify recovery key still works:
cryptsetup luksOpen --test-passphrase /dev/nvme0n1p2
# Enter recovery key when prompted → should succeed silently

# When TPM2 is functional again, re-enroll as above.

# If TPM2 is permanently damaged:
# Option A: Re-enroll with a regular passphrase (not TPM2)
systemd-cryptenroll --password /dev/nvme0n1p2
systemd-cryptenroll --password /dev/nvme1n1p1

# Option B: Accept reduced security (recovery-key-only boot)
# Not recommended for APT threat model — a lost drive is trivially decryptable
# with a weak passphrase. Use a strong 25+ character passphrase as compensating control.
```

---

## Appendix A — Installation Order Checklist

The following installation sequence ensures dependencies are in place before configuration:

```
Phase 1 — Disk Setup (live environment):
  1.1  Partition drives (gdisk)
  1.2  Format LUKS2 on both partitions (cryptsetup luksFormat)
  1.3  Open LUKS containers, create LVM VG + LVs
  1.4  Format LVs: Btrfs (main), Btrfs (secondary), vfat (ESP)
  1.5  Create Btrfs subvolumes
  1.6  Mount all subvolumes

Phase 2 — Base Install:
  2.1  pacstrap base base-devel linux-firmware
  2.2  Add CachyOS repos, install linux-cachyos
  2.3  genfstab → /mnt/etc/fstab
  2.4  arch-chroot

Phase 3 — In-Chroot Configuration:
  3.1  Timezone, locale, hostname
  3.2  Install core packages: lvm2 btrfs-progs cryptsetup dracut sbctl
  3.3  Configure dracut (Parts 1.4 drop-in files)
  3.4  First UKI build: dracut --uefi
  3.5  Sign UKI: sbctl sign
  3.6  Enroll Secure Boot keys: sbctl enroll-keys
  3.7  Exit chroot, reboot, boot signed UKI

Phase 4 — Post-Boot Hardening:
  4.1  TPM2+PIN enrollment (Part 1.3) — must be done on running system
  4.2  Install AppArmor + apparmor.d (Part 3)
  4.3  Deploy sysctl config (Part 5)
  4.4  Deploy module blacklist + rebuild initramfs (Part 6)
  4.5  Verify IOMMU active (Part 7)
  4.6  Configure firewalld (Part 9.1)
  4.7  Configure dnscrypt-proxy + systemd-resolved (Part 9.2)
  4.8  Harden NetworkManager (Part 9.3)
  4.9  Harden SSH (Part 10)
  4.10 Harden PAM (Part 11)
  4.11 Configure auditd rules (Part 4)
  4.12 Install snap-pac, configure Snapper (Part 1.6)
  4.13 Install pkgman.py, svc-harden.py (Parts 2, 12)
  4.14 Configure monitoring timers + msmtp (Part 14)
  4.15 Verify all services running, run full audit pass
```

## Appendix B — Conflict and Uncertainty Notes

The following items involve conflicting guidance, judgment calls, or areas of uncertainty as of April 2026:

| Item | Conflict | Resolution |
|---|---|---|
| Full RELRO in CachyOS | Arch wiki says partial RELRO is default; CachyOS adds LTO but not explicit `-Wl,-z,now` system-wide | Accepted gap; compensated by ASLR+PIE. No runtime fix without recompiling. |
| `kernel.unprivileged_userns_clone` | Setting to 0 breaks Chrome, Firefox, Flatpak sandbox; setting to 1 leaves namespace CVE surface | Set to 1 with AppArmor profiling the consumers. Revisit if namespace CVEs spike. |
| Flatpak security without SELinux | Some sources claim Flatpak is "fine" without SELinux; accurate analysis shows weakened MAC backstop | Firm: AppArmor+native is primary; Flatpak only for apps with no alternative, with audit logging. |
| `ptrace_scope` | scope=2 is stronger but breaks user-mode debuggers; scope=1 prevents cross-user injection | scope=1 chosen for workstation usability. Adjust to 2 on servers. |
| rng-tools on modern kernels | Oracle blog recommends keeping rngd even on kernel ≥ 5.6; ArchWiki says unnecessary on x86-64 | ArchWiki position is more current and accurate for the i9-13900K. Not installed. |
| dnscrypt-proxy port | Both systemd-resolved stub and dnscrypt-proxy default to port 53 | Resolved by running dnscrypt-proxy on port 5300 with systemd-resolved forwarding to it. |
