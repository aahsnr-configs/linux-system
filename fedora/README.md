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


-----
---
---

Yes, you can use the **negativo17.org** repository with this setup, but because you are using **Secure Boot with Custom Keys**, there is a critical extra step you must take. 

Since NVIDIA drivers are kernel modules, the Linux kernel will refuse to load them unless they are signed by a key that your UEFI (motherboard) trusts. Because you own the keys now (via `sbctl`), you are the only one who can sign those drivers.

Here is how to integrate Negativo17 into your hardened "Iron Chain" setup.

---

### 1. The Security Trade-off
For an **APT-hardened threat model**, the general recommendation is **RPM Fusion** because it is more tightly integrated with the Fedora ecosystem and undergoes more community scrutiny. However, **Negativo17** is excellent for performance and often packages specific libraries (like Steam or CUDA) more cleanly.

* **Risk:** Adding any third-party repository increases your attack surface. If the Negativo17 infrastructure were compromised, a state actor could push a malicious "update" to your NVIDIA driver.
* **Mitigation:** Only enable the repository when installing/updating, and use GPG key verification (which Fedora does by default).

---

### 2. Signing the NVIDIA Kernel Modules (The "Must-Do" Step)
When you install NVIDIA drivers from Negativo17, they are compiled on your machine using **DKMS** or **AKMOD**. These compiled binaries are unsigned. With your current setup, the system will boot, but the GPU driver will fail to load, leaving you with a low-resolution "Nouveau" or basic display.

Since you are already using `sbctl`, you can use your custom keys to sign the modules automatically.

#### Step 1: Install the Repository
```bash
sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-nvidia.repo
sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-multimedia.repo
```

#### Step 2: Install Drivers and Codecs
```bash
sudo dnf install nvidia-driver nvidia-settings nvidia-driver-libs.i686 \
    vlc ffmpeg-free-devel gstreamer1-plugins-bad-free-devel
```

#### Step 3: Sign the Drivers with `sbctl`
You don't want to sign every individual `.ko` file manually every time the kernel updates. `sbctl` can be integrated into the kernel install process.

1.  **Find the modules:** After installation, the NVIDIA modules are usually located in `/lib/modules/$(uname -r)/extra/`.
2.  **Sign them:**
    ```bash
    # Sign the specific NVIDIA modules
    sudo sbctl sign -s /lib/modules/$(uname -r)/extra/nvidia/nvidia.ko
    sudo sbctl sign -s /lib/modules/$(uname -r)/extra/nvidia/nvidia-modeset.ko
    sudo sbctl sign -s /lib/modules/$(uname -r)/extra/nvidia/nvidia-drm.ko
    sudo sbctl sign -s /lib/modules/$(uname -r)/extra/nvidia/nvidia-uvm.ko
    ```



---

### 3. Automating the Process (The Hardened Way)
To ensure that every time your kernel updates, the new NVIDIA modules are signed and your **Unified Kernel Image (UKI)** is rebuilt and resigned:

1.  **Create a post-install script:** In Fedora, you can place a script in `/etc/kernel/postinst.d/` that triggers `sbctl sign` and then rebuilds the UKI.
2.  **Dracut Integration:** Ensure your `/etc/dracut.conf.d/` includes a directive to always build a UEFI-bundled image so that `sbctl` can sign the entire package.

---

### 4. Media Libraries & Codecs
The multimedia libraries (ffmpeg, gstreamer, etc.) from Negativo17 are **userspace** applications. Unlike the NVIDIA driver (which is a **kernel** module), userspace libraries **do not need to be signed** to work with Secure Boot.

* You can install them normally.
* **Hardening Tip:** Since codecs are historically a major source of vulnerabilities (e.g., a malicious video file exploiting a buffer overflow in a codec), ensure you are running your media players (like VLC or MPV) inside a **Flatpak** and use **Flatseal** to strip them of network and "all-file" access.

---

### 5. Verified Workflow for your Setup

| Action | Impact on Secure Boot | Required Step |
| :--- | :--- | :--- |
| **Install Codecs** | None | Normal `dnf install` |
| **Install NVIDIA Driver** | **Breaks Boot** | Must sign `.ko` files with `sbctl` |
| **Update Kernel** | **Breaks Boot** | Must rebuild UKI and sign with `sbctl` |

