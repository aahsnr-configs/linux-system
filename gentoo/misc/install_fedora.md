Below are the individual bash scripts for each phase of the Fedora 43 + ZFS + ZFSBootMenu installation guide.  
Save each script with the suggested filename, make it executable (`chmod +x script.sh`), and run it as **root** in the live environment.

---

## Phase 0 – Preparation (`phase0.sh`)

```bash
#!/bin/bash
set -e

echo "Phase 0: Preparation – Boot and Initial Checks"

# Verify internet connectivity
ping -c2 8.8.8.8 || { echo "No internet"; exit 1; }

# Check NVMe drives
lsblk | grep nvme || { echo "NVMe drives not found"; exit 1; }

read -p "Are you sure you want to wipe /dev/nvme0n1 and /dev/nvme1n1? Type YES: " confirm
if [[ "$confirm" != "YES" ]]; then
    echo "Aborted."
    exit 1
fi

echo "Phase 0 completed successfully."
```

---

## Phase 1 – Install ZFS tools in live environment (`phase1.sh`)

```bash
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
    "kernel-devel-$(uname -r | awk -F'-' '{print $1}')" || \
    dnf install -y --setopt=install_weak_deps=False kernel-devel

dnf install -y --setopt=install_weak_deps=False zfs

modprobe zfs

echo "Phase 1 completed successfully."
```

---

## Phase 2 – Partition NVMe drives (`phase2.sh`)

```bash
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
```

---

## Phase 3 – Create ZFS pool and encrypted datasets (`phase3.sh`)

```bash
#!/bin/bash
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
```

---

## Phase 4 – Prepare directories and DNF configuration (`phase4.sh`)

```bash
#!/bin/bash
set -e

echo "Phase 4: Create directories and prepare DNF config"

mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/run /mnt/tmp

mkdir -p /mnt/etc/dnf
cat > /mnt/etc/dnf/dnf.conf <<'EOF'
[main]
gpgcheck=True
installonly_limit=3
clean_requirements_on_remove=True
best=False
install_weak_deps=False
skip_if_unavailable=True
fastestmirror=True
max_parallel_downloads=10
EOF

mkdir -p /mnt/etc/yum.repos.d
for repo in /etc/yum.repos.d/fedora*.repo /etc/yum.repos.d/fedora-updates*.repo; do
    [[ -f "$repo" ]] && cp "$repo" /mnt/etc/yum.repos.d/
done

mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
mount --bind /run /mnt/run
mount --bind /tmp /mnt/tmp

echo "Phase 4 completed successfully."
```

---

## Phase 5 – Bootstrap minimal Fedora system (`phase5.sh`)

```bash
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
```

---

## Phase 6 – Install ZFS inside chroot (`phase6.sh`)

```bash
#!/bin/bash
set -e

echo "Phase 6: Install ZFS inside the chroot"

chroot /mnt dnf install -y --nogpgcheck \
    "https://zfsonlinux.org/fedora/zfs-release-3-0$(rpm --eval "%{dist}").noarch.rpm"

curl -s https://zfsonlinux.org/fedora/zfsonlinux.gpg | chroot /mnt tee /tmp/zfs-key.asc >/dev/null
chroot /mnt rpm --import /tmp/zfs-key.asc
chroot /mnt rm -f /tmp/zfs-key.asc

if chroot /mnt dnf config-manager setopt zfs-latest.enabled=1 &>/dev/null; then
    echo OK
else
    chroot /mnt sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/zfs-latest.repo
fi

chroot /mnt dnf install -y --setopt=install_weak_deps=False --setopt=tsflags=noscripts zfs zfs-dracut

echo "Phase 6 completed successfully."
```

---

## Phase 7 – Configure target system (chroot) (`phase7.sh`)

