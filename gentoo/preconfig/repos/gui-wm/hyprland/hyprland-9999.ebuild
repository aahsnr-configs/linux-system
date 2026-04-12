# Copyright 2023-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit meson toolchain-funcs git-r3

DESCRIPTION="A dynamic tiling Wayland compositor that doesn't sacrifice on its looks"
HOMEPAGE="https://github.com/hyprwm/Hyprland"
EGIT_REPO_URI="https://github.com/hyprwm/${PN^}.git"
KEYWORDS="~amd64"

LICENSE="BSD"
SLOT="0"
IUSE="X legacy-renderer qtutils systemd"

# hyprpm (hyprland plugin manager) requires the dependencies at runtime
# so that it can clone, compile and install plugins.
HYPRPM_RDEPEND="
	app-alternatives/ninja
	dev-build/cmake
	dev-build/meson
	dev-vcs/git
	virtual/pkgconfig
"
RDEPEND="
	${HYPRPM_RDEPEND}
	dev-cpp/tomlplusplus
	dev-libs/glib:2
	dev-libs/hyprlang
	dev-libs/libinput
	dev-libs/hyprgraphics
	dev-libs/re2
	dev-libs/udis86
	dev-libs/wayland
	gui-libs/aquamarine
	gui-libs/hyprcursor
	gui-libs/hyprutils
	media-libs/libglvnd
	media-libs/mesa
	sys-apps/util-linux
	x11-libs/cairo
	x11-libs/libdrm
	x11-libs/libxkbcommon
	x11-libs/pango
	x11-libs/pixman
	x11-libs/libXcursor
	qtutils? ( gui-libs/hyprland-qtutils )
	X? (
		x11-libs/libxcb
		x11-base/xwayland
    x11-libs/xcb-util
		x11-libs/xcb-util-errors
    x11-libs/xcb-util-renderutil
		x11-libs/xcb-util-wm
	)
"
DEPEND="
	${RDEPEND}
	dev-libs/hyprland-protocols
	dev-libs/wayland-protocols
"
BDEPEND="
	|| ( >=sys-devel/gcc-14:* >=llvm-core/clang-18:* )
	app-misc/jq
	dev-build/cmake
	dev-util/hyprwayland-scanner
	virtual/pkgconfig
"

pkg_setup() {
	[[ ${MERGE_TYPE} == binary ]] && return

	if tc-is-gcc && ver_test $(gcc-version) -lt 14 ; then
		eerror "Hyprland requires >=sys-devel/gcc-14 to build"
		eerror "Please upgrade GCC: emerge -v1 sys-devel/gcc"
		die "GCC version is too old to compile Hyprland!"
	elif tc-is-clang && ver_test $(clang-version) -lt 18 ; then
		eerror "Hyprland requires >=llvm-core/clang-18 to build"
		eerror "Please upgrade Clang: emerge -v1 llvm-core/clang"
		die "Clang version is too old to compile Hyprland!"
	fi
}

src_configure() {
	local emesonargs=(
		$(meson_feature legacy-renderer legacy_renderer)
		$(meson_feature systemd)
		$(meson_feature X xwayland)
	)

	meson_src_configure
}
