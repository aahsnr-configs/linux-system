-- Autostart programs
-- Verified: hl.on("hyprland.start", ...) fires once at startup
-- This replaces the legacy exec-once = ... syntax

hl.on("hyprland.start", function()
	hl.exec_cmd("dbus-update-activation-environment --systemd --all")
	hl.exec_cmd("systemctl --user start hyprland-session.target")
	hl.exec_cmd("udiskie")
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
	hl.exec_cmd("noctalia")
	hl.exec_cmd("hyprpm reload -n")
	hl.exec_cmd("pypr")
	hl.exec_cmd("emacs --daemon")
end)
