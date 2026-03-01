-- ============================================================
-- init.lua — Yazi Lua Configuration
-- Version: 26.x  |  Updated: 2026-02
-- ============================================================

-- ── Core Plugins ─────────────────────────────────────────────

-- Full border around all three panels (yazi-rs/plugins:full-border)
require("full-border"):setup()

-- Starship prompt in the header bar (Rolv-Apneseth/starship)
require("starship"):setup()

-- Git file status (yazi-rs/plugins:git)
-- Note: also requires [plugin.prepend_fetchers] entries in yazi.toml
require("git"):setup()

-- ── Bunny Bookmarks (stelcodes/bunny) ────────────────────────
-- Trigger: "zh" in the manager (mapped in keymap.toml)
require("bunny"):setup({
    hops = {
        { key = "~",  path = "~",              desc = "Home" },
        { key = "d",  path = "~/Downloads",    desc = "Downloads" },
        { key = "D",  path = "~/Desktop",      desc = "Desktop" },
        { key = ".",  path = "~/dotfiles",     desc = "Dotfiles" },
        { key = "c",  path = "~/.config",      desc = "~/.config" },
        { key = "p",  path = "~/Pictures",     desc = "Pictures" },
        { key = "P",  path = "~/Projects",     desc = "Projects" },
        { key = "v",  path = "~/Videos",       desc = "Videos" },
        { key = "m",  path = "~/Music",        desc = "Music" },
        { key = "t",  path = "/tmp",           desc = "/tmp" },
        { key = "/",  path = "/",              desc = "Root (/)" },
        { key = "e",  path = "/etc",           desc = "/etc" },
        { key = "M",  path = "/run/media",     desc = "Media mounts" },
    },
})

-- ── Custom Header: "user@host:" prefix ───────────────────────
-- Prepends "user@host:" in blue to the left of the header bar.
Header:children_add(function()
    if ya.target_family() ~= "unix" then
        return ui.Line {}
    end
    return ui.Span(ya.user_name() .. "@" .. ya.host_name() .. ":"):fg("blue")
end, 500, Header.LEFT)

-- ── Custom Status: filename + symlink arrow ───────────────────
-- Shows "filename -> target" in the status bar for symlinks.
function Status:name()
    local h = self._tab.current.hovered
    if not h then
        return ui.Line {}
    end

    local linked = ""
    if h.link_to ~= nil then
        linked = " -> " .. tostring(h.link_to)
    end
    return ui.Line(" " .. h.name .. linked)
end

-- ── Custom Status: size + mtime combined linemode ─────────────
-- Enable with:  linemode = "size_and_mtime"  in yazi.toml [mgr],
-- or toggle at runtime with:  linemode size_and_mtime  (. s by default)
function Linemode:size_and_mtime()
    local time = math.floor(self._file.cha.mtime or 0)
    if time == 0 then
        time = ""
    elseif os.date("%Y", time) == os.date("%Y") then
        time = os.date("%b %d %H:%M", time)
    else
        time = os.date("%b %d  %Y", time)
    end

    local size = self._file:size()
    return string.format(
        "%s  %s",
        size and ya.readable_size(size) or "  -  ",
        time
    )
end
