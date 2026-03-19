#!/usr/bin/env python3
"""
hyprland_scrolling_first_window.py
───────────────────────────────────────────────────────────────────────────────
Hyprland v0.54.2 scrolling layout — first-window left-alignment manager.
Requires the patched Hyprland build that adds `layoutmsg lockcameraoffset`.

BEHAVIOUR
─────────
  • fullscreen_on_one_column = false at all times (applied at startup and
    after every configreloaded event).

  • The camera is locked at offset 0 on any scrolling-layout workspace whose
    columns do not yet fill the full screen width.  Specifically:

        tiled_count * column_width < 1.0  →  lockcameraoffset 0
        tiled_count * column_width >= 1.0 →  lockcameraoffset none

    With column_width = 0.40 this means:
        1 window  (0.40W)  →  locked at 0  (left-aligned, no centering)
        2 windows (0.80W)  →  locked at 0  (left-aligned, no centering)
        3+ windows (1.20W) →  unlocked     (normal scrolling takes over)

  • The lock is pre-applied on workspacev2 (workspace switch), BEFORE any
    window opens on an empty workspace.  This eliminates the visual jump
    caused by the compositor placing the window at the centred position first
    and then moving it — the window now opens directly at x=0.

  • All syncs are also applied on openwindow, closewindow, and configreloaded
    as a safety net.

SETUP
─────
~/.config/hypr/hyprland.conf:
    scrolling {
        fullscreen_on_one_column = false
        column_width             = 0.40
        # ... rest of your scrolling config
    }
    exec-once = python3 /path/to/hyprland_scrolling_first_window.py

Requires Python 3.10+ — no pip packages needed.
"""

from __future__ import annotations

import json
import logging
import os
import socket
import subprocess
import sys
import time
from typing import Optional

# ── Logging ──────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%H:%M:%S",
    stream=sys.stdout,
)
log = logging.getLogger("hypr-scroll-fw")


# ── IPC helpers ──────────────────────────────────────────────────────────────

def _run(*args: str, timeout: int = 3) -> str:
    """Run hyprctl and return stdout, empty string on any error."""
    try:
        r = subprocess.run(
            ["hyprctl", *args],
            capture_output=True, text=True, timeout=timeout,
        )
        return r.stdout.strip()
    except Exception as exc:
        log.debug("hyprctl %s failed: %s", args, exc)
        return ""


def _json(*args: str) -> object:
    """Run hyprctl and return parsed JSON, or None on failure."""
    raw = _run(*args)
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        log.debug("JSON parse error for hyprctl %s: %s", args, exc)
        return None


def layoutmsg(msg: str) -> None:
    """hyprctl dispatch layoutmsg <msg>  — always targets the active workspace."""
    result = _run("dispatch", "layoutmsg", msg)
    log.debug("layoutmsg %r → %r", msg, result)


def keyword(key: str, value: str) -> None:
    """hyprctl keyword <key> <value>  — live config override."""
    _run("keyword", key, value)


def getoption_float(option: str) -> Optional[float]:
    """
    Read a float config option via `hyprctl -j getoption`.
    Verified format: {"option": "...", "float": 0.400000, "set": true}
    """
    data = _json("-j", "getoption", option)
    if isinstance(data, dict) and "float" in data:
        return float(data["float"])
    return None


# ── Queries ──────────────────────────────────────────────────────────────────

def socket2_path() -> str:
    """Return the path to Hyprland's socket2 event socket."""
    his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if not his:
        raise RuntimeError("HYPRLAND_INSTANCE_SIGNATURE is not set.")
    xdg = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    return f"{xdg}/hypr/{his}/.socket2.sock"


def get_active_workspace() -> Optional[dict]:
    """
    Return the active workspace dict, or None on failure.
    Verified fields: id (int), name (str), tiledLayout (str), windows (int)
    """
    data = _json("-j", "activeworkspace")
    if isinstance(data, dict):
        return data
    return None


def tiled_count(workspace_id: int) -> int:
    """
    Count non-floating, non-hidden, mapped tiled windows on a workspace.

    Verified client fields (from hyprland_info.txt):
      workspace.id  — int
      floating      — bool
      hidden        — bool
      mapped        — bool
    """
    clients = _json("-j", "clients")
    if not isinstance(clients, list):
        return 0
    return sum(
        1 for c in clients
        if c.get("workspace", {}).get("id") == workspace_id
        and not c.get("floating", False)
        and not c.get("hidden", False)
        and c.get("mapped", True)
    )


