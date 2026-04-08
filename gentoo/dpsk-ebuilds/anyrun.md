# Anyrun Ebuild for Gentoo

Here's a Gentoo ebuild for the Anyrun git repository. This ebuild will fetch the latest version directly from GitHub.

Create a file named `anyrun-9999.ebuild` in an appropriate overlay (for example, `/var/db/repos/local/app-misc/anyrun/`):

```bash
# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cargo git-r3

DESCRIPTION="A stylish way to run programs in Linux"
HOMEPAGE="https://github.com/anyrun-org/anyrun"
EGIT_REPO_URI="https://github.com/anyrun-org/anyrun.git"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+plugins"

DEPEND="
	>=gui-libs/gtk-4.10.0
	gui-libs/libadwaita
	dev-libs/glib
	dev-libs/openssl
"
RDEPEND="${DEPEND}"
BDEPEND="
	>=virtual/rust-1.70.0
	dev-util/meson
	dev-util/ninja
"

src_unpack() {
	git-r3_src_unpack
	cargo_live_src_unpack
}

src_compile() {
	emake build
}

src_install() {
	emake install DESTDIR="${D}" PREFIX="/usr"
  mkdir -p ~/.config/anyrun/plugins
  cp target/release/*.so ~/.config/anyrun/plugins
}
```

## Important Notes:

1. This is a live ebuild (version 9999) that will always fetch the latest git commit.

2. You'll need to create the necessary directory structure in your overlay:
   ```
   mkdir -p /var/db/repos/local/app-misc/anyrun
   ```

3. You'll also need a `metadata.xml` file in the same directory with content like:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE pkgmetadata SYSTEM "http://www.gentoo.org/dtd/metadata.dtd">
   <pkgmetadata>
       <maintainer type="person">
           <email>your@email.com</email>
           <name>Your Name</name>
       </maintainer>
       <longdescription>
           Anyrun is a stylish way to run programs in Linux, written in Rust.
       </longdescription>
   </pkgmetadata>
   ```

4. After creating the ebuild, you'll need to generate the manifest:
   ```
   ebuild anyrun-9999.ebuild manifest
   ```

5. The ebuild assumes you have Rust and Cargo installed. If not, you'll need to:
   ```
   emerge dev-lang/rust
   ```

6. The build dependencies (especially Rust crates) will be automatically handled by Portage through the cargo.eclass.

7. You may need to adjust the dependencies based on your specific system configuration.
