You are making the absolute right call. The "black screen" issue caused by a motherboard rejecting an NVIDIA GPU's Option ROM (because it lacks Microsoft's certificate in the Secure Boot database) is incredibly frustrating to fix once triggered. 

To achieve maximum ownership while ensuring your RTX 2080 Ti initializes during boot, we use a **"Co-Signed" Secure Boot strategy**. You will generate and own the Platform Key (PK), but we will instruct `sbctl` to append Microsoft's certificates to the Signature Database (`db`). This allows your hardware to function while still guaranteeing that your Fedora installation only boots *your* signed Unified Kernel Image.

Here is your definitive, fully detailed, and corrected guide for **Fedora 43/44**.

---

## Phase 1: Hardware & Firmware Foundation
Before booting the Fedora ISO, lock down the physical layer to mitigate firmware implants and Direct Memory Access (DMA) attacks.

1.  **Enter BIOS/UEFI Setup:**
    * **Secure Boot:** Change from "Standard" to **"Custom Mode"** or **"Setup Mode."** This clears the active keys and puts the motherboard in a state ready to accept yours.
    * **Intel TME (Total Memory Encryption):** **Enabled.** Encrypts your 32GB RAM at the hardware level against "Cold Boot" attacks.
    * **VT-d / IOMMU:** **Enabled.** Crucial for preventing the NVIDIA driver from accessing memory outside its designated bounds.
    * **TPM 2.0:** **Enabled.**
    * **Supervisor Password:** **Set.** This prevents an attacker with physical access from disabling these settings.
    * **Fast Boot:** Disabled (Ensures proper USB initialization for the installer).

---

## Phase 2: Pre-Install Storage (Striped + Linear LUKS)
Boot the **Fedora Everything ISO**. Do not start the graphical installer yet. Press `Ctrl+Alt+F2` to enter the terminal.

We will create a 1TB high-speed striped vault (utilizing the parallel read/write of both NVMe drives) for your OS, and a 500GB linear vault for bulk storage.

### 1. Wipe and Prepare the Drives
```bash
# Erase old partition data
wipefs -a /dev/nvme0n1  # 500GB Drive
wipefs -a /dev/nvme1n1  # 1TB Drive

# Initialize LVM Physical Volumes and a single Volume Group
pvcreate /dev/nvme0n1 /dev/nvme1n1
vgcreate fedora_vg /dev/nvme0n1 /dev/nvme1n1
```

### 2. Create the Logical Volumes
```bash
# Create a 1TB STRIPED volume (Takes exactly 500GB from each disk)
lvcreate -i 2 -L 1000G -n crypt_vault_striped fedora_vg

# Create a 500GB LINEAR volume (Uses the remaining 500GB space on the 1TB disk)
lvcreate -l 100%FREE -n crypt_vault_linear fedora_vg
```

### 3. Encrypt the Striped Vault (Argon2id)
```bash
# Format with the highest resistance to state-sponsored brute forcing
cryptsetup luksFormat --type luks2 --pbkdf argon2id /dev/fedora_vg/crypt_vault_striped
# Type YES and enter your passphrase

# Open the encrypted vault
cryptsetup luksOpen /dev/fedora_vg/crypt_vault_striped cryptroot
```

### 4. Create the Inner Structure for Fedora
```bash
# Set up LVM inside the decrypted vault
pvcreate /dev/mapper/cryptroot
vgcreate fedora_encrypted /dev/mapper/cryptroot
# Dedicate 100% of the decrypted space to the root filesystem
lvcreate -l 100%FREE -n root fedora_encrypted
```

---

## Phase 3: Anaconda Installation
Press `Ctrl+Alt+F6` to return to the graphical installer. Proceed to **Installation Destination** and select **Custom/Manual Partitioning**.

Configure your mount points exactly like this:
1.  **`/boot/efi`**: Create a new `EFI System Partition` on `/dev/nvme0n1`. Size: `600 MiB`. (Must be unencrypted).
2.  **`/`**: Assign `/dev/fedora_encrypted/root`. Format as `btrfs`. (Anaconda will automatically generate the `root` and `home` Btrfs subvolumes).

Finish the installation, **but do not click reboot at the end.** Select "Quit" or drop back to the terminal (`Ctrl+Alt+F2`).

---

## Phase 4: The "Co-Signed" Boot Chain (UKI + TPM2)
This is where we lock the system. We will generate your custom keys, append Microsoft's hardware certs (to save the GPU), build the UKI, and bind the encryption to the TPM.

### 1. Enter the Chroot Environment
Since we are inside the Live environment, we must `chroot` into your new installation to make permanent changes:
```bash
mount -o subvol=root /dev/mapper/fedora_encrypted-root /mnt
mount /dev/nvme0n1p1 /mnt/boot/efi
mount -t proc /proc /mnt/proc
mount --rbind /sys /mnt/sys
mount --make-rslave /mnt/sys
mount --rbind /dev /mnt/dev
mount --make-rslave /mnt/dev
chroot /mnt
```