def is_scrolling_workspace(ws: dict) -> bool:
    """
    Return True only for a regular (non-special) workspace using the
    scrolling tiled layout.

    Workspace 4 in the verified live data uses "dwindle" — dispatching
    lockcameraoffset on a non-scrolling layout produces an error.
    Special workspaces have negative IDs and "special:" name prefix.
    """
    ws_id   = ws.get("id", -1)
    ws_name = ws.get("name", "")
    layout  = ws.get("tiledLayout", "")
    return ws_id > 0 and not ws_name.startswith("special:") and layout == "scrolling"


def column_width() -> float:
    """
    Read the current scrolling:column_width config value.
    Falls back to 0.40 (the user's configured value) if the query fails.
    """
    w = getoption_float("scrolling:column_width")
    return w if w is not None else 0.40


# ── Lock state ────────────────────────────────────────────────────────────────

def lock_at_left() -> None:
    """
    Pin the camera tape at offset 0 on the active workspace.

    With m_lockedOffset = 0.0, calculateCameraOffset() in the patched
    ScrollTapeController.cpp returns 0 directly, bypassing the centering
    guard entirely.  Every column is positioned from x=0.
    """
    log.info("  → lockcameraoffset 0")
    layoutmsg("lockcameraoffset 0")


def unlock_camera() -> None:
    """
    Release the camera lock on the active workspace.

    Sets m_lockedOffset = nullopt.  Normal auto-centering and scrolling
    resume.  Called only when columns fill or exceed the screen width.
    """
    log.info("  → lockcameraoffset none")
    layoutmsg("lockcameraoffset none")


# ── Core sync ─────────────────────────────────────────────────────────────────

def sync_active_workspace() -> None:
    """
    Evaluate the active workspace and apply the correct lock state.

    Decision rule:
        count * column_width < 1.0  →  lock at 0
        count * column_width >= 1.0 →  unlock

    With column_width = 0.40:
        0 windows (pre-lock for incoming first window) →  0.00 < 1.0  →  lock
        1 window                                       →  0.40 < 1.0  →  lock
        2 windows                                      →  0.80 < 1.0  →  lock
        3+ windows                                     →  1.20 >= 1.0 →  unlock

    Locking at 0 with columns that don't fill the screen pins them all to
    the left edge (x=0, x=0.40W, x=0.80W ...) with no centering shift.
    Unlocking when columns fill the screen restores normal scrolling so the
    user can navigate left and right as expected.

    This function is a no-op if:
      - the active workspace cannot be queried
      - the active workspace is not a regular scrolling-layout workspace
    """
    ws = get_active_workspace()
    if ws is None:
        log.debug("sync_active_workspace: could not get active workspace")
        return

    if not is_scrolling_workspace(ws):
        log.debug(
            "sync_active_workspace: ws '%s' (id=%d, layout=%r) — skipping",
            ws.get("name"), ws.get("id"), ws.get("tiledLayout"),
        )
        return

    ws_id    = ws["id"]
    ws_name  = ws["name"]
    count    = tiled_count(ws_id)
    col_w    = column_width()
    fraction = count * col_w

    log.info(
        "sync ws '%s' (id=%d) — %d tiled window(s), %.2f * %.2f = %.2f",
        ws_name, ws_id, count, count, col_w, fraction,
    )

    if fraction < 1.0:
        lock_at_left()
    else:
        unlock_camera()


# ── Event handlers ────────────────────────────────────────────────────────────

def on_workspacev2(payload: str) -> None:
    """
    socket2 event:  workspacev2>>workspaceid,workspacename

    This is the primary mechanism for Issue 1 (instant left-alignment).

    By syncing here — which includes locking for empty (count=0) workspaces —
    m_lockedOffset is set on the controller BEFORE newTarget() is called for
    the first window.  When newTarget() calls recalculate() at the end,
    calculateCameraOffset() returns 0 immediately via the lock guard, placing
    the column at x=0.  No second animation occurs.

    The sync also corrects workspaces that gained or lost windows while the
    user was on another workspace.
    """
    # Minimal sleep: let activeworkspace reflect the switch before querying.
    time.sleep(0.02)

    parts = payload.split(",", 1)
    if len(parts) < 2:
        log.debug("on_workspacev2: malformed payload %r", payload)
        return

    try:
        ws_id = int(parts[0])
    except ValueError:
        log.debug("on_workspacev2: could not parse id from %r", payload)
        return

    ws_name = parts[1]

    if ws_id < 0 or ws_name.startswith("special:"):
        log.debug("on_workspacev2: ignoring special workspace '%s'", ws_name)
        return

    log.info("workspacev2 → switched to ws '%s' (id=%d)", ws_name, ws_id)
    sync_active_workspace()


