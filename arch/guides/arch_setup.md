# Custom Arch Linux Installation - CachyOS-Style with Dracut + Limine + Bootable Snapshots

This guide creates a custom Arch Linux installation that replicates CachyOS features using:

- Full disk encryption (LUKS2 on LVM)
- Optimized Btrfs with extensive subvolume layout
- Dracut for initramfs generation (required for bootable btrfs snapshots)
- Limine bootloader (faster than GRUB, especially with encryption)
- Snapper with bootable snapshots via limine-snapper-sync
- Automatic snapshot creation before system updates
- CachyOS optimized repositories and kernel

## Prerequisites

- Boot into Arch Linux live environment
- Working network connection
- UEFI system (not BIOS/Legacy)

## Part 1: Disk Partitioning and Encryption Setup

### 1.1 Partition the Disk

```bash
cfdisk /dev/nvme0n1
```

Create two partitions:

- `/dev/nvme0n1p1` - **2GB**, type: EFI System (ESP - needs space for multiple kernels + snapshots)
- `/dev/nvme0n1p2` - Remaining space, type: Linux LVM

### 1.2 Create and Configure Encrypted LVM

```bash
# Format ESP
mkfs.vfat -F 32 /dev/nvme0n1p1

# Create LUKS2 encrypted container
cryptsetup --cipher aes-xts-plain64 \
           --hash sha512 \
           --use-random \
           --verify-passphrase \
           luksFormat /dev/nvme0n1p2

# Open the encrypted container
cryptsetup luksOpen /dev/nvme0n1p2 cryptlvm

# Create physical volume and volume group
pvcreate /dev/mapper/cryptlvm
vgcreate vg0 /dev/mapper/cryptlvm

# Create logical volumes
lvcreate -L 24G vg0 -n swap
lvcreate -l 100%FREE vg0 -n root

# Format volumes
mkfs.btrfs -f /dev/vg0/root
mkswap /dev/vg0/swap

# Initial mount
mount /dev/vg0/root /mnt
swapon /dev/vg0/swap
```

## Part 2: Btrfs Subvolume Layout

### 2.1 Create Comprehensive Subvolume Structure

This layout ensures snapshots only capture the root system while excluding caches, logs, home, and other data.

```bash
# Create all subvolumes
btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@opt
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@root
btrfs su cr /mnt/@srv
btrfs su cr /mnt/@nix
btrfs su cr /mnt/@usr@local
btrfs su cr /mnt/@var
btrfs su cr /mnt/@var@cache
btrfs su cr /mnt/@pkg
btrfs su cr /mnt/@var@crash
btrfs su cr /mnt/@var@tmp
btrfs su cr /mnt/@var@spool
btrfs su cr /mnt/@var@log
btrfs su cr /mnt/@var@log@audit
btrfs su cr /mnt/@snapshots

# Unmount to remount with proper options
umount /mnt
```

### 2.2 Mount Subvolumes with Optimal Options

```bash
# Mount options for performance and compression (matching CachyOS defaults)
BTRFS_OPTS="noatime,compress=zstd:3,space_cache=v2,discard=async"

# Mount root subvolume
mount -o ${BTRFS_OPTS},subvol=@ /dev/vg0/root /mnt

# Create mount points and mount all subvolumes
mkdir -p /mnt/{home,opt,tmp,root,srv,nix,usr/local,var/{cache/pacman/pkg,crash,tmp,spool,log/audit},.snapshots,boot}

mount -o ${BTRFS_OPTS},subvol=@home /dev/vg0/root /mnt/home
mount -o ${BTRFS_OPTS},subvol=@opt /dev/vg0/root /mnt/opt
mount -o ${BTRFS_OPTS},subvol=@tmp /dev/vg0/root /mnt/tmp
mount -o ${BTRFS_OPTS},subvol=@root /dev/vg0/root /mnt/root
mount -o ${BTRFS_OPTS},subvol=@srv /dev/vg0/root /mnt/srv
mount -o ${BTRFS_OPTS},subvol=@nix /dev/vg0/root /mnt/nix
mount -o ${BTRFS_OPTS},subvol=@usr@local /dev/vg0/root /mnt/usr/local
mount -o ${BTRFS_OPTS},subvol=@var /dev/vg0/root /mnt/var
mount -o ${BTRFS_OPTS},subvol=@var@cache /dev/vg0/root /mnt/var/cache
mount -o ${BTRFS_OPTS},subvol=@pkg /dev/vg0/root /mnt/var/cache/pacman/pkg
mount -o ${BTRFS_OPTS},subvol=@var@crash /dev/vg0/root /mnt/var/crash
mount -o ${BTRFS_OPTS},subvol=@var@tmp /dev/vg0/root /mnt/var/tmp
mount -o ${BTRFS_OPTS},subvol=@var@spool /dev/vg0/root /mnt/var/spool
mount -o ${BTRFS_OPTS},subvol=@var@log /dev/vg0/root /mnt/var/log
mount -o ${BTRFS_OPTS},subvol=@var@log@audit /dev/vg0/root /mnt/var/log/audit
mount -o ${BTRFS_OPTS},subvol=@snapshots /dev/vg0/root /mnt/.snapshots

# Mount ESP
mount /dev/nvme0n1p1 /mnt/boot

# Enable swap
swapon /dev/vg0/swap
```

