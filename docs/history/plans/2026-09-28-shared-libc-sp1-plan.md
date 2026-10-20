# Shared libc sub-project 1: heap limit and fork -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every data bank a heap limit cell, `HEAP_LIM` at $FFF8, that the kernel's break check and fork's copies obey, so a region above the heap can later hold libc's per-process data.

**Architecture:** The loader seeds `HEAP_LIM = $FFF8` for every program.  `_Sys_Brk` refuses a break past the cell instead of the constant $FFF9.  Fork's snapshot copy (`_Fork_CopyBank` via `_Img_BankMove`) and the concurrent-fork exchange (`_Img_Xchg` via `Img_Swap`) carry `[HEAP_LIM, $FFFF]` instead of the constant `[HEAP_BASE, $FFFF]`.  `fgx_ld` refuses a data segment that would run into the cell.  Nothing in the shipped system lowers the cell yet; a probe does, to prove the kernel follows it.

**Tech Stack:** Merlin32 65816 assembly (kernel `src/kernel/process.s`, loader `src/kernel/far/loader.s`), fcc K&R C (probe, `ps`), Python (`fgx_ld`, its test), ninja, the MAME harness (`tools/mame_test/run.py`), `tools/gate.sh`.

**Spec:** `docs/history/plans/2026-09-28-shared-libc-design.md` sections 5.2 (data bank map), 5.5 (kernel changes), 6 item 1, 7 (heap and fork-isolation probes).

## Global Constraints

- ASCII only in every file (no em-dashes, no curly quotes).
- Source comments describe the current state only: no "used to", no dated transcripts.  History goes in the commit body.
- Commit bodies are the changelog: informational, no names, no process/CI talk, no follow-ups.  End with the repo's `Co-Authored-By` / `Claude-Session` lines.
- A kernel change with a BSD counterpart names the counterpart file and quotes the deciding line in its commit (sbrk: `vendor/2.11BSD/usr/sys/sys/kern_mman.c:98`; fork: `vendor/2.11BSD/usr/sys/sys/kern_fork.c:271-273`, both quoted below).
- Kernel and far banks are nearly full: `python3 tools/check_kernel_ceiling.py` read kernel 163 B free, far 187 B free on 2026-09-28.  Run it after every kernel edit; if either goes negative, STOP and report -- do not squeeze other code to make room.
- Never run `ninja -t clean`; never `git checkout` a generated file (`kernel_exports.s`).
- Every MAME run is headless through `tools/mame_test/run.py` (never a raw `mame64`).
- Announce to the maintainer before any checkout or rebuild of the main tree; say which branch the tree is on afterwards.
- Work on branch `feat/shared-libc` (spec commit a0137df11).  Do not push; the maintainer merges.
- New tests: small, one behaviour each, each with a check that goes red on today's code.  Nothing is added to the gate (`tools/gate.sh` GATE_TESTS); the gate's existing fork and heap tests are the blast-radius check.

## Review Focus

- A program whose data + bss ends in [$FFF8, $FFFA) links today and would have its last bytes overwritten by the new cell: the linker must refuse it (Task 1).
- A `HEAP_LIM` cell holding garbage above its seed (a stray store, a process that wrote it): the break check and fork's copies must treat it as $FFF8, never copy less than the descriptor or allow a break over it (Task 2 clamp check; Task 3 `_Img_Lim` clamp).
- A break exactly at the limit: `brk(LIM)` must succeed and `brk(LIM + 1)` must fail (Task 2).
- An exec'd program must start with a fresh `HEAP_LIM = $FFF8` whatever its parent's cell held (Task 2 exec-seed check).
- Both fork paths -- the deferred one (child never sleeps) and the concurrent one (child sleeps, parent runs) -- must keep parent and child bytes above the limit separate (Task 3).

## Background the implementer needs

**The data bank today** (every process; include/kernel.s:975-980):

