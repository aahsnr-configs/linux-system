# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3
DESCRIPTION="Additional completion definitions for Zsh"
HOMEPAGE="https://github.com/zsh-users/zsh-completions"
EGIT_REPO_URI="https://github.com/zsh-users/zsh-completions.git"
KEYWORDS="~amd64"
LICENSE="Apache-2.0 BSD MIT ZSH"
SLOT="0"

RDEPEND="app-shells/zsh"

src_install() {
	insinto /usr/share/zsh/site-functions
	doins src/_*
}

pkg_postinst() {
	elog "If you happen to compile your functions, you may need to delete"
	elog "~/.zcompdump{,.zwc} and recompile to make the new completions available"
	elog "to your shell."
}
