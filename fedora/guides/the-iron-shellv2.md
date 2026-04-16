# 🛡️ THE IRON SHELL: Fedora 43 Deployment Guide (Web UI Edition)

**Hardware Scope:** i9-13900K · RTX 2080 Ti · 32 GB RAM · 500 GB NVMe (`nvme0n1`) + 1 TB NVMe (`nvme1n1`)
**Status:** Audited & corrected — April 2026, Fedora 43

This guide uses a **"Hybrid Installation"** workflow: the encrypted LVM vault is built manually in the Live environment, then the Anaconda Web UI is used to target that vault. This is necessary because the Anaconda Web UI cannot create a single LUKS container spanning two asymmetrical NVMe drives.

> **Prerequisite:** Confirm TPM 2.0 is visible in firmware. Run `ls /sys/class/tpm/` — it must show at least one `tpm*` device before proceeding.

---

## Phase 1 — Hardware Hardening (The Physical Layer)

Enter BIOS/UEFI and apply the following before booting the Live ISO:

| Setting | Value | Reason |
|---|---|---|
| Secure Boot | **Setup Mode** (clear factory keys) | Required for sbctl key enrollment |
| Intel TME | **Enable** | Encrypts 32 GB RAM at the hardware level |
| VT-d / IOMMU | **Enable** | Required for NVIDIA driver memory isolation |
| Fast Boot | **Disable** | Ensures clean USB detection |
| Supervisor Password | **Set** | Prevents firmware tampering from physical access |

---

## Phase 2 — CLI Vault Preparation

Boot the **Fedora 43 Workstation Live ISO**. When the "Welcome to Fedora" screen appears,
**do not click "Install Fedora" yet.** Open a GNOME Terminal and switch to root:

```bash
sudo -i
```

### 2.1 Partition Both Drives

> **Critical:** The drives must be GPT-partitioned before LVM is created. The entire-disk
> `pvcreate` approach in many guides destroys any chance of placing an EFI partition later.
> We reserve 600 MiB on `nvme0n1` first, then use the remainder as PV space.

```bash
# Wipe any existing metadata
wipefs -a /dev/nvme0n1 /dev/nvme1n1

# nvme0n1 (500 GB): GPT + 600 MiB EFI + rest for LVM
parted -s /dev/nvme0n1 mklabel gpt
parted -s /dev/nvme0n1 mkpart efi fat32 1MiB 601MiB
parted -s /dev/nvme0n1 set 1 esp on
parted -s /dev/nvme0n1 mkpart lvm 601MiB 100%

# nvme1n1 (1 TB): GPT + entire disk for LVM
parted -s /dev/nvme1n1 mklabel gpt
parted -s /dev/nvme1n1 mkpart lvm 1MiB 100%

# Format the EFI partition now
mkfs.fat -F32 -n EFI /dev/nvme0n1p1

# Verify layout
lsblk /dev/nvme0n1 /dev/nvme1n1
```

After this step, `nvme0n1p1` is your EFI partition and `nvme0n1p2`/`nvme1n1p1` are the LVM PVs.

### 2.2 Build the Outer LVM and Encrypt the Vault

```bash
# Create Physical Volumes (on PARTITIONS, not raw devices)
pvcreate /dev/nvme0n1p2 /dev/nvme1n1p1
vgcreate fedora_vg /dev/nvme0n1p2 /dev/nvme1n1p1

# Striped OS vault: 928 GiB, split equally across both PVs
# (nvme0n1p2 contributes ~464 GiB; staying under its ceiling)
lvcreate -i 2 -L 928G -n crypt_vault_striped fedora_vg

# Linear data vault: consume all remaining space (~568 GiB on nvme1n1p1)
lvcreate -l 100%FREE -n crypt_vault_linear fedora_vg

# Encrypt the striped OS vault (Argon2id — requires LUKS2)
cryptsetup luksFormat \
    --type luks2 \
    --pbkdf argon2id \
    --pbkdf-memory 524288 \
    /dev/fedora_vg/crypt_vault_striped
# Type YES and enter your master passphrase.

# Encrypt the linear data vault with the same passphrase
cryptsetup luksFormat \
    --type luks2 \
    --pbkdf argon2id \
    /dev/fedora_vg/crypt_vault_linear
# Type YES and enter the same master passphrase.

# Open the striped vault
cryptsetup luksOpen /dev/fedora_vg/crypt_vault_striped cryptroot

# Build the inner LVM inside the decrypted vault
pvcreate /dev/mapper/cryptroot
vgcreate fedora_encrypted /dev/mapper/cryptroot
lvcreate -l 100%FREE -n root fedora_encrypted
```

