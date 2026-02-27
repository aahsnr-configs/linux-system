#!/usr/bin/env bash
# =============================================================================
# build-noctalia-qs.sh
#
# Build and install noctalia-qs (Noctalia's Quickshell fork) from source,
# system-wide, on Fedora 43 — faithfully replicating what the PKGBUILD does.
#
# KEY DESIGN RULES:
#   • Installs to /usr  (same as Arch PKGBUILD, system-wide for all users)
#   • Script invokes sudo internally — do NOT run as: sudo ./build-noctalia-qs.sh
#   • Topgrade-compatible via --non-interactive flag
#   • Idempotent: skips rebuild when already at latest upstream commit
#   • Checks upstream GitHub for new commits before deciding to rebuild
#
# USAGE:
#   ./build-noctalia-qs.sh                    # interactive (prompts before each step)
#   ./build-noctalia-qs.sh --non-interactive  # for topgrade / cron
#   ./build-noctalia-qs.sh --force            # force rebuild even if up-to-date
#   ./build-noctalia-qs.sh --help
#
# TOPGRADE INTEGRATION — add to ~/.config/topgrade.toml:
#   [misc]
#   pre_sudo = true          # cache sudo credentials before steps run
#
#   [commands]
#   "noctalia-qs" = "/path/to/build-noctalia-qs.sh --non-interactive"
#
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# ── Constants ─────────────────────────────────────────────────────────────────

readonly SCRIPT_VERSION="3.0.0"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/${SCRIPT_NAME}"

readonly REPO_URL="https://github.com/noctalia-dev/noctalia-qs"

# System-wide install prefix — mirrors the Arch PKGBUILD (which also uses /usr)
readonly INSTALL_PREFIX="/usr"

# Build & source dirs live in the user's cache (no root required for the build
# itself; only cmake --install needs root because it writes to /usr)
readonly CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/noctalia-qs"
readonly SRC_DIR="${CACHE_DIR}/src"
readonly BUILD_DIR="${CACHE_DIR}/build"

# State dir (commit hash of last successful build)
readonly STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/noctalia-qs"
readonly STATE_FILE="${STATE_DIR}/last_built_commit"
readonly LOG_FILE="${STATE_DIR}/build.log"

# ── Runtime flags ─────────────────────────────────────────────────────────────

NON_INTERACTIVE=false
FORCE_BUILD=false
SUDO_KEEPALIVE_PID=

# ── Colour helpers ────────────────────────────────────────────────────────────

if [[ -t 1 ]]; then
    BOLD='\033[1m'   RED='\033[0;31m'    GREEN='\033[0;32m'
    YELLOW='\033[1;33m' BLUE='\033[0;34m' CYAN='\033[0;36m' RESET='\033[0m'
else
    BOLD='' RED='' GREEN='' YELLOW='' BLUE='' CYAN='' RESET=''
fi

# ── Logging ───────────────────────────────────────────────────────────────────

log_info()  { echo -e "${BLUE}[INFO]${RESET}  ${*}"; }
log_ok()    { echo -e "${GREEN}[ OK ]${RESET}  ${*}"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET}  ${*}"; }
log_error() { echo -e "${RED}[ERR ]${RESET}  ${*}" >&2; }
log_step()  { echo -e "\n${BOLD}${CYAN}══> ${*}${RESET}"; }
die()       { log_error "${*}"; exit 1; }

log_and_run() {
    # Run a command, printing it and teeing stdout+stderr to the log file.
    echo "  + ${*}" | tee -a "${LOG_FILE}"
    "${@}" 2>&1 | tee -a "${LOG_FILE}" || return "${PIPESTATUS[0]}"
}

# ── User confirmation ─────────────────────────────────────────────────────────
# In --non-interactive mode, always confirms automatically (returns 0).
# Returns 1 (no) when the user declines.

