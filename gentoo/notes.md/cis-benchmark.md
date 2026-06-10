---

# Appendix D — Unified CIS Gentoo Hardening Guide

**Based on:**
- CIS Ubuntu Linux 24.04 LTS Benchmark v1.0.0 (2024‑08‑26)
- CIS Ubuntu Linux 24.04 LTS STIG Benchmark v1.0.0 (2025‑01‑28)

**Adapted for:** Hardened Gentoo Installation — APT Threat Model (April 2026)
**Primary Reference:** `README.md` (Hardened Gentoo Installation Guide)
**Target System:** Gentoo Linux · CachyOS‑sources kernel · UKI direct UEFI boot · TPM2 + PIN LUKS2 · AppArmor (apparmor.d) · systemd‑homed · Btrfs · Firewalld (nftables backend)

---

## Foreword

No official CIS Benchmark or DISA STIG exists for Gentoo Linux. This document fills that gap by translating every recommendation from both the CIS Desktop Benchmark and the DISA STIG overlay into concrete, verifiable steps for the hardened Gentoo workstation described in the accompanying `README.md`.

Two documents are merged here:
- **CIS Ubuntu 24.04 LTS Benchmark** — the general-purpose hardening guide, with Level 1 (practical, prudent) and Level 2 (defence‑in‑depth) profiles.
- **CIS Ubuntu 24.04 LTS STIG Benchmark** — the Department of Defense overlay, with CAT I (high), CAT II (medium), and CAT III (low) severity categories.

Where the STIG is stricter than the general CIS recommendation, the STIG requirement takes precedence in this guide unless a deliberate deviation is justified (see §8).

---

## How to Use This Guide

Each recommendation is a self‑contained block:

1. **Heading** — The CIS recommendation number (e.g., **1.1.1.1**). If a STIG rule applies, its ID is listed beneath (e.g., *STIG: UBTU‑24‑100030*).
2. **Profile & Status** — Which CIS levels and STIG categories apply, plus a quick icon:
   - ✅ **COMPLIANT** — The hardened Gentoo system already satisfies this requirement.
   - ⚠️ **NEEDS REVIEW** — Mostly satisfied, but requires site‑specific customisation or verification.
   - ❌ **INTENTIONAL DEVIATION** — Deliberately not applied, with rationale.
   - 🔵 **NOT APPLICABLE** — Not relevant to a standalone workstation.
3. **What's Required** — A concise, plain‑English description of the requirement.
4. **Gentoo Implementation** — How the target system meets (or intentionally deviates from) the requirement, with references to relevant `README.md` sections.
5. **Audit** — Copy‑paste‑ready commands to verify compliance. A successful audit produces no output or the expected value; anything else warrants investigation.
6. **Remediation** — Copy‑paste‑ready commands to bring the system into compliance. Only shown when the default configuration does not already satisfy the requirement.

> **Convention:** Prompts beginning with `#` denote commands run as root. Prompts beginning with `$` denote commands run as an unprivileged user.

---

## 1. Initial Setup

### 1.1 Filesystem

#### 1.1.1 Configure Filesystem Kernel Modules

---

##### 1.1.1.1 Ensure cramfs kernel module is not available

*STIG: UBTU‑24‑100030 (telnetd, analogous principle)*

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
The `cramfs` kernel module must be prevented from loading. This reduces the local attack surface by removing support for a rarely‑used compressed ROM filesystem that has known vulnerabilities.

**Gentoo Implementation**
`cramfs` is blacklisted via `/etc/modprobe.d/blacklist-hardening.conf` (README Part 16). The configuration uses both `install cramfs /bin/true` (to prevent loading) and `blacklist cramfs` (to prevent auto‑loading).

**Audit**
```bash
modprobe -n -v cramfs 2>&1 | grep -q 'install /bin/true' && \
  echo "✅ cramfs is blocked" || echo "❌ cramfs is NOT blocked"
```

**Remediation**
```bash
echo "install cramfs /bin/true"  > /etc/modprobe.d/cramfs.conf
echo "blacklist cramfs"         >> /etc/modprobe.d/cramfs.conf
dracut --force --regenerate-all
```

---

##### 1.1.1.2 Ensure freevxfs kernel module is not available

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
The `freevxfs` (Veritas filesystem) module must be blocked.

**Gentoo Implementation**
Blacklisted in `blacklist-hardening.conf` (README Part 16).

**Audit**
```bash
modprobe -n -v freevxfs 2>&1 | grep -q 'install /bin/true' && \
  echo "✅ freevxfs is blocked" || echo "❌ freevxfs is NOT blocked"
```

**Remediation**
```bash
echo "install freevxfs /bin/true"  > /etc/modprobe.d/freevxfs.conf
echo "blacklist freevxfs"         >> /etc/modprobe.d/freevxfs.conf
dracut --force --regenerate-all
```

---

##### 1.1.1.3 – 1.1.1.5 Ensure hfs, hfsplus, and jffs2 kernel modules are not available

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
The `hfs`, `hfsplus` (Mac filesystems), and `jffs2` (flash filesystem) modules must be blocked.

**Gentoo Implementation**
All three are blacklisted in `blacklist-hardening.conf` (README Part 16). The block follows the same pattern: `install <module> /bin/true` plus `blacklist <module>`.

**Audit (unified)**
```bash
for mod in hfs hfsplus jffs2; do
    modprobe -n -v "$mod" 2>&1 | grep -q 'install /bin/true' && \
      echo "✅ $mod blocked" || echo "❌ $mod NOT blocked"
done
```

**Remediation (per module)**
```bash
# Replace <module> with hfs, hfsplus, or jffs2
echo "install <module> /bin/true"  > /etc/modprobe.d/<module>.conf
echo "blacklist <module>"         >> /etc/modprobe.d/<module>.conf
dracut --force --regenerate-all
```

---

##### 1.1.1.6 Ensure overlayfs kernel module is not available

**Profile:** CIS Level 2 – Server & Workstation | **Status:** ⚠️ NEEDS REVIEW

**What's Required**
The `overlayfs` module must be blocked. This is a Level 2 (defence‑in‑depth) recommendation because containers (Docker, Podman) depend on overlayfs.

**Gentoo Implementation**
Conditionally blacklisted in `blacklist-hardening.conf` (README Part 16). The comment states: "If you use Flatpak, snap, AppImage, or Docker, comment out the two lines below."

**Audit**
```bash
modprobe -n -v overlay 2>&1 | grep -q 'install /bin/true' && \
  echo "✅ overlay blocked" || echo "⚠️ overlay is loadable (containers may need it)"
```

**Remediation (if no containers are used)**
```bash
echo "install overlay /bin/true"  > /etc/modprobe.d/overlay.conf
echo "blacklist overlay"         >> /etc/modprobe.d/overlay.conf
dracut --force --regenerate-all
```

---

##### 1.1.1.7 – 1.1.1.8 Ensure squashfs and udf kernel modules are not available

**Profile:** CIS Level 2 – Server & Workstation | **Status:** ⚠️ NEEDS REVIEW

**What's Required**
`squashfs` (compressed read‑only, used by Snap/Flatpak) and `udf` (optical disc) modules must be blocked.

**Gentoo Implementation**
Both are conditionally blacklisted in `blacklist-hardening.conf`. Review whether your workload requires them before enabling the blacklist.

**Audit**
```bash
for mod in squashfs udf; do
    modprobe -n -v "$mod" 2>&1 | grep -q 'install /bin/true' && \
      echo "✅ $mod blocked" || echo "⚠️ $mod is loadable"
done
```

**Remediation (if neither Snap/Flatpak nor optical drives are needed)**
```bash
for mod in squashfs udf; do
    echo "install $mod /bin/true"  > /etc/modprobe.d/$mod.conf
    echo "blacklist $mod"         >> /etc/modprobe.d/$mod.conf
done
dracut --force --regenerate-all
```

---

##### 1.1.1.9 Ensure usb‑storage kernel module is not available

*STIG: UBTU‑24‑300039 (CAT II)*

**Profile:** CIS Level 1 – Server / Level 2 – Workstation · STIG CAT II | **Status:** ⚠️ NEEDS REVIEW

**What's Required**
The `usb‑storage` module must be blocked to prevent USB mass storage devices from being used. The STIG requires both `install usb‑storage /bin/true` and `blacklist usb‑storage`.

**Gentoo Implementation**
Conditionally blacklisted in `blacklist-hardening.conf` (README Part 16). The comment states it is "required for recovery USB boot." If USB storage is not routinely needed, enable the blacklist. For a workstation that uses the STIG profile, this should be fully blocked.

**Audit**
```bash
modprobe -n -v usb-storage 2>&1 | grep -q 'install /bin/true' && \
  modprobe -n -v usb-storage 2>&1 | grep -q 'blacklist' && \
  echo "✅ usb-storage fully blocked" || echo "❌ usb-storage NOT fully blocked"
```

**Remediation**
```bash
echo "install usb-storage /bin/true"  > /etc/modprobe.d/usb-storage.conf
echo "blacklist usb-storage"         >> /etc/modprobe.d/usb-storage.conf
dracut --force --regenerate-all
```

---

##### 1.1.1.10 Ensure unused filesystems kernel modules are not available (Manual)

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
Review all loaded filesystem modules and disable any not required for the system's function.

**Gentoo Implementation**
README Part 16 blacklists cover the most common attack vectors. The administrator must manually review loaded filesystem modules.

**Audit**
```bash
# List all loaded filesystem-related modules
lsmod | awk '{print $1}' | grep -E 'fs$|_fs'
# Review each and determine if it is required for normal operation
```

**Remediation**
For any module identified as unnecessary, follow the pattern established in 1.1.1.1–1.1.1.9: create a `.conf` file in `/etc/modprobe.d/` with `install <module> /bin/true` and `blacklist <module>`, then rebuild the initramfs.

---

#### 1.1.2 Configure Filesystem Partitions

The target Gentoo system uses **Btrfs subvolumes with appropriate mount options** rather than separate physical partitions for each directory. This provides equivalent — and in some cases superior — isolation because each subvolume can be snapshotted independently, and Btrfs honours mount options identically to a separate partition.

All seven CIS partition requirements are satisfied by the layout described in README Part 4 (Btrfs subvolume creation) and Part 11 (fstab):

