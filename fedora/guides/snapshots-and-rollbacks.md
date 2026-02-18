# Fedora 43 — Btrfs Snapshot & Rollback Guide

### Minimal Install · LUKS Encryption · Snapper · DNF5 · Honest Recovery

## Read This First — What Actually Works on Fedora

Before anything else, you deserve an honest picture of what this guide does and does not deliver.

**What reliably works on stock Fedora:**

- Automatic Btrfs snapshots via Snapper before every `dnf` transaction (pre + post pairs)
- Automatic snapshots before every reboot/shutdown via a systemd service
- Manual snapshots at any time
- `snapper --ambit classic rollback N` from a *running, bootable* system to roll back to any snapshot
- Surgically undoing the file changes made by a specific DNF transaction with `snapper undochange`
- Restoring individual files directly from the snapshot directory

**What does NOT reliably work on stock Fedora:**

- Picking a snapshot from a GRUB submenu and booting directly into it — this is the grub-btrfs feature. Fedora uses the Boot Loader Specification (BLS), where each kernel gets its own drop-in `.conf` file in `/boot/loader/entries/` rather than a traditional monolithic `grub.cfg`. The `grub-btrfs` tool was written for the traditional approach and conflicts with BLS in ways that require disabling BLS entirely to work around — an invasive change that affects how kernels are managed. Distributions like Garuda, CachyOS, and openSUSE achieve bootable snapshot selection through deep, custom integration work that does not exist in stock Fedora.

**What this means for the "system won't boot" scenario:**

If a reboot results in an unbootable system, you cannot run `snapper rollback` because you cannot log in. The recovery path in that situation is to boot from a Fedora Live USB, unlock your LUKS container, and manually set the Btrfs default subvolume to a known-good snapshot.
The full procedure is in Part 3. It takes about five minutes once you have done it once.

This is a real limitation compared to Garuda/CachyOS. It is worth knowing upfront rather than discovering it in an emergency.

---

## How Snapper Rollback Works on Fedora

Understanding this mechanism prevents confusion when things go wrong.

When Snapper creates a rollback, it does three things in sequence:

1. Takes a read-only snapshot of the currently running root subvolume
2. Creates a new **read-write** copy of the target snapshot (this becomes the new root)
3. Calls `btrfs subvolume set-default` to make that new subvolume the default

On the next boot, GRUB reads the Btrfs filesystem's default subvolume and boots it. This works **only if** the BLS kernel entries do not hardcode `rootflags=subvol=root`, because that argument would override the Btrfs default and always force the kernel to mount the `root` subvolume regardless of what Snapper set. Removing that argument is therefore a required step in the setup, and it is one of the first things you will do.

---

## What Fedora 43 Workstation Actually Installs

When you use the Anaconda Web UI with automatic partitioning and LUKS encryption enabled,
Fedora creates this layout:

```
Physical Disk (e.g. /dev/sda or /dev/nvme0n1)
├── Part 1   ~600 MB   FAT32   /boot/efi   ← EFI partition, unencrypted
├── Part 2     1 GB    ext4    /boot        ← kernels & initramfs, unencrypted
└── Part 3   remainder LUKS2               ← encrypted container
    └── /dev/mapper/luks-<UUID>  (opened at boot with your passphrase)
        └── Btrfs filesystem
            ├── subvolume: root   → mounted at  /
            ├── subvolume: home   → mounted at  /home
            └── (subvol var/lib/machines  created by systemd later)
```

**`/boot` is intentionally outside the encrypted container.** Kernels must be readable by GRUB before you enter your LUKS passphrase. This means `/boot` is never snapshotted. That is fine — Fedora keeps the last three kernel versions installed, so you always have older kernels
to fall back to without needing snapshots.

**Snapper snapshots never include `/home`.** Btrfs snapshots do not cross subvolume boundaries. When you snapshot `root`, nothing in `/home` is touched. This is a feature, not a bug — it means a rollback of your system never deletes personal files.

---
---
---

## Part 1 — Setting Up (Do This Once, Right After Install)

**IMPORTANT:** All steps in this section must be performed from your freshly installed, running Fedora system — not from the installer, not from a Live USB, and not from chroot. Complete the Fedora Workstation 43 installation normally, reboot into your new system, and log in. Then begin Step 1 below.

### Step 1 — Install Required Packages

**You are running these commands from your installed Fedora system after rebooting from the installation.**

```bash
sudo dnf install snapper btrfs-assistant libdnf5-plugin-actions
```

- **snapper** — snapshot creation, management, and rollback
- **btrfs-assistant** — optional graphical interface for snapper and Btrfs maintenance
- **libdnf5-plugin-actions** — the DNF5 hook mechanism that replaces the old `python3-dnf-plugin-snapper` (which is incompatible with DNF5)

---
---
---

# Step 2 — Create the `.snapshots` Subvolume at the Top Level

**You are performing these commands from your running, freshly installed Fedora system** (not from a Live USB, not in chroot).

## Why This Step Is Critical

When Snapper initializes a configuration for `/`, it automatically creates a `.snapshots` subvolume. If you let it do this on its own, it creates that subvolume **inside** the `root` subvolume—nested at top level 257. The problem: when you snapshot `root`, Btrfs snapshots do not recurse into child subvolumes. So `.snapshots` would be missing from every snapshot. Rolling back becomes unpredictable or fails entirely.

