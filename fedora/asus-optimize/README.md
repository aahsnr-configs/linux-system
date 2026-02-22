# ASUS G14 Performance Profile — Fedora / CachyOS / Any systemd distro

Automatically applies CPU power and thermal limits every time your laptop powers on, restarts, wakes from suspend, resumes from hibernate, or comes back from hybrid sleep — with no manual steps required after the initial install.

**Kernel compatibility:** Works on kernel 6.5 through 6.19+ with full automatic detection of which sysfs interface is available. **CachyOS 6.18.xx kernels may already have the `asus-armoury` driver backported** — the script handles this transparently.

**Distro compatibility:** The scripts, sysfs paths, kernel module, and systemd units in this project are entirely distro-agnostic. They talk directly to the Linux kernel's sysfs interface and the AMD SMU. This project works on any `systemd`-based distribution running kernel ≥ 6.5 with the ASUS WMI driver loaded.

---

## The Problem This Solves

The ASUS G14 firmware resets CPU power limits on every power-state transition: cold boot, restart, suspend resume, and hibernate resume. This project re-applies your preferred limits immediately after each transition via a combination of systemd units and a periodic refresh timer.

There are two failure modes that this project addresses:

**Failure mode 1 — Limits reset at every boot:**
`asusd` and `power-profiles-daemon` start at boot and restore the saved platform power profile. When the `asus-wmi` kernel driver receives the resulting `platform_profile` write, it resets `ppt_pl1_spl`, `ppt_pl2_sppt`, `ppt_fppt`, and `throttle_thermal_policy` back to the profile defaults. The periodic refresh timer (90 second initial delay, then every 60 seconds) is the primary defence: it silently re-applies limits after any daemon reset.

**Failure mode 2 — CPU locked at ~82°C regardless of ryzenadj settings:**
`throttle_thermal_policy` controls the ASUS embedded controller's thermal operating mode. When `asusd` or `power-profiles-daemon` restores the "balanced" profile at boot, the `asus-wmi` driver sets `throttle_thermal_policy=0`. This puts the EC in "balanced" mode, which imposes an EC-level ceiling of approximately 82°C. This ceiling is enforced by the embedded controller and is independent of whatever you write via ryzenadj (`--tctl-temp`) or the PPT sysfs nodes. Setting `throttle_thermal_policy=1` (overboost) tells the EC to remove this ceiling.

---

## What This Applies

| Limit | Value | Controls |
|---|---|---|
| PL1 / SPL (sustained) | 33 W | Long-run CPU package power ceiling |
| PL2 / SPPT (boost) | 54 W | Short-burst CPU power ceiling |
| FPPT (fast package power tracking) | 54 W | Very first milliseconds of a burst |
| Slow limit | 44 W | Intermediate ramp-down (ryzenadj only) |
| Thermal limit (`tctl-temp`) | 84 °C | AMD SMU thermal ceiling |
| `throttle_thermal_policy` | 1 (overboost) | **EC-level thermal ceiling — this is the 82°C fix** |

All values are defined as `readonly` constants at the top of `asus-performance-setup.sh` and are straightforward to change.

---

## Critical Context: Kernel 6.18 vs 6.19+ (PPT sysfs interface)

### The two kernel interfaces

**On kernel 6.5–6.18** (vanilla Fedora 43 ships 6.18), the ASUS power limit sysfs interface lives at the legacy platform path:

```
/sys/devices/platform/asus-nb-wmi/ppt_pl1_spl
/sys/devices/platform/asus-nb-wmi/ppt_pl2_sppt
/sys/devices/platform/asus-nb-wmi/ppt_fppt
```

This interface is **marked deprecated upstream** and will be removed in the LTS kernel after 6.19. When first accessed, the kernel logs a one-time notice in `dmesg`. This notice is harmless and expected.

**On kernel 6.19+**, the PPT interface moves to the new `asus-armoury` firmware-attributes path:

```
/sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl1_spl/current_value
/sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl2_sppt/current_value
/sys/class/firmware-attributes/asus-armoury/attributes/ppt_fppt/current_value
```

Kernel 6.19 was released in February 2026 with `asus-armoury` built in. The CachyOS COPR kernel may already include this driver even on 6.18.xx releases.

### What about `throttle_thermal_policy`?

**`throttle_thermal_policy` is NOT deprecated and does NOT move.** It lives at:

```
/sys/devices/platform/asus-nb-wmi/throttle_thermal_policy
```

