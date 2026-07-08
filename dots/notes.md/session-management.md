---
---

---

Here's a complete, current (mid‑2026) setup for getting as close as possible to macOS/Windows-style "resume where I left off" on Hyprland, tailored to your kitty + pyprland scratchpad workflow. A few things changed recently that affect this directly, so I've folded them in.

## Reality check first

There's no native Wayland "session restore" protocol that apps implement yet, so nothing on Hyprland will be pixel-perfect like macOS. What you _can_ get, by combining three separate tools at three separate layers, is genuinely close:

| Layer               | Handles                                     | Tool                                     |
| ------------------- | ------------------------------------------- | ---------------------------------------- |
| GUI windows         | Position, workspace, monitor, relaunch      | **hyprflow**                             |
| TUI apps / shells   | Actual running processes, panes, scrollback | **zellij** (built-in resurrection)       |
| Scratchpad plumbing | Toggling, lazy-spawn, animations            | **pyprland** (unchanged, just repointed) |

One more thing worth knowing before you configure anything: **Hyprland 0.55 (May 2026) replaced hyprlang with a Lua config** (`~/.config/hypr/hyprland.lua`). Hyprlang still works for now but is deprecated and frozen. I'll give both syntaxes below — check your version with `hyprctl version`.

---

## Layer 1 — GUI window restore: hyprflow

Of the several community session-savers (hyprsession, hyprland-session-saver, hypr-session-restore), **hyprflow** is the most complete/maintained as of now — AUR-packaged, systemd-timer autosave, staleness protection, and it already has kitty-aware handling.

```bash
yay -S hyprflow
```

Config at `~/.config/hyprflow/config.toml`:

```toml
[general]
default_session = "latest"
restore_delay_ms = 800          # give waybar/pypr time to init first
window_detect_timeout_ms = 8000
autosave_retain = 5

[filters]
ignore_classes = ["waybar", "wofi", "mako", "polkit", "nm-applet",
                   "xdg-desktop-portal", "kitty-dropterm"]   # <- exclude your scratchpad, see Layer 3

[apps.kitty]
binary = "kitty"
capture_cwd = true
capture_last_command = true
```

**Important:** add every pyprland scratchpad `class` to `ignore_classes`. Scratchpad windows are lazily spawned by pypr on demand — if hyprflow also tries to relaunch them at boot, you'll get duplicates fighting over the same window class.

Autosave + boot restore:

```bash
hyprflow autosave --install          # systemd --user timer, saves every 10 min
```

**Lua config (0.55+)** — in your startup hook file:

```lua
hl.on("hyprland.start", function()
  hl.exec_cmd("waybar & pypr")
  hl.exec_cmd("sleep 1 && hyprflow restore --max-age 24h")
end)
```

**Legacy hyprlang:**

```ini
exec-once = waybar
exec-once = pypr
exec-once = sleep 1 && hyprflow restore --max-age 24h
```

For an _exact_ snapshot instead of relying only on the 10-minute timer, hook `hyprflow save` into whatever triggers your logout/reboot/poweroff (wlogout, a power menu script, a keybind):

```bash
hyprflow save; systemctl reboot
```

GUI apps that already resume themselves (browsers, editors) need nothing more — hyprflow just needs to get them back to the right workspace/position and let their own resume kick in.

---

## Layer 2 — Actual TUI persistence: zellij, not just a window-position hack

This is the part hyprflow can't do: it can relaunch `kitty`, but a relaunched `kitty` is an empty shell. To get **the actual running nvim/htop/ssh sessions** back, the process itself has to survive independently of the window — that's a terminal multiplexer's job.

As of 2026, **zellij is the better choice here over tmux**, specifically for your case:

- Session resurrection is **built in** — no tmux-resurrect + tmux-continuum plugin combo to maintain.
- It serializes session state to disk continuously (~every second), not on a 15-minute timer, so there's less to lose on a hard crash/power-loss reboot.
- It natively supports the **kitty keyboard protocol**, which matters if you use kitty — things like Shift+Enter in Claude Code/CLI tools work correctly, whereas tmux still doesn't pass this through properly.

