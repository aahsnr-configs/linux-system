# ASUS G14 Performance Profile — Fedora 43

Automatically applies CPU power and thermal limits every time your laptop powers on, restarts, wakes from suspend, resumes from hibernate, or comes back from hybrid sleep — with no manual steps required after the initial install.

---

## What This Does

ASUS G14 firmware resets CPU power limits on every power state transition — cold boot, restart, suspend resume, hibernate resume. This project re-applies your preferred limits immediately after each transition via two complementary mechanisms:

- **Kernel sysfs writes** — direct writes to the ASUS WMI power management nodes exposed by the `asus-nb-wmi` kernel module
- **ryzenadj** — writes the same limits directly to AMD's System Management Unit as a complementary/reinforcing layer

| Limit | Value | Controls |
|---|---|---|
| PL1 / SPL (sustained) | 34 W | Long-run CPU package power ceiling |
| PL2 / SPPT (boost) | 53 W | Short-burst CPU power ceiling |
| FPPT (fast package power tracking) | 53 W | Very first milliseconds of a burst |
| Slow limit | 44 W | Intermediate ramp-down (ryzenadj only) |
| Thermal limit (`tctl-temp`) | 85 °C | CPU throttle temperature ceiling |

All values are defined as `readonly` constants at the top of `asus-performance-setup.sh` and are straightforward to change.

---

## Critical Context: Kernel 6.18 vs 6.19+

This is the single most important technical detail to understand.

**On Fedora 43 (kernel 6.18)**, the ASUS power limit sysfs interface lives at the *legacy* platform path:

```
/sys/devices/platform/asus-nb-wmi/ppt_pl1_spl
/sys/devices/platform/asus-nb-wmi/ppt_pl2_sppt
/sys/devices/platform/asus-nb-wmi/ppt_fppt
```

This interface has been available since kernel 6.5 and **works correctly on 6.18**. However, upstream has marked it `DEPRECATED — WILL BE REMOVED SOON`. When it is first accessed, the kernel logs a one-time notice in `dmesg`:

```
asus_wmi: Accessing attributes through /sys/bus/platform/asus_wmi is deprecated
          and will be removed in a future release. Please switch over to
          /sys/class/firmware_attributes.
```

This notice is **expected and harmless**. The script prints a matching `[WARN]` line to explain it.

**On kernel 6.19+** (not yet shipped with Fedora 43), the replacement interface is:

```
/sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl1_spl/current_value
```

**The script handles both automatically.** It probes for the `asus-armoury` path first. If not found, it falls back to the `asus-nb-wmi` legacy path. When you eventually upgrade to kernel 6.19+, the script will silently switch interfaces — no changes needed on your part.

---

## Files in This Project

```
asus-performance-setup.sh        ← The main script that applies all limits
asus-performance.service         ← systemd unit: triggers on boot & restart
asus-performance-resume.service  ← systemd unit: triggers on every wake/resume
install.sh                       ← Automated installer and uninstaller
README.md                        ← This file
```

### `asus-performance-setup.sh`

The core script. Key design decisions:

- **No root required to invoke it.** It uses an internal `_sudo()` wrapper that calls commands directly when already root (for the systemd service use case) and calls `command sudo` otherwise. The `sudo` timestamp cache is populated once at startup via `sudo -v`, so subsequent internal calls don't re-prompt.
- **`sudo tee` for all sysfs writes.** The naive `sudo echo X > file` pattern does not work — the shell opens the redirect before sudo elevates, so the write runs as the unprivileged user. All writes use `echo value | sudo tee path`.
- **`(( ++n ))` pre-increment everywhere.** `set -euo pipefail` is active throughout the script. `(( n++ ))` (post-increment) exits with code 1 when `n` is 0 because it evaluates to the old value (0 = false). Pre-increment `(( ++n ))` always returns the new value (≥1 = true), so it is safe under `set -e`.
- **Graceful degradation.** Each section (sysfs detection, sysfs writes, ryzenadj) skips cleanly with a clear `[WARN]` message if the required module, sysfs node, or binary is absent. The script always exits 0 from its normal paths.

### `asus-performance.service`

A `Type=oneshot` systemd service that runs the script on **every cold boot and restart**.

- `RemainAfterExit=yes` keeps the unit "active" after the script finishes, so systemd can track that the profile is applied.
- `Conflicts=sleep.target` transitions the unit to "inactive" when any sleep state begins. This is purely informational — the resume unit handles wake independently and does not depend on this unit's state.

### `asus-performance-resume.service`

