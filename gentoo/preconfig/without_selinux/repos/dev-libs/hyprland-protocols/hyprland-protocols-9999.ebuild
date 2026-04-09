# Copyright 2023-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit meson git-r3

DESCRIPTION="Wayland protocol extensions for Hyprland"
HOMEPAGE="https://github.com/hyprwm/hyprland-protocols"
EGIT_REPO_URI="https://github.com/hyprwm/${PN}.git"

LICENSE="BSD"
SLOT="0"

BDEPEND="
	dev-util/wayland-scanner
	virtual/pkgconfig
"
