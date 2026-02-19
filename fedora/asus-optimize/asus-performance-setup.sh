#!/bin/bash
# =============================================================================
# asus-performance-setup.sh
# ASUS G14 Performance Profile — Fedora 43 / Kernel 6.18
#
# Applies CPU power and thermal limits via two complementary mechanisms:
#
#   1. Kernel sysfs (asus-nb-wmi, kernel 6.5–6.18)  ← active on Fedora 43
#      /sys/devices/platform/asus-nb-wmi/ppt_pl1_spl
#      /sys/devices/platform/asus-nb-wmi/ppt_pl2_sppt
#      /sys/devices/platform/asus-nb-wmi/ppt_fppt
#      NOTE: This interface is marked DEPRECATED upstream.  The script auto-
#      detects and switches to the asus-armoury interface on kernel 6.19+.
#
#   2. ryzenadj (AMD SMU direct) — complements sysfs writes.
#
# USAGE
#   Run as a normal user:  ./asus-performance-setup.sh
#   Do NOT prefix with sudo.  The script uses sudo internally, only where
#   privileged writes are required.
#
# REQUIRES
#   • sudo access
#   • asus-nb-wmi kernel module loaded (automatic on ASUS hardware)
#   • ryzenadj (optional; skipped gracefully if absent)
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# USER-TUNEABLE VALUES — edit these to change your performance profile
# ─────────────────────────────────────────────────────────────────────────────

# Sustained (long-run) CPU package power ceiling, watts  [PL1 / SPL]
readonly PL1_WATTS=30

# Boost (short-burst) CPU package power ceiling, watts   [PL2 / SPPT]
readonly PL2_WATTS=50

# Fast package power tracking limit, watts               [FPPT]
# Governs the very first milliseconds of a burst. Usually equal to PL2.
readonly FPPT_WATTS=50

# Slow limit in milliwatts — intermediate ramp-down (ryzenadj only)
readonly SLOW_MW=40000

