#!/usr/bin/env python3
"""fgx_offrel.py - the same-segment offset relocations of a code segment.

A segment is assembled at $0000, and again at $0101.  Merlin32's listing
carries no relocation information (the Reloc column is empty on every row),
so the difference is the record: every 16-bit word holding an address in
this segment reads exactly $0101 more in the second assembly, and nothing
else changes.  The move is odd on purpose: a lone high byte (#>label) or
low byte (<label) then reads only $0001 more, and a halved or doubled
address something else again, and none of them can be relocated by adding
a page offset, so the link stops.  An odd move also breaks any DS \\
alignment, which then stops the link the same way.

Addresses in OTHER segments are not found here: fgx_ld writes every one of
them itself and records them as it writes them.
"""
import os

import fgx_libso
import fgx_sites

MOVE = 0x101
LIMIT = 0x10000 - MOVE      # a bigger segment would cross the bank at MOVE


def assemble_code(d, name, equs, puts):
    a = fgx_libso.run_merlin(d, fgx_libso.write_link(d, name, 0, equs, puts))
    if a is None or len(a) > LIMIT:
        return a, None
    sd = os.path.join(d, "move")
    os.makedirs(sd, exist_ok=True)
    rel = [p if os.path.isabs(p) else os.path.join("..", p) for p in puts]
    b = fgx_libso.run_merlin(sd, fgx_libso.write_link(sd, name, MOVE, equs, rel))
    return a, [off for off, _v in fgx_sites.diff_sites(b, a, MOVE)]
