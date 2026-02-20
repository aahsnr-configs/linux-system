# ASUS G14 Performance Profile — Fedora / openSUSE Tumbleweed / Any systemd distro

Automatically applies CPU power and thermal limits every time your laptop powers on, restarts, wakes from suspend, resumes from hibernate, or comes back from hybrid sleep — with no manual steps required after the initial install.

**Distro compatibility:** The scripts, sysfs paths, kernel module, and systemd units in this project are entirely distro-agnostic. They talk directly to the Linux kernel's sysfs interface and the AMD SMU — both of which are hardware-level and kernel-level, not distro-level. This project works on any `systemd`-based distribution running kernel ≥ 6.5 with `asusd` and `power-profiles-daemon` installed. The only distro-specific content in this project is the package manager install commands in the Requirements section. Fedora and openSUSE Tumbleweed commands are both provided there.

---

## The Problem This Solves

The ASUS G14 firmware resets CPU power limits on every power-state transition: cold boot, restart, suspend resume, and hibernate resume. This project re-applies your preferred limits immediately after each transition via a combination of systemd units and a periodic refresh timer.

There are two failure modes on Fedora 43 with `asusd` and `power-profiles-daemon` that this project addresses:

**Failure mode 1 — Limits reset at every boot:**
`asusd` is launched by a udev rule (not a normal boot dependency), so it starts unpredictably after early targets. When it starts, it calls `power-profiles-daemon` over D-Bus to restore the saved power profile. The `asus-wmi` kernel driver reacts to the resulting `platform_profile` write by resetting `ppt_pl1_spl`, `ppt_pl2_sppt`, `ppt_fppt`, and `throttle_thermal_policy` back to the profile defaults. If your custom service runs before `asusd`, its writes are overwritten. The boot unit in this project is explicitly ordered `After=asusd.service power-profiles-daemon.service` to ensure it always runs last.

**Failure mode 2 — CPU locked at ~82°C regardless of ryzenadj settings:**
`throttle_thermal_policy` is a sysfs node that controls the ASUS embedded controller's thermal operating mode. When `asusd` or `power-profiles-daemon` restores the "balanced" profile at boot, the `asus-wmi` driver sets `throttle_thermal_policy=0`. This puts the EC in "balanced" thermal mode, which imposes an EC-level ceiling of approximately 82°C. This ceiling is enforced by the embedded controller and is independent of and in addition to whatever you write via ryzenadj (`--tctl-temp`) or the PPT sysfs nodes. The CPU will clock-throttle when it approaches 82°C regardless of your ryzenadj settings because the EC is issuing the throttle, not the AMD SMU. Setting `throttle_thermal_policy=1` (overboost) tells the EC to remove this ceiling.

---

## What This Applies

| Limit | Value | Controls |
|---|---|---|
| PL1 / SPL (sustained) | 30 W | Long-run CPU package power ceiling |
| PL2 / SPPT (boost) | 50 W | Short-burst CPU power ceiling |
| FPPT (fast package power tracking) | 50 W | Very first milliseconds of a burst |
| Slow limit | 40 W | Intermediate ramp-down (ryzenadj only) |
| Thermal limit (`tctl-temp`) | 83 °C | AMD SMU thermal ceiling |
| `throttle_thermal_policy` | 1 (overboost) | **EC-level thermal ceiling — this is the 82°C fix** |

All values are defined as `readonly` constants at the top of `asus-performance-setup.sh` and are straightforward to change.

---

## Important: The asusd ↔ power-profiles-daemon Conflict

Running `asusd` alongside `power-profiles-daemon` creates a known profile-inversion conflict: setting Performance via `powerprofilesctl` causes `asusd` to switch to Quiet mode, and setting Performance via `asusctl` causes `power-profiles-daemon` to switch to power-saver. This is a longstanding issue in how `asusd` maps its profiles to `platform_profile` values.

This conflict means that even after this project's boot unit correctly applies limits, any subsequent profile-change event (GNOME power slider, Fn+F5 hotkey, AC plug/unplug, another daemon interaction) can trigger a `platform_profile` write, which the `asus-wmi` driver reacts to by resetting PPT values and `throttle_thermal_policy`.

**The periodic refresh timer (`asus-performance-refresh.timer`) is the primary defence against this.** It silently re-applies all limits every 60 seconds, ensuring that any firmware or daemon reset has at most a 60-second window of effect.

