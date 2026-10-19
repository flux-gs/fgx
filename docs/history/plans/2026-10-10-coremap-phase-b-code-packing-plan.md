# Coremap phase B, steps B1-B3: code packing -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A program's code segments are placed by size inside shared banks instead of one whole bank each, so the idle system's eleven text banks (about 180 KB of code) fit in about three.

**Architecture:** The toolchain emits a second relocation kind, a 16-bit offset patch, found for same-segment addresses by assembling each code segment a second time at `$0101` and classifying the difference, and known to `fgx_ld` for every cross-segment address it patches itself.  The kernel's 56-bank pool becomes a 2.11BSD resource map (`subr_rmap.c`) in 256-byte pages, with whole-bank requests unchanged on top of it.  The loader places a flagged code segment of a newly claimed text at a page offset, and the text table records each segment's pages.

**Tech Stack:** Python 3 (`toolchain/src/ld/`), Merlin32 65816 (`src/kernel/bank.s`, `src/kernel/far/loader.s`, `src/kernel/tty/text.s`, `src/kernel/far_shims.s`), ninja, headless MAME via `tools/mame_test/run.py`.

**Spec:** `docs/history/plans/2026-10-03-coremap-shared-text-design.md`, sections 3, 6.1, 6.2, 8, 9 (steps B1, B2, B3).  2.11BSD: `vendor/2.11BSD/usr/sys/sys/subr_rmap.c` (`malloc`, `mfree`), `h/map.h`, `sys/vm_text.c` (`xuncore`, `xalloc`).

## Global Constraints

- Branch `feat/coremap` (off main d036aa414).  No push and no MR until the maintainer asks; pushes need `ALLOW_FEAT_PUSH=1`.  Each commit ends with the session's attribution trailers; commit bodies are the changelog (informational, no names or process).  Announce every `ninja` rebuild and every MAME run before it starts.
- ASCII only; comments describe the current state only.  Merlin32 has no operator precedence (braces, not parens; `ERR` takes neither); explicit `MX` at every label reached in another width (`check_mx`).
- Toolchain-first: a gap in fcc or libc is fixed there, never worked around.
- A kernel behaviour with a BSD counterpart: read it in `vendor/2.11BSD/usr/sys/` and name file and function in the commit; quote the deciding line.
- 65816 assembly is written by the main agent, not delegated.
- Byte budgets on main d036aa414 (`python3 tools/check_kernel_ceiling.py`): core 1,394 bytes free, far 800, tty 1,052.  Every task that adds kernel code records the new free counts in its commit body.  Ceilings for this plan: core may fall to 700, far to 500, tty to 500; a task that would cross one stops and rules.
- KTTY slots: main uses up to 61.  This plan takes **62** onward.
- Patch-site tables (`far_patchsites.s`, `far/core_patchsites.s`, `tty_patchsites.s`, `tty/core_patchsites.s`, `fnptr_patchsites.s`) are committed and only `--check`ed by the build.  Regenerate with `python3 tools/gen_far_bankpatch.py <listing> <out> core|far|core-tty|tty` (and `gen_mod_bankpatch.py`); a row whose marker was deleted must be dropped by hand first, or the kernel will not assemble.  `tools/gen_kernel_exports.py` lists every `_FarSh_*` export (two tables: :77 and :192).
- Never `git checkout` a tracked-but-generated file (`kernel_exports.s`, the patch-site tables); regenerate it.
- Every MAME verdict is a fresh run (`--fresh`; "(1 cached)" did not run).  A typed command is at most 255 characters; a longer probe is a `sh /testdata/<name>` script (a new testdata file needs `python3 tools/ninja/gen.py` before ninja).
- Tests are the tail: one discriminating probe per mechanism, each shown RED before the change it proves.  New MAME tests are probes, not `GATE_TESTS` (the gate has a seconds ratchet).  New host tests are wired into `toolchain/Makefile`'s `test-libs` target, which the gate runs (`test_d1_gate.py` is the precedent of a test that landed unwired; do not repeat it).
- Before the last commit, run every manifest: `python3 -c "import os;print('\n'.join(sorted(f[:-5] for f in os.listdir('tools/mame_test/tests') if f.endswith('.json'))))" | xargs python3 tools/mame_test/run.py --fresh`, and `tools/gate.sh`.

## Measured before planning (main d036aa414, 2026-10-10)

- Idle prompt (`idlemem`, 20 s after boot): 46 of 56 pool banks in use.  Programs running: init, inetd, 3 x getty, 2 x sh, syslogd, update, cron.  Their text banks: init 2 (15.5 + 29.6 KB), getty 2 (7.4 + 22.2), sh 3 (64.0 + 4.4 + 7.3), inetd 1 (10.9), syslogd 1 (22.3), update 1 (1.2), cron 1 (46.6): **11 banks for about 180 KB**, about 3 banks if packed.  libfgx.so's 3.7 KB code holds a 12th bank (libraries are not in this plan; Ruling 7).
- All 354 code segments on the volume: median 4.9 KB; 242 under 16 KB; 292 under 32 KB.
- The two-origin diff, measured by reassembling `seg0` at `ORG $0B0100` and comparing high bytes: cron 236 sites in 44,262 bytes, syslogd 88 / 20,674, ls 92 / 20,268, init 73 / 15,903, inetd 63 / 9,996, getty 50 / 7,568, update 15 / 800.  **Zero bytes unclassified** in all seven.  sh's 64.0 KB `seg0` does not assemble at `$0100` (it would cross the bank), as expected.  One extra assembly of cron's `seg0` takes 0.36 s.
- **A move of `$0100` cannot refuse a lone high-byte operand** (spec 6.2 says it does).  `LDA #>label` assembled at `$0000` and `$0100`: the immediate byte reads one more and the opcode before it is unchanged, which is exactly what an address word looks like.  Moving by `$0101` separates them: an address word reads exactly `$0101` more, a lone high or low byte `$0001` more.  Measured with Merlin32 on a test segment: at `$0101`, `fgx_sites.diff_sites(b, a, 0x101)` refuses `LDA #>there` and, without it, finds all five sites (`JSR`, `JMP`, `LDA #`, `PEA`, `DA`).
- The kernel's map in C (`subr_rmap.c`'s `malloc`/`mfree` with the bank rule, compiled `--kernel-bank`) is 1,818 bytes of code; the tty bank has 1,052 free.  The map is written in assembly.  The draft found apple/fgx#524 (fcc rejects `q[i]` on a struct pointer used as a whole struct), filed, not blocking.

