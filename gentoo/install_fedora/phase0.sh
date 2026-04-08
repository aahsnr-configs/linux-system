#!/bin/bash
set -e

echo "Phase 0: Preparation – Boot and Initial Checks"

# Verify internet connectivity
ping -c2 8.8.8.8 || {
  echo "No internet"
  exit 1
}

# Check NVMe drives
lsblk | grep nvme || {
  echo "NVMe drives not found"
  exit 1
}

read -p "Are you sure you want to wipe /dev/nvme0n1 and /dev/nvme1n1? Type YES: " confirm
if [[ "$confirm" != "YES" ]]; then
  echo "Aborted."
  exit 1
fi

echo "Phase 0 completed successfully."
