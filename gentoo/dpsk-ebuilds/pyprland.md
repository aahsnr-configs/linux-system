# pyprland Ebuild for Gentoo

Here's a basic ebuild for pyprland, a Python plugin manager for Hyprland:

```bash
# pyprland-9999.ebuild (for live/git version)
# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3

DESCRIPTION="A plugin manager for Hyprland written in Python"
HOMEPAGE="https://github.com/hyprland-community/pyprland"
EGIT_REPO_URI="https://github.com/hyprland-community/pyprland.git"

LICENSE="MIT"
SLOT="0"
KEYWORDS=""
IUSE=""

DEPEND="
	>=gui-wm/hyprland-0.30.0
	dev-lang/python
"
RDEPEND="${DEPEND}"
BDEPEND=""

src_install() {
	dobin pypr
	insinto /usr/share/pyprland
	doins -r plugins pyprland
	dodoc README.md
}
```

## Installation Instructions

1. Create a directory for the ebuild:
   ```bash
   mkdir -p /var/db/repos/local/gui-apps/pyprland
   ```

2. Save the ebuild as `/var/db/repos/local/gui-apps/pyprland/pyprland-9999.ebuild`

3. Generate the manifest:
   ```bash
   ebuild /var/db/repos/local/gui-apps/pyprland/pyprland-9999.ebuild manifest
   ```

4. Add the local repository to `/etc/portage/repos.conf/local.conf` if you haven't already:
   ```ini
   [local]
   location = /var/db/repos/local
   priority = 10
   auto-sync = no
   ```

5. Install:
   ```bash
   emerge -av gui-apps/pyprland
   ```

## Notes

1. This is a live ebuild (version 9999) that will always fetch the latest git version. For a stable release, you'd need to adjust the version number and possibly the SRC_URI.

2. You may want to add additional dependencies based on the plugins you plan to use with pyprland.

3. The ebuild assumes pyprland is installed system-wide. Adjust paths if you prefer a user-local installation.

4. Consider adding a `postinst` phase to remind users about configuration if needed.
