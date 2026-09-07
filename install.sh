#!/usr/bin/env bash
# turing-screen-desktop - desktop integration for mathoudebine/turing-smart-screen-python
#
# Installs launchers so the Turing smart screen config, theme editor and display
# program can be started from your applications menu, on any Linux desktop.
# Everything goes in your home directory; no root needed except for system packages.

set -euo pipefail

UPSTREAM_URL="https://github.com/mathoudebine/turing-smart-screen-python.git"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL_DIR="$SELF_DIR/share"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_DIR="$HOME/.local/bin"
APPS_DIR="$DATA_HOME/applications"
ICONS_DIR="$DATA_HOME/icons/hicolor"
AUTOSTART_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"

APP_DIR=""
CLONE_TO="$HOME/turing-smart-screen-python"
DO_AUTOSTART=0
REBUILD_VENV=0
ASSUME_YES=0

if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; N=$'\033[0m'
else B=""; G=""; Y=""; R=""; N=""; fi
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$1"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$1"; }
err()  { printf '  %s✗%s %s\n' "$R" "$N" "$1" >&2; }
step() { printf '\n%s%s%s\n' "$B" "$1" "$N"; }
die()  { err "$1"; exit 1; }

usage() {
    cat <<USAGE
${B}turing-screen-desktop installer${N}

  ./install.sh [options]

Options:
  --app-dir DIR    Use an existing turing-smart-screen-python checkout at DIR
  --clone-to DIR   Where to clone upstream if not found (default: $CLONE_TO)
  --autostart      Also start the display automatically at login
  --rebuild-venv   Delete and recreate the Python virtualenv
  -y, --yes        Don't prompt; accept the safe default for every question
  -h, --help       Show this help

With no options it finds an existing checkout or clones one, sets up the
virtualenv, and installs three launchers into your applications menu.
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --app-dir)      APP_DIR="${2:?--app-dir needs a path}"; shift 2 ;;
        --clone-to)     CLONE_TO="${2:?--clone-to needs a path}"; shift 2 ;;
        --autostart)    DO_AUTOSTART=1; shift ;;
        --rebuild-venv) REBUILD_VENV=1; shift ;;
        -y|--yes)       ASSUME_YES=1; shift ;;
        -h|--help)      usage; exit 0 ;;
        *)              err "Unknown option: $1"; usage; exit 2 ;;
    esac
done

ask() { # ask "question" -> 0 for yes
    [ "$ASSUME_YES" = 1 ] && return 0
    [ -t 0 ] || return 1
    local reply; read -r -p "  $1 [Y/n] " reply
    [[ -z "$reply" || "$reply" =~ ^[Yy] ]]
}

# ---------------------------------------------------------------- checks
step "Checking prerequisites"

command -v python3 >/dev/null || die "python3 not found. Install Python 3.9-3.14 first."
PYV=$(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])')
PYOK=$(python3 -c 'import sys;v=sys.version_info[:2];print(1 if (3,9)<=v<=(3,14) else 0)')
[ "$PYOK" = 1 ] || die "Python $PYV found, but this app supports 3.9-3.14 only."
ok "Python $PYV"

MISSING_PKGS=()
python3 -m venv --help >/dev/null 2>&1 || MISSING_PKGS+=("python3-venv")
python3 -c 'import tkinter' 2>/dev/null || MISSING_PKGS+=("python3-tk")
command -v git >/dev/null || MISSING_PKGS+=("git")

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    warn "Missing system packages: ${MISSING_PKGS[*]}"
    if command -v apt-get >/dev/null; then
        if ask "Install them with sudo apt-get?"; then
            sudo apt-get update -qq && sudo apt-get install -y "${MISSING_PKGS[@]}"
            ok "System packages installed"
        else
            die "Cannot continue without: ${MISSING_PKGS[*]}"
        fi
    else
        die "Install these with your package manager, then re-run: ${MISSING_PKGS[*]}"
    fi
