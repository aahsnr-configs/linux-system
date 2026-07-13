--[[
  leftscroll.lua — a niri-style scrolling layout for Hyprland (0.55+ Lua config)

  Behavior:
    * Windows are arranged in COLUMNS on a horizontal tape, left -> right.
    * A lone window on an empty workspace opens flush against the LEFT edge
      of the screen — never centered. (This is the whole point.)
    * The camera never re-centers on focus like the native scrolling layout's
      focus_fit_method=0 can. It only scrolls the minimum distance needed to
      bring the focused column fully into view, snapping to whichever edge
      it's approaching — equivalent to niri's center-focused-column="never".
    * Columns can stack more than one window vertically (consume/expel),
      like niri's column stacking.
    * Per-column resizable width, with preset-width cycling.

  Usage:
    require("leftscroll")  -- from your hyprland.lua
    hl.config({ general = { layout = "lua:leftscroll" } })
    -- or per-workspace:
    -- hl.workspace_rule({ workspace = "2", layout = "lua:leftscroll" })

  Keybind wiring (put in your hyprland.lua, adjust mainMod as needed):
    local mainMod = "SUPER"
    hl.bind(mainMod .. " + H",         hl.dsp.layout("focus l"))
    hl.bind(mainMod .. " + L",         hl.dsp.layout("focus r"))
    hl.bind(mainMod .. " + K",         hl.dsp.layout("focus u"))
    hl.bind(mainMod .. " + J",         hl.dsp.layout("focus d"))
    hl.bind(mainMod .. " + SHIFT + H", hl.dsp.layout("movecol l"))
    hl.bind(mainMod .. " + SHIFT + L", hl.dsp.layout("movecol r"))
    hl.bind(mainMod .. " + SHIFT + K", hl.dsp.layout("movewin u"))
    hl.bind(mainMod .. " + SHIFT + J", hl.dsp.layout("movewin d"))
    hl.bind(mainMod .. " + MINUS",     hl.dsp.layout("resize -0.05"))
    hl.bind(mainMod .. " + EQUAL",     hl.dsp.layout("resize +0.05"))
    hl.bind(mainMod .. " + R",         hl.dsp.layout("resize +conf"))
    hl.bind(mainMod .. " + C",         hl.dsp.layout("consume"))
    hl.bind(mainMod .. " + X",         hl.dsp.layout("expel"))
    hl.bind(mainMod .. " + A",         hl.dsp.layout("consume_or_expel"))
    hl.bind(mainMod .. " + Z",         hl.dsp.layout("center"))  -- opt-in, one-off

  Known limitation: only a horizontal (left/right) tape is implemented.
  A vertical (up/down) tape would need mirroring x<->y throughout —
  left as an extension point, not included here to keep this maintainable.

  Unverified assumption (see the Geometry section below for details and a
  debug snippet): ctx.area's exact field names aren't documented anywhere
  we could confirm. This file auto-detects between the two most likely
  conventions and refuses to place windows (rather than crashing) if
  neither matches.
]]

-- ============================================================
-- Tunables
-- ============================================================
local CONFIG = {
	default_width = 0.5, -- fraction of work-area width for a new column
	min_width = 0.1,
	max_width = 1.0,
	width_step = 0.05, -- used by bare "resize +" / "resize -"
	width_presets = { 0.333, 0.5, 0.667, 1.0 }, -- cycled by resize +conf/-conf
	wrap_focus = false, -- wrap focus l/r and focus u/d at the ends of the tape/stack
}

