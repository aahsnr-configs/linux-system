# Hardened Arch Linux Workstation — CachyOS + AppArmor + UKI + TPM2

**Edition**: April 2026 — complete rewrite  
**Threat Model**: Nation-state APT (Chinese and Russian state-sponsored groups, documented TTPs)  
**Hardware**: Intel i9‑13900K (Raptor Lake, 24‑core), 500 GB + 1 TB NVMe, TPM 2.0, UEFI, Intel VT‑d, Intel TME  
**Kernel**: `linux‑cachyos‑hardened` — includes the upstream `linux‑hardened` patch‑set and kernel config  
**MAC**: AppArmor in **enforce** mode with the full `apparmor.d` profile set (~1 500 profiles) — SELinux is **not** installed  
**Sandboxing**: AppArmor exclusively; Flatpak is permitted for software distribution only, **not** as a security boundary  


## Pre‑Work Research Summary

### 0.1 — CachyOS compile‑time hardening status

CachyOS publishes the **`linux‑cachyos‑hardened`** variant that bundles the upstream `linux‑hardened` patch‑set, a kernel configuration derived from Arch’s `linux‑hardened` config, and “very aggressive hardening that significantly impacts performance and user experience” according to the CachyOS Wiki. This kernel enables Kernel Lockdown, restricted `/dev/mem`, hardened slab allocator, and numerous other compile‑time defences that the standard `linux‑cachyos` lacks.

User‑space packages from the CachyOS repositories inherit Arch Linux’s default security flags: PIE, `FORTIFY_SOURCE`, stack protector, NX, and RELRO are applied by Arch packaging guidelines. CachyOS does **not** publish a separate security‑flag policy for its rebuilt packages. No per‑package recompilation is performed in this guide; runtime controls (AppArmor, systemd service hardening, auditd) provide defence‑in‑depth that is effective regardless of binary compilation flags.

> **Decision**: This guide specifies **`linux‑cachyos‑hardened`**, not the standard `linux‑cachyos`. The performance cost documented by CachyOS is accepted as a necessary trade‑off against the APT threat model.

### 0.2 — AppArmor confinement vs. Flatpak

**`apparmor.d` project status (April 2026)**: The project provides **over 1 500** AppArmor profiles covering systemd tools, Bluetooth, dbus, polkit, NetworkManager, GDM, rtkit, colord, Pipewire, Gvfsd, XWayland, and desktop environments (GNOME/GDM, KDE/SDDM, XFCE/LightDM). Profiles ship in **complain mode** (logging‑only) and must be manually transitioned to enforce mode — a deliberate upstream design choice to avoid breakage. Installation on Arch is via the `apparmor.d` AUR package. Support for AppArmor 3.x will be dropped in early 2026; AppArmor 4.1+ will be required.

**Flatpak security without SELinux — corrected analysis**: Flatpak does **not** depend on AppArmor or SELinux for its primary sandboxing. Flatpak uses **bubblewrap** (user‑namespace‑based containers) for isolation, which is independent of the system LSM. The absence of SELinux does **not** weaken Flatpak’s bubblewrap‑based sandbox. However, Flatpak has a structural weakness: its seccomp filter is **denylist‑based** rather than allowlist‑based, and many dangerous syscalls cannot be blocked because applications rely on them. AppArmor and Flatpak operate independently — an AppArmor profile will still apply when a binary runs inside a Flatpak container, but the two mechanisms are not integrated.

> **Architectural decision (confirmed)**: Application sandboxing is handled **exclusively by AppArmor**. Flatpak is retained **solely as a software distribution mechanism** for applications not available in Arch/CachyOS repos or AUR. Flatpak’s bubblewrap sandbox is treated as a secondary, non‑trusted boundary due to the denylist‑based seccomp filter.

### 0.3 — Gentoo and Arch reference file audit

*Full audit conducted. Principal adaptations:*

| Gentoo concept | Arch adaptation |
|---|---|
| mdadm RAID 0 | LVM RAID 0 (`--type raid0`) |
| GRUB with cryptodisk | UKI + EFISTUB (no bootloader) |
| `crypttab.initramfs` keyfile | TPM2 + PIN via `systemd‑cryptenroll` |
| Bootable snapshots via grub‑btrfs | Chroot‑based Snapper restoration only |
| Portage hooks | Pacman hooks |
| `installkernel` USE flags | Dracut pacman hooks |

### 0.4 — Entropy on modern Linux kernels

On Linux ≥ 5.6 on x86‑64 with RDTSC and RDRAND (i9‑13900K), the kernel’s built‑in CRNG (ChaCha20‑based, seeded with BLAKE2s‑extracted entropy from RDRAND, RDSEED, CPU jitter, and interrupts) is **cryptographically sufficient for all use cases** and does not require userspace entropy augmentation. `/dev/random` and `/dev/urandom` are **equivalent** on Arch Linux (x86‑64 only). `rng‑tools` is deprecated in several distributions. `haveged` is not needed on x86‑64 with RDTSC. `jitterentropy‑rngd` is unnecessary — the kernel already incorporates CPU jitter entropy via its own jitterentropy subsystem.

**Early‑boot entropy**: The kernel CRNG is initialised before the initramfs phase. The `random: crng init done` message in dmesg confirms seeding before `systemd‑cryptsetup` attempts LUKS unlock.

> **Recommendation**: No userspace entropy daemon is installed.


## Part 1 — Disk Layout, Encryption, and Boot Chain

### 1.1 — Hardware

| Drive | Size | Role |
|---|---|---|
| `nvme0n1` | 500 GB | LVM PV (RAID‑0 member + linear member) |
| `nvme1n1` | 1 TB | LVM PV (RAID‑0 member + linear member) |

### 1.2 — LVM Layout

Each NVMe drive is independently encrypted with LUKS2. LVM is assembled on top of the decrypted mapper devices. This is the **only** configuration that supports LVM RAID‑0 striping across independently encrypted physical devices.

```
nvme0n1 → LUKS2 → /dev/mapper/crypt0 ─┐
                                        ├── VG vg0
nvme1n1 → LUKS2 → /dev/mapper/crypt1 ─┘    ├── lv_main (RAID 0, ≤ ~1 TB, 64 KB stripe)
                                             └── lv_secondary (linear, remaining space)
```

**Layering justification**: Encrypting each PV before LVM assembly encrypts **all** data — LVM metadata, volume names, and sizes. The alternative (LUKS2 on individual LVs) leaks LVM metadata in plaintext.

**Stripe size**: 64 KB. This balances sequential throughput with small‑I/O latency on NVMe drives and aligns with Btrfs block group sizes.

```bash
wipefs -a /dev/nvme0n1 /dev/nvme1n1
pvcreate /dev/nvme0n1 /dev/nvme1n1
vgcreate vg0 /dev/nvme0n1 /dev/nvme1n1

# RAID-0 striped LV (both PVs, 64 KB stripe)
lvcreate --type raid0 -i 2 -L 1000G -n lv_main vg0

# Linear LV (remaining space ≈ 500 GB)
lvcreate -l 100%FREE -n lv_secondary vg0
```

> ⚠ **RAID 0 has zero redundancy.** Either NVMe failure destroys all data on both volumes. Maintain off‑site backups.

### 1.3 — Full Disk Encryption

**LUKS2 with Argon2id** on each NVMe drive. Argon2id is used because **no bootloader** is involved in LUKS decryption — the UKI’s initramfs handles this via TPM2 + PIN.

```bash
for dev in nvme0n1 nvme1n1; do
    cryptsetup luksFormat \
      --type luks2 \
      --cipher aes-xts-plain64 \
      --key-size 512 \
      --hash sha512 \
      --pbkdf argon2id \
      --iter-time 4000 \
      --label crypt_${dev} \
      /dev/${dev}
    cryptsetup luksOpen /dev/${dev} crypt_${dev}
done
```

**TPM2 + PIN enrollment — rationale**: The TPM2 chip is the sole key‑storage device. No FIDO2 device is available. A PIN is required to prevent cold‑boot TPM‑only unlock — an attacker with physical access could otherwise power on the machine and have the TPM silently release the key. The PIN provides a “something you know” factor.

```bash
for dev in nvme0n1 nvme1n1; do
    systemd-cryptenroll --tpm2-device=auto \
      --tpm2-pcrs="7+11" \
      --tpm2-with-pin=yes \
      /dev/${dev}
done
```

**PCR register selection rationale**:

