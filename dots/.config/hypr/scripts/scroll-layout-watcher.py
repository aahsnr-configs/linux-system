#!/usr/bin/env python3
"""
scroll-layout-watcher.py  v5
~/.config/hypr/scripts/scroll-layout-watcher.py

Hyprland 0.54.x IPC daemon — scrolling layout left-anchor.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PROBLEM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
With fullscreen_on_one_column = true, a solo window opens full-frame.  When
a second window opens the layout must choose a leftOffset.  With
focus_fit_method = 1 (fit), follow_focus scrolls just enough to show the
newly-focused column 2 from the LEFT edge of the monitor:

    leftOffset ≈ column_width × monitor_width   (column 1 scrolled off-screen)

The desired state is the opposite:

    leftOffset = 0  →  [col1][col2][──── empty gap ────]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FIX
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
On the exact 1→2 tiled-window transition on a scrolling workspace:

    hyprctl dispatch -- layoutmsg "move -999999"

The `move -VALUE` layoutmsg shifts leftOffset left by VALUE logical pixels,
clamping at 0.  It is a PURE VIEWPORT OPERATION — column widths and focus are
untouched.  The `--` flag stops hyprctl's own CLI option parser before it
reaches the minus sign in -999999, which would otherwise be misread as a flag
for hyprctl itself.

With column_width = 0.40 and two columns (total 0.80 × monitor width), the
layout always clamps leftOffset to 0; the move is exact on all monitor sizes.

WHY NOT `fit tobeg`:
  The `fit` command family recalculates column WIDTHS to fill the screen,
  which would override column_width = 0.40.  Use `move` for viewport-only
  anchoring.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WHY PYTHON, NOT BASH
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
A Bash daemon uses `socat | while read line; do handle "$line" &; done`.
The `&` spawns a new shell process for EVERY event.  Hyprland emits events
at display refresh rate during animations — potentially hundreds of subshells
per second with no upper bound.

Python asyncio uses a single-threaded cooperative event loop:
  • Reads socket2 directly via asyncio.open_unix_connection — no socat
  • Dispatches per-workspace tasks via asyncio.create_task — no process spawning
  • Parses JSON via stdlib json — no jq
  • Debounces burst opens with Task.cancel() — no lock files

Dependencies: Python ≥ 3.8 (stdlib only) + hyprctl (ships with Hyprland).
Arch Linux ships Python 3.13+ by default; 3.8 is the tested minimum.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
AUTOSTART  (autostart.conf — exec-once ONLY)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  exec-once = ~/.config/hypr/scripts/scroll-layout-watcher.py

IMPORTANT — hyprctl reload does NOT restart exec-once:
  `hyprctl reload` re-parses hyprland.conf only.  exec-once commands are
  started once at session boot and never re-run.  If this script crashes it
  stays dead until the next full session restart.

CRASH-RECOVERY WRAPPER (recommended):
  exec-once = bash -c 'trap exit TERM INT; while true; do ~/.config/hypr/scripts/scroll-layout-watcher.py; sleep 2; done'

  How this works step-by-step:
    1. Hyprland forks bash, passing -c and the loop string as arguments.
    2. Bash starts executing the while loop.
    3. When bash encounters the .py path it checks execute permission, reads
       the first line, and finds the shebang: #!/usr/bin/env python3
    4. The Linux kernel's binfmt_misc handler invokes `env python3 <script>`.
    5. Python inherits the full environment from Hyprland → bash → python3,
       so HYPRLAND_INSTANCE_SIGNATURE and XDG_RUNTIME_DIR are present.
    6. Python runs asyncio.run(_main()) as its own process.
    7. If Python exits for any reason (unhandled exception, OOM kill, etc.),
       control returns to the bash while loop.
    8. Bash sleeps 2 s, then re-executes the Python script.
    9. trap exit TERM INT ensures bash itself exits cleanly when Hyprland
       sends SIGTERM at session shutdown, rather than looping forever.

  The script already self-recovers from socket drops (compositor restart
  within the session) via its internal reconnect loop.  The bash wrapper
  adds recovery from Python process crashes only.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DEBUGGING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SCROLL_WATCHER_DEBUG=1 ~/.config/hypr/scripts/scroll-layout-watcher.py
  tail -f "$XDG_RUNTIME_DIR/scroll-watcher.log"
"""

from __future__ import annotations  # PEP 563 — lazy annotations, Python 3.8 compat

import asyncio
import json
import logging
import os
import signal
import sys
from pathlib import Path
from typing import Any


# ─── Configuration ────────────────────────────────────────────────────────────

