#!/usr/bin/env bash
# =============================================================================
# build-noctalia-qs.sh — v4.0.0
# =============================================================================
# Build and install noctalia-qs (Noctalia's Quickshell fork) from source,
# system-wide, on Fedora 43 — faithfully replicating what the PKGBUILD does.
#
# KEY DESIGN RULES:
#   • Installs to /usr  (same as Arch PKGBUILD — system-wide for all users)
#   • Script invokes sudo internally — do NOT run as: sudo ./build-noctalia-qs.sh
#   • Topgrade-compatible via --non-interactive flag
#   • Idempotent: skips rebuild when already at latest upstream commit
#   • Fully hardened: absolute paths, locked PATH, noclobber, flock, umask
#
# QUICK REFERENCE:
#   ./build-noctalia-qs.sh                    interactive full build
#   ./build-noctalia-qs.sh --non-interactive  for topgrade / cron
#   ./build-noctalia-qs.sh --force            force rebuild even if up-to-date
#   ./build-noctalia-qs.sh --help             full help text
#
# TOPGRADE INTEGRATION — add to ~/.config/topgrade.toml:
#   [misc]
#   pre_sudo = true
#
#   [commands]
#   "noctalia-qs" = "/path/to/build-noctalia-qs.sh --non-interactive"
# =============================================================================

# =============================================================================
# STRICT MODE
# =============================================================================
set -euo pipefail  # exit on error, unset vars, or pipeline failures
set -C             # noclobber: prevent > from silently overwriting existing files
IFS=$'\n\t'        # safer word splitting — no accidental splitting on spaces

# =============================================================================
# HARDENED PATH
# =============================================================================
# Lock PATH to a minimal, trusted set of system directories before anything
# else runs. This prevents a compromised $PATH from redirecting commands
# (including those run via sudo) to attacker-controlled binaries.
export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

# =============================================================================
# RESTRICTIVE UMASK
# =============================================================================
# Every file and directory created by this script (state file, log file, temp
# files) will be owner-only by default. Install steps override permissions
# explicitly where world-readable access is intentional.
umask 077

# =============================================================================
# ABSOLUTE PATHS FOR ALL EXTERNAL COMMANDS
# =============================================================================
# Declared up front and used exclusively throughout. Together with the locked
# PATH above, this is the primary defence against PATH-injection attacks: even
# if an attacker inserts a directory early in a user's PATH, our calls to
# known-good system binaries cannot be redirected.
readonly _AWK='/usr/bin/awk'
readonly _BASENAME='/usr/bin/basename'
readonly _CAT='/usr/bin/cat'
readonly _CMAKE='/usr/bin/cmake'
readonly _CUT='/usr/bin/cut'
readonly _DATE='/usr/bin/date'
readonly _DNF='/usr/bin/dnf'
readonly _FLOCK='/usr/bin/flock'
readonly _GIT='/usr/bin/git'
readonly _GREP='/usr/bin/grep'
readonly _KILL='/usr/bin/kill'
readonly _MKDIR='/usr/bin/mkdir'
readonly _NPROC='/usr/bin/nproc'
readonly _PRINTF='/usr/bin/printf'
readonly _REALPATH='/usr/bin/realpath'
readonly _RM='/usr/bin/rm'
readonly _RPM='/usr/bin/rpm'
readonly _SLEEP='/usr/bin/sleep'
readonly _SUDO='/usr/bin/sudo'
readonly _TEE='/usr/bin/tee'
readonly _TR='/usr/bin/tr'

# =============================================================================
# SCRIPT METADATA
# =============================================================================
readonly SCRIPT_VERSION="4.0.0"
readonly SCRIPT_NAME="$("${_BASENAME}" "${BASH_SOURCE[0]}")"
readonly SCRIPT_ABS="$("${_REALPATH}" "${BASH_SOURCE[0]}")"

# =============================================================================
# INSTALLATION PATHS  (all readonly — prevents accidental mutation)
# =============================================================================
readonly REPO_URL="https://github.com/noctalia-dev/noctalia-qs"

# System-wide install prefix — mirrors the Arch PKGBUILD (also uses /usr).
readonly INSTALL_PREFIX="/usr"

# Build & source dirs live in the user's XDG cache. No root required for the
# build itself; only cmake --install needs root (writes to /usr).
readonly CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/noctalia-qs"
readonly SRC_DIR="${CACHE_DIR}/src"
readonly BUILD_DIR="${CACHE_DIR}/build"

# Persistent state dir: last-built commit hash and build log.
readonly STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/noctalia-qs"
readonly STATE_FILE="${STATE_DIR}/last_built_commit"
readonly LOG_FILE="${STATE_DIR}/build.log"

# Lock file — prevents two instances racing on the build/source directories
# or the sudo-privileged cmake --install step.
readonly LOCK_FILE="/tmp/noctalia-qs-build.lock"

# =============================================================================
# RUNTIME FLAGS
# =============================================================================
# Initialised here so every subsequent function can reference them safely
# under set -u, even before argument parsing runs.
NON_INTERACTIVE=false
FORCE_BUILD=false
CURRENT_COMMIT=""      # populated by fetch_source()
SUDO_KEEPALIVE_PID=""  # populated by setup_sudo(); killed by _cleanup()

