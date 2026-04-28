
This section covers the installation and configuration of the proprietary NVIDIA driver stack, ensuring it is compatible with Secure Boot, the Wayland compositor, and the system's hardening measures.

### 7B.1 — Kernel Configuration for NVIDIA

The cachyos-sources `.config` already enables most of the required options, but verify the following with `make menuconfig` before building the kernel:

```
Bus options (PCI etc.) --->
  [*] PCI Express support
  [*] VGA Arbitration                                   CONFIG_VGA_ARB

Device Drivers --->
  Graphics support --->
    <*/M> Direct Rendering Manager (XFree86 …)          CONFIG_DRM
    [*]   Enable legacy fbdev support for your …        CONFIG_DRM_FBDEV_EMULATION
    < >   Nouveau (NVIDIA) cards                        CONFIG_DRM_NOUVEAU

  Firmware Drivers --->
    [*] Mark VGA/VBE/EFI FB as generic system …         CONFIG_SYSFB_SIMPLEFB
```

*   `CONFIG_DRM_FBDEV_EMULATION` is essential for `nvidia-drm` to provide a framebuffer console.
*   `CONFIG_VGA_ARB` ensures correct handoff between multiple GPU drivers (e.g., `simpledrm` and `nvidia-drm`) at boot.

### 7B.2 — Kernel Command Line and Modesetting

For NVIDIA driver versions 560 and later, modesetting is enabled by default for Wayland. No additional kernel command-line parameters are required. The driver will automatically set `modeset=1` and `fbdev=1`. This behavior is confirmed by the Arch Linux wiki and the official NVIDIA documentation for the 580 series.

### 7B.3 — USE Flags

The relevant USE flags for `x11-drivers/nvidia-drivers` are evaluated for this specific desktop setup (RTX 2080 Ti). The key flags are `kernel-open` and `modules-sign`.

*   **`kernel-open`**: This flag is enabled by default and uses the open-source kernel modules. It is recommended for Turing (RTX 20-series) and newer GPUs, and is mandatory for the NVIDIA 50-series "Blackwell" GPUs.
*   **`modules-sign`**: This flag is critical for Secure Boot. Its role is elaborated in section 7B.4.
*   **`persistenced`**: Enables the `nvidia-persistenced` daemon, which is useful for keeping the GPU state initialized, reducing latency for CUDA applications.
*   **`powerd`**: This flag is **not needed** for desktops. It is specifically for laptops with NVIDIA Dynamic Boost technology. The Gentoo package description explicitly states it is "only useful with specific laptops, ignore if unsure".

Configure the necessary flags. If you already have an entry for `x11-drivers/nvidia-drivers` in your file, merge the flags to avoid duplication.

```bash
# /etc/portage/package.use/nvidia
x11-drivers/nvidia-drivers modules-sign persistenced
```

### 7B.4 — Secure Boot and Module Signing

Since this system uses Secure Boot with custom keys, all kernel modules must be signed to load. The `modules-sign` USE flag automates this process in Gentoo, leveraging the same keys used for the kernel and UKI.

1.  **Ensure Keys Exist**: The `sbctl` keys must exist. If you followed Part 9, they are at `/var/lib/sbctl/keys/db/db.key` and `/var/lib/sbctl/keys/db/db.pem`.
2.  **Module Signing in `make.conf`**: Add the following to `/etc/portage/make.conf` to tell Portage where the signing keys are. These variables are used by the `modules-sign` eclass.

    ```bash
    # /etc/portage/make.conf
    MODULES_SIGN_KEY="/var/lib/sbctl/keys/db/db.key"
    MODULES_SIGN_CERT="/var/lib/sbctl/keys/db/db.pem"
    ```

3.  **Kernel Configuration**: Ensure `CONFIG_MODULE_SIG=y` is set in the kernel. This is usually already enabled by cachyos-sources.
4.  **Verification**: After installing the driver, verify the modules are signed.

    ```bash
    modinfo nvidia | grep '^sig_key'
    ```
    Running `modinfo nvidia` should show a signature key, confirming the module has been signed. The output should include the signer and key fingerprint, indicating the module's integrity is protected.

### 7B.5 — Install the Driver

```bash
emerge --ask x11-drivers/nvidia-drivers
```

After the emerge completes, verify the key components:

```bash
# Check that modules are present
modinfo nvidia nvidia-modeset nvidia-uvm nvidia-drm

# Verify that the modules are signed
modinfo nvidia | grep -E 'sig_|signer'
# Expected output should show a signer and signature info, not be empty.
```

### 7B.6 — Module Parameters and Blacklisting

Create the main NVIDIA module configuration file:

```bash
cat > /etc/modprobe.d/nvidia.conf << 'EOF'
# Maintained by: Hardened Gentoo Setup Guide
# Enable kernel mode setting (required for Wayland)
options nvidia-drm modeset=1
# Use the Page Attribute Table for memory allocation (performance)
options nvidia NVreg_UsePageAttributeTable=1
# Preserve video memory allocations across suspend/resume
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/tmp
EOF
```

As noted in 7B.2, `modeset=1` is the default for newer drivers. The explicit option is kept as a precaution for older branches and serves as a clear document of the requirement.

Prevent the open-source `nouveau` driver from binding to the GPU:

```bash
cat > /etc/modprobe.d/blacklist-nouveau.conf << 'EOF'
# Prevent the nouveau driver from binding to NVIDIA GPUs
install nouveau /bin/true
blacklist nouveau
EOF
```

### 7B.7 — TPM and NVIDIA

The TPM is used primarily for boot-time integrity verification (PCR sealing of the LUKS key) and for SSH key storage. There is no direct integration between the TPM and the NVIDIA driver. The driver's operation is unaffected by the TPM, and it does not interact with the TPM for functionality. Its security on this system is ensured through module signing (Secure Boot) and confinement via AppArmor.

### 7B.8 — Enable Services

```bash
# Persistence daemon – keeps GPU state alive (reduces initialization latency)
systemctl enable nvidia-persistenced.service
```

### 7B.9 — Rebuild the Initramfs and UKI

The NVIDIA kernel modules must be included in the initramfs to load early enough for a graphical boot and Wayland.

```bash
KVER=$(ls /lib/modules/ | sort -V | tail -1)
dracut --force --verbose /efi/EFI/Linux/gentoo-${KVER}.efi ${KVER}
```

Verify the NVIDIA modules are embedded:

```bash
lsinitrd /efi/EFI/Linux/gentoo-${KVER}.efi | grep -E "nvidia"
```

Re-sign the new UKI:

```bash
sbctl sign -s /efi/EFI/Linux/gentoo-${KVER}.efi
```

---

### 7B.10 — AppArmor Integration for NVIDIA

The `apparmor.d` project includes an `abstractions/nvidia` file that can be used to mediate access to NVIDIA device files and libraries. This abstraction defines rules for common NVIDIA resources, including device nodes (`/dev/nvidia*`), library paths, and shared memory. To integrate it into your security policy, `#include <abstractions/nvidia>` to the profiles of any application that requires GPU access.

1.  **Identify Profiles**: Start with applications that have existing AppArmor profiles, such as Firefox (in complain mode) or your display manager (SDDM).
2.  **Add the Abstraction**: Edit the relevant profile in `/etc/apparmor.d/`. For example, to allow SDDM to manage the display, add the include line to its profile:

    ```bash
    # In /etc/apparmor.d/usr.sbin.sddm
    profile sddm /usr/bin/sddm {
      # ... existing rules ...
      #include <abstractions/nvidia>
      # ...
    }
    ```

3.  **Test**: After making changes, run your system in complain mode for these profiles and monitor the AppArmor logs (`aa-logprof`) to identify any additional rules needed.

### 7B.11 — Hardening `nvidia-persistenced` with `svc-harden.py`

The `nvidia-persistenced` service can be hardened using `svc-harden.py`, as referenced in Part 23 of the main guide. The script applies security directives such as `NoNewPrivileges`, `ProtectSystem=strict`, and `MemoryDenyWriteExecute` to reduce the attack surface of the service.

After ensuring the service runs correctly in its default configuration, apply the hardening:

```bash
# Analyze the current security posture
svc-harden.py analyze nvidia-persistenced.service

# Apply hardening directives interactively
svc-harden.py apply nvidia-persistenced.service
```

During the `apply` process, you can enable directives such as `ProtectSystem=strict` and `PrivateTmp=true`. It is important to test the GPU's functionality after applying each directive to ensure it does not interfere with driver operations.

---

### 7B.12 — Post-Install Verification

After the first successful boot:

```bash
# 1. Verify the NVIDIA kernel module is loaded and signed
lsmod | grep nvidia
# Expected output should include: nvidia_drm, nvidia_modeset, nvidia_uvm, nvidia

# 2. Check DRM KMS is active
cat /sys/module/nvidia_drm/parameters/modeset
# Should print: Y

# 3. Verify GPU status
nvidia-smi
```

If `nvidia-smi` reports the GPU and driver version, the setup is complete.nd `bisect` subcommands for per‑service systemd hardening. It applies directives like `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`, `MemoryDenyWriteExecute`, and `SystemCallFilter` interactively, one service at a time.