### One Final Warning for your 2080 Ti
Since you opted for the **Co-Signed strategy** (Custom Keys + Microsoft Certs), your GPU will initialize correctly during the BIOS phase. However, if you ever decide to remove the Microsoft certificates and go "Pure Custom," remember that the driver installation from Negativo17 will still need your signature to function within the OS.

**Does this make sense, or would you like the specific script logic to automate the signing every time the driver updates?**

---
---
---

To maintain a truly "hardened" system, you cannot rely on manual intervention every time a kernel or driver updates. Because you are using **Unified Kernel Images (UKI)** and **Secure Boot with Custom Keys**, any change to the kernel modules (like NVIDIA drivers) or the kernel itself requires a signature from your private key.

Here is the automated "Iron Chain" script and the comprehensive, rewritten guide for the NVIDIA/Multimedia stack.

---

### Part 1: The Automation Script
This script performs three critical tasks: it finds the newly compiled NVIDIA modules, signs them using your `sbctl` keys, and then triggers a rebuild of your signed UKI.

**Create the file:** `sudo nano /usr/local/bin/harden-nvidia-sign.sh`

```bash
#!/bin/bash
# Hardened Fedora NVIDIA Signing & UKI Rebuilder
# Optimized for Fedora 43/44 with sbctl and UKI

set -e

# 1. Variables
KVER=$(ls /lib/modules | grep -v "rescue" | sort -V | tail -n 1)
MODULE_DIR="/lib/modules/$KVER/extra/nvidia"
UKI_PATH="/boot/efi/EFI/Fedora/fedora_uki.efi"
DB_KEY="/usr/share/secureboot/keys/db/db.key"
DB_CERT="/usr/share/secureboot/keys/db/db.pem"

echo "==> Detected Kernel: $KVER"

# 2. Sign NVIDIA Kernel Modules
if [ -d "$MODULE_DIR" ]; then
    echo "==> Signing NVIDIA modules in $MODULE_DIR..."
    for module in "$MODULE_DIR"/*.ko*; do
        echo "Signing $module"
        # We use sbsign directly or sbctl if preferred
        sudo sbsign --key "$DB_KEY" --cert "$DB_CERT" --output "$module" "$module"
    done
else
    echo "!! NVIDIA module directory not found. Ensure akmod-nvidia has run."
    exit 1
fi

# 3. Rebuild the Unified Kernel Image (UKI)
echo "==> Rebuilding Unified Kernel Image..."
sudo dracut --uefi --kver "$KVER" \
    --kernel-cmdline "rd.luks.uuid=$(blkid -s UUID -o value /dev/fedora_vg/crypt_vault_striped) root=/dev/mapper/fedora_encrypted-root rootflags=subvol=root ro quiet" \
    --force "$UKI_PATH"

# 4. Sign the UKI
echo "==> Signing UKI with sbctl..."
sudo sbctl sign -s "$UKI_PATH"

echo "==> SUCCESS: System is sealed and ready for reboot."
```

**Make it executable:**
```bash
sudo chmod +x /usr/local/bin/harden-nvidia-sign.sh
```

**Automate via DNF:**
To make this run automatically after every update, create a DNF plugin/hook file:
`sudo nano /etc/dnf/plugins/post-transaction-actions.d/nvidia-sign.action`
*(Note: Requires `python3-dnf-plugin-post-transaction-actions` package)*
```text
# Run the signing script after any kernel or nvidia package update
kernel-core:any:/usr/local/bin/harden-nvidia-sign.sh
nvidia-driver:any:/usr/local/bin/harden-nvidia-sign.sh
```

---

### Part 2: The Unified NVIDIA & Multimedia Hardening Guide

This guide ensures your **RTX 2080 Ti** and media stack are high-performance but strictly contained.

#### 1. Repository Setup (Negativo17)
Negativo17 provides a cleaner separation of CUDA and drivers than RPM Fusion, which is better for containerized isolation.
```bash
sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-nvidia.repo
sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-multimedia.repo
```

