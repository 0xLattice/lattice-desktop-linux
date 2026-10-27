# Lattice Desktop for Linux

A full Lattice node and the Lattice Wallet in one Linux app, as a `.deb` and an
AppImage.

This repository is the Linux packaging of
[lattice-desktop](https://github.com/0xLattice/lattice-desktop). The app itself
(the wallet, the node screens, the shell that runs the node) is that
repository, pinned here as the submodule `vendor/lattice-desktop`, and is the
same code on every platform. What is here is only what differs on Linux:

- how the node binaries are built (`scripts/build-node-binaries.sh`),
- how the app is packaged (`tauri.linux.conf.json`, `scripts/build-app.sh`),
- and the checks that the result works on Linux (`scripts/test.sh`, CI).

What the app does is described in
[lattice-desktop's README](https://github.com/0xLattice/lattice-desktop#readme).
On Linux:

- The app's data is in `~/.local/share/Lattice` (or `$XDG_DATA_HOME/Lattice`):
  the node's host root in `host/`, the wallet's vault in `wallet/`.
- The node binaries are installed in the package's own directory
  (`/usr/lib/Lattice/bin`), not on the `PATH`, so they neither replace nor are
  replaced by a `lattice` the machine already has.
- Mining searches on the graphics chip through OpenCL (AMD, Intel, NVIDIA),
  or on the processor. The app offers the graphics chip when the worker finds
  a hash on it, which needs the system's OpenCL loader (`ocl-icd-libopencl1`
  on Debian and Ubuntu, which the `.deb` recommends) and the OpenCL package
  of the graphics driver: for example `nvidia-opencl-icd` or the driver's own
  installer for NVIDIA, `intel-opencl-icd` for Intel, `mesa-opencl-icd` or
  the vendor's driver for AMD. `clinfo` lists what the machine has. Without
  them the app offers the processor only.

## Build

On Linux, with Docker, in the image the node itself is built in:

```sh
git clone --recurse-submodules https://github.com/0xLattice/lattice-desktop-linux.git
cd lattice-desktop-linux
docker run --rm -it -v "$PWD":/work -w /work swift:6.1-jammy bash -c '
  git config --global --add safe.directory "*" &&
  scripts/install-build-dependencies.sh &&
  scripts/build-node-binaries.sh &&
  scripts/build-app.sh'
```

The packages are written to `dist/`. Without Docker, the same three scripts
run on Ubuntu 22.04 or later with a Swift 6.1 toolchain installed.

- `scripts/build-node-binaries.sh` builds `lattice`, `lattice-node`,
  `lattice-mining-coordinator` and `lattice-miner` from
  [lattice-node](https://github.com/0xLattice/lattice-node) at the commit in
  `vendor/lattice-desktop/NODE_COMMIT`, with the node's own release build. The
  Swift runtime is linked in; they need only glibc and SQLite from the host.
  It also builds the GPU mining worker from
  [lattice-miner-gpu](https://github.com/0xLattice/lattice-miner-gpu) at the
  commit in `vendor/lattice-desktop/MINER_GPU_COMMIT`, with its OpenCL
  backend.
- `scripts/build-app.sh` builds the shared app with `tauri.linux.conf.json`
  laid over its configuration.

The packages are built on Ubuntu 22.04, so they need glibc 2.35 or later and
WebKitGTK 4.1 (Ubuntu 22.04, Debian 12, Fedora 36 and later).

## Tests

`scripts/test.sh` runs the shared app's tests against the node binaries built
here: its unit tests, the shell's tests, and the headless end-to-end tests,
which drive the app's page against a real node on throwaway storage with no
peers. The mining test searches on the graphics chip where the GPU worker can
use one, and on the processor where it cannot.

`scripts/test-gpu-mining.sh <directory of binaries>` is the mining test with
the graphics chip required: it fails unless the GPU worker searches and the
app mines with it. CI runs it on Ubuntu 24.04 against the installed `.deb`.
A runner has no graphics chip, so CI sets `LATTICE_MINER_OPENCL_DEVICES=all`,
which lets the worker use PoCL (OpenCL on the processor): the same worker,
kernel and mining loop, on a different device.

`scripts/test.sh --package` then installs the `.deb` and launches the
installed app on a virtual display, checking that the app itself brought its
node up through the packaged CLI. It installs a package, so run it in a
container; CI does.

`scripts/test-ui.sh` drives the installed app in its own window through
WebDriver, with real clicks and keys and nothing standing in for the shell or
the node: making a wallet, the node the app starts, sending, mining, a
transfer seen through to a confirmation, locking, node settings, a relaunch,
and the common mistakes on the way (bad passwords, a bad address or amount,
more than the balance, mining with the node stopped, bad ports). CI runs it
on Ubuntu 24.04 against the installed `.deb`.

## Updating

To take a newer app or node, move the submodule:

```sh
git -C vendor/lattice-desktop fetch && git -C vendor/lattice-desktop checkout <commit>
git add vendor/lattice-desktop
```

The node commit follows the app: it is `NODE_COMMIT` in the submodule.
