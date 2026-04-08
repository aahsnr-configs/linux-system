#!/bin/bash
chroot /mnt dnf install -y --setopt=tsflags=noscripts zfs zfs-dracut zfs-dkms

echo "Phase 6 completed successfully."
