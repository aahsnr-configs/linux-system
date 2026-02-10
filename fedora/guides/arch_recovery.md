# Chrooting into Existing Installation

This addendum provides instructions for accessing your installed system from a live Arch environment for maintenance, recovery, or troubleshooting purposes.

## When You Need This

- System won't boot and needs repair
- Forgot to install a critical package
- Need to regenerate initramfs after changes
- Kernel parameter adjustments
- Bootloader configuration fixes
- General system maintenance

## Prerequisites

- Bootable Arch Linux live USB
- Your LUKS encryption passphrase
- Network connection (if you need to download packages)

## Step-by-Step Chroot Process

### Step 1: Boot into Arch Live Environment

Boot from your Arch Linux USB and wait for the live environment to load.

### Step 2: Unlock the LUKS Encrypted Partition

```bash
# Unlock the LUKS container (you'll be prompted for your passphrase)
cryptsetup luksOpen /dev/nvme0n1p2 cryptlvm

# Verify it was unlocked successfully
ls -la /dev/mapper/
# You should see: cryptlvm
```

### Step 3: Activate LVM Volumes

```bash
# Scan for volume groups
vgscan

# Activate all volume groups
vgchange -ay

# Verify volumes are active
lvs
# You should see vg0/root and vg0/swap
```

### Step 4: Mount Btrfs Root Subvolume

```bash
# Mount options (same as installation)
BTRFS_OPTS="noatime,compress=zstd:3,space_cache=v2,discard=async"

# Mount the root @ subvolume first
# This makes all the directories (/home, /var, /boot, etc.) available
mount -o ${BTRFS_OPTS},subvol=@ /dev/mapper/vg0-root /mnt

# Verify the directories exist
ls -la /mnt
# You should see: bin, boot, dev, etc, home, opt, root, srv, tmp, usr, var, etc.
```

### Step 5: Mount All Other Subvolumes

**Important:** The directories already exist after mounting @ - you do NOT need to create them!

```bash
# Mount all subvolumes to their existing directories
mount -o ${BTRFS_OPTS},subvol=@home /dev/mapper/vg0-root /mnt/home
mount -o ${BTRFS_OPTS},subvol=@opt /dev/mapper/vg0-root /mnt/opt
mount -o ${BTRFS_OPTS},subvol=@tmp /dev/mapper/vg0-root /mnt/tmp
mount -o ${BTRFS_OPTS},subvol=@root /dev/mapper/vg0-root /mnt/root
mount -o ${BTRFS_OPTS},subvol=@srv /dev/mapper/vg0-root /mnt/srv
mount -o ${BTRFS_OPTS},subvol=@nix /dev/mapper/vg0-root /mnt/nix
mount -o ${BTRFS_OPTS},subvol=@usr@local /dev/mapper/vg0-root /mnt/usr/local
mount -o ${BTRFS_OPTS},subvol=@var /dev/mapper/vg0-root /mnt/var
mount -o ${BTRFS_OPTS},subvol=@var@cache /dev/mapper/vg0-root /mnt/var/cache
mount -o ${BTRFS_OPTS},subvol=@pkg /dev/mapper/vg0-root /mnt/var/cache/pacman/pkg
mount -o ${BTRFS_OPTS},subvol=@var@crash /dev/mapper/vg0-root /mnt/var/crash
mount -o ${BTRFS_OPTS},subvol=@var@tmp /dev/mapper/vg0-root /mnt/var/tmp
mount -o ${BTRFS_OPTS},subvol=@var@spool /dev/mapper/vg0-root /mnt/var/spool
mount -o ${BTRFS_OPTS},subvol=@var@log /dev/mapper/vg0-root /mnt/var/log
mount -o ${BTRFS_OPTS},subvol=@var@log@audit /dev/mapper/vg0-root /mnt/var/log/audit
mount -o ${BTRFS_OPTS},subvol=@snapshots /dev/mapper/vg0-root /mnt/.snapshots
```

### Step 6: Mount ESP

```bash
# Mount the EFI System Partition
mount /dev/nvme0n1p1 /mnt/boot
```