| PCR | What it measures | Why sealed |
|---|---|---|
| 7 | Secure Boot state (PK, KEK, db, dbx) + policy | If Secure Boot is disabled or keys are compromised, TPM refuses to unseal |
| 11 | UKI measurement (systemd‑stub measures the UKI before launching it) | If the UKI binary is tampered with or replaced, TPM refuses to unseal |

PCR 4 (boot manager) is **not** used — we boot UKIs directly via EFISTUB. PCR 8 (kernel command line) is **not** used — the UKI embeds the command line, and PCR 11 covers the entire UKI including the embedded cmdline. PCR 9 is superseded by PCR 11 for UKI‑based boot.

**Recovery key**:

```bash
for dev in nvme0n1 nvme1n1; do
    systemd-cryptenroll --recovery-key /dev/${dev}
done
# Print the displayed recovery key and store it **offline**.
# This key bypasses TPM2 — protect it accordingly.
```

**What happens to TPM2 state when Secure Boot keys are rotated or the UKI is updated**: PCR 7 changes (new Secure Boot policy hash). PCR 11 changes (new UKI hash). The TPM will refuse to unseal the LUKS key. Boot using the **recovery key**, then re‑run the `systemd‑cryptenroll` commands above. The recovery key remains valid throughout. See Part 15.4 for the full recovery procedure.

### 1.4 — UKI and Secure Boot

Dracut generates a **Unified Kernel Image** (UKI) using `systemd‑stub` as the UEFI stub. No GRUB, no systemd‑boot, no Limine. The UKI is a single signed EFI binary containing: kernel image, initramfs, kernel command line, CPU microcode, and a splash image.

**Trust chain**:

```
UEFI firmware (Secure Boot enabled)
  └─► Validates UKI signature against db key
       └─► Loads UKI (systemd‑stub)
            └─► Linux kernel boots
                 └─► Dracut initramfs runs
                      └─► systemd‑cryptsetup reads TPM2 + PIN → unlocks both LUKS containers
                           └─► LVM assembles VG, activates LVs
                                └─► Btrfs root mounts
                                     └─► systemd init
```

**`/etc/dracut.conf.d/99-uki.conf`**:

```bash
uefi="yes"
uefi_stub="/usr/lib/systemd/boot/efi/linuxx64.efi.stub"
uefi_path="/EFI/Linux/arch-cachyos-hardened.efi"
early_microcode="yes"
compress="zstd"

# lsm= enables AppArmor alongside other LSMs
# intel_iommu=on iommu=force enables strict DMA protection
# iommu.strict=1 ensures synchronous TLB invalidation
kernel_cmdline="quiet loglevel=3 rw lsm=landlock,lockdown,yama,integrity,apparmor,bpf intel_iommu=on iommu=force iommu.strict=1"

add_dracutmodules+=" systemd systemd-initrd crypt lvm btrfs tpm2-tss "
```

**ESP layout**:

```bash
mkfs.vfat -F32 -n ESP /dev/nvme0n1p1
mkdir -p /boot
mount /dev/nvme0n1p1 /boot
mkdir -p /boot/EFI/Linux
```

**Secure Boot key generation and enrollment with `sbctl`**:

```bash
pacman -S sbctl
sbctl status            # Verify "Setup Mode: ✓ Enabled"
sbctl create-keys        # Generate custom PK, KEK, db
sbctl enroll-keys -m     # Enroll to firmware, retain Microsoft keys for compatibility
sbctl status             # Verify "Setup Mode: ✓ Disabled, Secure Boot: ✓ Enabled"
```

**UKI signing and pacman integration**:

```bash
sbctl sign -s /boot/EFI/Linux/arch-cachyos-hardened.efi
sbctl verify
```

`sbctl` installs a pacman hook that automatically re‑signs tracked files when the kernel or dracut updates.

**UEFI boot entry**:

```bash
efibootmgr --create \
  --disk /dev/nvme0n1 --part 1 \
  --label "Arch Linux (CachyOS Hardened)" \
  --loader /EFI/Linux/arch-cachyos-hardened.efi
```

### 1.5 — No Hibernation

Hibernation (suspend‑to‑disk) is **not configured**. Rationale:

- Eliminates the hibernation image as an attack vector — APT forensic tools can extract keys and sensitive memory state from hibernation images
- No encrypted swap volume is needed — swap is not configured at all
- Suspend‑to‑RAM (S3) is the only sleep state permitted

**Intel TME verification**: The i9‑13900K supports Intel Total Memory Encryption (AES‑XTS‑128 at the memory controller). During S3, DRAM is in self‑refresh; TME ensures cold‑boot or DMA attacks against DRAM contents recover only ciphertext. The TME key is stored in the CPU package and is not accessible via DRAM probing.

```bash
dmesg | grep -i "memory encryption"
# Expected: "x86/tme: enabled by BIOS" or "Intel TME: enabled"
```

**TME limitations**: (1) Single key for all memory — no per‑process or per‑VM key isolation (requires MKTME, not available on consumer CPUs). (2) Does not protect against runtime attacks where the attacker has code execution. (3) Does not protect against Thunderbolt DMA attacks — IOMMU strict mode (Part 7) addresses this.

### 1.6 — Btrfs Subvolume Layout (lv_main)

```
/dev/mapper/vg0-lv_main (Btrfs)
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
└── @snapshots               → /.snapshots (Snapper directory)
```

**Subvolume justification**:

| Subvolume | Purpose | Why separate |
|---|---|---|
| `@` | Root filesystem | Snapper snapshots capture only this |
| `@home` | User home directories | Preserved across rollbacks |
| `@opt` | Third‑party applications | Preserved across rollbacks |
| `@root` | Root user home | Preserved for audit trail |
| `@srv` | Service data | Excluded from snapshots |
| `@tmp` | Temporary files | Prevents stale tmp data in rollbacks |
| `@usr_local` | Locally compiled software | Excluded from snapshots |
| `@var` | Variable data | CoW disabled for DB/log performance |
| `@var_cache` | Package cache | CoW disabled; avoids cache bloat in snapshots |
| `@var_log` | System logs | CoW disabled; preserves audit trail across rollbacks |
| `@var_tmp` | Persistent temp files | CoW disabled |
| `@nix` | Nix package store | CoW disabled (Nix manages its own dedup) |
| `@snapshots` | Snapper snapshots | Nested under top‑level, not under `@` |

**Key differences from `gentoo‑setup.md`**: `/boot` is not a subvolume — UKIs live on the separate FAT32 ESP. No `@/boot/grub2/` subvolume — no GRUB is used. No `@/.snapshots/1/snapshot` initial snapshot — Arch Snapper creates its own structure. `@var@cache/pkg` (Gentoo’s separate pkg subvolume) is collapsed into `@var_cache`.

**Complete subvolume creation**:

```bash
mount -o defaults,noatime,compress=zstd:1,space_cache=v2 /dev/mapper/vg0-lv_main /mnt

for subvol in @ @home @opt @root @srv @tmp @usr_local @var @var_cache @var_log @var_tmp @nix @snapshots; do
    btrfs subvolume create /mnt/${subvol}
done

for subvol in @var @var_cache @var_log @var_tmp @nix; do
    chattr +C /mnt/${subvol}
done

mkdir -p /mnt/@/{home,opt,root,srv,tmp,usr/local,var/{cache,log,tmp},nix,.snapshots,boot}
umount /mnt
mount -o defaults,noatime,compress=zstd:1,space_cache=v2,subvol=@ /dev/mapper/vg0-lv_main /mnt

BTRFS_OPTS="defaults,noatime,compress=zstd:1,space_cache=v2"
mount -o ${BTRFS_OPTS},subvol=@home      /dev/mapper/vg0-lv_main /mnt/home
mount -o ${BTRFS_OPTS},subvol=@opt       /dev/mapper/vg0-lv_main /mnt/opt
mount -o ${BTRFS_OPTS},subvol=@root      /dev/mapper/vg0-lv_main /mnt/root
mount -o ${BTRFS_OPTS},subvol=@srv       /dev/mapper/vg0-lv_main /mnt/srv
mount -o ${BTRFS_OPTS},subvol=@tmp       /dev/mapper/vg0-lv_main /mnt/tmp
mount -o ${BTRFS_OPTS},subvol=@usr_local /dev/mapper/vg0-lv_main /mnt/usr/local
mount -o defaults,noatime,space_cache=v2,subvol=@var       /dev/mapper/vg0-lv_main /mnt/var
mount -o defaults,noatime,space_cache=v2,subvol=@var_cache /dev/mapper/vg0-lv_main /mnt/var/cache
mount -o defaults,noatime,space_cache=v2,subvol=@var_log   /dev/mapper/vg0-lv_main /mnt/var/log
mount -o defaults,noatime,space_cache=v2,subvol=@var_tmp   /dev/mapper/vg0-lv_main /mnt/var/tmp
mount -o defaults,noatime,space_cache=v2,subvol=@nix       /dev/mapper/vg0-lv_main /mnt/nix
mount -o ${BTRFS_OPTS},subvol=@snapshots /dev/mapper/vg0-lv_main /mnt/.snapshots

mount /dev/nvme0n1p1 /mnt/boot
```