on ALL kernel versions from 5.6 through 6.19 and beyond. This is confirmed by the kernel ABI documentation at `kernel.org/doc/Documentation/ABI/testing/sysfs-platform-asus-wmi`, where the PPT nodes are all marked `DEPRECATED, WILL BE REMOVED SOON` but `throttle_thermal_policy` is not.

### How the script handles both interfaces

**The script handles everything automatically.** It probes for the `asus-armoury` path first. If found, it uses it. If not found, it falls back to the legacy path. When you upgrade to kernel 6.19+ (or switch to a CachyOS kernel with the backport), the script switches PPT interfaces silently — no changes needed. `throttle_thermal_policy` is always written using `find /sys/devices/platform`, so it also adapts to any device-name variation.

---

## CachyOS COPR Kernel Notes

The CachyOS COPR kernel (`bieszczaders/kernel-cachyos`) is based on the latest stable kernel with CachyOS-specific patches (BORE scheduler, ZSTD compression, etc.). On 6.18.xx, it may include the `asus-armoury` driver as a backport. On 6.19.xx, `asus-armoury` is mainline and will always be present.

**How to check which interface your CachyOS kernel is using:**

```bash
sudo /usr/local/bin/asus-kernel-check.sh
```

Or check directly:

```bash
# If this directory exists, you have asus-armoury (6.19 or backport)
ls /sys/class/firmware-attributes/asus-armoury/attributes/ 2>/dev/null

# Legacy path — if present, asus-nb-wmi is the active PPT interface
ls /sys/devices/platform/asus-nb-wmi/ppt_pl1_spl 2>/dev/null
```

**What to do when upgrading from CachyOS 6.18.xx → 6.19.xx:**

Nothing. The transition is fully automatic. On the first boot of the new kernel, `detect_sysfs_interface()` will find `asus-armoury` and use it. You will see `[OK] PPT interface: asus-armoury firmware-attributes` in the journal. The `dmesg` deprecation notice will stop appearing. Run `sudo /usr/local/bin/asus-kernel-check.sh` after the first boot on the new kernel to confirm.

---

## Important: The asusd ↔ power-profiles-daemon Conflict

Running `asusd` alongside `power-profiles-daemon` creates a known profile-inversion conflict: setting Performance via `powerprofilesctl` causes `asusd` to switch to Quiet mode, and vice versa. This is a longstanding issue in how `asusd` maps its profiles to `platform_profile` values.

This conflict means that even after the boot unit applies limits, any subsequent profile-change event (GNOME power slider, Fn+F5 hotkey, AC plug/unplug) can trigger a `platform_profile` write, which the `asus-wmi` driver reacts to by resetting PPT values and `throttle_thermal_policy`.

**The periodic refresh timer (`asus-performance-refresh.timer`) is the primary defence.** It fires 90 seconds after boot (after all daemons have settled) and then every 60 seconds, silently re-applying all limits.

**Additionally, set both daemons to their least-restrictive profile persistently:**

```bash
asusctl profile -P Performance
powerprofilesctl set performance
```

---

## Files in This Project

```
asus-performance-setup.sh        ← Main script that applies all limits
asus-performance.service         ← Boot unit: runs on every cold boot & restart
asus-performance-resume.service  ← Resume unit: runs after every sleep/wake
asus-performance-refresh.service ← Refresh service: called by the timer
asus-performance-refresh.timer   ← Timer: fires every 60 seconds
asus-kernel-check.sh             ← Diagnostic utility for kernel transitions
install.sh                       ← Automated installer and uninstaller
README.md                        ← This file
```

### `asus-performance-setup.sh`

The core script. Applied in three sequential phases:

**Phase 1: sysfs PPT limits** — Auto-detects which interface is present (`asus-armoury` firmware-attributes or legacy `asus-nb-wmi` platform sysfs) and writes `ppt_pl1_spl`, `ppt_pl2_sppt`, and `ppt_fppt`. Waits 1 second after writing to let the firmware register limits before the ryzenadj call.

**Phase 2: `throttle_thermal_policy`** — Always written to `1` (overboost) after the PPT limits. This is the fix for the ~82°C EC-level clock throttle. The node is always at the legacy platform path regardless of kernel version (confirmed as not deprecated in kernel ABI docs).

**Phase 3: ryzenadj** — Applies limits directly to the AMD SMU as a complementary layer. Uses `--tctl-temp`, `--stapm-limit`, `--fast-limit`, and `--slow-limit`.

Key design decisions:

