#!/bin/bash

# ==============================================================================
# Automate Emacs Service Configuration for UWSM
# Based on: emacs-service.md
# ==============================================================================

# 1. Strict Error Handling
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error and exit immediately.
# -o pipefail: The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -euo pipefail

# Define constants
SERVICE_NAME="emacs.service"
# Use XDG_CONFIG_HOME if set, otherwise default to ~/.config
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
OVERRIDE_DIR="${CONFIG_DIR}/systemd/user/${SERVICE_NAME}.d"
OVERRIDE_FILE="${OVERRIDE_DIR}/override.conf"

# Helper function for pretty printing
log_info() { echo -e "\e[34m[INFO]\e[0m $1"; }
log_success() { echo -e "\e[32m[OK]\e[0m $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; }

# Trap errors to provide helpful feedback
trap 'log_error "An error occurred on line $LINENO. Exiting."; exit 1' ERR

# ==============================================================================
# Pre-flight Checks
# ==============================================================================

# Check 1: Ensure script is NOT run as root
if [ "$EUID" -eq 0 ]; then
    log_error "This script manages user-level systemd units."
    log_error "Please run this as your normal user, NOT as root (sudo)."
    exit 1
fi

# Check 2: Verify systemd is running for this user
if ! systemctl --user list-units --no-pager > /dev/null 2>&1; then
    log_error "Systemd user instance is not accessible."
    exit 1
fi

# Check 3: Verify Emacs service unit exists
if ! systemctl --user list-unit-files "${SERVICE_NAME}" > /dev/null 2>&1; then
    log_error "Unit file '${SERVICE_NAME}' not found."
    log_error "Is Emacs installed? (e.g., sudo pacman -S emacs)"
    exit 1
fi

# ==============================================================================
# Part 1: Configuration (Override File)
# ==============================================================================

log_info "Preparing directory structure..."
if [ ! -d "$OVERRIDE_DIR" ]; then
    mkdir -p "$OVERRIDE_DIR"
    log_success "Created directory: $OVERRIDE_DIR"
else
    log_info "Directory already exists: $OVERRIDE_DIR"
fi

log_info "Writing override configuration..."
# Writing the file content as specified in the markdown
cat > "$OVERRIDE_FILE" <<EOF
[Unit]
After=graphical-session.target
PartOf=graphical-session.target

[Install]
# Remove default.target dependency
WantedBy=
# Add graphical-session.target dependency
WantedBy=graphical-session.target
EOF

if [ -f "$OVERRIDE_FILE" ]; then
    log_success "Successfully wrote: $OVERRIDE_FILE"
else
    log_error "Failed to write configuration file."
    exit 1
fi

# ==============================================================================
# Part 2: Applying Changes (Reload and Relink)
# ==============================================================================

log_info "Reloading systemd user daemon..."
systemctl --user daemon-reload
log_success "Daemon reloaded."

log_info "Updating service symlinks..."
# We disable first to ensure the old 'default.target' link is removed.
# We silence stderr here because if it wasn't enabled before, disable prints a warning.
systemctl --user disable "${SERVICE_NAME}" > /dev/null 2>&1 || true

# Now enable it to create the new link in 'graphical-session.target.wants'
systemctl --user enable "${SERVICE_NAME}"
log_success "Service re-enabled with new target."

# ==============================================================================
# Completion & Instructions
# ==============================================================================

echo ""
log_success "Configuration Complete!"
echo "----------------------------------------------------------------"
echo "The emacs.service is now configured to start with 'graphical-session.target'."
echo ""
echo "To start the service now and watch the logs (as requested), run:"
echo ""
echo "   systemctl --user start ${SERVICE_NAME} && journalctl --user -u ${SERVICE_NAME} -f"
echo ""
echo "----------------------------------------------------------------"
