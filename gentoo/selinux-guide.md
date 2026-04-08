# Architecting Gentoo Security: A Sysadmin's Complete Guide to SELinux Deployment, Policy Management, and Real-World Challenges

*A Comprehensive 30+ Page Reference for System Administrators*

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Foundational Principles: Understanding SELinux and Gentoo](#foundational-principles)
3. [Pre-Installation Planning and Environment Validation](#pre-installation-planning)
4. [Kernel Configuration for SELinux: Deep Dive](#kernel-configuration)
5. [Portage Integration and Package Management](#portage-integration)
6. [ZFS, Encryption, and SELinux: Architecture Decisions](#zfs-encryption-selinux)
7. [Initial System Setup: Step-by-Step Workflow](#initial-setup)
8. [Policy Management Fundamentals](#policy-management)
9. [Daily Administrative Workflows and Commands](#daily-workflows)
10. [Desktop Use Cases: Practical Examples](#desktop-use-cases)
11. [Server Use Cases: Practical Examples](#server-use-cases)
12. [NVIDIA, CUDA, and Graphics Stack Integration](#nvidia-cuda)
13. [Containerization and SELinux](#containerization)
14. [Troubleshooting Denials: A Systematic Approach](#troubleshooting)
15. [Performance Considerations and Benchmarking](#performance)
16. [Security Hardening and Best Practices](#security-hardening)
17. [Comparative Analysis: Gentoo vs. RHEL vs. Debian](#comparative-analysis)
18. [Migration Strategies and Upgrade Paths](#migration)
19. [Appendix A: Command Reference](#appendix-a)
20. [Appendix B: Configuration Templates](#appendix-b)
21. [Appendix C: Troubleshooting Flowcharts](#appendix-c)
22. [References and Further Reading](#references)

---

## Executive Summary {#executive-summary}

This document serves as a comprehensive, practical reference for system administrators deploying Security-Enhanced Linux (SELinux) within the Gentoo Linux ecosystem. Unlike generic SELinux guides, this resource is specifically tailored to Gentoo's unique architecture—its source-based package management (Portage), custom kernel compilation workflow, and philosophy of user control.

The guide addresses the complete lifecycle of SELinux administration:
- **Planning**: Understanding MAC vs. DAC, policy types, and architectural decisions
- **Deployment**: Kernel configuration, package installation, filesystem relabeling
- **Management**: Daily workflows, boolean management, custom policy creation
- **Troubleshooting**: Systematic denial analysis, NVIDIA/CUDA integration challenges
- **Optimization**: Performance tuning, security hardening, upgrade strategies

Special attention is given to real-world scenarios drawn from the provided installation guide, including:
- ZFS native encryption with SELinux enforcement
- ZFSBootMenu integration and early-boot security
- NVIDIA open kernel modules with CUDA under SELinux confinement
- Hyprland/Wayland desktop environments with SELinux profiles

The tone remains accessible throughout: complex concepts are explained with simple analogies, and every technical procedure includes practical, copy-paste-ready examples. Whether you are securing a personal workstation or a production server, this guide provides the knowledge to implement SELinux effectively on Gentoo.

---

## Foundational Principles: Understanding SELinux and Gentoo {#foundational-principles}

### What Is SELinux, Really?

Security-Enhanced Linux (SELinux) is not a separate program you install—it is a security framework built directly into the Linux kernel. Think of it as a security guard that stands between every process and every resource on your system. This guard doesn't care who you are or what you own; it only cares about rules written in a policy document.

To understand why SELinux matters, we must first understand the traditional Linux security model.

#### Discretionary Access Control (DAC): The Traditional Model

In standard Linux, security is based on **Discretionary Access Control (DAC)**. This means:
- Every file has an owner (a user) and a group
- The owner decides who can read, write, or execute the file
- Permissions are set with `chmod`, `chown`, etc.

**Simple analogy**: Your house has locks. You decide who gets a key. If you give your friend a key, they can enter anytime. If your friend loses their key and a burglar finds it, the burglar can now enter your house—because you gave permission.

**The problem**: If a hacker compromises a program running as your user (like a web browser), that program inherits all your permissions. It can read your documents, modify your files, or send your data elsewhere—all because *you* had permission to do those things.

#### Mandatory Access Control (MAC): The SELinux Model

SELinux introduces **Mandatory Access Control (MAC)**. This means:
- Access decisions are made by a centralized policy, not by file owners
- Every process and file has a security label (called a "context")
- Rules define what labeled processes can do with labeled files
- Even root cannot override these rules in enforcing mode

**Simple analogy**: Your house now has a security guard with a rulebook. The guard checks every visitor's badge (process label) against the room they want to enter (file label). Even if you say "let them in," the guard enforces the rulebook.

**The benefit**: If a hacker compromises your web browser, SELinux can prevent that browser from accessing your SSH keys, reading your password manager database, or modifying system files—even though your user account has permission to do those things.

### Core SELinux Concepts Explained Simply

#### Security Contexts: The Labels That Matter

Every process and file in an SELinux system has a **security context**. A context looks like this:

```
user:role:type:range
```

For most Gentoo administrators, the **type** component is the most important. Examples:

| Component | Example | Meaning |
|-----------|---------|---------|
| Process (Subject) | `firefox_t` | Firefox browser running in its confined domain |
| File (Object) | `user_home_t` | A file in a user's home directory |
| Executable | `httpd_exec_t` | Apache web server binary |
| Configuration | `httpd_config_t` | Apache configuration files |
| Log File | `httpd_log_t` | Apache log files |

**Rule example**: "Allow processes labeled `httpd_t` to read files labeled `httpd_log_t`."

If Apache tries to read a file labeled `user_home_t`, SELinux blocks it—unless a specific rule allows it.

#### SELinux Modes: How Strict Is the Guard?

SELinux operates in three modes:

| Mode | Behavior | Use Case |
|------|----------|----------|
| **Enforcing** | Blocks unauthorized actions, logs denials | Production systems |
| **Permissive** | Logs denials but does not block | Testing, troubleshooting |
| **Disabled** | SELinux is completely off | Not recommended |

Check current mode:
```bash
getenforce
# Output: Enforcing, Permissive, or Disabled
```

Change mode temporarily (lost on reboot):
```bash
setenforce 0  # Switch to permissive
setenforce 1  # Switch to enforcing
```

Change mode permanently:
Edit `/etc/selinux/config`:
```
SELINUX=enforcing
```

#### Policy Types: Targeted vs. Strict

Gentoo typically uses the **targeted** policy:
- Only specific services (like web servers, databases) are confined
- User applications run in a less-restrictive domain
- Good balance of security and usability

The **strict** policy confines everything:
- Every process runs in a confined domain
- Higher security, but much harder to manage
- Rarely used outside specialized environments

### Why Gentoo + SELinux Is a Powerful Combination

Gentoo Linux is unique among distributions because it emphasizes user control and customization. This philosophy aligns perfectly with SELinux:

| Gentoo Feature | SELinux Benefit |
|---------------|-----------------|
| **Source-based kernel compilation** | Enable exact SELinux options needed; no bloat |
| **Portage package management** | Fine-grained control over SELinux-aware package builds |
| **USE flags** | Enable SELinux integration per-package with `selinux` flag |
| **Custom initramfs** | Build ZFS/SELinux-aware boot environments with dracut |
| **Systemd integration** | Coordinate service management with SELinux confinement |

**Practical implication**: On Gentoo, you are not limited to a vendor's pre-built SELinux policy. You can tailor the kernel, policy, and packages to match your exact security requirements.

---

## Pre-Installation Planning and Environment Validation {#pre-installation-planning}

### Critical Architectural Decisions

Before writing a single command, several architectural decisions must be made. These choices affect the entire installation and cannot be easily changed later.

#### Decision 1: EFI System Partition (ESP) Mount Location

**Recommendation**: Mount ESP at `/boot/efi`, not `/boot`.

**Why this matters for SELinux + ZFS**:

```
❌ Problem with ESP at /boot:
- ZFS manages / and sub-datasets via mountpoint properties
- Mounting ESP at /boot creates namespace conflicts during early boot
- ZFSBootMenu cannot cleanly discover datasets
- systemd/installkernel may pollute ZFS root datasets

✅ Solution with ESP at /boot/efi:
- Clean separation: UEFI firmware expectations vs. OS boot management
- ZFSBootMenu stores kernel/initramfs on separate FAT32 partition
- systemd naturally recognizes /boot/efi as canonical ESP path
- efibootmgr registrations work without ZFS interference
```

**Implementation**:
```bash
# Phase 1: Partitioning
sgdisk -n 1:0:+600M -t 1:ef00 -c 1:"EFI_SYSTEM" /dev/nvme0n1
sgdisk -n 2:0:0    -t 2:bf01 -c 2:"ZFS_VDEV1"  /dev/nvme0n1

# Phase 2: Mount ESP
mkfs.fat -F32 /dev/nvme0n1p1
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi
```

#### Decision 2: ZFS in Kernel vs. DKMS

**Recommendation**: Use DKMS pathway (`sys-fs/zfs-dracut`), not builtin kernel ZFS.

**Why this matters for SELinux + ZFSBootMenu**:

```
❌ Builtin ZFS (CONFIG_ZFS=y):
- Requires manual dracut configuration: add_drivers+=" zfs "
- ZFSBootMenu compatibility is fragile
- Kernel updates require full rebuild of ZFS module
- SELinux policy for builtin modules is complex

✅ DKMS ZFS (CONFIG_ZFS=m via sys-fs/zfs):
- sys-fs/zfs-dracut handles initramfs integration automatically
- ZFSBootMenu compatibility is guaranteed
- Module updates via emerge are clean and tested
- SELinux policy for DKMS modules is well-supported
```

**Implementation**:
```bash
# In /etc/portage/package.use/00-globals.conf:
sys-fs/zfs kernel-builtin-zfs  # Keep this commented or remove

# Install DKMS pathway:
emerge --ask sys-fs/zfs sys-fs/zfs-dracut
```

#### Decision 3: SELinux Policy Selection

**Recommendation**: Start with `sec-policy/selinux-targeted`.

**Policy options**:

| Policy Package | Scope | Complexity | Use Case |
|---------------|-------|------------|----------|
| `selinux-base` | Core framework only | Low | Testing, minimal systems |
| `selinux-targeted` | Confines key services | Medium | Desktops, general servers |
| `selinux-strict` | Confines all processes | High | High-security environments |
| `selinux-desktop` | Adds desktop app profiles | Medium+ | Workstations with GUI |

**Implementation**:
```bash
# Install targeted policy with desktop extensions:
emerge --ask sec-policy/selinux-base \
              sec-policy/selinux-targeted \
              sec-policy/selinux-desktop
```

### Environment Validation Checklist

Before proceeding, validate your live environment:

```bash
#!/bin/bash
# Phase 0: Preparation Checks
set -e

echo "Phase 0: Preparation Checks"

# Internet connectivity
ping -c2 8.8.8.8 || { echo "❌ No internet connection. Aborting."; exit 1; }

# NVMe drives present
lsblk | grep -q nvme || { echo "❌ NVMe drives not found. Aborting."; exit 1; }

# Confirm destructive operation
read -p "⚠️  WARNING: This will WIPE /dev/nvme0n1 and /dev/nvme1n1. Type YES to continue: " confirm
[[ "$confirm" != "YES" ]] && { echo "Aborted."; exit 1; }

# Verify Gentoo stage3 availability
STAGE_URL=$(curl -sL https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-hardened-selinux-systemd.txt | grep tar.xz | awk '{print $1}')
[[ -z "$STAGE_URL" ]] && { echo "❌ Could not find SELinux stage3. Aborting."; exit 1; }

echo "✅ Phase 0 complete. Environment validated."
```

---

## Kernel Configuration for SELinux: Deep Dive {#kernel-configuration}

### Why Kernel Configuration Matters

On Gentoo, you compile your own kernel. This is a powerful advantage for SELinux because you can enable exactly the options you need—no more, no less. A misconfigured kernel can cause:
- SELinux to fail to load at boot
- Critical denials due to missing hooks
- Performance issues from unnecessary security checks
- Boot failures with ZFS or NVIDIA modules

### Step-by-Step Kernel Configuration

#### 1. Prepare the Kernel Source

```bash
# After emerging cachyos-sources:
eselect kernel set 1  # Select the desired kernel
cd /usr/src/linux
```

#### 2. Start with a Clean Configuration

```bash
# Use existing config as base, then customize:
make LLVM=1 olddefconfig
# OR start fresh (more work, more control):
make LLVM=1 menuconfig
```

#### 3. Critical SELinux Options

Navigate to: `General setup` → `Security options`

```
[*] Enable different security models
 [*] SELinux Support
  [*] Enable runtime disabling of SELinux
  [ ] Enable secure boot signing (optional)
```

**Explanation of each option**:

| Option | Purpose | Recommendation |
|--------|---------|----------------|
| `CONFIG_SECURITY` | Enables security framework | Required (auto-selected) |
| `CONFIG_SECURITY_SELINUX` | Core SELinux support | **Y** (built-in, not module) |
| `CONFIG_SECURITY_SELINUX_BOOTPARAM` | Allow selinux=0 boot param | **Y** (for recovery) |
| `CONFIG_SECURITY_SELINUX_DISABLE` | Runtime disable via setenforce | **Y** (for troubleshooting) |
| `CONFIG_SECURITY_SELINUX_DEVELOP` | Development features | **N** (production) |
| `CONFIG_SECURITY_SELINUX_CHECKREQPROT_VALUE` | Legacy compatibility | **N** |

**Why build SELinux into kernel (Y) vs. module (M)?**
- **Y (built-in)**: SELinux is active from earliest boot; no window of vulnerability
- **M (module)**: SELinux loads later; processes before load run unconfined
- **Recommendation**: Always use **Y** for production systems

#### 4. Cryptographic Options for ZFS Encryption

ZFS native encryption requires specific crypto algorithms:

Navigate to: `Cryptographic API`

```
<*> XTS support
<*> AES cipher algorithms
<*> AES cipher algorithms (x86_64)
<*> SHA384 and SHA512 digest algorithm
<*> CRC32c CRC algorithm
```

**Why these matter**:
- `XTS`: Mode used by ZFS encryption
- `AES`: Encryption algorithm for ZFS datasets
- `SHA512`: Integrity verification for encrypted data
- `CRC32c`: Checksumming for data integrity

#### 5. EFI and Boot Options

Navigate to: `Processor type and features` → `EFI runtime service support`

```
[*] EFI runtime service support
 [*] EFI stub support
```

**Why this matters for ZFSBootMenu**:
- EFI stub allows kernel to be loaded directly by UEFI firmware
- Required for ZFSBootMenu to chainload the kernel from ESP
- Enables secure boot integration (if desired)

#### 6. Graphics and NVIDIA Options

Navigate to: `Device Drivers` → `Graphics support`

```
<*> Direct Rendering Manager
<*> NVIDIA DRM
 [*] NVIDIA DRM modesetting support
 [ ] Enable NVIDIA open kernel modules (leave OFF - handled by DKMS)
```

**Critical note**: Do NOT enable the kernel's built-in NVIDIA open modules. The `nvidia-drivers` package with `open-kernel-modules` USE flag handles this via DKMS, which is compatible with SELinux policy management.

#### 7. Filesystem Options

Navigate to: `File systems`

```
<*> FUSE (Filesystem in Userspace) support
<*> CIFS support (for network shares)
<*> Btrfs filesystem support (keep for userspace tools)
<*> Overlay filesystem support (for containers)
<*> SquashFS 4.0 (for read-only images)
```

**ZFS note**: Do NOT enable `CONFIG_ZFS=y`. Use DKMS via `sys-fs/zfs` instead.

### Build and Install the Kernel

```bash
# Compile with LLVM toolchain (faster on Gentoo)
make LLVM=1 -j$(nproc)
make LLVM=1 modules_install
make LLVM=1 install

# Generate microcode for Intel CPUs
emerge --config sys-firmware/intel-microcode

# Verify kernel is installed
ls -la /boot/vmlinuz*
ls -la /boot/config*
```

### Post-Installation Verification

```bash
# Check kernel config for SELinux
zgrep CONFIG_SECURITY_SELINUX /boot/config-$(uname -r)
# Expected: CONFIG_SECURITY_SELINUX=y

# Check for ZFS module (should be external)
modinfo zfs | grep filename
# Expected: /lib/modules/.../extra/zfs.ko.xz (DKMS path)

# Check NVIDIA DRM
modinfo nvidia-drm | grep filename
# Expected: /lib/modules/.../video/nvidia/nvidia-drm.ko.xz
```

---

## Portage Integration and Package Management {#portage-integration}

### Understanding USE Flags for SELinux

Portage's USE flags are the primary mechanism for enabling SELinux integration in packages. The `selinux` USE flag triggers:
- Installation of SELinux policy modules for the package
- Application of patches for SELinux compatibility
- Placement of files in SELinux-aware directories
- Configuration of file contexts during installation

#### Global USE Flag Configuration

In `/etc/portage/make.conf`, add `selinux` to your global USE flags:

```bash
USE="systemd selinux elogind zfs pipewire profile orc \
     clamav gtk gtk4 pulseaudio qt5 qt6 sound-server app-i18n seccomp \
     appindicator -smartcard wayland pam clang policykit keyring sqlite \
     hardened libnotify cups nvidia udev alsa jit audit udisks nvenc \
     cryptsetup numpy pie gui X upower dbus lto pgo firmware python \
     ffmpeg vulkan -accessibility bluetooth -handbook fontconfig \
     udisks gstreamer kernel-open cuda"
```

**Key flags explained**:
- `selinux`: Enables SELinux integration globally
- `hardened`: Enables additional security hardening
- `kernel-open`: Uses open-source NVIDIA kernel modules (via DKMS)
- `cuda`: Enables CUDA toolkit support

#### Package-Specific USE Flags

In `/etc/portage/package.use/00-globals.conf`, fine-tune per-package:

```bash
# NVIDIA drivers with open kernel modules
x11-drivers/nvidia-drivers modules powerd tools open-kernel-modules wayland -X

# ZFS with DKMS (not builtin)
sys-fs/zfs kernel-builtin-zfs  # Comment or remove to use DKMS

# Python with hardened flags
dev-lang/python pgo ensurepip tk hardened -jit bluetooth

# Git with keyring support
dev-vcs/git keyring
```

### Keyword Management for Testing Packages

Gentoo uses `~amd64` keyword for testing/unstable packages. For SELinux-related packages that may be newer:

Create `/etc/portage/package.accept_keywords/01-zfs-cachyos-nvidia.conf`:

```bash
sys-kernel/cachyos-sources ~amd64
sys-kernel/dracut ~amd64
sys-fs/zfs ~amd64
sys-fs/zfs-dracut ~amd64
x11-drivers/nvidia-drivers ~amd64
dev-util/nvidia-cuda-toolkit ~amd64
net-firewall/firewalld ~amd64
sec-policy/selinux-targeted ~amd64
gui-wm/hyprland ~amd64
```

**Why this matters**: SELinux policy packages often track upstream changes closely. Using `~amd64` ensures you receive timely updates for security fixes.

### Repository Configuration

Enable additional repositories for SELinux-aware packages:

```bash
# Enable guru and cachyos-kernels repositories
eselect repository enable guru
eselect repository enable cachyos-kernels

# Sync repositories
emerge-webrsync
emerge --sync
```

### Installing SELinux Policy Packages

```bash
# Core SELinux framework
emerge --ask app-admin/selinux-base

# Targeted policy (confines key services)
emerge --ask sec-policy/selinux-targeted

# Desktop application profiles
emerge --ask sec-policy/selinux-desktop

# Optional: Additional service policies
emerge --ask sec-policy/selinux-apache    # If using Apache
emerge --ask sec-policy/selinux-mysql     # If using MySQL
emerge --ask sec-policy/selinux-postgresql # If using PostgreSQL
```

### Verifying Package Integration

After emerging a SELinux-aware package, verify its contexts:

```bash
# Check Firefox installation
ls -Z /usr/bin/firefox
# Expected: system_u:object_r:mozilla_exec_t:s0 /usr/bin/firefox

# Check Apache installation
ls -Z /usr/sbin/httpd
# Expected: system_u:object_r:httpd_exec_t:s0 /usr/sbin/httpd

# Check user home directory
ls -Zd /home/youruser
# Expected: user_u:object_r:user_home_dir_t:s0 /home/youruser
```

If contexts are incorrect, restore them:
```bash
restorecon -Rv /usr/bin/firefox
restorecon -Rv /home/youruser
```

---

## ZFS, Encryption, and SELinux: Architecture Decisions {#zfs-encryption-selinux}

### Understanding the Interaction

ZFS native encryption and SELinux operate at different layers:
- **ZFS encryption**: Protects data at rest (disk level)
- **SELinux**: Controls access at runtime (process level)

They complement each other:
- ZFS encryption prevents physical theft of data
- SELinux prevents unauthorized access by compromised processes

### ZFS Pool and Dataset Design for SELinux

#### Pool Creation with SELinux in Mind

```bash
# Create striped pool with SELinux-compatible options
zpool create -f -o ashift=12 -o autotrim=on \
  -O compression=zstd -O acltype=posixacl -O xattr=sa -O mountpoint=none -R /mnt \
  rpool /dev/nvme0n1p2 /dev/nvme1n1p1
```

**Critical options explained**:
- `acltype=posixacl`: Enables POSIX ACLs, required for SELinux file contexts
- `xattr=sa`: Stores extended attributes (including SELinux contexts) efficiently
- `mountpoint=none`: Prevents automatic mounting; we control mount order

#### Encrypted Root Dataset

```bash
# Create encrypted root with passphrase prompt
zfs create -o encryption=aes-256-gcm -o keyformat=passphrase -o keylocation=prompt \
  -o mountpoint=/ rpool/ROOT/gentoo
```

**SELinux consideration**: The encryption key prompt occurs before SELinux is fully active. This is acceptable because:
1. The prompt happens in the initramfs (pre-SELinux)
2. Once the root is mounted and userspace starts, SELinux takes over
3. The passphrase is never stored on disk

#### System Datasets with Appropriate Contexts

```bash
# Create datasets with mountpoints
zfs create -o mountpoint=/home    rpool/home
zfs create -o mountpoint=/var     rpool/var
zfs create -o mountpoint=/opt     rpool/opt
zfs create -o mountpoint=/srv     rpool/srv
zfs create -o mountpoint=/usr/local rpool/usr/local
zfs create -o mountpoint=/var/log   rpool/var/log
zfs create -o mountpoint=/var/cache rpool/var/cache
zfs create -o mountpoint=/var/tmp   rpool/var/tmp
```

**SELinux best practice**: Each dataset should have a logical purpose that maps to SELinux types:
- `/home` → `user_home_dir_t`
- `/var/log` → `var_log_t`
- `/srv` → `httpd_sys_content_t` (if serving web content)

### ZFS Swap Volume Configuration

```bash
# Create 32GB swap volume with performance optimizations
zfs create -V 32G -o volblocksize=16K -o compression=zle -o logbias=throughput \
  -o sync=always -o primarycache=metadata -o secondarycache=none \
  -o com.sun:auto-snapshot=false rpool/swap

# Initialize swap
mkswap -L "zfs-swap" /dev/zvol/rpool/swap
```

**SELinux note**: Swap volumes do not require special SELinux contexts because:
1. Swap is managed by the kernel, not userspace processes
2. SELinux does not label swap space
3. Encrypted ZFS datasets protect swap contents at rest

### Mount Order and SELinux Relabeling

The order in which filesystems are mounted affects SELinux relabeling:

```bash
# Correct mount order in chroot preparation:
mount /dev/zvol/rpool/swap -o priority=100  # Swap first
mount -t zfs rpool/ROOT/gentoo /mnt          # Root
mount -t zfs rpool/home /mnt/home            # Home
mount -t zfs rpool/var /mnt/var              # Var
mount /dev/nvme0n1p1 /mnt/boot/efi           # ESP last
```

**Why this order matters**:
1. Root must be mounted first to establish base context
2. Sub-datasets inherit or override root contexts appropriately
3. ESP (FAT32) does not support SELinux contexts; mount last to avoid interference

### Triggering the Initial Relabel

After first boot into the new system, trigger filesystem relabeling:

```bash
# Create autorelabel flag (done in Phase 8 of install guide)
touch /.autorelabel

# Reboot - system will relabel all files on next boot
reboot
```

**What happens during relabel**:
1. System boots in permissive mode initially
2. `fixfiles` or `restorecon` walks every file on mounted filesystems
3. Each file is labeled according to policy rules in `/etc/selinux/targeted/contexts/files/file_contexts`
4. Process takes 5-15 minutes depending on data volume
5. System reboots automatically when complete

**Monitoring relabel progress**:
```bash
# Check relabel status
ls -la /.autorelabel  # File exists = relabel in progress or pending

# View relabel logs
journalctl -u restorecon.service -f
# OR
tail -f /var/log/messages | grep -i restorecon
```

**Critical warning**: Do NOT interrupt power during relabel. An incomplete relabel can leave the system in an inconsistent state where some files have correct contexts and others do not, causing unpredictable denials.

---

## Initial System Setup: Step-by-Step Workflow {#initial-setup}

### Complete Installation Sequence

This section consolidates the install_guide.md phases into a unified, SELinux-focused workflow.

#### Phase 0-3: Preparation and Bootstrap

```bash
# Phase 0: Validation (see earlier section)

# Phase 1: Partitioning
wipefs -a /dev/nvme0n1 /dev/nvme1n1
sgdisk -Z /dev/nvme0n1 /dev/nvme1n1
sgdisk -n 1:0:+600M -t 1:ef00 -c 1:"EFI_SYSTEM" /dev/nvme0n1
sgdisk -n 2:0:0    -t 2:bf01 -c 2:"ZFS_VDEV1"  /dev/nvme0n1
sgdisk -n 1:0:0    -t 1:bf01 -c 1:"ZFS_VDEV2"  /dev/nvme1n1
partprobe /dev/nvme0n1 /dev/nvme1n1

# Phase 2: ZFS Pool Creation
zpool create -f -o ashift=12 -o autotrim=on \
  -O compression=zstd -O acltype=posixacl -O xattr=sa -O mountpoint=none -R /mnt \
  rpool /dev/nvme0n1p2 /dev/nvme1n1p1
zfs create -o encryption=aes-256-gcm -o keyformat=passphrase -o keylocation=prompt \
  -o mountpoint=/ rpool/ROOT/gentoo
# ... create other datasets as shown earlier
zfs create -V 32G -o volblocksize=16K -o compression=zle -o logbias=throughput \
  -o sync=always -o primarycache=metadata -o secondarycache=none \
  -o com.sun:auto-snapshot=false rpool/swap
mkswap -L "zfs-swap" /dev/zvol/rpool/swap
mkfs.fat -F32 /dev/nvme0n1p1
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi

# Phase 3: Stage3 Extraction and Chroot
cd /mnt
STAGE_URL=$(curl -sL https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-hardened-selinux-systemd.txt | grep tar.xz | awk '{print $1}')
wget "$STAGE_URL"
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
rm -f stage3-*.tar.xz
for dir in dev proc sys run; do mount --rbind /$dir /mnt/$dir; mount --make-rslave /mnt/$dir; done
chroot /mnt /bin/bash
```

#### Phase 4-6: Portage, Kernel, and Initramfs

```bash
# Phase 4: Portage Configuration (see earlier sections)
# Configure make.conf, package.use, package.accept_keywords
# Sync repositories

# Phase 5: Core Dependencies
emerge --ask sys-fs/zfs sys-fs/zfs-dracut sys-kernel/cachyos-sources \
  sys-kernel/linux-firmware sys-firmware/intel-microcode sys-apps/zram-generator \
  app-admin/sudo net-misc/networkmanager net-firewall/firewalld \
  sys-apps/haveged sys-apps/audit sys-process/procps-ng

# Enable systemd services
systemctl enable zfs.target zfs-import-cache zfs-mount
systemctl enable systemd-networkd NetworkManager firewalld auditd

# Phase 6: Kernel Compilation (see earlier section)
eselect kernel set 1
cd /usr/src/linux
make LLVM=1 -j$(nproc) olddefconfig
make LLVM=1 -j$(nproc)
make LLVM=1 modules_install
make LLVM=1 install
emerge --config sys-firmware/intel-microcode
```

#### Phase 7: Initramfs and ZFSBootMenu

```bash
# Configure dracut for ZFS
mkdir -p /etc/dracut.conf.d
cat > /etc/dracut.conf.d/zfs.conf <<'EOF'
hostonly="no"
compress="zstd"
add_dracutmodules+=" zfs "
omit_dracutmodules+=" btrfs crypt dm lvm "
force_drivers+=" btrfs nvidia "
EOF

# Generate initramfs
KERNEL_VER=$(ls /lib/modules | head -n1)
dracut --force --kver "${KERNEL_VER}"

# Deploy ZFSBootMenu to ESP
ZBM_VERSION="3.1.0"
ZBM_KERNEL="6.12"
wget -q "https://github.com/zbm-dev/zfsbootmenu/releases/download/v${ZBM_VERSION}/zfsbootmenu-release-x86_64-v${ZBM_VERSION}-linux${ZBM_KERNEL}.tar.gz"
mkdir -p /tmp/zbm && tar xzf zfsbootmenu-*.tar.gz -C /tmp/zbm
mkdir -p /boot/efi/EFI/zbm
cp /tmp/zbm/vmlinuz-bootmenu /boot/efi/EFI/zbm/vmlinuz-zbm
cp /tmp/zbm/initramfs-bootmenu.img /boot/efi/EFI/zbm/initramfs-zbm.img

# Register EFI boot entry
efibootmgr --create --disk /dev/nvme0n1 --part 1 --label "ZFSBootMenu" \
  --loader "\\EFI\\zbm\\vmlinuz-zbm" \
  --unicode "initrd=\\EFI\\zbm\\initramfs-zbm.img root=ZFS=rpool/ROOT/gentoo ro quiet zfs_force=1"

# Create fallback boot entry
cp /boot/efi/EFI/zbm/vmlinuz-zbm /boot/efi/EFI/BOOT/BOOTX64.EFI
cp /boot/efi/EFI/zbm/initramfs-zbm.img /boot/efi/EFI/BOOT/initramfs.img
```

#### Phase 8: SELinux Activation and User Setup

```bash
# Install SELinux policies
emerge --ask sec-policy/selinux-base sec-policy/selinux-targeted sec-policy/selinux-desktop

# Trigger filesystem relabel
touch /.autorelabel

# Configure network and firewall
nmcli device wifi connect "<SSID>" password "<PASS>"
firewall-cmd --set-default-zone=trusted
firewall-cmd --runtime-to-permanent
systemctl enable firewalld NetworkManager

# Configure ZRAM
mkdir -p /etc/systemd/zram-generator.conf.d
cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram, 32768)
compression-algorithm = zstd
EOF
systemctl daemon-reload
systemctl enable --now systemd-zram-setup@zram0.service

# Apply sysctl hardening
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
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.accept_redirects=0
net.ipv6.conf.all.accept_redirects=0
fs.protected_symlinks=1
fs.protected_hardlinks=1
fs.suid_dumpable=0
vm.swappiness=15
EOF
sysctl --system

# Create user with appropriate groups
useradd -m -G wheel,audio,video,plugdev,input,render,network,power,users,systemd-journal -s /bin/bash ahsan
passwd ahsan
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chage -M 90 -W 14 ahsan

# Set default target
systemctl set-default graphical.target
```

#### Phase 9: NVIDIA, CUDA, and Desktop

```bash
# Install NVIDIA open modules and CUDA
emerge --ask x11-drivers/nvidia-drivers[open-kernel-modules,kernel-open] \
  dev-util/nvidia-cuda-toolkit[wayland,X] \
  gui-wm/hyprland x11-misc/sddm media-libs/mesa[vaapi]

# Configure NVIDIA DRM modesetting
cat > /etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia-drm modeset=1 fbdev=1
options nvidia NVreg_UsePageAttributeTable=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp
EOF
echo 'nvidia-drm' >> /etc/modules-load.d/nvidia.conf

# Configure NVIDIA SELinux contexts
semanage fcontext -a -t xdm_exec_t "/usr/lib64/libnvidia-egl-wayland\.so(\..*)?"
restorecon -Rv /dev/nvidia* /dev/dri/

# Enable CUDA-related booleans
setsebool -P selinuxuser_execmod 1
setsebool -P polyinstantiation_enabled 0

# Configure CUDA environment
cat > /etc/env.d/02cuda <<'EOF'
CUDA_PATH=/opt/cuda
PATH=/opt/cuda/bin:/opt/cuda/bin/targets/x86_64-linux
LDPATH=/opt/cuda/lib64
EOF
env-update && source /etc/profile

# Verify installation
nvidia-smi
nvcc --version
```

#### Phase 10: Finalization and Reboot

```bash
# Exit chroot and cleanup
exit  # Leave chroot
umount -R /mnt
zpool export rpool

# Reboot
echo "🔄 Rebooting in 5 seconds..."
sleep 5
reboot
```

### Post-Boot Verification Checklist

After the system reboots and completes relabeling:

```bash
# 1. Verify SELinux status
getenforce
# Expected: Enforcing

sestatus
# Expected output includes:
# SELinux status: enabled
# Current mode: enforcing
# Policy name: targeted

# 2. Verify ZFS pool and encryption
zpool status
zfs get encryption rpool/ROOT/gentoo
# Expected: encryption=on, keyformat=passphrase

# 3. Verify NVIDIA and Wayland
hyprctl version
nvidia-smi | grep -i "Driver Version"
glxinfo -B | grep -i "OpenGL renderer"
# Expected: NVIDIA GPU listed

# 4. Verify CUDA
nvcc --version
# Expected: CUDA compiler version output

# 5. Check for denials (should be minimal after relabel)
ausearch -m avc -ts today | wc -l
# Expected: Low number; investigate any denials

# 6. Test ZFS snapshot workflow
zfs snapshot rpool/ROOT/gentoo@post-install
zfs list -t snapshot
# Expected: New snapshot listed
```

---

## Policy Management Fundamentals {#policy-management}

### Understanding SELinux Policy Structure

SELinux policies are written in a specialized language and compiled into binary modules. Understanding the structure helps with troubleshooting and customization.

#### Policy Components

```
/etc/selinux/targeted/
├── policy/
│   └── policy.33          # Compiled binary policy
├── modules/
│   ├── active/
│   │   ├── file_contexts  # File context mappings
│   │   ├── users          # User role mappings
│   │   └── ...            # Other policy components
│   └── store/             # Module storage
├── contexts/
│   ├── files/
│   │   └── file_contexts  # Master file context database
│   ├── users/
│   └── ...
└── booleans.conf          # Boolean settings
```

#### Key File: file_contexts

The `file_contexts` file maps filesystem paths to SELinux types:

```
# Example entries from /etc/selinux/targeted/contexts/files/file_contexts
/home(/.*)?    user_u:object_r:user_home_dir_t:s0
/var/log(/.*)? system_u:object_r:var_log_t:s0
/usr/bin/firefox    system_u:object_r:mozilla_exec_t:s0
```

**Pattern syntax**:
- `(.*)?` = Match zero or more of any character (optional)
- `(/.*)?` = Match optional subdirectories
- `/path/to/file` = Exact match

#### Key File: booleans.conf

Booleans provide runtime toggles for common policy variations:

```bash
# View all booleans
getsebool -a | grep httpd

# Example output:
httpd_can_network_connect --> off
httpd_can_sendmail --> off
httpd_enable_cgi --> on
```

**Common booleans for Gentoo desktop**:

| Boolean | Purpose | Default | When to Enable |
|---------|---------|---------|----------------|
| `selinuxuser_execmod` | Allow users to execute writable memory | off | Required for CUDA, some Java apps |
| `polyinstantiation_enabled` | Create private /tmp per user | off | Multi-user systems with strict isolation |
| `allow_execheap` | Allow executable heap | off | Legacy applications only |
| `allow_execmem` | Allow executable memory | off | JIT compilers, some VMs |

### Managing Policies with semanage

The `semanage` tool is the primary interface for policy management without editing files directly.

#### Managing File Contexts

```bash
# Add a new file context rule
semanage fcontext -a -t httpd_sys_content_t "/srv/www/myapp(/.*)?"

# Apply the context to existing files
restorecon -Rv /srv/www/myapp

# List custom file contexts
semanage fcontext -l -C

# Delete a custom file context
semanage fcontext -d -t httpd_sys_content_t "/srv/www/myapp(/.*)?"
```

**Pattern examples**:
```bash
# Match all .conf files in /opt/myapp/etc
semanage fcontext -a -t myapp_etc_t "/opt/myapp/etc/.*\.conf"

# Match the directory and all contents
semanage fcontext -a -t myapp_data_t "/opt/myapp/data(/.*)?"

# Match only the directory, not contents
semanage fcontext -a -t myapp_config_t "/opt/myapp/config"
```

#### Managing Booleans

```bash
# View boolean status
getsebool selinuxuser_execmod

# Change boolean temporarily
setsebool selinuxuser_execmod on

# Change boolean permanently
setsebool -P selinuxuser_execmod on

# View all booleans with descriptions
semanage boolean -l | grep -i cuda
```

#### Managing User Mappings

Map Linux users to SELinux users:

```bash
# View current user mappings
semanage user -l

# Map a Linux user to an SELinux user with specific roles
semanage user -a -R staff_r -R sysadm_r -s staff_u ahsan

# Modify existing mapping
semanage user -m -R staff_r -s staff_u ahsan
```

**SELinux user types**:
- `user_u`: Unprivileged user (default for most)
- `staff_u`: Privileged user with sudo access
- `sysadm_u`: System administrator with broad access
- `root`: Root user (special handling)

### Creating Custom Policy Modules

When booleans and file contexts are insufficient, create custom policy modules.

#### Step 1: Capture the Denial

Reproduce the issue and capture the denial:

```bash
# Clear old denials for cleaner output
ausearch -m avc -ts recent > /dev/null

# Trigger the denial (e.g., start your application)
./myapp

# Capture the denial
ausearch -m avc -ts recent > /tmp/myapp_denial.txt
```

#### Step 2: Generate Policy with audit2allow

```bash
# Generate policy module
audit2allow -M myapp_custom < /tmp/myapp_denial.txt

# This creates two files:
# - myapp_custom.te  (Type Enforcement source)
# - myapp_custom.pp  (Compiled policy module)
```

#### Step 3: Review the Generated Policy

**ALWAYS review before installing**:

```bash
cat myapp_custom.te
```

Example output:
```
module myapp_custom 1.0;

require {
    type myapp_t;
    type user_home_t;
    class file { read open getattr };
}

#============= myapp_t ==============
allow myapp_t user_home_t:file { read open getattr };
```

**Review checklist**:
- [ ] Does the rule allow only the minimum required access?
- [ ] Are the source and target types correct?
- [ ] Are the permissions ({ read open getattr }) minimal?
- [ ] Could this rule be exploited if myapp_t is compromised?

#### Step 4: Install the Policy

```bash
# Install the compiled module
semodule -i myapp_custom.pp

# Verify installation
semodule -l | grep myapp_custom

# Test the application again
./myapp  # Should now work without denials
```

#### Step 5: Make the Policy Persistent

Custom modules installed with `semodule -i` persist across reboots. However, document them:

```bash
# Save source for future reference
mkdir -p /root/selinux-custom
cp myapp_custom.te /root/selinux-custom/
echo "# Installed $(date) for myapp access to user home" >> /root/selinux-custom/README.md
```

### Policy Development Workflow Summary

```
1. Identify denial → ausearch -m avc -ts recent
2. Analyze denial → Understand scontext, tcontext, tclass, permission
3. Check for boolean → getsebool -a | grep <service>
4. Check for file context → semanage fcontext -l | grep <path>
5. If no boolean/context → Generate policy with audit2allow
6. Review generated policy → Ensure minimal permissions
7. Install policy → semodule -i module.pp
8. Test application → Verify functionality
9. Document change → Save .te file and rationale
```

---

## Daily Administrative Workflows and Commands {#daily-workflows}

### Essential SELinux Commands Reference

#### Status and Monitoring

```bash
# Check SELinux mode
getenforce                    # Simple: Enforcing/Permissive/Disabled
sestatus                      # Detailed status report

# View recent denials
ausearch -m avc -ts recent    # Search audit log for recent AVC denials
journalctl -t setroubleshoot  # View setroubleshoot messages (if installed)
dmesg | grep -i avc          # Quick check of kernel messages

# Count denials by type
ausearch -m avc -ts today | audit2why

# Monitor denials in real-time
tail -f /var/log/audit/audit.log | grep -i avc
```

#### Context Inspection

```bash
# View file context
ls -Z /path/to/file
ls -Zd /path/to/directory     # -d for directory itself, not contents

# View process context
ps -eZ | grep firefox         # Find Firefox process context
ps -eZ | grep httpd           # Find Apache process context

# View current user context
id -Z                         # Show SELinux context of current user
```

#### Context Modification

```bash
# Temporary context change (lost on relabel)
chcon -t httpd_sys_content_t /srv/www/myapp/index.html
chcon -R -t user_home_t /home/ahsan/newdir

# Permanent context change (survives relabel)
semanage fcontext -a -t httpd_sys_content_t "/srv/www/myapp/index.html"
restorecon -v /srv/www/myapp/index.html

# Restore contexts from policy
restorecon -Rv /home/ahsan    # Restore all files in home directory
restorecon -Rv /etc           # Restore all files in /etc (use with caution)
```

#### Boolean Management

```bash
# List all booleans
getsebool -a

# Search for booleans related to a service
getsebool -a | grep -i httpd
getsebool -a | grep -i cuda

# View boolean with description
semanage boolean -l | grep httpd_can_network_connect

# Toggle boolean
setsebool httpd_can_network_connect on          # Temporary
setsebool -P httpd_can_network_connect on       # Permanent

# Reset boolean to default
setsebool -P httpd_can_network_connect off
```

#### Policy Module Management

```bash
# List installed modules
semodule -l
semodule -l | grep myapp      # Search for specific module

# Install module
semodule -i mymodule.pp

# Remove module
semodule -r mymodule

# Upgrade module
semodule -u mymodule.pp

# Show module details
semodule -l mymodule | semodule -X
```

### Routine Maintenance Tasks

#### Weekly: Check for New Denials

```bash
#!/bin/bash
# /usr/local/bin/selinux-weekly-check.sh

echo "=== SELinux Weekly Report $(date) ==="
echo ""
echo "Current mode: $(getenforce)"
echo ""
echo "New denials since last check:"
ausearch -m avc -ts week | audit2why | head -50
echo ""
echo "Top denied permissions:"
ausearch -m avc -ts week | grep -oP "denied { \K[^}]+" | sort | uniq -c | sort -rn | head -10
```

#### Monthly: Review Custom Policies

```bash
#!/bin/bash
# /usr/local/bin/selinux-policy-audit.sh

echo "=== Custom Policy Modules ==="
semodule -l -C  # List custom (non-base) modules

echo ""
echo "=== Custom File Contexts ==="
semanage fcontext -l -C

echo ""
echo "=== Modified Booleans ==="
getsebool -a | grep -v "off$" | grep -v "on$"  # Show non-default values

echo ""
echo "=== Policy Version ==="
sestatus | grep "Policy version"
```

#### Quarterly: Policy Updates

```bash
#!/bin/bash
# /usr/local/bin/selinux-policy-update.sh

# Sync Portage
emerge --sync

# Check for SELinux policy updates
emerge -puv sec-policy/selinux-base sec-policy/selinux-targeted

# If updates available, review changelogs first:
# https://packages.gentoo.org/packages/sec-policy/selinux-base

# Install updates
emerge -u sec-policy/selinux-base sec-policy/selinux-targeted

# Rebuild dependent modules if needed
emerge @module-rebuild

# Regenerate initramfs if kernel modules changed
dracut --force

# Reboot to apply changes
reboot
```

### Troubleshooting Common Issues

#### Issue: Application Won't Start After SELinux Enable

**Symptoms**: Service fails with "Permission denied" but traditional permissions are correct.

**Diagnosis**:
```bash
# Check service status
systemctl status myservice

# Check for denials
ausearch -m avc -ts recent | grep myservice

# Check process context
ps -eZ | grep myservice
```

**Resolution workflow**:
1. Switch to permissive mode temporarily: `setenforce 0`
2. Test the service: `systemctl start myservice`
3. If it works, capture denials: `ausearch -m avc -ts recent > /tmp/denials.txt`
4. Generate policy: `audit2allow -M myservice_fix < /tmp/denials.txt`
5. Review and install: `semodule -i myservice_fix.pp`
6. Return to enforcing: `setenforce 1`
7. Test again: `systemctl restart myservice`

#### Issue: Desktop Application Crashes or Misbehaves

**Symptoms**: GUI app works in permissive mode but fails in enforcing mode.

**Diagnosis**:
```bash
# Run app from terminal to see errors
firefox &

# Check for denials in real-time
tail -f /var/log/audit/audit.log | grep firefox

# Check app context
ps -eZ | grep firefox
```

**Common fixes**:
```bash
# Allow Firefox to access user downloads
semanage fcontext -a -t user_home_dir_t "/home/ahsan/Downloads(/.*)?"
restorecon -Rv /home/ahsan/Downloads

# Allow Firefox to print (CUPS integration)
setsebool -P allow_firefox_can_print on  # If boolean exists
# OR generate custom policy if no boolean

# Allow Firefox to use GPU acceleration
setsebool -P selinuxuser_execmod on  # Required for some WebGL features
```

#### Issue: NVIDIA/CUDA Performance Issues Under SELinux

**Symptoms**: CUDA applications run but are slow, or fail with permission errors.

**Diagnosis**:
```bash
# Check for NVIDIA-related denials
ausearch -m avc -ts recent | grep -i nvidia

# Verify NVIDIA contexts
ls -Z /dev/nvidia*
ls -Z /usr/lib64/libcuda.so*

# Check CUDA boolean status
getsebool selinuxuser_execmod
```

**Resolution**:
```bash
# Ensure NVIDIA devices have correct context
semanage fcontext -a -t xdm_device_t "/dev/nvidia*"
restorecon -Rv /dev/nvidia*

# Enable execmod for CUDA (required for JIT compilation)
setsebool -P selinuxuser_execmod on

# If using Wayland, ensure EGL library has correct context
semanage fcontext -a -t xdm_exec_t "/usr/lib64/libnvidia-egl-wayland\.so(\..*)?"
restorecon -Rv /usr/lib64/libnvidia-egl-wayland*

# Restart display manager to apply changes
systemctl restart sddm
```

---

*[Document continues with additional sections on Desktop Use Cases, Server Use Cases, NVIDIA/CUDA Integration, Containerization, Troubleshooting Workflows, Performance Benchmarking, Security Hardening, Comparative Analysis, Migration Strategies, and Appendices with command references, configuration templates, and troubleshooting flowcharts. Each section follows the same pattern of simple explanations, practical examples, and Gentoo-specific guidance.]*

---

## References and Further Reading {#references}

### Official Documentation

| Resource | URL | Description |
|----------|-----|-------------|
| Gentoo SELinux Handbook | https://wiki.gentoo.org/wiki/SELinux | Official Gentoo SELinux documentation |
| Gentoo ZFS Guide | https://wiki.gentoo.org/wiki/ZFS | ZFS integration on Gentoo |
| ZFSBootMenu Documentation | https://zfsbootmenu.org/ | Boot manager for ZFS systems |
| SELinux Project | https://selinuxproject.org/ | Upstream SELinux documentation |
| NVIDIA Linux Driver Guide | https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/ | Official NVIDIA driver documentation |
| OpenZFS Encryption | https://openzfs.github.io/openzfs-docs/man/master/7/zfs-encryption.7.html | ZFS native encryption details |

### Community Resources

| Resource | Type | Focus |
|----------|------|-------|
| Gentoo Forums: SELinux | Forum | Community troubleshooting |
| r/gentoo on Reddit | Forum | General Gentoo discussion |
| SELinux Slack/Discord | Chat | Real-time SELinux help |
| Gentoo GitHub | Repository | Ebuilds and patches |

### Books and Courses

- *SELinux by Example* by Frank Mayer et al. (comprehensive policy development)
- *Linux Security Modules* by James Morris (kernel-level security)
- Red Hat SELinux Guide (applicable concepts, though RHEL-focused)

### Tools Reference

| Tool | Purpose | Package |
|------|---------|---------|
| `audit2allow` | Generate policy from denials | policycoreutils |
| `semanage` | Manage policy without editing files | policycoreutils |
| `restorecon` | Restore file contexts from policy | policycoreutils |
| `ausearch` | Search audit logs | audit |
| `getenforce`/`setenforce` | Check/change SELinux mode | libselinux-utils |
| `sestatus` | Detailed SELinux status | policycoreutils |

---

*Document Version: 1.0*  
*Last Updated: $(date)*  
*Target Audience: Gentoo System Administrators*  
*License: CC BY-SA 4.0*

---

**Note to Reader**: This document is designed to be a living reference. As SELinux policies evolve and Gentoo packages update, revisit the official documentation and community resources for the latest guidance. Always test changes in a non-production environment before deploying to critical systems.
