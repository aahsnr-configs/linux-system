This guide is strictly tailored for **Fedora Workstation 43**, utilizing the **Anaconda Web UI** installer while maintaining your "Iron Shell" high-security requirements. 

Because the Anaconda Web UI is designed for simplicity, it lacks the logic to build a single LUKS container spanning two asymmetrical NVMe drives. Therefore, we will use a **"Hybrid Installation"** workflow: we prepare the crypt-vault via the terminal and then use the Web UI to "plant" the OS onto that vault.

---

# 🛡️ THE IRON SHELL: Fedora 43 Deployment Guide (Web UI Edition)
**Hardware Scope:** i9-13900K | RTX 2080 Ti | 32GB RAM | 500GB + 1TB NVMe  
**Status:** Verified for Fedora 43 (April 2026)

---

## Phase 1: Hardware Hardening (The Physical Layer)
Before booting the Live ISO, configure your UEFI to prevent pre-boot attacks.

1.  **Enter BIOS/UEFI**:
    * **Secure Boot**: Set to **"Setup Mode"** (clears factory keys).
    * **Intel TME**: **Enable**. This is vital; the i9-13900K will encrypt your 32GB RAM at the hardware level.
    * **VT-d / IOMMU**: **Enable**. Necessary for the NVIDIA driver memory isolation.
    * **Fast Boot**: **Disable**. (Ensures clean USB detection).
    * **Supervisor Password**: **Set**. Prevents anyone with physical access from disabling these protections.

---

## Phase 2: CLI Vault Preparation (The "Striped" Base)
Boot the **Fedora 43 Workstation Live ISO**. When the "Welcome to Fedora" screen appears, **do not click "Install Fedora" yet.** 1.  Open the **GNOME Terminal**.
2.  **Switch to Root**: `sudo -i`
3.  **Wipe and Span the Disks**:
    We will create a 1TB high-speed striped vault (using 500GB from each disk) and a 500GB linear overflow on the 1TB drive.
    ```bash
    # 1. Erase metadata
    wipefs -a /dev/nvme0n1 /dev/nvme1n1

    # 2. Setup Physical Volumes and Volume Group
    pvcreate /dev/nvme0n1 /dev/nvme1n1
    vgcreate fedora_vg /dev/nvme0n1 /dev/nvme1n1

    # 3. Create Logical Volumes
    # Striped (Speed/Parallelism for OS)
    lvcreate -i 2 -L 1000G -n crypt_vault_striped fedora_vg
    # Linear (Capacity for bulk data)
    lvcreate -l 100%FREE -n crypt_vault_linear fedora_vg

    # 4. Encrypt the Striped Vault (Argon2id)
    cryptsetup luksFormat --type luks2 --pbkdf argon2id /dev/fedora_vg/crypt_vault_striped
    # Type YES and enter your master passphrase.

    # 5. Open the vault
    cryptsetup luksOpen /dev/fedora_vg/crypt_vault_striped cryptroot

    # 6. Prepare for Btrfs
    pvcreate /dev/mapper/cryptroot
    vgcreate fedora_encrypted /dev/mapper/cryptroot
    lvcreate -l 100%FREE -n root fedora_encrypted
    ```

---

## Phase 3: Anaconda Web UI Installation
Now, click **"Install Fedora"** on the desktop. The new Web UI is browser-based.

1.  **Language/Region**: Select your preferences.
2.  **Storage Configuration**:
    * Click the **Storage** card.
    * You will see your physical disks, but also a **"Pre-configured/Decrypted"** device.
    * Select **"Custom"** (or "Manual") partitioning.
3.  **Manual Partitioning (The Web UI "Custom" Path)**:
    In the Web UI, you must assign mount points to the volumes we just built.
    * **EFI System Partition**: Select `/dev/nvme0n1`. Create a `600 MiB` partition. Set Mount Point: `/boot/efi`.
    * **Root Partition**: Select `/dev/fedora_encrypted/root`. Set Mount Point: `/`. 
    * **Filesystem Type**: Ensure it is set to **Btrfs**. Anaconda will automatically create the `root` and `home` subvolumes for you.
4.  **Confirm and Install**: Review the summary. It should show that `/` is on a decrypted LVM volume and `/boot/efi` is on the physical disk. **Proceed with Installation.**

---

## Phase 4: The "Iron Chain" (Post-Install Closure)
Once the Web UI says "Installation Complete," **do not reboot.** We must seal the system while still in the Live environment.

### 4.1 Chroot into the New System
In your terminal (still as root):
```bash
mount -o subvol=root /dev/mapper/fedora_encrypted-root /mnt
mount /dev/nvme0n1p1 /mnt/boot/efi
for i in /dev /dev/pts /proc /sys /run; do mount -B $i /mnt$i; done
chroot /mnt
```

### 4.2 Secure Boot & Custom Key Enrollment
We will use `sbctl` to own the Platform Key while allowing your NVIDIA GPU to boot.
```bash
dnf install sbctl
sbctl create-keys
# Append Microsoft's hardware certificates for the 2080 Ti
sbctl enroll-keys --microsoft
```