A systemd service that hooks into `sleep.target` — the single common parent of all four Linux sleep targets — to re-apply the profile after **every wake event**.

`sleep.target` is pulled in by:

| Sleep state | Target |
|---|---|
| Suspend (RAM / S3) | `suspend.target` |
| Hibernate (disk / S4) | `hibernate.target` |
| Hybrid sleep | `hybrid-sleep.target` |
| Suspend-then-hibernate | `suspend-then-hibernate.target` |

The unit uses `ExecStop=` (not `ExecStart=`) as its payload. This is the correct and officially confirmed systemd idiom for running something *after* resume:

1. Sleep begins → `sleep.target` activates → unit starts → `ExecStart=/bin/true` (no-op)
2. `RemainAfterExit=yes` keeps the unit "active" throughout sleep
3. System wakes → `sleep.target` deactivates → `StopWhenUnneeded=yes` stops this unit → `ExecStop=` fires the script

`DefaultDependencies=no` is set to remove the implicit `After=basic.target` and `Before=shutdown.target` dependencies that systemd adds to all services by default. Those are designed for normal long-running services and would interfere with the sleep/wake ordering. The `/usr/local/bin` path is on the root filesystem which remains mounted through all sleep/wake cycles, so removing these implicit dependencies is safe.

### `install.sh`

Runs as root. Installs the script and unit files to their system locations, enables both units, and does an immediate first run. Also handles clean uninstall.

**Bugs fixed in this version vs earlier drafts:**
- `local variable=value` was used at top-level script scope (outside any function). `local` is only valid inside functions in bash; using it outside causes a hard error. Fixed to plain variable assignment.
- `(( removed++ ))` without `|| true` in the uninstall loop: when `removed=0`, `(( 0++ ))` exits with code 1 and `set -e` would kill the script mid-uninstall. Fixed to `(( ++removed ))`.

---

## Requirements

| Requirement | Notes |
|---|---|
| Fedora 43 | Tested target. Should work on any systemd distro with kernel ≥ 6.5 |
| Kernel 6.18 | Fedora 43's current kernel. 6.5–6.17 also work via the same legacy sysfs path |
| `asus-nb-wmi` module | Loaded automatically on ASUS hardware. Verify with `lsmod \| grep asus` |
| `sudo` access | Installer runs as root; the setup script uses internal sudo |
| `ryzenadj` | Optional but recommended. Applies limits via AMD SMU directly |

### Installing `ryzenadj` on Fedora 43

```bash
# Check if it's available in the repos first
sudo dnf install ryzenadj

# If not in repos, build from source:
sudo dnf install cmake gcc gcc-c++ pciutils-devel
git clone https://github.com/FlyGoat/RyzenAdj.git
cd RyzenAdj
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
sudo make install
```

### Verifying the `asus-nb-wmi` module

```bash
lsmod | grep asus
```

You should see `asus_nb_wmi` and `asus_wmi`. If absent:

```bash
sudo modprobe asus-nb-wmi

# Confirm the sysfs nodes appeared:
ls /sys/devices/platform/asus-nb-wmi/ppt_*
```

---

## Installation

### Step 1 — Place all project files in the same directory

```
~/asus-g14-perf/
├── asus-performance-setup.sh
├── asus-performance.service
├── asus-performance-resume.service
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

1. Check that all source files are present in the current directory
2. Warn if `ryzenadj` or the `asus` kernel module is missing (install continues either way)
3. Install `asus-performance-setup.sh` → `/usr/local/bin/` with executable permissions
4. Install both `.service` files → `/etc/systemd/system/` with `644` permissions
5. Run `systemctl daemon-reload`
6. Enable both units so they survive reboots (`systemctl enable`)
7. Start the boot unit immediately so limits are applied now without rebooting

### Step 4 — Verify

```bash
# Check the boot unit ran successfully
systemctl status asus-performance.service

# Check the resume unit is armed and waiting
systemctl status asus-performance-resume.service

