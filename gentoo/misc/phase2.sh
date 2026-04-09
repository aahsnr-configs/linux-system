#!/bin/bash
set -e

echo "Phase 2: Partition the two NVMe drives"

wipefs -a /dev/nvme0n1
wipefs -a /dev/nvme1n1

sgdisk -Z /dev/nvme0n1
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" /dev/nvme0n1
sgdisk -n 2:0:0 -t 2:bf01 -c 2:"ZFS" /dev/nvme0n1

sgdisk -Z /dev/nvme1n1
sgdisk -n 1:0:0 -t 1:bf01 -c 1:"ZFS" /dev/nvme1n1

partprobe /dev/nvme0n1
partprobe /dev/nvme1n1
sleep 2

lsblk /dev/nvme0n1
lsblk /dev/nvme1n1

echo "Phase 2 completed successfully."
