#!/bin/bash
# =============================================================================
# install.sh
# Installs or uninstalls the ASUS G14 performance profile.
#
# Compatible with:
#   • Fedora 43 with official kernel (6.18.xx)
#   • Fedora with CachyOS COPR kernel (6.18.xx or 6.19.xx)
#   • Any systemd-based distro with kernel ≥ 6.5
#
# Usage:
#   sudo ./install.sh            → install everything
#   sudo ./install.sh uninstall  → cleanly remove everything
#
# Must be run from the directory that contains all project files:
#   asus-performance-setup.sh
#   asus-performance.service
#   asus-performance-resume.service
#   asus-performance-refresh.service
#   asus-performance-refresh.timer
#   asus-kernel-check.sh        (optional diagnostic utility)
#   install.sh
# =============================================================================

set -euo pipefail

# ── File paths ────────────────────────────────────────────────────────────────
readonly SCRIPT_NAME="asus-performance-setup.sh"
readonly SCRIPT_SRC="./${SCRIPT_NAME}"
readonly SCRIPT_DST="/usr/local/bin/${SCRIPT_NAME}"

readonly CHECK_SCRIPT_NAME="asus-kernel-check.sh"
readonly CHECK_SCRIPT_SRC="./${CHECK_SCRIPT_NAME}"
readonly CHECK_SCRIPT_DST="/usr/local/bin/${CHECK_SCRIPT_NAME}"

readonly BOOT_UNIT_NAME="asus-performance.service"
readonly BOOT_UNIT_SRC="./${BOOT_UNIT_NAME}"
readonly BOOT_UNIT_DST="/etc/systemd/system/${BOOT_UNIT_NAME}"

readonly RESUME_UNIT_NAME="asus-performance-resume.service"
readonly RESUME_UNIT_SRC="./${RESUME_UNIT_NAME}"
readonly RESUME_UNIT_DST="/etc/systemd/system/${RESUME_UNIT_NAME}"

readonly REFRESH_SVC_NAME="asus-performance-refresh.service"
readonly REFRESH_SVC_SRC="./${REFRESH_SVC_NAME}"
readonly REFRESH_SVC_DST="/etc/systemd/system/${REFRESH_SVC_NAME}"

readonly REFRESH_TMR_NAME="asus-performance-refresh.timer"
readonly REFRESH_TMR_SRC="./${REFRESH_TMR_NAME}"
readonly REFRESH_TMR_DST="/etc/systemd/system/${REFRESH_TMR_NAME}"

# ── Colour helpers ────────────────────────────────────────────────────────────
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

die() { log_err "$*"; exit 1; }

# ── Guard: must be root ───────────────────────────────────────────────────────
[[ "${EUID}" -eq 0 ]] || die "Please run as root:  sudo ./install.sh ${1:-}"

# ── Helper: check if any ASUS kernel module is present ───────────────────────
# Covers both loaded modules and built-in modules, and both 6.18 and 6.19
# kernel module names.
check_asus_modules() {
    local kver
    kver=$(uname -r)
    local found_nb_wmi=false
    local found_wmi=false
    local found_armoury=false

    # Check lsmod (loaded as module) — lsmod uses underscores
    lsmod 2>/dev/null | awk '{print $1}' | grep -qx "asus_nb_wmi"  && found_nb_wmi=true  || true
    lsmod 2>/dev/null | awk '{print $1}' | grep -qx "asus_wmi"     && found_wmi=true     || true
    lsmod 2>/dev/null | awk '{print $1}' | grep -qx "asus_armoury" && found_armoury=true || true

    # Also check modules.builtin (built into kernel, won't appear in lsmod)
    if [[ -f "/lib/modules/${kver}/modules.builtin" ]]; then
        grep -qx "kernel/drivers/platform/x86/asus-nb-wmi.ko" \
            "/lib/modules/${kver}/modules.builtin" 2>/dev/null && found_nb_wmi=true || true
        grep -qx "kernel/drivers/platform/x86/asus-wmi.ko" \
            "/lib/modules/${kver}/modules.builtin" 2>/dev/null && found_wmi=true    || true
        grep -q "asus-armoury" \
            "/lib/modules/${kver}/modules.builtin" 2>/dev/null && found_armoury=true || true
    fi

    if "${found_armoury}"; then
        log_ok "asus-armoury module detected (kernel 6.19+ or CachyOS backport)."
        log_note "The script will use the firmware-attributes PPT interface."
    fi
    if "${found_nb_wmi}" || "${found_wmi}"; then
        log_ok "asus-wmi / asus-nb-wmi module detected."
        if ! "${found_armoury}"; then
            log_note "The script will use the legacy platform sysfs PPT interface."
        fi
    fi

    if ! "${found_nb_wmi}" && ! "${found_wmi}" && ! "${found_armoury}"; then
        echo ""
        log_warn "No ASUS kernel module detected in lsmod or modules.builtin."
        log_note "The script may still work if the module loads automatically at boot."
        log_note "On kernel 6.18:   sudo modprobe asus-nb-wmi"
        log_note "On kernel 6.19+:  module is asus-armoury (loads with asus-wmi)"
        log_note "Run after install: sudo ./asus-kernel-check.sh"
        echo ""
    fi
}

