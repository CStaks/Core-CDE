# CDE

![License](https://img.shields.io/badge/license-Apache%202.0-3DA639?style=flat-square&logo=apache)
![Python](https://img.shields.io/badge/python-3.x-blue)
![Platform](https://img.shields.io/badge/platform-linux-lightgrey)
![Display](https://img.shields.io/badge/display-Wayland-orange)
![Layout](https://img.shields.io/badge/layout-floating-blueviolet)


CStaks Desktop Environment (CDE) is a Linux-focused desktop environment layer built on top of the Qtile core.


## 🚀 Getting Started

You must have git installed.

1. Clone the repository and enter the directory, run:
   ```bash
   git clone https://github.com/CStaks/Core-CDE
   cd Core-CDE
   ```
2. Run setup from this repository:
   ```bash
   bash setup.sh
   ```
   Run as your normal user (not `sudo`)
3. Restart your device.


Default keybinds from the shipped CDE config:

- `Super + Q`: terminal
- `Super + Space`: rofi app/file search launcher
- `Super + A`: fullscreen app launcher (rofi)
- `Super + E`: file manager (dolphin by default)
- `Super + 1..9,0`: switch workspaces 1..10
- `Super + Shift + 1..9,0`: send focused window to workspace 1..10
- `Super + \``: workspace picker menu
- `Super + ,`: CDE settings GUI
- `Super + F`: fullscreen toggle

Settings app highlights:

- Sectioned settings layout: `General`, `Appearance`, `Launchers`, `Updates`, `Advanced`
- Update channel switch (`stable` or `nightly`)
- `Check for Updates` and `Update CDE` actions
- One-time onboarding with welcome screen, theme choice, and update-channel choice
- `nightly` tracks `origin/main`; `stable` tracks `origin/stable`
- `Update CDE` force-syncs to selected remote channel and discards local repo changes

Desktop highlights:

- Dock-style bottom bar with launcher icons
- Single workspace icon opens a workspace picker (up to 10 workspaces)



Session commands after install:

- `cde start` (start CDE directly on Wayland)
- `cde session` (run the full CDE session launcher)
- `cde settings` (open the CDE settings app)

## 📦 Release flows

- `Nightly Source Release` is automatic on pushes to `main` and publishes a `nightly` (can be unstable)
- `Manual Publish Packages` is manual (`workflow_dispatch`) and is typically more stable than nightly
- Manual PyPI publish has guardrails: it requires running from `main`, explicit confirmation (`confirm_stable_release=publish-stable`), and preflight build/twine/import checks before publishing.

Install/update one-liners (no manual `chmod` needed):

- Nightly:
  ```bash
  git clone --branch main https://github.com/CStaks/Core-CDE.git Core-CDE && cd Core-CDE && bash setup.sh
  ```
- Stable:
  ```bash
  git clone --branch stable https://github.com/CStaks/Core-CDE.git Core-CDE && cd Core-CDE && bash setup.sh
  ```
- Update existing checkout to nightly:
  ```bash
  cd Core-CDE && git -c core.hooksPath=/dev/null fetch origin && git -c core.hooksPath=/dev/null checkout main && git -c core.hooksPath=/dev/null reset --hard origin/main && CDE_SKIP_FLATPAK=1 bash setup.sh
  ```
- Update existing checkout to stable:
  ```bash
  cd Core-CDE && git -c core.hooksPath=/dev/null fetch origin && git -c core.hooksPath=/dev/null checkout stable && git -c core.hooksPath=/dev/null reset --hard origin/stable && CDE_SKIP_FLATPAK=1 bash setup.sh
  ```

## 🤝 Contributing
See CONTRIBUTING.md

## 📄 License
![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)

This project is licensed under the Apache License 2.0.  
See the [LICENSE](./LICENSE) file for details.