> **Why `/nix` has no `compress=zstd`**: The Nix store primarily contains already‑compressed binary data. Applying zstd would waste CPU cycles without meaningful space savings.

**Chroot‑based Snapper restoration** (primary recovery mechanism — snapshots are restored by booting a live USB, **not** by booting snapshots directly):

```bash
# 1. Boot Arch Linux live USB
# 2. Unlock LUKS containers with the recovery key
cryptsetup luksOpen /dev/nvme0n1 crypt0
cryptsetup luksOpen /dev/nvme1n1 crypt1
# 3. Assemble LVM
vgchange -ay vg0
# 4. Mount Btrfs top‑level volume (subvolid=5)
mount -o subvolid=5 /dev/mapper/vg0-lv_main /mnt
# 5. List available snapshots
grep '<date>' /mnt/@snapshots/*/info.xml
# 6. Non‑destructive rollback (creates new read‑write snapshot, sets default, preserves old @)
snapper -c root --ambit classic rollback <snapshot_number>
# 7. Verify
btrfs subvolume get-default /mnt
# 8. Unmount and reboot
umount -R /mnt && reboot
```


## Part 2 — Package Management Security Wrapper (`pkgman.py`)

A Python 3 CLI tool (`pkgman.py`) provides secure installation workflows for three sources. It uses `argparse` for a full CLI, logs all operations with ISO 8601 timestamps to a structured JSON audit log, and implements comprehensive exception handling.

**Subcommands**: `repo` (pacman with signature verification), `aur` (mandatory PKGBUILD review and static analysis), `flatpak` (confinement warning), and `audit` (log viewer).

```python
#!/usr/bin/env python3
"""
pkgman.py — Hardened Package Management Wrapper for Arch/CachyOS
Threat model: APT supply chain attacks, malicious PKGBUILDs,
typosquatting, unverified sources, and Flatpak sandboxing without SELinux.
All operations logged to a structured JSON audit log.
"""

import argparse, json, os, subprocess, sys, textwrap, time, re, tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, List, Dict, Any

AUDIT_LOG_PATH = os.environ.get("PKGMAN_AUDIT_LOG", "/var/log/pkgman-audit.json")
PACMAN_CONF = "/etc/pacman.conf"
AUR_URL_BASE = "https://aur.archlinux.org"

# Suspicious PKGBUILD patterns for static analysis
SUSPICIOUS_PATTERNS = [
    (re.compile(r'(curl|wget)\s+.*\|\s*(bash|sh|python|perl|ruby)'),
     "Piped execution pattern — potential RCE"),
    (re.compile(r'base64\s+(-d|--decode)'),
     "Base64 decode in PKGBUILD — potential obfuscation"),
    (re.compile(r'\beval\b'), "eval() call — potentially dangerous"),
    (re.compile(r'(?i)(password|passwd|token|secret|api[_-]?key)\s*=\s*["\'][^"\']{8,}["\']'),
     "Hardcoded credential/token found"),
    (re.compile(r'(?<!https)http://'), "Non-HTTPS URL in source= array"),
    (re.compile(r'^md5sums=', re.MULTILINE),
     "MD5 checksums — cryptographically broken; use sha256sums or b2sums"),
    (re.compile(r'^sha256sums=\("SKIP"\)', re.MULTILINE),
     "Checksum verification skipped (SKIP)"),
    (re.compile(r'install\s*=\s*["\'](.+\.install)["\']'),
     "References .install hook script — review separately"),
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
                entries = json.loads(log_path.read_text())
            except (json.JSONDecodeError, FileNotFoundError):
                entries = []
        entries.append(entry)
        log_path.write_text(json.dumps(entries, indent=2))
    except Exception as e:
        print(f"ERROR: Failed to write audit log: {e}", file=sys.stderr)


def check_pacman_sig_level() -> bool:
    """Verify pacman enforces package signatures."""
    try:
        conf = Path(PACMAN_CONF).read_text()
        for line in conf.splitlines():
            line = line.strip()
            if line.startswith("SigLevel") and ("Never" in line or "Optional" in line):
                if "DatabaseOptional" not in line and "PackageOptional" not in line:
                    print(f"WARNING: Weak SigLevel: {line}", file=sys.stderr)
                    return False
        return True
    except FileNotFoundError:
        print("ERROR: pacman.conf not found!", file=sys.stderr)
        return False


def install_repo(packages: List[str], dry_run: bool = False) -> bool:
    """Install from official repositories via pacman."""
    if not check_pacman_sig_level():
        print("ERROR: GPG signature enforcement is not active. Aborting.", file=sys.stderr)
        return False
    cmd = ["pacman", "-S", "--noconfirm"] + packages
    if dry_run:
        print(f"[DRY RUN] Would execute: {' '.join(cmd)}")
        return True
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        for pkg in packages:
            audit_log({"action": "install_repo", "package": pkg, "source": "official",
                        "success": True, "output": result.stdout[-500:]})
        print(f"Successfully installed: {', '.join(packages)}")
        return True
    except subprocess.CalledProcessError as e:
        for pkg in packages:
            audit_log({"action": "install_repo", "package": pkg, "source": "official",
                        "success": False, "error": str(e)})
        print(f"ERROR: pacman failed: {e.stderr}", file=sys.stderr)
        return False


def fetch_pkgbuild(package: str) -> Optional[str]:
    """Fetch the PKGBUILD for an AUR package."""
    tmpdir = tempfile.mkdtemp(prefix="pkgman-aur-")
    try:
        subprocess.run(["git", "clone", "--depth=1", f"{AUR_URL_BASE}/{package}.git", tmpdir],
                       check=True, capture_output=True, text=True)
        return Path(tmpdir, "PKGBUILD").read_text()
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"ERROR: Failed to fetch PKGBUILD: {e}", file=sys.stderr)
        return None


def analyze_pkgbuild(content: str) -> List[Dict[str, str]]:
    """Static analysis of PKGBUILD content."""
    findings = []
    for pattern, description in SUSPICIOUS_PATTERNS:
        matches = pattern.findall(content)
        if matches:
            findings.append({"pattern": pattern.pattern, "description": description,
                             "matches": str(matches)[:200]})
    return findings


def fetch_aur_comments(package: str) -> str:
    """Fetch recent AUR comments."""
    try:
        import urllib.request
        url = f"{AUR_URL_BASE}/rpc/v5/comments/{package}"
        req = urllib.request.Request(url, headers={"User-Agent": "pkgman/1.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode())
        if data.get("resultcount", 0) > 0:
            return "\n".join(f"[{c.get('CommentDate','?')}] {c.get('Comments','')[:300]}"
                             for c in data["results"][-10:])
        return "(No comments found)"
    except Exception as e:
        return f"(Failed to fetch comments: {e})"


def install_aur(package: str, dry_run: bool = False) -> bool:
    """Install a single package from AUR with mandatory PKGBUILD review."""
    print(f"\n{'='*70}\nAUR Package Installation: {package}\n{'='*70}")

    print("\n[1/5] Fetching PKGBUILD...")
    pkgbuild = fetch_pkgbuild(package)
    if pkgbuild is None:
        return False
    print("\n" + "-"*70 + "\nPKGBUILD CONTENTS:\n" + "-"*70)
    print(pkgbuild)
    print("-"*70)

    print("\n[2/5] Static analysis...")
    findings = analyze_pkgbuild(pkgbuild)
    if findings:
        print(f"\n⚠️  Found {len(findings)} issue(s):")
        for i, f in enumerate(findings, 1):
            print(f"\n  Issue {i}: {f['description']}\n  Matched: {f['matches']}")
    else:
        print("✓ No suspicious patterns detected.")

    print("\n[3/5] Fetching AUR comments...\n" + "-"*50)
    print(fetch_aur_comments(package))
    print("-"*50)

    print(f"\n[4/5] Summary: {len(findings)} static issues, comments reviewed.")

    if dry_run:
        print("\n[DRY RUN] Would require confirmation.")
        return True

    print("\n[5/5] Type 'INSTALL' to proceed (anything else aborts):")
    try:
        if input("  > ").strip() != "INSTALL":
            print("Aborted."); return False
    except (EOFError, KeyboardInterrupt):
        print("\nAborted."); return False

    tmpdir = tempfile.mkdtemp(prefix="pkgman-aur-build-")
    try:
        subprocess.run(["git", "clone", "--depth=1", f"{AUR_URL_BASE}/{package}.git", tmpdir],
                       check=True)
        subprocess.run(["makepkg", "-si", "--noconfirm"], cwd=tmpdir, check=True)
        audit_log({"action": "install_aur", "package": package, "source": "aur",
                    "success": True, "static_analysis_issues": len(findings)})
        print(f"✓ Installed: {package}")
        return True
    except subprocess.CalledProcessError as e:
        audit_log({"action": "install_aur", "package": package, "source": "aur",
                    "success": False, "error": str(e)})
        print(f"ERROR: AUR build failed: {e}", file=sys.stderr)
        return False


FLATPAK_WARNING = textwrap.dedent("""\
    ╔══════════════════════════════════════════════════════════════════╗
    ║  FLATPAK CONFINEMENT WARNING                                    ║
    ║  This system uses AppArmor (not SELinux). Flatpak relies on     ║
    ║  bubblewrap (user-namespace sandboxing) with a denylist-based   ║
    ║  seccomp filter. Its sandbox is treated as a secondary,         ║
    ║  non-trusted boundary. Flatpak is permitted for software        ║
    ║  distribution only, NOT as a security mechanism.                ║
    ╚══════════════════════════════════════════════════════════════════╝
""")


def install_flatpak(package: str, dry_run: bool = False) -> bool:
    """Install a Flatpak package with confinement warning."""
    print(FLATPAK_WARNING)
    if dry_run:
        print(f"[DRY RUN] Would require confirmation, then install: {package}")
        return True
    print("Type 'I UNDERSTAND' to proceed:")
    try:
        if input("  > ").strip() != "I UNDERSTAND":
            print("Aborted."); return False
    except (EOFError, KeyboardInterrupt):
        print("\nAborted."); return False
    try:
        subprocess.run(["flatpak", "install", "--noninteractive", package], check=True)
        audit_log({"action": "install_flatpak", "package": package, "source": "flatpak",
                    "success": True})
        print(f"✓ Installed: {package}")
        return True
    except subprocess.CalledProcessError as e:
        audit_log({"action": "install_flatpak", "package": package, "source": "flatpak",
                    "success": False, "error": str(e)})
        print(f"ERROR: {e}", file=sys.stderr)
        return False


def main() -> None:
    parser = argparse.ArgumentParser(description="Hardened Package Management Wrapper")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--audit-log", default=AUDIT_LOG_PATH)
    sub = parser.add_subparsers(dest="command")
    rp = sub.add_parser("repo", help="Install from official repositories")
    rp.add_argument("packages", nargs="+")
    ap = sub.add_parser("aur", help="Install from AUR")
    ap.add_argument("package")
    fp = sub.add_parser("flatpak", help="Install from Flatpak")
    fp.add_argument("package")
    sub.add_parser("audit", help="View audit log summary")
    args = parser.parse_args()

    global AUDIT_LOG_PATH
    AUDIT_LOG_PATH = args.audit_log

    if args.command == "repo":
        success = install_repo(args.packages, args.dry_run)
    elif args.command == "aur":
        success = install_aur(args.package, args.dry_run)
    elif args.command == "flatpak":
        success = install_flatpak(args.package, args.dry_run)
    elif args.command == "audit":
        try:
            entries = json.loads(Path(AUDIT_LOG_PATH).read_text())
            print(f"Audit log: {AUDIT_LOG_PATH}\nTotal entries: {len(entries)}")
            for e in entries[-10:]:
                s = "✓" if e.get("success") else "✗"
                print(f"  {s} [{e.get('timestamp','?')}] {e.get('action')} "
                      f"{e.get('package','?')} ({e.get('source','?')})")
        except (FileNotFoundError, json.JSONDecodeError):
            print("No audit log found or log is empty.")
    else:
        parser.print_help(); sys.exit(1)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
```