| Directory | Required Mount Options | Gentoo Implementation |
|-----------|----------------------|----------------------|
| `/tmp` | `nosuid,nodev,noexec` | `subvol=@/tmp` — tmpfs with `nosuid,nodev,noexec` |
| `/dev/shm` | `nosuid,nodev,noexec` | tmpfs with `nosuid,nodev,noexec` |
| `/home` | `nosuid,nodev` (sep. partition at L2) | `subvol=@/home` + systemd‑homed LUKS2 per‑user encryption |
| `/var` | `nosuid,nodev` (sep. partition at L2) | `subvol=@/var` (CoW disabled via `chattr +C`) |
| `/var/tmp` | `nosuid,nodev,noexec` | `subvol=@/var/tmp` (CoW disabled) |
| `/var/log` | `nosuid,nodev,noexec` | `subvol=@/var/log` |
| `/var/log/audit` | `nosuid,nodev,noexec` | `subvol=@/var/log/audit` |

**Unified Audit**
```bash
#!/bin/bash
# Verify all critical directories have correct mount options
for mp in /tmp /dev/shm /home /var /var/tmp /var/log /var/log/audit; do
    echo "=== $mp ==="
    findmnt -kn "$mp" 2>/dev/null || echo "  NOT MOUNTED"
done
```

---

### 1.2 Package Management

---

##### 1.2.1.1 Ensure GPG keys are configured (Manual)

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
Package manager must verify package integrity using GPG key signing.

**Gentoo Implementation**
Gentoo uses Portage with Git commit signature verification. The `repos.conf` entry for `::gentoo` includes `sync-git-verify-commit-signature = yes` and references the Gentoo release OpenPGP key. Additionally, `app-portage/gemato` provides full‑tree Manifest verification (README Part 21.2).

**Audit**
```bash
grep 'sync-git-verify-commit-signature' /etc/portage/repos.conf/gentoo.conf
# Must show: sync-git-verify-commit-signature = yes
```

**Remediation**
```bash
cat > /etc/portage/repos.conf/gentoo.conf << 'EOF'
[DEFAULT]
main-repo = gentoo

[gentoo]
location = /var/db/repos/gentoo
sync-type = git
sync-uri = https://github.com/gentoo-mirror/gentoo.git
auto-sync = yes
sync-git-verify-commit-signature = yes
sync-openpgp-key-path = /usr/share/openpgp-keys/gentoo-release.asc
EOF
```

---

##### 1.2.2.1 Ensure updates, patches, and additional security software are installed (Manual)

*STIG: UBTU‑24‑700400 (vendor‑supported release, CAT II)*

**Profile:** CIS Level 1 – Server & Workstation · STIG CAT II | **Status:** ✅ COMPLIANT

**What's Required**
The system must receive regular security updates from a supported source.

**Gentoo Implementation**
Gentoo is a rolling‑release distribution. As long as `emerge --sync` runs regularly, the system receives continuous security updates. The weekly GLSA scan (`glsa-check`) identifies any packages affected by published vulnerabilities (README Part 21.4).

**Audit**
```bash
# Verify the Portage tree has been synced within the last 7 days
find /var/db/repos/gentoo/metadata/timestamp.chk -mtime -7 2>/dev/null && \
  echo "✅ Synced within last 7 days" || echo "⚠️ Tree may be stale"

# Check for GLSA-affected packages
glsa-check --list affected 2>/dev/null
```

**Remediation**
```bash
emerge --sync
glsa-check --fix affected 2>/dev/null
```

---

### 1.3 Mandatory Access Control — AppArmor

---

##### 1.3.1.1 Ensure AppArmor is installed

*STIG: UBTU‑24‑100500 (CAT II)*

**Profile:** CIS Level 1 – Server & Workstation · STIG CAT II | **Status:** ✅ COMPLIANT

**What's Required**
The `apparmor` package must be installed. The STIG also requires `apparmor‑utils`.

**Gentoo Implementation**
`sys‑apps/apparmor`, `sys‑apps/apparmor‑utils`, and `sec‑policy/apparmor‑profiles` are emerged. Additionally, the `apparmor.d` profile set (~1500 profiles) is installed from source (README Part 14.1).

**Audit**
```bash
qpkg -I apparmor && echo "✅ AppArmor installed" || echo "❌ AppArmor NOT installed"
ls /lib64/security/pam_apparmor.so && echo "✅ PAM module present" || echo "⚠️ PAM module missing"
```

**Remediation**
```bash
emerge --ask sys-apps/apparmor sys-apps/apparmor-utils sec-policy/apparmor-profiles
```

---

##### 1.3.1.2 Ensure AppArmor is enabled in the bootloader configuration

*STIG: UBTU‑24‑100510 (CAT II)*

**Profile:** CIS Level 1 – Server & Workstation · STIG CAT II | **Status:** ✅ COMPLIANT — **exceeds requirement**

**What's Required**
AppArmor must be activated at boot time via `apparmor=1` and `security=apparmor` kernel parameters. The CIS benchmark assumes GRUB; the STIG requires the service to be enabled and active.

**Gentoo Implementation**
The target system does not use GRUB. Instead, the UKI (Unified Kernel Image) embeds `apparmor=1 security=apparmor` in its command line (README Part 8.2). The kernel is compiled with `CONFIG_LSM="lockdown,yama,apparmor,bpf"`. Secure Boot prevents tampering with the UKI. The `apparmor.service` is enabled and active.

This **exceeds** the CIS requirement: there is no plaintext bootloader configuration to protect, and the UKI is cryptographically verified by Secure Boot before execution.

**Audit**
```bash
cat /proc/cmdline | grep -o 'apparmor=1'
# Must output: apparmor=1
cat /proc/cmdline | grep -o 'security=apparmor'
# Must output: security=apparmor
systemctl is-active apparmor.service
# Must output: active
```

**Remediation**
```bash
systemctl unmask apparmor.service 2>/dev/null || true
systemctl enable --now apparmor.service
```

---

##### 1.3.1.3 Ensure all AppArmor Profiles are in enforce or complain mode

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
All installed AppArmor profiles must be loaded and in either enforce or complain mode. No processes should be unconfined.

**Gentoo Implementation**
Approximately 1500 profiles from the `apparmor.d` project are loaded (README Part 14.3). The project recommends installing in complain mode first, then switching to enforce after a testing period.

**Audit**
```bash
aa-status | head -10
# Verify: "apparmor module is loaded." and "N profiles are loaded."
aa-status | grep -E 'processes are unconfined'
# Should show: 0 processes are unconfined
```

**Remediation**
```bash
# Load all profiles in complain mode (initial deployment)
aa-complain /etc/apparmor.d/*
# After testing, switch to enforce
aa-enforce /etc/apparmor.d/*
```

---

##### 1.3.1.4 Ensure all AppArmor Profiles are enforcing

**Profile:** CIS Level 2 – Server & Workstation | **Status:** ⚠️ NEEDS REVIEW

**What's Required**
Every AppArmor profile must be in enforce mode — no profiles in complain mode.

**Gentoo Implementation**
Critical system profiles (sshd, systemd, dbus, polkit, firewalld) are in enforce mode. Some user‑application profiles remain in complain mode pending site‑specific tuning (README Part 14.6). The `apparmor.d` project strongly recommends a minimum one‑week testing period in complain mode before enforcing.

**Audit**
```bash
aa-status | grep 'profiles are in complain mode'
# The number should be as close to 0 as possible
```

**Remediation (after thorough testing)**
```bash
aa-enforce /etc/apparmor.d/*
systemctl reload apparmor.service
```

---

### 1.4 Configure Bootloader

---

##### 1.4.1 Ensure bootloader password is set

*STIG: UBTU‑24‑102000 (CAT I)*

**Profile:** CIS Level 1 – Server & Workstation · STIG CAT I | **Status:** ✅ COMPLIANT — **exceeds requirement**

**What's Required**
A password must be required to modify boot parameters or enter single‑user mode. The CIS benchmark assumes GRUB2 with `password_pbkdf2`. The STIG requires authentication before booting into single‑user or maintenance modes.

**Gentoo Implementation**
The target system **does not use GRUB2 at all**. It uses UKI + direct UEFI boot with Secure Boot (README Parts 7‑9). This architecture provides **stronger** protection:

1. The UKI is a signed PE binary — any modification invalidates the Secure Boot signature, and the firmware refuses to load it.
2. There is no GRUB shell, no single‑user mode accessible from the boot menu, and no kernel command‑line editor that an attacker could use.
3. The TPM2 + PIN requirement (README Part 10) means the root filesystem cannot be decrypted without both physical possession of the TPM **and** knowledge of the PIN.

There is no plaintext bootloader password because there is no bootloader. This is a deliberate architectural decision that **exceeds** the CIS and STIG requirements.

**Audit**
```bash
sbctl status
# Must show: "Installed: ✓" and "Secure Boot: ✓ Enabled"

# Verify no GRUB installation exists
qpkg -I grub 2>/dev/null && echo "⚠️ GRUB is installed (unexpected)" || echo "✅ GRUB not installed"

# Verify UKIs on the ESP are signed
sbctl verify | grep -E '/efi/EFI/Linux/.*\.efi'
# All entries must show "✓ signed"
```

---

##### 1.4.2 Ensure access to bootloader config is configured

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT — **exceeds requirement**

**What's Required**
The GRUB configuration file (`/boot/grub/grub.cfg`) must be owned by `root:root` and have mode `0600` or more restrictive.

**Gentoo Implementation**
No GRUB configuration file exists. The ESP contains only signed `.efi` binaries (the UKIs). The ESP is mounted at `/efi` with `noatime` and does not contain any plaintext configuration files that could reveal boot parameters or weaken security.

**Audit**
```bash
# Verify no GRUB config exists
[ ! -f /boot/grub/grub.cfg ] && echo "✅ No GRUB config (UKI system)"

# Verify ESP contents are only signed binaries
ls -la /efi/EFI/Linux/
# Should show only .efi files

# Verify ESP mount options
findmnt -kn /efi
# Should include noatime
```

---

### 1.5 Configure Additional Process Hardening

---

##### 1.5.1 Ensure address space layout randomization (ASLR) is enabled

*STIG: UBTU‑24‑700310 (CAT II)*

**Profile:** CIS Level 1 – Server & Workstation · STIG CAT II | **Status:** ✅ COMPLIANT

**What's Required**
`kernel.randomize_va_space` must be set to `2` (full randomization). The STIG audit specifically checks for value `2`; value `3` (which some kernels support) would cause a STIG audit failure despite being more secure.

**Gentoo Implementation**
The `cachyos‑sources` kernel defaults to `kernel.randomize_va_space=2`. The UKI cmdline includes `mitigations=auto` which enables all relevant CPU vulnerability mitigations (README Part 1.5).

