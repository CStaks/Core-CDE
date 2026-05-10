#!/usr/bin/env bash
set -euo pipefail

# Optional environment flags:
# - CDE_SKIP_DEPS=1: skip distro package dependency installation
# - CDE_SKIP_FLATPAK=1: skip Warehouse Flatpak installation
# - CDE_SKIP_DM=1: skip display manager configuration
PKG_MANAGER=""
DEBIAN_VERSION_ID=0
DEBIAN_CODENAME=""

cd "$(dirname "$0")"

# ---------------------------------------------------------------------------
# Package manager + distro detection
# ---------------------------------------------------------------------------

detect_pkg_manager() {
    if [ -n "${PKG_MANAGER}" ]; then
        return
    fi

    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MANAGER="zypper"
    else
        echo "No supported package manager found (apt, dnf, pacman, zypper)." >&2
        exit 1
    fi
}

# Populate DEBIAN_VERSION_ID and DEBIAN_CODENAME from /etc/os-release.
# Only meaningful when PKG_MANAGER=apt; safe to call on any distro.
detect_debian_version() {
    if [ ! -f /etc/os-release ]; then
        return
    fi
    local id=""
    id=$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
    if [ "${id}" != "debian" ]; then
        return
    fi
    DEBIAN_VERSION_ID=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"' || echo "0")
    DEBIAN_CODENAME=$(grep -E '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '"' || echo "")
    echo "Detected Debian ${DEBIAN_VERSION_ID} (${DEBIAN_CODENAME})"
}

# Add bookworm-backports if we are on Debian 12 and it is not already present.
enable_bookworm_backports() {
    local sources_list="/etc/apt/sources.list.d/bookworm-backports.list"
    if [ -f "${sources_list}" ]; then
        return
    fi
    echo "Enabling Debian bookworm-backports for newer packages..."
    echo "deb http://deb.debian.org/debian bookworm-backports main" \
        | sudo tee "${sources_list}" >/dev/null
    sudo apt-get update -qq
}

# ---------------------------------------------------------------------------
# Source builds for packages not available on Debian Bookworm
# ---------------------------------------------------------------------------

# libdisplay-info is required by wlroots >= 0.17 but is not packaged on
# Debian 12 Bookworm. Build it from source before building wlroots.
build_libdisplay_info_from_source() {
    if pkg-config --exists libdisplay-info 2>/dev/null; then
        echo "libdisplay-info already available via pkg-config, skipping source build."
        return
    fi

    echo "Building libdisplay-info from source (required by wlroots >= 0.17)..."
    sudo apt-get install -y meson ninja-build git hwdata

    local build_dir
    build_dir="$(mktemp -d)"
    trap "rm -rf ${build_dir}" RETURN

    local tag
    tag=$(git ls-remote --tags https://gitlab.freedesktop.org/emersion/libdisplay-info.git \
        | awk -F'/' '{print $NF}' \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
        | sort -V \
        | tail -1)

    if [ -z "${tag}" ]; then
        echo "Could not resolve a libdisplay-info release tag." >&2
        exit 1
    fi

    echo "Building libdisplay-info ${tag}..."
    git clone --depth=1 --branch "${tag}" \
        https://gitlab.freedesktop.org/emersion/libdisplay-info.git \
        "${build_dir}/libdisplay-info"

    meson setup "${build_dir}/libdisplay-info/_build" "${build_dir}/libdisplay-info" \
        --prefix=/usr/local
    ninja -C "${build_dir}/libdisplay-info/_build"
    sudo ninja -C "${build_dir}/libdisplay-info/_build" install
    sudo ldconfig
    echo "libdisplay-info ${tag} installed to /usr/local."
}

build_wlroots_from_source() {
    echo "Building wlroots from source..."

    # Core build toolchain and wlroots dependencies available on all supported releases
    sudo apt-get install -y \
        meson ninja-build git \
        libdrm-dev libgbm-dev libpixman-1-dev \
        libvulkan-dev glslang-tools \
        libseat-dev libxkbcommon-dev libudev-dev \
        libxcb-dri3-dev libxcb-present-dev libxcb-composite0-dev \
        libxcb-xinput-dev libxcb-icccm4-dev \
        libxcb-render-util0-dev libx11-xcb-dev

    # Optional — present on Trixie+, absent on Bookworm; ignore failures
    sudo apt-get install -y libxcb-errors-dev 2>/dev/null || true

    # libdisplay-info: packaged on Trixie+, needs source build on Bookworm
    if ! sudo apt-get install -y libdisplay-info-dev 2>/dev/null; then
        build_libdisplay_info_from_source
    fi

    local build_dir
    build_dir="$(mktemp -d)"
    trap "rm -rf ${build_dir}" RETURN

    local wlroots_tag
    wlroots_tag=$(git ls-remote --tags https://gitlab.freedesktop.org/wlroots/wlroots.git \
        | awk -F'/' '{print $NF}' \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
        | sort -V \
        | tail -1)

    if [ -z "${wlroots_tag}" ]; then
        echo "Failed to resolve a wlroots release tag. Check your internet connection." >&2
        exit 1
    fi

    # Make sure pkg-config can find source-built libdisplay-info
    local arch
    arch="$(uname -m)-linux-gnu"
    export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}:/usr/local/lib/pkgconfig:/usr/local/lib/${arch}/pkgconfig"

    echo "Building wlroots ${wlroots_tag}..."
    git clone --depth=1 --branch "${wlroots_tag}" \
        https://gitlab.freedesktop.org/wlroots/wlroots.git "${build_dir}/wlroots"

    meson setup "${build_dir}/wlroots/_build" "${build_dir}/wlroots" \
        --prefix=/usr/local \
        -Drenderers=gles2 \
        -Dbackends=drm,libinput,wayland

    ninja -C "${build_dir}/wlroots/_build"
    sudo ninja -C "${build_dir}/wlroots/_build" install
    sudo ldconfig
    echo "wlroots ${wlroots_tag} installed to /usr/local."
}