## Rulings this plan makes against the spec (each lands in the spec in Task 9)

1. **Same-segment sites come from ONE extra assembly per code segment, all at `$0101`; cross-segment sites come from `fgx_ld`, which already writes every one of them** (spec 6.2 said move one segment at a time).  Every cross-segment address in an FGX binary is written by `fgx_ld` (`FGX2_IMPORT_JSL`, `FGX2_LONG_PTR`, `FGX2_FARCALL`, `FGX2_FARJUMP`, `FGX2_ABS_OFFSET`) or by `fgx_dyn`'s table writer, never by Merlin, because each segment is assembled alone against the other segments' layouts as EQUs; so moving a segment's own `ORG` can only move its own addresses, and `fgx_ld` knows the target of each cross site exactly.  The one-at-a-time proof the spec wanted ("operands into other segments do not move") holds by construction.  Cost if wrong: a cross site Merlin resolves would be missed; Task 8's `codepack` (a packed dynamic and static program run in MAME) and Task 2's test catch it.  **The move is `$0101`, not `$0100`** (see Measured): only an odd move refuses a high-byte or low-byte operand, which a page offset could not relocate.  An odd move also breaks any `DS \` alignment; fcc emits none and no linked library file uses `_ALIGN`/`_PAGE`, and if one ever does the two assemblies differ unclassifiably and the link stops, loudly.
2. **The flag is per segment, not per header**: segment-table byte 5 (`FGX2_SEG_RESERVED`) bit 0, `FGX2_SEGF_PLACE`, says "every absolute reference to this segment has an offset relocation".  A segment over `$FEFF` bytes cannot assemble at `$0101` and is never flagged; it loads at `$0000` of its own bank as today.
3. **The offset relocation is the existing 4-byte entry with bit 7 of the target byte set** (`FGX2_RELOC_OFFSET` = `$80`): add the target segment's load offset to the 16-bit word at `src:offset`.  A kernel without this plan refuses such an image with ENOEXEC by the apple/fgx#522 check (target >= segment count), so no ABI stamp bump is needed.
4. **The map lives in the core bank** (spec 6.1 named no bank).  `Bank_Init` runs at `main.s:259` and the first `Bank_Alloc` at `main.s:911`; the tty bank is bound at `main.s:2252`.  Map pieces coalesce freely, as `mfree` does; the bank rule is enforced in allocation: a request is placed at the first address in a piece from which it does not cross a bank boundary, splitting the piece when that address is not the piece's start.
5. **Memory Manager grants stay outside the map** (spec 6.1 said a grant enters it).  `Bank_Alloc`'s dry-pool grant and `Bank_Free`'s dispose-by-table-lookup are unchanged; a sub-bank request that finds no room falls back to a whole bank.  Cost: a granted bank holds one segment, as today.
6. **Only a newly claimed text's segments are placed.**  The text entry is claimed before the segments load (`KTTY_TEXT_CLAIM`, replacing `KTTY_TEXT_REG`) and filled after (`KTTY_TEXT_FILL`), so placed pages always belong to an entry and never to a process: `TCB_BankList` and exit's bank-by-bank free never see a page.  A load with no claim (uncacheable file, a file changed in the last second, a table of 16 running texts) loads into whole banks as today.
7. **Libraries are not placed in this plan**: `fgx_libso` links get no offset relocations, and `ld_load` keeps whole banks.  Cost: about one bank at idle (libfgx).
8. **Reclaim keeps freeing one least-recently-used unused text per rescan until the allocation succeeds** (`Bank_Alloc` already loops this way).  2.11BSD's `xuncore(size)` stops once it has freed one text at least `size` clicks big, a proxy for "the retry can succeed" that holds when any free piece serves; with packed banks a whole-bank request needs a whole bank empty, so the retry itself is the test.
9. **No per-bank allocation counts and no "prefer the text whose bank it would empty"** (spec 6.1).  Measure the reclaim churn in Task 8 first.

## Review Focus

1. **Two different texts share a bank and one is reclaimed** -- the other keeps running and its next exec still hits.  Test: `codepack` (Task 8) kills one packed program, forces a reclaim, and checks the other is still running and a fresh exec works.
2. **An exec that fails after some segments were placed** (a truncated image) -- its pages go back.  Test: `coremap` (Task 6) runs the truncated image 50 times; a leak of one page per failure would cost 50, and Task 8 records the free total beside Task 6's.
3. **A dynamic program packed at a non-zero offset** -- its binder tables carry the offset and it binds and runs.  Test: `codepack` runs `dyntrue` (dynamic) while its text is placed (Task 8).
4. **The pool runs dry with packed banks** -- a whole-bank request frees unused texts until a bank empties, then succeeds.  Test: `textreclaim` and `manyproc`, fresh (Task 8).
5. **A segment that exactly fills its pages, and one over `$FEFF`** -- the first places with its last byte at a page end; the second is unflagged and loads at `$0000`.  Test: `test_offset_relocs.py` cases `fill` and `big` (Task 1, Task 2).

---

### Task 1: The offset-site classifier (B1)

**Files:**
- Create: `toolchain/src/ld/fgx_offrel.py`
- Create: `toolchain/tests/ld/test_offset_relocs.py`
- Modify: `toolchain/Makefile` (`test-libs` target, lines 154-180)

**Interfaces:**
- Consumes: `fgx_libso.write_link(d, name, org, equs, puts, pad=0)` and `fgx_libso.run_merlin(d, link)` (`toolchain/src/ld/fgx_libso.py:281`, `:301`).
- Consumes also: `fgx_sites.diff_sites(a, b, delta)` (`toolchain/src/ld/fgx_sites.py:29`), the differ fgx_dyn already uses for library data sites.
- Produces: `fgx_offrel.MOVE = 0x101`; `fgx_offrel.LIMIT = 0x10000 - 0x101`; `fgx_offrel.assemble_code(d, name, equs, puts) -> (bytes, list[int] | None)` (the segment at `$0000` and its same-segment sites, or `None` when the segment is over `LIMIT`).