# See the full output from the most recent run
journalctl -u asus-performance.service --no-pager -n 50
```

You should see `[ OK ]` lines for each limit set and `[WARN]` lines for anything skipped.

---

## Customising the Power Limits

Open the script in an editor:

```bash
sudo nano /usr/local/bin/asus-performance-setup.sh
```

Find the `readonly` block near the top of the file and change the values:

```bash
readonly PL1_WATTS=34     # Sustained limit — change this
readonly PL2_WATTS=53     # Boost limit — change this
readonly FPPT_WATTS=53    # Fast package power tracking (usually = PL2)
readonly SLOW_MW=44000    # Slow limit in milliwatts (ryzenadj only)
readonly TCTL_TEMP=85     # Thermal ceiling in °C
```

Save, then apply the new values immediately without rebooting:

```bash
sudo systemctl restart asus-performance.service
journalctl -u asus-performance.service --no-pager -n 20
```

> Keep `SLOW_MW` roughly between `PL1_WATTS × 1000` and `PL2_WATTS × 1000`. The ryzenadj slow limit and sysfs PL1 both govern the sustained budget via different paths — wildly mismatched values can cause the CPU to oscillate.

---

## Monitoring & Troubleshooting

### Watch all events live

```bash
journalctl -f -u asus-performance.service -u asus-performance-resume.service
```

### Read current PPT values from sysfs

```bash
# Kernel 6.18 (Fedora 43 — legacy path)
cat /sys/devices/platform/asus-nb-wmi/ppt_pl1_spl
cat /sys/devices/platform/asus-nb-wmi/ppt_pl2_sppt
cat /sys/devices/platform/asus-nb-wmi/ppt_fppt

# Kernel 6.19+ (after upgrade)
cat /sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl1_spl/current_value
```

### Check all AMD power management values

```bash
sudo ryzenadj --info
```

Look for `STAPM LIMIT`, `PPT LIMIT FAST`, and `THM LIMIT CORE`. They should match your configured watt values (converted to milliwatts).

### Manually simulate a wake event

The `ExecStop=` pattern means the script runs when the resume unit *stops*, which is triggered by `sleep.target` deactivating. To replicate this manually:

```bash
sudo systemctl start asus-performance-resume.service
sudo systemctl stop  asus-performance-resume.service
journalctl -u asus-performance-resume.service --no-pager -n 30
```

Starting then immediately stopping the unit fires `ExecStop=` exactly as a real wake event would.

### Verify which sysfs interface is active

```bash
# Legacy path (kernel 6.5–6.18, Fedora 43)
ls /sys/devices/platform/asus-nb-wmi/ppt_* 2>/dev/null \
    && echo "Legacy asus-nb-wmi path is active" \
    || echo "Legacy path not found"

# Current path (kernel 6.19+)
ls /sys/class/firmware-attributes/asus-armoury/ 2>/dev/null \
    && echo "Armoury firmware-attributes path is active" \
    || echo "Armoury path not found (expected on kernel < 6.19)"
```

### The dmesg deprecation notice

On kernel 6.18, accessing the legacy sysfs path causes the kernel to log a one-time message:

```
asus_wmi: Accessing attributes through /sys/bus/platform/asus_wmi is deprecated
          and will be removed in a future release.
```

This appears in `dmesg` and `journalctl -k`. It is **not an error**. The script prints a matching `[WARN]` line to explain why it appears.

---

## Uninstallation

```bash
sudo ./install.sh uninstall
```

This stops and disables both units, removes both unit files from `/etc/systemd/system/`, removes the script from `/usr/local/bin/`, and reloads the daemon. Power limits will revert to BIOS defaults on the next boot.

---

## How the Two-Unit Design Works

No single systemd target fires on both boot and wake. Two units cover complementary triggers:

```
Cold boot or Restart
  └─▶ multi-user.target activates
        └─▶ asus-performance.service
              ExecStart= runs the script  ✓
              RemainAfterExit=yes keeps it "active"

Any sleep state (suspend / hibernate / hybrid-sleep / suspend-then-hibernate)
  └─▶ sleep.target activates  ←── single parent of ALL sleep targets
        └─▶ asus-performance-resume.service starts
              ExecStart=/bin/true  (no-op)
              RemainAfterExit=yes  (stays "active" during sleep)
        └─▶ [ SYSTEM SLEEPS ]
        └─▶ sleep.target deactivates on wake
              └─▶ StopWhenUnneeded=yes: unit is no longer needed
                    └─▶ Unit stop fires ExecStop=  ✓
                          └─▶ Script re-applies all limits
```

---

## After a Kernel Upgrade to 6.19+

No action is required. On the next boot after upgrading, `detect_sysfs_interface()` will find the new `asus-armoury` firmware-attributes path first and use it automatically. You will see `[INFO] Interface: asus-armoury firmware-attributes (kernel ≥ 6.19)` in the log instead of the legacy interface message, and the `dmesg` deprecation notice will stop appearing.

---

## File Locations After Install

| File | Installed location |
|---|---|
| Setup script | `/usr/local/bin/asus-performance-setup.sh` |
| Boot unit | `/etc/systemd/system/asus-performance.service` |
| Wake/resume unit | `/etc/systemd/system/asus-performance-resume.service` |
