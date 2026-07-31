-- ~/.config/hypr/hyprland/unified-dispatch.lua
-- Native Lua replacement for unified-dispatch.py
-- Leverages Hyprland 0.55+ Lua API for zero-overhead layout-aware dispatching.

local M = {}

-- Fallback layout table matching your workspaces.lua definitions
local WS_LAYOUT = {
	[1] = "scrolling",
	[2] = "scrolling",
	[3] = "scrolling",
	[4] = "hy3",
	[5] = "hy3",
	[6] = "hy3",
	[7] = "master",
	[8] = "master",
	[9] = "monocle",
}

local function get_active_layout()
	-- Get the active special workspace if one is open, otherwise fallback to the regular active workspace [[32]]
	local ws = hl.get_active_special_workspace() or hl.get_active_workspace()
	if not ws then
		return "dwindle"
	end

	local layout = ws.tiled_layout

	-- Validate against known Hyprland layouts
	if layout == "scrolling" or layout == "dwindle" or layout == "master" or layout == "monocle" or layout == "hy3" then
		return layout
	end

	-- Fallback to static table if Hyprland returns null/empty or an unknown layout name
	return WS_LAYOUT[ws.id] or "dwindle"
end

function M.dispatch(action, direction)
	if direction ~= "l" and direction ~= "r" and direction ~= "u" and direction ~= "d" then
		print(string.format("Error: direction must be l, r, u, or d (got: %s)", tostring(direction)))
		return
	end

	local layout = get_active_layout()

	-- ACTION: FOCUS
	if action == "focus" then
		if layout == "scrolling" then
			hl.dispatch(hl.dsp.layout("focus " .. direction))
		elseif layout == "master" or layout == "monocle" then
			if direction == "r" or direction == "d" then
				hl.dispatch(hl.dsp.layout("cyclenext"))
			else
				hl.dispatch(hl.dsp.layout("cycleprev"))
			end
		else -- dwindle, hy3, and fallback
			hl.dispatch(hl.dsp.focus({ direction = direction }))
		end

		-- ACTION: MOVEWIN
	elseif action == "movewin" then
		if layout == "scrolling" then
			if direction == "l" then
				hl.dispatch(hl.dsp.layout("swapcol l"))
			elseif direction == "r" then
				hl.dispatch(hl.dsp.layout("swapcol r"))
			else
				hl.dispatch(hl.dsp.window.move({ direction = direction }))
			end
		elseif layout == "master" then
			if direction == "r" or direction == "d" then
				hl.dispatch(hl.dsp.layout("rollnext"))
			else
				hl.dispatch(hl.dsp.layout("rollprev"))
			end
		elseif layout == "monocle" then
			if direction == "r" or direction == "d" then
				hl.dispatch(hl.dsp.layout("cyclenext"))
			else
				hl.dispatch(hl.dsp.layout("cycleprev"))
			end
		else
			hl.dispatch(hl.dsp.window.move({ direction = direction }))
		end

		-- ACTION: RESIZE
	elseif action == "resize" then
		if layout == "scrolling" then
			if direction == "l" then
				hl.dispatch(hl.dsp.layout("colresize -0.05"))
			elseif direction == "r" then
				hl.dispatch(hl.dsp.layout("colresize +0.05"))
			elseif direction == "u" then
				hl.dispatch(hl.dsp.window.resize({ x = 0, y = -60, relative = true }))
			elseif direction == "d" then
				hl.dispatch(hl.dsp.window.resize({ x = 0, y = 60, relative = true }))
			end
		else
			if direction == "l" then
				hl.dispatch(hl.dsp.window.resize({ x = -60, y = 0, relative = true }))
			elseif direction == "r" then
				hl.dispatch(hl.dsp.window.resize({ x = 60, y = 0, relative = true }))
			elseif direction == "u" then
				hl.dispatch(hl.dsp.window.resize({ x = 0, y = -60, relative = true }))
			elseif direction == "d" then
				hl.dispatch(hl.dsp.window.resize({ x = 0, y = 60, relative = true }))
			end
		end
	else
		print(string.format("Error: unknown action '%s'", tostring(action)))
	end
end

return M
