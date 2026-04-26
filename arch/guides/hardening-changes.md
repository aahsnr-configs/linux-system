## Changes Required — Single TPM‑PIN Unlock for Two LUKS Devices

### Problem Summary

The original guide enrolls the TPM‑2 into **both** NVMe drives with the same PIN.  Because `systemd‑cryptsetup` processes `/etc/crypttab` entries as independent services, it would ask for the PIN twice — once for each LUKS container.  The Arch Linux forums confirm this exact behaviour.

### Solution Architecture — *Drive‑1: TPM‑2+PIN, Drive‑2: embedded keyfile*

The integrity of the RAID‑0 stripe guarantees that **neither drive alone yields any plain‑text data**.  Therefore:

1. **nvme0n1** (first PV) is unlocked with TPM‑2 + PIN at boot — this is the **single** PIN prompt.
2. A **random keyfile** is added as a second LUKS keyslot to **nvme1n1**.  That keyfile lives inside the signed UKI (on the unencrypted ESP), so it is available immediately once the UKI is loaded.
3. The second LUKS container is unlocked *silently* by the keyfile.  No second PIN is required.

Because the LVM RAID‑0 stripe requires **both** decrypted mapper devices to assemble the volume group, an attacker who extracts the keyfile from the ESP still cannot access any data without the TPM‑2 + PIN that protects the first drive.

---

## Changed Sections

### ① Part 1.3 — Full Disk Encryption (TPM2 Enrollment)

**Old (original guide) — TPM‑2 enrolled on both drives:**

```bash
for dev in nvme0n1 nvme1n1; do
    systemd‑cryptenroll --tpm2‑device=auto \
      --tpm2‑pcrs="7+11" \
      --tpm2‑with‑pin=yes \
      /dev/${dev}
done
```

**New — TPM‑2 ONLY on first drive; keyfile slots on both:**

```bash
# 1. Generate a high‑entropy keyfile (64 bytes = 512 bits)
sudo dd if=/dev/urandom of=/etc/cryptsetup‑keys.d/luks‑keyfile.bin \
        bs=64 count=1 iflag=fullblock
sudo chmod 0400 /etc/cryptsetup‑keys.d/luks‑keyfile.bin

# 2. Add the keyfile as a LUKS keyslot on BOTH drives
sudo cryptsetup luksAddKey /dev/nvme0n1 /etc/cryptsetup‑keys.d/luks‑keyfile.bin
sudo cryptsetup luksAddKey /dev/nvme1n1 /etc/cryptsetup‑keys.d/luks‑keyfile.bin

# 3. Enroll TPM‑2 ONLY on the first drive (nvme0n1)
sudo systemd‑cryptenroll --tpm2‑device=auto \
    --tpm2‑pcrs="7+11" \
    --tpm2‑with‑pin=yes \
    /dev/nvme0n1

# 4. Recovery key on both (safety net)
sudo systemd‑cryptenroll --recovery‑key /dev/nvme0n1
sudo systemd‑cryptenroll --recovery‑key /dev/nvme1n1
```

**Why this works**: nvme0n1 has **three** keyslots — passphrase, recovery key, TPM‑2.  nvme1n1 has **two** — passphrase, recovery key, plus the keyfile.  The keyfile decrypts nvme1n1 silently; only nvme0n1 triggers the PIN prompt.

---

### ② Part 1.4 — Dracut UKI Configuration (Embed the Keyfile)

**Old `/etc/dracut.conf.d/99‑uki.conf`:**

```bash
add_dracutmodules+=" systemd systemd‑initrd crypt lvm btrfs tpm2‑tss "
```

**New — add the keyfile and the TPM‑2 cryptsetup token library:**

```bash
# /etc/dracut.conf.d/99‑uki.conf
add_dracutmodules+=" systemd systemd‑initrd crypt lvm btrfs tpm2‑tss "

# Embed the keyfile inside the initramfs (which is itself inside the signed UKI)
install_items+=" /etc/cryptsetup‑keys.d/luks‑keyfile.bin "

# Required so that the TPM‑2 token can be read in the initramfs
install_items+=" /usr/lib/cryptsetup/libcryptsetup‑token‑systemd‑tpm2.so "
```

---

### ③ New Section — `/etc/crypttab.initramfs`

The `crypttab` that Dracut copies into the initramfs must tell systemd how to unlock each LUKS container.

```bash
# /etc/crypttab.initramfs
# <name>   <device>          <keyfile or “‑”>           <options>

# First drive — TPM‑2 + PIN (keyfile column “‑” means “ask TPM/PIN”)
crypt0     UUID=<UUID‑nvme0n1>   ‑   tpm2‑device=auto

# Second drive — unlocked by the embedded keyfile
crypt1     UUID=<UUID‑nvme1n1>   /etc/cryptsetup‑keys.d/luks‑keyfile.bin   luks
```

