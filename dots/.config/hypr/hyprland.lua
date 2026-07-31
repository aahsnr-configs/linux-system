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
require("noctalia/noctalia-colors")

-- For Noctalia Color templates
require("noctalia").apply_theme()