def on_openwindow(payload: str) -> None:
    """
    socket2 event:  openwindow>>windowaddress,workspacename,windowclass,windowtitle

    Safety net for windows that open on the active workspace.
    The pre-lock in on_workspacev2 handles the no-animation case for the first
    window.  This handler corrects any case that workspacev2 did not cover
    (e.g. a window opened by a rule on the currently active workspace without
    a workspace switch).

    Only acts on the currently active workspace.  Windows that open on
    non-active workspaces are corrected by on_workspacev2 when the user
    switches there.
    """
    # The openwindow event fires after the compositor has placed the window.
    # A minimal sleep ensures tiled_count() is accurate.
    time.sleep(0.02)

    parts = payload.split(",", 3)
    if len(parts) < 2:
        log.debug("on_openwindow: malformed payload %r", payload)
        return

    ws_name = parts[1]

    if ws_name.startswith("special:"):
        log.debug("on_openwindow: ignoring special workspace '%s'", ws_name)
        return

    # Only act if this workspace is currently active.
    active_ws = get_active_workspace()
    if active_ws is None:
        return
    if active_ws.get("name") != ws_name:
        log.debug(
            "on_openwindow: ws '%s' is not active (active='%s') — skipping",
            ws_name, active_ws.get("name"),
        )
        return

    log.info("openwindow on active ws '%s'", ws_name)
    sync_active_workspace()


def on_closewindow(_payload: str) -> None:
    """
    socket2 event:  closewindow>>windowaddress

    The closed window may have been on the active workspace.  Sync to
    re-apply a lock if the workspace dropped below the fill threshold.
    A slightly longer sleep ensures the client is no longer in the
    clients list before tiled_count() queries it.
    """
    time.sleep(0.05)
    log.info("closewindow — syncing active workspace")
    sync_active_workspace()


def on_configreloaded() -> None:
    """
    socket2 event:  configreloaded>>  (empty payload, per EventManager.cpp)

    A config reload re-reads hyprland.conf.  The user has
    fullscreen_on_one_column = false there, but we re-apply the keyword as a
    safety net regardless.

    m_lockedOffset on each workspace's CScrollTapeController is not touched
    by the configCallback in CScrollingAlgorithm (which only updates
    configuredWidths and direction), so individual workspace locks survive
    the reload.  We only need to re-sync the active workspace.
    """
    log.info("configreloaded — re-applying keyword override and syncing")
    keyword("scrolling:fullscreen_on_one_column", "false")
    time.sleep(0.05)
    sync_active_workspace()


# ── Event loop ────────────────────────────────────────────────────────────────

def process(line: str) -> None:
    """
    Dispatch a single socket2 event line.
    Format per EventManager.cpp formatEvent():  EVENTTYPE>>DATA\n
    (newlines in data are replaced with spaces; data truncated to 1024 chars)
    """
    if line.startswith("workspacev2>>"):
        on_workspacev2(line[len("workspacev2>>"):])

    elif line.startswith("openwindow>>"):
        on_openwindow(line[len("openwindow>>"):])

    elif line.startswith("closewindow>>"):
        on_closewindow(line[len("closewindow>>"):])

    elif line.startswith("configreloaded>>"):
        on_configreloaded()


def run() -> None:
    """
    Connect to Hyprland's socket2 and process events indefinitely.
    Reconnects automatically on socket drop.
    """
    path = socket2_path()
    log.info("Connecting to %s …", path)

    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
                sock.connect(path)
                log.info("Connected. Listening for events.")

                buf = ""
                while True:
                    chunk = sock.recv(4096)
                    if not chunk:
                        log.warning("Socket closed by compositor — reconnecting …")
                        break
                    buf += chunk.decode("utf-8", errors="replace")
                    # EventManager sends one event per line, terminated by \n
                    while "\n" in buf:
                        line, buf = buf.split("\n", 1)
                        line = line.strip()
                        if line:
                            process(line)

        except FileNotFoundError:
            log.error("Socket not found: %s — retrying in 3 s …", path)
            time.sleep(3)
        except (ConnectionRefusedError, OSError) as exc:
            log.error("Socket error: %s — retrying in 1 s …", exc)
            time.sleep(1)


# ── Entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    if not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        print(
            "Error: HYPRLAND_INSTANCE_SIGNATURE is not set.\n"
            "This script must run inside a live Hyprland session.",
            file=sys.stderr,
        )
        sys.exit(1)

    log.info("═" * 58)
    log.info("Hyprland Scrolling Layout — First-Window Manager")
    log.info("(patched build: lockcameraoffset IPC available)")
    log.info("═" * 58)

    # Apply the keyword override immediately at startup.
    keyword("scrolling:fullscreen_on_one_column", "false")
    log.info("fullscreen_on_one_column = false applied.")

    # Sync the active workspace on startup.
    # workspacev2 does not fire for the initial workspace at launch, so
    # we evaluate it manually here.
    time.sleep(0.05)
    sync_active_workspace()

    run()


if __name__ == "__main__":
    main()