confirm() {
    local prompt="${1}"
    if [[ "${NON_INTERACTIVE}" == true ]]; then
        log_info "(auto-confirmed) ${prompt}"
        return 0
    fi
    printf "${BOLD}%s [y/N]: ${RESET}" "${prompt}"
    local reply
    read -r reply
    [[ "${reply}" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# ── Argument parsing ──────────────────────────────────────────────────────────

parse_args() {
    for arg in "${@}"; do
        case "${arg}" in
            --non-interactive) NON_INTERACTIVE=true ;;
            --force)           FORCE_BUILD=true; NON_INTERACTIVE=true ;;
            --help|-h)         show_help; exit 0 ;;
            *)                 die "Unknown argument: ${arg}  (try --help)" ;;
        esac
    done
}

show_help() {
    cat <<EOF
${BOLD}${SCRIPT_NAME}${RESET} v${SCRIPT_VERSION}

Build and install noctalia-qs from source, system-wide, on Fedora 43.
Replicates the upstream AUR PKGBUILD: installs to ${INSTALL_PREFIX}.

${BOLD}USAGE${RESET}
  ${SCRIPT_NAME} [OPTION]

${BOLD}OPTIONS${RESET}
  (none)              Interactive — prompts before each major action
  --non-interactive   Fully automatic; for use by topgrade or cron
  --force             Force rebuild even if already at latest commit
  --help              Show this message

${BOLD}TOPGRADE INTEGRATION${RESET}
  Add to ~/.config/topgrade.toml:

    [misc]
    pre_sudo = true   # cache sudo credentials before all steps run

    [commands]
    "noctalia-qs" = "${SCRIPT_ABS} --non-interactive"

  To run only this step:
    topgrade --only custom_commands

${BOLD}KEY PATHS${RESET}
  Repository  : ${REPO_URL}
  Source dir  : ${SRC_DIR}
  Build dir   : ${BUILD_DIR}
  Install to  : ${INSTALL_PREFIX}
  State file  : ${STATE_FILE}
  Log file    : ${LOG_FILE}

${BOLD}NOTES${RESET}
  • Do NOT prefix with sudo; the script calls sudo itself as needed.
  • CRASH_REPORTER is disabled (google-breakpad is not in Fedora repos).
  • The build type is Release (matches the upstream PKGBUILD).
  • Binaries are NOT stripped (matches PKGBUILD options=(!strip)).
  • LTO is always enabled (-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON).
  • x86-64-v3 (-march=x86-64-v3) is applied automatically when the host
    CPU supports AVX2/FMA/BMI1/BMI2/MOVBE; skipped silently otherwise.
EOF
}

# ── Sudo management ───────────────────────────────────────────────────────────
#
# We need sudo exclusively to:
#   1) Install missing build packages via dnf
#   2) Run cmake --install (writes to /usr)
#
# Strategy:
#   • In interactive mode:   prompt once, then keep the timestamp alive.
#   • In non-interactive:    use sudo -n (non-prompting); rely on the caller
#     (topgrade with pre_sudo=true, or a previous sudo call) having cached it.
#     If it hasn't been cached, we abort rather than hang.

setup_sudo() {
    # Root needs no special treatment.
    [[ "${EUID}" -eq 0 ]] && return 0

    log_step "Checking sudo access"

    if [[ "${NON_INTERACTIVE}" == true ]]; then
        # In non-interactive mode try a no-password sudo test.
        if sudo -n true 2>/dev/null; then
            log_ok "sudo credentials already cached (non-interactive mode)."
        else
            # Credentials not cached. Provide a clear actionable message.
            log_warn "sudo credentials are not cached."
            log_warn "For topgrade, add  pre_sudo = true  to ~/.config/topgrade.toml"
            log_warn "under the [misc] section so topgrade caches credentials first."
            log_warn "Attempting to prompt anyway (may fail in non-interactive contexts)..."
            if ! sudo -v; then
                die "sudo authentication failed in non-interactive mode. Aborting."
            fi
        fi
    else
        # Interactive mode: prompt once, then spawn a keep-alive loop.
        log_info "sudo is needed to install packages and to write to ${INSTALL_PREFIX}."
        log_info "Please enter your password once — it will be cached for this session."
        if ! sudo -v; then
            die "sudo authentication failed. Aborting."
        fi
        log_ok "sudo credentials cached."
    fi

    # Keep the sudo timestamp alive in the background for the duration of the
    # script. Kill the background process on any exit (success or failure).
    ( while true; do
        sudo -n true 2>/dev/null || true
        sleep 55
        # Exit the background loop if the parent process is gone.
        kill -0 $$ 2>/dev/null || exit 0
    done ) &
    SUDO_KEEPALIVE_PID=$!
}