# ---------------------------------------------------------------------------
# Dependency installation
# ---------------------------------------------------------------------------

install_deps() {
    echo "Installing CDE runtime dependencies..."

    detect_pkg_manager

    if [ "$PKG_MANAGER" = "apt" ]; then
        detect_debian_version

        # On Debian 12 Bookworm, enable backports so we have the best chance
        # of finding a recent enough wlroots package before falling back to source.
        if [ "${DEBIAN_VERSION_ID}" = "12" ]; then
            enable_bookworm_backports
        fi

        sudo apt-get update
        sudo apt-get install -y \
            picom dunst rofi dolphin flatpak python3-tk kitty lightdm lightdm-gtk-greeter \
            build-essential python3-dev pkg-config libcairo2-dev libffi-dev libinput-dev \
            libwayland-dev libxkbcommon-dev wayland-protocols libwayland-bin

        # Try packaged wlroots dev headers newest-first.
        # On Bookworm also try pulling from backports explicitly.
        wlroots_installed=0
        wlroots_candidates=(libwlroots-dev libwlroots-0.19-dev libwlroots-0.18-dev)

        for pkg in "${wlroots_candidates[@]}"; do
            if sudo apt-get install -y "${pkg}" 2>/dev/null; then
                wlroots_installed=1
                echo "Installed packaged wlroots: ${pkg}"
                break
            fi
            if [ "${DEBIAN_VERSION_ID}" = "12" ]; then
                if sudo apt-get install -y -t bookworm-backports "${pkg}" 2>/dev/null; then
                    wlroots_installed=1
                    echo "Installed wlroots from bookworm-backports: ${pkg}"
                    break
                fi
            fi
        done

        if [ "${wlroots_installed}" -ne 1 ]; then
            echo "No packaged wlroots dev headers found. Falling back to source build..."
            build_wlroots_from_source
        fi

    elif [ "$PKG_MANAGER" = "dnf" ]; then
        dnf_common=(
            picom dunst rofi dolphin flatpak python3-tkinter kitty lightdm
            gcc python3-devel cairo-devel libinput-devel
            wayland-devel wayland-protocols-devel wayland-utils
            pkgconf-pkg-config libffi-devel libxkbcommon-devel
        )
        if ! sudo dnf install -y "${dnf_common[@]}" wlroots0.19-devel; then
            sudo dnf install -y "${dnf_common[@]}" wlroots-devel
        fi

    elif [ "$PKG_MANAGER" = "pacman" ]; then
        sudo pacman -Sy --noconfirm \
            picom dunst rofi dolphin flatpak tk kitty lightdm lightdm-gtk-greeter \
            base-devel python pkgconf cairo libffi libinput wayland wayland-protocols wlroots libxkbcommon

    elif [ "$PKG_MANAGER" = "zypper" ]; then
        sudo zypper --non-interactive install \
            picom dunst rofi dolphin flatpak python3-tk kitty lightdm \
            gcc make python3-devel pkg-config cairo-devel libffi-devel libinput-devel \
            wayland-devel wayland-protocols-devel wlroots-devel libxkbcommon-devel
    fi
}

