#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# env.sh  –  Wayland / toolkit environment variables for scroll
#
# SOURCE THIS IN YOUR ~/.bash_profile (or ~/.zprofile etc.) like so:
#
#   [[ -f ~/.config/scroll/env.sh ]] && source ~/.config/scroll/env.sh
#
# scroll does NOT support 'env =' directives in its config file.
# These variables MUST be present in the environment BEFORE scroll starts.
# ══════════════════════════════════════════════════════════════════════════════

# ── Wayland session identity ──────────────────────────────────────────────────
# Mirrors:  env.conf → XDG_SESSION_TYPE, XDG_SESSION_DESKTOP, XDG_CURRENT_DESKTOP
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=scroll
export XDG_CURRENT_DESKTOP=scroll

# ── Toolkit Wayland backends ──────────────────────────────────────────────────
# Mirrors:  env.conf → GDK_BACKEND, QT_QPA_PLATFORM, SDL_VIDEODRIVER, CLUTTER_BACKEND
export GDK_BACKEND="wayland,x11,*"
export QT_QPA_PLATFORM="wayland;xcb"
export SDL_VIDEODRIVER=wayland
export CLUTTER_BACKEND=wayland

# ── Qt theming & scaling ──────────────────────────────────────────────────────
# Mirrors:  env.conf → QT_AUTO_SCREEN_SCALE_FACTOR, QT_WAYLAND_DISABLE_WINDOWDECORATION,
#           QT_QPA_PLATFORMTHEME, QT_QPA_PLATFORMTHEME_QT6
export QT_AUTO_SCREEN_SCALE_FACTOR=1
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export QT_QPA_PLATFORMTHEME=qt5ct
# qt6ct is set via the qt6 theme variable
export QT_QPA_PLATFORMTHEME_QT6=qt6ct
# Fix font rendering on QWebEngineView 6 (qutebrowser, goldendict etc.)
export QT_SCALE_FACTOR_ROUNDING_POLICY=RoundPreferFloor

# ── NVIDIA ────────────────────────────────────────────────────────────────────
# Mirrors:  env.conf → GBM_BACKEND, __GLX_VENDOR_LIBRARY_NAME, LIBVA_DRIVER_NAME
# NOTE: scroll bundles its own wlroots and does NOT need --unsupported-gpu
# for NVIDIA, but these driver hints are still required for correct rendering.
export GBM_BACKEND=nvidia-drm
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export LIBVA_DRIVER_NAME=nvidia

# ── Electron ──────────────────────────────────────────────────────────────────
# Mirrors:  env.conf → ELECTRON_OZONE_PLATFORM_HINT
export ELECTRON_OZONE_PLATFORM_HINT=wayland

# ── Cursor theme ──────────────────────────────────────────────────────────────
# Mirrors:  env.conf → XCURSOR_THEME, XCURSOR_SIZE
# (HYPRCURSOR_* is Hyprland-specific and not used in scroll)
export XCURSOR_THEME=Bibata-Modern-Ice
export XCURSOR_SIZE=20

# ── Vulkan renderer (optional – better performance, HDR support) ──────────────
# Uncomment to use the Vulkan backend instead of gles2:
# export WLR_RENDERER=vulkan
