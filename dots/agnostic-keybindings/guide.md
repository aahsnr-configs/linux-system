Good. Now I have everything confirmed:

- swhkd's `@` and `~` are verified supported in the actual codebase
- swhkd has a native **mode system** (`@enter`, `swallow oneoff`) that can handle chord sequences without xremap
- xremap v0.14.18 (March 2026) handles sequences via nested `remap:` + `timeout_millis`
- kanata supports `btn-right` + `(cmd ...)` with `danger-enable-cmd yes`

Here is the clean division with zero binding overlap:

- **swhkd** → all app launches, media keys, system controls, transparency, bar
- **xremap** → all BSPWM window management **and** the `super + n ; ...` chord sequences
- **kanata** → mouse right-click context menuHere are the three files, with every binding from the gh0stzk sxhkdrc covered. Here's the exact division of labor and what's verified:

---

### How it's split (zero binding overlap)

**swhkd** (`~/.config/swhkd/swhkdrc`) — all application launching, rofi applets, system power commands, bar hide/show, picom transparency, all XF86/media hardware keys, and swhkd reload. The `@` prefix (run on key release) and `~` prefix (pass-through) are both confirmed supported — used for `super + @space` and `alt + @space`.

**xremap** (`~/.config/xremap/config.yml`) — all BSPWM window management: close/kill, node states, node flags, hide/restore, rotate, workspace switching, focus/swap direction, preselect, balance, resize, move floating — plus the `super + n ; {x,k,m,1-9}` chord sequences via xremap's nested `remap:` + `timeout_millis: 2000`. xremap v0.14.18 was released March 8, 2026 and is actively maintained.

**kanata** (`~/.config/kanata/kanata.kbd`) — the `~button3` right-click binding, replicated with `(multi btn-right (cmd bash -c "rofi -show drun &"))`. The file has detailed inline comments explaining exactly what cannot be ported (`xdotool`, `xprop`, `jgmenu`, and desktop-window detection are all X11-only) and lists `nwg-menu` as the closest Wayland-native equivalent to jgmenu.

---

### One thing to do before using kanata

Replace `YOUR-MOUSE-DEVICE-event-mouse` in `kanata.kbd` with your actual device path:

```bash
ls /dev/input/by-id/ | grep -i mouse
```
