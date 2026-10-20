# Shared libc SP4 step 3: binding on the machine -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A dynamic program runs on the machine with no host binding: its crt0 copies libc's resident core into its data bank, enters the binder in libc, which binds the program's imports against the resident libraries (prebound, or by name when a library changed), copies their cores and returns; `LD_TRACE_LOADED_OBJECTS` and `ldd` describe it, `LD_BIND_DIGEST` proves the binding equals `fgx_bind`'s, and a small tool's exec is measured against today's.

**Architecture:** `fgx_dyn` links `crt0_dyn.s` ahead of `crt0_lib.s` and appends, at segment 0's tail, a segment-bank table and the program's IMPS table, whose offset it patches into crt0_dyn's locator. crt0_dyn ACQUIREs libc, copies its core with `_lib_copy`, and calls libc's `_ld_bind` (asm: seeds libc's `_fcc_dbr`, then `ld_bind` in C), which uses step 2's `ld_need` for any absent library, an asm site loop (`_ld_patch`) for the patching, and a by-name lookup through an export index ld_load now builds. Then crt0_dyn continues as crt0_lib.

**Tech Stack:** fcc K&R C (libc's `ld_bind.c`, `ldd`, `exectime`), Merlin32 65816 (`crt0_dyn.s`, `ld_bind_asm.s`), Python 3 (`fgx_dyn`, `fgx_bind`, `fgx_lddigest`), ninja, headless MAME.

**Spec:** `docs/history/plans/2026-09-30-shared-libc-sp4-design.md` (sections 5.1, 5.3, 5.4, 5.5, 7, 8, 9, 10 step 3). Step 2's plan for the conventions: `docs/history/plans/2026-09-30-shared-libc-sp4-step2-plan.md`.

## Global Constraints

- Branch `feat/shared-libc`; no push, no MR. Each commit ends with the session's attribution trailers; bodies are the changelog (informational, no names or process).
- ASCII only; comments describe the current state only.
- Merlin32 has no operator precedence; `LDX n,S` does not exist; a new `PUT`/source file needs `python3 tools/ninja/gen.py`; explicit `MX` at every label reached in a width other than the line before it (check_mx).
- fcc locals live on the bank-0 stack: anything a syscall reads is in the data bank. fcc pointers are 3 bytes in a 4-byte slot; arguments right to left, the first nearest, the caller drops them; a far call leaves a 3-byte return above them (`docs/userland-abi.md` 3.6).
- A leaf asm routine may use fcc's caller-saved direct-page pointer scratch (`_fcc_ptr` $E8, `_fcc_ptr2` $FC, `_fcc_fpr0` $98) for `[dp],Y`; it must not move D.
- Every MAME verdict is a fresh run ("cached" did not run); every probe needle is printed only after the checks it stands for.
- The binder prints with `write(2)` from the data bank (its blocks do not exist yet); libc literals are in code banks, so messages are assembled in `struct ld_work`'s `msg`.
- SunOS 4.1.3 texts where rtld has one (spec 5.5); the trace line is rtld's `\t-l<name>.<major> => <path>` (`examples/SunOS-4.1.3/lang/rtld/rtld.c:361-370`) with FGX's fields after it.
- Exec is a landing gate (spec 1, 8): a small dynamic tool's exec within 10% of today's static `true`, or STOP for the maintainer.

## Rulings this plan makes against the spec (each lands in the spec in Task 6)

1. **The tables go only at segment 0's tail** in step 3; a program whose segment 0 has no room is refused naming sub-project 5. fgx_dyn links one code segment today (its own `die` says multi-bank programs are sub-project 5's), and appending to the data segment would move its bss.
2. **The locator is the operand of an `LDA #` in crt0_dyn** that fgx_dyn patches: crt0 reads it without a data access or a reloc, and the tables' bank is segment 0's, which is crt0's own (`PHK`).
3. **libc's `_fcc_dbr` is seeded by `_ld_bind`'s asm entry**, not by crt0: it is a cell in libc's core, whose address only libc's own (CSIT-moved) code knows.
4. **The digest covers the program's patched sites**, each bank byte normalised to (library index, code segment); the core copies are not in the host parity -- their bank bytes are the libraries' own relocs, which the binder does not know and step 2's `lddig` already proved in the templates; the binder checks each copy equals its template but for the fixups.
5. **`LD_BIND_DIGEST` prints and exits 0**, as `LD_TRACE_LOADED_OBJECTS` does, so a probe can compare it with `cmp`.
6. **ld_load builds an export index (`XIDX`) after EXPT** at load: by-name binding tries the recorded ordinal, then a binary search (spec 5.3), and both need random access to EXPT's variable-length records. Its payload also carries the library's assembled core base, which by-name data addresses need.
7. **Step 2's deferred minor in `ld_bind_imps`** (all three site classes patched for either kind) is fixed by routing both binders through one asm loop that takes the class the import's kind allows.
8. **crt0 hands the binder libc's row** (`_dyn_blk`, as its ACQUIRE left it), and the binder takes every other row from the ACQUIRE or COMMIT that made it resident: a dynamic program with only libc costs one `SYS_LDCTL` per exec (spec 8 counts one per needed library).
9. **A library's block table is found through the program's own import of `_<lib>_blktab`** (every dynamic program's `_crt0_inits` names it), not by a search of EXPT per exec; a program that does not import it is refused.

Revised after an adversarial review of this plan (Fable, 2026-10-01), all twelve findings adopted.

## Review Focus

1. **A library rebuilt since the program was linked** (CRC differs, data addresses moved) -- the program binds by name and runs. Test: `dynsomisdyn` (Task 4).
2. **A dynamic program's environment and arguments** after binding -- argv, `__progname` and an environment variable reach `main` intact (the binder reads the kernel's frame before `_libc_start`). Test: `dynsodyn` with `DSO_ENV=yes` (Task 3).
3. **fork and exec from a dynamic program** -- a forked child and an exec'd dynamic program run, and the registry's counts stay right. Test: `dynsodyn` (fork, vfork, exec of `/testbin/dyntrue`) and an `ldctl look libc` users count after (Task 3).
4. **`ldd` on what is not a dynamic program** -- a static program says "statically linked"; a missing file names itself; neither runs anything. Test: `ldd` probe (Task 4).
5. **Tracing a program whose data does not fit, or with a library absent** -- not testable without a second libc on the machine (step 4's error probes); stated so it is not assumed covered.

---

### Task 1: libc's side -- the export index and the asm site loop

**Files:**
- Create: `toolchain/lib/ld_bind_asm.s` (`_ld_patch`; Task 3 adds `_ld_bind` to it)
- Modify: the libc link so `ld_bind_asm.s` is in libc.so's bank-0 hand-written code (`fgx_libso.LIBS["libc"]["bank0"]`) and the static pile's (`toolchain/Makefile`'s libc piles, beside `libc_so_helpers.s`)
- Modify: `toolchain/lib/libc_c/ld_load.c` (XIDX after FIXS; `ld_bind_imps` through `_ld_patch`)
- Modify: `toolchain/include/sys/ldctl.h` (`_ld_patch` prototype; `struct ld_seg`)
- Modify: `toolchain/src/ld/fgx_lddigest.py` (`tagged()` adds XIDX)

**Interfaces:**
- Produces: `void _ld_patch(unsigned char *sites, int n, struct ld_seg *segs, int kind, unsigned val, int bank)` -- `n` records of (segment u8, offset u16) at `sites`; `segs[s]` is (offset word, bank byte, pad): kind 0 writes `val` at `segs[s].off + off` and `bank` at +2; kind 1 adds `val` there. In memory after FIXS: `XIDX` = u16 assembled core base, u16 count, u16 offset of each EXPT record from EXPT's payload; then `END`.

- [ ] **Step 1: The host twin first**

In `fgx_lddigest.py`, `tagged(tr)` becomes:

```python
def xidx(tr):
    """ld_load's export index: the assembled core base, the count, and each
    EXPT record's offset in its payload, in EXPT's (name) order."""
    rec, offs, p = tr["blocks_raw"].get("EXPT", b""), [], 0
    while p < len(rec):
        offs.append(p)
        p += 1 + rec[p] + 6
    return struct.pack("<HH", tr["core_base"], len(offs)) + \
        b"".join(struct.pack("<H", o) for o in offs)


def tagged(tr):
    raw = tr["blocks_raw"]
    return (fgx_ld.block(b"EXPT", raw.get("EXPT", b""))
            + fgx_ld.block(b"FIXS", raw.get("FIXS", b""))
            + fgx_ld.block(b"XIDX", xidx(tr))
            + fgx_ld.block(b"END\0", b""))
```

and `fgx_libso.tagged_bytes`/`tagged_guess` charge it: `+ 12 + 2 * n_exports` (8 for the tag and length, 4 for base and count, 2 a record).

Run: `python3 toolchain/src/ld/fgx_lddigest.py --self-test && python3 toolchain/src/ld/fgx_libso.py --self-test && python3 tools/ninja/gen.py >/dev/null && ninja > $S/t1_build.log 2>&1; tools/mame_test/run.py ldload lddelta`
Expected: self-tests OK; both probes FAIL with `LDD FAIL lib... bank <last> digest ...` (the machine has no XIDX yet).

- [ ] **Step 2: XIDX in ld_load**

In `ld_fill`, after the FIXS copy and before the END tag:

```c
    /* XIDX: the assembled core base, the count, each EXPT record's offset. */
    t[0] = 'X'; t[1] = 'I'; t[2] = 'D'; t[3] = 'X';
    for (n = 0, i = 0; i < elen; i += 1 + e[i] + 6)
        n++;
    ld_wr16(t + 4, 4 + 2 * n);
    t[6] = t[7] = 0;
    ld_wr16(t + 8, cbase);
    ld_wr16(t + 10, n);
    t += 12;
    for (i = 0; i < elen; i += 1 + e[i] + 6, t += 2)
        ld_wr16(t, i);
```

and the room check becomes `expt_at + 8 + elen + 8 + flen + 12 + 2 * nexp + 8 > 0x10000L` with `nexp` counted the same way before the GRANT. `lddig` computes the last bank's length from the same terms: add `+ 12 + 2 * nexp` to its `tagend`.

Run: `ninja > $S/t1_build2.log 2>&1; tools/mame_test/run.py ldload lddelta ldorder`
Expected: `3 passed`, fresh.

- [ ] **Step 3: The asm site loop, and ld_bind_imps on it**

`toolchain/lib/ld_bind_asm.s`:

```
;==============================================================================
; ld_bind_asm.s - the shared-library binder's hand-written half (shared libc
; SP4 spec, section 5.4): the loop that patches a run of sites.  A site is
; (segment, offset); `segs' gives each segment's (offset, bank) once loaded,
; so a library's core and template segments, which sit inside its last bank,
; resolve as its code banks do.  In C the loop is about 410 cycles a site.
;==============================================================================

;------------------------------------------------------------------------------
; _ld_patch(sites, n, segs, kind, val, bank) - kind 0: the word at each site
; becomes val and the byte after it bank (a call's or a pointer's 24 bits);
; kind 1: val is added to the word (a data site moved by the delta).  Uses
; fcc's caller-saved pointer scratch: _fcc_ptr2 the site list, _fcc_fpr0 the
; segment table, _fcc_ptr the site.  Far: JSL'd from C, RTL.
;------------------------------------------------------------------------------
                FGX2_EXPORT _ld_patch
_ld_patch       MX      %00
                LDA     4,S                     ; sites
                STA     _fcc_ptr2
                LDA     6,S
                STA     _fcc_ptr2+2
                LDA     10,S                    ; segs
                STA     _fcc_fpr0
                LDA     12,S
                STA     _fcc_fpr0+2
                LDA     8,S                     ; n
                BEQ     @lp_done
                TAX
                LDY     #0
@lp_site        MX      %00
                LDA     [_fcc_ptr2],Y           ; the segment, in the low byte
                AND     #$00FF
                ASL
                ASL
                PHY
                TAY
                LDA     [_fcc_fpr0],Y           ; its offset once loaded
                STA     _fcc_ptr
                INY
                INY
                SEP     #$20
                MX      %10
                LDA     [_fcc_fpr0],Y           ; its bank
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLY
                INY
                LDA     [_fcc_ptr2],Y           ; the site's offset
                CLC
                ADC     _fcc_ptr
                STA     _fcc_ptr
                INY
                INY
                PHY                             ; arguments 2 deeper below
                LDA     14+2,S                  ; kind
                BNE     @lp_data
                LDA     16+2,S                  ; val
                STA     [_fcc_ptr]
                LDY     #2
                SEP     #$20
                MX      %10
                LDA     18+2,S                  ; bank
                STA     [_fcc_ptr],Y
                REP     #$20
                MX      %00
                BRA     @lp_next
@lp_data        MX      %00
                LDA     [_fcc_ptr]
                CLC
                ADC     16+2,S
                STA     [_fcc_ptr]
@lp_next        MX      %00
                PLY
                DEX
                BNE     @lp_site
@lp_done        MX      %00
                RTL
```

Add to `<sys/ldctl.h>`:

```c
/* A segment once loaded: where its offset 0 is. */
struct ld_seg {
    unsigned off;
    unsigned char bank, pad;
};

void _ld_patch();
```

In `ld_load.c`, `ld_map` gains `struct ld_seg seg[LD_MAXBANKS + 2]` filled after GRANT (code `i`: (0, banks[i]); core: (core_at, last); templates: (tmpl_at, last)), and `ld_bind_imps` keeps its two-cursor walk but patches each class through the loop, the class the kind allows only:

```c
        for (k = 0; k < 3; k++) {               /* call, ptr, data */
            c = ld_rd16(s);
            s += 2;
            if (c && (kind == 0) != (k < 2))
                return -1;                      /* a class this kind has not */
            if (c)
                _ld_patch(s, c, m->seg, kind,
                          kind == 0 ? val : dep[lib].delta,
                          kind == 0 ? dep[lib].banks[seg] : 0);
            s += 3 * c;
        }
```

(`ld_bind_imps` returns int now; `ld_fill` treats -1 as `goto bad`.) Find where libc's bank-0 hand-written files are listed (`grep -n '"bank0"' toolchain/src/ld/fgx_libso.py`) and add `ld_bind_asm.s` beside `libc_so_helpers.s`; do the same for the static pile's list in `toolchain/Makefile` (`grep -n libc_so_helpers toolchain/Makefile`), and run `python3 tools/ninja/gen.py`.

- [ ] **Step 4: Run, and a control**

Run: `ninja > $S/t1_build3.log 2>&1; tools/mame_test/run.py ldload lddelta ldorder; grep -h "ldload: lib" /tmp/fgx_test_ldload/dump.txt`
Expected: `3 passed`, fresh; curses's load time no higher than step 2's 1,535 ms (its 1,712 core sites still go through C's CSIT loop; its import sites now through asm).
Control: make `_ld_patch` write `val + 1` for kind 0 (`INC` before the first `STA [_fcc_ptr]`), `ninja`, run `ldload`: Expected `LDD FAIL libcurses bank 0 digest ...`. Restore, `ninja`.

- [ ] **Step 5: Shipped bytes, gate, commit**

Run: the staged-tree hash against the one before this task (`find disk_src -type f ! -path 'disk_src/testbin/*' ...` as step 2); Expected: only the three libraries, `/sbin/ldload`, and stamps differ (`_ld_patch` is in the static pile, which no shipped tool reaches). Run `tools/gate.sh`; Expected `GATE GREEN`.

```bash
git add toolchain/lib/ld_bind_asm.s toolchain/lib/libc_c/ld_load.c toolchain/include/sys/ldctl.h \
        toolchain/src/ld/fgx_lddigest.py toolchain/src/ld/fgx_libso.py toolchain/Makefile \
        src/userland/lddig/lddig.c tools/ninja/gen.py
git commit -F - <<'EOF'
feat(libc): an export index for by-name binding, and the site loop in asm

ld_load places an export index after a library's FIXS -- its assembled
core base, its export count, and each EXPT record's offset -- so a binder
can take an import by its recorded ordinal or a binary search over the
names (SunOS rtld's lookup, in EXPT's sorted order).

_ld_patch writes a run of sites through a segment table, about a tenth
of C's cost a site; ld_load binds a library's imports through it, each
class only where the import's kind has it -- a code import's calls and
pointers, a data import's data sites -- and refuses a table that mixes
them.  fgx_lddigest lays the index out as the machine does.
EOF
```

---

### Task 2: fgx_dyn's tables and locator; fgx_bind's entry and digest

**Files:**
- Create: `toolchain/lib/crt0_dyn.s` (Task 2 writes the locator and an entry that only continues to `_crt0_lib`; Task 3 fills it)
- Modify: `toolchain/src/ld/fgx_dyn.py` (crt0_dyn in segment 0, entry `_crt0_dyn`; the tables appended; the locator patched; the trailer's `ENTR` block; `_dyn_blk` and the message in `dyn.data.s`; the binder's frames)
- Modify: `toolchain/src/ld/fgx_bind.py` (startup jumps to `ENTR`'s offset when present; `--digest`)
- Modify: `toolchain/tests/dyn/test_dyn.py`, `toolchain/tests/dyn/test_bind.py`

**Interfaces:**
- Produces (the digest line is `LDB sites xxxx n=N`, N the sites walked, so an empty walk cannot match), in a dynamic program's segment 0 tail at offset T: `u16 nseg`, then per segment a 4-byte cell (word 0, bank byte relocated to that segment, pad 0), then `u16 imps_len` and the IMPS payload; the locator `_dyn_loc LDA #T` (operand patched); the FGXD trailer gains `ENTR` = u16 offset of `_crt0_lib`. `fgx_bind.digest(img, table, libs)` -> u16, and `fgx_bind.py --digest` prints `LDB sites xxxx`.
- The digest: rot-xor (`h = rotl16(h, 1) ^ byte`) over, for each import in IMPS order, each class (call, ptr, data), each site in order: the site's word after binding (low byte, high byte) and, for call and ptr, `16 * L + S` -- L the import's library index in IMPS, S the library code segment the bank byte names.

- [ ] **Step 1: The failing host tests**

In `toolchain/tests/dyn/test_dyn.py` add a check over `hello`'s dynamic link (use the file's existing `dyn()` helper):

```python
def tables():
    """Segment 0 ends with the segment-bank table and the IMPS table; the
    locator's operand is their offset; each cell's bank byte is a reloc to
    its segment; the trailer names _crt0_lib's offset."""
    rc, _text, data, linkdir = link(os.path.join(HERE, "hello.c"), "libc", "hello")
    p = fgx_bind.parse(data)
    tr = fgx_ld.read_dyn_trailer(p["trailer"])["blocks_raw"]
    seg0 = p["segs"][0][0]
    lst = os.path.join(linkdir, "seg0_Output.txt")
    ex = fgx_ld.scan_listing(lst, 2, libc=True)["exports"]
    t = struct.unpack_from("<H", seg0, ex["_dyn_loc"] + 1)[0]
    n = struct.unpack_from("<H", seg0, t)[0]
    check(n == len(p["segs"]), "the table has a cell per segment", str(n))
    check(all((0, t + 2 + 4 * i + 2, i) in p["relocs"] for i in range(n)),
          "each cell's bank byte is a reloc to its segment")
    ln = struct.unpack_from("<H", seg0, t + 2 + 4 * n)[0]
    check(seg0[t + 4 + 4 * n:t + 4 + 4 * n + ln] == tr["IMPS"],
          "the IMPS table follows, as the trailer has it")
    check(struct.unpack_from("<H", tr["ENTR"], 0)[0] == ex["_crt0_lib"]
          and struct.unpack_from("<H", data, 8)[0] == ex["_crt0_dyn"],
          "the header enters _crt0_dyn; ENTR names _crt0_lib")
```

and the block layout's three copies held equal:

```python
def block_offsets():
    """crt0_dyn.s's B_* offsets equal ld.mod's (both read ldctl.h's layout)."""
    def equs(path):
        return {m.group(1): int(m.group(2)) for m in re.finditer(
            r"^(B_\w+)\s+EQU\s+(\d+)", open(path).read(), re.M)}
    dyn_ = equs(os.path.join(ROOT, "lib", "crt0_dyn.s"))
    mod = equs(os.path.join(REPO, "src", "modules", "ld", "ld.s"))
    check(dyn_ and all(mod.get(k) == v for k, v in dyn_.items()),
          "crt0_dyn's block offsets are ld.mod's", str(dyn_))
```

(`test_dyn.py`'s `link(src, libs, name)` returns `(rc, text, bytes, linkdir)`; use the names the file already has for the repo and toolchain roots.) In `test_bind.py` add:

```python
def digest():
    """fgx_bind's digest of a prebound bind is stable and changes when one
    site's word does."""
    hello = os.path.join(tempfile.mkdtemp(prefix="bind_dg_"), "hello.dyn")
    rc, _t, data, _d = test_dyn.link(os.path.join(HERE, "hello.c"), "libc", "hello")
    open(hello, "wb").write(data)
    img, _e, rep = fgx_bind.bind(hello, fgx_libso.LIB)
    table = fgx_imports.unpack(fgx_ld.read_dyn_trailer(
        fgx_bind.parse(open(hello, "rb").read())["trailer"])["blocks_raw"]["IMPS"])
    a, n = fgx_bind.digest(img, table, rep)
    check(n > 0, "the digest walks the sites", str(n))
    s, o = next((s, o) for im in table["imports"] for s, o in im["call"])
    img.segs[s][o] ^= 1
    check(a != fgx_bind.digest(img, table, rep)[0], "the digest sees one site's word")
```

and, in `test_dyn.py`, the full-segment case (spec 9's host tests):

```python
def full_seg0():
    """A segment 0 with no room for the tables is refused, naming
    sub-project 5."""
    head = bytearray(16)
    head[6], head[7] = 2, 1
    body = bytes(head) + struct.pack("<HHB3x", 65530, 0, 0) + \
        struct.pack("<HHB3x", 4, 0, 1) + b"\0" * 65530 + b"\0" * 4
    try:
        fgx_dyn.with_tables(body, len(body), b"\0" * 64)
    except SystemExit as e:
        check("sub-project 5" in str(e), "a full segment 0 is refused", str(e))
    else:
        check(False, "a full segment 0 is refused")
```

and call each from its file's main sequence. Run `make -s -C toolchain test-archives`; Expected: FAIL (`_dyn_loc` / `digest` missing).

- [ ] **Step 2: crt0_dyn's locator and a pass-through entry**

`toolchain/lib/crt0_dyn.s` (Task 3 replaces the entry's body):

```
;==============================================================================
; crt0_dyn.s - the startup of a dynamic program (fgx_dyn): it binds the
; program to its shared libraries on the machine, then continues as
; crt0_lib.s.  fgx_dyn appends the segment-bank table and the IMPS table to
; segment 0 and patches their offset into _dyn_loc's operand.
;==============================================================================
                FGX2_EXPORT _crt0_dyn
_crt0_dyn       MX      %11
                REP     #$30
                MX      %00
                FGX2_EXPORT _dyn_loc
_dyn_loc        LDA     #$0000                  ; the tables' offset (fgx_dyn)
                JMP     _crt0_lib
```

- [ ] **Step 3: fgx_dyn**

Link `crt0_dyn.s` first in segment 0 (`[MACROS, "seg1_layout.s", "imports_layout.s", CRT0_DYN, fgx_static.CRT0] + code + ...`, with `CRT0_DYN = os.path.join(LIB, "crt0_dyn.s")`), take the entry from `_crt0_dyn`, and add `("SYS_LDCTL", "8")` to the segment-0 EQUs fgx_dyn passes. `dyn.data.s` gains:

```python
           "_dyn_blk        DS      50\n"
           "_dyn_nolibc     ASC     'ld.so: libc.so.1 not loaded'\n"
           "                HEX     0A\n"
```

After the trailer is built (where `build` writes `out`), append the tables instead of writing `a[:end_a] + trailer` directly:

```python
def with_tables(a, end_a, imps):
    """The linked program with the segment-bank table and IMPS appended to
    segment 0, their offset in _dyn_loc's operand, and ENTR in the trailer."""
    p = fgx_bind.parse(a[:end_a] + fgx_ld.dyn_trailer(b""))
    segs = [bytearray(s) for s, _b, _k in p["segs"]]
    t = len(segs[0])
    n = len(segs)
    tab = struct.pack("<H", n) + b"\0\0\0\0" * n + struct.pack("<H", len(imps)) + imps
    if t + len(tab) > 0xFFFF:
        die("segment 0 has no room for the binder's tables (%d bytes); a "
            "program that large links through the tool build (sub-project 5)"
            % len(tab))
    segs[0] += tab
    relocs = sorted(set(p["relocs"]) | {(0, t + 2 + 4 * i + 2, i) for i in range(n)})
    head = bytearray(p["head"])
    struct.pack_into("<H", head, 11, len(relocs))
    body = bytes(head)
    for (s, b, k), seg in zip(p["segs"], segs):
        body += struct.pack("<HHB3x", len(seg), b, k)
    body += b"".join(bytes(s) for s in segs)
    body += b"".join(struct.pack("<BHB", *r) for r in relocs)
    return body, t
```

Then, with `ex` the seg0 listing's exports (`fgx_ld.scan_listing(os.path.join(d, "seg0_Output.txt"), 2, libc=True)["exports"]`):

```python
    body, t = with_tables(a, end_a, fgx_imports.pack(table))
    body = bytearray(body)
    seg0_at = 16 + 8 * a[6]
    struct.pack_into("<H", body, seg0_at + ex["_dyn_loc"] + 1, t)
    trailer = fgx_ld.dyn_trailer(fgx_ld.block(b"IMPS", fgx_imports.pack(table))
                                 + fgx_ld.block(b"ENTR", struct.pack("<H", ex["_crt0_lib"])))
    # write body + trailer through the existing tmp/rename
```

The binder's frames: `bitmaps(libs, roots | {"ld_bind"})` for the `live` (frames) result only -- keep `bits`/`need` from the call without it -- so `stack_frames` charges the binder and the load path, which crt0 enters through the registry, not by name (spec 5.1). The root is the C function `ld_bind` (a unit in `libc_so.s`, which `bitmaps` searches), not the asm entry `_ld_bind` (bank-0 hand-written code, which it does not); it reaches nothing until Task 3 defines `ld_bind`, and Task 3's host test proves it does then.

- [ ] **Step 4: fgx_bind**

`bind()` reads the program's trailer already (`fgx_ld.read_dyn_trailer(prog["trailer"])`); keep its blocks and return `ENTR` with the entry -- the last line becomes:

```python
    raw = fgx_ld.read_dyn_trailer(prog["trailer"])["blocks_raw"]
    entry = struct.unpack_from("<H", raw["ENTR"], 0)[0] if "ENTR" in raw else \
        struct.unpack_from("<H", prog["head"], 8)[0]
    report["table"] = table
    return img, entry, report
```

(`main` already passes bind's entry to `startup`.) `bind_sites` gains a `segs_out` argument (a dict, or None): for each code import of the object being bound it records `segs_out[im["name"]] = seg`, the library code segment its bank byte names. `bind` calls it with `report["segs"] = {}` for the program (and None for the libraries' own imports). Then:

```python
def rotl(v, n):
    n &= 15
    return ((v << n) | (v >> (16 - n))) & 0xFFFF if n else v


def digest(img, table, report):
    """The binding's digest (shared libc SP4 spec, section 9): in IMPS
    order, each site's word after binding, and for a call or a pointer its
    bank normalised to 16 * (the import's library index) + (the library
    code segment it names).  (digest, sites walked)."""
    h = n = 0
    for im in table["imports"]:
        for k in fgx_imports.SITES:
            for s, o in im[k]:
                n += 1
                bs = bytes(img.segs[s][o:o + 2])
                if k != "data":
                    bs += bytes([16 * im["lib"] + report["segs"][im["name"]]])
                for x in bs:
                    h = rotl(h, 1) ^ x
    return h, n
```

and `main` takes `--digest`: bind as usual, print `LDB sites %04x n=%d` of `digest(img, rep["table"], rep)`, and write no image.

- [ ] **Step 5: Run, and the bound probes**

Run: `make -s -C toolchain test-archives > $S/t2_host.log 2>&1; tail -3 $S/t2_host.log; ninja > $S/t2_build.log 2>&1; tools/mame_test/run.py dynso cursso dynsomis dynsonodata`
Expected: host tests pass; `dynso`, `cursso`, `dynsomis` pass and `dynsonodata` passes as it does today (its expected failure), fresh -- the bound images now carry crt0_dyn and the tables and still enter `_crt0_lib`.

- [ ] **Step 6: Gate, commit**

Run `tools/gate.sh`; Expected `GATE GREEN`.

```bash
git add toolchain/lib/crt0_dyn.s toolchain/src/ld/fgx_dyn.py toolchain/src/ld/fgx_bind.py \
        toolchain/tests/dyn/test_dyn.py toolchain/tests/dyn/test_bind.py
git commit -F - <<'EOF'
feat(fgx_dyn): the binder's tables in segment 0, and crt0_dyn's locator

A dynamic program enters at crt0_dyn.s, linked ahead of crt0_lib.s.
fgx_dyn appends to segment 0 a table of the program's segments -- one
4-byte cell each, whose bank byte the loader fills, as it fills any
long pointer -- and the IMPS table, and patches their offset into the
operand of crt0_dyn's `LDA #': crt0 finds them with no data access and
no reloc, in its own bank.  The trailer gains ENTR, _crt0_lib's
offset, where fgx_bind's startup now jumps.  fgx_bind --digest prints
the binding's digest -- each site's word, and each call's and pointer's
bank as (library, segment) -- for the machine binder to match.
EOF
```

---

### Task 3: crt0_dyn and the binder -- dynso runs dynamic

**Files:**
- Modify: `toolchain/lib/crt0_dyn.s` (the whole startup)
- Modify: `toolchain/lib/ld_bind_asm.s` (`_ld_bind`)
- Create: `toolchain/lib/libc_c/ld_bind.c`; Modify: `toolchain/lib/libc_c/libc_c.c` (`#include "ld_bind.c"` after `"ld_load.c"`)
- Modify: `src/userland/dynso/dynso.c` (`DSO_SHARED` checks), `tools/dynso-fgx2/build_dynso.sh` (`dynsodyn`, `dyntrue`), `tools/ninja/gen.py`, `tools/ninja/manifest.json`
- Create: `src/userland/dyntrue/dyntrue.c`, `tools/mame_test/tests/dynsodyn.json`

**Interfaces:**
- Consumes: Task 1's `_ld_patch`, `struct ld_seg`, XIDX; Task 2's tables and locator; step 2's `ld_need`, `ld_ctl`, `struct ld_work`.
- Produces: libc export `_ld_bind(frame, tab, copy, blk)` -- `frame` the offset in bank 0 of the kernel's argv frame (argc there, argv's 16-bit pointers after), `tab` a far pointer to Task 2's table, `copy` crt0's `_lib_copy`, `blk` libc's row as crt0's ACQUIRE left it (`_dyn_blk`, the data bank); returns 0 with every needed library resident, bound and its core copied, `HEAP_LIM` set; exits 1 with an `ld.so:` message otherwise; under `LD_TRACE_LOADED_OBJECTS` or `LD_BIND_DIGEST` prints and exits 0 (Task 4 adds those two).

- [ ] **Step 1: The failing probe**

`src/userland/dyntrue/dyntrue.c`:

```c
/* dyntrue -- true(1) linked dynamically: the exec budget's subject
 * (shared libc SP4 spec, section 8). */
main()
{
    return 0;
}
```

`dynso.c`: under `#ifdef DSO_SHARED`, three checks before `DSO ok`:

```c
#ifdef DSO_SHARED
    {
        extern char *getenv();
        static struct ldblk lb;
        unsigned long a;
        int i, ok;

        say("env", getenv("DSO_ENV") != (char *)0 && strcmp(getenv("DSO_ENV"), "yes") == 0);
        strcpy(lb.name, "libc");
        lb.major = 1;
        a = (unsigned long)(char *)&lb;
        __syscall(SYS_LDCTL, LDS_LOOKUP, (unsigned)a, (unsigned)(a >> 16));
        for (ok = 0, i = 0; i < lb.nbanks; i++)     /* cmpf's bank: the cell the */
            ok |= lb.banks[i] == ((unsigned char *)&cmpf)[2];   /* binder patched */
        say("shared", ok);                         /* libc's resident banks */
        pid = fork();
        if (pid == 0) {
            execl("/testbin/dyntrue", "dyntrue", (char *)0);
            _exit(9);
        }
        wait(&st);
        say("exec", st == 0);
    }
#endif
```

(add `#include <sys/ldctl.h>`; `pid`/`st` as the file's fork check declares them). `build_dynso.sh`: names `dynsodyn` (src `dynso/dynso.c`, libs `libc`, fcc `-DDSO_SHARED`) and `dyntrue` (src `dyntrue/dyntrue.c`, libs `libc`): link with fgx_dyn and copy `$name.dyn` to `$name.bin` with no bind. gen.py entries beside `dynso` (same `extra`/`hard` plus `toolchain/lib/crt0_dyn.s`), manifest staging to `/testbin/dynsodyn` and `/testbin/dyntrue`.

In `toolchain/tests/dyn/test_dyn.py`, the binder's frames (spec 5.1, 9):

```python
def binder_frames():
    """The root `ld_bind' reaches the binder and the load path in libc's
    library-mode code, so stack_frames charges them."""
    libs = fgx_dyn.Libs(["libc"])
    _b, _n, live = fgx_dyn.bitmaps(libs, {"ld_bind"})
    labels = {r.split()[0] for sect in live["libc"] for r in sect if r[:1].strip()}
    check({"ld_bind", "ld_need"} <= labels, "ld_bind reaches the load path",
          str(sorted(labels & {"ld_bind", "ld_need", "ld_fill"})))
```

`tools/mame_test/tests/dynsodyn.json`:

```json
{
 "name": "dynsodyn",
 "description": "Shared libc SP4: dynso linked dynamically and bound on the machine (crt0_dyn, libc's binder): libcso's checks, a pointer cell, &errno, a far helper, the carve below the copied core, an environment variable, libc's resident banks under strcmp, an exec of a dynamic dyntrue; then libc's user count back to one.",
 "command": "DSO_ENV=yes /testbin/dynsodyn; /testbin/ldctl look libc",
 "timeout_s": 180,
 "expect": {
  "screen_contains": ["DSO ok", "LDC look users=0"],
  "screen_lacks": ["DSO FAIL", "ld.so:", "libc: no room", "PANIC", "BRK"]
 }
}
```

(After dynsodyn and its exec'd dyntrue exit, no process uses libc -- ldload, its loader, exited at boot and the shell is static -- so the row's count is 0: `ldctl look libc` prints `LDC look users=0`, and an exit hook that missed either process leaves it at 1 or 2.)

Run: `python3 tools/ninja/gen.py >/dev/null && ninja > $S/t3_red.log 2>&1; tools/mame_test/run.py dynsodyn`
Expected: FAIL (crt0_dyn jumps straight to `_crt0_lib`, whose first libc call has no bank: a crash or `BRK`).

- [ ] **Step 2: crt0_dyn**

Replace the entry in `crt0_dyn.s` (the locator stays the operand of an `LDA #`, now where crt0 pushes it):

```
; The registry's block as crt0 reads it.  toolchain/include/sys/ldctl.h is
; the layout; src/modules/ld/ld.s carries the same offsets, and the host
; test test_dyn.py holds these three copies equal.
LDS_ACQUIRE     EQU     0
LDS_ABORT       EQU     3
B_MAJOR         EQU     16
B_NBANKS        EQU     23
B_BANKS         EQU     24
B_COREBASE      EQU     32
B_CORESIZE      EQU     34
B_TMPL          EQU     36
B_BINDER        EQU     42

                FGX2_EXPORT _crt0_dyn
_crt0_dyn       MX      %11
                REP     #$30
                MX      %00
                TSC
                INC
                PHA                             ; 1,S = the kernel's argv frame
                ; Nothing on the binder's path takes a soft frame (no
                ; recursion), so _fcc_sfp waits for crt0_lib.s.
                ; ACQUIRE libc 1.  READY is the only answer that goes on.
                LDX     #48
@cd_zero        STZ     _dyn_blk,X
                DEX
                DEX
                BPL     @cd_zero
                SEP     #$20
                MX      %10
                LDA     #'l'
                STA     _dyn_blk
                LDA     #'i'
                STA     _dyn_blk+1
                LDA     #'b'
                STA     _dyn_blk+2
                LDA     #'c'
                STA     _dyn_blk+3
                LDA     #1
                STA     _dyn_blk+B_MAJOR
                PHB
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                TAY                             ; Y = the block's bank, this data bank
                LDX     #_dyn_blk
                LDA     #LDS_ACQUIRE
                JSL     SYS_TRAMP
                DFB     SYS_LDCTL
                BCC     @cd_nolibc              ; ENOSYS, EINTR: not usable
                CMP     #0
                BNE     @cd_absent              ; 1: nobody has loaded libc
                LDA     _dyn_blk+B_BINDER
                ORA     _dyn_blk+B_BINDER+1
                BEQ     @cd_nolibc              ; a libc with no binder
                ; libc's core into this data bank: _lib_copy(dst, src, n).
                LDA     _dyn_blk+B_CORESIZE
                PHA                             ; n
                LDA     _dyn_blk+B_NBANKS
                AND     #$00FF
                DEC
                TAX
                LDA     _dyn_blk+B_BANKS,X      ; the last bank, low byte
                AND     #$00FF
                PHA                             ; src's bank word
                LDA     _dyn_blk+B_TMPL
                PHA                             ; src's offset
                SEP     #$20
                MX      %10
                PHB
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                PHA                             ; dst's bank word
                LDA     _dyn_blk+B_COREBASE
                PHA                             ; dst's offset
                FGX2_FARCALL _lib_copy
                TSC
                CLC
                ADC     #10
                TCS
                ; The binder: _ld_bind(frame, tab, copy, blk), through the row.
                ; blk is libc's row as ACQUIRE left it, so the binder needs
                ; no syscall for libc.
                SEP     #$20
                MX      %10
                PHB
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                PHA                             ; blk's bank word: this data bank
                PEA     _dyn_blk                ; blk
                SEP     #$20
                MX      %10
                PHK
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                PHA                             ; copy's bank word
                PEA     _lib_copy               ; copy
                SEP     #$20
                MX      %10
                PHK
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                PHA                             ; tab's bank word
                FGX2_EXPORT _dyn_loc
_dyn_loc        LDA     #$0000                  ; the tables' offset (fgx_dyn)
                PHA                             ; tab
                LDA     13,S                    ; the frame slot, under 12 bytes
                PHA                             ; frame
                PHK
                PEA     @cd_back-1              ; the return a JSL would push
                SEP     #$20
                MX      %10
                LDA     _dyn_blk+B_BINDER+2
                PHA
                REP     #$20
                MX      %00
                LDA     _dyn_blk+B_BINDER
                DEC
                PHA
                RTL                             ; JSL [binder]
@cd_back        MX      %00
                TSC
                CLC
                ADC     #16                     ; 14 bytes of arguments, the frame slot
                TCS
                JMP     _crt0_lib
@cd_absent      MX      %00
                LDX     #_dyn_blk
                SEP     #$20
                MX      %10
                PHB
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                TAY
                LDA     #LDS_ABORT
                JSL     SYS_TRAMP
                DFB     SYS_LDCTL
@cd_nolibc      MX      %00
                LDA     #2
                LDX     #_dyn_nolibc
                LDY     #28
                JSL     SYS_TRAMP
                DFB     SYS_WRITE
                LDA     #1
                JSL     SYS_TRAMP
                DFB     SYS_EXIT
@cd_stop        BRA     @cd_stop
```

The stack at `LDA 13,S`: the frame slot was pushed first, then blk (4), copy (4), tab's bank word (2) and tab (2): the slot is at 13,S. Check every offset against the push sequence once more as you write it, and `_dyn_nolibc`'s length (27 characters and the newline). Read how `SYS_WRITE` takes its arguments in `crt0_lib.s`'s neighbours (`grep -n SYS_WRITE toolchain/lib/*.s`) before trusting A/X/Y here.

- [ ] **Step 3: _ld_bind and ld_bind.c**

Append to `ld_bind_asm.s`:

```
;------------------------------------------------------------------------------
; _ld_bind(frame, tab, copy, blk) - the binder's entry, from crt0_dyn through
; the registry's binder field.  libc's _fcc_dbr, a cell in libc's core, which
; crt0 has just copied into this data bank, is seeded first: the C binder
; converts ints to pointers before _libc_start would.  Then ld_bind, with
; the caller's frame (a tail jump: its arguments and return stay put).
;------------------------------------------------------------------------------
                FGX2_EXPORT _ld_bind
_ld_bind        MX      %00
                SEP     #$20
                MX      %10
                PHB
                PLA
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     _fcc_dbr
                FGX2_FARJUMP ld_bind
```

`toolchain/lib/libc_c/ld_bind.c`:

```c
/*
 * ld_bind -- bind a dynamic program to its shared libraries on the machine
 * (shared libc SP4 spec, section 5.3): each needed library resident (loaded
 * on first use by ld_need), the program's sites patched -- the recorded
 * values when the library's export CRC is the recorded one, else each name
 * through the library's export index -- each needed core copied into this
 * data bank with its per-process fixups set, HEAP_LIM lowered to the
 * lowest.  crt0_dyn has already copied libc's core, and hands over libc's
 * row as its ACQUIRE left it; _ld_bind seeded libc's _fcc_dbr.
 *
 * Per exec this is the cost a dynamic program pays over a static one
 * (spec section 8), so libc costs no syscall, a library's row comes from
 * the ACQUIRE or COMMIT that made it resident, each library's tagged
 * blocks are walked once, and its block table's address is the program's
 * own import of _<lib>_blktab.
 *
 * No statics and no stdio: this process's blocks do not exist yet.  Its
 * struct ld_work sits above the break, the room up to libc's core its
 * buffer, which only a first-use load reads; ld_load refuses a load that
 * does not fit it.  Messages are SunOS 4.1.3 rtld's (lang/rtld/rtld.c).
 */
#define LB_NLIB     4
#define LB_NSEG     10

struct lb_lib {
    char name[16];
    unsigned char major, minor, pre, loaded, last, rows;
    unsigned char crc[4];
    unsigned char banks[LD_MAXBANKS];
    unsigned base, abase, csize, tmpl, recbase, nexp, nfix, blktab;
    unsigned char *bits, *expt, *xidx, *fixs;
};

static char *
lb_far(bank, off)
unsigned bank, off;
{
    return (char *)(((unsigned long)bank << 16) | off);
}

/* The library's row (`b', as ACQUIRE or COMMIT left it) into L, and its
 * tagged blocks -- EXPT, FIXS, XIDX up to END -- found once.  0 if the chain
 * is not well formed within the bank. */
static int
lb_row(L, b)
struct lb_lib *L;
struct ldblk *b;
{
    unsigned char *p;
    unsigned at, n, k;

    for (k = 0; k < LD_MAXBANKS; k++)
        L->banks[k] = b->banks[k];
    L->last = b->banks[b->nbanks - 1];
    L->base = b->core_base;
    L->csize = b->core_size;
    L->tmpl = b->tmpl_off;
    L->minor = b->minor;
    for (L->pre = 1, k = 0; k < 4; k++)
        if (b->crc[k] != L->crc[k])
            L->pre = 0;
    L->expt = L->xidx = L->fixs = (unsigned char *)0;
    for (at = b->expt_off; at < 0xFFF8; at += 8 + n) {
        p = (unsigned char *)lb_far(L->last, at);
        n = ld_rd16(p + 4);
        if (p[0] == 'E' && p[1] == 'N' && p[2] == 'D')
            break;
        if (p[0] == 'E' && p[1] == 'X')
            L->expt = p + 8;
        else if (p[0] == 'F' && p[1] == 'I') {
            L->fixs = p + 8;
            L->nfix = n / 2;
        } else if (p[0] == 'X' && p[1] == 'I')
            L->xidx = p + 8;
        if ((unsigned long)at + 8 + n > 0xFFF8L)
            return 0;
    }
    if (L->expt == 0 || L->xidx == 0 || at >= 0xFFF8)
        return 0;
    L->abase = ld_rd16(L->xidx);
    L->nexp = ld_rd16(L->xidx + 2);
    return b->rows == L->rows ? 1 : -1;
}

static int
lb_cmp(r, name, n)
unsigned char *r, *name;
int n;
{
    int i;

    for (i = 0; i < r[0] && i < n; i++)
        if (r[1 + i] != name[i])
            return r[1 + i] < name[i] ? -1 : 1;
    return r[0] < n ? -1 : r[0] > n;
}

/* The export `name' (n bytes): its recorded ordinal first, then a binary
 * search of EXPT's sorted names through the index. */
static unsigned char *
lb_find(L, ordinal, name, n)
struct lb_lib *L;
unsigned ordinal;
unsigned char *name;
int n;
{
    unsigned char *r;
    unsigned lo, hi, mid;
    int c;

    if (ordinal < L->nexp) {
        r = L->expt + ld_rd16(L->xidx + 4 + 2 * ordinal);
        if (lb_cmp(r, name, n) == 0)
            return r;
    }
    lo = 0;
    hi = L->nexp;
    while (lo < hi) {
        mid = (lo + hi) / 2;
        r = L->expt + ld_rd16(L->xidx + 4 + 2 * mid);
        c = lb_cmp(r, name, n);
        if (c == 0)
            return r;
        if (c < 0)
            lo = mid + 1;
        else
            hi = mid;
    }
    return (unsigned char *)0;
}

/* "ld.so: <a><b><c>\n" on fd 2 (b: n bytes, up to 40), then exit 1. */
static void
lb_die(w, a, b, n, c)
struct ld_work *w;
char *a, *c;
unsigned char *b;
int n;
{
    char *p;
    int i;

    p = ld_cat(w->msg, "ld.so: ");
    p = ld_cat(p, a);
    for (i = 0; b && i < n && i < 40; i++)
        *p++ = b[i];
    p = ld_cat(p, c);
    *p++ = '\n';
    write(2, w->msg, p - w->msg);
    _exit(1);
}

static int
lb_len(s)
char *s;
{
    int n;

    for (n = 0; s[n]; n++)
        ;
    return n;
}

static char *
lb_hex(p, v, n)
char *p;
unsigned v;
int n;
{
    while (n--)
        *p++ = "0123456789abcdef"[(v >> (4 * n)) & 15];
    return p;
}

/* Does import `nm' (n bytes) name library L's block table, _<lib>_blktab? */
static int
lb_isbt(L, nm, n)
struct lb_lib *L;
unsigned char *nm;
int n;
{
    int k, ln;

    ln = lb_len(L->name);
    if (n != ln + 8 || nm[0] != '_')
        return 0;
    for (k = 0; k < ln; k++)
        if (nm[1 + k] != L->name[k])
            return 0;
    return nm[1 + ln] == '_' && nm[2 + ln] == 'b' && nm[3 + ln] == 'l' &&
           nm[4 + ln] == 'k' && nm[5 + ln] == 't' && nm[6 + ln] == 'a' &&
           nm[7 + ln] == 'b';
}

int
ld_bind(frame, tab, copy, blk)
unsigned frame;
unsigned char *tab;
int (*copy)();
struct ldblk *blk;
{
    struct lb_lib lib[LB_NLIB];
    struct ld_seg seg[LB_NSEG];
    struct lb_lib *L;
    struct ld_work *w;
    unsigned long bank;
    unsigned brk, at0, lowest, need, nseg, i, k, c, n, val, delta, ni, ord, at;
    unsigned char *p, *r, *s, *e, *nm, *bt;
    char *prog, *q;
    int nlib, li, kind, sg, rr, isc;

    bank = (unsigned long)(char *)&errno & 0xFF0000L;  /* libc's core: this data bank */
    brk = *(unsigned *)(bank | 0xFFFEL);                 /* HEAP_BRK, the data's end */
    prog = (char *)(unsigned long)((unsigned *)(unsigned long)frame)[1];  /* argv[0] */
    at0 = (brk + 1) & 0xFFFE;
    w = (struct ld_work *)(bank | at0);
    if ((unsigned long)at0 + sizeof *w >= blk->core_base)
        lb_die(w, "", (unsigned char *)prog, lb_len(prog), ": no room for its data");
    w->buf = (char *)w + sizeof *w;
    w->bufsz = blk->core_base - (at0 + sizeof *w);

    nseg = ld_rd16(tab);
    if (nseg > LB_NSEG)
        lb_die(w, "", (unsigned char *)prog, lb_len(prog), ": too many segments");
    for (i = 0; i < nseg; i++) {
        seg[i].off = ld_rd16(tab + 2 + 4 * i);
        seg[i].bank = tab[2 + 4 * i + 2];
    }
    p = tab + 4 + 4 * nseg;                             /* IMPS */

    /* The libraries, in load order: each resident, its row read. */
    nlib = *p++;
    if (nlib > LB_NLIB)
        lb_die(w, "", (unsigned char *)prog, lb_len(prog), ": needs too many libraries");
    for (li = 0; li < nlib; li++) {
        L = &lib[li];
        n = *p++;
        for (k = 0; k < n && k < 15; k++)
            L->name[k] = p[k];
        L->name[k] = 0;
        p += n;
        L->major = p[0];
        for (k = 0; k < 4; k++)
            L->crc[k] = p[2 + k];
        L->recbase = ld_rd16(p + 6);
        L->rows = p[8];
        L->bits = p + 9;
        L->blktab = 0;
        isc = L->name[0] == 'l' && L->name[1] == 'i' && L->name[2] == 'b' &&
              L->name[3] == 'c' && L->name[4] == 0 && L->major == 1;
        if (isc) {                                      /* crt0's ACQUIRE */
            L->loaded = 0;
            rr = lb_row(L, blk);
        } else {
            rr = ld_need(w, L->name, L->major, p[1], 0);
            if (rr < 0)
                _exit(1);                               /* ld_need said why */
            L->loaded = rr == 1;
            rr = lb_row(L, &w->blk);                    /* ACQUIRE's or COMMIT's row */
        }
        if (rr == 0)
            lb_die(w, "", (unsigned char *)L->name, lb_len(L->name),
                   ": a bad export table");
        if (rr < 0) {
            q = ld_cat(w->path, L->name);               /* lb_die builds in msg */
            q = ld_cat(q, ": ");
            *q = 0;
            lb_die(w, w->path, (unsigned char *)prog, lb_len(prog), " needs relinking");
        }
        p += 9 + (p[8] + 7) / 8;
    }

    /* The imports: their records, then their sites, two cursors. */
    ni = ld_rd16(p);
    r = p + 2;
    for (s = r, i = 0; i < ni; i++)
        s += 4 + s[3] + 6;
    for (i = 0; i < ni; i++) {
        li = r[0];
        ord = ld_rd16(r + 1);
        n = r[3];
        nm = r + 4;
        kind = r[4 + n];
        sg = r[5 + n];
        val = ld_rd16(r + 6 + n);
        L = &lib[li];
        if (L->pre)
            delta = L->base - L->recbase;
        else {
            e = lb_find(L, ord, nm, n);
            if (e == 0 || e[1 + e[0]] != kind ||
                (kind == 1 && ld_rd16(e + 1 + e[0] + 4) < ld_rd16(r + 8 + n)))
                lb_die(w, "Undefined symbol: ", nm, n, "");
            at = ld_rd16(e + 1 + e[0] + 2);
            if (kind == 0) {
                sg = e[1 + e[0] + 1];
                val = at;
            } else
                delta = at + (L->base - L->abase) - val;
        }
        if (kind == 1 && lb_isbt(L, nm, n))
            L->blktab = val + delta;                    /* where its table now is */
        r += 4 + n + 6;
        for (k = 0; k < 3; k++) {                       /* call, ptr, data */
            c = ld_rd16(s);
            s += 2;
            if (c && (kind == 0) != (k < 2))
                lb_die(w, "", (unsigned char *)prog, lb_len(prog),
                       ": a bad import table");
            if (c)
                _ld_patch(s, c, seg, kind, kind == 0 ? val : delta,
                          kind == 0 ? L->banks[sg] : 0);
            s += 3 * c;
        }
    }

    /* The cores: each but libc's copied (crt0 copied libc's), every
     * core's per-process fixups set to this data bank; the fit, the data's
     * end below the lowest core less the blocks the bitmaps reach. */
    lowest = 0xFFF8;
    need = 0;
    for (li = 0; li < nlib; li++) {
        L = &lib[li];
        if (L->base < lowest)
            lowest = L->base;
        if (li != 0 || L->name[3] != 'c' || L->name[4] != 0)
            (*copy)(lb_far((unsigned)(bank >> 16), L->base),
                    lb_far(L->last, L->tmpl), L->csize);
        for (k = 0; k < L->nfix; k++)
            *(unsigned char *)(bank | (unsigned long)(L->base + ld_rd16(L->fixs + 2 * k))) =
                (unsigned char)(bank >> 16);
        if (L->blktab == 0)
            lb_die(w, "", (unsigned char *)prog, lb_len(prog), ": a bad import table");
        bt = (unsigned char *)(bank | (unsigned long)L->blktab);
        for (k = 0; ld_rd16(bt + 8 * k); k++)
            if (L->bits[k >> 3] & (1 << (k & 7)))
                need += ld_rd16(bt + 8 * k + 6);
    }
    if (brk > lowest - need) {
        q = ld_cat(w->path, ": no room for its data (ends $");
        q = lb_hex(q, brk, 4);
        q = ld_cat(q, ", LIM $");
        q = lb_hex(q, lowest - need, 4);
        q = ld_cat(q, ")");
        *q = 0;
        lb_die(w, "", (unsigned char *)prog, lb_len(prog), w->path);
    }
    *(unsigned *)(bank | 0xFFF8L) = lowest;             /* HEAP_LIM */
    return 0;
}
```

Notes for the implementer, each a place fcc will not warn:
- `frame` is an offset in bank 0, so `(unsigned long)frame` is a bank-0 address, and argv's strings are bank-0 too.
- The data bank is `&errno`'s (libc's core, which crt0 copied here), never `tab`'s or `copy`'s, which are segment 0's; `blk` is in the data bank (`_dyn_blk`).
- libc is the first IMPS library of every dynamic program (fgx_dyn's `Libs` order); the copy skip tests `li == 0` and the name.
- `lb_die` builds in `w->msg`, so the two callers that assemble a part first do it in `w->path` (48 bytes: the longest, the "no room" text with both hex values, is 37).
- The block table's rows are four words (cell, template offset, template bank, size; `libc_init.c`'s header) and end at a zero cell.
- This file shares `ld_rd16`, `ld_cat`, `ld_need` with `ld_load.c` (one TU, included after it).
- If fcc rejects a construct, fix fcc with a fixture (CLAUDE.md), not this file.

- [ ] **Step 4: Run**

Run: `python3 tools/ninja/gen.py >/dev/null && ninja > $S/t3_build.log 2>&1; tools/mame_test/run.py dynsodyn dynso cursso ldload`
Expected: `4 passed`, fresh; the stack hint (header byte 14) of `dynsodyn` is at least the static `dynso`'s plus the binder's frames (`xxd -s 14 -l 1` on both).

- [ ] **Step 5: Controls**

(b) In crt0_dyn, skip libc's core copy: `dynsodyn` FAILs or crashes. Restore, `ninja`. (Skipping the data-site patch cannot fail here: libc loads at its link base, so every prebound delta is 0. That control runs on `dynsomisdyn` in Task 4.)

- [ ] **Step 6: Gate, commit**

Run `tools/gate.sh`; Expected `GATE GREEN`.

```bash
git add toolchain/lib/crt0_dyn.s toolchain/lib/ld_bind_asm.s toolchain/lib/libc_c/ld_bind.c \
        toolchain/lib/libc_c/libc_c.c src/userland/dynso/dynso.c src/userland/dyntrue \
        tools/dynso-fgx2/build_dynso.sh tools/ninja/gen.py tools/ninja/manifest.json \
        tools/mame_test/tests/dynsodyn.json
git commit -F - <<'EOF'
feat(libc): bind a dynamic program on the machine

A dynamic program's crt0 (crt0_dyn.s) ACQUIREs libc from the registry --
READY or nothing: "ld.so: libc.so.1 not loaded" -- copies libc's core
into its data bank with its own MVN copier, and calls libc's binder
through the row's entry.  _ld_bind seeds libc's _fcc_dbr and ld_bind
makes each needed library resident (ld_need loads one on first use),
patches the program's sites through the asm loop -- the recorded values
when the library's export CRC is the recorded one, else each name
through the export index -- copies each other core and sets every
core's per-process fixups to this data bank, checks the fit and lowers
HEAP_LIM.  Then crt0_lib.s's path runs as before.

dynsodyn is dynso linked dynamically and run with no host binding;
dyntrue is true(1) the same way.
EOF
```

---

### Task 4: by name, the digest, the trace, and ldd

**Files:**
- Modify: `toolchain/lib/libc_c/ld_bind.c` (`LD_TRACE_LOADED_OBJECTS`, `LD_BIND_DIGEST`)
- Create: `src/userland/ldd/ldd.c`, `vendor/SunOS-4.1.3/bin/ldd.c` (vendored from `examples/`), `src/userland/man/pages/cat1/ldd.0`
- Modify: `tools/dynso-fgx2/build_dynso.sh` (`dynsomisdyn`; each `*dyn` gets a host digest file), `tools/ninja/gen.py`, `tools/ninja/manifest.json`
- Create: `tools/mame_test/tests/dynsomisdyn.json`, `tools/mame_test/tests/lddigest.json`, `tools/mame_test/tests/ldd.json`

**Interfaces:**
- Consumes: Task 2's digest definition and `fgx_bind.py --digest`; Task 3's binder.

- [ ] **Step 1: The failing probes**

`fgx_dyn.py` gains `--so NAME=PATH` (repeatable), as fgx_bind has: `Libs(names, override)` takes `so = override.get(n, fgx_libso.so_path(n))`, and the core listing beside it (`os.path.join(os.path.dirname(so), "ld", "core_Output.txt")` for an override -- `build_dynso.sh` builds `mis/libc.so.1.0` with `--dir mis/ld`). `build_dynso.sh`: `dynsomisdyn` = `dynso.c` with `-DDSO_SHARED`, linked by fgx_dyn `--so libc=mis/libc.so.1.0` (a libc whose core is two bytes larger, so its CRC and every data address differ from the resident one), no bind; and for `dynsodyn` and `dynsomisdyn`, `python3 "$LD/fgx_bind.py" --prog "$name.bin" --digest > "$name.digest"` against the real `toolchain/lib` (what the machine has resident), staged beside the binary.

`tools/mame_test/tests/dynsomisdyn.json`: command `DSO_ENV=yes /testbin/dynsomisdyn`, needles `DSO ok`, lacks `DSO FAIL`, `ld.so:`, `PANIC`, `BRK`.

`tools/mame_test/tests/lddigest.json`:

```json
{
 "name": "lddigest",
 "description": "Shared libc SP4: the machine binder's digest of dynsodyn's and dynsomisdyn's binding (LD_BIND_DIGEST) equals fgx_bind's for the same libraries.",
 "command": "LD_BIND_DIGEST=1 /testbin/dynsodyn > /tmp/dg1; cmp /tmp/dg1 /testbin/dynsodyn.digest && echo LDB \"same\"1; LD_BIND_DIGEST=1 /testbin/dynsomisdyn > /tmp/dg2; cmp /tmp/dg2 /testbin/dynsomisdyn.digest && echo LDB \"same\"2",
 "timeout_s": 180,
 "expect": {
  "screen_contains": ["LDB same1", "LDB same2"],
  "screen_lacks": ["differ", "n=0", "ld.so:", "PANIC", "BRK"]
 }
}
```

(the quotes keep the needles `LDB same1`/`LDB same2` out of the typed command line; `tools/check_vacuous_assertions.py` checks it. Confirm `/tmp` exists and is writable on the image -- `grep -n 'disk_src/tmp' tools/ninja/manifest.json` -- and use `/var/tmp` if not.)

`tools/mame_test/tests/ldd.json`: command `ldd /testbin/dynsodyn; ldd /bin/true; ldd /nonexistent; echo st=$?`, needles `-lc.1 => /lib/libc.so.1.0`, `/bin/true: statically linked`, `ldd: /nonexistent unreadable`.

Run: `ninja; tools/mame_test/run.py dynsomisdyn lddigest ldd`
Expected: dynsomisdyn may already pass (by-name binding is Task 3's code) -- if it does, its RED is Task 3's: say so in the ledger; lddigest and ldd FAIL (no digest output, no `ldd`).

- [ ] **Step 2: The trace and the digest in the binder**

In `ld_bind.c`, add:

```c
#define LB_TRACE    1
#define LB_DIGEST   2

/* LD_TRACE_LOADED_OBJECTS and LD_BIND_DIGEST, in one walk of the kernel's
 * frame (bank 0: argc, then argv's 16-bit pointers to a 0, then envp's). */
static int
lb_env(frame)
unsigned frame;
{
    static char *var[2] = { "LD_TRACE_LOADED_OBJECTS", "LD_BIND_DIGEST" };
    unsigned *v;
    char *e;
    int i, j, f;

    f = 0;
    v = (unsigned *)(unsigned long)frame + 1;
    while (*v)
        v++;
    for (v++; *v; v++) {
        e = (char *)(unsigned long)*v;
        if (e[0] != 'L' || e[1] != 'D')
            continue;
        for (j = 0; j < 2; j++) {
            for (i = 0; var[j][i] && e[i] == var[j][i]; i++)
                ;
            if (var[j][i] == 0 && e[i] == '=')
                f |= 1 << j;
        }
    }
    return f;
}

static unsigned
lb_rotx(h, b)
unsigned h, b;
{
    return ((h << 1) | (h >> 15)) ^ (b & 0xFF);
}
```

(`var` is a static array of pointers to literals in libc's code bank: if fcc places the array itself in libc's core, that is a core cell -- write the two names as two literals compared in turn instead if `check_core_list` objects.) In `ld_bind`, at the top: `fl = lb_env(frame); h = 0; nd = 0;` (declare `fl`, `h`, `nd`, `j`).

Under `LB_TRACE`, a failed `ld_need` writes `\t-l<name less "lib">.<major> => not found\n` on fd 1 and marks the library absent (`L->base = 0`) instead of exiting. The imports loop skips an absent library's imports but still walks their sites, or every later import patches the wrong ones:

```c
        if (L->base == 0) {                             /* absent, under the trace */
            r += 4 + n + 6;
            for (k = 0; k < 3; k++)
                s += 2 + 3 * ld_rd16(s);
            continue;
        }
```

(before the `L->pre` test), and the cores loop skips it. After each class's `_ld_patch`, under `LB_DIGEST`, before `s += 3 * c`:

```c
            if (fl & LB_DIGEST)
                for (j = 0; j < c; j++, nd++) {
                    e = (unsigned char *)lb_far(seg[s[3 * j]].bank,
                                                seg[s[3 * j]].off + ld_rd16(s + 3 * j + 1));
                    h = lb_rotx(h, e[0]);
                    h = lb_rotx(h, e[1]);
                    if (k < 2)
                        h = lb_rotx(h, 16 * li + sg);
                }
```

Under `LB_DIGEST` the cores loop also compares each copy with its template byte for byte, but at its fixups, and dies `<lib>: core copy differs` on a difference (ruling 4). After `HEAP_LIM` is set:

```c
    if (fl & LB_DIGEST) {
        q = ld_cat(w->msg, "LDB sites ");
        q = lb_hex(q, h, 4);
        q = ld_cat(q, " n=");
        q = ld_num(q, nd);
        *q++ = '\n';
        write(1, w->msg, q - w->msg);
        _exit(0);
    }
    if (fl & LB_TRACE) {
        for (li = 0; li < nlib; li++) {
            L = &lib[li];
            if (L->base == 0)
                continue;
            q = ld_cat(w->msg, "\t-l");
            q = ld_cat(q, L->name + 3);                 /* libc -> c */
            *q++ = '.';
            q = ld_num(q, L->major);
            q = ld_cat(q, " => /lib/");
            q = ld_cat(q, L->name);
            q = ld_cat(q, ".so.");
            q = ld_num(q, L->major);
            *q++ = '.';
            q = ld_num(q, L->minor);
            q = ld_cat(q, " (core $");
            q = lb_hex(q, L->base, 4);
            q = ld_cat(q, L->pre ? ", prebound, " : ", by name, ");
            q = ld_cat(q, L->loaded ? "loaded)\n" : "resident)\n");
            write(1, w->msg, q - w->msg);
        }
        for (need = 0xFFF8 - lowest, li = 0; li < nlib; li++)
            need -= lib[li].base ? lib[li].csize : 0;
        q = ld_cat(w->msg, "\t");
        q = ld_num(q, need);
        q = ld_cat(q, " bytes of unused cores between them\n");
        write(1, w->msg, q - w->msg);
        _exit(0);
    }
```

(`L->minor` is the row's, which `lb_row` set: the file the trace names.) The fit and the "a bad import table" check for a missing `_<lib>_blktab` skip absent libraries too.

- [ ] **Step 3: ldd**

Vendor `examples/SunOS-4.1.3/bin/ldd.c` to `vendor/SunOS-4.1.3/bin/ldd.c`. `src/userland/ldd/ldd.c` is that file with FGX's executable test in place of `struct exec`: read 16 bytes, `FGX2`/`FGX3` magic else `not an executable`, header flags bit 2 else `<file>: statically linked`; `nenvp[0] = "LD_TRACE_LOADED_OBJECTS=1"`; `execve(argv[i], nargv, nenvp)` where `nargv = {argv[i], 0}`; FGX's `wait()` status macros in place of `union wait`; the file header says `FGX-Provenance: vendor/SunOS-4.1.3/bin/ldd.c` and lists the changes. Manifest: `{"name": "ldd"}` and staging `bin/ldd.bin` -> `disk_src/usr/bin/ldd`. `ldd.0` in `loadcda.0`'s form (NAME, SYNOPSIS, DESCRIPTION -- the trace line's fields --, SEE ALSO `ldload(8)`, BUGS: none known).

- [ ] **Step 4: Run, and controls**

Run: `ninja; tools/mame_test/run.py dynsodyn dynsomisdyn lddigest ldd`
Expected: `4 passed`, fresh. Controls, each required: (a) skip the data-site patch (`if (0)` around kind 1's `_ld_patch`): `dynsomisdyn` FAILs (`DSO FAIL errno`/`stdout`: by name, every data delta is non-zero) and `lddigest` FAILs on `same2`; (b) in the by-name path, take the export's value off by one (`val + 1`): `lddigest` FAILs on `same2`; (c) normalise the bank with `L` and `seg` swapped: `lddigest` FAILs on both. Restore, `ninja`.

- [ ] **Step 5: Gate, commit**

Run `tools/gate.sh`; Expected `GATE GREEN`.

```bash
git add toolchain/lib/libc_c/ld_bind.c src/userland/ldd vendor/SunOS-4.1.3/bin/ldd.c \
        src/userland/man/pages/cat1/ldd.0 tools/dynso-fgx2/build_dynso.sh tools/ninja/gen.py \
        tools/ninja/manifest.json tools/mame_test/tests/dynsomisdyn.json \
        tools/mame_test/tests/lddigest.json tools/mame_test/tests/ldd.json
git commit -F - <<'EOF'
feat(libc): LD_TRACE_LOADED_OBJECTS, LD_BIND_DIGEST, and ldd(1)

The binder reads the environment from the kernel's frame.  With
LD_TRACE_LOADED_OBJECTS set it prints each library as SunOS 4.1.3's
rtld does -- `-lc.1 => /lib/libc.so.1.0' -- with its core base, whether
it bound prebound or by name and was resident or loaded, and the bytes
of unused cores between them, then exits; ldd(1), from SunOS's ldd.c,
runs a program so.  With LD_BIND_DIGEST set it prints a digest of every
site it patched, each bank normalised to (library, segment), which
equals fgx_bind --digest's for the same libraries: a dynso linked
against a libc whose core moved binds by name on the machine to the
same bytes the host binder writes.
EOF
```

---

### Task 5: the exec budget

**Files:**
- Create: `src/userland/exectime/exectime.c`, `tools/mame_test/tests/exectime.json`
- Modify: `tools/dynso-fgx2/build_dynso.sh` (`dyntruebound`: dyntrue bound by fgx_bind), `tools/ninja/gen.py`, `tools/ninja/manifest.json`

- [ ] **Step 1: The tool and the probe**

`src/userland/exectime/exectime.c`:

```c
/*
 * exectime -- fork and exec a program n times and print the mean, in ms,
 * from gettimeofday: `EXT <path> <ms>'.  The exec budget's meter (shared
 * libc SP4 spec, section 8): every subject pays the same fork.
 *
 * FGX-Provenance: none
 */
#include <stdio.h>
#include <sys/time.h>

static struct timeval tv;

static long
ms()
{
    gettimeofday(&tv, (struct timezone *)0);
    return tv.tv_sec * 1000L + tv.tv_usec / 1000;
}

main(argc, argv)
int argc;
char **argv;
{
    int i, n, pid, st;
    long t;

    if (argc < 3)
        return 2;
    n = atoi(argv[2]);
    t = ms();
    for (i = 0; i < n; i++) {
        pid = fork();
        if (pid == 0) {
            execl(argv[1], argv[1], (char *)0);
            _exit(127);
        }
        wait(&st);
        if (st != 0) {
            printf("EXT %s failed %d\n", argv[1], st);
            return 1;
        }
    }
    printf("EXT %s %ld\n", argv[1], (ms() - t) / n);
    return 0;
}
```

`tools/mame_test/tests/exectime.json`: command `/testbin/exectime /bin/true 20; /testbin/exectime /testbin/dyntrue 20; /testbin/exectime /testbin/dyntruebound 20`, needles `EXT /bin/true `, `EXT /testbin/dyntrue `, `EXT /testbin/dyntruebound ` (with the trailing space the screen line has and the command line does not), lacks `failed`, `ld.so:`, `PANIC`, `BRK`; timeout 300.

Run: `ninja; tools/mame_test/run.py exectime` and read the three numbers from `/tmp/fgx_test_exectime/dump.txt`. Run it three times (fresh each) and take each subject's median. `dyntrue - dyntruebound` is the binder's own cost (both copy libc's core). Then, with a temporary `ld_tick` (step 2's, uncommitted) at the binder's phases -- entry, the libraries' rows, the imports, the cores and fit -- run dyntrue once and record the breakdown, whatever the medians say; remove the ticks and confirm `git diff` is empty of them.

- [ ] **Step 2: The gate the spec sets**

If dyntrue's median is within 10% of /bin/true's: record the three medians, the breakdown, and libc's core bytes (2,389) as the term that decides it, and go on. If not: STOP -- the spec makes this a landing gate (section 1), so the trade is the maintainer's -- with the medians and the breakdown.

- [ ] **Step 3: Commit**

```bash
git add src/userland/exectime tools/mame_test/tests/exectime.json \
        tools/dynso-fgx2/build_dynso.sh tools/ninja/gen.py tools/ninja/manifest.json
git commit -F - <<'EOF'
test(exectime): the exec budget -- a dynamic true(1) against the static one

exectime forks and execs a program n times and prints the mean.  /bin/true
(static, its libc pile read per exec), dyntrue (dynamic, bound on the
machine) and dyntruebound (the same bound on the host) measured in MAME:
<write the three medians from Step 1 here>.
EOF
```

---

### Task 6: the spec and the roadmap

**Files:**
- Modify: `docs/history/plans/2026-09-30-shared-libc-sp4-design.md` (5.1, 5.3, 5.4, 9, 12), `docs/ROADMAP.md`

- [ ] **Step 1: Amend the spec to the build**

- 5.1: the tables at segment 0's tail only (ruling 1), their shape, the locator as an `LDA #` operand (ruling 2), `ENTR`.
- 5.2: XIDX after FIXS (ruling 6).
- 5.3: `_ld_bind`'s entry seeding libc's `_fcc_dbr` (ruling 3); the binder's scratch above the break; the trace line as built; `LD_BIND_DIGEST` exits (ruling 5).
- 5.4: `_ld_patch`, one loop for both binders, the class the kind allows (ruling 7).
- 9.7: the digest's definition (with its site count) and what it leaves to `lddig` (ruling 4).
- 5.5: the "no room" message's end and LIM as printed; the binder's other texts as built.
- 8: the binder's per-exec costs as measured (Task 5's breakdown).
- 12: "Step 3 landed": what was built, the exec medians, libc's size, the probes and their controls, what was found.

- [ ] **Step 2: ROADMAP**

The shared libc paragraph: step 3 (binding on the machine) landed; next, step 4 (first use, the race, the kill, reclaim, the error probes).

- [ ] **Step 3: Commit**

```bash
git add docs/history/plans/2026-09-30-shared-libc-sp4-design.md docs/ROADMAP.md
git commit -F - <<'EOF'
docs(shared-libc): SP4 step 3 as built

The spec's binding sections brought to the build -- the tables and the
locator in segment 0, the export index, the binder's entry and scratch,
the site loop, the trace and the digest -- and the exec budget as
measured.  ROADMAP: step 3 landed; step 4 is next.
EOF
```