# ── Cleanup on exit ───────────────────────────────────────────────────────────

cleanup() {
    local exit_code=$?
    [[ -n "${SUDO_KEEPALIVE_PID}" ]] && kill "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "Build process exited with code ${exit_code}."
        log_error "Full log: ${LOG_FILE}"
    fi
}
trap cleanup EXIT

# ── OS check ──────────────────────────────────────────────────────────────────

check_os() {
    log_step "Verifying operating system"

    if [[ ! -f /etc/os-release ]]; then
        log_warn "Cannot detect OS (/etc/os-release not found)."
        confirm "Continue on unknown OS?" || die "Aborted by user."
        return
    fi

    local os_id os_ver
    os_id="$(  . /etc/os-release && echo "${ID:-unknown}" )"
    os_ver="$( . /etc/os-release && echo "${VERSION_ID:-unknown}" )"

    if [[ "${os_id}" != "fedora" ]]; then
        log_warn "This script is designed for Fedora 43."
        log_warn "Detected: ${os_id} ${os_ver}"
        log_warn "Package names (dnf) may differ. Proceed with caution."
        confirm "Continue anyway?" || die "Aborted by user."
    elif [[ "${os_ver}" != "43" ]]; then
        log_warn "Optimised for Fedora 43; detected Fedora ${os_ver}."
        log_warn "Likely still works, but dnf package names may vary slightly."
        if ! confirm "Continue?"; then die "Aborted by user."; fi
    else
        log_ok "Fedora 43 confirmed."
    fi
}

# ── Build dependencies ────────────────────────────────────────────────────────
#
# Three kinds of entries are used here:
#
#   1. Plain package names  — used for toolchain tools and header-only libs
#      that ship neither a .pc file nor a cmake config.
#      Checked with:  rpm -q <n>
#      Installed with: dnf install <n>
#
#   2. cmake(Name) virtual provides — used for Qt6 and other cmake-based libs.
#      This is the correct Fedora/RPM idiom (matches how spec files write
#      BuildRequires for cmake-based packages). dnf resolves cmake(Name) to
#      whichever -devel package provides that cmake config file, so the script
#      stays correct even if Fedora renames a package between releases.
#      Checked with:  rpm -q --whatprovides 'cmake(Name)'
#      Installed with: dnf install 'cmake(Name)'
#
#   3. pkgconfig(name) virtual provides — used for C/C++ library deps that
#      ship a .pc file (pkg-config).
#      Checked with:  rpm -q --whatprovides 'pkgconfig(name)'
#      Installed with: dnf install 'pkgconfig(name)'
#
# Both cmake() and pkgconfig() are virtual RPM provides; dnf/rpm resolve them
# to whichever -devel package currently owns that config/pc file. This mirrors
# exactly how the COPR spec (errornointernet/quickshell) writes its
# BuildRequires and keeps the script robust across Fedora release renames.
#
# OMITTED: qt6-qtwayland-private-devel — does NOT exist on Fedora. Private
#   Wayland headers are bundled inside qt6-qtwayland-devel. Fedora 43 ships
#   Qt 6.10.x where the build system handles private header requirements
#   automatically.
#
# OMITTED: glslang — not required by the quickshell/noctalia-qs build system;
#   the COPR spec does not list it and spirv-tools covers shader compilation.
#
# CRASH_REPORTER=OFF → google-breakpad is not packaged for Fedora.

