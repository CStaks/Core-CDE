# CDE

![License](https://img.shields.io/badge/license-Apache%202.0-3DA639?style=flat-square&logo=apache)
![Python](https://img.shields.io/badge/python-3.x-blue)
![Platform](https://img.shields.io/badge/platform-linux-lightgrey)
![Display](https://img.shields.io/badge/display-X11-orange)
![Layout](https://img.shields.io/badge/layout-floating-blueviolet)


CStaks Desktop Environment (CDE) is a Linux-focused desktop environment layer built on top of the Qtile core.


## 🚀 Getting Started

You must have git installed.

1. Clone the repository, run:
   ```bash
   git clone https://github.com/CStaks/Core-CDE   
   ```

2. From this repository, run:
   ```bash
   ./setup.sh
   ```
   Run as your normal user (not `sudo`)
3. Restart your device.


Default keybinds from the shipped CDE config:

- `Super + Q`: terminal
- `Super + Space`: rofi app/file search launcher
- `Super + A`: fullscreen app launcher (rofi)
- `Super + E`: file manager (dolphin by default)
- `Super + ,`: CDE settings GUI
- `Super + F`: fullscreen toggle

Settings app highlights:

- Update channel switch (`stable` or `nightly`)
- `Check for Updates` and `Update CDE` actions
- One-time onboarding with welcome screen, theme choice, and update-channel choice
- `nightly` tracks `origin/main`; `stable` tracks `origin/stable`



Session commands after install:

- `cde start` (start CDE directly on X11)
- `cde session` (run the full CDE session launcher)
- `cde settings` (open the CDE settings app)

## 📦 Release flows

- `Nightly Source Release` is automatic on pushes to `main` and publishes a `nightly` (can be unstable)
- `Manual Publish Packages` is manual (`workflow_dispatch`) and is typically more stable than nightly
- Manual PyPI publish has guardrails: it requires running from `main`, explicit confirmation (`confirm_stable_release=publish-stable`), and preflight build/twine/import checks before publishing.

## 🤝 Contributing
See CONTRIBUTING.md

## 📄 License
![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)

This project is licensed under the Apache License 2.0.  
See the [LICENSE](./LICENSE) file for details.