# =============================================================================
# UNINSTALL
# =============================================================================
uninstall() {
    echo -e "\n${BLU}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLU}║   Uninstalling ASUS G14 Performance Profile      ║${NC}"
    echo -e "${BLU}╚══════════════════════════════════════════════════╝${NC}\n"

    log_info "Stopping and disabling units…"

    systemctl disable --now "${BOOT_UNIT_NAME}"   2>/dev/null \
        && log_ok   "Disabled ${BOOT_UNIT_NAME}" \
        || log_warn "${BOOT_UNIT_NAME} was not active/enabled — skipping."

    systemctl disable --now "${RESUME_UNIT_NAME}" 2>/dev/null \
        && log_ok   "Disabled ${RESUME_UNIT_NAME}" \
        || log_warn "${RESUME_UNIT_NAME} was not active/enabled — skipping."

    systemctl disable --now "${REFRESH_TMR_NAME}" 2>/dev/null \
        && log_ok   "Disabled ${REFRESH_TMR_NAME}" \
        || log_warn "${REFRESH_TMR_NAME} was not active/enabled — skipping."

    # The refresh service has no [Install] section; stopping the timer is
    # sufficient, but terminate any in-progress run too.
    systemctl stop "${REFRESH_SVC_NAME}" 2>/dev/null || true

    log_info "Removing installed files…"

    # BUG FIX: using `local` at top-level scope is illegal in bash; plain vars.
    # BUG FIX: using (( ++removed )) (pre-increment) avoids set -e exit on 0.
    removed=0
    for f in "${BOOT_UNIT_DST}" \
              "${RESUME_UNIT_DST}" \
              "${REFRESH_SVC_DST}" \
              "${REFRESH_TMR_DST}" \
              "${SCRIPT_DST}" \
              "${CHECK_SCRIPT_DST}"
    do
        if [[ -f "${f}" ]]; then
            rm -f "${f}"
            log_ok "Removed ${f}"
            (( ++removed ))
        else
            log_warn "Not found, skipping: ${f}"
        fi
    done

    log_info "Reloading systemd daemon…"
    systemctl daemon-reload
    log_ok "Daemon reloaded."

    echo ""
    if (( removed > 0 )); then
        log_ok "Uninstall complete (${removed} file(s) removed)."
        log_note "Power limits will reset to BIOS defaults on the next boot."
    else
        log_warn "No files were found to remove.  Was the project installed?"
    fi
    echo ""
}

