# Copyright 2023-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="Aquamarine is a very light linux rendering backend library"
HOMEPAGE="https://github.com/hyprwm/aquamarine"
EGIT_REPO_URI="https://github.com/hyprwm/${PN^}.git"
KEYWORDS="~amd64"

LICENSE="BSD"
SLOT="0"

# Upstream states that the simpleWindow test is broken, see bug 936653
RESTRICT="test"
RDEPEND="
	dev-libs/wayland
	media-libs/mesa[opengl]
	media-libs/libdisplay-info
	dev-libs/libinput
	dev-util/hyprwayland-scanner
	gui-libs/hyprutils
	x11-libs/cairo
	x11-libs/libxkbcommon
	x11-libs/libdrm
	x11-libs/pango
	x11-libs/pixman
	virtual/libudev
	sys-apps/hwdata
	sys-auth/seatd
"
DEPEND="
	${RDEPEND}
	dev-libs/wayland-protocols
"

BDEPEND="
	dev-util/wayland-scanner
	virtual/pkgconfig
"

src_prepare() {
	sed -i "/add_compile_options(-O3)/d" "${S}/CMakeLists.txt" || die
	cmake_src_prepare
}
