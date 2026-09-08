# Changelog

All notable changes to this project are documented here.
This project follows [Semantic Versioning](https://semver.org/).

## [1.2.1] - 2026-09-08

### Fixed
- **The AppImage only worked on its first launch.** An AppImage mounts at a
  fresh `/tmp/.mount_XXXXXX` every run and is unmounted on exit, so the asset
  symlinks written into the working tree pointed at a path that no longer
  existed the next time. Because the version stamp still matched, they were
  never rebuilt, and the app failed with "Theme not found or contains errors!".
  Asset links are now re-pointed on every launch; code is still only copied
  when the bundled version changes.

## [1.2.0] - 2026-09-07

### Changed
- The release page now explains itself: notes lead with the AppImage, give
  copy-paste instructions for both install routes, and include a table saying
  what every asset is.
- One workflow builds and publishes everything. Previously two workflows wrote
  to the same release, so the notes described only the tarball and never
  mentioned the AppImage.
- Checksums are named after the file they cover
  (`Turing_Smart_Screen-x86_64.AppImage.sha256`) instead of a generic
  `SHA256SUMS.txt` sitting beside a similarly named tarball checksum.

## [1.1.3] - 2026-09-07

### Fixed
- Build steps referenced `*.AppImage`, which also matched the downloaded
  CPython base image: the smoke test resolved two paths, and the release would
  have shipped a stray ~100 MB python.AppImage. Everything now names the
  artifact explicitly, and the base image is deleted once extracted.

## [1.1.2] - 2026-09-07

### Fixed
- Install libfuse2 on the build runner: appimagetool is itself an AppImage and
  the smoke test runs the built image, so neither worked without FUSE 2.

## [1.1.1] - 2026-09-07

### Fixed
- AppImage build resolves the bundled CPython from the python-appimage release
  API instead of a hardcoded patch version that 404d.
- The AppImage now has a version-free filename, so
  `/releases/latest/download/Turing_Smart_Screen-x86_64.AppImage` is a stable
  link that never needs updating.

## [1.1.0] - 2026-09-07

### Added
- **AppImage build.** A single self-contained file with CPython, tkinter, every
  dependency and all upstream assets. No Python, virtualenv or clone needed.
  Built and smoke-tested in CI, attached to each release.
- **Multi-distro support in `install.sh`.** Detects apt, dnf, pacman, zypper or
  apk and maps logical dependencies to the right package names for each.
- Per-distro dependency commands in the README.

### Notes on the AppImage
Upstream resolves `config.yaml`, fonts and themes from
`Path(__file__).parent.parent.resolve()`, so it expects to write next to its own
source — impossible inside a read-only AppImage mount. On first run `AppRun`
builds a small writable tree in `~/.local/share/turing-screen/app`: code and
`config.yaml` are real files, while ~1 GB of fonts and theme artwork stay
symlinked into the image. A theme is copied for real only when it is edited.
Because `.resolve()` follows symlinks, the `library/` directory must be a real
copy or the app would resolve straight back into the read-only mount.

## [1.0.0] - 2026-09-07

First release.

### Added
- `install.sh` — one-command setup: locates or clones upstream, builds the
  virtualenv, installs three menu launchers and the icon.
- `uninstall.sh` — removes the launchers; `--purge-app` also removes the app.
- Preflight checks for Python 3.9–3.14, venv, tkinter, git and zenity, with an
  offer to install what is missing.
- `dialout` group check with an offer to fix it, since missing serial
  permissions is the most common reason the screen never appears.
- Theme picker wrapper, because upstream's `theme-editor.py` requires a theme
  name as an argument and otherwise just prints usage.
- Detection of a pre-existing hand-written Turing autostart entry, so the
  display does not get launched twice.
- Optional autostart at login via `--autostart`.