# =============================================================================
# INSTALL
# =============================================================================
install_all() {
    echo -e "\n${BLU}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLU}║   Installing ASUS G14 Performance Profile        ║${NC}"
    echo -e "${BLU}╚══════════════════════════════════════════════════╝${NC}\n"

    # ── Verify source files exist ─────────────────────────────────────────────
    log_info "Verifying source files…"
    [[ -f "${SCRIPT_SRC}"      ]] || die "Missing: ${SCRIPT_SRC}  (run install.sh from the project directory)"
    [[ -f "${BOOT_UNIT_SRC}"   ]] || die "Missing: ${BOOT_UNIT_SRC}"
    [[ -f "${RESUME_UNIT_SRC}" ]] || die "Missing: ${RESUME_UNIT_SRC}"
    [[ -f "${REFRESH_SVC_SRC}" ]] || die "Missing: ${REFRESH_SVC_SRC}"
    [[ -f "${REFRESH_TMR_SRC}" ]] || die "Missing: ${REFRESH_TMR_SRC}"
    log_ok "Required source files present."

    if [[ -f "${CHECK_SCRIPT_SRC}" ]]; then
        log_ok "Optional diagnostic script found: ${CHECK_SCRIPT_SRC}"
    else
        log_warn "Optional: ${CHECK_SCRIPT_SRC} not found — skipping install of diagnostic tool."
    fi

    # ── Warn early about optional tools ──────────────────────────────────────
    if ! command -v ryzenadj > /dev/null 2>&1; then
        echo ""
        log_warn "'ryzenadj' is not installed.  The sysfs section will still work,"
        log_warn "but AMD SMU direct tuning will be skipped until it is installed."
        log_note "Install:  sudo dnf install ryzenadj"
        log_note "Or build: https://github.com/FlyGoat/RyzenAdj"
        echo ""
    fi

    # ── Check ASUS kernel modules ─────────────────────────────────────────────
    log_info "Checking ASUS kernel module availability…"
    check_asus_modules

    # ── Warn about the asusd / power-profiles-daemon conflict ─────────────────
    echo ""
    log_info "Checking asusd and power-profiles-daemon status…"
    asusd_active=false
    ppd_active=false
    systemctl is-active --quiet asusd.service             2>/dev/null && asusd_active=true  || true
    systemctl is-active --quiet power-profiles-daemon.service 2>/dev/null && ppd_active=true   || true

    if "${asusd_active}" && "${ppd_active}"; then
        log_warn "Both asusd and power-profiles-daemon are running."
        log_note "These daemons can fight over platform_profile writes.  The refresh timer"
        log_note "fires every 60 seconds to re-apply your limits after any daemon reset."
        log_note "For best results, also run:"
        log_note "  asusctl profile -P Performance"
        log_note "  powerprofilesctl set performance"
        log_note "This makes their boot-time restore write 'performance' into"
        log_note "platform_profile, setting the least-restrictive EC defaults"
        log_note "before the refresh timer overrides throttle_thermal_policy."
    elif "${asusd_active}"; then
        log_ok   "asusd is running."
    elif "${ppd_active}"; then
        log_ok   "power-profiles-daemon is running."
    else
        log_warn "Neither asusd nor power-profiles-daemon appears to be running."
        log_note "The boot unit will still run correctly."
    fi
    echo ""

    # ── Install the setup script ──────────────────────────────────────────────
    log_info "Installing setup script → ${SCRIPT_DST}"
    install -D -m 755 "${SCRIPT_SRC}" "${SCRIPT_DST}"
    log_ok "Script installed (executable)."

    # Install diagnostic utility if present
    if [[ -f "${CHECK_SCRIPT_SRC}" ]]; then
        log_info "Installing diagnostic script → ${CHECK_SCRIPT_DST}"
        install -D -m 755 "${CHECK_SCRIPT_SRC}" "${CHECK_SCRIPT_DST}"
        log_ok "Diagnostic script installed."
    fi

    # ── Install the systemd unit files ────────────────────────────────────────
    log_info "Installing boot unit → ${BOOT_UNIT_DST}"
    install -D -m 644 "${BOOT_UNIT_SRC}" "${BOOT_UNIT_DST}"
    log_ok "Boot unit installed."

    log_info "Installing resume unit → ${RESUME_UNIT_DST}"
    install -D -m 644 "${RESUME_UNIT_SRC}" "${RESUME_UNIT_DST}"
    log_ok "Resume unit installed."

    log_info "Installing refresh service → ${REFRESH_SVC_DST}"
    install -D -m 644 "${REFRESH_SVC_SRC}" "${REFRESH_SVC_DST}"
    log_ok "Refresh service installed."

    log_info "Installing refresh timer → ${REFRESH_TMR_DST}"
    install -D -m 644 "${REFRESH_TMR_SRC}" "${REFRESH_TMR_DST}"
    log_ok "Refresh timer installed."

    # ── Reload daemon so systemd sees the new unit files ──────────────────────
    log_info "Reloading systemd daemon…"
    systemctl daemon-reload
    log_ok "Daemon reloaded."

    # ── Enable units (persist across reboots) ─────────────────────────────────
    log_info "Enabling boot unit…"
    systemctl enable "${BOOT_UNIT_NAME}"
    log_ok "Boot unit enabled."

    log_info "Enabling resume unit…"
    systemctl enable "${RESUME_UNIT_NAME}"
    log_ok "Resume unit enabled."

    log_info "Enabling refresh timer…"
    systemctl enable "${REFRESH_TMR_NAME}"
    log_ok "Refresh timer enabled."

    # ── Start units immediately ───────────────────────────────────────────────
    log_info "Starting boot unit now (applies limits without a reboot)…"
    systemctl start "${BOOT_UNIT_NAME}"
    log_ok "Boot unit started."

    log_info "Starting refresh timer…"
    systemctl start "${REFRESH_TMR_NAME}"
    log_ok "Refresh timer started (first refresh in 90 seconds)."

    # ── Summary ───────────────────────────────────────────────────────────────
    echo ""
    echo -e "${GRN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GRN}║            Installation complete ✓               ║${NC}"
    echo -e "${GRN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Verify boot unit:     systemctl status ${BOOT_UNIT_NAME}"
    echo "  Verify resume unit:   systemctl status ${RESUME_UNIT_NAME}"
    echo "  Verify refresh timer: systemctl status ${REFRESH_TMR_NAME}"
    echo "  Live log stream:      journalctl -f -u ${BOOT_UNIT_NAME} -u ${RESUME_UNIT_NAME} -u ${REFRESH_SVC_NAME}"
    echo "  Full diagnostic:      sudo ${CHECK_SCRIPT_DST}"
    echo "  Manual test run:      sudo ${SCRIPT_DST}"
    echo "  Uninstall:            sudo ./install.sh uninstall"
    echo ""
    echo -e "${YLW}  RECOMMENDED: set both daemons to Performance mode persistently:${NC}"
    echo "    asusctl profile -P Performance"
    echo "    powerprofilesctl set performance"
    echo ""
    echo -e "${YLW}  CachyOS / kernel upgrade note:${NC}"
    echo "    When you switch from a 6.18.xx to a 6.19.xx CachyOS kernel,"
    echo "    NO changes to this project are required.  Run the diagnostic"
    echo "    after the first boot on the new kernel to verify:"
    echo "      sudo ${CHECK_SCRIPT_DST}"
    echo ""
}

# =============================================================================
# Entry point
# =============================================================================
case "${1:-install}" in
    uninstall) uninstall ;;
    install)   install_all ;;
    *)         die "Unknown argument '${1}'.  Usage: sudo ./install.sh [install|uninstall]" ;;
esac
