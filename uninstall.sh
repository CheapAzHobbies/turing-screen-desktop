#!/usr/bin/env bash
# turing-screen-desktop - remove the launchers installed by install.sh
# By default this removes ONLY the desktop integration. The upstream app folder
# (and your config.yaml and themes) is left alone unless you pass --purge-app.

set -euo pipefail

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_DIR="$HOME/.local/bin"
APPS_DIR="$DATA_HOME/applications"
ICONS_DIR="$DATA_HOME/icons/hicolor"
AUTOSTART_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
PURGE_APP=0
ASSUME_YES=0

if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; N=$'\033[0m'
else B=""; G=""; Y=""; N=""; fi
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$1"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$1"; }
step() { printf '\n%s%s%s\n' "$B" "$1" "$N"; }

while [ $# -gt 0 ]; do
    case "$1" in
        --purge-app) PURGE_APP=1; shift ;;
        -y|--yes)    ASSUME_YES=1; shift ;;
        -h|--help)   echo "Usage: ./uninstall.sh [--purge-app] [-y]"; exit 0 ;;
        *)           echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

step "Removing launchers"
for f in "$BIN_DIR/turing-config" "$BIN_DIR/turing-theme-editor" "$BIN_DIR/turing-display"; do
    [ -e "$f" ] && { rm -f "$f"; ok "removed $f"; }
done
for f in "$APPS_DIR/turing-screen-config.desktop" \
         "$APPS_DIR/turing-screen-theme-editor.desktop" \
         "$APPS_DIR/turing-screen-display.desktop"; do
    [ -e "$f" ] && { rm -f "$f"; ok "removed $f"; }
done
[ -e "$AUTOSTART_DIR/turing-screen-display.desktop" ] && {
    rm -f "$AUTOSTART_DIR/turing-screen-display.desktop"; ok "removed autostart entry"; }
for s in 24 32 48 64 128; do
    f="$ICONS_DIR/${s}x${s}/apps/turing-smart-screen.png"
    [ -e "$f" ] && { rm -f "$f"; ok "removed ${s}px icon"; }
done

if command -v update-desktop-database >/dev/null; then update-desktop-database "$APPS_DIR" 2>/dev/null || true; fi
if command -v gtk-update-icon-cache >/dev/null; then gtk-update-icon-cache -f -t "$ICONS_DIR" >/dev/null 2>&1 || true; fi
ok "caches refreshed"

if [ "$PURGE_APP" = 1 ]; then
    step "Removing the app folder"
    APP=""
    for cand in "$HOME/turing-smart-screen-python" "$DATA_HOME/turing-smart-screen-python"; do
        [ -f "$cand/main.py" ] && { APP="$cand"; break; }
    done
    if [ -z "$APP" ]; then
        warn "No app folder found to remove."
    else
        warn "This deletes $APP including config.yaml and any themes you edited."
        if [ "$ASSUME_YES" = 1 ] || { [ -t 0 ] && read -r -p "  Type DELETE to confirm: " r && [ "$r" = DELETE ]; }; then
            rm -rf "$APP"; ok "removed $APP"
        else
            warn "Skipped."
        fi
    fi
else
    printf '\n  App folder and settings left in place. Use --purge-app to remove them too.\n'
fi

step "Done"
exit 0