### 2.3 Disable Copy-on-Write for Specific Directories

```bash
# IMPORTANT: Must be done on EMPTY directories BEFORE any files are created
# This disables CoW (and compression) for these directories only

# Disable CoW on directories with frequent writes
chattr +C /mnt/var/log
chattr +C /mnt/var/cache
chattr +C /mnt/var/tmp

# If you plan to use virtual machines, also disable for VM images:
# mkdir -p /mnt/var/lib/libvirt/images
# chattr +C /mnt/var/lib/libvirt/images

# If you plan to use databases, also disable for database directories:
# mkdir -p /mnt/var/lib/mysql
# chattr +C /mnt/var/lib/mysql
# mkdir -p /mnt/var/lib/postgres
# chattr +C /mnt/var/lib/postgres

# Verify the attributes were set (should show 'C' in the output)
lsattr -d /mnt/var/log /mnt/var/cache /mnt/var/tmp
```

## Part 3: Base System Installation

### 3.1 Install Base Packages

```bash
# Install essential packages including dracut
pacstrap -K /mnt base base-devel neovim git wget curl btrfs-progs lvm2 cryptsetup dracut networkmanager sudo

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
arch-chroot /mnt
```

### 3.2 Basic System Configuration

```bash
# Set timezone (adjust to your location)
ln -sf /usr/share/zoneinfo/Asia/Dhaka /etc/localtime
hwclock --systohc

# Configure locales
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "archlinux" > /etc/hostname

# Configure hosts file
cat >> /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   zephyrus.localdomain archlinux
EOF

# Set root password
passwd

# Create user account
useradd -m -G users,wheel,audio,video -s /bin/bash ahsan
passwd ahsan

# Configure sudo
EDITOR=nvim visudo
```

## Part 4: Setup CachyOS Repositories

This gives you access to optimized packages and the CachyOS kernel.

### 4.1 Install CachyOS Keyring and Repositories

```bash
# Download and install CachyOS repositories (while in chroot)
cd /tmp
curl -O https://mirror.cachyos.org/cachyos-repo.tar.xz
tar xvf cachyos-repo.tar.xz
cd cachyos-repo
./cachyos-repo.sh

pacman -Syyuu
```

## Part 5: Configure Dracut for LUKS+LVM+Btrfs

### 5.1 Get Your UUIDs

```bash
# Get LUKS UUID (the partition, not the mapper)
LUKS_UUID=$(cryptsetup luksDump /dev/nvme0n1p2 | grep "UUID:" | head -1 | awk '{print $2}')
echo "LUKS UUID: $LUKS_UUID"

# Get root filesystem UUID (the mapper device)
ROOT_UUID=$(blkid -s UUID -o value /dev/mapper/vg0-root)
echo "Root UUID: $ROOT_UUID"

# Get swap UUID
SWAP_UUID=$(blkid -s UUID -o value /dev/mapper/vg0-swap)
echo "Swap UUID: $SWAP_UUID"

# Save these for later
echo "LUKS_UUID=$LUKS_UUID" > /tmp/uuids.txt
echo "ROOT_UUID=$ROOT_UUID" >> /tmp/uuids.txt
echo "SWAP_UUID=$SWAP_UUID" >> /tmp/uuids.txt
cat /tmp/uuids.txt
```