# =============================================================================
# BUILD DEPENDENCY LIST
# =============================================================================
# Three kinds of entries are used here:
#
#   1. Plain package names — toolchain tools and header-only libs that ship
#      neither a .pc file nor a cmake config.
#      Checked:   rpm -q <n>
#      Installed: dnf install <n>
#
#   2. cmake(Name) virtual provides — Qt6 and other cmake-based libs.
#      This is the standard Fedora/RPM idiom (mirrors how spec files write
#      BuildRequires for cmake packages). dnf resolves cmake(Name) to
#      whichever -devel package currently provides that cmake config file,
#      keeping the script robust across Fedora release renames.
#      Checked:   rpm -q --whatprovides 'cmake(Name)'
#      Installed: dnf install 'cmake(Name)'
#
#   3. pkgconfig(name) virtual provides — C/C++ library deps that ship a
#      .pc file. dnf resolves them to whichever -devel package owns x.pc.
#      Checked:   rpm -q --whatprovides 'pkgconfig(name)'
#      Installed: dnf install 'pkgconfig(name)'
#
# OMITTED: qt6-qtwayland-private-devel — does not exist on Fedora. Private
#   Wayland headers are bundled inside qt6-qtwayland-devel. Fedora 43 ships
#   Qt 6.10.x which handles private header requirements automatically.
#
# OMITTED: glslang — not required by the quickshell/noctalia-qs build system;
#   the COPR spec does not list it and spirv-tools covers shader compilation.
#
# CRASH_REPORTER=OFF — google-breakpad is not packaged for Fedora.

readonly -a BUILD_DEPS=(
    # ── Toolchain (plain names — no cmake/pc file) ────────────────────────
    cmake
    ninja-build
    gcc-c++
    git

    # ── Qt6 — cmake() virtual provides ───────────────────────────────────
    'cmake(Qt6Core)'           # → qt6-qtbase-devel
    'cmake(Qt6Qml)'            # → qt6-qtdeclarative-devel
    'cmake(Qt6ShaderTools)'    # → qt6-qtshadertools-devel
    'cmake(Qt6WaylandClient)'  # → qt6-qtwayland-devel
    'cmake(Qt6Svg)'            # → qt6-qtsvg-devel

    # Private Qt headers — no cmake()/pkgconfig() virtual provides on Fedora.
    qt6-qtbase-private-devel
    qt6-qtdeclarative-private-devel

    # ── SPIR-V shader toolchain (build-time only) ─────────────────────────
    spirv-tools

    # ── Vulkan headers (header-only, required by Screencopy) ──────────────
    vulkan-headers

    # ── Library deps via pkgconfig() ──────────────────────────────────────
    'pkgconfig(CLI11)'              # → cli11-devel
    'pkgconfig(wayland-client)'     # → wayland-devel
    'pkgconfig(wayland-protocols)'  # → wayland-protocols-devel
    'pkgconfig(libdrm)'             # → libdrm-devel
    'pkgconfig(gbm)'                # → mesa-libgbm-devel
    'pkgconfig(libpipewire-0.3)'    # → pipewire-devel
    'pkgconfig(pam)'                # → pam-devel
    'pkgconfig(polkit-agent-1)'     # → polkit-devel
    'pkgconfig(glib-2.0)'           # → glib2-devel
    'pkgconfig(jemalloc)'           # → jemalloc-devel
    'pkgconfig(xcb)'                # → libxcb-devel
)

