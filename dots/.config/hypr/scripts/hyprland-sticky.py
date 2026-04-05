#!/usr/bin/env python3
"""
nsticky equivalent for Hyprland.
Sticky windows across workspaces and stage workspace.
"""

import os
import sys
import json
import subprocess
import socket
import signal
from pathlib import Path

STATE_FILE = Path.home() / ".config/hypr/sticky_state.json"
STAGE_WORKSPACE = "stage"


class StickyManager:
    def __init__(self):
        self.sticky_windows = set()
        self.staged_windows = set()
        self.running = True
        self.load_state()
        signal.signal(signal.SIGTERM, self._shutdown)
        signal.signal(signal.SIGINT, self._shutdown)

    def _shutdown(self, *args):
        self.running = False

    def hyprctl(self, command, json_output=False):
        cmd = ["hyprctl", "-j", command] if json_output else ["hyprctl", command]
        res = subprocess.run(cmd, capture_output=True, text=True)
        return json.loads(res.stdout) if json_output else res.stdout

    def dispatch(self, command):
        subprocess.run(["hyprctl", "dispatch", command], capture_output=True)

    def load_state(self):
        try:
            with open(STATE_FILE) as f:
                data = json.load(f)
                self.sticky_windows = set(data.get("sticky", []))
                self.staged_windows = set(data.get("staged", []))
        except:
            pass

    def save_state(self):
        with open(STATE_FILE, "w") as f:
            json.dump(
                {
                    "sticky": list(self.sticky_windows),
                    "staged": list(self.staged_windows),
                },
                f,
            )

    def get_focused_window(self):
        active = self.hyprctl("activewindow", json_output=True)
        return active.get("address") if active else None

    def toggle_sticky(self):
        addr = self.get_focused_window()
        if not addr:
            return
        if addr in self.sticky_windows:
            self.sticky_windows.remove(addr)
            self.dispatch(f"pin address:{addr} off")
        else:
            self.sticky_windows.add(addr)
            self.dispatch(f"pin address:{addr}")
            self.dispatch(f"movetoworkspace current,address:{addr}")
        self.save_state()

    def toggle_stage(self):
        addr = self.get_focused_window()
        if not addr:
            return
        if addr in self.staged_windows:
            self.staged_windows.remove(addr)
            self.dispatch(f"movetoworkspace current,address:{addr}")
        else:
            if addr not in self.sticky_windows:
                self.toggle_sticky()
            self.staged_windows.add(addr)
            self.dispatch(f"movetoworkspace {STAGE_WORKSPACE},address:{addr}")
        self.save_state()

    def on_workspace_change(self, new_ws):
        if new_ws == STAGE_WORKSPACE:
            return
        for addr in self.sticky_windows:
            if addr not in self.staged_windows:
                self.dispatch(f"movetoworkspace {new_ws},address:{addr}")

    def run_daemon(self):
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        if not sig:
            return
        sock_path = f"/tmp/hypr/{sig}/.socket2.sock"
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
                sock.connect(sock_path)
                sock.setblocking(True)
                with sock.makefile() as f:
                    while self.running:
                        line = f.readline()
                        if not line:
                            break
                        if line.startswith("workspace>>"):
                            ws = line.split(">>")[1].strip()
                            self.on_workspace_change(ws)
                        elif "closewindow>>" in line:
                            addr = line.split(">>")[1].strip()
                            if addr in self.sticky_windows:
                                self.sticky_windows.remove(addr)
                            if addr in self.staged_windows:
                                self.staged_windows.remove(addr)
                            self.save_state()
        except Exception as e:
            print(f"Sticky daemon error: {e}", file=sys.stderr)

    def command(self, cmd):
        if cmd == "toggle":
            self.toggle_sticky()
        elif cmd == "stage-toggle":
            self.toggle_stage()


if __name__ == "__main__":
    mgr = StickyManager()
    if len(sys.argv) > 1:
        mgr.command(sys.argv[1])
    else:
        mgr.run_daemon()
