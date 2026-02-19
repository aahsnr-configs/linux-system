#!/bin/bash
# =============================================================================
# install.sh
# Installs or uninstalls the ASUS G14 performance profile on Fedora 43.
#
# Usage:
#   sudo ./install.sh            → install everything
#   sudo ./install.sh uninstall  → cleanly remove everything
#
# Must be run from the directory that contains all four project files:
#   asus-performance-setup.sh
#   asus-performance.service
#   asus-performance-resume.service
#   install.sh
# =============================================================================

set -euo pipefail

# ── File paths ────────────────────────────────────────────────────────────────
readonly SCRIPT_NAME="asus-performance-setup.sh"
readonly SCRIPT_SRC="./${SCRIPT_NAME}"
readonly SCRIPT_DST="/usr/local/bin/${SCRIPT_NAME}"

readonly BOOT_UNIT_NAME="asus-performance.service"
readonly BOOT_UNIT_SRC="./${BOOT_UNIT_NAME}"
readonly BOOT_UNIT_DST="/etc/systemd/system/${BOOT_UNIT_NAME}"

readonly RESUME_UNIT_NAME="asus-performance-resume.service"
readonly RESUME_UNIT_SRC="./${RESUME_UNIT_NAME}"
readonly RESUME_UNIT_DST="/etc/systemd/system/${RESUME_UNIT_NAME}"

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

# Prints an error message and exits non-zero.
die() { log_err "$*"; exit 1; }

# ── Guard: must be root ───────────────────────────────────────────────────────
[[ "${EUID}" -eq 0 ]] || die "Please run as root:  sudo ./install.sh ${1:-}"

# =============================================================================
# UNINSTALL
# =============================================================================
uninstall() {
    echo -e "\n${BLU}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLU}║   Uninstalling ASUS G14 Performance Profile      ║${NC}"
    echo -e "${BLU}╚══════════════════════════════════════════════════╝${NC}\n"

    log_info "Stopping and disabling units…"

    # Use `|| true` so the script continues even if a unit was never enabled.
    systemctl disable --now "${BOOT_UNIT_NAME}"   2>/dev/null \
        && log_ok   "Disabled ${BOOT_UNIT_NAME}" \
        || log_warn "${BOOT_UNIT_NAME} was not active/enabled — skipping."

    systemctl disable --now "${RESUME_UNIT_NAME}" 2>/dev/null \
        && log_ok   "Disabled ${RESUME_UNIT_NAME}" \
        || log_warn "${RESUME_UNIT_NAME} was not active/enabled — skipping."

    log_info "Removing installed files…"

    # BUG FIX: `local` is only valid inside functions.  Using `local` at
    # top-level (outside a function) causes a hard bash error.  Use plain
    # variable assignment here.
    #
    # BUG FIX: never use bare `(( n++ ))` with `set -e` when n may be 0.
    # `(( 0++ ))` evaluates to 0 (arithmetic false) and exits with code 1,
    # killing the script before uninstall completes.  Use `(( ++n ))` instead:
    # the pre-increment always returns the new value (≥1), which is true.
    removed=0
    for f in "${BOOT_UNIT_DST}" "${RESUME_UNIT_DST}" "${SCRIPT_DST}"; do
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
    log_ok "All source files present."

    # ── Warn early about optional tools ──────────────────────────────────────
    if ! command -v ryzenadj > /dev/null 2>&1; then
        echo ""
        log_warn "'ryzenadj' is not installed.  The sysfs section will still work,"
        log_warn "but AMD SMU direct tuning will be skipped until it is installed."
        log_note "Install:  sudo dnf install ryzenadj"
        log_note "Or build: https://github.com/FlyGoat/RyzenAdj"
        echo ""
    fi

    # ── Check asus-nb-wmi module ──────────────────────────────────────────────
    if ! lsmod 2>/dev/null | grep -q 'asus'; then
        echo ""
        log_warn "No ASUS kernel module detected in lsmod output."
        log_note "The script may still work if the module loads automatically at boot."
        log_note "To load now:  sudo modprobe asus-nb-wmi"
        echo ""
    fi

    # ── Install the setup script ──────────────────────────────────────────────
    log_info "Installing setup script → ${SCRIPT_DST}"
    install -D -m 755 "${SCRIPT_SRC}" "${SCRIPT_DST}"
    log_ok "Script installed (executable)."

    # ── Install the systemd unit files ────────────────────────────────────────
    log_info "Installing boot unit → ${BOOT_UNIT_DST}"
    install -D -m 644 "${BOOT_UNIT_SRC}" "${BOOT_UNIT_DST}"
    log_ok "Boot unit installed."

    log_info "Installing resume unit → ${RESUME_UNIT_DST}"
    install -D -m 644 "${RESUME_UNIT_SRC}" "${RESUME_UNIT_DST}"
    log_ok "Resume unit installed."

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

    # ── Start the boot unit immediately (no reboot required) ──────────────────
    log_info "Starting boot unit now (first run without rebooting)…"
    systemctl start "${BOOT_UNIT_NAME}"
    log_ok "Boot unit started."

    # ── Summary ───────────────────────────────────────────────────────────────
    echo ""
    echo -e "${GRN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GRN}║            Installation complete ✓               ║${NC}"
    echo -e "${GRN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Verify boot unit:    systemctl status ${BOOT_UNIT_NAME}"
    echo "  Verify resume unit:  systemctl status ${RESUME_UNIT_NAME}"
    echo "  Live log stream:     journalctl -f -u ${BOOT_UNIT_NAME} -u ${RESUME_UNIT_NAME}"
    echo "  Manual test run:     ${SCRIPT_DST}"
    echo "  Uninstall:           sudo ./install.sh uninstall"
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