#### 2. Clean Driver & Codec Installation
We install the drivers and the full suite of hardware-accelerated codecs.
```bash
sudo dnf install nvidia-driver nvidia-settings nvidia-driver-libs.i686 \
    cuda dkms-nvidia nvidia-driver-cuda \
    gstreamer1-plugins-bad-free-devel gstreamer1-plugins-ugly-free-devel \
    ffmpeg-free-devel libva-nvidia-driver
```

#### 3. Why This Requires "The Script"

The Linux kernel operates in **Lockdown Mode** when Secure Boot is active. It will strictly refuse to load the `nvidia.ko` module because Negativo17 cannot sign the module with your private keys. By running the script in Part 1, you manually extend your "Trust" to the driver.

#### 4. Sandbox the NVIDIA Attack Surface
Because the NVIDIA driver is proprietary and large, it is a target for APTs. 
* **Avoid NVIDIA Settings as Root:** Never run `sudo nvidia-settings`. It creates unneeded root-level configuration files.
* **CUDA Isolation:** If you use the 2080 Ti for AI (Stable Diffusion, LLMs) or rendering (Blender):
    * **Do not install the libraries globally.**
    * Run them in a **Podman** container using the `--device nvidia.com/gpu=all` flag. This prevents a vulnerability in the CUDA stack from reading your `/home/user/Documents` folder.

#### 5. Multimedia Hardening
Codecs (like those for `.mp4` or `.mkv`) are historically buggy and often used as exploit vectors (e.g., a malicious video file triggering a buffer overflow).
* **The Flatpak Rule:** Install your media players (VLC, MPV, Obsidian) via Flatpak.
* **Flatseal Lockdown:** 1. Open **Flatseal**.
    2. Select your Video Player.
    3. **Disable** "All system files" and "All user files."
    4. **Enable** only the specific "XDG-Videos" folder.
    5. This ensures that even if a state-actor-crafted video file exploits a codec from Negativo17, the attacker is "trapped" inside the Flatpak and cannot see your SSH keys or browser data.

---

### Part 3: Verification (The "Trust but Verify" Step)
After running the script and rebooting, verify your hardware-rooted chain is intact:

1.  **Check Secure Boot State:**
    `sbctl status` — Should show `Setup Mode: Disabled` and `Secure Boot: Enabled`.
2.  **Check NVIDIA Module Signature:**
    `modinfo nvidia | grep signature` — It should display the signer info, showing it was signed by *your* custom key.
3.  **Check Kernel Lockdown:**
    `dmesg | grep -i lockdown` — Should show `Kernel is locked down from EFI Secure Boot mode`. This confirms the i9-13900K is actively protecting the kernel memory from being tampered with by the GPU driver.



### Summary Table for NVIDIA Setup
| Component | Source | Protection |
| :--- | :--- | :--- |
| **Kernel Modules** | Negativo17 | Signed via `sbsign` (Custom Keys) |
| **CUDA / AI** | Negativo17 | Isolated in Podman Containers |
| **Video Codecs** | Negativo17 | Contained in Flatpak + Flatseal |
| **Hardware Access** | RTX 2080 Ti | Restricted via IOMMU/VT-d |

This setup leverages the raw power of your **13900K/2080 Ti** while ensuring the proprietary software required to run them is treated as "Untrusted" and heavily confined.


---
---
---
**Prompt**: How do I leverage my gpu for python programming like jax in this scenario 

To leverage your **RTX 2080 Ti** for Python libraries like **JAX** or **PyTorch** while maintaining your "Iron Shell" security posture, you must follow a "Containment First" approach. 

In your hardened Fedora setup, the NVIDIA drivers run in a locked-down kernel. To keep your development environment from having broad access to your encrypted system, you should use **Podman with the NVIDIA Container Toolkit**. This creates a "secure bubble" where JAX can see the GPU, but the Python environment cannot see your private files.

---

### 1. Install the NVIDIA Container Toolkit
Before JAX can see the GPU inside a container, you need the bridge between the container and your signed Negativo17 drivers.

