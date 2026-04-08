# Copyright 2023-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="Hyprland utilities library used across the ecosystem"
HOMEPAGE="https://github.com/hyprwm/hyprutils"
EGIT_REPO_URI="https://github.com/hyprwm/${PN^}.git"
KEYWORDS="~amd64"

LICENSE="BSD"
SLOT="0"

DEPEND="
	x11-libs/pixman
"
RDEPEND="${DEPEND}"
