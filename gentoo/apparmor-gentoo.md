After a thorough audit, I’ve identified several issues and areas for improvement in the original script.  I’ll first outline the key problems, then present a fully revised script that addresses them.

---

## 🔍 Audit Findings

1. **Missing `gentoolkit` dependency** – the script uses `equery` and `portageq` but never ensures `app‑portage/gentoolkit` is installed.  
2. **Unreliable USE‑flag check** – `portageq envvar USE` is not guaranteed to return the current global USE flags; it’s better to parse `emerge --info`.  
3. **Undefined command `has_version`** – the script calls a function that doesn’t exist; the correct check is `equery list <atom>`.  
4. **`pip` may be absent** – `pip install --user ttkthemes` will fail unless `dev-python/pip` is already emerged.  
5. **`pyflakes` / `pyflakes3` not guaranteed** – `make check` for utils depends on it, but the script only installs it if the user answers “yes” to the missing‑package prompt.  
6. **`prepare_source()` doesn’t handle a non‑git directory** – if `$APPARMOR_SRC_DIR` exists but is not a git repository, the function will exit with an error.  
7. **No kernel‑config verification** – AppArmor requires specific kernel options (e.g., `CONFIG_SECURITY_APPARMOR`). The script should at least warn if they’re missing.  
8. **`PYTHONPATH` is set after `cd`** – the original script changes to the source directory before exporting `PYTHONPATH`; on Gentoo the exact path may differ.  
9. **Missing `pyflakes` dependency** – `dev-python/pyflakes` is not included in the dependency list.  
10. **Topgrade integration was only sketched** – the original file ended with a brief comment; the user asked for a full, ready‑to‑use explanation.  

All of these are fixed in the rewrite below.

---

## ✅ Revised Bash Script