else
    ok "python3-venv, tkinter, git"
fi

if command -v zenity >/dev/null; then
    ok "zenity (theme picker)"
else
    warn "zenity not found - the theme editor will just open the active theme."
    if command -v apt-get >/dev/null && ask "Install zenity for the theme picker?"; then
        sudo apt-get install -y zenity && ok "zenity installed"
    fi
fi

# ---------------------------------------------------------------- locate app
step "Locating turing-smart-screen-python"

is_app() { [ -f "$1/main.py" ] && [ -f "$1/configure.py" ] && [ -d "$1/res/themes" ]; }

if [ -n "$APP_DIR" ]; then
    APP_DIR="$(cd "$APP_DIR" 2>/dev/null && pwd)" || die "--app-dir does not exist"
    is_app "$APP_DIR" || die "$APP_DIR is not a turing-smart-screen-python checkout"
    ok "Using $APP_DIR"
else
    for cand in "$HOME/turing-smart-screen-python" "$DATA_HOME/turing-smart-screen-python" \
                "$SELF_DIR/turing-smart-screen-python" "$PWD/turing-smart-screen-python" "$PWD"; do
        if is_app "$cand"; then APP_DIR="$(cd "$cand" && pwd)"; break; fi
    done
    if [ -n "$APP_DIR" ]; then
        ok "Found $APP_DIR"
    else
        warn "No existing checkout found."
        ask "Clone it to $CLONE_TO? (~1 GB)" || die "Nothing to install against. Use --app-dir."
        git clone --depth 1 "$UPSTREAM_URL" "$CLONE_TO"
        APP_DIR="$(cd "$CLONE_TO" && pwd)"
        is_app "$APP_DIR" || die "Clone finished but $APP_DIR looks wrong"
        ok "Cloned to $APP_DIR"
    fi
fi

# ---------------------------------------------------------------- venv
step "Setting up the Python environment"

VENV="$APP_DIR/venv"
if [ "$REBUILD_VENV" = 1 ] && [ -d "$VENV" ]; then rm -rf "$VENV"; ok "Removed old virtualenv"; fi

if [ -x "$VENV/bin/python" ]; then
    ok "Virtualenv already present"
else
    python3 -m venv "$VENV"
    ok "Created $VENV"
fi

"$VENV/bin/python" -m pip install --quiet --upgrade pip
printf '  ... installing dependencies (this can take a few minutes)\n'
"$VENV/bin/python" -m pip install --quiet -r "$APP_DIR/requirements.txt"
"$VENV/bin/python" -c 'import serial, yaml, PIL, psutil, tkinter' \
    || die "Dependencies installed but a core import failed"
ok "Dependencies installed and verified"

# ---------------------------------------------------------------- serial access
step "Checking serial port access"

SERIAL_GROUP=""
if getent group dialout >/dev/null; then
    SERIAL_GROUP="dialout"
elif getent group uucp >/dev/null; then
    SERIAL_GROUP="uucp"
fi

if [ -z "$SERIAL_GROUP" ]; then
    warn "No dialout/uucp group on this system - check your distro's serial permissions."
elif id -nG | tr ' ' '\n' | grep -qx "$SERIAL_GROUP"; then
    ok "You are in the '$SERIAL_GROUP' group"
else
    warn "You are NOT in '$SERIAL_GROUP'. The screen will not be reachable over USB."
    if ask "Add $USER to '$SERIAL_GROUP' with sudo?"; then
        sudo usermod -aG "$SERIAL_GROUP" "$USER" \
            && warn "Added. You must LOG OUT and back in for this to take effect."
    else
        warn "Skipped. Run later: sudo usermod -aG $SERIAL_GROUP $USER"
    fi
fi

DEVS=$(find /dev -maxdepth 1 \( -name 'ttyACM*' -o -name 'ttyUSB*' \) -printf '%f ' 2>/dev/null || true)
if [ -n "$DEVS" ]; then
    ok "Serial devices present: $DEVS"
