#!/bin/bash
set -e

echo "Phase 1: Install ZFS tools in the live environment"

dnf install -y curl dnf-utils gdisk

mkdir -p /var/tmp/zfs-build
mount -t tmpfs -o size=4g tmpfs /var/tmp/zfs-build

rpm -q zfs-fuse && rpm -e --nodeps zfs-fuse || true

dnf install -y --nogpgcheck --setopt=install_weak_deps=False \
  "https://zfsonlinux.org/fedora/zfs-release-3-0$(rpm --eval "%{dist}").noarch.rpm"

if dnf config-manager setopt zfs-latest.enabled=1 &>/dev/null; then
  echo "Enabled via config-manager"
else
  sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/zfs-latest.repo
fi

dnf install -y --setopt=install_weak_deps=False \
  "kernel-devel-$(uname -r | awk -F'-' '{print $1}')" ||
  dnf install -y kernel-devel

dnf install -y zfs

modprobe zfs

echo "Phase 1 completed successfully."