```
$0100  program data + bss, then the heap up to the break
$FFFA  HEAP_BASE  `end' (the heap's floor)
$FFFC  HEAP_HWM   highest break ever reached
$FFFE  HEAP_BRK   the live break
```

`_Sys_Brk` (src/kernel/process.s ~2588-2810) refuses a new break at or above the constant `HEAP_TOP+1` = $FFFA.  After this plan the cell at $FFF8 is `HEAP_LIM`, the first byte the heap may not occupy; the break may equal it.  With the seed $FFF8 the highest break drops from $FFF9 to $FFF8 -- one byte.

**Fork is a snapshot fork.**  The child runs in the parent's banks.  Two paths save and restore the parent's bytes:

- Deferred (the child never sleeps): `_Img_BankMove` (process.s ~1777-1815) parks the parent's banks in a spare ("home") and restores them when the child is done, calling `_Fork_CopyBank` (~1218-1300) per bank pair.  For the data bank (pair 0) it copies `[0, break]` and then the "heap cells" `[HEAP_BASE, $FFFF]`.
- Concurrent (the child sleeps and the parent runs): `Img_Swap` (~1820-1880) exchanges the live banks and the home with `_Img_Xchg` (~1960-2014), again `[0, break]` and then `[HEAP_BASE, $FFFF]`.

Both second ranges become `[HEAP_LIM value, $FFFF]`, read from the bank itself.  This is 2.11BSD's fork shape: it copies the data segment and the stack segment, the two ends of the process's space (`kern_fork.c:271-273`):

```c
			copy(rip->p_daddr, rpp->p_daddr, rpp->p_dsize);
			rpp->p_saddr = a[1];
			copy(rip->p_saddr, rpp->p_saddr, rpp->p_ssize);
```

and the break's ceiling is the next thing above the data, as in 2.11BSD's `estabur`, which refuses data that would run into the stack's pages (`kern_mman.c:98`):

```c
		if (ctos(ts) > 8 || ctos(nd)+ctos(ns) > 8)
```

**Build and run:**
- Build everything: `ninja` from the repo root.  Toolchain tests: `make -C toolchain test-archives`.
- One MAME test: `python3 tools/mame_test/run.py <name>` (manifests in `tools/mame_test/tests/`).  Read the verdict lines; a "(1 cached)" verdict did not run -- rerun with `--fresh` after any rebuild.
- Gate: `tools/gate.sh` (stops at its first red stage; read which stage).

---

### Task 1: fgx_ld refuses a data segment that reaches HEAP_LIM

**Files:**
- Create: `toolchain/tests/ld/test_data_fit.py`
- Modify: `toolchain/src/ld/fgx_ld.py` (constants near `KIND_MAP` ~157; segment-table loop ~1050-1070)
- Modify: `toolchain/Makefile` (`test-archives` target ~206-211)

**Interfaces:**
- Produces: `HEAP_LIM = 0xFFF8` in fgx_ld.py; the link fails with a message containing `$FFF8` when a DATA segment's bytes + bss exceed it.

- [ ] **Step 1: Write the failing test** -- create `toolchain/tests/ld/test_data_fit.py`:

```python
#!/usr/bin/env python3
"""test_data_fit.py -- fgx_ld refuses a data segment that runs into HEAP_LIM.

The loader writes the heap limit cell at $FFF8 of every data bank
(include/kernel.s HEAP_LIM), so a data segment whose bytes plus bss end past
$FFF8 would have its tail overwritten at load.  The linker refuses it instead.

  fits       data + bss ending exactly at $FFF8 links
  overflows  data + bss ending at $FFF9 is refused, naming $FFF8
Run: python3 tests/ld/test_data_fit.py
"""
import json, os, subprocess, sys, tempfile

LD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..",
                  "src", "ld", "fgx_ld.py")
HEAP_LIM = 0xFFF8


def row(n, src, off, text, typ="Macro"):
    return (f" {n} |  1      {src}    1 | {typ:<11} | 00 |"
            f"         |    0 | 00/{off:04X}               | {text}\n")


