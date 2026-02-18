#!/usr/bin/env bash

# Simplified Fedora 42 Hyprland Setup Script
# Run as regular user with sudo privileges
# Required files: dnf.conf.txt, 99-custom-env.sh.txt, packages.txt, groups.txt, flatpaks.txt

set -euo pipefail

# Verify running as regular user
if [[ $EUID -eq 0 ]]; then
  echo "Error: This script must be run as a regular user with sudo privileges"
  exit 1
fi

# Install dependencies
sudo dnf install -y git-core curl wget pciutils dmidecode policycoreutils-python-utils util-linux

# Initial Setup
sudo cp dnf.conf.txt /etc/dnf/dnf.conf
sudo cp 99-custom-env.sh.txt /etc/profile.d/99-custom-env.sh
sudo chmod +x /etc/profile.d/99-custom-env.sh
sudo hostnamectl set-hostname zephyrus
sudo dnf update -y

# Setup Btrfs Swap
SWAPSIZE=$(free | awk '/Mem/ {x=$2/1024/1024; printf "%.0fG", (x<2 ? 2*x : x<8 ? 1.5*x : x) }')
sudo btrfs subvolume create /var/swap
sudo chattr +C /var/swap
sudo fallocate -l "$SWAPSIZE" /var/swap/swapfile
sudo chmod 600 /var/swap/swapfile
sudo mkswap -L SWAPFILE /var/swap/swapfile
echo "/var/swap/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab
sudo swapon -av
echo 'add_dracutmodules+=" resume "' | sudo tee /etc/dracut.conf.d/resume.conf
sudo dracut -f

# Setup Repositories
sudo dnf copr enable -y solopasha/hyprland
sudo dnf copr enable -y errornointernet/quickshell
sudo dnf copr enable -y deltacopy/darkly
sudo dnf copr enable -y sneexy/zen-browser
sudo dnf config-manager addrepo --from-repofile="https://download.opensuse.org/repositories/home:luisbocanegra/Fedora_Rawhide/home:luisbocanegra.repo"
sudo dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
sudo dnf install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
sudo dnf update -y

# Setup NVIDIA Drivers
sudo dnf install -y --setopt=install_weak_deps=False \
  akmod-nvidia \
  xorg-x11-drv-nvidia-cuda \
  xorg-x11-drv-nvidia-power \
  vulkan \
  xorg-x11-drv-nvidia-cuda-libs \
  nvidia-vaapi-driver \
  libva-utils \
  vdpauinfo \
  libva-nvidia-driver

sudo systemctl daemon-reload
sudo dnf mark install akmod-nvidia
sudo systemctl enable nvidia-suspend nvidia-resume nvidia-hibernate
echo "%_with_kmod_nvidia_open 1" | sudo tee /etc/rpm/macros.nvidia-kmod
sudo akmods --kernels "$(uname -r)" --rebuild

# Setup ASUS Laptops
sudo dnf copr enable -y lukenukem/asus-linux
sudo dnf update --refresh -y
sudo dnf install -y --allowerasing asusctl supergfxctl power-profiles-daemon asusctl-rog-gui
sudo systemctl daemon-reload
sudo systemctl enable --now supergfxd.service power-profiles-daemon.service

# Install Package Groups
mapfile -t groups < <(grep -vE '^\s*#|^\s*$' groups.txt)
sudo dnf group install -y "${groups[@]}"

# Install Packages
mapfile -t packages < <(grep -vE '^\s*#|^\s*$' packages.txt)
sudo dnf install -y --allowerasing "${packages[@]}"

