#!/usr/bin/env bash
# Build the node binaries the app carries (`lattice`, `lattice-node`,
# `lattice-mining-coordinator`, `lattice-miner`) from 0xLattice/lattice-node at
# the commit the shared app pins (vendor/lattice-desktop/NODE_COMMIT), with the
# node's own release build: optimized, the Swift runtime linked in, so they run
# on a plain Linux host with glibc and SQLite. With them, the GPU mining worker
# (`lattice-miner-gpu`) from 0xLattice/lattice-miner-gpu at the commit the
# shared app pins (vendor/lattice-desktop/MINER_GPU_COMMIT), built to search
# through OpenCL.
#
# Usage: scripts/build-node-binaries.sh
#   Needs a Swift 6.1 toolchain (the swift:6.1-jammy image has one) and Rust.
#   Output: build/bin/, with the commits in build/bin/COMMIT and
#   build/bin/MINER_GPU_COMMIT.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
commit="$(tr -d '[:space:]' < "$here/vendor/lattice-desktop/NODE_COMMIT")"
src="$here/.build-node"

if [ ! -d "$src/.git" ]; then
  git clone --quiet https://github.com/0xLattice/lattice-node.git "$src"
fi
git -C "$src" fetch --quiet origin "$commit"
git -C "$src" checkout --quiet --detach "$commit"
if [ -n "$(git -C "$src" status --porcelain --untracked-files=no)" ]; then
  echo "lattice-node checkout has local changes; refusing to bundle it" >&2
  exit 1
fi

(cd "$src" && scripts/build-release-binaries.sh)

out="$here/build/bin"
rm -rf "$out"
mkdir -p "$out"
for name in lattice lattice-node lattice-mining-coordinator lattice-miner; do
  install -m 0755 "$src/.build/release-binaries/$name" "$out/$name"
done
printf '%s\n' "$commit" > "$out/COMMIT"

# The GPU worker. OpenCL is loaded when it runs, so the build needs no OpenCL
# library and the worker starts (and says so) on a machine that has none.
[ -x "$HOME/.cargo/bin/cargo" ] && export PATH="$HOME/.cargo/bin:$PATH"
gpu_commit="$(tr -d '[:space:]' < "$here/vendor/lattice-desktop/MINER_GPU_COMMIT")"
gpu_src="$here/.build-miner-gpu"
if [ ! -d "$gpu_src/.git" ]; then
  git clone --quiet https://github.com/0xLattice/lattice-miner-gpu.git "$gpu_src"
fi
git -C "$gpu_src" fetch --quiet origin "$gpu_commit"
git -C "$gpu_src" checkout --quiet --detach "$gpu_commit"
if [ -n "$(git -C "$gpu_src" status --porcelain --untracked-files=no)" ]; then
  echo "lattice-miner-gpu checkout has local changes; refusing to bundle it" >&2
  exit 1
fi
# The target directory is named, so a CARGO_TARGET_DIR set outside cannot leave
# an older build to be picked up below.
(cd "$gpu_src" && cargo build --release --locked --features opencl --target-dir "$gpu_src/target")
install -m 0755 "$gpu_src/target/release/lattice-miner-gpu" "$out/lattice-miner-gpu"
printf '%s\n' "$gpu_commit" > "$out/MINER_GPU_COMMIT"
echo "staged the node binaries at $commit and the GPU worker at $gpu_commit in $out"

python3 "$here/scripts/collect-notices.py" node "$out/NODE-NOTICES.txt"
