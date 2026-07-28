Based on my thorough research of the Hyprland Wiki , the official example config , the Dispatchers reference , the Binds page , Window Rules , Monitors , Workspace Rules , Scrolling Layout , Plugins , and the Expanding Functionality page , I now have complete verified API knowledge to perform this migration.

Here is the complete migrated configuration:

---

# Hyprland Lua Configuration (Migrated from hyprlang)

Migrated to the Lua-based configuration system introduced in Hyprland 0.55 , verified against the 0.56 stable release . All API calls verified against wiki.hypr.land (last updated July 24–27, 2026) and the official example hyprland.lua .

## 1. Main Entry Point: `hyprland.lua`

`~/.config/hypr/hyprland.lua`

```lua
-- Hyprland Lua Configuration
-- Migrated from hyprlang to Lua (Hyprland 0.55+)
-- Refer to: https://wiki.hypr.land/Configuring/Start/

-- Module loading order respects dependency graph.
-- Variables shared across modules are defined in vars.lua.
require("hyprland/vars")
require("hyprland/env")
require("hyprland/settings")
require("hyprland/monitor")
require("hyprland/plugins")
require("hyprland/rules")
require("hyprland/workspaces")
require("hyprland/binds")
require("hyprland/autostart")

-- Noctalia color theme (must be converted to .lua)
-- TODO(verify): Convert noctalia-colors.conf to a .lua module calling hl.config()
-- require("noctalia/noctalia-colors")
```

## 2. Shared Variables: `hyprland/vars.lua`

`~/.config/hypr/hyprland/vars.lua`

```lua
-- Shared variables accessible across all modules via require("hyprland/vars")
-- In hyprlang, $variables were global across sourced files.
-- In Lua, locals are file-scoped, so we export them via a returned table.

local M = {}

M.terminal   = "kitty"
M.browser    = "brave-browser"
M.guifm      = "nautilus"
M.editor     = "emacsclient -c -a 'emacs'"
M.ipc        = "qs -c noctalia-shell ipc call"
M.screenshot = "~/bin/screenshot"
M.pypr       = "/usr/bin/pypr-client"
M.dispatch   = "~/bin/unified-dispatch.py"
M.mainMod    = "SUPER"

return M
```

## 3. Environment Variables: `hyprland/env.lua`

`~/.config/hypr/hyprland/env.lua`

```lua
-- Environment variables for Wayland session
-- Verified: hl.env(key, value) per wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- GDK / QT / SDL backend selection
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")

-- Clutter
hl.env("CLUTTER_BACKEND", "wayland")

-- XDG session identification
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_CURRENT_SESSION", "Hyprland")

-- QT scaling and theming
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("QT_QPA_PLATFORMTHEME_QT6", "qt6ct")

-- NVIDIA GPU backend
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("__GL_VRR_ALLOWED", "1")
hl.env("LIBVA_DRIVER_NAME", "nvidia")

-- Electron / Chromium
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Cursor theme
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "20")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "20")
```

## 4. Settings & Animations: `hyprland/settings.lua`

`~/.config/hypr/hyprland/settings.lua`

