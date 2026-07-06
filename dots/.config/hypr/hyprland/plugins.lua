-- hyprland/plugins.lua
hl.config({
	plugin = {
		hy3 = {
			tabs = {
				height = 22,
				padding = 6,
				render_text = true,
				from_top = false,
				radius = 6,
				border_width = 2,
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

