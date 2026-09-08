#!/usr/bin/env python3
"""Add a "Run at startup" checkbox to upstream's configuration window.

Upstream has no autostart option, and a command-line flag is not something a
normal user will find. This inserts a checkbox in the bottom-left of the main
window, wired to a helper script that AppRun generates.

The anchors below are deliberately exact: if upstream moves this code, the
patch fails loudly at build time rather than silently producing an AppImage
with no checkbox.
"""
import sys
from pathlib import Path

HELPERS = '''

# --- turing-screen-desktop: "run at startup" support ------------------------
# TURING_AUTOSTART_HELPER is exported by the AppImage's AppRun. Outside the
# AppImage it is unset and the checkbox is simply not shown.
def _ts_autostart_helper():
    return os.environ.get("TURING_AUTOSTART_HELPER", "")


def _ts_autostart_enabled():
    helper = _ts_autostart_helper()
    if not helper:
        return False
    try:
        out = subprocess.run([helper, "status"], capture_output=True, text=True, timeout=5)
        return "enabled" in out.stdout
    except Exception:
        return False


def _ts_autostart_set(enabled):
    helper = _ts_autostart_helper()
    if not helper:
        return
    try:
        subprocess.run([helper, "on" if enabled else "off"], timeout=10)
    except Exception:
        pass
# ---------------------------------------------------------------------------
'''

WIDGET = '''
        # --- turing-screen-desktop: run at startup -------------------------
        if _ts_autostart_helper():
            self.ts_autostart_var = IntVar(value=1 if _ts_autostart_enabled() else 0)
            self.ts_autostart_cb = ttk.Checkbutton(
                self.window, text="Run at startup",
                variable=self.ts_autostart_var,
                command=lambda: _ts_autostart_set(self.ts_autostart_var.get()))
            self.ts_autostart_cb.place(x=18, y=584)
        # -------------------------------------------------------------------
'''


def patch(path: Path) -> None:
    src = path.read_text(encoding="utf-8")

    # 1. helpers, after the sensors import that ends the import block
    anchor = "from library.sensors.sensors_python import sensors_fans, is_cpu_fan\n"
    if src.count(anchor) != 1:
        sys.exit(f"patch failed: import anchor not found exactly once in {path}")
    src = src.replace(anchor, anchor + HELPERS, 1)

    # 2. taller window so the checkbox has somewhere to live
    anchor = 'self.window.geometry("820x580")'
    if src.count(anchor) != 1:
        sys.exit(f"patch failed: window geometry anchor not found exactly once in {path}")
    src = src.replace(anchor, 'self.window.geometry("820x620")', 1)

    # 3. the checkbox itself, right after the last button in the bottom row
    anchor = '        self.save_run_btn.place(x=640, y=520, height=50, width=130)\n'
    if src.count(anchor) != 1:
        sys.exit(f"patch failed: button-row anchor not found exactly once in {path}")
    src = src.replace(anchor, anchor + WIDGET, 1)

    path.write_text(src, encoding="utf-8")
    print(f"patched {path}: added 'Run at startup' checkbox")


if __name__ == "__main__":
    patch(Path(sys.argv[1]))
