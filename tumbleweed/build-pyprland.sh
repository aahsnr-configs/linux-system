#!/usr/bin/env bash

################################################################################
# Pyprland Installation Script for openSUSE Tumbleweed
#
# Converted from: pyprland-git PKGBUILD (AUR)
# Source: https://aur.archlinux.org/packages/pyprland-git
#
# PKGBUILD Dependencies (verified from AUR):
#   makedepends: gcc, git, python-build, python-installer, python-pillow, python-poetry
#   depends: python, python-aiofiles
#
# This script combines two approaches:
#   1. pipx methodology: Isolated venv for each app (avoids pip warnings)
#   2. AUR methodology: Build in user space, only elevate for installation
#
# Installation Strategy:
#   - Build directory: ~/.cache/pyprland-build (user-owned, no sudo)
#   - Virtual env: ~/.local/share/pyprland-venv (user-owned, isolated)
#   - Binaries: /usr/local/bin/pypr, /usr/local/bin/pypr-client (symlinked)
#   - This avoids ALL pip warnings while providing system-wide access
#
# Supported Distribution:
#   - openSUSE Tumbleweed ONLY (rolling release)
#     ID=opensuse-tumbleweed in /etc/os-release
#
# openSUSE Tumbleweed Python packaging notes:
#   On Tumbleweed, Python library packages are named with the full version
#   number: python313-<name> (NOT python3-<name>). As of current Tumbleweed,
#   python313 is the primary Python flavor and /usr/bin/python3 is a symlink
#   to /usr/bin/python3.13.
#
# This script is fully idempotent - safe to run multiple times.
################################################################################

set -euo pipefail
IFS=$'\n\t'

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration
readonly PYPRLAND_REPO="https://github.com/hyprland-community/pyprland.git"
readonly BUILD_DIR="${HOME}/.cache/pyprland-build"
readonly VENV_DIR="${HOME}/.local/share/pyprland-venv"
readonly VERSION_FILE="${BUILD_DIR}/.installed_version"
readonly MIN_PYTHON_MAJOR=3
readonly MIN_PYTHON_MINOR=11

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should NOT be run as root or with sudo."
        log_info "The script will request sudo privileges when needed."
        exit 1
    fi
}

# Check for openSUSE Tumbleweed specifically
check_tumbleweed_distro() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine OS version. /etc/os-release not found."
        exit 1
    fi

    local os_id os_pretty_name
    os_id=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
    os_pretty_name=$(grep "^PRETTY_NAME=" /etc/os-release | cut -d'=' -f2 | tr -d '"')

    if [[ "${os_id}" == "opensuse-tumbleweed" ]]; then
        log_info "Detected ${os_pretty_name}"
    else
        log_error "This script requires openSUSE Tumbleweed ONLY."
        log_error "Detected: ${os_pretty_name} (ID=${os_id})"
        log_error "This script does NOT support Fedora, openSUSE Leap,"
        log_error "or any other distribution."
        exit 1
    fi
}

# Check Python version
check_python_version() {
    if ! command -v python3 &>/dev/null; then
        log_error "Python 3 is not installed. Install python313 via zypper."
        exit 1
    fi

    local python_version python_major python_minor
    python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
    python_major=$(echo "$python_version" | cut -d'.' -f1)
    python_minor=$(echo "$python_version" | cut -d'.' -f2)

    if [[ $python_major -lt $MIN_PYTHON_MAJOR ]] ||
        [[ $python_major -eq $MIN_PYTHON_MAJOR && $python_minor -lt $MIN_PYTHON_MINOR ]]; then
        log_error "Python ${MIN_PYTHON_MAJOR}.${MIN_PYTHON_MINOR}+ is required. Found: $python_version"
        exit 1
    fi

    log_success "Python version check passed: $python_version"
}

