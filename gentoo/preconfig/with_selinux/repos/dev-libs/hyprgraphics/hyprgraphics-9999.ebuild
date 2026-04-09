# Copyright 2023-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="Hyprland graphics / resource utilities"
HOMEPAGE="https://github.com/hyprwm/hyprgraphics"
EGIT_REPO_URI="https://github.com/hyprwm/${PN^}.git"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	gui-libs/hyprutils
	media-libs/libjpeg-turbo:=
	media-libs/libjxl
	media-libs/libwebp
	sys-apps/file
	x11-libs/cairo
"
DEPEND="${RDEPEND}"
