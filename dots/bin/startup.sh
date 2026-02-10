#!/bin/bash
# TODO: Either put it here or at the bottom
systemctl --user import-environment &
hash dbus-update-activation-environment 2>/dev/null &
dbus-update-activation-environment --systemd &
/usr/lib/hyprpolkitagent/hyprpolkitagent &
udiskie &
wl-paste --type text --watch cliphist store &
wl-paste --type image --watch cliphist store &
qs -c noctalia-shell &
/home/ahsan/.local/bin/pypr &
hyprpm reload -n &