**Additionally, you should set both daemons to their least-restrictive profile persistently** so that their boot-time restore writes the most permissive platform_profile value before the boot unit overrides `throttle_thermal_policy`:

```bash
asusctl profile -P Performance
powerprofilesctl set performance
```

---

## Critical Context: Kernel 6.18 vs 6.19+ (PPT sysfs interface)

**On kernel 6.5–6.18** (Fedora 43 ships 6.18; check your version with `uname -r`), the ASUS power limit sysfs interface for PPT values lives at the legacy platform path:

```
/sys/devices/platform/asus-nb-wmi/ppt_pl1_spl
/sys/devices/platform/asus-nb-wmi/ppt_pl2_sppt
/sys/devices/platform/asus-nb-wmi/ppt_fppt
```

This interface has been available since kernel 6.5 and works correctly on 6.18, but is marked upstream as deprecated. When first accessed, the kernel logs a one-time notice in `dmesg`. This notice is expected and harmless.

**`throttle_thermal_policy` is NOT part of this deprecated interface.** It lives at the same platform path but is a separate, stable sysfs node that is not being moved or deprecated. It exists on all supported kernel versions.

**On kernel 6.19+**, the PPT interface moves to:

```
/sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl1_spl/current_value
```

**The script handles both automatically.** It probes for the `asus-armoury` path first. If not found, it falls back to the legacy path. When you upgrade to kernel 6.19+, the script switches PPT interfaces silently — no changes needed.

---

## Files in This Project

```
asus-performance-setup.sh        ← Main script that applies all limits
asus-performance.service         ← Boot unit: runs on every cold boot & restart
asus-performance-resume.service  ← Resume unit: runs after every sleep/wake
asus-performance-refresh.service ← Refresh service: called by the timer
asus-performance-refresh.timer   ← Timer: fires every 60 seconds
install.sh                       ← Automated installer and uninstaller
README.md                        ← This file
```

### `asus-performance-setup.sh`

The core script. Applied in three sequential phases:

**Phase 1: sysfs PPT limits** — Writes `ppt_pl1_spl`, `ppt_pl2_sppt`, and `ppt_fppt` via the auto-detected interface. Waits 1 second after writing to let the firmware register both limits before the ryzenadj call.

**Phase 2: `throttle_thermal_policy`** — Always written to `1` (overboost) after the PPT limits. This is the fix for the ~82°C EC-level clock throttle. The node is always at the legacy platform path regardless of kernel version.

**Phase 3: ryzenadj** — Applies limits directly to the AMD SMU as a complementary layer. Uses `--tctl-temp`, `--stapm-limit`, `--fast-limit`, and `--slow-limit`.

Key design decisions:

- **`_sudo()` wrapper.** When already root (systemd service context), re-invoking `sudo` is unnecessary and may fail. The wrapper calls commands directly when `EUID==0`.
- **`sudo tee` for sysfs writes.** `sudo echo X > file` does not work — the shell opens the redirect before sudo elevates, so the write runs as the unprivileged user. All writes pipe through `_sudo tee`.
- **`(( ++n ))` pre-increment everywhere.** `set -euo pipefail` is active. `(( n++ ))` (post-increment) exits with code 1 when `n` is 0. Pre-increment `(( ++n ))` always returns the new value (≥1 = true), so it is safe under `set -e`.
- **Graceful degradation.** Each phase (sysfs detection, PPT writes, throttle write, ryzenadj) skips cleanly with a `[WARN]` message if the required module, sysfs node, or binary is absent.
- **Optional 4th argument to `sysfs_write`.** The unit suffix ("W", "°C", or "" for dimensionless) is now a separate parameter so the log line is always correct regardless of what is being written.

### `asus-performance.service`

A `Type=oneshot` unit that runs the script on every cold boot and restart.

`After=asusd.service power-profiles-daemon.service` is the critical ordering fix. This ensures the script runs after both daemons have finished their boot-time profile restore, so daemon writes cannot overwrite the custom limits. `Wants=` (not `Requires=`) keeps the dependency soft — the service runs even if neither daemon is installed.

`RemainAfterExit=yes` keeps the unit "active" after the script finishes so `Conflicts=sleep.target` can work correctly.

### `asus-performance-resume.service`

Hooks into `sleep.target` to re-apply the profile after every wake event.

Uses the `ExecStop=` pattern (not `ExecStart=`) as the payload. `ExecStop=` fires when `sleep.target` deactivates on wake, not when sleep begins.