# Seconds to wait after openwindow before inspecting window count.
# Gives the compositor time to:
#   • Assign column geometry to the new window.
#   • Complete the fullscreen_on_one_column → two-column transition.
#   • Run its internal follow_focus repositioning.
# 100 ms is comfortably above one frame at 60 Hz and below perceptible delay.
SETTLE_DELAY: float = 0.10

# Seconds between socket reconnect attempts after a disconnect.
RECONNECT_DELAY: float = 2.0

# Maximum bytes per event line from socket2.
# The default asyncio StreamReader limit is 64 KiB (2**16).  Hyprland event
# lines contain window titles, which are user-controlled.  1 MiB is ample
# headroom while preventing unbounded memory use from a malformed socket.
SOCKET_READ_LIMIT: int = 2 ** 20  # 1 MiB

# Workspace IDs/names known to use the scrolling layout (tier-3 fallback).
# Tiers 1 and 2 query hyprctl at runtime; this list is only consulted when
# those live queries return no layout information (e.g. on older builds).
# Edit to match workspaces.conf if your scrolling workspace IDs differ.
SCROLLING_WORKSPACE_NAMES: frozenset[str] = frozenset({"10", "11", "12"})


# ─── Logging ──────────────────────────────────────────────────────────────────

_DEBUG: bool = os.environ.get("SCROLL_WATCHER_DEBUG", "0") == "1"

# Default to stderr-only; in debug mode also write to a timestamped log file.
_log_handlers: list[logging.Handler] = [logging.StreamHandler(sys.stderr)]
if _DEBUG:
    _runtime: str = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    _log_handlers = [
        logging.FileHandler(Path(_runtime) / "scroll-watcher.log"),
        logging.StreamHandler(sys.stderr),
    ]

logging.basicConfig(
    level=logging.DEBUG if _DEBUG else logging.WARNING,
    format="[%(asctime)s.%(msecs)03d] %(levelname)-7s %(message)s",
    datefmt="%H:%M:%S",
    handlers=_log_handlers,
)
log: logging.Logger = logging.getLogger("scroll-watcher")


# ─── Async hyprctl helpers ────────────────────────────────────────────────────

async def _hyprctl(args: list[str], timeout: float = 2.0) -> bytes:
    """
    Run `hyprctl <args>` and return stdout bytes.

    Returns b"" on any failure (timeout, process error, hyprctl not found).
    Guarantees the subprocess is killed if it is still running when this
    coroutine exits for ANY reason — including asyncio.CancelledError, which
    is a BaseException and is NOT caught by `except Exception`.  The `finally`
    block runs on all exit paths.
    """
    proc: asyncio.subprocess.Process | None = None
    try:
        proc = await asyncio.create_subprocess_exec(
            "hyprctl", *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=timeout)
        return stdout

    except asyncio.TimeoutError:
        log.debug("hyprctl %s timed out after %.1fs", args, timeout)
        return b""

    except Exception as exc:
        log.debug("hyprctl %s failed: %s", args, exc)
        return b""

    finally:
        # Kill the subprocess if it is still running.  This block runs even
        # when CancelledError (a BaseException) propagates through the try,
        # preventing zombie processes when a task is debounced mid-flight.
        #
        # We do NOT `await proc.wait()` here: awaiting inside a finally block
        # that was entered via CancelledError would immediately raise
        # CancelledError again, aborting the cleanup.  A plain proc.kill()
        # sends SIGKILL synchronously; the OS reaps the child when Python's
        # event loop next runs the subprocess transport callback, or at latest
        # when the Process object is garbage-collected.
        if proc is not None and proc.returncode is None:
            try:
                proc.kill()
            except ProcessLookupError:
                pass  # Process already exited between the check and the kill


async def hyprctl_json(subcommand: str) -> Any:
    """
    Run `hyprctl -j <subcommand>` and parse the JSON response.

    Returns the parsed value (list, dict, …) or None on any error.
    """
    raw = await _hyprctl(["-j", subcommand])
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        log.debug("JSON parse error for 'hyprctl -j %s': %s", subcommand, exc)
        return None


async def hyprctl_dispatch(dispatcher: str, data: str = "") -> None:
    """
    Run `hyprctl dispatch -- <dispatcher> [data]`.

    The `--` end-of-options marker prevents hyprctl's own CLI parser from
    treating a leading `-` in `data` as a hyprctl flag.  Without it, calling
    this with data="move -999999" would cause hyprctl to try to parse
    "-999999" as one of its own options and reject the call.

    Example: hyprctl_dispatch("layoutmsg", "move -999999")
      →  argv: ["hyprctl", "dispatch", "--", "layoutmsg", "move -999999"]
      →  IPC string sent to compositor: "dispatch layoutmsg move -999999"
    """
    log.debug("dispatch: %s %s", dispatcher, data)
    args: list[str] = ["dispatch", "--", dispatcher]
    if data:
        args.append(data)
    await _hyprctl(args)


