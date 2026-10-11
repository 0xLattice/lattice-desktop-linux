#!/usr/bin/env bash
# Everything the build needs on top of the swift:6.1-jammy image (the node's
# own build image): the libraries Tauri links, a Rust toolchain, Node.js, a
# virtual display for launching the packaged app in a test, and PoCL, an
# OpenCL implementation that runs on the processor, for testing GPU mining on
# a machine with no graphics chip.
#
# Usage (as root, inside the container): scripts/install-build-dependencies.sh
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  build-essential ca-certificates curl file git jq xz-utils \
  libssl-dev libsqlite3-dev libwebkit2gtk-4.1-dev libxdo-dev \
  libayatana-appindicator3-dev librsvg2-dev \
  xvfb xauth xdg-utils dbus-x11 \
  ocl-icd-libopencl1 pocl-opencl-icd

node_version=24.9.0
case "$(uname -m)" in
  x86_64) node_arch=x64 ;;
  aarch64) node_arch=arm64 ;;
  *) echo "unsupported machine: $(uname -m)" >&2; exit 1 ;;
esac
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL "https://nodejs.org/dist/v${node_version}/node-v${node_version}-linux-${node_arch}.tar.xz" \
    | tar -xJ -C /usr/local --strip-components=1
fi

if ! command -v cargo >/dev/null 2>&1 && [ ! -x "$HOME/.cargo/bin/cargo" ]; then
  curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
fi
