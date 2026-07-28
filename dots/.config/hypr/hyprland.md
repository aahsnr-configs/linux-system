### 1. Main Entry Point: `hyprland.lua`

`/.config/hypr/hyprland.conf`

```conf
source = $HOME/.config/hypr/hyprland/autostart.conf
source = $HOME/.config/hypr/hyprland/env.conf
source = $HOME/.config/hypr/hyprland/settings.conf
source = $HOME/.config/hypr/hyprland/binds.conf
source = $HOME/.config/hypr/hyprland/monitor.conf
source = $HOME/.config/hypr/hyprland/rules.conf
source = $HOME/.config/hypr/hyprland/plugins.conf
source = $HOME/.config/hypr/hyprland/workspaces.conf
source = $HOME/.config/hypr/noctalia/noctalia-colors.conf
```

---

### 2. Environment Variables: `hyprland/env.conf`

`/.config/hypr/hyprland/env.conf`

```conf
#env = AQ_DRM_DEVICES,/dev/dri/card1:/dev/dri/card2
env = GDK_BACKEND,wayland,x11,*
env = QT_QPA_PLATFORM,wayland;xcb
env = SDL_VIDEODRIVER,wayland

## Clutter
env = CLUTTER_BACKEND,wayland

## Setting environment variables for wayland session
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_CURRENT_SESSION,Hyprland

env = QT_AUTO_SCREEN_SCALE_FACTOR,1
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = QT_QPA_PLATFORMTHEME,qt5ct
env = QT_QPA_PLATFORMTHEME_QT6,qt6ct

env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = __GL_VRR_ALLOWED,1


env = LIBVA_DRIVER_NAME,nvidia

env = ELECTRON_OZONE_PLATFORM_HINT,auto

env = HYPRCURSOR_THEME,Bibata-Modern-Ice
env = HYPRCURSOR_SIZE,20
env = XCURSOR_THEME,Bibata-Modern-Ice
env = XCURSOR_SIZE,20
```

---

### 3. Settings & Animations: `hyprland/settings.conf`

```conf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GENERAL
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

general {
    gaps_in = 4
    gaps_out = 7
    border_size = 3
    col.active_border = rgba(b8bb26ff) rgba(fabd2fff) 45deg
    col.inactive_border = rgba(3c3836cc) rgba(504945cc) 45deg
    layout = scroller
    resize_on_border = true

    snap {
        enabled = true
    }
}



# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DECORATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

decoration {
    rounding = 8
    rounding_power = 3
    active_opacity = 1.0
    inactive_opacity = 1.0
    fullscreen_opacity = 1
    dim_inactive = false

    shadow {
        enabled = true
        range = 2
        render_power = 1
        color = rgba(1a1a1aee)
    }

    blur {
        enabled = true
        size = 3
        passes = 2
        new_optimizations = true
        ignore_opacity = true
        xray = false
        special = true
        vibrancy = 0.1696
        popups = true
    }
}


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ANIMATIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

animations {
    enabled = true

    bezier = wind, 0.05, 0.9, 0.1, 1.05
    bezier = winIn, 0.1, 1.1, 0.1, 1.1
    bezier = winOut, 0.3, -0.3, 0, 1
    bezier = liner, 1, 1, 1, 1

    animation = windows, 1, 4, wind, popin
    animation = windowsIn, 1, 4, winIn, popin
    animation = windowsOut, 1, 4, winOut, popin
    animation = windowsMove, 1, 4, wind, slide
    animation = border, 1, 1, liner
    animation = borderangle, 1, 30, liner, once
    animation = fade, 1, 4, default
    animation = workspaces, 1, 5, wind, slidevert
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INPUT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

input {
    kb_layout = us
    kb_options = ctrl:nocaps
    follow_mouse = 1
    accel_profile = flat
    numlock_by_default = true

    touchpad {
        natural_scroll = true
    }
}

gesture = 3, horizontal, workspace


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAYOUTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

dwindle {
	preserve_split = true
	smart_split = true
	smart_resizing = true
}

master {
    new_status = master
}

scrolling {
    column_width             = 0.40
    follow_min_visible       = 0.33
    fullscreen_on_one_column = false
    focus_fit_method         = 1
    direction = right
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MISC
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

misc {
  vrr = 0
  disable_hyprland_logo = true
  force_default_wallpaper = 0
  middle_click_paste = false
  focus_on_activate = true
  session_lock_xray = true
  enable_swallow = true
  swallow_regex = ^(Alacritty|kitty|footclient)$
}

xwayland {
  force_zero_scaling = true
}

# debug {
#   watchdog_timeout = 0
# }
debug {
   disable_logs = false
   enable_stdout_logs = true
}
```