# ─── Workspace layout detection ───────────────────────────────────────────────

async def is_scrolling_workspace(ws_name: str) -> bool:
    """
    Return True if ws_name is currently using the scrolling layout.

    Three-tier detection (first positive match wins):

      Tier 1 — hyprctl -j workspaces (.layout field):
          Available in Hyprland 0.54+ due to the per-workspace layout rewrite.
          Most reliable: reflects the live state after any runtime layout switch.

      Tier 2 — hyprctl -j workspacerules (.layout field):
          Covers workspaces declared with `workspace = N, layout:scrolling`
          before their first window opens (they may not yet appear in the
          `workspaces` list, so tier 1 would miss them).

      Tier 3 — SCROLLING_WORKSPACE_NAMES constant:
          Hard-coded fallback; zero subprocess cost.  Used when tiers 1 and 2
          return no layout field (e.g. older Hyprland builds that predate the
          per-workspace layout field).  Edit the constant at the top of this
          file to match your workspaces.conf.
    """
    # ── Tier 1: live workspace state ─────────────────────────────────────────
    workspaces = await hyprctl_json("workspaces")
    if isinstance(workspaces, list):
        for ws in workspaces:
            if str(ws.get("name", "")) == ws_name:
                layout: str = str(ws.get("layout", ""))
                log.debug("tier1 ws=%s layout=%r", ws_name, layout)
                if layout == "scrolling":
                    return True
                # Workspace found with a definite non-scrolling layout.
                if layout:
                    return False
                # layout field absent on this build — fall through to tier 2.
                break

    # ── Tier 2: workspace rules ───────────────────────────────────────────────
    rules = await hyprctl_json("workspacerules")
    if isinstance(rules, list):
        for rule in rules:
            ws_str:   str = str(rule.get("workspaceString", ""))
            ws_rname: str = str(rule.get("workspaceName",   ""))
            if ws_str == ws_name or ws_rname == ws_name:
                rule_layout: str = str(rule.get("layout", ""))
                log.debug("tier2 ws=%s rule_layout=%r", ws_name, rule_layout)
                if rule_layout == "scrolling":
                    return True

    # ── Tier 3: hard-coded fallback ───────────────────────────────────────────
    if ws_name in SCROLLING_WORKSPACE_NAMES:
        log.debug("tier3 ws=%s matched hardcoded set", ws_name)
        return True

    log.debug("ws=%s NOT identified as scrolling", ws_name)
    return False


# ─── Window counting ──────────────────────────────────────────────────────────

async def count_tiled_windows(ws_name: str) -> int:
    """
    Count tiled (non-floating, non-minimized) windows on ws_name.

    Returns -1 if the hyprctl query fails, allowing callers to distinguish
    "zero windows" (returns 0) from "query error" (returns -1).
    """
    clients = await hyprctl_json("clients")
    if not isinstance(clients, list):
        return -1

    count: int = 0
    for client in clients:
        if not isinstance(client, dict):
            continue
        # `workspace` may be absent OR present with a JSON null value (→ None).
        # Using `or {}` handles both cases: absent key returns the default {},
        # and a None value is also replaced by {}.
        ws: dict[str, Any] = client.get("workspace") or {}
        if str(ws.get("name", "")) != ws_name:
            continue
        if client.get("floating", False):
            continue
        if client.get("minimized", False):
            continue
        count += 1
    return count


async def active_workspace_name() -> str:
    """Return the name of the currently active workspace, or '' on error."""
    ws = await hyprctl_json("activeworkspace")
    if isinstance(ws, dict):
        return str(ws.get("name", ""))
    return ""


# ─── Reconnect-loop sleep helper ──────────────────────────────────────────────

async def _interruptible_sleep(seconds: float, stop: asyncio.Event) -> None:
    """
    Sleep for `seconds` or return early when `stop` is set.

    Used in the reconnect loop so that a SIGTERM-triggered stop is responded
    to immediately rather than waiting up to RECONNECT_DELAY seconds.
    """
    try:
        await asyncio.wait_for(stop.wait(), timeout=seconds)
    except asyncio.TimeoutError:
        pass  # Normal expiry — not an error