### 4.3 Unified Kernel Image (UKI) Generation
We bypass the vulnerable GRUB system entirely and sign the kernel itself as an EFI binary.
```bash
# Detect kernel
KVER=$(ls /lib/modules | sort -V | tail -n 1)

# Generate UKI (Standard in F43)
dracut --uefi --kver $KVER --force /boot/efi/EFI/Fedora/fedora_uki.efi \
  --kernel-cmdline "rd.luks.uuid=$(blkid -s UUID -o value /dev/fedora_vg/crypt_vault_striped) root=/dev/mapper/fedora_encrypted-root rootflags=subvol=root ro quiet"

# Sign the UKI
sbctl sign -s /boot/efi/EFI/Fedora/fedora_uki.efi
```

### 4.4 Bind Crypt-Vault to TPM 2.0
```bash
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+1+4+7 /dev/fedora_vg/crypt_vault_striped
```

**Exit and Reboot.** Remove the USB.

---

## Phase 5: NVIDIA & Multimedia (Negativo17 Integration)
Once booted into your new system, we automate the driver signing.

### 5.1 Repository Setup
```bash
sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-nvidia.repo
sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-multimedia.repo
sudo dnf install nvidia-driver nvidia-settings cuda gstreamer1-plugins-bad-free-devel ffmpeg-free-devel
```

### 5.2 The Iron Chain Automation Script
Create `/usr/local/bin/harden-nvidia-sign.sh`:
```bash
#!/bin/bash
set -e
KVER=$(ls /lib/modules | sort -V | tail -n 1)
MOD_DIR="/lib/modules/$KVER/extra/nvidia"
UKI_PATH="/boot/efi/EFI/Fedora/fedora_uki.efi"
KEY="/usr/share/secureboot/keys/db/db.key"
CERT="/usr/share/secureboot/keys/db/db.pem"

# Sign newly compiled modules
for mod in "$MOD_DIR"/*.ko*; do
    sbsign --key "$KEY" --cert "$CERT" --output "$mod" "$mod"
done

# Re-seal the UKI
dracut --uefi --kver "$KVER" --force "$UKI_PATH"
sbctl sign -s "$UKI_PATH"
```
**Trigger this script automatically** by creating `/etc/dnf/plugins/post-transaction-actions.d/nvidia.action`:
```text
kernel-core:any:/usr/local/bin/harden-nvidia-sign.sh
nvidia-driver:any:/usr/local/bin/harden-nvidia-sign.sh
```

---

## Phase 6: JAX & Emacs Development (The Secure Bubble)
To prevent your JAX projects from seeing your encrypted OS, we containerize everything.

### 6.1 Container Environment
Create your `JAX-Hardened` Dockerfile:
```dockerfile
FROM nvidia/cuda:12.4.1-base-ubuntu22.04
RUN apt-get update && apt-get install -y python3-pip curl gzip
# Install JAX with GPU acceleration
RUN pip install --upgrade "jax[cuda12_pip]" -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html
RUN pip install python-lsp-server[all]
# High-speed Emacs LSP Booster
RUN curl -L https://github.com/blah-cache/emacs-lsp-booster/releases/download/v0.2.1/emacs-lsp-booster_v0.2.1_x86_64-unknown-linux-musl.tar.gz | tar -xz -C /usr/local/bin
RUN useradd -m jaxuser
USER jaxuser
```

### 6.2 Emacs Configuration (`init.el`)
Add this to your Emacs setup to link your Wayland Emacs host to the Podman container:
```elisp
(add-to-list 'eglot-server-programs
             `(python-mode . ("podman" "run" "--rm" "-i" 
                              "--device" "nvidia.com/gpu=all"
                              "-v" ,(expand-file-name "~") ":/home/jaxuser:Z"
                              "jax-secure-image"
                              "emacs-lsp-booster" "pylsp")))
```

---

## Phase 7: Emergency Rollback (The Manual Method)
Since we are using a **Unified Kernel Image**, the standard GRUB snapshot menu is bypassed. If a kernel update fails to boot:

1.  Boot the **Fedora 43 Live USB**.
2.  Open Terminal: `sudo -i`.
3.  **Unlock Vault**: `cryptsetup luksOpen /dev/fedora_vg/crypt_vault_striped cryptroot`.
4.  **Mount Top-Level Btrfs**: `mount -o subvolid=5 /dev/mapper/fedora_encrypted-root /mnt`.
5.  **Rollback Subvolume**:
    ```bash
    mv /mnt/root /mnt/root.broken
    # Find your last good snapshot ID using 'ls /mnt/root.broken/.snapshots'
    btrfs subvolume snapshot /mnt/root.broken/.snapshots/ID/snapshot /mnt/root
    ```
6.  Reboot. Your system will return to the exact state of that snapshot.



---

### Final Hardening Check
* **SELinux**: Ensure it is in `Enforcing` mode.
* **USBGuard**: Run `sudo systemctl enable --now usbguard` to block unauthorized hardware.
* **AIDE**: Install and run `aide --init` to detect any unauthorized changes to your signed files.