### Step 7: Enable Swap (Optional)

```bash
# If you need swap during maintenance
swapon /dev/mapper/vg0-swap
```

### Step 8: Verify All Mounts

```bash
# Check that everything is mounted correctly
mount | grep /mnt

# Check block devices
lsblk
```

You should see all subvolumes and /boot mounted under /mnt, similar to this:

```
/dev/mapper/vg0-root on /mnt type btrfs (subvol=/@)
/dev/mapper/vg0-root on /mnt/home type btrfs (subvol=/@home)
/dev/mapper/vg0-root on /mnt/opt type btrfs (subvol=/@opt)
...
/dev/nvme0n1p1 on /mnt/boot type vfat
```

### Step 9: Chroot into the System

```bash
# Enter the chroot environment
# arch-chroot automatically handles /dev, /proc, /sys mounting
arch-chroot /mnt
```

You are now inside your installed system and can perform maintenance.

## Common Maintenance Tasks

### Regenerate Initramfs

```bash
# If you made changes to dracut configuration
limine-dracut
```

### Update System

```bash
# Update all packages
pacman -Syu
```

### Fix Bootloader

```bash
# If Limine needs to be reinstalled
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI

# Regenerate boot entries
limine-dracut
```

### Check/Fix Kernel Parameters

```bash
# View current configuration
cat /etc/default/limine

# Edit if needed
nano /etc/default/limine

# Apply changes
limine-dracut
```

### Repair Snapper Configuration

```bash
# List snapshots
snapper list

# Check snapper configuration
cat /etc/snapper/configs/root

# Restart snapper services if needed
systemctl restart snapper-timeline.timer
systemctl restart snapper-cleanup.timer
systemctl restart limine-snapper-sync.service
```

### Reset User Password

```bash
# Reset password for user
passwd ahsan

# Reset root password
passwd
```

### Fix Broken Package Database

```bash
# If pacman database is corrupted
rm /var/lib/pacman/db.lck
pacman -Syy
```

## Exiting the Chroot Environment

### Step 1: Exit Chroot

```bash
# Exit the chroot
exit
```

### Step 2: Unmount Everything

```bash
# Unmount all filesystems (recursive unmount)
umount -R /mnt

# Turn off swap if enabled
swapoff /dev/mapper/vg0-swap
```

### Step 3: Deactivate LVM

```bash
# Deactivate volume group
vgchange -an vg0
```

### Step 4: Close LUKS Container

```bash
# Close the encrypted container
cryptsetup close cryptlvm
```

### Step 5: Reboot

```bash
# Remove the live USB and reboot
reboot
```

## Troubleshooting Chroot Issues

### Can't Find LUKS Device

```bash
# List all block devices
lsblk

# If using a different disk name (e.g., /dev/sda instead of /dev/nvme0n1)
cryptsetup luksOpen /dev/sdX2 cryptlvm
```

### Volume Group Not Found

```bash
# Manually scan for volume groups
vgscan --mknodes

# Activate specific volume group
vgchange -ay vg0

# If still not found, check LUKS was opened correctly
ls -la /dev/mapper/
```

### Mount Fails - "Directory Not Found"

This should not happen if you mounted @ first. If it does:

```bash
# Verify @ is mounted
mount | grep "on /mnt "

# Check what directories exist
ls -la /mnt

# If directories are missing, your @ subvolume might be corrupted
# Try mounting the top-level volume to investigate
umount /mnt
mount -o subvolid=5 /dev/mapper/vg0-root /mnt
btrfs subvolume list /mnt
```

### Can't Access Internet in Chroot

```bash
# Before chroot, copy DNS configuration
cp /etc/resolv.conf /mnt/etc/resolv.conf

# After chroot, if still no network
systemctl start NetworkManager
```

### arch-chroot Says "/mnt/proc mount point does not exist"

This means @ wasn't mounted correctly or is corrupted:

```bash
# Verify @ has the correct filesystem structure
ls -la /mnt
# Should show: bin, boot, dev, etc, home, lib, opt, proc, root, run, sbin, srv, sys, tmp, usr, var

# If proc, sys, dev directories don't exist, your @ subvolume is damaged
```