**Audit**
```bash
sysctl kernel.randomize_va_space
# Must output: kernel.randomize_va_space = 2

# Verify no override file sets a different value
grep -R "^kernel.randomize_va_space=[^2]" /etc/sysctl.conf /etc/sysctl.d 2>/dev/null && \
  echo "❌ Override found" || echo "✅ No incorrect override"
```

**Remediation**
```bash
printf '%s\n' "kernel.randomize_va_space = 2" > /etc/sysctl.d/60-aslr.conf
sysctl -w kernel.randomize_va_space=2
```

---

##### 1.5.2 Ensure ptrace_scope is restricted

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
`kernel.yama.ptrace_scope` must be set to `1`, `2`, or `3` to restrict the `ptrace()` system call.

**Gentoo Implementation**
Set to `1` (restricted ptrace) via sysctl. Value `1` allows a process to trace only its descendants; this is the recommended setting for a development workstation where debugging is needed. For stricter environments, value `2` (admin‑only) or `3` (completely disabled) may be used.

**Audit**
```bash
sysctl kernel.yama.ptrace_scope
# Must output: kernel.yama.ptrace_scope = 1 (or 2, or 3)
```

**Remediation**
```bash
printf '%s\n' "kernel.yama.ptrace_scope = 1" > /etc/sysctl.d/60-ptrace.conf
sysctl -w kernel.yama.ptrace_scope=1
```

---

##### 1.5.3 Ensure core dumps are restricted

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
Core dumps must be restricted via both `limits.conf` (`* hard core 0`) and the `fs.suid_dumpable` sysctl (`0`).

**Gentoo Implementation**
Both controls are implemented (README Part 1.5). The `systemd‑coredump` service is present but configured to store nothing.

**Audit**
```bash
grep -P '^\*\s+hard\s+core\s+0\b' /etc/security/limits.conf /etc/security/limits.d/*.conf 2>/dev/null && \
  echo "✅ Core dump limit set"
sysctl fs.suid_dumpable
# Must output: fs.suid_dumpable = 0
```

**Remediation**
```bash
echo "* hard core 0" >> /etc/security/limits.d/50-cis-core.conf
printf '%s\n' "fs.suid_dumpable = 0" > /etc/sysctl.d/60-coredump.conf
sysctl -w fs.suid_dumpable=0
# If systemd-coredump is present:
mkdir -p /etc/systemd/coredump.conf.d
printf '[Coredump]\nStorage=none\nProcessSizeMax=0\n' > /etc/systemd/coredump.conf.d/50-cis.conf
systemctl daemon-reload
```

---

##### 1.5.4 Ensure prelink is not installed

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
The `prelink` package must not be installed, as it interferes with AIDE file integrity checking.

**Gentoo Implementation**
`prelink` is not installed on the target system and is not a dependency of any package in the world set.

**Audit**
```bash
qpkg -I prelink 2>/dev/null && echo "❌ prelink is installed" || echo "✅ prelink is not installed"
```

**Remediation**
```bash
emerge --unmerge prelink 2>/dev/null || true
```

---

##### 1.5.5 Ensure Automatic Error Reporting is not enabled

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
The Apport Error Reporting Service must be disabled. Apport collects potentially sensitive data including core dumps, stack traces, and log files.

**Gentoo Implementation**
Apport is an Ubuntu‑specific package and is not present on Gentoo. The equivalent functionality does not exist on the target system.

**Audit**
```bash
qpkg -I apport 2>/dev/null && echo "❌ apport is installed" || echo "✅ apport is not installed"
```

---

##### Additional STIG Rules: Process Hardening

---

##### UBTU‑24‑700300 — NX (No‑Execute) bit must be active

*STIG: UBTU‑24‑700300 (CAT II)*

**Status:** ✅ COMPLIANT

**What's Required**
The CPU must support and have active the NX (No‑Execute) bit, also called XD (Execute Disable) on Intel platforms.

**Gentoo Implementation**
The Intel i9‑13900K (Raptor Lake) supports hardware NX/XD. The `cachyos‑sources` kernel enables this by default.

**Audit**
```bash
dmesg | grep -i "execute disable"
# Expected output: "NX (Execute Disable) protection: active"
grep -w nx /proc/cpuinfo | head -1
# Must include "nx" in the flags field
```

---

##### UBTU‑24‑600140 — Kernel message buffer must be restricted

*STIG: UBTU‑24‑600140 (CAT III)*

**Status:** ✅ COMPLIANT

**What's Required**
`kernel.dmesg_restrict` must be set to `1` to prevent unprivileged users from reading the kernel message buffer.

**Gentoo Implementation**
Set via sysctl. This is also enforced by the hardened Gentoo profile.

**Audit**
```bash
sysctl kernel.dmesg_restrict
# Must output: kernel.dmesg_restrict = 1
```

**Remediation**
```bash
printf '%s\n' "kernel.dmesg_restrict = 1" > /etc/sysctl.d/60-dmesg.conf
sysctl -w kernel.dmesg_restrict=1
```

---

##### UBTU‑24‑600190 — TCP syncookies must be enabled

*STIG: UBTU‑24‑600190 (CAT II)*

**Status:** ✅ COMPLIANT

**What's Required**
`net.ipv4.tcp_syncookies` must be set to `1`.

**Gentoo Implementation**
Enabled via the hardened kernel config and sysctl (README Part 3.3).

**Audit**
```bash
sysctl net.ipv4.tcp_syncookies
# Must output: net.ipv4.tcp_syncookies = 1
```

---

##### UBTU‑24‑300025 / UBTU‑24‑300026 — Ctrl‑Alt‑Delete must be disabled

*STIG: UBTU‑24‑300025 (CAT I, GUI) / UBTU‑24‑300026 (CAT I, system)*

**Status:** ✅ COMPLIANT

**What's Required**
The Ctrl‑Alt‑Delete key sequence must be disabled both in the graphical environment and at the system level.

**Gentoo Implementation**
The `ctrl‑alt‑del.target` is masked (README Part 1.6). The Hyprland/Wayland compositor does not bind Ctrl‑Alt‑Delete to any reboot action.

**Audit**
```bash
systemctl status ctrl-alt-del.target 2>&1 | grep -q "masked" && \
  echo "✅ ctrl-alt-del.target is masked" || echo "❌ ctrl-alt-del.target is NOT masked"
```

**Remediation**
```bash
systemctl mask ctrl-alt-del.target
systemctl daemon-reload
```

---

##### UBTU‑24‑600070 — Kernel core dumps (kdump) must be disabled

*STIG: UBTU‑24‑600070 (CAT II)*

**Status:** ✅ COMPLIANT

**What's Required**
The `kdump` service must be disabled unless required and documented.

**Gentoo Implementation**
`kdump` is not installed on the target system. Kernel crash dumps are not configured.

**Audit**
```bash
systemctl is-active kdump.service 2>/dev/null && echo "❌ kdump is active" || echo "✅ kdump not active / not installed"
```

---

### 1.6 Configure Command‑Line Warning Banners

---

##### 1.6.1 Ensure message of the day is configured properly

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
The `/etc/motd` file must contain an appropriate warning banner and must not include OS version information (`\m`, `\r`, `\s`, `\v` escapes).

**Gentoo Implementation**
A custom warning banner is installed via README Part 25. No OS version escapes are present.

**Audit**
```bash
cat /etc/motd
grep -E '\\\\[mrsv]' /etc/motd && echo "❌ Contains OS version escapes" || echo "✅ No OS version escapes"
```

---

##### 1.6.2 – 1.6.3 Ensure local and remote login warning banners are configured properly

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
Both `/etc/issue` (local login) and `/etc/issue.net` (remote login) must display appropriate warning banners without OS version information.

**Gentoo Implementation**
Both files contain the same custom banner from README Part 25. The SSH daemon is configured to display `/etc/issue.net` via the `Banner` directive (README Part 19.7).

**Audit**
```bash
for f in /etc/issue /etc/issue.net; do
    echo "=== $f ==="
    cat "$f"
    grep -E '\\\\[mrsv]' "$f" && echo "❌ Contains OS info" || echo "✅ Clean"
done
grep -i '^Banner' /etc/ssh/sshd_config
```

---

##### 1.6.4 – 1.6.6 Ensure access to banner files is configured

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
`/etc/motd`, `/etc/issue`, and `/etc/issue.net` must be owned by `root:root` and have mode `0644` or more restrictive.

**Audit**
```bash
for f in /etc/motd /etc/issue /etc/issue.net; do
    [ -f "$f" ] && stat -c '%a %U:%G %n' "$f"
done
# All should show: 644 root:root (or more restrictive)
```

**Remediation**
```bash
for f in /etc/motd /etc/issue /etc/issue.net; do
    [ -f "$f" ] && chown root:root "$f" && chmod 644 "$f"
done
```

---

##### UBTU‑24‑200640 — SSH must display the Standard Mandatory DoD Notice and Consent Banner

*STIG: UBTU‑24‑200640 (CAT II)*

**Status:** ⚠️ NEEDS REVIEW

**What's Required**
The SSH banner must display the exact DoD‑mandated text before authentication.

**Gentoo Implementation**
The SSH daemon is configured with `Banner /etc/ssh/banner` (README Part 19.7). The banner content in README Part 25 is a general warning. For STIG compliance, it must be replaced with the exact DoD text.

**Audit**
```bash
grep -i '^Banner' /etc/ssh/sshd_config
cat /etc/ssh/banner
# Content must match the DoD Standard Mandatory Notice exactly
```

**Remediation (DoD‑compliant banner)**
```bash
cat > /etc/ssh/banner << 'BANNER'
You are accessing a U.S. Government (USG) Information System (IS) that is provided for USG-authorized use only.

By using this IS (which includes any device attached to this IS), you consent to the following conditions:

-The USG routinely intercepts and monitors communications on this IS for purposes including, but not limited to, penetration testing, COMSEC monitoring, network operations and defense, personnel misconduct (PM), law enforcement (LE), and counterintelligence (CI) investigations.

-At any time, the USG may inspect and seize data stored on this IS.

-Communications using, or data stored on, this IS are not private, are subject to routine monitoring, interception, and search, and may be disclosed or used for any USG-authorized purpose.

-This IS includes security measures (e.g., authentication and access controls) to protect USG interests--not for your personal benefit or privacy.

-Notwithstanding the above, using this IS does not constitute consent to PM, LE or CI investigative searching or monitoring of the content of privileged communications, or work product, related to personal representation or services by attorneys, psychotherapists, or clergy, and their assistants. Such communications and work product are private and confidential. See User Agreement for details.
BANNER
systemctl reload sshd
```

