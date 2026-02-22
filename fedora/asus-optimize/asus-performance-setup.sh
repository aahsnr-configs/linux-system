#!/bin/bash
# =============================================================================
# asus-performance-setup.sh
# ASUS G14 Performance Profile — Fedora / CachyOS Kernel / Any systemd distro
#
# Compatible with:
#   • Kernel 6.5–6.18  — legacy asus-nb-wmi platform sysfs (PPT nodes)
#   • Kernel 6.19+     — asus-armoury firmware-attributes (PPT nodes)
#   • CachyOS 6.18.xx  — may have asus-armoury ALREADY BACKPORTED; the script
#                        detects and uses whichever interface is actually present
#
# Applies CPU power and thermal limits via two complementary mechanisms:
#
#   1. Kernel sysfs PPT limits (auto-detected interface):
#
#      Armoury path (kernel 6.19+, or CachyOS backport) — DETECTED FIRST:
#        /sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl1_spl/current_value
#        /sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl2_sppt/current_value
#        /sys/class/firmware-attributes/asus-armoury/attributes/ppt_fppt/current_value
#
#      Legacy path (kernel 6.5–6.18, asus-nb-wmi) — fallback:
#        /sys/devices/platform/asus-nb-wmi/ppt_pl1_spl
#        /sys/devices/platform/asus-nb-wmi/ppt_pl2_sppt
#        /sys/devices/platform/asus-nb-wmi/ppt_fppt
#
#      NOTE: The legacy PPT interface is marked DEPRECATED upstream and will be
#      removed in the LTS kernel after 6.19.  throttle_thermal_policy is NOT
#      deprecated — it lives at the platform path on ALL supported kernels.
#
#   2. ryzenadj (AMD SMU direct) — complements sysfs writes.
#
# INTERFACE DETECTION ORDER:
#   1. asus-armoury firmware-attributes path (6.19+ or CachyOS backport)
#   2. Legacy asus-nb-wmi platform path (6.5–6.18 without armoury backport)
#   The armoury path is probed first, so CachyOS 6.18.xx users with the
#   backport automatically use the stable, non-deprecated interface.
#
# throttle_thermal_policy:
#   This node lives at /sys/devices/platform/<device>/throttle_thermal_policy
#   on ALL kernel versions (5.6–6.19+).  It is NOT part of asus-armoury and
#   has NOT been deprecated (confirmed by kernel ABI documentation at
#   kernel.org/doc/Documentation/ABI/testing/sysfs-platform-asus-wmi).
#   It is always probed separately using `find`, not a hardcoded path.
#
# USAGE
#   Invoked automatically by:
#     asus-performance.service          (boot / restart)
#     asus-performance-resume.service   (every wake from sleep/hibernate)
#     asus-performance-refresh.timer    (periodic 60-second refresh)
#
#   Manual test run:
#     sudo /usr/local/bin/asus-performance-setup.sh
#
#   Full diagnostic:
#     sudo ./asus-kernel-check.sh
#
# WHY throttle_thermal_policy MATTERS
#   asusd and power-profiles-daemon restore the platform power profile on boot.
#   When the asus-wmi kernel driver receives that platform_profile write, it
#   resets throttle_thermal_policy to 0 (default/balanced).  This imposes an
#   EC-level thermal ceiling of ~82 °C independent of ryzenadj or PPT sysfs
#   values — the embedded controller will clock-throttle the CPU at that
#   temperature regardless of what you write elsewhere.  Setting
#   throttle_thermal_policy=1 (overboost) removes this EC-level cap.
#
# REQUIRES
#   • sudo access (or root — the script detects both)
#   • asus-nb-wmi (6.18) OR asus-armoury (6.19+) kernel module loaded
#   • ryzenadj (optional; skipped gracefully if absent)
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# USER-TUNEABLE VALUES — edit these to change your performance profile
# ─────────────────────────────────────────────────────────────────────────────

# Sustained (long-run) CPU package power ceiling, watts  [PL1 / SPL]
readonly PL1_WATTS=33

