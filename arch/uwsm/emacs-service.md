Based on my research, here's how to configure emacs.service to work properly with uwsm and see output when starting it:

## Part 1: Making emacs.service Start After graphical-session.target

The emacs.service file shipped by pacman is located at `/usr/lib/systemd/user/emacs.service`. According to the default configuration, it has `WantedBy=default.target` which starts it at login, not after the graphical session.

**To override it for uwsm compatibility, create a drop-in:**

```bash
systemctl --user edit emacs.service
```

This will open an editor for a drop-in file at `~/.config/systemd/user/emacs.service.d/override.conf`. Add:

```ini
[Unit]
After=graphical-session.target
PartOf=graphical-session.target

[Install]
# Remove default.target, add graphical-session.target
WantedBy=
WantedBy=graphical-session.target
```

**Key points:**

- `After=graphical-session.target` - Delays start until graphical session is active
- `PartOf=graphical-session.target` - Makes emacs stop when graphical session ends
- `WantedBy=` (empty line) - **Clears** the original `default.target` from the packaged service
- `WantedBy=graphical-session.target` - Makes it start with graphical session

**Alternative manual method:**

```bash
mkdir -p ~/.config/systemd/user/emacs.service.d/
cat > ~/.config/systemd/user/emacs.service.d/override.conf << 'EOF'
[Unit]
After=graphical-session.target
PartOf=graphical-session.target

[Install]
WantedBy=
WantedBy=graphical-session.target
EOF
```

**Then reload and re-enable:**

```bash
systemctl --user daemon-reload
systemctl --user disable emacs.service  # Remove old symlink
systemctl --user enable emacs.service   # Create new symlink in graphical-session.target.wants
```

## Part 2: Seeing Output When Starting the Service

To see output when you start emacs.service, use `journalctl` with the `-f` (follow) flag:

**Or start and immediately view logs:**

```bash
systemctl --user start emacs.service && journalctl --user -u emacs.service -n
```
