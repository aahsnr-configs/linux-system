-- hyprland/settings.lua
hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 7,
		border_size = 3,
		col = {
			active_border = { colors = { "rgba(b8bb26ff)", "rgba(fabd2fff)" }, angle = 45 },
			inactive_border = { colors = { "rgba(3c3836cc)", "rgba(504945cc)" }, angle = 45 },
		},
		layout = "scroller",
		resize_on_border = true,
		snap = { enabled = true },
	},
	decoration = {
		rounding = 8,
		rounding_power = 3,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		fullscreen_opacity = 1.0,
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
	input = {
		kb_layout = "us",
		kb_options = "ctrl:nocaps",
		follow_mouse = 1,
		accel_profile = "flat",
		numlock_by_default = true,
		touchpad = { natural_scroll = true },
	},
	dwindle = { preserve_split = true, smart_split = true, smart_resizing = true },
	master = { new_status = "master" },
	scrolling = {
		column_width = 0.40,
		follow_min_visible = 0.33,
		fullscreen_on_one_column = false,
		focus_fit_method = 1,
	},
	misc = {
		vrr = 0,
		disable_hyprland_logo = true,
		force_default_wallpaper = 0,
		middle_click_paste = false,
		focus_on_activate = true,
		session_lock_xray = true,
		enable_swallow = true,
		swallow_regex = [[^(Alacritty|kitty|footclient)$]],
	},
	xwayland = { force_zero_scaling = true },
	debug = { disable_logs = false, enable_stdout_logs = true },
})

-- Bezier Curves
hl.curve("wind", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("winIn", { type = "bezier", points = { { 0.1, 1.1 }, { 0.1, 1.1 } } })
hl.curve("winOut", { type = "bezier", points = { { 0.3, -0.3 }, { 0, 1 } } })
hl.curve("liner", { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })

-- Animations
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "wind", style = "popin" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, bezier = "winIn", style = "popin" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "winOut", style = "popin" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "wind", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 1, bezier = "liner" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "liner", style = "once" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "wind", style = "slidevert" })

-- Gestures
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
