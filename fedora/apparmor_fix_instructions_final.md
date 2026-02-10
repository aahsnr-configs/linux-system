# Complete Guide to Fixing AppArmor on Arch Linux and Choosing the Right Package

## Technical Deep Dive: Why This Problem Exists and Why the Fix Works

### Understanding AppArmor's Architecture

Before we dive into the fix, it's essential to understand how AppArmor works:

1. **Profiles** (`/etc/apparmor.d/*`): Define security policies for specific programs
2. **Tunables** (`/etc/apparmor.d/tunables/*`): Global variable definitions used across profiles
3. **Abstractions** (`/etc/apparmor.d/abstractions/*`): Reusable rule sets for common tasks

Every AppArmor profile starts with:

```
#include <tunables/global>
```

This includes global variables like `@{HOME}`, `@{PROC}`, `@{sys}`, and in apparmor 4.1.3, new variables like `pci_bus`.

### The Critical Problem: Duplicate Variable Definitions

The AppArmor parser is **extremely strict** about variable definitions. From the AppArmor bug tracker:

```bash
# echo '@{foo} = x @{foo} = y' | apparmor_parser -pq
'foo' is already defined
AppArmor parser error: variable @{foo} was previously declared
```

**The parser will completely refuse to load ANY profiles if it encounters duplicate variable definitions.** This isn't a warning - it's a fatal error that breaks your entire AppArmor setup.

### What Happened on Your System

When apparmor was updated to 4.1.3-1 on January 8, 2026, here's the sequence of events:

1. **Before the update**:
   - You had both `apparmor` (base package) and `apparmor.d` installed
   - Both provided `/etc/apparmor.d/tunables/global`, but ONE was active
   - AppArmor was working (though possibly improperly configured)

2. **During the apparmor 4.1.3 update**:
   - Pacman updated `/etc/apparmor.d/tunables/global` from base apparmor
   - This file now contains NEW variables including `pci_bus`
   - BUT: Your system also has apparmor.d's version of this file (or fragments of it)

3. **After the update**:
   - **Both packages' definitions are now active in the same files**
   - The tunable files contain duplicate definitions: `pci_bus` defined twice
   - The AppArmor parser encounters the duplicate and refuses to load
   - **Your entire AppArmor system is broken**

### Why the Files Conflict: The Design Requirement

Both packages **must** provide these files:

**Base apparmor package provides**:

- Minimal tunables with basic variables
- Simple abstractions for common tasks
- Works standalone for basic AppArmor usage

**apparmor.d package provides**:

- **Comprehensive tunables** with 1500+ profiles worth of variables
- **Extended abstractions** for complex application confinement
- **Must replace base tunables** to work properly

The apparmor.d project includes `<tunables/global>` in every single one of its 1500+ profiles. These profiles expect the comprehensive tunable definitions, not the minimal ones from base apparmor.

### Why Pacman Refuses to Install

Pacman's file conflict detection is a **safety feature**:

```
error: failed to commit transaction (conflicting files)
apparmor.d: /etc/apparmor.d/tunables/global exists in filesystem (owned by apparmor)
```

Pacman sees that:

1. `apparmor` package owns `/etc/apparmor.d/tunables/global`
2. `apparmor.d` wants to install its own `/etc/apparmor.d/tunables/global`
3. Pacman refuses because **overwriting another package's files could break things**

This is normally correct behavior! If two packages both want to provide the same file, it usually indicates a packaging problem.

### Why --overwrite is the Correct Solution

The `--overwrite` flag tells pacman: **"I understand these files conflict, and I explicitly authorize you to replace them."**

When you run:

```bash
sudo pacman -U apparmor.d-*.pkg.tar.zst \
  --overwrite 'etc/apparmor.d/tunables/*' \
  --overwrite 'etc/apparmor.d/abstractions/*'
```

You're telling pacman:

1. "I know `/etc/apparmor.d/tunables/global` is owned by the apparmor package"
2. "I explicitly want apparmor.d to replace it with its comprehensive version"
3. "This is intentional - apparmor.d's tunables supersede the base ones"

### Why This is Safe and Correct

This approach is safe because:

1. **By design**: apparmor.d is specifically designed to replace these files
   - The project documentation states this is required
   - The comprehensive tunables are **supersets** of the base ones
   - All variables from base apparmor are included, plus many more

2. **No data loss**: Tunable files contain only variable definitions, no user data
   - Example: `@{HOME} = /home/*/ /root/`
   - These are predefined system paths, not personal files