## Quick Reference Script

For convenience, here's a complete script for chrooting:

```bash
#!/bin/bash
# Quick chroot script for the custom Arch installation

set -e  # Exit on error

echo "=== Unlocking LUKS ==="
cryptsetup luksOpen /dev/nvme0n1p2 cryptlvm

echo "=== Activating LVM ==="
vgscan
vgchange -ay vg0

echo "=== Mounting Btrfs subvolumes ==="
# Mount options
BTRFS_OPTS="noatime,compress=zstd:3,space_cache=v2,discard=async"

# Mount root first (this creates all directories)
mount -o ${BTRFS_OPTS},subvol=@ /dev/mapper/vg0-root /mnt

# Mount all other subvolumes to existing directories
mount -o ${BTRFS_OPTS},subvol=@home /dev/mapper/vg0-root /mnt/home
mount -o ${BTRFS_OPTS},subvol=@opt /dev/mapper/vg0-root /mnt/opt
mount -o ${BTRFS_OPTS},subvol=@tmp /dev/mapper/vg0-root /mnt/tmp
mount -o ${BTRFS_OPTS},subvol=@root /dev/mapper/vg0-root /mnt/root
mount -o ${BTRFS_OPTS},subvol=@srv /dev/mapper/vg0-root /mnt/srv
mount -o ${BTRFS_OPTS},subvol=@nix /dev/mapper/vg0-root /mnt/nix
mount -o ${BTRFS_OPTS},subvol=@usr@local /dev/mapper/vg0-root /mnt/usr/local
mount -o ${BTRFS_OPTS},subvol=@var /dev/mapper/vg0-root /mnt/var
mount -o ${BTRFS_OPTS},subvol=@var@cache /dev/mapper/vg0-root /mnt/var/cache
mount -o ${BTRFS_OPTS},subvol=@pkg /dev/mapper/vg0-root /mnt/var/cache/pacman/pkg
mount -o ${BTRFS_OPTS},subvol=@var@crash /dev/mapper/vg0-root /mnt/var/crash
mount -o ${BTRFS_OPTS},subvol=@var@tmp /dev/mapper/vg0-root /mnt/var/tmp
mount -o ${BTRFS_OPTS},subvol=@var@spool /dev/mapper/vg0-root /mnt/var/spool
mount -o ${BTRFS_OPTS},subvol=@var@log /dev/mapper/vg0-root /mnt/var/log
mount -o ${BTRFS_OPTS},subvol=@var@log@audit /dev/mapper/vg0-root /mnt/var/log/audit
mount -o ${BTRFS_OPTS},subvol=@snapshots /dev/mapper/vg0-root /mnt/.snapshots

echo "=== Mounting ESP ==="
mount /dev/nvme0n1p1 /mnt/boot

echo "=== Enabling swap ==="
swapon /dev/mapper/vg0-swap

echo "=== Mounted filesystems ==="
mount | grep /mnt

echo ""
echo "=== Block devices ==="
lsblk

echo ""
echo "=== Entering chroot ==="
arch-chroot /mnt
```

Save this as `chroot-system.sh`, make it executable with `chmod +x chroot-system.sh`, and run it when needed.

## Exit Script

For exiting cleanly:

```bash
#!/bin/bash
# Clean exit from chroot

echo "=== Unmounting filesystems ==="
umount -R /mnt

echo "=== Disabling swap ==="
swapoff /dev/mapper/vg0-swap

echo "=== Deactivating LVM ==="
vgchange -an vg0

echo "=== Closing LUKS ==="
cryptsetup close cryptlvm

echo "=== Done ==="
echo "System safely unmounted and locked. You can now reboot."
```

Save as `exit-chroot.sh` and run after exiting the chroot.

## Key Difference from Installation

**During installation:** You create empty subvolumes, then manually create all directories with `mkdir -p` before mounting.

**During chroot/recovery:** The directories already exist in the @ subvolume from your installation. You only need to mount the @ subvolume first, which exposes all existing directories, then mount the other subvolumes to those existing directories.