# Install Flatpaks
sudo dnf install -y flatpak
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
mapfile -t flatpaks < <(grep -vE '^\s*#|^\s*
PIA_INSTALLER=$(mktemp --suffix=.run)
trap "rm -f '$PIA_INSTALLER'" EXIT
wget -O "$PIA_INSTALLER" https://installers.privateinternetaccess.com/download/pia-linux-3.6.2-08398.run
chmod +x "$PIA_INSTALLER"
bash "$PIA_INSTALLER"

# Harden System
sudo tee /etc/issue > /dev/null <<'EOF'
-- WARNING -- This system is for the use of authorized users only. Individuals
using this computer system without authority or in excess of their authority
are subject to having all their activities on this system monitored and
recorded by system personnel. Anyone using this system expressly consents to
such monitoring and is advised that if such monitoring reveals possible
evidence of criminal activity system personal may provide the evidence of such
monitoring to law enforcement officials.
EOF

sudo cp /etc/issue /etc/issue.net

sudo tee /etc/security/limits.d/99-custom-limits.conf > /dev/null <<'EOF'
* soft nofile 65536
* hard nofile 1048576
EOF

sudo tee /etc/sysctl.d/99-custom-hardening.conf > /dev/null <<'EOF'
dev.tty.ldisc_autoload = 0
fs.protected_fifos = 2
fs.protected_regular = 2
fs.suid_dumpable = 0
kernel.kptr_restrict = 2
kernel.sysrq = 0
kernel.unprivileged_bpf_disabled = 1
kernel.yama.ptrace_scope = 2
net.core.bpf_jit_harden = 2
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
EOF

sudo sysctl -p /etc/sysctl.d/99-custom-hardening.conf
sudo dnf install -y psacct sysstat rng-tools haveged
sudo systemctl enable --now psacct sysstat rngd haveged

# Setup SSH
sudo systemctl enable --now sshd
sudo sed -i.bak 's/^\(GSSAPIKexAlgorithms.*\)/#\1/' /etc/crypto-policies/back-ends/openssh.config
sudo sed -i.bak 's/^\(GSSAPIAuthentication yes\)/#\1/' /etc/ssh/ssh_config.d/50-redhat.conf

sudo tee /etc/ssh/sshd_config.d/99-hardening.conf > /dev/null <<'EOF'
Port 47
LogLevel VERBOSE
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
TCPKeepAlive no
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 2
EOF

sudo firewall-cmd --add-port=47/tcp --permanent
sudo firewall-cmd --remove-service=ssh --permanent
sudo firewall-cmd --reload
sudo semanage port -a -t ssh_port_t -p tcp 47
sudo systemctl reload sshd

# Configure User
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global"

# Setup Hyprland
systemctl --user daemon-reload
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service

# Cleanup
sudo dnf autoremove -y

echo "Setup complete! Reboot is recommended."
 flatpaks.txt)
flatpak install -y --user flathub "${flatpaks[@]}"

# Install PIA VPN
PIA_INSTALLER=$(mktemp --suffix=.run)
trap "rm -f '$PIA_INSTALLER'" EXIT
wget -O "$PIA_INSTALLER" https://installers.privateinternetaccess.com/download/pia-linux-3.6.2-08398.run
chmod +x "$PIA_INSTALLER"
bash "$PIA_INSTALLER"

# Harden System
sudo tee /etc/issue > /dev/null << 'EOF'
-- WARNING -- This system is for the use of authorized users only. Individuals
using this computer system without authority or in excess of their authority
are subject to having all their activities on this system monitored and
recorded by system personnel. Anyone using this system expressly consents to
such monitoring and is advised that if such monitoring reveals possible
evidence of criminal activity system personal may provide the evidence of such
monitoring to law enforcement officials.
EOF

sudo cp /etc/issue /etc/issue.net

sudo tee /etc/security/limits.d/99-custom-limits.conf > /dev/null << 'EOF'
* soft nofile 65536
* hard nofile 1048576
EOF

sudo tee /etc/sysctl.d/99-custom-hardening.conf > /dev/null << 'EOF'
dev.tty.ldisc_autoload = 0
fs.protected_fifos = 2
fs.protected_regular = 2
fs.suid_dumpable = 0
kernel.kptr_restrict = 2
kernel.sysrq = 0
kernel.unprivileged_bpf_disabled = 1
kernel.yama.ptrace_scope = 2
net.core.bpf_jit_harden = 2
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
EOF

sudo sysctl -p /etc/sysctl.d/99-custom-hardening.conf
sudo dnf install -y psacct sysstat rng-tools haveged
sudo systemctl enable --now psacct sysstat rngd haveged

# Setup SSH
sudo systemctl enable --now sshd
sudo sed -i.bak 's/^\(GSSAPIKexAlgorithms.*\)/#\1/' /etc/crypto-policies/back-ends/openssh.config
sudo sed -i.bak 's/^\(GSSAPIAuthentication yes\)/#\1/' /etc/ssh/ssh_config.d/50-redhat.conf

sudo tee /etc/ssh/sshd_config.d/99-hardening.conf > /dev/null << 'EOF'
Port 47
LogLevel VERBOSE
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
TCPKeepAlive no
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 2
EOF

sudo firewall-cmd --add-port=47/tcp --permanent
sudo firewall-cmd --remove-service=ssh --permanent
sudo firewall-cmd --reload
sudo semanage port -a -t ssh_port_t -p tcp 47
sudo systemctl reload sshd

# Configure User
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global"

# Setup Hyprland
systemctl --user daemon-reload
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service

# Cleanup
sudo dnf autoremove -y

echo "Setup complete! Reboot is recommended."