readonly -a BUILD_DEPS=(
    # ── Toolchain (plain names — build tools with no cmake/pc file) ───────
    cmake
    ninja-build       # Fedora package name; upstream calls it 'ninja'
    gcc-c++
    git

    # ── Qt6 — cmake() virtual provides ────────────────────────────────────
    # dnf resolves each cmake(X) to the -devel package that installs the
    # corresponding Qt6XxxConfig.cmake file. This matches the COPR spec's
    # BuildRequires exactly and is more robust than hard-coding package names.
    'cmake(Qt6Core)'           # → qt6-qtbase-devel
    'cmake(Qt6Qml)'            # → qt6-qtdeclarative-devel
    'cmake(Qt6ShaderTools)'    # → qt6-qtshadertools-devel
    'cmake(Qt6WaylandClient)'  # → qt6-qtwayland-devel
    'cmake(Qt6Svg)'            # → qt6-qtsvg-devel  (needed for SVG icons)

    # Private Qt headers live in separate -private-devel packages on Fedora.
    # These have no cmake() or pkgconfig() virtual provides, so plain names
    # are the only option here.
    qt6-qtbase-private-devel
    qt6-qtdeclarative-private-devel

    # ── SPIR-V shader toolchain (build-time only, plain name) ─────────────
    spirv-tools       # build-time SPIR-V processing; headers are bundled inside

    # ── Vulkan headers (header-only build-time dep; no .pc or cmake file) ─
    vulkan-headers    # required by the Screencopy feature

    # ── Library deps via pkgconfig() ──────────────────────────────────────
    # dnf resolves each pkgconfig(x) to whichever -devel package owns x.pc.
    # This is the standard Fedora BuildRequires idiom for pkg-config libs and
    # matches the COPR spec line-for-line.
    'pkgconfig(CLI11)'             # → cli11-devel  (static lib; build-time only)
    'pkgconfig(wayland-client)'    # → wayland-devel
    'pkgconfig(wayland-protocols)' # → wayland-protocols-devel
    'pkgconfig(libdrm)'            # → libdrm-devel
    'pkgconfig(gbm)'               # → mesa-libgbm-devel
    'pkgconfig(libpipewire-0.3)'   # → pipewire-devel
    'pkgconfig(pam)'               # → pam-devel
    'pkgconfig(polkit-agent-1)'    # → polkit-devel  (agent API, not gobject)
    'pkgconfig(glib-2.0)'          # → glib2-devel
    'pkgconfig(jemalloc)'          # → jemalloc-devel
    'pkgconfig(xcb)'               # → libxcb-devel  (X11 feature)
)

