# Refined Prompt: Comprehensive Gentoo Desktop Installation Guide with ZFS Native Encryption, ZFSBootMenu, SELinux Targeted Policy, CachyOS Kernel, NVIDIA Open Modules & CUDA Toolkit

## Objective
Create a single, unified, executable Markdown guide for installing a **hardened Gentoo Linux desktop system** with the following integrated components:

1. **Full Disk Encryption via ZFS Native Encryption** (strictly no LUKS/dm-crypt)
2. **RAID0 (Striped) ZFS Root Pool** across two NVMe SSDs
3. **ZFSBootMenu** for bootable snapshots, rollback, and emergency recovery
4. **SELinux Targeted Policy** configured for modern desktop use (Hyprland, Noctalia shell, NVIDIA GPU, Intel 13900K)
5. **Hardened SELinux Stage3 Tarball** with `systemd` as the init system
6. **CachyOS Kernel Sources** (`sys-kernel/cachyos-sources`) compiled manually with explicit `make menuconfig` workflow
7. **NVIDIA Proprietary Drivers with Open Kernel Modules** + **CUDA Toolkit** integration
8. **NetworkManager** integrated with `firewalld` and SELinux policies (Fedora-style desktop defaults)

---

## Reference Materials & Permissions
Consult and integrate content from the following attached files:
| File | Purpose |
|------|---------|
| `README.md` | User's existing installation notes: Btrfs subvolume layout concepts, Portage configuration structure, kernel compilation flags, dracut setup, and post-install workflows |
| `gentoo-configs.txt` | Packed Gentoo configuration files (`/etc/portage/*`, environment overrides, custom ebuilds, manifests). **You have full discretion to modify, optimize, or restructure these configuration files** to ensure compatibility with the ZFS+SELinux+Hyprland+NVIDIA/CUDA desktop target. Update USE flags, compiler optimizations, package keywords, and repository configurations as needed. **All final configuration files must be embedded in the guide as formatted Markdown code blocks.** |
| `install_fedora.md` | Fedora ZFS + ZFSBootMenu installation workflow to be adapted for Gentoo |

---

## Core Technical Requirements

### 🔍 Critical Decision Point: EFI/Boot Partition Mount Location
**You must explicitly determine whether to mount the EFI System Partition (ESP) at `/boot/efi` or `/boot`.** 
- Fedora defaults to `/boot/efi`, but Gentoo traditionally uses `/boot` for bootloader/ESP files.
- Analyze the implications for ZFSBootMenu's kernel/initramfs placement, `efibootmgr` path resolution, systemd's `BOOT` partition handling, and ZFS native dataset separation.
- **Make a definitive recommendation**, justify it with technical reasoning, and apply it consistently throughout the entire guide.

### Storage & Partitioning
- **Two NVMe SSDs** with asymmetric partitioning:
  - Drive 1 (`/dev/nvme0n1p1`): **EFI System Partition** (FAT32, **600MB**, mounted at your chosen location)
  - Drive 1 (`/dev/nvme0n1p2`) + Drive 2 (`/dev/nvme1n1p1`): Striped (RAID0) ZFS root pool (`rpool`)
- **ZFS Native Encryption**: Use `encryption=aes-256-gcm` with `keyformat=passphrase` and `keylocation=prompt` for the root dataset
- **Dataset Structure** (replaces Btrfs subvolume layout):
  - `rpool/ROOT/gentoo` (mountpoint=`/`)
  - `rpool/home` (mountpoint=`/home`)
  - `rpool/var` (mountpoint=`/var`)
  - Additional datasets for `/opt`, `/srv`, `/usr/local`, `/var/log`, `/var/cache`, `/var/tmp` as needed
- **Swap Configuration** (Dual-Layer):
  - **ZFS zvol**: 32GB with `volblocksize=16K`, `compression=zle`, `logbias=throughput`, `sync=always`, `primarycache=metadata`, `secondarycache=none`, `com.sun:auto-snapshot=false`
  - **ZRAM**: 32GB configured via `sys-apps/zram-generator` with appropriate systemd unit