# ---------------------------------------------------------------------------
# Flatpak GUI
# ---------------------------------------------------------------------------

install_flatpak_gui() {
    echo "Setting up Flatpak app store GUI..."
    sudo flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    if sudo flatpak install --system -y flathub io.github.flattool.Warehouse; then
        return
    fi

    echo "Flatpak install failed. Retrying without static deltas (lower disk usage)..."
    sudo flatpak install --system -y --no-static-deltas flathub io.github.flattool.Warehouse
}

# ---------------------------------------------------------------------------
# Display manager
# ---------------------------------------------------------------------------

configure_login_manager() {
    echo "Configuring LightDM as default login manager..."

    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl enable --force lightdm.service
        sudo systemctl set-default graphical.target
    fi

    if [ -d "/etc/X11" ]; then
        lightdm_bin="$(command -v lightdm || true)"
        if [ -n "${lightdm_bin}" ]; then
            echo "${lightdm_bin}" | sudo tee /etc/X11/default-display-manager >/dev/null
        fi
    fi
}

configure_lightdm_session() {
    echo "Setting CDE as the default LightDM session..."
    sudo mkdir -p /etc/lightdm/lightdm.conf.d
    # Quoted heredoc is intentional: do not expand variables while writing config.
    cat <<'EOF' | sudo tee /etc/lightdm/lightdm.conf.d/50-cde.conf >/dev/null
[Seat:*]
user-session=cde
EOF
}

