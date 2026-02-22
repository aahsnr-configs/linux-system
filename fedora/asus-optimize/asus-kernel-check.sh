#!/bin/bash
# =============================================================================
# asus-kernel-check.sh
# ASUS G14 Kernel Transition Diagnostic — for CachyOS / Fedora users
#
# Detects which kernel and sysfs interface is active, reads all current
# power limit values, and reports the full health of the asus performance
# setup across both kernel generations.
#
# Designed for use when:
#   • You upgrade from CachyOS kernel 6.18.xx → 6.19.xx (or any 6.19+ kernel)
#   • You want to verify the setup is working correctly after install
#   • You suspect sysfs paths have changed or limits aren't being applied
#   • You want to know which interface (legacy vs armoury) is active
#
# USAGE
#   sudo ./asus-kernel-check.sh           — full diagnostic report
#   sudo ./asus-kernel-check.sh --reapply — run diagnostic then re-apply limits
#   sudo ./asus-kernel-check.sh --help    — show this message
#
# Does NOT require the project to be installed — can be run from any directory
# containing asus-performance-setup.sh.
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Colour helpers
# ─────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
BLU='\033[0;34m'
CYN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

hdr()   { echo -e "\n${BLU}${BOLD}━━ $* ━━${NC}"; }
ok()    { echo -e "  ${GRN}✔${NC}  $*"; }
warn()  { echo -e "  ${YLW}⚠${NC}  $*"; }
fail()  { echo -e "  ${RED}✘${NC}  $*"; }
info()  { echo -e "  ${CYN}→${NC}  $*"; }
note()  { echo -e "     ${DIM}$*${NC}"; }
val()   { echo -e "     ${BOLD}$1${NC}  =  ${CYN}$2${NC}  $3"; }

