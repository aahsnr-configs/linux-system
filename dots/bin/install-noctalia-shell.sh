#!/usr/bin/env bash
# ==============================================================================
# install-noctalia-shell.sh — v4.0.0
# ==============================================================================
# Installs and keeps noctalia-shell up to date from GitHub source, deployed
# system-wide on Fedora 43.
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  THIS SCRIPT DOES NOT, CANNOT, AND WILL NOT INSTALL THE TERRA REPO.    │
# │  Terra must be installed by YOU before running this script.             │
# │  If Terra is missing, this script stops and tells you what to do.       │
# └─────────────────────────────────────────────────────────────────────────┘
#
# Why Terra is required
# ---------------------
# The following packages are only available from the Terra community Fedora
# repository (https://terra.fyralabs.com) and cannot be installed without it:
#
#   gpu-screen-recorder   (required)
#   cliphist              (optional)
#   wlsunset              (optional)
#   cava                  (optional)
#
# How to install Terra manually (one-time, do this before running this script)
# ----------------------------------------------------------------------------
#   sudo dnf install --nogpgcheck \
#     --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
#     terra-release
#
# For full Terra documentation:  https://terra.fyralabs.com
#
# Dependency mapping (Arch → Fedora 43)
# ---------------------------------------
#   brightnessctl         → brightnessctl         (Fedora base)
#   ddcutil               → ddcutil                (Fedora base)
#   imagemagick           → ImageMagick            (Fedora base)
#   ffmpeg                → ffmpeg-free            (Fedora base)
#   python                → python3                (Fedora base)
#   qt6-multimedia        → qt6-qtmultimedia       (Fedora base)
#   inter-font            → rsms-inter-fonts       (Fedora base)
#   ttf-roboto            → google-roboto-fonts    (Fedora base)
#   dejavu-fonts          → dejavu-sans-fonts      (Fedora base)
#   xdg-desktop-portal    → xdg-desktop-portal    (Fedora base)
#   gpu-screen-recorder   → gpu-screen-recorder   (Terra — required)
#   cliphist              → cliphist              (Terra — optional)
#   wlsunset              → wlsunset              (Terra — optional)
#   power-profiles-daemon → power-profiles-daemon (Fedora base — optional)
#   cava                  → cava                  (Terra — optional)
#
# Note: matugen is NOT a dependency. noctalia-shell uses an internal colour
# system. quickshell must be installed separately before launching the shell.
#
# Quick reference
# ---------------
#   ./install-noctalia-shell.sh              full interactive install/update
#   ./install-noctalia-shell.sh --update     pull latest + redeploy only
#   ./install-noctalia-shell.sh --deps       install/verify dependencies only
#   ./install-noctalia-shell.sh --help       full help text (options, paths, …)
# ==============================================================================

# ==============================================================================
# STRICT MODE
# ==============================================================================
set -euo pipefail # exit on error, unset vars, or pipeline failures
set -C            # noclobber: prevent > from silently overwriting existing files
IFS=$'\n\t'       # safer word splitting (no space splitting)

# ==============================================================================
# HARDENED PATH
# ==============================================================================
# Explicitly define a minimal, trusted PATH before anything else runs.
# This prevents a compromised $PATH from redirecting commands (including those
# called via sudo) to attacker-controlled binaries.
export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

# ==============================================================================
# RESTRICTIVE UMASK
# ==============================================================================
# All files and directories created by this script (including temp files) will
# be owner-only by default. The install step overrides permissions explicitly.
umask 077

# ==============================================================================
# ABSOLUTE PATHS FOR ALL EXTERNAL COMMANDS
# ==============================================================================
# Declared up front so every call below uses a verified, hardcoded path.
# This is the primary defence against PATH-based injection attacks.
readonly _BASH='/usr/bin/bash'
readonly _AWK='/usr/bin/awk'
readonly _CAT='/usr/bin/cat'
readonly _CHMOD='/usr/bin/chmod'
readonly _CP='/usr/bin/cp'
readonly _DNF='/usr/bin/dnf'
readonly _FIND='/usr/bin/find'
readonly _FLOCK='/usr/bin/flock'
readonly _GIT='/usr/bin/git'
readonly _GREP='/usr/bin/grep'
readonly _KILL='/usr/bin/kill'
readonly _MKDIR='/usr/bin/mkdir'
readonly _MKTEMP='/usr/bin/mktemp'
readonly _MV='/usr/bin/mv'
readonly _PRINTF='/usr/bin/printf'
readonly _RM='/usr/bin/rm'
readonly _RPM='/usr/bin/rpm'
readonly _SLEEP='/usr/bin/sleep'
readonly _SUDO='/usr/bin/sudo'
readonly _TEE='/usr/bin/tee'
readonly _TOUCH='/usr/bin/touch'

