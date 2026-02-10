# Complete NVIDIA Driver Installation Guide for Fedora Linux

## Using Negativo17 Repository with CachyOS Kernel

**Last Updated:** February 2026  
**For:** Fedora 41, 42+

---

## ❓ Do I Need RPMFusion if Using Negativo17?

**NO! Negativo17 and RPMFusion are NOT compatible.**

- They **conflict with each other** and cannot be installed together
- Negativo17 packages are marked with `Conflicts` against RPMFusion packages
- The multimedia repository from Negativo17 **includes all NVIDIA drivers** plus codecs
- **Choose ONE:** Either use Negativo17 OR RPMFusion, never both

**If you have RPMFusion installed, you must remove it first** (see Step 1 below).

---

## 🎯 Complete Installation Guide

### Step 1: Remove Any Existing NVIDIA Drivers

```bash
# Remove RPMFusion or any other NVIDIA packages
sudo dnf remove '*nvidia*' --exclude=nvidia-gpu-firmware

# Clean up orphaned packages
sudo dnf autoremove

# If you have RPMFusion enabled, disable the NVIDIA driver repo
sudo dnf config-manager --set-disabled rpmfusion-nonfree-nvidia-driver
```

### Step 2: Install CachyOS Kernel (Recommended for Performance)

**⚠️ CRITICAL: Use the GCC variant, NOT the LTO variant!**

```bash
# Enable CachyOS GCC kernel repository
sudo dnf copr enable bieszczaders/kernel-cachyos

# Install CachyOS kernel with matching development headers
sudo dnf install kernel-cachyos kernel-cachyos-devel-matched
```

**Why GCC and not LTO?**

- The LTO kernel is built with **Clang compiler**
- NVIDIA drivers build with **GCC** via akmods
- Compiler mismatch = driver won't work
- CachyOS themselves state: _"The default linux-cachyos kernel is compiled with GCC due to a bug at the NVIDIA Driver"_

### Step 3: Add Negativo17 Multimedia Repository

**This single repository includes NVIDIA drivers + multimedia codecs:**

```bash
sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-multimedia.repo
```

### Step 4: Install Kernel Development Tools

```bash
# Required for akmod to build kernel modules
sudo dnf install kernel-devel kernel-headers gcc make
```

### Step 5: Install NVIDIA Drivers and All Components

**Complete installation (recommended for most users):**

```bash
# Core driver packages
sudo dnf install nvidia-driver \
                 nvidia-driver-libs \
                 nvidia-driver-libs.i686 \
                 nvidia-settings

# CUDA support (for machine learning, rendering, compute tasks)
sudo dnf install nvidia-driver-cuda \
                 cuda-devel

# Hardware encoding/decoding
sudo dnf install nvenc \
                 nvidia-driver-NvFBCOpenGL

# Vulkan support (for gaming)
sudo dnf install vulkan \
                 vulkan-tools

# VA-API for Firefox and other apps
sudo dnf install libva-nvidia-driver

# Persistence daemon (for servers/workstations)
sudo dnf install nvidia-persistenced
```

**For gaming-focused systems, add:**

```bash
# Mesa Vulkan (for compatibility)
sudo dnf install mesa-vulkan-drivers.i686
```

**Minimal installation (drivers only, no extras):**

```bash
sudo dnf install nvidia-driver nvidia-settings
```

### Step 6: Install Multimedia Codecs

**Complete multimedia package installation:**

```bash
# GStreamer plugins (for GNOME Videos, Rhythmbox, etc.)
sudo dnf install gstreamer1-plugins-base \
                 gstreamer1-plugins-good \
                 gstreamer1-plugins-ugly \
                 gstreamer1-plugins-bad-free \
                 gstreamer1-plugins-bad-freeworld

# FFmpeg with NVIDIA NVENC/NVDEC support
sudo dnf install ffmpeg

# HandBrake for video transcoding
sudo dnf install handbrake

# MakeMKV for Blu-ray ripping
sudo dnf install makemkv libdvdcss

# VLC media player
sudo dnf install vlc

# mpv player
sudo dnf install mpv
```

### Step 7: Wait for Akmod Build

**This is critical - DO NOT skip this step!**

```bash
# Monitor the build process (takes 5-10 minutes)
journalctl --follow --grep=akmod
```

Wait until you see messages like:

```
akmodsbuild: Building and installing nvidia-kmod
akmodsbuild: Finished
```

### Step 8: Verify Module Build Success

**Before rebooting, verify the module was built:**

```bash
modinfo -F version nvidia
```

**Expected output:** A version number like `580.126.09`

**If you get an error:** DO NOT REBOOT. See troubleshooting section below.

### Step 9: Reboot

```bash
sudo reboot
```

### Step 10: Verify Installation

**After reboot, check that everything works:**

```bash
# Check driver is loaded
nvidia-smi

# Check module type (open vs proprietary)
modinfo nvidia | grep license

# Check which kernel you're running
uname -r
```

**Expected nvidia-smi output:**

