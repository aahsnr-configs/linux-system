#!/bin/bash
#===============================================================================
# Script: build-hyprland.sh
# Purpose: Idempotent build & install of the latest stable Hyprland release
# Target: openSUSE Tumbleweed
# Requirements: curl, jq, git, sudo, zypper
#===============================================================================

set -euo pipefail # Exit on error, undefined vars, pipe failures

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
readonly REPO_OWNER="hyprwm"
readonly REPO_NAME="Hyprland"
readonly REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"
readonly GITHUB_API="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}"
readonly BUILD_DIR="${HOME}/.cache/hyprland-build"
readonly LOG_PREFIX="[Hyprland Installer]"

# Runtime flags
FORCE_REBUILD=false
UPDATE_MODE=false
VERBOSE=false

#-------------------------------------------------------------------------------
# Argument Parsing
#-------------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -f | --force)
            FORCE_REBUILD=true
            shift
            ;;
        -u | --update)
            UPDATE_MODE=true
            shift
            ;;
        -v | --verbose)
            VERBOSE=true
            shift
            ;;
        -h | --help)
            cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -f, --force    Bypass version check. Forces clean rebuild of latest tag.
  -u, --update   Explicit update mode. Optimized for cron/automation.
  -v, --verbose  Enable debug output.
  -h, --help     Show this help message.

Idempotent Behavior:
  ✅ Exits immediately if latest version is already installed (unless --force)
  ✅ Safe to run repeatedly without side effects
  ✅ When proceeding: always performs clean rebuild + 5s wait + full pipeline
EOF
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# Logging Functions
#-------------------------------------------------------------------------------
log_info() { echo -e "${LOG_PREFIX} \033[1;34mINFO\033[0m: $*"; }
log_success() { echo -e "${LOG_PREFIX} \033[1;32mSUCCESS\033[0m: $*"; }
log_warn() { echo -e "${LOG_PREFIX} \033[1;33mWARN\033[0m: $*" >&2; }
log_error() { echo -e "${LOG_PREFIX} \033[1;31mERROR\033[0m: $*" >&2; }
log_debug() { [[ "${VERBOSE}" == true ]] && echo -e "${LOG_PREFIX} \033[1;90mDEBUG\033[0m: $*" || true; }

#-------------------------------------------------------------------------------
# Version Normalization & Comparison
#-------------------------------------------------------------------------------
normalize_version() { echo "${1#v}"; }

versions_equal() {
    local v1
    v1=$(normalize_version "$1")
    local v2
    v2=$(normalize_version "$2")
    [[ "${v1}" == "${v2}" ]]
}

version_gt() {
    local v1
    v1=$(normalize_version "$1")
    local v2
    v2=$(normalize_version "$2")
    local IFS='.'
    read -ra V1 <<<"$v1"
    read -ra V2 <<<"$v2"
    for i in {0..2}; do
        local n1="${V1[$i]:-0}" n2="${V2[$i]:-0}"
        if ((n1 > n2)); then return 0; fi
        if ((n1 < n2)); then return 1; fi
    done
    return 1
}

#-------------------------------------------------------------------------------
# State Fetchers
#-------------------------------------------------------------------------------
get_latest_release_tag() {
    log_debug "Querying GitHub API: ${GITHUB_API}/releases/latest"
    curl -sL --max-time 30 \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${GITHUB_API}/releases/latest" |
        jq -r '.tag_name // empty' 2>/dev/null ||
        curl -sL --max-time 30 "${GITHUB_API}/releases/latest" |
        grep -oP '"tag_name"\s*:\s*"\K[^"]+' | head -n1
}

get_installed_version() {
    if command -v hyprland &>/dev/null; then
        hyprland --version 2>/dev/null | grep -oP 'v\K[0-9]+\.[0-9]+\.[0-9]+' | head -n1
    elif zypper search --installed-only hyprland &>/dev/null; then
        zypper search --installed-only hyprland 2>/dev/null |
            grep -oP 'hyprland\s+\|\s+\K[0-9]+\.[0-9]+\.[0-9]+' | head -n1
    fi
}

#-------------------------------------------------------------------------------
# Main Execution Flow
#-------------------------------------------------------------------------------
main() {
    parse_args "$@"

    log_info "Starting Hyprland installer for openSUSE Tumbleweed"
    [[ "${UPDATE_MODE}" == true ]] && log_info "Mode: UPDATE (automation/cron friendly)"
    [[ "${FORCE_REBUILD}" == true ]] && log_info "Mode: FORCE (bypassing idempotency check)"

    # 1. Fetch current state
    local latest_tag
    latest_tag=$(get_latest_release_tag)
    [[ -z "${latest_tag}" ]] && {
        log_error "Failed to fetch release tag from GitHub API"
        exit 1
    }

    local installed_version
    installed_version=$(get_installed_version) || true

    log_info "Latest stable release: ${latest_tag}"
    [[ -n "${installed_version}" ]] && log_info "Currently installed: v${installed_version}" || log_info "No existing installation detected."

    # 2. IDEMPOTENCY CHECK
    # If versions match and --force is not set, exit cleanly. This prevents redundant work.
    if [[ "${FORCE_REBUILD}" != true ]] && [[ -n "${installed_version}" ]] && versions_equal "${latest_tag}" "v${installed_version}"; then
        log_success "Target version (${latest_tag}) is already installed."
        log_success "System is up-to-date. Idempotent exit (no changes made)."
        exit 0
    fi

    # 3. Proceed with pipeline (clean rebuild + sleep + update + build)
    log_info "State requires update/rebuild. Proceeding..."

    # Clean build environment (guarantees fresh state)
    log_info "Preparing clean build directory..."
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"

    # 5-second feedback delay (applies to all proceeding runs)
    echo ""
    log_info "Target version: ${latest_tag}"
    log_info "Build pipeline begins in 5 seconds... (Press Ctrl+C to cancel)"
    sleep 5

    # System maintenance
    log_info "Performing full system update (zypper dup)..."
    sudo zypper --non-interactive up
    log_success "System update completed."

    # Dependency installation (runs every update cycle as requested)
    log_info "Installing build dependencies (zypper si -d hyprland)..."
    sudo zypper --non-interactive si -d hyprland
    log_success "Build dependencies installed."

    # Source checkout & build
    log_info "Cloning repository recursively..."
    git clone --recursive --quiet "${REPO_URL}" "${REPO_NAME}"
    cd "${REPO_NAME}"

    log_info "Checking out release tag: ${latest_tag}"
    git checkout --quiet "${latest_tag}"
    git submodule update --init --recursive --quiet

    log_info "Compiling Hyprland (make all)..."
    make --no-print-directory -j22 all

    log_info "Installing to system (sudo make install)..."
    sudo make --no-print-directory install

    # Completion
    echo ""
    log_success "============================================"
    log_success "Hyprland ${latest_tag} installed successfully"
    log_success "============================================"
    log_info "Restart your display manager or log out/in to apply changes."
}

main "$@"