# =============================================================================
# COLOUR OUTPUT
# =============================================================================
# Colours are disabled automatically when stdout is not a real terminal
# (e.g. topgrade, cron, pipe), so help and log output are always clean.
if [[ -t 1 ]]; then
    BOLD=$'\033[1m'      RED=$'\033[0;31m'   GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m' BLUE=$'\033[0;34m'  CYAN=$'\033[0;36m'
    RESET=$'\033[0m'
else
    BOLD='' RED='' GREEN='' YELLOW='' BLUE='' CYAN='' RESET=''
fi

# =============================================================================
# LOGGING
# =============================================================================
# All logging uses printf, not echo -e. printf is POSIX-specified, portable,
# and never misinterprets backslash sequences in message text the way echo -e
# can on some platforms.
log_info()  { "${_PRINTF}" '%b[INFO]%b  %s\n' "${BLUE}"        "${RESET}" "$*";     }
log_ok()    { "${_PRINTF}" '%b[ OK ]%b  %s\n' "${GREEN}"       "${RESET}" "$*";     }
log_warn()  { "${_PRINTF}" '%b[WARN]%b  %s\n' "${YELLOW}"      "${RESET}" "$*";     }
log_error() { "${_PRINTF}" '%b[ERR ]%b  %s\n' "${RED}"         "${RESET}" "$*" >&2; }
log_step()  { "${_PRINTF}" '\n%b══> %s%b\n'   "${BOLD}${CYAN}" "$*" "${RESET}";     }
die()       { log_error "$*"; exit 1; }

# log_and_run <cmd> [args…]
#
# Run a command, echo it and tee both stdout and stderr to the build log.
# Returns the exit code of <cmd> itself, not of tee.
#
# Design notes:
#   • The if-compound makes the inner pipeline exempt from set -e, so a
#     failing command does not immediately abort the script — the caller
#     uses `|| die "…"` to provide a meaningful error message.
#   • PIPESTATUS is read inside the if/else immediately after the pipeline,
#     before any other command can overwrite it, yielding the true exit code
#     of <cmd> (PIPESTATUS[0]) separately from tee's exit code (PIPESTATUS[1]).
#   • set -C (noclobber) is active globally; tee uses -a (append mode) which
#     is unaffected by noclobber.
log_and_run() {
    "${_PRINTF}" '  + %s\n' "${*}" | "${_TEE}" -a "${LOG_FILE}" || true
    local _rc
    if "${@}" 2>&1 | "${_TEE}" -a "${LOG_FILE}"; then
        _rc=0
    else
        # PIPESTATUS[0] = exit code of "${@}" (the actual command)
        # PIPESTATUS[1] = exit code of tee
        # Return the command's code; tee write failures are secondary.
        _rc="${PIPESTATUS[0]}"
    fi
    return "${_rc}"
}

# =============================================================================
# SIGNAL HANDLING AND CLEANUP
# =============================================================================
# _cleanup() is registered for EXIT, INT, TERM, and HUP so the sudo keepalive
# background process is reliably killed on every exit path: normal completion,
# die(), Ctrl-C, kill, and terminal hangup (topgrade timeout / SSH disconnect).
_cleanup() {
    if [[ -n "${SUDO_KEEPALIVE_PID}" ]]; then
        "${_KILL}" "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true
        SUDO_KEEPALIVE_PID=""
    fi
}

trap '_cleanup' EXIT INT TERM HUP

# =============================================================================
# CONCURRENCY LOCK
# =============================================================================
# Acquires an exclusive advisory flock on LOCK_FILE using a dedicated file
# descriptor (fd 9). A second concurrent invocation fails immediately rather
# than silently racing on the build directory, source directory, or the
# privileged install step. The lock is released automatically when fd 9 is
# closed on script exit — no stale lock files can block a future run.
_acquire_lock() {
    exec 9>"${LOCK_FILE}"
    "${_FLOCK}" -n 9 || \
        die "Another instance of ${SCRIPT_NAME} is already running. Aborting."
}

# =============================================================================
# ROOT GUARD
# =============================================================================
# Checked at module level (before main()) so it fires immediately regardless
# of which flags were passed.
if (( EUID == 0 )); then
    die "Do not run ${SCRIPT_NAME} as root or with sudo.
  It requests elevated privileges internally, only when necessary.
  Run it as your regular user:  ./${SCRIPT_NAME}"
fi

# =============================================================================
# INTERACTIVITY DETECTION
# =============================================================================
# Returns 0 only when BOTH stdin and stdout are real terminals.
# When called non-interactively (topgrade, cron, pipe), confirm() auto-accepts.
is_interactive() { [[ -t 0 && -t 1 ]]; }

# =============================================================================
# USER CONFIRMATION
# =============================================================================
# confirm "Prompt text"
#   Interactive mode       → prompts Y/N; empty or N → returns 1
#   --non-interactive mode → logs the action and auto-accepts (returns 0)
confirm() {
    local prompt="${1:-Continue?}"
    if [[ "${NON_INTERACTIVE}" == true ]]; then
        log_info "(auto-confirmed) ${prompt}"
        return 0
    fi
    local reply
    "${_PRINTF}" '%b%s [y/N]: %b' "${BOLD}" "${prompt}" "${RESET}"
    read -r reply
    [[ "${reply}" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# =============================================================================
# HELP TEXT
# =============================================================================
# show_help() uses a cat heredoc — self-contained, correct regardless of any
# changes to the header comment. Colour variables are already initialised;
# they are empty strings when stdout is not a TTY, so output is clean whether
# piped, redirected, or rendered in a terminal. Exits 0 — asking for help is
# not an error.
show_help() {
    "${_CAT}" <<EOF
${BOLD}NAME${RESET}
    ${SCRIPT_NAME} — build and install noctalia-qs from source (Fedora 43)

${BOLD}SYNOPSIS${RESET}
    ${CYAN}${SCRIPT_NAME}${RESET} [${BOLD}OPTION${RESET}]

${BOLD}DESCRIPTION${RESET}
    Clones or pulls the noctalia-qs repository, verifies and installs all
    required build dependencies via DNF, configures the project with CMake
    (Ninja generator, Release build, LTO, optional AVX2 tuning), compiles it,
    and installs the resulting binary system-wide to ${CYAN}${INSTALL_PREFIX}${RESET}.

    The script is fully idempotent — when the installed binary was already
    built from the same commit as the current HEAD, the build is skipped
    automatically. Use ${CYAN}--force${RESET} to override this check.

    When called non-interactively (topgrade, cron, or a pipe), every
    confirmation prompt is auto-accepted.

${BOLD}OPTIONS${RESET}
    ${CYAN}-h${RESET}, ${CYAN}--help${RESET}
        Print this help text and exit.

    ${CYAN}--non-interactive${RESET}
        Skip all confirmation prompts; auto-accept every step. Intended for
        use by topgrade or cron. If sudo credentials are not already cached,
        the script will attempt to prompt; set ${CYAN}pre_sudo = true${RESET} in
        ${CYAN}~/.config/topgrade.toml${RESET} under ${CYAN}[misc]${RESET} to avoid this.

    ${CYAN}--force${RESET}
        Force a full rebuild even when the installed binary is already at the
        latest upstream commit. Implies ${CYAN}--non-interactive${RESET}.

${BOLD}BUILD PIPELINE${RESET}
    1.  Verify the operating system (warns on non-Fedora; prompts to continue)
    2.  Acquire sudo credentials and start a keepalive background loop
    3.  Check and install all build dependencies with dnf
    4.  Clone or pull source from GitHub (with recursive submodule update)
    5.  Check whether a rebuild is actually needed (idempotency)
    6.  Configure with CMake (Ninja, Release, LTO, optional x86-64-v3)
    7.  Compile with Ninja
    8.  Install to ${CYAN}${INSTALL_PREFIX}${RESET} via sudo cmake --install

${BOLD}EXAMPLES${RESET}
    # First-time full build (interactive)
    ${CYAN}./${SCRIPT_NAME}${RESET}

    # Routine update — pull latest and rebuild only if something changed
    ${CYAN}./${SCRIPT_NAME} --non-interactive${RESET}

    # Force a clean rebuild of the current HEAD regardless of state
    ${CYAN}./${SCRIPT_NAME} --force${RESET}

    # Show this help text
    ${CYAN}./${SCRIPT_NAME} --help${RESET}

${BOLD}TOPGRADE INTEGRATION${RESET}
    Add the following to ${CYAN}~/.config/topgrade.toml${RESET}:

        ${BOLD}[misc]${RESET}
        pre_sudo = true          # cache credentials before all steps run

        ${BOLD}[commands]${RESET}
        "noctalia-qs" = "${SCRIPT_ABS} --non-interactive"

    To run only this step manually:
        ${CYAN}topgrade --only custom_commands${RESET}

${BOLD}PATHS${RESET}
    Repository   ${CYAN}${REPO_URL}${RESET}
    Source cache ${CYAN}${SRC_DIR}${RESET}
    Build cache  ${CYAN}${BUILD_DIR}${RESET}
    Install to   ${CYAN}${INSTALL_PREFIX}${RESET}
    State file   ${CYAN}${STATE_FILE}${RESET}
    Log file     ${CYAN}${LOG_FILE}${RESET}
    Lock file    ${CYAN}${LOCK_FILE}${RESET}

${BOLD}CMAKE OPTIONS${RESET}
    Build type        Release (matches upstream PKGBUILD)
    Stripping         Disabled (DISTRIBUTOR_DEBUGINFO_AVAILABLE=NO,
                      matching PKGBUILD options=(!strip))
    LTO               ON (CMAKE_INTERPROCEDURAL_OPTIMIZATION)
    Crash reporter    OFF (google-breakpad is not packaged for Fedora)
    x86-64-v3 tuning  Applied automatically when the host CPU supports
                      AVX2 + FMA + BMI1 + BMI2 + MOVBE; skipped silently
                      on CPUs that do not meet all requirements (prevents
                      building a binary that crashes with SIGILL on startup)
    Parallel jobs     nproc/2; respects \$CMAKE_BUILD_PARALLEL_LEVEL

${BOLD}SECURITY NOTES${RESET}
    • PATH is locked to trusted system directories at startup to prevent
      PATH-injection attacks against commands called with sudo.
    • Every external command is called via a hardcoded absolute path
      declared as a readonly variable at the top of the script.
    • umask 077 ensures all created files are owner-only by default.
    • set -C (noclobber) prevents silent overwriting of existing files.
    • flock prevents concurrent instances from racing on shared state.
    • /etc/os-release is read with grep/cut/tr, never sourced, to prevent
      arbitrary code execution from a maliciously crafted file.
    • Script version: ${SCRIPT_VERSION}

EOF
    exit 0
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================
# Uses the "while shift" pattern rather than "for arg in $@":
#   • Handles "--" (explicit end-of-options) correctly.
#   • Processes each token left-to-right with explicit shift, making it
#     straightforward to add option-argument pairs in the future.
#   • Reports unknown options clearly and directs the user to --help.
while :; do
    case "${1-}" in
    -h | --help)
        show_help            # show_help() calls exit 0
        ;;
    --non-interactive)
        NON_INTERACTIVE=true
        ;;
    --force)
        FORCE_BUILD=true
        NON_INTERACTIVE=true
        ;;
    --)
        # Explicit end-of-options — stop processing flags.
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

# =============================================================================
# OS VERIFICATION
# =============================================================================
check_os() {
    log_step "Verifying operating system"

    if [[ ! -f /etc/os-release ]]; then
        log_warn "Cannot detect OS (/etc/os-release not found)."
        confirm "Continue on unknown OS?" || die "Aborted by user."
        return
    fi

    # Read os-release with grep+cut+tr instead of sourcing it.
    # Sourcing /etc/os-release executes it as a shell script — on a system
    # with a maliciously crafted or accidentally broken os-release file this
    # could execute arbitrary code. grep/cut/tr only read text; they cannot
    # execute anything.
    local os_id os_ver
    os_id="$(  "${_GREP}" -m1 '^ID='         /etc/os-release \
               | "${_CUT}" -d= -f2 | "${_TR}" -d '"' )"
    os_ver="$( "${_GREP}" -m1 '^VERSION_ID=' /etc/os-release \
               | "${_CUT}" -d= -f2 | "${_TR}" -d '"' )"

    if [[ "${os_id}" != "fedora" ]]; then
        log_warn "This script is designed for Fedora 43."
        log_warn "Detected: ${os_id} ${os_ver}"
        log_warn "Package names (dnf) may differ. Proceed with caution."
        confirm "Continue anyway?" || die "Aborted by user."
    elif [[ "${os_ver}" != "43" ]]; then
        log_warn "Optimised for Fedora 43; detected Fedora ${os_ver}."
        log_warn "Likely still works, but dnf package names may vary slightly."
        confirm "Continue?" || die "Aborted by user."
    else
        log_ok "Fedora 43 confirmed."
    fi
}

# =============================================================================
# SUDO MANAGEMENT
# =============================================================================
# sudo is needed exclusively to:
#   1) Install missing build packages via dnf
#   2) Run cmake --install (writes to /usr)
#
# Interactive mode   — prompt once, then spawn a keepalive loop in the
#                      background to prevent timeout during a long compile.
# Non-interactive    — use sudo -n (non-prompting); expects the caller
#                      (topgrade with pre_sudo=true) to have already cached
#                      credentials. If not cached, warn and try to prompt.
#
# The keepalive loop:
#   • Uses the parent PID captured before forking, not $$, which in bash
#     always refers to the main shell regardless of subshell depth but is
#     nonetheless made explicit here for clarity.
#   • Checks that the parent is still alive on every iteration and exits
#     cleanly when it is gone (covers the case where the parent exits
#     abnormally before _cleanup() can fire).
#   • Is disowned so bash does not print "Killed: N" on normal exits.

setup_sudo() {
    [[ "${EUID}" -eq 0 ]] && return 0  # root requires no special treatment

    log_step "Acquiring sudo credentials"

    if [[ "${NON_INTERACTIVE}" == true ]]; then
        if "${_SUDO}" -n true 2>/dev/null; then
            log_ok "sudo credentials already cached."
        else
            log_warn "sudo credentials are not cached."
            log_warn "For topgrade, add  pre_sudo = true  under [misc] in topgrade.toml."
            log_warn "Attempting interactive prompt (may fail in non-interactive contexts)..."
            "${_SUDO}" -v || die "sudo authentication failed. Aborting."
        fi
    else
        log_info "sudo is required to install packages and write to ${INSTALL_PREFIX}."
        log_info "Please enter your password once — it will be kept alive for this session."
        "${_SUDO}" -v || die "sudo authentication failed. Aborting."
        log_ok "sudo credentials cached."
    fi

    # Spawn the keepalive loop as a background subshell.
    local _parent_pid="$$"
    (
        while true; do
            "${_SLEEP}" 55
            "${_KILL}" -0 "${_parent_pid}" 2>/dev/null || exit 0
            "${_SUDO}" -n true 2>/dev/null || true
        done
    ) &
    SUDO_KEEPALIVE_PID=$!
    disown "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true
}

# =============================================================================
# BUILD DEPENDENCY CHECK AND INSTALLATION
# =============================================================================

# dep_is_installed <dep>
# Returns 0 if satisfied, 1 if not. Handles plain names as well as
# cmake(Name) and pkgconfig(name) virtual provides via rpm --whatprovides.
dep_is_installed() {
    local dep="${1}"
    if [[ "${dep}" == pkgconfig\(* ]] || [[ "${dep}" == cmake\(* ]]; then
        "${_RPM}" -q --whatprovides "${dep}" &>/dev/null
    else
        "${_RPM}" -q "${dep}" &>/dev/null
    fi
}

install_build_deps() {
    log_step "Checking build dependencies (${#BUILD_DEPS[@]} entries)"

    local -a missing=()
    local dep
    for dep in "${BUILD_DEPS[@]}"; do
        dep_is_installed "${dep}" || missing+=("${dep}")
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        log_ok "All build dependencies are already satisfied."
        return 0
    fi

    log_warn "${#missing[@]} missing:"
    "${_PRINTF}" '  • %s\n' "${missing[@]}"

    confirm "Install missing dependencies with dnf now?" \
        || die "Cannot proceed without build dependencies. Aborting."

    log_info "Running: sudo dnf install -y ..."
    # dnf accepts both plain package names and cmake()/pkgconfig() virtual
    # provides directly — no extra quoting or escaping is required.
    "${_SUDO}" "${_DNF}" install -y "${missing[@]}" 2>&1 \
        | "${_TEE}" -a "${LOG_FILE}" \
        || die "dnf install failed. See log: ${LOG_FILE}"

    log_ok "All build dependencies installed."
}

# =============================================================================
# SOURCE MANAGEMENT
# =============================================================================
fetch_source() {
    log_step "Managing source repository"
    "${_MKDIR}" -p "${CACHE_DIR}"

    if [[ -d "${SRC_DIR}/.git" ]]; then
        # Guard against the cache having been manually redirected to a
        # different remote — would result in building the wrong project.
        local current_remote
        current_remote="$("${_GIT}" -C "${SRC_DIR}" remote get-url origin \
                          2>/dev/null || true)"
        if [[ "${current_remote}" != "${REPO_URL}" ]]; then
            log_warn "Cached repo at ${SRC_DIR} has unexpected remote:"
            log_warn "  found   : ${current_remote}"
            log_warn "  expected: ${REPO_URL}"
            confirm "Delete and re-clone?" \
                || die "Cannot continue with mismatched remote. Remove ${SRC_DIR} manually."
            "${_RM}" -rf -- "${SRC_DIR}"
        fi
    fi

    if [[ ! -d "${SRC_DIR}/.git" ]]; then
        confirm "Clone ${REPO_URL} into ${SRC_DIR}?" \
            || die "Source is required. Aborting."
        log_info "Cloning repository (this may take a few minutes)..."
        log_and_run "${_GIT}" clone --recurse-submodules \
            "${REPO_URL}" "${SRC_DIR}" \
            || die "git clone failed. See log: ${LOG_FILE}"
    else
        log_info "Fetching latest commits from origin..."
        log_and_run "${_GIT}" -C "${SRC_DIR}" \
            fetch --recurse-submodules origin \
            || die "git fetch failed. See log: ${LOG_FILE}"
    fi

    # Determine the default branch from the locally-cached origin/HEAD symref.
    # This avoids a second network round-trip that `git remote show origin`
    # would require. The symref is set during git clone and updated by fetch.
    # Falls back to "main" which is the branch used by noctalia-qs.
    local default_branch
    default_branch="$( "${_GIT}" -C "${SRC_DIR}" \
        rev-parse --abbrev-ref origin/HEAD 2>/dev/null \
        | "${_AWK}" -F'/' '{print $NF}' )" || true
    [[ -z "${default_branch}" ]] && default_branch="main"

    log_and_run "${_GIT}" -C "${SRC_DIR}" checkout "${default_branch}" \
        || die "git checkout ${default_branch} failed."

    log_and_run "${_GIT}" -C "${SRC_DIR}" \
        merge --ff-only "origin/${default_branch}" \
        || die "git merge (fast-forward) failed."

    if [[ -f "${SRC_DIR}/.gitmodules" ]]; then
        log_info "Updating submodules..."
        log_and_run "${_GIT}" -C "${SRC_DIR}" \
            submodule update --init --recursive \
            || die "submodule update failed."
    fi

    CURRENT_COMMIT="$("${_GIT}" -C "${SRC_DIR}" rev-parse HEAD)"
    local commit_subject
    commit_subject="$("${_GIT}" -C "${SRC_DIR}" log -1 --format='%s')"
    log_ok "Source HEAD: ${CURRENT_COMMIT:0:12}  ${commit_subject}"
}

# =============================================================================
# IDEMPOTENCY CHECK
# =============================================================================
# Returns 0 → rebuild is needed.
# Returns 1 → already at this commit; nothing to do.
needs_rebuild() {
    if [[ "${FORCE_BUILD}" == true ]]; then
        log_info "--force: rebuilding unconditionally."
        return 0
    fi

    if [[ ! -f "${STATE_FILE}" ]]; then
        log_info "No previous build state found — will build from scratch."
        return 0
    fi

    local last_built_commit
    last_built_commit="$("${_CAT}" "${STATE_FILE}")"

    if [[ "${last_built_commit}" == "${CURRENT_COMMIT}" ]]; then
        return 1  # already at this commit
    fi

    log_info "New commits since last build:"
    "${_GIT}" -C "${SRC_DIR}" log \
        --oneline \
        --no-walk=unsorted \
        "${last_built_commit}..HEAD" 2>/dev/null || true

    return 0
}

# =============================================================================
# QML INSTALL PREFIX
# =============================================================================
# The quickshell build system requires INSTALL_QML_PREFIX. On Fedora x86_64,
# Qt QML modules live at /usr/lib64/qt6/qml. We query qmake6 at build time
# for the exact path and make it relative to INSTALL_PREFIX.
#
# qmake6/qmake-qt6 are Qt tools whose install location varies between Fedora
# versions and Qt configurations. We detect them at runtime with `command -v`
# rather than hardcoding a path that may not exist on all systems.
get_qml_prefix() {
    local abs_qml_path=""

    if command -v qmake6 &>/dev/null; then
        abs_qml_path="$(qmake6 -query QT_INSTALL_QML 2>/dev/null || true)"
    elif command -v qmake-qt6 &>/dev/null; then
        abs_qml_path="$(qmake-qt6 -query QT_INSTALL_QML 2>/dev/null || true)"
    fi

    if [[ -n "${abs_qml_path}" ]] && \
       [[ "${abs_qml_path}" == "${INSTALL_PREFIX}/"* ]]; then
        "${_PRINTF}" '%s' "${abs_qml_path#"${INSTALL_PREFIX}/"}"
        return
    fi

    # Fallback: standard Fedora x86_64 location.
    "${_PRINTF}" 'lib64/qt6/qml'
}

# =============================================================================
# CPU CAPABILITY CHECK
# =============================================================================
# Returns 0 if the host CPU supports the x86-64-v3 microarchitecture level
# (requires AVX2 + FMA + BMI1 + BMI2 + MOVBE — all five flags are mandatory).
# Returns 1 otherwise so the caller skips the -march flag silently, preventing
# a binary that would crash immediately with SIGILL on non-v3 machines.
cpu_supports_x86_64_v3() {
    local flags
    flags="$("${_GREP}" -m1 '^flags' /proc/cpuinfo 2>/dev/null || true)"
    [[ "${flags}" == *avx2*  ]] &&
    [[ "${flags}" == *fma*   ]] &&
    [[ "${flags}" == *bmi1*  ]] &&
    [[ "${flags}" == *bmi2*  ]] &&
    [[ "${flags}" == *movbe* ]]
}

# =============================================================================
# CMAKE CONFIGURATION
# =============================================================================
configure() {
    log_step "Configuring with CMake"
    "${_MKDIR}" -p "${BUILD_DIR}"

    local qml_prefix
    qml_prefix="$(get_qml_prefix)"

    # Default to nproc/2 parallel jobs (matches the upstream PKGBUILD).
    # Callers may override by exporting CMAKE_BUILD_PARALLEL_LEVEL.
    local -i njobs
    njobs=$(( "$("${_NPROC}")" / 2 ))
    (( njobs < 1 )) && njobs=1
    export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-${njobs}}"

    # Apply x86-64-v3 tuning only when the host CPU supports all required
    # flags. Building with -march=x86-64-v3 on a CPU that lacks AVX2 produces
    # a binary that crashes immediately on first execution with SIGILL.
    local march_flag=""
    if cpu_supports_x86_64_v3; then
        march_flag="-march=x86-64-v3"
        log_info "CPU tuning      : x86-64-v3 (AVX2/FMA/BMI2 detected)"
    else
        log_warn "x86-64-v3 not supported — building without -march tuning."
    fi

    log_info "Install prefix  : ${INSTALL_PREFIX}"
    log_info "QML sub-path    : ${qml_prefix}"
    log_info "Parallel jobs   : ${CMAKE_BUILD_PARALLEL_LEVEL} (of $("${_NPROC}") cores)"
    log_info "Build type      : Release"
    log_info "LTO             : ON (interprocedural optimisation)"
    log_info "Crash reporter  : OFF (google-breakpad not in Fedora repos)"

    # cmake_options mirrors what the PKGBUILD does on Arch, plus LTO and
    # optional x86-64-v3 tuning.
    local -a cmake_options=(
        -G Ninja
        -D CMAKE_BUILD_TYPE=Release
        -D CMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}"
        -D DISTRIBUTOR="Fedora 43 (source build)"
        # DISTRIBUTOR_DEBUGINFO_AVAILABLE=NO → do NOT strip the binary.
        # This matches the Arch PKGBUILD  options=(!strip)  directive.
        -D DISTRIBUTOR_DEBUGINFO_AVAILABLE=NO
        -D INSTALL_QML_PREFIX="${qml_prefix}"
        -D CRASH_REPORTER=OFF
        -D CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON
    )

    if [[ -n "${march_flag}" ]]; then
        cmake_options+=(
            -D CMAKE_C_FLAGS="${march_flag}"
            -D CMAKE_CXX_FLAGS="${march_flag}"
        )
    fi

    log_and_run "${_CMAKE}" -S "${SRC_DIR}" -B "${BUILD_DIR}" \
        "${cmake_options[@]}" \
        || die "CMake configuration failed. See log: ${LOG_FILE}"

    log_ok "CMake configuration complete."
}

# =============================================================================
# COMPILATION
# =============================================================================
compile() {
    log_step "Compiling noctalia-qs"
    log_info "This is a large C++/Qt6 project — expect 15–45 minutes on most hardware."

    confirm "Start compilation now?" \
        || die "Compilation cancelled by user."

    log_and_run "${_CMAKE}" --build "${BUILD_DIR}" \
        || die "Compilation failed. See log: ${LOG_FILE}"

    log_ok "Compilation complete."
}

# =============================================================================
# INSTALLATION
# =============================================================================
do_install() {
    log_step "Installing to ${INSTALL_PREFIX}"
    log_info "This writes to ${INSTALL_PREFIX} and requires sudo."

    confirm "Install noctalia-qs to ${INSTALL_PREFIX} (sudo cmake --install)?" \
        || die "Installation cancelled by user."

    "${_SUDO}" "${_CMAKE}" --install "${BUILD_DIR}" 2>&1 \
        | "${_TEE}" -a "${LOG_FILE}" \
        || die "cmake --install failed. See log: ${LOG_FILE}"

    log_ok "Installation complete."

    # Quick smoke-test: verify the binary landed where expected.
    local binary="${INSTALL_PREFIX}/bin/quickshell"
    local qs_link="${INSTALL_PREFIX}/bin/qs"

    if [[ -x "${binary}" ]]; then
        log_ok "Binary   : ${binary}"
    else
        log_warn "Binary not found at ${binary} — may have installed under a different name."
    fi
    if [[ -L "${qs_link}" ]] || [[ -x "${qs_link}" ]]; then
        log_ok "Symlink  : ${qs_link} → quickshell"
    fi
}

# =============================================================================
# STATE RECORDING
# =============================================================================
# Persists the commit hash of the just-installed binary so the next run can
# detect whether a rebuild is needed without making a network call.
#
# set -C (noclobber) is active globally. >| is the force-overwrite operator
# that explicitly bypasses noclobber. It is used here because overwriting the
# state file on each successful build is the correct, intended behaviour.
record_state() {
    "${_MKDIR}" -p "${STATE_DIR}"
    "${_PRINTF}" '%s\n' "${CURRENT_COMMIT}" >| "${STATE_FILE}"
    {
        "${_PRINTF}" '%s\n' "────────────────────────────────────"
        "${_PRINTF}" 'Built  : %s\n' "$("${_DATE}" -Iseconds)"
        "${_PRINTF}" 'Commit : %s\n' "${CURRENT_COMMIT}"
        "${_PRINTF}" 'Prefix : %s\n' "${INSTALL_PREFIX}"
    } >> "${LOG_FILE}"
    log_ok "State recorded: ${STATE_FILE}"
}

# =============================================================================
# LOG INITIALISATION
# =============================================================================
init_log() {
    "${_MKDIR}" -p "${STATE_DIR}"
    local mode
    mode="$( [[ "${NON_INTERACTIVE}" == true ]] \
             && "${_PRINTF}" 'non-interactive' \
             || "${_PRINTF}" 'interactive' )"
    {
        "${_PRINTF}" '%s\n' "════════════════════════════════════════════════════════"
        "${_PRINTF}" '  noctalia-qs build  —  %s\n' "$("${_DATE}" -Iseconds)"
        "${_PRINTF}" '  Script  : %s\n'              "${SCRIPT_ABS}"
        "${_PRINTF}" '  Version : %s\n'              "${SCRIPT_VERSION}"
        "${_PRINTF}" '  Mode    : %s\n'              "${mode}"
        "${_PRINTF}" '%s\n' "════════════════════════════════════════════════════════"
    } >> "${LOG_FILE}"
}

# =============================================================================
# BANNER
# =============================================================================
print_banner() {
    "${_PRINTF}" '\n'
    "${_PRINTF}" '%b╔══════════════════════════════════════════════════════════╗%b\n' \
        "${BOLD}${CYAN}" "${RESET}"
    "${_PRINTF}" '%b║  noctalia-qs  system-wide  builder  v%-6s             ║%b\n' \
        "${BOLD}${CYAN}" "${SCRIPT_VERSION}" "${RESET}"
    "${_PRINTF}" '%b║  Fedora 43  │  Installs to %-28s  ║%b\n' \
        "${BOLD}${CYAN}" "${INSTALL_PREFIX}" "${RESET}"
    "${_PRINTF}" '%b╚══════════════════════════════════════════════════════════╝%b\n' \
        "${BOLD}${CYAN}" "${RESET}"
    "${_PRINTF}" '\n'
}

# =============================================================================
# TOPGRADE HINT
# =============================================================================
print_topgrade_hint() {
    "${_PRINTF}" '\n'
    "${_PRINTF}" '%b─── Topgrade integration ────────────────────────────────────────%b\n' \
        "${CYAN}" "${RESET}"
    "${_PRINTF}" '  ~/.config/topgrade.toml:\n\n'
    "${_PRINTF}" '    [misc]\n'
    "${_PRINTF}" '    pre_sudo = true\n\n'
    "${_PRINTF}" '    [commands]\n'
    "${_PRINTF}" '    "noctalia-qs" = "%s --non-interactive"\n\n' "${SCRIPT_ABS}"
    "${_PRINTF}" '  Run manually:  topgrade --only custom_commands\n'
    "${_PRINTF}" '%b────────────────────────────────────────────────────────────────%b\n' \
        "${CYAN}" "${RESET}"
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    # Acquire the concurrency lock before doing anything else. A concurrent
    # invocation will fail here rather than racing on shared build state.
    _acquire_lock

    print_banner
    init_log
    check_os
    setup_sudo
    install_build_deps
    fetch_source

    log_step "Checking if a rebuild is needed"
    if ! needs_rebuild; then
        log_ok "Already at latest upstream commit: ${CURRENT_COMMIT:0:12}"
        log_ok "Nothing to do.  (Use --force to rebuild anyway.)"
        print_topgrade_hint
        exit 0
    fi

    log_step "Build plan"
    log_info "Commit  : ${CURRENT_COMMIT:0:12}"
    log_info "Install : ${INSTALL_PREFIX}"
    log_info "Log     : ${LOG_FILE}"

    confirm "Proceed: configure → compile → install?" \
        || { log_info "Cancelled by user."; exit 0; }

    configure
    compile
    do_install
    record_state

    "${_PRINTF}" '\n'
    log_step "Done"
    log_ok "noctalia-qs built and installed successfully."
    log_ok "Commit  : ${CURRENT_COMMIT}"
    log_ok "Binary  : ${INSTALL_PREFIX}/bin/quickshell"
    log_ok "Log     : ${LOG_FILE}"
    print_topgrade_hint
}

main "$@"