-- ============================================================
-- Per-workspace state
--
-- ws = {
--   columns    = { { ids = {win_id, ...}, width = frac, focus = idx }, ... },
--   focusedCol = index into columns,
--   offset     = camera position in px along the tape (0 = leftmost column's
--                left edge sits at the work area's left edge),
-- }
--
-- Keyed by a best-effort workspace identity. ctx.workspace is NOT documented
-- by the wiki (only ctx.area / ctx.targets are), so we try a couple of
-- plausible spots and fall back to a single shared namespace if neither is
-- present. If your build exposes ctx.workspace.id, this picks it up
-- automatically and each workspace gets fully independent state. Test this
-- by opening the layout on two workspaces and checking their columns stay
-- independent; if they don't, that's your signal something here needs
-- adjusting for your build.
-- ============================================================

local workspaces = {}

-- Indexes obj[field] defensively; some Lua-bound userdata objects raise an
-- error on an unrecognized field instead of returning nil, so we don't
-- trust plain indexing here.
local function safe_get(obj, field)
	if obj == nil then
		return nil
	end
	local ok, val = pcall(function()
		return obj[field]
	end)
	if ok then
		return val
	end
	return nil
end

local function resolve_ws_key(ctx)
	local wsObj = safe_get(ctx, "workspace")
	if wsObj then
		local id = safe_get(wsObj, "id")
		if id then
			return "id:" .. tostring(id)
		end
		local name = safe_get(wsObj, "name")
		if name then
			return "name:" .. tostring(name)
		end
	end

	local t1 = ctx.targets and ctx.targets[1]
	local win = t1 and safe_get(t1, "window")
	if win then
		local wwsObj = safe_get(win, "workspace")
		if wwsObj then
			local id = safe_get(wwsObj, "id")
			if id then
				return "id:" .. tostring(id)
			end
			local name = safe_get(wwsObj, "name")
			if name then
				return "name:" .. tostring(name)
			end
		end
	end

	return "default" -- fallback: shared namespace across all workspaces using this layout
end

local function get_ws(key)
	local s = workspaces[key]
	if not s then
		-- lastActiveId is left nil here on purpose (see
		-- resync_focus_from_active): unset means "no baseline yet",
		-- so the first observed active window is accepted as-is.
		s = { columns = {}, focusedCol = 1, offset = 0, lastActiveId = nil }
		workspaces[key] = s
	end
	return s
end

-- ============================================================
-- Target/window identity helpers (same pattern as manual.lua)
-- ============================================================

local function target_id(target)
	local window = target.window
	return window and tostring(window.stable_id) or ("idx:" .. tostring(target.index))
end

-- Best-effort: try to move real input focus onto a window. The exact call
-- for "focus this specific window from a custom Lua layout" isn't confirmed
-- against current docs (see hyprwm/Hyprland discussion #13731, which is
-- specifically about this gap). Wrapped in pcall so a failure here never
-- breaks placement/resizing/etc. If it doesn't work on your build, check
-- `hl.dsp.window` in your LSP stubs (usually /usr/share/hypr/stubs/) for
-- the right call and patch this function.
local function try_focus_window(win)
	if not win then
		return
	end
	pcall(function()
		if win.address then
			hl.dispatch(hl.dsp.window.focus({ window = "address:" .. tostring(win.address) }))
		end
	end)
end

-- ============================================================
-- Sync: reconcile ws.columns against the live ctx.targets list.
-- Closed windows are dropped (and emptied columns removed). Brand-new
-- windows become their own new column, inserted right after the currently
-- focused column (or as column 1 if the workspace was empty) and focused —
-- this is what makes a lone new window land flush-left, and what makes
-- subsequent windows open to the right of whatever's focused, niri-style.
-- ============================================================

local function sync(ctx, ws)
	local targetsById, present = {}, {}
	for _, t in ipairs(ctx.targets) do
		local id = target_id(t)
		targetsById[id] = t
		present[id] = true
	end

	-- Drop closed windows; drop columns left empty
	local kept = {}
	for _, col in ipairs(ws.columns) do
		local keptIds = {}
		for _, id in ipairs(col.ids) do
			if present[id] then
				table.insert(keptIds, id)
			end
		end
		if #keptIds > 0 then
			col.ids = keptIds
			if col.focus > #keptIds then
				col.focus = #keptIds
			end
			table.insert(kept, col)
		end
	end
	ws.columns = kept
	if ws.focusedCol > #ws.columns then
		ws.focusedCol = #ws.columns
	end
	if ws.focusedCol < 1 and #ws.columns > 0 then
		ws.focusedCol = 1
	end

	local tracked = {}
	for _, col in ipairs(ws.columns) do
		for _, id in ipairs(col.ids) do
			tracked[id] = true
		end
	end

	-- Insert brand-new windows as their own column after the focused one
	for _, t in ipairs(ctx.targets) do
		local id = target_id(t)
		if not tracked[id] then
			local newCol = { ids = { id }, width = CONFIG.default_width, focus = 1 }
			local insertAt = (#ws.columns == 0) and 1 or (ws.focusedCol + 1)
			table.insert(ws.columns, insertAt, newCol)
			ws.focusedCol = insertAt
			tracked[id] = true
		end
	end

	return targetsById
end

-- Keep our internal focus pointer in sync with real input focus, but only
-- when it actually CHANGES (edge-triggered), not on every recalculate
-- (level-triggered). This matters a lot: if try_focus_window()'s dispatch
-- call doesn't actually move real input focus on a given build (see the
-- caveat on that function — this is a genuinely unverified part of the
-- API), a level-triggered version would snap focusedCol back to wherever
-- real focus still is on the very next recalculate, silently erasing every
-- focus l/r/u/d command's effect. Edge-triggering means: if real focus
-- hasn't moved since we last checked, we leave our own layout_msg-driven
-- state alone and the camera/column focus still follows commands even if
-- the "make Hyprland actually focus this window" call is a no-op — a
-- graceful degradation instead of a silent revert. Genuine out-of-band
-- changes (e.g. a mouse click) are still picked up correctly, because
-- those DO change which window Hyprland reports as active.
-- Caught by running the layout through a scripted mock harness that
-- stubs the dispatch call as a no-op — i.e. the worst case for this —
-- not just by reading the code.
local function resync_focus_from_active(ctx, ws)
	for _, t in ipairs(ctx.targets) do
		local w = t.window
		if w and w.active then
			local id = target_id(t)
			if id == ws.lastActiveId then
				return -- no real change since last check; don't fight our own state
			end
			ws.lastActiveId = id
			for ci, col in ipairs(ws.columns) do
				for wi, wid in ipairs(col.ids) do
					if wid == id then
						ws.focusedCol = ci
						col.focus = wi
						return
					end
				end
			end
			return
		end
	end
end

-- ============================================================
-- Geometry
--
-- IMPORTANT / unverified assumption: the wiki documents that ctx.area is
-- "the work area" but never documents its field names, and none of the
-- four example layouts ever read ctx.area's fields directly — they only
-- ever pass it opaquely into ctx:split/column/grid_cell. Since a scrolling
-- tape fundamentally needs to place columns OUTSIDE the current visible
-- area (off-screen, at negative or overflowing x), and ctx:split can only
-- ever carve pieces WITHIN the area it's given, manual box construction is
-- unavoidable here — so this is the one place we have to guess a shape.
--
-- resolve_box_shape() below probes for the two most likely conventions the
-- first time it sees a real ctx.area, and recalculate() skips placement
-- entirely (rather than crashing) if neither matches. If your windows
-- aren't moving at all, temporarily add this at the top of recalculate()
-- to see the real field names and extend resolve_box_shape() accordingly:
--   for k, v in pairs(ctx.area) do hl.print(tostring(k), tostring(v)) end
-- ============================================================

local box_get, box_make -- filled in lazily by resolve_box_shape()

local function resolve_box_shape(a)
	local function n(v)
		return type(v) == "number" and v or nil
	end

	if n(a.x) and n(a.y) and n(a.w) and n(a.h) then
		box_get = function(b)
			return b.x, b.y, b.w, b.h
		end
		box_make = function(x, y, w, h)
			return { x = x, y = y, w = w, h = h }
		end
		return true
	end

	if n(a.x) and n(a.y) and n(a.width) and n(a.height) then
		box_get = function(b)
			return b.x, b.y, b.width, b.height
		end
		box_make = function(x, y, w, h)
			return { x = x, y = y, width = w, height = h }
		end
		return true
	end

	return false
end

local function column_px_width(col, areaW)
	return math.max(1, col.width * areaW)
end

-- x offset (tape space) of the LEFT edge of column `index`
local function tape_offset(ws, areaW, index)
	local x = 0
	for i = 1, index - 1 do
		x = x + column_px_width(ws.columns[i], areaW)
	end
	return x
end

-- "Never center": scroll the minimum amount needed to bring the focused
-- column fully into view, snapping to whichever edge it's approaching.
-- A lone/first column always ends up flush-left through this same rule —
-- its tape offset is 0, so either the edge-snap step pulls the camera to 0,
-- or (if it's already there) the final clamp below forces maxOffset to 0
-- anyway, since a single column's width can never exceed the viewport.
-- No special-casing needed; verified both paths independently converge.
local function clamp_camera_to_focused(ws, areaW)
	if #ws.columns == 0 then
		ws.offset = 0
		return
	end

	local col = ws.columns[ws.focusedCol]
	local colX = tape_offset(ws, areaW, ws.focusedCol)
	local colW = column_px_width(col, areaW)

	local viewLeft, viewRight = ws.offset, ws.offset + areaW
	if colX < viewLeft then
		ws.offset = colX
	elseif colX + colW > viewRight then
		ws.offset = colX + colW - areaW
	end

	local tapeWidth = tape_offset(ws, areaW, #ws.columns + 1)
	local maxOffset = math.max(0, tapeWidth - areaW)
	ws.offset = math.max(0, math.min(ws.offset, maxOffset))
end

-- Opt-in, one-off centering (bind to a key if you want it available as an
-- escape hatch — it is NOT applied automatically, unlike native
-- focus_fit_method=0).
local function center_focused(ws, areaW)
	local col = ws.columns[ws.focusedCol]
	if not col then
		return
	end
	local colX = tape_offset(ws, areaW, ws.focusedCol)
	local colW = column_px_width(col, areaW)
	ws.offset = colX + colW / 2 - areaW / 2
	local tapeWidth = tape_offset(ws, areaW, #ws.columns + 1)
	local maxOffset = math.max(0, tapeWidth - areaW)
	ws.offset = math.max(0, math.min(ws.offset, maxOffset))
end

-- ============================================================
-- Placement: lay columns left-to-right; stack each column's windows
-- evenly, top-to-bottom, using plain arithmetic (deliberately NOT routed
-- through ctx:split — see the Geometry note above on why hand-built boxes
-- shouldn't be assumed to round-trip through it).
-- ============================================================

local function place_columns(ws, targetsById, ax, ay, aw, ah)
	local x = ax - ws.offset

	for _, col in ipairs(ws.columns) do
		local w = column_px_width(col, aw)
		local n = #col.ids

		if n == 1 then
			local t = targetsById[col.ids[1]]
			if t then
				t:place(box_make(x, ay, w, ah))
			end
		else
			local slotH = ah / n
			for j, id in ipairs(col.ids) do
				local t = targetsById[id]
				if t then
					t:place(box_make(x, ay + (j - 1) * slotH, w, slotH))
				end
			end
		end

		x = x + w
	end
end

-- ============================================================
-- Structural operations
-- ============================================================

local function focus_col(ws, dir)
	local n = #ws.columns
	if n == 0 then
		return
	end
	local j = ws.focusedCol + dir
	if CONFIG.wrap_focus then
		j = ((j - 1) % n) + 1
	else
		j = math.max(1, math.min(n, j))
	end
	ws.focusedCol = j
end

local function focus_in_col(ws, dir)
	local col = ws.columns[ws.focusedCol]
	if not col then
		return
	end
	local n = #col.ids
	local j = col.focus + dir
	if CONFIG.wrap_focus then
		j = ((j - 1) % n) + 1
	else
		j = math.max(1, math.min(n, j))
	end
	col.focus = j
end

local function move_col(ws, dir)
	local i = ws.focusedCol
	local j = i + dir
	if j < 1 or j > #ws.columns then
		return
	end
	ws.columns[i], ws.columns[j] = ws.columns[j], ws.columns[i]
	ws.focusedCol = j
end

local function move_win_in_col(ws, dir)
	local col = ws.columns[ws.focusedCol]
	if not col then
		return
	end
	local i = col.focus
	local j = i + dir
	if j < 1 or j > #col.ids then
		return
	end
	col.ids[i], col.ids[j] = col.ids[j], col.ids[i]
	col.focus = j
end

local function resize_focused(ws, arg)
	local col = ws.columns[ws.focusedCol]
	if not col then
		return true
	end -- nothing focused; harmless no-op
	if not arg or arg == "" then
		return false, "leftscroll: resize expects +conf, -conf, +, -, +N, -N, or N"
	end

	if arg == "+conf" or arg == "-conf" then
		local presets = CONFIG.width_presets
		local idx = 1
		for i, v in ipairs(presets) do
			if math.abs(v - col.width) < 0.001 then
				idx = i
				break
			end
		end
		if arg == "+conf" then
			idx = (idx % #presets) + 1
		else
			idx = ((idx - 2) % #presets) + 1
		end
		col.width = presets[idx]
		return true
	end

	if arg == "+" or arg == "-" then
		col.width = col.width + (arg == "+" and CONFIG.width_step or -CONFIG.width_step)
	else
		local num = tonumber(arg)
		if not num then
			return false, "leftscroll: resize got a non-numeric argument '" .. arg .. "'"
		end
		if arg:match("^[+-]") then
			col.width = col.width + num
		else
			col.width = num
		end
	end

	col.width = math.max(CONFIG.min_width, math.min(CONFIG.max_width, col.width))
	return true
end

-- Move the currently-focused-within-column WINDOW (not the whole column)
-- into the previous column's stack — matches the native scrolling layout's
-- "consume" semantics (moves current window into previous column). The
-- source column is only removed if this empties it.
local function consume(ws)
	if ws.focusedCol < 2 then
		return
	end
	local cur = ws.columns[ws.focusedCol]
	local prev = ws.columns[ws.focusedCol - 1]
	if not cur or not prev then
		return
	end

	local id = table.remove(cur.ids, cur.focus)
	if cur.focus > #cur.ids then
		cur.focus = math.max(1, #cur.ids)
	end

	table.insert(prev.ids, id)
	prev.focus = #prev.ids

	if #cur.ids == 0 then
		table.remove(ws.columns, ws.focusedCol)
	end
	ws.focusedCol = ws.focusedCol - 1
end

-- Pop the focused-within-column window out into its own new column,
-- placed immediately to the right of its old column. No-op on a column
-- that's already solo (nothing to pull out).
local function expel(ws)
	local col = ws.columns[ws.focusedCol]
	if not col or #col.ids <= 1 then
		return
	end
	local id = table.remove(col.ids, col.focus)
	if col.focus > #col.ids then
		col.focus = #col.ids
	end
	local newCol = { ids = { id }, width = CONFIG.default_width, focus = 1 }
	table.insert(ws.columns, ws.focusedCol + 1, newCol)
	ws.focusedCol = ws.focusedCol + 1
end

-- Convenience matching native scrolling layout parity: expel if the
-- focused column has more than one window, consume otherwise.
local function consume_or_expel(ws)
	local col = ws.columns[ws.focusedCol]
	if not col then
		return
	end
	if #col.ids > 1 then
		expel(ws)
	else
		consume(ws)
	end
end

-- ============================================================
-- layout_msg: command surface, bound via hl.dsp.layout("...")
-- ============================================================

local function focused_window_target(ctx, ws)
	local col = ws.columns[ws.focusedCol]
	if not col then
		return nil
	end
	local id = col.ids[col.focus]
	for _, t in ipairs(ctx.targets) do
		if target_id(t) == id then
			return t
		end
	end
	return nil
end

local function handle_msg(ctx, ws, msg)
	if not msg or msg == "" then
		return "leftscroll: no command given"
	end

	local cmd, rest = msg:match("^(%S*)%s*(.*)$")

	if cmd == "focus" then
		if rest == "l" then
			focus_col(ws, -1)
		elseif rest == "r" then
			focus_col(ws, 1)
		elseif rest == "u" then
			focus_in_col(ws, -1)
		elseif rest == "d" then
			focus_in_col(ws, 1)
		else
			return "leftscroll: focus expects l, r, u, or d"
		end
		local t = focused_window_target(ctx, ws)
		if t then
			try_focus_window(t.window)
		end
	elseif cmd == "movecol" then
		if rest == "l" then
			move_col(ws, -1)
		elseif rest == "r" then
			move_col(ws, 1)
		else
			return "leftscroll: movecol expects l or r"
		end
	elseif cmd == "movewin" then
		if rest == "u" then
			move_win_in_col(ws, -1)
		elseif rest == "d" then
			move_win_in_col(ws, 1)
		else
			return "leftscroll: movewin expects u or d"
		end
	elseif cmd == "resize" then
		local ok, err = resize_focused(ws, rest)
		if not ok then
			return err
		end
	elseif cmd == "consume" then
		consume(ws)
	elseif cmd == "expel" then
		expel(ws)
	elseif cmd == "consume_or_expel" then
		consume_or_expel(ws)
	elseif cmd == "center" then
		if box_get and ctx.area then
			local _, _, aw = box_get(ctx.area)
			if aw then
				center_focused(ws, aw)
			end
		end
	else
		return "leftscroll: unknown command '" .. tostring(cmd) .. "'"
	end

	return true
end

-- ============================================================
-- Registration
-- ============================================================

hl.layout.register("leftscroll", {
	recalculate = function(ctx)
		if not ctx.targets or #ctx.targets == 0 then
			return
		end
		if not ctx.area then
			return
		end
		if not box_get and not resolve_box_shape(ctx.area) then
			return -- unrecognized area shape; see Geometry section note above
		end

		local ax, ay, aw, ah = box_get(ctx.area)
		if not (ax and ay and aw and ah) then
			return
		end

		local ws = get_ws(resolve_ws_key(ctx))
		local targetsById = sync(ctx, ws)
		resync_focus_from_active(ctx, ws)
		clamp_camera_to_focused(ws, aw)
		place_columns(ws, targetsById, ax, ay, aw, ah)
	end,

	layout_msg = function(ctx, msg)
		local ws = get_ws(resolve_ws_key(ctx))
		return handle_msg(ctx, ws, msg)
	end,
})
