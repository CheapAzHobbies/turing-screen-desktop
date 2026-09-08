# Changelog

All notable changes to this project are documented here.
This project follows [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-09-08

First working release, verified end to end on real hardware: fresh install,
display starts, theme change applied without reopening the app, autostart at
login, and a second launch that does not create a duplicate.

### The AppImage
- One self-contained file: CPython 3.12 with tkinter, every dependency, and all
  upstream assets. No Python, virtualenv or clone needed.
- Clicking the app opens the settings window and nothing else. That window is
  upstream's own hub: **Apply to screen** starts the display, **Edit theme**
  opens the theme editor.
- **"Run at startup"** checkbox, patched into the settings window. Upstream has
  no autostart option of its own. Enabled by default on a fresh install, since
  anyone installing this wants the screen running; applied exactly once, so
  unticking it sticks.
- **Apply to screen** keeps the window open, with a **Close** button beside it,
  so adjusting a value does not mean reopening the app.
- Only ever one display, one settings window and one theme editor at a time.
  Starting the display replaces a running one, so new settings take effect.
- Settings live in `~/.local/share/turing-screen/app` and survive replacing the
  AppImage. The ~1 GB of fonts and theme art stays inside the image, so the
  working tree on disk is about 650 KB.

### The installer script
- `install.sh` finds or clones upstream, builds a virtualenv, and adds menu
  launchers. Detects apt, dnf, pacman, zypper or apk and offers to install what
  is missing, including the `dialout` group membership that is the usual reason
  a screen is never found.
- `uninstall.sh` reverses it; `--purge-app` also removes the app and settings.

### Testing
- `tests/test-apprun.sh`: 67 headless regression tests covering the AppImage
  runtime - mount paths changing between launches, settings surviving upgrades,
  edited themes not being clobbered, single-instance behaviour, and graceful
  degradation with and without zenity.
- `tests/test-patcher.sh`: applies the settings-window patch to the pinned
  upstream release and asserts every control landed, so an upstream change
  fails the build rather than shipping a window with missing buttons.
- CI runs both, plus shellcheck, desktop-entry validation, and a full
  install/uninstall of the script route on a clean runner.

### Note on earlier tags
Tags v1.0.0 through v1.6.0 were published during development and withdrawn.
They were not working releases: variously the AppImage failed on every launch
after the first, "Apply to screen" silently did nothing, or the display exited
immediately on a missing dependency path. This is the first release that works.
