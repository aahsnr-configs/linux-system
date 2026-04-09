# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
EAPI=8

inherit cmake git-r3

DESCRIPTION="An application to enable a blue-light filter on Hyprland"
HOMEPAGE="https://github.com/hyprwm/hyprsunset"
EGIT_REPO_URI="https://github.com/hyprwm/${PN^}.git"

LICENSE="BSD"
SLOT="0"

RDEPEND="
	gui-wm/hyprland
	dev-libs/wayland
	gui-libs/hyprutils
"

DEPEND="
	${RDEPEND}
	dev-libs/wayland-protocols
	dev-libs/hyprland-protocols
	dev-util/hyprwayland-scanner
	dev-util/wayland-scanner
"

BDEPEND="
	virtual/pkgconfig
"