# Returns 0 if the dependency is already satisfied, 1 if not.
# Handles plain package names as well as cmake(Name) and pkgconfig(name)
# virtual provides — all three are queried via rpm --whatprovides.
dep_is_installed() {
    local dep="${1}"
    if [[ "${dep}" == pkgconfig\(* ]] || [[ "${dep}" == cmake\(* ]]; then
        # Virtual provide (cmake or pkgconfig); must query by --whatprovides.
        rpm -q --whatprovides "${dep}" &>/dev/null
    else
        rpm -q "${dep}" &>/dev/null
    fi
}

install_build_deps() {
    log_step "Checking build dependencies (${#BUILD_DEPS[@]} entries)"

    local -a missing=()
    for dep in "${BUILD_DEPS[@]}"; do
        if ! dep_is_installed "${dep}"; then
            missing+=("${dep}")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        log_ok "All build dependencies are already satisfied."
        return 0
    fi

    log_warn "${#missing[@]} missing:"
    printf '  • %s\n' "${missing[@]}"

    confirm "Install missing dependencies with dnf now?" \
        || die "Cannot proceed without build dependencies."

    # dnf accepts both plain package names and cmake()/pkgconfig() virtual provides directly.
    log_info "Running: sudo dnf install -y ..."
    sudo dnf install -y "${missing[@]}" 2>&1 | tee -a "${LOG_FILE}" \
        || die "dnf install failed. See log: ${LOG_FILE}"

    log_ok "All build dependencies installed."
}

# ── Source management ─────────────────────────────────────────────────────────

fetch_source() {
    log_step "Managing source repository"
    mkdir -p "${CACHE_DIR}"

    if [[ -d "${SRC_DIR}/.git" ]]; then
        # Verify the remote hasn't changed (e.g., user modified it manually).
        local current_remote
        current_remote="$(git -C "${SRC_DIR}" remote get-url origin 2>/dev/null || true)"
        if [[ "${current_remote}" != "${REPO_URL}" ]]; then
            log_warn "Repo at ${SRC_DIR} points to: ${current_remote}"
            log_warn "Expected:                      ${REPO_URL}"
            confirm "Delete and re-clone?" \
                || die "Cannot continue with mismatched remote. Remove ${SRC_DIR} manually."
            rm -rf "${SRC_DIR}"
        fi
    fi

    if [[ ! -d "${SRC_DIR}/.git" ]]; then
        confirm "Clone ${REPO_URL} into ${SRC_DIR}?" \
            || die "Source is required. Aborting."
        log_info "Cloning repository (this may take a few minutes)..."
        log_and_run git clone --recurse-submodules "${REPO_URL}" "${SRC_DIR}" \
            || die "git clone failed."
    else
        log_info "Fetching latest commits from origin..."
        log_and_run git -C "${SRC_DIR}" fetch --recurse-submodules origin \
            || die "git fetch failed."
    fi

    # Determine the default branch (main or master).
    local default_branch
    default_branch="$(git -C "${SRC_DIR}" remote show origin 2>/dev/null \
        | awk '/HEAD branch/{print $NF}')"
    [[ -z "${default_branch}" ]] && default_branch="main"

    log_and_run git -C "${SRC_DIR}" checkout "${default_branch}" \
        || die "git checkout ${default_branch} failed."

    log_and_run git -C "${SRC_DIR}" merge --ff-only "origin/${default_branch}" \
        || die "git merge (fast-forward) failed."

    # Ensure submodules are up to date.
    if [[ -f "${SRC_DIR}/.gitmodules" ]]; then
        log_info "Updating submodules..."
        log_and_run git -C "${SRC_DIR}" submodule update --init --recursive \
            || die "submodule update failed."
    fi

    CURRENT_COMMIT="$(git -C "${SRC_DIR}" rev-parse HEAD)"
    local commit_subject
    commit_subject="$(git -C "${SRC_DIR}" log -1 --format='%s')"
    log_ok "Source HEAD: ${CURRENT_COMMIT:0:12}  ${commit_subject}"
}

# ── Idempotency / upstream-change check ─────────────────────────────────────
#
# Returns 0 (true)  → rebuild needed
# Returns 1 (false) → already up to date, nothing to do

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
    last_built_commit="$(cat "${STATE_FILE}")"

    if [[ "${last_built_commit}" == "${CURRENT_COMMIT}" ]]; then
        return 1  # already at this commit
    fi

    log_info "New commits since last build:"
    git -C "${SRC_DIR}" log \
        --oneline \
        --no-walk=unsorted \
        "${last_built_commit}..HEAD" 2>/dev/null || true

    return 0
}

# ── QML install prefix ────────────────────────────────────────────────────────
#
# The quickshell build system requires INSTALL_QML_PREFIX to be set.
# For a system install to /usr on Fedora x86_64, Qt QML modules live at
# /usr/lib64/qt6/qml. We query qmake6 for the exact path at build time,
# then make it relative to INSTALL_PREFIX.

get_qml_prefix() {
    local abs_qml_path
    if command -v qmake6 &>/dev/null; then
        abs_qml_path="$(qmake6 -query QT_INSTALL_QML 2>/dev/null || true)"
    elif command -v qmake-qt6 &>/dev/null; then
        abs_qml_path="$(qmake-qt6 -query QT_INSTALL_QML 2>/dev/null || true)"
    fi

    if [[ -n "${abs_qml_path}" ]] && \
       [[ "${abs_qml_path}" == "${INSTALL_PREFIX}/"* ]]; then
        # Make it relative to the install prefix.
        echo "${abs_qml_path#${INSTALL_PREFIX}/}"
        return
    fi

    # Fallback: Fedora x86_64 default.
    echo "lib64/qt6/qml"
}

# ── CPU capability check ──────────────────────────────────────────────────────
#
# Returns 0 if the host CPU supports the x86-64-v3 microarchitecture level,
# i.e. it has AVX2 + FMA + BMI1 + BMI2 + MOVBE (all required by v3).
# Returns 1 otherwise.

cpu_supports_x86_64_v3() {
    local flags
    flags="$(grep -m1 '^flags' /proc/cpuinfo 2>/dev/null || true)"
    [[ "${flags}" == *avx2*    ]] &&
    [[ "${flags}" == *fma*     ]] &&
    [[ "${flags}" == *bmi1*    ]] &&
    [[ "${flags}" == *bmi2*    ]] &&
    [[ "${flags}" == *movbe*   ]]
}

# ── CMake configure ───────────────────────────────────────────────────────────

configure() {
    log_step "Configuring with CMake"
    mkdir -p "${BUILD_DIR}"

    local qml_prefix
    qml_prefix="$(get_qml_prefix)"

    # Respect CMAKE_BUILD_PARALLEL_LEVEL; default to nproc/2 (matches PKGBUILD).
    local -i njobs
    njobs=$(( $(nproc) / 2 ))
    (( njobs < 1 )) && njobs=1
    export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-${njobs}}"

    # ── x86-64-v3 tuning ─────────────────────────────────────────────────────
    # Enables AVX2/FMA/BMI2 which benefit Qt6's rendering, text shaping, and
    # image processing paths. Only applied when the host CPU actually supports
    # every required flag; falls back to the toolchain default otherwise.
    local march_flag=""
    if cpu_supports_x86_64_v3; then
        march_flag="-march=x86-64-v3"
        log_info "CPU tuning      : x86-64-v3 (AVX2/FMA detected)"
    else
        log_warn "x86-64-v3 not supported by this CPU — building without -march tuning."
    fi

    log_info "Install prefix  : ${INSTALL_PREFIX}"
    log_info "QML sub-path    : ${qml_prefix}"
    log_info "Parallel jobs   : ${CMAKE_BUILD_PARALLEL_LEVEL} (of $(nproc) cores)"
    log_info "Build type      : Release"
    log_info "LTO             : ON (interprocedural optimisation)"
    log_info "Crash reporter  : OFF (google-breakpad not in Fedora repos)"

    # Build a single flags string; only non-empty when march_flag is set.
    local extra_flags="${march_flag}"

    # cmake_options array — mirrors what the PKGBUILD would do on Arch,
    # plus LTO and optional x86-64-v3 tuning.
    local -a cmake_options=(
        -G Ninja
        -D CMAKE_BUILD_TYPE=Release
        -D CMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}"
        -D DISTRIBUTOR="Fedora 43 (source build)"
        # DISTRIBUTOR_DEBUGINFO_AVAILABLE=NO → do NOT strip the binary.
        # This matches the Arch PKGBUILD  options=(!strip)  directive.
        -D DISTRIBUTOR_DEBUGINFO_AVAILABLE=NO
        -D INSTALL_QML_PREFIX="${qml_prefix}"
        # Disable crash reporter: google-breakpad is not packaged for Fedora.
        -D CRASH_REPORTER=OFF
        # LTO: enables cross-translation-unit inlining and dead-code elimination.
        -D CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON
    )

    # Append march flags only when the CPU supports them — avoids building a
    # binary that crashes immediately on a machine that lacks AVX2.
    if [[ -n "${extra_flags}" ]]; then
        cmake_options+=(
            -D CMAKE_C_FLAGS="${extra_flags}"
            -D CMAKE_CXX_FLAGS="${extra_flags}"
        )
    fi

    log_and_run cmake -S "${SRC_DIR}" -B "${BUILD_DIR}" "${cmake_options[@]}" \
        || die "CMake configure failed. See log: ${LOG_FILE}"

    log_ok "CMake configuration complete."
}