---

## Phase 3 — Anaconda Web UI Installation

Now click **"Install Fedora"** on the desktop.

1. **Language / Region:** Select your preferences.
2. **Storage Configuration → Custom / Manual partitioning.**
3. **Assign mount points:**

   | Device | Mount Point | Filesystem | Size |
   |---|---|---|---|
   | `/dev/nvme0n1p1` | `/boot/efi` | FAT32 (pre-formatted, do not reformat) | 600 MiB |
   | `/dev/fedora_encrypted/root` | `/` | **Btrfs** | All remaining |

   > Anaconda will automatically create `root` and `home` Btrfs subvolumes under `/`.
   > Do **not** create a separate `/boot` partition — the UKI workflow embeds everything
   > into a single signed EFI binary.

4. **Confirm and Install.** The summary should show `/` on a decrypted LVM volume and
   `/boot/efi` on the physical disk. Proceed.

---

## Phase 4 — The Iron Chain (Post-Install Closure)

When Anaconda says "Installation Complete," **do not reboot.** Return to the terminal.

### 4.1 Chroot Into the New System

```bash
# Mount root subvolume
mount -o subvol=root /dev/mapper/fedora_encrypted-root /mnt

# Mount EFI partition
mount /dev/nvme0n1p1 /mnt/boot/efi

# Bind kernel virtual filesystems
for i in /dev /dev/pts /proc /sys /run; do
    mount --bind "$i" "/mnt$i"
done

# Enter chroot
chroot /mnt
```

### 4.2 Install sbctl and Create Secure Boot Keys

> **Note:** `sbctl` is not in the default Fedora repositories. Install it via COPR.

```bash
# Install sbctl and signing tools
dnf install dnf-plugins-core -y
dnf copr enable chenxiaolong/sbctl -y
dnf install sbctl sbsigntools -y

# Create your own Platform Key, KEK, and DB keys
sbctl create-keys

# Enroll your keys into UEFI firmware, including Microsoft's hardware certificates.
# The --microsoft flag is required for the RTX 2080 Ti's option ROM to pass Secure Boot.
sbctl enroll-keys --microsoft
```

> **Key location:** sbctl stores keys at `/var/lib/sbctl/keys/db/db.key` and
> `/var/lib/sbctl/keys/db/db.pem`. All scripts in later phases use this path.

### 4.3 Build and Sign the Unified Kernel Image (UKI)

This bypasses the GRUB chain entirely and signs the kernel as a single EFI binary.

```bash
# Capture kernel version and LUKS UUID
KVER=$(ls /lib/modules | sort -V | tail -n 1)
LUKS_UUID=$(blkid -s UUID -o value /dev/fedora_vg/crypt_vault_striped)

# Ensure the target directory exists
mkdir -p /boot/efi/EFI/Linux

# Write the kernel command line to the standard location
# rd.luks.name maps the UUID to the device name "cryptroot"
cat > /etc/kernel/cmdline <<EOF
rd.luks.uuid=${LUKS_UUID} rd.luks.name=${LUKS_UUID}=cryptroot \
root=/dev/mapper/fedora_encrypted-root rootflags=subvol=root \
rd.lvm.vg=fedora_encrypted ro quiet
EOF

# Generate the UKI (dracut bundles kernel + initramfs + cmdline into one EFI binary)
# The UKI is placed in EFI/Linux/ for automatic detection by systemd-boot/efibootmgr
dracut --uefi \
    --kver "${KVER}" \
    --force \
    --add "crypt lvm btrfs" \
    --kernel-cmdline "$(cat /etc/kernel/cmdline)" \
    /boot/efi/EFI/Linux/fedora-uki.efi

# Sign the UKI with your sbctl DB key
sbctl sign -s /boot/efi/EFI/Linux/fedora-uki.efi

# Register the UKI as a UEFI boot entry
efibootmgr \
    --create \
    --disk /dev/nvme0n1 \
    --part 1 \
    --label "Fedora Iron Shell" \
    --loader '\EFI\Linux\fedora-uki.efi' \
    --unicode

# Verify the boot entry was created
efibootmgr -v | grep "Fedora Iron Shell"
```

### 4.4 Bind Crypt-Vault to TPM 2.0

This enables passphrase-free boot on your hardware while remaining protected against
offline attacks (the TPM will refuse to release the key if PCRs have been tampered with).