## Part 3 — AppArmor Configuration

### 3.1 — AppArmor in enforcing mode

```bash
pacman -S apparmor apparmor-utils
systemctl enable apparmor.service && systemctl start apparmor.service
cat /sys/module/apparmor/parameters/enabled   # → Y
aa-status
```

The `lsm=` kernel parameter enabling AppArmor is embedded in the UKI cmdline (Part 1.4).

### 3.2 — `apparmor.d` integration

```bash
pkgman.py aur apparmor.d
```

Profiles install to `/etc/apparmor.d/` and load in **complain mode** by default — a deliberate upstream design choice to avoid breakage.

**Selective enforcement** based on profile maturity for a GNOME/Wayland/Pipewire workstation:

```bash
# Core system services — enforce all
aa-enforce /etc/apparmor.d/systemd/*
aa-enforce /etc/apparmor.d/dbus/*
aa-enforce /etc/apparmor.d/polkit/*
aa-enforce /etc/apparmor.d/NetworkManager/*
aa-enforce /etc/apparmor.d/sshd

# Desktop environment components
aa-enforce /etc/apparmor.d/gdm/*
aa-enforce /etc/apparmor.d/gnome-shell
aa-enforce /etc/apparmor.d/xwayland

# Audio/video
aa-enforce /etc/apparmor.d/pipewire/*
aa-enforce /etc/apparmor.d/wireplumber

# User services
aa-enforce /etc/apparmor.d/gvfsd/*
aa-enforce /etc/apparmor.d/xdg-dbus-proxy

# Leave in complain mode:
# Browsers (firefox, chromium) — complex user-profile interaction
# Development tools (gcc, python) — compile-time variances
```

**Profile conflict handling**: The Arch `apparmor` package installs base profiles; `apparmor.d` installs its own set. Prefer the `apparmor.d` version for any duplicate:

```bash
# Disable distro profiles superseded by apparmor.d:
# ln -s /dev/null /etc/apparmor.d/disable/usr.bin.<distro-profile>
```

**Local overrides** (site‑specific adjustments without modifying upstream files):

```bash
# /etc/apparmor.d/local/usr.bin.sshd
# Example: allow access to custom sshd config directory
/etc/ssh/sshd_config.d/* r,
```


## Part 4 — Auditd Hardening

```bash
pacman -S audit
systemctl enable auditd.service && systemctl start auditd.service
```

**`/etc/audit/rules.d/99-hardening.rules`**:

```bash
# === 99-hardening.rules — APT-Resistant Auditd Rule Set for Arch/CachyOS ===
# April 2026

-D
-b 8192
-f 2   # panic on failure — audit integrity takes priority for APT threat model

# --- File integrity monitoring ---
-w /etc -p wa -k etc_changes
-w /usr/bin -p wa -k bin_changes
-w /usr/sbin -p wa -k sbin_changes
-w /usr/lib -p wa -k lib_changes
-w /usr/lib64 -p wa -k lib64_changes
-w /boot -p wa -k boot_changes
-w /root -p wa -k root_changes
-w /home -p a -k home_attr_changes
-w /etc/pam.d -p wa -k pam_config
-w /etc/security -p wa -k security_config
-w /etc/apparmor.d -p wa -k apparmor_policy
-w /etc/apparmor.d/local -p wa -k apparmor_local
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d -p wa -k sudoers_changes
-w /etc/ssh -p wa -k ssh_config

# --- Privileged command execution ---
-a always,exit -F arch=b64 -S execve -F euid=0 -k priv_exec_root
-a always,exit -F arch=b64 -S execve -F uid>=1000 -F euid=0 -k priv_escalation
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/su -k su_usage
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/sudo -k sudo_usage

# --- Authentication events ---
-w /etc/pam.d -p wa -k pam_config_changes
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/login -k auth_login

# --- Network socket creation ---
-a always,exit -F arch=b64 -S socket -F success=1 -k net_socket_create
-a always,exit -F arch=b64 -S bind -F success=1 -k net_bind
-a always,exit -F arch=b64 -S connect -F success=1 -k net_connect

# --- Kernel module loading/unloading ---
-w /sbin/insmod -p x -k kmod_insert
-w /sbin/rmmod -p x -k kmod_remove
-w /sbin/modprobe -p x -k kmod_probe
-a always,exit -F arch=b64 -S init_module -S delete_module -k kmod_syscall

# --- User, group, and permission management ---
-w /usr/bin/useradd -p x -k user_add
-w /usr/bin/userdel -p x -k user_del
-w /usr/bin/usermod -p x -k user_mod
-w /usr/bin/groupadd -p x -k group_add
-w /usr/bin/groupdel -p x -k group_del
-w /usr/bin/groupmod -p x -k group_mod
-w /usr/bin/passwd -p x -k passwd_change
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F success=1 -k perm_chmod
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F success=1 -k perm_chown
-a always,exit -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -k perm_xattr

# --- Package manager activity detection (Arch‑specific) ---
-w /usr/bin/pacman -p x -k pkg_pacman
-w /var/lib/pacman/local -p wa -k pkg_pacman_db
-w /usr/bin/paru -p x -k pkg_aur_helper
-w /usr/bin/yay -p x -k pkg_aur_helper
-w /usr/bin/makepkg -p x -k pkg_makepkg

# --- Performance tuning ---
-a never,exclude -F path=/var/log/journal -F perm=r
-a never,exclude -F path=/usr/bin/ls -F perm=x
-a never,exclude -F path=/usr/bin/cat -F perm=x
```