---

### 4. Monitors: `hyprland/monitor.conf`

```conf
monitorv2 {
    output = HDMI-A-1
    mode = 3840x2160@60
    position = 0x0
    scale = 2.0
    # bitdepth = 10
    # cm = auto
    # sdrbrightness = 1.0
    # sdrsaturation = 1.0
    # supports_hdr = true
    # supports_wide_color = true
    # sdr_min_luminance = 0.005
    # sdr_max_luminance = 250
    # min_luminance = 0
    # max_luminance = 1000
    # max_avg_luminance = 500
}

# render {
#     cm_auto_hdr = 2
# }

# monitorv2 {
#     output = eDP-1
#     mode = 2560x1440@60
#     position = 0x0
# scale = 1.33
# }
#
#env = ENABLE_HDR_WSI, 1
# monitor = eDP-1, disable
```

---

### 5. Plugins: `hyprland/plugins.conf`

```conf
# hy3 plugin (already present, extended)
plugin {
  hy3 {
    tabs {
      height = 22
      padding = 6
      render_text = false
      from_top = false
      radius = 6
      border_width = 2
      text_font = "Sans"
      text_height = 8
      text_padding = 3
    }
    autotile {
      enable = true
      trigger_width = 600
      trigger_height = 200
      workspaces = "all"
    }
    group_inset = 10
    node_collapse_policy = 2
    tab_first_window = false
  }

  # hyprscroller configuration
  scroller {
    column_default_width = 0.4
    focus_wrap = true
  }

  # hyprtrails – visual window trails (optional)
  trails {
    enabled = true
    trail_length = 8
    trail_opacity = 0.6
    trail_color = 0xffffffff
    trail_blend = "add"
  }
}
```

---

### 6. Window, Layer, and Workspace Rules: `hyprland/rules.conf`

