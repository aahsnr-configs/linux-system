#!/bin/bash
# 'set +e' ensures the script continues even if a single command fails
set +e

dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=wlroots >/dev/null 2>&1

/usr/libexec/xdg-desktop-portal-wlr >/dev/null 2>&1 &

mmsg -d disable_monitor,eDP-1

wl-clip-persist --clipboard regular --reconnect-tries 0 >/dev/null 2>&1 &

# cliphist watchers for both text and images
wl-paste --type text --watch cliphist store >/dev/null 2>&1 &
wl-paste --type image --watch cliphist store >/dev/null 2>&1 &

# Launch Noctalia-shell (Quickshell-based desktop environment)
qs -c noctalia-shell >/dev/null 2>&1 &

udiskie >/dev/null 2>&1 &

thunar --daemon >/dev/null 2>&1 &
rog-control-center >/dev/null 2>&1 &
emacs --daemon >/dev/null 2>&1 &
