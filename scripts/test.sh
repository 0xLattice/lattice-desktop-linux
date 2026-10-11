#!/usr/bin/env bash
# The shared app's tests on Linux, against the node binaries in build/bin: the
# unit tests, the shell's tests, and the headless end-to-end tests (a real
# node on throwaway storage with no peers).
#
# With --package it also installs the .deb in dist/ and launches the installed
# app on a virtual display, checking that it starts its own node. That changes
# the system it runs on, so it is for a container or a CI runner.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
app="$here/vendor/lattice-desktop"
[ -x "$HOME/.cargo/bin/cargo" ] && export PATH="$HOME/.cargo/bin:$PATH"

cd "$app"
[ -d node_modules ] || npm ci
npm run typecheck
LATTICE_NODE_BIN="$here/build/bin" npm test
# The shell is built as it is packaged here: with this repository's configuration over the shared one.
TAURI_CONFIG="$(cat "$here/tauri.linux.conf.json")" cargo test --manifest-path src-tauri/Cargo.toml

if [ "${1:-}" = "--package" ]; then
  apt-get install -y "$here"/dist/*.deb
  LATTICE_APP=/usr/bin/lattice-desktop LATTICE_APP_BINARIES=/usr/lib/Lattice/bin \
    xvfb-run --auto-servernum node --test test/app-bundle.test.ts
fi