**AppArmor and auditd log distinction**: AppArmor denials appear as `type=1401` (APPARMOR_DENIED) events; auditd rules generate `type=1300` (SYSCALL) events. The monitoring system in Part 14 filters on event type to separate these streams.


## Part 5 — Kernel Hardening (Sysctl)

> This system uses **`linux‑cachyos‑hardened`**, which includes the `linux‑hardened` patch‑set with kernel‑level mitigations. The sysctl rules below supplement those built‑in protections.

**`/etc/sysctl.d/99-hardening.conf`**:

```ini
# === 99-hardening.conf — Kernel Runtime Hardening for CachyOS (April 2026) ===

# --- Network stack hardening ---
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
net.ipv4.icmp_echo_ignore_all = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# --- Kernel pointer/address restrictions ---
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1

# --- ASLR entropy (maximum for x86-64) ---
vm.mmap_rnd_bits = 32
vm.mmap_rnd_compat_bits = 16

# --- Core dump restrictions ---
fs.suid_dumpable = 0
kernel.core_pattern = |/bin/false

# --- BPF hardening ---
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2

# --- ptrace restrictions (scope 2: child-only, balanced for dev workstation) ---
kernel.yama.ptrace_scope = 2

# --- userfaultfd restrictions ---
vm.unprivileged_userfaultfd = 0

# --- perf_event restrictions ---
kernel.perf_event_paranoid = 3

# --- User namespaces ---
# MUST remain enabled — Flatpak and bubblewrap require user namespaces.
# APT groups exploit userns for privilege escalation.
# Trade-off: userns attack surface accepted for Flatpak distribution utility.
# Heavily monitored via auditd.
kernel.unprivileged_userns_clone = 1

# --- Filesystem protections ---
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2

# --- Miscellaneous ---
kernel.sysrq = 0
kernel.kexec_load_disabled = 1
```

**Module loading restriction post‑boot**:

```bash
# /etc/systemd/system/modules-disable.service
[Unit]
Description=Disable kernel module loading after boot
DefaultDependencies=no
After=multi-user.target systemd-modules-load.service

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

> ⚠ Once `modules_disabled=1` is set, it **cannot** be reverted without a reboot. All required modules must be loaded before this service runs.


## Part 6 — Kernel Module Blacklisting

**`/etc/modprobe.d/blacklist-hardening.conf`**:

```bash
# --- Unused filesystems ---
install cramfs /bin/false
install freevxfs /bin/false
install jffs2 /bin/false
install hfs /bin/false
install hfsplus /bin/false
install squashfs /bin/false
install udf /bin/false
# NOTE: fat/vfat NOT blacklisted — needed for ESP access

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
install firewire-core /bin/false
install firewire-ohci /bin/false
install firewire-sbp2 /bin/false

# --- Bluetooth — conditional ---
# If Bluetooth IS needed (peripherals): leave unblacklisted + enforce AppArmor profile
# If Bluetooth is NOT needed: uncomment the lines below
# install bluetooth /bin/false
# install btusb /bin/false

# --- USB over IP ---
install usbip-core /bin/false
```


## Part 7 — IOMMU and DMA Protection

**Required UEFI/BIOS**: Enable **Intel VT‑d** (may be labelled “Intel Virtualization Technology for Directed I/O”). On Z790/i9‑13900K platforms, this is typically under Advanced → CPU Configuration or System Agent Configuration.

**Kernel parameters** (embedded in UKI — Part 1.4):

```
intel_iommu=on iommu=force iommu.strict=1
```

**Rationale**: `iommu=force` places all devices in IOMMU DMA remapping mode — every DMA transfer is translated through the IOMMU page table, preventing devices from DMA‑ing to arbitrary physical addresses. `iommu.strict=1` enables synchronous TLB invalidation on DMA unmap, ensuring mappings are always accurate rather than lazily updated. `intel_iommu` defaults to `on` since kernel 6.8.

**Verification**:

```bash
dmesg | grep -i "iommu\|DMAR"
find /sys/kernel/iommu_groups/ -type d | sort -V
```

**IOMMU + TME interaction**: Complementary, not redundant. IOMMU prevents malicious PCIe devices from DMA‑ing to unauthorised physical addresses. If IOMMU is bypassed, TME still encrypts the DRAM.


## Part 8 — Entropy and Random Number Generation

**Recommendation**: No userspace entropy daemon is installed.

**Rationale**: The kernel’s built‑in CRNG (ChaCha20‑based, seeded with BLAKE2s‑extracted entropy from RDRAND, RDSEED, CPU jitter, and interrupts) is cryptographically sufficient. `/dev/random` and `/dev/urandom` are equivalent on Arch Linux (x86‑64 only). `rng‑tools` is deprecated in several distributions. The kernel CRNG is initialised **before** the initramfs phase — confirmed by `random: crng init done` in early dmesg.

**Verification**:

```bash
dmesg | grep "crng init done"
grep -o 'rdrand' /proc/cpuinfo | head -1
cat /proc/sys/kernel/random/entropy_avail   # → 256
```


## Part 9 — Network Hardening

### 9.1 — Firewalld

```bash
pacman -S firewalld
systemctl enable firewalld.service && systemctl start firewalld.service
firewall-cmd --set-default-zone=drop
```

```bash
# Create a workstation zone
firewall-cmd --permanent --new-zone=workstation
firewall-cmd --permanent --zone=workstation --set-target=DROP
firewall-cmd --permanent --zone=workstation --add-interface=eth0
firewall-cmd --permanent --zone=workstation --add-interface=wlan0

# Allow essential outbound services
firewall-cmd --permanent --zone=workstation --add-service=dhcpv6-client

# Cockpit management (localhost only — see 9.4)
firewall-cmd --permanent --zone=workstation --add-rich-rule='
  rule family="ipv4" source address="127.0.0.1" port port="9090" protocol="tcp" accept'

# SSH (localhost only; expand for specific admin IPs)
firewall-cmd --permanent --zone=workstation --add-rich-rule='
  rule family="ipv4" source address="127.0.0.1" port port="2222" protocol="tcp" accept'

# Block cleartext DNS (port 53 outbound) — enforce encrypted DNS
firewall-cmd --permanent --zone=workstation --add-rich-rule='
  rule family="ipv4" port port="53" protocol="udp" reject'
firewall-cmd --permanent --zone=workstation --add-rich-rule='
  rule family="ipv4" port port="53" protocol="tcp" reject'