# ── Compile ───────────────────────────────────────────────────────────────────

compile() {
    log_step "Compiling noctalia-qs"
    log_info "This is a large C++/Qt6 project — expect 15–45 minutes on most hardware."

    confirm "Start compilation now?" \
        || die "Compilation cancelled by user."

    log_and_run cmake --build "${BUILD_DIR}" \
        || die "Compilation failed. See log: ${LOG_FILE}"

    log_ok "Compilation complete."
}

# ── Install ───────────────────────────────────────────────────────────────────

do_install() {
    log_step "Installing to ${INSTALL_PREFIX}"
    log_info "This writes to ${INSTALL_PREFIX} and requires sudo."

    confirm "Install noctalia-qs to ${INSTALL_PREFIX} (sudo cmake --install)?" \
        || die "Installation cancelled by user."

    sudo cmake --install "${BUILD_DIR}" 2>&1 | tee -a "${LOG_FILE}" \
        || die "cmake --install failed. See log: ${LOG_FILE}"

    log_ok "Installation complete."

    # Quick smoke-test: verify the binary landed.
    local binary="${INSTALL_PREFIX}/bin/quickshell"
    local qs_link="${INSTALL_PREFIX}/bin/qs"

    if [[ -x "${binary}" ]]; then
        log_ok "Binary   : ${binary}"
    else
        log_warn "Expected binary not found at ${binary} — install may have used a different name."
    fi
    if [[ -L "${qs_link}" ]] || [[ -x "${qs_link}" ]]; then
        log_ok "Symlink  : ${qs_link} → quickshell"
    fi
}