`ExecStop=` now runs `/bin/bash -c 'sleep 3 && /usr/local/bin/asus-performance-setup.sh'`. The 3-second delay addresses a race condition: with `DefaultDependencies=no`, there is no implicit ordering relative to driver re-initialisation. After a hibernate resume, `asus-nb-wmi` needs time to re-register its sysfs nodes with the EC. Without the delay, writes return exit code 0 (the node exists) but the EC does not receive the values because the WMI transport is still initialising.

### `asus-performance-refresh.service` and `asus-performance-refresh.timer`

The timer fires 90 seconds after activation (to let `asusd` and PPD settle at boot) and then every 60 seconds thereafter. On each fire it starts the refresh service, which simply runs the setup script.

This is the primary defence against mid-session firmware resets caused by AC plug/unplug events, platform_profile writes from other daemons, or EC background timers. With this timer, any reset has a maximum 60-second window before limits are silently re-applied.

### `install.sh`

Runs as root. Installs all five files to their system locations, enables all persistent units, starts the boot unit and the refresh timer immediately, and handles clean uninstall.

---

## Requirements

| Requirement | Notes |
|---|---|
| Any systemd distro | Tested on Fedora 43 and openSUSE Tumbleweed. Any distro with systemd ≥ 245 works. |
| Kernel ≥ 6.5 | The legacy sysfs PPT interface (`asus-nb-wmi`) requires 6.5+. Fedora 43 ships 6.18; Tumbleweed is a rolling release and stays current. |
| `asus-nb-wmi` module | Loaded automatically on ASUS hardware by udev. Verify with `lsmod \| grep asus` |
| `asusd` | The ASUS Linux daemon. The boot unit is ordered to run after it. |
| `power-profiles-daemon` | In official repos on both Fedora and Tumbleweed. The boot unit is ordered to run after it. |
| `sudo` access | Installer runs as root; the setup script uses an internal sudo wrapper. |
| `ryzenadj` | Optional but recommended. Applies limits directly via AMD SMU. |

### Installing packages — Fedora

```bash
# asusd and asusctl
sudo dnf copr enable lukenukem/asus-linux
sudo dnf install asusctl asusd

# power-profiles-daemon (usually pre-installed on Fedora)
sudo dnf install power-profiles-daemon

# ryzenadj
sudo dnf install ryzenadj
# If not in repos, build from source:
sudo dnf install cmake gcc gcc-c++ pciutils-devel
git clone https://github.com/FlyGoat/RyzenAdj.git
cd RyzenAdj && mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release .. && make -j$(nproc)
sudo make install
```

### Installing packages — openSUSE Tumbleweed

```bash
# asusd and asusctl — via the community OBS repo (home:RN:asusctl)
# NOTE: the older luke_nukem OBS repo is defunct as of 2024. Use this one instead.
sudo zypper addrepo https://download.opensuse.org/repositories/home:RN:asusctl/openSUSE_Tumbleweed/home:RN:asusctl.repo
sudo zypper refresh
sudo zypper install asusctl

# power-profiles-daemon — in the official Tumbleweed repo
sudo zypper install power-profiles-daemon

# ryzenadj — build from source (no official Tumbleweed package)
sudo zypper install cmake gcc gcc-c++ pciutils-devel
git clone https://github.com/FlyGoat/RyzenAdj.git
cd RyzenAdj && mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release .. && make -j$(nproc)
sudo make install
```

> **openSUSE note:** The official ASUS Linux Tumbleweed guide notes that the `home:luke_nukem` OBS repo is no longer recommended and may be broken. Use `home:RN:asusctl` as shown above, which currently packages asusctl 6.3.2 for Tumbleweed.

### Verifying the `asus-nb-wmi` module

```bash
lsmod | grep asus
```

You should see `asus_nb_wmi` and `asus_wmi`. If absent:

```bash
sudo modprobe asus-nb-wmi

# Confirm the sysfs nodes appeared:
ls /sys/devices/platform/asus-nb-wmi/ppt_* /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy
```

This works identically on Fedora, Tumbleweed, and any other distro — the module is part of the mainline Linux kernel and is not distro-specific.

---

## Installation

### Step 1 — Place all project files in the same directory

```
~/asus-g14-perf/
├── asus-performance-setup.sh
├── asus-performance.service
├── asus-performance-resume.service
├── asus-performance-refresh.service
├── asus-performance-refresh.timer
├── install.sh
└── README.md
```