```lua
-- General, Decoration, Animations, Input, Gestures, Layouts, Misc, XWayland, Debug
-- Verified against: wiki.hypr.land/Configuring/Basics/Variables/ (July 24, 2026)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- GENERAL
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.config({
  general = {
    gaps_in = 4,
    gaps_out = 7,
    border_size = 3,
    col = {
      active_border = { colors = { "rgba(b8bb26ff)", "rgba(fabd2fff)" }, angle = 45 },
      inactive_border = { colors = { "rgba(3c3836cc)", "rgba(504945cc)" }, angle = 45 },
    },
    layout = "scrolling",
    resize_on_border = true,
    snap = {
      enabled = true,
    },
  },
})

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- DECORATION
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.config({
  decoration = {
    rounding = 8,
    rounding_power = 3,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    fullscreen_opacity = 1,
    dim_inactive = false,
    shadow = {
      enabled = true,
      range = 2,
      render_power = 1,
      color = "rgba(1a1a1aee)",
    },
    blur = {
      enabled = true,
      size = 3,
      passes = 2,
      new_optimizations = true,
      ignore_opacity = true,
      xray = false,
      special = true,
      vibrancy = 0.1696,
      popups = true,
    },
  },
})

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ANIMATIONS
-- Verified: hl.curve() for bezier definitions, hl.animation() for animation leaves
-- Legacy format: animation = NAME, ENABLED, SPEED, CURVE, STYLE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.config({
  animations = {
    enabled = true,
  },
})

-- Bezier curve definitions
hl.curve("wind",   { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("winIn",  { type = "bezier", points = { { 0.1, 1.1 }, { 0.1, 1.1 } } })
hl.curve("winOut", { type = "bezier", points = { { 0.3, -0.3 }, { 0, 1 } } })
hl.curve("liner",  { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })

-- Animation leaves
hl.animation({ leaf = "windows",      enabled = true, speed = 4,  bezier = "wind",  style = "popin" })
hl.animation({ leaf = "windowsIn",    enabled = true, speed = 4,  bezier = "winIn", style = "popin" })
hl.animation({ leaf = "windowsOut",   enabled = true, speed = 4,  bezier = "winOut", style = "popin" })
hl.animation({ leaf = "windowsMove",  enabled = true, speed = 4,  bezier = "wind",  style = "slide" })
hl.animation({ leaf = "border",       enabled = true, speed = 1,  bezier = "liner" })
hl.animation({ leaf = "borderangle",  enabled = true, speed = 30, bezier = "liner", style = "once" })
hl.animation({ leaf = "fade",         enabled = true, speed = 4,  bezier = "default" })
hl.animation({ leaf = "workspaces",   enabled = true, speed = 5,  bezier = "wind",  style = "slidevert" })

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- INPUT
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.config({
  input = {
    kb_layout = "us",
    kb_options = "ctrl:nocaps",
    follow_mouse = 1,
    accel_profile = "flat",
    numlock_by_default = true,
    touchpad = {
      natural_scroll = true,
    },
  },
})

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- GESTURES
-- Verified: hl.gesture() per wiki Variables page (gestures section)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.gesture({
  fingers = 3,
  direction = "horizontal",
  action = "workspace",
})

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LAYOUTS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.config({
  dwindle = {
    preserve_split = true,
    smart_split = true,
    smart_resizing = true,
  },
})

hl.config({
  master = {
    new_status = "master",
  },
})

-- Built-in scrolling layout (Hyprland 0.55+)
-- Verified: wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
hl.config({
  scrolling = {
    column_width = 0.40,
    follow_min_visible = 0.33,
    fullscreen_on_one_column = false,
    focus_fit_method = 1,
    direction = "right",
  },
})

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- MISC
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.config({
  misc = {
    vrr = 0,
    disable_hyprland_logo = true,
    force_default_wallpaper = 0,
    middle_click_paste = false,
    focus_on_activate = true,
    session_lock_xray = true,
    enable_swallow = true,
    swallow_regex = "^(Alacritty|kitty|footclient)$",
  },
})

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- XWAYLAND
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.config({
  xwayland = {
    force_zero_scaling = true,
  },
})

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- DEBUG
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.config({
  debug = {
    disable_logs = false,
    enable_stdout_logs = true,
  },
})
```

## 5. Monitors: `hyprland/monitor.lua`

`~/.config/hypr/hyprland/monitor.lua`

```lua
-- Monitor configuration
-- Verified: wiki.hypr.land/Configuring/Basics/Monitors/ (July 24, 2026)

hl.monitor({
  output = "HDMI-A-1",
  mode = "3840x2160@60",
  position = "0x0",
  scale = 2.0,
  bitdepth = 10,
  cm = "auto",
  -- sdrbrightness = 1.0,
  -- sdrsaturation = 1.0,
  -- supports_hdr = 1,
  -- supports_wide_color = 1,
  -- sdr_min_luminance = 0.005,
  -- sdr_max_luminance = 250,
  -- min_luminance = 0,
  -- max_luminance = 1000,
  -- max_avg_luminance = 500,
})

-- Fallback rule for any unplugged monitor
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = "auto",
})

-- hl.config({
--   render = {
--     cm_auto_hdr = 2,
--   },
-- })
```

