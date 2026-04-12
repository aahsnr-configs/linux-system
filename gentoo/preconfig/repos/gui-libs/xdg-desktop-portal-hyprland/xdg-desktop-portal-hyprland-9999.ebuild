# Copyright 2022-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake toolchain-funcs git-r3

DESCRIPTION="xdg-desktop-portal backend for hyprland"
HOMEPAGE="https://github.com/hyprwm/xdg-desktop-portal-hyprland"
EGIT_REPO_URI="https://github.com/hyprwm/${PN}.git"
KEYWORDS="~amd64"

LICENSE="MIT"
SLOT="0"
IUSE="elogind systemd"
REQUIRED_USE="?? ( elogind systemd )"

DEPEND="
	dev-cpp/sdbus-c++
	dev-libs/hyprlang
	dev-libs/inih
	dev-libs/wayland
	dev-qt/qtbase:6[gui,widgets]
	dev-qt/qtwayland:6
	media-libs/mesa
	media-video/pipewire
	sys-apps/util-linux
	x11-libs/libdrm
	|| (
		sys-libs/basu
		elogind? ( >=sys-auth/elogind-237 )
		systemd? ( >=sys-apps/systemd-237 )
	)
"

RDEPEND="
	${DEPEND}
	sys-apps/xdg-desktop-portal
"

BDEPEND="
	dev-libs/hyprland-protocols
	dev-libs/wayland-protocols
	dev-util/hyprwayland-scanner
	virtual/pkgconfig
	|| ( >=sys-devel/gcc-14:* >=llvm-core/clang-17:* )
"

pkg_setup() {
	[[ ${MERGE_TYPE} == binary ]] && return

	if tc-is-gcc && ver_test $(gcc-version) -lt 14 ; then
		eerror "XDPH needs >=gcc-14 or >=clang-18 to compile."
		eerror "Please upgrade GCC: emerge -v1 sys-devel/gcc"
		die "GCC version is too old to compile XDPH!"
	elif tc-is-clang && ver_test $(clang-version) -lt 18 ; then
		eerror "XDPH needs >=gcc-14 or >=clang-18 to compile."
		eerror "Please upgrade Clang: emerge -v1 llvm-core/clang"
		die "Clang version is too old to compile XDPH!"
	fi
}

src_prepare() {
	sed -i "/add_compile_options(-O3)/d" "${S}/CMakeLists.txt" || die
	cmake_src_prepare
}