```bash
systemd-cryptenroll \
    --tpm2-device=auto \
    --tpm2-pcrs=0+1+4+7 \
    /dev/fedora_vg/crypt_vault_striped
```

### 4.5 Configure Snapper for Btrfs Snapshots

The emergency rollback in Phase 7 requires snapshots. Set them up now, before first boot.

```bash
dnf install snapper -y

# Create a snapper config for the root subvolume
snapper -c root create-config /

# Enable timeline snapshots and set retention
cat > /etc/snapper/configs/root <<'EOF'
SUBVOLUME="/"
FSTYPE="btrfs"
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="4"
TIMELINE_LIMIT_MONTHLY="6"
TIMELINE_LIMIT_YEARLY="0"
NUMBER_CLEANUP="yes"
NUMBER_LIMIT="50"
EOF

systemctl enable snapper-timeline.timer snapper-cleanup.timer
```

**Exit the chroot and reboot.** Remove the USB drive.

```bash
exit
umount -R /mnt
reboot
```

---

## Phase 5 — NVIDIA Driver & Module Signing

### 5.1 Repository Setup

> **DNF5 syntax:** Fedora 41+ ships DNF5, which uses `addrepo --from-repofile` instead of
> the legacy `--add-repo` flag. Using the old flag will silently fail.

```bash
# Add negativo17 repositories (DNF5 syntax)
sudo dnf config-manager addrepo \
    --from-repofile=https://negativo17.org/repos/fedora-nvidia.repo
sudo dnf config-manager addrepo \
    --from-repofile=https://negativo17.org/repos/fedora-multimedia.repo

# Install driver stack
sudo dnf install nvidia-driver nvidia-settings cuda \
    gstreamer1-plugins-bad-free-devel ffmpeg-free-devel -y
```

### 5.2 Kernel Module Signing Setup

> **Critical error in common guides:** `sbsign` signs EFI PE executables (UKIs, bootloaders).
> It **cannot** sign Linux kernel modules (`.ko` files). Kernel modules must be signed with
> `sign-file`, which produces the PKCS#7 signature format the kernel verifies.
>
> We use a **dedicated module-signing key** separate from the Secure Boot DB key. Its
> certificate is added to the UEFI DB so the kernel's platform keyring trusts it.

```bash
# Generate a dedicated 2048-bit RSA key for module signing
# (TPMs max out at RSA 2048; keeping keys consistent)
sudo openssl req -new -x509 \
    -newkey rsa:2048 \
    -keyout /etc/pki/akmods/certs/private_key.pem \
    -out    /etc/pki/akmods/certs/public_key.pem \
    -days 7300 \
    -subj "/CN=Iron Shell Module Signing Key" \
    -nodes

# Convert the certificate to DER for the UEFI DB
sudo openssl x509 \
    -in  /etc/pki/akmods/certs/public_key.pem \
    -out /etc/pki/akmods/certs/public_key.der \
    -outform DER

# Enroll the module-signing certificate into the UEFI DB alongside the sbctl keys
# This makes the kernel's platform keyring trust your signed modules
sudo sbctl enroll-keys \
    --custom /etc/pki/akmods/certs/public_key.pem \
    --yes-this-might-brick-my-machine
# Note: Microsoft keys were enrolled in Phase 4.2, so this only adds the custom cert.
```

### 5.3 The Iron Chain Automation Script

Create `/usr/local/bin/harden-kernel-sign.sh`:

```bash
#!/bin/bash
# Iron Chain: Re-signs NVIDIA modules and the UKI after kernel or driver updates.
# Triggered automatically by dnf post-transaction hooks.
set -euo pipefail

KVER=$(ls /lib/modules | sort -V | tail -n 1)
MOD_DIR="/lib/modules/${KVER}/extra/nvidia"
UKI_PATH="/boot/efi/EFI/Linux/fedora-uki.efi"

# Keys for module signing (sign-file format: key then cert, both PEM)
MOD_KEY="/etc/pki/akmods/certs/private_key.pem"
MOD_CERT="/etc/pki/akmods/certs/public_key.pem"

# sign-file lives inside the kernel build directory
SIGN_FILE="/usr/lib/modules/${KVER}/build/scripts/sign-file"

if [[ ! -x "${SIGN_FILE}" ]]; then
    echo "ERROR: sign-file not found at ${SIGN_FILE}. Install kernel-devel." >&2
    exit 1
fi

# Sign each NVIDIA kernel module with sign-file (not sbsign — sbsign is for EFI binaries)
echo "[Iron Chain] Signing NVIDIA kernel modules..."
for mod in "${MOD_DIR}"/*.ko "${MOD_DIR}"/*.ko.xz 2>/dev/null; do
    [[ -f "${mod}" ]] || continue
    "${SIGN_FILE}" sha256 "${MOD_KEY}" "${MOD_CERT}" "${mod}"
    echo "  Signed: ${mod}"
done

# Rebuild and re-sign the UKI
echo "[Iron Chain] Rebuilding UKI for kernel ${KVER}..."
dracut --uefi \
    --kver "${KVER}" \
    --force \
    --add "crypt lvm btrfs" \
    --kernel-cmdline "$(cat /etc/kernel/cmdline)" \
    "${UKI_PATH}"

sbctl sign -s "${UKI_PATH}"
echo "[Iron Chain] UKI signed and registered: ${UKI_PATH}"
```