```
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 580.126.09             Driver Version: 580.126.09     CUDA Version: 12.6     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
...
```

**You're done!** 🎉

---

## 🔧 Switching Between Open and Proprietary Modules

**Check current module type:**

```bash
modinfo nvidia | grep license
```

- `license: MIT/GPL` = Open-source modules
- `license: NVIDIA` = Proprietary modules

### Switch to Open Modules (Turing and newer GPUs only)

**⚠️ WARNING:** Only for RTX 20/30/40 series or newer!

```bash
sudo sed -i -e 's/kernel$/kernel-open/g' /etc/nvidia/kernel.conf
sudo akmods --rebuild
sudo reboot
```

### Switch to Proprietary Modules

```bash
sudo sed -i -e 's/kernel-open$/kernel/g' /etc/nvidia/kernel.conf
sudo akmods --rebuild
sudo reboot
```

---

## 🐛 Troubleshooting

### Module Build Failed

**Symptom:** `modinfo nvidia` returns "Module nvidia not found"

**Solutions:**

1. **Check kernel and kernel-devel versions match:**

```bash
uname -r
rpm -q kernel-devel
```

2. **If mismatched, synchronize:**

```bash
sudo dnf distro-sync
```

3. **Force rebuild:**

```bash
sudo akmods --force
```

4. **Check build logs:**

```bash
journalctl -b | grep akmod
```

### Secure Boot Issues

**Symptom:** Module built successfully but won't load

**Check if Secure Boot is enabled:**

```bash
mokutil --sb-state
```

**Option 1: Disable Secure Boot in BIOS/UEFI** (Easiest)

**Option 2: Sign the modules:**

```bash
sudo mokutil --import /etc/pki/akmods/certs/public_key.der
# Follow on-screen prompts, create a password
# Reboot, select "Enroll MOK" in blue screen
# Enter password and reboot again
```

### Black Screen After Installation

**Solutions:**

1. **Boot into older kernel from GRUB menu**

2. **Access TTY console:** Press `Ctrl+Alt+F3`

3. **Check if wrong module type installed:**

```bash
cat /etc/nvidia/kernel.conf
# If it shows 'kernel-open' but you have older GPU (GTX 10 series, etc.):
sudo sed -i -e 's/kernel-open$/kernel/g' /etc/nvidia/kernel.conf
sudo akmods --rebuild
sudo reboot
```

4. **Add kernel parameter to fix conflicts:**

```bash
sudo grubby --update-kernel=ALL --args='initcall_blacklist=simpledrm_platform_driver_init'
sudo reboot
```

### NVIDIA Module Missing Error

**Symptom:** System boots but falls back to nouveau

**Solutions:**

1. **Rebuild modules:**

```bash
sudo akmods --force
```

2. **Rebuild initramfs:**

```bash
sudo dracut --force
sudo reboot
```

3. **Explicitly blacklist nouveau:**

```bash
echo "blacklist nouveau" | sudo tee /etc/modprobe.d/blacklist-nvidia-nouveau.conf
echo "options nouveau modeset=0" | sudo tee -a /etc/modprobe.d/blacklist-nvidia-nouveau.conf
sudo dracut --force
sudo reboot
```

### Wayland Not Working

**Solutions:**

1. **Enable DRM kernel mode setting:**

```bash
echo "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf
sudo dracut --force
sudo reboot
```

2. **Enable NVIDIA services:**

```bash
sudo systemctl enable nvidia-suspend.service
sudo systemctl enable nvidia-hibernate.service
sudo systemctl enable nvidia-resume.service
```

---

## 📦 Complete Package List Summary

### Essential Packages (Minimal Installation)

```bash
nvidia-driver                    # Main driver
nvidia-driver-libs              # 64-bit libraries
nvidia-driver-libs.i686         # 32-bit libraries (for gaming)
nvidia-settings                 # GUI configuration tool
```

### CUDA and Compute

```bash
nvidia-driver-cuda              # CUDA runtime support
cuda-devel                      # CUDA development toolkit
```

### Hardware Acceleration

```bash
nvenc                           # Hardware encoding (OBS, FFmpeg)
nvidia-driver-NvFBCOpenGL       # Frame buffer capture (streaming)
libva-nvidia-driver             # VA-API support (Firefox, etc.)
```

### Graphics and Gaming

```bash
vulkan                          # Vulkan runtime
vulkan-tools                    # Vulkan utilities
mesa-vulkan-drivers.i686        # 32-bit Vulkan for compatibility
```

### System Services

```bash
nvidia-persistenced             # Keep driver loaded (servers)
```

### Multimedia Codecs

```bash
gstreamer1-plugins-base
gstreamer1-plugins-good
gstreamer1-plugins-ugly
gstreamer1-plugins-bad-free
gstreamer1-plugins-bad-freeworld
ffmpeg                          # With NVENC/NVDEC support
handbrake                       # Video transcoding
makemkv                         # Blu-ray ripping
libdvdcss                       # DVD decryption
vlc                             # Media player
mpv                             # Media player
```

