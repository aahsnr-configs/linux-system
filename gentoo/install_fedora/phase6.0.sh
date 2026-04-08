#!/bin/bash

echo "Phase 6: Install ZFS inside the chroot"

chroot /mnt dnf install -y --nogpgcheck \
  "https://zfsonlinux.org/fedora/zfs-release-3-0$(rpm --eval "%{dist}").noarch.rpm"

mkdir -p /var/tmp/zfs-build
mount -t tmpfs -o size=4g tmpfs /var/tmp/zfs-build

if chroot /mnt dnf config-manager setopt zfs-latest.enabled=1 &>/dev/null; then
  echo OK
else
  chroot /mnt sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/zfs-latest.repo
fi

#chroot /mnt dnf install -y --setopt=tsflags=noscripts zfs zfs-dracut

echo "Check zfs-latest is enabled in /etc/yum.repos.d/zfs-latest.repo"