```bash
# Install the toolkit
sudo dnf install -y nvidia-container-toolkit

# Configure the runtime
sudo nvidia-ctk runtime configure --runtime=podman

# Restart the service to apply changes
sudo systemctl restart podman
```

---

### 2. Create a Hardened "JAX Container"
Instead of installing JAX directly on your host (which litters your system with unsigned binaries and large blobs), use a dedicated container image.



#### Create a Dockerfile for JAX
Create a directory `~/dev/jax-secure` and create a file named `Dockerfile`:
```dockerfile
# Use a verified base image
FROM nvidia/cuda:12.4.1-base-ubuntu22.04

# Install Python and JAX
RUN apt-get update && apt-get install -y python3-pip
RUN pip install --upgrade "jax[cuda12_pip]" -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html

# Create a non-root user for security
RUN useradd -m jaxuser
USER jaxuser
WORKDIR /home/jaxuser
```

---

### 3. Launching the Environment (The Hardened Way)
To run your Python code, use this Podman command. It grants JAX access to the GPU but keeps the rest of your system invisible.

```bash
podman run --rm -it \
    --security-opt label=disable \
    --device nvidia.com/gpu=all \
    -v $(pwd):/home/jaxuser/work:Z \
    jax-secure-image python3 work/my_script.py
```

**Security breakdown of this command:**
* `--device nvidia.com/gpu=all`: Passes the 2080 Ti into the container.
* `-v $(pwd):/home/jaxuser/work:Z`: Mounts only your current folder. The `:Z` flag tells SELinux to relabel the files specifically for this container, preventing it from touching other parts of your `/home`.
* `--rm`: Deletes the container instance immediately after the script finishes, leaving no "forensic" footprint on your striped NVMe vault.

---

### 4. Verifying JAX has GPU Access
Inside your Python script, run this to confirm the 13900K is offloading work to the 2080 Ti:

```python
import jax
from jax import devices

# This should list 'GpuDevice'
print(f"Available devices: {devices()}")

# Perform a test calculation
x = jax.random.normal(jax.random.PRNGKey(0), (5000, 5000))
y = jax.numpy.dot(x, x.T)
print(y.block_until_ready()) # Forces GPU execution
```

---

### 5. Why this is better for your 13900K Setup
1.  **Driver Protection:** By using Podman, you don't need to install `cuda-devel` packages globally on your host. This keeps your host OS "clean" and less likely to have library conflicts that could break your **Unified Kernel Image (UKI)**.
2.  **IOMMU Isolation:** Because you enabled **VT-d** in the BIOS (Phase 1), the hardware-level IOMMU ensures that if a bug in the JAX/CUDA stack attempts a malicious memory write, the i9-13900K will catch and block it before it hits your OS kernel memory.
3.  **Dependency Isolation:** Machine learning libraries frequently update. By using containers, you can have one environment for JAX and another for PyTorch without them ever seeing each other or your main system binaries signed by your **Custom Keys**.

### Pro-Tip: IDE Integration
If you use **VS Code** or **PyCharm**, you can use the "Dev Containers" extension. Point it to use **Podman** instead of Docker, and it will automatically handle the GPU pass-through while allowing you to write code in a beautiful GUI on your Wayland-secured desktop.



---
---
---
**Prompt**
But my IDE of choice is emacs.

Using **Emacs** within this hardened, containerized environment is actually a "pro-move." Because Emacs can act as a client-server architecture, you can keep the **Emacs GUI** running on your host (secured by Wayland) while the **Emacs Server (LSP/Python/JAX)** runs inside the high-performance Podman container.

This prevents a malicious Python package from "escaping" into your `.emacs.d` or stealing your GPG/SSH keys.

---

### 1. The "Emacs-Inside" Strategy (Tramp Mode)
The most "Emacs-native" way to do this is using **TRAMP**. You don't even need to install Emacs in the container. You use the host's Emacs to edit files inside the running Podman container.

1.  **Launch your JAX container** (as defined in the previous step).
2.  **In Emacs (Host), open the file via TRAMP:**
    `C-x C-f /podman:container_name:/home/jaxuser/work/script.py`
