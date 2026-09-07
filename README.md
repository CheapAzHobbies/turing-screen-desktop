# turing-screen-desktop

Desktop launchers for [turing-smart-screen-python](https://github.com/mathoudebine/turing-smart-screen-python)
on Linux — set up, theme, and start your Turing smart screen from the applications
menu instead of remembering `cd` and virtualenv paths.

Upstream ships an excellent Python program. This adds the last mile: a one-command
install that creates the virtualenv, checks the things that usually go wrong
(serial permissions, `python3-tk`), and drops three entries into your menu.

## What you get

| Launcher | What it does |
|---|---|
| **Turing Screen Configuration** | Display model, port, brightness, theme, sensors |
| **Turing Theme Editor** | Pick any installed theme and edit its layout live |
| **Turing Screen Display** | Start pushing stats to the screen |

Search your applications menu for `turing`, `lcd`, or `screen`.

The theme editor upstream requires a theme name on the command line, so this
wraps it in a picker that lists every installed theme with your active one
preselected.

## Install

### Option 1 — AppImage (nothing to set up)

One file, no Python, no virtualenv, no cloning. Download it, make it executable,
run it. Works on any distro with FUSE.

```bash
curl -fsSLO https://github.com/CheapAzHobbies/turing-screen-desktop/releases/latest/download/Turing_Smart_Screen-x86_64.AppImage
chmod +x Turing_Smart_Screen-*.AppImage
./Turing_Smart_Screen-*.AppImage
```

Or just download it from the [releases page](https://github.com/CheapAzHobbies/turing-screen-desktop/releases/latest),
right-click → Properties → *Allow executing as program*, and double-click it.

The first run opens the configuration wizard; after that it starts the display.

```
./Turing_Smart_Screen-*.AppImage --config          # configuration wizard
./Turing_Smart_Screen-*.AppImage --theme-editor    # pick a theme and edit it
./Turing_Smart_Screen-*.AppImage --display         # start the display
./Turing_Smart_Screen-*.AppImage --where           # where settings are kept
```

Settings live in `~/.local/share/turing-screen/app/` and survive replacing the
AppImage with a newer one. It is a large download (~1 GB) because upstream ships
about 850 MB of theme artwork and 190 MB of fonts, all bundled so it works offline.

To get it into your applications menu, use [Gear Lever](https://flathub.org/apps/it.mijorus.gearlever)
or [AppImageLauncher](https://github.com/TheAssassin/AppImageLauncher).

### Option 2 — Installer script (menu launchers, smaller download)

Download the latest release, unpack it, and run the installer:

```bash
curl -fsSL https://github.com/CheapAzHobbies/turing-screen-desktop/releases/latest/download/turing-screen-desktop.tar.gz | tar xz
cd turing-screen-desktop
./install.sh
```

Or from a clone:

```bash
git clone https://github.com/CheapAzHobbies/turing-screen-desktop.git
cd turing-screen-desktop
./install.sh
```

The installer will find an existing `turing-smart-screen-python` checkout, or offer
to clone one for you. Nothing is written outside your home directory; `sudo` is used
only if a system package or a group change is needed, and only after asking.

### Options

```
--app-dir DIR    Use an existing turing-smart-screen-python checkout
--clone-to DIR   Where to clone upstream if none is found
--autostart      Start the display at login
--rebuild-venv   Recreate the Python virtualenv
-y, --yes        Accept the safe default for every prompt
```

## Requirements

Only for the installer script — the AppImage needs none of this.

- Linux with a freedesktop-compatible menu (GNOME, KDE, XFCE, Cinnamon…)
- Python 3.9–3.14
- venv, tkinter and git — the installer offers to fetch these for you
- `zenity` (optional) for the theme picker
- Membership of the `dialout` group for USB serial access

The installer detects your package manager (**apt**, **dnf**, **pacman**,
**zypper** or **apk**) and offers to install what is missing. To do it yourself
first:

| Distro | Command |
|---|---|
| Debian / Ubuntu / Mint / Pop!_OS | `sudo apt install python3-venv python3-tk git zenity` |
| Fedora / RHEL / Rocky | `sudo dnf install python3-tkinter git zenity` |
| Arch / Manjaro / EndeavourOS | `sudo pacman -S python tk git zenity` |
| openSUSE | `sudo zypper install python3 python3-tk git zenity` |
| Alpine | `sudo apk add python3 python3-tkinter git zenity` |

Then add yourself to the serial group (log out and back in afterwards):

```bash
sudo usermod -aG dialout "$USER"     # dialout on most distros, uucp on Arch
```

## Uninstall

```bash
./uninstall.sh              # remove the launchers
./uninstall.sh --purge-app  # also delete the app folder, config and themes
```

Your `config.yaml` and edited themes are never touched unless you ask for `--purge-app`.

## Troubleshooting

**The screen isn't found.** You need to be in `dialout` and to have logged out and
back in since being added:

```bash
groups | tr ' ' '\n' | grep dialout   # no output means you are not in it
sudo usermod -aG dialout "$USER"      # then log out and back in
```

**Menu entries don't appear.** Some desktops cache aggressively:

```bash
update-desktop-database ~/.local/share/applications
```

Then log out and back in.

**The configuration window won't open.** That is `python3-tk` missing:

```bash
sudo apt-get install python3-tk
./install.sh --rebuild-venv
```

## Credits

- The screen software itself: [mathoudebine/turing-smart-screen-python](https://github.com/mathoudebine/turing-smart-screen-python) (GPL-3.0)
- Menu icon: [Anu Rocks](https://freeicons.io/profile/730) on freeicons.io, CC BY 3.0, shipped inside the upstream repo

This project only installs launchers. It bundles no upstream code.

## License

MIT — see [LICENSE](LICENSE).