```conf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WINDOW RULES (Hyprland 0.53+ syntax)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Ghostty - more transparency
windowrule {
    name = ghostty_opacity
    match:class = ^(com.mitchellh.ghostty)$
    opacity = 0.95 0.95
}

windowrule {
    name = kitty_floating
    match:class = ^(kitty-dropterm)$
    size = 70% 70%
    float = 1
    animation = slidein
}

windowrule {
    name = yazi_floating
    match:class = ^(explorer)$
    size = 90% 90%
    float = 1
    animation = slidein
}

windowrule {
    name = nautilus_floating
    match:class = ^(org\.gnome\.Nautilus)$
    float = true
    animation = popin
    size = 1000 800
}

windowrule {
    name = bleachbit_floating
    match:class = ^(org.bleachbit.BleachBit)$
    float = true
    animation = popin
    size = 600 600
    no_blur = on
    no_anim = on

}

windowrule {
    name = thunar_floating
    match:class = ^(thunar)$
    float = true
    animation = popin
    size = 800 600
}

windowrule {
    name = Thunar-Progress-bar
    match:class = ^(thunar)$
    match:title = ^(File Operation Progress)$
    float = on
    center = on
    move = (cursor_x-(window_w*0.05)) (cursor_y-(window_h*0.6))
    size = (monitor_w*0.26) (monitor_h*0.18)
}

windowrule {
    name = qt5ct_floating
    match:class = ^(qt5ct)$
    float = true
    center = 1
    size = 800 600
}

windowrule {
    name = qt6ct_floating
    match:class = ^(qt6ct)$
    float = true
    center = 1
    size = 800 600
}

windowrule {
    name = nwg_look
    match:class = ^(nwg-look)$
    float = on
    center = 1
    size = 600 400
}

windowrule {
    name = google_signin_popup
    match:class = ^(brave-browser)$
    match:title = ^(Untitled - Brave)$
    float = on
    size = 450 600
    move = (cursor_x-(window_w*0.5)) (cursor_y-(window_h*0.5))
    no_blur = on
    no_anim = on

}

windowrule {
    name = bitwarden_popup
    match:class = ^(brave-nngceckbapebfimnlniiiahkandclblb-Default)$
    match:title = ^(_crx_nngceckbapebfimnlniiiahkandclblb)$
    float = on
    size = 450 600
    move = (cursor_x-(window_w*0.5)) (cursor_y-(window_h*0.5))
    no_blur = on
    no_anim = on
}

windowrule {
    name = xdg_desktop_portal_gtk
    match:class = ^(xdg-desktop-portal-gtk)$
    size = 600 600
    float = on
    move = (cursor_x-(window_w*0.05)) (cursor_y-(window_h*0.6))
    #move = (cursor_x) (cursor_y-(window_h*0.5))
    no_blur = on
    #no_anim = on
}

# Center all floating windows (not xwayland cause popups)
windowrule = center true, match:float true, match:xwayland false

# Float
windowrule = float true, match:class org\.gnome\.FileRoller
windowrule = float true, match:class file-roller  # WHY IS THERE TWOOOOOOOOOOOOOOOO
windowrule = float true, match:class imv
windowrule = float true, match:class system-config-printer
windowrule = float true, match:class CachyOSHello

# Float, resize and center
windowrule = float true, match:class org\.pulseaudio\.pavucontrol|yad-icon-browser
windowrule = size 60% 70%, match:class org\.pulseaudio\.pavucontrol|yad-icon-browser
windowrule = center 1, match:class org\.pulseaudio\.pavucontrol|yad-icon-browser

# Dialogs
windowrule = float true, match:title (Select|Open)( a)? (File|Folder)(s)?
windowrule = float true, match:title File (Operation|Upload)( Progress)?
windowrule = float true, match:title .* Properties
windowrule = float true, match:title Export Image as PNG
windowrule = float true, match:title GIMP Crash Debug
windowrule = float true, match:title Save As
windowrule = float true, match:title Library

# TODO: Look at cachyos config for this
windowrule {
    name = Picture-in-Picture
    match:title = ^(Picture-in-Picture)$
    float = on
    move = 72% 7%
    opacity = 0.95 0.75
    pin = on
    keep_aspect_ratio = on
    size = (monitor_w*0.3) (monitor_h*0.3)
}

# Ugh xwayland popups
windowrule = no_dim true, match:xwayland 1, match:title win[0-9]+
windowrule = no_shadow true, match:xwayland 1, match:title win[0-9]+
windowrule = rounding 10, match:xwayland 1, match:title win[0-9]+

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAYER RULES (Hyprland 0.53+ syntax)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Noctalia Shell blur (docs.noctalia.dev)
layerrule {
    name = noctalia
    match:namespace = noctalia-background-.*$
    ignore_alpha = 0.5
    blur = true
    blur_popups = true
}

# Other blur layers
layerrule {
    name = blur_layers
    match:namespace = ^(rofi|notifications|quickshell:.*)$
    blur = true
    ignore_alpha = true
}

layerrule = match:namespace gtk4-layer-shell, no_anim on

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WORKSPACE RULES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
workspace = special:exposed,gapsout:60,gapsin:30,bordersize:5,border:true,shadow:false
#

```

---

### 7. Workspaces: `hyprland/workspaces.conf`

```conf
# Workspace layout assignments
workspace = 1, layout:scrolling
# workspace = 2, layout:scroller, gapsin:0, gapsout:0, monitor:HDMI-A-1
workspace = 2, layout:scrolling
workspace = 3, layout:scrolling
workspace = 4, layout:hy3
workspace = 5, layout:hy3
workspace = 6, layout:hy3
workspace = 7, layout:master
workspace = 8, layout:master
workspace = 9, layout:monocle


# Named workspaces (for launcher and quick access)
workspace = name:research, layout:scroller
workspace = name:dev, layout:hy3
workspace = name:comm, layout:master
workspace = name:stage, layout:scroller   # for nsticky stage

# Switch Workspaces (Super+1-9)
bind = Super, 1, workspace, 1
bind = Super, 2, workspace, 2
bind = Super, 3, workspace, 3
bind = Super, 4, workspace, 4
bind = Super, 5, workspace, 5
bind = Super, 6, workspace, 6
bind = Super, 7, workspace, 7
bind = Super, 8, workspace, 8
bind = Super, 9, workspace, 9

# Move Window to Workspace
bind = Super+Shift, 1, movetoworkspace, 1
bind = Super+Shift, 2, movetoworkspace, 2
bind = Super+Shift, 3, movetoworkspace, 3
bind = Super+Shift, 4, movetoworkspace, 4
bind = Super+Shift, 5, movetoworkspace, 5
bind = Super+Shift, 6, movetoworkspace, 6
bind = Super+Shift, 7, movetoworkspace, 7
bind = Super+Shift, 8, movetoworkspace, 8
bind = Super+Shift, 9, movetoworkspace, 9

# Relative switching
binde = Ctrl+Alt, down, workspace, +1
binde = Ctrl+Alt, up,  workspace, -1

bind = Super, bracketleft,        workspace, e-1
bind = Super, bracketright,       workspace, e+1
bind = Ctrl+Super+Alt, up,  movetoworkspace, -1
bind = Ctrl+Super+Alt, down, movetoworkspace, +1

# Named workspace bindings
# bind = Super, R, workspace, name:research
# bind = Super, D, workspace, name:dev
# bind = Super, C, workspace, name:comm
# bind = Super, H, workspace, name:stage
```