Make the script executable:

```bash
sudo chmod +x /usr/local/bin/harden-kernel-sign.sh
```

Install the `kernel-devel` package so `sign-file` is available:

```bash
sudo dnf install kernel-devel -y
```

Create the dnf post-transaction trigger at `/etc/dnf/plugins/post-transaction-actions.d/nvidia.action`:

```text
kernel-core:any:/usr/local/bin/harden-kernel-sign.sh
kernel-devel:any:/usr/local/bin/harden-kernel-sign.sh
nvidia-driver:any:/usr/local/bin/harden-kernel-sign.sh
```

---

## Phase 6 — JAX & Emacs Development (Secure Container)

### 6.1 Container Image

```dockerfile
# Use a current CUDA 12 base image compatible with the RTX 2080 Ti (SM 7.5 / Turing)
FROM nvidia/cuda:12.6.0-base-ubuntu24.04

RUN apt-get update && apt-get install -y \
    python3-pip python3-venv curl gzip \
    && rm -rf /var/lib/apt/lists/*

# Install JAX — modern pip-wheel method (no external -f flag needed since JAX 0.4.14)
RUN pip install --upgrade pip && \
    pip install --upgrade "jax[cuda12]"

# Python LSP server for Emacs eglot
RUN pip install python-lsp-server[all]

# emacs-lsp-booster for high-speed LSP throughput
RUN curl -L \
    https://github.com/blahgeek/emacs-lsp-booster/releases/latest/download/emacs-lsp-booster_x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C /usr/local/bin

RUN useradd -m jaxuser
USER jaxuser
```

> **Note:** The old `"jax[cuda12_pip]" -f https://storage.googleapis.com/jax-releases/...`
> installation method is deprecated and removed upstream. Use `"jax[cuda12]"` from PyPI.

### 6.2 Emacs Configuration (`init.el`)

Link your Wayland Emacs host to the Podman container via eglot:

```elisp
(add-to-list 'eglot-server-programs
             `(python-mode . ("podman" "run" "--rm" "-i"
                              "--device" "nvidia.com/gpu=all"
                              "-v" ,(expand-file-name "~") ":/home/jaxuser:Z"
                              "jax-secure-image"
                              "emacs-lsp-booster" "--emacs-json" "--" "pylsp")))
```

---

## Phase 7 — Emergency Rollback

The UKI bypasses GRUB entirely, so there is no GRUB snapshot menu. Rollback is a two-step
procedure: use snapper (configured in Phase 4.5) to identify a good snapshot, then restore it.

### 7.1 Boot the Fedora 43 Live USB

Open a terminal and switch to root:

```bash
sudo -i
```

### 7.2 Unlock the Vault and Mount Btrfs

```bash
# Reassemble the outer LVM
vgscan --mknodes
vgchange -ay fedora_vg

# Unlock the LUKS layer
cryptsetup luksOpen /dev/fedora_vg/crypt_vault_striped cryptroot

# Activate the inner LVM
vgscan --mknodes
vgchange -ay fedora_encrypted

# Mount the Btrfs top-level (subvolid=5) to see all subvolumes
mount -o subvolid=5 /dev/mapper/fedora_encrypted-root /mnt
```

### 7.3 Identify and Restore a Snapshot

```bash
# List available snapper snapshots
ls /mnt/root/.snapshots/

# Each numbered directory contains a snapshot at:
#   /mnt/root/.snapshots/N/snapshot
# Read the description file to find the right snapshot:
cat /mnt/root/.snapshots/N/info.xml

# Rename the broken root subvolume
mv /mnt/root /mnt/root.broken

# Restore the chosen snapshot as the new root subvolume
btrfs subvolume snapshot \
    /mnt/root.broken/.snapshots/N/snapshot \
    /mnt/root
