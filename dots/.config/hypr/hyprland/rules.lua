-- hyprland/rules.lua

-- Window Rules
hl.window_rule({ name = "ghostty_opacity", match = { class = [[^(com\.mitchellh\.ghostty)$]] }, opacity = "0.95 0.95" })
hl.window_rule({
	name = "kitty_floating",
	match = { class = [[^(kitty-dropterm)$]] },
	size = { "70%", "70%" },
	float = true,
	animation = "slidein",
})
hl.window_rule({
	name = "yazi_floating",
	match = { class = [[^(explorer)$]] },
	size = { "90%", "90%" },
	float = true,
	animation = "slidein",
})
hl.window_rule({
	name = "nautilus_floating",
	match = { class = [[^(org\.gnome\.Nautilus)$]] },
	float = true,
	animation = "popin",
	size = { 1000, 800 },
})
hl.window_rule({
	name = "bleachbit_floating",
	match = { class = [[^(org\.bleachbit\.BleachBit)$]] },
	float = true,
	animation = "popin",
	size = { 600, 600 },
	no_blur = true,
	no_anim = true,
})
hl.window_rule({
	name = "thunar_floating",
	match = { class = [[^(thunar)$]] },
	float = true,
	animation = "popin",
	size = { 800, 600 },
})
hl.window_rule({
	name = "Thunar-Progress-bar",
	match = { class = [[^(thunar)$]], title = [[^(File Operation Progress)$]] },
	float = true,
	center = true,
	move = { "cursor_x-(window_w*0.05)", "cursor_y-(window_h*0.6)" },
	size = { "(monitor_w*0.26)", "(monitor_h*0.18)" },
})
hl.window_rule({
	name = "qt5ct_floating",
	match = { class = [[^(qt5ct)$]] },
	float = true,
	center = true,
	size = { 800, 600 },
})
hl.window_rule({
	name = "qt6ct_floating",
	match = { class = [[^(qt6ct)$]] },
	float = true,
	center = true,
	size = { 800, 600 },
})
hl.window_rule({
	name = "nwg_look",
	match = { class = [[^(nwg-look)$]] },
	float = true,
	center = true,
	size = { 600, 400 },
})

hl.window_rule({
	name = "google_signin_popup",
	match = { class = [[^(brave-browser)$]], title = [[^(Untitled - Brave)$]] },
	float = true,
	size = { 450, 600 },
	move = { "cursor_x-(window_w*0.5)", "cursor_y-(window_h*0.5)" },
	no_blur = true,
	no_anim = true,
})
hl.window_rule({
	name = "bitwarden_popup",
	match = {
		class = [[^(brave-nngceckbapebfimnlniiiahkandclblb-Default)$]],
		title = [[^(_crx_nngceckbapebfimnlniiiahkandclblb)$]],
	},
	float = true,
	size = { 450, 600 },
	move = { "cursor_x-(window_w*0.5)", "cursor_y-(window_h*0.5)" },
	no_blur = true,
	no_anim = true,
})
hl.window_rule({
	name = "xdg_desktop_portal_gtk",
	match = { class = [[^(xdg-desktop-portal-gtk)$]] },
	size = { 600, 600 },
	float = true,
	move = { "cursor_x-(window_w*0.05)", "cursor_y-(window_h*0.6)" },
	no_blur = true,
})

hl.window_rule({ match = { float = true, xwayland = false }, center = true })

hl.window_rule({ match = { class = [[org\.gnome\.FileRoller]] }, float = true })
hl.window_rule({ match = { class = [[file-roller]] }, float = true })
hl.window_rule({ match = { class = [[imv]] }, float = true })
hl.window_rule({ match = { class = [[system-config-printer]] }, float = true })
hl.window_rule({ match = { class = [[CachyOSHello]] }, float = true })

hl.window_rule({ match = { class = [[org\.pulseaudio\.pavucontrol|yad-icon-browser]] }, float = true })
hl.window_rule({ match = { class = [[org\.pulseaudio\.pavucontrol|yad-icon-browser]] }, size = { "60%", "70%" } })
hl.window_rule({ match = { class = [[org\.pulseaudio\.pavucontrol|yad-icon-browser]] }, center = true })

hl.window_rule({ match = { title = [[(Select|Open)( a)? (File|Folder)(s)?]] }, float = true })
hl.window_rule({ match = { title = [[File (Operation|Upload)( Progress)?]] }, float = true })
hl.window_rule({ match = { title = [[.* Properties]] }, float = true })
hl.window_rule({ match = { title = [[Export Image as PNG]] }, float = true })
hl.window_rule({ match = { title = [[GIMP Crash Debug]] }, float = true })
hl.window_rule({ match = { title = [[Save As]] }, float = true })
hl.window_rule({ match = { title = [[Library]] }, float = true })

hl.window_rule({
	name = "Picture-in-Picture",
	match = { title = [[^(Picture-in-Picture)$]] },
	float = true,
	move = { "72%", "7%" },
	opacity = "0.95 0.75",
	pin = true,
	keep_aspect_ratio = true,
	size = { "(monitor_w*0.3)", "(monitor_h*0.3)" },
})

hl.window_rule({ match = { xwayland = true, title = [[win[0-9]+]] }, no_dim = true })
hl.window_rule({ match = { xwayland = true, title = [[win[0-9]+]] }, no_shadow = true })
hl.window_rule({ match = { xwayland = true, title = [[win[0-9]+]] }, rounding = 10 })

-- Layer Rules
hl.layer_rule({
	name = "noctalia",
	match = { namespace = [[noctalia-background-.*$]] },
	ignore_alpha = 0.5,
	blur = true,
	blur_popups = true,
})
hl.layer_rule({
	name = "blur_layers",
	match = { namespace = [[^(rofi|notifications|quickshell:.*)$]] },
	blur = true,
	ignore_alpha = true,
})
hl.layer_rule({ match = { namespace = [[gtk4-layer-shell]] }, no_anim = true })

-- Workspace Rules
hl.workspace_rule({
	workspace = "special:exposed",
	gaps_out = 60,
	gaps_in = 30,
	border_size = 5,
	no_border = false,
	no_shadow = true,
})
