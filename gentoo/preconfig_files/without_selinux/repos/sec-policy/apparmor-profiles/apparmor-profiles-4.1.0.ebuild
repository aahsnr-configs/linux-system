# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

MY_PV="$(ver_cut 1-2)"

DESCRIPTION="A collection of profiles for the AppArmor application security system"
HOMEPAGE="https://gitlab.com/apparmor/apparmor/wikis/home"
SRC_URI="https://gitlab.com/apparmor/apparmor/-/archive/v4.1.0-beta5/apparmor-v4.1.0-beta5.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"
IUSE="minimal"

RESTRICT="test"

S=${WORKDIR}/apparmor-v4.1.0-beta5/profiles

src_install() {
	if use minimal ; then
		insinto /etc/apparmor.d
		doins -r apparmor.d/{abi,abstractions,tunables}
	else
		default
	fi
}
