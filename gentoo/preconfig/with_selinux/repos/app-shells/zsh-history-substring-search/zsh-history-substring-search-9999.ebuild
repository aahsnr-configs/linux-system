# Copyright 2022,2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit readme.gentoo-r1 git-r3

DESCRIPTION="ZSH port of Fish history search (up arrow)"
HOMEPAGE="https://github.com/zsh-users/zsh-history-substring-search"
EGIT_REPO_URI="https://github.com/zsh-users/zsh-history-substring-search.git"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="app-shells/zsh"

DISABLE_AUTOFORMATTING="true"
DOC_CONTENTS="In order to use ${CATEGORY}/${PN} add
. /usr/share/zsh/site-functions/zsh-history-substring-search.zsh
at the end of your ~/.zshrc"

src_install() {
	insinto /usr/share/zsh/site-functions
	doins ${PN}.zsh

	readme.gentoo_create_doc
	einstalldocs
}

pkg_postinst() {
	readme.gentoo_print_elog
}
