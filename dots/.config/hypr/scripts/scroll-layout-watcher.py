#!/usr/bin/env python3
import os
import sys
import json
import socket
import time

SOCKET1_PATH = ""
SOCKET2_PATH = ""
WS_WINDOW_COUNTS = {}
CURRENT_SCROLL_STATE = -1


def init_sockets():
    global SOCKET1_PATH, SOCKET2_PATH
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not signature:
        sys.exit(1)

    xdg_runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    for sock_type in ["1", "2"]:
        path_xdg = f"{xdg_runtime}/hypr/{signature}/.socket{sock_type}.sock"
        path_tmp = f"/tmp/hypr/{signature}/.socket{sock_type}.sock"

        if xdg_runtime and os.path.exists(path_xdg):
            selected = path_xdg
        elif os.path.exists(path_tmp):
            selected = path_tmp
        else:
            selected = path_xdg

        if sock_type == "1":
            SOCKET1_PATH = selected
        else:
            SOCKET2_PATH = selected


def hyprctl_json(command):
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.connect(SOCKET1_PATH)
            client.sendall(f"j/{command}".encode("utf-8"))
            response = b""
            # Drains socket safely
            while True:
                data = client.recv(8192)
                if not data:
                    break
                response += data
            decoded = response.decode("utf-8")
            return json.loads(decoded) if decoded.strip() else None
    except Exception:
        return None


def hyprctl_batch(commands):
    if not commands:
        return
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.connect(SOCKET1_PATH)
            cmd_str = "[[BATCH]]" + ";".join(commands)
            client.sendall(cmd_str.encode("utf-8"))

            # CRITICAL FIX: Fully drain the IPC socket before closing.
            # This prevents Hyprland from suffering a Broken Pipe, which
            # is what previously froze `unified-dispatch.sh` and `hyprctl`.
            while True:
                if not client.recv(8192):
                    break
    except Exception:
        pass


def update_layout(event_line=None):
    global CURRENT_SCROLL_STATE, WS_WINDOW_COUNTS
    try:
        active_ws_data = hyprctl_json("activeworkspace")
        if not active_ws_data:
            return

        # Reliably detect layout using the exact same logic as your Bash script
        layout = active_ws_data.get("layout", "").lower()
        ws_id = active_ws_data.get("id", -1)

        if layout:
            is_scrolling = layout == "scrolling"
        else:
            # Fallback mapping exactly mirroring your WS_LAYOUT in unified-dispatch
            is_scrolling = ws_id in [1, 2, 3, 10, 11, 12]

        # If not a scrolling workspace, back off entirely so unified-dispatch works flawlessly
        if not is_scrolling:
            if CURRENT_SCROLL_STATE != 0:
                hyprctl_batch(["keyword scrolling:focus_fit_method 0"])
                CURRENT_SCROLL_STATE = 0
            return

        clients = hyprctl_json("clients")
        if not clients:
            return

        ws_clients = [
            c
            for c in clients
            if c.get("workspace", {}).get("id") == ws_id and not c.get("floating")
        ]
        count = len(ws_clients)

        last_count = WS_WINDOW_COUNTS.get(ws_id, 0)
        WS_WINDOW_COUNTS[ws_id] = count

        if count == 2:
            cmds = []
            if CURRENT_SCROLL_STATE != 1:
                cmds.append("keyword scrolling:focus_fit_method 1")
                CURRENT_SCROLL_STATE = 1

            cmds.extend(
                ["dispatch layoutmsg fit tobeg", "dispatch layoutmsg move -9999"]
            )

            is_workspace_switch = event_line and event_line.startswith("workspace")

            # Cursor warping hack to prevent 3rd window placement bugs
            if last_count != 2 and not is_workspace_switch:
                active_window_data = hyprctl_json("activewindow")
                active_addr = (
                    active_window_data.get("address") if active_window_data else None
                )

                if active_addr:
                    other_window = next(
                        (c for c in ws_clients if c.get("address") != active_addr), None
                    )
                    if other_window:
                        cmds.append(
                            f"dispatch focuswindow address:{other_window.get('address')}"
                        )
                    cmds.append(f"dispatch focuswindow address:{active_addr}")

            hyprctl_batch(cmds)
        else:
            if CURRENT_SCROLL_STATE != 0:
                hyprctl_batch(["keyword scrolling:focus_fit_method 0"])
                CURRENT_SCROLL_STATE = 0

    except Exception:
        pass


def main():
    init_sockets()
    update_layout()

    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
                client.connect(SOCKET2_PATH)
                buffer = ""
                while True:
                    data = client.recv(4096).decode("utf-8")
                    if not data:
                        break
                    buffer += data
                    while "\n" in buffer:
                        line, buffer = buffer.split("\n", 1)
                        if line.startswith(
                            (
                                "openwindow>>",
                                "closewindow>>",
                                "movewindow>>",
                                "changefloatingmode>>",
                                "workspace",
                            )
                        ):
                            update_layout(line)
        except Exception:
            time.sleep(3)


if __name__ == "__main__":
    main()