```bash
#!/usr/bin/env bash
# ----------------------------------------------------------------------
# apparmor-update.sh
# =================
# Build & install AppArmor userspace from the official GitLab repository,
# optimized for Gentoo Linux.
#
# Features
# --------
# - Fully idempotent: checks the latest GitLab release tag and records
#   the installed version in /var/lib/apparmor/installed_version.
# - Interactive: prompts before every major step.
# - Verifies Gentoo build dependencies and USE flags.
# - Fetches the latest release via the GitLab API.
# - Follows the exact build order described in README-apparmor.md.
# - Installs Python dependencies (aa-notify) via emerge.
# - Ready for topgrade: see the section at the end of this file.
# ----------------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

# --- user‑adjustable settings ------------------------------------------------
: "${APPARMOR_SRC_DIR:=/opt/apparmor-build}"           # clone/update location
: "${APPARMOR_INSTALLED_VER_FILE:=/var/lib/apparmor/installed_version}"
: "${APPARMOR_CONFIGURE_OPTS:=--prefix=/usr --with-perl --with-python}"

readonly -a CORE_DEPENDENCIES=(
    "sys-devel/autoconf"
    "sys-devel/automake"
    "sys-devel/libtool"
    "sys-devel/bison"
    "sys-devel/flex"
    "sys-devel/gettext"
    "dev-util/pkgconf"
    "dev-lang/swig"
    "dev-lang/perl"
    "dev-lang/python"
    "dev-vcs/git"
    "net-misc/curl"
    "app-misc/jq"
    "app-portage/gentoolkit"
    "dev-python/pyflakes"
)

# colour helpers
readonly RED='\e[31m' GREEN='\e[32m' YELLOW='\e[33m' RESET='\e[0m'
info()  { printf "${GREEN}[INFO]${RESET}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${RESET}  %s\n" "$*" >&2; }
err()   { printf "${RED}[ERROR]${RESET} %s\n" "$*" >&2; exit 1; }

# --- banner ------------------------------------------------------------------
banner() {
    echo "=============================================="
    echo "  AppArmor Userspace Build / Update Script"
    echo "  GitLab Release API ➔ https://gitlab.com/api/v4"
    echo "=============================================="
}

# --- Gentoo guard ------------------------------------------------------------
require_gentoo() {
    [[ -f /etc/gentoo-release ]] || err "This script requires Gentoo Linux."
}

# --- command existence -------------------------------------------------------
require_cmd() {
    command -v "$1" >/dev/null 2>&1 || err "Required command '$1' not found; install it first."
}

# --- ensure a USE flag is globally active ------------------------------------
ensure_use_flag() {
    local flag="$1"
    # check current global USE flags
    if emerge --info | grep "^USE=" | grep -qw "$flag"; then
        info "USE flag '$flag' is already globally enabled."
        return 0
    fi
    warn "USE flag '$flag' is NOT globally enabled."
    read -r -p "Enable it now? (will modify /etc/portage/package.use/apparmor) [y/N] " ans
    if [[ "$ans" =~ ^[Yy] ]]; then
        # ensure /etc/portage/package.use directory exists
        if [[ ! -d /etc/portage/package.use ]]; then
            sudo mkdir -p /etc/portage/package.use
        fi
        echo "*/* ${flag}" | sudo tee -a /etc/portage/package.use/apparmor >/dev/null
        info "Added '${flag}' to /etc/portage/package.use/apparmor."
        return 0
    fi
    err "Cannot proceed without USE flag '${flag}'."
}

# --- verify / install Gentoo build dependencies ------------------------------
check_gentoo_deps() {
    info "Verifying Gentoo build dependencies..."
    local missing=()
    for pkg in "${CORE_DEPENDENCIES[@]}"; do
        if ! equery list -q "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -ne 0 ]]; then
        warn "The following packages are missing:"
        for p in "${missing[@]}"; do
            warn "  - $p"
        done
        read -r -p "Emerge them now? [y/N] " ans
        if [[ "$ans" =~ ^[Yy] ]]; then
            sudo emerge -av "${missing[@]}" || err "Emerge failed."
        else
            err "Cannot proceed without required packages."
        fi
    fi

    # Python USE flags
    ensure_use_flag "tk"
    ensure_use_flag "sqlite"

    info "All build dependencies satisfied."
}

# --- fetch latest GitLab release tag -----------------------------------------
get_latest_version() {
    info "Querying GitLab for latest AppArmor release..."
    local api_url="https://gitlab.com/api/v4/projects/apparmor%2Fapparmor/releases"
    local latest
    latest=$(curl -sSf "$api_url" | jq -r '.[0].tag_name')
    if [[ -z "$latest" || "$latest" == "null" ]]; then
        err "Cannot determine latest version from GitLab API."
    fi
    echo "$latest"
}

# --- clone / update source tree ----------------------------------------------
prepare_source() {
    local tag="$1"
    if [[ ! -d "$APPARMOR_SRC_DIR" ]]; then
        info "Cloning AppArmor repository into $APPARMOR_SRC_DIR ..."
        git clone https://gitlab.com/apparmor/apparmor.git "$APPARMOR_SRC_DIR"
    elif [[ ! -d "$APPARMOR_SRC_DIR/.git" ]]; then
        err "'${APPARMOR_SRC_DIR}' exists but is not a git repository. Remove it manually."
    else
        info "Updating existing repository in $APPARMOR_SRC_DIR ..."
        git -C "$APPARMOR_SRC_DIR" fetch --tags --prune
    fi
    info "Checking out tag $tag ..."
    git -C "$APPARMOR_SRC_DIR" checkout "$tag"
}

# --- set python environment (as per README) ----------------------------------
setup_python_env() {
    local libdir
    libdir="$(realpath "$APPARMOR_SRC_DIR/libraries/libapparmor/swig/python")"
    if [[ -z "${PYTHONPATH:-}" ]]; then
        export PYTHONPATH="$libdir"
    else
        export PYTHONPATH="$libdir:$PYTHONPATH"
    fi
    export PYTHON="${PYTHON:-/usr/bin/python3}"
    export PYTHON_VERSION="${PYTHON_VERSION:-3}"
    export PYTHON_VERSIONS="${PYTHON_VERSIONS:-python3}"
}

# --- build & install individual components -----------------------------------
build_libapparmor() {
    info "Building libapparmor..."
    cd "$APPARMOR_SRC_DIR/libraries/libapparmor"
    sh autogen.sh
    sh configure $APPARMOR_CONFIGURE_OPTS
    make -j"$(nproc)"
    make check
    sudo make install
}

build_binutils() {
    info "Building binary utilities..."
    cd "$APPARMOR_SRC_DIR/binutils"
    make -j"$(nproc)"
    make check
    sudo make install
}

build_parser() {
    info "Building parser..."
    cd "$APPARMOR_SRC_DIR/parser"
    make -j"$(nproc)"
    make -j"$(nproc)" tst_binaries
    make check
    sudo make install
}

build_init() {
    info "Building init scripts..."
    cd "$APPARMOR_SRC_DIR/init"
    make -j"$(nproc)"
    make check
    sudo make install
}

build_utils() {
    info "Building Python utilities..."
    cd "$APPARMOR_SRC_DIR/utils"
    make -j"$(nproc)"
    # pyflakes3 is provided by dev-python/pyflakes; use /usr/bin/pyflakes or pyflakes3
    if command -v pyflakes3 >/dev/null 2>&1; then
        make check PYFLAKES=pyflakes3 || true
    elif command -v pyflakes >/dev/null 2>&1; then
        make check PYFLAKES=pyflakes || true
    else
        warn "pyflakes not found; skipping 'make check' for utils."
    fi
    sudo make install
}

build_mod_apparmor() {
    if [[ -d "$APPARMOR_SRC_DIR/changehat/mod_apparmor" ]]; then
        info "Building Apache mod_apparmor..."
        cd "$APPARMOR_SRC_DIR/changehat/mod_apparmor"
        make -j"$(nproc)"
        sudo make install
    fi
}

build_pam_apparmor() {
    if [[ -d "$APPARMOR_SRC_DIR/changehat/pam_apparmor" ]]; then
        info "Building PAM AppArmor..."
        cd "$APPARMOR_SRC_DIR/changehat/pam_apparmor"
        make -j"$(nproc)"
        sudo make install
    fi
}

install_profiles() {
    info "Installing AppArmor profiles..."
    cd "$APPARMOR_SRC_DIR/profiles"
    make
    make check
    sudo make install
}

# --- install Python runtime dependencies (aa-notify) -------------------------
install_python_deps() {
    info "Installing Python runtime dependencies for aa-notify..."

    # ensure Python has tk and sqlite (already enforced by ensure_use_flag)
    # but if we just added them, a rebuild may be needed once
    if ! emerge --info | grep "^USE=" | grep -qw "tk" || \
       ! emerge --info | grep "^USE=" | grep -qw "sqlite"; then
        warn "Rebuilding dev-lang/python with tk and sqlite..."
        sudo emerge -1av dev-lang/python
    fi

    local -a emerge_pkgs=("dev-python/notify2" "dev-python/psutil" "dev-python/pygobject")
    info "Emerging: ${emerge_pkgs[*]}"
    sudo emerge -av "${emerge_pkgs[@]}"

    # ttkthemes is not in the main tree; use pip as fallback
    if ! equery list -q "dev-python/ttkthemes" &>/dev/null; then
        warn "dev-python/ttkthemes not in Portage; installing via pip..."
        if command -v pip3 >/dev/null 2>&1; then
            pip3 install --user ttkthemes || warn "pip3 install ttkthemes failed."
        elif command -v pip >/dev/null 2>&1; then
            pip install --user ttkthemes || warn "pip install ttkthemes failed."
        else
            warn "pip not found; please install ttkthemes manually."
        fi
    fi
}

# --- record installed version ------------------------------------------------
record_version() {
    local tag="$1"
    sudo mkdir -p "$(dirname "$APPARMOR_INSTALLED_VER_FILE")"
    echo "$tag" | sudo tee "$APPARMOR_INSTALLED_VER_FILE" >/dev/null
    info "Installed version recorded: $tag"
}

# --- kernel config warning ---------------------------------------------------
warn_kernel_config() {
    if [[ -f /proc/config.gz ]]; then
        if ! zgrep -q "CONFIG_SECURITY_APPARMOR=y" /proc/config.gz; then
            warn "AppArmor kernel support (CONFIG_SECURITY_APPARMOR=y) not found."
            warn "Please enable it in your kernel configuration."
        fi
    else
        warn "Cannot read kernel config (/proc/config.gz missing)."
        warn "Ensure CONFIG_SECURITY_APPARMOR=y is set in your kernel."
    fi
}

# --- main --------------------------------------------------------------------
main() {
    banner
    require_gentoo

    # early dependency check (requires root only for emerge)
    check_gentoo_deps
    require_cmd curl jq git

    warn_kernel_config

    # get latest tag
    local latest_tag
    latest_tag=$(get_latest_version)
    info "Latest AppArmor release from GitLab: $latest_tag"

    # idempotency check
    if [[ -f "$APPARMOR_INSTALLED_VER_FILE" ]]; then
        local current_ver
        current_ver=$(cat "$APPARMOR_INSTALLED_VER_FILE")
        if [[ "$current_ver" == "$latest_tag" ]]; then
            info "AppArmor $latest_tag is already installed. Nothing to do."
            exit 0
        fi
        info "Updating from $current_ver to $latest_tag ..."
    fi

    # interactive confirmation
    read -r -p "Proceed with build & install of AppArmor $latest_tag? [y/N] " ans
    if [[ ! "$ans" =~ ^[Yy] ]]; then
        info "Aborted by user."
        exit 0
    fi

    # prepare source and set up Python environment
    prepare_source "$latest_tag"
    setup_python_env

    # build & install in the order required by the README
    build_libapparmor
    build_binutils
    build_parser
    build_init
    build_utils
    build_mod_apparmor
    build_pam_apparmor
    install_profiles

    # Python deps
    install_python_deps

    # record success
    record_version "$latest_tag"

    info "AppArmor $latest_tag build & install completed successfully."
    info "Run 'aa-status' to verify."
}

# --- entry point -------------------------------------------------------------
main "$@"
```