else
    warn "No serial device detected - plug the screen in before running Configuration."
fi

# ---------------------------------------------------------------- install files
step "Installing launchers"

mkdir -p "$BIN_DIR" "$APPS_DIR"

render() { sed -e "s|@APP_DIR@|$APP_DIR|g" -e "s|@BIN_DIR@|$BIN_DIR|g" "$1" > "$2"; }

for name in turing-config turing-theme-editor turing-display; do
    render "$TPL_DIR/$name.in" "$BIN_DIR/$name"
    chmod +x "$BIN_DIR/$name"
    ok "$BIN_DIR/$name"
done

for name in turing-screen-config turing-screen-theme-editor turing-screen-display; do
    render "$TPL_DIR/$name.desktop.in" "$APPS_DIR/$name.desktop"
    chmod +x "$APPS_DIR/$name.desktop"
    ok "$APPS_DIR/$name.desktop"
done

# icon shipped inside the upstream repo
ICON_SRC="$APP_DIR/res/icons/monitor-icon-17865"
if [ -d "$ICON_SRC" ]; then
    for s in 24 32 48 64 128; do
        if [ -f "$ICON_SRC/$s.png" ]; then
            mkdir -p "$ICONS_DIR/${s}x${s}/apps"
            cp "$ICON_SRC/$s.png" "$ICONS_DIR/${s}x${s}/apps/turing-smart-screen.png"
        fi
    done
    ok "Icon installed (CC-BY, Anu Rocks / freeicons.io)"
else
    warn "Upstream icon folder not found; menu entries will use a generic icon."
fi

if command -v update-desktop-database >/dev/null; then update-desktop-database "$APPS_DIR" 2>/dev/null || true; fi
if command -v gtk-update-icon-cache >/dev/null; then gtk-update-icon-cache -f -t "$ICONS_DIR" >/dev/null 2>&1 || true; fi
ok "Desktop and icon caches refreshed"

# ---------------------------------------------------------------- autostart
if [ "$DO_AUTOSTART" = 1 ] || { [ "$DO_AUTOSTART" = 0 ] && ask "Start the display automatically at login?"; }; then
    mkdir -p "$AUTOSTART_DIR"
    cat > "$AUTOSTART_DIR/turing-screen-display.desktop" <<AUTO
[Desktop Entry]
Type=Application
Name=Turing Screen Display
Comment=Start the Turing smart screen at login
Exec=$BIN_DIR/turing-display
Icon=turing-smart-screen
Terminal=false
X-GNOME-Autostart-enabled=true
AUTO
    ok "Autostart enabled ($AUTOSTART_DIR/turing-screen-display.desktop)"
    # A hand-rolled autostart from before this package would double-launch the display.
    for legacy in "$AUTOSTART_DIR"/*.desktop; do
        [ -e "$legacy" ] || continue
        case "$legacy" in *turing-screen-display.desktop) continue ;; esac
        if grep -qiE "turing|RunTuringScreen" "$legacy" 2>/dev/null; then
            warn "Another Turing autostart exists: $(basename "$legacy")"
            if ask "Remove it so the display doesn't start twice?"; then
                rm -f "$legacy"; ok "removed $(basename "$legacy")"
            fi
        fi
    done
else
    printf '  autostart skipped - re-run with --autostart to enable it later\n'
fi

# ---------------------------------------------------------------- done
step "Done"
cat <<DONE
  App:        $APP_DIR
  Launchers:  Turing Screen Configuration / Turing Theme Editor / Turing Screen Display
              (search your menu for "turing")
  Terminal:   turing-config | turing-theme-editor [theme] | turing-display

  Next: open ${B}Turing Screen Configuration${N} to pick your display model and theme.
DONE

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) warn "$BIN_DIR is not on your PATH - menu entries still work, terminal commands won't." ;;
esac
[ ${#MISSING_PKGS[@]} -gt 0 ] && warn "If you were just added to a group, log out and back in."
exit 0
