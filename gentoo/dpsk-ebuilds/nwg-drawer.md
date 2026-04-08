# nwg-drawer ebuild

Here's a Gentoo ebuild for the `nwg-drawer` Git repository:

```bash
# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 meson

DESCRIPTION="Application drawer (launcher) for wlroots-based Wayland compositors"
HOMEPAGE="https://github.com/nwg-piotr/nwg-drawer"
EGIT_REPO_URI="https://github.com/nwg-piotr/nwg-drawer.git"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

DEPEND="
	dev-cpp/gtkmm:3.0
	dev-libs/glib:2
	dev-libs/jsoncpp
	gui-libs/gtk-layer-shell
	x11-libs/gtk+:3
"
RDEPEND="${DEPEND}"
BDEPEND="
	virtual/pkgconfig
"

src_configure() {
	local emesonargs=(
		--buildtype release
	)
	meson_src_configure
}
```

## Installation Instructions

1. Save this file as `nwg-drawer-9999.ebuild` in your local overlay under `app-misc/nwg-drawer/`
2. Create the necessary metadata files:
   ```bash
   mkdir -p /path/to/your/overlay/app-misc/nwg-drawer/
   cd /path/to/your/overlay/app-misc/nwg-drawer/
   echo "9999" > metadata/layout.conf
   ```
3. Generate the manifest:
   ```bash
   ebuild nwg-drawer-9999.ebuild manifest
   ```
4. Install the package:
   ```bash
   emerge -av app-misc/nwg-drawer
   ```

## Notes

- This is a live ebuild (version 9999) that will always fetch the latest commit from Git
- The ebuild inherits `git-r3` for Git repository support and `meson` for the build system
- Dependencies include GTK and related libraries needed for Wayland applications
- If you want a specific release version, you would need to adjust the ebuild to use a release tarball instead of Git

You may need to adjust dependencies based on your specific system configuration or if the project's requirements change.