The fix is to create `.snapshots` as its own sibling subvolume at the Btrfs top level (level 5), **before** running `snapper create-config`. Snapper will then use your pre-existing subvolume instead of creating a nested one.

---

## Step 2.1 — Find Your Unlocked LUKS Device Path

The LUKS container is already unlocked by the time you're logged into your running system. During boot, after you entered your LUKS passphrase, the system created a device mapper device at `/dev/mapper/luks-<LUKS-UUID>`.

Find it:

```bash
lsblk
```

Look for output like this:

```
NAME                                          MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINT
sda                                             8:0    0 500GB  0 disk  
├─sda1                                          8:1    0   600M  0 part  /boot/efi
├─sda2                                          8:2    0     1G  0 part  /boot
└─sda3                                          8:3    0 498.4G  0 part  
  └─luks-a9a402be-cc3d-4190-8487-50562dc43e22 253:0    0 498.4G  0 crypt /home
                                                                         /
```

The device path you need is: `/dev/mapper/luks-a9a402be-cc3d-4190-8487-50562dc43e22`

**Note:** The UUID in the device name (`a9a402be-...`) is the UUID of the **encrypted LUKS partition** (from `sda3`), not the UUID of the Btrfs filesystem inside it. This is correct and expected.

---

## Step 2.2 — Mount the Btrfs Top Level

Mount the raw Btrfs filesystem at its top level (subvolid=5), which shows all top-level subvolumes without entering any of them:

```bash
sudo mkdir /mnt/btrfsroot
sudo mount /dev/mapper/luks-<YOUR-UUID-HERE> -o subvolid=5 /mnt/btrfsroot
```

Replace `<YOUR-UUID-HERE>` with the actual UUID from your `lsblk` output. Example:

```bash
sudo mount /dev/mapper/luks-a9a402be-cc3d-4190-8487-50562dc43e22 -o subvolid=5 /mnt/btrfsroot
```

Verify you can see `root` and `home` at the top level:

```bash
ls /mnt/btrfsroot
# Expected output: home  root
```

---

## Step 2.3 — Create the `.snapshots` Subvolume

Create `.snapshots` as a top-level subvolume, sibling to `root` and `home`:

```bash
sudo btrfs subvolume create /mnt/btrfsroot/.snapshots
```

Expected output:

```
Create subvolume '/mnt/btrfsroot/.snapshots'
```

---

## Step 2.4 — Unmount the Top Level

Clean up:

```bash
sudo umount /mnt/btrfsroot
sudo rmdir /mnt/btrfsroot
```

---

## Step 2.5 — Create the Mount Point

```bash
sudo mkdir -p /.snapshots
```

---

## Step 2.6 — Add `.snapshots` to `/etc/fstab`

You need to add a line to `/etc/fstab` so the `.snapshots` subvolume automatically mounts at `/.snapshots` on every boot.

First, find your Btrfs filesystem UUID. This is the UUID of the **unlocked Btrfs filesystem** (the device mapper device), not the raw disk:

```bash
sudo blkid | grep btrfs
```

Example output:

```
/dev/mapper/luks-a9a402be-cc3d-4190-8487-50562dc43e22: UUID="8d2e94f1-f26d-4ac5-bf89-2c3a0a9e8f0c" TYPE="btrfs"
```

The UUID you want is `8d2e94f1-f26d-4ac5-bf89-2c3a0a9e8f0c`.

Open `/etc/fstab`:

```bash
sudo nano /etc/fstab
```

Find the existing line for the `root` subvolume. It will look something like this:

```
UUID=8d2e94f1-f26d-4ac5-bf89-2c3a0a9e8f0c  /  btrfs  subvol=root,compress=zstd:1,x-systemd.device-timeout=0  0 0
```

**Immediately below that line**, add this new line using the **same UUID**:

```
UUID=8d2e94f1-f26d-4ac5-bf89-2c3a0a9e8f0c  /.snapshots  btrfs  subvol=.snapshots,compress=zstd:1,x-systemd.device-timeout=0  0 0
```

Save the file and exit the editor (`Ctrl+O`, `Enter`, `Ctrl+X` in nano).

---

## Step 2.7 — Mount the `.snapshots` Subvolume

Mount it now without rebooting:

```bash
sudo mount /.snapshots
```

Verify it mounted correctly:

```bash
df -h /.snapshots
# Should show the Btrfs filesystem mounted at /.snapshots

mount | grep snapshots
# Should show: /dev/mapper/luks-... on /.snapshots type btrfs (...)
```

---

## Step 2.8 — Fix the SELinux Context (CRITICAL)

**Why this is absolutely necessary:**

Fedora Workstation runs SELinux in **enforcing mode by default**. On CentOS (and Red Hat Enterprise Linux) and Fedora, SELinux is typically installed and enabled by default in enforcing mode, and enforcing mode is the normal and expected way to run Fedora.