def link(d, data_bss):
    segs = [("CODE", bytes([0x6B]), [row(1, "c.s", 0, "FGX2_RELOC_COUNT 0")]),
            ("DATA", b"\x00\x00", [])]
    m = {"output": "out", "n_data_segment": 1, "segments": []}
    for i, (kind, data, rows) in enumerate(segs):
        open(os.path.join(d, f"s{i}"), "wb").write(data)
        open(os.path.join(d, f"s{i}.lst"), "w").write("".join(rows))
        m["segments"].append({"bin": f"s{i}", "listing": f"s{i}.lst",
                              "kind": kind,
                              "bss": data_bss if kind == "DATA" else 0})
    open(os.path.join(d, "m.json"), "w").write(json.dumps(m))
    return subprocess.run([sys.executable, LD, os.path.join(d, "m.json")],
                          capture_output=True, text=True)


def main():
    fails = 0
    with tempfile.TemporaryDirectory() as d:
        r = link(d, HEAP_LIM - 2)          # 2 data bytes + bss = $FFF8
        if r.returncode != 0:
            print("FAIL fits:", r.stderr.strip()[-300:])
            fails += 1
        r = link(d, HEAP_LIM - 1)          # ends at $FFF9
        if r.returncode == 0 or "$FFF8" not in r.stderr:
            print("FAIL overflows: a data segment ending at $FFF9 linked")
            fails += 1
    print("test_data_fit: %s" % ("%d FAILURE(S)" % fails if fails else
                                 "OK (fits at $FFF8, refused past it)"))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 toolchain/tests/ld/test_data_fit.py`
Expected (verified against fgx_ld on 2026-09-28): `FAIL overflows: a data segment ending at $FFF9 linked` and `test_data_fit: 1 FAILURE(S)`.  "fits" must NOT fail; if it does, the harness is wrong, not fgx_ld.

- [ ] **Step 3: Implement** -- in `toolchain/src/ld/fgx_ld.py`, after `KIND_MAP = {...}` add:

```python
# include/kernel.s HEAP_LIM: the heap limit cell the loader writes at this
# offset of every data bank.  A data segment's bytes plus bss must end at or
# below it, or the loader's store overwrites the segment's tail.
HEAP_LIM = 0xFFF8
```

and in the segment-table loop, directly after `kind = KIND_MAP[kind_name]`:

```python
        if kind_name == "DATA" and size + bss > HEAP_LIM:
            die(f"segment {i} (DATA): {size} bytes + {bss} bss = "
                f"{size + bss} B runs into the heap limit cell at "
                f"${HEAP_LIM:04X}; the data segment must end at or below it")
```

- [ ] **Step 4: Run it to verify it passes**

Run: `python3 toolchain/tests/ld/test_data_fit.py`
Expected: `test_data_fit: OK (fits at $FFF8, refused past it)`

- [ ] **Step 5: Wire it into the archive tests and prove no shipped binary trips it**

In `toolchain/Makefile`, `test-archives:` add after `python3 tests/ld/test_c_archive.py`:

```make
	python3 tests/ld/test_data_fit.py
```

Run: `make -C toolchain test-archives` -- every line OK.
Run: `ninja` -- exit 0 with no `runs into the heap limit cell` in the output (the largest data segment today is sbin/ac, ending $F5A3).

- [ ] **Step 6: Commit**

```bash
git add toolchain/tests/ld/test_data_fit.py toolchain/src/ld/fgx_ld.py toolchain/Makefile
git commit   # body: fgx_ld refuses a data segment whose bytes plus bss end past
             # $FFF8, where the loader writes the heap limit cell; test_data_fit
             # covers the boundary on both sides.