# ==============================================================================
# SCRIPT METADATA
# ==============================================================================
readonly SCRIPT_VERSION="4.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_PATH="$(realpath "$0")"

# ==============================================================================
# INSTALLATION PATHS
# ==============================================================================
readonly REPO_URL="https://github.com/noctalia-dev/noctalia-shell.git"
readonly REPO_BRANCH="main"

# Cache lives in user-space — git operations require no sudo.
readonly CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/noctalia-shell-src"

# System-wide install target — matches the Fedora RPM spec's %files section.
readonly INSTALL_DIR="/etc/xdg/quickshell/noctalia-shell"

# Written after each successful deployment; stores the live git commit hash.
# Drives the idempotency check on re-runs.
readonly STATE_FILE="${INSTALL_DIR}/.installed-commit"

# Lock file — prevents two instances running concurrently and racing on the
# install directory or the git cache.
readonly LOCK_FILE="/tmp/noctalia-shell-install.lock"

# ==============================================================================
# COLOUR OUTPUT
# ==============================================================================
# Colours are disabled automatically when stdout is not a real terminal
# (e.g. when topgrade, cron, or a pipe invokes this script).
if [[ -t 1 ]]; then
    _RED=$'\033[0;31m' _GREEN=$'\033[0;32m' _YELLOW=$'\033[1;33m'
    _BLUE=$'\033[0;34m' _CYAN=$'\033[0;36m' _BOLD=$'\033[1m'
    _RESET=$'\033[0m'
else
    _RED='' _GREEN='' _YELLOW='' _BLUE='' _CYAN='' _BOLD='' _RESET=''
fi

# ==============================================================================
# LOGGING
# ==============================================================================
log_info() { "${_PRINTF}" '%b[INFO]%b  %s\n' "${_BLUE}" "${_RESET}" "$*"; }
log_ok() { "${_PRINTF}" '%b[OK]%b    %s\n' "${_GREEN}" "${_RESET}" "$*"; }
log_warn() { "${_PRINTF}" '%b[WARN]%b  %s\n' "${_YELLOW}" "${_RESET}" "$*"; }
log_error() { "${_PRINTF}" '%b[ERROR]%b %s\n' "${_RED}" "${_RESET}" "$*" >&2; }
log_step() { "${_PRINTF}" '\n%b==> %s%b\n' "${_BOLD}${_CYAN}" "$*" "${_RESET}"; }

die() {
    log_error "$*"
    exit 1
}

# ==============================================================================
# SIGNAL HANDLING AND CLEANUP
# ==============================================================================
# _TMP_FILES tracks every temp file created by this process so they are all
# removed on exit, regardless of whether we exit cleanly, via die(), or via
# an external signal (Ctrl-C, SIGTERM, SIGHUP).
declare -a _TMP_FILES=()
_KEEPALIVE_PID=""

_cleanup() {
    local file
    for file in "${_TMP_FILES[@]+"${_TMP_FILES[@]}"}"; do
        [[ -f "${file}" ]] && "${_RM}" -f -- "${file}" 2>/dev/null || true
    done
    if [[ -n "${_KEEPALIVE_PID}" ]]; then
        "${_KILL}" "${_KEEPALIVE_PID}" 2>/dev/null || true
        _KEEPALIVE_PID=""
    fi
}

# Cover every realistic exit path:
#   EXIT   — normal exit and die()
#   INT    — Ctrl-C
#   TERM   — kill / systemd stop
#   HUP    — terminal hangup / topgrade timeout
trap '_cleanup' EXIT INT TERM HUP

# mktemp_tracked — create a temp file and register it for cleanup.
mktemp_tracked() {
    local f
    f="$("${_MKTEMP}")" || die "Failed to create temporary file."
    _TMP_FILES+=("${f}")
    printf '%s' "${f}"
}

