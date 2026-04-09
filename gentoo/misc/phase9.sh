#!/bin/bash
set -e

echo "Phase 9: Install ZFSBootMenu"

ZBM_VERSION="3.1.0"
mkdir -p /tmp/zfsbootmenu

SUPPORTED_KERNELS=("6.18" "6.19")
RUNNING_KERNEL=$(uname -r | cut -d'-' -f1 | cut -d'.' -f1-2)
echo "Running kernel: $RUNNING_KERNEL"

ZBM_KERNEL=""
for kernel in "${SUPPORTED_KERNELS[@]}"; do
  if [[ "$RUNNING_KERNEL" == "$kernel"* ]]; then
    ZBM_KERNEL="$kernel"
    break
  fi
done
if [[ -z "$ZBM_KERNEL" ]]; then
  ZBM_KERNEL="6.19"
  echo "Warning: No exact kernel match found. Using fallback kernel version $ZBM_KERNEL"
fi
echo "Using ZBM kernel: $ZBM_KERNEL"

DOWNLOAD_URL="https://github.com/zbm-dev/zfsbootmenu/releases/download/v${ZBM_VERSION}/zfsbootmenu-release-x86_64-v${ZBM_VERSION}-linux${ZBM_KERNEL}.tar.gz"
echo "Downloading from: $DOWNLOAD_URL"

curl -L -o /tmp/zfsbootmenu/zfsbootmenu-release.tar.gz "$DOWNLOAD_URL" || {
  echo "Download failed"
  exit 1
}

if file /tmp/zfsbootmenu/zfsbootmenu-release.tar.gz | grep -q "gzip compressed data"; then
  tar -xzf /tmp/zfsbootmenu/zfsbootmenu-release.tar.gz -C /tmp/zfsbootmenu
else
  echo "Not a valid gzip archive"
  exit 1
fi

mkdir -p /mnt/boot/efi/EFI/zbm
cp /tmp/zfsbootmenu/vmlinuz-bootmenu /mnt/boot/efi/EFI/zbm/vmlinuz-zbm
cp /tmp/zfsbootmenu/initramfs-bootmenu.img /mnt/boot/efi/EFI/zbm/initramfs-zbm.img

chroot /mnt efibootmgr --create --disk /dev/nvme0n1 --part 1 --label "ZFSBootMenu" \
  --loader "\\EFI\\zbm\\vmlinuz-zbm" \
  --unicode "initrd=\\EFI\\zbm\\initramfs-zbm.img root=ZFS=rpool/ROOT/fedora ro quiet"

mkdir -p /mnt/boot/efi/EFI/BOOT
cp /mnt/boot/efi/EFI/zbm/vmlinuz-zbm /mnt/boot/efi/EFI/BOOT/BOOTX64.EFI

echo "Phase 9 completed successfully."
