#!/usr/bin/env python3
"""
hyprland_scrolling_first_window.py
───────────────────────────────────────────────────────────────────────────────
Hyprland v0.54.2 scrolling layout — left-alignment manager.

Requires the patched Hyprland build (ScrollTapeController.cpp) which makes
two changes to calculateCameraOffset():

  1. When content fits in the viewport (maxExtent < usablePrimary):
       m_offset = 0.0          ← left-aligned (was: centered)

  2. lockcameraoffset layoutmsg added for optional manual camera locking.

WHY THIS SCRIPT IS NOW MINIMAL
───────────────────────────────
All layout behaviour is now enforced by the C++ engine on every recalculate():

  • Single window, col_w=0.40:
      maxExtent=0.40W < W  →  m_offset=0  →  column at x=0  (left)        ✓

  • Two windows, col_w=0.40:
      maxExtent=0.80W < W  →  m_offset=0  →  columns at x=0, x=0.40W      ✓

  • Third window opens (col_w=0.40):
      newTarget() → fitCol(col3) → fitStrip(2):
        clamp(0, stripStart-W+stripSize, stripStart)
        = clamp(0, 0.20W, 0.80W) = 0.20W  →  m_offset=0.20W
      recalculate(): maxExtent=1.20W >= W  →  guard inactive, stays 0.20W  ✓
      Window 3 at: 0.80W - 0.20W = 0.60W, right edge = 1.00W  (flush)     ✓

  • Any resize:
      recalculate() fires → calculateCameraOffset() applies the same rules
      automatically regardless of which app was resized or how.              ✓

  • No socket2 events are needed. There is no resize event on socket2 anyway.

This script's only job is to ensure fullscreen_on_one_column stays false,
because if it were true the single-column case would expand to full width
(calculateMaxExtent returns usablePrimary for 1 strip), making the
left-align guard (maxExtent < usablePrimary) never fire.

SETUP
─────
~/.config/hypr/hyprland.conf:
    scrolling {
        fullscreen_on_one_column = false
        column_width             = 0.40
    }
    exec-once = python3 /path/to/hyprland_scrolling_first_window.py

Requires Python 3.10+ — no pip packages needed.
"""

from __future__ import annotations

import logging
import os
import socket
import subprocess
import sys
import time

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


def keyword(key: str, value: str) -> None:
    """hyprctl keyword <key> <value> — live config override."""
    _run("keyword", key, value)


def apply_config_overrides() -> None:
    """
    Ensure fullscreen_on_one_column = false is active.

    Why this matters:
      With fullscreen_on_one_column = true (the upstream default), a single
      column causes calculateMaxExtent() to return usablePrimary regardless
      of the column's actual width fraction. This makes the left-align guard
        if (maxExtent < usablePrimary) m_offset = 0.0;
      never fire for a single window, so left-alignment is not applied.

    With fullscreen_on_one_column = false and col_w=0.40:
      calculateMaxExtent() = 0.40 * usablePrimary < usablePrimary
      → guard fires → m_offset = 0.0 → column at x=0  ✓

    The user already has this in hyprland.conf; the keyword call here is a
    safety net so it takes effect immediately on startup before the first
    window opens, and is re-applied after every config reload.
    """
    keyword("scrolling:fullscreen_on_one_column", "false")
    log.info("fullscreen_on_one_column = false applied.")


# ── Socket path ───────────────────────────────────────────────────────────────

def socket2_path() -> str:
    """Return the path to Hyprland's socket2 event socket."""
    his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if not his:
        raise RuntimeError("HYPRLAND_INSTANCE_SIGNATURE is not set.")
    xdg = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    return f"{xdg}/hypr/{his}/.socket2.sock"


# ── Event handling ────────────────────────────────────────────────────────────

def process(line: str) -> None:
    """
    Dispatch a single socket2 event line.
    Format per EventManager.cpp formatEvent():  EVENTTYPE>>DATA

    Only configreloaded is handled — it is the only event that can undo
    the fullscreen_on_one_column = false keyword override.
    All layout behaviour (left-align, overflow scroll, resize) is handled
    natively by the patched C++ engine.
    """
    if line.startswith("configreloaded>>"):
        log.info("configreloaded — re-applying overrides.")
        apply_config_overrides()


def run() -> None:
    """Connect to socket2 and process events. Reconnects on socket drop."""
    path = socket2_path()
    log.info("Connecting to %s …", path)

    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
                sock.connect(path)
                log.info("Connected. Listening for configreloaded events.")

                buf = ""
                while True:
                    chunk = sock.recv(4096)
                    if not chunk:
                        log.warning("Socket closed — reconnecting …")
                        break
                    buf += chunk.decode("utf-8", errors="replace")
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
    log.info("Hyprland Scrolling Layout — Left-Alignment Manager")
    log.info("(patched build: left-align default + lockcameraoffset)")
    log.info("═" * 58)

    apply_config_overrides()
    run()


if __name__ == "__main__":
    main()