Install:

```bash
sudo pacman -S zellij
```

Config, `~/.config/zellij/config.kdl`:

```kdl
session_serialization true
pane_viewport_serialization true
scrollback_lines_to_serialize 10000
```

`pane_viewport_serialization` is what lets it bring back visible pane content (not just re-run the command), and the scrollback line count controls how much history comes with it.

Resurrection is CLI-driven and idempotent:

```bash
zellij attach --create <name>
```

- Session running → attaches.
- Session exited/crashed/rebooted → rebuilds it from the cached layout and re-runs the last commands (behind a "Press ENTER to run…" banner by default, to stop something like a stray `rm -rf` firing on its own — check `zellij attach --help` for the flag to skip that if you want it fully silent).
- Nothing on record → starts fresh.

(If you're already deep in tmux muscle memory instead: `tmux-resurrect` + `tmux-continuum` with `@continuum-restore 'on'` and `@continuum-boot 'on'` does the equivalent job, just with more moving parts to maintain.)

---

## Layer 3 — Wiring this into your pyprland kitty scratchpad

This is your actual ask. Change the scratchpad's `command` from a bare `kitty -e ...` into one that attaches to a fixed, named zellij session:

```toml
# ~/.config/hypr/pyprland.toml
[pyprland]
plugins = ["scratchpads"]

[scratchpads.term]
animation = "fromTop"
command = "kitty --class kitty-dropterm -e zellij attach --create scratch_term"
class = "kitty-dropterm"
size = "75% 60%"
margin = 50
lazy = true          # don't spawn at hyprland startup — only on first toggle
unfocus = "hide"
```

Why this works cleanly:

- `unfocus = "hide"` in pyprland just moves the window to a special workspace — it doesn't kill the process. So while you're actively hiding/showing the scratchpad during a session, zellij's client just stays attached the whole time.
- `lazy = true` means nothing spawns at Hyprland startup — exactly what you want for a dropdown terminal.
- The _first_ time you toggle it after a reboot, `zellij attach --create scratch_term` finds no live session, finds the cached (resurrectable) layout from before the reboot, and rebuilds your panes/tabs and re-runs whatever was in them.
- Because `kitty-dropterm` is in hyprflow's `ignore_classes`, hyprflow leaves it alone entirely — no conflict.

If you run more than one scratchpad, give each its own zellij session name (`scratch_logs`, `scratch_notes`, etc.) and its own `ignore_classes` entry.

---

## Optional: extend persistence to regular (non-scratchpad) kitty windows too

Trying to auto-map every regular kitty window to its own zellij session via hyprflow gets fragile fast (hyprflow doesn't know the target workspace until after it launches the window). A more robust pattern, and honestly closer to how zellij is meant to be used, is to let zellij's own session picker do the reattaching:

`kitty.conf`:

```
shell zellij -l welcome
```

Now every plain kitty window you open — including ones hyprflow relaunches after reboot — drops you into zellij's welcome screen, which lists your resurrectable sessions by name. One keypress reattaches a full context (panes, cwd, running commands). It's a single manual step instead of full automation, but it avoids the ambiguity of "which window should reattach to which session," which is the actual hard part of doing this automatically.

---

## Completing the picture: Neovim buffer state

zellij/tmux resurrection gets the **process** (`nvim`) running again in the right directory — it does not know which buffers/splits were open inside it. Add a lightweight Neovim session plugin for that layer:

- **persistence.nvim** (folke) — autosaves a session per project directory, restore with one call on `VimEnter` if a session exists for the cwd.

That's the piece that makes reopening the scratchpad actually show your open files again, not just an empty `nvim`.

---

## End-to-end boot sequence

1. Hyprland starts → `hl.on("hyprland.start")` (or `exec-once`) fires: waybar, `pypr`, then `hyprflow restore --max-age 24h`.
2. hyprflow relaunches GUI apps + regular kitty windows to their saved workspaces/positions; GUI apps' own resume takes over; kitty windows land on zellij's welcome screen for one-keypress reattach.
3. Scratchpad stays dormant (lazy) until you press its bind.
4. First scratchpad toggle after reboot → `zellij attach --create scratch_term` silently resurrects the exact pane layout, commands, and scrollback from before the reboot.
5. Ongoing: hyprflow's systemd timer keeps window positions fresh every ~10 min; zellij keeps TUI state fresh continuously; a `hyprflow save` hook on your logout/reboot keybind captures an exact snapshot on clean shutdowns.

### Known limits, stated plainly

- Exact dwindle/master split-tree geometry isn't restorable (Hyprland doesn't expose it) — windows land on the right workspace but may re-tile in a different order.
- Scrollback/viewport restoration depends on `pane_viewport_serialization` being on and costs disk/cache space.
- Auto-running resurrected commands (`--force-run-commands`) trades safety for convenience — fine for a scratchpad you trust, worth leaving off elsewhere.

---

---

---

Both are real tools and worth using — but they solve different problems than the ones I'd lean on them for, so let me be direct about that before rewriting, rather than just nodding along:

- **hyprland-session-saver** is a legitimate, lighter alternative to hyprflow. It's genuinely more hackable (read-the-whole-thing Python), but it's a smaller project — no AUR package (git clone only), no releases yet, 6 stars, one maintainer, and "Daemon Mode" for autosave is still an unchecked roadmap item. It also only has built-in CWD/nvim detection for **Alacritty**, not kitty — you'll need to add that yourself. I'll wire it in.

- **CRIU** is a serious, real checkpoint/restore tool, but it wasn't built for this scenario, and it has hard edges specific to your use case that are worth knowing before depending on it:
  - It needs root (`CAP_CHECKPOINT_RESTORE`) — a meaningfully bigger privilege footprint than anything else here.
  - It restores a process onto its **original PID**. Fine most of the time right after boot, not guaranteed.
  - There's no continuous background saving — you must explicitly `criu dump` before shutdown. An unclean crash or power-loss gives you _nothing_, whereas zellij is writing state to disk every ~1s regardless.
  - **TCP connections do not meaningfully survive a real reboot.** CRIU's TCP repair mode is built for live migration on a network path that never goes down — after a full power cycle the remote end of any ssh/mosh session has already seen the connection die. So this can't help with the "long-running ssh session" case at all.
  - **GUI/Wayland apps are effectively out of scope.** Checkpointing a Wayland client's GPU context/DMA-BUF/socket state isn't something CRIU does reliably today — this only ever applies to the TUI layer, not your browser/editor windows.
  - There's a known, still-open rough edge where a restored process can attach to the wrong tty unless CRIU is invoked from inside the exact target pty.

Given that, the responsible way to use CRIU here is as a **best-effort bonus layer on top of zellij**, not a replacement for it — checkpoint the zellij _server_ itself (which sidesteps the tty-attachment problem, since kitty just reconnects to zellij's socket afterward), and fall back to zellij's own resurrection if the CRIU restore doesn't come back clean. That gets you the upside (exact scrollback/memory state when it works) without the downside (nothing at all when it doesn't).

Here's the rewritten guide.

---

# Hyprland "resume where I left off" — with hyprland-session-saver + CRIU + zellij

## Architecture

| Layer                       | Handles                          | Tool                                      |
| --------------------------- | -------------------------------- | ----------------------------------------- |
| GUI windows                 | Position, workspace, relaunch    | **hyprland-session-saver**                |
| TUI baseline (always works) | Panes, cwd, re-run commands      | **zellij** built-in resurrection          |
| TUI bonus (best-effort)     | Exact in-memory/scrollback state | **CRIU**, checkpointing the zellij server |
| Scratchpad plumbing         | Toggle, lazy-spawn               | **pyprland** (unchanged mechanics)        |

Note on Hyprland itself: **0.55 (May 2026) replaced hyprlang with a Lua config** (`~/.config/hypr/hyprland.lua`). Legacy `hyprland.conf` still works for now but is frozen/deprecated. Both syntaxes are given below — check yours with `hyprctl version`.

---

## Layer 1 — GUI windows: hyprland-session-saver

```bash
git clone https://github.com/anky209e/hyprland-session-saver
cd hyprland-session-saver
chmod +x install.sh
./install.sh
```

This installs to `~/.local/bin` and writes config to `~/.config/hypr-session/config.py`. CLI:

```bash
hypr-session save      # snapshot current windows
hypr-session restore   # relaunch them
hypr-session clear      # wipe saved session
```

Add kitty to the app map (it isn't there by default — only Alacritty gets special CWD/nvim handling out of the box):

```python
# ~/.config/hypr-session/config.py
APP_MAP = {
    "firefox": "firefox",
    "alacritty": "alacritty",
    # kitty added manually — regular windows only, NOT your scratchpad class
    "kitty": "kitty",
}
```

**Don't** add `kitty-dropterm` (or whatever class you give your scratchpad) to `APP_MAP`. If a window's class isn't mapped, hyprland-session-saver won't try to relaunch it at boot — which is what you want, since pyprland's `lazy` scratchpad should stay dormant until you toggle it, not get double-spawned by two different tools. (This is a smaller, less-documented project than most — worth a quick read of `hypr_session.py` to confirm that's actually its skip behavior before you rely on it.)

There's no built-in autosave daemon yet, so add one:

```ini
# ~/.config/systemd/user/hypr-session-autosave.timer
[Unit]
Description=Periodic Hyprland session snapshot

[Timer]
OnUnitActiveSec=10min

[Install]
WantedBy=timers.target
```

```ini
# ~/.config/systemd/user/hypr-session-autosave.service
[Unit]
Description=Save Hyprland session

[Service]
Type=oneshot
ExecStart=%h/.local/bin/hypr-session save
```

```bash
systemctl --user enable --now hypr-session-autosave.timer
```

Startup restore — **Lua (0.55+)**:

```lua
hl.on("hyprland.start", function()
  hl.exec_cmd("waybar & pypr")
  hl.exec_cmd("sleep 1 && hypr-session restore")
end)
```

**Legacy hyprlang:**

```ini
exec-once = waybar
exec-once = pypr
exec-once = sleep 1 && hypr-session restore
```

---

## Layer 2 — TUI baseline: zellij (the load-bearing layer)

This stays in the design regardless of CRIU, because it's the only piece here with a continuous, crash-safe save — it writes session state to disk roughly every second, no daemon babysitting required, and it's what guarantees you get _something_ back even when CRIU doesn't.

```bash
sudo pacman -S zellij
```

```kdl
# ~/.config/zellij/config.kdl
session_serialization true
pane_viewport_serialization true
scrollback_lines_to_serialize 10000
```

Restore is idempotent: `zellij attach --create <name>` attaches if running, resurrects from cache if not, creates fresh otherwise.

---

## Layer 3 — CRIU: best-effort exact-state bonus, on top of the zellij server

Instead of checkpointing individual shells (fragile tty-attachment issues), checkpoint the **zellij server process tree**. Kitty never touches CRIU directly — it just reconnects to zellij's socket afterward, same as any normal `zellij attach`.

```bash
sudo pacman -S criu
sudo setcap cap_checkpoint_restore,cap_sys_admin+eip $(which criu)   # avoid needing sudo every call
```

Find the server PID (confirm the exact process pattern on your system first — `ps aux | grep zellij`):

```bash
#!/bin/bash
# ~/.local/bin/zellij-criu-dump
SESSION="scratch_term"
PID=$(pgrep -f "zellij.*server.*${SESSION}" | head -n1)
[ -z "$PID" ] && exit 0
IMG_DIR="/var/lib/criu-zellij/${SESSION}"
sudo mkdir -p "$IMG_DIR"
sudo criu dump -t "$PID" -D "$IMG_DIR" -o dump.log -v4 --tcp-established || true
```

Hook it into your shutdown/reboot path, before the window-level saves:

```bash
zellij-criu-dump; hypr-session save; systemctl reboot
```

Restore attempt, wrapped with a fallback — **this wrapper is what actually goes in the pyprland command**, not a raw `zellij attach`:

```bash
#!/bin/bash
# ~/.local/bin/scratchpad-attach
SESSION="scratch_term"
IMG_DIR="/var/lib/criu-zellij/${SESSION}"

if [ -f "$IMG_DIR/dump.log" ] && sudo criu restore -D "$IMG_DIR" -d --shell-job 2>/tmp/criu-restore.log; then
    exec zellij attach "$SESSION"          # server came back exactly as it was
else
    exec zellij attach --create "$SESSION" # fall back to zellij's own resurrection
fi
```

Be realistic about this layer: a Rust async server touching epoll/io_uring and PTY fds is exactly the kind of workload CRIU sometimes chokes on. Treat it as "free exact-scrollback restore when it works," not something to depend on — which is precisely why the fallback line isn't optional.

---

## Layer 4 — Wire it into the pyprland scratchpad

```toml
# ~/.config/hypr/pyprland.toml
[pyprland]
plugins = ["scratchpads"]

[scratchpads.term]
animation = "fromTop"
command = "kitty --class kitty-dropterm -e ~/.local/bin/scratchpad-attach"
class = "kitty-dropterm"
size = "75% 60%"
margin = 50
lazy = true
unfocus = "hide"
```

`unfocus = "hide"` doesn't kill the process, so during a single uptime the CRIU/zellij layer never even gets exercised — you're just hiding/showing a live zellij client. It only matters across an actual reboot.

---

## Layer 5 — Neovim buffer state

Neither zellij nor CRIU knows which buffers/splits were open inside nvim if it falls back to a fresh relaunch. Add:

- **persistence.nvim** — autosaves a session per project directory, one call to restore on `VimEnter`.

This is what closes the gap on the fallback path specifically — if CRIU restore fails and zellij just re-runs `nvim`, persistence.nvim is what gets your actual files/splits back.

---

## End-to-end sequence

**On shutdown/reboot** (bind this to your power menu / logout key):

```bash
zellij-criu-dump; hypr-session save; systemctl reboot
```

**On boot:**

1. `hl.on("hyprland.start")` (or `exec-once`): waybar, `pypr`, then `hypr-session restore` — GUI apps + regular kitty windows land back on their workspaces; GUI apps' own resume takes over.
2. Scratchpad stays dormant (`lazy = true`).
3. First scratchpad toggle: `scratchpad-attach` tries the CRIU-restored zellij server first; if that image is missing, stale, or fails to restore, it transparently falls back to `zellij attach --create`, which rebuilds the session from its own continuously-written layout cache instead.

### Where this is honest about its limits

- CRIU only ever touches the TUI layer — it does nothing for GUI/Wayland windows.
- If you skip the shutdown hook (crash, power loss, forgot), CRIU has nothing; zellij still has state up to ~1 second before the crash.
- Anything with a live network connection open in that scratchpad (ssh, mosh) will not meaningfully resume either way after a real reboot — zellij will re-run the `ssh` command fresh, which is the realistic outcome regardless of which tool you use here.
- hyprland-session-saver being a smaller project means less mileage than hyprflow specifically for exotic window types (multi-window Chromium, apps needing re-login) — same caveat the tool's own README notes for similar tools in this space.

---

---

---

You're right that I undersold it — the README has one genuinely more sophisticated capability I only footnoted before: **per-profile Brave browser restore**, which needs special handling because Brave runs all windows in a single process (so naive class-based relaunching can't tell profiles apart). There's also a diagnostic mode (`hyprflow config` shows detected profile mapping status) and an `--on-login` helper that prints the exec line for you. Folding those in properly below, keeping the zellij + CRIU layers from before since you didn't ask to change those.