# ─── Per-workspace event handler ──────────────────────────────────────────────

class ScrollWatcher:
    """
    Maintains a map of pending asyncio Tasks, one per workspace name.

    When a new openwindow event arrives for a workspace that already has a
    pending task (rapid successive opens), the old task is cancelled and a
    fresh one is scheduled.  Only the final settle-and-snap runs after a
    burst of window-open events on the same workspace.
    """

    def __init__(self) -> None:
        self._pending: dict[str, asyncio.Task[None]] = {}

    def cancel_all(self) -> None:
        """
        Cancel every pending task.

        Called when the socket disconnects so tasks blocked in
        asyncio.sleep(SETTLE_DELAY) do not outlive the connection context
        and trigger asyncio's "Task destroyed but it is pending" warning.
        """
        for task in self._pending.values():
            if not task.done():
                task.cancel()
        self._pending.clear()

    def handle(self, event_payload: str) -> None:
        """
        Parse an openwindow payload and schedule a settle-and-snap task.

        event_payload is the part after 'openwindow>>':
            WINDOWADDRESS,WORKSPACENAME,WINDOWCLASS,WINDOWTITLE

        Window titles may contain commas; we split at most 3 times so that
        everything after the class name is captured as a single token and
        does not interfere with ws_name extraction.

        Must be called from within the running event loop because
        asyncio.create_task() requires a running loop.
        """
        parts = event_payload.split(",", 3)
        if len(parts) < 2:
            log.debug("malformed openwindow payload: %r", event_payload)
            return

        ws_name: str = parts[1].strip()
        if not ws_name:
            return

        log.debug("openwindow on ws=%s", ws_name)

        # Debounce: cancel any in-flight task for this workspace so that only
        # the most recent open triggers the viewport correction.
        old = self._pending.get(ws_name)
        if old is not None and not old.done():
            old.cancel()

        task: asyncio.Task[None] = asyncio.create_task(
            self._settle_and_snap(ws_name),
            name=f"snap-{ws_name}",
        )
        self._pending[ws_name] = task

    async def _settle_and_snap(self, ws_name: str) -> None:
        """
        Core logic: wait for the layout to settle, then snap the viewport.

        Runs as a background asyncio.Task so it never blocks socket reading.
        """
        try:
            # ── Layout check ─────────────────────────────────────────────────
            # Done before the settle delay: layout assignment is stable
            # immediately, and the hyprctl queries are fast (< 10 ms).
            if not await is_scrolling_workspace(ws_name):
                return

            # ── Settle delay ─────────────────────────────────────────────────
            # asyncio.sleep is non-blocking — the event loop continues reading
            # socket events from other workspaces during this pause.
            await asyncio.sleep(SETTLE_DELAY)

            # ── Window count ─────────────────────────────────────────────────
            count: int = await count_tiled_windows(ws_name)
            log.debug("ws=%s tiled_count=%d", ws_name, count)

            # Act only on the exact 1→2 transition.
            if count != 2:
                return

            # ── Active workspace guard ────────────────────────────────────────
            # `hyprctl dispatch layoutmsg` always targets the ACTIVE workspace.
            # If the second window was sent to a background workspace by a
            # window rule, dispatching here would incorrectly affect the
            # workspace the user is currently viewing.
            active: str = await active_workspace_name()
            if active != ws_name:
                log.debug(
                    "ws=%s is not active (active=%s) — skipping dispatch",
                    ws_name, active,
                )
                return

            # ── Viewport snap ─────────────────────────────────────────────────
            # `move -999999` shifts leftOffset left by 999999 logical pixels.
            # The layout clamps it at 0 (tape start): column 1 flush at the
            # monitor left edge.
            #
            # With column_width = 0.40:
            #   Column 1  →  [0.00 … 0.40] × monitor_width
            #   Column 2  →  [0.40 … 0.80] × monitor_width
            #   Empty gap →  [0.80 … 1.00] × monitor_width
            await hyprctl_dispatch("layoutmsg", "move -999999")
            log.debug("ws=%s viewport anchored to leftOffset=0", ws_name)

        except asyncio.CancelledError:
            log.debug("ws=%s task debounced (cancelled)", ws_name)
            # Re-raise so asyncio records the task as cancelled, not failed.
            raise

        except Exception as exc:
            log.warning("ws=%s unexpected error in snap task: %s", ws_name, exc)

        finally:
            # Only remove our own entry from _pending.  If we were debounced,
            # a newer task is already stored under ws_name; removing it would
            # break that task's debounce tracking.
            if self._pending.get(ws_name) is asyncio.current_task():
                self._pending.pop(ws_name, None)