### Step 2 — Make the scripts executable

```bash
chmod +x asus-performance-setup.sh install.sh
```

### Step 3 — Run the installer

```bash
cd ~/asus-g14-perf
sudo ./install.sh
```

The installer will:

1. Verify all source files are present
2. Warn if `ryzenadj` or the `asus` kernel module is missing (install continues either way)
3. Check whether `asusd` and `power-profiles-daemon` are running and print guidance
4. Install `asus-performance-setup.sh` → `/usr/local/bin/` with executable permissions
5. Install all four `.service` / `.timer` files → `/etc/systemd/system/` with 644 permissions
6. Run `systemctl daemon-reload`
7. Enable the boot unit, resume unit, and refresh timer
8. Start the boot unit immediately (limits applied without rebooting)
9. Start the refresh timer (first refresh in 90 seconds)

### Step 4 — Set both daemons to Performance mode (recommended)

```bash
asusctl profile -P Performance
powerprofilesctl set performance
```

This makes the boot-time profile restore by `asusd` and PPD write the "performance" value to `platform_profile`, which sets the least-restrictive EC defaults before the boot unit overrides `throttle_thermal_policy`. It does not prevent the project from working if you skip this step — the boot unit and refresh timer will correct any reset — but it reduces the window between the daemon restore and the first timer correction at boot.

### Step 5 — Verify

```bash
# Boot unit: should show "active (exited)" and [ OK ] lines in the logs
systemctl status asus-performance.service

# Resume unit: should show "active (exited)" — armed and waiting for sleep
systemctl status asus-performance-resume.service

# Refresh timer: should show "active (waiting)" with a "Next elapse" time
systemctl status asus-performance-refresh.timer

# Full output from the most recent run
journalctl -u asus-performance.service --no-pager -n 60

# Confirm throttle_thermal_policy is now 1 (overboost)
cat /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy

# Confirm PPT values match your configured watts
cat /sys/devices/platform/asus-nb-wmi/ppt_pl1_spl
cat /sys/devices/platform/asus-nb-wmi/ppt_pl2_sppt
```

---

## Customising the Power Limits

Open the script in an editor:

```bash
sudo nano /usr/local/bin/asus-performance-setup.sh
```

Find the `readonly` block near the top:

```bash
readonly PL1_WATTS=30      # Sustained limit — change this
readonly PL2_WATTS=50      # Boost limit — change this
readonly FPPT_WATTS=50     # Fast package power tracking (usually = PL2)
readonly SLOW_MW=40000     # Slow limit in milliwatts (ryzenadj only)
readonly TCTL_TEMP=83      # AMD SMU thermal ceiling in °C
```

Save, then apply the new values immediately without rebooting:

```bash
sudo systemctl restart asus-performance.service
journalctl -u asus-performance.service --no-pager -n 30
```

Keep `SLOW_MW` roughly between `PL1_WATTS × 1000` and `PL2_WATTS × 1000`. The ryzenadj slow limit and sysfs PL1 both govern the sustained budget via different paths — wildly mismatched values can cause the CPU to oscillate between limit tiers.

The `throttle_thermal_policy` value (`1` = overboost) is intentionally not a user-tuneable constant because its only sensible value for a performance profile is `1`. If you want silent/balanced mode, you should switch to Quiet or Balanced via `asusctl profile -P Quiet` instead of modifying this value directly.

---

## Monitoring & Troubleshooting

### Watch all events live

```bash
journalctl -f -u asus-performance.service \
              -u asus-performance-resume.service \
              -u asus-performance-refresh.service
```

### Read current values from sysfs

```bash
# Kernel 6.5–6.18 (legacy path — active on Fedora 43; check uname -r)
cat /sys/devices/platform/asus-nb-wmi/ppt_pl1_spl
cat /sys/devices/platform/asus-nb-wmi/ppt_pl2_sppt
cat /sys/devices/platform/asus-nb-wmi/ppt_fppt
cat /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy  # must be 1

# Kernel 6.19+ (PPT only; throttle_thermal_policy stays at legacy path on all kernels)
cat /sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl1_spl/current_value
```

### Check all AMD SMU power management values

```bash
sudo ryzenadj --info
```

Look for `STAPM LIMIT`, `PPT LIMIT FAST`, and `THM LIMIT CORE`. They should match your configured watt values (converted to milliwatts). If they show BIOS defaults instead, a firmware reset has occurred — the refresh timer will correct it within 60 seconds.

