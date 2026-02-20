#!/bin/bash
# ASUS G14 Performance Configuration Script
# Place this where your autostart mechanism can execute it

# Wait for system to fully initialize
sleep 5

# Set PPT limits (kernel 6.19 paths)
echo 34 > /sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl1_spl/current_value
echo 53 > /sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl2_sppt/current_value

# Wait for PPT to apply
sleep 2

# Set thermal target and power limits via ryzenadj
/usr/bin/ryzenadj --tctl-temp=85 --stapm-limit=34000 --fast-limit=53000 --slow-limit=44000

# Log completion (optional)
echo "$(date): ASUS performance settings applied" >> /tmp/asus-perf.log