---

##### UBTU‑24‑200680 — SSH banner must be acknowledged by the user

*STIG: UBTU‑24‑200680 (CAT II)*

**Status:** ⚠️ NEEDS REVIEW

**What's Required**
Before granting access via SSH, the user must explicitly acknowledge the banner by typing `y` or `Y`.

**Gentoo Implementation**
The STIG provides a supplemental `ssh_confirm.sh` script. This must be installed on Gentoo.

**Audit**
```bash
cat /etc/profile.d/ssh_confirm.sh 2>/dev/null || echo "❌ ssh_confirm.sh not installed"
```

**Remediation**
```bash
cat > /etc/profile.d/ssh_confirm.sh << 'SCRIPT'
#!/bin/bash
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    while true; do
        read -p "

You are accessing a U.S. Government (USG) Information System (IS) that is provided for USG-authorized use only.

By using this IS (which includes any device attached to this IS), you consent to the following conditions:

- The USG routinely intercepts and monitors communications on this IS for purposes including, but not limited to, penetration testing, COMSEC monitoring, network operations and defense, personnel misconduct (PM), law enforcement (LE), and counterintelligence (CI) investigations.

- At any time, the USG may inspect and seize data stored on this IS.

- Communications using, or data stored on, this IS are not private, are subject to routine monitoring, interception, and search, and may be disclosed or used for any USG-authorized purpose.

- This IS includes security measures (e.g., authentication and access controls) to protect USG interests--not for your personal benefit or privacy.

- Notwithstanding the above, using this IS does not constitute consent to PM, LE or CI investigative searching or monitoring of the content of privileged communications, or work product, related to personal representation or services by attorneys, psychotherapists, or clergy, and their assistants. Such communications and work product are private and confidential. See User Agreement for details.

Do you agree? [y/N] " yn
        case $yn in
            [Yy]* ) break ;;
            [Nn]* ) exit 1 ;;
        esac
    done
fi
SCRIPT
chmod +x /etc/profile.d/ssh_confirm.sh
```

---

### 1.7 Configure GNOME Display Manager

The target system uses **SDDM** (or `tuigreet` with `greetd`) with the **Hyprland** Wayland compositor — not GNOME/GDM. The following table maps each GDM recommendation to the equivalent SDDM/Hyprland control.

---

##### 1.7.1 Ensure GDM is removed (Level 2 – Server)

**Profile:** CIS Level 2 – Server | **Status:** ✅ COMPLIANT

**Audit**
```bash
qpkg -I gdm 2>/dev/null && echo "❌ GDM installed" || echo "✅ GDM not installed"
```

---

##### 1.7.2 – 1.7.3 Ensure GDM login banner is configured and disable‑user‑list is enabled

*STIG: UBTU‑24‑200650, UBTU‑24‑200660 (CAT II)*

**Profile:** CIS Level 1 – Server & Workstation · STIG CAT II | **Status:** ⚠️ NEEDS REVIEW

**What's Required**
A warning banner must be displayed on the graphical login screen, and the user list must be hidden.

**Gentoo Implementation**
For SDDM, configure the theme to display `/etc/issue` and set `HideUsers=true` or `HideShells=/usr/bin/nologin`. For `tuigreet`, the banner is displayed as part of the greeter. These settings must be verified against site policy.

**Audit (SDDM)**
```bash
grep -E '^(MessageFile|HideUsers|HideShells)' /etc/sddm.conf 2>/dev/null || \
  echo "⚠️ SDDM banner not configured — verify theme settings"
```

---

##### 1.7.4 – 1.7.5 Ensure GDM screen locks when user is idle and cannot be overridden

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
The screen must lock automatically after a period of inactivity (≤ 15 minutes), and users must not be able to override this setting.

**Gentoo Implementation**
`swayidle` is configured to trigger `swaylock` after 15 minutes of inactivity. The Hyprland configuration (`~/.config/hypr/hyprland.conf`) binds the lock to the `exec-once` directive (README Part 1.7).

**Audit**
```bash
grep -E 'swayidle|swaylock' ~/.config/hypr/hyprland.conf 2>/dev/null && \
  echo "✅ Screen lock configured" || echo "⚠️ Screen lock not found in Hyprland config"
```

---

##### 1.7.6 – 1.7.10 Autorun, automount, and XDMCP

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT / 🔵 NOT APPLICABLE

**Gentoo Implementation**
Automount and autorun are not applicable to a Wayland compositor that does not use GVFS/GDM. USB storage is blacklisted at the kernel module level (see 1.1.1.9). XDMCP is not present because the system uses Wayland, not X11.

---

## 2. Services

### 2.1 Configure Server Services

The CIS benchmark lists 22 services that should be removed or masked if not required. The target Gentoo system installs a minimal set of services; most CIS‑listed services are not present.

---

##### 2.1.1 – 2.1.20 Ensure unnecessary server services are not in use

**Profile:** CIS Level 1 – Server & Workstation (varies by service) | **Status:** ✅ COMPLIANT

**What's Required**
The following services must not be installed or must be masked: autofs, avahi, dhcp, dns (bind9), dnsmasq, ftp (vsftpd), ldap (slapd), dovecot (imap/pop3), nfs‑kernel‑server, nis (ypserv), cups, rpcbind, rsync, samba, snmpd, tftpd‑hpa, squid, apache2/nginx, xinetd, X11 (xserver‑common).

**Gentoo Implementation**
None of these services are installed. The MTA is configured for local‑only delivery (see 2.1.21).

**Unified Audit**
```bash
#!/bin/bash
SERVICES=(autofs avahi-daemon isc-dhcp-server named dnsmasq vsftpd slapd dovecot
    nfs-server ypserv cups rpcbind rsyncd smbd snmpd tftpd-hpa squid
    apache2 nginx xinetd)
for svc in "${SERVICES[@]}"; do
    state=$(systemctl is-active "$svc.service" 2>/dev/null || echo "inactive")
    [ "$state" = "active" ] && echo "❌ $svc is ACTIVE" || echo "✅ $svc inactive"
done
```

---

##### 2.1.21 Ensure mail transfer agent is configured for local‑only mode

*STIG: implicit in UBTU‑24‑200090 (remote access logging)*

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
The MTA must not listen on external network interfaces. Only local mail delivery should be permitted.

**Gentoo Implementation**
No MTA (Postfix, Exim, Sendmail) is installed. `msmtp` is used for outbound mail relay only (README Part 22.1). It does not listen on any port.

**Audit**
```bash
ss -plntu | grep -P ':(25|465|587)\b' | grep -v '127.0.0.1\|::1' && \
  echo "❌ MTA listening on external interface" || echo "✅ No external MTA listener"
```

---

##### 2.1.22 Ensure only approved services are listening on a network interface (Manual)

*STIG: UBTU‑24‑300041 (CAT II)*

**Profile:** CIS Level 1 – Server & Workstation · STIG CAT II | **Status:** ⚠️ NEEDS REVIEW

**What's Required**
Review all listening network services. Any service not explicitly approved must be stopped and its package removed or masked.

**Gentoo Implementation**
Firewalld is configured with a default‑drop zone. Only explicitly allowed ports (SSH on 2222, DNS over TLS on 853, HTTPS on 443, Cockpit on localhost:9090) are open (README Part 18.1). OpenSnitch provides per‑application outbound control (README Part 18.2).

**Audit**
```bash
ss -plntu | grep LISTEN
# Review the output. Expected services:
#   - sshd on port 2222
#   - dnscrypt-proxy on 127.0.0.1:5300
#   - systemd-resolved on 127.0.0.53:53
#   - cockpit on 127.0.0.1:9090 (if installed)
```

**Remediation (if unexpected services are found)**
```bash
# Stop and mask the service
systemctl stop <service>.service
systemctl mask <service>.service
# Or remove entirely:
emerge --unmerge <package>
```

---

### 2.2 Configure Client Services

---

##### 2.2.1 – 2.2.6 Ensure insecure client packages are not installed

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
NIS client (`nis`), RSH client (`rsh-client`), talk client (`talk`), telnet client (`telnet`, `inetutils-telnet`), LDAP client (`ldap-utils`), and FTP client (`ftp`, `tnftp`) must not be installed.

**Gentoo Implementation**
None of these client packages are installed on the target system.

**Unified Audit**
```bash
for pkg in nis rsh talk telnet inetutils-telnet ldap-utils ftp tnftp; do
    qpkg -I "$pkg" 2>/dev/null && echo "❌ $pkg installed" || echo "✅ $pkg not installed"
done
```

**Remediation**
```bash
emerge --unmerge nis rsh talk telnet inetutils-telnet ldap-utils ftp tnftp 2>/dev/null || true
```

---

### 2.3 Configure Time Synchronization

The target system uses **systemd‑timesyncd** by default (README Part 6). The STIG benchmark requires **chrony** and explicitly forbids both `systemd‑timesyncd` and `ntp`. This section documents the system's actual configuration and notes the STIG deviation.

---

##### 2.3.1.1 Ensure a single time synchronization daemon is in use

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
Only one time synchronization daemon must be active. The CIS benchmark supports either systemd‑timesyncd or chrony.

**Gentoo Implementation**
`systemd‑timesyncd` is active. `chrony` is not installed. `ntp` is not installed.

**Audit**
```bash
systemctl is-active systemd-timesyncd.service
systemctl is-active chronyd.service 2>/dev/null && echo "⚠️ chrony is also running"
qpkg -I ntp 2>/dev/null && echo "⚠️ ntp is installed"
```

---

##### 2.3.2.1 – 2.3.2.2 Ensure systemd‑timesyncd is configured and running

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
systemd‑timesyncd must be configured with authorised NTP servers and must be enabled and running.

**Gentoo Implementation**
Configured in `/etc/systemd/timesyncd.conf.d/60-timesyncd.conf` with `NTP=time.nist.gov` and fallback servers (README Part 6).

**Audit**
```bash
systemctl is-active systemd-timesyncd.service
# Must output: active
grep -E '^(NTP|FallbackNTP)=' /etc/systemd/timesyncd.conf.d/*.conf 2>/dev/null || \
  grep -E '^(NTP|FallbackNTP)=' /etc/systemd/timesyncd.conf 2>/dev/null
```

---

##### STIG Deviation: Chrony Requirement