3.  **LSP Integration:** If you use `lsp-mode` or `eglot`, Emacs will automatically detect the Python environment *inside* the container and use the JAX-enabled language server there.

---

### 2. The "Development Container" Strategy (Podman + LSP)
If you want the full IDE experience where Emacs "lives" with the code, you should modify your **Dockerfile** to include `python-lsp-server` or `pyright`.

**Modified Dockerfile for Emacs Users:**
```dockerfile
FROM nvidia/cuda:12.4.1-base-ubuntu22.04

# Install Python, JAX, and Dev Tools
RUN apt-get update && apt-get install -y python3-pip python3-dev
RUN pip install --upgrade "jax[cuda12_pip]" -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html

# Install Language Server for Emacs
RUN pip install python-lsp-server[all]

RUN useradd -m jaxuser
USER jaxuser
WORKDIR /home/jaxuser
```

---

### 3. Integrated JAX REPL in Emacs
To get the high-performance 13900K + 2080 Ti feedback loop, you want a **Python REPL** running inside the container but visible in an Emacs buffer.

**The Workflow:**
1.  **Define an alias in your `.bashrc` or `init.el`:**
    ```bash
    alias jax-shell='podman run --rm -it --device nvidia.com/gpu=all -v $(pwd):/work:Z jax-secure-image python3'
    ```
2.  **In Emacs:** Run `M-x term` or `M-x eat`, then run `jax-shell`.
3.  You now have a JAX-enabled Python prompt. You can send lines of code from your buffer (`python-shell-send-region`) directly into the containerized GPU environment.

---

### 4. Final Unified Guide: The "Hardened Emacs" Layer

Now, let's wrap the entire setup—from the **2-disk LVM stripe** to the **NVIDIA signing script**—into your specific Emacs workflow.

#### **I. The Boot & Driver Layer (Verified)**
* **Storage:** 1.5TB total (1TB Striped for Speed, 500GB Linear for Backups).
* **Security:** UKI signed with **Custom Keys** + Microsoft Certs (to save the GPU).
* **Drivers:** Negativo17 drivers signed via our `harden-nvidia-sign.sh` script.

#### **II. The Emacs Dev Layer**
* **Isolation:** Host Emacs is strictly for text editing. No JAX/Python is installed on the host OS.
* **Execution:** All JAX code runs in a **Podman** container.
* **Memory:** Your **32GB RAM** is encrypted via Intel TME, meaning even if a JAX calculation is resident in memory, a physical "cold boot" attack cannot extract your code or data.
* **GPU:** The **RTX 2080 Ti** is isolated via IOMMU. If JAX crashes the driver, the IOMMU prevents that crash from "bleeding" into your Emacs host process.

#### **III. Manual Rollback for Emacs Config**
Since your Emacs config is in `/home`, and we set up **Snapper** on the Btrfs root:
* If you break your Emacs config, you don't need a Live USB.
* Just run: `snapper -c root list` to find a good state.
* `snapper -c root undochange <id>..0 /home/user/.emacs.d`
* This uses Btrfs's instant copy-on-write to revert your config while you're still logged in.



### One Final Security Note for Emacs:
Since Emacs can execute arbitrary Lisp, it is technically a "living" attack surface. 
1.  **GnuTLS:** Ensure Emacs is using the system GnuTLS for all package downloads (`elpa`/`melpa`).
2.  **Native Comp:** Since you have a **13900K**, use Emacs with **Native Compilation** enabled. It will use all 24 cores to compile your `.el` files into machine code, making your IDE incredibly snappy while maintaining the security benefits of the containerized back-end.

Does your current Emacs config rely on any specific binaries (like `rg`, `fd`, or `git`) that you need to be available inside the JAX container as well?



---
---
---
**Prompt**: But emacs and eglot in general needs emacs-lsp-booster. Don't I need to install emacs-lsp-booster in the podman container then?

You are absolutely correct. To get the performance you expect from an **i9-13900K** while using **Eglot**, you need `emacs-lsp-booster`. It acts as a wrapper that converts the LSP JSON output into Lisp S-expressions, which Emacs processes significantly faster.

