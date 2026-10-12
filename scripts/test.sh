#!/usr/bin/env bash
# The shared app's tests on Linux, against the node binaries in build/bin: the
# unit tests, the shell's tests, and the headless end-to-end tests (a real
# node on throwaway storage with no peers).
#
# The mining test searches on the graphics chip when the GPU worker can use
# one here, and on the processor otherwise; scripts/test-gpu-mining.sh is the
# test that requires the graphics chip.
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
LATTICE_NODE_BIN="$here/build/bin" LATTICE_GPU_MINER="$here/build/bin/lattice-miner-gpu" npm test
# The shell is built as it is packaged here: with this repository's configuration over the shared one.
TAURI_CONFIG="$(cat "$here/tauri.linux.conf.json")" cargo test --manifest-path src-tauri/Cargo.toml

if [ "${1:-}" = "--package" ]; then
  version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$app/src-tauri/tauri.conf.json")"
  test "$(dpkg-deb -f "$here/dist/Lattice_${version}_amd64.deb" Version)" = "$version"
  test -s "$here/dist/Lattice_${version}_amd64.AppImage"
  apt-get install -y "$here"/dist/*.deb
  LATTICE_APP=/usr/bin/lattice-desktop LATTICE_APP_BINARIES=/usr/lib/Lattice/bin \
    xvfb-run --auto-servernum node --test test/app-bundle.test.ts
fi