---

### 8. Keybindings & Submaps: `hyprland/binds.conf`

```conf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Keybindings
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


# Variables
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$terminal   = kitty
$browser    = brave-browser
$guifm      = nautilus
$editor     = emacsclient -c -a 'emacs'
$ipc        = qs -c noctalia-shell ipc call
$screenshot = ~/bin/screenshot
$pypr       = /usr/bin/pypr-client
$dispatch   = ~/bin/unified-dispatch.py

# ESSENTIALS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
bind = Super, D,            exec, $ipc launcher toggle
bind = Super, X,            exec, $ipc sessionMenu toggle
bind = Super, Return,       exec, $terminal
bind = Super+Shift, Return, exec, $pypr toggle term
bind = Super, Q,            killactive
bind = Super, Space,        togglefloating
bind = Super+Shift, Space,  fullscreen, 1
bind = Super, S,            togglespecialworkspace
bind = Super+Shift, R,      exec, hyprctl reload

# Focus cycling
# bind = Super, grave,      cyclenext
# bind = Super+Shift,   grave,      cyclenext, prev
#
# SCREENSHOT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
bind = Alt, Print,     exec, $screenshot --region
bind = Ctrl, Print,    exec, $screenshot --fullscreen
bind = Super+Shift, S, exec, $screenshot --region


# SCRATCHPADS SUBMAP  (Super+P → leader | PERSISTENT)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
bind = Super, P, submap, scratchpads

submap = scratchpads
bind  = , Escape, submap, reset

bind  = , C, exec, $pypr toggle calculator
bind  = , M, exec, $pypr toggle spotify
bind  = , Y, exec, $pypr toggle tuifm
bind  = , L, exec, $pypr toggle lazygit
bind  = , F, exec, $pypr toggle files

bindr = , catchall, submap, reset
submap = reset


# GUI APPLICATIONS SUBMAP  (Super+G → leader | PERSISTENT)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
bind = Super, G, submap, guiapps

submap = guiapps, reset
bind  = , Escape, submap, reset

bind  = , B, exec, $browser
bind  = , F, exec, $guifm
bind  = , E, exec, $editor

bindr = , catchall, submap, reset
submap = reset


# TUI APPLICATIONS SUBMAP  (Super+T → leader | PERSISTENT)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
bind = Super, T, submap, tuiapps

submap = tuiapps, reset
bind  = , Escape, submap, reset

bind  = , Y, exec, kitty -e yazi
bind  = , B, exec, kitty -e btop
bind  = , E, exec, kitty -e nvim

bindr = , catchall, submap, reset
submap = reset


# NOCTALIA LAUNCHERS SUBMAP  (Super+L → leader | PERSISTENT)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
bind = Super+Shift, L, submap, noctalia_launchers

submap = noctalia_launchers
bind  = , Escape,  submap, reset

bind  = , V,      exec, $ipc launcher clipboard
bind  = , W,      exec, $ipc launcher windows
bind  = , Period, exec, $ipc launcher command

bind  = SHIFT, Period, exec, $ipc launcher emoji

bindr = , catchall, submap, reset
submap = reset


# NOCTALIA CORE INTERFACE SUBMAP  (Super+N → leader | PERSISTENT)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
bind = Super, N, submap, noctalia_core

submap = noctalia_core
bind  = , Escape, submap, reset

bind  = , C,     exec, $ipc controlCenter toggle
bind  = , Comma, exec, $ipc settings toggle
bind  = , A,     exec, $ipc calendar toggle
bind  = , I,     exec, $ipc systemMonitor toggle
bind  = , P,     exec, $ipc plugin togglePanel notes-scratchpad

bindr = , catchall, submap, reset
submap = reset


# NOCTALIA MISC SUBMAP  (Super+M → leader | MIXED)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
bind = Super, M, submap, noctalia_misc

submap = noctalia_misc
bind  = , Escape, submap, reset

# Persistent — toggles you may want to reverse without re-invoking the leader
bind  = , I, exec, $ipc idleInhibitor toggle
bind  = , W, exec, $ipc wifi toggle
bind  = , B, exec, $ipc bluetooth toggle
bind  = , N, exec, $ipc nightLight toggle
bind  = , P, exec, $ipc powerProfile cycle

# One-shot — terminal/destructive actions with no meaningful follow-up
bind  = , K, exec, $ipc lockScreen lock
bind  = , K, submap, reset

bind  = , X, exec, $ipc sessionMenu lockAndSuspend
bind  = , X, submap, reset

bindr = , catchall, submap, reset
submap = reset


# PYPRLAND  (Hyprland-specific extras)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
bind = Super+Ctrl, B,  exec, $pypr expose
bind = Super, Z,       exec, $pypr zoom ++0.5
bind = Super+Shift, Z, exec, $pypr zoom


# HYPRLAND CORE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
bind = Super, BackSpace, pseudo
bind = Super, Slash, layoutmsg, togglesplit


# FOCUS & MOVEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Focus — routed through unified-dispatch
bind = Super, left,  exec, $dispatch focus l
bind = Super, right, exec, $dispatch focus r
bind = Super, up,    exec, $dispatch focus u
bind = Super, down,  exec, $dispatch focus d

# Move Window — routed through unified-dispatch
bind = Super+Shift, left,  exec, $dispatch movewin l
bind = Super+Shift, right, exec, $dispatch movewin r
bind = Super+Shift, up,    exec, $dispatch movewin u
bind = Super+Shift, down,  exec, $dispatch movewin d

# Resize Window — routed through unified-dispatch
binde = Super+Ctrl, left,  exec, $dispatch resize l
binde = Super+Ctrl, right, exec, $dispatch resize r
binde = Super+Ctrl, up,    exec, $dispatch resize u
binde = Super+Ctrl, down,  exec, $dispatch resize d


# MOUSE SCROLLING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
bind = Ctrl+Super, mouse_down, workspace, -10
bind = Ctrl+Super, mouse_up,   workspace, +10
bind = Super, mouse_down,      workspace, e+1
bind = Super, mouse_up,        workspace, e-1

# Move/resize with mouse
bindm = Super, mouse:272, movewindow
bindm = Super, mouse:273, resizewindow


# SPECIAL WORKSPACE & MINIMIZE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
bind = Super, minus,          movetoworkspace,      special:minimized # mangowc: minimized
bind = Super, equal,          togglespecialworkspace, minimized        # mangowc: restore_minimized
bind = Ctrl+Super+Alt, up,    movetoworkspace,      special:special
bind = Ctrl+Super+Alt, down,  movetoworkspace,      e+0
bind = Super+Alt, S,          movetoworkspace,      special:special


# AUDIO & BRIGHTNESS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
bindel = , XF86AudioRaiseVolume,  exec, $ipc volume increase
bindel = , XF86AudioLowerVolume,  exec, $ipc volume decrease
bindl  = , XF86AudioMute,         exec, $ipc volume muteOutput
bindl  = , XF86AudioMicMute,      exec, $ipc volume muteInput
bindel = , XF86MonBrightnessUp,   exec, $ipc brightness increase
bindel = , XF86MonBrightnessDown, exec, $ipc brightness decrease


# Overview
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#bind = SUPER, grave, niri:overview, toggle


# LAPTOP LID
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# bindl = , switch:Lid Switch,     exec, $ipc lockScreen lock
bindl = , switch:on:Lid Switch,  exec, hyprctl keyword monitor "eDP-1, disable"
bindl = , switch:off:Lid Switch, exec, hyprctl keyword monitor "eDP-1, disable"
```

---

### 9. Autostart: `hyprland/autostart.conf`

```conf
exec-once = dbus-update-activation-environment --systemd --all
exec-once = systemctl --user start hyprland-session.target
exec-once = udiskie
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
exec-once = qs -c noctalia-shell --no-duplicate
exec-once = hyprpm reload -n
exec-once = pypr
exec-once = emacs --daemon
```
