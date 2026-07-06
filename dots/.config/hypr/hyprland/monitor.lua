-- hyprland/monitor.lua
hl.monitor({
	output = "HDMI-A-1",
	mode = "3840x2160@60",
	position = "0x0",
	scale = 2.0,
	bitdepth = 10,
	cm = "auto",
	sdrbrightness = 1.0,
	sdrsaturation = 1.0,
	supports_hdr = true,
	supports_wide_color = true,
	sdr_min_luminance = 0.005,
	sdr_max_luminance = 250,
	min_luminance = 0,
	max_luminance = 1000,
	max_avg_luminance = 500,
})