*STIG: UBTU‑24‑100010, UBTU‑24‑100020, UBTU‑24‑100700*

**Status:** ❌ INTENTIONAL DEVIATION

**What the STIG Requires**
- UBTU‑24‑100010 (CAT III): `systemd‑timesyncd` must be purged.
- UBTU‑24‑100020 (CAT III): `ntp` must be purged.
- UBTU‑24‑100700 (CAT III): `chrony` must be installed and configured with authorised servers and `makestep 1 -1`.

**Gentoo Implementation**
These three STIG rules are **not applied** for the following reasons:

1. `systemd‑timesyncd` is part of `sys‑apps/systemd` and cannot be removed without breaking the init system. However, the service can be masked and chrony used instead if STIG compliance is legally required.
2. `ntp` is not installed — this rule is satisfied.
3. `chrony` is not installed. The system uses `systemd‑timesyncd` which, for a standalone workstation with internet connectivity, provides adequate time accuracy.

**Remediation (if STIG compliance is required)**
```bash
emerge --ask net-misc/chrony
systemctl mask systemd-timesyncd.service
systemctl enable --now chronyd.service
cat > /etc/chrony/chrony.conf << 'EOF'
server time.nist.gov iburst maxpoll 16
server time2.google.com iburst maxpoll 16
makestep 1 -1
EOF
systemctl restart chronyd
```

---

##### UBTU‑24‑901220 — Audit records must use UTC timestamps

*STIG: UBTU‑24‑901220 (CAT III)*

**Status:** ✅ COMPLIANT

**What's Required**
System timezone must be set to UTC.

**Gentoo Implementation**
The system timezone is set to `Etc/UTC` (README Part 6.1).

**Audit**
```bash
timedatectl status | grep -i "time zone"
# Must show: Time zone: Etc/UTC (UTC, +0000)
```

---

### 2.4 Job Schedulers

---

##### 2.4.1.1 Ensure cron daemon is enabled and active

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
A cron daemon must be installed and running to execute scheduled system maintenance jobs.

**Gentoo Implementation**
`cronie` (or `systemd‑cron`) is enabled and active.

**Audit**
```bash
systemctl is-enabled cronie.service 2>/dev/null || systemctl is-enabled cron.service 2>/dev/null
systemctl is-active cronie.service 2>/dev/null || systemctl is-active cron.service 2>/dev/null
```

---

##### 2.4.1.2 – 2.4.1.8 Ensure cron directories and files are secured and access is restricted

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ⚠️ NEEDS REVIEW (cron.allow/at.allow)

**What's Required**
- `/etc/crontab` and cron directories (`/etc/cron.hourly`, `.daily`, `.weekly`, `.monthly`, `.d`) must be owned by `root:root` with mode `0700` (directories) or `0600` (crontab).
- `/etc/cron.allow` must exist, be owned by `root:root` (or `root:crontab`), and have mode `0640` or more restrictive. If `/etc/cron.deny` exists, it must also be restricted.
- `/etc/at.allow` must exist with similar restrictions.

**Gentoo Implementation**
Directory permissions are correct by default on Gentoo. However, `/etc/cron.allow` and `/etc/at.allow` may not exist and must be created.

**Audit**
```bash
# Check directory permissions
stat -c '%a %U:%G %n' /etc/crontab /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d

# Check cron.allow exists
[ -f /etc/cron.allow ] && stat -c '%a %U:%G %n' /etc/cron.allow || echo "⚠️ /etc/cron.allow does not exist"

# Check at.allow exists
[ -f /etc/at.allow ] && stat -c '%a %U:%G %n' /etc/at.allow || echo "⚠️ /etc/at.allow does not exist"
```

**Remediation**
```bash
# Create cron.allow
[ ! -f /etc/cron.allow ] && touch /etc/cron.allow
chown root:root /etc/cron.allow
chmod 600 /etc/cron.allow
echo "root" > /etc/cron.allow

# Create at.allow
[ ! -f /etc/at.allow ] && touch /etc/at.allow
chown root:root /etc/at.allow
chmod 600 /etc/at.allow
echo "root" > /etc/at.allow
```

---

## 3. Network Configuration

### 3.1 Configure Network Devices

---

##### 3.1.1 Ensure IPv6 status is identified (Manual)

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
The system administrator must determine whether IPv6 is enabled and configure it accordingly. IETF RFC 4038 recommends dual‑stack.

**Gentoo Implementation**
IPv6 is enabled. It is not disabled because dual‑stack compatibility is preferred for a modern workstation.

**Audit**
```bash
sysctl net.ipv6.conf.all.disable_ipv6
# 0 = enabled, 1 = disabled
```

---

##### 3.1.2 Ensure wireless interfaces are disabled

**Profile:** CIS Level 1 – Server (not workstation) | **Status:** ✅ COMPLIANT

**What's Required**
If the system is a server, wireless interfaces must be disabled to reduce the attack surface.

**Gentoo Implementation**
Wireless adapter drivers are blacklisted in `blacklist-hardening.conf` (README Part 16). This recommendation is for servers; workstations may require wireless.

**Audit**
```bash
find /sys/class/net/* -type d -name wireless 2>/dev/null | while read iface; do
    echo "Wireless interface found: $(basename $(dirname $iface))"
done
```

---

##### 3.1.3 Ensure bluetooth services are not in use

*STIG: implicit in CIS 3.1.3*

**Profile:** CIS Level 1 – Server / Level 2 – Workstation | **Status:** ✅ COMPLIANT

**What's Required**
Bluetooth must be disabled to prevent bluesnarfing and other Bluetooth‑based attacks.

**Gentoo Implementation**
Bluetooth kernel modules are blacklisted in `blacklist-hardening.conf` (README Part 16).

**Audit**
```bash
modprobe -n -v bluetooth 2>&1 | grep -q 'install /bin/true' && \
  echo "✅ bluetooth blocked" || echo "❌ bluetooth loadable"
```

---

### 3.2 Configure Network Kernel Modules

All four uncommon network protocol modules are blacklisted (README Part 16).

---

##### 3.2.1 – 3.2.4 Ensure dccp, tipc, rds, and sctp kernel modules are not available

**Profile:** CIS Level 2 – Server & Workstation | **Status:** ✅ COMPLIANT

**Unified Audit**
```bash
for mod in dccp tipc rds sctp; do
    modprobe -n -v "$mod" 2>&1 | grep -q 'install /bin/true' && \
      echo "✅ $mod blocked" || echo "❌ $mod NOT blocked"
done
```

**Unified Remediation**
```bash
for mod in dccp tipc rds sctp; do
    echo "install $mod /bin/true"  > /etc/modprobe.d/$mod.conf
    echo "blacklist $mod"         >> /etc/modprobe.d/$mod.conf
done
dracut --force --regenerate-all
```

---

### 3.3 Configure Network Kernel Parameters

All eleven kernel parameters from CIS §3.3 are enforced via a unified sysctl file (README Part 3.3). The STIG adds `net.ipv4.tcp_syncookies` (covered in §1.5). All are pre‑configured on the target system.

---

##### 3.3.1 – 3.3.11 Unified Network Kernel Parameters

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
The following sysctl parameters must be set:

| Parameter | Expected Value |
|-----------|---------------|
| `net.ipv4.ip_forward` | `0` |
| `net.ipv6.conf.all.forwarding` | `0` |
| `net.ipv4.conf.all.send_redirects` | `0` |
| `net.ipv4.conf.default.send_redirects` | `0` |
| `net.ipv4.icmp_ignore_bogus_error_responses` | `1` |
| `net.ipv4.icmp_echo_ignore_broadcasts` | `1` |
| `net.ipv4.conf.all.accept_redirects` | `0` |
| `net.ipv4.conf.default.accept_redirects` | `0` |
| `net.ipv6.conf.all.accept_redirects` | `0` |
| `net.ipv6.conf.default.accept_redirects` | `0` |
| `net.ipv4.conf.all.secure_redirects` | `0` |
| `net.ipv4.conf.default.secure_redirects` | `0` |
| `net.ipv4.conf.all.rp_filter` | `1` |
| `net.ipv4.conf.default.rp_filter` | `1` |
| `net.ipv4.conf.all.accept_source_route` | `0` |
| `net.ipv4.conf.default.accept_source_route` | `0` |
| `net.ipv6.conf.all.accept_source_route` | `0` |
| `net.ipv6.conf.default.accept_source_route` | `0` |
| `net.ipv4.conf.all.log_martians` | `1` |
| `net.ipv4.conf.default.log_martians` | `1` |
| `net.ipv4.tcp_syncookies` | `1` |
| `net.ipv6.conf.all.accept_ra` | `0` |
| `net.ipv6.conf.default.accept_ra` | `0` |

**Gentoo Implementation**
All parameters are set in `/etc/sysctl.d/99-cis-network.conf` (README Part 3.3).

**Audit**
```bash
# Spot-check key parameters
for param in net.ipv4.ip_forward net.ipv4.tcp_syncookies net.ipv4.conf.all.rp_filter net.ipv6.conf.all.accept_ra; do
    val=$(sysctl -n "$param" 2>/dev/null)
    echo "$param = $val"
done
```

**Remediation**
```bash
cat > /etc/sysctl.d/99-cis-network.conf << 'EOF'
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.tcp_syncookies = 1
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
EOF
sysctl --system
```

---

## 4. Host‑Based Firewall

The target system uses **firewalld** with the **nftables** backend (README Part 18.1). The CIS benchmark covers UFW, nftables, and iptables in separate sections. This guide translates the requirements to firewalld equivalents.

---

##### 4.1.1 Ensure a single firewall configuration utility is in use

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
Only one firewall management tool may be active. Running multiple tools (e.g., UFW + iptables + nftables simultaneously) causes conflicts.

**Gentoo Implementation**
`firewalld` is the sole firewall manager. Neither UFW, raw iptables, nor standalone nftables services are active.

**Audit**
```bash
systemctl is-active firewalld.service
systemctl is-active ufw.service 2>/dev/null && echo "❌ UFW is active"
systemctl is-active nftables.service 2>/dev/null && echo "❌ standalone nftables is active"
systemctl is-active iptables.service 2>/dev/null && echo "❌ standalone iptables is active"
```

---

##### 4.2.1 – 4.2.7 Mapping UFW Requirements to Firewalld

*STIG: UBTU‑24‑100300, UBTU‑24‑100310, UBTU‑24‑600200*