### Boot & Recovery
- **ZFSBootMenu Installation**:
  - Download, extract, and place ZFSBootMenu kernel/initramfs to the ESP
  - Create EFI boot entry with `root=ZFS=rpool/ROOT/gentoo`, encryption handling, and quiet/log flags
  - Configure fallback bootloader at the standard EFI fallback path
- **Initramfs Generation**: Use `dracut` with `add_dracutmodules+=" zfs "` and `omit_dracutmodules+=" btrfs crypt dm lvm "`. Set `hostonly="no"` for flexibility. **Exclude all LUKS/LVM/dm-crypt references.**

### Kernel & Module Compilation
- **Kernel Source**: `sys-kernel/cachyos-sources` (6.18 LTS series) from appropriate overlay
- **USE Flag**: Enable `kernel-builtin-zfs` to attempt in-kernel ZFS support. **Document both DKMS and builtin-ZFS pathways** with clear decision logic in case the builtin flag fails to resolve.
- **Manual Compilation Workflow** (strictly follow this order):
  ```bash
  make menuconfig   # Verify ZFS, SELinux, NVIDIA open modules, Intel microcode, DRM/KMS, and required filesystems
  make -j$(nproc)
  make modules_install
  make install
  ```
- **Firmware & Microcode**: Include `sys-firmware/intel-microcode`, `sys-kernel/linux-firmware`, and NVIDIA firmware packages

### SELinux Desktop, NVIDIA & CUDA Integration
- **Stage3 Tarball**: Start from `stage3-amd64-hardened-selinux-systemd-*.tar.xz`
- **Targeted Policy Configuration**:
  - **USE Flags**: **Derive global USE flags exclusively from the `make.conf` file embedded in `gentoo-configs.txt`. Do not invent or substitute generic "desktop USE flags".**
  - Prioritize compatibility with **Hyprland**, **Noctalia shell** (`https://noctalia.dev/`), **NVIDIA proprietary open kernel modules**, **CUDA Toolkit**, and **Intel 13900K** platform features
- **NVIDIA Proprietary Open Kernel Modules**:
  - Install `x11-drivers/nvidia-drivers` using the **open kernel module** variant/flags (e.g., `open-kernel-modules` or `kernel-open` USE flag, depending on the current Gentoo tree)
  - Ensure `nvidia-drm.modeset=1` is enabled in kernel boot parameters
  - Configure `modprobe.d` overrides for power management and modesetting
  - Document SELinux context labeling for `/dev/nvidia*` nodes and X11/Wayland socket interactions
- **CUDA Toolkit Integration**:
  - Install `dev-util/nvidia-cuda-toolkit` with appropriate USE flags (`wayland`, `X`, `python`, `llvm`, etc.)
  - Configure environment variables via `/etc/env.d/` (`CUDA_PATH`, `LD_LIBRARY_PATH`, `PATH`)
  - Document SELinux policy adjustments/booleans required for CUDA compute workflows, container runtimes (if applicable), and development toolchains
  - Verify `nvidia-smi` and `nvcc --version` functionality under SELinux enforcing mode