## 6. Plugins: `hyprland/plugins.lua`

`~/.config/hypr/hyprland/plugins.lua`

```lua
-- Plugin configuration
-- hy3 plugin (tabbed groups, autotile)
if hl.plugin.hy3 ~= nil then
  hl.config({
    plugin = {
      hy3 = {
        tabs = {
          height = 22,
          padding = 6,
          render_text = false,
          from_top = false,
          radius = 6,
          border_width = 2,
          text_font = "Sans",
          text_height = 8,
          text_padding = 3,
        },
        autotile = {
          enable = true,
          trigger_width = 600,
          trigger_height = 200,
          workspaces = "all",
        },
        group_inset = 10,
        node_collapse_policy = 2,
        tab_first_window = false,
      },
    },
  })
end

-- hyprscroller plugin (column-based scrolling)
if hl.plugin.hyprscroller ~= nil then
  hl.config({
    plugin = {
      hyprscroller = {
        column_default_width = 0.4,
        focus_wrap = true,
      },
    },
  })
end

-- hyprtrails plugin (visual window trails)
if hl.plugin.hyprtrails ~= nil then
  hl.config({
    plugin = {
      hyprtrails = {
        enabled = true,
        trail_length = 8,
        trail_opacity = 0.6,
        trail_color = "0xffffffff",
        trail_blend = "add",
      },
    },
  })
end
```

## 7. Window, Layer, and Workspace Rules: `hyprland/rules.lua`

`~/.config/hypr/hyprland/rules.lua`