### 5.2 Create Dracut Configuration Files

**Main dracut configuration:**

```bash
cat > /etc/dracut.conf.d/custom.conf << 'EOF'
# Host-only mode for smaller, faster initramfs
hostonly="yes"

# Let dracut auto-detect and embed kernel parameters from system config
hostonly_cmdline="yes"

# Compression
compress="zstd"

# Add required modules for LUKS + LVM + Btrfs + Resume
add_dracutmodules+=" crypt dm lvm rootfs-block resume "

# Omit unnecessary modules
omit_dracutmodules+=" network cifs nfs nbd brltty "

# Force inclusion of btrfs driver
force_drivers+=" btrfs "

# Use fstab for mounting
use_fstab="yes"

# Show modules during build (helpful for debugging)
show_modules="yes"
EOF
```

### 5.3 Configure /etc/crypttab

This is CRITICAL for dracut to properly unlock LUKS:

```bash
# Create crypttab entry
# Format: mapper-name UUID=<uuid> none luks
cat > /etc/crypttab << EOF
# <name>    <device>                                  <password>  <options>
cryptlvm    UUID=${LUKS_UUID}                         none        luks,discard
EOF

# Verify
cat /etc/crypttab
```

### 5.4 Verify /etc/fstab

Make sure your fstab has correct UUIDs:

```bash
cat /etc/fstab
```

It should look like:

```
# /dev/mapper/vg0-root
UUID=<ROOT_UUID>  /  btrfs  rw,noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=/@  0 0

# /dev/mapper/vg0-root
UUID=<ROOT_UUID>  /home  btrfs  rw,noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=/@home  0 0

# ... (other subvolume mounts)

# /dev/mapper/vg0-swap
UUID=<SWAP_UUID>  none  swap  defaults  0 0

# /dev/nvme0n1p1
UUID=<ESP_UUID>  /boot  vfat  rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro  0 2
```

## Part 6: Install and Configure Limine Bootloader

### 6.1 Install Limine, Java, and AUR Helper

```bash
# Install Limine and Java from official repos
pacman -S limine jdk-openjdk paru

# Temporarily allow user to run sudo without password
echo "ahsan ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers.d/temp_install
chmod 440 /etc/sudoers.d/temp_install

# Remove temporary passwordless sudo
rm /etc/sudoers.d/temp_install
```

### 6.2 Install limine-dracut-support

**CRITICAL:** This package integrates Limine with dracut and provides the `limine-dracut` command.

```bash
echo "ahsan ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers.d/temp_install
chmod 440 /etc/sudoers.d/temp_install

sudo -u ahsan paru -S limine-dracut-support --noconfirm

# Remove temporary passwordless sudo
rm /etc/sudoers.d/temp_install
```

### 6.3 Deploy Limine to ESP

```bash
# Create Limine directories on ESP
mkdir -p /boot/EFI/BOOT
mkdir -p /boot/EFI/arch-limine

# Copy Limine EFI binaries
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/arch-limine/BOOTX64.EFI

# Register with UEFI (creates named boot entry)
efibootmgr --create --disk /dev/nvme0n1 --part 1 \
    --label "Arch Linux (Limine)" \
    --loader /EFI/arch-limine/BOOTX64.EFI
```

### 6.4 Configure Limine (/etc/default/limine)

This is where you set kernel parameters for dracut:

```bash
# The variables from section 5.1 are still active in this shell session
# Verify they are set
echo "LUKS UUID: $LUKS_UUID"
echo "Root UUID: $ROOT_UUID"
echo "Swap UUID: $SWAP_UUID"

# If variables are not set, source them:
# source /tmp/uuids.txt

# Create Limine configuration with dracut syntax
cat > /etc/default/limine << EOF
# ESP Path
ESP_PATH="/boot"

# Kernel command line parameters (dracut syntax!)
# Note: With hostonly_cmdline="yes", dracut auto-detects parameters from
# /etc/crypttab and /etc/fstab, but we specify them here for explicit control

# Basic boot parameters
KERNEL_CMDLINE[default]+="quiet loglevel=3 rw"

# Btrfs root subvolume
KERNEL_CMDLINE[default]+="rootflags=subvol=/@"

# LUKS unlock parameters
KERNEL_CMDLINE[default]+="rd.luks.uuid=${LUKS_UUID}"
KERNEL_CMDLINE[default]+="rd.luks.name=${LUKS_UUID}=cryptlvm"

# LVM activation (uses VG/LV names, NOT UUIDs)
KERNEL_CMDLINE[default]+="rd.lvm.lv=vg0/root"
KERNEL_CMDLINE[default]+="rd.lvm.lv=vg0/swap"

# Root filesystem (uses UUID - recommended by dracut documentation)
KERNEL_CMDLINE[default]+="root=UUID=${ROOT_UUID}"

# Resume from swap (uses UUID - recommended)
KERNEL_CMDLINE[default]+="resume=UUID=${SWAP_UUID}"

# Enable TRIM/discard for SSD on LUKS
KERNEL_CMDLINE[default]+="rd.luks.allow-discards"

# Boot order (* means all main kernels)
BOOT_ORDER="*, *lts, *fallback, Snapshots"

# Commands to run before/after saving config
# These ensure Limine bootloader files are properly enrolled
COMMANDS_BEFORE_SAVE="limine-reset-enroll"
COMMANDS_AFTER_SAVE="limine-enroll-config"
EOF

# Verify configuration was created correctly
cat /etc/default/limine
```

### 6.5 Initial Dracut Image Generation

```bash
# Generate initramfs using limine-dracut command
# This will:
# - Run dracut with proper options
# - Create /boot/limine.conf
# - Add kernel entries to Limine
limine-dracut

# Expected output should list all modules being included, including:
# - systemd-cryptsetup (LUKS unlock)
# - lvm (LVM support)
# - btrfs (Btrfs filesystem)
# - crypt (encryption)
# - resume (hibernation support)
# - btrfs-snapshot-overlay (CRITICAL for bootable snapshots)
#
# You should see:
# Building initramfs for linux-cachyos (or linux)
# [list of modules]
# Kernel stored in: /boot/[hash]/linux-cachyos/vmlinuz-linux-cachyos
# Initramfs stored in: /boot/[hash]/linux-cachyos/initramfs-linux-cachyos
# Updated: /boot/limine.conf

# Verify Limine configuration was created
ls -la /boot/limine.conf
cat /boot/limine.conf
```

## Part 7: Install CachyOS Kernel (Optional but Recommended)

```bash
pacman -S linux-cachyos linux-cachyos-headers
limine-dracut
cat /boot/limine.conf
```

## Part 8: Final System Configuration

### 8.1 Install Essential Packages

```bash
pacman -S sof-firmware mesa vulkan-radeon nvidia-open-dkms nvidia-utils  chrony power-profiles-daemon  exfatprogs unrar unzip p7zip zip smartmontools pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber alsa-utils bluez bluez-utils lshw usbutils pciutils acpi thermald exfatprogs unrar unzip zip p7zip

```

### 8.2 Enable Essential Services

```bash
systemctl enable NetworkManager fstrim.timer chronyd power-profiles-daemon auditd sshd bluetooth
```

### 8.2 Final Verification

```bash
# Check that Limine configuration exists
cat /boot/limine.conf

# Verify crypttab
cat /etc/crypttab

# Verify fstab
cat /etc/fstab

# Verify dracut was configured properly
ls -la /etc/dracut.conf.d/

# Test that limine-dracut command works
limine-dracut
```

## Part 9: Exit and Reboot

```bash
# Exit chroot
exit

# Unmount all
umount -R /mnt
swapoff /dev/mapper/vg0-swap

# Close encrypted volume
vgchange -an vg0
cryptsetup close cryptlvm

# Reboot
reboot
```

---

# POST-INSTALLATION: First Boot Configuration

**IMPORTANT:** The following steps must be completed AFTER you have rebooted into your new system. Snapper setup requires a running system (not chroot) to function properly with DBUS and system services.

## Part 10: First Boot Setup

### 10.1 Login and Verify System

