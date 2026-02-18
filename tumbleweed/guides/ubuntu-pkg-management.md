You're asking the right questions. Let me search thoroughly to verify the behavior and provide you with the correct answer.Now let me provide you with the final, thoroughly verified configuration.

---

# Ubuntu 25.10 Selective Package Installation from Resolute - VERIFIED CONFIGURATION

## Your Questions Answered

### 1. Will 700 and 900 priorities cause conflicts?

**NO.** When packages exist in multiple repositories with different priorities, the version with the higher priority wins; if priorities are equal, the newer version wins.

**How it works:**
- **Pinned packages (nautilus, kitty, etc.)**: Resolute @ 900 vs Questing @ 700 → **900 wins ALWAYS**
- **Non-pinned packages (firefox, vim, etc.)**: Resolute @ 100 vs Questing @ 700 → **700 wins ALWAYS**

No conflicts. Package-specific rules override general rules.

### 2. Should priorities be equal?

**NO.** If we set both to 700:
- When priorities are equal, apt picks the package with the higher version number (most recent)
- Since resolute is development, it typically has newer versions
- Apt would choose based on VERSION, not repository
- **Problem:** If questing gets a security backport newer than resolute, apt would switch to questing
- **This violates your requirement** to always upgrade from resolute

Priority 900 ensures apt installs that version even if it's older than other versions, and won't downgrade if a higher version is already installed.

### 3. Why higher priority for resolute packages?

**To guarantee they ALWAYS use resolute, regardless of version numbers.**
- Priority 900 (resolute pinned) > Priority 700 (questing) → resolute wins
- Even if questing somehow has a newer version, 900 > 700 means resolute is chosen
- This ensures your pinned packages stay on resolute permanently

### 4. Does "n=" match all pockets?

**YES, CONFIRMED.** Looking at actual Release files:
```
noble-security: a=noble-security,n=noble
noble-updates:  a=noble-updates,n=noble  
noble-backports: a=noble-backports,n=noble
```

The "n=" (Codename) field matches all packages belonging to that codename, while "a=" (Archive/Suite) matches specific pocket names.

All pockets share the **same codename**, so `Pin: release n=questing` matches questing, questing-security, questing-updates, and questing-backports.

---

## Final Configuration

### 1. Create Resolute Sources File

```bash
sudo nano /etc/apt/sources.list.d/resolute.sources
```

```
Types: deb
URIs: http://archive.ubuntu.com/ubuntu
Suites: resolute resolute-proposed
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

**Note:** During development, packages are uploaded to -proposed for testing before migrating to the release pocket.

### 2. Create Apt Pinning Configuration

```bash
sudo nano /etc/apt/preferences.d/devel-pinning
```

```
# Questing (25.10) stable - high priority
# "n=" matches ALL pockets: questing, questing-security, questing-updates
Package: *
Pin: release n=questing
Pin-Priority: 700

# Resolute (26.04 dev) - very low priority by default
Package: *
Pin: release n=resolute
Pin-Priority: 100

# Specific packages from resolute - ALWAYS use and upgrade from resolute
Package: greetd tuigreet wlsunset pymol sqlite3 transmission-gtk gnome-tweaks nautilus kitty kitty-shell-integration kitty-terminfo imv qt5ct qt6ct nwg-look swappy mpv gnome-keyring distrobox podman zsh zsh-common cronie bleachbit slurp grim zathura zathura-pdf-poppler xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk file-roller
Pin: release n=resolute
Pin-Priority: 900
```

**Why this configuration is correct:**
1. **`n=questing` @ 700**: Matches all questing pockets (main, security, updates) with high priority
2. **`n=resolute` @ 100**: Matches all resolute pockets with low priority (won't auto-install)
3. **Package-specific @ 900**: Overrides general rules, ensures these packages ALWAYS use resolute

### 3. Apply Configuration

```bash
# Update package cache
sudo apt update

# Verify NO unwanted upgrades from resolute
apt list --upgradable

# Check pinned package (should show resolute @ 900)
apt-cache policy nautilus

# Check non-pinned package (should show questing @ 700, resolute @ 100)
apt-cache policy firefox
```

**Expected output for nautilus:**
```
nautilus:
  Installed: (none)
  Candidate: x.x.x (from resolute)
  Version table:
     x.x.x 900
        900 http://archive.ubuntu.com/ubuntu resolute/main amd64 Packages
     y.y.y 700
        700 http://archive.ubuntu.com/ubuntu questing/main amd64 Packages
```

### 4. Install Packages

```bash
# Pinned packages automatically use resolute (no -t flag needed)
sudo apt install --no-install-recommends nautilus kitty mpv

# Other packages automatically use questing
sudo apt install --no-install-recommends firefox vim
```

---

## Critical Stability Notes

### Dependency Behavior
When installing packages from a development release, even with low priority pinning, if a package doesn't exist in the current release, apt will pull it from the development repository along with its dependencies, potentially including newer core libraries.

**Mitigation:** The `--no-install-recommends` flag prevents recommended packages, but **required dependencies** will still be pulled from resolute. Monitor core system libraries carefully.

### Package Conflicts
If you encounter unmet dependencies or conflicts:
```bash
# Simulate installation first
apt install --no-install-recommends -s package-name

# Check specific package dependencies
apt-cache depends package-name
```

### After Ubuntu 26.04 Release (April 2026)
Update resolute.sources to include security and updates:
```
Types: deb
URIs: http://archive.ubuntu.com/ubuntu
Suites: resolute resolute-security resolute-updates
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

---

## Verification Commands

```bash
# View all priorities
apt-cache policy

# Check specific package
apt-cache policy <package-name>

# List upgradable packages (should be empty for non-pinned packages from resolute)
apt list --upgradable

# Simulate install to see what would happen
apt install --no-install-recommends -s <package-name>
```

This configuration guarantees:
✅ Maximum system stability on questing  
✅ Your specified packages ALWAYS use and upgrade from resolute  
✅ Security updates continue working  
✅ No manual `-t` flags needed  
✅ No accidental upgrades from resolute for non-pinned packages