---

# Hyprland "resume where I left off" — hyprflow + CRIU + zellij

## Architecture

| Layer                                 | Handles                          | Tool                                      |
| ------------------------------------- | -------------------------------- | ----------------------------------------- |
| GUI windows (incl. per-profile Brave) | Position, workspace, relaunch    | **hyprflow**                              |
| TUI baseline (always works)           | Panes, cwd, re-run commands      | **zellij** built-in resurrection          |
| TUI bonus (best-effort)               | Exact in-memory/scrollback state | **CRIU**, checkpointing the zellij server |
| Scratchpad plumbing                   | Toggle, lazy-spawn               | **pyprland**                              |

One config-syntax note carried over: **hyprland 0.55+ uses Lua** (`hyprland.lua`) instead of `hyprland.conf`. hyprflow's own `--on-login` helper still prints legacy `exec-once` syntax (its README requirement is "Hyprland 0.54+", predating the Lua switch) — so on 0.55+ you'll translate that one line yourself, shown below.

---

## Layer 1 — hyprflow

```bash
yay -S hyprflow
```

Full config, `~/.config/hyprflow/config.toml`:

```toml
[general]
default_session = "latest"
restore_delay_ms = 800          # give waybar/pypr a head start
window_detect_timeout_ms = 8000
autosave_retain = 5

[filters]
ignore_classes = ["waybar", "wofi", "mako", "polkit", "nm-applet",
                   "xdg-desktop-portal", "kitty-dropterm"]   # exclude the pyprland scratchpad

[apps.kitty]
binary = "kitty"
capture_cwd = true
capture_last_command = true
hint_template = "# Last: {last_command}\n# Dir: {cwd}"

[apps.brave-browser]
binary = "brave"
default_workspace = 1
profile_workspaces = { "Default" = 1, "Profile 1" = 6, "Profile 2" = 7 }
```

