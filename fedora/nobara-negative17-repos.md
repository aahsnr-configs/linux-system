# Comprehensive Guide: Installing NVIDIA Drivers from Negativo17 on Fedora Linux

**Including Akmods, Open Kernel Modules, Multimedia Codecs, and CachyOS Kernel Compatibility**

**Last Updated:** February 2026  
**Fedora Versions:** 41, 42+

---

## Table of Contents

1. [Introduction and Overview](#1-introduction-and-overview)
2. [System Requirements and Prerequisites](#2-system-requirements-and-prerequisites)
3. [Understanding Negativo17 Repository](#3-understanding-negativo17-repository)
4. [NVIDIA Driver Installation Methods](#4-nvidia-driver-installation-methods)
5. [Switching Between Open and Proprietary Modules](#5-switching-between-open-and-proprietary-modules)
6. [Multimedia Codecs Installation](#6-multimedia-codecs-installation)
7. [CachyOS Kernel Compatibility](#7-cachyos-kernel-compatibility)
8. [Troubleshooting and Common Issues](#8-troubleshooting-and-common-issues)
9. [Additional Resources](#9-additional-resources)

---

## 1. Introduction and Overview

This comprehensive guide covers the installation and configuration of NVIDIA drivers on Fedora Linux using the Negativo17 repository. Negativo17 provides a well-maintained alternative to RPMFusion with several advantages:

- **Granular package installation** - Install only what you need
- **Better CUDA and multimedia support** - Enhanced integration for development and content creation
- **Both proprietary and open-source modules** - Full support for both kernel module types
- **Multimedia repository integration** - Comprehensive codec and tools ecosystem
- **Wayland-only support** - Can install drivers without X11 components

### Why Negativo17?

Unlike RPMFusion, Negativo17 follows Fedora packaging guidelines more closely, offers more modular package selection, and provides better separation between driver components. This makes it ideal for specialized setups like compute-only servers, Wayland-exclusive desktops, or systems requiring specific CUDA toolkit versions.

---

## 2. System Requirements and Prerequisites

### 2.1 Supported Fedora Versions

Negativo17 officially supports the latest 2 Fedora releases. As of February 2026:

- **Fedora 41** (fully supported)
- **Fedora 42** (fully supported)

### 2.2 GPU Compatibility

#### Open Kernel Modules (`kernel-open`)

**Supported Architectures:**

- Turing (RTX 20 series, GTX 16 series)
- Ampere (RTX 30 series)
- Ada Lovelace (RTX 40 series)
- Hopper (H100, etc.)
- Blackwell and newer

**Examples of Supported GPUs:**

- GeForce: RTX 2060/2070/2080, RTX 3060/3070/3080/3090, RTX 4060/4070/4080/4090, GTX 1650/1660
- Quadro: RTX 4000/5000/6000/8000 (Turing), RTX A series
- Data Center: A100, H100, and newer

**Mandatory for:** Blackwell and newer GPUs  
**Recommended for:** All Turing and newer GPUs (per NVIDIA)

#### Proprietary Kernel Modules (`kernel`)

**Supported Architectures:**

- Maxwell (GTX 900 series)
- Pascal (GTX 10 series)
- Volta (TITAN V, Quadro GV100)
- Turing (RTX 20 series, GTX 16 series)
- Ampere (RTX 30 series)
- Ada Lovelace (RTX 40 series)

**Examples of Supported GPUs:**

- GeForce: GTX 950/960/970/980, GTX 1050/1060/1070/1080, RTX 2060/3070/4080
- Quadro: M series, P series, GP100

**Required for:** Maxwell, Pascal, and Volta GPUs (these lack GSP - GPU System Processor)  
**Note:** Driver 580 branch is the last to support Maxwell, Pascal, and Volta. A separate LTS repository is available for these older GPUs.

### 2.3 UEFI Secure Boot

**Options:**

1. **Disable Secure Boot** (Easiest) - Enter BIOS/UEFI and disable Secure Boot
2. **Sign kernel modules** (Advanced) - Import MOK keys using `mokutil`

If Secure Boot is enabled without signed modules, the driver will fail to load with no error messages.

### 2.4 Required Packages

Before installation, ensure you have:

```bash
sudo dnf install kernel-devel kernel-headers gcc make
```

These are required for akmod to build kernel modules.

---

## 3. Understanding Negativo17 Repository

### 3.1 Repository Structure

Negativo17 provides two primary repositories:

#### **fedora-nvidia**

- Contains only NVIDIA drivers and CUDA tools
- Minimal installation footprint
- Repository URL: `https://negativo17.org/repos/fedora-nvidia.repo`

#### **fedora-multimedia**

- Includes **all NVIDIA drivers** plus multimedia tools
- HandBrake, MakeMKV, FFmpeg with NVENC/NVDEC
- GStreamer plugins, codecs, and transcoding tools
- Repository URL: `https://negativo17.org/repos/fedora-multimedia.repo`

**Important:** If you install the multimedia repository, you don't need the nvidia-only repository.

### 3.2 Driver Versioning Strategy

| Distribution       | Driver Branch      | Description                                    |
| ------------------ | ------------------ | ---------------------------------------------- |
| **Fedora**         | Short Lived Branch | Latest feature drivers with newest GPU support |
| **RHEL/CentOS**    | Long Lived Branch  | Stable drivers with extended support           |
| **Fedora Rawhide** | Beta Branch        | Pre-release drivers for testing                |

As of February 2026, Fedora typically ships drivers in the **580+** series for current hardware.

### 3.3 Akmod vs DKMS vs kABI

Negativo17 provides three kernel module packaging methods:

| Method    | Description                                                 | Best For                              |
| --------- | ----------------------------------------------------------- | ------------------------------------- |
| **Akmod** | Automatic kernel module building on boot (Fedora standard)  | Fedora workstations (**recommended**) |
| **DKMS**  | Dynamic Kernel Module Support (cross-distribution standard) | Users familiar with Ubuntu/Debian     |
| **kABI**  | Pre-compiled modules for specific kernel versions           | CentOS/RHEL servers (stable kernels)  |

**This guide focuses on Akmod**, which is the recommended method for Fedora.

### 3.4 Special Repository: NVIDIA 580 LTS

For Maxwell, Pascal, and Volta GPUs, Negativo17 maintains a long-term support repository:

```bash
# Fedora
sudo wget https://negativo17.org/repos/fedora-nvidia-580.repo -P /etc/yum.repos.d/

# RHEL/CentOS
sudo wget https://negativo17.org/repos/epel-nvidia-580.repo -P /etc/yum.repos.d/
```

This repository will be maintained until approximately June 2028 (NVIDIA's EOL for the 580 branch).

---

## 4. NVIDIA Driver Installation Methods

### 4.1 Clean Installation (Recommended)

#### Step 1: Remove Existing NVIDIA Drivers

If you have previously installed NVIDIA drivers from RPMFusion or other sources, remove them:

```bash
sudo dnf remove '*nvidia*' --exclude=nvidia-gpu-firmware
sudo dnf autoremove
```

**Note:** We exclude `nvidia-gpu-firmware` because it's a firmware package that may be used by other drivers.

#### Step 2: Choose Your Repository

**Option A: NVIDIA Drivers Only**

```bash
sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-nvidia.repo
```

**Option B: NVIDIA Drivers + Multimedia Codecs (Recommended)**

```bash
sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-multimedia.repo
```

#### Step 3: Install Kernel Development Headers

Akmods requires kernel headers to build modules:

```bash
sudo dnf install kernel-devel kernel-headers
```

**Verify versions match:**

```bash
# Check running kernel
uname -r

# Check installed kernel-devel
rpm -q kernel-devel

# If mismatched, synchronize packages
sudo dnf distro-sync
```

#### Step 4: Install NVIDIA Driver Packages

**For Desktop/Workstation Use (with graphics):**

```bash
# Basic installation (Wayland + X11)
sudo dnf install nvidia-driver nvidia-settings

# Add 32-bit support for gaming/Wine/Steam
sudo dnf install nvidia-driver-libs.i686
```

**For Compute/CUDA Only (servers, headless systems):**

```bash
sudo dnf install nvidia-driver-cuda
```

**Additional packages (optional):**

```bash
# CUDA development toolkit
sudo dnf install cuda-devel

# NVENC support (hardware encoding for OBS, FFmpeg)
sudo dnf install nvenc

# NVIDIA Frame Buffer Capture (for Steam Remote Play, Moonlight)
sudo dnf install nvidia-driver-NvFBCOpenGL

# Vulkan support
sudo dnf install vulkan vulkan-tools

# VA-API for hardware video acceleration
sudo dnf install libva-nvidia-driver
```

#### Step 5: Wait for Module Build

During installation, akmods will automatically build the kernel modules. This takes **5-10 minutes** depending on your system.

**Monitor progress:**

```bash
journalctl --follow --grep=akmod
```

You'll see output like:

```
akmodsbuild: Building and installing nvidia-kmod
akmodsbuild: Building RPM using the command...
```

#### Step 6: Verify Module Build

**Before rebooting**, confirm the module was built successfully:

```bash
modinfo -F version nvidia
```

Expected output: A version number like `580.126.09`

If you get `modinfo: ERROR: Module nvidia not found`, **DO NOT REBOOT**. See [Section 8: Troubleshooting](#8-troubleshooting-and-common-issues).

#### Step 7: Reboot

```bash
sudo reboot
```

#### Step 8: Verify Installation

After rebooting, verify the driver is loaded:

```bash
nvidia-smi
```

Expected output:

```
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 580.126.09             Driver Version: 580.126.09     CUDA Version: 12.6     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA GeForce RTX 3070    Off     |   00000000:01:00.0  On |                  N/A |
| 30%   45C    P8             25W /  220W |     512MiB /   8192MiB |      2%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
```

**Installation complete!** 🎉

---

## 5. Switching Between Open and Proprietary Modules

Starting with driver version 545+, Negativo17's akmod and DKMS packages include **both** proprietary and open-source kernel module sources. You can switch between them using a configuration file.

### 5.1 Default Behavior

As of driver version **560+**, the default is:

| GPU Architecture       | Default Module Type                                |
| ---------------------- | -------------------------------------------------- |
| Turing and newer       | Open-source (`kernel-open`) - NVIDIA recommended   |
| Maxwell, Pascal, Volta | Proprietary (`kernel`) - Required (no GSP support) |
| Blackwell and newer    | Open-source (`kernel-open`) - **Mandatory**        |

### 5.2 Checking Current Module Type

```bash
modinfo nvidia | grep license
```

**Output interpretation:**

- `license: MIT/GPL` = Open-source modules
- `license: NVIDIA` = Proprietary modules

Alternative method:

```bash
cat /proc/driver/nvidia/version
```

Look for "Open Kernel Module" in the output.

### 5.3 Switching to Open Modules

⚠️ **WARNING:** Only do this if you have a **Turing or newer** GPU (RTX 20 series, RTX 30 series, RTX 40 series, or later). Maxwell, Pascal, and Volta GPUs are **not supported** by open modules.

```bash
# Edit the configuration file
sudo sed -i -e 's/kernel$/kernel-open/g' /etc/nvidia/kernel.conf

# Rebuild modules
sudo akmods --rebuild

# Verify the change
cat /etc/nvidia/kernel.conf
# Should show: kernel-open

# Reboot
sudo reboot
```

After reboot, verify:

```bash
modinfo nvidia | grep license
# Should show: license: MIT/GPL
```

### 5.4 Switching to Proprietary Modules

If you need to switch back to proprietary modules (e.g., for older GPUs or specific features):

```bash
# Edit the configuration file
sudo sed -i -e 's/kernel-open$/kernel/g' /etc/nvidia/kernel.conf

# Rebuild modules
sudo akmods --rebuild

# Verify the change
cat /etc/nvidia/kernel.conf
# Should show: kernel

# Reboot
sudo reboot
```

After reboot, verify:

```bash
modinfo nvidia | grep license
# Should show: license: NVIDIA
```

### 5.5 Feature Differences

While most features work with both module types, there are some differences:

**Open Module Limitations (as of driver 580):**

- Some G-SYNC features may not work on Turing GPUs
- Power management may differ slightly
- vGPU is not supported

**Proprietary Module Benefits:**

- Full feature support for all supported GPUs
- More mature codebase for Maxwell/Pascal/Volta
- Better tested for edge cases

For Turing and newer GPUs, **NVIDIA recommends open modules** as they will receive better ongoing support and new features.

---

## 6. Multimedia Codecs Installation

If you installed the `fedora-multimedia` repository, you already have access to comprehensive multimedia packages. This section covers additional useful packages.

### 6.1 GStreamer Plugins

For complete media playback support in GNOME and other GStreamer-based applications:

```bash
sudo dnf install gstreamer1-plugins-base \
                 gstreamer1-plugins-good \
                 gstreamer1-plugins-ugly \
                 gstreamer1-plugins-bad-free \
                 gstreamer1-plugins-bad-freeworld
```

These plugins enable playback of various formats in applications like:

- GNOME Videos (Totem)
- Rhythmbox
- Firefox web browser
- Most GTK-based media players

### 6.2 FFmpeg with NVIDIA Hardware Acceleration

The multimedia repository includes FFmpeg built with CUDA, NVENC, and NVDEC support:

```bash
sudo dnf install ffmpeg
```

**Verify NVIDIA support:**

```bash
ffmpeg -encoders | grep nvenc
```

Expected output:

```
 V..... h264_nvenc           NVIDIA NVENC H.264 encoder (codec h264)
 V..... hevc_nvenc           NVIDIA NVENC hevc encoder (codec hevc)
 V..... av1_nvenc            NVIDIA NVENC AV1 encoder (codec av1)
```

**Example usage:**

```bash
# Encode video with NVENC H.264
ffmpeg -i input.mp4 -c:v h264_nvenc -preset p7 -tune hq -rc vbr -cq 23 output.mp4

# Encode with AV1 (RTX 40 series and newer)
ffmpeg -i input.mp4 -c:v av1_nvenc -preset p7 -tune hq output.mp4
```

### 6.3 HandBrake and MakeMKV

For video transcoding and Blu-ray ripping:

```bash
# HandBrake with NVENC support
sudo dnf install handbrake

# MakeMKV for Blu-ray/DVD
sudo dnf install makemkv

# DVD CSS decryption library
sudo dnf install libdvdcss
```

### 6.4 Additional Multimedia Tools

```bash
# VLC media player
sudo dnf install vlc

# mpv player
sudo dnf install mpv

# Kdenlive video editor
sudo dnf install kdenlive

# Blender with CUDA support
sudo dnf install blender
```

### 6.5 NVIDIA-Specific Acceleration Libraries

```bash
# NVENC support for applications like OBS Studio
sudo dnf install nvenc

# NVIDIA Frame Buffer Capture (for Steam Remote Play, Parsec, Moonlight)
sudo dnf install nvidia-driver-NvFBCOpenGL

# VA-API support for NVIDIA (Firefox hardware acceleration)
sudo dnf install libva-nvidia-driver
```

**Testing VA-API:**

```bash
sudo dnf install libva-utils
vainfo
```

Expected output should show NVIDIA drivers providing VA-API support.

---

## 7. CachyOS Kernel Compatibility

⚠️ **CRITICAL COMPATIBILITY INFORMATION** ⚠️

### 7.1 Understanding the Compiler Mismatch Issue

CachyOS provides optimized kernels for Fedora through COPR repositories. However, there is a **critical compatibility concern** you must understand:

**The Problem:**

1. NVIDIA kernel modules **must be built with the same compiler** used to build the kernel
2. CachyOS provides two kernel variants:
   - `kernel-cachyos` - Built with **GCC**
   - `kernel-cachyos-lto` - Built with **Clang/LLVM** (ThinLTO optimizations)
3. Akmods uses **GCC by default** to build kernel modules
4. Forcing akmods to use Clang is **not officially supported** and often fails

**From NVIDIA's documentation:**

> "The kernel interface layers of the kernel modules must be built with the toolchain that was used to build the kernel."

**From CachyOS documentation:**

> "The default linux-cachyos kernel is compiled with GCC due to a bug at the NVIDIA Driver."

### 7.2 Recommended Approach ✅

**Use the standard CachyOS kernel (GCC-built), NOT the LTO variant:**

```bash
# Enable CachyOS GCC kernel repository
sudo dnf copr enable bieszczaders/kernel-cachyos

# Install kernel with matching development headers
sudo dnf install kernel-cachyos kernel-cachyos-devel-matched

# Remove stock Fedora kernel (optional, but recommended to avoid confusion)
# Note: Keep at least one Fedora kernel as backup!
# sudo dnf remove kernel kernel-core kernel-modules

# Rebuild NVIDIA modules for the new kernel
sudo akmods --rebuild

# Verify module was built
modinfo -F version nvidia

# Reboot into CachyOS kernel
sudo reboot
```

**After reboot, verify you're running CachyOS kernel:**

```bash
uname -r
# Should show something like: 6.13.1-cachyos-1.fc41.x86_64
```

**Benefits of kernel-cachyos (GCC):**

- ✅ Full NVIDIA driver compatibility with akmods
- ✅ Optimized for x86-64-v3 instruction set
- ✅ BORE scheduler for improved responsiveness
- ✅ CachyOS patches and optimizations
- ✅ Reliable, tested, and supported

### 7.3 CachyOS LTO Kernel (NOT Recommended) ❌

**⚠️ WARNING:** The following approach is **experimental**, **unsupported**, and **likely to fail**. NVIDIA drivers have historically had issues with Clang compilation, and akmods is not designed to use Clang by default.

The `kernel-cachyos-lto` repository provides kernels built with Clang/LLVM ThinLTO optimizations. While this offers theoretical performance benefits, it creates severe compatibility problems with NVIDIA drivers.

**Known Issues:**

1. ❌ Akmods may ignore `CC=clang` environment variable
2. ❌ Compilation often fails with "compiler version mismatch" errors
3. ❌ Even if compilation succeeds, modules frequently fail to load at runtime
4. ❌ System may freeze or black screen during first boot after rebuild
5. ❌ No official support from either NVIDIA, Negativo17, or CachyOS for this configuration

**If you still want to attempt this (against our recommendation):**

```bash
# Enable CachyOS LTO kernel repository
sudo dnf copr enable bieszczaders/kernel-cachyos-lto

# Install LTO kernel
sudo dnf install kernel-cachyos-lto kernel-cachyos-lto-devel-matched

# Attempt to force Clang (THIS USUALLY DOESN'T WORK)
export CC=clang
export CXX=clang++
sudo akmods --rebuild

# If it even builds (unlikely), reboot at your own risk
sudo reboot
```

**Expected result:** Build failure or non-functional driver. You'll need to boot into a working kernel and remove the LTO kernel.

### 7.4 CachyOS Precompiled NVIDIA Modules

CachyOS does provide their own **precompiled NVIDIA kernel modules** for their kernels on Arch Linux. However, for Fedora COPR repositories, these precompiled modules are **not consistently available** or maintained.

**Why precompiled modules aren't the solution for Fedora:**

- CachyOS COPR for Fedora focuses primarily on the kernel itself
- NVIDIA module packaging is complex and version-dependent
- Conflicts with Negativo17's akmod packaging approach
- Updates may lag behind kernel or driver releases

### 7.5 Summary and Recommendations

| Kernel Option                  | Compiler        | NVIDIA Akmod Support | Recommended                                   |
| ------------------------------ | --------------- | -------------------- | --------------------------------------------- |
| **Fedora stock kernel**        | GCC             | ✅ Full support      | ✅ **Yes** (most stable)                      |
| **kernel-cachyos (GCC)**       | GCC             | ✅ Full support      | ✅ **Yes** (best performance + compatibility) |
| **kernel-cachyos-lto (Clang)** | Clang (ThinLTO) | ❌ Incompatible      | ❌ **No**                                     |

**Final Recommendation:**

For users who want optimized kernel performance while maintaining full NVIDIA driver compatibility:

1. ✅ Use `kernel-cachyos` (GCC-built variant)
2. ✅ Install from `bieszczaders/kernel-cachyos` COPR
3. ✅ Use Negativo17 NVIDIA drivers with akmods as documented in this guide
4. ✅ Keep one Fedora stock kernel as backup

This gives you ~90% of the performance benefits of CachyOS optimizations while maintaining 100% NVIDIA driver compatibility.

---

## 8. Troubleshooting and Common Issues

### 8.1 Module Build Failed

**Symptom:** `modinfo nvidia` returns "Module nvidia not found" or akmod build fails

**Solutions:**

**1. Ensure kernel and kernel-devel versions match:**

```bash
# Check running kernel
uname -r

# Check all installed kernels and kernel-devel
rpm -qa | grep '^kernel'

# If versions mismatch, synchronize
sudo dnf distro-sync
```

**2. Force rebuild:**

```bash
sudo akmods --force
```

**3. Check build logs for specific errors:**

```bash
journalctl -b | grep akmod
```

or

```bash
ls -lh /var/cache/akmods/nvidia/
cat /var/cache/akmods/nvidia/*.log
```

**4. Common build errors:**

**Error: "No such file or directory: /lib/modules/X.X.X/build"**

```bash
# Kernel headers not installed or symlink broken
sudo dnf reinstall kernel-devel-$(uname -r)
```

**Error: "gcc: command not found"**

```bash
sudo dnf install gcc make
```

**Error: Compiler version mismatch**

```bash
# Usually happens with custom kernels built with Clang
# Solution: Use a GCC-built kernel
```

### 8.2 Secure Boot Issues

**Symptom:** "Module nvidia not found" even after successful build, or kernel refuses to load unsigned modules

**Check if Secure Boot is enabled:**

```bash
mokutil --sb-state
```

**Option 1: Disable Secure Boot (Easiest)**

1. Reboot and enter BIOS/UEFI settings (usually DEL, F2, or F12 during boot)
2. Find Secure Boot settings (usually under Security or Boot menu)
3. Disable Secure Boot and save changes

**Option 2: Sign Kernel Modules (Advanced)**

If you want to keep Secure Boot enabled:

```bash
# Import the akmod signing key
sudo mokutil --import /etc/pki/akmods/certs/public_key.der

# You'll be prompted to create a password - remember it!
# This password is temporary and only for this enrollment

# Reboot - you'll see a blue MOK Management screen
# Select: Enroll MOK → Continue → Yes → Enter the password you just created → Reboot
```

After reboot, the nvidia modules should load with Secure Boot enabled.

### 8.3 Black Screen After Installation

**Symptom:** System boots but displays only a black screen

**Solutions:**

**1. Boot into an older kernel from GRUB menu**

At boot, press ESC or hold SHIFT to show GRUB menu, then select an older working kernel.

**2. Access TTY console**

Press `Ctrl+Alt+F3` to access a text console and login.

**3. Check if you accidentally installed open modules on an unsupported GPU:**

```bash
cat /etc/nvidia/kernel.conf

# If it shows 'kernel-open' but you have Maxwell/Pascal/Volta GPU:
sudo sed -i -e 's/kernel-open$/kernel/g' /etc/nvidia/kernel.conf
sudo akmods --rebuild
sudo reboot
```

**4. For Fedora 36+ with simpledrm conflicts:**

```bash
# Add kernel parameter to blacklist simpledrm
sudo grubby --update-kernel=ALL --args='initcall_blacklist=simpledrm_platform_driver_init'
sudo reboot
```

**5. Rebuild initramfs:**

```bash
sudo dracut --force
sudo reboot
```

### 8.4 'NVIDIA kernel module missing' Error

**Symptom:** Boot message states "NVIDIA kernel module missing. Falling back to nouveau"

**Solutions:**

**1. Check if module built successfully:**

```bash
modinfo nvidia
```

If this fails, the module wasn't built. Run:

```bash
sudo akmods --force
journalctl -b | grep akmod
```

**2. If module builds but won't load:**

This is usually a Secure Boot issue. See [Section 8.2](#82-secure-boot-issues).

**3. Rebuild initramfs:**

```bash
sudo dracut --force
sudo reboot
```

**4. Blacklist nouveau explicitly:**

Although this should be automatic, you can manually ensure nouveau is blacklisted:

```bash
# Check current blacklist
cat /etc/modprobe.d/blacklist-nvidia-nouveau.conf

# Should contain:
# blacklist nouveau
# options nouveau modeset=0

# If missing, create it:
echo "blacklist nouveau" | sudo tee /etc/modprobe.d/blacklist-nvidia-nouveau.conf
echo "options nouveau modeset=0" | sudo tee -a /etc/modprobe.d/blacklist-nvidia-nouveau.conf

# Rebuild initramfs
sudo dracut --force
sudo reboot
```

### 8.5 Wayland Session Not Working

**Symptom:** Wayland session crashes, artifacts, or poor performance

**Solutions:**

**1. Ensure you're on driver 545+:**

```bash
nvidia-smi | head -3
```

Wayland support significantly improved in driver 545 and later.

**2. Enable DRM kernel mode setting:**

```bash
# Check if already enabled
cat /etc/modprobe.d/nvidia.conf

# Should contain:
# options nvidia-drm modeset=1

# If missing:
echo "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf
sudo dracut --force
sudo reboot
```

**3. For GNOME, ensure GDM uses Wayland:**

```bash
# Edit GDM config
sudo nano /etc/gdm/custom.conf

# Ensure this line is commented out or removed:
# WaylandEnable=false

# Save and reboot
```

**4. Enable required services:**

```bash
sudo systemctl enable nvidia-suspend.service
sudo systemctl enable nvidia-hibernate.service
sudo systemctl enable nvidia-resume.service
```

### 8.6 Performance Issues or Throttling

**Symptom:** GPU performing below expected levels

**Solutions:**

**1. Check power management mode:**

```bash
nvidia-smi -q -d PERFORMANCE
```

**2. Set maximum performance mode (persistent):**

```bash
# Install nvidia-persistenced
sudo dnf install nvidia-persistenced

# Enable it
sudo systemctl enable nvidia-persistenced
sudo systemctl start nvidia-persistenced

# Set performance mode
sudo nvidia-smi -pm 1

# Set maximum power limit (example: 300W - adjust for your GPU)
sudo nvidia-smi -pl 300
```

**3. For laptops, ensure you're using the NVIDIA GPU:**

```bash
# Check which GPU is being used
glxinfo | grep "OpenGL renderer"

# For Optimus laptops, you may need to configure prime-select
# See NVIDIA Prime configuration for Optimus setups
```

### 8.7 CUDA Applications Not Working

**Symptom:** CUDA applications fail to run or don't detect GPU

**Solutions:**

**1. Ensure CUDA libraries are installed:**

```bash
sudo dnf install cuda-devel
```

**2. Check CUDA version compatibility:**

```bash
nvidia-smi
# Look at "CUDA Version" - this is the maximum supported version

nvcc --version
# This should show an installed CUDA toolkit version ≤ driver's max version
```

**3. Add CUDA to your PATH:**

```bash
# Add to ~/.bashrc or ~/.bash_profile
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
```

### 8.8 Steam/Gaming Issues

**Symptom:** Games crash, poor performance, or won't launch

**Solutions:**

**1. Install 32-bit libraries:**

```bash
sudo dnf install nvidia-driver-libs.i686
```

**2. For Proton/Wine games:**

```bash
# Install additional Vulkan support
sudo dnf install vulkan vulkan-tools
sudo dnf install mesa-vulkan-drivers.i686

# Install 32-bit Vulkan for NVIDIA
sudo dnf install vulkan.i686
```

**3. Set Steam launch options:**

For NVIDIA GPU explicitly:

```
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia %command%
```

### 8.9 Driver Update Issues

**Symptom:** System breaks after NVIDIA driver update

**Prevention:**

**1. Don't reboot immediately after updates:**

Wait for akmods to finish building modules (5-10 minutes):

```bash
# Check if akmods is still running
systemctl status akmods

# Or monitor logs
journalctl -f -u akmods
```

**2. Always keep a working kernel:**

```bash
# See how many kernels you keep
sudo nano /etc/dnf/dnf.conf

# Ensure this line is present:
installonly_limit=3

# This keeps the last 3 kernels
```

**3. After update, verify before rebooting:**

```bash
# Check if new module was built for latest kernel
modinfo -k $(rpm -q --last kernel | head -1 | cut -d' ' -f1 | sed 's/kernel-//') nvidia

# Should show version info, not an error
```

---

## 9. Additional Resources

### 9.1 Official Documentation

- **Negativo17 Main Site:** https://negativo17.org/
- **NVIDIA Driver Page:** https://negativo17.org/nvidia-driver/
- **Multimedia Repository:** https://negativo17.org/multimedia/
- **GitHub (NVIDIA driver):** https://github.com/negativo17/nvidia-driver
- **CachyOS Kernel (Fedora):** https://github.com/CachyOS/copr-linux-cachyos

### 9.2 NVIDIA Official Resources

- **Open Kernel Modules:** https://github.com/NVIDIA/open-gpu-kernel-modules
- **Linux Driver Downloads:** https://www.nvidia.com/en-us/drivers/unix/
- **NVIDIA Developer Forums:** https://forums.developer.nvidia.com/c/gpu-graphics/linux/148
- **CUDA Toolkit Documentation:** https://docs.nvidia.com/cuda/
- **Open Kernel Modules Documentation:** https://download.nvidia.com/XFree86/Linux-x86_64/580.105.08/README/kernel_open.html

### 9.3 Community Support

- **Fedora Discussion:** https://discussion.fedoraproject.org/
- **Fedora Reddit:** https://reddit.com/r/Fedora
- **CachyOS Discord:** Join for kernel-specific support
- **NVIDIA Linux Community:** https://forums.developer.nvidia.com/

### 9.4 Quick Command Reference

```bash
# Check driver version
nvidia-smi

# Check module type (open vs proprietary)
modinfo nvidia | grep license

# Rebuild akmod modules
sudo akmods --rebuild

# Force rebuild with verbose output
sudo akmods --force

# Monitor akmod build progress
journalctl --follow --grep=akmod

# Check current kernel config
cat /etc/nvidia/kernel.conf

# Rebuild initramfs
sudo dracut --force

# List installed kernels
rpm -qa | grep '^kernel'

# Check running kernel
uname -r

# Check Secure Boot status
mokutil --sb-state

# Enable NVIDIA persistence daemon
sudo systemctl enable nvidia-persistenced

# Set maximum performance mode
sudo nvidia-smi -pm 1

# Monitor GPU in real-time
watch -n 1 nvidia-smi
```

---

## Appendix A: Comparison with RPMFusion

For users coming from RPMFusion, here are the key differences:

| Aspect               | RPMFusion                                | Negativo17                    |
| -------------------- | ---------------------------------------- | ----------------------------- |
| **Package naming**   | `akmod-nvidia`                           | `nvidia-driver`               |
| **32-bit libs**      | Separate `xorg-x11-drv-nvidia-libs.i686` | `nvidia-driver-libs.i686`     |
| **CUDA**             | In main package                          | Separate `nvidia-driver-cuda` |
| **Wayland-only**     | Must install full stack                  | Can skip X11 components       |
| **Repository setup** | Needs both free + nonfree                | Single repo                   |
| **Multimedia**       | Separate setup                           | Integrated option             |
| **Driver versions**  | Latest + legacy branches                 | Latest + 580 LTS branch       |

**Migration from RPMFusion to Negativo17:**

```bash
# 1. Remove RPMFusion drivers
sudo dnf remove '*nvidia*' --exclude=nvidia-gpu-firmware
sudo dnf autoremove

# 2. Disable RPMFusion NVIDIA repos (optional)
sudo dnf config-manager --set-disabled rpmfusion-nonfree-nvidia-driver

# 3. Add Negativo17 repo
sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-multimedia.repo

# 4. Install Negativo17 drivers
sudo dnf install nvidia-driver nvidia-driver-libs.i686 nvidia-settings

# 5. Reboot
sudo reboot
```

---

## Appendix B: GPU Architecture Quick Reference

| Architecture     | Example GPUs                         | Release Year | Open Modules    | Proprietary Modules | Notes              |
| ---------------- | ------------------------------------ | ------------ | --------------- | ------------------- | ------------------ |
| **Maxwell**      | GTX 950, 960, 970, 980               | 2014-2015    | ❌ No           | ✅ Yes (580 LTS)    | Use 580 LTS branch |
| **Pascal**       | GTX 1050, 1060, 1070, 1080           | 2016-2017    | ❌ No           | ✅ Yes (580 LTS)    | Use 580 LTS branch |
| **Volta**        | TITAN V, Quadro GV100                | 2017         | ❌ No           | ✅ Yes (580 LTS)    | Rare architecture  |
| **Turing**       | RTX 2060, 2070, 2080, GTX 1650, 1660 | 2018-2019    | ✅ Yes          | ✅ Yes              | Open recommended   |
| **Ampere**       | RTX 3060, 3070, 3080, 3090           | 2020-2021    | ✅ Yes          | ✅ Yes              | Open recommended   |
| **Ada Lovelace** | RTX 4060, 4070, 4080, 4090           | 2022-2023    | ✅ Yes          | ✅ Yes              | Open recommended   |
| **Hopper**       | H100, H200                           | 2022-2023    | ✅ Yes          | ✅ Yes              | Data center        |
| **Blackwell**    | B100, B200                           | 2024+        | ✅ **Required** | ❌ No               | Open only          |

---

## Appendix C: Environment Variables for Gaming

Useful environment variables for gaming with NVIDIA on Linux:

```bash
# Force NVIDIA GPU on Optimus laptops
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia

# Enable threaded optimization (may improve performance)
__GL_THREADED_OPTIMIZATION=1

# Disable GPU power management (max performance)
__GL_SYNC_TO_VBLANK=0

# Force full composition pipeline (reduce tearing, may impact latency)
nvidia-settings --assign CurrentMetaMode="nvidia-auto-select +0+0 { ForceFullCompositionPipeline = On }"

# Enable NVIDIA shader disk cache
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_PATH=/tmp/nvidia-shader-cache

# Example Steam launch options for a game:
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __GL_THREADED_OPTIMIZATION=1 %command%
```

---

## Appendix D: CachyOS Kernel Features

For reference, here are the optimizations in CachyOS kernels:

**Standard kernel-cachyos (GCC):**

- **Scheduler:** BORE (Burst-Oriented Response Enhancer)
- **Architecture:** Optimized for x86-64-v3
- **Patches:** CachyOS Cachy Sauce, latency improvements, futex optimizations
- **Features:** sched-ext support, AMD P-State improvements
- **Compiler:** GCC with `-O3` optimization

**LTO variant kernel-cachyos-lto (Clang):**

- **Everything from standard +**
- **Compiler:** Clang with ThinLTO
- **Optimization:** Link-time optimization across kernel
- **Trade-off:** ~5-10% performance gain, NVIDIA incompatibility

**Recommended for NVIDIA users:** Standard `kernel-cachyos` (GCC)

---

## Appendix E: Quick Start Cheat Sheet

**Complete installation in 6 commands:**

```bash
# 1. Add repository
sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-multimedia.repo

# 2. Install headers
sudo dnf install kernel-devel kernel-headers

# 3. Install drivers
sudo dnf install nvidia-driver nvidia-driver-libs.i686 nvidia-settings

# 4. Wait for build (5-10 min), then verify
modinfo -F version nvidia

# 5. Reboot
sudo reboot

# 6. Verify
nvidia-smi
```

**With CachyOS kernel:**

```bash
# Enable CachyOS repo
sudo dnf copr enable bieszczaders/kernel-cachyos

# Install CachyOS kernel
sudo dnf install kernel-cachyos kernel-cachyos-devel-matched

# Add Negativo17 repo
sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-multimedia.repo

# Install NVIDIA
sudo dnf install nvidia-driver nvidia-driver-libs.i686 nvidia-settings

# Rebuild for CachyOS kernel
sudo akmods --rebuild

# Verify and reboot
modinfo -F version nvidia && sudo reboot
```

---

[Question:] Should not the nvidia modules be built against the cachyos non-lto kernels?