- **`_sudo()` wrapper.** When already root (systemd service context), re-invoking `sudo` is unnecessary and may fail. The wrapper calls commands directly when `EUID==0`.
- **`sudo tee` for sysfs writes.** `sudo echo X > file` does not work — the shell opens the redirect before sudo elevates, so the write runs as the unprivileged user. All writes pipe through `_sudo tee`.
- **`(( ++n ))` pre-increment everywhere.** `set -euo pipefail` is active. `(( n++ ))` (post-increment) exits with code 1 when `n` is 0. Pre-increment `(( ++n ))` always returns the new value (≥1 = true), so it is safe under `set -e`.
- **Graceful degradation.** Each phase (sysfs detection, PPT writes, throttle write, ryzenadj) skips cleanly with a `[WARN]` message if the required module, sysfs node, or binary is absent.
- **`find`-based path discovery.** Both the PPT legacy path and `throttle_thermal_policy` are found using `find /sys/devices/platform`, not hardcoded paths. This handles device-name variation (asus-nb-wmi, asus-wmi, etc.) across G14 generations.

### `asus-performance.service`

A `Type=oneshot` unit that runs the script on every cold boot and restart.

**Important — why there is no `After=asusd.service` or `After=power-profiles-daemon.service`:**

Adding either of those to `After=` creates an ordering cycle that systemd detects and resolves by deleting this unit's start job entirely. The cycle is:

```
multi-user.target → [this unit] → [asusd or ppd] → multi-user.target
```

This is a closed loop. systemd logs `"Job asus-performance.service/start deleted to break ordering cycle"` and the service never runs.

The correct design is to **not** try to order after the daemons. Instead, this unit fires early (after `dbus.service`, which is safely before `multi-user.target` with no cycle risk) and the refresh timer handles the "daemons start after us and overwrite our limits" problem by re-applying every 60 seconds.

`RemainAfterExit=yes` keeps the unit "active" after the script finishes so `Conflicts=sleep.target` can work correctly.

### `asus-performance-resume.service`

Hooks into `sleep.target` to re-apply the profile after every wake event.

Uses the `ExecStop=` pattern (not `ExecStart=`) as the payload. `ExecStop=` fires when `sleep.target` deactivates on wake, not when sleep begins. Includes a 3-second delay before the script to address a race condition where `asus-nb-wmi` needs time to re-register its sysfs nodes with the EC after hibernate resume.

### `asus-performance-refresh.service` and `asus-performance-refresh.timer`

The timer fires 90 seconds after activation (letting `asusd` and PPD settle at boot) and then every 60 seconds. This is the primary defence against mid-session firmware resets caused by AC plug/unplug events, `platform_profile` writes from other daemons, or EC background timers.

### `asus-kernel-check.sh`

A standalone diagnostic and transition utility. Run it as root at any time to:

- Identify kernel version and generation (6.18 legacy, 6.19+ armoury, CachyOS backport)
- List loaded ASUS kernel modules (asus-wmi, asus-nb-wmi, asus-armoury)
- Show which PPT sysfs interface is active and print the actual paths
- Read and display current PPT and `throttle_thermal_policy` values
- Check the health of all systemd units and the next timer fire time
- Confirm ryzenadj availability
- Print the correct monitoring commands for the current kernel
- Run with `--reapply` to also run the setup script immediately

```bash
sudo /usr/local/bin/asus-kernel-check.sh
sudo /usr/local/bin/asus-kernel-check.sh --reapply
```

### `install.sh`

Runs as root. Installs all files to their system locations, enables all persistent units, starts the boot unit and the refresh timer immediately, and handles clean uninstall. Checks for both `asus-armoury` (6.19+) and `asus-nb-wmi` (6.18) modules.

---

## Requirements

| Requirement | Notes |
|---|---|
| Any systemd distro | Tested on Fedora 43 and openSUSE Tumbleweed. Any distro with systemd ≥ 245 works. |
| Kernel ≥ 6.5 | The legacy sysfs PPT interface requires 6.5+. Fedora 43 ships 6.18. CachyOS COPR tracks latest stable. |
| `asus-wmi` module | Loaded automatically on ASUS hardware. Provides throttle_thermal_policy on all kernels. |
| `asus-nb-wmi` module | Needed for legacy PPT interface on kernel 6.5–6.18 (without armoury backport). |
| `asus-armoury` module | Provides PPT interface on kernel 6.19+, or CachyOS 6.18.xx with backport. |
| `asusd` | Optional but recommended. The boot unit works without it. |
| `power-profiles-daemon` | Optional but recommended. |
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

### Verifying module and sysfs nodes