firewall-cmd --reload
```

### 9.2 — DNS‑over‑TLS and DNSCrypt via `dnscrypt‑proxy`

**Architecture**: `dnscrypt‑proxy` is the **sole** DNS resolver, listening on `127.0.0.1:53`. `systemd‑resolved` has its stub listener **disabled** (`DNSStubListener=no`) to avoid port conflicts. `systemd‑resolved` is retained only for its NSS module (`nss‑resolve`).

```bash
pacman -S dnscrypt-proxy
```

**`/etc/systemd/resolved.conf`**:

```ini
[Resolve]
DNSStubListener=no
LLMNR=no
MulticastDNS=no
DNSOverTLS=no
DNSSEC=no
Cache=no
DNS=127.0.0.1
```

**`/etc/dnscrypt-proxy/dnscrypt-proxy.toml`** (key sections):

```toml
listen_addresses = ['127.0.0.1:53']
require_dnssec = true
require_nolog = true
require_nofilter = true
anonymized_dns {
    enabled = true
    routes = [
        { server_name = '*', via = ['anon-scaleway', 'anon-cs-nl', 'anon-cs-fr'] },
    ]
}
server_names = ['quad9-dnscrypt-ip4-nofilter-pri', 'cloudflare-security']
cache = true
cache_size = 4096
fallback_resolvers = ['9.9.9.9:53', '1.1.1.1:53']
```

**`/etc/resolv.conf`**:

```bash
echo "nameserver 127.0.0.1" > /etc/resolv.conf
chattr +i /etc/resolv.conf   # Immutable — prevents modification
```

```bash
systemctl enable dnscrypt-proxy.service && systemctl start dnscrypt-proxy.service
systemctl enable systemd-resolved.service && systemctl start systemd-resolved.service
```

### 9.3 — Hardened NetworkManager

**`/etc/NetworkManager/conf.d/99-hardening.conf`**:

```ini
[main]
no-auto-default=*

[connectivity]
enabled=false

[keyfile]
unmanaged-devices=except:type:wifi,except:type:ethernet
```

**`/etc/NetworkManager/conf.d/99-mac-randomization.conf`**:

```ini
[device]
wifi.scan-rand-mac-address=yes

[connection]
ethernet.cloned-mac-address=random
wifi.cloned-mac-address=random
```

**WiFi connection hardening**:

```bash
nmcli connection modify "SSID_NAME" \
  802-11-wireless-security.key-mgmt sae \
  802-11-wireless-security.wps-method 0 \
  connection.zone workstation
```

### 9.4 — Cockpit Integration

```bash
pacman -S cockpit cockpit-packagekit
# Remove unused modules to reduce attack surface
```

**`/etc/cockpit/cockpit.conf`**:

```ini
[WebService]
Origins = https://localhost:9090
ProtocolHeader = X-Forwarded-Proto

[Session]
IdleTimeout = 15
```

**AppArmor profile**: As of April 2026, the `apparmor.d` project does **not** ship a dedicated Cockpit profile. Compensating controls:
- Cockpit restricted to localhost via own config + firewalld
- Hardened via `svc‑harden.py` (Part 12)
- Remote access via SSH port‑forwarding: `ssh -L 9090:localhost:9090 user@host`
- Auditd monitors `/etc/cockpit/` and `/usr/share/cockpit/`


## Part 10 — SSH Hardening

> **OpenSSH 10.0 (April 2025)** introduced `mlkem768x25519‑sha256` as the default post‑quantum hybrid key exchange. This configuration includes both post‑quantum hybrid algorithms. Excluding them would be a significant security regression.

**`/etc/ssh/sshd_config`**:

```ini
Port 2222
Protocol 2
HostKey /etc/ssh/ssh_host_ed25519_key

# Authentication
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
GSSAPIAuthentication no
AllowUsers ahsan
AllowGroups wheel

# Key algorithms — Ed25519 and ECDSA with NIST P‑521 minimum
HostKeyAlgorithms ssh-ed25519,ecdsa-sha2-nistp521
PubkeyAcceptedKeyTypes ssh-ed25519,ecdsa-sha2-nistp521

# Key exchange — include post‑quantum hybrid algorithms
# mlkem768x25519-sha256: default since OpenSSH 10.0 (NIST‑standardised)
# sntrup761x25519-sha512: earlier PQ hybrid (OpenSSH ≥ 9.0)
KexAlgorithms mlkem768x25519-sha256,sntrup761x25519-sha512,curve25519-sha256,curve25519-sha256@libssh.org

# MACs — Encrypt‑then‑MAC only
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

# Ciphers — AEAD only
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com

# Connection hardening
LoginGraceTime 30
MaxAuthTries 3
MaxStartups 3:50:10
MaxSessions 5
ClientAliveInterval 60
ClientAliveCountMax 5

# Forwarding restrictions
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
AllowStreamLocalForwarding no

PrintMotd no
PrintLastLog yes
Subsystem sftp /usr/lib/ssh/sftp-server
```

**`/etc/ssh/ssh_config`** (client):

```ini
Host *
    HostKeyAlgorithms ssh-ed25519,ecdsa-sha2-nistp521
    PubkeyAcceptedKeyTypes ssh-ed25519,ecdsa-sha2-nistp521
    KexAlgorithms mlkem768x25519-sha256,sntrup761x25519-sha512,curve25519-sha256,curve25519-sha256@libssh.org
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
    PasswordAuthentication no
    StrictHostKeyChecking ask
    ConnectTimeout 10
    ServerAliveInterval 30
    ServerAliveCountMax 3
```

**Non‑default port analysis**: Port 2222 drastically reduces log noise from mass scanners but provides **zero** security against a targeted APT actor who will port‑scan. The actual security comes from Ed25519 key‑only auth and the AppArmor sshd profile. The `apparmor.d` project ships an sshd profile (`/etc/apparmor.d/usr.sbin.sshd`). Verify with `aa-status | grep sshd`.

**`/etc/ssh/sshd_config.d/99-rate-limit.conf`** (separate drop‑in for rate limiting):

```ini
PerSourceMaxStartups 5
PerSourceNetBlockSize 32:60
```


## Part 11 — PAM and Authentication Hardening

**`/etc/security/faillock.conf`**:

```ini
deny = 5
unlock_time = 900
fail_interval = 900
even_deny_root
dir = /var/run/faillock
audit
```

Unlock: `faillock --user ahsan --reset`

**`/etc/security/pwquality.conf`**:

```ini
minlen = 15
minclass = 3
maxrepeat = 2
maxclassrepeat = 3
dictcheck = 1
usercheck = 1
enforcing = 1
difok = 8
```

**`/etc/security/limits.conf`** additions:

```ini
@wheel          hard    nproc           4096
@wheel          hard    nofile          65536
@wheel          hard    memlock         65536
*               hard    core            0
```

**PAM stack** — modify `/etc/pam.d/system-auth`:

```
#%PAM-1.0
auth       required                    pam_faillock.so      preauth
auth       required                    pam_unix.so          sha512 shadow nullok rounds=65536
auth       [default=die]               pam_faillock.so      authfail
auth       sufficient                  pam_faillock.so      authsucc

account    required                    pam_unix.so
account    required                    pam_faillock.so

password   required                    pam_pwquality.so
password   required                    pam_unix.so          sha512 shadow rounds=65536

session    required                    pam_limits.so
session    required                    pam_unix.so
session    required                    pam_umask.so         umask=0077
```

Similarly add `pam_faillock` to `/etc/pam.d/sudo`:

```
auth       required                    pam_faillock.so      preauth
auth       required                    pam_unix.so
auth       [default=die]               pam_faillock.so      authfail
account    required                    pam_unix.so
account    required                    pam_faillock.so
session    required                    pam_unix.so
```


## Part 12 — Systemd Service Hardening (`svc-harden.py`)

A Python 3 CLI tool for per‑service hardening via `systemd‑analyze security`. Operates on **individual services only** — bulk application is explicitly rejected because hardening directives have service‑specific effects and blanket application causes breakage.

**Subcommands**: `analyze`, `apply`, `test`, `revert`, `bisect`, `log`. The tool uses `systemd‑analyze security` to identify missing hardening directives, interactively prompts the user to select which to apply, writes drop‑in override files to `/etc/systemd/system/<service>.d/hardening.conf`, and maintains its own audit log.

```python
#!/usr/bin/env python3
"""
svc-harden.py — Systemd Service Hardening Tool (April 2026)
Per-service interactive hardening using systemd-analyze security.
Threat model: APT actors exploiting weakly-configured systemd services
for persistence, privilege escalation, and lateral movement.
"""

import argparse, json, os, subprocess, sys, time
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, List, Dict, Any

AUDIT_LOG_PATH = "/var/log/svc-harden-audit.json"
OVERRIDE_DIR = "/etc/systemd/system"

