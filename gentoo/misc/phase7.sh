#!/bin/bash

# echo "Phase 7: Configure the target system (chroot)"
#
# # Step 44: Generate hostid (use -f flag to force overwrite if needed)
chroot /mnt zgenhostid -f "$(hostid)"

# Step 45: Set hostname (interactive)
hostname=${workstation}
echo "$hostname" >/mnt/etc/hostname

# Step 46: Create /etc/hosts
cat >/mnt/etc/hosts <<'EOF'
127.0.0.1   localhost localhost.localdomain
::1         localhost localhost.localdomain
127.0.1.1   workstation.localdomain workstation
EOF

# Step 47: Set locale
echo "LANG=en_US.UTF-8" >/mnt/etc/locale.conf
chroot /mnt localectl set-locale "LANG=en_US.UTF-8"

# Step 48: Set timezone (interactive)
ln -sf "/usr/share/zoneinfo/Asia/Dhaka" /mnt/etc/localtime

# Step 49: Enable system services (including additional ZFS targets)
chroot /mnt systemctl enable zfs-import-cache.service
chroot /mnt systemctl enable zfs-mount.service
chroot /mnt systemctl enable zfs.target
chroot /mnt systemctl enable zfs-import.target
chroot /mnt systemctl enable zfs.target
chroot /mnt systemctl enable NetworkManager

# Step 50: Configure dracut for ZFS
mkdir -p /mnt/etc/dracut.conf.d
cat >/mnt/etc/dracut.conf.d/zfs.conf <<'EOF'
add_dracutmodules+=" zfs "
omit_dracutmodules+=" btrfs "
hostonly="no"
EOF

# Step 51: Load ZFS module at boot
echo "zfs" >/mnt/etc/modules-load.d/zfs.conf

# Step 52: Apply sysctl tuning
cat >/mnt/etc/sysctl.d/99-zfs.conf <<'EOF'
vm.zone_reclaim_mode = 0
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.vfs_cache_pressure = 200
EOF

# Step 53: Set up /tmp as tmpfs (50% of RAM)
total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
tmpfs_size_kb=$((total_ram_kb * 50 / 100))
echo "tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev,size=${tmpfs_size_kb}k 0 0" >>/mnt/etc/fstab
mkdir -p /mnt/tmp
chmod 1777 /mnt/tmp

# Step 54: Enable swap on the zvol
mkswap -L "swap" /dev/zvol/rpool/swap
echo "/dev/zvol/rpool/swap none swap defaults 0 0" >>/mnt/etc/fstab

# Step 55: Configure SELinux (enforcing + ensure autorelabel works on Fedora 43)
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /mnt/etc/selinux/config
sed -i 's/^SELINUXTYPE=.*/SELINUXTYPE=targeted/' /mnt/etc/selinux/config
# Use fixfiles -B onboot as the recommended method for Fedora 43
chroot /mnt fixfiles -B onboot

# Step 56: Rebuild initramfs
modprobe zfs
kernel_ver=$(chroot /mnt rpm -q kernel-core --queryformat "%{VERSION}-%{RELEASE}.%{ARCH}")
chroot /mnt dracut --force --verbose --no-hostonly "/boot/initramfs-${kernel_ver}.img" "${kernel_ver}"

echo "Phase 7 completed successfully."
