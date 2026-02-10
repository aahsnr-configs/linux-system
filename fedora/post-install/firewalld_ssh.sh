#!/bin/bash
# Firewalld Configuration for Custom SSH Port
# Safely transitions SSH from port 22 to port 47

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly NEW_SSH_PORT=47
readonly OLD_SSH_PORT=22

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

# Error handling
cleanup() {
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        error "Script failed with exit code ${exit_code}"
        error "Firewall configuration may be incomplete"
        info "Current firewall status:"
        firewall-cmd --list-all 2>/dev/null || true
    fi
}

trap cleanup EXIT

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
    error "This script must be run as root"
    exit 1
fi

# Check if firewalld is installed
if ! command -v firewall-cmd &> /dev/null; then
    error "firewalld is not installed"
    error "Install it with: sudo dnf install firewalld (RHEL/Fedora/CentOS)"
    error "              or: sudo apt install firewalld (Debian/Ubuntu)"
    exit 1
fi

log "Starting firewalld SSH port migration (port ${OLD_SSH_PORT} → port ${NEW_SSH_PORT})"
echo ""

# Step 1: Enable and start firewalld
log "Step 1: Enabling and starting firewalld..."
if systemctl is-active --quiet firewalld; then
    info "Firewalld is already running"
else
    systemctl enable --now firewalld
    # Wait for firewalld to fully start
    sleep 2
fi

# Verify firewalld is running
if ! systemctl is-active --quiet firewalld; then
    error "Failed to start firewalld"
    error "Check status with: sudo systemctl status firewalld"
    exit 1
fi
log "Firewalld is running"
echo ""

# Step 2: Add new SSH port (before removing anything)
log "Step 2: Adding new SSH port ${NEW_SSH_PORT}/tcp to firewall..."
if firewall-cmd --permanent --add-port="${NEW_SSH_PORT}/tcp"; then
    log "Port ${NEW_SSH_PORT}/tcp added to permanent configuration"
else
    error "Failed to add port ${NEW_SSH_PORT}/tcp"
    exit 1
fi
echo ""

# Step 3: Reload firewall to apply new port
log "Step 3: Reloading firewall to apply changes..."
if firewall-cmd --reload; then
    log "Firewall reloaded successfully"
else
    error "Failed to reload firewall"
    exit 1
fi
echo ""

# Verify the port was added
log "Verifying port ${NEW_SSH_PORT} is open..."
if firewall-cmd --list-ports | grep -q "${NEW_SSH_PORT}/tcp"; then
    log "Port ${NEW_SSH_PORT}/tcp is active in runtime configuration"
else
    warning "Port ${NEW_SSH_PORT}/tcp not found in runtime configuration"
    warning "This may cause connection issues"
fi
echo ""

# Display current firewall status
info "Current firewall configuration:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
firewall-cmd --list-all
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Display SSH service status
info "Current SSH daemon status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
systemctl status sshd --no-pager -l || systemctl status ssh --no-pager -l || true
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create helper script for removing old port
log "Creating helper script: /root/finalize_ssh_port_change.sh"
cat > /root/finalize_ssh_port_change.sh <<'HELPER_SCRIPT'
#!/bin/bash
# Helper script to finalize SSH port change
# Only run this after confirming SSH works on port 47

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Removing SSH service (port 22) from firewall...${NC}"

if firewall-cmd --permanent --remove-service=ssh; then
    echo -e "${GREEN}SSH service removed from permanent configuration${NC}"
else
    echo -e "${RED}Failed to remove SSH service${NC}"
    exit 1
fi

if firewall-cmd --reload; then
    echo -e "${GREEN}Firewall reloaded successfully${NC}"
else
    echo -e "${RED}Failed to reload firewall${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Firewall configuration after removing port 22:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
firewall-cmd --list-all
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}✓ SSH is now only accessible on port 47${NC}"
echo -e "${YELLOW}Remember to update your SSH client configuration${NC}"
HELPER_SCRIPT

chmod +x /root/finalize_ssh_port_change.sh
log "Helper script created: /root/finalize_ssh_port_change.sh"
echo ""

# Final instructions
warning "═══════════════════════════════════════════════════════════════"
warning "                    ⚠️  CRITICAL SAFETY STEPS ⚠️"
warning "═══════════════════════════════════════════════════════════════"
echo ""
info "BOTH port ${OLD_SSH_PORT} and port ${NEW_SSH_PORT} are now open in the firewall"
info "This is intentional for safety during the transition"
echo ""
warning "DO NOT CLOSE YOUR CURRENT SSH SESSION!"
echo ""
echo "Next steps:"
echo ""
echo "1. ${GREEN}Restart SSH to use port ${NEW_SSH_PORT}:${NC}"
echo "   sudo systemctl restart sshd"
echo ""
echo "2. ${GREEN}Open a NEW terminal and test SSH on the new port:${NC}"
echo "   ssh -p ${NEW_SSH_PORT} \$(whoami)@\$(hostname -I | awk '{print \$1}')"
echo ""
echo "3. ${YELLOW}If the connection works:${NC}"
echo "   sudo /root/finalize_ssh_port_change.sh"
echo ""
echo "4. ${RED}If the connection FAILS:${NC}"
echo "   - You still have access via your current session"
echo "   - Check SSH configuration with: sudo sshd -t"
echo "   - Check if SSH is listening: sudo ss -tlnp | grep sshd"
echo "   - Revert changes from backup if needed"
echo ""
warning "═══════════════════════════════════════════════════════════════"
warning "Security reminder: After successful migration, consider:"
warning "  - Installing fail2ban for brute force protection"
warning "  - Reviewing SSH logs regularly"
warning "  - Using SSH key authentication only (no passwords)"
warning "═══════════════════════════════════════════════════════════════"