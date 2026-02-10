# Complete Pyprland Guide: Installation, Configuration & Usage

## Table of Contents

1. [What is Pyprland](#what-is-pyprland)
2. [Installation](#installation)
3. [Installing pypr-client (The Fast Binary)](#installing-pypr-client)
4. [Configuration](#configuration)
5. [Running Pyprland](#running-pyprland)
6. [Using with Hyprland](#using-with-hyprland)
7. [Troubleshooting the Delay Issue](#troubleshooting-the-delay-issue)

---

## What is Pyprland

Pyprland is a plugin-based extension system for Hyprland that adds features like:

- **Scratchpads** - Dropdown/toggle terminals and windows
- **Expose** - Window overview/switcher
- **Magnify** - Zoom functionality
- **Layout Center** - Center-focused window layouts
- **And many more plugins**

**Key Components:**

- `pypr` - The Python daemon that runs in the background
- `pypr-client` - A fast C binary for keybindings (must be compiled separately)
- `~/.config/hypr/pyprland.toml` - Configuration file

**Important:** When you install pyprland via pip/pipx, you only get `pypr`. You must manually compile `pypr-client` for fast keybinding response.

---

## Installation

### Install Pyprland (Python Package)

**Recommended: Using pipx (isolated environment)**

```bash
pipx install pyprland
```

**Alternative: Using pip**

```bash
pip install pyprland
```

**Verify Installation:**

```bash
pypr --version
pypr help
```

---

## Installing pypr-client (The Fast Binary)

### Why You Need This

When you press a keybinding that calls `pypr`, it has to:

1. Start a Python interpreter (~50-300ms delay)
2. Load dependencies
3. Connect to daemon
4. Execute command

`pypr-client` is a compiled C binary that:

- Executes in ~1ms
- Is specifically designed for keybindings
- Eliminates the delay completely

**CRITICAL:** The pip/pipx installation does NOT include pypr-client. You must compile it manually.

### Installation Steps

**1. Ensure you have gcc:**

```bash
# Check if installed
gcc --version

# If not, install:
# Arch/Manjaro:
sudo pacman -S gcc

# Ubuntu/Debian:
sudo apt install build-essential

# Fedora:
sudo dnf install gcc
```

**2. Download and compile pypr-client:**

```bash
# Download source
cd /tmp
curl -LO https://raw.githubusercontent.com/hyprland-community/pyprland/main/client/pypr-client.c

# Compile
gcc -o pypr-client pypr-client.c

# Install to local bin
mkdir -p ~/.local/bin
mv pypr-client ~/.local/bin/
chmod +x ~/.local/bin/pypr-client
```

**3. Ensure ~/.local/bin is in PATH:**

```bash
# Check if already in PATH
echo $PATH | grep -q "$HOME/.local/bin" && echo "✓ Already in PATH" || echo "✗ Need to add"

# If not in PATH, add to ~/.bashrc or ~/.zshrc:
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**4. Verify it works:**

```bash
pypr-client help
```

### Alternative: One-Line Installation Script

```bash
cd /tmp && \
curl -LO https://raw.githubusercontent.com/hyprland-community/pyprland/main/client/pypr-client.c && \
gcc -o pypr-client pypr-client.c && \
mkdir -p ~/.local/bin && \
mv pypr-client ~/.local/bin/ && \
chmod +x ~/.local/bin/pypr-client && \
pypr-client help
```

---

## Configuration

### Create Configuration File

Create `~/.config/hypr/pyprland.toml`:

```toml
[pyprland]
plugins = [
  "scratchpads",
  "expose",
  "magnify",
  "layout_center",
]

# Scratchpad configurations
[scratchpads.term]
animation = "fromTop"
command = "kitty --class kitty-dropterm"
class = "kitty-dropterm"
size = "75% 60%"
margin = 50
unfocus = "hide"

[scratchpads.files]
command = "kitty --class file-explorer -e yazi"
class = "file-explorer"
size = "90% 90%"
margin = 50
animation = "fromBottom"
unfocus = "hide"

[scratchpads.git]
command = "kitty --class git-terminal -e lazygit"
class = "git-terminal"  # MUST match the --class in command!
size = "80% 80%"
margin = 50
animation = "fromTop"
unfocus = "hide"

# Expose plugin
[expose]
include_special = false

# Layout center plugin
[layout_center]
margin = 60
offset = [0, 30]
```

**Critical:** The `class` field MUST match the `--class` argument in the `command`. Mismatches cause scratchpads to fail.

---

## Running Pyprland

### Start the Daemon

Add to your `~/.config/hypr/hyprland.conf`:

```conf
# Start pyprland daemon (use full path if installed via pip/pipx)
exec-once = pypr

# For debugging:
# exec-once = pypr --debug /tmp/pypr.log
```

**Important Notes:**

- `pypr` (without arguments) runs the daemon
- `pypr` (with arguments) sends commands to the running daemon
- Use `pypr-client` for all keybindings, NOT `pypr`

---

## Using with Hyprland

### Configure Keybindings

Add to your `~/.config/hypr/hyprland.conf` or keybindings file:

```conf
# Define the pypr client variable
# CRITICAL: Use pypr-client, NOT pypr
$pypr = pypr-client

# Scratchpad bindings
bind = Super+Shift, Return, exec, $pypr toggle term
bind = Super, E, exec, $pypr toggle files
bind = Super, G, exec, $pypr toggle git

# Other pyprland features
bind = Super+Ctrl, E, exec, $pypr expose
bind = Super, Z, exec, $pypr zoom ++0.5
bind = Super+Shift, Z, exec, $pypr zoom

# Layout center
bind = Super, M, exec, $pypr layout_center toggle
bind = Super+Alt, left, exec, $pypr layout_center prev
bind = Super+Alt, right, exec, $pypr layout_center next
```

### Reload Configuration

```bash
# Reload Hyprland
hyprctl reload

# Or use your keybinding (usually Super+Shift+R)
```

---

## Troubleshooting the Delay Issue

### Problem: Delay when toggling scratchpads

**Symptom:** 50-300ms delay when pressing keybindings

**Cause:** Using `pypr` (Python) instead of `pypr-client` (C binary)

**Solution:** Change your keybindings variable:

```conf
# WRONG (causes delay):
$pypr = pypr

# CORRECT (instant response):
$pypr = pypr-client
```

### Verify Your Setup

**1. Check daemon is running:**

```bash
ps aux | grep pypr
# Should show: pypr (no arguments)
```

**2. Check pypr-client is installed:**

```bash
which pypr-client
# Should return: /home/yourusername/.local/bin/pypr-client

pypr-client help
# Should show command list
```

**3. Test manually:**

```bash
# Should toggle terminal instantly
pypr-client toggle term
```

**4. Check your keybindings:**

```bash
grep pypr ~/.config/hypr/hyprland.conf
# Should show: $pypr = pypr-client
```

### Common Issues

**Issue 1: "pypr-client: command not found"**

- Solution: Compile and install pypr-client (see above)
- Check PATH includes `~/.local/bin`

**Issue 2: Scratchpad doesn't appear**

- Check class name matches: `class = "your-class-name"` must match `--class your-class-name`
- Check daemon is running: `ps aux | grep pypr`
- Check logs: `pypr --debug /tmp/pypr.log`

**Issue 3: Still experiencing delay**

- Verify you're using `pypr-client` not `pypr` in keybindings
- Run `hyprctl reload` after changing config

**Issue 4: Multiple windows appearing**

- Make sure scratchpad class is unique
- Check window rules in Hyprland aren't interfering

---

## Performance Comparison

| Method        | Response Time | Use Case                        |
| ------------- | ------------- | ------------------------------- |
| `pypr`        | ~50-300ms     | Running daemon only (exec-once) |
| `pypr-client` | ~1ms          | All keybindings                 |

**Always use:**

- `pypr` for `exec-once` in hyprland.conf (starts daemon)
- `pypr-client` for all keybinding commands

---

## Quick Reference

### Essential Files

```
~/.config/hypr/pyprland.toml    # Pyprland configuration
~/.config/hypr/hyprland.conf    # Hyprland config (add exec-once and bindings)
~/.local/bin/pypr-client        # Fast binary for keybindings
```

### Essential Commands

```bash
# Installation
pipx install pyprland
# Then compile pypr-client manually

# Check status
ps aux | grep pypr              # Check if daemon running
pypr help                       # Show available commands
pypr-client help                # Show client commands

# Debugging
pypr --debug /tmp/pypr.log      # Run with logging
tail -f /tmp/pypr.log           # Watch logs
```

### Minimal Working Example

**pyprland.toml:**

```toml
[pyprland]
plugins = ["scratchpads"]

[scratchpads.term]
command = "kitty --class scratchpad"
class = "scratchpad"
size = "75% 60%"
```

**hyprland.conf:**

```conf
exec-once = pypr
$pypr = pypr-client
bind = Super+Shift, Return, exec, $pypr toggle term
```

---

## Additional Resources

- **Official Documentation:** https://hyprland-community.github.io/pyprland/
- **GitHub Repository:** https://github.com/hyprland-community/pyprland
- **Available Plugins:** https://hyprland-community.github.io/pyprland/Plugins.html
- **Discord Community:** https://discord.com/channels/1055990214411169892/1230972154330218526

---

## Summary

1. **Install pyprland:** `pipx install pyprland`
2. **Compile pypr-client:** Download and compile the C source manually
3. **Create config:** `~/.config/hypr/pyprland.toml` with your plugins and scratchpads
4. **Start daemon:** Add `exec-once = pypr` to hyprland.conf
5. **Add keybindings:** Use `$pypr = pypr-client` and add your bindings
6. **Reload Hyprland:** The delay should be gone!

**The most critical point:** Always use `pypr-client` in keybindings, not `pypr`. This is what eliminates the delay.
