Good. Now let me do thorough research before writing a single line.Now I have everything I need. Let me also verify the mangowc documentation site for any additional window rule parameters I may have missed.Now I have everything needed. Let me write all changes with full precision.

---

## Task 1 — Monitor setup

### Change 1a — MONITOR RULES section (around line 133)

**Modify** the existing `eDP-1` line AND uncomment/replace the HDMI-A-1 line. Replace this block:

```
# Primary display — adjust name/resolution/refresh as needed
monitorrule=name:eDP-1,width:1920,height:1080,refresh:60,x:0,y:0,scale:1,vrr:0

# External monitor to the right — uncomment and adjust
# monitorrule=name:HDMI-A-1,width:1920,height:1080,refresh:60,x:1920,y:0,scale:1
```

with:

```
# External display — primary, placed at origin
# Adjust width/height/refresh to match your actual monitor specs (use wlr-randr to query)
monitorrule=name:HDMI-A-1,width:1920,height:1080,refresh:60,x:0,y:0,scale:1,vrr:0

# Laptop display — kept defined for re-enable, placed logically to the right; powered off at startup below
monitorrule=name:eDP-1,width:1920,height:1080,refresh:60,x:1920,y:0,scale:1,vrr:0
```

### Change 1b — AUTOSTART section (after line 84, after the `swayidle` exec-once line)

**Add** one new line:

```
# Immediately power off the laptop panel; HDMI-A-1 is the sole active display
exec-once=wlr-randr --output eDP-1 --off
```

---

## Task 2 — Environment variables

### Change 2a — Modify existing `GDK_BACKEND` line (line 108)

**Replace:**

```
env=GDK_BACKEND,wayland,x11
```

**With:**

```
env=GDK_BACKEND,wayland,x11,*
```

### Change 2b — Add new env block (after the last existing `env=` line, i.e. after `env=GLFW_IM_MODULE,ibus` around line 123)

**Add:**

```
# DRM device selection (replaces Hyprland/Aquamarine's AQ_DRM_DEVICES)
env=WLR_DRM_DEVICES,/dev/dri/card0:/dev/dri/card1

# NVIDIA-specific — required for correct EGL/VA-API/GBM operation on Nvidia
env=GBM_BACKEND,nvidia-drm
env=__GLX_VENDOR_LIBRARY_NAME,nvidia
env=LIBVA_DRIVER_NAME,nvidia

# XDG session identity — change Hyprland values to match wlroots/mango
env=XDG_SESSION_TYPE,wayland
env=XDG_SESSION_DESKTOP,mango
env=XDG_CURRENT_DESKTOP,wlroots
env=XDG_CURRENT_SESSION,mango

# Qt — additional flags from your env.conf
env=QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env=QT_QPA_PLATFORMTHEME_QT6,qt6ct
```

---

## Task 3 — Window rules, layer rules, workspace/overview rules

### Change 3a — OVERVIEW SETTINGS (lines 327–328)

**Replace:**

```
overviewgappi=6
overviewgappo=35
```

**With:**

```
overviewgappi=30
overviewgappo=60
```

_(Matches `gapsin:30,gapsout:60` from the Hyprland workspace rule for the exposed special workspace.)_

---

### Change 3b — LAYER RULES section (after line 415, after the `swaylock` layerrule)

**Add** (gtk4-layer-shell: direct translation of `no_anim on`; quickshell layers already get blur via global `blur_layer=1` so no explicit blur rule is needed for them):

```
# gtk4-layer-shell surfaces (e.g. GTK4 popovers, app menus) — disable animation to prevent glitching
layerrule=noanim:1,layer_name:gtk4-layer-shell

# Noctalia shell background layers — already receive blur via global blur_layer=1
# ignore_alpha and blur_popups are Hyprland-specific features with no mangowc equivalent
```

**Note on noctalia and quickshell:** the Hyprland `blur = true` for `noctalia-background-.*` and `rofi|notifications|quickshell:.*` is satisfied by the global `blur_layer=1` already present in your config. No new layerrule line is needed for blur on those namespaces.

---

### Change 3c — WINDOW RULES section: modify four existing lines

**Replace** (line ~504):

```
windowrule=isfloating:1,appid:qt5ct
```

**With:**

```
windowrule=isfloating:1,width:800,height:600,appid:qt5ct
```

**Replace** (line ~505):

```
windowrule=isfloating:1,appid:qt6ct
```

**With:**

```
windowrule=isfloating:1,width:800,height:600,appid:qt6ct
```

**Replace** (line ~507):

```
windowrule=isfloating:1,appid:xdg-desktop-portal-gtk
```

**With:**

```
windowrule=isfloating:1,width:600,height:600,noblur:1,appid:xdg-desktop-portal-gtk
```

**Replace** (line ~514):

```
windowrule=isfloating:1,title:Picture-in-Picture
```

**With:**