| UFW Requirement | Firewalld Equivalent | Status |
|-----------------|---------------------|--------|
| UFW installed | `net‑firewall/firewalld` emerged | ✅ |
| UFW enabled & active | `firewalld.service` enabled, default zone `drop` | ✅ |
| Loopback traffic configured | `trusted` zone on `lo`; anti‑spoofing rich rules | ✅ |
| Outbound connections | Outbound allowed by default (stateful tracking) | ✅ |
| Rules for all open ports | Explicit accept rules for SSH, DNS, HTTPS | ⚠️ Verify |
| Default deny policy | Default zone `drop` | ✅ |
| Rate limiting (STIG) | Rich rules with limit directives | ⚠️ Site‑specific |

**Audit (firewalld)**
```bash
firewall-cmd --get-default-zone
# Must output: drop
firewall-cmd --list-all --zone=drop
firewall-cmd --get-active-zones
```

---

## 5. Access Control

### 5.1 Configure SSH Server

The target system's SSH configuration (README Part 19.7) satisfies or exceeds every CIS Level 1 SSH recommendation. This section provides individual audits for each parameter.

---

##### 5.1.1 Ensure permissions on /etc/ssh/sshd_config are configured

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**Audit**
```bash
stat -c '%a %U:%G' /etc/ssh/sshd_config
# Must show: 600 root:root
```

**Remediation**
```bash
chown root:root /etc/ssh/sshd_config
chmod 600 /etc/ssh/sshd_config
```

---

##### 5.1.2 – 5.1.3 Ensure permissions on SSH host key files are configured

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**Audit**
```bash
# Private keys: 600 root:root (or 640 root:ssh_keys)
find /etc/ssh -type f -name 'ssh_host_*_key' ! -name '*.pub' -exec stat -c '%a %U:%G %n' {} \;
# Public keys: 644 root:root
find /etc/ssh -type f -name 'ssh_host_*_key.pub' -exec stat -c '%a %U:%G %n' {} \;
```

---

##### 5.1.4 Ensure sshd access is configured

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
At least one of `AllowUsers`, `AllowGroups`, `DenyUsers`, or `DenyGroups` must be configured.

**Gentoo Implementation**
`AllowGroups sshusers` is set (README Part 19.7). Only members of the `sshusers` group may authenticate via SSH.

**Audit**
```bash
sshd -T | grep -Pi '^\h*(allow|deny)(users|groups)\h+\H+'
# Must show at least one configured restriction
```

---

##### 5.1.5 Ensure sshd Banner is configured

*STIG: UBTU‑24‑200640 (CAT II)*

**Profile:** CIS Level 1 – Server & Workstation · STIG CAT II | **Status:** ✅ COMPLIANT (see §1.6 for STIG content)

**Audit**
```bash
sshd -T | grep -i '^banner '
# Must output: banner /etc/ssh/banner (or similar)
```

---

##### 5.1.6 Ensure sshd Ciphers are configured

*STIG: UBTU‑24‑100820 (CAT II)*

**Profile:** CIS Level 1 – Server & Workstation · STIG CAT II | **Status:** ❌ INTENTIONAL DEVIATION (from STIG)

**What's Required**
- **CIS**: No weak ciphers (3des‑cbc, aes128‑cbc, aes192‑cbc, aes256‑cbc, arcfour, blowfish‑cbc, cast128‑cbc).
- **STIG**: Only FIPS‑approved ciphers: `aes256‑gcm@openssh.com, aes128‑gcm@openssh.com, aes256‑ctr, aes128‑ctr`.

**Gentoo Implementation**
The target system uses `chacha20‑poly1305@openssh.com, aes256‑gcm@openssh.com, aes256‑ctr` (README Part 19.7). ChaCha20‑Poly1305 is **not** FIPS‑approved but is **cryptographically stronger** than AES‑128 variants. It is constant‑time on all CPUs, provides better security on machines without AES‑NI, and is recommended by the cryptographic community.

**Audit**
```bash
sshd -T | grep -i '^ciphers '
```

---

##### 5.1.12 Ensure sshd KexAlgorithms is configured

*STIG: UBTU‑24‑100840 (CAT II)*

**Profile:** CIS Level 1 – Server & Workstation · STIG CAT II | **Status:** ❌ INTENTIONAL DEVIATION (from STIG)

**What's Required**
- **CIS**: No weak KEX algorithms (`diffie‑hellman‑group1‑sha1`, `diffie‑hellman‑group14‑sha1`, `diffie‑hellman‑group‑exchange‑sha1`).
- **STIG**: Only NIST P‑curve ECDH and Diffie‑Hellman with SHA‑256 or SHA‑512.

**Gentoo Implementation**
The target system uses post‑quantum hybrid key exchange: `sntrup761x25519‑sha512, mlkem768x25519‑sha256, curve25519‑sha256` (README Part 19.7). These algorithms provide protection against future quantum‑computer attacks that NIST curves do not. They are **not** FIPS‑approved but represent the current state of the art in SSH key exchange security.

**Audit**
```bash
sshd -T | grep -i '^kexalgorithms '
```

---

##### 5.1.15 Ensure sshd MACs are configured

*STIG: UBTU‑24‑100830 (CAT II)*

**Profile:** CIS Level 1 – Server & Workstation · STIG CAT II | **Status:** ✅ COMPLIANT

**Audit**
```bash
sshd -T | grep -i '^macs '
# Must include only hmac‑sha2‑256 and hmac‑sha2‑512 variants
```

---

##### 5.1.7 – 5.1.22 Quick Reference: All Remaining SSH Parameters

The following parameters are correctly configured in README Part 19.7. Each can be verified with `sshd -T | grep <parameter>`:

| Parameter | Expected Value | CIS ID | STIG ID |
|-----------|---------------|--------|---------|
| `clientaliveinterval` | `600` | 5.1.7 | UBTU‑24‑600010 |
| `clientalivecountmax` | `1` | 5.1.7 | UBTU‑24‑600000 |
| `disableforwarding` | `yes` (or individual directives set to `no`) | 5.1.8 | – |
| `gssapiauthentication` | `no` | 5.1.9 | – |
| `hostbasedauthentication` | `no` | 5.1.10 | – |
| `ignorerhosts` | `yes` | 5.1.11 | – |
| `logingracetime` | `60` or less | 5.1.13 | – |
| `loglevel` | `VERBOSE` or `INFO` | 5.1.14 | – |
| `maxauthtries` | `4` or less | 5.1.16 | – |
| `maxsessions` | `10` or less | 5.1.17 | – |
| `maxstartups` | `10:30:60` or more restrictive | 5.1.18 | – |
| `permitemptypasswords` | `no` | 5.1.19 | – |
| `permitrootlogin` | `no` | 5.1.20 | – |
| `permituserenvironment` | `no` | 5.1.21 | – |
| `usepam` | `yes` | 5.1.22 | UBTU‑24‑500050 |
| `x11forwarding` | `no` | – | UBTU‑24‑300022 |

---

### 5.2 Configure Privilege Escalation — sudo

---

##### 5.2.1 – 5.2.7 Quick Reference: All sudo Parameters

All seven sudo recommendations are satisfied. Each can be verified individually.

| CIS ID | Requirement | Audit Command | STIG ID |
|--------|-------------|---------------|---------|
| 5.2.1 | sudo installed | `which sudo` | – |
| 5.2.2 | Commands use pty | `grep 'use_pty' /etc/sudoers /etc/sudoers.d/*` | – |
| 5.2.3 | Log file exists | `grep 'logfile' /etc/sudoers /etc/sudoers.d/*` | – |
| 5.2.4 | Password required (L2) | `grep -r 'NOPASSWD' /etc/sudoers /etc/sudoers.d/` | – |
| 5.2.5 | Re‑authentication not disabled | `grep -r '!authenticate' /etc/sudoers /etc/sudoers.d/` | UBTU‑24‑300021 |
| 5.2.6 | Authentication timeout ≤ 15 min | `sudo -V \| grep 'Authentication timestamp timeout'` | – |
| 5.2.7 | su command restricted | `grep 'pam_wheel.so' /etc/pam.d/su` | – |

---

##### UBTU‑24‑600130 — Only authorised users in sudo group

*STIG: UBTU‑24‑600130 (CAT I)*

**Status:** ✅ COMPLIANT

**What's Required**
Only users who require access to security functions may be members of the sudo (or wheel) group.

**Gentoo Implementation**
Only the `ahsan` user is in the `wheel` group (README Part 5.6).

**Audit**
```bash
getent group wheel
# Verify only authorised users are listed
```

---

### 5.3 Pluggable Authentication Modules (PAM)

Gentoo configures PAM directly in `/etc/pam.d/system-auth`. There is no `pam‑auth‑update` tool. The PAM stack is fully configured in README Part 20.

---

##### 5.3.1.3 Ensure libpam‑pwquality is installed

*STIG: UBTU‑24‑100600 (CAT II)*

**Profile:** CIS Level 1 – Server & Workstation · STIG CAT II | **Status:** ✅ COMPLIANT

**Audit**
```bash
ls /lib64/security/pam_pwquality.so && echo "✅ installed" || echo "❌ NOT installed"
```

**Remediation**
```bash
emerge --ask sys-libs/libpwquality
```

---

##### 5.3.3.1.1 – 5.3.3.4.4 Quick Reference: All PAM Module Arguments

All PAM arguments are configured via `faillock.conf` and `pwquality.conf` (README Part 20). The following table shows the key STIG‑mapped settings:

| Setting | File | CIS Recommended | STIG Required | Gentoo Value | Status |
|---------|------|----------------|---------------|--------------|--------|
| `deny` | `faillock.conf` | ≤ 5 | ≤ 3 | `deny = 5` | ⚠️ (STIG wants 3) |
| `unlock_time` | `faillock.conf` | ≥ 900 or 0 (never) | `0` (never) | `unlock_time = 900` | ⚠️ (STIG wants 0) |
| `minlen` | `pwquality.conf` | ≥ 14 | ≥ 15 | `minlen = 16` | ✅ (exceeds both) |
| `difok` | `pwquality.conf` | ≥ 2 | ≥ 8 | `difok = 8` | ✅ |
| `dictcheck` | `pwquality.conf` | `1` | `1` | `dictcheck = 1` | ✅ |
| `enforcing` | `pwquality.conf` | `1` | `1` | `enforcing = 1` | ✅ |
| Hash algorithm | PAM `pam_unix.so` | `sha512` or `yescrypt` | `SHA512` | `yescrypt` | ✅ (stronger) |
| `remember` | PAM `pam_pwhistory.so` | ≥ 24 | N/A | `remember=24` | ✅ |

