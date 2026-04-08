#!/bin/bash
set -e

echo "Phase 10: Cleanup and reboot"

umount /mnt/dev
umount /mnt/proc
umount /mnt/sys
umount /mnt/run
umount /mnt/tmp
umount /mnt/boot/efi
zpool export rpool

echo "Rebooting in 5 seconds... Press Ctrl+C to abort."
sleep 5
reboot