3. **Reversible**: You created a backup, and can always reinstall base apparmor

4. **Standard practice**: This has been the documented installation method since 2022

### How the Fix Works: Step-by-Step

When you follow the fix procedure:

**Step 1-2**: Stop AppArmor and create backup

- Prevents conflicts during file operations
- Ensures you can recover if needed

**Step 3**: Remove apparmor.d

```bash
sudo pacman -R apparmor.d apparmor.d-git
```

- Removes the broken apparmor.d installation
- But leaves the corrupted files on disk (pacman doesn't remove config files by default)

**Step 4**: Reinstall base apparmor

```bash
sudo pacman -S apparmor
```

- **This is the key step**: Forces pacman to reinstall ALL files from base apparmor
- Replaces any corrupted/mixed files with clean 4.1.3 versions
- Now `/etc/apparmor.d/tunables/global` contains ONLY base apparmor's definitions
- **No more duplicate `pci_bus` definitions**

**Step 5-6**: Install apparmor.d with --overwrite

```bash
sudo pacman -U apparmor.d-*.pkg.tar.zst --overwrite 'etc/apparmor.d/tunables/*'
```

- Pacman installs apparmor.d's files
- **Overwrites** `/etc/apparmor.d/tunables/global` with apparmor.d's comprehensive version
- **Overwrites** `/etc/apparmor.d/abstractions/*` with apparmor.d's extended abstractions
- Result: Clean installation with NO duplicates, using apparmor.d's comprehensive definitions

**Step 7**: Start AppArmor

- Parser reads the tunable files
- Finds ONLY apparmor.d's definitions (no duplicates!)
- Successfully loads all 1500+ profiles
- **System is fixed**

### Why Reinstalling Base AppArmor First is Critical

Many people might think: "Just use --overwrite to install apparmor.d over the existing mess."

**This doesn't work** because:

1. Your current files are **corrupted with mixed definitions**
   - They have BOTH base apparmor's `pci_bus` definition
   - AND apparmor.d's `pci_bus` definition (or fragments)
   - Simply overwriting won't remove all the duplicates

2. You need a **clean slate** with known-good base files
   - Reinstalling base apparmor ensures clean 4.1.3 tunables
   - Then overwriting with apparmor.d gives you clean comprehensive tunables

3. The order matters:
   - `apparmor` → clean minimal tunables (no duplicates)
   - `apparmor.d --overwrite` → clean comprehensive tunables (replace minimal)
   - Result: Working system with comprehensive profiles

### Why the PKGBUILD Can't Fix This Automatically

You might wonder: "Why doesn't the apparmor.d PKGBUILD just declare `replaces=` or `conflicts=`?"

**It can't, because**:

1. **apparmor.d depends on apparmor**
   - Needs the apparmor_parser tool
   - Needs the kernel modules
   - Needs the systemd service files
   - **Cannot conflict with a dependency**

2. **The relationship is complex**:
   - Not a simple "one replaces the other"
   - apparmor.d **augments** apparmor (adds 1500 profiles)
   - apparmor.d **supersedes** certain apparmor files (tunables/abstractions)
   - apparmor.d **uses** other apparmor components (parser, tools)

3. **User control is important**:
   - Using `--overwrite` makes the intent explicit
   - Users consciously authorize file replacement
   - Prevents accidental system changes

This is why the `--overwrite` method has been the standard installation procedure since the package was created.

## Understanding the Different apparmor.d Packages

There are **three variants** of the apparmor.d package available in the AUR:

### 1. apparmor.d (Stable Release)

- **Source**: Tagged releases from GitHub (currently v0.4900)
- **Update frequency**: Only updates when new stable versions are released
- **Stability**: Most tested and stable
- **Default mode**: Complain mode (violations logged but NOT blocked)
- **Recommended for**: Most users who want stability

### 2. apparmor.d-git (Development Version)

- **Source**: Latest development code from git main branch
- **Update frequency**: Gets latest features and fixes immediately
- **Stability**: Less tested, may have bugs
- **Default mode**: Complain mode (violations logged but NOT blocked)
- **Recommended for**: Users who want bleeding-edge features or need latest fixes

### 3. apparmor.d.enforced (Stable + Enforce Mode)

- **Source**: Same as stable (v0.4900) but configured differently
- **Update frequency**: Same as stable
- **Stability**: Same as stable
- **Default mode**: **Enforce mode** (violations are BLOCKED)
- **Recommended for**: Advanced users who have tested the profiles and want maximum security

## Understanding Profile Modes

AppArmor profiles can operate in two modes:

### Complain Mode (Default for apparmor.d and apparmor.d-git)

- **What it does**: Logs policy violations but does NOT block them
- **Purpose**: Safe for testing - won't break your system
- **When to use**: Initial installation, testing new profiles, development
- **Note**: Even in complain mode, explicit `deny` rules ARE enforced

### Enforce Mode (Default for apparmor.d.enforced)

- **What it does**: Blocks policy violations AND logs them
- **Purpose**: Provides actual security by preventing unauthorized access
- **When to use**: After testing in complain mode with no issues for at least a week
- **Warning**: Can break applications if profiles aren't properly configured for your system

## Do You Really Need the -git Version?

**Short answer: No, you probably don't need it.**

**Use the stable version (`apparmor.d`) if:**

- You want a stable, well-tested system
- You prefer fewer updates and less potential for breakage
- You're new to AppArmor
- Version 0.4900 (current stable) already supports apparmor 4.1.3

**Use the git version (`apparmor.d-git`) only if:**

- You need a specific fix that's only in the development branch
- You want to help test new features
- You're comfortable troubleshooting potential issues
- You need the absolute latest profile updates

**Important**: Both the stable and git versions have been updated to work with apparmor 4.1.3-1. The compatibility issue you're experiencing is due to improper installation, NOT because you need a different version.

## Your Current Problem: File Conflicts

The errors you're seeing:

```
'pci_bus' is already defined
AppArmor parser error for /etc/apparmor.d
Error: At least one profile failed to load
```

This is caused by **duplicate tunable definitions** from improperly merged files between:

1. Base `apparmor` package (version 4.1.3-1 from official repos)
2. Your existing `apparmor.d` installation

### Why This Happens

Both packages provide files in `/etc/apparmor.d/`:

- `/etc/apparmor.d/tunables/global`
- `/etc/apparmor.d/tunables/xdg-user-dirs`
- `/etc/apparmor.d/abstractions/trash`
- Various other configuration files

The `apparmor.d` package is **designed to replace** these files with comprehensive versions, but pacman's safety mechanism prevents this without explicit permission.

### Why the January 8, 2026 Update Made It Worse

When base apparmor updated to 4.1.3-1:

1. It added new tunables (like `pci_bus`) to these shared files
2. Your existing apparmor.d installation already had its own versions
3. Now both sets of definitions exist in the same files
4. The AppArmor parser sees duplicate definitions and refuses to load

## The Complete Fix (Works for All Versions)

Follow these steps regardless of which package variant you choose.

### Step 1: Stop AppArmor Service

```bash
sudo systemctl stop apparmor.service
```

### Step 2: Create a Backup

```bash
sudo cp -r /etc/apparmor.d /etc/apparmor.d.backup_$(date +%Y%m%d_%H%M%S)
```

### Step 3: Remove ALL Existing apparmor.d Packages

```bash
sudo pacman -R apparmor.d apparmor.d-git apparmor.d.enforced
```

If none are installed, that's fine - proceed to the next step.

### Step 4: Reinstall Base AppArmor

```bash
sudo pacman -S apparmor
```

This ensures you have clean 4.1.3-1 files with no conflicts.

### Step 5: Choose and Install Your Preferred Package

**Choose ONE of the following options:**

#### Option A: Install Stable Version (Recommended for Most Users)

```bash
cd /tmp
rm -rf apparmor.d
git clone https://aur.archlinux.org/apparmor.d.git
cd apparmor.d
makepkg -s

# Install with overwrite flags
sudo pacman -U apparmor.d-*.pkg.tar.zst \
  --overwrite 'etc/apparmor.d/tunables/*' \
  --overwrite 'etc/apparmor.d/abstractions/*'
```

**Or using an AUR helper:**

```bash
paru -S apparmor.d \
  --overwrite='etc/apparmor.d/tunables/*' \
  --overwrite='etc/apparmor.d/abstractions/*'
```

#### Option B: Install Git Version (Latest Development Code)

```bash
cd /tmp
rm -rf apparmor.d-git
git clone https://aur.archlinux.org/apparmor.d-git.git
cd apparmor.d-git
makepkg -s

# Install with overwrite flags
sudo pacman -U apparmor.d-*.pkg.tar.zst \
  --overwrite 'etc/apparmor.d/tunables/*' \
  --overwrite 'etc/apparmor.d/abstractions/*'
```

**Or using an AUR helper:**

```bash
yay -S apparmor.d-git \
  --overwrite='etc/apparmor.d/tunables/*' \
  --overwrite='etc/apparmor.d/abstractions/*'
```

#### Option C: Install Enforced Version (Advanced Users Only)

**WARNING**: Only use this if you've already tested the profiles in complain mode for at least a week!

```bash
cd /tmp
rm -rf apparmor.d.enforced
git clone https://aur.archlinux.org/apparmor.d.enforced.git
cd apparmor.d.enforced
makepkg -s

# Install with overwrite flags
sudo pacman -U apparmor.d.enforced-*.pkg.tar.zst \
  --overwrite 'etc/apparmor.d/tunables/*' \
  --overwrite 'etc/apparmor.d/abstractions/*'
```

**Or using an AUR helper:**

```bash
yay -S apparmor.d.enforced \
  --overwrite='etc/apparmor.d/tunables/*' \
  --overwrite='etc/apparmor.d/abstractions/*'
```

### Step 6: Enable Profile Caching (Highly Recommended)

AppArmor.d contains over 100,000 lines of rules. Enable caching for faster loading:

```bash
echo 'write-cache' | sudo tee -a /etc/apparmor/parser.conf
echo 'cache-loc /etc/apparmor/earlypolicy/' | sudo tee -a /etc/apparmor/parser.conf
echo 'Optimize=compress-fast' | sudo tee -a /etc/apparmor/parser.conf
```

### Step 7: Start AppArmor Service

```bash
sudo systemctl start apparmor.service
```

### Step 8: Verify Installation

Check service status:

```bash
sudo systemctl status apparmor.service
```

Expected output: `Active: active (exited)` with no error messages.

Check loaded profiles:

```bash
sudo aa-status
```

You should see hundreds of profiles loaded (typically 400-1500 depending on your system).

Check for errors:

```bash
sudo journalctl -xeu apparmor.service --no-pager | grep -i error
```

The "pci_bus is already defined" errors should be completely gone.

## Post-Installation: Testing and Monitoring

### If You Installed apparmor.d or apparmor.d-git (Complain Mode)

Your system is safe - profiles are only logging violations, not blocking them. However, you should still monitor for issues:

#### Monitor AppArmor Denials

```bash
# View recent denials
sudo journalctl -b | grep -i "apparmor.*denied" | tail -20

# Continuously monitor for new denials
sudo journalctl -f | grep -i "apparmor.*denied"
```

#### Use aa-log for Better Formatting

```bash
# View all AppArmor logs
sudo aa-log

# View logs for a specific profile
sudo aa-log firefox
```

**Note**: aa-log may show errors about dbus-broker - these are tool limitations and can be ignored.

#### Testing Period (Recommended)

Use your system normally for at least a week while monitoring logs. After this period with no issues:

1. Review the logs: `sudo aa-log`
2. If you see repeated denials for legitimate actions, you may need to adjust profiles
3. If no issues occur, you can optionally switch to enforce mode

#### Switching Individual Profiles to Enforce Mode

Once tested, you can enforce specific profiles:

```bash
# Enforce a single profile
sudo aa-enforce /etc/apparmor.d/firefox

# Enforce all profiles
sudo aa-enforce /etc/apparmor.d/*

# Revert a profile to complain mode if issues occur
sudo aa-complain /etc/apparmor.d/firefox
```

### If You Installed apparmor.d.enforced (Enforce Mode)

Your profiles are actively blocking violations. If something breaks:

#### Troubleshooting Broken Applications

1. **Check recent denials**:

   ```bash
   sudo aa-log | tail -50
   ```

2. **Identify the problematic profile**:
   Look for repeated DENIED messages related to the broken application.

3. **Put the profile in complain mode**:

   ```bash
   sudo aa-complain /etc/apparmor.d/[profile-name]
   sudo systemctl reload apparmor.service
   ```

4. **Test if the application works now**:
   - If yes, the profile needs adjustment
   - If no, the issue is unrelated to AppArmor

5. **Report or fix the profile**:
   - Report issues to: https://github.com/roddhjav/apparmor.d/issues
   - Or adjust the profile yourself using local overrides

## Why --overwrite is Required (Not Optional)

The `--overwrite` flags tell pacman: _"Yes, I know these files are owned by the base apparmor package. Replace them with apparmor.d's versions - this is intentional."_

This is **the documented installation method** and has been standard practice since 2022 (see GitHub Issue #25). It's not a workaround - it's the correct way to install comprehensive AppArmor profile sets on Arch Linux.

### Why the PKGBUILD Doesn't Handle This

The apparmor.d PKGBUILD cannot declare `conflicts=` or `replaces=` for base apparmor because:

1. apparmor.d **depends on** the base apparmor package for the parser and tools
2. The file replacement is intentional design - apparmor.d's comprehensive tunables supersede the minimal base ones
3. Using `--overwrite` gives users explicit control over the installation

This same requirement exists for the stable, git, and enforced variants.

## About dbus-broker and aa-log Errors

### dbus-broker is Fine

You mentioned that dbus-broker is a systemd requirement and can't be replaced. **This is correct, and you don't need to replace it!**

The apparmor.d package is designed to work with dbus-broker on Arch Linux. The original `aa-log` errors about dbus-broker were just tool limitations in parsing certain AppArmor audit messages, not actual compatibility issues.

### aa-log Limitations

The `aa-log` tool has known parsing limitations with:

- Profile transitions involving dbus-broker
- Certain change_onexec operations
- Some label parsing edge cases

**These errors don't affect AppArmor's functionality.** Use these alternatives:

```bash
# View denials in journal
sudo journalctl -b | grep -i "apparmor.*denied"

# View all AppArmor messages
sudo journalctl -b | grep -i apparmor

# Check profile status
sudo aa-status
```

## Future Updates

### When Base apparmor Updates

When the base apparmor package updates in the future:

1. Update base apparmor: `sudo pacman -S apparmor`
2. Rebuild and reinstall your chosen apparmor.d variant with the same --overwrite flags

### When apparmor.d Updates

```bash
# For stable version
yay -S apparmor.d \
  --overwrite='etc/apparmor.d/tunables/*' \
  --overwrite='etc/apparmor.d/abstractions/*'

# For git version
yay -S apparmor.d-git \
  --overwrite='etc/apparmor.d/tunables/*' \
  --overwrite='etc/apparmor.d/abstractions/*'

# For enforced version
yay -S apparmor.d.enforced \
  --overwrite='etc/apparmor.d/tunables/*' \
  --overwrite='etc/apparmor.d/abstractions/*'
```

## Recommendation: Which Package to Choose?

### For Most Users: apparmor.d (Stable)

Choose the **stable version** if you want:

- Tested, reliable profiles
- Fewer updates
- Less potential for issues
- A system that "just works"

The stable version (0.4900) is fully compatible with apparmor 4.1.3 and provides excellent security in complain mode.

### For Advanced Users: apparmor.d-git

Choose the **git version** only if you:

- Need a specific fix only in development
- Want to contribute to development
- Enjoy living on the bleeding edge
- Don't mind occasional issues

### For Security-Focused Power Users: apparmor.d.enforced

Choose the **enforced version** only if you:

- Have already tested profiles in complain mode for a week+
- Are comfortable troubleshooting profile issues
- Need maximum security with active blocking
- Understand you may need to adjust profiles for your workflow

**Important**: Start with the regular version (complain mode) even if you plan to use enforce mode eventually. Test first!

## Summary

1. **Your problem**: File conflicts from improperly merged apparmor and apparmor.d installations
2. **The fix**: Reinstall both packages with `--overwrite` flags
3. **Package choice**: Use `apparmor.d` (stable) unless you have a specific reason for git or enforced
4. **Not using -git**: You don't need the git version - the stable version (0.4900) fully supports apparmor 4.1.3
5. **Enforced vs Regular**: Regular (complain mode) is safer for initial installation; enforced blocks violations but can break things

The key insight: Your issue isn't about which variant to use - it's about using the correct installation method (`--overwrite` flags) for whichever variant you choose.

## Additional Resources

- **AppArmor.d Documentation**: https://apparmor.pujol.io/
- **AppArmor.d GitHub**: https://github.com/roddhjav/apparmor.d
- **Installation Guide**: https://apparmor.pujol.io/install/
- **Enforce Mode Guide**: https://apparmor.pujol.io/enforce/
- **Arch Wiki - AppArmor**: https://wiki.archlinux.org/title/AppArmor
- **GitHub Issue #25** (File Conflicts): https://github.com/roddhjav/apparmor.d/issues/25
