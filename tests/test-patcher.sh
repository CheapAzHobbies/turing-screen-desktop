#!/usr/bin/env bash
# Verifies the configure.py patch applies cleanly to the pinned upstream release
# and produces valid Python. If upstream moves any anchor, this fails loudly
# rather than shipping an AppImage with missing buttons.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF="${UPSTREAM_REF:-3.10.0}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

curl -fsSL "https://raw.githubusercontent.com/mathoudebine/turing-smart-screen-python/${REF}/configure.py" \
    -o "$TMP/configure.py"
python3 "$ROOT/share/patch-configure-autostart.py" "$TMP/configure.py"
python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$TMP/configure.py"

fail=0
need() { grep -q "$1" "$TMP/configure.py" || { echo "  MISSING: $2"; fail=1; }; }
need 'text="Run at startup"'      '"Run at startup" checkbox'
need 'ts_close_btn'               'Close button'
need 'text="Apply to screen"'     'renamed apply button'
need '820x620'                    'enlarged window'

# The window must NOT be destroyed by the apply button any more.
if sed -n '/def on_saverun_click/,/def on_brightness_change/p' "$TMP/configure.py" | grep -q 'window.destroy'; then
    echo "  STILL CLOSES: apply button destroys the window"; fail=1
fi

[ "$fail" -eq 0 ] && echo "  patch applies cleanly to upstream $REF"
exit "$fail"