When you create and mount a new Btrfs subvolume, it gets labeled with the SELinux context `unlabeled_t`. Snapper has the wrong SELinux context on the .snapshots directory: the context is `system_u:object_r:unlabeled_t:s0` instead of the required `system_u:object_r:snapperd_data_t:s0`. Without the correct context, Snapper will fail with permission denied errors even when run as root.

Fix the SELinux context:

```bash
sudo restorecon -v /.snapshots
```

Expected output:

```
Relabeled //.snapshots from system_u:object_r:unlabeled_t:s0 to system_u:object_r:snapperd_data_t:s0
```

Verify the context is now correct:

```bash
ls -ldZ /.snapshots
```

Expected output should show `snapperd_data_t`:

```
drwxr-xr-x. 2 root root system_u:object_r:snapperd_data_t:s0 16 Feb 17 12:00 /.snapshots
```

---

## Step 2.9 — Verify the Final Subvolume Layout

Confirm the structure is correct:

```bash
sudo btrfs subvolume list /
```

Expected output (IDs may vary on your system):

```
ID 256  gen ...  top level 5    path home
ID 257  gen ...  top level 5    path root
ID 258  gen ...  top level 257  path root/var/lib/machines
ID 259  gen ...  top level 5    path .snapshots
```

**What to look for:**

- `home` at top level 5 ✅
- `root` at top level 5 ✅
- `.snapshots` at top level 5 ✅ (this is what you just created)
- `var/lib/machines` nested under root at level 257 ✅ (created by systemd, this is fine)

**What you should NOT see:**

- ❌ Any entry with `top level 257  path root/.snapshots` — this would be a nested subvolume inside root, which breaks snapshots

---

## What You Just Accomplished

1. ✅ Created `.snapshots` as a proper top-level subvolume alongside `root` and `home`
2. ✅ Added it to `/etc/fstab` so it auto-mounts on every boot
3. ✅ Mounted it at `/.snapshots` in your running system
4. ✅ Fixed the SELinux context so Snapper has permission to use it

**You are now ready to proceed to Step 3** (creating Snapper configurations).

---

## Troubleshooting

**If `sudo mount /.snapshots` fails with "wrong fs type, bad option, bad superblock...":**

Check that the UUID in your fstab line matches the Btrfs filesystem UUID:

```bash
sudo blkid | grep btrfs
grep snapshots /etc/fstab
```

Both should show the same UUID.

**If you see a nested `root/.snapshots` subvolume in the output of `btrfs subvolume list`:**

You likely ran `snapper create-config` before completing Step 2. Delete the nested one:

```bash
sudo btrfs subvolume delete /.snapshots
sudo mount /.snapshots
sudo restorecon -v /.snapshots
```

Then verify again with `sudo btrfs subvolume list /` — you should only see `.snapshots` at top level 5, not nested under `root`.

---
---
---

# Step 3 — Create Snapper Configurations

**You are running these commands from your running Fedora system** (logged in, after completing Step 2).

## What This Step Does

`snapper create-config` creates a configuration file that tells Snapper how to manage snapshots for a specific subvolume. It:

1. Creates a config file in `/etc/snapper/configs/`
2. Registers the config in `/etc/sysconfig/snapper`
3. Uses the existing `.snapshots` subvolume (for root) or creates a new one (for home)
4. Sets default retention and cleanup policies

After creating the configs, you'll adjust permissions so your regular user account can view and manage snapshots without needing `sudo` every time.

---

## Step 3.1 — Create the Root Configuration

Run this command to create a Snapper configuration for the root filesystem:

```bash
sudo snapper -c root create-config /
```

Expected output:

```
```

(The command produces no output on success.)

**What just happened:**

- Snapper found the existing `/.snapshots` subvolume you created in Step 2 and is now using it
- A configuration file was created at `/etc/snapper/configs/root`
- The config was registered in `/etc/sysconfig/snapper`

---

## Step 3.2 — Verify Snapper Did NOT Create a Nested Subvolume

This is a critical sanity check. Run:

```bash
sudo btrfs subvolume list /
```

**Look carefully at the output.** You should see:

```
ID 256  gen ...  top level 5    path home
ID 257  gen ...  top level 5    path root
ID 258  gen ...  top level 257  path root/var/lib/machines
ID 259  gen ...  top level 5    path .snapshots
```

**What you should NOT see:**

- ❌ Any entry with `top level 257  path root/.snapshots`

If you see `root/.snapshots` listed at top level 257, it means Snapper ignored your pre-existing `.snapshots` subvolume and created a new nested one. This breaks snapshots. Fix it immediately:

```bash
# Delete the nested subvolume Snapper incorrectly created
sudo btrfs subvolume delete /.snapshots

# Re-mount your correct top-level .snapshots from Step 2
sudo mount /.snapshots

# CRITICAL: Re-apply SELinux context after remounting
sudo restorecon -v /.snapshots
# Expected output:
# Relabeled //.snapshots from ... to system_u:object_r:snapperd_data_t:s0

# Verify the layout is now correct
sudo btrfs subvolume list / | grep snapshots
# Should show ONLY:  ID 259  top level 5  path .snapshots
```

If the output looks correct (`.snapshots` at top level 5, no nested `root/.snapshots`), proceed.

---

## Step 3.3 — Create the Home Configuration

Run this command to create a Snapper configuration for the home filesystem:

```bash
sudo snapper -c home create-config /home
```

Expected output:

```
```

(No output on success.)

**What just happened:**

- Snapper created a NEW subvolume at `/home/.snapshots` (this did not exist before)
- A configuration file was created at `/etc/snapper/configs/home`
- The config was registered in `/etc/sysconfig/snapper`

---

## Step 3.4 — Fix SELinux Contexts (CRITICAL)

The newly created `/home/.snapshots` subvolume has the wrong SELinux context. It currently has `unlabeled_t` but needs `snapperd_data_t`. Without fixing this, Snapper will fail with permission errors when trying to create snapshots in `/home/.snapshots`.

Additionally, we'll apply the context recursively to both `.snapshots` directories to ensure any subdirectories Snapper creates in the future (numbered snapshot directories like `1/`, `2/`, etc.) also have correct contexts.

Run:

```bash
sudo restorecon -RFv /.snapshots
sudo restorecon -RFv /home/.snapshots
```

**Understanding the flags:**

- `-R` = Recursive — fixes the directory and all contents inside it
- `-F` = Force — resets contexts even if they look correct
- `-v` = Verbose — shows what was changed

**Expected output:**

```
Relabeled //.snapshots from system_u:object_r:snapperd_data_t:s0 to system_u:object_r:snapperd_data_t:s0
Relabeled //home/.snapshots from system_u:object_r:unlabeled_t:s0 to system_u:object_r:snapperd_data_t:s0
```

The first line shows no actual change for `/.snapshots` (we already fixed it in Step 2) — this is fine and expected. The second line shows `/home/.snapshots` being corrected from `unlabeled_t` to `snapperd_data_t` — this is the critical fix.

**Why is this necessary?**

Fedora Workstation runs SELinux in enforcing mode by default. When Snapper creates the `/home/.snapshots` subvolume, SELinux labels it with the default context `unlabeled_t`. Snapper requires the context `snapperd_data_t` on the `.snapshots` directory to function correctly. Without this fix, Snapper will encounter "Permission denied" errors even when run as root.

Verify the contexts are now correct:

```bash
ls -ldZ /.snapshots
ls -ldZ /home/.snapshots
```

Both should show `snapperd_data_t` in the output:

```
drwxr-xr-x. root root system_u:object_r:snapperd_data_t:s0 /.snapshots
drwxr-xr-x. root root system_u:object_r:snapperd_data_t:s0 /home/.snapshots
```

---

## Step 3.5 — Allow Your Regular User to Manage Snapshots

By default, only root can use Snapper. To allow your regular user account to view and manage snapshots without `sudo`, you need to:

1. Add your username to the `ALLOW_USERS` config setting
2. Enable `SYNC_ACL=yes` so Snapper automatically sets filesystem ACLs on the `.snapshots` directories

SYNC_ACL automatically configures filesystem Access Control Lists (ACLs) on the `.snapshots` directory so the users listed in ALLOW_USERS can read and traverse it, even though the directory is owned by root.