# ─── Socket event loop ────────────────────────────────────────────────────────

async def _event_loop(socket_path: Path) -> None:
    """
    Connect to socket2, read events line-by-line, dispatch openwindow events.

    Returns when the socket closes (compositor shutdown or restart).
    All pending snap tasks are cancelled before returning so they do not
    outlive the connection and trigger "Task destroyed but pending" warnings.
    """
    log.debug("connecting to %s", socket_path)
    reader, writer = await asyncio.open_unix_connection(
        str(socket_path),
        limit=SOCKET_READ_LIMIT,
    )
    watcher = ScrollWatcher()
    log.debug("connected to socket2")

    try:
        while True:
            try:
                line: bytes = await reader.readline()
            except asyncio.LimitOverrunError as exc:
                # A single event line exceeded SOCKET_READ_LIMIT (1 MiB).
                # This should never happen in practice; guard against it
                # anyway.  Drain the overlong line and continue normally.
                log.warning(
                    "event line exceeded %d-byte limit (%d bytes); skipping",
                    SOCKET_READ_LIMIT, exc.consumed,
                )
                await reader.read(exc.consumed)
                continue

            if not line:
                # Empty read = EOF — compositor closed the socket.
                log.debug("socket2 EOF")
                break

            # Strip both CR and LF to handle any line-ending style.
            event: str = line.decode("utf-8", errors="replace").rstrip("\r\n")

            if event.startswith("openwindow>>"):
                payload = event[len("openwindow>>"):]
                watcher.handle(payload)
            # All other events are silently ignored.

    finally:
        # Cancel snap tasks that are mid-sleep before closing the connection,
        # preventing asyncio's "Task destroyed but it is pending" warnings.
        watcher.cancel_all()
        writer.close()
        try:
            await writer.wait_closed()
        except BaseException:
            # Catch BaseException (not just Exception) so that CancelledError
            # raised by wait_closed() during asyncio.run() shutdown does not
            # propagate through the finally block and mask the real exit path.
            pass


# ─── Entry point ──────────────────────────────────────────────────────────────

async def _main() -> None:
    instance:    str | None = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime_dir: str | None = os.environ.get("XDG_RUNTIME_DIR")

    if not instance:
        log.error(
            "HYPRLAND_INSTANCE_SIGNATURE is not set. "
            "Is Hyprland running and was this script started from exec-once?"
        )
        sys.exit(1)

    if not runtime_dir:
        log.error("XDG_RUNTIME_DIR is not set.")
        sys.exit(1)

    socket_path = Path(runtime_dir) / "hypr" / instance / ".socket2.sock"
    log.warning("scroll-layout-watcher v5 started (pid=%d)", os.getpid())
    log.debug("socket path: %s", socket_path)

    # Shutdown event — set by SIGTERM to break the reconnect loop cleanly.
    # Using an asyncio.Event rather than a plain flag lets the reconnect sleep
    # (_interruptible_sleep) wake up immediately on signal instead of waiting
    # up to RECONNECT_DELAY seconds.
    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    try:
        loop.add_signal_handler(signal.SIGTERM, stop.set)
    except (OSError, NotImplementedError):
        # add_signal_handler is not available on Windows or in some minimal
        # environments.  SIGTERM will use the OS default (process termination)
        # which is acceptable; the bash wrapper's `trap exit TERM INT` handles
        # it cleanly anyway.
        pass

    # Self-reconnect loop.
    # Recovers from: compositor restart within the session (socket briefly
    # disappears), transient IO errors, and any exception from _event_loop.
    # Does NOT recover from this Python process crashing — use the bash wrapper
    # in exec-once for that (documented at the top of this file).
    while not stop.is_set():
        if not socket_path.exists():
            log.debug("socket not found, retrying in %.1fs...", RECONNECT_DELAY)
            await _interruptible_sleep(RECONNECT_DELAY, stop)
            continue

        try:
            await _event_loop(socket_path)
        except ConnectionRefusedError:
            log.debug("connection refused, compositor may be restarting")
        except FileNotFoundError:
            log.debug("socket disappeared mid-connect")
        except Exception as exc:
            log.warning("event loop error: %s", exc)

        if not stop.is_set():
            log.debug("reconnecting in %.1fs...", RECONNECT_DELAY)
            await _interruptible_sleep(RECONNECT_DELAY, stop)

    log.warning("scroll-layout-watcher stopped")


if __name__ == "__main__":
    try:
        asyncio.run(_main())
    except (KeyboardInterrupt, SystemExit):
        pass