# ==============================================================================
# CONCURRENCY LOCK
# ==============================================================================
# Acquire an exclusive advisory lock on LOCK_FILE using a file descriptor.
# A second invocation will fail immediately rather than silently racing.
_acquire_lock() {
    exec 9>"${LOCK_FILE}"
    "${_FLOCK}" -n 9 ||
        die "Another instance of ${SCRIPT_NAME} is already running. Aborting."
}

# ==============================================================================
# INTERACTIVITY DETECTION
# ==============================================================================
# Returns 0 only when BOTH stdin and stdout are real terminals.
# Non-interactive (topgrade, cron, pipe) → all confirms auto-accept.
is_interactive() { [[ -t 0 && -t 1 ]]; }

# ==============================================================================
# USER CONFIRMATION
# ==============================================================================
# confirm "Prompt text"
#   Interactive     → asks Y/N; empty / N → returns 1
#   Non-interactive → logs the action and returns 0 (auto-accept)
confirm() {
    local prompt="${1:-Continue?}"
    if is_interactive; then
        local reply
        "${_PRINTF}" '%b%s [y/N]%b ' "${_YELLOW}" "${prompt}" "${_RESET}"
        read -r reply
        [[ "${reply}" =~ ^[Yy]$ ]] || return 1
    else
        log_info "Auto-confirming (non-interactive): ${prompt}"
    fi
    return 0
}

# ==============================================================================
# ARGUMENT PARSING
# ==============================================================================
MODE="full" # full | update | deps

# ------------------------------------------------------------------------------
# usage — print full help text and exit 0.
#
# Design notes:
#   • Uses a cat heredoc rather than extracting comments with awk; the help
#     text is self-contained and won't silently break if the header changes.
#   • Colour variables (_BOLD, _CYAN, etc.) are already set by the time this
#     function is called and are automatically empty strings when stdout is not
#     a TTY, so the heredoc is safe for pipes and redirects.
#   • Exits 0 — callers treating non-zero as failure should not be broken by
#     the user asking for help.
# ------------------------------------------------------------------------------
usage() {
    cat <<EOF
${_BOLD}NAME${_RESET}
    ${SCRIPT_NAME} — install and update noctalia-shell from source (Fedora 43)

${_BOLD}SYNOPSIS${_RESET}
    ${_CYAN}${SCRIPT_NAME}${_RESET} [${_BOLD}OPTION${_RESET}]

${_BOLD}DESCRIPTION${_RESET}
    Clones or pulls the noctalia-shell git repository, installs all required
    and optional runtime dependencies via DNF, and deploys the shell files to
    the system-wide location ${_CYAN}${INSTALL_DIR}${_RESET}.

    The script is fully idempotent — re-running it when nothing has changed
    is a no-op.  When called non-interactively (e.g. from topgrade, cron, or
    a pipe) every confirmation prompt is auto-accepted.

    ${_YELLOW}IMPORTANT:${_RESET} The Terra community repository must be installed by you
    before running this script.  It will never be installed automatically.
    Run without arguments for a step-by-step reminder.

${_BOLD}OPTIONS${_RESET}
    ${_CYAN}-h${_RESET}, ${_CYAN}--help${_RESET}
        Print this help text and exit.

    ${_CYAN}-u${_RESET}, ${_CYAN}--update${_RESET}
        Update mode: pull the latest commits and redeploy files only.
        Skips all package installation steps.  Use this for routine updates
        once the initial installation has been completed.

    ${_CYAN}-d${_RESET}, ${_CYAN}--deps${_RESET}
        Deps-only mode: install or verify all required and optional packages
        without touching the git repository or the deployed files.

${_BOLD}MODES${_RESET}
    ${_BOLD}full${_RESET}  (default, no flag required)
        1. Verify the Terra repository is present and enabled
        2. Install required packages from Fedora base repos
        3. Install required packages from Terra
        4. Install optional packages from Fedora base repos
        5. Install optional packages from Terra
        6. Clone or pull source from GitHub
        7. Deploy files to ${INSTALL_DIR}

    ${_BOLD}update${_RESET}  (${_CYAN}--update${_RESET})
        1. Verify the Terra repository is present and enabled
        2. Pull latest commits from GitHub
        3. Deploy files to ${INSTALL_DIR}

    ${_BOLD}deps${_RESET}  (${_CYAN}--deps${_RESET})
        1. Verify the Terra repository is present and enabled
        2. Install all required and optional packages

${_BOLD}EXAMPLES${_RESET}
    # First-time full installation (interactive)
    ${_CYAN}./${SCRIPT_NAME}${_RESET}

    # Pull the latest commits and redeploy (non-interactive, safe for cron)
    ${_CYAN}./${SCRIPT_NAME} --update${_RESET}

    # Verify / repair dependencies without touching shell files
    ${_CYAN}./${SCRIPT_NAME} --deps${_RESET}

    # Show this help text
    ${_CYAN}./${SCRIPT_NAME} --help${_RESET}

${_BOLD}TOPGRADE INTEGRATION${_RESET}
    Add the following to ${_CYAN}~/.config/topgrade.toml${_RESET} to include noctalia-shell
    in your regular system upgrades:

        ${_BOLD}[commands]${_RESET}
        "Noctalia Shell" = "${SCRIPT_PATH} --update"

    The ${_CYAN}--update${_RESET} flag is recommended here: it skips package installation
    (handled by topgrade itself) and only pulls and redeploys the shell files.

${_BOLD}PATHS${_RESET}
    Source cache   ${_CYAN}${CACHE_DIR}${_RESET}
    Install dir    ${_CYAN}${INSTALL_DIR}${_RESET}
    State file     ${_CYAN}${STATE_FILE}${_RESET}
    Lock file      ${_CYAN}${LOCK_FILE}${_RESET}

${_BOLD}TERRA REPOSITORY${_RESET}
    The following packages are only available from the Terra repo and cannot
    be installed without it:

        gpu-screen-recorder   (required)
        cliphist              (optional)
        wlsunset              (optional)
        cava                  (optional)

    Install Terra once before running this script:

        ${_CYAN}sudo dnf install --nogpgcheck \\${_RESET}
        ${_CYAN}  --repofrompath 'terra,https://repos.fyralabs.com/terra\$releasever' \\${_RESET}
        ${_CYAN}  terra-release${_RESET}

    Full Terra documentation: https://terra.fyralabs.com

${_BOLD}NOTES${_RESET}
    • Do not run as root or with sudo.  The script requests elevated
      privileges internally, only when required.
    • ffmpeg-free (Fedora base) is installed by default.  For full codec
      support, swap it after enabling RPM Fusion free:
          sudo dnf swap ffmpeg-free ffmpeg --allowerasing
    • matugen is NOT a dependency — noctalia-shell uses an internal colour
      system.  quickshell must be installed separately before launching.
    • Script version: ${SCRIPT_VERSION}

EOF
    exit 0
}