```

---

### Task 2: the heap limit cell -- loader seed, break ceiling, ps

**Files:**
- Modify: `include/kernel.s:975-980` (heap descriptor EQUs)
- Modify: `src/kernel/far/loader.s` (`@los_done`, ~1620-1666)
- Modify: `src/kernel/process.s` (`_Sys_Brk` ceiling ~2613-2632; `_Img_Brk` ~1722-1736)
- Modify: `src/userland/ps/ps.c:37-49`
- Modify: `src/userland/forkpair/forkpair.c` (new `limcell` and `lim` modes)
- Create: `tools/mame_test/tests/forkpair_lim.json`
- Modify (comments only): `src/userland/sbrktest/sbrktest.c:54-58`, `src/userland/heapkill/heapkill.c:41-49`, `src/userland/fsck/fsck.h:210`, `toolchain/lib/libc_c/proc.c:88-91` if it quotes the descriptor as "three words"

**Interfaces:**
- Produces: `HEAP_LIM EQU $FFF8` (include/kernel.s) -- the cell's address AND its highest meaningful value; the loader writes $FFF8 there at every spawn; `_Sys_Brk` refuses a break > min(cell, $FFF8).  `HEAP_TOP` is deleted.  Probe modes `forkpair limcell` (exit 0 iff the cell reads $FFF8) and `forkpair lim` (prints `FP LIM ok`).
- Consumes: nothing from Task 1 at runtime.

- [ ] **Step 1: Write the failing probe** -- in `src/userland/forkpair/forkpair.c`:

Add to the header comment's mode list:

```c
 *   lim     the break stops at the HEAP_LIM cell ($FFF8, include/kernel.s),
 *           and an exec'd program starts with the cell at its seed:
 *                                                            FP LIM ok
```

Add `int brk();` beside the other declarations, then these helpers after `mark()`:

```c
/* An address in this process's data bank: the bank of any heap address. */
static char *
at(char *h, unsigned off)
{
    return (char *)(((unsigned long)h & 0xFF0000L) | (unsigned long)off);
}

/* The heap limit cell, HEAP_LIM (include/kernel.s). */
static unsigned *
limp(char *h)
{
    return (unsigned *)at(h, 0xFFF8);
}
```

In `main`, after the `sbrk(64)` check and before the `order` mode, add:

```c
    if (strcmp(m, "limcell") == 0)
        return *limp(h) == 0xFFF8 ? 0 : 4;
    if (strcmp(m, "lim") == 0) {
        unsigned *lp;

        lp = limp(h);
        if (*lp != 0xFFF8) { printf("FP LIM FAIL seed %x\n", *lp); return 1; }
        *lp = 0xE000;
        if (brk(at(h, 0xDF00)) != 0) { printf("FP LIM FAIL park\n"); return 1; }
        if (brk(at(h, 0xE000)) != 0) { printf("FP LIM FAIL reach\n"); return 1; }
        if (brk(at(h, 0xE001)) == 0) { printf("FP LIM FAIL ceiling\n"); return 1; }
        *lp = 0xFFFF;                   /* garbage above the seed reads as it */
        if (brk(at(h, 0xFFF9)) == 0) { printf("FP LIM FAIL clamp\n"); return 1; }
        *lp = 0xE000;
        if (brk(h + 64) != 0) { printf("FP LIM FAIL unpark\n"); return 1; }
        pid = fork();
        if (pid == 0) {
            execl("/testbin/forkpair", "forkpair", "limcell", (char *)0);
            _exit(6);
        }
        wait(&st);
        if (st != 0) { printf("FP LIM FAIL exec seed %x\n", st); return 1; }
        printf("FP LIM ok\n");
        return 0;
    }
