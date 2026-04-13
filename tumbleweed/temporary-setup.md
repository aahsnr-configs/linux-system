You're absolutely right on all points. Let me correct these:

---

## 🔧 **Corrected ZRAM Setup**

You only need to enable **`zram-generator.service`** - it handles everything automatically based on the config file.

**Corrected script:**

```bash
#!/bin/bash
# ZRAM Generator Setup Script for openSUSE Tumbleweed

set -e

echo "🔧 Setting up ZRAM swap..."

# Create ZRAM configuration
sudo tee /etc/systemd/zram-generator.conf > /dev/null << 'EOF'
[zram0]
compression-algorithm = zstd
zram-size = ram / 2
priority = 100
EOF

echo "✅ ZRAM configuration created at /etc/systemd/zram-generator.conf"

# Enable and start ZRAM generator (this is the ONLY service needed)
sudo systemctl daemon-reload
sudo systemctl enable --now zram-generator.service

# Verify ZRAM is active
echo ""
echo "📊 ZRAM Status:"
zramctl

echo ""
echo "✅ ZRAM setup complete!"
```

---

## 📍 **Correct XDG Portal Configuration Locations**

The **correct** locations are:

### **System-wide (Recommended):**
- `/etc/xdg/xdg-desktop-portal/hyprland-portals.conf`
- `/etc/xdg/xdg-desktop-portal/portals.conf`

### **User-specific (Alternative):**
- `~/.config/xdg/xdg-desktop-portal/hyprland-portals.conf`
- `~/.config/xdg/xdg-desktop-portal/portals.conf`

**System-wide is preferred** because it applies to all sessions and is loaded more reliably.

---

## 📝 **Corrected Portal Configuration Files**

### **1. Create `/etc/xdg/xdg-desktop-portal/hyprland-portals.conf`:**

```ini
[preferred]
default=hyprland
org.freedesktop.impl.portal.Secret=gnome-keyring
org.freedesktop.impl.portal.FileChooser=gtk
org.freedesktop.impl.portal.Notification=gtk
org.freedesktop.impl.portal.Screenshot=hyprland
org.freedesktop.impl.portal.ScreenCast=hyprland
org.freedesktop.impl.portal.InputCapture=hyprland
org.freedesktop.impl.portal.Background=hyprland
org.freedesktop.impl.portal.Access=gtk
org.freedesktop.impl.portal.Account=gtk
org.freedesktop.impl.portal.AppChooser=gtk
org.freedesktop.impl.portal.Call=gtk
org.freedesktop.impl.portal.Clock=gtk
org.freedesktop.impl.portal.Device=gtk
org.freedesktop.impl.portal.DynamicLauncher=gtk
org.freedesktop.impl.portal.Email=gtk
org.freedesktop.impl.portal.Inhibit=gtk
org.freedesktop.impl.portal.Location=gtk
org.freedesktop.impl.portal.MemoryMonitor=gtk
org.freedesktop.impl.portal.NetworkMonitor=gtk
org.freedesktop.impl.portal.OpenUri=gtk
org.freedesktop.impl.portal.Print=gtk
org.freedesktop.impl.portal.RemoteDesktop=hyprland
org.freedesktop.impl.portal.RequestCounter=gtk
org.freedesktop.impl.portal.Session=hyprland
org.freedesktop.impl.portal.Settings=gtk
org.freedesktop.impl.portal.Shortcut=hyprland
org.freedesktop.impl.portal.Trash=gtk
org.freedesktop.impl.portal.Wallpaper=gtk

[hyprland]
UseIn=hyprland
```

### **2. Create `/etc/xdg/xdg-desktop-portal/portals.conf`:**

```ini
[preferred]
default=hyprland
```

### **3. Create the directories if they don't exist:**

```bash
sudo mkdir -p /etc/xdg/xdg-desktop-portal
```

---

## 🔧 **Corrected Systemd Services**

```markdown
# System-Wide Services (Run with: sudo systemctl enable --now <service>)

acpid.service                    # ACPI event daemon
bluez.service                    # Bluetooth stack
bpftune.service                  # BPF-based system tuning
cronie.service                   # Cron daemon
fail2ban.service                 # Intrusion prevention
fwupd.service                    # Firmware updates
haveged.service                  # Entropy generator
logrotate.timer                  # Log rotation (timer)
podman.socket                    # Podman API socket (system-wide)
tuned.service                    # System tuning daemon
xdg-desktop-portal.service       # XDG Desktop Portal (SYSTEM service)
xdg-desktop-portal-hyprland.service  # Hyprland portal backend (SYSTEM service)
zram-generator.service           # ZRAM swap setup (ONLY this one needed)

# User Services (Run with: systemctl --user enable --now <service>)

gnome-keyring-daemon.service     # GNOME Keyring (secrets/passwords)
gnome-keyring-daemon.socket      # GNOME Keyring socket
pipewire.service                 # PipeWire audio server
pipewire.socket                  # PipeWire socket
pipewire-pulse.service           # PipeWire PulseAudio replacement
wireplumber.service              # PipeWire session manager

# User Services (Enable only, start on demand)

podman.socket                    # Podman user socket for rootless containers
```

---

## 📋 **Complete Setup Commands**

```bash
# System services
sudo systemctl enable --now acpid bluez bpftune cronie fail2ban fwupd haveged logrotate.timer tuned xdg-desktop-portal xdg-desktop-portal-hyprland zram-generator

# User services
systemctl --user enable --now gnome-keyring-daemon pipewire pipewire-pulse wireplumber

# Podman user socket
systemctl --user enable podman.socket
```

---

## ✅ **Verify Portal Configuration**

```bash
# Check if portal config is loaded
cat /etc/xdg/xdg-desktop-portal/hyprland-portals.conf

# Verify portal service status
systemctl status xdg-desktop-portal
systemctl status xdg-desktop-portal-hyprland

# Check which portal is active
ps aux | grep xdg-desktop-portal
```

---

**All corrections applied!** 🐧
