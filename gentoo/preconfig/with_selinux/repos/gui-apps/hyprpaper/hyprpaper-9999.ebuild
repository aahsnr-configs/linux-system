# Copyright 2023-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="A blazing fast wayland wallpaper utility"
HOMEPAGE="https://github.com/hyprwm/hyprpaper"
EGIT_REPO_URI="https://github.com/hyprwm/${PN^}.git"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	dev-libs/hyprgraphics
	dev-libs/hyprlang
	dev-libs/wayland
	gui-libs/hyprutils
	media-libs/libglvnd
	media-libs/libjpeg-turbo
	media-libs/libwebp
	x11-libs/cairo
	x11-libs/pango
"
DEPEND="
	${RDEPEND}
	dev-libs/wayland-protocols
"
BDEPEND="
	dev-util/hyprwayland-scanner
	dev-util/wayland-scanner
	dev-vcs/git
	virtual/pkgconfig
"

DOCS=( README.md )

src_compile() {
	emake protocols
	cmake_src_compile
}
