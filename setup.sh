#!/usr/bin/env bash
set -eu

install_deps() {
    echo "Installing CDE runtime dependencies..."

    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y picom dunst rofi flatpak python3-tk
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y picom dunst rofi flatpak python3-tkinter
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm picom dunst rofi flatpak tk
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper --non-interactive install picom dunst rofi flatpak python3-tk
    else
        echo "No supported package manager found (apt, dnf, pacman, zypper)." >&2
        exit 1
    fi
}

install_flatpak_gui() {
    echo "Setting up Flatpak app store GUI..."
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    sudo flatpak install -y flathub io.github.flattool.Warehouse
}

if [ "${CDE_SKIP_DEPS:-0}" != "1" ]; then
    install_deps
    install_flatpak_gui
fi

echo "Installing CDE Python package..."
python3 -m pip install .

echo "Installing CDE session and defaults..."
sudo mkdir -p /etc/cde
sudo install -m 0644 resources/default_config.py /etc/cde/default_config.py
sudo install -m 0644 resources/cde.desktop /usr/share/xsessions/cde.desktop
sudo install -m 0755 resources/cde-session /usr/local/bin/cde-session
sudo install -m 0755 resources/cde-settings /usr/local/bin/cde-settings
sudo install -m 0644 resources/cde-settings.desktop /usr/share/applications/cde-settings.desktop

echo "CDE installed. Select \"CDE\" at your login screen."
echo "Flatpak GUI installed: Warehouse (launch with: flatpak run io.github.flattool.Warehouse)"
