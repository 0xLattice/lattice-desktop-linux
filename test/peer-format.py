#!/usr/bin/env python3
"""Read-only CLI compatibility checks on three disposable topology copies.
Neither CLI starts a node, opens a wallet, or reads an existing user root.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

new, old = map(str, map(Path.resolve, map(Path, sys.argv[1:3])))
with tempfile.TemporaryDirectory(prefix='lattice-peer-format-') as scratch:
    scratch = Path(scratch)
    initial = {'listen': 49151, 'rpc': 49152, 'peers': []}
    original = (json.dumps(initial, sort_keys=True) + '\n').encode()
    baseline_digest = hashlib.sha256(original).hexdigest()
    roots = {name: scratch / name for name in ['legacy', 'upgraded', 'rollback']}
    for root in roots.values():
        root.mkdir()
        (root / 'lattice.json').write_bytes(original)
    def status(cli, root):
        return subprocess.run([cli, 'status', '--root', str(root)], capture_output=True, text=True, timeout=30)
    for cli in [old, new]:
        result = status(cli, roots['legacy'])
        assert result.returncode == 0, 'legacy no-peer configuration must load'
    upgraded = {**initial, 'hostedChains': ['Nexus/releasecheck'], 'peers': {'Nexus': [], 'Nexus/releasecheck': []}}
    new_config = (json.dumps(upgraded, sort_keys=True) + '\n').encode()
    (roots['upgraded'] / 'lattice.json').write_bytes(new_config)
    assert status(new, roots['upgraded']).returncode == 0, 'new CLI accepts per-chain peers'
    assert status(old, roots['upgraded']).returncode != 0, 'old CLI must not silently discard per-chain settings'
    # A rollback uses an untouched pre-upgrade copy, not a destructive conversion
    # of real user data. This says nothing about arbitrary store downgrades.
    assert status(old, roots['rollback']).returncode == 0, 'old CLI accepts the preserved configuration'
    for name in ['legacy', 'rollback']:
        assert hashlib.sha256((roots[name] / 'lattice.json').read_bytes()).hexdigest() == baseline_digest
    assert (roots['upgraded'] / 'lattice.json').read_bytes() == new_config
    print('Peer-format fixture passed: legacy loads in both; new map loads only in new CLI; untouched rollback copy loads in old CLI. No node or wallet was started.')