```bash
# Check which ASUS modules are loaded
lsmod | grep asus

# On kernel 6.18 (legacy):
ls /sys/devices/platform/asus-nb-wmi/ppt_pl1_spl \
   /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy

# On kernel 6.19+ or CachyOS with backport (armoury):
ls /sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl1_spl/current_value

# throttle_thermal_policy is always at the platform path:
find /sys/devices/platform -maxdepth 2 -name "throttle_thermal_policy"
```

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
├── asus-kernel-check.sh
├── install.sh
└── README.md
```

### Step 2 — Make the scripts executable

```bash
chmod +x asus-performance-setup.sh asus-kernel-check.sh install.sh
```

### Step 3 — Run the installer

```bash
cd ~/asus-g14-perf
sudo ./install.sh
```

The installer will:

1. Verify all source files are present
2. Warn if `ryzenadj` is missing (install continues either way)
3. Check for both `asus-nb-wmi` and `asus-armoury` modules and report what it finds
4. Check whether `asusd` and `power-profiles-daemon` are running and print guidance
5. Install `asus-performance-setup.sh` and `asus-kernel-check.sh` → `/usr/local/bin/`
6. Install all four `.service` / `.timer` files → `/etc/systemd/system/`
7. Run `systemctl daemon-reload`
8. Enable the boot unit, resume unit, and refresh timer
9. Start the boot unit immediately (limits applied without rebooting)
10. Start the refresh timer (first refresh in 90 seconds)

### Step 4 — Set both daemons to Performance mode (recommended)

```bash
asusctl profile -P Performance
powerprofilesctl set performance
```

### Step 5 — Verify

```bash
# Full diagnostic (shows kernel, interface, values, unit health)
sudo /usr/local/bin/asus-kernel-check.sh

# Boot unit: should show "active (exited)"
systemctl status asus-performance.service

# Resume unit: should show "active (exited)" — armed and waiting for sleep
systemctl status asus-performance-resume.service

# Refresh timer: should show "active (waiting)" with a "Next elapse" time
systemctl status asus-performance-refresh.timer

# Full log from the most recent run
journalctl -u asus-performance.service --no-pager -n 60
```

---

## Customising the Power Limits

Open the script in an editor:

```bash
sudo nano /usr/local/bin/asus-performance-setup.sh
```

Find the `readonly` block near the top:

```bash
readonly PL1_WATTS=33      # Sustained limit — change this
readonly PL2_WATTS=54      # Boost limit — change this
readonly FPPT_WATTS=54     # Fast package power tracking (usually = PL2)
readonly SLOW_MW=44000     # Slow limit in milliwatts (ryzenadj only)
readonly TCTL_TEMP=84      # AMD SMU thermal ceiling in °C
```

Save, then apply the new values immediately without rebooting:

```bash
sudo systemctl restart asus-performance.service
journalctl -u asus-performance.service --no-pager -n 30
```

Keep `SLOW_MW` roughly between `PL1_WATTS × 1000` and `PL2_WATTS × 1000`. The `throttle_thermal_policy` value (`1` = overboost) is intentionally not user-tuneable; if you want silent/balanced mode, switch via `asusctl profile -P Quiet` instead.

---

## Monitoring & Troubleshooting

### Full diagnostic report

```bash
sudo /usr/local/bin/asus-kernel-check.sh
```

This is the first thing to run when diagnosing any issue. It shows kernel version, active interface, current values, unit health, and the correct monitoring commands for your kernel.

### Watch all events live

```bash
journalctl -f -u asus-performance.service \
              -u asus-performance-resume.service \
              -u asus-performance-refresh.service
```

### Read current values — kernel-version-aware

```bash
# Works on any kernel (uses find to discover the path):
PPT_DIR=$(find /sys/devices/platform -maxdepth 2 -name "ppt_pl1_spl" \
          -printf '%h\n' 2>/dev/null | head -n 1)
THROTTLE=$(find /sys/devices/platform -maxdepth 2 -name "throttle_thermal_policy" \
           2>/dev/null | head -n 1)

# Read legacy PPT path if found:
[[ -n "${PPT_DIR}" ]] && cat "${PPT_DIR}/ppt_pl1_spl" 2>/dev/null || echo "legacy path not present"
[[ -n "${THROTTLE}" ]] && cat "${THROTTLE}" || echo "throttle node not found"

# Read asus-armoury PPT path if present (kernel 6.19+ or CachyOS backport):
ARMOURY=/sys/class/firmware-attributes/asus-armoury/attributes
[[ -f "${ARMOURY}/ppt_pl1_spl/current_value" ]] && \
  cat "${ARMOURY}/ppt_pl1_spl/current_value" || echo "armoury path not present"
