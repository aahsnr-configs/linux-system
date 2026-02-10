```bash
cfdisk /dev/nvme0n1 &&
  mkfs.vfat -F 32 /dev/nvme0n1p1 &&
  cryptsetup --cipher aes-xts-plain64 --hash sha512 --use-random --verify-passphrase luksFormat /dev/nvme0n1p2 &&
  cryptsetup luksOpen /dev/nvme0n1p2 cryptlvm &&
  pvcreate /dev/mapper/cryptlvm &&
  vgcreate vg0 /dev/mapper/cryptlvm &&
  lvcreate -L 32G vg0 -n swap &&
  lvcreate -l 100%FREE vg0 -n root &&
  mkfs.btrfs -f /dev/vg0/root &&
  mkswap /dev/vg0/swap &&
  mount /dev/vg0/root /mnt &&
  swapon /dev/vg0/swap
```

### Creating Subvolumes

```bash
btrfs su cr /mnt/@ &&
  btrfs su cr /mnt/@/.snapshots &&
  mkdir /mnt/@/.snapshots/1 &&
  btrfs su cr /mnt/@/.snapshots/1/snapshot &&
  mkdir -v /mnt/@/boot &&
  btrfs su cr /mnt/@/boot/grub &&
  btrfs su cr /mnt/@/home &&
  btrfs su cr /mnt/@/nix &&
  btrfs su cr /mnt/@/opt &&
  btrfs su cr /mnt/@/root &&
  btrfs su cr /mnt/@/srv &&
  btrfs su cr /mnt/@/tmp &&
  mkdir -v /mnt/@/usr &&
  btrfs su cr /mnt/@/usr/local &&
  btrfs su cr /mnt/@/var &&
  btrfs su cr /mnt/@/var/cache &&
  btrfs su cr /mnt/@/var/crash &&
  btrfs su cr /mnt/@/var/log &&
  btrfs su cr /mnt/@/var/spool &&
  btrfs su cr /mnt/@/var/tmp


date +"%Y-%m-%d %H:%M:%S"

nvim /mnt/@/.snapshots/1/info.xml

<?xml version="1.0"?>
<snapshot>
	<type>single</type>
	<num>1</num>
	<date>2026-01-07 08:28:39</date>
	<description>First Root Filesystem Created at Installation</description>
</snapshot>

btrfs subvolume get-default /mnt


btrfs subvolume set-default $(btrfs subvolume list /mnt | grep "@/.snapshots/1/snapshot" | grep -oP '(?<=ID )[0-9]+') /mnt

btrfs subvolume get-default /mnt

```

### Quota

```bash
btrfs quota enable /mnt &&
btrfs qgroup create 1/0 /mnt

```

### Disable CoW

```bash
chattr +C /mnt/@/var/cache &&
chattr +C /mnt/@/var/crash &&
chattr +C /mnt/@/var/log &&
chattr +C /mnt/@/var/spool &&
chattr +C /mnt/@/var/tmp

```

### Output verification

```bash
ls -la /mnt

ls -la /mnt/@
```

# unmount /mnt

```bash
# umount /mnt much later
umount /mnt
```

```bash
# Don't execute this command; this is just an example
mount UUID=eb5f654e-bfaf-4d89-b3e4-3d6dc3bd224b -o compress=zstd /mnt
```

### Main subvol

```bash
# The following command cannot be executed anymore since defeault subvolume is not in @
# mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@ /dev/vg0/root /mnt
mount -o noatime,compress=zstd:3,space_cache=v2,discard=async /dev/vg0/root /mnt

mount | grep /mnt

# result
/dev/mapper/vg0-root on /mnt type btrfs (rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvolid=258,subvol=/@/.snapshots/1/snapshot)
```

### Make mountpoints for subvolumes

```bash
mkdir /mnt/.snapshots &&
mkdir -p /mnt/boot/grub &&
mkdir /mnt/opt &&
mkdir /mnt/root &&
mkdir /mnt/srv &&
mkdir /mnt/tmp &&
mkdir -p /mnt/usr/local &&
mkdir -p /mnt/var/cache &&
mkdir /mnt/var/crash &&
mkdir /mnt/var/log &&
mkdir /mnt/var/spool &&
mkdir /mnt/var/tmp &&
mkdir /mnt/home &&
mkdir /mnt/nix

```

### Mount volumes

```bash
# Example
mount UUID=eb5f654e-bfaf-4d89-b3e4-3d6dc3bd224b -o subvol=@/.snapshots,compress=zstd /mnt/.snapshots

mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@/.snapshots /dev/vg0/root /mnt/.snapshots

mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@/boot/grub /mnt/boot/grub


```