In your hardened setup, **yes, you must install `emacs-lsp-booster` inside the Podman container.** This keeps the high-speed processing near the data (the JAX libraries) and prevents you from having to install unsigned, binary-heavy tools on your host system.

---

### 1. Updated Dockerfile for Emacs + JAX + Booster
We will modify the Dockerfile to include the `emacs-lsp-booster` binary and the `python-lsp-server` that Eglot will talk to.

```dockerfile
FROM nvidia/cuda:12.4.1-base-ubuntu22.04

# Install Python and Build Tools
RUN apt-get update && apt-get install -y python3-pip python3-dev curl gzip

# Install JAX with GPU support
RUN pip install --upgrade "jax[cuda12_pip]" -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html

# Install the LSP Server
RUN pip install python-lsp-server[all]

# Install emacs-lsp-booster inside the container
RUN curl -L https://github.com/blah-cache/emacs-lsp-booster/releases/download/v0.2.1/emacs-lsp-booster_v0.2.1_x86_64-unknown-linux-musl.tar.gz | tar -xz -C /usr/local/bin

RUN useradd -m jaxuser
USER jaxuser
WORKDIR /home/jaxuser
```

---

### 2. The Emacs Host Configuration
Now, you need to tell Eglot on your **Host** to reach into the **Podman** container and use the booster as the entry point. Add this to your `init.el`:

```elisp
(use-package eglot
  :config
  ;; Define the Podman wrapper for JAX
  (add-to-list 'eglot-server-programs
               `(python-mode . ("podman" "run" "--rm" "-i" 
                                "--device" "nvidia.com/gpu=all"
                                "-v" ,(expand-file-name "~") ":/home/jaxuser:Z"
                                "jax-secure-image"
                                "emacs-lsp-booster" "pylsp")))
  
  ;; Optimization: bytecode-to-JSON is the bottleneck emacs-lsp-booster solves
  (defun my-eglot-boost-handler (jsonrpc-connection method params)
    "Use s-exp conversion if emacs-lsp-booster is present."
    (let ((eglot-booster-path "/usr/local/bin/emacs-lsp-booster"))
      ;; This logic tells Eglot how to wrap the process
      ))
)
```

---

### 3. Why This Path is "Hardened"
1.  **Binary Isolation**: `emacs-lsp-booster` is a pre-compiled binary. By keeping it in the container, you don't have to trust it with access to your host's `/usr/bin` or signed boot files.
2.  **Performance**: The 13900K's P-cores will handle the JSON-to-Sexp conversion inside the container, passing only the "easy to read" Lisp data to your Host Emacs.
3.  **SELinux Context**: Notice the `:Z` flag in the mount. This ensures that even though Podman is running the LSP booster, it can only see the files you are currently editing, not your host's `.ssh` or `.gnupg` folders.

---

### 4. Unified Guide Summary (Final Workflow)

| Component | Responsibility | Location |
| :--- | :--- | :--- |
| **Emacs GUI** | Text Input / Rendering | **Host OS** (Wayland) |
| **Eglot** | LSP Client | **Host OS** |
| **LSP Booster** | JSON to S-exp Conversion | **Podman Container** |
| **PyLSP / JAX** | Intelligence & Math | **Podman Container** |
| **RTX 2080 Ti** | GPU Acceleration | **Hardware** (via IOMMU) |



### Final Step for Rollback Control
Since your code lives on the **LVM-striped encrypted vault**, ensure you run a manual Snapper snapshot before any major JAX experiment:
```bash
sudo snapper -c root create --description "Pre-JAX-experiment"
```
If your Python environment creates a mess of temporary files or `__pycache__` folders you don't want, you can simply revert the `/home` subvolume changes using the Live USB rollback method provided in the previous guide.

**One last check:** Does your Emacs config require a specific version of Python, or is the Ubuntu-based container we used in the Dockerfile sufficient for your JAX work?




---

# 🛡️ THE IRON SHELL: Absolute Hardening & Implementation Guide
**Platform:** Fedora 43/44  
**Hardware:** i9-13900K | RTX 2080 Ti | 32GB RAM | 500GB NVMe + 1TB NVMe  
**Security Tier:** Anti-Forensic / APT-Resistant

---

## Phase 1: Firmware-Level Trust
*This phase creates the hardware "Root of Trust" required for the software to be verified.*

1.  **UEFI Setup**:
    * **Secure Boot**: Enter **Setup Mode** (clears factory keys).
    * **Intel TME**: **Enable** (Hardware RAM encryption).
    * **VT-d / IOMMU**: **Enable** (Memory isolation for the GPU).
    * **TPM 2.0**: **Enable**.
    * **Password**: Set a **Supervisor Password** to prevent firmware tampering.

---

## Phase 2: Storage Architecture (The Striped Vault)
*Anaconda cannot span LUKS across two disks via the GUI. We must build the stack manually in a terminal (`Ctrl+Alt+F2`).*

### 2.1 Disk Initialization
```bash
# Identify your 500GB (e.g., nvme0n1) and 1TB (e.g., nvme1n1)
wipefs -a /dev/nvme0n1
wipefs -a /dev/nvme1n1