# ── Record state ──────────────────────────────────────────────────────────────

record_state() {
    mkdir -p "${STATE_DIR}"
    echo "${CURRENT_COMMIT}" > "${STATE_FILE}"
    {
        echo "────────────────────────────────────"
        echo "Built  : $(date -Iseconds)"
        echo "Commit : ${CURRENT_COMMIT}"
        echo "Prefix : ${INSTALL_PREFIX}"
    } >> "${LOG_FILE}"
    log_ok "State recorded: ${STATE_FILE}"
}

# ── Topgrade hint ─────────────────────────────────────────────────────────────

print_topgrade_hint() {
    echo ""
    echo -e "${CYAN}─── Topgrade integration ────────────────────────────────────────${RESET}"
    echo    "  ~/.config/topgrade.toml:"
    echo    ""
    echo    "    [misc]"
    echo    "    pre_sudo = true"
    echo    ""
    echo    "    [commands]"
    echo -e "    \"noctalia-qs\" = \"${SCRIPT_ABS} --non-interactive\""
    echo    ""
    echo    "  Run manually:  topgrade --only custom_commands"
    echo -e "${CYAN}────────────────────────────────────────────────────────────────${RESET}"
}

# ── Logging init ──────────────────────────────────────────────────────────────

init_log() {
    mkdir -p "${STATE_DIR}"
    {
        echo "════════════════════════════════════════════════════════"
        echo "  noctalia-qs build  —  $(date -Iseconds)"
        echo "  Script  : ${SCRIPT_ABS}"
        echo "  Version : ${SCRIPT_VERSION}"
        echo "  Mode    : $( [[ "${NON_INTERACTIVE}" == true ]] && echo non-interactive || echo interactive )"
        echo "════════════════════════════════════════════════════════"
    } >> "${LOG_FILE}"
}

# ── Banner ────────────────────────────────────────────────────────────────────

print_banner() {
    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║  noctalia-qs  system-wide  builder  v${SCRIPT_VERSION}              ║${RESET}"
    echo -e "${BOLD}${CYAN}║  Fedora 43  │  Installs to ${INSTALL_PREFIX}                  ║${RESET}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    parse_args "${@}"
    print_banner
    init_log
    check_os
    setup_sudo
    install_build_deps
    fetch_source

    log_step "Checking if rebuild is needed"
    if ! needs_rebuild; then
        log_ok "Already at latest upstream commit: ${CURRENT_COMMIT:0:12}"
        log_ok "Nothing to do. (Use --force to rebuild anyway.)"
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

    echo ""
    log_step "Done"
    log_ok "noctalia-qs built and installed successfully."
    log_ok "Commit  : ${CURRENT_COMMIT}"
    log_ok "Binary  : ${INSTALL_PREFIX}/bin/quickshell"
    log_ok "Log     : ${LOG_FILE}"
    print_topgrade_hint
}

main "${@}"
