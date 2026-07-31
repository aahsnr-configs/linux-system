-- Monitor configuration
-- Verified: wiki.hypr.land/Configuring/Basics/Monitors/ (July 24, 2026)

hl.monitor({
	output = "HDMI-A-5",
	mode = "3840x2160@60",
	position = "0x0",
	scale = 2.0,
	-- bitdepth = 10,
	-- cm = "auto",
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