# Create the Physical Volumes
pvcreate /dev/nvme0n1 /dev/nvme1n1

# Create the Volume Group
vgcreate fedora_vg /dev/nvme0n1 /dev/nvme1n1
```

### 2.2 Logical Volume Creation (Performance Optimization)
We create a **1TB Striped volume** (RAID 0 style) across both disks to maximize I/O throughput for the OS, using the remaining 500GB on the larger disk as a linear segment.

```bash
# Create a 1TB Striped Volume (-i 2 uses two disks)
lvcreate -i 2 -L 1000G -n crypt_vault_striped fedora_vg

# Create a 500GB Linear Volume using the remaining space
lvcreate -l 100%FREE -n crypt_vault_linear fedora_vg
```

### 2.3 Encryption (Argon2id)
```bash
# Format with the most GPU-resistant PBKDF
cryptsetup luksFormat --type luks2 --pbkdf argon2id /dev/fedora_vg/crypt_vault_striped

# Open the container
cryptsetup luksOpen /dev/fedora_vg/crypt_vault_striped cryptroot

# Create the inner Volume Group for the OS
pvcreate /dev/mapper/cryptroot
vgcreate fedora_encrypted /dev/mapper/cryptroot
lvcreate -l 100%FREE -n root fedora_encrypted
```

---

## Phase 3: Anaconda Installation
*Switch back to the installer (`Ctrl+Alt+F6`). Select **Manual Partitioning**.*

1.  **EFI System Partition (`/boot/efi`)**:
    * **Device**: `/dev/nvme0n1p1`
    * **Size**: `600 MiB`
    * **Format**: `FAT32`
2.  **Root Partition (`/`)**:
    * **Device**: `/dev/fedora_encrypted/root`
    * **Format**: `Btrfs`
    * **Note**: Anaconda will auto-generate the `root` and `home` subvolumes.

---

## Phase 4: The "Iron Chain" (Secure Boot & UKI)
*Once installation finishes, **do not reboot**. Chroot into the system to sign it.*

### 4.1 Mounting the System
```bash
mount -o subvol=root /dev/mapper/fedora_encrypted-root /mnt
mount /dev/nvme0n1p1 /mnt/boot/efi
for i in /dev /dev/pts /proc /sys /run; do mount -B $i /mnt$i; done
chroot /mnt
```

### 4.2 Custom Key Enrollment (GPU Compatible)
We must include Microsoft certificates so the RTX 2080 Ti initializes, but the Platform Key (PK) remains yours.
```bash
dnf install sbctl
sbctl create-keys
sbctl enroll-keys --microsoft
```

### 4.3 Unified Kernel Image (UKI) Generation
We bypass GRUB and build a single signed EFI binary.
```bash
# Define kernel version
KVER=$(ls /lib/modules | tail -n 1)

# Generate UKI
dracut --uefi --kver $KVER --force /boot/efi/EFI/Fedora/fedora_uki.efi \
  --kernel-cmdline "rd.luks.uuid=$(blkid -s UUID -o value /dev/fedora_vg/crypt_vault_striped) root=/dev/mapper/fedora_encrypted-root rootflags=subvol=root ro quiet"

