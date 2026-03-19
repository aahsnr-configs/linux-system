-- scratchpad_anim.lua
-- Per-scratchpad directional slide animation (fromTop / fromBottom) for scroll.
-- Also demonstrates Option B: temporarily swapping the global window_move_float
-- curve so scratchpads and regular popup windows each get their own curve.
--
-- Place at:  ~/.config/scroll/scripts/scratchpad_anim.lua
-- Load with: lua $lua_scripts/scratchpad_anim.lua
--            ($lua_scripts must be defined in config BEFORE this line as:
--             set $lua_scripts ~/.config/scroll/scripts)

-- ── Standard header for all config-loaded scripts (discussion #48 pattern) ──
local args, state = ...

-- ── scroll is registered in package.loaded at compositor startup.         ──
-- ── require("scroll") is the correct, confirmed pattern from discussion    ──
-- ── #48 (center.lua, center-focused-column.lua, workspace.lua, etc).      ──
local scroll = require("scroll")


-- ══════════════════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ══════════════════════════════════════════════════════════════════════════

-- Which scratchpad gets which slide direction.
-- Keys are app_ids from your rules.conf / autostart.conf.
local ANIMATIONS = {
    scratch_term    = "fromTop",
    scratch_yazi    = "fromBottom",
    scratch_lazygit = "fromTop",
}

-- Distance in pixels to slide from off-screen.
-- 3000 is safely beyond any monitor regardless of resolution or orientation.
local SLIDE_DISTANCE = 3000

-- The window_move_float curve used ONLY during a scratchpad slide.
local SCRATCHPAD_CURVE = "yes 350 var simple [ 0.16 1.0 0.3 1.0 ]"

-- The window_move_float curve for ALL OTHER floating windows.
-- Must match the value in settings.conf.
local GLOBAL_CURVE = "yes 250 var simple [ 0.05 0.9 0.1 1.05 ]"


-- ══════════════════════════════════════════════════════════════════════════
-- STATE
-- ══════════════════════════════════════════════════════════════════════════

-- Weak-key table keyed on view userdata objects.
--
-- WHY WEAK KEYS INSTEAD OF PIDs:
--   scroll.view_get_pid() is not a confirmed API in discussion #48.
--   Keying on the view object itself is the idiomatic Lua approach and
--   fully supported by the scroll Lua API.
--
-- Lifecycle:
--   * First view_map  (initial launch) -> entry added; animation skipped.
--     The for_window rule in rules.conf handles placement (float/resize/
--     center/move scratchpad). We must not interfere here.
--   * Subsequent view_map (scratchpad show, user pressed toggle key)
--     -> entry already exists -> slide animation fires.
--   * App killed -> C side destroys the view; Lua GC eventually collects
--     the userdata; the weak-key entry disappears automatically.
--   * App relaunched -> brand-new view userdata object -> not in table
--     -> treated as first launch again (no animation, rules.conf runs).
--
-- setmetatable(__mode = "k") enables weak keys.
local seen_views = setmetatable({}, { __mode = "k" })


-- ══════════════════════════════════════════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════════════════════════════════════════

-- Run a scroll command against a container.
-- Uses print() for logging -- scroll.log() is not a confirmed API function.
local function cmd(container, command_str)
    local results = scroll.command(container, command_str)
    if type(results) == "table" then
        for _, r in ipairs(results) do
            if type(r) == "string" and #r > 0 then
                print("[scratchpad_anim] cmd('" .. command_str .. "'): " .. r)
            end
        end
    end
end

-- Temporarily swap the global window_move_float animation curve.
local function set_float_curve(curve)
    local results = scroll.command(nil,
        "animations { window_move_float " .. curve .. " }")
    if type(results) == "table" then
        for _, r in ipairs(results) do
            if type(r) == "string" and #r > 0 then
                print("[scratchpad_anim] set_float_curve: " .. r)
            end
        end
    end
end


-- ══════════════════════════════════════════════════════════════════════════
-- ON WINDOW MAP
-- Fires every time a window becomes visible (including scratchpad show).
-- ══════════════════════════════════════════════════════════════════════════

local function on_view_map(view, _)
    -- 1. Guard: only act on our scratchpad app_ids.
    local app_id = scroll.view_get_app_id(view)
    if not app_id then return end

    local direction = ANIMATIONS[app_id]
    if not direction then return end

    -- 2. Guard: confirm view is actually mapped/visible right now.
    --    scroll.view_mapped() is confirmed in discussion #48 (BlueInGreen68
    --    view-count script, Jan 2026 update by dawsers).
    if not scroll.view_mapped(view) then return end

    -- 3. First time we see this view object = initial launch from autostart.conf.
    --    Record it and return -- let the for_window rule do its job.
    if not seen_views[view] then
        seen_views[view] = true
        return
    end

    -- 4. Same view object appearing again = scratchpad show.
    local con = scroll.view_get_container(view)
    if not con then return end

    -- OPTION B: CURVE SWAP
    -- Replace the global window_move_float curve with the scratchpad-specific
    -- one BEFORE the three-step move commands. All three commands run
    -- synchronously in this callback before scroll renders a single frame,
    -- so SCRATCHPAD_CURVE is already active when the animation object for
    -- step 3 is created. Restore GLOBAL_CURVE immediately after step 3.

    set_float_curve(SCRATCHPAD_CURVE)

    -- THREE-STEP SLIDE TECHNIQUE
    --
    -- Step 1: Snap to horizontal center.
    --         Ensures X = center_x so step 2 only affects Y.
    cmd(con, "move position center")

    -- Step 2: Teleport off-screen VERTICALLY by a RELATIVE move.
    --         `move up/down N px` shifts relative to current position,
    --         so X stays at center_x.
    if direction == "fromTop" then
        cmd(con, "move up "   .. SLIDE_DISTANCE .. " px")
    else
        cmd(con, "move down " .. SLIDE_DISTANCE .. " px")
    end

    -- Step 3: Move back to center.
    --         scroll animates from the off-screen position to center using
    --         SCRATCHPAD_CURVE. This is the visible slide-in.
    cmd(con, "move position center")

    -- RESTORE GLOBAL CURVE
    -- Step 3's animation object has already captured SCRATCHPAD_CURVE, so
    -- restoring here does not affect the ongoing slide. All future floating
    -- window moves will use GLOBAL_CURVE again.

    set_float_curve(GLOBAL_CURVE)
end


-- ══════════════════════════════════════════════════════════════════════════
-- REGISTER CALLBACK
-- ══════════════════════════════════════════════════════════════════════════

-- No on_view_unmap needed: the weak-key table automatically drops entries
-- when the view userdata is garbage-collected after the app is killed.
-- A relaunched app always gets a fresh view object -> treated as first launch.

scroll.add_callback("view_map", on_view_map, nil)