```

Update the usage line to `usage: forkpair order|bytes|orphan|three|hwm|lim|limcell`.

Create `tools/mame_test/tests/forkpair_lim.json`:

```json
{
 "name": "forkpair_lim",
 "description": "Shared libc sub-project 1: the break stops at the HEAP_LIM cell ($FFF8), whatever the cell holds up to its seed; garbage above the seed reads as the seed; an exec'd program starts with the cell at $FFF8; and both fork paths keep parent and child bytes above the limit separate.  On a kernel with the constant $FFF9 ceiling it prints FP LIM FAIL ceiling.",
 "command": "/testbin/forkpair lim",
 "timeout_s": 90,
 "expect": {
  "screen_contains": [
   "FP LIM ok"
  ],
  "screen_lacks": [
   "FP LIM FAIL",
   "FP FAIL",
   "PANIC",
   "BRK"
  ]
 }
}
```

- [ ] **Step 2: Build and run it to verify it fails**

Announce the rebuild to the maintainer (branch `feat/shared-libc`).
Run: `ninja` then `python3 tools/mame_test/run.py --fresh forkpair_lim`
Expected: red, with `FP LIM FAIL seed 0` (the loader does not write the cell yet; nothing above the break is initialised).  If it instead says `FP LIM FAIL ceiling`, the cell happened to read $FFF8 -- also a valid red.

- [ ] **Step 3: Add the EQU** -- in `include/kernel.s`, replace the two `HEAP_TOP` lines (978-979) with:

```
HEAP_LIM        EQU     $FFF8           ; the heap limit cell: the first byte
                                        ; the heap may not occupy.  The break
                                        ; may equal it.  The loader seeds it
                                        ; to its own address, $FFF8; a lower
                                        ; value reserves [value, $FFF8) above
                                        ; the heap, which fork carries.  A
                                        ; value above $FFF8 reads as $FFF8.
```

and move it above `HEAP_BASE` so the block reads in address order.  Update the descriptor comments in this file that say "three words" to four.

- [ ] **Step 4: Seed it in the loader** -- in `src/kernel/far/loader.s` at `@los_done`, directly after `STA:    $FFFA                    ; HEAP_BASE = end (fixed)` add:

```
                LDA     #$FFF8
                STA:    $FFF8                    ; HEAP_LIM  = its seed: no region
                                                 ; above the heap
```

and update the block comment above to list the fourth cell (`(dataBank:$FFF8) HEAP_LIM = $FFF8, the heap limit`) and "four words".

- [ ] **Step 5: Take the break ceiling from the cell** -- in `src/kernel/process.s` `_Sys_Brk`, replace

```
                LDA     #HEAP_TOP+1                 ; ceiling: the break may reach
                STA     _sb_sfp                     ; HEAP_TOP, not past it
                STZ     _libcTmp2                   ; base = (data bank : $0000) -- heap
```

with

```
                STZ     _libcTmp2                   ; base = (data bank : $0000) -- heap
                LDY     #HEAP_LIM                   ; ceiling: the break may reach
                LDA     [_libcTmp2],Y               ;   the heap limit cell, not
                CMP     #HEAP_LIM+1                 ;   past it; a cell above its
                BCC     @sb_limOk                   ;   seed reads as the seed
                LDA     #HEAP_LIM
@sb_limOk       INC
                STA     _sb_sfp
```

keeping the three addressing-comment lines that followed `STZ _libcTmp2`.  Rewrite the comment block above it (the "soft-frame stack used to live in THIS bank" paragraph) to describe the current rule only: the ceiling is the data bank's `HEAP_LIM`, the analogue of 2.11BSD `estabur` refusing data that runs into the stack's pages.

In `_Img_Brk` replace `CMP     #HEAP_TOP+1` with `CMP     #HEAP_LIM` (a break is at most $FFF8, so break-1 is below $FFF8).

Run: `grep -rn 'HEAP_TOP' src include toolchain/lib` -- expect no assembler references left (comments are fixed in Step 7).

- [ ] **Step 6: ps** -- in `src/userland/ps/ps.c` `heapfree`, change `top -= 6;` to `top -= 8;` and its comment to `/* $FFF8 = HEAP_LIM, the heap limit cell (kernel.s) */`; rewrite the function's header comment to say the heap may reach `HEAP_LIM` ($FFF8).

- [ ] **Step 7: Comments that name the old ceiling** -- update `sbrktest.c:54-58`, `heapkill.c:41-49`, `fsck.h:210`, and any "three words" quote of the descriptor in `toolchain/lib/libc_c/proc.c`, to say `HEAP_LIM ($FFF8)` / four words.  Both probes' assertions (park at $F000, grow to $FFFF refused) stay valid unchanged.