```bash
#!/bin/bash
set -e

echo "Phase 7: Configure the target system (chroot)"

chroot /mnt zgenhostid -f "$(hostid)"

read -p "Enter hostname [fedora-zfs]: " hostname
hostname=${hostname:-fedora-zfs}
echo "$hostname" > /mnt/etc/hostname

cat > /mnt/etc/hosts <<'EOF'
127.0.0.1   localhost localhost.localdomain
::1         localhost localhost.localdomain
127.0.1.1   $hostname.localdomain $hostname
EOF

echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
chroot /mnt localectl set-locale "LANG=en_US.UTF-8"

read -p "Timezone [UTC]: " tz
tz=${tz:-UTC}
ln -sf "/usr/share/zoneinfo/$tz" /mnt/etc/localtime

chroot /mnt systemctl enable zfs-import-cache.service
chroot /mnt systemctl enable zfs-mount.service
chroot /mnt systemctl enable zfs.target
chroot /mnt systemctl enable NetworkManager

mkdir -p /mnt/etc/dracut.conf.d
cat > /mnt/etc/dracut.conf.d/zfs.conf <<EOF
add_dracutmodules+=" zfs "
omit_dracutmodules+=" btrfs "
hostonly="no"
EOF

echo "zfs" > /mnt/etc/modules-load.d/zfs.conf

cat > /mnt/etc/sysctl.d/99-zfs.conf <<EOF
vm.zone_reclaim_mode = 0
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.vfs_cache_pressure = 200
EOF

total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
tmpfs_size_kb=$(( total_ram_kb * 50 / 100 ))
echo "tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev,size=${tmpfs_size_kb}k 0 0" >> /mnt/etc/fstab
mkdir -p /mnt/tmp
chmod 1777 /mnt/tmp

mkswap -L "swap" /dev/zvol/rpool/swap
echo "/dev/zvol/rpool/swap none swap defaults 0 0" >> /mnt/etc/fstab

sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /mnt/etc/selinux/config
sed -i 's/^SELINUXTYPE=.*/SELINUXTYPE=targeted/' /mnt/etc/selinux/config
touch /mnt/.autorelabel

kernel_ver=$(chroot /mnt rpm -q kernel-core --queryformat "%{VERSION}-%{RELEASE}.%{ARCH}")
chroot /mnt dracut --force --no-hostonly "/boot/initramfs-${kernel_ver}.img" "${kernel_ver}"

echo "Phase 7 completed successfully."
```

---

## Phase 8 – Set passwords and create user (`phase8.sh`)

```bash
#!/bin/bash
set -e

echo "Phase 8: Set passwords and create user"

chroot /mnt dnf install -y cracklib-dicts

# Set root password
chroot /mnt bash -c '
    if ! grep -q "^root:" /etc/shadow; then
        echo "root:*:19800:0:99999:7:::" >> /etc/shadow
    fi
    echo "Set root password:"
    read -s p1; echo
    read -s p2; echo
    if [ "$p1" != "$p2" ]; then
        echo "Password mismatch" >&2
        exit 1
    fi
    hash=$(openssl passwd -6 "$p1")
    sed -i "s|^root:[^:]*|root:$hash|" /etc/shadow
    echo "Root password set successfully"
'

# Create sudo user
read -p "Enter username for sudo user: " username
chroot /mnt useradd -m -G wheel "$username"
chroot /mnt bash -c '
    touch /etc/shadow
    chmod 600 /etc/shadow
    username="$1"
    if ! grep -q "^$username:" /etc/shadow; then
        echo "$username:*:19800:0:99999:7:::" >> /etc/shadow
    fi
    echo "Set password for $username:"
    read -s p1; echo
    read -s p2; echo
    if [ "$p1" != "$p2" ]; then
        echo "Password mismatch" >&2
        exit 1
    fi
    hash=$(openssl passwd -6 "$p1")
    sed -i "s|^$username:[^:]*|$username:$hash|" /etc/shadow
    echo "Password for $username set successfully"
' -- "$username"

# Configure sudoers
chroot /mnt bash -c "EDITOR=nano visudo"
echo "Please ensure %wheel ALL=(ALL) ALL is uncommented or added in nano, then save and exit."

echo "Phase 8 completed successfully."
```

---

## Phase 9 – Install ZFSBootMenu (`phase9.sh`)

```bash
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

curl -L -o /tmp/zfsbootmenu/zfsbootmenu-release.tar.gz "$DOWNLOAD_URL" || { echo "Download failed"; exit 1; }

if file /tmp/zfsbootmenu/zfsbootmenu-release.tar.gz | grep -q "gzip compressed data"; then
    tar -xzf /tmp/zfsbootmenu/zfsbootmenu-release.tar.gz -C /tmp/zfsbootmenu
else
    echo "Not a valid gzip archive"; exit 1
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
```

---

## Phase 10 – Cleanup and reboot (`phase10.sh`)

```bash
#!/bin/bash
set -e

echo "Phase 10: Cleanup and reboot"

umount /mnt/dev
umount /mnt/proc
umount /mnt/sys
umount /mnt/run
umount /mnt/tmp
umount /mnt/boot/efi
zpool export rpool

echo "Rebooting in 5 seconds... Press Ctrl+C to abort."
sleep 5
reboot
```

---

## Usage Instructions

1. Copy each script into a separate file (e.g., `phase0.sh`, `phase1.sh`, … `phase10.sh`).
2. Make them executable:  
   `chmod +x phase*.sh`
3. Run them **in order** as **root** from the Fedora 43 live environment:  
   `sudo ./phase0.sh`  
   `sudo ./phase1.sh`  
   …  
   `sudo ./phase10.sh`
4. For phases that require interactive input (passphrase, hostname, timezone, passwords), follow the prompts.

**Note:** The scripts assume you are starting from a clean state. If any phase fails, fix the issue manually (or adjust the script) before proceeding to the next phase.