- [ ] **Step 1: Write the failing test**

`toolchain/tests/ld/test_offset_relocs.py` (hermetic: assembles small segments in a temp dir with `merlin32`, as `test_farjump.py` does):

```python
#!/usr/bin/env python3
"""Offset relocations: the two-origin classifier finds every same-segment
address and refuses any byte it cannot classify."""
import os, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "src", "ld"))
import fgx_offrel  # noqa: E402


def seg(body, fill=0):
    d = tempfile.mkdtemp()
    with open(os.path.join(d, "b.s"), "w") as f:
        f.write(body)
        if fill:
            f.write("                DS     %d\n" % fill)
    return fgx_offrel.assemble_code(d, "s", [], ["b.s"])


def must_die(body):
    try:
        seg(body)
    except SystemExit:
        return
    raise AssertionError("accepted:\n" + body)


# JSR abs, JMP abs, LDA #label (16-bit), PEA label-1, DA label: five sites.
GOOD = """\
                MX     %00
start           JSR    there
                JMP    there
                LDA    #there
                PEA    there-1
there           RTS
tab             DA     start
"""
code, s = seg(GOOD)
assert s == [1, 4, 7, 10, 13], s

# Branches and data-bank operands move nothing.
code, s = seg("loop            BRA    loop\n                LDA    $1234\n")
assert s == [], s

# fill: a segment ending exactly at a page end still classifies.
code, s = seg(GOOD, fill=256 - 15)
assert len(code) == 256 and s == [1, 4, 7, 10, 13], (len(code), s)

# big: over LIMIT is never placed.
code, s = seg("x               RTS\n", fill=fgx_offrel.LIMIT)
assert s is None

# Refused: a high byte alone, a low byte alone, a halved address, a
# doubled one.  The first two are why MOVE is odd.
must_die("x               LDA    #>x\n")
must_die("x               DFB    <x\n")
must_die("x               DA     x/2\n")
must_die("x               DA     x*2\n")
print("test_offset_relocs: ok")
```

- [ ] **Step 2: Run it, RED**

Run: `python3 toolchain/tests/ld/test_offset_relocs.py`
Expected: `ModuleNotFoundError: No module named 'fgx_offrel'`.

- [ ] **Step 3: Write the classifier**

`toolchain/src/ld/fgx_offrel.py`:

```python
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
```

Note for the implementer: `write_link` rewrites an absolute PUT relative to the directory it writes in, and Merlin resolves a relative PUT from where it runs; the `move` directory is one level below `d`, hence the `..` on each relative PUT (generated files such as `seg1_layout.s` and `inits.s` stay in `d`).  `fgx_sites.diff_sites` dies with the offset and both values on anything it cannot classify.

- [ ] **Step 4: Run it, GREEN**

Run: `python3 toolchain/tests/ld/test_offset_relocs.py`
Expected: `test_offset_relocs: ok`.  If the site list for `GOOD` differs, print the listing (`s_Output.txt`) and correct the expected offsets from it, not the classifier.

- [ ] **Step 5: Wire it into `test-libs`**

In `toolchain/Makefile`'s `test-libs` recipe, beside `test_farjump.py`, add:

```make
	$(PYTHON) tests/ld/test_offset_relocs.py
```

Run: `make -C toolchain -s test-libs`
Expected: exit 0, `test_offset_relocs: ok` among the output.

- [ ] **Step 6: Commit**

```bash
git add toolchain/src/ld/fgx_offrel.py toolchain/tests/ld/test_offset_relocs.py toolchain/Makefile
git commit   # "fgx_offrel: a code segment's own addresses, found by assembling it at $0101"
```

---

### Task 2: fgx_ld emits offset relocations and the segment flag (B1)

**Files:**
- Modify: `toolchain/src/ld/fgx_ld.py` (manifest schema docstring :9-38; reloc emission; segment table writer near :1174-1193)
- Modify: `include/loader.s` (:94-136: `FGX2_SEG_RESERVED` becomes `FGX2_SEG_FLAGS`, `FGX2_SEGF_PLACE EQU $01`; `FGX2_RELOC_OFFSET EQU $80`)
- Modify: `toolchain/tests/ld/test_offset_relocs.py`

**Interfaces:**
- Consumes: `fgx_offrel.sites`.
- Produces: manifest segment field `"offsets": [int, ...]` (present = the segment is placeable); output segment-table byte 5 bit 0 set for such a segment; a reloc entry `(src, off, 0x80 | tgt)` for (a) every `offsets` entry of segment `src` (with `tgt = src`) and (b) every 16-bit address fgx_ld writes into any segment whose target segment is placeable.

- [ ] **Step 1: Write the failing test**

Append to `test_offset_relocs.py` a two-code-segment link through `fgx_ld.py` with a manifest: segment 0 `JSL`s segment 2 through `FGX2_IMPORT_JSL`, segment 1 (DATA) holds `FGX2_LONG_PTR` to a segment-0 label, both code segments carry `offsets`.  Assert on the output image (parse with `fgx_libso.file_segments` and the reloc table at the end of the segment data):

```python
# every intra site of seg 0 and seg 2 is a reloc (src, off, 0x80|src);
# the JSL's low word in seg 0 is (0, jsl+1, 0x82); the LONG_PTR's word in
# seg 1 is (1, ptr, 0x80); both code segments' flag byte is 1; seg 1's is 0.
```

Build the manifest exactly as `fgx_static.build` does (`"format": "FGX3"`, `"n_data_segment": 1`, `"segments": [{"bin", "listing", "kind", "bss", "offsets"}]`).

- [ ] **Step 2: Run it, RED**

Run: `python3 toolchain/tests/ld/test_offset_relocs.py`
Expected: an assertion naming the missing offset relocs (fgx_ld ignores `offsets` today).

- [ ] **Step 3: Implement**

