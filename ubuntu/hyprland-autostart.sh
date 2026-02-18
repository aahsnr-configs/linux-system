#!/bin/bash
# Hyprland Autostart Script - User Services Only
# Performance configuration handled by systemd service: asus-performance.service

# =============================================================================
# PART 1: ENVIRONMENT SETUP (must complete synchronously)
# =============================================================================

# Import environment for systemd user services
systemctl --user import-environment 2>/dev/null || true

# Update D-Bus activation environment if available
if hash dbus-update-activation-environment 2>/dev/null; then
    dbus-update-activation-environment --systemd 2>/dev/null || true
fi

# =============================================================================
# PART 2: USER SERVICES (background processes with &)
# =============================================================================

# Start polkit authentication agent
systemctl --user start hyprpolkitagent &

# Start automount daemon
udiskie &

# Start clipboard managers (continuous monitoring)
wl-paste --type text --watch cliphist store &
wl-paste --type image --watch cliphist store &

# Start user services
systemctl --user start noctalia &

# Reload Hyprland plugins
hyprpm reload -n &

# Start scratchpad manager
pypr &

# Uncomment if needed:
# rog-control-center &