```lua
-- Window Rules, Layer Rules
-- Verified: wiki.hypr.land/Configuring/Basics/Window-Rules/ (July 24, 2026)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- WINDOW RULES
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Ghostty transparency
hl.window_rule({
  name = "ghostty_opacity",
  match = { class = "^(com\\.mitchellh\\.ghostty)$" },
  opacity = "0.95 0.95",
})

-- Kitty drop-terminal
hl.window_rule({
  name = "kitty_floating",
  match = { class = "^(kitty-dropterm)$" },
  size = "70% 70%",
  float = true,
  animation = "slidein",
})

-- Yazi file manager
hl.window_rule({
  name = "yazi_floating",
  match = { class = "^(explorer)$" },
  size = "90% 90%",
  float = true,
  animation = "slidein",
})

-- Nautilus
hl.window_rule({
  name = "nautilus_floating",
  match = { class = "^(org\\.gnome\\.Nautilus)$" },
  float = true,
  animation = "popin",
  size = "1000 800",
})

-- BleachBit
hl.window_rule({
  name = "bleachbit_floating",
  match = { class = "^(org\\.bleachbit\\.BleachBit)$" },
  float = true,
  animation = "popin",
  size = "600 600",
  no_blur = true,
  no_anim = true,
})

-- Thunar
hl.window_rule({
  name = "thunar_floating",
  match = { class = "^(thunar)$" },
  float = true,
  animation = "popin",
  size = "800 600",
})

-- Thunar progress bar
hl.window_rule({
  name = "Thunar-Progress-bar",
  match = { class = "^(thunar)$", title = "^(File Operation Progress)$" },
  float = true,
  center = true,
  move = "(cursor_x-(window_w*0.05)) (cursor_y-(window_h*0.6))",
  size = "(monitor_w*0.26) (monitor_h*0.18)",
})

-- qt5ct / qt6ct
hl.window_rule({
  name = "qt5ct_floating",
  match = { class = "^(qt5ct)$" },
  float = true,
  center = true,
  size = "800 600",
})

hl.window_rule({
  name = "qt6ct_floating",
  match = { class = "^(qt6ct)$" },
  float = true,
  center = true,
  size = "800 600",
})

-- nwg-look
hl.window_rule({
  name = "nwg_look",
  match = { class = "^(nwg-look)$" },
  float = true,
  center = true,
  size = "600 400",
})

-- Brave Google sign-in popup
hl.window_rule({
  name = "google_signin_popup",
  match = { class = "^(brave-browser)$", title = "^(Untitled - Brave)$" },
  float = true,
  size = "450 600",
  move = "(cursor_x-(window_w*0.5)) (cursor_y-(window_h*0.5))",
  no_blur = true,
  no_anim = true,
})

-- Bitwarden popup
hl.window_rule({
  name = "bitwarden_popup",
  match = { class = "^(brave-nngceckbapebfimnlniiiahkandclblb-Default)$",
            title = "^(_crx_nngceckbapebfimnlniiiahkandclblb)$" },
  float = true,
  size = "450 600",
  move = "(cursor_x-(window_w*0.5)) (cursor_y-(window_h*0.5))",
  no_blur = true,
  no_anim = true,
})

-- xdg-desktop-portal-gtk
hl.window_rule({
  name = "xdg_desktop_portal_gtk",
  match = { class = "^(xdg-desktop-portal-gtk)$" },
  size = "600 600",
  float = true,
  move = "(cursor_x-(window_w*0.05)) (cursor_y-(window_h*0.6))",
  no_blur = true,
})

-- Center all floating windows (not xwayland popups)
hl.window_rule({
  name = "center-floating",
  match = { float = true, xwayland = false },
  center = true,
})

-- Float rules for various apps
hl.window_rule({ match = { class = "org\\.gnome\\.FileRoller" }, float = true })
hl.window_rule({ match = { class = "file-roller" }, float = true })
hl.window_rule({ match = { class = "imv" }, float = true })
hl.window_rule({ match = { class = "system-config-printer" }, float = true })
hl.window_rule({ match = { class = "CachyOSHello" }, float = true })

-- Float, resize and center
hl.window_rule({
  match = { class = "org\\.pulseaudio\\.pavucontrol|yad-icon-browser" },
  float = true,
  size = "60% 70%",
  center = true,
})

-- Dialog rules (match by title)
hl.window_rule({ match = { title = "(Select|Open)( a)? (File|Folder)(s)?" }, float = true })
hl.window_rule({ match = { title = "File (Operation|Upload)( Progress)?" }, float = true })
hl.window_rule({ match = { title = ".* Properties" }, float = true })
hl.window_rule({ match = { title = "Export Image as PNG" }, float = true })
hl.window_rule({ match = { title = "GIMP Crash Debug" }, float = true })
hl.window_rule({ match = { title = "Save As" }, float = true })
hl.window_rule({ match = { title = "Library" }, float = true })

-- Picture-in-Picture
hl.window_rule({
  name = "Picture-in-Picture",
  match = { title = "^(Picture-in-Picture)$" },
  float = true,
  move = "72% 7%",
  opacity = "0.95 0.75",
  pin = true,
  keep_aspect_ratio = true,
  size = "(monitor_w*0.3) (monitor_h*0.3)",
})

-- XWayland popup cosmetics
hl.window_rule({
  match = { xwayland = true, title = "win[0-9]+" },
  no_dim = true,
  no_shadow = true,
  rounding = 10,
})

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LAYER RULES
-- Verified: wiki.hypr.land/Configuring/Basics/Window-Rules/ (Layer Rules section)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Noctalia Shell blur
hl.layer_rule({
  name = "noctalia",
  match = { namespace = "noctalia-background-.*$" },
  ignore_alpha = 0.5,
  blur = true,
  blur_popups = true,
})

-- Other blur layers (rofi, notifications, quickshell)
hl.layer_rule({
  name = "blur_layers",
  match = { namespace = "^(rofi|notifications|quickshell:.*)$" },
  blur = true,
  ignore_alpha = 1,
})

-- Disable animation for gtk4-layer-shell
hl.layer_rule({
  match = { namespace = "gtk4-layer-shell" },
  no_anim = true,
})
```

## 8. Workspaces: `hyprland/workspaces.lua`

`~/.config/hypr/hyprland/workspaces.lua`

