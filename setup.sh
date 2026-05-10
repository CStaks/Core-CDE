#!/usr/bin/env bash
set -eu

PKG_MANAGER=""

detect_pkg_manager() {
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

install_deps() {
    echo "Installing CDE runtime dependencies..."

    detect_pkg_manager

    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y \
            picom dunst rofi dolphin flatpak python3-tk kitty lightdm lightdm-gtk-greeter \
            build-essential python3-dev pkg-config libcairo2-dev libffi-dev libinput-dev \
            libwayland-dev libxkbcommon-dev wayland-protocols libwayland-bin
        if ! sudo apt-get install -y libwlroots-dev; then
            if ! sudo apt-get install -y libwlroots-0.19-dev; then
                if ! sudo apt-get install -y libwlroots-0.18-dev; then
                    echo "No compatible wlroots development package found (tried libwlroots-dev/0.19/0.18)." >&2
                    exit 1
                fi
            fi
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

install_flatpak_gui() {
    echo "Setting up Flatpak app store GUI..."
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    if sudo flatpak install -y flathub io.github.flattool.Warehouse; then
        return
    fi

    echo "Flatpak install failed. Retrying without static deltas (lower disk usage)..."
    sudo flatpak install -y --no-static-deltas flathub io.github.flattool.Warehouse
}

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
    if ! python3 -m pip install --upgrade pip setuptools wheel "setuptools-scm>=7.0" "cffi>=1.1.0" "cairocffi[xcb]>=1.6.0"; then
        python3 -m pip install --break-system-packages --upgrade pip setuptools wheel "setuptools-scm>=7.0" "cffi>=1.1.0" "cairocffi[xcb]>=1.6.0"
    fi
    python3 -m pip uninstall -y cstaks-cde >/dev/null 2>&1 || true
    if python3 -m pip install --no-build-isolation --no-cache-dir --force-reinstall --config-settings=backend=wayland .; then
        return
    fi

    if python3 -m pip install --break-system-packages --no-build-isolation --no-cache-dir --force-reinstall --config-settings=backend=wayland .; then
        return
    fi

    echo "Failed to install CDE Python package with pip." >&2
    exit 1
}

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
