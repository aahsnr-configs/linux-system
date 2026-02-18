# Testing Guide for Hyprland Autostart with Systemd Service

## The Problem & Solution

**Problem**: Hyprland's `exec-once` runs scripts as your user without a TTY, so `sudo` commands won't work even with NOPASSWD configured.

**Solution**: Use a systemd **system service** (runs as root) for privileged operations, and keep user-level services in the Hyprland autostart script.

## Architecture

```
Boot Process
    ↓
Systemd starts
    ↓
asus-performance.service runs (as root)
    ├─ Writes PPT values to sysfs
    └─ Runs ryzenadj
    ↓
User logs in
    ↓
Hyprland starts
    ↓
hyprland-autostart.sh runs (as user)
    ├─ Environment setup
    └─ Start user services (udiskie, wl-paste, etc.)
```

## Installation Steps

### 1. Install the performance setup script

```bash
# Copy script to system location
sudo cp asus-performance-setup.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/asus-performance-setup.sh
```

### 2. Install the systemd service

```bash
# Copy service file
sudo cp asus-performance.service /etc/systemd/system/

# Reload systemd to recognize new service
sudo systemctl daemon-reload

# Enable service to run on boot
sudo systemctl enable asus-performance.service
```

### 3. Install the Hyprland autostart script

```bash
# Copy to your Hyprland scripts directory
mkdir -p ~/.config/hypr/scripts
cp hyprland-autostart.sh ~/.config/hypr/scripts/
chmod +x ~/.config/hypr/scripts/hyprland-autostart.sh
```

### 4. Add to Hyprland config

In `~/.config/hypr/hyprland.conf`:

```
exec-once = ~/.config/hypr/scripts/hyprland-autostart.sh
```

## Testing the Systemd Service

### Test the performance script manually (as root)

```bash
# Run as root to test
sudo /usr/local/bin/asus-performance-setup.sh

# Check if PPT values were set
cat /sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl1_spl/current_value
cat /sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl2_sppt/current_value

# Check ryzenadj settings
sudo ryzenadj --info | grep -E "STAPM|PPT|TCTL"
```

### Test the systemd service

```bash
# Start the service manually
sudo systemctl start asus-performance.service

# Check service status
sudo systemctl status asus-performance.service

# Should show "active (exited)" with exit code 0

# Check service logs
sudo journalctl -u asus-performance.service -n 50

# Verify settings applied
cat /sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl1_spl/current_value
sudo ryzenadj --info
```

### Test autostart on boot

```bash
# Reboot system
sudo reboot

# After reboot, check if service ran
sudo systemctl status asus-performance.service

# Verify performance settings
cat /sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl1_spl/current_value
sudo ryzenadj --info
```

## Testing the Hyprland Autostart Script

### Test manually (as your user)

```bash
# Run the script
~/.config/hypr/scripts/hyprland-autostart.sh

# Check if services started
ps aux | grep -E "udiskie|wl-paste|pypr"

# Check systemd user services
systemctl --user status hyprpolkitagent
systemctl --user status noctalia
```

### Test in Hyprland

```bash
# Reload Hyprland (doesn't re-run exec-once)
hyprctl reload

# Or log out and log back in to test exec-once

# After login, verify processes
ps aux | grep -E "udiskie|wl-paste|pypr"

# Check clipboard works
echo "test" | wl-copy
cliphist list
```

## Troubleshooting

### Service fails to start

```bash
# Check detailed logs
sudo journalctl -u asus-performance.service -xe

# Check if paths exist
ls -la /sys/class/firmware-attributes/asus-armoury/attributes/

# Verify kernel version (need 6.19+)
uname -r

# Check ASUS driver loaded
lsmod | grep asus
```

### PPT values not applying

```bash
# Test writing manually as root
sudo bash -c 'echo 34 > /sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl1_spl/current_value'

# Check if value was written
cat /sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl1_spl/current_value

# If this fails, driver may not be loaded or kernel too old
```

### ryzenadj not found

```bash
# Install ryzenadj
paru -S ryzenadj
# or
yay -S ryzenadj

# Verify installation
which ryzenadj
ryzenadj --help
```

### User services not starting

```bash
# Check if binaries exist
which udiskie wl-paste cliphist pypr hyprpm

# Run Hyprland autostart script with debug
bash -x ~/.config/hypr/scripts/hyprland-autostart.sh

# Check Hyprland logs
cat ~/.cache/hyprland/hyprland.log | grep exec-once
```

### Service won't start at boot

```bash
# Check if enabled
sudo systemctl is-enabled asus-performance.service
# Should output: enabled

# If not enabled
sudo systemctl enable asus-performance.service

# Check service dependencies
sudo systemctl list-dependencies asus-performance.service
```

## Verification Checklist

- [ ] `asus-performance-setup.sh` in `/usr/local/bin/` and executable
- [ ] `asus-performance.service` in `/etc/systemd/system/`
- [ ] Service enabled: `sudo systemctl is-enabled asus-performance.service`
- [ ] Service runs on boot and shows "active (exited)"
- [ ] PPT values correct after boot
- [ ] ryzenadj settings apply correctly
- [ ] `hyprland-autostart.sh` in `~/.config/hypr/scripts/` and executable
- [ ] `exec-once` line in `~/.config/hypr/hyprland.conf`
- [ ] All user processes start after Hyprland login
- [ ] No sudo/password prompts appear

## Why This Works

**Systemd system service**:
- Runs as root (no sudo needed)
- Starts early in boot process
- Handles privileged operations (sysfs writes, ryzenadj)
- Type=oneshot means it runs once and exits
- RemainAfterExit=yes keeps it marked as "active"

**Hyprland autostart script**:
- Runs as your user via exec-once
- No TTY required
- Handles user-level services only
- No privileged operations = no sudo needed

## Advantages Over Sudo Approach

1. **No sudo in non-TTY context** - Avoids the fundamental issue
2. **Proper separation** - Root operations vs user operations
3. **Standard systemd** - Uses Linux best practices
4. **Better logging** - `journalctl` for service logs
5. **More reliable** - Service dependencies handled by systemd
6. **Easier debugging** - Can test service independently