```bash
mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@home /dev/vg0/root /mnt/home &&
mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@opt /dev/vg0/root /mnt/opt &&
mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@tmp /dev/vg0/root /mnt/tmp
mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@root /dev/vg0/root /mnt/root &&
mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@srv /dev/vg0/root /mnt/srv &&
mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@nix /dev/vg0/root /mnt/nix &&
mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@usr@local /dev/vg0/root /mnt/usr/local &&
mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@var /dev/vg0/root /mnt/var &&
mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@var@cache /dev/vg0/root /mnt/var/cache &&
mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@pkg /dev/vg0/root /mnt/var/cache/pacman/pkg
mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@var@crash /dev/vg0/root /mnt/var/crash &&
mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@var@tmp /dev/vg0/root /mnt/var/tmp &&
mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@var@spool /dev/vg0/root /mnt/var/spool &&
mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@var@log /dev/vg0/root /mnt/var/log &&
mount -o noatime,compress=zstd:3,space_cache=v2,discard=async,subvol=@var@log@audit /dev/vg0/root /mnt/var/log/audit &&


```

### Mount Boot Partition

```bash
pacstrap /mnt base base-devel devtools git neovim arch-install-scripts reflector dracut  wget btrfs-progs lvm2

genfstab -U /mnt >>/mnt/etc/fstab

arch-chroot /mnt

reflector --verbose -l 25 --country BD,IN,SG --sort rate --save /etc/pacman.d/mirrorlist

ln -sf /usr/share/zoneinfo/Asia/Dhaka /etc/localtime && hwclock --systohc && nvim /etc/locale.gen && locale-gen && echo "LANG=en_US.UTF-8" >>/etc/locale.conf

useradd -m -G users,wheel,audio,video -s /bin/bash ahsan && passwd ahsan
```

## Setup CachyOS repositories

```sh
curl https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz
tar xvf cachyos-repo.tar.xz && cd cachyos-repo
sudo ./cachyos-repo.sh
```

After the above commands are executed, execute the following command: sudo pacman -Syyuu

The next block of commands is an example of the output of the command `lsblk -o name,uuid`

```sh
nvme0n1
├─nvme0n1p1    B918-8549
└─nvme0n1p2    {nvme0n1p2}
  └─cryptlvm   TQ8t2M-PwaT-liwO-fPT8-v178-218Y-QhZGbw
    ├─vg0-swap {vg0-swap}
    └─vg0-root {vg0-root}
```

You must execute the command 'lsblk -o name,uuid' and the corresponding UUIDs for {nvme0n1p2}, {vg0-root}, and {vg0-swap} respectively

Then you must create a file called custom.conf /etc/dracut.conf.d/ directory and fill it with the following contents where you must replace all {} with the respective UUIDS from the last command

vg0-swap = c74f12c3-9cfe-4469-9b7f-2270bf704879
vg0-root = 11289bd2-113e-495a-9265-4a9ae7ed2340

```sh
hostonly="yes"
compress="zstd"
add_dracutmodules+=" crypt dm rootfs-block resume lvm "
omit_dracutmodules+=" network cifs nfs nbd brltty "
force_drivers+=" btrfs "
kernel_cmdline+=" rd.luks.uuid=luks-9687319d-3f60-4daf-8dcd-7e0ae6c6bf38 root=UUID=11289bd2-113e-495a-9265-4a9ae7ed2340 resume=UUID=c74f12c3-9cfe-4469-9b7f-2270bf704879 rd.lvm.lv=vg0/swap rd.lvm.lv=vg0/root "
```

The next part is to start setting up grub. You will need to install the following packages: grub, efibootmgr. And then update the /etc/default/grub file with the contents from the next block with {} being used placeholders for UUID

```sh
nvim /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="rootfstype=btrfs quiet loglevel=0 rw rd.vconsole.keymap=us rd.luks.uuid=luks-9687319d-3f60-4daf-8dcd-7e0ae6c6bf38 root=UUID=11289bd2-113e-495a-9265-4a9ae7ed2340 resume=UUID=c74f12c3-9cfe-4469-9b7f-2270bf704879 rd.lvm.lv=vg0/swap rd.lvm.lv=vg0/root"
GRUB_CMDLINE_LINUX=""
```

Now, this part involves setting the Endeavoros repository. While in /tmp, download the latest keyring and mirrorlist. Then install these packages. Check the /etc/pacman.conf to make sure the Endeavoros repository is after the cachyos repositories. Then execute the following two commands:

```sh
sudo pacman -S eos-dracut
sudo dracut-rebuild
```

```sh
sudo grub-install --target=x86_64-efi --efi-directory=/boot && sudo grub-install --target=x86_64-efi --efi-directory=/boot --removable && sudo grub-mkconfig -o /boot/grub/grub.cfg
```
