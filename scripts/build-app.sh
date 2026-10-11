#!/usr/bin/env bash
# Build the shared app (vendor/lattice-desktop) for Linux and package it as a
# .deb and an AppImage, carrying the node binaries in build/bin.
#
# Usage: scripts/build-app.sh
#   Run scripts/build-node-binaries.sh first.
#   Output: dist/Lattice_<version>_<arch>.deb and .AppImage
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
app="$here/vendor/lattice-desktop"
[ -x "$here/build/bin/lattice-node" ] || { echo "no node binaries: run scripts/build-node-binaries.sh first" >&2; exit 1; }
[ -x "$HOME/.cargo/bin/cargo" ] && export PATH="$HOME/.cargo/bin:$PATH"
# linuxdeploy is itself an AppImage; in a container there is no FUSE to mount it.
export APPIMAGE_EXTRACT_AND_RUN=1

cd "$app"
npm ci
npx tauri build --config "$here/tauri.linux.conf.json"

mkdir -p "$here/dist"
rm -f "$here/dist"/*.deb "$here/dist"/*.AppImage
cp src-tauri/target/release/bundle/deb/*.deb src-tauri/target/release/bundle/appimage/*.AppImage "$here/dist/"
ls -l "$here/dist"
