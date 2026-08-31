-- Shared variables accessible across all modules via require("hyprland/vars")
-- In hyprlang, $variables were global across sourced files.
-- In Lua, locals are file-scoped, so we export them via a returned table.

local M = {}

M.terminal = "kitty"
M.browser = "brave"
M.guifm = "thunar"
M.editor = "emacsclient -c -a 'emacs'"
M.ipc = "noctalia msg "
M.screenshot = "~/bin/screenshot"
M.pypr = "/usr/bin/pypr-client"
M.mainMod = "SUPER"

return M
