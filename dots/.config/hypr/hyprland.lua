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

-- For Noctalia Color templates
require("noctalia").apply_theme()
