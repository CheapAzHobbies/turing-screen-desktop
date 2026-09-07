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

- Linux with a freedesktop-compatible menu (GNOME, KDE, XFCE, Cinnamon…)
- Python 3.9–3.14
- `python3-venv`, `python3-tk`, `git` — the installer offers to apt-install these
- `zenity` (optional) for the theme picker
- Membership of the `dialout` group for USB serial access

The installer checks all of these and tells you exactly what is missing.

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