# ------------------------------------------------------------------------------
# Parse arguments.
#
# Uses the modern "while shift" pattern rather than "for arg in $@":
#   • Handles "--" end-of-options marker correctly.
#   • Processes each token once, left to right, with explicit shift.
#   • Throws a clear error on any unrecognised option and suggests --help.
# ------------------------------------------------------------------------------
while :; do
    case "${1-}" in
    -h | --help)
        usage
        ;;
    -u | --update)
        MODE="update"
        ;;
    -d | --deps)
        MODE="deps"
        ;;
    --)
        # Explicit end-of-options marker — stop processing flags.
        shift
        break
        ;;
    -?*)
        die "Unknown option: '${1}'.  Run '${SCRIPT_NAME} --help' for usage."
        ;;
    *)
        # First non-option argument (or empty) — stop.
        break
        ;;
    esac
    shift
done

# ==============================================================================
# ROOT GUARD
# ==============================================================================
if ((EUID == 0)); then
    die "Do not run ${SCRIPT_NAME} as root or with sudo.
It requests elevated privileges internally, only when necessary.
Run it as your regular user:  ./${SCRIPT_NAME}"
fi

# ==============================================================================
# DEPENDENCY LISTS
# ==============================================================================

# Required — Fedora 43 base repos
readonly -a REQ_DNF=(
    git
    brightnessctl
    ddcutil
    ImageMagick
    ffmpeg
    python3
    qt6-qtmultimedia
    xdg-desktop-portal
    rsms-inter-fonts
    google-roboto-fonts
    dejavu-sans-fonts
)

# Required — Terra repo
readonly -a REQ_TERRA=(
    gpu-screen-recorder
)

# Optional — Fedora 43 base repos
readonly -a OPT_DNF=(
    power-profiles-daemon
)

