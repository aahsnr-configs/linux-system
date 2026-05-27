#!/usr/bin/env python3
"""
niri-sidebar equivalent for Hyprland.
Manages a vertical stack of windows on the right edge.
Commands: toggle, toggle-visibility, flip, reorder, listen
"""

import os
import sys
import json
import subprocess
import signal
import socket
from pathlib import Path

CONFIG_DIR = Path.home() / ".config/hypr/sidebar"
STATE_FILE = CONFIG_DIR / "state.json"

DEFAULT_CONFIG = {
    "width": 400,
    "height": 335,
    "gap": 10,
    "margins": {"top": 50, "right": 10, "bottom": 10, "left": 10},
    "position": "right",
    "peek": 10,
    "focus_peek": 50,
    "sticky": False,
}


class SidebarManager:
    def __init__(self):
        self.config = self.load_config()
        self.state = self.load_state()
        self.window_list = self.state.get("windows", [])
        self.visible = True
        self.running = True
        signal.signal(signal.SIGTERM, self._shutdown)
        signal.signal(signal.SIGINT, self._shutdown)

    def _shutdown(self, *args):
        self.running = False

    def load_config(self):
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        # For simplicity, use defaults; could load TOML
        return DEFAULT_CONFIG

    def load_state(self):
        if STATE_FILE.exists():
            try:
                with open(STATE_FILE) as f:
                    return json.load(f)
            except:
                pass
        return {"windows": []}

    def save_state(self):
        with open(STATE_FILE, "w") as f:
            json.dump({"windows": self.window_list}, f)

    def hyprctl(self, command, json_output=False):
        cmd = ["hyprctl", "-j", command] if json_output else ["hyprctl", command]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if json_output:
            return json.loads(res.stdout) if res.stdout else {}
        return res.stdout

    def dispatch(self, command):
        subprocess.run(["hyprctl", "dispatch", command], capture_output=True)

    def get_focused_window(self):
        active = self.hyprctl("activewindow", json_output=True)
        return active.get("address") if active else None

    def get_sidebar_geometry(self):
        monitor = self.hyprctl("monitors", json_output=True)[0]
        mon_w = monitor["width"]
        mon_h = monitor["height"]
        width = self.config["width"]
        margins = self.config["margins"]
        x = mon_w - width - margins["right"]
        y = margins["top"]
        h = mon_h - margins["top"] - margins["bottom"]
        return (x, y, width, h)

    def reposition_window(self, address):
        x, y, w, h = self.get_sidebar_geometry()
        self.dispatch(f"movewindowpixel {x} {y},address:{address}")
        self.dispatch(f"resizewindowpixel exact {w} {h},address:{address}")
        self.dispatch(f"pin address:{address}")

    def reorder_sidebar(self):
        if not self.visible:
            return
        x, y, w, h = self.get_sidebar_geometry()
        gap = self.config["gap"]
        num = len(self.window_list)
        if num == 0:
            return
        win_h = (h - (num - 1) * gap) // num
        cur_y = y
        for addr in self.window_list:
            self.dispatch(f"movewindowpixel {x} {cur_y},address:{addr}")
            self.dispatch(f"resizewindowpixel exact {w} {win_h},address:{addr}")
            self.dispatch(f"pin address:{addr}")
            cur_y += win_h + gap

    def toggle_window(self):
        addr = self.get_focused_window()
        if not addr:
            return
        if addr in self.window_list:
            self.window_list.remove(addr)
            self.dispatch(f"pin address:{addr} off")
        else:
            self.window_list.append(addr)
            self.reposition_window(addr)
        self.reorder_sidebar()
        self.save_state()

    def toggle_visibility(self):
        self.visible = not self.visible
        if self.visible:
            self.reorder_sidebar()
        else:
            x, y, w, h = self.get_sidebar_geometry()
            off_x = -w - 100
            for addr in self.window_list:
                self.dispatch(f"movewindowpixel {off_x} {y},address:{addr}")

    def flip(self):
        self.window_list.reverse()
        self.reorder_sidebar()
        self.save_state()

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
                        if "closewindow>>" in line:
                            addr = line.split(">>")[1].strip()
                            if addr in self.window_list:
                                self.window_list.remove(addr)
                                self.save_state()
                                self.reorder_sidebar()
                        if (
                            not self.config.get("sticky", False)
                            and "workspace>>" in line
                        ):
                            self.reorder_sidebar()
        except Exception as e:
            print(f"Sidebar daemon error: {e}", file=sys.stderr)

    def command(self, cmd):
        if cmd == "toggle":
            self.toggle_window()
        elif cmd == "toggle-visibility":
            self.toggle_visibility()
        elif cmd == "flip":
            self.flip()
        elif cmd == "reorder":
            self.reorder_sidebar()


if __name__ == "__main__":
    mgr = SidebarManager()
    if len(sys.argv) > 1:
        if sys.argv[1] == "listen":
            mgr.run_daemon()
        else:
            mgr.command(sys.argv[1])
    else:
        mgr.command("toggle")