In `fgx_ld.py`:
- read `seg.get("offsets")`; set the segment-table entry's byte 5 to `1` when present (it is written `0` today; keep `0` otherwise);
- after the existing relocs are built, append `(i, off, 0x80 | i)` for each `off` in segment `i`'s `offsets`;
- at every place the linker writes a 16-bit target address into segment bytes (the import resolver that patches `LL+HH at addr+1..+2`, the `FGX2_LONG_PTR` / `FGX2_FARCALL` / `FGX2_FARJUMP` / `FGX2_ABS_OFFSET` resolvers), append `(src, addr_of_word, 0x80 | tgt)` when segment `tgt` has `offsets`.  Find them with `grep -n "pack_into\|struct.pack" toolchain/src/ld/fgx_ld.py` and print the count before and after editing;
- `d1_check` must accept the high bit: compare `tgt & 0x7F` against the segment count.
- document both fields in the module docstring.

In `include/loader.s`, rename `FGX2_SEG_RESERVED` (offset 5) to `FGX2_SEG_FLAGS` with its comment, add `FGX2_SEGF_PLACE EQU $01` and `FGX2_RELOC_OFFSET EQU $80` beside the reloc entry EQUs, each with a one-paragraph comment in the file's style.  `grep -rn FGX2_SEG_RESERVED src include tools` first and update every user.

- [ ] **Step 4: Run it, GREEN**

Run: `python3 toolchain/tests/ld/test_offset_relocs.py && make -C toolchain -s test-libs`
Expected: `test_offset_relocs: ok`; `test-libs` exit 0.

- [ ] **Step 5: Commit**

```bash
git add toolchain/src/ld/fgx_ld.py include/loader.s toolchain/tests/ld/test_offset_relocs.py
git commit   # "fgx_ld: offset relocations, and a flag on each segment they cover"
```

---

### Task 3: Every program link finds its sites (B1)