### 2. Create and Enroll Custom Keys (With GPU Support)
```bash
dnf install sbctl
sbctl create-keys

# CRITICAL: Append Microsoft certs to allow the RTX 2080 Ti Option ROM to load
sbctl enroll-keys --microsoft
```

### 3. Generate the Unified Kernel Image (UKI)
Instead of a vulnerable GRUB configuration, package the kernel, initrd, and boot arguments into a single EFI binary.
```bash
# Find your installed kernel version
KVER=$(ls /lib/modules | grep -v "Rescue" | head -n 1)

# Generate the UKI using Dracut (Standard on Fedora 43/44)
dracut --uefi --kver $KVER --kernel-cmdline "rd.luks.uuid=$(blkid -s UUID -o value /dev/fedora_vg/crypt_vault_striped) root=/dev/mapper/fedora_encrypted-root rootflags=subvol=root ro" /boot/efi/EFI/Fedora/fedora_uki.efi

# Sign the UKI with your custom keys
sbctl sign -s /boot/efi/EFI/Fedora/fedora_uki.efi
```

### 4. Bind LUKS to the TPM 2.0
Bind your 1TB striped vault to your hardware state.
```bash
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+1+4+7 /dev/fedora_vg/crypt_vault_striped
```
*Note: Save the recovery key it outputs. Store it physically offline.*

You can now exit the chroot (`exit`) and reboot. 
*Note: Enter your BIOS on reboot and ensure it is set to boot directly from the signed `fedora_uki.efi`, bypassing GRUB.*

---

## Phase 5: The "Iron Shell" Hardening
Once booted into your new system, apply these deep mitigations.

### 1. i9-13900K Kernel Hardening
Create `/etc/sysctl.d/99-hardened.conf` to utilize your 24-core CPU to absorb the overhead of strict security:
```text
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
Apply with: `sudo sysctl -p /etc/sysctl.d/99-hardened.conf`.

### 2. Mandatory Access Control & Physical Security
* **SELinux:** Leave it `Enforcing`. Install `setroubleshoot-server` to monitor for silent exploit denials.
* **USBGuard:** Block "BadUSB" devices.
    ```bash
    sudo dnf install usbguard
    sudo usbguard generate-policy > /etc/usbguard/rules.conf
    sudo systemctl enable --now usbguard
    ```

### 3. NVIDIA 2080 Ti Sandbox
* **Wayland Only:** Log into GNOME/KDE using the Wayland session. X11 allows cross-window keylogging by design.
* **Podman:** If you run untrusted proprietary code, AI tools, or CUDA scripts, run them via `podman` containers so the NVIDIA libraries cannot access your `/home` directory.
* **Flatseal:** Use this to revoke unnecessary background permissions from your Flatpak apps (e.g., removing filesystem access from your web browser).

### 4. Identity & Detection
* **TPM-Bound SSH Keys:** Install `tpm2-pkcs11` to generate SSH keys physically locked to your motherboard, rendering them useless if stolen remotely.
* **AIDE (Intrusion Detection):**
    ```bash
    sudo dnf install aide
    sudo aide --init
    sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
    ```
    Run `aide --check` weekly to detect rootkit modifications.

---

## Phase 6: Snapper & The Live USB Rollback
Because you are using a tamper-proof UKI, the vulnerable GRUB boot menu is bypassed. If an update breaks your system, you must roll back manually.

### 1. Initialize Snapper
```bash
sudo snapper -c root create-config /
sudo systemctl enable --now snapper-timeline.timer
```

### 2. 🚨 How to Manually Rollback from a Live USB
If your system fails to boot, follow these exact steps:

1.  **Boot the Fedora Live USB** and open a terminal.
2.  **Unlock your Striped Vault:**
    ```bash
    sudo cryptsetup luksOpen /dev/fedora_vg/crypt_vault_striped cryptroot
    # Enter your passphrase or recovery key
    ```
3.  **Mount the Top-Level Btrfs Volume:**
    To manage Btrfs subvolumes, mount the "root" of the filesystem (`subvolid=5`), not the OS root.
    ```bash
    sudo mkdir -p /mnt/btrfs_top
    sudo mount -o subvolid=5 /dev/mapper/fedora_encrypted-root /mnt/btrfs_top
    ```
4.  **Locate Your Snapshots:**
    ```bash
    ls -l /mnt/btrfs_top/root/.snapshots/
    ```
    *Find the number of the snapshot you want to restore (e.g., `45`). Inside that numbered directory is a read-only subvolume named `snapshot`.*
5.  **Move the Broken Root:**
    ```bash
    sudo mv /mnt/btrfs_top/root /mnt/btrfs_top/root.broken
    ```
6.  **Clone the Good Snapshot to be the New Root:**
    ```bash
    # This takes the read-only snapshot and creates a read-write copy named "root"
    sudo btrfs subvolume snapshot /mnt/btrfs_top/root.broken/.snapshots/45/snapshot /mnt/btrfs_top/root
    ```
7.  **Clean up and Reboot:**
    ```bash
    sudo umount /mnt/btrfs_top
    sudo reboot
    ```
    Your system will now boot into the exact state of Snapshot #45, completely ignoring the `root.broken` directory.