DIRECTIVES = [
    "PrivateTmp", "PrivateDevices", "ProtectSystem", "ProtectHome",
    "NoNewPrivileges", "CapabilityBoundingSet", "AmbientCapabilities",
    "SystemCallFilter", "SystemCallArchitectures", "RestrictAddressFamilies",
    "MemoryDenyWriteExecute", "RestrictNamespaces", "ProtectKernelTunables",
    "ProtectKernelModules", "ProtectKernelLogs", "ProtectControlGroups",
    "LockPersonality", "RestrictRealtime", "PrivateNetwork", "IPAddressDeny",
    "ProtectClock", "ProtectHostname", "UMask", "RemoveIPC", "PrivateUsers",
]

RECOMMENDED_VALUES = {
    "PrivateTmp": "yes", "PrivateDevices": "yes", "ProtectSystem": "full",
    "ProtectHome": "yes", "NoNewPrivileges": "yes",
    "CapabilityBoundingSet": "~CAP_SYS_ADMIN ~CAP_SYS_PTRACE ~CAP_SYS_MODULE",
    "MemoryDenyWriteExecute": "yes",
    "RestrictNamespaces": "~cgroup ~ipc ~net ~mnt ~pid ~user ~uts",
    "ProtectKernelTunables": "yes", "ProtectKernelModules": "yes",
    "ProtectKernelLogs": "yes", "ProtectControlGroups": "yes",
    "LockPersonality": "yes", "RestrictRealtime": "yes",
    "ProtectClock": "yes", "ProtectHostname": "yes",
    "UMask": "0077", "RemoveIPC": "yes",
    "SystemCallArchitectures": "native",
}

# Directives that require service-specific evaluation
UNSAFE_DIRECTIVES = [
    "PrivateNetwork", "PrivateUsers", "IPAddressDeny",
    "SystemCallFilter", "RestrictAddressFamilies", "AmbientCapabilities",
]


def audit_log(entry: Dict[str, Any]) -> None:
    entry["timestamp"] = datetime.now(timezone.utc).isoformat()
    try:
        p = Path(AUDIT_LOG_PATH); p.parent.mkdir(parents=True, exist_ok=True)
        entries = json.loads(p.read_text()) if p.exists() and p.stat().st_size > 0 else []
        entries.append(entry); p.write_text(json.dumps(entries, indent=2))
    except Exception as e:
        print(f"ERROR: audit log: {e}", file=sys.stderr)


def run_analyze(service: str) -> Optional[str]:
    try:
        r = subprocess.run(["systemd-analyze", "security", service],
                           check=True, capture_output=True, text=True)
        return r.stdout
    except subprocess.CalledProcessError as e:
        print(f"ERROR: {e.stderr}", file=sys.stderr); return None


def parse_analyze(output: str) -> Dict[str, Any]:
    parsed = {"score": None, "missing": []}
    for line in output.splitlines():
        if "Overall exposure level" in line:
            try: parsed["score"] = float(line.split(":")[-1].strip().split()[0])
            except: pass
        for d in DIRECTIVES:
            if d in line and ("✘" in line or "×" in line):
                if d not in parsed["missing"]: parsed["missing"].append(d)
    return parsed


def override_path(service: str) -> Path:
    return Path(OVERRIDE_DIR) / f"{service.replace('.service','')}.service.d" / "hardening.conf"


def apply_directives(service: str, directives: Dict[str, str], dry_run: bool = False) -> bool:
    p = override_path(service)
    content = ["# Auto-generated by svc-harden.py",
               f"# Date: {datetime.now(timezone.utc).isoformat()}", "[Service]"]
    content += [f"{k}={v}" for k, v in directives.items()] + [""]
    if dry_run:
        print(f"[DRY RUN] Would write: {p}\n" + "\n".join(content)); return True
    try:
        p.parent.mkdir(parents=True, exist_ok=True); p.write_text("\n".join(content))
        print(f"✓ Wrote: {p}"); return True
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr); return False


def reload_restart(service: str, dry_run: bool = False) -> bool:
    if dry_run:
        print(f"[DRY RUN] daemon-reload + restart {service}"); return True
    try:
        subprocess.run(["systemctl", "daemon-reload"], check=True)
        subprocess.run(["systemctl", "restart", service], check=True)
        time.sleep(2)
        r = subprocess.run(["systemctl", "is-active", service], capture_output=True, text=True)
        ok = "active" in r.stdout
        print(f"{'✓' if ok else '⚠'} {service}: {r.stdout.strip()}")
        return ok
    except subprocess.CalledProcessError as e:
        print(f"ERROR: {e}", file=sys.stderr); return False


def cmd_analyze(args) -> None:
    svc = args.service if args.service.endswith(".service") else args.service + ".service"
    out = run_analyze(svc)
    if out is None: return
    parsed = parse_analyze(out)
    print(out)
    if parsed["score"] is not None:
        print(f"\nExposure Score: {parsed['score']:.1f} (lower = better)")
    if parsed["missing"]:
        print(f"\nRecommended hardening ({len(parsed['missing'])} missing):")
        for d in parsed["missing"]:
            tag = " ⚠ POTENTIALLY UNSAFE" if d in UNSAFE_DIRECTIVES else ""
            print(f"  {'⚠' if d in UNSAFE_DIRECTIVES else '✓'} {d}{tag}")


def cmd_apply(args) -> None:
    svc = args.service if args.service.endswith(".service") else args.service + ".service"
    if svc in ("*.service", "all", "*"):
        print("ERROR: Bulk application is NOT supported. Specify an individual service.",
              file=sys.stderr); sys.exit(1)
    out = run_analyze(svc)
    if out is None: return
    parsed = parse_analyze(out)
    if not parsed["missing"]:
        print("No missing directives."); return
    selected = {}
    for d in parsed["missing"]:
        val = RECOMMENDED_VALUES.get(d, "yes")
        tag = " ⚠ POTENTIALLY UNSAFE" if d in UNSAFE_DIRECTIVES else ""
        print(f"\n  {d}{tag}  (recommended: {val})")
        try:
            ch = input("  [Y]es/[N]o/[S]kip all/[V]alue: ").strip().upper()
            if ch == "S": break
            elif ch == "N": continue
            elif ch == "V": selected[d] = input(f"  Value for {d}: ").strip()
            else: selected[d] = val
        except (EOFError, KeyboardInterrupt):
            print("\nAborted."); return
    if not selected: print("Nothing selected."); return
    print("\nSelected:" + "\n".join(f"  {k}={v}" for k, v in selected.items()))
    try:
        if input("\nType 'APPLY': ").strip() != "APPLY": print("Aborted."); return
    except (EOFError, KeyboardInterrupt): print("\nAborted."); return
    if apply_directives(svc, selected, args.dry_run):
        audit_log({"action": "apply", "service": svc, "directives": selected})
        if not args.dry_run: reload_restart(svc)


def cmd_test(args) -> None:
    svc = args.service if args.service.endswith(".service") else args.service + ".service"
    ok = reload_restart(svc, args.dry_run)
    if ok and args.test_command:
        print(f"\nRunning: {args.test_command}")
        try:
            subprocess.run(args.test_command, shell=True, check=True)
            print("✓ Test passed")
        except subprocess.CalledProcessError:
            print("⚠ Test failed")
    audit_log({"action": "test", "service": svc, "success": ok})


def cmd_revert(args) -> None:
    svc = args.service if args.service.endswith(".service") else args.service + ".service"
    p = override_path(svc)
    if not p.exists(): print(f"No override for {svc}"); return
    if args.dry_run: print(f"[DRY RUN] Remove: {p}"); return
    p.unlink()
    if p.parent.exists() and not any(p.parent.iterdir()): p.parent.rmdir()
    print(f"✓ Removed override for {svc}")
    subprocess.run(["systemctl", "daemon-reload"], check=True)
    subprocess.run(["systemctl", "restart", svc], check=True)
    audit_log({"action": "revert", "service": svc})


def cmd_bisect(args) -> None:
    svc = args.service if args.service.endswith(".service") else args.service + ".service"
    p = override_path(svc)
    if not p.exists(): print(f"No override for {svc}"); return
    directives = {}
    for line in p.read_text().splitlines():
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            if k in DIRECTIVES: directives[k] = v
    if not directives: print("No directives found."); return
    print(f"Bisecting {svc} ({len(directives)} directives)...")
    problematic = None
    for d, v in directives.items():
        apply_directives(svc, {d: v}, args.dry_run)
        if not args.dry_run:
            if reload_restart(svc): print(f"  ✓ {d}={v}")
            else: print(f"  ✗ {d}={v} BREAKS"); problematic = d; break
    if problematic and not args.dry_run:
        working = {k: v2 for k, v2 in directives.items() if k != problematic}
        apply_directives(svc, working); reload_restart(svc)
        print(f"\nProblematic: {problematic}. Options: (a) remove it [done] (b) revert all (c) keep")
        try:
            ch = input("Choice [a/b/c]: ").strip().lower()
            if ch == "b": cmd_revert(args)
        except: pass
        audit_log({"action": "bisect", "service": svc, "problematic": problematic,
                    "resolution": "removed_problematic"})
    elif not problematic:
        print("All directives safe individually — interaction problem likely.")
        audit_log({"action": "bisect", "service": svc, "problematic": None,
                    "resolution": "no_single_cause"})