**Brave profile support** — the part worth calling out properly: since all Brave windows share one process, hyprflow can't tell profiles apart from `hyprctl clients` the way it does for normal apps. Instead it reads Brave's `Local State` file directly to identify which profile each window belongs to. Only profiles listed in `profile_workspaces` get captured/restored at all — anything not listed is skipped on both save and restore. On restore, hyprflow launches one Brave window per mapped profile and moves each to its configured workspace. Check what it's actually detected with:

```bash
hyprflow config
```

This prints your config plus the live profile-detection/mapping status — useful for confirming `profile_workspaces` lines up with what Brave's `Local State` actually reports before you trust it at boot.

Day-to-day commands:

```bash
hyprflow save                    # save as "latest"
hyprflow save work               # named save
hyprflow restore --dry-run       # preview before it touches anything
hyprflow restore --max-age 24h   # skip if stale
hyprflow list
hyprflow delete work
```

`--dry-run` is worth using once after writing the config — it shows exactly what would be relaunched and where, without spawning anything, which is the fastest way to confirm your `ignore_classes` and `profile_workspaces` are actually correct before you rely on it unattended at boot.

Autosave, built in (no separate systemd unit needed, unlike the lighter alternatives):

```bash
hyprflow autosave --install   # systemd --user timer, every 10 min, rotates via autosave_retain
```

