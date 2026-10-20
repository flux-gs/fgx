#!/usr/bin/env python3
"""P3-5 I5: bank-pressure measurement for the text-sharing decision.

For every binary in bin/, parse the FGX1/FGX2/FGX3 header and report the
whole-bank cost of ONE running instance (user-pool banks only: code segs +
data seg; bank-0 slivers and kernel-heap items are not user-pool).  Then
price the multitasking push's target process mixes against the 22-bank
($0A-$1F, 1.375MB) user pool, and the marginal saving text-sharing would
buy on multi-instance-same-binary workloads.
"""
import os
import struct
import sys
from pathlib import Path

def _pool_banks():
    """The pool's capacity from its one source of truth, rest.user_banks in
    cfg/system.cfg, as genconfig.py writes it into include/config.s
    (CFG_REST_USER_BANKS, which loader.s's BANK_USER_COUNT aliases).
    A literal here drifted 2.5x behind the pool once (22 against 56)."""
    import re
    cfg = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       '..', 'include', 'config.s')
    with open(cfg, errors='ignore') as f:
        m = re.search(r'^CFG_REST_USER_BANKS\s+EQU\s+(\d+)', f.read(), re.M)
    if not m:
        raise SystemExit('bank_pressure: no CFG_REST_USER_BANKS in '
                         'include/config.s -- run tools/ninja/genconfig.py')
    return int(m.group(1))


POOL_BANKS = _pool_banks()

def banks_for(path):
    d = path.read_bytes()
    if len(d) < 16:
        return None
    magic = d[:4]
    if magic in (b'FGX2', b'FGX3'):
        n_segs = d[6]
        sizes = []
        for i in range(n_segs):
            off = 16 + i * 8
            size, bss = struct.unpack_from('<HH', d, off)
            sizes.append(size + bss)
        return {'fmt': magic.decode(), 'banks': n_segs, 'seg_bytes': sizes}
    if magic == b'FGX1':
        return {'fmt': 'FGX1', 'banks': 1, 'seg_bytes': [len(d) - 16]}
    return None

def main(bindir):
    rows = []
    for p in sorted(Path(bindir).glob('*.bin')):
        r = banks_for(p)
        if r:
            rows.append((p.stem, r))
    for name, r in rows:
        used = sum(r['seg_bytes'])
        dead = r['banks'] * 65536 - used
        print(f"{name:14s} {r['fmt']}  banks={r['banks']}  "
              f"used={used:7d}B  bank-dead={dead:7d}B")
    total = sum(r['banks'] for _, r in rows)
    print(f"\n{len(rows)} binaries, {total} banks if ALL ran at once "
          f"(pool={POOL_BANKS})")

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'bin')