# Install system dependencies via zypper
install_dependencies() {
    log_info "Installing system dependencies via zypper..."

    # openSUSE Tumbleweed package equivalents of AUR PKGBUILD makedepends/depends.
    #
    # On Tumbleweed, Python library packages are named with the full Python
    # version number: python313-<name>. The python3-<name> convention is NOT
    # correct for Tumbleweed.
    #
    # Package mapping (AUR name -> Tumbleweed package name):
    #   gcc                 -> gcc                    (C compiler for pypr-client)
    #   make                -> make                   (build tooling)
    #   git                 -> git                    (source checkout)
    #   python (interp.)    -> python313              (Python 3.13 interpreter)
    #   python-pip          -> python313-pip          (pip for Python 3.13)
    #   python-devel        -> python313-devel        (headers/libs for C extensions)
    #   python-build        -> python313-build        (PEP 517 build frontend)
    #   python-setuptools   -> python313-setuptools   (build tooling)
    #   python-wheel        -> python313-wheel        (wheel packaging support)
    #   python-poetry       -> python313-poetry-core  (poetry build backend)
    #   python-pillow       -> python313-Pillow       (Pillow imaging; capital P)
    #   python-aiofiles     -> python313-aiofiles     (async file I/O; runtime dep)
    local -a packages=(
        git
        gcc
        make
        python313
        python313-pip
        python313-devel
        python313-build
        python313-setuptools
        python313-wheel
        python313-poetry-core
        python313-Pillow
        python313-aiofiles
    )

    log_info "Refreshing zypper repositories..."
    if ! sudo zypper --non-interactive refresh; then
        log_error "Failed to refresh zypper repositories"
        exit 1
    fi

    log_info "Installing packages: ${packages[*]}"
    if ! sudo zypper --non-interactive install "${packages[@]}"; then
        log_error "Failed to install dependencies"
        exit 1
    fi

    log_success "Dependencies installed successfully"
}

# Get current installed version
get_installed_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        echo "not_installed"
    fi
}

# Get latest version from GitHub
get_latest_version() {
    local latest_commit
    if ! latest_commit=$(git ls-remote "$PYPRLAND_REPO" HEAD 2>/dev/null | cut -f1); then
        log_error "Failed to fetch latest version from GitHub"
        return 1
    fi
    echo "$latest_commit"
}

# Check for updates
check_for_updates() {
    log_info "Checking for updates..."

    local installed_version latest_version
    installed_version=$(get_installed_version)

    if [[ "$installed_version" == "not_installed" ]]; then
        log_info "Pyprland is not installed"
        return 0
    fi

    if ! latest_version=$(get_latest_version); then
        log_error "Failed to check for updates"
        return 1
    fi

    if [[ "$installed_version" == "$latest_version" ]]; then
        log_success "Pyprland is up to date"
        log_info "Installed version: ${installed_version:0:8}"
        return 1
    else
        log_info "Update available!"
        log_info "Installed version: ${installed_version:0:8}"
        log_info "Latest version:    ${latest_version:0:8}"
        return 0
    fi
}

# Clone or update repository (AS USER)
prepare_source() {
    log_info "Preparing source code..."
    log_info "Build directory: ${BUILD_DIR}"

    mkdir -p "$BUILD_DIR"

    if [[ -d "${BUILD_DIR}/.git" ]]; then
        log_info "Updating existing repository..."
        if ! git -C "$BUILD_DIR" fetch --all; then
            log_error "Failed to fetch updates"
            exit 1
        fi
        if ! git -C "$BUILD_DIR" reset --hard origin/main; then
            log_error "Failed to reset repository"
            exit 1
        fi
        git -C "$BUILD_DIR" clean -fdx || log_warning "Failed to clean repository"
    else
        log_info "Cloning repository..."
        [[ -d "$BUILD_DIR" ]] && rm -rf "$BUILD_DIR"
        if ! git clone "$PYPRLAND_REPO" "$BUILD_DIR"; then
            log_error "Failed to clone repository"
            exit 1
        fi
    fi

    log_success "Source code prepared"
}

# Create or update virtual environment (AS USER)
setup_venv() {
    log_info "Setting up virtual environment..."
    log_info "Virtual environment: ${VENV_DIR}"

    if [[ -d "$VENV_DIR" ]]; then
        log_info "Removing existing virtual environment for clean install..."
        rm -rf "$VENV_DIR"
    fi

    # Create fresh virtual environment using python3, which on Tumbleweed is
    # a symlink to /usr/bin/python3.13 provided by the python313 package.
    # The venv module is included in python313 itself on Tumbleweed;
    # no separate python313-venv package is required.
    if ! python3 -m venv "$VENV_DIR"; then
        log_error "Failed to create virtual environment"
        exit 1
    fi

    log_success "Virtual environment created"
}

