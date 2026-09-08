# Changelog

All notable changes to this project are documented here.
This project follows [Semantic Versioning](https://semver.org/).

## [1.6.0] - 2026-09-08

### Changed
- **"Save and run" is now "Apply to screen" and no longer closes the window.**
  Adjusting a value meant reopening the app every time; now you can keep
  tweaking and applying.

### Added
- **Close button** in the settings window.

### Removed
- The "Reset screen on startup" checkbox added in 1.5.0. The flash it avoided
  only appears when reconfiguring a screen that is already running, never at
  boot, so the option was not worth the extra control.

## [1.5.0] - 2026-09-08

### Added
- **"Reset screen on startup" checkbox.** Upstream sends a hardware RESET at
  startup, which reboots the panel: it flashes, shows its firmware screen, then
  waits five seconds before drawing. Upstream's own config note says rev. A
  displays are better off without it, but the option was not exposed anywhere.
  Measured on a rev. A panel: 7 seconds and a flash with it, 1 second and no
  flash without.
- **Close button** in the settings window.
- `tests/test-patcher.sh`, run by CI: applies the configure.py patch to the
  pinned upstream release and asserts every control landed and the result is
  valid Python, so an upstream change fails the build instead of shipping a
  window with missing buttons.

### Changed
- **"Save and run" is now "Apply to screen" and no longer closes the window.**
  Adjusting a value meant reopening the app every time; now you can keep
  tweaking and applying.

## [1.4.0] - 2026-09-08

Verified end to end on real hardware before release: fresh install, display
starts, theme change applied by Save and run, simulated login autostart, and a
second launch that does not duplicate.

### Added
- "Run at startup" checkbox in the settings window, patched into upstream at
  build time. Upstream has no autostart option of its own.
- Autostart is enabled by default on a fresh install, with no prompt. Applied
  exactly once, so unticking the checkbox sticks.
- Clicking the app opens the settings window and nothing else. Save and run
  starts the display; Edit theme opens the editor.
- `tests/test-apprun.sh`: 67 headless regression tests, run by CI.

### Fixed
- The display died instantly, logging only "Loading theme". The launch path had
  been rewritten to a bare exec that dropped PYTHONPATH, so the first
  third-party import failed and upstream exited 0 silently.
- Save and run did nothing when a display was already running. configure.py
  passes an absolute path to main.py, which the process scan did not recognise.
  Starting the display now replaces a running one.
- The launcher killed itself: the interpreter shim is named ".python" and
  detection matched "python" as a substring, so the shim was mistaken for the
  display it was starting. Matching is now on the basename.
- A shell sitting in the working directory could be killed, because detection
  matched any command line containing "main.py".
- The display was started with the interpreter from a mount that unmounts as
  soon as configure.py exits. Long-lived windows now relaunch the AppImage so
  each owns a live mount.
- Autostart hung at login: AppImageLauncher intercepts un-integrated images with
  an "Integrate and run" dialog that nobody is there to click. The login
  launcher now bypasses it.

## [1.3.0] - 2026-09-08

### Added
- "Run at startup" checkbox in the configuration window itself, patched into
  upstream at build time. Upstream has no autostart option, and a flag or a
  right-click action is not something a normal user will find.
- Clicking the app opens the settings window and nothing else. That window is
  upstream's own hub: Save and run starts the display, Edit theme opens the
  editor.
- `tests/test-apprun.sh`: 57 headless regression tests, run by CI.

### Fixed
- Upstream ships `#!/usr/bin/env python` and the wizard launches its scripts
  through that shebang. Plain `python` does not exist on most distros, so
  "Save and run" and "Edit theme" were both dead inside the AppImage.
- "Save and run" appeared to do nothing when a display was already running.
  Starting the display now replaces a running one rather than refusing.
- The process scan matched any command line containing "main.py", so a shell
  sitting in the working directory could be killed. Detection is now exact.

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
