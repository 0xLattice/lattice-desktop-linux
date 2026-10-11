#!/usr/bin/env bash
# Mining on the graphics chip, required: the GPU worker has to search on this
# machine, and the shared app's mining test has to mine with it through a real
# node (throwaway storage, no peers).
#
# Usage: scripts/test-gpu-mining.sh [directory of binaries]
#   The directory holds the node binaries and lattice-miner-gpu: build/bin by
#   default, /usr/lib/Lattice/bin for the installed package.
#   On a machine with no graphics chip, LATTICE_MINER_OPENCL_DEVICES=all lets
#   the worker use an OpenCL device that is not one, such as PoCL.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
bin="$(cd "${1:-$here/build/bin}" && pwd)"
worker="$bin/lattice-miner-gpu"

"$worker" --work-id probe --prefix-hex 00 --start-nonce 0 --count 1024 \
  --target ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff | grep -q '"status":"found"' \
  || { echo "the GPU worker cannot search on this machine" >&2; exit 1; }

cd "$here/vendor/lattice-desktop"
[ -d node_modules ] || npm ci
log="$(mktemp)"
LATTICE_NODE_BIN="$bin" LATTICE_GPU_MINER="$worker" node --test test/e2e-mining.test.ts | tee "$log"
grep -q "mining on the graphics chip" "$log" || { echo "the app did not mine on the graphics chip" >&2; exit 1; }
