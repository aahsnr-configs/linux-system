# Copyright 2023-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3

DESCRIPTION="The hyprland cursor format, library and utilities"
HOMEPAGE="https://github.com/hyprwm/hyprcursor"
EGIT_REPO_URI="https://github.com/hyprwm/${PN^}.git"
KEYWORDS="~amd64"

LICENSE="BSD"
SLOT="0"

# Disable tests since as per upstream, tests require a theme to be installed
# See also https://github.com/hyprwm/hyprcursor/commit/94361fd8a75178b92c4bb24dcd8c7fac8423acf3
RESTRICT="test"

RDEPEND="
	dev-cpp/tomlplusplus
	dev-libs/hyprlang
	dev-libs/libzip
	gnome-base/librsvg:2
	x11-libs/cairo
"
