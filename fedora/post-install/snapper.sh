#!/bin/bash
paru -S --needed --noconfirm snapper inotify-tools
sudo umount /.snapshots
sudo rm -rf /.snapshots
sudo snapper -c root create-config /
sudo btrfs subvolume delete /.snapshots
sudo mkdir /.snapshots
sudo mount /.snapshots
mount | grep snapshots
sudo chmod 750 /.snapshots
sudo chown root:root /.snapshots

ROOT_SUBVOL_ID=$(sudo btrfs subvolume list / | grep "path @$" | awk '{print $2}')
echo "Root subvolume ID: $ROOT_SUBVOL_ID"
sudo btrfs subvolume set-default ${ROOT_SUBVOL_ID} /

paru -S --needed --noconfirm snap-pac limine-snapper-sync

# Enable Snapper timers
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer

# Verify services are running
sudo systemctl status snapper-timeline.timer
sudo systemctl status snapper-cleanup.timer

# Enable and start the service
sudo systemctl enable --now limine-snapper-sync.service

# Verify it's running
sudo systemctl status limine-snapper-sync.service

# Create a baseline snapshot after installation
sudo snapper -c root create --description "Fresh Installation - Post Snapper Setup"

# List snapshots to verify
sudo snapper list

sudo limine-snapper-sync