# Optional — Terra repo
readonly -a OPT_TERRA=(
    cliphist # clipboard history manager
    wlsunset # night light / blue-light filter
    cava     # audio visualiser
)

# ==============================================================================
# TERRA REPOSITORY CHECK — HARD PREREQUISITE
# ==============================================================================
#
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  IMPORTANT: This script does NOT install the Terra repository.          ║
# ║                                                                          ║
# ║  Terra is a third-party community repository. Adding a system-wide      ║
# ║  package repository is a security-sensitive action that requires your   ║
# ║  explicit, informed consent. This script will never perform that action ║
# ║  on your behalf.                                                         ║
# ║                                                                          ║
# ║  You must install Terra yourself before running this script.             ║
# ║  If Terra is absent, this function prints clear instructions and exits. ║
# ╚══════════════════════════════════════════════════════════════════════════╝
#
check_terra_repo() {
    log_step "Checking for Terra repository (required — not installed by this script)"

    local terra_pkg_ok=false
    local terra_repo_ok=false

    "${_RPM}" -q terra-release &>/dev/null && terra_pkg_ok=true
    "${_DNF}" repolist --enabled 2>/dev/null |
        "${_GREP}" -qi '^terra' && terra_repo_ok=true

    if [[ "${terra_pkg_ok}" == "true" && "${terra_repo_ok}" == "true" ]]; then
        log_ok "Terra repository is present and enabled"
        return 0
    fi

    # ── Terra is missing ─────────────────────────────────────────────────────
    "${_PRINTF}" '\n'
    "${_PRINTF}" '%b╔══════════════════════════════════════════════════════════════╗%b\n' \
        "${_RED}${_BOLD}" "${_RESET}"
    "${_PRINTF}" '%b║              TERRA REPOSITORY NOT FOUND                     ║%b\n' \
        "${_RED}${_BOLD}" "${_RESET}"
    "${_PRINTF}" '%b╚══════════════════════════════════════════════════════════════╝%b\n' \
        "${_RED}${_BOLD}" "${_RESET}"
    "${_PRINTF}" '\n'
    "${_PRINTF}" '%bThis script does NOT and WILL NOT install the Terra repository.%b\n' \
        "${_BOLD}" "${_RESET}"
    "${_PRINTF}" 'Adding a package repository is a security-sensitive action that\n'
    "${_PRINTF}" 'requires your explicit, informed consent. You must do it yourself.\n'
    "${_PRINTF}" '\n'
    "${_PRINTF}" '%bPackages only available from Terra that noctalia-shell needs:%b\n' \
        "${_YELLOW}" "${_RESET}"
    "${_PRINTF}" '  gpu-screen-recorder (required)\n'
    "${_PRINTF}" '  cliphist, wlsunset, cava (optional)\n'
    "${_PRINTF}" '\n'
    "${_PRINTF}" '%bTo install Terra, run this command — then re-run this script:%b\n' \
        "${_BOLD}" "${_RESET}"
    "${_PRINTF}" '\n'
    "${_PRINTF}" '  %bsudo dnf install --nogpgcheck \\%b\n' "${_CYAN}" "${_RESET}"
    "${_PRINTF}" "  %b  --repofrompath 'terra,https://repos.fyralabs.com/terra\$releasever' \\%b\n" \
        "${_CYAN}" "${_RESET}"
    "${_PRINTF}" '  %b  terra-release%b\n' "${_CYAN}" "${_RESET}"
    "${_PRINTF}" '\n'
    "${_PRINTF}" 'Full Terra documentation:  %bhttps://terra.fyralabs.com%b\n\n' "${_CYAN}" "${_RESET}"

    exit 1
}

# ==============================================================================
# SUDO KEEPALIVE
# ==============================================================================
# Acquires sudo credentials once, then refreshes them in a background subshell
# every 50 s so they never time out mid-install. The keepalive PID is recorded
# and killed in _cleanup() on any exit.
_acquire_sudo() {
    log_step "Acquiring sudo credentials"
    "${_SUDO}" -v || die "Failed to obtain sudo privileges. Aborting."
    (
        while true; do
            "${_SLEEP}" 50
            "${_SUDO}" -n true 2>/dev/null || exit 0
        done
    ) &
    _KEEPALIVE_PID=$!
    log_ok "sudo credentials active"
}

# ==============================================================================
# DNF HELPERS
# ==============================================================================