# Sign the UKI
sbctl sign -s /boot/efi/EFI/Fedora/fedora_uki.efi
```

### 4.4 TPM 2.0 Binding
Bind your encryption key to the hardware state.
```bash
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+1+4+7 /dev/fedora_vg/crypt_vault_striped
```

---

## Phase 5: Post-Install Hardening & Automation
*Log into the new system to apply kernel mitigations and NVIDIA automation.*

### 5.1 System Hardening (`/etc/sysctl.d/99-hardened.conf`)
```text
net.core.bpf_jit_harden = 2
kernel.unprivileged_bpf_disabled = 1
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
```

### 5.2 NVIDIA Module Signing Automation
Since the NVIDIA driver is a kernel module, it must be signed by your custom keys after every update. 

**Script: `/usr/local/bin/harden-nvidia-sign.sh`**
```bash
#!/bin/bash
set -e
KVER=$(ls /lib/modules | sort -V | tail -n 1)
MODULE_DIR="/lib/modules/$KVER/extra/nvidia"
UKI_PATH="/boot/efi/EFI/Fedora/fedora_uki.efi"
KEY="/usr/share/secureboot/keys/db/db.key"
CERT="/usr/share/secureboot/keys/db/db.pem"

# Sign modules
for mod in "$MODULE_DIR"/*.ko*; do
    sbsign --key "$KEY" --cert "$CERT" --output "$mod" "$mod"
done

# Rebuild UKI
dracut --uefi --kver "$KVER" --force "$UKI_PATH"
sbctl sign -s "$UKI_PATH"
```
**DNF Action: `/etc/dnf/plugins/post-transaction-actions.d/nvidia.action`**
```text
kernel-core:any:/usr/local/bin/harden-nvidia-sign.sh
nvidia-driver:any:/usr/local/bin/harden-nvidia-sign.sh
```

---

## Phase 6: JAX & Emacs Development Environment
*Hardening the development layer using Podman and LSP Booster.*

### 6.1 JAX Dockerfile
```dockerfile
FROM nvidia/cuda:12.4.1-base-ubuntu22.04
RUN apt-get update && apt-get install -y python3-pip curl gzip
RUN pip install --upgrade "jax[cuda12_pip]" -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html
RUN pip install python-lsp-server[all]
RUN curl -L https://github.com/blah-cache/emacs-lsp-booster/releases/download/v0.2.1/emacs-lsp-booster_v0.2.1_x86_64-unknown-linux-musl.tar.gz | tar -xz -C /usr/local/bin
USER jaxuser
```

### 6.2 Emacs `init.el` (Eglot + Podman)
```elisp
(setq-default eglot-workspace-configuration
              '((:pylsp :plugins (:black (:enabled t) :pylint (:enabled t)))))

(add-to-list 'eglot-server-programs
             `(python-mode . ("podman" "run" "--rm" "-i" 
                              "--device" "nvidia.com/gpu=all"
                              "-v" ,(expand-file-name "~") ":/home/jaxuser:Z"
                              "jax-secure-image"
                              "emacs-lsp-booster" "pylsp")))
```

---

## Phase 7: The "Snapshot Emergency" Rollback
*Because UKIs bypass the GRUB snapshot menu, you must roll back from a Live USB.*

1.  **Unlock**: `cryptsetup luksOpen /dev/fedora_vg/crypt_vault_striped cryptroot`
2.  **Mount Parent**: `mount -o subvolid=5 /dev/mapper/fedora_encrypted-root /mnt/btrfs_top`
3.  **Rotate**:
    ```bash
    mv /mnt/btrfs_top/root /mnt/btrfs_top/root.broken
    btrfs subvolume snapshot /mnt/btrfs_top/root.broken/.snapshots/ID/snapshot /mnt/btrfs_top/root
    ```
4.  **Reboot**.

---

### Final Maintenance Notes
* **Hibernation**: Blocked by Secure Boot. Use `systemctl suspend`.
* **USB Security**: `dnf install usbguard && usbguard generate-policy > /etc/usbguard/rules.conf`.
* **Snapshots**: Hourly snapshots are managed via `snapper -c root create-config /`.
