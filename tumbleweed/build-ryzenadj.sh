#!/bin/bash
# Build and install ryzenadj for Ubuntu 24.04
# Based on AUR PKGBUILD: https://aur.archlinux.org/packages/ryzenadj
# Tested on Ubuntu 24.04 LTS

set -euo pipefail

# Variables
readonly PKGNAME="ryzenadj"
readonly PKGVER="0.17.0"
readonly URL="https://github.com/FlyGoat/RyzenAdj"
readonly SRCDIR="/tmp/${PKGNAME}-build-$$"
readonly REQUIRED_PACKAGES=("build-essential" "cmake" "libpci-dev")

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Helper functions
error() {
    echo -e "${RED}ERROR:${NC} $1" >&2
    cleanup
    exit 1
}

info() {
    echo -e "${GREEN}==>${NC} $1"
}

warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

cleanup() {
    if [ -d "$SRCDIR" ]; then
        rm -rf "$SRCDIR"
    fi
}

# Trap errors and interrupts
trap cleanup EXIT ERR INT TERM

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    error "Do not run this script as root. Sudo will be used only when necessary."
fi

# Check Ubuntu version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" != "ubuntu" ]; then
        warning "This script is designed for Ubuntu. Your OS: $ID"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
fi

# Check dependencies
info "Checking build dependencies..."
MISSING_PACKAGES=()

for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        MISSING_PACKAGES+=("$pkg")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -ne 0 ]; then
    error "Missing packages: ${MISSING_PACKAGES[*]}\nInstall with: sudo apt install ${MISSING_PACKAGES[*]}"
fi

# Verify commands are available
for cmd in cmake gcc g++ make curl tar; do
    if ! command -v "$cmd" &> /dev/null; then
        error "$cmd is not available in PATH"
    fi
done

# Clean previous build if exists
if [ -d "$SRCDIR" ]; then
    info "Removing previous build directory..."
    rm -rf "$SRCDIR"
fi

# Create build directory
info "Creating build directory: $SRCDIR"
mkdir -p "$SRCDIR"
cd "$SRCDIR"

# Download source
info "Downloading RyzenAdj v${PKGVER}..."
if ! curl -fsSL "${URL}/archive/refs/tags/v${PKGVER}.tar.gz" -o "${PKGNAME}-${PKGVER}.tar.gz"; then
    error "Failed to download source from GitHub"
fi

# Verify download
if [ ! -f "${PKGNAME}-${PKGVER}.tar.gz" ] || [ ! -s "${PKGNAME}-${PKGVER}.tar.gz" ]; then
    error "Downloaded file is missing or empty"
fi

# Extract source
info "Extracting source archive..."
if ! tar -xzf "${PKGNAME}-${PKGVER}.tar.gz"; then
    error "Failed to extract source archive"
fi

# Change to source directory
cd "RyzenAdj-${PKGVER}" || error "Source directory 'RyzenAdj-${PKGVER}' not found"

# Remove win32 directory (not needed on Linux)
if [ -d "win32" ]; then
    rm -rf win32
fi

# Configure with cmake (following AUR PKGBUILD pattern)
info "Configuring build with CMake..."
if ! cmake -B build -S . \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX='/usr' \
    -Wno-dev; then
    error "CMake configuration failed"
fi

# Build
info "Building ryzenadj (this may take a minute)..."
if ! cmake --build build -j"$(nproc)"; then
    error "Build failed"
fi

# Verify build artifacts exist
if [ ! -f "build/ryzenadj" ]; then
    error "Binary build/ryzenadj not found after build"
fi

if [ ! -f "build/libryzenadj.so" ]; then
    error "Library build/libryzenadj.so not found after build"
fi

# Install (requires sudo)
info "Installing ryzenadj to /usr/bin (requires sudo)..."
echo "This step requires root privileges to install to system directories."

if ! sudo cmake --install build; then
    warning "CMake install failed, trying manual installation..."
    
    # Fallback to manual installation
    sudo install -Dm755 build/ryzenadj /usr/bin/ryzenadj || error "Failed to install binary"
    sudo install -Dm755 build/libryzenadj.so /usr/lib/libryzenadj.so || error "Failed to install library"
    sudo install -Dm644 lib/ryzenadj.h /usr/include/ryzenadj.h || error "Failed to install header"
fi

# Update library cache
info "Updating library cache..."
sudo ldconfig

# Verify installation
info "Verifying installation..."
if ! command -v ryzenadj &> /dev/null; then
    error "ryzenadj command not found after installation"
fi

INSTALLED_PATH=$(command -v ryzenadj)
echo -e "${GREEN}SUCCESS:${NC} ryzenadj installed at $INSTALLED_PATH"
echo ""

# Test if binary works
info "Testing ryzenadj binary..."
if sudo ryzenadj --help &> /dev/null; then
    echo -e "${GREEN}SUCCESS:${NC} Binary is working correctly"
else
    warning "Binary execution test failed. This may be normal if you don't have a Ryzen CPU."
fi

echo ""
echo "=========================================="
echo "Installation completed successfully!"
echo "=========================================="
echo ""
echo "Usage: sudo ryzenadj [options]"
echo "Example: sudo ryzenadj --info"
echo ""
echo "For more information, visit:"
echo "https://github.com/FlyGoat/RyzenAdj"
echo ""

# Cleanup happens automatically via trap EXIT