**Files:**
- Modify: `toolchain/src/ld/fgx_static.py` (code segment assembly at :290-366: `seg0_link`, the `extra` segments, the libc banks)
- Modify: `toolchain/src/ld/fgx_dyn.py` (`link_once`'s code segments, :244-302; `with_tables` and the `_dyn_tab` cell, :379-382, :549-551)
- Modify: `toolchain/src/ld/fgx_bind.py` (must carry segment flags and offset relocs through unchanged)
- Modify: `toolchain/tests/ld/test_offset_relocs.py`

**Interfaces:**
- Consumes: `fgx_offrel.assemble_code`, the `offsets` manifest field.
- Produces: every program built by `fgx_static`/`fgx_dyn` whose code segment is at most `LIMIT` ($FEFF) bytes has that segment flagged.  `fgx_dyn` adds `(tseg_cell_seg, cell, 0x80 | i)` for each per-segment `off` cell of the binder table (`t + 4 + 4*i`) whose segment `i` is flagged, and `(0, _dyn_tab, 0x80 | tseg)` for the `_dyn_tab` offset word.

- [ ] **Step 1: Write the failing test**

Add to `test_offset_relocs.py` a check over two real built programs: read `disk_src/sbin/update` (dynamic) and `disk_src/bin/getty` (static), and assert each CODE segment of size <= `LIMIT` has flag byte 1 and at least one `0x80` reloc whose source is that segment.  Skip with a message when `disk_src/` is absent (a toolchain-only checkout).

- [ ] **Step 2: Run it, RED**

Run: `python3 toolchain/tests/ld/test_offset_relocs.py`
Expected: an assertion that `update`'s segment 0 is unflagged.

- [ ] **Step 3: Implement**

- Replace each CODE segment's `fgx_libso.run_merlin(d, fgx_libso.write_link(d, nm, 0, EQUS, puts))` in `fgx_static.py` and `fgx_dyn.py` with `got, offs = fgx_offrel.assemble_code(d, nm, EQUS, puts)`, and put `"offsets": offs` in that segment's manifest entry when `offs is not None`.  Measuring assemblies (`fgx_pack.measure`, `fgx_libso.measure`, the `ovn` probe) stay single: they produce sizes, not output.
- `fgx_dyn`'s shifted link (`sd = .../shift`, :510) is a second full link for the library data sites; give it the plain single assembly (pass a flag down `link_once`), so the moved assembly runs once per segment, not twice.
- `fgx_dyn.with_tables`: emit the offset relocs listed under Produces.  `toolchain/lib/libc_c/ld_bind.c:294` already reads each segment's `off` from these cells and adds it at every patch (`:434`).
- `fgx_bind.py`: confirm it copies the segment table and reloc table byte for byte; if it rebuilds either, carry byte 5 and the `0x80` entries.
- `fgx_libso` (library links) is unchanged (Ruling 7).

- [ ] **Step 4: Rebuild, GREEN**

Announce: "rebuilding with ninja on feat/coremap".
Run: `ninja > /tmp/ninja.out 2>&1; echo rc=$?; python3 toolchain/tests/ld/test_offset_relocs.py; make -C toolchain -s test-libs`
Expected: `rc=0`; `test_offset_relocs: ok`.  Record in the commit body: `fgxfs fsck` "blocks used" before (12,704) and after, and the total `0x80` reloc count over `disk_src/` (a one-off script in the commit message, not a tool).

- [ ] **Step 5: Commit**

```bash
git add toolchain/src/ld/fgx_static.py toolchain/src/ld/fgx_dyn.py toolchain/src/ld/fgx_bind.py toolchain/tests/ld/test_offset_relocs.py
git commit   # "fgx_static, fgx_dyn: every code segment up to $FEFF carries its offset relocations"
```

The tree does not boot after this commit until Task 4 lands (the kernel refuses `0x80` relocs with ENOEXEC).  Tasks 3 and 4 are committed back to back with no MAME run between them.

---

### Task 4: The loader applies offset relocations (B1, kernel)

**Files:**
- Modify: `src/kernel/far/loader.s` (reloc loop :1033-1080; `_BankForSeg`; new `_ldSegPage DS FGX2_MAX_SEGS`, zero in this task)
- Create: `tools/mame_test/fixtures/relocoff.bin` (generator: the script that made `relocseg.bin`, `git log --format=%h -1 -- tools/mame_test/fixtures/relocseg.bin` names its commit)
- Modify: the `relocseg` probe manifest to run `relocoff.bin` as well

**Interfaces:**
- Consumes: `FGX2_RELOC_OFFSET` ($80).
- Produces: `_ldSegPage[seg]` = the page offset (high byte of the load address) of each segment, 0 for every segment until Task 8; an offset reloc adds `_ldSegPage[tgt] << 8` to the word at `src:offset`, skipping the store when the page is 0.

- [ ] **Step 1: The fixture, RED**

Make `relocoff.bin`: a one-code-segment FGX3 image whose single reloc is `(0, 0, $80 | 9)` (an offset reloc naming segment 9).  Expected verdict: ENOEXEC, and the machine keeps running (the shell prints the error; `screen_lacks` "PANIC", "BRK").

Announce the MAME run.  Run: `python3 tools/mame_test/run.py --fresh relocseg`
Expected (after Task 3's build): RED -- every program on the volume now carries `$80` relocs and the shell itself fails to exec (the boot stops).  This is the RED for the whole task.

- [ ] **Step 2: Implement**

In the reloc loop, after the source checks: load the target byte, keep it in a scratch, mask `AND #$7F`, `CMP _ldNSegs / BCS @lf2_relocBad` as now.  If bit 7 was clear, the existing bank-byte store.  If set: `LDA _ldSegPage,X`(target) ; `BEQ @lf2_relocNext` ; otherwise 16-bit `CLC / ADC [_libcTmp2]` with the page in the high byte (`XBA` from an 8-bit page, low byte 0) and `STA [_libcTmp2]`.  Keep the text-hit skip (`_ldTextList,Y` non-zero) unchanged.  The listing's MX at each new label.

Run `python3 tools/check_kernel_ceiling.py` and record the far bank's free bytes.

- [ ] **Step 3: Rebuild and run, GREEN**

Announce the rebuild and MAME runs.
Run: `ninja && python3 tools/mame_test/run.py --fresh relocseg execkind exectrunc smoke`
Expected: all pass; `relocoff` ENOEXEC.

- [ ] **Step 4: Gate**

Run: `tools/gate.sh`
Expected: `GATE GREEN`.

- [ ] **Step 5: Commit**

```bash
git add src/kernel/far/loader.s tools/mame_test/fixtures/relocoff.bin tools/mame_test/tests/relocseg.json src/kernel/*patchsites.s src/kernel/*/*patchsites.s
git commit   # "loader: an offset relocation adds its target segment's page"
```

---

### Task 5: The resource map's reference model (B2)

**Files:**
- Create: `tools/coremap_model.py`

**Interfaces:**
- Produces: `Coremap(first_bank, nbanks, nmap=64)` with `alloc(size) -> addr | 0`, `free(size, addr) -> lost_pages`, `claim(size, addr) -> bool`, `pieces() -> [(size, addr)]`, `free_total() -> int`; `check(pieces, first_bank, nbanks)` raising `AssertionError` on a broken map (unsorted, zero size, overlapping, abutting, outside the pool).  Used by Task 6's probe checker and as the behaviour the assembly must match.

- [ ] **Step 1: Write the model and its self-test**

```python
#!/usr/bin/env python3
"""The kernel's page map (src/kernel/bank.s), modelled.

2.11BSD's resource map (usr/sys/sys/subr_rmap.c, h/map.h): a dense array of
{m_size, m_addr} pieces in address order, first fit, coalescing on return,
size 0 ends it, address 0 is not legal.  A unit is a 256-byte page and an
address is bank << 8 | page.  FGX's rule BSD does not have: no allocation
crosses a bank, so a request is placed at the first address of a piece from
which it fits inside one bank, and the piece splits when that is not its
start.  A request under a bank first looks for room that does not start a
wholly free bank, so whole banks stay whole for data.
"""
import sys

BANK = 256


class Coremap:
    def __init__(self, first, nbanks, nmap=64):
        self.nmap = nmap
        self.m = [[nbanks * BANK, first << 8]]

    def pieces(self):
        return [tuple(p) for p in self.m]

    def free_total(self):
        return sum(s for s, _ in self.m)

    def alloc(self, size):
        assert 0 < size <= BANK
        for strict in (True, False):
            for i, (sz, a) in enumerate(self.m):
                p = a if (a & 0xFF) + size <= BANK else (a | 0xFF) + 1
                if p + size > a + sz:
                    continue
                if strict and size < BANK and p & 0xFF == 0 and a + sz - p >= BANK:
                    continue
                if p != a:
                    if len(self.m) >= self.nmap:
                        continue
                    self.m.insert(i, [p - a, a])
                    i += 1
                    self.m[i] = [sz - (p - a), p]
                    sz = sz - (p - a)
                if sz == size:
                    del self.m[i]
                else:
                    self.m[i] = [sz - size, p + size]
                return p
        return 0

    def free(self, size, addr):
        assert size and addr
        i = 0
        while i < len(self.m) and self.m[i][1] <= addr:
            i += 1
        if i and self.m[i - 1][1] + self.m[i - 1][0] == addr:
            self.m[i - 1][0] += size
            if i < len(self.m) and addr + size == self.m[i][1]:
                self.m[i - 1][0] += self.m[i][0]
                del self.m[i]
            return 0
        if i < len(self.m) and addr + size == self.m[i][1]:
            self.m[i] = [self.m[i][0] + size, addr]
            return 0
        if len(self.m) >= self.nmap:
            return size                 # mfree: "overflow, lost %u clicks"
        self.m.insert(i, [size, addr])
        return 0

    def claim(self, size, addr):
        for i, (sz, a) in enumerate(self.m):
            if a <= addr and addr + size <= a + sz:
                left, right = addr - a, a + sz - (addr + size)
                rows = ([[left, a]] if left else []) + ([[right, addr + size]] if right else [])
                if len(self.m) - 1 + len(rows) > self.nmap:
                    return False
                self.m[i:i + 1] = rows
                return True
        return False


def check(pieces, first, nbanks):
    lo, hi = first << 8, (first + nbanks) << 8
    prev_end = None
    for sz, a in pieces:
        assert sz > 0 and a > 0, (sz, a)
        assert lo <= a and a + sz <= hi, "outside the pool: %#x+%#x" % (a, sz)
        if prev_end is not None:
            assert a > prev_end, "unsorted, overlapping or uncoalesced at %#x" % a
        prev_end = a + sz


def self_test():
    m = Coremap(0x41, 4)                          # banks $41-$44
    assert m.alloc(256) == 0x4100                 # whole bank: lowest
    assert m.alloc(16) == 0x4200                  # no partly used bank yet
    assert m.alloc(256) == 0x4300                 # $42 is partly used: next whole bank
    assert m.alloc(32) == 0x4210                  # packs into the partial bank
    assert m.alloc(250) == 0x4400                 # 250 does not fit $42's 208 left
    m.free(16, 0x4200)
    m.free(32, 0x4210)                            # coalesces with $4230..$42FF
    check(m.pieces(), 0x41, 4)
    assert m.pieces() == [(256, 0x4200), (6, 0x44FA)], m.pieces()
    # A request that would cross a bank is placed at the next bank.
    m2 = Coremap(0x41, 2)
    assert m2.alloc(200) == 0x4100
    assert m2.alloc(100) == 0x4200                # 56 left in $41: does not fit
    assert m2.alloc(56) == 0x41C8
    # claim splits; overflow loses and reports.
    m3 = Coremap(0x41, 3, nmap=2)
    assert m3.claim(256, 0x4200)
    assert m3.pieces() == [(256, 0x4100), (256, 0x4300)]
    assert m3.alloc(1) == 0x4100                  # both banks whole: strict fails, then first fit
    assert m3.free(1, 0x4100) == 0
    assert m3.free(256, 0x4200) == 0              # coalesces all three
    assert m3.pieces() == [(768, 0x4100)]
    print("coremap_model: ok")


if __name__ == "__main__":
    self_test()
```

- [ ] **Step 2: Run it**

Run: `python3 tools/coremap_model.py`
Expected: `coremap_model: ok` (the expected values were traced by hand through the rules in the docstring; an assertion here is a defect in the model or the trace -- fix whichever the docstring's rules say is wrong).

- [ ] **Step 3: Commit**

```bash
git add tools/coremap_model.py
git commit   # "coremap_model: subr_rmap.c's map in pages, with the bank rule"
```

---

### Task 6: The pool becomes the map (B2, kernel)

**Files:**
- Modify: `src/kernel/bank.s` (all of it: `Bank_Init`, `Bank_Alloc`, `Bank_Free`, `Bank_MarkUsed`; new `Rm_Alloc`, `Rm_Free`, `Rm_Claim`)
- Modify: `include/memmap.s:1145-1147` (`BankBitmap DS 7` and `KMem_BankBitmap_canary` become `_coremap DS {NMAP+1}*4` and `KMem_Coremap_canary`)
- Modify: `include/loader.s` (`BANK_BITMAP_BYTES` goes; `NMAP EQU 64`)
- Modify: `src/kernel/main.s:1464` (canary stamp), `tools/check_canaries.py`, `tools/mame_test/tests/smoke.json` (`cn_BankBitmap` regions), `tools/mame_test/probes/bankcount.json`, `tools/mame_test/tests/idlemem.json`, `tools/bank_pressure.py:21-37` (pool size from `BANK_USER_COUNT` in `include/loader.s`)
- Create: `disk_src/testdata/coremap`, `tools/mame_test/tests/coremap.json`, `tools/mame_test/coremap_check.py`

**Interfaces:**
- Consumes: `tools/coremap_model.py` (`check`, and the behaviour).
- Produces (core bank, MX %00, DBR = core): `Rm_Alloc` A = pages (1..256) -> C=1 A = address, C=0 none; `Rm_Free` A = pages, X = address (preserves X/Y); `Rm_Claim` A = pages, X = address -> C=1 claimed.  `Bank_Alloc`/`Bank_Free`/`Bank_MarkUsed` keep their contracts (bank.s:80-88, :196-199, :244-251) exactly: `Bank_Alloc` = `Rm_Alloc(256)`, its reclaim loop and grant fallback unchanged; `Bank_Free` = in-pool `Rm_Free(256, bank<<8)`, else the grant dispose; `Bank_MarkUsed` = `Rm_Claim(256, bank<<8)`.  A free that overflows the map logs `coremap: overflow, lost <n> pages at <addr>` through `Kern_LogStr`.

- [ ] **Step 1: The probe, RED**

`disk_src/testdata/coremap`:

```sh
# Spawn/exit churn, then fifty failed execs of a truncated image.
sh /testdata/textchurn
i=0
while [ $i -lt 50 ]; do /testbin/trunc 2>/dev/null; i=`expr $i + 1`; done
echo CHURNED
```

`coremap.json`: `"command": "sh"`, `"post_commands": ["sleep 20; sh /testdata/coremap"]`, `"post_gap_frames": 1800`, `"exit_on_prompt": false`, `stage_files` the truncated image exactly as `exectrunc.json` stages it (`tools/mame_test/fixtures/trunc.bin` -> `/FGX/testbin/trunc`), `screen_contains` `CHURNED`, and two memory regions: `{"name": "coremap", "symbol": "_coremap", "len": 260}` and `{"name": "first", "symbol": "_kUserFirstBank", "len": 2}`.  `coremap_check.py` parses the dump into pieces up to the size-0 terminator, runs `coremap_model.check(pieces, first, n)` (first bank = `_kUserFirstBank`, dumped as a second region; n = 56), and asserts the free total is at least 10 banks (2,560 pages) -- the idle system leaves about 10 free.  RED today: `_coremap` does not exist (the harness reports an unknown symbol).

Positive control, in the checker's own self-test (`python3 tools/mame_test/coremap_check.py --self-test`): an unsorted dump and an overlapping dump must both fail.

- [ ] **Step 2: Implement the map**

Write `Rm_Alloc`, `Rm_Free`, `Rm_Claim` in `bank.s` from `coremap_model.py`'s `alloc`, `free`, `claim`, line for line, entries `{size, addr}` 4 bytes each, `abs,X` DBR-relative (bank.s's header explains why).  Head the file with the 2.11BSD reference (`subr_rmap.c`'s comment block on the dense array, quoted) and the bank rule.  `Bank_Init` builds the single piece `{count*256, _kUserFirstBank<<8}` where `count` is the claimed pool (`KFGX_REST_COUNT - REST_USER_FIRST_OFF`, at most `BANK_USER_COUNT`, as the bitmap's pre-marking computes today) and stores the terminator.  Delete `BankBit_LUT` and the bitmap code.  Pin the array with `ERR` against `NMAP` the way the bitmap's width was pinned.

Run `python3 tools/check_kernel_ceiling.py`; record core free bytes (ceiling: 700).

- [ ] **Step 3: Update the bitmap's readers**

`smoke.json`, `check_canaries.py`, `main.s` canary stamp: rename to `KMem_Coremap_canary`.  `bankcount.json` and `idlemem.json`: dump `_coremap` instead of `BankBitmap`; `idlemem.json`'s description says "the pool's free pieces".  `bank_pressure.py`: read `BANK_USER_COUNT EQU <n>` from `include/loader.s`.  `grep -rn BankBitmap src include tools` must print nothing afterwards (print the count).

- [ ] **Step 4: Rebuild and run, GREEN**

Announce the rebuild and MAME runs.
Run: `python3 tools/ninja/gen.py >/dev/null && ninja && python3 tools/mame_test/coremap_check.py --self-test && python3 tools/mame_test/run.py --fresh coremap smoke idlemem manyproc textreclaim textchurn textshare`
Expected: all pass.  Record the free total from `coremap`, and idle pool use from `idlemem` (banks in use = 56 - free/256): it must equal 46 (behaviour-neutral).

- [ ] **Step 5: Gate**

Run: `tools/gate.sh`
Expected: `GATE GREEN`.

- [ ] **Step 6: Commit**

```bash
git add src/kernel/bank.s include/memmap.s include/loader.s src/kernel/main.s tools/check_canaries.py tools/mame_test/tests/smoke.json tools/mame_test/probes/bankcount.json tools/mame_test/tests/idlemem.json tools/bank_pressure.py tools/mame_test/tests/coremap.json tools/mame_test/coremap_check.py src/kernel/*patchsites.s src/kernel/*/*patchsites.s
git commit   # "bank: the user pool is a resource map in pages (2.11BSD subr_rmap.c)"
```

---

### Task 7: Text entries hold pages; claim before load (B3, kernel)

**Files:**
- Modify: `src/kernel/tty/text.s` (entry layout :32-40; `_Tx_Off`; `_Tx_Unref`; `_Tx_Reclaim`; `_KTty_TextFind`; `_KTty_TextReg` becomes `_KTty_TextClaim`; new `_KTty_TextFill`)
- Modify: `src/kernel/bank.s` (new `Core_Alloc`, `Core_Free`)
- Modify: `src/kernel/far_shims.s` (new `_FarSh_Core_Alloc`, `_FarSh_Core_Free`; `_FarSh_TextReg` becomes `_FarSh_TextClaim`; new `_FarSh_TextFill`), `tools/gen_kernel_exports.py` (:77-80, :192), `include/ktty.s` (slot 62 `KTTY_TEXT_FILL`; the REG slot renamed `KTTY_TEXT_CLAIM`), the tty slot table

**Interfaces:**
- Consumes: `Rm_Alloc`, `Rm_Free` (Task 6).
- Produces:
  - `Core_Alloc` (core, JSR; `_FarSh_Core_Alloc` by JSL): A = pages 1..255 -> C=1 A = address; C=0 no room after reclaiming every unused text and library (`KTTY_TEXT_RECLAIM`, then `KTTY_LD_RECLAIM`, retrying `Rm_Alloc` after each).  Never asks the Memory Manager.
  - `Core_Free`: A = pages (0 = a whole bank), X = address: pages 0 -> `Bank_Free(X >> 8)`; else `Rm_Free`.  Preserves X/Y.
  - Text entry: `TX_DEV 0`, `TX_INO 2`, `TX_CTIME 4`, `TX_BANKS 8` (8), `TX_PAGE 16` (8: first page per segment), `TX_NPG 24` (8: pages per segment, 0 = whole bank), `TX_COUNT 32`, `TX_STAMP 33`, `TX_SIZE 36`.
  - `KTTY_TEXT_CLAIM`: In A = key offset, X = key bank.  The `TX_YOUNG` test and the slot search (with reclaim) of today's REG; writes the key, zero banks/pages/counts, `x_count` = 1.  Out C=1 + A = index; C=0 (young, or 16 running texts).
  - `KTTY_TEXT_FILL`: In A = index, X = list bank, Y = list offset: 24 bytes (banks 8, pages 8, npg 8), copied into the entry.
  - `KTTY_TEXT_FIND`: copies 16 bytes (banks, then pages) to the caller's list.
  - `_Tx_Unref`: when `x_count` reaches 0 and the entry's eight banks are all 0 (claimed, never filled), the entry is freed (`TX_INO` = 0).
  - `_Tx_Reclaim`: per segment, `Core_Free(TX_NPG, TX_BANKS << 8 | TX_PAGE)` through `_FarSh_Core_Free`.

- [ ] **Step 1: RED**

There is no behaviour change visible yet (the loader still passes whole banks, npg 0).  The RED for this task is the assembler: change `TX_SIZE` and `_Tx_Off` first and run `ninja`; the existing `ERR`s on the table and the loader's 8-byte `_ldTextList` must still assemble, and `textshare`, `textfresh`, `textreclaim`, `textchurn` must still pass after Step 3.  Record the four as the regression set.

- [ ] **Step 2: Implement**

As the Interfaces list says.  `_Tx_Off` computes `(i-1)*36` as `(i-1)*32 + (i-1)*4`.  The loader (far bank) changes in this task only as far as the API: at F6 miss with `_ldTextKeyOk`, call `_FarSh_TextClaim` (A = key offset, X = bank) and keep the index in `_ldTextIdx` with a new flag `_ldTextNew` = 1; at F7.6, call `_FarSh_TextFill` with a 24-byte list built from `_ldTextList`, zero pages and zero npg (whole banks); delete the REG call and its "table full: the banks stay ours" arm, which CLAIM made unreachable (a claim that failed means no text).  `_FreeExtras` already drops the reference; with Step 2's `_Tx_Unref` rule, an unfilled claim frees its entry.  `_ldTextList` grows to 16 bytes (banks, pages) for FIND.

Regenerate the patch-site tables and `kernel_exports.s` as the Global Constraints say.  Record core/far/tty free bytes.

- [ ] **Step 3: Rebuild and run, GREEN**

Announce the rebuild and MAME runs.
Run: `ninja && python3 tools/mame_test/run.py --fresh textshare textfresh textreclaim textchurn manyproc exectrunc coremap`
Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add src/kernel/tty/text.s src/kernel/bank.s src/kernel/far_shims.s src/kernel/far/loader.s tools/gen_kernel_exports.py include/ktty.s src/kernel/*patchsites.s src/kernel/*/*patchsites.s src/kernel/*/kernel_exports.s
git commit   # "text: an entry is claimed before its load and records each segment's pages"
```

---

### Task 8: The loader places code by size (B3, kernel)

**Files:**
- Modify: `src/kernel/far/loader.s` (`@lf2_alloc` :937-943; `_LoadOneSegment`'s destination offset; `_ldSegPage` filled; F7.6's FILL list; F8 entry; `_FreeExtras` :1438)
- Create: `disk_src/testdata/codepack`, `tools/mame_test/tests/codepack.json`, `tools/mame_test/codepack_check.py`

**Interfaces:**
- Consumes: `FGX2_SEGF_PLACE`, `_FarSh_Core_Alloc`, `_FarSh_Core_Free`, `_FarSh_TextFill`, `_ldTextNew`, `_ldSegPage`.
- Produces: a CODE segment with `FGX2_SEGF_PLACE`, in a load with `_ldTextNew` = 1, takes `ceil((size + bss) / 256)` pages from `Core_Alloc`; its bank is the address's high byte and `_ldSegPage[seg]` its low byte; on `Core_Alloc` failure it takes a whole bank (`_FarSh_Bank_Alloc`) as today.  `_LoadOneSegment` copies to `_ldSegPage[seg] << 8`.  The entry is `seg0 bank : (_ldSegPage[0] << 8) + entry_offset`.  `_FreeExtras` frees a placed segment with `Core_Free(npg, bank << 8 | page)`.  A text hit fills `_ldSegPage` from FIND's page list, so its DATA relocations add the text's offsets.

- [ ] **Step 1: The probe, RED**

`disk_src/testdata/codepack`:

```sh
# Small programs packed; one goes and is reclaimed; the other keeps running.
/sbin/update &
/bin/sleep 600 &
/testbin/dyntrue && echo DYNOK
echo PACKED
kill %2
sh /testdata/textreclaim
ps
/bin/sleep 1 && echo SLEPT
```

`codepack.json`: `"command": "sh /testdata/codepack"`, `exit_on_prompt` false, memory regions `_kTextTab` (tty bank symbol, `"len": 576`) and the task table as `textshare.json` dumps it.  `codepack_check.py` parses text entries (36 bytes each, layout from Task 7) and asserts: (a) at least one bank holds the segments of two or more entries, and within every bank the ranges `[page, page + npg)` are disjoint; (b) the positive control: `sh`'s entry's segment 0 (64 KB) has npg 0, a whole bank; (c) the screen shows `DYNOK` (a dynamic program placed at a non-zero offset bound and ran), `PACKED`, and `SLEPT`, and the `ps` printed after the reclaim workload still lists `update` (a reclaim around it did not take its pages).  RED today: every npg is 0, so (a) fails.

- [ ] **Step 2: Implement**

As the Interfaces list says.  Read the segment flag from `_ldSegTable+FGX2_SEG_FLAGS,X`.  Pages: `(size + bss + 255) >> 8` in 16-bit, from `FGX2_SEG_SIZE` and `FGX2_SEG_BSS`.  The FILL list's npg byte is the page count for a placed segment and 0 for a whole bank.

Record core/far/tty free bytes.

- [ ] **Step 3: Rebuild and run, GREEN**

Announce the rebuild and MAME runs.
Run: `python3 tools/ninja/gen.py >/dev/null && ninja && python3 tools/mame_test/run.py --fresh codepack coremap textshare textfresh textreclaim textchurn manyproc exectrunc idlemem exectime`
Expected: all pass.  Record from `idlemem`: idle pool banks in use (46 before; expected about 38); from `coremap`, the free total beside Task 6's; and `exectime`'s three figures beside the 91 / 149 / 280 ms of 2026-10-07.

- [ ] **Step 4: Run every manifest and the gate**

Run the every-manifest command from Global Constraints, then `tools/gate.sh`.
Expected: no new failure; `GATE GREEN`.  Record known failures by name.

- [ ] **Step 5: Commit**

```bash
git add src/kernel/far/loader.s disk_src/testdata/codepack tools/mame_test/tests/codepack.json tools/mame_test/codepack_check.py src/kernel/*patchsites.s src/kernel/*/*patchsites.s
git commit   # "loader: a text's code segments are placed by size in shared banks"
```

---

### Task 9: The spec, the ROADMAP, the measurements

**Files:**
- Modify: `docs/history/plans/2026-10-03-coremap-shared-text-design.md` (new section 6.5 "B1-B3 as built": Rulings 1-9 and the measurements)
- Modify: `docs/ROADMAP.md` (the memory campaign entry: B1-B3 done, measured; next B4/B5)

- [ ] **Step 1: Write the section and the entry**

Section 6.5 lists Rulings 1-9 in the spec's voice, then the measured idle pool use, blocks used, offset-reloc totals, exec times and bank free bytes from Tasks 3, 6 and 8.  The ROADMAP entry keeps to one paragraph and points at the spec.

- [ ] **Step 2: Commit**

```bash
git add docs/history/plans/2026-10-03-coremap-shared-text-design.md docs/ROADMAP.md
git commit   # "docs: coremap B1-B3 as built and measured"
```

No gate for this commit (documentation only).