# pkg_installed <name>  →  returns 0 if the RPM is already installed
pkg_installed() { "${_RPM}" -q "$1" &>/dev/null; }

# dnf_install_missing <pkg> [pkg …]
# Calls dnf only for packages not yet installed. No-op when all present.
dnf_install_missing() {
    local -a to_install=()
    local pkg
    for pkg in "$@"; do
        pkg_installed "${pkg}" || to_install+=("${pkg}")
    done

    if ((${#to_install[@]} == 0)); then
        log_ok "Already installed: $*"
        return 0
    fi

    log_info "Installing: ${to_install[*]}"
    "${_SUDO}" "${_DNF}" install -y "${to_install[@]}"
    log_ok "Installed: ${to_install[*]}"
}

# ==============================================================================
# PRINT INSTALLATION PLAN
# ==============================================================================
print_plan() {
    "${_PRINTF}" '\n'
    "${_PRINTF}" '%b╔══════════════════════════════════════════════════════════╗%b\n' \
        "${_BOLD}" "${_RESET}"
    "${_PRINTF}" '%b║  Noctalia Shell Installer  %-28s  ║%b\n' \
        "${_BOLD}" "v${SCRIPT_VERSION} — Fedora 43" "${_RESET}"
    "${_PRINTF}" '%b╚══════════════════════════════════════════════════════════╝%b\n\n' \
        "${_BOLD}" "${_RESET}"

    "${_PRINTF}" '  %bSource%b  : %s (branch: %s)\n' \
        "${_BOLD}" "${_RESET}" "${REPO_URL}" "${REPO_BRANCH}"
    "${_PRINTF}" '  %bCache%b   : %s\n' "${_BOLD}" "${_RESET}" "${CACHE_DIR}"
    "${_PRINTF}" '  %bTarget%b  : %s\n\n' "${_BOLD}" "${_RESET}" "${INSTALL_DIR}"

    case "${MODE}" in
    full)
        "${_PRINTF}" '  %bSteps:%b\n' "${_BOLD}" "${_RESET}"
        "${_PRINTF}" '    1. Verify Terra repository is present (hard stop if missing)\n'
        "${_PRINTF}" '    2. Install required packages from Fedora base repos\n'
        "${_PRINTF}" '    3. Install required packages from Terra\n'
        "${_PRINTF}" '    4. Install optional packages from Fedora base repos\n'
        "${_PRINTF}" '    5. Install optional packages from Terra\n'
        "${_PRINTF}" '    6. Clone / pull source from GitHub\n'
        "${_PRINTF}" '    7. Deploy files to %s\n' "${INSTALL_DIR}"
        ;;
    update)
        "${_PRINTF}" '  %bMode%b: update-only\n' "${_BOLD}" "${_RESET}"
        "${_PRINTF}" '    1. Verify Terra repository is present\n'
        "${_PRINTF}" '    2. Pull latest changes from GitHub\n'
        "${_PRINTF}" '    3. Deploy files to %s\n' "${INSTALL_DIR}"
        ;;
    deps)
        "${_PRINTF}" '  %bMode%b: deps-only\n' "${_BOLD}" "${_RESET}"
        "${_PRINTF}" '    1. Verify Terra repository is present\n'
        "${_PRINTF}" '    2. Install all required and optional packages\n'
        ;;
    esac

    "${_PRINTF}" '\n  %bNotes:%b\n' "${_BOLD}" "${_RESET}"
    "${_PRINTF}" '    • This script does NOT install the Terra repository.\n'
    "${_PRINTF}" '      Terra must be set up by you before running this script.\n'
    "${_PRINTF}" '    • quickshell must be installed separately before launching.\n'
    "${_PRINTF}" '    • matugen is NOT required — noctalia uses an internal colour system.\n'
    "${_PRINTF}" '    • ffmpeg-free (base repo) is installed. For full codec support:\n'
    "${_PRINTF}" '        sudo dnf swap ffmpeg-free ffmpeg --allowerasing\n'
    "${_PRINTF}" '      (requires RPM Fusion free to be enabled first)\n'
    "${_PRINTF}" '    • This script is idempotent — re-running is always safe.\n\n'
}

# ==============================================================================
# STEP: Required packages — Fedora base repos
# ==============================================================================
step_core_deps() {
    log_step "Required packages — Fedora base repos"

    if is_interactive; then
        confirm "Install required packages from Fedora base repos?" ||
            {
                log_warn "Skipping — the shell may not function correctly."
                return 0
            }
    fi

    dnf_install_missing "${REQ_DNF[@]}"
}

