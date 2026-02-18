Let me search for how hyprpm detects Hyprland versions and how to properly integrate it with distrobox.Based on my extensive research, here's a comprehensive guide for using distrobox to build Hyprland plugins with hyprpm while detecting your host Ubuntu 24.04 Hyprland version:

---

# Complete Guide: Building Hyprland Plugins with hyprpm in Distrobox

## Understanding the Architecture

**How hyprpm Detects Hyprland Version:**

- hyprpm automatically detects your Hyprland version and installs only the corresponding pinned release of hyprland-plugins
- hyprctl creates a Unix domain socket at `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock`
- hyprpm connects to this socket to query the running Hyprland instance

**How Distrobox Provides Access:**

- Distrobox provides access to Wayland and X11 sockets, the user's home directory, systemd journal, D-Bus, and the udev database
- The host's runtime directory is accessible at `/run/host/$XDG_RUNTIME_DIR` inside the container
- Environment variables are automatically adjusted: `XDG_RUNTIME_DIR=/run/host//run/user/1000`

---

## Prerequisites

Ensure these packages are installed on your Ubuntu 24.04 host:

- `distrobox` (in your resolute-pkgs.sh)
- `podman` (in your resolute-pkgs.sh)
- Hyprland from cppiber PPA (in your 10hyprland script)

Verify Hyprland is running:

```bash
hyprctl version
```

Note your Hyprland version - you'll need it later.

---

## Step 1: Create Arch Linux Build Container

Create a container with Arch Linux (has gcc-15+ and latest build tools):

```bash
distrobox create --name hypr-build --image docker.io/archlinux:latest
```

**What this does:**

- Creates container named `hypr-build`
- Uses official Arch Linux image
- Automatically shares your HOME directory
- Automatically shares runtime directories including Hyprland sockets

---

## Step 2: Enter the Container

```bash
distrobox enter hypr-build
```

You're now inside the Arch container. All subsequent commands run inside the container unless specified otherwise.

---

## Step 3: Install Build Tools

Update system and install required packages:

```bash
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm gcc git cmake meson ninja cpio base-devel
```

**What each package does:**

- `gcc` - C++ compiler (version 15+ in Arch)
- `git` - Clone repositories
- `cmake` - Build system
- `meson` - Build system (some plugins use it)
- `ninja` - Build backend
- `cpio` - Archive tool (required by hyprpm)
- `base-devel` - Development tools meta-package

---

## Step 4: Verify Hyprland Detection from Container

Test if hyprctl can detect the host's Hyprland:

```bash
# Check if hyprctl is available from host
which hyprctl
```

If hyprctl is not found in the container, you need to access it from the host. There are two methods:

### Method A: Use distrobox-host-exec (Recommended)

```bash
distrobox-host-exec hyprctl version
```

This runs hyprctl on the host from inside the container.

### Method B: Install hyprctl in Container

If you want hyprctl available directly in the container:

```bash
# Install Hyprland package (just for hyprctl tool)
sudo pacman -S --noconfirm hyprland
```

Now test socket connectivity:

```bash
hyprctl version
```

**Expected output:** Should show your host's Hyprland version (e.g., v0.52.1).

**If you get "Couldn't connect to socket" error:**
The socket path needs adjustment. Check the socket location on host:

```bash
# On host (open new terminal)
echo $XDG_RUNTIME_DIR
ls -la $XDG_RUNTIME_DIR/hypr/
```

Inside container, verify socket accessibility:

```bash
ls -la /run/host/run/user/$(id -u)/hypr/
```

---

## Step 5: Clone and Build Hyprland Headers

hyprpm needs Hyprland headers to build plugins. Clone Hyprland matching your host version:

```bash
cd ~/
git clone --recursive https://github.com/hyprwm/Hyprland
cd Hyprland
```

**Critical:** Checkout the EXACT version running on your host:

```bash
# Get your host version (from earlier)
# Example: if host version is v0.52.1
git checkout v0.52.1
```

**To find available versions:**

```bash
git tag | grep "^v0\." | tail -20
```

Build and install headers:

```bash
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build -G Ninja
sudo cmake --build ./build --target installheaders
```

**What this does:**

- Configures build with CMake
- Builds only the headers target
- Installs headers to system directories
- Headers are required for plugin compilation

**Verify installation:**

```bash
ls -la /usr/local/include/hyprland/
```

You should see header files.

---

## Step 6: Configure Environment for hyprpm

hyprpm needs to access the host's Hyprland socket. Set up environment:

```bash
# Check current runtime dir
echo $XDG_RUNTIME_DIR
```

If it shows `/run/user/1000`, the socket should be accessible automatically.

**If hyprpm can't detect Hyprland, manually set the socket path:**

Create a wrapper script `~/hyprpm-wrapper`:

```bash
cat > ~/hyprpm-wrapper << 'EOF'
#!/bin/bash
# Wrapper to ensure hyprpm can access host Hyprland socket

# Use host's runtime directory
export XDG_RUNTIME_DIR="/run/host/run/user/$(id -u)"

# Verify socket exists
if [ ! -S "$XDG_RUNTIME_DIR/hypr/"*"/.socket.sock" ]; then
    echo "Error: Cannot find Hyprland socket"
    echo "Socket should be at: $XDG_RUNTIME_DIR/hypr/"
    ls -la "$XDG_RUNTIME_DIR/hypr/" 2>/dev/null || echo "Directory doesn't exist"
    exit 1
fi

# Run hyprpm with proper environment
exec hyprpm "$@"
EOF

chmod +x ~/hyprpm-wrapper
```

---

## Step 7: Install Hyprland Plugins with hyprpm

Now use hyprpm to install plugins:

```bash
# Add the official Hyprland plugins repository
hyprpm add https://github.com/hyprwm/hyprland-plugins
```

**What happens:**

1. hyprpm detects your Hyprland version automatically
2. Clones the repository
3. Checks out the correct tag matching your version
4. Builds plugins with the installed headers

**List available plugins:**

```bash
hyprpm list
```

**Enable specific plugins:**

```bash
hyprpm enable borders-plus-plus
hyprpm enable hyprbars
hyprpm enable hyprexpo
```

**Check plugin status:**

```bash
hyprpm list
```

---

## Step 8: Verify Plugin Installation

Plugins are installed to your HOME directory (shared between host and container):

```bash
# View installed plugins
ls -la ~/.local/share/hyprpm/

# Check specific plugin
ls -la ~/.local/share/hyprpm/hyprland-plugins/
```

You should see `.so` files (compiled plugin libraries).

---

## Step 9: Load Plugins on Host Hyprland

Exit the container:

```bash
exit
```

You're now back on your Ubuntu 24.04 host.

Add to your `~/.config/hypr/hyprland.conf`:

```
# Load plugins built by hyprpm
exec-once = hyprpm reload -n
```

The `-n` flag tells hyprpm to not notify (runs silently).

**Alternative: Manual plugin loading:**

```
plugin = ~/.local/share/hyprpm/hyprland-plugins/borders-plus-plus.so
plugin = ~/.local/share/hyprpm/hyprland-plugins/hyprbars.so
```

Reload Hyprland configuration:

```bash
hyprctl reload
```

**Verify plugins are loaded:**

```bash
hyprctl plugin list
```

---

## Step 10: Update Plugins

When you update Hyprland on the host, update plugins in the container:

```bash
# Enter container
distrobox enter hypr-build

# Update Hyprland headers to match new version
cd ~/Hyprland
git fetch --all
git checkout v0.XX.X  # Replace with new version

# Rebuild headers
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build -G Ninja
sudo cmake --build ./build --target installheaders

# Update plugins
hyprpm update

exit
```

---

## Troubleshooting

### Problem: "Couldn't connect to socket"

**Solution:** Verify socket path:

```bash
# On host
ls -la $XDG_RUNTIME_DIR/hypr/

# In container
ls -la /run/host/run/user/$(id -u)/hypr/
```

If socket exists but hyprpm can't connect, use the wrapper script from Step 6.

### Problem: "You don't seem to be running Hyprland"

**Causes:**

- hyprctl is looking in the wrong place
- Socket path mismatch

**Solution:**

```bash
# Check HYPRLAND_INSTANCE_SIGNATURE environment variable
echo $HYPRLAND_INSTANCE_SIGNATURE

# If empty, socket detection will fail
# Manually locate socket:
find /run/host/run/user/$(id -u)/hypr/ -name ".socket.sock"
```

### Problem: "Build failed - compiler version too old"

**Verification:**

```bash
gcc --version  # Should show gcc 15+
```

If showing older version, ensure you're in the Arch container, not on the host.

### Problem: Version mismatch between headers and host Hyprland

**Solution:**
Always checkout the EXACT version:

```bash
# On host - check version
hyprctl version

# In container - checkout that version
cd ~/Hyprland
git checkout vX.X.X
```

---

## Daily Workflow

**Add new plugin:**

```bash
distrobox enter hypr-build
hyprpm add <github-url>
exit
```

**Update plugins:**

```bash
distrobox enter hypr-build
hyprpm update
exit
```

**Remove plugin:**

```bash
distrobox enter hypr-build
hyprpm remove <github-url>
exit
```

**List plugins:**

```bash
distrobox enter hypr-build
hyprpm list
exit
```

---

## Important Notes

1. **HOME directory is shared:** Plugins built in the container are immediately available on the host

2. **Version matching is critical:** hyprpm automatically detects your Hyprland version and installs only the corresponding pinned release

3. **No system pollution:** Build tools (gcc-15, cmake, etc.) stay in the container and don't affect your Ubuntu 24.04 base

4. **Container persistence:** The `hypr-build` container persists across reboots

5. **Socket access:** Distrobox automatically provides access to Wayland sockets and runtime directories

This setup gives you bleeding-edge build tools for Hyprland plugins while keeping your Ubuntu 24.04 system stable and clean.
