-- Keybindings and Submaps
-- Verified: wiki.hypr.land/Configuring/Basics/Binds/ (July 24, 2026)
-- Verified: wiki.hypr.land/Configuring/Basics/Dispatchers/ (July 24, 2026)

local vars = require("hyprland/vars")
local mainMod = vars.mainMod
local unified_dispatch = require("hyprland/unified-dispatch")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ESSENTIALS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(vars.ipc .. "panel-toggle launcher"))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd(vars.ipc .. " sessionMenu toggle"))
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(vars.terminal))
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd(vars.pypr .. " toggle term"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special(""))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SCREENSHOT
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind("ALT + Print", hl.dsp.exec_cmd(vars.screenshot .. " --region"))
hl.bind("CTRL + Print", hl.dsp.exec_cmd(vars.screenshot .. " --fullscreen"))
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
	hl.bind("comma", hl.dsp.exec_cmd(vars.ipc .. "settings-toggle"))
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
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd(vars.pypr .. " zoom ++0.5"))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd(vars.pypr .. " zoom"))

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HYPRLAND CORE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind(mainMod .. " + BackSpace", hl.dsp.window.pseudo({ action = "toggle" }))
hl.bind(mainMod .. " + slash", hl.dsp.layout("togglesplit"))

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FOCUS & MOVEMENT (Routed natively through unified-dispatch.lua)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind(mainMod .. " + left", function()
	unified_dispatch.dispatch("focus", "l")
end)
hl.bind(mainMod .. " + right", function()
	unified_dispatch.dispatch("focus", "r")
end)
hl.bind(mainMod .. " + up", function()
	unified_dispatch.dispatch("focus", "u")
end)
hl.bind(mainMod .. " + down", function()
	unified_dispatch.dispatch("focus", "d")
end)

-- Move Window
hl.bind(mainMod .. " + SHIFT + left", function()
	unified_dispatch.dispatch("movewin", "l")
end)
hl.bind(mainMod .. " + SHIFT + right", function()
	unified_dispatch.dispatch("movewin", "r")
end)
hl.bind(mainMod .. " + SHIFT + up", function()
	unified_dispatch.dispatch("movewin", "u")
end)
hl.bind(mainMod .. " + SHIFT + down", function()
	unified_dispatch.dispatch("movewin", "d")
end)

-- Resize Window
hl.bind(mainMod .. " + CTRL + left", function()
	unified_dispatch.dispatch("resize", "l")
end, { repeating = true })
hl.bind(mainMod .. " + CTRL + right", function()
	unified_dispatch.dispatch("resize", "r")
end, { repeating = true })
hl.bind(mainMod .. " + CTRL + up", function()
	unified_dispatch.dispatch("resize", "u")
end, { repeating = true })
hl.bind(mainMod .. " + CTRL + down", function()
	unified_dispatch.dispatch("resize", "d")
end, { repeating = true })

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- MOUSE SCROLLING
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind("CTRL + SUPER + mouse_down", hl.dsp.focus({ workspace = "-10" }))
hl.bind("CTRL + SUPER + mouse_up", hl.dsp.focus({ workspace = "+10" }))
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SPECIAL WORKSPACE & MINIMIZE
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind(mainMod .. " + minus", hl.dsp.window.move({ workspace = "special:minimized" }))
hl.bind(mainMod .. " + equal", hl.dsp.workspace.toggle_special("minimized"))
hl.bind("CTRL + SUPER + ALT + up", hl.dsp.window.move({ workspace = "special:special" }))
hl.bind("CTRL + SUPER + ALT + down", hl.dsp.window.move({ workspace = "e+0" }))
hl.bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:special" }))

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- AUDIO & BRIGHTNESS
-- bindel = repeating + locked
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(vars.ipc .. "volume-up"), { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(vars.ipc .. "volume-down"), { repeating = true, locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(vars.ipc .. "volume-mute"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(vars.ipc .. " volume muteInput"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(vars.ipc .. " brightness increase"), { repeating = true, locked = true })
hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd(vars.ipc .. " brightness decrease"),
	{ repeating = true, locked = true }
)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LAPTOP LID
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd('hyprctl keyword monitor "eDP-1, disable"'), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd('hyprctl keyword monitor "eDP-1, disable"'), { locked = true })