### See the boot-time ordering

```bash
# Shows the dependency chain and confirms ordering relative to asusd and PPD
systemd-analyze critical-chain asus-performance.service

# Shows a full timeline of everything that started at boot
systemd-analyze plot > /tmp/boot.svg && xdg-open /tmp/boot.svg
```

Look for `asusd.service` and `power-profiles-daemon.service` appearing before `asus-performance.service` in the timeline. If `asus-performance.service` appears first, the ordering is not working — verify that asusd is recognised as a proper systemd unit (check `systemctl status asusd.service`).

### Diagnose whether the limits are being reset mid-session

```bash
# Watch ppt_pl1_spl in real time
watch -n 5 cat /sys/devices/platform/asus-nb-wmi/ppt_pl1_spl

# Watch throttle_thermal_policy in real time  
watch -n 5 cat /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy
```

If you see the value flipping back to the BIOS default every few seconds, the refresh timer is fighting a daemon that is resetting it very aggressively. In that case, also run:

```bash
# Check what daemon last wrote to platform_profile
journalctl -b | grep -i 'platform_profile\|asusd\|power-profiles' | tail -40
```

### Manually simulate a wake event

The `ExecStop=` pattern means the script runs when the resume unit stops, triggered by `sleep.target` deactivating. To replicate this manually without sleeping:

```bash
sudo systemctl start asus-performance-resume.service
sudo systemctl stop  asus-performance-resume.service
journalctl -u asus-performance-resume.service --no-pager -n 40
```

Starting and immediately stopping the unit fires `ExecStop=` exactly as a real wake event would.

### The dmesg deprecation notice

On kernels 6.5–6.18, accessing the legacy PPT sysfs path causes a one-time kernel log message:

```
asus_wmi: Accessing attributes through /sys/bus/platform/asus_wmi is deprecated
          and will be removed in a future release.
```

This appears in `dmesg` and `journalctl -k`. It is not an error. The script prints a matching `[WARN]` line to explain why it appears. It will stop appearing once you upgrade to kernel 6.19+ and the script switches to the `asus-armoury` interface.

---

## Uninstallation

```bash
sudo ./install.sh uninstall
```

This stops and disables all units and the timer, removes all five installed files from `/etc/systemd/system/`, removes the script from `/usr/local/bin/`, and reloads the daemon. Power limits will revert to BIOS defaults on the next boot.

---

## How the Multi-Unit Design Works

```
Cold boot or Restart
  └─► multi-user.target activates (after asusd and ppd have settled)
        └─► asus-performance.service
              ExecStart= runs the script  ✓  (ordered After= both daemons)

Any sleep state (suspend / hibernate / hybrid-sleep / suspend-then-hibernate)
  └─► sleep.target activates  ←— single parent of ALL sleep targets
        └─► asus-performance-resume.service starts
              ExecStart=/bin/true  (no-op)
              RemainAfterExit=yes  (stays "active" during sleep)
        └─► [ SYSTEM SLEEPS ]
        └─► sleep.target deactivates on wake
              └─► StopWhenUnneeded=yes: unit is no longer needed
                    └─► Unit stop fires ExecStop=  ✓
                          └─► sleep 3 (WMI re-init settle)
                                └─► Script re-applies all limits

Every 60 seconds (after initial 90-second delay at boot)
  └─► asus-performance-refresh.timer fires
        └─► asus-performance-refresh.service runs the script  ✓
              (silently corrects any firmware/daemon reset)
```

---

## After a Kernel Upgrade to 6.19+

No action is required for the PPT limits. On the next boot after upgrading, `detect_sysfs_interface()` will find the `asus-armoury` firmware-attributes path first and use it. You will see `[INFO] PPT interface: asus-armoury firmware-attributes (kernel ≥ 6.19)` in the log and the `dmesg` deprecation notice will stop appearing.

`throttle_thermal_policy` is written separately from the PPT interface detection and continues to work from the same legacy platform path on all kernel versions.

---

## File Locations After Install

| File | Installed location |
|---|---|
| Setup script | `/usr/local/bin/asus-performance-setup.sh` |
| Boot unit | `/etc/systemd/system/asus-performance.service` |
| Wake/resume unit | `/etc/systemd/system/asus-performance-resume.service` |
| Refresh service | `/etc/systemd/system/asus-performance-refresh.service` |
| Refresh timer | `/etc/systemd/system/asus-performance-refresh.timer` |