def cmd_log(args) -> None:
    try:
        entries = json.loads(Path(AUDIT_LOG_PATH).read_text())
        print(f"Audit log: {AUDIT_LOG_PATH}\nTotal: {len(entries)}")
        for e in entries[-20:]:
            print(f"  {'✓' if e.get('success',True) else '✗'} [{e.get('timestamp','?')}] "
                  f"{e.get('action')} {e.get('service','?')}")
        print("\nHardened services:")
        found = False
        for p in sorted(Path(OVERRIDE_DIR).glob("*.service.d/hardening.conf")):
            print(f"  - {p.parent.parent.name}"); found = True
        if not found: print("  (none)")
    except (FileNotFoundError, json.JSONDecodeError):
        print("No audit log found.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Systemd Service Hardening Tool")
    parser.add_argument("--dry-run", action="store_true")
    sub = parser.add_subparsers(dest="command")
    ap = sub.add_parser("analyze"); ap.add_argument("service")
    bp = sub.add_parser("apply"); bp.add_argument("service")
    cp = sub.add_parser("test"); cp.add_argument("service")
    cp.add_argument("--test-command")
    dp = sub.add_parser("revert"); dp.add_argument("service")
    ep = sub.add_parser("bisect"); ep.add_argument("service")
    sub.add_parser("log")
    args = parser.parse_args()
    cmds = {"analyze": cmd_analyze, "apply": cmd_apply, "test": cmd_test,
            "revert": cmd_revert, "bisect": cmd_bisect, "log": cmd_log}
    if args.command in cmds: cmds[args.command](args)
    else: parser.print_help(); sys.exit(1)


if __name__ == "__main__":
    main()
```


## Part 13 — Supply Chain Monitoring

**GPG signature enforcement**: Verify in `/etc/pacman.conf`:

```ini
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional
```

**Pacman post‑install audit hook** (`/etc/pacman.d/hooks/99-pkgman-audit.hook`):

```ini
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Operation = Remove

[Action]
Description = Log package operations to audit log
When = PostTransaction
Exec = /usr/local/bin/pkgman-audit-hook
```

**CVE monitoring with `arch‑audit`**:

```bash
pacman -S arch-audit
arch-audit
```

Weekly scan timer:

```bash
# /etc/systemd/system/cve-scan.service
[Unit]
Description=Weekly CVE vulnerability scan
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/arch-audit --upgradable --color never

# /etc/systemd/system/cve-scan.timer
[Unit]
Description=Weekly CVE scan
[Timer]
OnCalendar=weekly
Persistent=true
[Install]
WantedBy=timers.target
```

```bash
systemctl enable cve-scan.timer
```

**CachyOS‑specific advisories**: As of April 2026, CachyOS does **not** publish a dedicated security advisory feed separate from Arch Linux’s security tracker. Monitor `https://security.archlinux.org/` and `https://github.com/CachyOS/distribution/issues`.


## Part 14 — Ongoing Monitoring, Log Review, and Vulnerability Alerting

**Destination**: `aahsnr041@proton.me`

**Mail relay**: Use `msmtp` relaying through **Proton Mail Bridge** (local IMAP/SMTP, end‑to‑end encrypted — preferred) or a third‑party SMTP relay with TLS.

```bash
pacman -S msmtp
```

**`/etc/msmtprc`**:

```
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        proton
host           localhost
port           1025
from           aahsnr041@proton.me

account default : proton
```

```bash
chmod 600 /etc/msmtprc
```

**Daily summary** (`/usr/local/lib/monitoring/daily-summary.sh`): Parses auditd logs for authentication failures, privilege escalations, kernel module events, package operations, AppArmor denial counts, and firewall drops — emails to the Proton Mail address.

**Weekly CVE report** (`/usr/local/lib/monitoring/weekly-cve-report.sh`): Runs `arch‑audit --upgradable` and emails results.

**Real‑time alerting**: Triggered for high‑severity auditd rule hits — immediate email via `msmtp`.

**AppArmor denial summary**: Weekly digest of `type=1401` events from journald, grouped by profile and operation.

**Systemd timers**:

```bash
# Daily and weekly timers enabled
systemctl enable daily-audit-summary.timer weekly-cve-scan.timer
```


## Part 15 — Emergency Disaster Recovery

### 15.1 — Recovery USB preparation

Create a bootable Arch Linux live USB with all required recovery tools pre‑staged:

```bash
# On a separate machine:
dd if=archlinux-2026.04.01-x86_64.iso of=/dev/sdX bs=4M status=progress
```

Boot the USB, then install tools: `pacman -Sy arch-install-scripts cryptsetup lvm2 btrfs-progs sbctl systemd dracut snapper`

### 15.2 — System unlock and mount from live environment

```bash
# TPM2+PIN unavailable from live environment — use the recovery key
cryptsetup luksOpen /dev/nvme0n1 crypt0
cryptsetup luksOpen /dev/nvme1n1 crypt1
vgchange -ay vg0

# Mount Btrfs top‑level (subvolid=5)
mount -o subvolid=5 /dev/mapper/vg0-lv_main /mnt

# List available snapshots
grep '<date>' /mnt/@snapshots/*/info.xml

# Non‑destructive rollback
snapper -c root --ambit classic rollback <snapshot_number>

# Verify
btrfs subvolume get-default /mnt
umount -R /mnt
reboot
```

### 15.3 — Chroot and system restoration

```bash
arch-chroot /mnt
# Verify environment
source /etc/profile
ls /boot/EFI/Linux/arch-cachyos-hardened.efi
```

**Broken UKI/Secure Boot recovery**:

```bash
# Disable Secure Boot in firmware, boot live USB, chroot
dracut --force --uefi /boot/EFI/Linux/arch-cachyos-hardened.efi
sbctl create-keys
sbctl enroll-keys -m
sbctl sign -s /boot/EFI/Linux/arch-cachyos-hardened.efi
sbctl verify
# Exit, unmount, reboot, re‑enable Secure Boot
```

**Broken pacman database recovery**:

```bash
# From within chroot:
cp -a /.snapshots/<number>/snapshot/var/lib/pacman/local/* /var/lib/pacman/local/
pacman -Syy
```

### 15.4 — TPM2 key recovery

**Scenario: TPM state lost** (firmware update, CMOS reset, key rotation). Symptom: TPM2 + PIN unlock fails at boot. Drops to LUKS password prompt.

**Recovery procedure**: Enter the **recovery key** at the LUKS password prompt. This bypasses TPM2. After booting:

```bash
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs="7+11" --tpm2-with-pin=yes /dev/nvme0n1
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs="7+11" --tpm2-with-pin=yes /dev/nvme1n1
```

**Scenario: Secure Boot keys rotated** (PCR 7 changed): Use recovery key to boot, then re‑enroll as above.

**Scenario: UKI re‑signed** (PCR 11 changed): Use recovery key to boot, then re‑enroll as above.

> ⚠ The recovery key must be stored **offline** (paper, safety deposit box, offline encrypted USB). If both the recovery key and TPM2 are unavailable simultaneously, the encrypted data is permanently inaccessible.


## End of Guide

*Guide rewritten April 2026. Verified against: ArchWiki (AppArmor, Dracut, UKI, Secure Boot, dm‑crypt, Snapper, systemd‑cryptenroll, firewalld, auditd, PAM, SSH, Random number generation, Dnscrypt‑proxy), CachyOS Wiki and GitHub repository, kernel.org documentation, `apparmor.d` project documentation, systemd man pages (systemd‑cryptenroll, systemd‑measure, systemd‑analyze), OpenSSH 10.0 release notes and post‑quantum cryptography page, `sbctl` documentation, `arch‑audit` man page, Privacy Guides IOMMU guidance, and Proton Mail Bridge documentation.*