Boot restore — get the line, then place it correctly for your config syntax:

```bash
hyprflow restore --on-login
# → prints: exec-once = hyprflow restore --max-age 24h
```

**Lua (0.55+)** — translate that line manually:

```lua
hl.on("hyprland.start", function()
  hl.exec_cmd("waybar & pypr")
  hl.exec_cmd("sleep 1 && hyprflow restore --max-age 24h")
end)
```

**Legacy hyprlang** — use the printed line as-is:

```ini
exec-once = waybar
exec-once = pypr
exec-once = hyprflow restore --max-age 24h
```

For an exact snapshot instead of relying on the 10-minute timer, hook `hyprflow save` into your logout/reboot trigger:

```bash
hyprflow save; systemctl reboot
```

---

## Layer 2 — TUI baseline: zellij

Unchanged from before — this is the layer with a continuous, crash-safe save (~1s to disk), so it's what guarantees you get _something_ back even when the CRIU layer below doesn't.

```bash
sudo pacman -S zellij
```

```kdl
# ~/.config/zellij/config.kdl
session_serialization true
pane_viewport_serialization true
scrollback_lines_to_serialize 10000
```

`zellij attach --create <name>` attaches if running, resurrects from cache if not, creates fresh otherwise.

---

## Layer 3 — CRIU: best-effort exact-state bonus