---

## 🚀 Quick Start Cheat Sheet

**Complete installation in one command block:**

```bash
# 1. Remove old drivers
sudo dnf remove '*nvidia*' --exclude=nvidia-gpu-firmware && sudo dnf autoremove

# 2. Install CachyOS kernel
sudo dnf copr enable bieszczaders/kernel-cachyos -y
sudo dnf install kernel-cachyos kernel-cachyos-devel-matched -y

# 3. Add Negativo17 repo
sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-multimedia.repo

# 4. Install kernel development tools
sudo dnf install kernel-devel kernel-headers gcc make -y

# 5. Install NVIDIA drivers and multimedia
sudo dnf install nvidia-driver nvidia-driver-libs nvidia-driver-libs.i686 nvidia-settings \
                 nvidia-driver-cuda cuda-devel nvenc nvidia-driver-NvFBCOpenGL \
                 libva-nvidia-driver vulkan vulkan-tools nvidia-persistenced \
                 gstreamer1-plugins-{base,good,ugly,bad-free,bad-freeworld} \
                 ffmpeg handbrake makemkv libdvdcss vlc mpv -y

# 6. Wait for akmod build (5-10 minutes)
journalctl --follow --grep=akmod
# Press Ctrl+C when you see "Finished"

# 7. Verify before reboot
modinfo -F version nvidia

# 8. Reboot
sudo reboot

# 9. After reboot, verify
nvidia-smi
```

---

## 📊 GPU Architecture Quick Reference

| GPU Series     | Architecture | Open Modules | Proprietary      | Recommendation       |
| -------------- | ------------ | ------------ | ---------------- | -------------------- |
| GTX 900 series | Maxwell      | ❌ No        | ✅ Yes (580 LTS) | Use 580 LTS repo     |
| GTX 10 series  | Pascal       | ❌ No        | ✅ Yes (580 LTS) | Use 580 LTS repo     |
| GTX 16 series  | Turing       | ✅ Yes       | ✅ Yes           | **Use open modules** |
| RTX 20 series  | Turing       | ✅ Yes       | ✅ Yes           | **Use open modules** |
| RTX 30 series  | Ampere       | ✅ Yes       | ✅ Yes           | **Use open modules** |
| RTX 40 series  | Ada Lovelace | ✅ Yes       | ✅ Yes           | **Use open modules** |

---

## 🔗 Important Links

- **Negativo17 Main Site:** https://negativo17.org/
- **NVIDIA Driver Page:** https://negativo17.org/nvidia-driver/
- **Multimedia Repository:** https://negativo17.org/multimedia/
- **CachyOS Kernel (Fedora COPR):** https://copr.fedorainfracloud.org/coprs/bieszczaders/kernel-cachyos/
- **NVIDIA Official Drivers:** https://www.nvidia.com/en-us/drivers/unix/
- **NVIDIA Open Modules:** https://github.com/NVIDIA/open-gpu-kernel-modules

---

## 📝 Quick Command Reference

```bash
# Check driver version
nvidia-smi

# Check module type
modinfo nvidia | grep license

# Rebuild akmods
sudo akmods --rebuild

# Force rebuild with verbose output
sudo akmods --force

# Monitor akmod build
journalctl --follow --grep=akmod

# Check current kernel
uname -r

# Check kernel config
cat /etc/nvidia/kernel.conf

# Rebuild initramfs
sudo dracut --force

# Check Secure Boot status
mokutil --sb-state

# Monitor GPU in real-time
watch -n 1 nvidia-smi
```

---

## ⚠️ Important Notes

1. **Never use both RPMFusion and Negativo17** - they conflict
2. **Always wait for akmod build to complete** before rebooting (5-10 minutes)
3. **Use kernel-cachyos (GCC), NOT kernel-cachyos-lto** for NVIDIA compatibility
4. **Keep at least one Fedora stock kernel** as a backup
5. **For Maxwell/Pascal/Volta GPUs** (GTX 900/1000 series), use the 580 LTS repository
6. **Verify module build before rebooting:** `modinfo -F version nvidia`
7. **Disable Secure Boot or sign modules** - unsigned modules won't load

---

## 🎓 What You Get

After following this guide, you'll have:

✅ Latest NVIDIA drivers from Negativo17  
✅ CachyOS optimized kernel for better performance  
✅ Full CUDA support for machine learning and compute  
✅ Hardware encoding/decoding (NVENC/NVDEC)  
✅ Vulkan support for gaming  
✅ Complete multimedia codec support  
✅ FFmpeg with NVIDIA acceleration  
✅ HandBrake, VLC, mpv, and other tools  
✅ Wayland support (driver 545+)  
✅ Automatic module rebuilding on kernel updates

**Your system will be fully optimized for NVIDIA graphics, gaming, content creation, and development!**

---

**END OF GUIDE**

_Created: February 2026_  
_Tested on: Fedora 41, 42_
