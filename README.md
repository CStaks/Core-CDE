# CDE

CStaks Desktop Environment (CDE) is a Linux-focused desktop environment layer built on top of Qtile.

## What CDE provides

- X11-only session entry (`CDE` in your display manager)
- Floating-first window behavior (no tiling layouts in the shipped config)
- Taskbar/panel via Qtile widgets (groups, task list, tray, clock)
- App launcher and search bindings with `rofi`
- `cde-settings` GUI for basic launcher/theme command preferences

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

## 🤝 Contributing
See CONTRIBUTING.md

## 📄 License
MIT License