Run these commands (replace `$USER` with your actual username if the variable doesn't work):

```bash
sudo snapper -c root set-config ALLOW_USERS="$USER" SYNC_ACL=yes
sudo snapper -c home set-config ALLOW_USERS="$USER" SYNC_ACL=yes
```

**What this does:**

- `ALLOW_USERS="$USER"` — adds your username to the config's list of permitted users
- `SYNC_ACL=yes` — tells Snapper to automatically set ACLs on `/.snapshots` and `/home/.snapshots` so your user can access them

Verify the settings were applied:

```bash
sudo snapper -c root get-config | grep -E "ALLOW_USERS|SYNC_ACL"
sudo snapper -c home get-config | grep -E "ALLOW_USERS|SYNC_ACL"
```

Expected output for both:

```
ALLOW_USERS          | yourusername
SYNC_ACL             | yes
```

Now verify the ACLs were actually set on the directories:

```bash
getfacl /.snapshots
getfacl /home/.snapshots
```

You should see your username listed with `r-x` (read + execute/traverse) permissions:

```
# file: .snapshots
# owner: root
# group: root
user::rwx
user:yourusername:r-x
group::r-x
mask::r-x
other::r-x
```

---

## Step 3.6 — Verify Both Configurations Exist

Check that Snapper recognizes both configurations:

```bash
sudo snapper list-configs
```

Expected output:

```
Config | Subvolume
-------+----------
root   | /
home   | /home
```

Test that your regular user can now run snapper commands without `sudo`:

```bash
snapper list
# Should show: "Type | # | Pre # | Date | User | Cleanup | Description | Userdata"
# Currently no snapshots exist yet, so the list will be empty

snapper -c home list
# Same — empty list
```

If both commands succeed without errors, your user permissions are set up correctly.

---

## What You Just Accomplished

1. ✅ Created Snapper configuration for the root filesystem (`/`)
2. ✅ Verified that Snapper is using the top-level `.snapshots` subvolume (not a nested one)
3. ✅ Created Snapper configuration for the home filesystem (`/home`)
4. ✅ Fixed SELinux contexts on both `/.snapshots` and `/home/.snapshots` so Snapper has permission to use them
5. ✅ Configured both configs to allow your regular user to manage snapshots
6. ✅ Enabled automatic ACL syncing so your user can access snapshot directories

**You are now ready to proceed to Step 4** (tuning Snapper retention settings).

---

## Troubleshooting

**Problem: `snapper create-config` fails with "config 'root' already exists"**

Check if a config file already exists:

```bash
ls /etc/snapper/configs/
```

If you see a `root` file but `snapper list-configs` doesn't show it, there's a registration mismatch. Delete the orphaned config and try again:

```bash
sudo rm /etc/snapper/configs/root
sudo snapper -c root create-config /
```

**Problem: After fixing the nested subvolume, Snapper still has issues**

Make sure you re-ran `restorecon` after deleting and remounting:

```bash
sudo restorecon -v /.snapshots
ls -ldZ /.snapshots
# Should show snapperd_data_t
```

**Problem: ACLs not showing up on `.snapshots` directories**

Try triggering the ACL sync manually:

```bash
sudo snapper -c root set-config SYNC_ACL=yes
sudo snapper -c home set-config SYNC_ACL=yes
getfacl /.snapshots
# Should now show your username
```

**Problem: Regular user still gets permission errors running `snapper list`**

Verify all three permission requirements are met:

1. User is in ALLOW_USERS: `sudo snapper -c root get-config | grep ALLOW_USERS`
2. SYNC_ACL is enabled: `sudo snapper -c root get-config | grep SYNC_ACL`
3. SELinux context is correct: `ls -ldZ /.snapshots` (should show `snapperd_data_t`)

If all three are correct but it still fails, try logging out and back in to refresh group memberships.

---
---
---

### Step 4 — Set the Root Subvolume as Btrfs Default and Remove the Hardcoded Kernel Argument

This step is what makes `snapper rollback` actually take effect on the next boot. Without it,
every boot ignores what Snapper set as the default and always mounts the `root` subvolume.

First, find the subvolume ID of your `root` subvolume:

```bash
sudo btrfs subvolume list /
# Find the line:  ID 257  top level 5  path root
# The ID will be 257 on most Fedora installs, but check yours
```

Set it explicitly as the Btrfs filesystem default:

```bash
sudo btrfs subvolume set-default 257 /
# Replace 257 with the actual ID from the output above

# Verify
sudo btrfs subvolume get-default /
# Output should show: ID 257 gen ... path root
```

Now remove the `rootflags=subvol=root` argument from every installed kernel's BLS entry.
This is the argument that currently overrides the Btrfs default:

```bash
sudo grubby --update-kernel=ALL --remove-args="rootflags=subvol=root"
```

Verify it was removed from all kernels:

```bash
sudo grubby --info=ALL | grep args
# None of the output should contain rootflags=subvol=root
```

**Reboot now** to confirm the system still boots correctly with this argument removed. The
system should boot identically to before because the Btrfs default is still the `root`
subvolume. Only future rollbacks will cause a different subvolume to be booted.

```bash
sudo reboot
```

After rebooting, verify:

```bash
sudo btrfs subvolume get-default /
# Should still show: ID 257 gen ... path root
```

---

### Step 5 — Tune Snapper Retention

The defaults keep too many snapshots and can fill your disk. Set practical limits for a
desktop system:

```bash
# Root: keep last 10 numbered snapshots, 5 that are marked important, no automatic timeline
sudo snapper -c root set-config \
  NUMBER_LIMIT=10 \
  NUMBER_LIMIT_IMPORTANT=5 \
  TIMELINE_CREATE=no

# Home: keep last 5 snapshots, no timeline
sudo snapper -c home set-config \
  NUMBER_LIMIT=5 \
  TIMELINE_CREATE=no
```

Enable the daily cleanup timer so old snapshots beyond these limits are pruned automatically:

```bash
sudo systemctl enable --now snapper-cleanup.timer
```

Prevent `plocate`/`mlocate` from crawling snapshot directories. Each snapshot contains a full
copy of your filesystem tree — without this exclusion, `updatedb` will index millions of
redundant files and run for a very long time:

```bash
sudo bash -c "echo 'PRUNENAMES = \".snapshots\"' >> /etc/updatedb.conf"
```

---

### Step 6 — Enable Automatic Snapshots for Every DNF Transaction

The old `python3-dnf-plugin-snapper` no longer works with DNF5. As of February 2026, a native
libdnf5 snapper plugin does not yet exist. The current community-endorsed solution is the
`libdnf5-plugin-actions` package with a shell script actions file. This is the approach
documented by Dusty Mabe (a Fedora engineer) in his Fedora 41 guide from January 2025 and
taken directly from the official DNF5 documentation.

Create the actions directory and file:

```bash
sudo mkdir -p /etc/dnf/libdnf5-plugins/actions.d

sudo tee /etc/dnf/libdnf5-plugins/actions.d/snapper.actions > /dev/null <<'EOF'
# Snapper pre/post snapshots for DNF5 transactions
# Emulates the behaviour of the old python3-dnf-plugin-snapper
# Source: https://dnf5.readthedocs.io/en/latest/libdnf5_plugins/actions.8.html

# Capture the command being run and store as description
pre_transaction::::/usr/bin/sh -c echo\ "tmp.snapper_descr=$(ps\ -o\ command\ --no-headers\ -p\ '${pid}')"

# Create the pre-transaction snapshot and store its number
pre_transaction::::/usr/bin/sh -c echo\ "tmp.snapper_pre_number=$(snapper\ create\ -t\ pre\ -p\ -d\ '${tmp.snapper_descr}')"

# Create the matching post-transaction snapshot and clear the stored variables
post_transaction::::/usr/bin/sh -c [\ -n\ "${tmp.snapper_pre_number}"\ ]\ &&\ snapper\ create\ -t\ post\ --pre-number\ "${tmp.snapper_pre_number}"\ -d\ "${tmp.snapper_descr}";\ echo\ tmp.snapper_pre_number;\ echo\ tmp.snapper_descr
EOF
```

Test it immediately:

```bash
sudo dnf install htop
snapper list
# You should now see two new entries:
# N  | pre  |   | <timestamp> | ... | dnf install htop
# N+1| post | N | <timestamp> | ... | dnf install htop
```

---

### Step 7 — Automatic Snapshot Before Every Reboot and Shutdown

This systemd service runs `snapper create` just before the system powers off or reboots. The
`Before=shutdown.target reboot.target halt.target poweroff.target` dependencies ensure it
fires in every power-off code path — including `systemctl reboot`, `shutdown -r`, the desktop
power menu, and holding the power button.

```bash
sudo tee /etc/systemd/system/snapper-pre-reboot.service > /dev/null <<'EOF'
[Unit]
Description=Snapper snapshot before shutdown or reboot
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target poweroff.target
After=snapper.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/snapper -c root create \
  --description "pre-reboot %(%Y-%m-%d %H:%M)" \
  --cleanup-algorithm number \
  --userdata "important=yes"

[Install]
WantedBy=shutdown.target reboot.target halt.target poweroff.target
EOF
```

Enable and test it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable snapper-pre-reboot.service

# Test: run it manually to verify it creates a snapshot
sudo systemctl start snapper-pre-reboot.service
snapper list
# A new snapshot with "pre-reboot" in the description should appear
```

---

### Step 8 — Create a Baseline Snapshot

Create a known-good reference point now that everything is configured:

```bash
sudo snapper -c root create \
  --description "post-setup-baseline" \
  --userdata "important=yes"

sudo snapper -c home create \
  --description "post-setup-baseline" \
  --userdata "important=yes"

snapper list
snapper -c home list
```

---

### Setup Complete — What Is Now Automatic

| Event | What Happens |
|-------|-------------|
| `sudo dnf install / remove / upgrade` | Pre and post snapshots created with command description |
| System reboot or shutdown | Snapshot created before power-off, marked important |
| Daily at 00:00 | Cleanup runs, enforces NUMBER_LIMIT, keeps important ones |
| Manual trigger | `snapper create --description "note"` |

---

## Part 2 — Recovery When the System Is Still Bootable

These scenarios assume you can log in. If you cannot boot at all, go to Part 3.

### Scenario A — A Package Install or Update Broke Something

The DNF5 actions plugin created a pre and post snapshot automatically. Find them:

```bash
snapper list
# Look for paired pre/post entries, for example:
# 8  | pre  |   | 2026-02-15 10:32 | ... | dnf install bad-package
# 9  | post | 8 | 2026-02-15 10:33 | ... | dnf install bad-package
```

**Option 1 — Surgical undo (preferred):** Reverts only the files changed by that specific
transaction, leaving everything else since then untouched:

```bash
# See exactly what files changed between pre and post
sudo snapper status 8..9

# Undo just those changes
sudo snapper undochange 8..9
```

**Option 2 — Full rollback to the pre-snapshot state:** Resets the entire root filesystem
to snapshot 8. Everything that happened after snapshot 8 is gone from root.

```bash
sudo snapper --ambit classic rollback 8
sudo reboot
```

After rebooting, your system is in the state it was at snapshot 8. The broken state is
preserved as a read-only snapshot in case you want to inspect it. You can delete it later.

---

### Scenario B — Rebooted Into a Broken But Still Bootable System

You rebooted and something is wrong but you can still log in. The pre-reboot snapshot exists:

```bash
snapper list
# Find the most recent "pre-reboot" entry

sudo snapper --ambit classic rollback <number>
sudo reboot
```

---

### Scenario C — You Accidentally Deleted or Overwrote a File

Snapper snapshots are stored as actual Btrfs snapshot subvolumes, directly accessible at
`/.snapshots/<number>/snapshot/`. You can browse them like a regular directory and copy
files out:

```bash
# Browse snapshot 5
ls /.snapshots/5/snapshot/etc/

# Check what changed between snapshot 5 and now
sudo snapper status 5..0

# Restore a single file
sudo cp /.snapshots/5/snapshot/etc/hosts /etc/hosts

# Restore a whole directory
sudo rsync -a /.snapshots/5/snapshot/etc/ssh/ /etc/ssh/
```

For home directory files:

```bash
# Home snapshots live here
ls /home/.snapshots/3/snapshot/yourusername/

# Restore a file
cp /home/.snapshots/3/snapshot/yourusername/.bashrc ~/
```

---

### Scenario D — Bad Kernel Update

Fedora keeps three kernel versions by default (`installonly_limit=3` in `/etc/dnf/dnf.conf`).
A bad kernel update does not remove the previous working kernel.

**Easiest path — select the previous kernel at boot:**

1. At GRUB, select **"Advanced options for Fedora"**
2. Choose the previous kernel version
3. Boot succeeds
4. Once logged in, remove the bad kernel if you want: `sudo dnf remove kernel-<version>`

**If that also fails,** use the pre-reboot snapshot and the rollback procedure from Scenario B
or the Live USB method from Part 3.

---

### Scenario E — A Config File Change Broke sudo, PAM, or Login

If you have a second terminal session open: restore the file directly from the latest snapshot:

```bash
sudo snapper list
sudo cp /.snapshots/<number>/snapshot/etc/sudoers /etc/sudoers
```

If you are fully locked out (no session, cannot sudo): boot from a GRUB advanced entry to
an older kernel to try to get in, or use the Live USB method from Part 3.

---

### Scenario F — A Previous Rollback Made Things Worse

When Snapper performs a rollback, it always preserves the state you rolled back *from* as a
read-only snapshot. You are never left without a way back:

```bash
snapper list
# Find the entry labelled "rollback backup of ..." — this is the state you rolled back from
sudo snapper --ambit classic rollback <that-number>
sudo reboot
```

---

## Part 3 — Recovery When the System Will Not Boot (Live USB)

This is your fallback for when `snapper rollback` cannot be run because the system is
completely unbootable. It is the honest recovery path for the "rebooted and can't get back in"
scenario.

You need: a Fedora Live USB (any recent version). Boot it and open a terminal.

**Step 1 — Identify your encrypted partition:**

```bash
lsblk
# Look for a partition of type crypto_LUKS — typically /dev/sda3 or /dev/nvme0n1p3
```

**Step 2 — Unlock the LUKS container:**

```bash
sudo cryptsetup open /dev/sda3 fedoraluks
# Enter your LUKS passphrase when prompted
# Adjust /dev/sda3 to match your actual partition
```

**Step 3 — Mount the Btrfs top level:**

```bash
sudo mkdir -p /mnt/btrfsroot
sudo mount /dev/mapper/fedoraluks -o subvolid=5 /mnt/btrfsroot
```

**Step 4 — List all subvolumes including snapshots:**

```bash
sudo btrfs subvolume list /mnt/btrfsroot
# You will see entries like:
# ID 256  top level 5    path home
# ID 257  top level 5    path root
# ID 259  top level 5    path .snapshots
# ID 260  top level 259  path .snapshots/1/snapshot   ← snapshot 1
# ID 261  top level 259  path .snapshots/2/snapshot   ← snapshot 2
# ...and so on
```

**Step 5 — Inspect a snapshot to find a working one:**

```bash
# Mount a candidate snapshot and look at it
sudo mkdir -p /mnt/inspect
sudo mount /dev/mapper/fedoraluks -o subvol=.snapshots/5/snapshot /mnt/inspect
ls /mnt/inspect
# Verify it looks like a healthy root filesystem

# When done inspecting
sudo umount /mnt/inspect
```

Check Snapper's info file for each snapshot to see its description and date:

```bash
cat /mnt/btrfsroot/.snapshots/5/info.xml
# Shows: type, date, description, userdata
```

**Step 6 — Set the chosen snapshot as the new default boot target:**

```bash
# Get the subvolume ID of the snapshot you want to boot
# From Step 4, e.g. ID 260 for .snapshots/1/snapshot
sudo btrfs subvolume set-default 260 /mnt/btrfsroot
```

**Step 7 — Unmount and reboot:**

```bash
sudo umount /mnt/btrfsroot
sudo reboot
# Remove the Live USB before the system boots
```

The system will now boot from the snapshot you selected.

**Step 8 — Convert the snapshot to a proper writable root (critical):**

After booting successfully, run Snapper's rollback to convert the snapshot from a temporary
default into a proper permanent root:

```bash
sudo snapper --ambit classic rollback
sudo reboot
```

This creates a clean new writable subvolume based on the snapshot, sets it as the default,
and preserves the original snapshot as a read-only reference. After this reboot, your system
is running normally from a stable, writable root.

---

## Part 4 — Day-to-Day Usage

### Listing Snapshots

```bash
# Root snapshots
snapper list

# Home snapshots
snapper -c home list

# All configs
sudo snapper list-configs
```

### Creating Manual Snapshots

Before doing anything that makes you nervous:

```bash
sudo snapper -c root create --description "before-editing-grub"

# Mark as important to protect from auto-cleanup
sudo snapper -c root create \
  --description "working-state-$(date +%Y-%m-%d)" \
  --userdata "important=yes"
```

### Seeing What Changed Between Snapshots

```bash
# Files that changed between snapshot 5 and now (0 means current)
sudo snapper status 5..0

# Files that changed between a pre/post pair
sudo snapper status 8..9

# Actual diff of a file
sudo snapper diff 8..9 -- /etc/hostname
```

### Deleting Snapshots

```bash
# Delete one snapshot
sudo snapper delete 5

# Delete a range
sudo snapper delete 5-10

# Run cleanup manually right now
sudo snapper cleanup number
```

### Checking Disk Space Used by Snapshots

```bash
# Overall Btrfs filesystem usage
sudo btrfs filesystem usage /

# How much space each snapshot exclusively uses
sudo btrfs filesystem du -s --human-readable /.snapshots/*/snapshot
```

Snapshot space is proportional to *how much changed* after the snapshot, not to time. A
snapshot taken five minutes before a `dnf upgrade` that updates hundreds of packages will
use significant space. A snapshot from a month ago that was followed by minimal changes
uses almost nothing.

### Recovering Space When Disk Is Getting Full

```bash
# Reduce retention limits
sudo snapper -c root set-config NUMBER_LIMIT=5 NUMBER_LIMIT_IMPORTANT=2

# Force cleanup immediately
sudo snapper cleanup number

# After deleting many snapshots, run a Btrfs balance pass to reclaim free blocks
# Safe on a live system; may take a while on large volumes
sudo btrfs balance start -dusage=50 /
```

---

## Scenario Reference

| What happened | Automated protection | Recovery |
|---------------|---------------------|----------|
| DNF broke the system, still bootable | Pre/post DNF snapshots | `snapper undochange pre..post` or `rollback` |
| Rebooted into broken but usable system | Pre-reboot snapshot | `snapper --ambit classic rollback N` + reboot |
| Bad kernel update, system won't boot | Fedora keeps 3 kernels | Boot previous kernel from GRUB Advanced Options |
| System completely unbootable | Pre-reboot snapshot | Live USB → `btrfs subvolume set-default` → reboot → `snapper rollback` |
| Accidentally deleted a file | Last snapshot before deletion | `cp` from `/.snapshots/N/snapshot/path/to/file` |
| Broke sudoers / PAM config | Last snapshot | `cp` config from snapshot, or Live USB method |
| Rolled back but it made things worse | Old state saved as snapshot | `snapper rollback` to previous rollback-backup |
| Home files corrupted or deleted | Home snapper config | `cp` from `/home/.snapshots/N/snapshot/` |

---

## Quick Command Reference

```bash
# List snapshots
snapper list

# Create a manual snapshot
sudo snapper create --description "my note"

# See what changed between snapshot 5 and now
sudo snapper status 5..0

# Undo only what changed between a pre/post pair
sudo snapper undochange 8..9

# Full rollback to snapshot 5 (then reboot)
sudo snapper --ambit classic rollback 5 && sudo reboot

# Delete snapshot 5
sudo snapper delete 5

# Restore one file from snapshot 5
sudo cp /.snapshots/5/snapshot/etc/hosts /etc/hosts

# --- Live USB recovery ---

# Unlock LUKS
sudo cryptsetup open /dev/sda3 fedoraluks

# Mount Btrfs top level
sudo mount /dev/mapper/fedoraluks -o subvolid=5 /mnt/btrfsroot

# List all subvolumes and snapshots
sudo btrfs subvolume list /mnt/btrfsroot

# Set snapshot ID 260 as default
sudo btrfs subvolume set-default 260 /mnt/btrfsroot

# Check Btrfs default subvolume (from running system)
sudo btrfs subvolume get-default /
```

---

## Honest Notes and Limitations

**`/boot` is never snapshotted.** Kernels and initramfs files live in `/boot` (ext4). Rolling
back root does not change which kernels are in `/boot`. Fedora's default of keeping three
kernels provides its own rollback protection for kernel issues independently of Snapper.
However: if you roll back to a very old snapshot and then manually removed kernels in the
meantime, you may end up in a state where the snapshot expects a kernel that no longer exists.
The mitigation is to never manually remove old kernels and to keep your rollback window
reasonable — rolling back weeks into the past is rarely necessary and carries more risk.

**Flatpak, AppImages, and firmware are not automatically snapshotted.** The DNF5 actions
plugin only fires for `dnf` transactions. Create a manual snapshot before installing or
updating Flatpaks if you want rollback protection for them. Firmware updates via `fwupd`
write to `/boot/efi` and `/boot` — entirely separate from Btrfs — and must be rolled back
using `fwupdmgr downgrade`, not Snapper.

**Snapshots do not cross subvolume boundaries.** A snapshot of `root` never touches `home`.
They are managed independently through separate Snapper configurations.

**A future Fedora change is in progress.** The Fedora Project Wiki documents an active change
proposal titled "BtrfsWithFullSystemSnapshots" that plans to integrate `snapm` (a snapshot
manager) and `boom` (a boot manager) natively into Fedora, which would provide proper GRUB
bootable snapshot entries without third-party tools. This work had not shipped in a stable
Fedora release as of February 2026. When it does ship, this guide will be superseded by the
native tooling.

---

**Document Version:** 3.0 — February 17, 2026  
**Primary source:** Dusty Mabe, "Fedora BTRFS+Snapper — The Fedora 41 Edition" (January 7, 2025)  
**Also consulted:** DNF5 official actions plugin documentation, Fedora Project Wiki
(Changes/BtrfsWithFullSystemSnapshots, Changes/BootLoaderSpecByDefault),
davejansen.com Fedora Btrfs guide, Fedora Discussion forums