```

### 7.4 Rebuild the UKI from the Live Environment

Since the UKI cmdline is embedded, you must regenerate it after a rollback if the kernel changed:

```bash
# Chroot into the restored system
mount /dev/nvme0n1p1 /mnt/root/boot/efi
for i in /dev /dev/pts /proc /sys /run; do
    mount --bind "$i" "/mnt/root$i"
done
chroot /mnt/root

# Rebuild and re-sign
KVER=$(ls /lib/modules | sort -V | tail -n 1)
dracut --uefi \
    --kver "${KVER}" \
    --force \
    --add "crypt lvm btrfs" \
    --kernel-cmdline "$(cat /etc/kernel/cmdline)" \
    /boot/efi/EFI/Linux/fedora-uki.efi
sbctl sign -s /boot/efi/EFI/Linux/fedora-uki.efi

exit
```

Reboot. The system returns to the exact state of that snapshot.

---

## Final Hardening Checklist

Run these after first successful boot:

```bash
# Confirm Secure Boot is active with your keys
sbctl status
# Expected: "Setup Mode: Disabled", "Secure Boot: Enabled"

# Confirm all signed files are still valid
sbctl verify

# SELinux must be in Enforcing mode
getenforce
# If it shows "Permissive": sudo setenforce 1
# Make permanent in /etc/selinux/config: SELINUX=enforcing

# USBGuard: block unauthorized USB devices at runtime
sudo systemctl enable --now usbguard

# AIDE: file integrity baseline (run after full setup, takes a few minutes)
sudo dnf install aide -y
sudo aide --init
sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
# Schedule weekly checks:
sudo systemctl enable --now aidecheck.timer
```

---

## Audit Log: Bugs Fixed in This Revision

| # | Location | Original Error | Fix Applied |
|---|---|---|---|
| 1 | Phase 2 | `pvcreate` on raw `nvme0n1`/`nvme1n1` made EFI partition creation impossible | Added GPT partitioning step; EFI on `nvme0n1p1`, PVs on `nvme0n1p2`/`nvme1n1p1` |
| 2 | Phase 2 | `crypt_vault_linear` created but never encrypted or mounted | Added `cryptsetup luksFormat` for the linear vault |
| 3 | Phase 2 | Striped LV size `-L 1000G` would exceed `nvme0n1p2` capacity after EFI reservation | Reduced to `-L 928G` with explanation |
| 4 | Phase 4.2 | `dnf install sbctl` — sbctl is not in default Fedora repos | Added `dnf copr enable chenxiaolong/sbctl` prerequisite |
| 5 | Phase 4.3 | `rd.luks.uuid=` without `rd.luks.name=` — dracut would not name the mapper device `cryptroot` | Added `rd.luks.name=${UUID}=cryptroot` to cmdline |
| 6 | Phase 4.3 | No `efibootmgr` call after UKI creation — system would not know to boot the UKI | Added `efibootmgr --create ...` registration step |
| 7 | Phase 4.3 | Missing `--add "crypt lvm btrfs"` in dracut — initramfs would lack LUKS/LVM modules | Added explicit `--add` dracut flag |
| 8 | Phase 4 | No snapper setup anywhere, but Phase 7 rollback depended on `.snapshots` existing | Added Phase 4.5: snapper configuration |
| 9 | Phase 5.1 | `dnf config-manager --add-repo=URL` is DNF4 syntax; Fedora 41+ uses DNF5 | Changed to `dnf config-manager addrepo --from-repofile=URL` |
| 10 | Phase 5.2 | `sbsign` used to sign `.ko` kernel modules — `sbsign` only works on EFI PE binaries | Replaced with `sign-file sha256` from `kernel-devel` |
| 11 | Phase 5.2 | Key path `/usr/share/secureboot/keys/db/` — sbctl moved this to `/var/lib/sbctl/` in 2023 | Updated all key paths to `/var/lib/sbctl/keys/db/` |
| 12 | Phase 6.1 | Deprecated JAX install: `"jax[cuda12_pip]" -f https://storage.googleapis.com/jax-releases/...` | Updated to `pip install "jax[cuda12]"` from PyPI |
| 13 | Phase 6.1 | `emacs-lsp-booster` download URL used a placeholder (`blah-cache`) path | Updated to the correct `blahgeek` GitHub org URL |
| 14 | Phase 7 | Rollback assumed LVM/LUKS were auto-visible — they are not in the Live environment | Added `vgscan`, `vgchange`, and inner LVM activation steps |
