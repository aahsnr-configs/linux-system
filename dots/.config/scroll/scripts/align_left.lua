-- first_window_align_left.lua
-- When the first tiling window opens in any workspace, align it to the
-- left edge of the screen.  Immediately restores reorder_auto so every
-- subsequent window continues to lay out normally.
--
-- NOTE: `scroll` is a global pre-injected by scroll's embedded Lua runtime.
-- Do NOT use require("scroll") — it is not a file module.

local function on_view_map(view, _)
  local container = scroll.view_get_container(view)
  if container == nil then
    return
  end

  local workspace = scroll.container_get_workspace(container)
  if workspace == nil then
    return
  end

  local tiling = scroll.workspace_get_tiling(workspace)

  if #tiling == 1 then
    scroll.command(nil, "align left; set_mode reorder_auto")
  end
end

scroll.add_callback("view_map", on_view_map, nil)