# Boost (short-burst) CPU package power ceiling, watts   [PL2 / SPPT]
readonly PL2_WATTS=54

# Fast package power tracking limit, watts               [FPPT]
# Governs the very first milliseconds of a burst.  Usually equal to PL2.
readonly FPPT_WATTS=54

# Slow limit in milliwatts — intermediate ramp-down (ryzenadj only)
readonly SLOW_MW=44000

# Thermal control temperature ceiling in °C              [tctl-temp]
# This is the AMD SMU thermal ceiling — it works alongside
# throttle_thermal_policy=1 (overboost) which removes the EC-level ~82°C cap.
readonly TCTL_TEMP=84

# ─────────────────────────────────────────────────────────────────────────────
# Colour helpers
# ─────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
BLU='\033[0;34m'
DIM='\033[2m'
NC='\033[0m'

log_info()  { echo -e "${BLU}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GRN}[ OK ]${NC}  $*"; }
log_warn()  { echo -e "${YLW}[WARN]${NC}  $*" >&2; }
log_err()   { echo -e "${RED}[ERR ]${NC}  $*" >&2; }
log_note()  { echo -e "${DIM}        $*${NC}"; }

# ─────────────────────────────────────────────────────────────────────────────
# Internal sudo wrapper
#
# When the script is already running as root (e.g. invoked via a systemd
# service), re-invoking sudo is unnecessary and may fail in minimal
# environments.  This wrapper calls the command directly when EUID==0, and
# falls through to the real sudo binary otherwise.
#
# IMPORTANT: every privileged write must go through this wrapper — never call
# `sudo echo X > file` because the shell opens the redirect *before* sudo
# runs, so the redirect still executes as the unprivileged user.  Always pipe
# through `_sudo tee` instead (see sysfs_write below).
# ─────────────────────────────────────────────────────────────────────────────
_sudo() {
    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    else
        command sudo "$@"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# sysfs_write <value> <path> <label> [unit]
#
# Writes <value> to a sysfs node using `_sudo tee`.
#   <value>  — the value to write
#   <path>   — full sysfs path to write to
#   <label>  — human-readable name for log output
#   [unit]   — optional unit suffix for the log line (e.g. "W", "°C")
#              omit or pass "" for dimensionless values
#
# Returns 0 on success, 1 if the node does not exist or the write fails.
# ─────────────────────────────────────────────────────────────────────────────
sysfs_write() {
    local value="$1"
    local path="$2"
    local label="$3"
    local unit="${4:-}"

    if [[ ! -e "${path}" ]]; then
        log_warn "Sysfs node not found, skipping: ${path}"
        return 1
    fi

    if echo "${value}" | _sudo tee "${path}" > /dev/null 2>&1; then
        log_ok "Set ${label} = ${value}${unit}  →  ${path}"
        return 0
    else
        log_err "Failed to write ${value} to ${path}"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# preflight — validate sudo access and print runtime context
# ─────────────────────────────────────────────────────────────────────────────
preflight() {
    log_info "Pre-flight checks…"

    if [[ "${EUID}" -ne 0 ]]; then
        if ! command -v sudo > /dev/null 2>&1; then
            log_err "'sudo' is not installed.  Cannot elevate privileges."
            exit 1
        fi
        # Validate credentials once here.  The sudo timestamp cache then
        # satisfies all subsequent _sudo calls without re-prompting.
        log_info "Validating sudo credentials (one password prompt if needed)…"
        if ! command sudo -v; then
            log_err "sudo authentication failed.  Aborting."
            exit 1
        fi
        log_ok "sudo credentials valid."
    else
        log_info "Running as root — _sudo calls will execute commands directly."
    fi

    local kver
    kver=$(uname -r)
    log_info "Kernel: ${kver}"
    log_info "Script: ${BASH_SOURCE[0]}"

    # Advisory note for CachyOS kernels: asus-armoury may be present even on
    # 6.18.xx.  The interface detection below handles this transparently.
    if echo "${kver}" | grep -qi 'cachyos\|cachy'; then
        log_note "CachyOS kernel detected."
        log_note "asus-armoury may already be available even on 6.18.xx — will auto-detect."
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# detect_sysfs_interface
#
# Populates the global SYSFS_MODE, SYSFS_PL1, SYSFS_PL2, SYSFS_FPPT,
# and SYSFS_THROTTLE variables by probing for the active ASUS kernel sysfs
# interface.
#
# SYSFS_MODE values:
#   "armoury"  — asus-armoury firmware-attributes interface
#                (kernel 6.19+ mainline, or CachyOS 6.18.xx with backport)
#   "legacy"   — kernel 6.5–6.18 asus-nb-wmi platform sysfs
#   "none"     — neither found; module may not be loaded
#
# throttle_thermal_policy:
#   Lives at the platform sysfs path on ALL kernel versions.  NOT part of
#   asus-armoury.  NOT deprecated.  Probed independently of the PPT interface.
# ─────────────────────────────────────────────────────────────────────────────
SYSFS_MODE="none"
SYSFS_PL1=""
SYSFS_PL2=""
SYSFS_FPPT=""
SYSFS_THROTTLE=""   # throttle_thermal_policy — always at platform path

detect_sysfs_interface() {
    log_info "Detecting ASUS sysfs interface…"

    # ── Priority 1: asus-armoury firmware-attributes ──────────────────────────
    # Present on kernel 6.19+ (mainline) and on CachyOS kernels that have
    # backported the asus-armoury driver from the ASUS Linux project.
    local armoury_base="/sys/class/firmware-attributes/asus-armoury/attributes"
    if [[ -d "${armoury_base}" ]]; then
        local a_pl1="${armoury_base}/ppt_pl1_spl/current_value"
        local a_pl2="${armoury_base}/ppt_pl2_sppt/current_value"
        local a_fppt="${armoury_base}/ppt_fppt/current_value"
        if [[ -f "${a_pl1}" && -f "${a_pl2}" ]]; then
            SYSFS_MODE="armoury"
            SYSFS_PL1="${a_pl1}"
            SYSFS_PL2="${a_pl2}"
            [[ -f "${a_fppt}" ]] && SYSFS_FPPT="${a_fppt}"
            log_ok "PPT interface: asus-armoury firmware-attributes"
            log_note "Using stable, non-deprecated interface (kernel 6.19+ or CachyOS backport)."
        fi
    fi

    # ── Priority 2: kernel 6.5–6.18 asus-nb-wmi platform sysfs ──────────────
    if [[ "${SYSFS_MODE}" == "none" ]]; then
        # Use `find` rather than a hardcoded path — the platform device name
        # can vary across G14 generations (asus-nb-wmi, asus-wmi, etc.).
        local legacy_pl1=""
        legacy_pl1=$(find /sys/devices/platform -maxdepth 2 \
                          -name "ppt_pl1_spl" 2>/dev/null | head -n 1)

        if [[ -n "${legacy_pl1}" ]]; then
            local platform_dir
            platform_dir="$(dirname "${legacy_pl1}")"

            SYSFS_MODE="legacy"
            SYSFS_PL1="${legacy_pl1}"
            [[ -f "${platform_dir}/ppt_pl2_sppt" ]] && SYSFS_PL2="${platform_dir}/ppt_pl2_sppt"
            [[ -f "${platform_dir}/ppt_fppt"     ]] && SYSFS_FPPT="${platform_dir}/ppt_fppt"

            log_ok "PPT interface: asus-nb-wmi platform sysfs (kernel 6.5–6.18)"
            log_warn "This PPT interface is marked DEPRECATED upstream (will be removed"
            log_warn "in the LTS kernel after 6.19).  When you upgrade to kernel 6.19+"
            log_warn "(or to a CachyOS kernel with asus-armoury), the script switches"
            log_warn "to the stable asus-armoury interface automatically — no changes needed."
            log_note "A one-time deprecation notice in dmesg is expected and harmless."
        fi
    fi

    # ── throttle_thermal_policy — always at platform sysfs path ─────────────
    # This node is NOT deprecated and NOT part of asus-armoury.
    # Confirmed stable at the platform path for all kernel versions through 6.19+.
    # Using `find` to handle device-name variation (asus-nb-wmi vs asus-wmi, etc.)
    local throttle_path=""
    throttle_path=$(find /sys/devices/platform -maxdepth 2 \
                         -name "throttle_thermal_policy" 2>/dev/null | head -n 1)
    if [[ -n "${throttle_path}" ]]; then
        SYSFS_THROTTLE="${throttle_path}"
        log_ok "throttle_thermal_policy found: ${SYSFS_THROTTLE}"
    else
        log_warn "throttle_thermal_policy node not found."
        log_note "This node is at the platform path on ALL kernel versions, including 6.19+."
        log_note "The asus-wmi module must be loaded for this node to appear."
        log_note "  lsmod | grep asus   →  should show asus_wmi and/or asus_nb_wmi"
        log_note "  sudo modprobe asus-nb-wmi"
        log_note "The EC thermal cap (~82 °C) will remain in effect until the next run."
    fi

    # ── Neither PPT interface found ───────────────────────────────────────────
    if [[ "${SYSFS_MODE}" == "none" ]]; then
        log_warn "No ASUS sysfs PPT interface found."
        log_note "Kernel 6.18  → lsmod | grep asus_nb_wmi   (load: sudo modprobe asus-nb-wmi)"
        log_note "Kernel 6.19+ → lsmod | grep asus_armoury"
        log_note "CachyOS      → ls /sys/class/firmware-attributes/  (check for asus-armoury)"
        log_note "Run:  sudo ./asus-kernel-check.sh  for full diagnostics"
    fi

    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# apply_ppt_sysfs — write PL1, PL2, FPPT, and throttle_thermal_policy
# ─────────────────────────────────────────────────────────────────────────────
apply_ppt_sysfs() {
    echo ""
    log_info "─── Phase 1: sysfs PPT limits (mode: ${SYSFS_MODE}) ───"

    if [[ "${SYSFS_MODE}" == "none" ]]; then
        log_warn "Skipping PPT sysfs writes — no interface is available."
    else
        # BUG NOTE: never use (( n++ )) bare with `set -e` — when n==0 the
        # arithmetic expression evaluates to 0 (false) and exits with code 1.
        # Use (( ++n )) (pre-increment) which always returns the new value
        # (≥1 = true), which is safe under set -e.
        local written=0

        if [[ -n "${SYSFS_PL1}" ]]; then
            sysfs_write "${PL1_WATTS}"  "${SYSFS_PL1}"  "ppt_pl1_spl (PL1/SPL)"  "W" \
                && (( ++written )) || true
        fi
        if [[ -n "${SYSFS_PL2}" ]]; then
            sysfs_write "${PL2_WATTS}"  "${SYSFS_PL2}"  "ppt_pl2_sppt (PL2/SPPT)" "W" \
                && (( ++written )) || true
        fi
        if [[ -n "${SYSFS_FPPT}" ]]; then
            sysfs_write "${FPPT_WATTS}" "${SYSFS_FPPT}" "ppt_fppt (FPPT)"          "W" \
                && (( ++written )) || true
        fi

        # Short pause to let the firmware register PPT values before ryzenadj
        # writes to the same SMU registers via a different path.
        if (( written > 0 )); then
            sleep 1
        fi
    fi

    # ── throttle_thermal_policy ───────────────────────────────────────────────
    # Write this AFTER the PPT limits.  asusd/power-profiles-daemon may have
    # set this to 0 (balanced) when they restored the platform_profile on boot,
    # which imposes an EC-level ~82 °C clock-throttle cap independent of all
    # other limits.  Setting it to 1 (overboost) removes that EC-level cap.
    #
    # Values:
    #   0 = default/balanced — EC enforces ~82 °C ceiling
    #   1 = overboost/performance — EC cap removed, fans run harder
    #   2 = silent — conservative limits
    #
    # This node is at the platform path on ALL kernels including 6.19+.
    echo ""
    log_info "─── Phase 2: throttle_thermal_policy ───"
    if [[ -n "${SYSFS_THROTTLE}" ]]; then
        sysfs_write "1" "${SYSFS_THROTTLE}" "throttle_thermal_policy (overboost)" "" \
            || log_warn "Could not set throttle_thermal_policy — EC thermal cap remains."
    else
        log_warn "Skipping throttle_thermal_policy — node not found."
        log_note "Ensure asus-wmi module is loaded: lsmod | grep asus"
    fi

    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# apply_ryzenadj — set limits via AMD SMU directly
#
# ryzenadj writes directly to the AMD System Management Unit.  This is a
# complementary layer to the sysfs writes above: the two paths reach the same
# hardware limits via different interfaces, which helps the values stick
# against firmware resets.
#
# NOTE: the firmware can reset these values at any time (AC plug/unplug,
# power state transitions, background EC timers).  The periodic refresh timer
# (asus-performance-refresh.timer) re-applies them every 60 seconds.
# ─────────────────────────────────────────────────────────────────────────────
apply_ryzenadj() {
    echo ""
    log_info "─── Phase 3: ryzenadj (AMD SMU direct) ───"

    if ! command -v ryzenadj > /dev/null 2>&1; then
        log_warn "'ryzenadj' not found in PATH.  Skipping."
        log_note "Install:  sudo dnf install ryzenadj"
        log_note "Or build: https://github.com/FlyGoat/RyzenAdj"
        return 0
    fi

    # ryzenadj takes milliwatts for power limits, °C for temperature.
    local stapm_mw=$(( PL1_WATTS  * 1000 ))
    local fast_mw=$(( FPPT_WATTS  * 1000 ))

    # Argument reference:
    #   --tctl-temp    CPU thermal throttle ceiling (°C)   — AMD SMU layer
    #   --stapm-limit  Sustained AMD power limit (mW)      — mirrors PL1
    #   --fast-limit   Fast burst limit (mW)               — mirrors FPPT
    #   --slow-limit   Intermediate ramp-down limit (mW)   — ryzenadj only
    if _sudo ryzenadj \
            --tctl-temp="${TCTL_TEMP}"   \
            --stapm-limit="${stapm_mw}"  \
            --fast-limit="${fast_mw}"    \
            --slow-limit="${SLOW_MW}"    2>/dev/null
    then
        log_ok "ryzenadj applied:"
        log_note "  tctl-temp  = ${TCTL_TEMP}°C"
        log_note "  stapm      = ${stapm_mw} mW  (${PL1_WATTS}W)"
        log_note "  fast-limit = ${fast_mw} mW   (${FPPT_WATTS}W)"
        log_note "  slow-limit = ${SLOW_MW} mW"
    else
        log_err "ryzenadj exited with an error."
        log_note "Verify:  sudo ryzenadj --info"
    fi

    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# main
# ─────────────────────────────────────────────────────────────────────────────
main() {
    echo -e "\n${BLU}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLU}║  ASUS G14 Performance Profile — 6.18 / 6.19+ / CachyOS   ║${NC}"
    echo -e "${BLU}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    preflight
    detect_sysfs_interface
    apply_ppt_sysfs
    apply_ryzenadj

    echo ""
    log_ok "Done."
    log_note "Active limits:"
    log_note "  PL1 (sustained)          = ${PL1_WATTS}W"
    log_note "  PL2 (boost)              = ${PL2_WATTS}W"
    log_note "  FPPT (fast burst)        = ${FPPT_WATTS}W"
    log_note "  tctl-temp (AMD SMU)      = ${TCTL_TEMP}°C"
    log_note "  throttle_thermal_policy  = 1 (overboost — EC cap removed)"
    log_note "  sysfs mode               = ${SYSFS_MODE}"
    echo ""
}

main "$@"
