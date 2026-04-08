#!/bin/bash
set -e

echo "Phase 5: Bootstrap minimal Fedora system"

dnf --installroot=/mnt --releasever=43 group install -y custom-environment
dnf --installroot=/mnt --releasever=43 install -y dnf

dnf --installroot=/mnt --releasever=43 install -y --setopt=tsflags=noscripts kernel-core kernel-devel
kernel_ver=$(chroot /mnt rpm -q kernel-core --queryformat "%{VERSION}-%{RELEASE}.%{ARCH}" | head -1)
chroot /mnt depmod -a "${kernel_ver}"
chroot /mnt ln -sf "/usr/src/kernels/${kernel_ver}" "/lib/modules/${kernel_ver}/build"

dnf --installroot=/mnt --releasever=43 install -y dkms make gcc dracut dracut-config-generic efibootmgr NetworkManager curl neovim passwd shadow-utils sudo hostname grep sed gawk util-linux-core procps-ng which openssl zram-generator-defaults langpacks-core-en langpacks-en glibc-langpack-en policycoreutils selinux-policy-targeted selinux-policy-devel setroubleshoot dnf-utils gdisk

echo "Phase 5 completed successfully."
