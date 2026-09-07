# Changelog

All notable changes to this project are documented here.
This project follows [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-09-07

First release.

### Added
- `install.sh` — one-command setup: locates or clones upstream, builds the
  virtualenv, installs three menu launchers and the icon.
- `uninstall.sh` — removes the launchers; `--purge-app` also removes the app.
- Preflight checks for Python 3.9–3.14, `python3-venv`, `python3-tk`, `git`
  and `zenity`, with an offer to apt-install what is missing.
- `dialout` group check with an offer to fix it, since missing serial
  permissions is the most common reason the screen never appears.
- Theme picker wrapper, because upstream's `theme-editor.py` requires a theme
  name as an argument and otherwise just prints usage.
- Detection of a pre-existing hand-written Turing autostart entry, so the
  display does not get launched twice.
- Optional autostart at login via `--autostart`.