- [ ] **Step 8: Build, check bytes, run the probe to verify it passes**

Run: `ninja` then `python3 tools/check_kernel_ceiling.py` -- kernel and far both still have free bytes (record the numbers for the commit body).
Run: `python3 tools/mame_test/run.py --fresh forkpair_lim sbrktest heapkill`
Expected: all three green; forkpair_lim shows `FP LIM ok`.

- [ ] **Step 9: Commit**

```bash
git add include/kernel.s src/kernel/far/loader.s src/kernel/process.s \
        src/userland/ps/ps.c src/userland/forkpair/forkpair.c \
        tools/mame_test/tests/forkpair_lim.json src/userland/sbrktest/sbrktest.c \
        src/userland/heapkill/heapkill.c src/userland/fsck/fsck.h \
        toolchain/lib/libc_c/proc.c
git commit   # body: the heap limit cell HEAP_LIM at $FFF8, seeded by the loader;
             # _Sys_Brk's ceiling is the cell (clamped to its seed) where it was
             # the constant $FFF9, so the highest break drops by one byte.
             # Quote 2.11BSD vendor/2.11BSD/usr/sys/sys/kern_mman.c:98
             # `if (ctos(ts) > 8 || ctos(nd)+ctos(ns) > 8)'.  Kernel/far bytes
             # before and after.  Probe: forkpair lim.
```

---

### Task 3: fork carries the region above the limit

**Files:**
- Modify: `src/kernel/process.s` -- new `_Img_Lim` beside `_Img_Brk` (~1722); `_Img_BankMove` (~1777-1815); `_Fork_CopyBank` (~1218-1300); `Img_Swap` pair loop (~1840-1865); `_Img_Xchg` tail (~2005-2014) and its header comment (~1952-1958); new cell `_ib_lim` beside `_ib_brk` (~4927)
- Modify: `src/userland/forkpair/forkpair.c` (`lim` mode: two fork-isolation checks)

**Interfaces:**
- Consumes: `HEAP_LIM EQU $FFF8` and the seeded cell (Task 2).
- Produces: `_Img_Lim` (In: A.lo = a data bank; Out: A = that bank's `HEAP_LIM` cell, values above $FFF8 read as $FFF8; clobbers A; DBR preserved) and `_ib_lim DS 2` (the low bound of the top range for the copy or exchange in progress).  `_Fork_CopyBank` and `_Img_Xchg` read `_ib_lim` where they used `#HEAP_BASE`.

- [ ] **Step 1: Write the failing checks** -- in `forkpair.c`'s `lim` mode, replace the `if (brk(h + 64) != 0) ...` line and everything after it up to `printf("FP LIM ok\n");` with:

```c
        if (brk(h + 64) != 0) { printf("FP LIM FAIL unpark\n"); return 1; }
        r = at(h, 0xE000);
        for (i = 0; i < 256; i++)
            r[i] = 'P';
        /* Deferred: the child never sleeps, so the parent is parked and
         * restored around it (_Img_BankMove). */
        pid = fork();
        if (pid == 0) {
            for (i = 0; i < 256; i++)
                r[i] = 'C';
            _exit(0);
        }
        wait(&st);
        for (i = 0; i < 256 && r[i] == 'P'; i++)
            ;
        if (i != 256) { printf("FP LIM FAIL deferred %d\n", i); return 1; }
        /* Concurrent: the child sleeps and the parent runs, so the two
         * images are exchanged (Img_Swap); each must see only its own. */
        unlink("/tmp/fp.lim");
        pid = fork();
        if (pid == 0) {
            for (i = 0; i < 256; i++)
                r[i] = 'C';
            sleep(2);
            ok = access("/tmp/fp.lim", 0) == 0;
            for (i = 0; i < 256; i++)
                if (r[i] != 'C')
                    ok = 0;
            _exit(ok ? 0 : 5);
        }
        for (i = 0; i < 256 && r[i] == 'P'; i++)
            ;
        ok = i == 256;
        mark("/tmp/fp.lim");
        wait(&st);
        if (!ok || st != 0) {
            printf("FP LIM FAIL concurrent %d %x\n", i, st);
            return 1;
        }
        pid = fork();
        if (pid == 0) {
            execl("/testbin/forkpair", "forkpair", "limcell", (char *)0);
            _exit(6);
        }
        wait(&st);
        if (st != 0) { printf("FP LIM FAIL exec seed %x\n", st); return 1; }
```

