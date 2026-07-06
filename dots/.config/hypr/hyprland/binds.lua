-- hyprland/binds.lua
local terminal = "kitty"
local browser = "brave-browser"
local guifm = "nautilus"
local editor = "emacsclient -c -a 'emacs'"
local ipc = "qs -c noctalia-shell ipc call"
local screenshot = "~/bin/screenshot"
local pypr = "/usr/bin/pypr-client"
local dispatch = "~/bin/unified-dispatch.py"

-- ESSENTIALS
hl.bind("SUPER + D", hl.dsp.exec_cmd(ipc .. " launcher toggle"))
hl.bind("SUPER + X", hl.dsp.exec_cmd(ipc .. " sessionMenu toggle"))
hl.bind("SUPER + Return", hl.dsp.exec_cmd(terminal))
hl.bind("SUPER + SHIFT + Return", hl.dsp.exec_cmd(pypr .. " toggle term"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + SHIFT + Space", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("special"))
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

-- SCREENSHOT
hl.bind("ALT + Print", hl.dsp.exec_cmd(screenshot .. " --region"))
hl.bind("CTRL + Print", hl.dsp.exec_cmd(screenshot .. " --fullscreen"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd(screenshot .. " --region"))

-- SUBMAPS
hl.bind("SUPER + P", hl.dsp.submap("scratchpads"))
hl.define_submap("scratchpads", function()
	hl.bind("Escape", hl.dsp.submap("reset"))
	hl.bind("C", hl.dsp.exec_cmd(pypr .. " toggle calculator"))
	hl.bind("M", hl.dsp.exec_cmd(pypr .. " toggle spotify"))
	hl.bind("Y", hl.dsp.exec_cmd(pypr .. " toggle tuifm"))
	hl.bind("L", hl.dsp.exec_cmd(pypr .. " toggle lazygit"))
	hl.bind("F", hl.dsp.exec_cmd(pypr .. " toggle files"))
	hl.bind("catchall", hl.dsp.submap("reset"), { release = true })
end)

hl.bind("SUPER + G", hl.dsp.submap("guiapps"))
hl.define_submap("guiapps", function()
	hl.bind("Escape", hl.dsp.submap("reset"))
	hl.bind("B", hl.dsp.exec_cmd(browser))
	hl.bind("F", hl.dsp.exec_cmd(guifm))
	hl.bind("E", hl.dsp.exec_cmd(editor))
	hl.bind("catchall", hl.dsp.submap("reset"), { release = true })
end)

hl.bind("SUPER + T", hl.dsp.submap("tuiapps"))
hl.define_submap("tuiapps", function()
	hl.bind("Escape", hl.dsp.submap("reset"))
	hl.bind("Y", hl.dsp.exec_cmd("kitty -e yazi"))
	hl.bind("B", hl.dsp.exec_cmd("kitty -e btop"))
	hl.bind("E", hl.dsp.exec_cmd("kitty -e nvim"))
	hl.bind("catchall", hl.dsp.submap("reset"), { release = true })
end)

hl.bind("SUPER + SHIFT + L", hl.dsp.submap("noctalia_launchers"))
hl.define_submap("noctalia_launchers", function()
	hl.bind("Escape", hl.dsp.submap("reset"))
	hl.bind("V", hl.dsp.exec_cmd(ipc .. " launcher clipboard"))
	hl.bind("W", hl.dsp.exec_cmd(ipc .. " launcher windows"))
	hl.bind("Period", hl.dsp.exec_cmd(ipc .. " launcher command"))
	hl.bind("SHIFT + Period", hl.dsp.exec_cmd(ipc .. " launcher emoji"))
	hl.bind("catchall", hl.dsp.submap("reset"), { release = true })
end)

hl.bind("SUPER + N", hl.dsp.submap("noctalia_core"))
hl.define_submap("noctalia_core", function()
	hl.bind("Escape", hl.dsp.submap("reset"))
	hl.bind("C", hl.dsp.exec_cmd(ipc .. " controlCenter toggle"))
	hl.bind("Comma", hl.dsp.exec_cmd(ipc .. " settings toggle"))
	hl.bind("A", hl.dsp.exec_cmd(ipc .. " calendar toggle"))
	hl.bind("I", hl.dsp.exec_cmd(ipc .. " systemMonitor toggle"))
	hl.bind("P", hl.dsp.exec_cmd(ipc .. " plugin togglePanel notes-scratchpad"))
	hl.bind("catchall", hl.dsp.submap("reset"), { release = true })
end)

hl.bind("SUPER + M", hl.dsp.submap("noctalia_misc"))
hl.define_submap("noctalia_misc", function()
	hl.bind("Escape", hl.dsp.submap("reset"))
	hl.bind("I", hl.dsp.exec_cmd(ipc .. " idleInhibitor toggle"))
	hl.bind("W", hl.dsp.exec_cmd(ipc .. " wifi toggle"))
	hl.bind("B", hl.dsp.exec_cmd(ipc .. " bluetooth toggle"))
	hl.bind("N", hl.dsp.exec_cmd(ipc .. " nightLight toggle"))
	hl.bind("P", hl.dsp.exec_cmd(ipc .. " powerProfile cycle"))

	-- One-shot actions that reset the submap immediately upon execution
	hl.bind("K", function()
		hl.dispatch(hl.dsp.exec_cmd(ipc .. " lockScreen lock"))
		hl.dispatch(hl.dsp.submap("reset"))
	end)
	hl.bind("X", function()
		hl.dispatch(hl.dsp.exec_cmd(ipc .. " sessionMenu lockAndSuspend"))
		hl.dispatch(hl.dsp.submap("reset"))
	end)
	hl.bind("catchall", hl.dsp.submap("reset"), { release = true })
end)

-- PYPRLAND & CORE
hl.bind("SUPER + CTRL + B", hl.dsp.exec_cmd(pypr .. " expose"))
hl.bind("SUPER + Z", hl.dsp.exec_cmd(pypr .. " zoom ++0.5"))
hl.bind("SUPER + SHIFT + Z", hl.dsp.exec_cmd(pypr .. " zoom"))
hl.bind("SUPER + BackSpace", hl.dsp.window.pseudo({ action = "toggle" }))
hl.bind("SUPER + Slash", hl.dsp.layout("togglesplit"))

-- FOCUS & MOVEMENT
hl.bind("SUPER + left", hl.dsp.exec_cmd(dispatch .. " focus l"))
hl.bind("SUPER + right", hl.dsp.exec_cmd(dispatch .. " focus r"))
hl.bind("SUPER + up", hl.dsp.exec_cmd(dispatch .. " focus u"))
hl.bind("SUPER + down", hl.dsp.exec_cmd(dispatch .. " focus d"))

hl.bind("SUPER + SHIFT + left", hl.dsp.exec_cmd(dispatch .. " movewin l"))
hl.bind("SUPER + SHIFT + right", hl.dsp.exec_cmd(dispatch .. " movewin r"))
hl.bind("SUPER + SHIFT + up", hl.dsp.exec_cmd(dispatch .. " movewin u"))
hl.bind("SUPER + SHIFT + down", hl.dsp.exec_cmd(dispatch .. " movewin d"))

hl.bind("SUPER + CTRL + left", hl.dsp.exec_cmd(dispatch .. " resize l"), { repeating = true })
hl.bind("SUPER + CTRL + right", hl.dsp.exec_cmd(dispatch .. " resize r"), { repeating = true })
hl.bind("SUPER + CTRL + up", hl.dsp.exec_cmd(dispatch .. " resize u"), { repeating = true })
hl.bind("SUPER + CTRL + down", hl.dsp.exec_cmd(dispatch .. " resize d"), { repeating = true })

-- MOUSE BINDINGS
hl.bind("CTRL + SUPER + mouse_down", hl.dsp.focus({ workspace = "-10" }))
hl.bind("CTRL + SUPER + mouse_up", hl.dsp.focus({ workspace = "+10" }))
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- SPECIAL WORKSPACES
hl.bind("SUPER + minus", hl.dsp.window.move({ workspace = "special:minimized" }))
hl.bind("SUPER + equal", hl.dsp.workspace.toggle_special("minimized"))
hl.bind("CTRL + SUPER + ALT + up", hl.dsp.window.move({ workspace = "special:special" }))
hl.bind("CTRL + SUPER + ALT + down", hl.dsp.window.move({ workspace = "e+0" }))
hl.bind("SUPER + ALT + S", hl.dsp.window.move({ workspace = "special:special" }))

-- AUDIO & BRIGHTNESS
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(ipc .. " volume increase"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(ipc .. " volume decrease"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(ipc .. " volume muteOutput"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(ipc .. " volume muteInput"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(ipc .. " brightness increase"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(ipc .. " brightness decrease"), { locked = true, repeating = true })

-- LAPTOP LID
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("hyprctl keyword monitor 'eDP-1, disable'"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("hyprctl keyword monitor 'eDP-1, disable'"), { locked = true })

-- WORKSPACE SWITCHING (Using a Lua loop to replace repetitive binds)
for i = 1, 9 do
	hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
	hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
end

hl.bind("CTRL + ALT + down", hl.dsp.focus({ workspace = "+1" }), { repeating = true })
hl.bind("CTRL + ALT + up", hl.dsp.focus({ workspace = "-1" }), { repeating = true })
hl.bind("SUPER + bracketleft", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + bracketright", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("CTRL + SUPER + ALT + up", hl.dsp.window.move({ workspace = "-1" }))
hl.bind("CTRL + SUPER + ALT + down", hl.dsp.window.move({ workspace = "+1" }))