1. **At Limine menu:**
   - You should see "Arch Linux" entry
   - Select it and press Enter

2. **LUKS password prompt:**
   - Enter your LUKS password
   - System should unlock and boot

3. **Login:**
   - Login as your user (ahsan)
   - Verify network connectivity

### 10.2 Connect to Network (if needed)

```bash
# Check network status
ip a

# If using WiFi, connect via NetworkManager
nmtui

# Test connectivity
ping -c 3 archlinux.org
```

## Part 11: Setup Snapper for Bootable Snapshots

Now that you're in a running system, set up Snapper properly.

### 11.1 Install Snapper and Dependencies

```bash
sudo pacman -S snapper inotify-tools
```

### 11.2 Configure Snapper

```bash
# Unmount the snapshots directory
sudo umount /.snapshots

# Remove the directory
sudo rm -rf /.snapshots

# Create Snapper configuration for root
sudo snapper -c root create-config /

# Snapper creates a .snapshots subvolume, but we want to use ours
# Delete Snapper's auto-created subvolume
sudo btrfs subvolume delete /.snapshots

# Recreate directory and remount our @snapshots subvolume
sudo mkdir /.snapshots
sudo mount /.snapshots

# Verify it's mounted
mount | grep snapshots

# Set proper permissions
sudo chmod 750 /.snapshots
sudo chown root:root /.snapshots

# Get the ID of @ subvolume and set it as default
ROOT_SUBVOL_ID=$(sudo btrfs subvolume list / | grep "path @$" | awk '{print $2}')
echo "Root subvolume ID: $ROOT_SUBVOL_ID"
sudo btrfs subvolume set-default ${ROOT_SUBVOL_ID} /
```

### 11.3 Configure Snapper Settings

```bash
# Edit Snapper configuration
sudo tee /etc/snapper/configs/root > /dev/null << 'EOF'
# Subvolume to snapshot
SUBVOLUME="/"

# Filesystem type
FSTYPE="btrfs"

# Btrfs qgroup
QGROUP=""

# Space limits
SPACE_LIMIT="0.5"
FREE_LIMIT="0.2"

# User/group permissions
ALLOW_USERS=""
ALLOW_GROUPS=""
SYNC_ACL="no"

# Background comparison
BACKGROUND_COMPARISON="yes"

# Number cleanup
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="10"
NUMBER_LIMIT_IMPORTANT="10"

# Timeline snapshots
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="10"
TIMELINE_LIMIT_YEARLY="0"

# Empty pre-post pairs cleanup
EMPTY_PRE_POST_CLEANUP="yes"
EMPTY_PRE_POST_MIN_AGE="1800"
EOF
```

### 11.4 Install snap-pac for Automatic Snapshots

```bash
# Install snap-pac - creates pre/post snapshots during pacman operations
sudo pacman -S snap-pac

# Enable Snapper timers
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer

# Verify services are running
sudo systemctl status snapper-timeline.timer
sudo systemctl status snapper-cleanup.timer
```

## Part 12: Setup Limine-Snapper Integration

### 12.1 Install limine-snapper-sync

```bash
# Install from AUR
paru -S limine-snapper-sync
```

### 12.2 Configure limine-snapper-sync

```bash
sudo tee /etc/default/limine-snapper-sync > /dev/null << 'EOF'
### OS Entry Targeting
# Must match the OS name in limine.conf
TARGET_OS_NAME="Arch Linux"

### Max Snapshot Entries
# Limit entries to avoid filling ESP
MAX_SNAPSHOT_ENTRIES=8

### ESP Usage Limit
# Stop creating entries when ESP reaches this percentage
LIMIT_USAGE_PERCENT=80

### ESP Path
ESP_PATH="/boot"

### Snapper Configuration Name
SNAPPER_CONFIG_NAME="root"

### Root Subvolume Path
ROOT_SUBVOLUME_PATH="/@"

### Root Snapshot Path
ROOT_SNAPSHOTS_PATH="/@snapshots"

### Restore Method Selection
# Use btrfs for fast "one-click-restore"
ENABLE_RSYNC_ASK=no

### Snapshot Entry Formatting
SPACE_NUMBER=5

### Snapshot Name Format
# 0: ID=111 2023-12-20 10:59:59
# 1: 111│2023-12-20 10:59:59
# 2: 111 │ 2023-12-20 10:59:59 (recommended)
# 3: 2023-12-20 10:59:59│111
# 4: 2023-12-20 10:59:59 │ 111
# 5: 2023-12-20 10:59:59
# 6: 111
SNAPSHOT_FORMAT_CHOICE=2

### Hash Function for Deduplication
HASH_FUNCTION=sha256

### Notification Icon
NOTIFICATION_ICON="/usr/share/icons/hicolor/128x128/apps/LimineSnapperSync.png"

### Automatic Config Backup
BACKUP_THRESHOLD=8

### Commands Before/After Save
COMMANDS_BEFORE_SAVE="limine-reset-enroll"
COMMANDS_AFTER_SAVE="limine-enroll-config"
EOF
```