and declare `char *r; int i;` at the top of the `lim` block beside `unsigned *lp;`.

- [ ] **Step 2: Build and run it to verify it fails**

Run: `ninja` then `python3 tools/mame_test/run.py --fresh forkpair_lim`
Expected: `FP LIM FAIL deferred 0` -- the parked copy stops at the break and the cells, so the child's 'C' bytes survive into the parent.

- [ ] **Step 3: `_Img_Lim` and `_ib_lim`** -- in `process.s`, directly after `_Img_Brk`'s `@ibk_ok RTS`, add:

```
;------------------------------------------------------------------------------
; _Img_Lim - A = the data bank A.lo's heap limit cell (HEAP_LIM): the first
; byte of the region above the heap that a copy of the bank carries.  A cell
; above its seed reads as the seed, so a copy never skips the descriptor.
; Clobbers A.
;------------------------------------------------------------------------------
_Img_Lim        MX      %00
                PHB
                SEP     #$20
                MX      %10
                PHA
                PLB                             ; DBR = that bank
                REP     #$20
                MX      %00
                LDA    |HEAP_LIM
                PLB
                CMP     #HEAP_LIM+1
                BCC     @ilm_ok
                LDA     #HEAP_LIM
@ilm_ok         RTS
```

and beside `_ib_brk DS 2` (~4927):

```
_ib_lim         DS      2                       ; the data bank's heap limit in play
```

- [ ] **Step 4: The deferred path** -- in `_Img_BankMove`, change

```
@ibm_src        JSR     _Img_Brk                ; (used for pair 0 only)
```

to

```
@ibm_src        PHA
                JSR     _Img_Lim                ; the source's limit and break
                STA    |_ib_lim                 ; (both used for pair 0 only)
                PLA
                JSR     _Img_Brk
```

In `_Fork_CopyBank`, replace

```
                LDX     #HEAP_BASE                  ; the heap cells
                LDA     #$FFFF-HEAP_BASE
                JSR     @fcb_move
```

with

```
                LDX    |_ib_lim                     ; the region above the heap
                LDA     #$FFFF                      ;   and the descriptor
                SEC
                SBC    |_ib_lim                     ; count-1 = $FFFF - limit
                JSR     @fcb_move
```

and rewrite its header comment: when `_fs_end` is below $FFFF it also copies `[_ib_lim, $FFFF]`, the region above the heap and the heap descriptor; add `_ib_lim` to its "In:" line.  Confirm the single caller: `grep -n 'JSR     _Fork_CopyBank' src/kernel/*.s` -- one hit, in `_Img_BankMove`.

- [ ] **Step 5: The concurrent path** -- in `Img_Swap`'s pair loop, replace the line

```
@isw_brkLo      JSR     _Img_Extent
```

with

```
@isw_brkLo      LDA    |_ib_pair
                JSR     _Img_Lim                ; the live limit (orig)
                STA    |_ib_lim
                LDA    |_ib_pair
                XBA
                JSR     _Img_Lim                ; the home's (spare)
                CMP    |_ib_lim
                BCS     @isw_limHi
                STA    |_ib_lim                 ; the lower of the two
@isw_limHi      JSR     _Img_Extent
```  In `_Img_Xchg`, replace

```
                LDA     #HEAP_BASE
                STA     _fs_start
```

with