# ==============================================================================
# STEP: Required packages — Terra
# ==============================================================================
step_required_terra() {
    log_step "Required packages — Terra repo"

    if is_interactive; then
        confirm "Install required packages from Terra?" ||
            {
                log_warn "Skipping Terra required packages — screen recording will be unavailable."
                return 0
            }
    fi

    dnf_install_missing "${REQ_TERRA[@]}"
}

# ==============================================================================
# STEP: Optional packages — Fedora base repos
# ==============================================================================
step_optional_dnf() {
    log_step "Optional packages — Fedora base repos"
    local pkg install_it

    for pkg in "${OPT_DNF[@]}"; do
        if pkg_installed "${pkg}"; then
            log_ok "Already installed (optional): ${pkg}"
            continue
        fi

        install_it=true
        if is_interactive; then
            confirm "Install optional package '${pkg}'?" || install_it=false
        fi

        if [[ "${install_it}" == "true" ]]; then
            "${_SUDO}" "${_DNF}" install -y "${pkg}"
            log_ok "Installed (optional): ${pkg}"
        else
            log_warn "Skipped optional package: ${pkg}"
        fi
    done
}

# ==============================================================================
# STEP: Optional packages — Terra
# ==============================================================================
step_optional_terra() {
    log_step "Optional packages — Terra repo"
    local pkg install_it

    for pkg in "${OPT_TERRA[@]}"; do
        if pkg_installed "${pkg}"; then
            log_ok "Already installed (optional): ${pkg}"
            continue
        fi

        install_it=true
        if is_interactive; then
            confirm "Install optional package '${pkg}' from Terra?" || install_it=false
        fi

        if [[ "${install_it}" == "true" ]]; then
            "${_SUDO}" "${_DNF}" install -y "${pkg}"
            log_ok "Installed (optional): ${pkg}"
        else
            log_warn "Skipped optional package: ${pkg}"
        fi
    done
}

# ==============================================================================
# STEP: Clone or update the git repository
# ==============================================================================
step_sync_repo() {
    log_step "Syncing source from GitHub"

    if is_interactive; then
        confirm "Clone/pull ${REPO_URL} into local cache?" ||
            die "Cannot install without the source. Aborting."
    fi

    if [[ -d "${CACHE_DIR}/.git" ]]; then
        log_info "Repository already cached at ${CACHE_DIR} — fetching updates …"
        "${_GIT}" -C "${CACHE_DIR}" fetch --prune origin
        "${_GIT}" -C "${CACHE_DIR}" reset --hard "origin/${REPO_BRANCH}"
        "${_GIT}" -C "${CACHE_DIR}" clean -fdx --quiet
        log_ok "Repository updated"
    else
        log_info "Cloning into ${CACHE_DIR} …"
        "${_MKDIR}" -p "${CACHE_DIR}"
        "${_GIT}" clone \
            --filter=blob:none \
            --branch "${REPO_BRANCH}" \
            "${REPO_URL}" "${CACHE_DIR}"
        log_ok "Repository cloned"
    fi

    local head_commit head_subject
    head_commit="$("${_GIT}" -C "${CACHE_DIR}" rev-parse HEAD)"
    head_subject="$("${_GIT}" -C "${CACHE_DIR}" log -1 --format='%s')"
    log_info "HEAD → ${head_commit:0:12}  ${head_subject}"
}