### 12.3 Enable limine-snapper-sync Service

```bash
# Enable and start the service
sudo systemctl enable --now limine-snapper-sync.service

# Verify it's running
sudo systemctl status limine-snapper-sync.service
```

### 12.4 Verify ESP Path Detection

```bash
bootctl --print-esp-path
# Should output: /boot
```

### 12.5 Create Initial Baseline Snapshot

```bash
# Create a baseline snapshot after installation
sudo snapper -c root create --description "Fresh Installation - Post Snapper Setup"

# List snapshots to verify
sudo snapper list
```

## Part 13: Test Snapshot Functionality

### 13.1 Test Automatic Snapshots

```bash
# Install a test package to trigger snapshot
sudo pacman -S htop

# This will automatically create a pre/post snapshot via snap-pac
# Verify snapshots were created
sudo snapper list

# You should see new snapshots with type "pre" and "post"
```

### 13.2 Test Bootable Snapshots

```bash
# Reboot to see snapshots in Limine menu
sudo reboot

# In Limine menu, you should now see:
# - Arch Linux (current system)
# - Snapshots (submenu with snapshot entries)
```

### 13.3 How to Boot into a Snapshot

1. Reboot system
2. In Limine menu, navigate to "Snapshots"
3. Select a snapshot entry
4. Boot into it
5. The snapshot mounts read-only with an overlay
6. You'll get a notification asking if you want to restore
7. Click "Restore" or run: `sudo limine-snapper-restore`

---

# System Usage and Maintenance

## Managing Snapshots

### View Snapshots

```bash
# List all snapshots
sudo snapper list

# Show detailed info about a snapshot
sudo snapper info <snapshot-number>

# Compare snapshots
sudo snapper diff <snapshot1> <snapshot2>
```

### Create Manual Snapshot

```bash
# Before major changes
sudo snapper -c root create --description "Before major system change"
```

### Delete Snapshots

```bash
# Delete a specific snapshot
sudo snapper delete <snapshot-number>

# Delete a range
sudo snapper delete <start>-<end>
```

### Rollback Methods

**Method 1: Using Notification (Easiest)**

1. Boot into snapshot
2. Click notification "Restore this snapshot?"
3. Confirm
4. Reboot

**Method 2: Manual Command**

```bash
# When booted into snapshot, run:
sudo limine-snapper-restore
```

**Method 3: Traditional Snapper Rollback**

```bash
# From any boot (not necessarily in snapshot)
sudo snapper rollback <snapshot-number>
sudo reboot
```

**Method 4: Manual Btrfs (Most Control)**

```bash
# Boot into snapshot first, then:
sudo mkdir -p /mnt/btrfs_root
sudo mount -o subvolid=5 /dev/mapper/vg0-root /mnt/btrfs_root

# Delete current @ subvolume
sudo btrfs subvolume delete /mnt/btrfs_root/@

# Create new @ from snapshot (replace 123 with snapshot ID)
sudo btrfs subvolume snapshot /mnt/btrfs_root/@snapshots/123/snapshot /mnt/btrfs_root/@

# Set as default
NEW_ID=$(sudo btrfs subvolume list /mnt/btrfs_root | grep "path @$" | awk '{print $2}')
sudo btrfs subvolume set-default ${NEW_ID} /mnt/btrfs_root

# Clean up and reboot
sudo umount /mnt/btrfs_root
sudo reboot
```

