#!/usr/bin/env bash
# The installed app in its own window, driven through WebDriver with real
# clicks and keys: the shared app's UI test (vendor/lattice-desktop/test/ui),
# with nothing standing in for the shell or the node. The node it starts has
# no peers and lives in a throwaway home directory.
#
# Usage: scripts/test-ui.sh [the app's executable] [directory of its binaries]
#   Defaults to the installed package: /usr/bin/lattice-desktop and
#   /usr/lib/Lattice/bin.
#   Needs Node.js 24, tauri-driver (`cargo install tauri-driver --locked`),
#   WebKitWebDriver (the webkit2gtk-driver package) and, without a display,
#   xvfb.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
[ -x "$HOME/.cargo/bin/tauri-driver" ] && export PATH="$HOME/.cargo/bin:$PATH"
export LATTICE_UI_APP="${1:-/usr/bin/lattice-desktop}"
export LATTICE_APP_BINARIES="${2:-/usr/lib/Lattice/bin}"

test="${LATTICE_UI_TEST_FILE:-$here/vendor/lattice-desktop/test/ui/desktop.ui.test.mjs}"
if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
  node --test "$test"
else
  xvfb-run --auto-servernum node --test "$test"
fi
