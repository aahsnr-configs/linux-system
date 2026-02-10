#!/bin/bash
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=wlroots &
eval "$(dbus-launch --sh-syntax)" &

# Keep clipboard content after app closes
wl-clip-persist --clipboard regular --reconnect-tries 0 &

# Watch clipboard and store history
wl-paste --type text --watch cliphist store &

# fast launch on GTK/Qt apps
fc-cache -f &
gtk-update-icon-cache -q &

# udiskie
udiskie &
