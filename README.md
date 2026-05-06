# CDE

![License](https://img.shields.io/badge/license-Apache%202.0-3DA639?style=flat-square&logo=apache)
![Python](https://img.shields.io/badge/python-3.x-blue)
![Platform](https://img.shields.io/badge/platform-linux-lightgrey)
![Display](https://img.shields.io/badge/display-X11-orange)
![Layout](https://img.shields.io/badge/layout-floating--tiling-blueviolet)


CStaks Desktop Environment (CDE) is a Linux-focused desktop environment layer built on top of the libqtile core.


## 🚀 Getting Started

1. From this repository, run:
   ```bash
   ./setup.sh
   ```
2. Log out and choose **CDE** from your login manager session list.

Default keybinds from the shipped CDE config:

- `Super + Enter`: terminal
- `Super + D`: app launcher (`rofi -show drun`)
- `Super + P`: command runner (`rofi -show run`)
- `Super + /`: file search (`rofi filebrowser mode`)
- `Super + ,`: CDE settings GUI
- `Super + F`: fullscreen toggle

By default, `setup.sh` installs core desktop dependencies (`picom`, `dunst`, `rofi`), Flatpak, and the Flatpak GUI app store **Warehouse**.
Set `CDE_SKIP_DEPS=1` if you only want to install CDE files without package installs.
Default terminal is **Kitty** when available.

Session commands after install:

- `cde start` (start CDE directly on X11)
- `cde session` (run the full CDE session launcher)
- `cde settings` (open the CDE settings app)

## 🤝 Contributing
See CONTRIBUTING.md

## 📄 License
![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)

This project is licensed under the Apache License 2.0.  
See the [LICENSE](./LICENSE) file for details.