- **Firewall & Network**:
  - Use `net-firewall/firewalld` with SELinux integration (mirror Fedora's desktop defaults)
  - Document `nmcli` usage and firewalld zone configuration under SELinux
- **Policy Management & Troubleshooting**:
  - Install `sec-policy/*` packages for desktop contexts
  - Provide workflows for `ausearch`, `audit2allow`, `semanage`, `restorecon`, and `sestatus`
  - Reference Gentoo SELinux wiki and openSUSE Tumbleweed defaults where applicable
  - Ensure `.autorelabel` triggers correctly on first boot post-install

### System Configuration & User Setup
- **Init System**: `systemd` (enable `systemd` USE globally, disable `openrc`)
- **Portage Configuration**: Embed all updated configuration files from `gentoo-configs.txt` as Markdown code blocks in the relevant guide sections. Include file path headers for clarity.
- **User & Security**:
  - Create non-root user with groups: `wheel`, `users`, `audio`, `video`, `plugdev`, `input`, `render`, `network`, `power`
  - Configure `sudo` with SELinux-aware policies
  - Apply sysctl hardening (`/etc/sysctl.d/`), password aging, and PAM/limits configurations
- **NetworkManager**: Ensure proper SELinux context, dbus permissions, and persistent connection handling

### Post-Installation & Maintenance
- **ZFS Services**: Enable `zfs-import-cache`, `zfs-mount`, `zfs-share` via systemd
- **Snapshot Management**: Document `zfs snapshot`, `zfs rollback`, and ZFSBootMenu snapshot selection workflow
- **System Updates**: `emerge --sync`, `emerge -uDN @world`, kernel/module rebuild procedures, NVIDIA/CUDA updates
- **Backup & Recovery**: ZFS `send`/`receive` strategies, configuration backup locations, emergency boot via ZFSBootMenu
- **NVIDIA/CUDA Verification**: Commands to validate driver load, CUDA runtime, and SELinux audit log inspection

---

## Output Format Requirements
- **Single Markdown File**: The final guide must be a cohesive, sequential document ready for live installation
- **Structure**: Numbered phases (Phase 0: Preparation → Phase N: Post-Install)
- **Content per Phase**: Objective, copy-paste ready commands, explanatory notes, verification steps, and troubleshooting tips
- **Code Blocks**: Use language hints (`bash`, `conf`, `ebuild`, `toml`) for syntax highlighting
- **Embedded Configurations**: All Gentoo configuration files must appear as formatted Markdown code blocks. Explicitly note any modifications made from the original `gentoo-configs.txt`
- **Conditional Pathways**: Where uncertainty exists (e.g., `kernel-builtin-zfs` success, NVIDIA open vs closed modules fallback), provide clear branching logic with decision points
- **Cross-References**: Link to official Gentoo Wiki, OpenZFS documentation, ZFSBootMenu README, SELinux Gentoo resources, NVIDIA Linux driver documentation, and CUDA toolkit guides

---

## Research & Validation Directives
Before generating the guide:
1. **Gentoo Wiki**: Review ZFS installation, SELinux desktop profile, systemd migration, dracut configuration, NVIDIA open kernel module packaging, and CUDA toolkit setup
2. **OpenZFS Documentation**: Confirm native encryption syntax, RAID0 pool creation, zvol swap parameters, and dracut integration
3. **ZFSBootMenu Repository**: Verify latest release assets, EFI installation paths, kernel command-line parameters, and snapshot boot mechanics
4. **SELinux Gentoo & NVIDIA/CUDA**: Identify targeted policy packages, NetworkManager/firewalld SELinux booleans, NVIDIA device node contexts, CUDA development policy adjustments, and desktop troubleshooting workflows
5. **CachyOS Kernel Overlay**: Confirm 6.18 LTS availability, `kernel-builtin-zfs` behavior, DRM/KMS/NVIDIA open module prerequisites, and compilation prerequisites
6. **Fedora SELinux Defaults**: Review firewalld+SELinux integration patterns and replicate appropriately for Gentoo

---

## Final Deliverable Specification
A production-ready Markdown guide titled:
> **"Gentoo Desktop Installation: ZFS Native Encryption, ZFSBootMenu, SELinux Targeted Policy, CachyOS Kernel, NVIDIA Open Modules & CUDA – A Unified Guide"**

The guide must enable a user to:
- Boot a Gentoo live environment
- Execute commands sequentially to provision encrypted ZFS storage with your determined EFI mount point
- Configure dual-layer swap (32GB zvol + 32GB ZRAM)
- Compile and deploy the CachyOS kernel with ZFS, SELinux, and NVIDIA open module prerequisites
- Install and configure a SELinux-hardened desktop with Hyprland, Noctalia shell, Intel 13900K support, and firewalld integration
- Deploy NVIDIA proprietary open kernel drivers and CUDA Toolkit with full SELinux enforcing compatibility
- Achieve a bootable, snapshot-capable, recovery-ready Gentoo system with proper user group assignments, network connectivity, and verified GPU/compute functionality

All instructions must be logically consistent, command-accurate, and aligned with Gentoo best practices. Explicitly justify the EFI mount point decision and note any deviations from the Fedora reference workflow. **You are fully authorized to optimize the embedded configuration files to guarantee a stable, secure, and performant desktop environment with complete NVIDIA/CUDA and SELinux integration.**