**Audit (PAM faillock)**
```bash
grep -v '^#' /etc/security/faillock.conf | grep -v '^$'
```

**Audit (PAM pwquality)**
```bash
grep -v '^#' /etc/security/pwquality.conf | grep -v '^$'
```

**Audit (PAM system‑auth)**
```bash
grep 'pam_unix.so\|pam_faillock.so\|pam_pwquality.so\|pam_pwhistory.so' /etc/pam.d/system-auth
```

---

### 5.4 User Accounts and Environment

---

##### 5.4.1.1 – 5.4.3.3 Quick Reference: Password Aging, Root, and User Environment

All CIS §5.4 recommendations are satisfied. Key settings:

| Setting | File | Value | CIS ID | STIG ID |
|---------|------|-------|--------|---------|
| `PASS_MAX_DAYS` | `/etc/login.defs` | `365` | 5.4.1.1 | UBTU‑24‑400310 |
| `PASS_MIN_DAYS` | `/etc/login.defs` | `1` | 5.4.1.2 | UBTU‑24‑400300 |
| `PASS_WARN_AGE` | `/etc/login.defs` | `7` | 5.4.1.3 | – |
| `ENCRYPT_METHOD` | `/etc/login.defs` | `YESCRYPT` | 5.4.1.4 | UBTU‑24‑400400 |
| `INACTIVE` | `/etc/default/useradd` | `35` | 5.4.1.5 | UBTU‑24‑200260 |
| Root account locked | `passwd -S root` | `L` (locked) | 5.4.2.4 | UBTU‑24‑400110 |
| `TMOUT` | `/etc/profile.d/` | `600` | 5.4.3.2 | UBTU‑24‑200060 |
| Default umask | `/etc/login.defs` | `027` (or `077` for STIG) | 5.4.3.3 | UBTU‑24‑300030 |

---

## 6. Logging and Auditing

### 6.1 System Logging

The target system uses **systemd‑journald** exclusively (README Part 6). rsyslog is not installed. The STIG requires rsyslog for certain rules; this deviation is documented.

---

##### 6.1.1.1 Ensure journald service is enabled and active

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**Audit**
```bash
systemctl is-active systemd-journald.service
# Must output: active
```

---

##### 6.1.1.2 – 6.1.1.3 Ensure journald log file access and rotation are configured

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**What's Required**
Journal files must have correct permissions (`0640`), and log rotation must be configured to prevent disk exhaustion.

**Gentoo Implementation**
journald is configured with persistent storage, compression, and size‑based rotation in `/etc/systemd/journald.conf.d/60-journald.conf` (README Part 6).

**Audit**
```bash
grep -E '^(Storage|Compress|SystemMaxUse|MaxFileSec)=' /etc/systemd/journald.conf /etc/systemd/journald.conf.d/*.conf 2>/dev/null
```

---

##### 6.1.1.4 Ensure only one logging system is in use

**Profile:** CIS Level 1 – Server & Workstation | **Status:** ✅ COMPLIANT

**Audit**
```bash
systemctl is-active systemd-journald.service
systemctl is-active rsyslog.service 2>/dev/null && echo "⚠️ rsyslog is also running"
```

---

##### STIG Deviation: rsyslog Requirement

*STIG: UBTU‑24‑100200, UBTU‑24‑200090*

**Status:** ❌ INTENTIONAL DEVIATION

**What the STIG Requires**
`rsyslog` must be installed, enabled, and active. Remote access methods must be logged via `auth.*`, `authpriv.*`, and `daemon.*`.

**Gentoo Implementation**
The target system uses `systemd‑journald` with persistent storage. Journald provides equivalent logging functionality with structured, indexed binary logs. The `audit` subsystem captures authentication and privilege escalation events (README Part 15). If STIG compliance is legally required, `rsyslog` can be emerged alongside journald.

**Remediation (if STIG compliance is required)**
```bash
emerge --ask app-admin/rsyslog
systemctl enable --now rsyslog.service
```

---

### 6.2 System Auditing — auditd

The auditd configuration (README Part 15) satisfies all CIS §6.2 and STIG audit requirements. The comprehensive ruleset in `/etc/audit/rules.d/99-hardening.rules` covers every STIG‑required audit event.

---

##### 6.2.1.1 – 6.2.1.4 Quick Reference: auditd Service

| Requirement | CIS ID | STIG ID | Audit |
|-------------|--------|---------|-------|
| auditd installed | 6.2.1.1 | UBTU‑24‑100400 | `qpkg -I audit` |
| auditd enabled & active | 6.2.1.2 | UBTU‑24‑100410 | `systemctl is-active auditd` |
| Early process auditing | 6.2.1.3 | UBTU‑24‑102010 | `grep 'audit=1' /proc/cmdline` |
| backlog limit sufficient | 6.2.1.4 | – | `grep 'audit_backlog_limit' /proc/cmdline` |

**Status on Target System:** ✅ All compliant.

---

##### 6.2.2.1 – 6.2.2.4 Quick Reference: Data Retention

All four retention settings are configured in `/etc/audit/auditd.conf` (README Part 15.2): `max_log_file = 50`, `max_log_file_action = keep_logs`, `disk_full_action = halt`, `space_left_action = SYSLOG` with `admin_space_left_action = halt`.

**Audit**
```bash
grep -E '^(max_log_file |max_log_file_action |disk_full_action |disk_error_action |space_left_action |admin_space_left_action )' /etc/audit/auditd.conf
```

---

##### 6.2.3.1 – 6.2.3.21 Quick Reference: Audit Rules

The full audit ruleset is in `/etc/audit/rules.d/99-hardening.rules` (README Part 15.3). This covers all CIS §6.2.3 and STIG audit rules (UBTU‑24‑200280 through UBTU‑24‑900750). Key rule categories:

| CIS ID | STIG IDs Covered | Event Category | Rule Key |
|--------|-----------------|----------------|----------|
| 6.2.3.1 | – | sudoers changes | `scope` / `sudoers_change` |
| 6.2.3.2 | UBTU‑24‑200580 | Actions as another user | `setuid_exec` / `setgid_exec` |
| 6.2.3.3 | UBTU‑24‑500010 | sudo log modifications | `sudo_cmd` |
| 6.2.3.4 | – | Date/time modifications | `time_change` |
| 6.2.3.5 | – | Network environment changes | `system_locale` |
| 6.2.3.6 | – | Privileged commands | `privileged` |
| 6.2.3.7 | UBTU‑24‑900160 | Unsuccessful file access | `access` |
| 6.2.3.8 | UBTU‑24‑200280‑320 | User/group modifications | `identity` |
| 6.2.3.9 | UBTU‑24‑900130‑150 | DAC permission modifications | `perm_mod` / `perm_chng` |
| 6.2.3.10 | UBTU‑24‑900090‑100 | File system mounts | `mounts` |
| 6.2.3.11 | UBTU‑24‑900590‑610 | Session initiation | `session` / `logins` |
| 6.2.3.12 | UBTU‑24‑900250‑260 | Login/logout events | `logins` |
| 6.2.3.13 | UBTU‑24‑900540 | File deletion | `delete` |
| 6.2.3.14 | UBTU‑24‑900220 | MAC (AppArmor) changes | `MAC_policy` / `apparmor_policy` |
| 6.2.3.19 | UBTU‑24‑900340‑350, 900730‑740 | Kernel module changes | `module_load` / `module_unload` / `kmod_exec` |
| 6.2.3.20 | UBTU‑24‑909000 | Immutable config | `-e 2` |

**Unified Audit**
```bash
# Check all loaded audit rules
auditctl -l | wc -l
# Should show a significant number of rules (50+)

# Verify immutable configuration
grep '^-e 2' /etc/audit/rules.d/99-hardening.rules
```

**Remediation (if rules are missing)**
```bash
augenrules --load
# If immutable, reboot required:
auditctl -s | grep "enabled" | grep -q "2" && echo "Reboot required to load immutable rules"
```

---

##### 6.2.4.1 – 6.2.4.10 Quick Reference: Audit File Access

*STIG: UBTU‑24‑900040‑060, 901230‑380*

All audit configuration files, log files, and audit tools have correct permissions and ownership:
- Audit config files (`/etc/audit/audit.rules`, `/etc/audit/rules.d/*`, `/etc/audit/auditd.conf`): mode `0640`, owned by `root:root`
- Audit log files: mode `0600`, owned by `root:root`
- Audit tools (`/sbin/auditctl`, etc.): mode `0755`, owned by `root:root`
- Audit log directory: mode `0750`

**Unified Audit**
```bash
stat -c '%a %U:%G %n' /etc/audit/auditd.conf /etc/audit/audit.rules
stat -c '%a %U:%G %n' /sbin/auditctl /sbin/ausearch /sbin/aureport /sbin/autrace /sbin/auditd /sbin/augenrules
stat -c '%a %U:%G %n' /var/log/audit
find /var/log/audit -type f -exec stat -c '%a %U:%G %n' {} \;
```

---

### 6.3 Configure Integrity Checking — AIDE

---

##### 6.3.1 Ensure AIDE is installed

*STIG: UBTU‑24‑100100 (CAT II)*

**Profile:** CIS Level 1 – Server & Workstation · STIG CAT II | **Status:** ✅ COMPLIANT

**Audit**
```bash
qpkg -I aide && echo "✅ AIDE installed" || echo "❌ AIDE NOT installed"
```

**Remediation**
```bash
emerge --ask app-forensics/aide
aide --init
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

---

##### 6.3.2 Ensure filesystem integrity is regularly checked

*STIG: UBTU‑24‑100110, UBTU‑24‑100120 (CAT II)*

**Profile:** CIS Level 1 – Server & Workstation · STIG CAT II | **Status:** ✅ COMPLIANT

**What's Required**
AIDE must run regularly (at least weekly) and its database must be verified against the default configuration.

**Gentoo Implementation**
A weekly AIDE check is integrated into the `weekly-security-scan.timer` and script (README Part 18.4.3). Results are emailed to the administrator.

**Audit**
```bash
systemctl list-timers | grep -i aide || \
  grep -r aide /etc/cron* /etc/crontab 2>/dev/null
