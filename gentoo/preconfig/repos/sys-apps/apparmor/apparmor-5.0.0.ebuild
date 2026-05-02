# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic systemd toolchain-funcs linux-info

MY_PV="$(ver_cut 1-2)"

DESCRIPTION="Userspace utils and init scripts for the AppArmor application security system"
HOMEPAGE="https://gitlab.com/apparmor/apparmor/wikis/home"
# 5.0.0 tarballs are only published on GitLab
SRC_URI="https://gitlab.com/apparmor/apparmor/-/archive/v${PV}/apparmor-v${PV}.tar.gz"
# GitLab archive extracts to apparmor-v${PV}, not apparmor-${PV}
S=${WORKDIR}/apparmor-v${PV}/parser

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~ppc64 ~riscv"
IUSE="doc"

# 5.0.0 must be paired with matching libapparmor; keep ~ for strict coupling
RDEPEND="~sys-libs/libapparmor-${PV}"
DEPEND="${RDEPEND}"
BDEPEND="
	dev-lang/perl
	sys-apps/which
	app-alternatives/yacc
	sys-devel/gettext
	app-alternatives/lex
	doc? ( dev-tex/latex2html )
"
CONFIG_CHECK="SECURITY_APPARMOR"

# The single patch from 4.0.3 is now upstream, so the array is empty
PATCHES=()

src_prepare() {
	default

	# AppArmor 5.0 no longer forces static linking; this sed is obsolete
	# sed -e '/^AALIB =/ s/-Bstatic/-Bdynamic/' -i Makefile || die

	# Keep Gentoo‑specific path adjustments for rc.apparmor.functions
	sed -e '/install-indep: indep/a\\tinstall -m 755 -d ${DESTDIR}/usr/libexec' -i Makefile || die
	sed -e 's:rc.apparmor.functions $(APPARMOR_BIN_PREFIX):rc.apparmor.functions ${DESTDIR}/usr/libexec:' \
		-i Makefile || die
	sed -e ':^APPARMOR_FUNCTIONS=: s:/lib/apparmor/:/usr/libexec/:' -i apparmor.systemd || die
	sed -e 's:\. /lib/apparmor/rc.apparmor.functions:\. /usr/libexec/rc.apparmor.functions:' -i profile-load || die

	# Suppress warning about missing features file (not yet supported on Gentoo)
	sed -e "/installation problem/ctrue" -i rc.apparmor.functions || die

	# Ensure the correct preprocessor is used (bug 634782)
	sed -e "s/cpp/$(tc-getCPP) -/" \
		-i ../common/list_capabilities.sh \
		-i ../common/list_af_names.sh || die
}

src_configure() {
	# ODR violations (bug #863524)
	filter-lto

	default
}

src_compile() {
	emake \
		AR="$(tc-getAR)" \
		CC="$(tc-getCC)" \
		CPP="$(tc-getCPP) -" \
		CXX="$(tc-getCXX)" \
		USE_SYSTEM=1 \
		arch manpages
	use doc && emake pdf
}

src_test() {
	emake CXX="$(tc-getCXX)" USE_SYSTEM=1 check -Onone
}

src_install() {
	# DISTRO variable was removed upstream; do not pass it
	emake \
		CPP="$(tc-getCPP) -" \
		DESTDIR="${D}" \
		USE_SYSTEM=1 \
		install

	dodir /etc/apparmor.d/disable

	newinitd "${FILESDIR}/${PN}-init-1" ${PN}
	systemd_newunit "${FILESDIR}/apparmor.service" apparmor.service

	use doc && dodoc techdoc.pdf

	exeinto /usr/share/apparmor
	doexe "${FILESDIR}/apparmor_load.sh"
	doexe "${FILESDIR}/apparmor_unload.sh"
}