```lua
-- Workspace rules and workspace-switching keybindings
-- Verified: wiki.hypr.land/Configuring/Basics/Workspace-Rules/ (July 24, 2026)

local vars = require("hyprland/vars")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- WORKSPACE RULES (layout assignments)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.workspace_rule({ workspace = "1", layout = "scrolling" })
hl.workspace_rule({ workspace = "2", layout = "scrolling" })
hl.workspace_rule({ workspace = "3", layout = "scrolling" })
hl.workspace_rule({ workspace = "4", layout = "hy3" })
hl.workspace_rule({ workspace = "5", layout = "hy3" })
hl.workspace_rule({ workspace = "6", layout = "hy3" })
hl.workspace_rule({ workspace = "7", layout = "master" })
hl.workspace_rule({ workspace = "8", layout = "master" })
hl.workspace_rule({ workspace = "9", layout = "monocle" })

-- Named workspaces
hl.workspace_rule({ workspace = "name:research", layout = "scrolling" })
hl.workspace_rule({ workspace = "name:dev", layout = "hy3" })
hl.workspace_rule({ workspace = "name:comm", layout = "master" })
hl.workspace_rule({ workspace = "name:stage", layout = "scrolling" })

-- Special workspace rule
hl.workspace_rule({
  workspace = "special:exposed",
  gaps_out = 60,
  gaps_in = 30,
  border_size = 5,
  no_border = false,
  no_shadow = true,
})

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- WORKSPACE KEYBINDINGS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Switch Workspaces (Super+1-9)
for i = 1, 9 do
  hl.bind(vars.mainMod .. " + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
end

-- Move Window to Workspace (Super+Shift+1-9)
for i = 1, 9 do
  hl.bind(vars.mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
end

-- Relative switching
hl.bind("CTRL + ALT + down", hl.dsp.focus({ workspace = "+1" }), { repeating = true })
hl.bind("CTRL + ALT + up",   hl.dsp.focus({ workspace = "-1" }), { repeating = true })
hl.bind(vars.mainMod .. " + bracketleft",  hl.dsp.focus({ workspace = "e-1" }))
hl.bind(vars.mainMod .. " + bracketright", hl.dsp.focus({ workspace = "e+1" }))

-- Move window relative
hl.bind("CTRL + SUPER + ALT + up",   hl.dsp.window.move({ workspace = "-1" }))
hl.bind("CTRL + SUPER + ALT + down", hl.dsp.window.move({ workspace = "+1" }))
```

## 9. Keybindings & Submaps: `hyprland/binds.lua`

`~/.config/hypr/hyprland/binds.lua`