**Effect**: `systemd‑cryptsetup@crypt0.service` uses TPM‑2 + PIN → one prompt.  `systemd‑cryptsetup@crypt1.service` uses the keyfile → no prompt.  After both are open, LVM assembles `vg0` from `/dev/mapper/crypt0` and `/dev/mapper/crypt1`.

---

### ④ Part 11 — PAM Hardening: Add TPM‑2‑Backed Sudo Authentication

**4a. Install `pinpam`** — a PAM module that stores a PIN in TPM NVRAM with hardware brute‑force lockout.

```bash
pkgman.py aur pinpam
```

**4b. Re‑initialise the PIN (run as each user):**

```bash
pinutil init
# Enter a numeric PIN when prompted — this is stored inside the TPM
```

**4c. Modify `/etc/pam.d/sudo`** — add `pinpam` **before** `pam_unix` so the TPM PIN is tried first:

```
#%PAM-1.0
auth       required                    pam_faillock.so      preauth
auth       sufficient                  pam_pinpam.so
auth       required                    pam_unix.so
auth       [default=die]               pam_faillock.so      authfail
account    required                    pam_unix.so
account    required                    pam_faillock.so
session    required                    pam_unix.so
```

Now typing the TPM PIN at a `sudo` prompt authenticates without the Unix password.

---

### ⑤ New Section — Unlock GNOME Keyring/KDE Wallet with the TPM‑2 PIN

`systemd‑cryptsetup` automatically stores the LUKS PIN in the kernel keyring during boot.  The PAM module `pam_systemd_loadkey` can read it and pass it to `pam_gnome_keyring` or `pam_kwallet5` so that the user’s secret store is unlocked at login without another prompt.

**Add to `/etc/pam.d/gdm‑password` (and/or `/etc/pam.d/login`) just before the session line:**

```
session    optional                    pam_systemd_loadkey.so
session    optional                    pam_gnome_keyring.so auto_start
```

If you use KDE, replace `pam_gnome_keyring` with `pam_kwallet5`.  The key‑ring password must match the LUKS PIN — set it once with `seahorse` (GNOME) or `kwalletmanager` (KDE).

---

### ⑥ New Section — Bitwarden “Unlock with system authentication”

Bitwarden’s desktop client uses a **Polkit** action (`com.bitwarden.Bitwarden.unlock`) to authenticate the user via the system PAM stack.  Once PAM is augmented with `pinpam` (④) and the key‑ring is auto‑unlocked (⑤), the flow is:

1. **First unlock after app start**: Bitwarden still requires the master password or the **Bitwarden PIN** (a *separate* PIN stored in the vault itself, not in the TPM).  This is a deliberate security design — the vault decryption key is only derived after this first unlock.
2. **Subsequent locks**: In Bitwarden **Settings → Unlock with system authentication** becomes available.  When enabled, unlocking the vault calls Polkit, which authenticates via `pam_pinpam` — you enter your TPM‑2 PIN (the same one used for LUKS and sudo).

**Summary**: Bitwarden **cannot** be unlocked purely by the TPM at app start, but after the first daily unlock, the TPM‑2 PIN replaces the master password for every subsequent lock/unlock cycle.

**Manual Polkit rule** (if not installed automatically):

```bash
sudo tee /usr/share/polkit‑1/actions/com.bitwarden.Bitwarden.policy << 'EOF'
<?xml version="1.0" encoding="UTF‑8"?>
<!DOCTYPE policyconfig PUBLIC
 "‑//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/PolicyKit/1.0/policyconfig.dtd">
<policyconfig>
  <action id="com.bitwarden.Bitwarden.unlock">
    <description>Unlock Bitwarden</description>
    <message>Authenticate to unlock Bitwarden</message>
    <defaults>
      <allow_any>no</allow_any>
      <allow_inactive>no</allow_inactive>
      <allow_active>auth_self</allow_active>
    </defaults>
  </action>
</policyconfig>
EOF
```

---

## Implementation Checklist

| Step | Where | What changes | Impact |
|---|---|---|---|
| ① | Part 1.3 | Enroll TPM‑2 only on nvme0n1; add keyfile keyslot to **both** drives | Single PIN prompt at boot |
| ② | Part 1.4 | Add `luks‑keyfile.bin` and `libcryptsetup‑token‑systemd‑tpm2.so` to dracut’s `install_items` | Keyfile available in initramfs |
| ③ | New | Create `/etc/crypttab.initramfs` with asymmetric unlock strategy | Silent unlock of second drive |
| ④ | Part 11 | Install `pinpam`; add `pam_pinpam.so` to `/etc/pam.d/sudo` | TPM‑2 PIN replaces sudo password |
| ⑤ | New | Add `pam_systemd_loadkey` to GDM/login PAM stack | GNOME Keyring / KDE Wallet auto‑unlocked |
| ⑥ | New | Bitwarden Polkit rule + enable “Unlock with system authentication” | Bitwarden re‑locked vaults unlocked with TPM‑2 PIN |
