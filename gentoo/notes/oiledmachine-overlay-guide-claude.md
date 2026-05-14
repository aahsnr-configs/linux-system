# Selective Package Installation from `oiledmachine-overlay` on Gentoo

> **Audience:** Experienced Gentoo users on a stable (`amd64`) profile who do **not** set `~amd64` globally, and want surgical control over which packages they pull from the `oiledmachine-overlay`.

---

## Table of Contents

1. [What Is the oiledmachine-overlay?](#1-what-is-the-oiledmachine-overlay)
2. [Prerequisites](#2-prerequisites)
3. [Adding the Overlay](#3-adding-the-overlay)
4. [Hard-Masking the Entire Overlay (Critical First Step)](#4-hard-masking-the-entire-overlay-critical-first-step)
5. [Configuring repos.conf Priority](#5-configuring-reposconf-priority)
6. [Selectively Unmasking Specific Packages](#6-selectively-unmasking-specific-packages)
7. [Accepting ~amd64 Keywords Per-Package](#7-accepting-amd64-keywords-per-package)
8. [Handling Custom and Non-Free Licenses](#8-handling-custom-and-non-free-licenses)
9. [Configuring USE Flags for Overlay Packages](#9-configuring-use-flags-for-overlay-packages)
10. [Inspecting Package Metadata Before Installing](#10-inspecting-package-metadata-before-installing)
11. [Installing a Package](#11-installing-a-package)
12. [Overlay-Specific Concepts and Pitfalls](#12-overlay-specific-concepts-and-pitfalls)
13. [Syncing and Staying Current](#13-syncing-and-staying-current)
14. [Reading Overlay News Items](#14-reading-overlay-news-items)
15. [Ongoing Package Management](#15-ongoing-package-management)
16. [Removing Packages from the Overlay](#16-removing-packages-from-the-overlay)
17. [Undoing Everything — Removing the Overlay](#17-undoing-everything--removing-the-overlay)
18. [Reference: File Cheat Sheet](#18-reference-file-cheat-sheet)

---

## 1. What Is the oiledmachine-overlay?

The **oiledmachine-overlay** is an unofficial Gentoo ebuild repository maintained by Orson Teodoro (`orsonteodoro` on GitHub). It is officially registered with the Gentoo overlays infrastructure at [`repos.gentoo.org`](https://repos.gentoo.org). Its stated goal is that a Gentoo system should run like a "well-oiled machine" — never sluggish under heavy I/O or memory pressure.

The overlay's focus includes:

- **Game development** toolkits and engines (Godot, Box2D, MonoGame, etc.)
- **AI/ML packages** (ROCm, various LLM-adjacent tooling)
- **PGO- and BOLT-optimised ebuilds** for packages like Firefox, GCC, the Linux kernel (`ot-sources`), and others
- **Security-hardened builds** with LLVM CFI, AddressSanitizer, and UndefinedBehaviorSanitizer integration
- **Miscellaneous apps** not present or outdated in the main tree

**Important characteristics you must understand before using it:**

- The overlay is **large**, and package quality varies significantly across ebuilds.
- Many packages carry **`~amd64`** keywords only (no stable keyword). Some have **no keywords at all** (`**`).
- A number of ebuilds introduce **overlay-specific USE flag prefixes** (e.g., `gcc_slot_*`) absent from the main tree.
- Packages with known critical vulnerabilities or defunct upstreams may be **hard-masked** inside the overlay's own `profiles/package.mask`.
- Some non-free packages require **manually downloading proprietary installers** before `emerge` will proceed.
- Old ebuilds are removed aggressively; packages may disappear without deprecation warnings.

---

## 2. Prerequisites

Ensure the following packages are installed:

```sh
emerge -av app-eselect/eselect-repository dev-vcs/git app-portage/gentoolkit
```

- `eselect-repository` — the modern replacement for `layman` for managing overlay repositories.
- `git` — required because the overlay uses Git as its sync method.
- `gentoolkit` — provides `epkginfo`, `equery`, `eclean`, etc., all of which are invaluable for overlay management.

Verify that `/etc/portage/repos.conf` exists (as a directory, preferably):

```sh
ls /etc/portage/repos.conf/
# Should show at least: gentoo.conf
```

If `repos.conf` is a flat file rather than a directory, that is fine too — `eselect repository` handles both.

---

## 3. Adding the Overlay

Register the overlay using `eselect repository`:

```sh
eselect repository add oiledmachine-overlay git https://github.com/orsonteodoro/oiledmachine-overlay.git
```

This creates `/etc/portage/repos.conf/eselect-repo.conf` (or appends a stanza to a single `repos.conf`) with content like:

```ini
[oiledmachine-overlay]
location = /var/db/repos/oiledmachine-overlay
sync-type = git
sync-uri = https://github.com/orsonteodoro/oiledmachine-overlay.git
auto-sync = yes
```

Now perform an initial sync:

```sh
emaint sync -r oiledmachine-overlay
```

> **Note:** Do **not** run `emerge --sync` at this point without first completing Step 4. Without hard-masking, the overlay's packages will immediately become visible and may shadow packages in the main Gentoo tree, potentially offering newer (unstable) versions that Portage could try to pull in during a world update.

Confirm the overlay synced correctly and the repository name is recognised:

```sh
eselect repository list -i
# Should show: [*] oiledmachine-overlay
```

Verify the internal repo name matches:

```sh
cat /var/db/repos/oiledmachine-overlay/profiles/repo_name
# Output: oiledmachine-overlay
```

The repo name is `oiledmachine-overlay`. This matters when constructing `::oiledmachine-overlay` atom suffixes.

---

## 4. Hard-Masking the Entire Overlay (Critical First Step)

**This is the single most important step.** Because the overlay is large and of variable quality, the Gentoo Wiki best practice for such overlays is to hard-mask the entire repository and then surgically unmask only the packages you actually need.

Create a mask file for the overlay. Using a directory-based `package.mask` is strongly preferred:

```sh
mkdir -p /etc/portage/package.mask
```

Add a single line that masks every package from the overlay:

```sh
# FILE: /etc/portage/package.mask/oiledmachine-overlay
# Hard-mask everything from oiledmachine-overlay.
# Unmask only specific packages in /etc/portage/package.unmask/
*/*::oiledmachine-overlay
```

With this in place, **no package from the overlay will be visible to Portage**, regardless of whether they have keywords. Your system updates remain entirely unaffected by the overlay's contents until you explicitly opt-in.

---

## 5. Configuring repos.conf Priority

By default, overlays have priority `0`, higher than the main Gentoo tree's `-1000`. This means any package in the overlay with the same atom as the main tree would normally shadow the main-tree version. The mask from Step 4 already prevents this, but it is still good hygiene to set an explicit priority.

Edit `/etc/portage/repos.conf/eselect-repo.conf` (or whichever file was created by `eselect repository`):

```ini
[oiledmachine-overlay]
location = /var/db/repos/oiledmachine-overlay
sync-type = git
sync-uri = https://github.com/orsonteodoro/oiledmachine-overlay.git
auto-sync = yes
priority = 50
```

A priority of `50` is higher than the Gentoo tree (`-1000`) but lower than a local overlay you might maintain. This ensures that when you unmask a specific package, the overlay version wins over the main tree for that atom, which is usually the intent. You can adjust this value as needed.

Verify priorities with:

```sh
emerge --info -v | grep -A3 "oiledmachine"
```

---

## 6. Selectively Unmasking Specific Packages

Once the entire overlay is hard-masked, you unmask individual packages you want to install. This uses `/etc/portage/package.unmask`.

```sh
mkdir -p /etc/portage/package.unmask
```

**Example: Unmask a specific package (e.g., `sci-libs/rocm-opencl-runtime`):**

```sh
# FILE: /etc/portage/package.unmask/oiledmachine-overlay
# Unmask specific packages from oiledmachine-overlay.

# ROCm OpenCL runtime (overlay provides newer version with extra patches)
sci-libs/rocm-opencl-runtime::oiledmachine-overlay

# ot-sources (PGO-optimised kernel sources)
sys-kernel/ot-sources::oiledmachine-overlay
```

The `::oiledmachine-overlay` suffix tells Portage that the unmask applies only to that specific package *from this overlay*, not to same-named packages from the main tree.

**Version-pinning the unmask** (recommended for stability):

If you only want a specific version, use a versioned atom:

```sh
=sci-libs/rocm-opencl-runtime-6.2.1::oiledmachine-overlay
```

This prevents Portage from automatically pulling in a newer (potentially broken) version from the overlay when you run `emerge -uDN @world`.

> **About the overlay's own `profiles/package.mask`:** The overlay ships its own internal `profiles/package.mask` for ebuilds the maintainer considers unsafe or defunct. When you unmask with `/etc/portage/package.unmask`, you are **not** overriding the overlay's internal masks — those are a different mechanism (`package.mask` inside a profile is a hard mask from the profile level, which requires using `package.unmask` in `/etc/portage` to override). In practice, if a package is in the overlay's own `profiles/package.mask`, you should treat that as a strong signal to not install it; it means the maintainer considers it broken or dangerous.

---

## 7. Accepting ~amd64 Keywords Per-Package

Almost all packages in the oiledmachine-overlay are keyworded `~amd64` (testing), and many have no keyword at all (requiring `**`). Since you run a stable profile and do not set `ACCEPT_KEYWORDS="~amd64"` globally, you must accept keywords on a per-package basis.

```sh
mkdir -p /etc/portage/package.accept_keywords
```

**For a `~amd64`-keyworded package:**

```sh
# FILE: /etc/portage/package.accept_keywords/oiledmachine-overlay

# Accept testing keyword for ot-sources
sys-kernel/ot-sources ~amd64

# Accept testing keyword for a specific version only (preferred)
=sci-libs/rocm-opencl-runtime-6.2.1 ~amd64
```

**For a package with no keyword at all (missing keyword / `**` case):**

Some overlay ebuilds have empty or missing KEYWORDS. Use `**` to accept any keyword state:

```sh
# Accept regardless of keyword status (use sparingly, only when you know the risk)
dev-games/godot **
```

**Checking what keyword a package requires:**

```sh
# Use equery to find keyword status
equery -q list -po dev-games/godot

# Or inspect the ebuild directly
grep KEYWORDS /var/db/repos/oiledmachine-overlay/dev-games/godot/godot-*.ebuild
```

**Keyword acceptance with `--autounmask`:**

When you attempt to `emerge` an overlay package, Portage will often tell you what keywords and unmask entries are needed. Use:

```sh
emerge -pv --autounmask --autounmask-write =dev-games/godot-4.3::oiledmachine-overlay
```

Review the proposed changes carefully, then apply them:

```sh
dispatch-conf
# or
etc-update
```

**Never blindly apply `--autounmask-write` output without reviewing it.** It may propose accepting keywords for dependency packages in the main tree that you do not want on `~amd64`.

---

## 8. Handling Custom and Non-Free Licenses

The oiledmachine-overlay contains many packages with custom, proprietary, or unusual licenses not present in the main Gentoo license database. Emerge will refuse to install these without explicit acceptance.

**Step 1: Find the license name.**

```sh
emerge -pv =category/package-version::oiledmachine-overlay 2>&1 | grep -i license
```

Or inspect the ebuild:

```sh
grep ^LICENSE /var/db/repos/oiledmachine-overlay/category/package/package-version.ebuild
```

**Step 2: Review the actual license text.**

For packages with custom licenses, the license file may be embedded in the source. The overlay README suggests this workflow for finding it before merging:

```sh
OILEDMACHINE_OVERLAY_ROOT="/var/db/repos/oiledmachine-overlay"
PN="some-package"
PV="1.2.3"
cd "${OILEDMACHINE_OVERLAY_ROOT}/${PN}"
ebuild ${PN}-${PV}.ebuild unpack
# Then search unpacked workdir for license text:
grep -r -l -i "LICENSE\|COPYING" "${WORKDIR}"
```

You can also search the overlay's GitHub repository directly for license files within the package directory.

**Step 3: Accept the license.**

```sh
mkdir -p /etc/portage/package.license
```

```sh
# FILE: /etc/portage/package.license/oiledmachine-overlay

# Accept a specific custom license for a package
=category/some-package-1.2.3 custom-license-name

# Accept all licenses for a specific package (use only when you have reviewed them)
category/some-package @FREE
```

To accept a broad set (e.g., all free licenses, plus a specific non-free one):

```sh
# In /etc/portage/make.conf, or per-package:
# ACCEPT_LICENSE="@FREE custom-nonfree-license-name"
```

> **Caution with non-free packages:** Several packages in this overlay, especially proprietary software or game binaries, require you to manually download an installer or tarball and place it in `/var/cache/distfiles/` before `emerge` will work. The required filename and URL are documented in the ebuild itself.

---

## 9. Configuring USE Flags for Overlay Packages

The overlay introduces several USE flag conventions not found in the main tree.

### 9.1 The `gcc_slot_*` USE Flag Prefix

This overlay-specific USE flag prefix resolves GLIBCXX version symbol conflicts when linking against GCC-compiled libraries. The overlay README advises using an LTS GCC slot.

```sh
mkdir -p /etc/portage/package.use
```

```sh
# FILE: /etc/portage/package.use/oiledmachine-overlay

# Example: force GCC 14 slot linkage for an AI/GPU package
dev-libs/some-rocm-package gcc_slot_14

# Or use the LTS recommendation (GCC 13 as of 2025):
dev-libs/some-rocm-package gcc_slot_13
```

To find which `gcc_slot_*` USE flags are available for a given package:

```sh
epkginfo -x =category/package-version::oiledmachine-overlay
# Read the metadata.xml output; gcc_slot_* flags are documented there.
```

### 9.2 Security Hardening USE Flags

The overlay offers opt-in security hardening flags. These are not enabled by default for most packages:

| USE Flag | Effect |
|---|---|
| `cet` | Enable Intel CET (Control-flow Enforcement Technology) |
| `llvm-cfi` | Enable LLVM Control Flow Integrity (amd64 without CET only) |
| `asan` | AddressSanitizer (not safe for production use) |
| `ubsan` | UndefinedBehaviorSanitizer (not safe for production use) |
| `lto` | Link-Time Optimisation |

```sh
# FILE: /etc/portage/package.use/oiledmachine-overlay

# Enable LTO and LLVM CFI for a security-critical package (if no CET support)
net-libs/some-network-lib lto llvm-cfi

# Enable LTO only for a performance-critical package
media-video/some-encoder lto
```

> **Warning:** Do **not** enable `asan` or `ubsan` on packages in `@system`. The overlay maintainer explicitly warns that ASan and UBSan are non-production mitigations and enabling them on system-critical packages (e.g., `curl`) can cause login failures and other severe breakage.

### 9.3 PGO and BOLT Optimisation Environment Variables

Some overlay ebuilds (particularly `ot-sources` and Firefox variants) support Profile-Guided Optimisation and BOLT. These are controlled via environment variables rather than USE flags:

```sh
mkdir -p /etc/portage/env
```

```sh
# FILE: /etc/portage/env/pgo-enabled.conf
UOPTS_GROUP="portage"
# BOLT hugify (minimises iTLB misses for large binaries) — disable on PREEMPT_RT kernels
UOPTS_BOLT_HUGIFY=1
```

```sh
# FILE: /etc/portage/package.env/oiledmachine-overlay
sys-kernel/ot-sources pgo-enabled.conf
```

---

## 10. Inspecting Package Metadata Before Installing

Before installing any package from the overlay, always inspect its metadata. The overlay's `metadata.xml` files are often richer than typical Gentoo ebuilds, containing USE flag documentation, developer API notes, and build environment variables.

```sh
# View full metadata for a package
epkginfo -x =games-engines/box2d-2.4.1-r2::oiledmachine-overlay

# Alternative using equery
equery meta category/package-name
```

**Check for hard masks from the overlay's own profiles:**

```sh
grep -r "category/package-name" \
    /var/db/repos/oiledmachine-overlay/profiles/package.mask
```

If a result is found, read the comment above the mask line — it explains why the package is masked (vulnerability, defunct upstream, etc.).

**Examine the ebuild itself for special requirements:**

```sh
# List available versions
ls /var/db/repos/oiledmachine-overlay/category/package-name/

# Read the ebuild
cat /var/db/repos/oiledmachine-overlay/category/package-name/package-version.ebuild
```

Pay attention to:
- `RESTRICT="fetch"` — means you must manually download sources.
- `LICENSE` — check for non-standard license identifiers.
- `PYTHON_COMPAT` — some packages hard-depend on older Python versions (e.g. 3.9/3.10) that may not be active on your system.
- Comments at the top of the ebuild (`OILEDMACHINE-OVERLAY-EBUILD-TESTED-VERSIONS`, `OILEDMACHINE-OVERLAY-TEST`) — these are test result annotations by the maintainer.

---

## 11. Installing a Package

With the overlay added, masked, and your chosen package unmasked with keywords and licenses accepted, installation follows standard Portage procedure. The workflow below summarises all steps for a complete, safe install.

### Full Workflow Example: Installing `sys-kernel/ot-sources`

**Step 1: Unmask the package.**

```sh
# /etc/portage/package.unmask/oiledmachine-overlay
sys-kernel/ot-sources::oiledmachine-overlay
```

**Step 2: Accept the keyword.**

```sh
# /etc/portage/package.accept_keywords/oiledmachine-overlay
sys-kernel/ot-sources ~amd64
```

**Step 3: Accept any required licenses.**

```sh
emerge -pv sys-kernel/ot-sources 2>&1 | grep -i "license\|mask"
# If a custom license is shown, add it to package.license
```

**Step 4: Configure USE flags.**

```sh
# /etc/portage/package.use/oiledmachine-overlay
sys-kernel/ot-sources lto -asan -ubsan
```

**Step 5: Dry-run to check the full dependency graph.**

```sh
emerge -avpDU sys-kernel/ot-sources
```

Review the output carefully. Ensure no unexpected packages from the overlay are being pulled in without your prior unmasking. If Portage proposes installing a dependency from the overlay that you have not explicitly unmasked, you have two options:
- Add that dependency to your `package.unmask` and `package.accept_keywords` files, or
- Find an alternative package version in the main tree that satisfies the dependency.

**Step 6: Check whether dependencies dragged in from the main tree need keyword acceptance.**

```sh
emerge -avpDU --autounmask sys-kernel/ot-sources
```

If `--autounmask` proposes changes, review them and apply selectively via `dispatch-conf`.

**Step 7: Emerge.**

```sh
emerge -av sys-kernel/ot-sources
```

---

## 12. Overlay-Specific Concepts and Pitfalls

### 12.1 The Legacy Overlay

The maintainer operates a separate `oiledmachine-overlay-legacy` repository for packages that have been removed from the main overlay due to:
- Bundled dependencies with unresolved critical CVEs.
- Defunct upstream projects.

If you were relying on a package that disappeared from the overlay, check whether it moved to legacy before filing a bug. Packages **do not** move to legacy if a replacement is available in the main Gentoo tree or the overlay itself.

### 12.2 Python Version Constraints

Several overlay packages hard-depend on Python 3.9 or 3.10, which are EOL or deprecated in the main Gentoo tree. If you encounter:

```
!!! No supported implementation in PYTHON_COMPAT
```

This is a known issue documented by the overlay maintainer. Your options:
1. Wait for the ebuild to be updated.
2. Check if a newer version of the ebuild has updated `PYTHON_COMPAT`.
3. Keep an older Python slot active: `emerge -a =dev-lang/python-3.10*` and configure `python-exec` to expose it.

Verify your active Python targets:

```sh
eselect python list
python-exec --version
```

### 12.3 Overlay Shadowing the Main Tree

Even with the global mask, if you unmask a package that exists in **both** the overlay and the main Gentoo tree, the overlay version (due to higher priority) will be preferred. To force use of the main-tree version despite having unmasked the overlay package, either:

- Remove the unmask entry, or
- Use a versioned atom that pinpoints the main-tree version: `=category/package-X.Y.Z::gentoo`

### 12.4 LLVM CFI and CET Interaction

The `llvm-cfi` USE flag in this overlay applies **only to `amd64` users without Intel CET support**. If your CPU supports CET (Intel Tiger Lake and later), the `cet` USE flag is preferred and `llvm-cfi` is redundant. You can check for CET support:

```sh
grep -m1 "flags" /proc/cpuinfo | grep -o "cetuser\|cet"
```

If `cetuser` appears, use `cet` instead of `llvm-cfi`.

### 12.5 Sanitizer Stability Warnings

The overlay README explicitly warns:
- Do **not** simultaneously enable ASan and UBSan on packages like `curl` — this can break PAM and prevent login.
- If you do enable sanitisers and see `ASan runtime does not come first in initial library list`, run `source /etc/profile` as a temporary fix, then either rebuild the package from this overlay with the sanitiser fix or switch back to the Gentoo main-tree version.

### 12.6 `OILEDMACHINE-OVERLAY-EBUILD-TESTED-VERSIONS` Annotations

Ebuilds in this overlay often have header comments like:

```sh
# OILEDMACHINE-OVERLAY-EBUILD-TESTED-VERSIONS: 1.2.1 1.2.1[python_targets_python3_10]
# OILEDMACHINE-OVERLAY-TEST: PASS (INTERACTIVE) 113.0.1 (May 15, 2023)
```

These tell you which versions and USE flag combinations the maintainer has actually tested. If you are installing a version not listed here, or with a different USE flag combination, treat it as untested.

---

## 13. Syncing and Staying Current

**Sync only the overlay** (fastest, avoids touching the main tree):

```sh
emaint sync -r oiledmachine-overlay
```

**Sync all repositories including the main tree:**

```sh
emerge --sync
```

Or with `emaint`:

```sh
emaint sync -a
```

> Prefer `emaint sync -r oiledmachine-overlay` when you only need to check for overlay updates, to minimise sync time and avoid inadvertently triggering main-tree updates.

After syncing, always check for updates to your installed overlay packages:

```sh
emerge -avpDU --with-bdeps=y @world
```

If you use `eix`, you can quickly identify packages installed from the overlay:

```sh
eix-update
eix --in-overlay oiledmachine-overlay --installed
```

---

## 14. Reading Overlay News Items

The oiledmachine-overlay uses Gentoo's `eselect news` mechanism to post critical bug notices and manual-intervention fixes. This is the overlay maintainer's primary channel for broadcasting breaking changes.

**Check for unread news:**

```sh
eselect news list
eselect news read
```

**Read news items specific to the overlay:**

News items for this overlay are also browsable directly at:

```
https://github.com/orsonteodoro/oiledmachine-overlay/tree/master/metadata/news
```

Notable historical news items include:

- **2023-11-05** — `ot-sources` PGO patch debug output breaks `emerge` because `linux-info.eclass` does not validate data (GCC_PGO_PHASE message spam fix).

Always check news after syncing, particularly if a world update is about to touch an overlay package.

---

## 15. Ongoing Package Management

### 15.1 Checking Which Installed Packages Come From the Overlay

```sh
# Using equery
equery list -F '$repo $cpv' '*' | grep oiledmachine-overlay

# Using eix (if installed)
eix --installed --in-overlay oiledmachine-overlay

# Using qlist (from portage-utils)
qlist -IRv | xargs -I{} sh -c 'equery which {} 2>/dev/null | grep oiledmachine-overlay && echo {}'
```

### 15.2 Verifying Package Integrity

The overlay uses standard Portage manifests. Verify installed files:

```sh
emerge -a --checksum =category/package-version::oiledmachine-overlay
# or
qcheck category/package-name
```

### 15.3 Keeping an Upgrade Hold on Overlay Packages

If you want an overlay package to stay at a specific version and not update automatically, pin it in `package.accept_keywords` with a versioned atom and set a package mask for newer versions:

```sh
# /etc/portage/package.mask/oiledmachine-overlay-pins
# Pin ot-sources to 6.9.x; block anything newer
>=sys-kernel/ot-sources-6.10::oiledmachine-overlay
```

```sh
# /etc/portage/package.unmask/oiledmachine-overlay
# Only unmask the pinned version
=sys-kernel/ot-sources-6.9.10::oiledmachine-overlay
```

### 15.4 Handling Packages That Move to Legacy

When a package disappears from the active overlay (moved to legacy or deleted), your next `emerge -uDN @world` will warn that the ebuild no longer exists. Options:

1. **Replace with a main-tree equivalent:** `emerge -a category/replacement-package`
2. **Keep the installed package without updates:** Add it to `/etc/portage/package.mask` to prevent accidental removal by depclean.
3. **Manually fetch the old ebuild:** The overlay history is on GitHub. You can retrieve an old ebuild, place it in a local overlay, and maintain it yourself.

### 15.5 Watching for Security Advisories

The overlay maintainer cross-references NVD and GLSA for package updates. However, the overlay is maintained by one person, and advisory response time is variable. For any security-critical package from this overlay:

```sh
# Check NVD directly for the package
glsa-check -l | grep package-name
```

Also periodically check whether the package has been moved to `oiledmachine-overlay-legacy` with a note about unresolved CVEs.

---

## 16. Removing Packages from the Overlay

To uninstall an overlay package and optionally switch to the main-tree version:

**Uninstall cleanly:**

```sh
emerge -a --deselect category/package-name
emerge -a --depclean
```

**Switch from the overlay version to the main-tree version:**

```sh
# Remove the overlay-specific unmask and keyword entries, then:
emerge -a --newrepo category/package-name
# --newrepo forces Portage to recalculate the best repo for the atom
```

**Clean up configuration files:**

After removing a package from the overlay, remove its entries from:
- `/etc/portage/package.unmask/oiledmachine-overlay`
- `/etc/portage/package.accept_keywords/oiledmachine-overlay`
- `/etc/portage/package.use/oiledmachine-overlay`
- `/etc/portage/package.license/oiledmachine-overlay`
- `/etc/portage/package.env/oiledmachine-overlay` (if applicable)

Leaving stale entries is harmless but adds clutter and can cause confusion during future troubleshooting.

---

## 17. Undoing Everything — Removing the Overlay

If you want to completely remove the overlay:

**Step 1: Uninstall all packages from the overlay.**

```sh
# Identify them first
equery list -F '$repo $cpv' '*' | grep oiledmachine-overlay

# Deselect each one
emerge --deselect category/package-name
emerge --depclean
```

**Step 2: Remove the overlay.**

```sh
eselect repository remove oiledmachine-overlay
# This removes the repos.conf entry but leaves /var/db/repos/oiledmachine-overlay on disk
```

To also remove the local repository clone:

```sh
rm -rf /var/db/repos/oiledmachine-overlay
```

**Step 3: Clean up `/etc/portage` files.**

Remove all files you created under:
- `/etc/portage/package.mask/`
- `/etc/portage/package.unmask/`
- `/etc/portage/package.accept_keywords/`
- `/etc/portage/package.use/`
- `/etc/portage/package.license/`
- `/etc/portage/package.env/`

That specifically reference `oiledmachine-overlay`.

**Step 4: Rebuild any packages that depended on overlay packages.**

```sh
emerge -avDU --with-bdeps=y @world
```

---

## 18. Reference: File Cheat Sheet

Below is a summary of every `/etc/portage` file touched by this guide, with a minimal but complete example of their content for a hypothetical package `dev-example/foo`.

### `/etc/portage/package.mask/oiledmachine-overlay`

```
# Block everything from oiledmachine-overlay by default
*/*::oiledmachine-overlay
```

### `/etc/portage/package.unmask/oiledmachine-overlay`

```
# Unmask specific packages
=dev-example/foo-1.2.3::oiledmachine-overlay
sys-kernel/ot-sources::oiledmachine-overlay
```

### `/etc/portage/package.accept_keywords/oiledmachine-overlay`

```
# Accept testing keyword per-package (never set globally)
=dev-example/foo-1.2.3 ~amd64
sys-kernel/ot-sources ~amd64

# For packages with no keyword at all:
# dev-example/bar **
```

### `/etc/portage/package.license/oiledmachine-overlay`

```
# Accept a specific custom license
=dev-example/foo-1.2.3 custom-foo-license

# Accept all free licenses plus a named non-free license
# =dev-example/baz-2.0 @FREE proprietary-baz-license
```

### `/etc/portage/package.use/oiledmachine-overlay`

```
# Overlay-specific USE flags
=dev-example/foo-1.2.3 gcc_slot_13 lto -asan -ubsan
sys-kernel/ot-sources lto -asan
```

### `/etc/portage/package.env/oiledmachine-overlay`

```
# Assign custom environment files to overlay packages
sys-kernel/ot-sources pgo-enabled.conf
```

### `/etc/portage/env/pgo-enabled.conf`

```sh
UOPTS_GROUP="portage"
UOPTS_BOLT_HUGIFY=1
```

### `/etc/portage/repos.conf/eselect-repo.conf` (relevant stanza)

```ini
[oiledmachine-overlay]
location = /var/db/repos/oiledmachine-overlay
sync-type = git
sync-uri = https://github.com/orsonteodoro/oiledmachine-overlay.git
auto-sync = yes
priority = 50
```

---

## Quick Reference: Command Summary

| Task | Command |
|---|---|
| Add the overlay | `eselect repository add oiledmachine-overlay git https://github.com/orsonteodoro/oiledmachine-overlay.git` |
| Initial sync | `emaint sync -r oiledmachine-overlay` |
| Sync overlay only | `emaint sync -r oiledmachine-overlay` |
| Check overlay repo name | `cat /var/db/repos/oiledmachine-overlay/profiles/repo_name` |
| List installed overlay packages | `equery list -F '$repo $cpv' '*' \| grep oiledmachine-overlay` |
| Inspect package metadata | `epkginfo -x =category/pkg-ver::oiledmachine-overlay` |
| Check package keywords | `grep KEYWORDS /var/db/repos/oiledmachine-overlay/cat/pkg/pkg-ver.ebuild` |
| Check overlay internal masks | `grep -r "cat/pkg" /var/db/repos/oiledmachine-overlay/profiles/package.mask` |
| Dry-run install | `emerge -avpDU =category/pkg-ver::oiledmachine-overlay` |
| Read news items | `eselect news read` |
| Remove the overlay | `eselect repository remove oiledmachine-overlay` |

---

*Guide last verified against the oiledmachine-overlay state as of May 2026. The overlay is maintained by a single developer and undergoes frequent structural changes; always consult the upstream README and `metadata/news` directory for the latest advisories.*