install_session_entry() {
    echo "Installing CDE display-manager session entry..."
    # Remove stale CDE entries from older installs so the login menu has one CDE option.
    sudo rm -f \
        /usr/share/xsessions/cde*.desktop \
        /usr/local/share/xsessions/cde*.desktop \
        /usr/share/wayland-sessions/cde*.desktop \
        /usr/local/share/wayland-sessions/cde*.desktop

    sudo mkdir -p /usr/share/wayland-sessions
    sudo install -m 0644 resources/cde.desktop /usr/share/wayland-sessions/cde.desktop
    if ! sudo test -f /usr/share/wayland-sessions/cde.desktop; then
        echo "Failed to install /usr/share/wayland-sessions/cde.desktop." >&2
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Python package
# ---------------------------------------------------------------------------

ensure_pip() {
    if python3 -m pip --version >/dev/null 2>&1; then
        return
    fi

    echo "python3-pip not found. Installing pip for Python 3..."
    detect_pkg_manager

    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y python3-pip
    elif [ "$PKG_MANAGER" = "dnf" ]; then
        sudo dnf install -y python3-pip
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        sudo pacman -Sy --noconfirm python-pip
    elif [ "$PKG_MANAGER" = "zypper" ]; then
        sudo zypper --non-interactive install python3-pip
    fi

    if ! python3 -m pip --version >/dev/null 2>&1; then
        echo "Failed to install python3-pip automatically." >&2
        exit 1
    fi
}

install_python_package() {
    ensure_pip
    if ! python3 -m pip install --upgrade pip setuptools wheel "setuptools-scm>=7.0"; then
        python3 -m pip install --break-system-packages --upgrade pip setuptools wheel "setuptools-scm>=7.0"
    fi
    # Ignore uninstall errors if package is not installed yet.
    python3 -m pip uninstall -y cstaks-cde >/dev/null 2>&1 || true

    # Ensure pkg-config can find wlroots regardless of whether it was installed
    # from a package or built from source into /usr/local.
    local arch
    arch="$(uname -m)-linux-gnu"
    export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}:/usr/local/lib/pkgconfig:/usr/local/lib/${arch}/pkgconfig:/usr/lib/${arch}/pkgconfig:/usr/lib/pkgconfig"

    # Confirm wlroots is resolvable before attempting a Wayland backend build.
    local wayland_ok=0
    if pkg-config --exists wlroots 2>/dev/null; then
        echo "wlroots $(pkg-config --modversion wlroots) found. Attempting Wayland backend build."
        wayland_ok=1
    else
        echo "WARNING: pkg-config cannot find wlroots. Skipping Wayland backend build." >&2
    fi

    if [ "${wayland_ok}" -eq 1 ]; then
        pip_flag_sets=(
            "--config-settings=backend=wayland"
            "--break-system-packages --config-settings=backend=wayland"
            "--no-build-isolation --config-settings=backend=wayland"
            "--break-system-packages --no-build-isolation --config-settings=backend=wayland"
        )
        for pip_flags in "${pip_flag_sets[@]}"; do
            # shellcheck disable=SC2086
            if python3 -m pip install --no-cache-dir --force-reinstall ${pip_flags} .; then
                return
            fi
        done
        echo "WARNING: All Wayland backend pip attempts failed. Falling back to default backend." >&2
    fi

    # Last resort: let the package choose its own backend.
    echo "Attempting build without explicit backend selection..."
    if python3 -m pip install --no-cache-dir --force-reinstall .; then return; fi
    if python3 -m pip install --break-system-packages --no-cache-dir --force-reinstall .; then return; fi
    if python3 -m pip install --no-build-isolation --no-cache-dir --force-reinstall .; then return; fi
    if python3 -m pip install --break-system-packages --no-build-isolation --no-cache-dir --force-reinstall .; then return; fi

    if python3 -m pip install --help 2>/dev/null | grep -q -- "--no-use-pep517"; then
        if python3 -m pip install --no-use-pep517 --no-cache-dir --force-reinstall .; then return; fi
        if python3 -m pip install --break-system-packages --no-use-pep517 --no-cache-dir --force-reinstall .; then return; fi
    fi

    echo "Failed to install CDE Python package with pip." >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

detect_pkg_manager

if [ "${CDE_SKIP_DEPS:-0}" != "1" ]; then
    install_deps
fi

if [ "${CDE_SKIP_FLATPAK:-0}" != "1" ]; then
    install_flatpak_gui
fi

echo "Installing CDE session and defaults..."
sudo mkdir -p /etc/cde
sudo install -m 0644 resources/default_config.py /etc/cde/default_config.py
install_session_entry
sudo install -m 0644 resources/99-cde.rules /etc/udev/rules.d/99-cde.rules
sudo install -m 0755 resources/cde /usr/local/bin/cde
sudo install -m 0755 resources/cde-session /usr/local/bin/cde-session
sudo install -m 0755 resources/cde-workspaces /usr/local/bin/cde-workspaces
sudo install -m 0755 resources/cde-settings /usr/local/bin/cde-settings
sudo install -m 0644 resources/cde-settings.desktop /usr/share/applications/cde-settings.desktop

echo "Installing CDE Python package..."
install_python_package

if [ "${CDE_SKIP_DM:-0}" != "1" ]; then
    configure_login_manager
    configure_lightdm_session
fi

echo "CDE installed. LightDM is configured to default to \"CDE\"."
echo "Flatpak GUI installed: Warehouse (launch with: flatpak run io.github.flattool.Warehouse)"
echo "Login manager: LightDM (disable with CDE_SKIP_DM=1)"
echo "Active setup flags: CDE_SKIP_DEPS=${CDE_SKIP_DEPS:-0} CDE_SKIP_FLATPAK=${CDE_SKIP_FLATPAK:-0} CDE_SKIP_DM=${CDE_SKIP_DM:-0}"