```

### Check all AMD SMU power management values

```bash
sudo ryzenadj --info
```

Look for `STAPM LIMIT`, `PPT LIMIT FAST`, and `THM LIMIT CORE`. They should match your configured watt values (converted to milliwatts). If they show BIOS defaults instead, a firmware reset has occurred — the refresh timer will correct it within 60 seconds.

### See the boot-time ordering

```bash
systemd-analyze critical-chain asus-performance.service
systemd-analyze plot > /tmp/boot.svg && xdg-open /tmp/boot.svg
```

### Diagnose whether the limits are being reset mid-session

```bash
# Watch throttle_thermal_policy live (works on all kernels):
THROTTLE=$(find /sys/devices/platform -maxdepth 2 -name throttle_thermal_policy 2>/dev/null | head -n 1)
watch -n 5 cat "${THROTTLE}"

# If you see it flipping to 0 repeatedly, check what's writing platform_profile:
journalctl -b | grep -i 'platform_profile\|asusd\|power-profiles' | tail -40
```

### Manually simulate a wake event

```bash
sudo systemctl start asus-performance-resume.service
sudo systemctl stop  asus-performance-resume.service
journalctl -u asus-performance-resume.service --no-pager -n 40
```

### The dmesg deprecation notice

On kernels 6.5–6.18 **without** the `asus-armoury` backport, accessing the legacy PPT sysfs path causes a one-time kernel log message:

```
asus_wmi: Accessing attributes through /sys/bus/platform/asus_wmi is deprecated
          and will be removed in a future release.
```

This appears in `dmesg` and `journalctl -k`. It is not an error. Once you upgrade to kernel 6.19+ (or to a CachyOS kernel with the backport), the script uses the `asus-armoury` interface and this message stops appearing.

---

## After a Kernel Upgrade to 6.19+

No action is required. On the next boot after upgrading, `detect_sysfs_interface()` finds the `asus-armoury` firmware-attributes path first and uses it. You will see `[OK] PPT interface: asus-armoury firmware-attributes` in the journal.

After the first boot on the new kernel, run the diagnostic to confirm:

```bash
sudo /usr/local/bin/asus-kernel-check.sh
```

`throttle_thermal_policy` continues to work from the same platform path as always — it is not affected by the kernel upgrade.

---

## Uninstallation

```bash
sudo ./install.sh uninstall
```

This stops and disables all units and the timer, removes all installed files from `/etc/systemd/system/` and `/usr/local/bin/`, and reloads the daemon. Power limits revert to BIOS defaults on the next boot.

---

## How the Multi-Unit Design Works

```
Cold boot or Restart
  └─► asus-performance.service fires early (after dbus.service)
        ExecStart= runs the setup script — first pass
  └─► [asusd and power-profiles-daemon start, may reset limits]
  └─► T+90s: asus-performance-refresh.timer fires first time
        └─► re-applies all limits after daemon startup has settled ✓
  └─► Every 60s thereafter: refresh timer re-applies limits
        (corrects any AC plug/unplug or daemon resets)

Any sleep state (suspend / hibernate / hybrid-sleep)
  └─► sleep.target activates
        └─► asus-performance-resume.service starts
              ExecStart=/bin/true  (no-op — unit stays "active" during sleep)
        └─► [ SYSTEM SLEEPS ]
        └─► sleep.target deactivates on wake
              └─► StopWhenUnneeded=yes: unit stopped automatically
                    └─► ExecStop= fires  ✓
                          └─► sleep 3 (WMI re-init settle time)
                                └─► Script re-applies all limits

Every 60 seconds (after initial 90-second delay at boot)
  └─► asus-performance-refresh.timer fires
        └─► asus-performance-refresh.service runs the script  ✓
```

**Note on boot unit ordering:** The boot service (`asus-performance.service`) uses `After=sysinit.target local-fs.target dbus.service` — it does NOT list `After=asusd.service` or `After=power-profiles-daemon.service`. Adding those would create an ordering cycle that systemd breaks by deleting the unit's start job. The refresh timer (90-second initial delay) is the correct mechanism for ensuring limits are applied after daemons have settled.

---

## File Locations After Install

| File | Installed location |
|---|---|
| Setup script | `/usr/local/bin/asus-performance-setup.sh` |
| Diagnostic utility | `/usr/local/bin/asus-kernel-check.sh` |
| Boot unit | `/etc/systemd/system/asus-performance.service` |
| Wake/resume unit | `/etc/systemd/system/asus-performance-resume.service` |
| Refresh service | `/etc/systemd/system/asus-performance-refresh.service` |
| Refresh timer | `/etc/systemd/system/asus-performance-refresh.timer` |