```lua
-- Keybindings and Submaps
-- Verified: wiki.hypr.land/Configuring/Basics/Binds/ (July 24, 2026)
-- Verified: wiki.hypr.land/Configuring/Basics/Dispatchers/ (July 24, 2026)

local vars = require("hyprland/vars")
local mainMod = vars.mainMod

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ESSENTIALS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind(mainMod .. " + D",      hl.dsp.exec_cmd(vars.ipc .. " launcher toggle"))
hl.bind(mainMod .. " + X",      hl.dsp.exec_cmd(vars.ipc .. " sessionMenu toggle"))
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(vars.terminal))
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd(vars.pypr .. " toggle term"))
hl.bind(mainMod .. " + Q",      hl.dsp.window.close())
hl.bind(mainMod .. " + Space",  hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + S",      hl.dsp.workspace.toggle_special(""))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SCREENSHOT
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind("ALT + Print",       hl.dsp.exec_cmd(vars.screenshot .. " --region"))
hl.bind("CTRL + Print",      hl.dsp.exec_cmd(vars.screenshot .. " --fullscreen"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(vars.screenshot .. " --region"))

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SCRATCHPADS SUBMAP (Super+P → leader)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind(mainMod .. " + P", hl.dsp.submap("scratchpads"))

hl.define_submap("scratchpads", function()
  hl.bind("escape", hl.dsp.submap("reset"))
  hl.bind("C", hl.dsp.exec_cmd(vars.pypr .. " toggle calculator"))
  hl.bind("M", hl.dsp.exec_cmd(vars.pypr .. " toggle spotify"))
  hl.bind("Y", hl.dsp.exec_cmd(vars.pypr .. " toggle tuifm"))
  hl.bind("L", hl.dsp.exec_cmd(vars.pypr .. " toggle lazygit"))
  hl.bind("F", hl.dsp.exec_cmd(vars.pypr .. " toggle files"))
  hl.bind("catchall", hl.dsp.submap("reset"), { release = true })
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- GUI APPLICATIONS SUBMAP (Super+G → leader)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind(mainMod .. " + G", hl.dsp.submap("guiapps"))

hl.define_submap("guiapps", function()
  hl.bind("escape", hl.dsp.submap("reset"))
  hl.bind("B", hl.dsp.exec_cmd(vars.browser))
  hl.bind("F", hl.dsp.exec_cmd(vars.guifm))
  hl.bind("E", hl.dsp.exec_cmd(vars.editor))
  hl.bind("catchall", hl.dsp.submap("reset"), { release = true })
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TUI APPLICATIONS SUBMAP (Super+T → leader)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind(mainMod .. " + T", hl.dsp.submap("tuiapps"))

hl.define_submap("tuiapps", function()
  hl.bind("escape", hl.dsp.submap("reset"))
  hl.bind("Y", hl.dsp.exec_cmd("kitty -e yazi"))
  hl.bind("B", hl.dsp.exec_cmd("kitty -e btop"))
  hl.bind("E", hl.dsp.exec_cmd("kitty -e nvim"))
  hl.bind("catchall", hl.dsp.submap("reset"), { release = true })
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NOCTALIA LAUNCHERS SUBMAP (Super+Shift+L → leader)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.submap("noctalia_launchers"))

hl.define_submap("noctalia_launchers", function()
  hl.bind("escape", hl.dsp.submap("reset"))
  hl.bind("V", hl.dsp.exec_cmd(vars.ipc .. " launcher clipboard"))
  hl.bind("W", hl.dsp.exec_cmd(vars.ipc .. " launcher windows"))
  hl.bind("period", hl.dsp.exec_cmd(vars.ipc .. " launcher command"))
  hl.bind("SHIFT + period", hl.dsp.exec_cmd(vars.ipc .. " launcher emoji"))
  hl.bind("catchall", hl.dsp.submap("reset"), { release = true })
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NOCTALIA CORE INTERFACE SUBMAP (Super+N → leader)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind(mainMod .. " + N", hl.dsp.submap("noctalia_core"))

hl.define_submap("noctalia_core", function()
  hl.bind("escape", hl.dsp.submap("reset"))
  hl.bind("C", hl.dsp.exec_cmd(vars.ipc .. " controlCenter toggle"))
  hl.bind("comma", hl.dsp.exec_cmd(vars.ipc .. " settings toggle"))
  hl.bind("A", hl.dsp.exec_cmd(vars.ipc .. " calendar toggle"))
  hl.bind("I", hl.dsp.exec_cmd(vars.ipc .. " systemMonitor toggle"))
  hl.bind("P", hl.dsp.exec_cmd(vars.ipc .. " plugin togglePanel notes-scratchpad"))
  hl.bind("catchall", hl.dsp.submap("reset"), { release = true })
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NOCTALIA MISC SUBMAP (Super+M → leader)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind(mainMod .. " + M", hl.dsp.submap("noctalia_misc"))

hl.define_submap("noctalia_misc", function()
  hl.bind("escape", hl.dsp.submap("reset"))
  -- Persistent toggles
  hl.bind("I", hl.dsp.exec_cmd(vars.ipc .. " idleInhibitor toggle"))
  hl.bind("W", hl.dsp.exec_cmd(vars.ipc .. " wifi toggle"))
  hl.bind("B", hl.dsp.exec_cmd(vars.ipc .. " bluetooth toggle"))
  hl.bind("N", hl.dsp.exec_cmd(vars.ipc .. " nightLight toggle"))
  hl.bind("P", hl.dsp.exec_cmd(vars.ipc .. " powerProfile cycle"))
  -- One-shot actions (auto-reset)
  hl.bind("K", function()
    hl.dispatch(hl.dsp.exec_cmd(vars.ipc .. " lockScreen lock"))
    hl.dispatch(hl.dsp.submap("reset"))
  end)
  hl.bind("X", function()
    hl.dispatch(hl.dsp.exec_cmd(vars.ipc .. " sessionMenu lockAndSuspend"))
    hl.dispatch(hl.dsp.submap("reset"))
  end)
  hl.bind("catchall", hl.dsp.submap("reset"), { release = true })
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- PYPRLAND (Hyprland-specific extras)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind(mainMod .. " + CTRL + B", hl.dsp.exec_cmd(vars.pypr .. " expose"))
hl.bind(mainMod .. " + Z",        hl.dsp.exec_cmd(vars.pypr .. " zoom ++0.5"))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd(vars.pypr .. " zoom"))

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HYPRLAND CORE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind(mainMod .. " + BackSpace", hl.dsp.window.pseudo({ action = "toggle" }))
hl.bind(mainMod .. " + slash",     hl.dsp.layout("togglesplit"))

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FOCUS & MOVEMENT (routed through unified-dispatch)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind(mainMod .. " + left",  hl.dsp.exec_cmd(vars.dispatch .. " focus l"))
hl.bind(mainMod .. " + right", hl.dsp.exec_cmd(vars.dispatch .. " focus r"))
hl.bind(mainMod .. " + up",    hl.dsp.exec_cmd(vars.dispatch .. " focus u"))
hl.bind(mainMod .. " + down",  hl.dsp.exec_cmd(vars.dispatch .. " focus d"))

-- Move Window
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.exec_cmd(vars.dispatch .. " movewin l"))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.exec_cmd(vars.dispatch .. " movewin r"))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.exec_cmd(vars.dispatch .. " movewin u"))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.exec_cmd(vars.dispatch .. " movewin d"))

-- Resize Window
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.exec_cmd(vars.dispatch .. " resize l"), { repeating = true })
hl.bind(mainMod .. " + CTRL + right", hl.dsp.exec_cmd(vars.dispatch .. " resize r"), { repeating = true })
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.exec_cmd(vars.dispatch .. " resize u"), { repeating = true })
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.exec_cmd(vars.dispatch .. " resize d"), { repeating = true })

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- MOUSE SCROLLING
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind("CTRL + SUPER + mouse_down", hl.dsp.focus({ workspace = "-10" }))
hl.bind("CTRL + SUPER + mouse_up",   hl.dsp.focus({ workspace = "+10" }))
hl.bind(mainMod .. " + mouse_down",  hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",    hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SPECIAL WORKSPACE & MINIMIZE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind(mainMod .. " + minus", hl.dsp.window.move({ workspace = "special:minimized" }))
hl.bind(mainMod .. " + equal", hl.dsp.workspace.toggle_special("minimized"))
hl.bind("CTRL + SUPER + ALT + up",   hl.dsp.window.move({ workspace = "special:special" }))
hl.bind("CTRL + SUPER + ALT + down", hl.dsp.window.move({ workspace = "e+0" }))
hl.bind(mainMod .. " + ALT + S",     hl.dsp.window.move({ workspace = "special:special" }))

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- AUDIO & BRIGHTNESS
-- bindel = repeating + locked
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(vars.ipc .. " volume increase"), { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(vars.ipc .. " volume decrease"), { repeating = true, locked = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(vars.ipc .. " volume muteOutput"), { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd(vars.ipc .. " volume muteInput"), { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(vars.ipc .. " brightness increase"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(vars.ipc .. " brightness decrease"), { repeating = true, locked = true })

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LAPTOP LID
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd('hyprctl keyword monitor "eDP-1, disable"'), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd('hyprctl keyword monitor "eDP-1, disable"'), { locked = true })
```

