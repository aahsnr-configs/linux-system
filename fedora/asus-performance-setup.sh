#!/bin/bash
# ASUS G14 Performance Setup Script
# Runs as root via systemd service

# Wait for system initialization
sleep 5

# Set PPT limits via ASUS Armoury firmware attributes (kernel 6.19+)
PPT_PL1="/sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl1_spl/current_value"
PPT_PL2="/sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl2_sppt/current_value"

if [ -f "$PPT_PL1" ] && [ -f "$PPT_PL2" ]; then
    echo 34 > "$PPT_PL1"
    echo 53 > "$PPT_PL2"
    sleep 2
fi

# Apply ryzenadj thermal and power limits
if command -v ryzenadj &> /dev/null; then
    ryzenadj --tctl-temp=85 --stapm-limit=34000 --fast-limit=53000 --slow-limit=44000 2>/dev/null
fi

exit 0