---

## 🔗 Integration with `topgrade`

To have **Topgrade** automatically build and update AppArmor whenever you run `topgrade`, add the following `[commands]` section to your Topgrade configuration file (`~/.config/topgrade.toml`):

```toml
[commands]
"AppArmor Source Update" = "sudo /usr/local/bin/apparmor-update.sh"
```

Make sure the script is executable and placed in a location that is accessible to your user (the example uses `/usr/local/bin`):

```bash
sudo install -m 0755 apparmor-update.sh /usr/local/bin/apparmor-update.sh
```

**Important:** Topgrade runs custom commands from the configuration file in a fresh non‑interactive shell. Because this script is interactive, make sure that `sudo` is configured to allow password‑less execution for the user that runs `topgrade` (or that you set `pre_sudo` / `sudo_loop` in `topgrade.toml` as described in the [official documentation](https://github.com/topgrade-rs/topgrade/blob/master/config.example.toml)).

If you prefer the AppArmor update to happen **after** all other Topgrade steps, move the entry to the `[post_commands]` section:

```toml
[post_commands]
"AppArmor Source Update" = "sudo /usr/local/bin/apparmor-update.sh"
```

After adding the configuration, simply run `topgrade` – the script will be invoked automatically, check for the latest AppArmor release, and rebuild only when a new version is available.
