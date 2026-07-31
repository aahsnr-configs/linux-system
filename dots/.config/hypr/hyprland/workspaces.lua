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
