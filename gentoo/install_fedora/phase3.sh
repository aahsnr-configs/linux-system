set -e

echo "Phase 3: Create ZFS pool (RAID0) and encrypted datasets"

zpool create -f -o ashift=12 -o autotrim=on \
  -O compression=zstd -O acltype=posixacl -O xattr=sa -O mountpoint=/ -R /mnt \
  rpool /dev/nvme0n1p2 /dev/nvme1n1p1

zfs create -o mountpoint=none rpool/ROOT

# Prompt for encryption passphrase
zfs create -o encryption=aes-256-gcm -o keyformat=passphrase -o keylocation=prompt -o mountpoint=/ rpool/ROOT/fedora

zfs get keystatus rpool/ROOT/fedora

zfs create -o mountpoint=/home rpool/home
zfs create -o mountpoint=/var rpool/var

zfs create -V 32G -o volblocksize=16K -o compression=zle -o logbias=throughput \
  -o sync=always -o primarycache=metadata -o secondarycache=none \
  -o com.sun:auto-snapshot=false rpool/swap

mkfs.vfat -F 32 /dev/nvme0n1p1
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi

echo "Phase 3 completed successfully."