Checkpoints the zellij **server** process tree, not individual shells — kitty just reconnects to zellij's socket afterward, sidestepping CRIU's known tty-attachment quirks.

```bash
sudo pacman -S criu
sudo setcap cap_checkpoint_restore,cap_sys_admin+eip $(which criu)
```

```bash
#!/bin/bash
# ~/.local/bin/zellij-criu-dump
SESSION="scratch_term"
PID=$(pgrep -f "zellij.*server.*${SESSION}" | head -n1)   # verify the actual pattern via: ps aux | grep zellij
[ -z "$PID" ] && exit 0
IMG_DIR="/var/lib/criu-zellij/${SESSION}"
sudo mkdir -p "$IMG_DIR"
sudo criu dump -t "$PID" -D "$IMG_DIR" -o dump.log -v4 --tcp-established || true
```

```bash
#!/bin/bash
# ~/.local/bin/scratchpad-attach
SESSION="scratch_term"
IMG_DIR="/var/lib/criu-zellij/${SESSION}"

if [ -f "$IMG_DIR/dump.log" ] && sudo criu restore -D "$IMG_DIR" -d --shell-job 2>/tmp/criu-restore.log; then
    exec zellij attach "$SESSION"
else
    exec zellij attach --create "$SESSION"   # zellij's own resurrection
fi
```

