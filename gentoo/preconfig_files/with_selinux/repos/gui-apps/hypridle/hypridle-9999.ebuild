# Copyright 2023-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="Hyprland's idle daemon"
HOMEPAGE="https://github.com/hyprwm/hypridle"
EGIT_REPO_URI="https://github.com/hyprwm/${PN^}.git"
KEYWORDS="~amd64"

LICENSE="BSD"
SLOT="0"

RDEPEND="
	dev-cpp/sdbus-c++
	dev-libs/hyprlang
	gui-libs/hyprutils
	dev-libs/wayland
"
DEPEND="
	${RDEPEND}
	dev-libs/wayland-protocols
"

BDEPEND="
	dev-util/wayland-scanner
	virtual/pkgconfig
"

PATCHES=(
	"${FILESDIR}/hypridle-9999-fix-CFLAGS-CXXFLAGS.patch"
)
