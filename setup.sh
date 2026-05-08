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
        sudo apt-get install -y picom dunst rofi dolphin flatpak python3-tk kitty lightdm lightdm-gtk-greeter
    elif [ "$PKG_MANAGER" = "dnf" ]; then
        sudo dnf install -y picom dunst rofi dolphin flatpak python3-tkinter kitty lightdm
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        sudo pacman -Sy --noconfirm picom dunst rofi dolphin flatpak tk kitty lightdm lightdm-gtk-greeter
    elif [ "$PKG_MANAGER" = "zypper" ]; then
        sudo zypper --non-interactive install picom dunst rofi dolphin flatpak python3-tk kitty lightdm
    fi
}

install_flatpak_gui() {
    echo "Setting up Flatpak app store GUI..."
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    sudo flatpak install -y flathub io.github.flattool.Warehouse
}

configure_login_manager() {
    echo "Configuring LightDM as default login manager..."

    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl enable lightdm.service
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

install_python_package() {
    if python3 -m pip install .; then
        return
    fi

    if python3 -m pip install --break-system-packages .; then
        return
    fi

    echo "Failed to install CDE Python package with pip." >&2
    exit 1
}

if [ "${CDE_SKIP_DEPS:-0}" != "1" ]; then
    install_deps
    install_flatpak_gui
fi

echo "Installing CDE Python package..."
install_python_package

echo "Installing CDE session and defaults..."
sudo mkdir -p /etc/cde
sudo install -m 0644 resources/default_config.py /etc/cde/default_config.py
sudo install -m 0644 resources/cde.desktop /usr/share/xsessions/cde.desktop
sudo install -m 0644 resources/99-cde.rules /etc/udev/rules.d/99-cde.rules
sudo install -m 0755 resources/cde /usr/local/bin/cde
sudo install -m 0755 resources/cde-session /usr/local/bin/cde-session
sudo install -m 0755 resources/cde-workspaces /usr/local/bin/cde-workspaces
sudo install -m 0755 resources/cde-settings /usr/local/bin/cde-settings
sudo install -m 0644 resources/cde-settings.desktop /usr/share/applications/cde-settings.desktop

if [ "${CDE_SKIP_DM:-0}" != "1" ]; then
    configure_login_manager
    configure_lightdm_session
fi

echo "CDE installed. LightDM is configured to default to \"CDE\"."
echo "Flatpak GUI installed: Warehouse (launch with: flatpak run io.github.flattool.Warehouse)"
echo "Login manager: LightDM (disable with CDE_SKIP_DM=1)"