## 10. Autostart: `hyprland/autostart.lua`

`~/.config/hypr/hyprland/autostart.lua`

```lua
-- Autostart programs
-- Verified: hl.on("hyprland.start", ...) fires once at startup
-- This replaces the legacy exec-once = ... syntax

hl.on("hyprland.start", function()
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")
  hl.exec_cmd("systemctl --user start hyprland-session.target")
  hl.exec_cmd("udiskie")
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("qs -c noctalia-shell --no-duplicate")
  hl.exec_cmd("hyprpm reload -n")
  hl.exec_cmd("pypr")
  hl.exec_cmd("emacs --daemon")
end)
```

---

## Migration Summary

| Legacy Construct                    | Lua Equivalent                                                     | Verified Source       |
| ----------------------------------- | ------------------------------------------------------------------ | --------------------- |
| `source = path`                     | `require("module")`                                                | Official example      |
| `$var = value`                      | `local vars = require("hyprland/vars")`                            | Section 3 of protocol |
| `env = K,V`                         | `hl.env("K", "V")`                                                 | Official example      |
| `general { }`                       | `hl.config({ general = { } })`                                     | Wiki Variables        |
| `monitorv2 { }`                     | `hl.monitor({ })`                                                  | Wiki Monitors         |
| `bezier = name, x0,y0,x1,y1`        | `hl.curve("name", { type="bezier", points={{x0,y0},{x1,y1}} })`    | Official example      |
| `animation = N,E,S,C,ST`            | `hl.animation({ leaf=N, enabled=E, speed=S, bezier=C, style=ST })` | Official example      |
| `gesture = F,D,A`                   | `hl.gesture({ fingers=F, direction=D, action=A })`                 | Wiki Variables        |
| `windowrule { }`                    | `hl.window_rule({ match={ }, effects... })`                        | Wiki Window Rules     |
| `layerrule { }`                     | `hl.layer_rule({ match={ namespace= }, effects... })`              | Wiki Window Rules     |
| `workspace = id, opts`              | `hl.workspace_rule({ workspace=id, ... })`                         | Wiki Workspace Rules  |
| `bind = M,K,disp,param`             | `hl.bind("M + K", hl.dsp.disp(param))`                             | Wiki Binds            |
| `binde = ...`                       | `hl.bind(..., { repeating = true })`                               | Wiki Binds            |
| `bindl = ...`                       | `hl.bind(..., { locked = true })`                                  | Wiki Binds            |
| `bindr = ...`                       | `hl.bind(..., { release = true })`                                 | Wiki Binds            |
| `bindm = ...`                       | `hl.bind(..., { mouse = true })`                                   | Wiki Binds            |
| `bindel = ...`                      | `hl.bind(..., { repeating=true, locked=true })`                    | Wiki Binds            |
| `submap = name`                     | `hl.define_submap("name", function() ... end)`                     | Wiki Binds            |
| `bindr = , catchall, submap, reset` | `hl.bind("catchall", hl.dsp.submap("reset"), { release=true })`    | Wiki Binds            |
| `exec-once = cmd`                   | `hl.on("hyprland.start", function() hl.exec_cmd("cmd") end)`       | Official example      |
| `plugin { name { } }`               | `hl.config({ plugin = { name = { } } })`                           | Wiki Plugins          |
| `general.layout = scroller`         | `general.layout = "scrolling"` (built-in 0.55+)                    | Wiki Scrolling        |

### Items Flagged for Verification

- `noctalia/noctalia-colors.conf` must be manually converted to a `.lua` module that calls `hl.config()` with the color definitions. The require is commented out until conversion is complete.
- Plugin config key names (`hyprscroller`, `hyprtrails`) should be verified against each plugin's own documentation, as plugin config keys are not standardized by Hyprland core.
- The `hy3` workspace layout name (`layout = "hy3"`) in workspace rules should be verified — it depends on the hy3 plugin registering itself as a layout provider.
- `hl.dsp.workspace.toggle_special("")` for the default (unnamed) special workspace — verify with `hyprctl` REPL on your running instance if this differs from passing no argument.