## Maintenance Commands

### Regenerate Initramfs After Changes

```bash
# After changing /etc/default/limine or kernel parameters:
sudo limine-dracut

# This regenerates initramfs AND updates Limine config
```

### Update Kernel

```bash
# Install new kernel
sudo pacman -S linux-cachyos

# limine-dracut will be called automatically via pacman hooks
# Reboot to use new kernel
sudo reboot
```

### Check Disk Space

```bash
# ESP space (should keep 20%+ free)
df -h /boot

# Btrfs space
sudo btrfs filesystem usage /
```

### Monitor ESP Space

```bash
# If ESP is filling up, reduce snapshot entries
sudo nano /etc/default/limine-snapper-sync
# Change: MAX_SNAPSHOT_ENTRIES=5

# Restart service to apply
sudo systemctl restart limine-snapper-sync
```

## Troubleshooting

### System Won't Boot / Drops to Emergency Shell

**Check kernel parameters:**

```bash
# Boot from live USB, mount and chroot
cryptsetup luksOpen /dev/nvme0n1p2 cryptlvm
mount -o subvol=@ /dev/mapper/vg0-root /mnt
mount /dev/nvme0n1p1 /mnt/boot
arch-chroot /mnt

# Verify /etc/default/limine has correct UUIDs
cat /etc/default/limine

# Verify crypttab
cat /etc/crypttab

# Regenerate everything
limine-dracut

# Exit and reboot
exit
umount -R /mnt
cryptsetup close cryptlvm
reboot
```

**Add debug parameters temporarily:**

- At Limine menu, press 'e' to edit entry
- Add to kernel line: `rd.debug rd.shell`
- This gives you a shell in initramfs to debug

### Snapshots Not Appearing in Limine

```bash
# Check service status
systemctl status limine-snapper-sync

# Check if snapshots exist
snapper list

# Manually trigger sync
sudo systemctl restart limine-snapper-sync

# Check Limine config
cat /boot/limine.conf
```

### LUKS Won't Unlock

```bash
# Check if correct LUKS UUID in /etc/default/limine
cat /etc/default/limine | grep luks

# Check crypttab
cat /etc/crypttab

# Get correct UUID
cryptsetup luksDump /dev/nvme0n1p2 | grep UUID
```

### Dracut Errors During Generation

```bash
# Check dracut config
cat /etc/dracut.conf.d/custom.conf

# Test dracut manually with debug
sudo dracut --force --hostonly --show-modules

# Check for missing modules
lsinitrd /boot/initramfs-linux.img | grep -E 'crypt|lvm|btrfs'
```

### ESP Full

```bash
# Check space
df -h /boot

# Reduce snapshot entries
sudo nano /etc/default/limine-snapper-sync
# Change MAX_SNAPSHOT_ENTRIES=5

# Remove old kernels if you have multiple
sudo pacman -R linux

# Delete old snapshots
sudo snapper delete <old-snapshot-numbers>
```

### Rollback Didn't Work

```bash
# Boot from any working state
# Check current subvolume
mount | grep "on / "

# Should show: subvol=/@

# If wrong, boot from live USB and fix:
cryptsetup luksOpen /dev/nvme0n1p2 cryptlvm
mount -o subvolid=5 /dev/mapper/vg0-root /mnt

# List subvolumes
btrfs subvolume list /mnt

# Find @ subvolume ID and set as default
btrfs subvolume set-default <@-subvolume-id> /mnt
umount /mnt
reboot
```

# GENERAL COMMANDS

```sh
- emacs --batch --eval "(require 'org)" --eval '(org-babel-tangle-file "file-to-tangle.org")'
- #+begin_src python  :shebang "#!/usr/bin/env python"

- grep 'app-emacs/' /var/lib/portage/world | xargs --open-tty emerge --ask --deselect; emerge --ask --depclean

- esearch esearch -I emacs #list all installed emacs packages

- :shebang #!/usr/bin/env bash

- PY_CFLAGS:
python3 -c "import sysconfig; print(sysconfig.get_config_var('PY_CFLAGS') + sysconfig.get_config_var('PY_CFLAGS_NODIST'))"

- find / -name ".git"


```