```

---

##### 6.3.3 Ensure cryptographic mechanisms protect audit tools' integrity

*STIG: UBTU‑24‑90890 (CAT II)*

**Profile:** CIS Level 2 – Server & Workstation · STIG CAT II | **Status:** ⚠️ NEEDS REVIEW

**What's Required**
AIDE must be configured to use SHA‑512 checksums for all audit tools.

**Gentoo Implementation**
The AIDE configuration must include specific rules for audit tools with `sha512`. The default AIDE configuration uses `sha256`; this must be verified or updated.

**Audit**
```bash
grep -E '(/sbin/(audit|au))' /etc/aide/aide.conf 2>/dev/null | grep sha512 || \
  echo "⚠️ SHA-512 not configured for audit tools in AIDE"
```

**Remediation**
```bash
cat >> /etc/aide/aide.conf << 'EOF'
# Audit Tools — STIG compliance (SHA-512)
/sbin/auditctl    p+i+n+u+g+s+b+acl+xattrs+sha512
/sbin/auditd      p+i+n+u+g+s+b+acl+xattrs+sha512
/sbin/ausearch    p+i+n+u+g+s+b+acl+xattrs+sha512
/sbin/aureport    p+i+n+u+g+s+b+acl+xattrs+sha512
/sbin/autrace     p+i+n+u+g+s+b+acl+xattrs+sha512
/sbin/augenrules  p+i+n+u+g+s+b+acl+xattrs+sha512
EOF
aide --update
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

---

## 7. System Maintenance

### 7.1 System File Permissions

---

##### 7.1.1 – 7.1.13 Quick Reference: All System File Permissions

All thirteen CIS §7.1 file permission recommendations are satisfied. The following files are verified:

| File | Expected Mode | Expected Owner:Group | CIS ID |
|------|--------------|---------------------|--------|
| `/etc/passwd` | `0644` | `root:root` | 7.1.1 |
| `/etc/passwd-` | `0644` | `root:root` | 7.1.2 |
| `/etc/group` | `0644` | `root:root` | 7.1.3 |
| `/etc/group-` | `0644` | `root:root` | 7.1.4 |
| `/etc/shadow` | `0640` | `root:root` or `root:shadow` | 7.1.5 |
| `/etc/shadow-` | `0640` | `root:root` or `root:shadow` | 7.1.6 |
| `/etc/gshadow` | `0640` | `root:root` or `root:shadow` | 7.1.7 |
| `/etc/gshadow-` | `0640` | `root:root` or `root:shadow` | 7.1.8 |
| `/etc/shells` | `0644` | `root:root` | 7.1.9 |
| `/etc/security/opasswd` | `0600` | `root:root` | 7.1.10 |

**Unified Audit**
```bash
#!/bin/bash
declare -A EXPECTED
EXPECTED=(
    ["/etc/passwd"]="0644:root:root"
    ["/etc/passwd-"]="0644:root:root"
    ["/etc/group"]="0644:root:root"
    ["/etc/group-"]="0644:root:root"
    ["/etc/shadow"]="0640:root:root"
    ["/etc/shadow-"]="0640:root:root"
    ["/etc/gshadow"]="0640:root:root"
    ["/etc/gshadow-"]="0640:root:root"
    ["/etc/shells"]="0644:root:root"
    ["/etc/security/opasswd"]="0600:root:root"
)
for file in "${!EXPECTED[@]}"; do
    if [ -f "$file" ]; then
        IFS=':' read -r exp_perm exp_owner exp_group <<< "${EXPECTED[$file]}"
        actual=$(stat -c '%a:%U:%G' "$file")
        if [[ "$actual" == "$exp_perm:$exp_owner:$exp_group" ]] || \
           [[ "$file" =~ shadow|gshadow && "$actual" =~ ^06[04]0:root:(root|shadow)$ ]]; then
            echo "✅ $file"
        else
            echo "❌ $file: $actual (expected $exp_perm:$exp_owner:$exp_group)"
        fi
    fi
done
```

---

### 7.2 Local User and Group Settings

All ten CIS §7.2 recommendations are satisfied. Key checks:

- **7.2.1**: All accounts in `/etc/passwd` use shadowed passwords (`x` in second field).
- **7.2.2**: No empty password fields in `/etc/shadow`.
- **7.2.3**: All GIDs in `/etc/passwd` exist in `/etc/group`.
- **7.2.4**: Shadow group is empty.
- **7.2.5–8**: No duplicate UIDs, GIDs, usernames, or group names.
- **7.2.9**: All local interactive user home directories exist, are owned by the user, and have mode `0750` or less.
- **7.2.10**: User dot files (`.forward`, `.rhost`, `.netrc`, `.bash_history`) have correct permissions.

**Unified Audit (key checks)**
```bash
# 7.2.1 - Shadowed passwords
awk -F: '($2 != "x") {print "User: " $1 " not shadowed"}' /etc/passwd

# 7.2.2 - Empty passwords
awk -F: '($2 == "") {print $1 " has empty password"}' /etc/shadow

# 7.2.5 - Duplicate UIDs
cut -f3 -d: /etc/passwd | sort -n | uniq -d | while read uid; do
    echo "Duplicate UID $uid: $(awk -F: -v u=$uid '$3==u{print $1}' /etc/passwd | xargs)"
done
```

---

## 8. Cryptographic Requirements

---

##### UBTU‑24‑600030 — FIPS 140‑3 mode must be enabled

*STIG: UBTU‑24‑600030 (CAT I)*

**Status:** ❌ INTENTIONAL DEVIATION

**What the STIG Requires**
The system must run in FIPS mode (`fips=1` on the kernel command line) and use only FIPS‑validated cryptographic modules.

**Gentoo Implementation**
FIPS mode is **not enabled**. This is a deliberate, risk‑informed decision documented in the README (Appendix D, §8.2). The cryptographic choices made for the APT threat model are **stronger** than their FIPS‑approved equivalents:

| Cryptographic Use | Gentoo Choice | FIPS‑Approved Equivalent | Rationale |
|-------------------|---------------|--------------------------|-----------|
| LUKS key derivation | Argon2id (1 GiB memory cost) | PBKDF2 | Argon2id is memory‑hard; resists GPU/ASIC brute‑force |
| Password hashing | yescrypt | SHA‑512 | yescrypt is memory‑hard; recommended by systemd upstream |
| SSH encryption | ChaCha20‑Poly1305 | AES‑128‑GCM | Constant‑time on all CPUs; no AES‑NI dependency |
| SSH key exchange | sntrup761x25519‑sha512 | ECDH NIST P‑256/384/521 | Post‑quantum hybrid; quantum‑safe |

FIPS is a **compliance standard**, not a security standard. Enabling it would require downgrading several cryptographic choices, weakening the system against the nation‑state APT threat model.

**If FIPS compliance is legally required:**
```bash
# Add fips=1 to /etc/kernel/cmdline
# Rebuild LUKS with: cryptsetup luksFormat --pbkdf pbkdf2 ...
# Replace yescrypt with sha512 in PAM
# Remove ChaCha20 and post‑quantum algorithms from SSH
# Enable 'fips' USE flag globally and rebuild @world
```

---

##### UBTU‑24‑600090 — Full disk encryption must be implemented

*STIG: UBTU‑24‑600090 (CAT II)*

**Status:** ✅ COMPLIANT — **exceeds requirement**

**What's Required**
All persistent disk partitions must be encrypted at rest.

**Gentoo Implementation**
The target system uses **LUKS2 with Argon2id** on all data partitions (README Parts 2‑3). Additionally, `systemd‑homed` provides **per‑user LUKS2 encryption** with lock‑on‑suspend (README Part 10B). This provides two independent encryption layers — full‑disk and per‑user — exceeding the STIG requirement.

**Audit**
```bash
cat /etc/crypttab
# Every persistent data partition must have an entry
lsblk -f | grep -i luks
# All non‑ESP partitions should show crypto_LUKS
```

---

## Appendix A: Compliance Summary

| CIS Section | Topic | Key Requirements | Status |
|-------------|-------|-----------------|--------|
| 1.1 | Filesystem kernel modules | 10 modules blacklisted | ✅ |
| 1.1.2 | Filesystem partitions | All mount options correct | ✅ |
| 1.2 | Package management | GPG verification, updates, GLSA scanning | ✅ |
| 1.3 | AppArmor | Installed, enabled, ~1500 profiles loaded | ✅ |
| 1.4 | Bootloader | UKI + Secure Boot (exceeds CIS) | ✅ |
| 1.5 | Process hardening | ASLR, ptrace, core dumps, NX, syncookies, Ctrl‑Alt‑Del | ✅ |
| 1.6 | Warning banners | All banner files configured | ⚠️ STIG banner text needed |
| 1.7 | Display manager | SDDM/Hyprland equivalents configured | ✅ |
| 2.1 | Server services | All unnecessary services removed | ✅ |
| 2.2 | Client services | Insecure clients not installed | ✅ |
| 2.3 | Time sync | systemd‑timesyncd active | ❌ STIG wants chrony |
| 3.1–3.3 | Network | Kernel modules blacklisted, sysctl hardened | ✅ |
| 4 | Firewall | firewalld with default‑drop zone | ✅ |
| 5.1 | SSH | Fully hardened sshd_config | ❌ FIPS ciphers/KEX deviation |
| 5.2 | sudo | All hardening directives applied | ✅ |
| 5.3 | PAM | faillock, pwquality, pwhistory configured | ⚠️ Some STIG values differ |
| 5.4 | User accounts | Password aging, root locked, umask set | ✅ |
| 6.1 | System logging | journald configured | ❌ STIG wants rsyslog |
| 6.2 | auditd | Comprehensive ruleset, immutable, correct permissions | ✅ |
| 6.3 | AIDE | Installed, weekly checks, audit tools hashed | ⚠️ SHA‑512 may need config |
| 7.1 | File permissions | All system files correctly configured | ✅ |
| 7.2 | User/group settings | All checks pass | ✅ |
| 8 | Cryptography | LUKS2 + homed encryption | ❌ FIPS not enabled (intentional) |

**Overall Compliance:**
- ~88% of CIS Level 1 Workstation recommendations are fully satisfied.
- ~72% of STIG rules are fully satisfied; ~15% require site‑specific customisation.
- 4 intentional deviations are documented with rationale (FIPS, SSH ciphers/KEX, time sync, logging).

---

*Guide prepared April 2026. Architecture verified against: Gentoo Wiki (Hardened, UKI, Dracut, Installkernel, Secure Boot, systemd‑cryptenroll), CIS Ubuntu Linux 24.04 LTS Benchmark v1.0.0, CIS Ubuntu Linux 24.04 LTS STIG Benchmark v1.0.0, Arch Wiki (dm‑crypt, Unified Kernel Image), CachyOS Wiki (Kernel), and systemd documentation.*
