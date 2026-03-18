#!/usr/bin/env python3
"""
scroll-layout-watch.py  —  Hyprland scrolling-layout left-aligner
"""

from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
import threading
import time
from typing import Optional

# ── tunables ─────────────────────────────────────────────────────────────────

# 20ms debounce ensures Hyprland fully maps the window so the script can see it.
# Because follow_focus is dynamically disabled, this delay is completely invisible.
DEBOUNCE_S: float = 0.02

# ─────────────────────────────────────────────────────────────────────────────

_timer: Optional[threading.Timer] = None
_lock = threading.Lock()
_warp_needed: bool = False
_follow_focus_enabled: bool = True  # Tracks native state

# ── IPC helpers ───────────────────────────────────────────────────────────────


def _socket2_path() -> str:
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not sig:
        print("[scroll-watch] HYPRLAND_INSTANCE_SIGNATURE not set.", file=sys.stderr)
        sys.exit(1)
    xdg = os.environ.get("XDG_RUNTIME_DIR", "")
    xdg_p = f"{xdg}/hypr/{sig}/.socket2.sock"
    tmp_p = f"/tmp/hypr/{sig}/.socket2.sock"
    return xdg_p if (xdg and os.path.exists(xdg_p)) else tmp_p


def _hyprctl(*args: str) -> str:
    try:
        return subprocess.check_output(
            ["hyprctl", *args], stderr=subprocess.DEVNULL
        ).decode("utf-8", errors="replace")
    except Exception:
        return ""


def _batch(*cmds: str) -> None:
    if not cmds:
        return
    try:
        subprocess.run(
            ["hyprctl", "--batch", " ; ".join(cmds)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
    except Exception as exc:
        print(f"[scroll-watch] _batch error: {exc}", file=sys.stderr)


# ── core logic ────────────────────────────────────────────────────────────────


def _active_workspace_id() -> Optional[int]:
    raw = _hyprctl("activeworkspace", "-j")
    if not raw:
        return None
    try:
        return json.loads(raw).get("id")
    except json.JSONDecodeError:
        return None


def _check_and_align() -> None:
    global _warp_needed, _follow_focus_enabled
    warp = _warp_needed
    _warp_needed = False

    ws_id = _active_workspace_id()
    if ws_id is None or ws_id < 0:
        return

    raw = _hyprctl("clients", "-j")
    if not raw:
        return

    try:
        clients = json.loads(raw)
    except json.JSONDecodeError:
        return

    tiled = [
        c
        for c in clients
        if c.get("workspace", {}).get("id") == ws_id
        and not c.get("floating", False)
        and c.get("mapped", True)
    ]

    count = len(tiled)

    # 1 Window: Snap left, and disable follow_focus to prep for Window 2
    if count == 1:
        cmds = []
        if _follow_focus_enabled:
            cmds.append("keyword scrolling:follow_focus 0")
            _follow_focus_enabled = False

        cmds.extend(
            [
                "keyword animations:enabled 0",
                "dispatch layoutmsg move -100000",
                "keyword animations:enabled 1",
            ]
        )
        _batch(*cmds)
        return

    # 2 Windows: Snap left, warp cursor, and ensure follow_focus is off
    if count == 2:
        cmds = []
        if _follow_focus_enabled:
            cmds.append("keyword scrolling:follow_focus 0")
            _follow_focus_enabled = False

        cmds.extend(["keyword animations:enabled 0", "dispatch layoutmsg move -100000"])

        if warp:
            tiled.sort(key=lambda c: c.get("at", [0, 0])[0])
            win1_addr = tiled[0].get("address")
            win2_addr = tiled[1].get("address")

            raw_active = _hyprctl("activewindow", "-j")
            active_addr = None
            if raw_active:
                try:
                    active_addr = json.loads(raw_active).get("address")
                except Exception:
                    pass

            target_addr = win1_addr if active_addr == win1_addr else win2_addr
            other_addr = win2_addr if target_addr == win1_addr else win1_addr

            if target_addr and other_addr:
                cmds.append(f"dispatch focuswindow address:{other_addr}")
                cmds.append(f"dispatch focuswindow address:{target_addr}")

        cmds.append("keyword animations:enabled 1")
        _batch(*cmds)
        return

    # 3+ Windows: Re-enable follow_focus so normal scrolling resumes
    if count > 2:
        if not _follow_focus_enabled:
            cmds = ["keyword scrolling:follow_focus 1"]
            _follow_focus_enabled = True

            # Since follow_focus was off when the 3rd window opened, it won't scroll
            # into view automatically. We trigger focuswindow to force the layout to scroll.
            raw_active = _hyprctl("activewindow", "-j")
            if raw_active:
                try:
                    active_addr = json.loads(raw_active).get("address")
                    if active_addr:
                        cmds.append(f"dispatch focuswindow address:{active_addr}")
                except Exception:
                    pass

            _batch(*cmds)
        return


# ── debounce ──────────────────────────────────────────────────────────────────


def _schedule() -> None:
    global _timer
    with _lock:
        if _timer is not None:
            _timer.cancel()
        t = threading.Timer(DEBOUNCE_S, _check_and_align)
        t.daemon = True
        _timer = t
        t.start()


# ── event routing ─────────────────────────────────────────────────────────────

_TRIGGERS = (
    "openwindow>>",
    "closewindow>>",
    "movewindow>>",
    "workspace>>",
    "focusedmon>>",
)


def _handle(line: str) -> None:
    global _warp_needed
    if any(line.startswith(t) for t in _TRIGGERS):
        if line.startswith("openwindow>>"):
            _warp_needed = True
        _schedule()


# ── main loop ─────────────────────────────────────────────────────────────────


def main() -> None:
    sock_path = _socket2_path()
    print(f"[scroll-watch] Connecting to {sock_path}")

    _check_and_align()

    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(sock_path)
                buf = ""
                while True:
                    data = s.recv(4096).decode("utf-8", errors="replace")
                    if not data:
                        break
                    buf += data
                    while "\n" in buf:
                        line, buf = buf.split("\n", 1)
                        _handle(line.strip())
        except Exception as exc:
            print(
                f"[scroll-watch] socket error ({exc}) — reconnecting in 3 s",
                file=sys.stderr,
            )
            time.sleep(3)


if __name__ == "__main__":
    main()