# Build pyprland wheel (AS USER)
build_pyprland() {
    log_info "Building pyprland Python package..."

    cd "$BUILD_DIR" || {
        log_error "Failed to change directory to $BUILD_DIR"
        exit 1
    }

    # Clean previous builds
    rm -rf dist/ build/ ./*.egg-info/ 2>/dev/null || true

    # Build wheel using system-installed build backend (poetry-core).
    # --no-isolation tells the PEP 517 build frontend to use the system-installed
    # python313-poetry-core rather than creating an isolated environment and
    # downloading it from PyPI. This works correctly on Tumbleweed because
    # python313-poetry-core is available in the official OSS repository.
    log_info "Building wheel package..."
    if ! python3 -m build --wheel --no-isolation; then
        log_error "Failed to build wheel"
        exit 1
    fi

    log_success "Python package build completed"
}

# Install pyprland in venv (AS USER)
install_pyprland_in_venv() {
    log_info "Installing pyprland in virtual environment..."

    cd "$BUILD_DIR" || {
        log_error "Failed to change directory to $BUILD_DIR"
        exit 1
    }

    # Find the built wheel
    local wheel_file
    wheel_file=$(find dist/ -name "*.whl" -type f 2>/dev/null | head -n 1)

    if [[ -z "$wheel_file" ]]; then
        log_error "No wheel file found in dist/"
        exit 1
    fi

    log_info "Installing wheel in venv: $(basename "$wheel_file")"

    # Install the wheel and all its runtime dependencies into the isolated venv.
    # The venv pip does not produce --break-system-packages warnings because it
    # is operating inside an isolated virtual environment, not the system Python.
    if ! "${VENV_DIR}/bin/pip" install "$wheel_file"; then
        log_error "Failed to install pyprland in virtual environment"
        exit 1
    fi

    log_success "Pyprland installed in virtual environment"
}

# Build pypr-client C binary (AS USER)
build_pypr_client() {
    log_info "Building pypr-client C binary..."

    cd "$BUILD_DIR" || {
        log_error "Failed to change directory to $BUILD_DIR"
        exit 1
    }

    if [[ ! -d "client" ]]; then
        log_warning "Client directory not found - pypr-client will not be available"
        return 0
    fi

    cd client || {
        log_error "Failed to change to client directory"
        exit 1
    }

    local c_source
    c_source=$(find . -maxdepth 1 -name "*.c" -type f | head -n 1)

    if [[ -z "$c_source" ]]; then
        log_warning "No C source file found in client/ directory"
        return 0
    fi

    log_info "Compiling $(basename "$c_source")..."

    if ! gcc -O2 -o pypr-client "$c_source"; then
        log_error "Failed to compile pypr-client"
        exit 1
    fi

    log_success "pypr-client binary compiled successfully"
}

# Create system-wide symlinks (NEEDS SUDO)
create_symlinks() {
    log_info "Creating system-wide symlinks..."

    # Symlink pypr from venv to /usr/local/bin
    local pypr_venv="${VENV_DIR}/bin/pypr"

    if [[ ! -f "$pypr_venv" ]]; then
        log_error "pypr binary not found in venv: $pypr_venv"
        exit 1
    fi

    if ! sudo ln -sf "$pypr_venv" /usr/local/bin/pypr; then
        log_error "Failed to create symlink for pypr"
        exit 1
    fi

    log_success "Created symlink: /usr/local/bin/pypr -> $pypr_venv"

    # Install pypr-client binary if it exists
    local client_binary="${BUILD_DIR}/client/pypr-client"

    if [[ -f "$client_binary" ]]; then
        if ! sudo install -Dm755 "$client_binary" /usr/local/bin/pypr-client; then
            log_error "Failed to install pypr-client binary"
            exit 1
        fi
        log_success "Installed: /usr/local/bin/pypr-client"
    else
        log_warning "pypr-client not found - skipping (optional component)"
    fi
}

# Save version info
save_version() {
    cd "$BUILD_DIR" || return
    local current_commit
    current_commit=$(git rev-parse HEAD)
    echo "$current_commit" >"$VERSION_FILE"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."

    sleep 1

    local all_good=true

    # Check pypr
    if command -v pypr &>/dev/null; then
        local pypr_version
        pypr_version=$(pypr --version 2>&1 || echo "version check failed")
        log_success "pypr command is available"
        log_info "  Location: $(which pypr)"
        log_info "  Version: $pypr_version"
    else
        log_error "pypr command not found"
        all_good=false
    fi

    # Check pypr-client
    if command -v pypr-client &>/dev/null; then
        log_success "pypr-client command is available"
        log_info "  Location: $(which pypr-client)"
    else
        log_warning "pypr-client not found (optional - pypr will work without it)"
    fi

    if [[ "$all_good" != "true" ]]; then
        log_error "Installation verification failed"
        exit 1
    fi

    log_success "Installation verification passed"
}

# Display usage
usage() {
    cat <<'EOF'
Pyprland Installation Script for openSUSE Tumbleweed

Converted from pyprland-git PKGBUILD (AUR)
Combines pipx isolation with AUR build methodology

USAGE:
    ./setup-pyprland [COMMAND]

COMMANDS:
    install         Install or update pyprland (default)
    check-update    Check if updates are available
    remove          Remove pyprland completely
    clean           Remove build directory only
    help            Display this help message

EXAMPLES:
    ./setup-pyprland install       # Install or update
    ./setup-pyprland check-update  # Check for updates
    ./setup-pyprland remove        # Completely remove
    ./setup-pyprland clean         # Clean build cache

INSTALLATION DETAILS:
    Build directory:  ~/.cache/pyprland-build
    Virtual env:      ~/.local/share/pyprland-venv
    Binary symlinks:  /usr/local/bin/pypr
                      /usr/local/bin/pypr-client (if available)

WHY THIS APPROACH:
    - Uses isolated venv (like pipx) = NO pip warnings
    - Builds in user space (like AUR) = NO git ownership errors
    - System-wide binaries via symlinks = Available to all users
    - Clean, idempotent, production-ready

REQUIREMENTS:
    - openSUSE Tumbleweed ONLY (rolling release)
    - Python 3.11 or higher (Tumbleweed ships python313 by default)
    - Sudo privileges
    - Internet connection

CONFIGURATION:
    Config file: ~/.config/hypr/pyprland.toml
    Add to hyprland.conf: exec-once = pypr

For more information:
    https://github.com/hyprland-community/pyprland
    https://hyprland-community.github.io/pyprland/

EOF
}

# Remove pyprland
remove_pyprland() {
    log_info "Removing pyprland..."

    # Remove symlinks
    if [[ -L /usr/local/bin/pypr ]]; then
        log_info "Removing symlink: /usr/local/bin/pypr"
        sudo rm -f /usr/local/bin/pypr
    fi

    if [[ -f /usr/local/bin/pypr-client ]]; then
        log_info "Removing binary: /usr/local/bin/pypr-client"
        sudo rm -f /usr/local/bin/pypr-client
    fi

    # Remove venv
    if [[ -d "$VENV_DIR" ]]; then
        log_info "Removing virtual environment: ${VENV_DIR}"
        rm -rf "$VENV_DIR"
    fi

    log_success "Pyprland removed successfully"
    log_info "Build directory still exists at: ${BUILD_DIR}"
    log_info "Run '$0 clean' to remove build directory"
}

# Clean build directory
clean_build_dir() {
    log_info "Cleaning build directory..."

    if [[ -d "$BUILD_DIR" ]]; then
        log_info "Removing: ${BUILD_DIR}"
        rm -rf "$BUILD_DIR"
        log_success "Build directory removed"
    else
        log_info "Build directory not found (already clean)"
    fi
}

# Main installation function
main_install() {
    log_info "Starting pyprland installation..."
    log_info "Repository: ${PYPRLAND_REPO}"
    log_info "Build directory: ${BUILD_DIR}"
    log_info "Virtual environment: ${VENV_DIR}"
    echo

    check_root
    check_tumbleweed_distro
    check_python_version
    install_dependencies
    prepare_source
    setup_venv
    build_pyprland
    install_pyprland_in_venv
    build_pypr_client
    create_symlinks
    save_version
    verify_installation

    echo
    log_success "==========================================="
    log_success " Installation completed successfully!"
    log_success "==========================================="
    echo
    log_info "Commands available:"
    log_info "  pypr          - Main daemon (required)"
    if command -v pypr-client &>/dev/null; then
        log_info "  pypr-client   - Fast client for keybindings (optional)"
    fi
    echo
    log_info "Configuration:"
    log_info "  File: ~/.config/hypr/pyprland.toml"
    log_info "  Auto-start: exec-once = pypr"
    echo
    log_info "Directories:"
    log_info "  Build: ${BUILD_DIR}"
    log_info "  Venv:  ${VENV_DIR}"
    echo
    log_info "Update: $0 install (idempotent)"
    echo
}

# Main function
main() {
    local command="${1:-install}"

    case "$command" in
    install)
        main_install
        ;;
    check-update | check)
        check_root
        if check_for_updates; then
            echo
            log_info "To update: $0 install"
        fi
        ;;
    remove | uninstall)
        check_root
        remove_pyprland
        ;;
    clean)
        clean_build_dir
        ;;
    help | -h | --help)
        usage
        ;;
    *)
        log_error "Unknown command: $command"
        echo
        usage
        exit 1
        ;;
    esac
}

main "$@"
