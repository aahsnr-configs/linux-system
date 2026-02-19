#!/bin/bash
# Harden System
sudo tee /etc/issue >/dev/null <<'EOF'
-- WARNING -- This system is for the use of authorized users only. Individuals
using this computer system without authority or in excess of their authority
are subject to having all their activities on this system monitored and
recorded by system personnel. Anyone using this system expressly consents to
such monitoring and is advised that if such monitoring reveals possible
evidence of criminal activity system personal may provide the evidence of such
monitoring to law enforcement officials.
EOF

sudo systemctl enable bluetooth power-profiles-daemon

sudo cp /etc/issue /etc/issue.net

# sudo tee /etc/security/limits.d/99-custom-limits.conf >/dev/null <<'EOF'
# * soft nofile 65536
# * hard nofile 1048576
# EOF