```
                LDA    |_ib_lim                 ; the region above the heap
                STA     _fs_start
```

and in its header comment replace "the heap cells [HEAP_BASE, $FFFF]" with "[_ib_lim, $FFFF], the region above the heap and the descriptor".  Confirm callers: `grep -n 'JSR     _Img_Xchg' src/kernel/*.s` -- every caller must set `_ib_lim` first; if any caller other than `Img_Swap` exists, add the same two-bank lower-of step there.

Also update `_Img_Extent`'s header comment ("the data bank to the break ... plus the heap cells") to name the region above the heap.

- [ ] **Step 6: Build, check bytes, run to verify it passes**

Run: `ninja` then `python3 tools/check_kernel_ceiling.py` (record the numbers).
Run: `python3 tools/mame_test/run.py --fresh forkpair_lim forkpair_bytes forkpair_three forkpair_hwm forkpair_order forkpair_orphan`
Expected: all green; forkpair_lim prints `FP LIM ok`.

- [ ] **Step 7: Prove the check discriminates** -- temporarily change `_Img_Lim`'s `LDA    |HEAP_LIM` to `LDA     #HEAP_LIM` (the constant seed, i.e. ignore the cell), `ninja`, run `python3 tools/mame_test/run.py --fresh forkpair_lim`: expected `FP LIM FAIL deferred` (or `concurrent`).  Revert the line, `ninja`, rerun: green.  Record both outcomes for the commit body.

- [ ] **Step 8: Commit**

```bash
git add src/kernel/process.s src/userland/forkpair/forkpair.c
git commit   # body: fork's snapshot copy and the concurrent-fork exchange carry
             # [HEAP_LIM, $FFFF] where they carried the fixed heap cells, reading
             # the cell from the bank (lower of the two banks for an exchange).
             # Quote 2.11BSD vendor/2.11BSD/usr/sys/sys/kern_fork.c:271-273 (data
             # and stack segments copied).  Kernel bytes; the mutation result.
```

---

### Task 4: verify the whole system and record it

**Files:**
- Modify: `docs/ROADMAP.md` (one short entry under the performance / libc work pointing at the spec, marking sub-project 1 done)
- Modify: `docs/history/plans/2026-09-28-shared-libc-design.md` section 6 item 1 (mark done, link the commits)

**Interfaces:**
- Consumes: Tasks 1-3.

- [ ] **Step 1: Gate**

Run: `tools/gate.sh` (long; run it in the background and wait for it).
Expected: green.  The gate's fork and heap tests (`bigfork bigforkx fkiso fknest fkbg fkbadex sbrktest heapkill softfork softexec`) are the blast radius of this change.  If a stage is red, read WHICH stage: the gate stops at its first red stage and hides the rest.

- [ ] **Step 2: Fork and exec timing did not move**

Run the three manifests from `docs/history/wip-2026-09-28-cache/` (`qcolon.json`, `qsub.json`, `qtrue.json`) with `python3 tools/mame_test/run.py --fresh --manifest <file>` and read `frame - paste_frame` from each `/tmp/fgx_test_<name>/dump.json`.
Baseline (2026-09-28, main 75f05713f): qcolon 205, qsub 301, qtrue 409 frames; `_kImgCopies` 0 / 40 / 40.
Expected: within +/-1 frame of the baseline (the copy grows by 2 bytes per fork).  Report the measured numbers either way.

- [ ] **Step 3: Docs and commit**

Add the ROADMAP entry (one paragraph: shared libc campaign, spec link, sub-project 1 done with the commit hashes, next is sub-project 2).  Mark section 6 item 1 done in the spec.

```bash
git add docs/ROADMAP.md docs/history/plans/2026-09-28-shared-libc-design.md
git commit   # body: states what landed and the measured gate/timing results
```

- [ ] **Step 4: Record in the project notes (group `fgx`)** -- one `add_triplet`: sub-project 1 landed, the commit hashes, kernel/far bytes after, the fork/exec timings, and the mutation result.