# ─────────────────────────────────────────────────────────────────────────────
# Guard: must be root
# ─────────────────────────────────────────────────────────────────────────────
[[ "${EUID}" -eq 0 ]] || {
    echo -e "${RED}[ERR]${NC} Please run as root:  sudo ./asus-kernel-check.sh ${1:-}"
    exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    sed -n '/^# USAGE/,/^# ====/p' "${BASH_SOURCE[0]}" | head -n -1 | sed 's/^# \?//'
    exit 0
fi

DO_REAPPLY=false
[[ "${1:-}" == "--reapply" ]] && DO_REAPPLY=true

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
read_sysfs() {
    local path="$1"
    if [[ -f "${path}" ]]; then
        cat "${path}" 2>/dev/null || echo "(unreadable)"
    else
        echo "(not found)"
    fi
}

find_platform_node() {
    find /sys/devices/platform -maxdepth 2 -name "$1" 2>/dev/null | head -n 1
}

module_loaded() {
    # lsmod uses _ not -, so convert
    lsmod 2>/dev/null | awk '{print $1}' | grep -qx "${1//-/_}"
}

module_builtin() {
    [[ -f "/sys/module/${1//-/_}/coresize" ]] || \
    grep -qx "${1//-/_}" /lib/modules/"$(uname -r)"/modules.builtin 2>/dev/null
}

module_present() {
    module_loaded "$1" || module_builtin "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
# Banner
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n${BLU}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLU}${BOLD}║   ASUS G14 Kernel Transition & Diagnostics                  ║${NC}"
echo -e "${BLU}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"

# =============================================================================
# SECTION 1: Kernel identity
# =============================================================================
hdr "Kernel Identity"

KVER=$(uname -r)
info "Running kernel: ${BOLD}${KVER}${NC}"

# Classify
KERNEL_GEN="unknown"
if echo "${KVER}" | grep -qE '^6\.(19|[2-9][0-9])'; then
    KERNEL_GEN="6.19+"
    ok "Kernel generation: ${BOLD}6.19+${NC} — asus-armoury is mainline in this kernel"
elif echo "${KVER}" | grep -qE '^6\.(5|6|7|8|9|10|11|12|13|14|15|16|17|18)'; then
    KERNEL_GEN="6.18-range"
    if echo "${KVER}" | grep -qi 'cachyos\|cachy'; then
        ok "Kernel generation: ${BOLD}6.18.xx CachyOS${NC}"
        note "CachyOS 6.18.xx may have asus-armoury backported — check sections below."
    else
        ok "Kernel generation: ${BOLD}6.18.xx vanilla/Fedora${NC}"
        note "Legacy asus-nb-wmi PPT interface expected."
    fi
else
    warn "Kernel version '${KVER}' is older than 6.5 or unrecognised."
    note "The legacy asus-nb-wmi PPT interface requires kernel ≥ 6.5."
fi

# =============================================================================
# SECTION 2: Kernel modules
# =============================================================================
hdr "Kernel Modules"

HAVE_WMI=false
HAVE_NB_WMI=false
HAVE_ARMOURY=false

if module_present "asus-wmi" || module_present "asus_wmi"; then
    HAVE_WMI=true
    ok "asus-wmi (asus_wmi)  — loaded / built-in"
else
    fail "asus-wmi not found in lsmod or modules.builtin"
    note "Try: sudo modprobe asus-nb-wmi"
fi

if module_present "asus-nb-wmi" || module_present "asus_nb_wmi"; then
    HAVE_NB_WMI=true
    ok "asus-nb-wmi          — loaded / built-in"
else
    note "asus-nb-wmi not loaded (expected on kernel 6.18, optional on 6.19+)"
fi

if module_present "asus-armoury" || module_present "asus_armoury"; then
    HAVE_ARMOURY=true
    ok "asus-armoury         — loaded / built-in"
    note "This is the new firmware-attributes driver introduced in kernel 6.19."
else
    if [[ "${KERNEL_GEN}" == "6.19+" ]]; then
        fail "asus-armoury NOT found — expected on kernel 6.19+"
        note "Try: sudo modprobe asus-armoury"
        note "Or check: ls /sys/class/firmware-attributes/"
    else
        note "asus-armoury not present (normal for vanilla 6.18.xx without backport)"
    fi
fi

# =============================================================================
# SECTION 3: PPT sysfs interface detection
# =============================================================================
hdr "PPT Sysfs Interface"

ARMOURY_BASE="/sys/class/firmware-attributes/asus-armoury/attributes"
PPT_MODE="none"
PPT_PL1_PATH=""
PPT_PL2_PATH=""
PPT_FPPT_PATH=""

# Check asus-armoury firmware-attributes first (preferred)
if [[ -d "${ARMOURY_BASE}" ]]; then
    A_PL1="${ARMOURY_BASE}/ppt_pl1_spl/current_value"
    A_PL2="${ARMOURY_BASE}/ppt_pl2_sppt/current_value"
    A_FPPT="${ARMOURY_BASE}/ppt_fppt/current_value"

    if [[ -f "${A_PL1}" && -f "${A_PL2}" ]]; then
        PPT_MODE="armoury"
        PPT_PL1_PATH="${A_PL1}"
        PPT_PL2_PATH="${A_PL2}"
        [[ -f "${A_FPPT}" ]] && PPT_FPPT_PATH="${A_FPPT}"
        ok "Active PPT interface: ${BOLD}asus-armoury firmware-attributes${NC}"
        note "Base directory: ${ARMOURY_BASE}"
    else
        warn "asus-armoury directory found but PPT attribute files are missing:"
        [[ ! -f "${A_PL1}"  ]] && note "  Missing: ${A_PL1}"
        [[ ! -f "${A_PL2}"  ]] && note "  Missing: ${A_PL2}"
        note "The asus-armoury module may not fully support your hardware variant."
    fi
fi

# Fall back to legacy platform sysfs
if [[ "${PPT_MODE}" == "none" ]]; then
    LEGACY_PL1=$(find_platform_node "ppt_pl1_spl")
    if [[ -n "${LEGACY_PL1}" ]]; then
        PLAT_DIR="$(dirname "${LEGACY_PL1}")"
        PPT_MODE="legacy"
        PPT_PL1_PATH="${LEGACY_PL1}"
        LEGACY_PL2="${PLAT_DIR}/ppt_pl2_sppt"
        LEGACY_FPPT="${PLAT_DIR}/ppt_fppt"
        [[ -f "${LEGACY_PL2}"  ]] && PPT_PL2_PATH="${LEGACY_PL2}"
        [[ -f "${LEGACY_FPPT}" ]] && PPT_FPPT_PATH="${LEGACY_FPPT}"
        ok "Active PPT interface: ${BOLD}asus-nb-wmi platform sysfs (legacy)${NC}"
        warn "This interface is DEPRECATED upstream and will be removed in the"
        note "LTS kernel following 6.19.  After upgrading to kernel 6.19+ (or a"
        note "CachyOS kernel with asus-armoury), the script switches automatically."
        note "Base directory: ${PLAT_DIR}"
    fi
fi

if [[ "${PPT_MODE}" == "none" ]]; then
    fail "No PPT sysfs interface found (neither asus-armoury nor legacy path)"
    note "Verify kernel modules are loaded (see section above)."
fi

# =============================================================================
# SECTION 4: throttle_thermal_policy
# =============================================================================
hdr "throttle_thermal_policy"

THROTTLE_PATH=$(find_platform_node "throttle_thermal_policy")
if [[ -n "${THROTTLE_PATH}" ]]; then
    ok "Found at: ${THROTTLE_PATH}"
    note "This node lives at the PLATFORM path on ALL kernels (5.6–6.19+)."
    note "It is NOT part of asus-armoury and is NOT deprecated."
else
    fail "throttle_thermal_policy NOT found"
    note "This node must be present at /sys/devices/platform/<device>/throttle_thermal_policy"
    note "It should exist on all kernels if asus-wmi is loaded."
    note "Try: sudo modprobe asus-nb-wmi && ls /sys/devices/platform/asus-nb-wmi/"
fi

# =============================================================================
# SECTION 5: Current values
# =============================================================================
hdr "Current Sysfs Values"

if [[ "${PPT_MODE}" != "none" ]]; then
    PL1_CUR=$(read_sysfs "${PPT_PL1_PATH}")
    PL2_CUR=$(read_sysfs "${PPT_PL2_PATH}")
    FPPT_CUR=$(read_sysfs "${PPT_FPPT_PATH:-}")

    val "ppt_pl1_spl  (PL1/SPL)"  "${PL1_CUR}W"   "(${PPT_PL1_PATH})"
    val "ppt_pl2_sppt (PL2/SPPT)" "${PL2_CUR}W"   "(${PPT_PL2_PATH})"
    if [[ -n "${PPT_FPPT_PATH}" ]]; then
        val "ppt_fppt    (FPPT)"   "${FPPT_CUR}W"  "(${PPT_FPPT_PATH})"
    else
        warn "ppt_fppt node not found — may not be supported on this hardware"
    fi
else
    warn "Cannot read PPT values — no interface found."
fi

if [[ -n "${THROTTLE_PATH}" ]]; then
    THROT_CUR=$(read_sysfs "${THROTTLE_PATH}")
    val "throttle_thermal_policy" "${THROT_CUR}" "(0=balanced/82°C cap, 1=overboost, 2=silent)"
    if [[ "${THROT_CUR}" == "1" ]]; then
        ok "throttle_thermal_policy=1 (overboost) — EC thermal cap is REMOVED  ✓"
    elif [[ "${THROT_CUR}" == "0" ]]; then
        warn "throttle_thermal_policy=0 (balanced) — EC is enforcing ~82°C ceiling!"
        note "Run the setup script or restart asus-performance.service to fix this."
    else
        note "throttle_thermal_policy=${THROT_CUR} (silent mode)"
    fi
else
    warn "Cannot read throttle_thermal_policy — node not found."
fi

# =============================================================================
# SECTION 6: systemd unit health
# =============================================================================
hdr "Systemd Unit Health"

check_unit() {
    local unit="$1"
    local expected_state="$2"
    if ! systemctl list-unit-files "${unit}" 2>/dev/null | grep -q "${unit}"; then
        fail "${unit}  — NOT INSTALLED (run install.sh)"
        return
    fi
    local state
    state=$(systemctl is-active "${unit}" 2>/dev/null || true)
    local enabled
    enabled=$(systemctl is-enabled "${unit}" 2>/dev/null || true)
    if [[ "${state}" == "${expected_state}" ]]; then
        ok "${unit}  — ${state} / ${enabled}"
    else
        warn "${unit}  — ${state} / ${enabled}  (expected: ${expected_state})"
        note "Run: journalctl -u ${unit} --no-pager -n 20"
    fi
}

check_unit "asus-performance.service"         "active"
check_unit "asus-performance-resume.service"  "active"
check_unit "asus-performance-refresh.timer"   "active"

# Show next timer fire
if systemctl is-active --quiet "asus-performance-refresh.timer" 2>/dev/null; then
    NEXT=$(systemctl status asus-performance-refresh.timer 2>/dev/null \
           | grep "Trigger:" | head -n 1 | sed 's/.*Trigger: //')
    [[ -n "${NEXT}" ]] && info "Next refresh timer fire: ${NEXT}"
fi

# =============================================================================
# SECTION 7: Optional ryzenadj
# =============================================================================
hdr "ryzenadj (AMD SMU)"

if command -v ryzenadj > /dev/null 2>&1; then
    ok "ryzenadj is installed: $(command -v ryzenadj)"
    note "To see current AMD SMU limits: sudo ryzenadj --info"
    note "Look for: STAPM LIMIT, PPT LIMIT FAST, THM LIMIT CORE"
else
    warn "ryzenadj is NOT installed (optional but recommended)."
    note "Install:  sudo dnf install ryzenadj"
    note "Or build: https://github.com/FlyGoat/RyzenAdj"
fi

# =============================================================================
# SECTION 8: Kernel upgrade readiness summary
# =============================================================================
hdr "Kernel Upgrade Readiness"

if [[ "${PPT_MODE}" == "armoury" ]]; then
    ok "Already using asus-armoury interface — you are 6.19+-ready."
    note "After upgrading to any 6.19.xx kernel, the setup requires NO changes."
    note "The script will continue using the armoury interface automatically."
elif [[ "${PPT_MODE}" == "legacy" ]]; then
    info "Currently using legacy asus-nb-wmi interface (6.18 mode)."
    echo ""
    echo -e "  ${YLW}What happens when you upgrade to kernel 6.19+:${NC}"
    note "1. asus-armoury module loads and creates the firmware-attributes path."
    note "2. asus-performance-setup.sh detects it and switches automatically."
    note "3. You should see '[OK] PPT interface: asus-armoury firmware-attributes'"
    note "   in the journal instead of the legacy path."
    note "4. The dmesg deprecation notice will stop appearing."
    note "5. throttle_thermal_policy stays at the same platform path — no change."
    echo ""
    echo -e "  ${GRN}Required action AFTER kernel upgrade:${NC}"
    note "   NONE — the transition is fully automatic."
    echo ""
    echo -e "  ${YLW}Recommended verification AFTER kernel upgrade:${NC}"
    note "   sudo ./asus-kernel-check.sh           # run this script again"
    note "   journalctl -u asus-performance.service --no-pager -n 30"
else
    warn "No PPT interface found — setup is NOT fully functional."
    note "Install the project first: sudo ./install.sh"
    note "Then run this check again."
fi

# =============================================================================
# SECTION 9: Quick reference for current kernel's monitoring commands
# =============================================================================
hdr "Monitoring Commands (for this kernel)"

if [[ "${PPT_MODE}" == "armoury" ]]; then
    echo "  # Read PPT values (asus-armoury path, kernel 6.19+ / CachyOS backport):"
    echo "  cat /sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl1_spl/current_value"
    echo "  cat /sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl2_sppt/current_value"
    echo "  cat /sys/class/firmware-attributes/asus-armoury/attributes/ppt_fppt/current_value"
elif [[ "${PPT_MODE}" == "legacy" ]]; then
    PLAT_DIR2="$(dirname "${PPT_PL1_PATH}")"
    echo "  # Read PPT values (legacy asus-nb-wmi path, kernel 6.18):"
    echo "  cat ${PLAT_DIR2}/ppt_pl1_spl"
    echo "  cat ${PLAT_DIR2}/ppt_pl2_sppt"
    echo "  cat ${PLAT_DIR2}/ppt_fppt"
fi

if [[ -n "${THROTTLE_PATH}" ]]; then
    echo ""
    echo "  # Read throttle_thermal_policy (same path on ALL kernels):"
    echo "  cat ${THROTTLE_PATH}   # must be 1 for overboost"
fi

echo ""
echo "  # Watch live log:"
echo "  journalctl -f -u asus-performance.service -u asus-performance-resume.service -u asus-performance-refresh.service"
echo ""
echo "  # ryzenadj SMU values:"
echo "  sudo ryzenadj --info | grep -E 'STAPM|PPT|THM'"

# =============================================================================
# SECTION 10: Optional re-apply
# =============================================================================
if "${DO_REAPPLY}"; then
    echo ""
    hdr "Re-applying Limits (--reapply)"

    SETUP_SCRIPT="/usr/local/bin/asus-performance-setup.sh"
    LOCAL_SETUP="$(dirname "${BASH_SOURCE[0]}")/asus-performance-setup.sh"

    if [[ -x "${SETUP_SCRIPT}" ]]; then
        info "Running: ${SETUP_SCRIPT}"
        "${SETUP_SCRIPT}"
    elif [[ -x "${LOCAL_SETUP}" ]]; then
        info "Running: ${LOCAL_SETUP}"
        "${LOCAL_SETUP}"
    else
        fail "Setup script not found at ${SETUP_SCRIPT} or ${LOCAL_SETUP}"
        note "Install first with: sudo ./install.sh"
    fi
fi

# =============================================================================
# Final summary
# =============================================================================
echo ""
echo -e "${BLU}${BOLD}━━ Summary ━━${NC}"
val "Kernel"        "${KVER}" ""
val "PPT interface" "${PPT_MODE}"  ""
[[ -n "${THROTTLE_PATH}" ]] && val "Throttle node" "found" "(${THROTTLE_PATH})" || val "Throttle node" "NOT FOUND" ""
echo ""

if [[ "${PPT_MODE}" != "none" && -n "${THROTTLE_PATH}" ]]; then
    ok "Setup appears healthy.  Run with --reapply to re-apply limits now."
else
    warn "Setup has issues.  Review the sections above."
fi
echo ""