# Thermal control temperature ceiling in °C              [tctl-temp]
readonly TCTL_TEMP=83

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
log_warn()  { echo -e "${YLW}[WARN]${NC}  $*"; }
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
# through `sudo tee` instead (see sysfs_write below).
# ─────────────────────────────────────────────────────────────────────────────
_sudo() {
    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    else
        command sudo "$@"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# sysfs_write <value> <path> [label]
#
# Writes <value> to a sysfs node using `_sudo tee`.  Returns 0 on success,
# 1 if the node does not exist or the write fails.
# ─────────────────────────────────────────────────────────────────────────────
sysfs_write() {
    local value="$1"
    local path="$2"
    local label="${3:-$(basename "$path")}"

    if [[ ! -e "$path" ]]; then
        log_warn "Sysfs node not found, skipping: ${path}"
        return 1
    fi

    if echo "${value}" | _sudo tee "${path}" > /dev/null 2>&1; then
        log_ok "Set ${label} = ${value}W  →  ${path}"
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

    log_info "Kernel: $(uname -r)"
    log_info "Script: ${BASH_SOURCE[0]}"
}

# ─────────────────────────────────────────────────────────────────────────────
# detect_sysfs_interface
#
# Populates the global SYSFS_MODE, SYSFS_PL1, SYSFS_PL2, SYSFS_FPPT
# variables by probing for the active ASUS kernel sysfs interface.
#
# SYSFS_MODE values:
#   "armoury"  — kernel 6.19+ firmware-attributes interface (future)
#   "legacy"   — kernel 6.5–6.18 asus-nb-wmi platform sysfs (Fedora 43)
#   "none"     — neither found; module may not be loaded
# ─────────────────────────────────────────────────────────────────────────────
SYSFS_MODE="none"
SYSFS_PL1=""
SYSFS_PL2=""
SYSFS_FPPT=""

detect_sysfs_interface() {
    log_info "Detecting ASUS sysfs interface…"

    # ── Priority 1: kernel 6.19+ asus-armoury firmware-attributes ────────────
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
            log_ok "Interface: asus-armoury firmware-attributes (kernel ≥ 6.19)"
            return 0
        fi
    fi

    # ── Priority 2: kernel 6.5–6.18 asus-nb-wmi platform sysfs ──────────────
    # Use `find` rather than a hardcoded path — the platform device name can
    # vary across G14 generations (asus-nb-wmi, asus-wmi, etc.).
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

        log_ok "Interface: asus-nb-wmi platform sysfs (kernel 6.5–6.18)"
        log_warn "This interface is marked DEPRECATED upstream (will be removed"
        log_warn "in a future kernel).  When you upgrade to kernel ≥ 6.19, this"
        log_warn "script will automatically switch to asus-armoury — no changes needed."
        log_note "You may see a one-time kernel notice in dmesg about firmware_attributes;"
        log_note "this is expected and harmless."
        return 0
    fi

    # ── Neither interface found ───────────────────────────────────────────────
    SYSFS_MODE="none"
    log_warn "No ASUS sysfs power interface found."
    log_note "Check that the asus-nb-wmi module is loaded:"
    log_note "  lsmod | grep asus"
    log_note "  sudo modprobe asus-nb-wmi"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# apply_ppt_sysfs — write PL1, PL2, and FPPT via the detected sysfs interface
# ─────────────────────────────────────────────────────────────────────────────
apply_ppt_sysfs() {
    if [[ "${SYSFS_MODE}" == "none" ]]; then
        log_warn "Skipping sysfs PPT writes — no interface is available."
        return 0
    fi

    log_info "Applying PPT limits via sysfs (mode: ${SYSFS_MODE})…"

    # Track how many writes succeeded so we know whether to sleep.
    # BUG NOTE: never use (( n++ )) bare with `set -e` — when n==0 the
    # arithmetic expression evaluates to 0 (false) and exits with code 1,
    # killing the script.  Use (( ++n )) (pre-increment) which always
    # returns the new value, which is ≥1 and therefore always true.
    local written=0

    if [[ -n "${SYSFS_PL1}" ]]; then
        sysfs_write "${PL1_WATTS}"  "${SYSFS_PL1}"  "ppt_pl1_spl"  && (( ++written )) || true
    fi
    if [[ -n "${SYSFS_PL2}" ]]; then
        sysfs_write "${PL2_WATTS}"  "${SYSFS_PL2}"  "ppt_pl2_sppt" && (( ++written )) || true
    fi
    if [[ -n "${SYSFS_FPPT}" ]]; then
        sysfs_write "${FPPT_WATTS}" "${SYSFS_FPPT}" "ppt_fppt"     && (( ++written )) || true
    fi

    # Short pause to let the firmware register both PL1 and PL2 before
    # ryzenadj writes to the same SMU registers via a different path.
    if (( written > 0 )); then
        sleep 1
    fi

    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# apply_ryzenadj — set limits via AMD SMU directly
# ─────────────────────────────────────────────────────────────────────────────
apply_ryzenadj() {
    log_info "Applying limits via ryzenadj…"

    if ! command -v ryzenadj > /dev/null 2>&1; then
        log_warn "'ryzenadj' not found in PATH.  Skipping."
        log_note "Install:  sudo dnf install ryzenadj"
        log_note "Or build: https://github.com/FlyGoat/RyzenAdj"
        return 0
    fi

    # ryzenadj takes milliwatts for power limits, °C for temperature.
    # Derive mW values arithmetically so they stay in sync with the watts
    # constants defined at the top of the file.
    local stapm_mw=$(( PL1_WATTS  * 1000 ))
    local fast_mw=$(( FPPT_WATTS  * 1000 ))

    # Argument reference:
    #   --tctl-temp    CPU thermal throttle ceiling (°C)
    #   --stapm-limit  Sustained AMD power limit, mirrors PL1 (mW)
    #   --fast-limit   Fast burst limit, mirrors FPPT (mW)
    #   --slow-limit   Intermediate ramp-down limit (mW)
    if _sudo ryzenadj \
            --tctl-temp="${TCTL_TEMP}"   \
            --stapm-limit="${stapm_mw}"  \
            --fast-limit="${fast_mw}"    \
            --slow-limit="${SLOW_MW}"    2>/dev/null
    then
        log_ok "ryzenadj applied: tctl=${TCTL_TEMP}°C  stapm=${stapm_mw}mW  fast=${fast_mw}mW  slow=${SLOW_MW}mW"
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
    echo -e "\n${BLU}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLU}║   ASUS G14 Performance Profile  —  Fedora 43         ║${NC}"
    echo -e "${BLU}╚══════════════════════════════════════════════════════╝${NC}\n"

    preflight
    echo ""
    detect_sysfs_interface
    echo ""
    apply_ppt_sysfs
    echo ""
    apply_ryzenadj
    echo ""
    log_ok "Done.  Active limits: PL1=${PL1_WATTS}W  PL2=${PL2_WATTS}W  FPPT=${FPPT_WATTS}W  tctl=${TCTL_TEMP}°C"
    echo ""
}

main "$@"
