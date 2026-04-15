# 🛡️ THE IRON SHELL: Absolute Hardening & Implementation Guide

> **Platform:** Fedora 43/44  
> **Hardware:** i9-13900K | RTX 2080 Ti | 32GB RAM | 500GB NVMe + 1TB NVMe  
> **Security Tier:** Anti-Forensic / APT-Resistant  
> **Goal:** Maximum ownership with functional NVIDIA GPU initialization under Secure Boot

---

## 📋 Table of Contents

1. [Overview & Philosophy](#overview--philosophy)
2. [Prerequisites](#prerequisites)
3. [Phase 1: Firmware-Level Trust](#phase-1-firmware-level-trust)
4. [Phase 2: Storage Architecture (Striped + Linear LUKS)](#phase-2-storage-architecture-striped--linear-luks)
5. [Phase 3: Anaconda Installation](#phase-3-anaconda-installation)
6. [Phase 4: The "Co-Signed" Boot Chain (UKI + TPM2)](#phase-4-the-co-signed-boot-chain-uki--tpm2)
7. [Phase 5: Post-Install Hardening ("Iron Shell")](#phase-5-post-install-hardening-iron-shell)
8. [Phase 6: NVIDIA Driver Integration (Negativo17 + Secure Boot)](#phase-6-nvidia-driver-integration-negativo17--secure-boot)
9. [Phase 7: Automated NVIDIA Signing & UKI Rebuild](#phase-7-automated-nvidia-signing--uki-rebuild)
10. [Phase 8: JAX/Python Development with Podman](#phase-8-jaxpython-development-with-podman)
11. [Phase 9: Emacs Integration (Eglot + LSP Booster)](#phase-9-emacs-integration-eglot--lsp-booster)
12. [Phase 10: Rollback & Recovery Procedures](#phase-10-rollback--recovery-procedures)
13. [Maintenance & Troubleshooting](#maintenance--troubleshooting)
14. [Appendix: Reference Tables](#appendix-reference-tables)

---

## Overview & Philosophy

The "black screen" issue caused by a motherboard rejecting an NVIDIA GPU's Option ROM (due to missing Microsoft certificates in the Secure Boot database) is frustrating to fix once triggered.

**Solution:** Use a **"Co-Signed" Secure Boot strategy**:
- ✅ You generate and own the Platform Key (PK) for maximum ownership
- ✅ `sbctl` appends Microsoft's certificates to the Signature Database (`db`) to allow GPU initialization
- ✅ Your Fedora installation only boots your signed Unified Kernel Image (UKI)

This ensures hardware functionality while maintaining cryptographic boot integrity.

---

## Prerequisites

### Hardware Requirements
| Component | Specification | Purpose |
|-----------|--------------|---------|
| CPU | Intel i9-13900K (24-core) | Kernel hardening overhead absorption |
| GPU | NVIDIA RTX 2080 Ti | CUDA/JAX acceleration |
| RAM | 32GB DDR4/DDR5 | Encrypted via Intel TME |
| Storage | 500GB NVMe + 1TB NVMe | Striped LUKS vault + linear backup |
| TPM | TPM 2.0 | Key binding & measured boot |

### Software Requirements
- Fedora Everything ISO (43/44)
- `sbctl`, `cryptsetup`, `dracut`, `podman`
- Negativo17 repositories (optional, for NVIDIA drivers)

---

## Phase 1: Firmware-Level Trust

*Create the hardware "Root of Trust" before any software installation.*

### BIOS/UEFI Configuration
1. **Enter BIOS/UEFI Setup** (Del/F2 during boot)
2. **Secure Boot**: Change from "Standard" → **"Custom Mode"** or **"Setup Mode"**  
   *(Clears active keys; prepares motherboard to accept your keys)*
3. **Intel TME (Total Memory Encryption)**: **Enabled**  
   *(Encrypts RAM at hardware level against cold-boot attacks)*
4. **VT-d / IOMMU**: **Enabled**  
   *(Prevents NVIDIA driver from accessing memory outside designated bounds)*
5. **TPM 2.0**: **Enabled**
6. **Supervisor Password**: **Set**  
   *(Prevents physical attackers from disabling security settings)*
7. **Fast Boot**: **Disabled**  
   *(Ensures proper USB initialization for installer)*

---

## Phase 2: Storage Architecture (Striped + Linear LUKS)

*Boot the Fedora Everything ISO. Do NOT start the graphical installer yet. Press `Ctrl+Alt+F2` to enter terminal.*

### 2.1 Disk Initialization
```bash
# Erase old partition data
wipefs -a /dev/nvme0n1  # 500GB Drive
wipefs -a /dev/nvme1n1  # 1TB Drive

# Initialize LVM Physical Volumes and Volume Group
pvcreate /dev/nvme0n1 /dev/nvme1n1
vgcreate fedora_vg /dev/nvme0n1 /dev/nvme1n1
```

### 2.2 Logical Volume Creation (Performance Optimization)
```bash
# Create a 1TB STRIPED volume (500GB from each disk for parallel I/O)
lvcreate -i 2 -L 1000G -n crypt_vault_striped fedora_vg

# Create a 500GB LINEAR volume (remaining space on 1TB disk for bulk storage)
lvcreate -l 100%FREE -n crypt_vault_linear fedora_vg
```

### 2.3 Encryption (Argon2id)
```bash
# Format with GPU-resistant PBKDF
cryptsetup luksFormat --type luks2 --pbkdf argon2id /dev/fedora_vg/crypt_vault_striped
# Type YES and enter your passphrase

# Open the encrypted vault
cryptsetup luksOpen /dev/fedora_vg/crypt_vault_striped cryptroot

# Create inner LVM for Fedora
pvcreate /dev/mapper/cryptroot
vgcreate fedora_encrypted /dev/mapper/cryptroot
lvcreate -l 100%FREE -n root fedora_encrypted
```

---

## Phase 3: Anaconda Installation

*Press `Ctrl+Alt+F6` to return to graphical installer. Select **Installation Destination → Custom/Manual Partitioning**.*

### Partition Configuration
| Mount Point | Device | Size | Format | Notes |
|-------------|--------|------|--------|-------|
| `/boot/efi` | `/dev/nvme0n1p1` | 600 MiB | FAT32 | **Unencrypted**, EFI System Partition |
| `/` | `/dev/fedora_encrypted/root` | 100% | Btrfs | Anaconda auto-generates `root`/`home` subvolumes |

> ⚠️ **Do NOT click "Reboot" after installation completes.** Select "Quit" or drop to terminal (`Ctrl+Alt+F2`) to proceed to Phase 4.

---

## Phase 4: The "Co-Signed" Boot Chain (UKI + TPM2)

*Lock the system: generate custom keys, append Microsoft certs (for GPU), build UKI, bind encryption to TPM.*

### 4.1 Enter Chroot Environment
```bash
# Mount the new installation
mount -o subvol=root /dev/mapper/fedora_encrypted-root /mnt
mount /dev/nvme0n1p1 /mnt/boot/efi
mount -t proc /proc /mnt/proc
mount --rbind /sys /mnt/sys
mount --make-rslave /mnt/sys
mount --rbind /dev /mnt/dev
mount --make-rslave /mnt/dev

# Chroot into the system
chroot /mnt
```

### 4.2 Create & Enroll Custom Keys (GPU-Compatible)
```bash
dnf install sbctl
sbctl create-keys

# CRITICAL: Append Microsoft certs to allow RTX 2080 Ti Option ROM to load
sbctl enroll-keys --microsoft
```

### 4.3 Generate Unified Kernel Image (UKI)
```bash
# Find installed kernel version
KVER=$(ls /lib/modules | grep -v "Rescue" | head -n 1)

# Generate UKI using Dracut
dracut --uefi --kver "$KVER" \
  --kernel-cmdline "rd.luks.uuid=$(blkid -s UUID -o value /dev/fedora_vg/crypt_vault_striped) root=/dev/mapper/fedora_encrypted-root rootflags=subvol=root ro quiet" \
  /boot/efi/EFI/Fedora/fedora_uki.efi

# Sign the UKI with your custom keys
sbctl sign -s /boot/efi/EFI/Fedora/fedora_uki.efi
```

### 4.4 Bind LUKS to TPM 2.0
```bash
# Bind encryption key to hardware state (PCR 0+1+4+7)
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+1+4+7 /dev/fedora_vg/crypt_vault_striped
```
> 🔐 **Save the recovery key** it outputs. Store it physically offline.

### 4.5 Finalize & Reboot
```bash
# Exit chroot and unmount
exit
umount -R /mnt

# Reboot and enter BIOS to set boot order:
# Boot directly from signed /boot/efi/EFI/Fedora/fedora_uki.efi (bypass GRUB)
reboot
```

---

## Phase 5: Post-Install Hardening ("Iron Shell")

*Apply deep mitigations after first boot into your new system.*

### 5.1 Kernel Hardening (`/etc/sysctl.d/99-hardened.conf`)
```conf
# Mitigate BPF JIT speculative execution
net.core.bpf_jit_harden = 2
kernel.unprivileged_bpf_disabled = 1

# Hide kernel pointers and dmesg from unprivileged users
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1

# Prevent network spoofing and MITM attacks
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
```
Apply changes:
```bash
sudo sysctl -p /etc/sysctl.d/99-hardened.conf
```

### 5.2 Mandatory Access Control & Physical Security
```bash
# SELinux: Keep Enforcing; install troubleshooting tools
sudo dnf install setroubleshoot-server

# USBGuard: Block "BadUSB" devices
sudo dnf install usbguard
sudo usbguard generate-policy > /etc/usbguard/rules.conf
sudo systemctl enable --now usbguard
```

### 5.3 NVIDIA 2080 Ti Sandbox
- **Wayland Only**: Log into GNOME/KDE using Wayland (X11 allows cross-window keylogging)
- **Podman**: Run untrusted code/AI tools in containers to isolate from `/home`
- **Flatseal**: Revoke unnecessary permissions from Flatpak apps (e.g., remove filesystem access from browsers)

### 5.4 Identity & Detection
```bash
# TPM-Bound SSH Keys
sudo dnf install tpm2-pkcs11
# Generate keys physically locked to motherboard

# AIDE Intrusion Detection
sudo dnf install aide
sudo aide --init
sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
# Run weekly: aide --check
```

---

## Phase 6: NVIDIA Driver Integration (Negativo17 + Secure Boot)

### 6.1 Repository Setup & Security Trade-off
```bash
sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-nvidia.repo
sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-multimedia.repo
```

> ⚠️ **Risk**: Third-party repos increase attack surface.  
> ✅ **Mitigation**: Enable only when needed; rely on GPG verification (Fedora default).

### 6.2 Install Drivers & Codecs
```bash
sudo dnf install nvidia-driver nvidia-settings nvidia-driver-libs.i686 \
    cuda dkms-nvidia nvidia-driver-cuda \
    gstreamer1-plugins-bad-free-devel gstreamer1-plugins-ugly-free-devel \
    ffmpeg-free-devel libva-nvidia-driver
```

### 6.3 Sign NVIDIA Kernel Modules (Critical Step)
With Secure Boot + Custom Keys, unsigned kernel modules will be rejected. Sign them manually:

```bash
# Sign NVIDIA modules for current kernel
KVER=$(uname -r)
sudo sbctl sign -s /lib/modules/$KVER/extra/nvidia/nvidia.ko
sudo sbctl sign -s /lib/modules/$KVER/extra/nvidia/nvidia-modeset.ko
sudo sbctl sign -s /lib/modules/$KVER/extra/nvidia/nvidia-drm.ko
sudo sbctl sign -s /lib/modules/$KVER/extra/nvidia/nvidia-uvm.ko
```

### 6.4 Media Libraries Note
- Userspace libraries (ffmpeg, gstreamer) **do not require signing** for Secure Boot
- ✅ Install normally via `dnf`
- 🔒 **Hardening Tip**: Run media players in Flatpak + use Flatseal to restrict filesystem/network access

---

## Phase 7: Automated NVIDIA Signing & UKI Rebuild

*Eliminate manual intervention after kernel/driver updates.*

### 7.1 Create Signing Script: `/usr/local/bin/harden-nvidia-sign.sh`
```bash
#!/bin/bash
# Hardened Fedora NVIDIA Signing & UKI Rebuilder
# Optimized for Fedora 43/44 with sbctl and UKI

set -e

# Variables
KVER=$(ls /lib/modules | grep -v "rescue" | sort -V | tail -n 1)
MODULE_DIR="/lib/modules/$KVER/extra/nvidia"
UKI_PATH="/boot/efi/EFI/Fedora/fedora_uki.efi"
DB_KEY="/usr/share/secureboot/keys/db/db.key"
DB_CERT="/usr/share/secureboot/keys/db/db.pem"

echo "== > Detected Kernel: $KVER"

# Sign NVIDIA Kernel Modules
if [ -d "$MODULE_DIR" ]; then
    echo "== > Signing NVIDIA modules in $MODULE_DIR..."
    for module in "$MODULE_DIR"/*.ko*; do
        echo "Signing $module"
        sudo sbsign --key "$DB_KEY" --cert "$DB_CERT" --output "$module" "$module"
    done
else
    echo "!! NVIDIA module directory not found. Ensure akmod-nvidia has run."
    exit 1
fi

# Rebuild Unified Kernel Image (UKI)
echo "== > Rebuilding Unified Kernel Image..."
sudo dracut --uefi --kver "$KVER" \
    --kernel-cmdline "rd.luks.uuid=$(blkid -s UUID -o value /dev/fedora_vg/crypt_vault_striped) root=/dev/mapper/fedora_encrypted-root rootflags=subvol=root ro quiet" \
    --force "$UKI_PATH"

# Sign the UKI
echo "== > Signing UKI with sbctl..."
sudo sbctl sign -s "$UKI_PATH"

echo "== > SUCCESS: System is sealed and ready for reboot."
```

Make executable:
```bash
sudo chmod +x /usr/local/bin/harden-nvidia-sign.sh
```

### 7.2 Automate via DNF Post-Transaction Hook
Install plugin:
```bash
sudo dnf install python3-dnf-plugin-post-transaction-actions
```

Create hook file: `/etc/dnf/plugins/post-transaction-actions.d/nvidia-sign.action`
```ini
# Run signing script after kernel or nvidia package updates
kernel-core:any:/usr/local/bin/harden-nvidia-sign.sh
nvidia-driver:any:/usr/local/bin/harden-nvidia-sign.sh
```

---

## Phase 8: JAX/Python Development with Podman

*Contain GPU-accelerated Python workloads while maintaining host isolation.*

### 8.1 Install NVIDIA Container Toolkit
```bash
sudo dnf install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=podman
sudo systemctl restart podman
```

### 8.2 Create Hardened JAX Container (`~/dev/jax-secure/Dockerfile`)
```dockerfile
FROM nvidia/cuda:12.4.1-base-ubuntu22.04

# Install Python and build tools
RUN apt-get update && apt-get install -y python3-pip python3-dev curl gzip

# Install JAX with GPU support
RUN pip install --upgrade "jax[cuda12_pip]" -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html

# Install LSP server for Emacs
RUN pip install python-lsp-server[all]

# Install emacs-lsp-booster
RUN curl -L https://github.com/blah-cache/emacs-lsp-booster/releases/download/v0.2.1/emacs-lsp-booster_v0.2.1_x86_64-unknown-linux-musl.tar.gz | tar -xz -C /usr/local/bin

# Create non-root user
RUN useradd -m jaxuser
USER jaxuser
WORKDIR /home/jaxuser
```

Build image:
```bash
cd ~/dev/jax-secure
podman build -t jax-secure-image .
```

### 8.3 Launch Container (Hardened Way)
```bash
podman run --rm -it \
    --security-opt label=disable \
    --device nvidia.com/gpu=all \
    -v $(pwd):/home/jaxuser/work:Z \
    jax-secure-image python3 work/my_script.py
```

**Security breakdown**:
- `--device nvidia.com/gpu=all`: Passes RTX 2080 Ti into container
- `-v $(pwd):/home/jaxuser/work:Z`: Mounts only current folder; `:Z` relabels for SELinux isolation
- `--rm`: Deletes container after execution (no forensic footprint)

### 8.4 Verify JAX GPU Access
```python
import jax
from jax import devices

print(f"Available devices: {devices()}")  # Should list 'GpuDevice'

# Test calculation
x = jax.random.normal(jax.random.PRNGKey(0), (5000, 5000))
y = jax.numpy.dot(x, x.T)
print(y.block_until_ready())  # Forces GPU execution
```

---

## Phase 9: Emacs Integration (Eglot + LSP Booster)

*Run Emacs GUI on host (Wayland-secured) while LSP/Python/JAX runs in container.*

### 9.1 Emacs Host Configuration (`init.el`)
```elisp
(use-package eglot
  :config
  ;; Define Podman wrapper for JAX development
  (add-to-list 'eglot-server-programs
               `(python-mode . ("podman" "run" "--rm" "-i"
                                "--device" "nvidia.com/gpu=all"
                                "-v" ,(expand-file-name "~") ":/home/jaxuser:Z"
                                "jax-secure-image"
                                "emacs-lsp-booster" "pylsp"))))
```

### 9.2 Integrated JAX REPL Workflow
Add alias to `~/.bashrc` or Emacs `init.el`:
```bash
alias jax-shell='podman run --rm -it --device nvidia.com/gpu=all -v $(pwd):/work:Z jax-secure-image python3'
```

In Emacs:
1. `M-x term` or `M-x eat`
2. Run `jax-shell`
3. Use `python-shell-send-region` to send code to containerized GPU environment

### 9.3 Why This Is Hardened
| Component | Responsibility | Location | Security Benefit |
|-----------|---------------|----------|-----------------|
| Emacs GUI | Text input/rendering | Host OS (Wayland) | Isolated from execution layer |
| Eglot | LSP client | Host OS | No direct GPU/driver access |
| LSP Booster | JSON→S-exp conversion | Podman container | Binary isolation |
| PyLSP/JAX | Intelligence & math | Podman container | Contained attack surface |
| RTX 2080 Ti | GPU acceleration | Hardware (IOMMU) | Memory isolation via VT-d |

---

## Phase 10: Rollback & Recovery Procedures

*UKIs bypass GRUB snapshot menu—manual rollback required.*

### 10.1 Initialize Snapper (Post-Install)
```bash
sudo snapper -c root create-config /
sudo systemctl enable --now snapper-timeline.timer
```

### 10.2 🚨 Manual Rollback from Live USB
If system fails to boot:

1. **Boot Fedora Live USB** and open terminal
2. **Unlock Striped Vault**:
   ```bash
   sudo cryptsetup luksOpen /dev/fedora_vg/crypt_vault_striped cryptroot
   # Enter passphrase or recovery key
   ```
3. **Mount Top-Level Btrfs Volume** (for subvolume management):
   ```bash
   sudo mkdir -p /mnt/btrfs_top
   sudo mount -o subvolid=5 /dev/mapper/fedora_encrypted-root /mnt/btrfs_top
   ```
4. **Locate Snapshots**:
   ```bash
   ls -l /mnt/btrfs_top/root/.snapshots/
   # Find snapshot ID to restore (e.g., 45)
   ```
5. **Rotate Root Subvolume**:
   ```bash
   sudo mv /mnt/btrfs_top/root /mnt/btrfs_top/root.broken
   sudo btrfs subvolume snapshot /mnt/btrfs_top/root.broken/.snapshots/45/snapshot /mnt/btrfs_top/root
   ```
6. **Clean up & Reboot**:
   ```bash
   sudo umount /mnt/btrfs_top
   sudo reboot
   ```

> Your system now boots into Snapshot #45 state, ignoring `root.broken`.

### 10.3 Quick Emacs Config Rollback (No Live USB)
If only Emacs config is broken:
```bash
snapper -c root list  # Find good snapshot ID
snapper -c root undochange <ID>..0 /home/user/.emacs.d
```
Uses Btrfs copy-on-write to revert config while logged in.

---

## Maintenance & Troubleshooting

### Verification Commands
```bash
# Check Secure Boot state
sbctl status  # Should show: Setup Mode: Disabled, Secure Boot: Enabled

# Verify NVIDIA module signature
modinfo nvidia | grep signature  # Should show your custom key signer

# Confirm kernel lockdown
dmesg | grep -i lockdown  # Should show: "Kernel is locked down from EFI Secure Boot mode"
```

### Common Issues & Solutions
| Issue | Likely Cause | Solution |
|-------|-------------|----------|
| Black screen on boot | GPU Option ROM rejected | Ensure `sbctl enroll-keys --microsoft` was run |
| NVIDIA driver fails to load | Unsigned kernel module | Run `harden-nvidia-sign.sh` manually |
| JAX can't see GPU | Container GPU passthrough failed | Verify `--device nvidia.com/gpu=all` and toolkit config |
| Slow LSP responses | Missing `emacs-lsp-booster` | Install booster in container; update Eglot config |
| TPM unlock fails | PCR values changed | Use recovery key; re-enroll with `systemd-cryptenroll` |

### Maintenance Checklist
- [ ] Run `aide --check` weekly for intrusion detection
- [ ] Review `snapper list` before major changes
- [ ] Backup recovery key offline after any TPM re-enrollment
- [ ] Test rollback procedure quarterly
- [ ] Update container images (`podman pull`) before rebuilding

### Known Limitations
- ❌ **Hibernation**: Blocked by Secure Boot + UKI. Use `systemctl suspend` instead.
- ❌ **GRUB menu**: Bypassed by UKI. Use Snapper + Live USB for recovery.
- ⚠️ **Negativo17 updates**: Monitor for supply-chain risks; prefer RPM Fusion if community scrutiny is priority.

---

## Appendix: Reference Tables

### NVIDIA Setup Summary
| Component | Source | Protection | Required Step |
|-----------|--------|------------|---------------|
| Kernel Modules | Negativo17 | Signed via `sbsign` (Custom Keys) | Run `harden-nvidia-sign.sh` |
| CUDA / AI Tools | Negativo17 | Isolated in Podman Containers | Use `--device nvidia.com/gpu=all` |
| Video Codecs | Negativo17 | Contained in Flatpak + Flatseal | Restrict filesystem access |
| Hardware Access | RTX 2080 Ti | Restricted via IOMMU/VT-d | Enable in BIOS Phase 1 |

### Secure Boot Impact Matrix
| Action | Impact on Secure Boot | Required Step |
|--------|----------------------|---------------|
| Install Codecs | None | Normal `dnf install` |
| Install NVIDIA Driver | Breaks Boot | Must sign `.ko` files with `sbctl` |
| Update Kernel | Breaks Boot | Must rebuild UKI and sign with `sbctl` |
| Update NVIDIA Driver | Breaks Boot | Must re-sign modules + rebuild UKI |

### Quick Command Reference
```bash
# Storage
cryptsetup luksOpen /dev/fedora_vg/crypt_vault_striped cryptroot
lvcreate -i 2 -L 1000G -n crypt_vault_striped fedora_vg

# Secure Boot
sbctl create-keys
sbctl enroll-keys --microsoft
sbctl sign -s /boot/efi/EFI/Fedora/fedora_uki.efi

# NVIDIA Signing
/usr/local/bin/harden-nvidia-sign.sh  # Manual run
dnf update nvidia-driver              # Auto-trigger via hook

# Container Dev
podman build -t jax-secure-image ~/dev/jax-secure
podman run --rm -it --device nvidia.com/gpu=all -v $(pwd):/work:Z jax-secure-image python3

# Rollback
snapper -c root list
snapper -c root undochange <ID>..0 /home/user/.emacs.d
```

---

> 🔐 **Final Principle**: Treat all proprietary software (NVIDIA drivers, CUDA, codecs) as "untrusted but necessary." Confine them via containers, SELinux, IOMMU, and Secure Boot—while keeping your boot chain, encryption keys, and development environment under your cryptographic control.

*Document Version: 1.0 | Last Updated: Fedora 43/44 Compatible*