Reminder on scope: this needs root, has no continuous safety net of its own (an unclean shutdown = nothing), doesn't help with the GUI layer at all, and a Rust async server (epoll/io_uring-heavy) is exactly the kind of process CRIU sometimes struggles with — the fallback line is load-bearing, not decorative.

Shutdown hook, full chain:

```bash
zellij-criu-dump; hyprflow save; systemctl reboot
```

---

## Layer 4 — pyprland scratchpad

```toml
# ~/.config/hypr/pyprland.toml
[pyprland]
plugins = ["scratchpads"]

[scratchpads.term]
animation = "fromTop"
command = "kitty --class kitty-dropterm -e ~/.local/bin/scratchpad-attach"
class = "kitty-dropterm"
size = "75% 60%"
margin = 50
lazy = true
unfocus = "hide"
```

`kitty-dropterm` is excluded from hyprflow's `ignore_classes` (set above), so hyprflow never tries to also relaunch it — the scratchpad stays lazy and only the `scratchpad-attach` wrapper handles its restoration.

---

## Layer 5 — Neovim buffer state

If CRIU restore fails and zellij falls back to just re-running `nvim` fresh, you still want your actual buffers/splits back, not an empty editor:

- **persistence.nvim** — autosaves per project directory, one call to restore on `VimEnter`.

---

## End-to-end sequence

**Shutdown/reboot:**

```bash
zellij-criu-dump; hyprflow save; systemctl reboot
```

**Boot:**

1. Startup hook: waybar, `pypr`, then `hyprflow restore --max-age 24h` — regular GUI windows and kitty windows land back on their workspaces (with the CWD/last-command hint for kitty); mapped Brave profiles relaunch to their configured workspaces; each app's own resume feature takes it from there.
2. Scratchpad stays dormant (`lazy = true`).
3. First toggle: `scratchpad-attach` tries the CRIU-restored zellij server; on any failure, falls back to zellij's own layout-cache resurrection.

### Still worth knowing

- hyprflow is small (6 stars) but structurally more mature than the alternative I compared it to — it ships CI workflows, a test suite, three tagged releases, and an AUR package, versus a single git-clone script with none of that.
- Brave profile restore depends on parsing `Local State`, so a Brave update that changes that file's format is the most likely thing to quietly break it — `hyprflow config`'s mapping-status output is the fastest way to notice.
- Everything from before about CRIU/zellij's honest limits still applies: no GUI/Wayland coverage, no surviving network connections across a real reboot, and zellij (not CRIU) is what actually guarantees a fallback.
