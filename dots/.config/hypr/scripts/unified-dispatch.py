#!/usr/bin/env python3
import os
import sys
import json
import socket

# --- FALLBACK WORKSPACE TABLE ---
# Covers both your workspaces.conf (1-9) and your previous bash script array (10-18)
WS_LAYOUT = {
    1: "scrolling",
    2: "scrolling",
    3: "scrolling",
    4: "dwindle",
    5: "dwindle",
    6: "dwindle",
    7: "master",
    8: "master",
    9: "monocle",
    10: "scrolling",
    11: "scrolling",
    12: "scrolling",
    13: "dwindle",
    14: "dwindle",
    15: "dwindle",
    16: "master",
    17: "master",
    18: "monocle",
}


def get_socket_path():
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not signature:
        sys.exit(1)

    xdg_runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    path_xdg = f"{xdg_runtime}/hypr/{signature}/.socket1.sock"
    path_tmp = f"/tmp/hypr/{signature}/.socket1.sock"

    if xdg_runtime and os.path.exists(path_xdg):
        return path_xdg
    if os.path.exists(path_tmp):
        return path_tmp
    return path_xdg


SOCKET1_PATH = get_socket_path()


def hypr_request(command, is_json=False):
    """Sends a raw command to Hyprland's IPC socket for zero-overhead execution."""
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.connect(SOCKET1_PATH)
            prefix = "j/" if is_json else "/"
            client.sendall(f"{prefix}{command}".encode("utf-8"))

            response = b""
            while True:
                data = client.recv(8192)
                if not data:
                    break
                response += data

            decoded = response.decode("utf-8")
            if is_json:
                return json.loads(decoded) if decoded.strip() else None
            return decoded
    except Exception as e:
        print(f"IPC Error: {e}", file=sys.stderr)
        return None


def get_active_layout():
    ws_data = hypr_request("activeworkspace", is_json=True)
    if not ws_data:
        sys.exit(1)

    ws_id = ws_data.get("id", -1)
    layout = ws_data.get("layout", "").lower()

    if layout in ["scrolling", "dwindle", "master", "monocle"]:
        return layout

    # Fallback to static table if Hyprland IPC returns null
    if ws_id in WS_LAYOUT:
        return WS_LAYOUT[ws_id]

    print(f"Error: workspace {ws_id} not in WS_LAYOUT table.", file=sys.stderr)
    sys.exit(1)


def dispatch(command):
    hypr_request(f"dispatch {command}")


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <focus|movewin|resize> <l|r|u|d>", file=sys.stderr)
        sys.exit(1)

    action = sys.argv[1]
    direction = sys.argv[2]

    if direction not in ["l", "r", "u", "d"]:
        print(
            f"Error: direction must be l, r, u, or d (got: {direction})",
            file=sys.stderr,
        )
        sys.exit(1)

    layout = get_active_layout()

    # --- ACTION: FOCUS ---
    if action == "focus":
        if layout == "scrolling":
            dispatch(f"layoutmsg focus {direction}")
        elif layout in ["master", "monocle"]:
            if direction in ["r", "d"]:
                dispatch("layoutmsg cyclenext")
            else:
                dispatch("layoutmsg cycleprev")
        else:  # dwindle and fallback
            dispatch(f"movefocus {direction}")

    # --- ACTION: MOVEWIN ---
    elif action == "movewin":
        if layout == "scrolling":
            if direction == "l":
                dispatch("layoutmsg swapcol l")
            elif direction == "r":
                dispatch("layoutmsg swapcol r")
            else:
                dispatch(f"movewindow {direction}")
        elif layout == "master":
            if direction in ["r", "d"]:
                dispatch("layoutmsg rollnext")
            else:
                dispatch("layoutmsg rollprev")
        elif layout == "monocle":
            if direction in ["r", "d"]:
                dispatch("layoutmsg cyclenext")
            else:
                dispatch("layoutmsg cycleprev")
        else:
            dispatch(f"movewindow {direction}")

    # --- ACTION: RESIZE ---
    elif action == "resize":
        if layout == "scrolling":
            if direction == "l":
                dispatch("layoutmsg colresize -0.05")
            elif direction == "r":
                dispatch("layoutmsg colresize +0.05")
            elif direction == "u":
                dispatch("resizeactive 0 -60")
            elif direction == "d":
                dispatch("resizeactive 0 60")
        else:
            if direction == "l":
                dispatch("resizeactive -60 0")
            elif direction == "r":
                dispatch("resizeactive 60 0")
            elif direction == "u":
                dispatch("resizeactive 0 -60")
            elif direction == "d":
                dispatch("resizeactive 0 60")

    else:
        print(f"Error: unknown action '{action}'", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