```
windowrule=isfloating:1,isglobal:1,isoverlay:1,width:576,height:324,focused_opacity:0.95,unfocused_opacity:0.75,offsetx:65,offsety:-57,title:Picture-in-Picture
```

_(Geometry: 30% of 1920×1080. `isglobal` = Hyprland's `pin` (visible across all tags). `isoverlay` = always on top. `offsetx:65,offsety:-57` approximates Hyprland's `move = 72% 7%` — the PiP sits in the top-right. `keep_aspect_ratio` has no mangowc equivalent.)_

---

### Change 3d — WINDOW RULES section: add new rules block

**After** the last named scratchpad windowrule (line 545, after `windowrule=isnamedscratchpad:1,width:1100,height:700,appid:com.spotify.Client`) **and the three lines added in the previous scratchpad session**, **append** the entire block below:

```
# ── From rules.conf (Hyprland migration) ─────────────────────────────────────

# Ghostty — slight transparency on both focused and unfocused
windowrule=focused_opacity:0.95,unfocused_opacity:0.95,appid:com.mitchellh.ghostty

# kitty-dropterm — slide animation (size already set in isnamedscratchpad rule above)
windowrule=isfloating:1,animation_type_open:slide,appid:kitty-dropterm

# Nautilus — floating file manager
windowrule=isfloating:1,width:1000,height:800,animation_type_open:zoom,appid:org.gnome.Nautilus

# BleachBit — floating, no blur, no animation
windowrule=isfloating:1,width:600,height:600,noblur:1,isnoanimation:1,appid:org.bleachbit.BleachBit

# Thunar — general floating window with zoom open
windowrule=isfloating:1,width:800,height:600,animation_type_open:zoom,appid:thunar

# Thunar file operation progress dialog — small, centered
# cursor-relative positioning from rules.conf is not supported in mangowc; window centers by default
windowrule=isfloating:1,width:500,height:194,appid:thunar,title:File Operation Progress

# nwg-look appearance settings
windowrule=isfloating:1,width:600,height:400,appid:nwg-look

# pavucontrol (Flatpak/org.pulseaudio appid variant) — 60%×70% of 1920×1080
windowrule=isfloating:1,width:1152,height:756,appid:org.pulseaudio.pavucontrol

# yad icon browser
windowrule=isfloating:1,width:1152,height:756,appid:yad-icon-browser

# Brave — Google sign-in popup (matched by title; no blur, no anim)
windowrule=isfloating:1,width:450,height:600,noblur:1,isnoanimation:1,appid:brave-browser,title:Untitled - Brave

# Brave — Bitwarden extension popup
windowrule=isfloating:1,width:450,height:600,noblur:1,isnoanimation:1,appid:brave-nngceckbapebfimnlniiiahkandclblb-Default,title:_crx_nngceckbapebfimnlniiiahkandclblb

# Additional float rules
windowrule=isfloating:1,appid:org.gnome.FileRoller
windowrule=isfloating:1,appid:file-roller
windowrule=isfloating:1,appid:imv
windowrule=isfloating:1,appid:system-config-printer
windowrule=isfloating:1,appid:CachyOSHello

# Dialog title patterns (broader regex from rules.conf)
windowrule=isfloating:1,title:(Select|Open)( a)? (File|Folder)(s)?
windowrule=isfloating:1,title:File (Operation|Upload)( Progress)?
windowrule=isfloating:1,title:.* Properties
windowrule=isfloating:1,title:Export Image as PNG
windowrule=isfloating:1,title:GIMP Crash Debug
windowrule=isfloating:1,title:Library

# XWayland unnamed popups (win0, win1, …) — remove shadow; no_dim has no mangowc equivalent
# xwayland-status matching is not available in mangowc windowrules; title regex is the filter
windowrule=isnoshadow:1,title:win[0-9]+
```

---

### What does NOT translate and why

| Hyprland rule                          | Reason not translatable                                                                                                                                                  |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `center = on` on individual windows    | mangowc centers all floating windows by default (`no_force_center` defaults to 0); no per-rule override needed                                                           |
| `move = (cursor_x-…) (cursor_y-…)`     | Dynamic cursor-relative positioning expressions are not supported in mangowc's `offsetx`/`offsety` (which are static screen-center percentages)                          |
| `keep_aspect_ratio = on` on PiP        | No mangowc equivalent                                                                                                                                                    |
| `blur_popups = true` on noctalia layer | No mangowc layerrule equivalent                                                                                                                                          |
| `ignore_alpha` on layer rules          | No mangowc layerrule equivalent                                                                                                                                          |
| `no_dim = true` on xwayland popups     | mangowc has no dim/undim concept                                                                                                                                         |
| `workspace = special:exposed,…`        | Hyprland special workspaces don't exist in mangowc; the gap/border values from that rule are approximated by updating `overviewgappi`/`overviewgappo` in Change 3a above |
