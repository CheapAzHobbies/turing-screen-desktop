#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034,SC2030,SC2031
# SC2016/SC2034: assertions are single-quoted on purpose - check() defers them
#   to eval so they run after the step under test, and $out is consumed there.
# SC2030/SC2031: each run_app call is deliberately isolated in its own subshell;
#   the env changes are meant to be local to it.
# Regression tests for share/AppRun.
#
# These build fake "mounted AppImage" trees and stub the bundled interpreter, so
# the whole thing runs headless with no hardware, no real Python deps and no
# network. Every test here corresponds to a way this has broken, or could.

set -uo pipefail


ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPRUN="$ROOT/share/AppRun"
HOME_REAL="$HOME"
# Snapshot, so we assert the SUITE changed nothing rather than assuming the
# developer's machine started clean.
REAL_AUTOSTART="$HOME/.config/autostart/turing-smart-screen.desktop"
REAL_AUTOSTART_BEFORE=absent; [ -f "$REAL_AUTOSTART" ] && REAL_AUTOSTART_BEFORE=present
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
if [ -t 1 ]; then G=$'\033[32m'; R=$'\033[31m'; N=$'\033[0m'; else G=""; R=""; N=""; fi
ok()   { pass=$((pass+1)); printf '  %s✓%s %s\n' "$G" "$N" "$1"; }
bad()  { fail=$((fail+1)); printf '  %s✗%s %s\n' "$R" "$N" "$1"; [ -n "${2:-}" ] && printf '      %s\n' "$2"; }
check(){ if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

# Build a fake extracted image at $1 with bundled version $2.
make_image() {
    local dir="$1" version="${2:-3.10.0}"
    mkdir -p "$dir/opt/turing/library" "$dir/opt/turing/res"/{fonts,backgrounds,icons,docs} \
             "$dir/opt/turing/res/themes"/{ThemeOne,ThemeTwo} "$dir/usr/bin" "$dir/opt/deps"
    echo "$version" > "$dir/opt/VERSION"
    printf '#!/usr/bin/env python\nprint("main")\n'      > "$dir/opt/turing/main.py"
    printf '#!/usr/bin/env python\nprint("configure")\n' > "$dir/opt/turing/configure.py"
    printf '#!/usr/bin/env python\nprint("editor")\n'    > "$dir/opt/turing/theme-editor.py"
    printf 'x = 1\n' > "$dir/opt/turing/library/config.py"
    printf 'config:\n  THEME: ThemeOne\n' > "$dir/opt/turing/config.yaml"
    printf 'default\n' > "$dir/opt/turing/res/themes/default.yaml"
    printf 'one\n' > "$dir/opt/turing/res/themes/ThemeOne/theme.yaml"
    printf 'two\n' > "$dir/opt/turing/res/themes/ThemeTwo/theme.yaml"
    printf 'font\n' > "$dir/opt/turing/res/fonts/f.ttf"
    # Stub interpreter: records how it was invoked instead of running Python.
    cat > "$dir/usr/bin/python3" <<'STUB'
#!/bin/sh
echo "PYTHON_CALLED: $*" >> "${STUB_LOG:-/dev/null}"
echo "PYTHONPATH_WAS: ${PYTHONPATH:-EMPTY}" >> "${STUB_LOG:-/dev/null}"
exit 0
STUB
    chmod +x "$dir/usr/bin/python3"
    install -m755 "$APPRUN" "$dir/AppRun"
}

run_app() { # run_app <image> [args...]
    ( export XDG_DATA_HOME="$TMP/data" XDG_CONFIG_HOME="$TMP/config" HOME="$TMP/home" STUB_LOG="$TMP/calls.log"
      PATH="$TMP/nozenity:$PATH" "$1/AppRun" "${@:2}" ) 2>&1
}

# Two distinct situations, easy to conflate:
#   cancelling  - zenity IS present and the user dismisses the dialog -> do nothing
#   absent      - zenity is NOT installed at all -> fall back to the active theme
# "cancel" is a stub that exits non-zero; "absent" is a PATH with no zenity on it.
mkdir -p "$TMP/nozenity" "$TMP/bin" "$TMP/home"
printf '#!/bin/sh\nexit 1\n' > "$TMP/nozenity/zenity"; chmod +x "$TMP/nozenity/zenity"
for t in bash sh sed find sort grep head cat mkdir rm cp ln chmod readlink dirname \
         basename pgrep flock tr sleep kill env printf touch install; do
    src="$(command -v "$t" 2>/dev/null)" && ln -sf "$src" "$TMP/bin/$t"
done

run_app_nozenity() { # same as run_app but with zenity genuinely unavailable
    ( export XDG_DATA_HOME="$TMP/data" XDG_CONFIG_HOME="$TMP/config" HOME="$TMP/home" STUB_LOG="$TMP/calls.log"
      PATH="$TMP/bin" "$1/AppRun" "${@:2}" ) 2>&1
}

WORK="$TMP/data/turing-screen/app"

echo "AppRun regression tests"
echo

# ---------------------------------------------------------------- first run
make_image "$TMP/mnt-a"
run_app "$TMP/mnt-a" --where >/dev/null
check "first run builds the working tree"        '[ -d "$WORK" ]'
check "config.yaml is created"                   '[ -f "$WORK/config.yaml" ]'
check "config.yaml is writable"                  '[ -w "$WORK/config.yaml" ]'
check "library/ is a real dir, not a symlink"    '[ -d "$WORK/library" ] && [ ! -L "$WORK/library" ]' \
      "config.py resolves __file__; a symlink would lead back into the read-only mount"
check "res/fonts is a symlink (assets not copied)" '[ -L "$WORK/res/fonts" ]'
check "theme symlink resolves"                   '[ -e "$WORK/res/themes/ThemeOne" ]'

# ------------------------------------------------- the v1.2.1 regression
# An AppImage mounts somewhere new every launch; links must be re-pointed.
make_image "$TMP/mnt-b"
run_app "$TMP/mnt-b" --where >/dev/null
check "assets re-point after the mount path changes" \
      '[ "$(readlink "$WORK/res/fonts")" = "$TMP/mnt-b/opt/turing/res/fonts" ]' \
      "this is the bug that made every launch after the first fail"
check "theme link resolves from the new mount"   '[ -e "$WORK/res/themes/ThemeOne" ]'
check "fonts link actually resolves"             '[ -e "$WORK/res/fonts" ]'

# ---------------------------------------------------------------- settings
echo 'config:
  THEME: MyCustomChoice' > "$WORK/config.yaml"
run_app "$TMP/mnt-a" --where >/dev/null
check "user settings survive a relaunch" \
      'grep -q MyCustomChoice "$WORK/config.yaml"' \
      "config.yaml must never be overwritten once it exists"

# ------------------------------------------------------- version upgrade
make_image "$TMP/mnt-c" "3.11.0"
run_app "$TMP/mnt-c" --where >/dev/null
check "code refreshes on a version bump"   '[ "$(cat "$WORK/.built-from")" = "3.11.0" ]'
check "settings survive a version bump"    'grep -q MyCustomChoice "$WORK/config.yaml"' \
      "an upgrade must not reset the user's configuration"

# ------------------------------------------------------ edited themes kept
rm -f "$WORK/res/themes/ThemeTwo"
mkdir -p "$WORK/res/themes/ThemeTwo"
echo "edited by hand" > "$WORK/res/themes/ThemeTwo/theme.yaml"
run_app "$TMP/mnt-b" --where >/dev/null
check "an edited theme is not clobbered by a relaunch" \
      'grep -q "edited by hand" "$WORK/res/themes/ThemeTwo/theme.yaml"' \
      "materialised themes are real dirs and must survive re-linking"
check "an edited theme stays a real directory" '[ ! -L "$WORK/res/themes/ThemeTwo" ]'

# --------------------------------------------------------------- shebangs
check "copied scripts point at the bundled interpreter" \
      'head -1 "$WORK/configure.py" | grep -q "$WORK/.python"' \
      "upstream ships #!/usr/bin/env python, which usually does not exist"
check "the interpreter shim exists and is executable" '[ -x "$WORK/.python" ]'
check "the shim targets the current mount" \
      'grep -q "$TMP/mnt-b/usr/bin/python3" "$WORK/.python"'
check "the shim exports PYTHONPATH for bundled deps" \
      'grep -q "PYTHONPATH" "$WORK/.python"'
check "tray Configure can actually execute configure.py" \
      '"$WORK/configure.py" >/dev/null 2>&1' \
      "main.py launches this file directly from the tray menu"

# ------------------------------------------------------------ entry points
: > "$TMP/calls.log"
run_app "$TMP/mnt-b" --config >/dev/null
check "--config runs configure.py" 'grep -q "PYTHON_CALLED: configure.py" "$TMP/calls.log"'

: > "$TMP/calls.log"
run_app "$TMP/mnt-b" --display >/dev/null
check "--display runs main.py"     'grep -q "PYTHON_CALLED: main.py" "$TMP/calls.log"'

out="$(run_app "$TMP/mnt-b" --help)"
check "--help prints usage"        'echo "$out" | grep -q -- "--theme-editor"'
out="$(run_app "$TMP/mnt-b" --where)"
check "--where reports the workdir" 'echo "$out" | grep -q "workdir:"'

# --------------------------------------------------- zenity behaviour
# Cancelling the picker must do nothing at all.
: > "$TMP/calls.log"
run_app "$TMP/mnt-b" --theme-editor >/dev/null
check "cancelling the theme picker launches nothing" \
      '! grep -q "PYTHON_CALLED" "$TMP/calls.log"'

# With zenity genuinely missing, fall back to the configured theme rather than
# silently doing nothing.
: > "$TMP/calls.log"
run_app_nozenity "$TMP/mnt-b" --theme-editor >/dev/null
check "theme editor falls back to the active theme when zenity is absent" \
      'grep -q "PYTHON_CALLED: theme-editor.py" "$TMP/calls.log"' \
      "must not silently do nothing on a system without zenity"

# A no-argument launch opens the configuration window - the one thing clicking
# the app should ever do.
: > "$TMP/calls.log"
run_app "$TMP/mnt-b" >/dev/null
check "clicking the app opens the configuration window" \
      'grep -q "PYTHON_CALLED: configure.py" "$TMP/calls.log"' \
      "must not start the display or show a menu"

: > "$TMP/calls.log"
run_app_nozenity "$TMP/mnt-b" >/dev/null
check "clicking the app works without zenity too" \
      'grep -q "PYTHON_CALLED: configure.py" "$TMP/calls.log"'

# An explicit theme name skips the picker entirely.
: > "$TMP/calls.log"
run_app "$TMP/mnt-b" --theme-editor ThemeOne >/dev/null
check "an explicit theme name bypasses the picker" \
      'grep -q "PYTHON_CALLED: theme-editor.py ThemeOne" "$TMP/calls.log"'

check "editing a theme makes it a real writable directory" \
      '[ ! -L "$WORK/res/themes/ThemeOne" ] && [ -w "$WORK/res/themes/ThemeOne" ]' \
      "themes live read-only in the image until edited"

# ------------------------------------------------------------- robustness
run_app "$TMP/mnt-b" --stop >/dev/null 2>&1
check "--stop is safe when nothing is running" '[ $? -eq 0 ]'

mkdir -p "$TMP/data/turing-screen/app/res/themes/Weird Name With Spaces"
run_app "$TMP/mnt-b" --where >/dev/null
check "a theme name with spaces does not break relinking" '[ -d "$WORK" ]'

rm -rf "$WORK"
run_app "$TMP/mnt-b" --where >/dev/null
check "recovers if the working tree is deleted" '[ -f "$WORK/config.yaml" ]'

chmod -w "$WORK/config.yaml" 2>/dev/null
run_app "$TMP/mnt-b" --where >/dev/null 2>&1
check "survives a read-only config.yaml" '[ -d "$WORK" ]'
chmod +w "$WORK/config.yaml" 2>/dev/null

# ------------------------------------------------------- single instance
check "only one display can run at a time" \
      'grep -q "flock -w 5" "$APPRUN" && grep -q "display.lock" "$APPRUN"'
check "--display stops any running display first" \
      'grep -q "stop_display" "$APPRUN"' \
      "Save and run must apply new settings, not silently do nothing"
check "--display waits for the port to be released" \
      'grep -q "flock -w 5" "$APPRUN"'
check "the shim relaunches the AppImage for the display" \
      'grep -q -- "--display" "$WORK/.python"' \
      "otherwise the mount vanishes when configure.py exits, killing the display"
check "the shim relaunches the AppImage for the theme editor" \
      'grep -q -- "--theme-editor" "$WORK/.python"'
check "the shim can find the image if it was renamed" \
      'grep -q "Turing_Smart_Screen\*.AppImage" "$WORK/.python"'
check "the shim still runs other scripts in the current mount" \
      'grep -q "exec \"" "$WORK/.python"'

out="$(run_app "$TMP/mnt-b" --help)"
check "help documents the single-window guarantee" \
      'echo "$out" | grep -qi "only one"'

# ------------------------ the wizard launches main.py by ABSOLUTE path
# configure.py does Popen([str(main_file)]) with a full path, so detection that
# insists on the bare string "main.py" never sees the running display. That made
# "Save and run" silently do nothing.
check "detection accepts an absolute path to main.py" \
      'grep -q "main.py|\*/main.py" "$APPRUN"' \
      "the wizard passes /full/path/main.py, not main.py"

# Prove it end to end: a stand-in started the way configure.py starts main.py
# (cwd = working dir, argv[0] a python, argv[1] an ABSOLUTE path) must be
# stopped when a new display starts, while a bystander must survive.
cp "$WORK/main.py" "$TMP/main.py.stub"
printf 'import time\ntime.sleep(30)\n' > "$WORK/main.py"
( cd "$WORK" && exec python3 "$WORK/main.py" ) &
wizard_style=$!
( cd "$WORK" && exec -a "bash -c edit main.py" sleep 30 ) &
bystander=$!
sleep 1
cp "$TMP/main.py.stub" "$WORK/main.py"
run_app "$TMP/mnt-b" --display >/dev/null 2>&1 || true
sleep 1
check "a display started by absolute path IS stopped by a new start" \
      '! kill -0 '"$wizard_style"' 2>/dev/null' \
      "this is the exact case Save and run hits"
# The shim is literally named ".python" and passes an absolute main.py path.
# A substring match on "python" made it recognise itself and commit suicide.
( cd "$WORK" && exec -a "$WORK/.python" sleep 30 ) &
shim_lookalike=$!
sleep 1
run_app "$TMP/mnt-b" --display >/dev/null 2>&1 || true
sleep 1
check "the .python shim is never mistaken for the display" \
      'kill -0 '"$shim_lookalike"' 2>/dev/null' \
      "a substring match on python made the launcher kill itself"
kill "$shim_lookalike" 2>/dev/null || true

check "a bystander mentioning main.py is NOT stopped" \
      'kill -0 '"$bystander"' 2>/dev/null' \
      "matching command lines loosely once killed a real terminal"
kill "$wizard_style" "$bystander" 2>/dev/null || true


# ------------------------------------- busy messages name the thing
check "the display never shows a busy message - it restarts instead" \
      '! grep -q "screen display is already running" "$APPRUN"' \
      "refusing would make Save and run appear to do nothing"
check "the busy message for settings names it" \
      'grep -q "settings window is already open" "$APPRUN"'
check "the busy message for the theme editor names it" \
      'grep -q "theme editor is already open" "$APPRUN"'

# ------------------- every entry point must pass the bundled deps
# A bare exec that forgot PYTHONPATH made the display die with
# "Import error: No module named 'babel'" right after loading the theme.
for mode in --config --display; do
    : > "$TMP/calls.log"
    run_app "$TMP/mnt-b" "$mode" >/dev/null 2>&1
    check "$mode passes PYTHONPATH to the bundled interpreter" \
          'grep -q "PYTHONPATH_WAS:.*opt/deps" "$TMP/calls.log"' \
          "without it none of the bundled dependencies import"
done
: > "$TMP/calls.log"
run_app_nozenity "$TMP/mnt-b" --theme-editor >/dev/null 2>&1
check "--theme-editor passes PYTHONPATH too" \
      'grep -q "PYTHONPATH_WAS:.*opt/deps" "$TMP/calls.log"'

# ------------------------------------------- checkbox helper
check "the autostart helper is generated" '[ -x "$WORK/.autostart-helper" ]'
out="$("$WORK/.autostart-helper" status)"
check "helper reports enabled, since autostart is the default" 'echo "$out" | grep -q enabled'
HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/config" "$WORK/.autostart-helper" on >/dev/null
check "helper can enable autostart" \
      '[ -f "$TMP/config/autostart/turing-smart-screen.desktop" ]'
check "helper writes a resilient launcher" \
      'grep -q "Turing_Smart_Screen\*.AppImage" "$TMP/home/.local/bin/turing-smart-screen"'
HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/config" "$WORK/.autostart-helper" off >/dev/null
check "helper can disable autostart" \
      '[ ! -f "$TMP/config/autostart/turing-smart-screen.desktop" ]'

# --------------------------------------- autostart is on out of the box
rm -rf "${TMP:?}/data" "${TMP:?}/config" "${TMP:?}/home"; mkdir -p "$TMP/home"
run_app "$TMP/mnt-b" --where >/dev/null 2>&1
check "autostart is enabled on a fresh install, with no prompt" \
      '[ -f "$TMP/config/autostart/turing-smart-screen.desktop" ]' \
      "anyone installing this wants the screen running at startup"
check "no question dialog is used for it" \
      '! grep -q "zenity --question" "$APPRUN"'

# Unticking the checkbox must stick: the default is applied once only.
HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/config" "$WORK/.autostart-helper" off >/dev/null
run_app "$TMP/mnt-b" --where >/dev/null 2>&1
check "turning it off is not silently undone on the next launch" \
      '[ ! -f "$TMP/config/autostart/turing-smart-screen.desktop" ]' \
      "the default must be applied exactly once, ever"

# ------------------------------------------------------------- autostart
out="$(run_app "$TMP/mnt-b" --autostart)"
check "autostart is off by default" 'echo "$out" | grep -q "disabled"'

run_app "$TMP/mnt-b" --autostart on >/dev/null 2>&1
check "autostart on writes a desktop entry" \
      '[ -f "$TMP/config/autostart/turing-smart-screen.desktop" ]'
check "the autostart launcher bypasses the AppImageLauncher dialog" \
      'grep -q "APPIMAGELAUNCHER_DISABLE" "$TMP/home/.local/bin/turing-smart-screen"' \
      "at login nobody can click Integrate and run"
check "autostart on writes a resilient launcher" \
      'grep -q "Turing_Smart_Screen\*.AppImage" "$TMP/home/.local/bin/turing-smart-screen"' \
      "must still find the image after AppImageLauncher renames it on update"
out="$(run_app "$TMP/mnt-b" --autostart)"
check "autostart status reports enabled" 'echo "$out" | grep -q "enabled"'
run_app "$TMP/mnt-b" --autostart off >/dev/null 2>&1
check "autostart off removes the entry" '[ ! -f "$TMP/config/autostart/turing-smart-screen.desktop" ]'
check "autostart off removes the launcher" '[ ! -f "$TMP/home/.local/bin/turing-smart-screen" ]'
real_after=absent; [ -f "$REAL_AUTOSTART" ] && real_after=present
check "the suite leaves the real HOME exactly as it found it" \
      '[ "$real_after" = "$REAL_AUTOSTART_BEFORE" ]' \
      "a test must never write into the developer's home"

echo
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
