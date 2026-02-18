# Comprehensive Guide: Fan & Clock Control on ASUS ROG Zephyrus G14 GA401QE

## For Wayland/Hyprland - Linux (CachyOS)

**Last Updated:** February 2026

---

## Table of Contents

1. [Introduction](#introduction)
2. [System Overview](#system-overview)
3. [Laptop Fan Control](#1-laptop-fan-control)
4. [NVIDIA GPU Fan Control (Wayland-Compatible)](#2-nvidia-gpu-fan-control-wayland-compatible)
5. [AMD Radeon iGPU Fan Control](#3-amd-radeon-igpu-fan-control)
6. [CPU Frequency/Clock Control](#4-cpu-frequencyclock-control)
7. [GPU Clock/Frequency Control](#5-gpu-clockfrequency-control)
8. [TDP/Power Limit Control (RyzenAdj)](#6-tdppower-limit-control-ryzenadj)
9. [Automation & Persistence](#7-automation--persistence)
10. [Monitoring Tools](#8-monitoring-tools)
11. [Troubleshooting](#9-troubleshooting)
12. [Safety Guidelines](#10-safety-guidelines)
13. [Quick Reference](#11-quick-reference)

---

## Introduction

This guide provides methods to control fan speeds and clock frequencies on the **ASUS ROG Zephyrus G14 GA401QE** running **Wayland/Hyprland** without using asus-linux.org packages (asusctl/supergfxctl).

### **Critical Note for Wayland Users**

Traditional X11-based tools like `nvidia-settings` with Coolbits **do not work** on Wayland for fan control. This guide focuses on Wayland-compatible alternatives.

---

## System Overview

Based on your fastfetch output:

| Component          | Specification                               |
| ------------------ | ------------------------------------------- |
| **CPU**            | AMD Ryzen 7 5800HS (8 cores @ 4.46 GHz)     |
| **GPU 1 (dGPU)**   | NVIDIA GeForce RTX 3050 Ti Mobile           |
| **GPU 2 (iGPU)**   | AMD Radeon Vega Series / Radeon Vega Mobile |
| **OS**             | CachyOS x86_64 (Linux 6.18.9-3-cachyos)     |
| **Display Server** | Wayland (Hyprland)                          |
| **Memory**         | 16 GiB (15.02 GiB usable)                   |

---

## 1. Laptop Fan Control

### Method 1.1: NBFC (NoteBook FanControl) - Recommended

NBFC is a cross-platform fan control service for notebooks that writes directly to the Embedded Controller (EC).

#### Installation

```bash
# Clone repository
git clone https://github.com/nbfc-linux/nbfc-linux.git
cd nbfc-linux

# Build and install
make
sudo make install
```

#### Configuration

```bash
# Find recommended configuration
nbfc config --recommend

# Try ASUS Zephyrus configurations
sudo nbfc config --set "Asus Zephyrus G14"
# Or try G15 if G14 doesn't work
sudo nbfc config --set "Asus Zephyrus G15"

# Test in read-only mode first (very important!)
sudo nbfc start -r

# Monitor status
nbfc status

# Check fan speed and temperatures
watch -n 1 nbfc status
```

#### If Configuration Works

```bash
# Restart in write mode
sudo nbfc restart

# Enable auto mode
nbfc set --auto

# Enable systemd service for automatic startup
sudo systemctl enable nbfc_service
sudo systemctl start nbfc_service
```

#### Manual Fan Control

```bash
# Set specific fan speed (0-100%)
nbfc set --fan-speed 50

# Return to auto mode
nbfc set --auto
```

#### Temperature Source Configuration

```bash
# Configure which temperature sensor NBFC uses
# Find available sensors first
find /sys/class/hwmon -name "temp*_input"

# Set temperature source (example)
sudo nbfc sensors set -f 0 -s /sys/class/hwmon/hwmon4/temp1_input
```

---

### Method 1.2: asus-nb-wmi Kernel Module (Basic Control)

The `asus-nb-wmi` module provides basic fan control but typically only controls one fan.

#### Check Module Status

```bash
lsmod | grep asus
```

#### Find Fan Control Files

```bash
find /sys/devices/platform/asus-nb-wmi -name "pwm*"
```

#### Manual Fan Control

```bash
# Enable manual mode (1 = manual, 2 = auto)
echo 1 | sudo tee /sys/devices/platform/asus-nb-wmi/hwmon/hwmon*/pwm1_enable

# Set fan speed (0-255, where 255 = 100%)
echo 128 | sudo tee /sys/devices/platform/asus-nb-wmi/hwmon/hwmon*/pwm1  # 50%
echo 192 | sudo tee /sys/devices/platform/asus-nb-wmi/hwmon/hwmon*/pwm1  # 75%

# Return to automatic control
echo 2 | sudo tee /sys/devices/platform/asus-nb-wmi/hwmon/hwmon*/pwm1_enable
```

#### Fan Boost Mode (if available)

```bash
# Check current fan boost mode
cat /sys/devices/platform/asus-nb-wmi/fan_boost_mode

# Modes: 0 = Normal, 1 = Performance, 2 = Silent
echo 1 | sudo tee /sys/devices/platform/asus-nb-wmi/fan_boost_mode
```

---

## 2. NVIDIA GPU Fan Control (Wayland-Compatible)

Traditional `nvidia-settings` with Coolbits **does not work on Wayland**. Here are Wayland-compatible alternatives:

### Method 2.1: NVFD (NVIDIA Fan Daemon) - RECOMMENDED for Wayland

**NVFD** uses the NVML API directly and works on X11, Wayland, and headless systems without requiring `nvidia-settings` or Coolbits.

#### Installation

```bash
# Install from AUR (for Arch-based systems like CachyOS)
yay -S nvfd
# Or
paru -S nvfd

# Alternatively, build from source
git clone https://github.com/Infinirc/nvfd.git
cd nvfd
cargo build --release
sudo cp target/release/nvfd /usr/local/bin/
```

#### Usage

```bash
# Launch interactive TUI dashboard
nvfd

# Run as daemon in background
nvfd daemon

# Set custom fan curve
nvfd curve
```

The TUI provides:

- Real-time GPU monitoring
- Interactive fan curve editor with mouse support
- Temperature tracking
- Automatic fan control

#### Create Systemd Service

```bash
# Create service file
sudo tee /etc/systemd/system/nvfd.service << 'EOF'
[Unit]
Description=NVIDIA Fan Control Daemon
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/nvfd daemon
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl enable nvfd
sudo systemctl start nvfd
```

---

### Method 2.2: nvidia-settings (Wayland Workaround)

While `nvidia-settings` is X11-focused, it can work on Wayland if you run it within your user session (not as root systemd service).

#### Setup

```bash
# Create wrapper script
sudo tee /usr/local/bin/nvidia-fan-wayland.sh << 'EOF'
#!/bin/bash

# Enable manual fan control
nvidia-settings -a "[gpu:0]/GPUFanControlState=1"

while true; do
    TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader)

    if [ $TEMP -le 40 ]; then
        FAN_SPEED=30
    elif [ $TEMP -le 50 ]; then
        FAN_SPEED=40
    elif [ $TEMP -le 60 ]; then
        FAN_SPEED=50
    elif [ $TEMP -le 70 ]; then
        FAN_SPEED=65
    elif [ $TEMP -le 80 ]; then
        FAN_SPEED=80
    else
        FAN_SPEED=100
    fi

    nvidia-settings -a "[fan:0]/GPUTargetFanSpeed=$FAN_SPEED" > /dev/null 2>&1
    sleep 3
done
EOF

sudo chmod +x /usr/local/bin/nvidia-fan-wayland.sh
```

#### Run in User Session (Hyprland)

Add to your Hyprland config (`~/.config/hypr/hyprland.conf`):

```
exec-once = /usr/local/bin/nvidia-fan-wayland.sh
```

---

### Method 2.3: Power Limit Control (Alternative to Fan Control)

Instead of controlling fans, limit GPU power consumption:

```bash
# Check current power limit
nvidia-smi -q -d POWER

# Set power limit (example: 60W - adjust for your needs)
sudo nvidia-smi -pl 60

# To make persistent, add to systemd service (see Section 7)
```

---

## 3. AMD Radeon iGPU Fan Control

The AMD Radeon integrated GPU uses the AMDGPU driver with sysfs hwmon interface.

### Method 3.1: Direct sysfs Control

```bash
# Find GPU hwmon path
ls /sys/class/drm/card*/device/hwmon/

# Check current temperature (output in millidegrees Celsius)
cat /sys/class/drm/card0/device/hwmon/hwmon*/temp1_input

# Enable manual fan control
echo 1 | sudo tee /sys/class/drm/card0/device/hwmon/hwmon*/pwm1_enable

# Set fan speed (0-255, where 255 = 100%)
echo 128 | sudo tee /sys/class/drm/card0/device/hwmon/hwmon*/pwm1  # 50%

# Return to automatic control
echo 2 | sudo tee /sys/class/drm/card0/device/hwmon/hwmon*/pwm1_enable
```

### Method 3.2: amdgpu-fan (Automated Fan Curve)

```bash
# Install
pip install amdgpu-fan --break-system-packages

# Create configuration file
sudo tee /etc/amdgpu-fan.yml << 'EOF'
speed_matrix:
- [0, 0]
- [30, 33]
- [45, 50]
- [60, 66]
- [65, 69]
- [70, 75]
- [75, 89]
- [80, 100]

temp_drop: 4
EOF

# Start and enable service
sudo systemctl start amdgpu-fan
sudo systemctl enable amdgpu-fan
```

---

## 4. CPU Frequency/Clock Control

### Method 4.1: Enable amd_pstate Driver (HIGHLY RECOMMENDED)

The `amd_pstate` driver provides better power efficiency and performance for Ryzen processors. **As of Linux 6.5+, this is the recommended driver for Zen 2+ CPUs.**

#### Check Current Driver

```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver
```

#### Enable amd_pstate EPP (Active Mode)

For Ryzen mobile processors (like your 5800HS), you may need to enable it manually:

```bash
# Edit GRUB configuration
sudo nano /etc/default/grub

# Add to GRUB_CMDLINE_LINUX_DEFAULT:
# amd_pstate=active

# Example line:
# GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_pstate=active"

# Update GRUB
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Reboot
sudo reboot
```

#### Verify After Reboot

```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver
# Should output: amd-pstate-epp
```

---

### Method 4.2: Control CPU Frequency with cpupower

```bash
# Install cpupower
sudo pacman -S cpupower

# Check current status
cpupower frequency-info

# Available energy performance preferences (EPP)
cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_available_preferences
# Outputs: default performance balance_performance balance_power power

# Set EPP preference
echo "balance_power" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
```

#### Traditional Governor Control (if using acpi-cpufreq)

```bash
# View available governors
cpupower frequency-info -g

# Set governor
sudo cpupower frequency-set -g schedutil  # Balanced (recommended)
sudo cpupower frequency-set -g performance  # Maximum performance
sudo cpupower frequency-set -g powersave  # Power saving

# Set frequency limits
sudo cpupower frequency-set --max 3.5GHz
sudo cpupower frequency-set --min 1.4GHz
```

#### CPU Boost Control

```bash
# Disable CPU boost (reduces max frequency, saves power)
echo 0 | sudo tee /sys/devices/system/cpu/cpufreq/boost

# Enable CPU boost
echo 1 | sudo tee /sys/devices/system/cpu/cpufreq/boost
```

---

## 5. GPU Clock/Frequency Control

### 5.1 NVIDIA GPU Clock Control

#### View Current Clocks

```bash
nvidia-smi -q -d CLOCK
```

#### Set Power Limit (Wayland-Compatible)

```bash
# Check power limit range
nvidia-smi -q -d POWER

# Set power limit (adjust based on your needs)
sudo nvidia-smi -pl 60  # Set to 60W

# Lower power = lower clocks = cooler, quieter operation
```

#### Clock Offset (Requires Coolbits - X11 Only)

⚠️ **Not available on Wayland** - requires X11 with Coolbits enabled

---

### 5.2 AMD Radeon GPU Performance Control

```bash
# View current GPU frequency
cat /sys/class/drm/card0/device/pp_dpm_sclk

# Set performance level
echo "high" | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level
# Options: auto, low, high, manual

# For manual control, set specific power state
# First check available states
cat /sys/class/drm/card0/device/pp_dpm_sclk

# Set to specific state (example: state 2)
echo "2" | sudo tee /sys/class/drm/card0/device/pp_dpm_sclk
```

---

## 6. TDP/Power Limit Control (RyzenAdj)

**RyzenAdj** allows adjusting power management settings for AMD Ryzen mobile processors.

### Installation

```bash
# Install dependencies
sudo pacman -S base-devel cmake git pciutils

# Clone and build
git clone https://github.com/FlyGoat/RyzenAdj.git
cd RyzenAdj
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make

# Install
sudo make install
# Or manually copy
sudo cp ryzenadj /usr/local/bin/
```

### Install ryzen_smu Module (Required)

```bash
git clone https://github.com/amkillam/ryzen_smu
cd ryzen_smu
sudo make dkms-install
```

### Usage

```bash
# Check current settings
sudo ryzenadj -i

# Set TDP limits (values in milliwatts)
# Example: 35W sustained, 40W burst
sudo ryzenadj --stapm-limit=35000 --fast-limit=40000 --slow-limit=35000 --tctl-temp=85
```

### Power Limit Parameters

| Parameter       | Description                               |
| --------------- | ----------------------------------------- |
| `--stapm-limit` | Sustained Power Limit (long-term average) |
| `--fast-limit`  | Actual Power Limit (short bursts)         |
| `--slow-limit`  | Average Power Limit                       |
| `--tctl-temp`   | Temperature limit (°C)                    |

### Example Configurations

```bash
# Battery saving (25W)
sudo ryzenadj --stapm-limit=25000 --fast-limit=25000 --slow-limit=25000

# Balanced (35W)
sudo ryzenadj --stapm-limit=35000 --fast-limit=40000 --slow-limit=35000

# Performance (54W)
sudo ryzenadj --stapm-limit=54000 --fast-limit=80000 --slow-limit=54000
```

---

## 7. Automation & Persistence

Most settings reset on reboot. Here's how to make them persistent.

### Method 7.1: Systemd Service

Create `/etc/systemd/system/power-tweaks.service`:

```ini
[Unit]
Description=Power and Performance Tweaks
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/power-tweaks.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Create `/usr/local/bin/power-tweaks.sh`:

```bash
#!/bin/bash

# AMD P-State EPP preference
echo "balance_power" > /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference

# TDP Limits (adjust as needed)
ryzenadj --stapm-limit=35000 --fast-limit=40000 --slow-limit=35000

# AMD GPU Performance
echo "auto" > /sys/class/drm/card0/device/power_dpm_force_performance_level

# NVIDIA Power Limit (if using dGPU)
nvidia-smi -pl 60
```

Make executable and enable:

```bash
sudo chmod +x /usr/local/bin/power-tweaks.sh
sudo systemctl enable power-tweaks.service
sudo systemctl start power-tweaks.service
```

---

### Method 7.2: cpupower Configuration

Edit `/etc/default/cpupower`:

```bash
# For traditional governors (if not using amd_pstate EPP)
governor='schedutil'
max_freq='3.5GHz'
min_freq='1.4GHz'
```

Enable service:

```bash
sudo systemctl enable cpupower.service
```

---

### Method 7.3: Hyprland Auto-start

Add to `~/.config/hypr/hyprland.conf`:

```
# NVIDIA fan control (if using nvidia-settings method)
exec-once = /usr/local/bin/nvidia-fan-wayland.sh

# Or NVFD daemon
exec-once = nvfd daemon
```

---

## 8. Monitoring Tools

### lm-sensors (CPU/System Temperatures)

```bash
# Install
sudo pacman -S lm_sensors

# Detect sensors (run once)
sudo sensors-detect

# View temperatures
sensors

# Continuous monitoring
watch -n 1 sensors
```

### NVIDIA GPU Monitoring

```bash
# Basic info
nvidia-smi

# Continuous monitoring
watch -n 1 nvidia-smi

# Detailed query
nvidia-smi -q
```

### CPU Frequency Monitoring

```bash
# Current frequencies
grep MHz /proc/cpuinfo

# Continuous monitoring
watch -n 1 'grep MHz /proc/cpuinfo'
```

### GUI Tools

- **htop** - Interactive process viewer with temperature display
- **nvtop** - GPU process monitoring (supports NVIDIA and AMD)
- **zenmonitor** - AMD Ryzen monitoring GUI
- **psensor** - Graphical temperature monitor

```bash
sudo pacman -S htop nvtop zenmonitor psensor
```

---

## 9. Troubleshooting

### NBFC Not Detecting Fans

- Try different Zephyrus G14/G15 configurations
- Use read-only mode first: `sudo nbfc start -r`
- Check NBFC logs: `journalctl -u nbfc_service -f`
- Ensure EC probe is working: `sudo nbfc status`

### NVFD Not Working

```bash
# Check if nvidia driver is loaded
lsmod | grep nvidia

# Ensure nvidia-utils is installed
sudo pacman -S nvidia-utils

# Check NVML access
nvidia-smi
```

### AMD P-State Not Loading

```bash
# Verify CPPC support
lscpu | grep -i cppc

# For desktop Ryzen (shared memory), you may need:
# Add to kernel parameters: amd_pstate=active amd_pstate.shared_mem=1

# Check BIOS settings - enable CPPC if available
```

### RyzenAdj Fails to Apply Settings

```bash
# Check if ryzen_smu module is loaded
lsmod | grep ryzen_smu

# Load manually if needed
sudo modprobe ryzen_smu

# Check permissions
ls -l /dev/cpu/*/msr

# For iomem errors on some kernels, add kernel parameter:
# iomem=relaxed
```

### CPU Not Scaling Down

```bash
# Check what's preventing frequency scaling
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq

# Ensure no conflicting power management tools
systemctl list-units | grep -E 'tlp|laptop-mode'
```

---

## 10. Safety Guidelines

### Critical Safety Rules

✅ **DO:**

- Monitor temperatures constantly when testing new configurations
- Start with conservative settings and gradually adjust
- Keep laptop on hard, flat surfaces for proper airflow
- Test under load (gaming, stress tests) before trusting config
- Keep BIOS at default as backup option

❌ **DON'T:**

- Never disable fans completely unless system is idle and cool
- Don't set overly aggressive TDP limits that cause throttling
- Don't ignore temperature warnings (>95°C CPU, >85°C GPU)
- Don't make multiple changes at once (isolate variables)

### Safe Temperature Ranges

| Component                | Safe Range | Warning | Critical |
| ------------------------ | ---------- | ------- | -------- |
| **CPU (Ryzen 7 5800HS)** | <80°C      | 80-90°C | >90°C    |
| **GPU (RTX 3050 Ti)**    | <75°C      | 75-83°C | >83°C    |
| **GPU (AMD Vega)**       | <75°C      | 75-85°C | >85°C    |

### Monitoring During Testing

```bash
# Monitor everything in real-time
watch -n 1 'sensors && nvidia-smi && grep MHz /proc/cpuinfo | head -n 4'

# Stress test CPU
stress -c 8 -t 300  # 5 minutes

# Monitor during stress
htop
```

---

## 11. Quick Reference

### Essential Commands

| Control            | Tool       | Command                                                                                               |
| ------------------ | ---------- | ----------------------------------------------------------------------------------------------------- |
| **Laptop Fans**    | NBFC       | `nbfc set --auto`                                                                                     |
| **NVIDIA GPU Fan** | NVFD       | `nvfd daemon`                                                                                         |
| **AMD GPU Fan**    | sysfs      | `echo 2 \| sudo tee /sys/class/drm/card0/device/hwmon/hwmon*/pwm1_enable`                             |
| **CPU EPP**        | sysfs      | `echo "balance_power" \| sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference` |
| **CPU TDP**        | RyzenAdj   | `sudo ryzenadj --stapm-limit=35000`                                                                   |
| **NVIDIA Power**   | nvidia-smi | `sudo nvidia-smi -pl 60`                                                                              |
| **Monitor All**    | Various    | `watch -n 1 'sensors && nvidia-smi'`                                                                  |

### File Locations

```
# AMD CPU EPP preferences
/sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference

# NVIDIA GPU temperature
nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader

# AMD iGPU temperature
/sys/class/drm/card0/device/hwmon/hwmon*/temp1_input

# CPU boost control
/sys/devices/system/cpu/cpufreq/boost
```

---

## Conclusion

This guide provides Wayland/Hyprland-compatible methods to control fan speeds and system performance on your ASUS ROG Zephyrus G14 without asus-linux.org packages.

**Recommended Setup:**

- **Fans:** NBFC for laptop fans, NVFD for NVIDIA GPU
- **CPU:** Enable `amd_pstate=active` and use EPP preferences
- **Power:** RyzenAdj for TDP, nvidia-smi for GPU power limits

Start conservatively, monitor temperatures, and adjust based on your workload and noise tolerance.

---

**For the latest updates and community support:**

- ArchWiki: https://wiki.archlinux.org/
- asus-linux FAQ: https://asus-linux.org/faq/
- NBFC GitHub: https://github.com/nbfc-linux/nbfc-linux
- NVFD GitHub: https://github.com/Infinirc/nvfd
- RyzenAdj GitHub: https://github.com/FlyGoat/RyzenAdj

**Document Version:** 1.0 (February 2026)