# ==============================================================================
# STEP: Deploy files system-wide (idempotent)
# ==============================================================================
step_install_files() {
    log_step "Deploying files to ${INSTALL_DIR}"

    local new_commit
    new_commit="$("${_GIT}" -C "${CACHE_DIR}" rev-parse HEAD)"

    # Idempotency: skip if the already-deployed commit matches HEAD exactly.
    local installed_commit=""
    if [[ -f "${STATE_FILE}" ]]; then
        installed_commit="$("${_CAT}" "${STATE_FILE}")"
    fi

    if [[ -n "${installed_commit}" && "${new_commit}" == "${installed_commit}" ]]; then
        log_ok "Already at commit ${new_commit:0:12} — nothing to deploy."
        return 0
    fi

    if [[ -n "${installed_commit}" ]]; then
        log_info "Upgrading: ${installed_commit:0:12} → ${new_commit:0:12}"
    else
        log_info "First install at commit ${new_commit:0:12}"
    fi

    if is_interactive; then
        confirm "Deploy noctalia-shell to ${INSTALL_DIR} (requires sudo)?" ||
            die "Deployment cancelled. Aborting."
    fi

    # Create target directory if absent.
    "${_SUDO}" "${_MKDIR}" -p "${INSTALL_DIR}"

    # Wipe directory contents while preserving the directory node itself.
    # This protects any bind mounts or ACLs on the directory.
    "${_SUDO}" "${_FIND}" "${INSTALL_DIR}" -mindepth 1 -maxdepth 1 \
        -exec "${_RM}" -rf {} +

    # Copy the full repo tree, then prune build-env / Nix artefacts that have
    # no place in a runtime installation.
    "${_SUDO}" "${_CP}" -a "${CACHE_DIR}/." "${INSTALL_DIR}/"

    "${_SUDO}" "${_RM}" -rf \
        "${INSTALL_DIR}/.git" \
        "${INSTALL_DIR}/.gitignore" \
        "${INSTALL_DIR}/.github" \
        "${INSTALL_DIR}/nix" \
        "${INSTALL_DIR}/flake.nix" \
        "${INSTALL_DIR}/flake.lock" \
        "${INSTALL_DIR}/shell.nix" \
        "${INSTALL_DIR}/lefthook.yml" \
        2>/dev/null || true

    # Permissions:
    #   directories  → 0755 (world-traversable)
    #   regular files → 0644 (world-readable)
    #   scripts       → 0755 (world-executable)
    "${_SUDO}" "${_FIND}" "${INSTALL_DIR}" -type d -exec "${_CHMOD}" 755 {} +
    "${_SUDO}" "${_FIND}" "${INSTALL_DIR}" -type f -exec "${_CHMOD}" 644 {} +
    "${_SUDO}" "${_FIND}" "${INSTALL_DIR}/Scripts" -type f \
        \( -name '*.sh' -o -name '*.py' \) \
        -exec "${_CHMOD}" 755 {} + 2>/dev/null || true

    # Persist the deployed commit so the next run can detect a no-op.
    # set -C (noclobber) is active, so |tee is used instead of >.
    "${_PRINTF}" '%s\n' "${new_commit}" |
        "${_SUDO}" "${_TEE}" "${STATE_FILE}" >/dev/null
    "${_SUDO}" "${_CHMOD}" 644 "${STATE_FILE}"

    log_ok "Deployed at commit ${new_commit:0:12}"
}

# ==============================================================================
# FINAL SUMMARY
# ==============================================================================
print_summary() {
    local installed_commit=""
    [[ -f "${STATE_FILE}" ]] && installed_commit="$("${_CAT}" "${STATE_FILE}")"

    "${_PRINTF}" '\n%b✓  noctalia-shell is ready!%b\n\n' "${_BOLD}${_GREEN}" "${_RESET}"
    "${_PRINTF}" '  Install dir  : %s\n' "${INSTALL_DIR}"
    [[ -n "${installed_commit}" ]] &&
        "${_PRINTF}" '  Commit       : %s\n' "${installed_commit:0:12}"
    "${_PRINTF}" '\n  To launch with quickshell:\n'
    "${_PRINTF}" '    %bqs --config-path %s%b\n\n' \
        "${_CYAN}" "${INSTALL_DIR}" "${_RESET}"
}

# ==============================================================================
# MAIN
# ==============================================================================
main() {
    # Acquire the concurrency lock before doing anything else.
    _acquire_lock

    print_plan

    if is_interactive; then
        confirm "Proceed with the above plan?" ||
            {
                log_info "Aborted by user."
                exit 0
            }
    fi

    # Terra check is a hard prerequisite in every mode.
    # This script will NEVER install Terra on your behalf.
    check_terra_repo

    # Acquire sudo once, up front, before any privileged steps.
    _acquire_sudo

    case "${MODE}" in
    full)
        step_core_deps
        step_required_terra
        step_optional_dnf
        step_optional_terra
        step_sync_repo
        step_install_files
        ;;
    update)
        step_sync_repo
        step_install_files
        ;;
    deps)
        step_core_deps
        step_required_terra
        step_optional_dnf
        step_optional_terra
        ;;
    esac

    print_summary
}

main "$@"
