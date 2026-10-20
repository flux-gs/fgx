# Shared libc SP5 step 1: the dynamic mode and the binder -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A program of any number of code segments links dynamically through the build, its binder tables go where there is room, and the libc.so binder patches shared text repeatably and skips the code patches on a later exec -- proven on wc, ls, ul, worm and ntpd and on synthetic probes, while every other tool stays on piles.

**Architecture:** `fgx_dyn.py` becomes the build's dynamic link for every program shape: it gains extra code segments, places the tables in the roomiest code segment (adding one if none has room) behind a relocated pointer in segment 0, and writes a bind record after IMPS. Data sites carry their original word everywhere IMPS is written or read, so `_ld_patch` stores instead of adding. `ld_bind.c` compares the record with the rows it ACQUIREd, patches only the data segment's sites on a match, and repatches and rewrites the record otherwise. `gen.py` builds a manifest tool marked `"dynamic": true` through `fgx_dyn` instead of the pile path.

**Tech Stack:** Python 3 host tools (`toolchain/src/ld/`), fcc K&R C (`toolchain/lib/libc_c/`), Merlin32 65816 assembly (`toolchain/lib/*.s`), ninja via `tools/ninja/gen.py`, headless MAME tests (`tools/mame_test/run.py`).

**Spec:** [`2026-10-04-shared-libc-sp5-design.md`](2026-10-04-shared-libc-sp5-design.md) (3c109e53c), sections 4, 4.1, 5.1-5.3, 5.5 and section 8 item 1.

## Global Constraints

- ASCII only in every file.
- 65816 assembly is written by the main agent, not delegated (standing rule).
- Commit bodies are the changelog: informational, no process, no follow-ups; end with the session's Co-Authored-By and Claude-Session trailers.
- No push, no MR (feat branch; `ALLOW_FEAT_PUSH=1` only when the maintainer asks).
- Headless MAME only: `tools/mame_test/run.py` (or `SDL_VIDEODRIVER=dummy`); never a raw `mame64`.
- A test that cannot go red is not coverage: every new check states its control and the control is run once.
- None of the new MAME tests joins `GATE_TESTS` (`tools/gate.sh:633-639`): they are probes (spec 5.5).
- Every other manifest tool stays on piles in this step; nothing in section 7 of the spec is retired here.
- Toolchain-first: a gap in fcc or libc is fixed there, never worked around in a tool.
- Source comments describe the current state only.

## Plan rulings (decisions the spec left to the plan, and one deviation)

- **R1. fgx_dyn is the dynamic mode.** Spec section 4 leaves fgx_dyn's fate to the plan "by what is less code". fgx_dyn already does the dynamic link's every step for one segment, so it grows extra code segments and `gen.py` calls it for a dynamic tool, rather than teaching `materialize_links` and the seg templates a second link mode.
- **R2. The record's compare and repatch is tested on the machine,** not on the host as spec 5.5 says. The binder is fcc-compiled 65816 code with no host build, so a host test could only test a Python model of it. A probe (`dynrebind`) that corrupts one of its own patched sites and its record, then execs itself, reaches the mismatch path through the real binder; its control (skip the compare) goes red. Cost if wrong: one probe replaced by a host model later.
- **R3. libfgx is out of step 1.** 34 manifest tools call libfgx (`spawnx`, `ticks`, `procs`, ...), which libc.so does not contain; the spec does not say where it goes. Step 1's tools use none of it. Raised with the maintainer as a spec gap before step 2.
- **R4. The bind record is fixed-size per library:** a word, then per IMPS library 8 bank bytes (`LD_MAXBANKS`), the core base (2) and the export CRC (4) -- 14 bytes, 2 + 14 x nlib in all, placed after IMPS so `nlib` is read before it is sized.
- **R5. Site filtering is in `_ld_patch`.** A run of sites mixes segments, so `_ld_patch` takes a seventh argument `only`: `$FF` patches every site, any other value patches only sites in that segment. A matched record calls it with `only` = the data segment.

## Review Focus

1. **A dynamic tool whose data segment is near the ceiling under the by-name path** -- the binder must still say `no room for its data`, never write past the break. Pinned by `ldfit` re-run in Task 1 and Task 3.
2. **A tool linked with termlib run first after boot (termlib not resident)** -- the first-use load must work through the new tables. Pinned by `dyntools` running `ul` first in Task 7.
3. **fork of a dynamic program whose text is bound** -- the child must run without rebinding and print correctly. `dynsodyn` already forks; Task 3's `dynrepeat` runs it twice.
4. **A dynamic program exec'd from a pile-linked shell** (every MAME test command runs under the boot shell) -- covered by every MAME test in this plan.
5. **The host binder's images (dynso, cursso, dyntruebound)** must still bind and run after the format change. Pinned by `test_bind.py` and the `dynso`/`cursso` MAME tests in Task 1.

---

### Task 1: Data sites carry their original word; `_ld_patch` stores

The format change has to land in every producer and consumer at once, or the libraries and programs disagree.

**Files:**
- Modify: `toolchain/src/ld/fgx_sites.py` (`attribute` keeps each site's value)
- Modify: `toolchain/src/ld/fgx_imports.py` (data sites are `(seg, off, orig)`, 5 bytes)
- Modify: `toolchain/src/ld/fgx_dyn.py:417-421` (pass the original word)
- Modify: `toolchain/src/ld/fgx_libso.py:766-775` (pass the original word)
- Modify: `toolchain/src/ld/fgx_bind.py:186-189` (data sites become `orig + delta`)
- Modify: `toolchain/lib/ld_bind_asm.s` (`_ld_patch`: kind 1 stride 5, store; the `only` argument)
- Modify: `toolchain/lib/libc_c/ld_bind.c:355-394` (site strides; `only` = `$FF` for now)
- Modify: `toolchain/lib/libc_c/ld_load.c:430-447` (site strides; `only` = `$FF`)
- Modify: `toolchain/include/sys/ldctl.h` (the `_ld_patch` contract comment)
- Modify: `src/userland/lddig/lddig.c:233-236` (its IMPS site walk steps 5 bytes over data sites)
- Modify: `tools/libc_so_check.py:240` (data sites unpack as triples)
- Modify: `toolchain/tests/dyn/test_bind.py:180,219,226` (data sites unpack as triples)
- Test: `toolchain/src/ld/fgx_imports.py --self-test`, `fgx_sites.py --self-test`, `toolchain/tests/dyn/test_bind.py`, new `tools/mame_test/tests/dynrepeat.json`

**Interfaces:**
- Produces: `fgx_sites.attribute(sites, objects, where)` -> `{name: [(off, value), ...]}`; IMPS data site tuple `(seg, off, orig)`; `fgx_imports.Resolver.use(kind, name, site, seg, off, orig=None)`; `_ld_patch(sites, n, segs, kind, val, bank, only)`.

- [ ] **Step 1: Write the failing machine test.**  `dynsomisdyn` is linked against a libc whose core is 2 bytes larger, so the machine binds it by name with a nonzero delta (`tools/dynso-fgx2/build_dynso.sh:21-24`).  Run twice, the second exec hits the text table and re-adds the delta today.

Create `tools/mame_test/tests/dynrepeat.json`:

```json
{
 "name": "dynrepeat",
 "description": "A DYNAMIC PROGRAM BOUND BY NAME, RUN TWICE IN ONE BOOT (shared libc SP5 spec 5.1, 5.5).  dynsomisdyn is linked against a libc.so whose core is two bytes larger, so the machine binds it by name and every data site moves by a nonzero delta.  The second exec finds its code in the shared-text table, already patched by the first; the binder must write the same bytes again, not add the delta twice.  dynso.c checks libc data through code-segment sites (errno, __progname, the block table) and through a data-segment site (`int *ep = &errno'), and prints DSO FAIL on any wrong value.  The markers are built by expansion so the typed line cannot satisfy them.  Control: restore the ADD in _ld_patch's data path and the second run prints DSO FAIL.",
 "command": "A=R; DSO_ENV=yes /testbin/dynsomisdyn; echo ${A}1=$?; DSO_ENV=yes /testbin/dynsomisdyn; echo ${A}2=$?",
 "timeout_s": 240,
 "expect": {
  "screen_contains": ["R1=0", "R2=0"],
  "screen_lacks": ["DSO FAIL", "ld.so:", "PANIC", "BRK"]
 }
}
```

- [ ] **Step 2: Run it and watch it fail.**

Run: `python3 tools/mame_test/run.py dynrepeat`
Expected: FAIL -- `R2=0` missing and/or `DSO FAIL` present on the second run.  If it passes, STOP: the second exec did not hit the text table (check the youth rule, `src/kernel/tty/text.s` REG) and this test cannot discriminate; report before going on.

- [ ] **Step 3: Write the failing host tests.**  In `toolchain/src/ld/fgx_imports.py`'s `self_test`, change the two data-site lists to triples:

```python
                     {"lib": 0, "ordinal": 9, "name": "errno", "kind": 1,
                      "seg": 3, "val": 0xF800, "size": 2,
                      "call": [], "ptr": [], "data": [(0, 0x20, 0xF800)]},
                     {"lib": 1, "ordinal": 0, "name": "UP", "kind": 1,
                      "seg": 1, "val": 0xF210, "size": 4,
                      "call": [], "ptr": [],
                      "data": [(0, 0x30, 0xF210), (1, 0x31, 0xF212)]}]}
```

In `toolchain/src/ld/fgx_sites.py`'s `self_test`, change the two `attribute` assertions to:

```python
    assert attribute([(1, 0xF800), (5, 0xF802)],
                     [("errno", 0xF800, 2), ("x", 0xF802, 4)]) == \
        {"errno": [(1, 0xF800)], "x": [(5, 0xF802)]}
    assert attribute([(5, 0xF802)], [("errno", 0xF800, 2)]) == \
        {"errno": [(5, 0xF802)]}
```

- [ ] **Step 4: Run them and watch them fail.**

Run: `cd toolchain && python3 src/ld/fgx_imports.py --self-test; python3 src/ld/fgx_sites.py --self-test`
Expected: both FAIL -- fgx_imports with `ValueError: too many values to unpack` (its `pack` still unpacks a site as a pair), fgx_sites with an AssertionError.

- [ ] **Step 5: `fgx_sites.attribute` keeps the value.**  Replace its loop's append:

```python
        out.setdefault(owner, []).append((off, v))
```

and its docstring's first line with `{object name: [(offset, value), ...]}`.

- [ ] **Step 6: `fgx_imports`: data sites are triples.**  In the module docstring replace the sites paragraph with:

```
Per import, its sites, three kinds: `call' (the operand of a JSL or JML),
`ptr' (a 24-bit pointer cell), `data' (a 16-bit word: its value as linked,
which the binder replaces by that value + actual - prebound).  A call or
pointer site is (segment, offset); a data site (segment, offset, original
word), so a bind writes the same bytes however often it runs.
```

and the payload line `per import, same order: ...` with:

```
  per import, same order: n_call (H) [seg (B) off (H)]*
                          n_ptr (H) [seg (B) off (H)]*
                          n_data (H) [seg (B) off (H) orig (H)]*
```

Change `Resolver.use` to take the original word:

```python
    def use(self, kind, name, site, seg, off, orig=None):
        """Record a site of `name' (kind 0 code, 1 data).  A data site
        carries the word the link wrote there."""
        if site == "data" and orig is None:
            fgx_ld.die(f"imports: data site of {name} at {seg}:{off:#x} has no original word")
```

keep the rest of its body, and change its last line to:

```python
        self.imports[name][site].append((seg, off) if site != "data" else (seg, off, orig))
```

In `pack`, replace the site loop with:

```python
    for im in t["imports"]:
        for k in SITES:
            out += struct.pack("<H", len(im[k]))
            if k == "data":
                out += b"".join(struct.pack("<BHH", s, o, v) for s, o, v in im[k])
            else:
                out += b"".join(struct.pack("<BH", s, o) for s, o in im[k])
```

In `unpack`, replace the site loop with:

```python
    for im in imports:
        for k in SITES:
            c = struct.unpack_from("<H", p, pos)[0]
            pos += 2
            w = 5 if k == "data" else 3
            fmt = "<BHH" if k == "data" else "<BH"
            im[k] = [struct.unpack_from(fmt, p, pos + w * i) for i in range(c)]
            pos += w * c
```

- [ ] **Step 7: Producers pass the original word.**  `fgx_dyn.py` around `:409-421`:

```python
    for im in old["imports"]:
        for k in fgx_imports.SITES:
            for site in im[k]:
                res.use(im["kind"], im["name"], k, *site)
    objects = [(n, a_, sz) for n, (a_, sz) in libs.data.items() if n not in shadowed]
    for seg, (x, y) in enumerate(zip(sa, sb)):
        found = fgx_sites.attribute(fgx_sites.diff_sites(x, y), objects,
                                    "%s segment %d" % (name, seg))
        for obj, offs in found.items():
            for off, v in offs:
                res.use(1, obj, "data", seg, off, v)
```

`fgx_libso.py` around `:765-776`, the same two loops:

```python
    for im in old["imports"]:
        for k in fgx_imports.SITES:
            for site in im[k]:
                res.use(im["kind"], im["name"], k, *site)
    csit = []
    for seg, (x, y) in enumerate(zip(sa, sb)):
        found = fgx_sites.attribute(fgx_sites.diff_sites(x, y), objects,
                                    "%s segment %d" % (name, seg))
        for obj, offs in found.items():
            for off, v in offs:
                if obj == "core":
                    csit.append((seg, off))
                else:
                    res.use(1, obj, "data", seg, off, v)
```

Check there is no other producer: `grep -rn "\.use(" toolchain/src/ld/*.py` must show only fgx_dyn, fgx_libso and fgx_ld's `resolver.use(0, ...)` (code sites, unchanged).

- [ ] **Step 8: `fgx_bind` stores.**  In `bind_sites`, the data branch:

```python
        elif patch_data:
            for s, o, orig in im["data"]:
                S, O = where[s]
                img.word_set(S, O + o, (orig + addr - im["val"]) & 0xFFFF)
```

and in `digest`, unpack only the first two fields (`for site in im[k]: s, o = site[0], site[1]`).

- [ ] **Step 9: Run the host tests.**

Run: `cd toolchain && python3 src/ld/fgx_imports.py --self-test && python3 src/ld/fgx_sites.py --self-test`
Expected: `fgx_imports: self-test OK`, `fgx_sites: self-test OK`.

- [ ] **Step 10: `_ld_patch` stores and filters (65816; main agent).**  Replace `toolchain/lib/ld_bind_asm.s` from its contract comment to the end with:

```
;------------------------------------------------------------------------------
; _ld_patch(sites, n, segs, kind, val, bank, only) - kind 0: a site is
; (segment, offset), 3 bytes, and the word there becomes val and the byte
; after it bank (a call's or a pointer's 24 bits); kind 1: a site is
; (segment, offset, original word), 5 bytes, and the word there becomes the
; original word + val (a data site moved by the delta), so a bind writes
; the same bytes however often it runs.  only = $FF patches every site; any
; other value only the sites in that segment.  Uses fcc's caller-saved
; pointer scratch: _fcc_ptr2 the site list, _fcc_fpr0 the segment table,
; _fcc_ptr the site.  Far: JSL'd from C, RTL.
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
                PHA                             ; 1,S = the site's segment
                LDA     20+2,S                  ; only
                AND     #$00FF
                CMP     #$00FF
                BEQ     @lp_take
                CMP     1,S
                BEQ     @lp_take
                PLA                             ; another segment: step over it
                LDA     14,S                    ; kind
                BEQ     @lp_skip3
                INY
                INY
@lp_skip3       INY
                INY
                INY
                BRA     @lp_next
@lp_take        PLA
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
                LDA     14,S                    ; kind
                BNE     @lp_data
                LDA     16,S                    ; val
                STA     [_fcc_ptr]
                PHY
                LDY     #2
                SEP     #$20
                MX      %10
                LDA     18+2,S                  ; bank
                STA     [_fcc_ptr],Y
                REP     #$20
                MX      %00
                PLY
                BRA     @lp_next
@lp_data        MX      %00
                LDA     [_fcc_ptr2],Y           ; the original word
                CLC
                ADC     16,S                    ; + val
                STA     [_fcc_ptr]
                INY
                INY
@lp_next        MX      %00
                DEX
                BNE     @lp_site
@lp_done        MX      %00
                RTL
```

Stack offsets: the JSL return is 3 bytes, so the arguments start at 4,S: sites 4-7, n 8-9, segs 10-13, kind 14-15, val 16-17, bank 18-19, only 20-21.  Inside `@lp_site` one word is pushed (`PHA`), hence `20+2,S`; inside the kind-0 bank store one word (`PHY`), hence `18+2,S`.  Read each `,S` operand against that table before assembling.

- [ ] **Step 11: The C callers walk 5-byte data sites and pass `only`.**  In `ld_bind.c`, the absent-library skip (`:356-357`):

```c
            for (k = 0; k < 3; k++)
                s += 2 + (k == 2 ? 5 : 3) * ld_rd16(s);
```

the patch call (`:383-385`):

```c
            if (c)
                _ld_patch(s, c, seg, kind, kind == 0 ? val : delta,
                          kind == 0 ? L->banks[sg] : 0, 0xFF);
```

the digest loop's site addressing (`:386-394`), with `w5 = k == 2 ? 5 : 3` declared as `unsigned w5;` at the top of `ld_bind`:

```c
            w5 = k == 2 ? 5 : 3;
            if (fl & LB_DIGEST)
                for (j = 0; j < c; j++, nd++) {
                    e = (unsigned char *)lb_far(seg[s[w5 * j]].bank,
                                                seg[s[w5 * j]].off + ld_rd16(s + w5 * j + 1));
```

and the advance at the end of the site loop:

```c
            s += w5 * c;
```

In `ld_load.c`'s `ld_bind_imps` (`:438-447`):

```c
            if (c)
                _ld_patch(s, c, m->seg, kind,
                          kind == 0 ? val : dep[lib].delta,
                          kind == 0 ? dep[lib].banks[seg] : 0, 0xFF);
            s += (k == 2 ? 5 : 3) * c;
```

The other walkers of IMPS sites, which all assume 3 bytes a data site:

- `src/userland/lddig/lddig.c:233-236`, `for (off = 0; off < len; off++, s += 3)` over all three kinds: change the step to `s += c == 2 ? 5 : 3` (where `c` is that loop's site-kind index -- read the loop and use its variable).  It walks libtermlib's and libcurses's IMPS, so the `lddelta`, `ldload` and `ldorder` probes depend on it.
- `tools/libc_so_check.py:240`: `for sg, off, _orig in im["data"]:`.
- `toolchain/tests/dyn/test_bind.py:180, 219, 226`: `for s, o, _v in ...` wherever `["data"]` is unpacked.

Then search for any walker still left: `grep -rn "s += 3\|3 \* c\|3 \* ld_rd16\|\[\"data\"\]" toolchain/lib/libc_c src/userland/lddig tools/*.py toolchain/tests toolchain/src/ld` -- every hit must be a call or pointer site, or already handle the triple.

- [ ] **Step 12: The contract comment in `ldctl.h`.**  Above `void _ld_patch();` add:

```c
/* _ld_patch(sites, n, segs, kind, val, bank, only): kind 0 sites are
 * (seg, off), 3 bytes, stored val:bank; kind 1 sites are (seg, off, orig),
 * 5 bytes, stored orig + val; only = 0xFF all sites, else that segment's. */
```

- [ ] **Step 13: Rebuild everything the format touches.**  Announce: the main checkout (feat/shared-libc) is rebuilt.

Run: `make -C toolchain libso_all && python3 tools/ninja/gen.py > /dev/null && ninja > /tmp/sp5t1.log 2>&1; echo rc=$?; tail -3 /tmp/sp5t1.log`
Expected: `rc=0`.  libc.so, libtermlib.so and libcurses.so are rebuilt -- because `ld_bind.c` and `ld_bind_asm.s` changed: `lib/libc.so.1.0`'s make dependencies (`toolchain/Makefile:72-78`) do not list `fgx_imports.py` or `fgx_sites.py`, so a later change to the format alone would NOT rebuild them; use `make -C toolchain -B libso_all` then -- and every dynamic probe relinks.

- [ ] **Step 14: Host tests.**

Run: `make -C toolchain test-archives 2>&1 | tail -15`
Expected: `test_dyn.py` and `test_bind.py` report no `FAIL`; the `libc_so_check.py` runs pass.  `test_bind.py`'s `delta()` and `binding()` exercise `word_set` on data sites.

- [ ] **Step 15: The machine test goes green, and the SP4 probes stay green.**

Run: `python3 tools/mame_test/run.py dynrepeat dynsodyn curssodyn cursexec dynso cursso ldfit lddigest ldd exectime lddelta ldload ldorder`
Expected: `13 passed, 0 failed`.

- [ ] **Step 16: Run the control once.**  In `ld_bind_asm.s`'s `@lp_data`, replace `LDA [_fcc_ptr2],Y` with `LDA [_fcc_ptr]` (add to the current word, the old behaviour), rebuild (`ninja`), run `python3 tools/mame_test/run.py dynrepeat`.
Expected: FAIL (`DSO FAIL` or no `R2=0`).  Restore the line, rebuild, and rerun `dynrepeat`: PASS.

- [ ] **Step 17: Commit.**

```bash
git add toolchain/src/ld/fgx_sites.py toolchain/src/ld/fgx_imports.py \
  toolchain/src/ld/fgx_dyn.py toolchain/src/ld/fgx_libso.py toolchain/src/ld/fgx_bind.py \
  toolchain/lib/ld_bind_asm.s toolchain/lib/libc_c/ld_bind.c toolchain/lib/libc_c/ld_load.c \
  toolchain/include/sys/ldctl.h tools/mame_test/tests/dynrepeat.json \
  src/userland/lddig/lddig.c tools/libc_so_check.py toolchain/tests/dyn/test_bind.py
git commit -m "fix(libc): a data site stores its original word plus the delta

<body: the binder ran in every exec and ADDED the delta to each data
site; with shared text a second exec of a program bound by name re-added
it to code the first had patched.  Each IMPS data site now carries the
word the link wrote (fgx_sites keeps it, fgx_imports packs (seg, off,
orig)), and _ld_patch, fgx_bind and ld_load store orig + delta.
_ld_patch takes a segment filter for the bind record.  dynrepeat runs
dynsomisdyn twice: red before, green after.>

```

---

### Task 2: The tables carry the data segment's index and the bind record; the binder skips a bound text's code patches

**Files:**
- Modify: `toolchain/src/ld/fgx_dyn.py:271-295` (`with_tables`: the new layout)
- Modify: `toolchain/lib/libc_c/ld_bind.c` (read the layout; data-segment bank; the record; the skip; the trace line)
- Test: `toolchain/tests/dyn/test_dyn.py` (`tables()`), new `tools/mame_test/tests/dynskip.json`

**Interfaces:**
- Consumes: `_ld_patch(..., only)` from Task 1.
- Produces: the table layout below, read by Tasks 3-4 and by `dynrebind` (Task 6).

```
+0        u16  nseg
+2        u8   dseg            the data segment's index
+3        u8   0
+4        4 x nseg cells       off (H), bank (B, loader-relocated), pad (B)
+4+4n     u16  ilen
+6+4n     IMPS (ilen bytes)
+6+4n+ilen  bind record: u16 bound (0 = not bound), then per IMPS library
            banks[8] (B), core_base (H), crc (I) -- 14 bytes each
```

- [ ] **Step 1: Write the failing host test.**  Replace `tables()` in `toolchain/tests/dyn/test_dyn.py` with:

```python
def tables():
    """The tables: a cell per segment, the data segment's index, IMPS as
    the trailer has it, then a zeroed bind record of 2 + 14 bytes a
    library; each cell's bank byte is a reloc to its segment."""
    rc, text, data, linkdir = link(os.path.join(HERE, "hello.c"), "libc", "hello")
    check(rc == 0, "hello links with its tables", text[-400:])
    if rc:
        return
    p = fgx_bind.parse(data)
    tr = fgx_ld.read_dyn_trailer(p["trailer"])["blocks_raw"]
    seg0 = p["segs"][0][0]
    ex = fgx_ld.scan_listing(os.path.join(linkdir, "seg0_Output.txt"), 2,
                             libc=True)["exports"]
    t = struct.unpack_from("<H", seg0, ex["_dyn_loc"] + 1)[0]
    n = struct.unpack_from("<H", seg0, t)[0]
    check(n == len(p["segs"]), "the table has a cell per segment", str(n))
    check(seg0[t + 2] == 1 and seg0[t + 3] == 0, "the data segment's index is 1",
          str(seg0[t + 2:t + 4].hex()))
    check(all((0, t + 4 + 4 * i + 2, i) in p["relocs"] for i in range(n)),
          "each cell's bank byte is a reloc to its segment")
    q = t + 4 + 4 * n
    ln = struct.unpack_from("<H", seg0, q)[0]
    check(seg0[q + 2:q + 2 + ln] == tr["IMPS"], "the IMPS table follows, as the trailer has it")
    nlib = tr["IMPS"][0]
    rec = seg0[q + 2 + ln:]
    check(len(rec) == 2 + 14 * nlib and not any(rec),
          "a zeroed bind record of 2 + 14 bytes a library ends the tables", rec.hex())
```

(Task 3 moves the locator off `_dyn_loc` and updates this test again.)

- [ ] **Step 2: Run it and watch it fail.**

Run: `cd toolchain && python3 tests/dyn/test_dyn.py 2>&1 | grep -E "FAIL|ok   (the data|a zeroed)"`
Expected: three FAILs -- `the data segment's index is 1`, `the IMPS table follows, as the trailer has it` (the old layout puts the length two bytes earlier) and `a zeroed bind record ...`.

- [ ] **Step 3: `with_tables` writes the layout.**  Replace its body's table construction in `fgx_dyn.py`:

```python
def with_tables(a, end_a, imps, dseg=1):
    """The linked program with the binder's tables appended to segment 0:
    the segment count, the data segment's index, a cell per segment (a word
    0 and a bank byte the loader fills, as it fills any long pointer),
    IMPS's length and IMPS, then the bind record, zero (spec section 5.2):
    a word and 14 bytes a library.  (file bytes without a trailer, the
    tables' offset)."""
    p = fgx_bind.parse(a[:end_a] + fgx_ld.dyn_trailer(b""))
    segs = [bytearray(s) for s, _b, _k in p["segs"]]
    t = len(segs[0])
    n = len(segs)
    nlib = imps[0] if imps else 0
    tab = struct.pack("<HBB", n, dseg, 0) + b"\0\0\0\0" * n \
        + struct.pack("<H", len(imps)) + imps + b"\0" * (2 + 14 * nlib)
    if t + len(tab) > 0xFFFF:
        die("segment 0 has no room for the binder's tables (%d bytes); a "
            "program that large links through the tool build (sub-project 5)"
            % len(tab))
    segs[0] += tab
    relocs = sorted(set(p["relocs"]) | {(0, t + 4 + 4 * i + 2, i) for i in range(n)})
```

and keep the rest (header relocs count, body assembly) as it is.

- [ ] **Step 4: The binder reads the layout and finds the record.**  In `ld_bind.c`'s `ld_bind`, declare `unsigned dseg, ilen; unsigned char *rec; int match;` and replace the segment-table read (`:276-285`) with:

```c
    nseg = ld_rd16(tab);
    if (nseg > LB_NSEG)
        lb_die(w, "", (unsigned char *)prog, lb_len(prog), ": too many segments");
    dseg = tab[2];
    for (i = 0; i < nseg; i++) {
        seg[i].off = ld_rd16(tab + 4 + 4 * i);
        seg[i].bank = tab[4 + 4 * i + 2];
    }
    /* The data segment is this process's, read fresh from the file: its
     * cell was relocated once, by the first load of this text, and holds
     * that process's bank (spec section 5.2). */
    seg[dseg].bank = (unsigned char)(bank >> 16);
    ilen = ld_rd16(tab + 4 + 4 * nseg);
    p = tab + 6 + 4 * nseg;                             /* IMPS */
    rec = p + ilen;                                     /* the bind record */
```

- [ ] **Step 5: Compare the record with the rows.**  After the library loop (before `/* The imports: ...`), add:

```c
    /* The bind record (spec sections 5.2, 5.3): the code segments were
     * patched against these banks, core bases and export CRCs.  A match
     * skips their sites; anything else repatches them.  The digest always
     * patches every site. */
    match = rec[0] | rec[1];
    for (li = 0; li < nlib && match; li++) {
        L = &lib[li];
        e = rec + 2 + 14 * li;
        if (L->base == 0 || ld_rd16(e + 8) != L->base)
            match = 0;
        for (k = 0; k < LD_MAXBANKS && match; k++)
            if (e[k] != L->banks[k])
                match = 0;
        for (k = 0; k < 4 && match; k++)
            if (e[10 + k] != L->rcrc[k])
                match = 0;
    }
    if (!match)
        rec[0] = rec[1] = 0;                            /* before any patch: an
                                                         * lb_die mid-loop leaves
                                                         * no record behind */
    if (fl & LB_DIGEST)
        match = 0;                                      /* patch every site; a
                                                         * matching record stays */
```

The CRC compared is the ROW's (the library as resident), not `L->crc`, which is the CRC the program was linked against (from IMPS).  So `struct lb_lib` gains `unsigned char rcrc[4];`, and `lb_row` copies the row's CRC in the loop that computes `L->pre`:

```c
    for (L->pre = 1, k = 0; k < 4; k++) {
        L->rcrc[k] = b->crc[k];
        if (b->crc[k] != L->crc[k])
            L->pre = 0;
    }
```

- [ ] **Step 6: Patch only the data segment on a match.**  The patch call from Task 1 becomes:

```c
            if (c)
                _ld_patch(s, c, seg, kind, kind == 0 ? val : delta,
                          kind == 0 ? L->banks[sg] : 0, match ? dseg : 0xFF);
            if (match && (fl & LB_TRACE))
                for (j = 0; j < c; j++)
                    nskip += s[w5 * j] != dseg;
```

with `unsigned nskip;` declared and set to 0 beside `h = nd = 0;`.

- [ ] **Step 7: Write the record last.**  After the import loop, before `/* The cores: ...`:

```c
    if (!match && !(fl & LB_DIGEST)) {
        for (li = 0; li < nlib; li++) {
            L = &lib[li];
            if (L->base == 0)
                break;                                  /* traced absent: no record */
            e = rec + 2 + 14 * li;
            for (k = 0; k < LD_MAXBANKS; k++)
                e[k] = L->banks[k];
            e[8] = (unsigned char)L->base;
            e[9] = (unsigned char)(L->base >> 8);
            for (k = 0; k < 4; k++)
                e[10 + k] = L->rcrc[k];
        }
        if (li == nlib)
            rec[0] = 1;                                 /* bound */
    }
```

- [ ] **Step 8: The trace says so.**  In the `LB_TRACE` block, before the `bytes of unused cores` line:

```c
        q = ld_cat(w->msg, match ? "\ttext bound, " : "\ttext patched, ");
        q = ld_num(q, nskip);
        q = ld_cat(q, " code sites skipped\n");
        write(1, w->msg, q - w->msg);
```

- [ ] **Step 9: Rebuild and run the host test.**  Announce the rebuild.

Run: `make -C toolchain libso_all && ninja > /tmp/sp5t2.log 2>&1; echo rc=$?; cd toolchain && python3 tests/dyn/test_dyn.py | grep -c FAIL`
Expected: `rc=0`, `0`.

- [ ] **Step 10: Write the skip's machine test.**  Create `tools/mame_test/tests/dynskip.json`:

```json
{
 "name": "dynskip",
 "description": "A BOUND TEXT'S SECOND EXEC SKIPS ITS CODE PATCHES (shared libc SP5 spec 5.2).  The first exec of dyntrue patches its code and writes the bind record; the second finds the text cached and the record matching the rows it ACQUIREd, so it patches only the data segment.  ldd runs the binder under LD_TRACE_LOADED_OBJECTS, which reports `text patched' or `text bound' with the count of code sites skipped.  dyntrue runs once first so its text is cached before the traced runs.  Control: clear the record word in ld_bind before the compare; the second traced run reports `text patched'.",
 "command": "/testbin/dyntrue; ldd /testbin/dyntrue; ldd /testbin/dyntrue",
 "timeout_s": 180,
 "expect": {
  "screen_contains": ["text bound, ", " code sites skipped"],
  "screen_lacks": ["ld.so:", "PANIC", "BRK"]
 }
}
```

Note the first `ldd` may itself report `text bound` (dyntrue's own run wrote the record); the assertion is that `text bound` appears.  The control is what makes it discriminate.

- [ ] **Step 11: Run it, then its control.**

Run: `python3 tools/mame_test/run.py dynskip dynrepeat dynsodyn curssodyn ldfit lddigest ldd`
Expected: `7 passed`.
Control: in `ld_bind.c` set `match = 0;` immediately after `match = rec[0] | rec[1];`, rebuild, run `dynskip`: FAIL (no `text bound`).  Restore, rebuild, rerun: PASS.

- [ ] **Step 12: Commit.**

```bash
git add toolchain/src/ld/fgx_dyn.py toolchain/lib/libc_c/ld_bind.c \
  toolchain/tests/dyn/test_dyn.py tools/mame_test/tests/dynskip.json
git commit -m "feat(libc): a bound text's later exec patches only its data segment

<body: the tables carry the data segment's index and, after IMPS, a bind
record -- a word and each library's banks, core base and export CRC as
the code was patched.  The binder compares it with the rows it ACQUIREd:
a match patches only the data segment's sites, whose bank is now always
this process's own (the cell holds the first loader's); anything else
clears the record, repatches, and writes it last.  ACQUIRE, core copies,
HEAP_LIM, the fit check and the trace run every exec.  ldd says `text
bound' or `text patched'.>

```

---

### Task 3: The tables' pointer in segment 0; crt0_dyn reads it

**Files:**
- Modify: `toolchain/lib/crt0_dyn.s` (`_dyn_tab` cell; read it instead of `_dyn_loc`)
- Modify: `toolchain/src/ld/fgx_dyn.py` (`with_tables` takes the table segment; patch the cell and reloc its bank byte)
- Test: `toolchain/tests/dyn/test_dyn.py` (`tables()`, `full_seg0()`)

**Interfaces:**
- Consumes: Task 2's layout.
- Produces: `with_tables(a, end_a, imps, dseg=1, tseg=None)` -> `(body, tseg, t)`; `_dyn_tab` (exported, segment 0): `DA 0` then `DFB 0, 0` -- the tables' offset and their segment's bank, relocated by the loader.

- [ ] **Step 1: Write the failing test.**  In `tables()` replace the locator lines with:

```python
    cell = ex["_dyn_tab"]
    t = struct.unpack_from("<H", seg0, cell)[0]
    check((0, cell + 2, 0) in p["relocs"],
          "the tables' pointer's bank byte is a reloc to segment 0 (where they are)")
```

(the rest unchanged).  Replace `full_seg0()` with a test that a full segment 0 now puts the tables in an added segment:

```python
def full_seg0():
    """A program whose code segments have no room puts its tables in an
    added code segment (spec section 4.1)."""
    head = bytearray(16)
    head[6], head[7] = 2, 1
    body = bytes(head) + struct.pack("<HHB3x", 65530, 0, 0) + \
        struct.pack("<HHB3x", 4, 0, 1) + b"\0" * 65530 + b"\0" * 4
    out, tseg, t = fgx_dyn.with_tables(body, len(body), b"\0" * 64)
    p = fgx_bind.parse(out + fgx_ld.dyn_trailer(b""))
    check(len(p["segs"]) == 3 and p["segs"][2][2] == 0 and tseg == 2 and t == 0,
          "a full segment 0 gets an added code segment for its tables",
          "%d segs, tseg %r, t %r" % (len(p["segs"]), tseg, t))
```

- [ ] **Step 2: Run them and watch them fail.**

Run: `cd toolchain && python3 tests/dyn/test_dyn.py 2>&1 | grep FAIL`
Expected: `KeyError: '_dyn_tab'` (or a FAIL naming the pointer) and the full-segment test failing on the old refusal.

- [ ] **Step 3: crt0_dyn's cell (65816; main agent).**  In `crt0_dyn.s`, replace the four lines from `FGX2_EXPORT _dyn_loc` through `PHA ; tab` with:

```
                ; The tables' far pointer, from _dyn_tab: the offset fgx_dyn
                ; wrote and the bank the loader relocated (spec 4.1).  It is
                ; in this bank, so read it with DBR = this bank.
                PHB
                PHK
                PLB
                LDA     |_dyn_tab+2             ; bank in the low byte
                AND     #$00FF
                TAX
                LDA     |_dyn_tab               ; offset
                PLB
                PHX                             ; tab's bank word
                PHA                             ; tab
```

remove the `PHK / PLA / ... PHA ; tab's bank word` group just above it (the tab bank now comes from the cell), and add after `@cd_stop BRA @cd_stop`:

```
                FGX2_EXPORT _dyn_tab
_dyn_tab        DA      $0000                   ; the tables' offset (fgx_dyn)
                DFB     $00                     ; their bank (the loader)
                DFB     $00
```

Recount the frame-slot load `LDA 13,S` after the change: the bytes pushed between the frame slot and that load are blk bank (2), blk (2), copy bank (2), copy (2), tab bank (2), tab (2) = 12, as before, so `13,S` stands.  Confirm against the listing (`seg0_Output.txt` of a test link) before moving on.

- [ ] **Step 4: `with_tables` picks the segment, patches the cell.**  Change its signature and placement:

```python
def with_tables(a, end_a, imps, dseg=1, tseg=None):
    """... the tables go at the tail of the code segment with the most room,
    or, if none has room, in an added code segment of their own (spec
    section 4.1).  (file bytes without a trailer, the tables' segment, the
    tables' offset in it)."""
    p = fgx_bind.parse(a[:end_a] + fgx_ld.dyn_trailer(b""))
    segs = [bytearray(s) for s, _b, _k in p["segs"]]
    bss = [b for _s, b, _k in p["segs"]]
    kinds = [k for _s, _b, k in p["segs"]]
    nlib = imps[0] if imps else 0
    n = len(segs)
    size = 4 + 4 * (n + 1) + 2 + len(imps) + 2 + 14 * nlib   # room for one more cell
    code = [i for i, k in enumerate(kinds) if k == fgx_ld.KIND_MAP["CODE"]]
    if tseg is None:
        roomy = max(code, key=lambda i: 0xFFFF - len(segs[i]))
        tseg = roomy if len(segs[roomy]) + size <= 0xFFFF else None
    if tseg is None:
        if n >= 9:
            die("no code segment has room for the binder's tables (%d bytes) "
                "and the program has nine segments" % size)
        segs.append(bytearray())
        bss.append(0)
        kinds.append(fgx_ld.KIND_MAP["CODE"])
        tseg = n
        n += 1
    t = len(segs[tseg])
    tab = struct.pack("<HBB", n, dseg, 0) + b"\0\0\0\0" * n \
        + struct.pack("<H", len(imps)) + imps + b"\0" * (2 + 14 * nlib)
    segs[tseg] += tab
    relocs = sorted(set(p["relocs"]) | {(tseg, t + 4 + 4 * i + 2, i) for i in range(n)})
    head = bytearray(p["head"])
    head[6] = n
    struct.pack_into("<H", head, 11, len(relocs))
    body = bytes(head)
    for seg, b, k in zip(segs, bss, kinds):
        body += struct.pack("<HHB3x", len(seg), b, k)
    body += b"".join(bytes(s) for s in segs)
    body += b"".join(struct.pack("<BHB", *r) for r in relocs)
    return body, tseg, t
```

In `build`, replace the `with_tables` call and the `_dyn_loc` patch with:

```python
    body, tseg, t = with_tables(a, end_a, fgx_imports.pack(table))
    body = bytearray(body)
    cell = 16 + 8 * body[6] + ex["_dyn_tab"]           # segment 0 is first in the file
    struct.pack_into("<H", body, cell, t)
    body = add_reloc(bytes(body), (0, ex["_dyn_tab"] + 2, tseg))
```

and add `add_reloc` beside `with_tables`:

```python
def add_reloc(body, r):
    """`body' with one more reloc (src segment, offset, target segment)."""
    p = fgx_bind.parse(body + fgx_ld.dyn_trailer(b""))
    relocs = sorted(set(p["relocs"]) | {r})
    head = bytearray(p["head"])
    struct.pack_into("<H", head, 11, len(relocs))
    out = bytes(head) + body[16:16 + 8 * head[6]]
    out += b"".join(bytes(s) for s, _b, _k in p["segs"])
    return out + b"".join(struct.pack("<BHB", *x) for x in relocs)
```

`with_tables` and `add_reloc` post-process fgx_ld's output, so fgx_ld's checks do not see them.  The loader's reloc pass is generic by segment index (`src/kernel/far/loader.s:1455-1480`, `_BankForSeg`) and skips only relocs whose SOURCE segment is already loaded as shared text, so `_dyn_tab`'s bank byte is written by the first load and, on a cached text, keeps the shared code bank the tables are in -- which is right for every sharer.

- [ ] **Step 5: Rebuild; host tests.**  Announce the rebuild.

Run: `ninja > /tmp/sp5t3.log 2>&1; echo rc=$?; cd toolchain && python3 tests/dyn/test_dyn.py | grep -c FAIL; python3 tests/dyn/test_bind.py | grep -c FAIL`
Expected: `rc=0`, `0`, `0`.  fgx_bind reads IMPS from the trailer, not from the tables, so the host-bound probes are unchanged.

- [ ] **Step 6: Machine.**

Run: `python3 tools/mame_test/run.py dynrepeat dynskip dynsodyn dynsomisdyn curssodyn cursexec ldfit lddigest ldd exectime`
Expected: `10 passed`.  `ldfit` is Review Focus 1 (a data segment near the ceiling).

- [ ] **Step 7: Commit.**

```bash
git add toolchain/lib/crt0_dyn.s toolchain/src/ld/fgx_dyn.py toolchain/tests/dyn/test_dyn.py
git commit -m "feat(ld): a dynamic program's tables go where there is room

<body: the binder's tables go at the tail of the code segment with the
most room, or in an added code segment when none has any; crt0_dyn finds
them through _dyn_tab, a 3-byte cell in segment 0 whose bank byte the
loader relocates, instead of an immediate operand that could name only
crt0's own bank.>

```

---

### Task 4: fgx_dyn links several code segments

**Files:**
- Modify: `toolchain/src/ld/fgx_dyn.py` (`--code-seg` option; `link_once`, `build`)
- Create: `src/userland/dynmulti/dynmulti.c`, `src/userland/dynmulti/dynmulti2.c`, `src/userland/dynmulti/dynmulti3.c`
- Create: `src/userland/dyntabseg/dyntabseg.c`, `src/userland/dyntabseg/pad.s`
- Modify: `tools/dynso-fgx2/build_dynso.sh` (cases `dynmulti`, `dyntabseg`)
- Modify: `tools/ninja/gen.py` (SHELLS entries for both), `tools/ninja/manifest.json` (stage both to `/testbin`)
- Test: `toolchain/tests/dyn/test_dyn.py` (`multi()`), new `tools/mame_test/tests/dynmulti.json`

**Interfaces:**
- Consumes: Tasks 2-3 (`with_tables(...) -> (body, tseg, t)`).
- Produces: `fgx_dyn.py --code-seg a.s[,b.s]` (repeatable): each adds a code segment after the data segment, in order; `build(name, d, code, data, out, lib_names, override=None, extra=())` with `extra` a list of lists of `.s` paths.

- [ ] **Step 1: The probe sources.**  `src/userland/dynmulti/dynmulti.c`:

```c
/*
 * dynmulti -- shared libc SP5's multi-segment probe: main in code segment
 * 0 calls two functions linked into code segments 2 and 3, each of which
 * calls libc and reads libc data, so every code segment carries import
 * sites.  `DMU <check> ok' or `DMU FAIL <check>' per check, then `DMU ok'.
 */
#include <stdio.h>
#include <string.h>
#include <errno.h>

extern int seg2_fn(), seg3_fn();
static int fails;

static void
chk(c, what)
int c;
char *what;
{
    printf(c ? "DMU %s ok\n" : "DMU FAIL %s\n", what);
    if (!c)
        fails++;
}

int
main()
{
    char b[16];

    errno = 0;
    chk(seg2_fn(b) == 5 && strcmp(b, "seg2!") == 0, "seg2");
    chk(seg3_fn() == 0, "seg3");
    if (!fails)
        printf("DMU ok\n");
    return fails;
}
```

`dynmulti2.c`:

```c
#include <string.h>
#include <errno.h>
int
seg2_fn(b)
char *b;
{
    strcpy(b, "seg2!");
    return errno == 0 ? (int)strlen(b) : -1;
}
```

`dynmulti3.c`:

```c
#include <stdio.h>
#include <errno.h>
int
seg3_fn()
{
    return fputs("", stdout) == EOF ? -1 : errno;
}
```

`src/userland/dyntabseg/dyntabseg.c` (its code segment is filled by `pad.s`):

```c
/* dyntabseg -- a dynamic program whose only code segment has no room for
 * the binder's tables, so they go in an added segment (spec 4.1). */
#include <stdio.h>
int
main()
{
    printf("TAB ok\n");
    return 0;
}
```

`src/userland/dyntabseg/pad.s`:

```
* Fills code segment 0 to within a few hundred bytes of 64 KB.  The exact
* size is set by build_dynso.sh from the first link's report.
_dyntab_pad     DS      PADSIZE
```

- [ ] **Step 2: Write the failing host test.**  Add to `test_dyn.py` (and call it from the main list at the bottom, beside `tables()`):

```python
def multi():
    """Three code segments: sites in each, the tables in the roomiest, a
    cell per segment (spec sections 4, 4.1)."""
    d = tempfile.mkdtemp(prefix="dyn_multi_")
    src = os.path.join(REPO, "src", "userland", "dynmulti")
    c0, d0 = compile_c(os.path.join(src, "dynmulti.c"), d, "dynmulti")
    c2, d2 = compile_c(os.path.join(src, "dynmulti2.c"), d, "dynmulti2")
    c3, d3 = compile_c(os.path.join(src, "dynmulti3.c"), d, "dynmulti3")
    out = os.path.join(d, "dynmulti.bin")
    r = subprocess.run([sys.executable, os.path.join(ROOT, "src", "ld", "fgx_dyn.py"),
                        "--name", "dynmulti", "--dir", os.path.join(d, "ld"),
                        "--code", c0, "--code-seg", c2, "--code-seg", c3,
                        "--data", ",".join([d0, d2, d3]), "--lib", "libc", "--out", out],
                       capture_output=True, text=True)
    check(r.returncode == 0, "dynmulti links with three code segments", (r.stdout + r.stderr)[-400:])
    if r.returncode:
        return
    data = open(out, "rb").read()
    p = fgx_bind.parse(data)
    kinds = [k for _s, _b, k in p["segs"]]
    check(kinds == [0, 1, 0, 0], "segments are code, data, code, code", str(kinds))
    t = fgx_imports.unpack(fgx_ld.read_dyn_trailer(p["trailer"])["blocks_raw"]["IMPS"])
    segs_with_sites = {s[0] for im in t["imports"] for k in fgx_imports.SITES for s in im[k]}
    check({0, 2, 3} <= segs_with_sites, "every code segment carries import sites",
          str(sorted(segs_with_sites)))
```

- [ ] **Step 3: Run it and watch it fail.**

Run: `cd toolchain && python3 tests/dyn/test_dyn.py 2>&1 | grep -A2 "dynmulti"`
Expected: FAIL `dynmulti links with three code segments` (`unrecognized arguments: --code-seg`).

- [ ] **Step 4: `--code-seg`.**  In `main()` add `ap.add_argument("--code-seg", action="append", default=[], help="comma-separated .s files: one more code segment")` and pass `extra=[[os.path.abspath(p) for p in s.split(",")] for s in a.code_seg]` to `build`.

In `build(..., extra=())`: include the extra segments' rows in `code_rows` (for `program_names`, roots and shadow detection), and pass `extra` to both `link_once` calls; the shifted link must produce the same number of segments.  The frames list gains the extra files.

In `link_once(d, code, data_rows, libs, shift, shadowed, gen, frames=None, extra=())`: after assembling seg0, for each `i, files in enumerate(extra)` write and assemble `seg%d` with `i + 2`:

```python
    extra_segs = []
    for i, files in enumerate(extra):
        nm = "seg%d" % (i + 2)
        rt = "\n".join(thunked_runtime(far_helpers(),
                                       "\n".join(sum((read(f) for f in files), []))))
        with open(os.path.join(d, nm + "_rt.s"), "w") as f:
            f.write(rt + "\n")
        b = fgx_libso.run_merlin(d, fgx_libso.write_link(
            d, nm, 0, SEG0_EQUS,
            [fgx_libso.MACROS, "seg1_layout.s", "imports_layout.s"] + files + [nm + "_rt.s"]))
        if b is None:
            die("code segment %d is over 64 KB" % (i + 2))
        extra_segs.append({"bin": nm, "listing": nm + "_Output.txt", "kind": "CODE", "bss": 0})
```

append `extra_segs` to the manifest's `"segments"`, and extend `OUTPUT` (the regex of files a link directory may hold) with `seg[2-8]` and `seg[2-8]_rt\.s`.  Each extra segment carries its own thunked runtime because fcc reaches its helpers by near `JSR`, which cannot leave the bank -- the same reason the tool build gives seg3 its own `fcc_runtime.s` (`tools/ninja/gen.py:645-650`).

Return `(seg0, seg1)` as before; `build`'s site diff already walks every segment of the two links (`fgx_dyn.py:417-421`).

- [ ] **Step 5: Run the host test.**

Run: `cd toolchain && python3 tests/dyn/test_dyn.py | grep -c FAIL`
Expected: `0`.

- [ ] **Step 6: Build the probes.**  In `tools/dynso-fgx2/build_dynso.sh`, add to the first `case`:

```bash
  dynmulti) src=dynmulti/dynmulti.c; libs=libc ;;
  dyntabseg) src=dyntabseg/dyntabseg.c; libs=libc ;;
```

and before the final `fcc`/`fgx_dyn` pair, a branch that builds them:

```bash
case "$name" in
  dynmulti)
    for f in dynmulti dynmulti2 dynmulti3; do
        "$REPO/toolchain/fcc" --sigs "$REPO/build/libc.sigs" \
            --data-segment "$f.data.s" -o "$f.s" "$REPO/src/userland/dynmulti/$f.c"
    done
    python3 "$LD/fgx_dyn.py" --name dynmulti --dir dynmulti.ld --code dynmulti.s \
        --code-seg dynmulti2.s --code-seg dynmulti3.s \
        --data dynmulti.data.s,dynmulti2.data.s,dynmulti3.data.s --lib libc --out dynmulti.dyn
    cp dynmulti.dyn dynmulti.bin; exit 0 ;;
  dyntabseg)
    "$REPO/toolchain/fcc" --sigs "$REPO/build/libc.sigs" \
        --data-segment dyntabseg.data.s -o dyntabseg.s "$REPO/src/userland/dyntabseg/dyntabseg.c"
    pad() { sed "s/PADSIZE/$1/" "$REPO/src/userland/dyntabseg/pad.s" > pad.s; }
    pad 1
    rep=$(python3 "$LD/fgx_dyn.py" --name dyntabseg --dir dyntabseg.ld --code dyntabseg.s,pad.s \
        --data dyntabseg.data.s --lib libc --out dyntabseg.dyn) || exit 1
    s0=$(echo "$rep" | sed -n 's/.*seg0 \([0-9]*\) bytes.*/\1/p')
    pad $((65535 - s0 - 64))            # leaves 64 bytes: too few for the tables
    python3 "$LD/fgx_dyn.py" --name dyntabseg --dir dyntabseg.ld --code dyntabseg.s,pad.s \
        --data dyntabseg.data.s --lib libc --out dyntabseg.dyn || exit 1
    cp dyntabseg.dyn dyntabseg.bin; exit 0 ;;
esac
```

In `tools/ninja/gen.py`'s `SHELLS`, add two entries shaped exactly like `"dyntrue"` (`out`, `script`, `gate`, `links`, `globs`, `extra`, `hard`), with `out="tools/dynso-fgx2/dynmulti.bin"`, `script="tools/dynso-fgx2/build_dynso.sh dynmulti"`, `gate="src/userland/dynmulti"`, `globs=["src/userland/dynmulti/*"]`, and the same for `dyntabseg`.  In `tools/ninja/manifest.json`, beside the `dynsodyn` staging row, add `{"src": "tools/dynso-fgx2/dynmulti.bin", "dst": "disk_src/testbin/dynmulti"}` and the same for `dyntabseg`.

- [ ] **Step 7: The machine test.**  Create `tools/mame_test/tests/dynmulti.json`:

```json
{
 "name": "dynmulti",
 "description": "A DYNAMIC PROGRAM OF SEVERAL CODE SEGMENTS, AND ONE WHOSE TABLES NEED AN ADDED SEGMENT (shared libc SP5 spec 4, 4.1).  dynmulti's main in code segment 0 calls functions in code segments 2 and 3, each reaching libc code and data through its own import sites, so a wrong segment bank in the tables or a site left unpatched in a later segment prints DMU FAIL.  dyntabseg's one code segment is padded to 64 bytes short of full, so the binder's tables are in an added code segment and crt0 finds them only through _dyn_tab.  Each runs twice, the second from the shared-text table.  Markers by expansion.",
 "command": "A=OK; /testbin/dynmulti; echo M1${A}=$?; /testbin/dynmulti; echo M2${A}=$?; /testbin/dyntabseg; /testbin/dyntabseg; echo T${A}=$?",
 "timeout_s": 240,
 "expect": {
  "screen_contains": ["DMU ok", "M1OK=0", "M2OK=0", "TAB ok", "TOK=0"],
  "screen_lacks": ["DMU FAIL", "ld.so:", "PANIC", "BRK"]
 }
}
```

- [ ] **Step 8: Build and run.**  Announce the rebuild.

Run: `python3 tools/ninja/gen.py > /dev/null && ninja > /tmp/sp5t4.log 2>&1; echo rc=$?; python3 tools/mame_test/run.py dynmulti dynrepeat dynskip dynsodyn`
Expected: `rc=0`; `4 passed`.  Check `tools/dynso-fgx2/dyntabseg.ld` link output says three segments (the added one) -- if it says two, the pad left enough room and the test is not testing the added segment: lower the 64.

- [ ] **Step 9: Commit.**

```bash
git add toolchain/src/ld/fgx_dyn.py toolchain/tests/dyn/test_dyn.py src/userland/dynmulti \
  src/userland/dyntabseg tools/dynso-fgx2/build_dynso.sh tools/ninja/gen.py \
  tools/ninja/manifest.json tools/mame_test/tests/dynmulti.json
git commit -m "feat(ld): a dynamic program may have several code segments

<body: fgx_dyn takes --code-seg for each code segment after the data
segment; each carries its own thunked fcc runtime, its sites are found by
the same two-link difference, and the tables go in the roomiest.
dynmulti spans three code segments; dyntabseg fills its one so the tables
take an added segment.>

```

---

### Task 5: `_lib_copy`'s MVN runs from the data bank

**Files:**
- Modify: `toolchain/lib/crt0_lib.s:60-94`
- Create: `toolchain/lib/crt0_lib_data.s` (the 4-byte cell)
- Modify: `toolchain/src/ld/fgx_dyn.py:234` and `toolchain/src/ld/fgx_static.py:162-164` (PUT it in the data segment)

Not in `fcc_runtime_data.s`: that file is also PUT into libc.so's core (`toolchain/Makefile:73`, `fgx_libso.DATA`) and into every pile tool's seg1, so the cell would grow libc's core by 4 bytes, move every prebound data address and relink every library and probe -- and the exectime comparison would measure that too.  crt0_lib's programs are exactly fgx_dyn's and fgx_static's.
- Test: new check in `toolchain/tests/dyn/test_dyn.py` (`no_text_store()`); machine: the existing probes and `exectime`

**Interfaces:**
- Produces: `_lib_copy_cell` (data segment, at $0100 or above): `MVN $00,$00` then `RTL`.

- [ ] **Step 1: Write the failing check.**  Add to `test_dyn.py` (and to the main list):

```python
def no_text_store():
    """crt0_lib writes nothing into its own code segment, which is shared
    text (spec section 5.1): no store names a label of segment 0's code."""
    src = open(os.path.join(ROOT, "lib", "crt0_lib.s")).read()
    check("_lib_copy_mvn" not in src and "_lib_copy_cell" in src,
          "_lib_copy's MVN is the data bank's _lib_copy_cell")
```

Run: `cd toolchain && python3 tests/dyn/test_dyn.py | grep -E "FAIL.*lib_copy"`
Expected: `FAIL _lib_copy's MVN is the data bank's _lib_copy_cell`.

- [ ] **Step 2: The cell.**  Create `toolchain/lib/crt0_lib_data.s`:

```
;==============================================================================
; crt0_lib_data.s - crt0_lib.s's data, in the data segment of every program
; that starts through crt0_lib (fgx_dyn's and fgx_static's links).
;
; _lib_copy's MVN: its bank bytes are written per call, so it lives in the
; process's data bank, never in shared code.  At $0100 or above, behind the
; data segment's 256-byte pad, so no operand naming it is direct-page.
;==============================================================================
                FGX2_EXPORT _lib_copy_cell
_lib_copy_cell  DFB     $54,$00,$00             ; MVN: opcode, dst bank, src bank
                DFB     $6B                     ; RTL
```

PUT it in both data segments.  `fgx_dyn.py`'s seg1 list (`:233-234`) becomes:

```python
        [fgx_libso.MACROS, "dataptr_mac.s", "imports_layout.s",
         os.path.join(LIB, "fcc_runtime_data.s"), os.path.join(LIB, "crt0_lib_data.s"),
         "prog.data.s", "dyn.data.s"],
```

and `fgx_static.py`'s (`:162-164`):

```python
    link = fgx_libso.write_link(d, "seg1", 0, fgx_libso.DATA_EQUS,
                                [fgx_libso.MACROS] + fgx_libso.DATA
                                + [os.path.join(fgx_libso.LIB, "crt0_lib_data.s"),
                                   "libc.data.s"] + data, pad=256)
```

Add `toolchain/lib/crt0_lib_data.s` to the `extra` list of every dynamic probe's `SHELLS` entry in `gen.py` and to the `dynlink` edge's inputs in Task 7, so editing it relinks them.

- [ ] **Step 3: `_lib_copy` (65816; main agent).**  Replace from the comment above `_lib_copy` to `@lc_none RTL` with:

```
;------------------------------------------------------------------------------
; _lib_copy(dst, src, n) - copy n bytes from far pointer src to far pointer
; dst with MVN.  MVN's two bank bytes are immediates in the instruction, so
; the MVN is _lib_copy_cell in this process's data bank (crt0_lib_data.s):
; segment 0 is shared text and is never written.  DBR is the data bank on
; entry (crt0_dyn and libc's binder both run with it); the cell is reached
; by a JSL built on the stack, since its bank is DBR and not a link-time
; value.  fcc's far-call convention: the first argument nearest, each
; pointer low word then bank word.  n = 0 copies nothing (MVN would copy
; 64 KB).
;------------------------------------------------------------------------------
                FGX2_EXPORT _lib_copy
_lib_copy       MX      %00
                LDA     12,S                    ; n
                BEQ     @lc_none
                DEC
                PHB
                PHA                             ; 1,S = n - 1; arguments up 3
                SEP     #$20
                MX      %10
                LDA     9,S                     ; dst bank
                STA     |_lib_copy_cell+1
                LDA     13,S                    ; src bank
                STA     |_lib_copy_cell+2
                REP     #$20
                MX      %00
                LDA     7,S                     ; dst offset
                TAY
                LDA     11,S                    ; src offset
                TAX
                PLA                             ; n - 1
                PHK
                PEA     @lc_back-1              ; the return a JSL would push
                PHB                             ; the cell's bank: DBR
                PEA     _lib_copy_cell-1
                RTL                             ; JSL _lib_copy_cell
@lc_back        PLB                             ; MVN left DBR = dst
@lc_none        RTL
```

`PHB` pushes one byte and `RTL` pops three (two of `PEA`, one of `PHB`) as the target `bank:offset-1`, then the cell's own `RTL` pops `PHK`'s byte and `PEA`'s two as the return.  `_lib_copy_cell` reaches segment 0 through `seg1_layout.s`, like every data label crt0 names.

- [ ] **Step 4: Rebuild; host check; machine.**  Announce the rebuild.

Run: `ninja > /tmp/sp5t5.log 2>&1; echo rc=$?; cd toolchain && python3 tests/dyn/test_dyn.py | grep -c FAIL; cd .. && python3 tools/mame_test/run.py dynsodyn dynsomisdyn curssodyn cursexec dynrepeat dynskip dynmulti libcso exectime`
Expected: `rc=0`, `0`, `9 passed`.  Record exectime's three `EXT` figures in the commit body beside the figures from before this task (run `exectime` once before Step 2 to have them); dyntrue's must be within 10% of the before figure.

- [ ] **Step 5: Commit.**

```bash
git add toolchain/lib/crt0_lib.s toolchain/lib/crt0_lib_data.s toolchain/src/ld/fgx_dyn.py \
  toolchain/src/ld/fgx_static.py tools/ninja/gen.py toolchain/tests/dyn/test_dyn.py
git commit -m "fix(libc): _lib_copy writes its MVN in the data bank, not shared code

<body: _lib_copy wrote MVN's bank bytes into itself in segment 0, which
is shared text; it now writes them into _lib_copy_cell, four bytes of
initialised data in the process's own bank, and reaches it by a JSL built
from DBR.  exectime before/after: <figures>.>

```

---

### Task 6: The record's compare and repatch, on the machine

**Files:**
- Create: `src/userland/dynrebind/dynrebind.c`
- Modify: `tools/dynso-fgx2/build_dynso.sh` (case `dynrebind`), `tools/ninja/gen.py` (SHELLS entry), `tools/ninja/manifest.json` (staging)
- Test: new `tools/mame_test/tests/dynrebind.json`

**Interfaces:**
- Consumes: `_dyn_tab` (Task 3), the table layout (Task 2).

- [ ] **Step 1: The probe.**  `src/userland/dynrebind/dynrebind.c`:

```c
/*
 * dynrebind -- shared libc SP5 spec 5.3's compare and repatch, reached on
 * purpose.  Run with no argument it checks errno through a code-segment
 * data site (`RBD ok' or `RBD FAIL'), then corrupts that site's word in
 * its own (shared) code and one byte of its bind record's first bank, and
 * execs itself with `again'.  The second run's binder must see the record
 * no longer match, patch the code segments again -- repairing the site --
 * and write a new record; the check passes only if it did.
 */
#include <stdio.h>
#include <errno.h>

extern unsigned char _dyn_tab[];
extern int execl();

static int
check()
{
    errno = 1234;
    return errno == 1234;
}

int
main(argc, argv)
int argc;
char **argv;
{
    unsigned char *tab, *q, *rec, *p;
    unsigned n, ilen, i;

    printf(check() ? "RBD ok\n" : "RBD FAIL\n");
    if (argc > 1)
        return 0;
    /* fcc addresses an extern array DBR-relative, so `_dyn_tab' alone would
     * read the DATA bank at the code label's offset.  A function designator
     * carries its code bank (a hidden long pointer), so the cell is reached
     * as check's bank : _dyn_tab's offset. */
    p = (unsigned char *)(((unsigned long)(unsigned char *)check & 0xFF0000L) |
                          ((unsigned)_dyn_tab & 0xFFFF));
    tab = (unsigned char *)(((unsigned long)p[2] << 16) | (p[0] | p[1] << 8));
    n = tab[0] | tab[1] << 8;
    q = tab + 4 + 4 * n;
    ilen = q[0] | q[1] << 8;
    rec = q + 2 + ilen;
    rec[2] ^= 0xFF;                     /* the first library's first bank */
    /* Corrupt the word of every data site of `errno' in code segment 0:
     * found by walking IMPS is long; the probe's errno sites are the
     * operands check() assembles to, so scan check()'s bytes instead. */
    q = (unsigned char *)check;
    for (i = 0; i < 64; i++)
        if (q[i] == 0x8D || q[i] == 0xAD) {   /* STA abs / LDA abs */
            q[i + 1] ^= 0x55;
            break;
        }
    execl(argv[0], argv[0], "again", (char *)0);
    printf("RBD FAIL exec\n");
    return 1;
}
```

Check against the probe's listing (`dynrebind.ld/seg0_Output.txt`) that `(unsigned)_dyn_tab` assembled to `_dyn_tab`'s segment-0 offset (not a data-bank address), and that the first `STA`/`LDA` absolute in `check` is an `errno` data site; if fcc emits a long store there, adjust the opcode test to that listing.  A wrong guess shows as `RBD FAIL` on the FIRST line of the second run with the control off -- which is what Step 3 checks.

- [ ] **Step 2: Wire it** as `dyntrue` is wired: `dynrebind) src=dynrebind/dynrebind.c; libs=libc ;;` in `build_dynso.sh`'s first case and in its "bound on the machine" copy case; a `SHELLS` entry and a manifest staging row to `disk_src/testbin/dynrebind`.  Create `tools/mame_test/tests/dynrebind.json`:

```json
{
 "name": "dynrebind",
 "description": "THE BIND RECORD'S COMPARE AND REPATCH (shared libc SP5 spec 5.3, plan ruling R2).  No kernel path reclaims a library while a cached text bound to it exists, so the probe makes the mismatch itself: it corrupts an errno data site in its own shared code and a bank byte of its bind record, then execs itself.  The second run's binder must find the record stale, repatch every code site and write a new record; its errno check passes only if the site was repaired.  Control: skip the compare (treat the record as matching); the second run prints RBD FAIL.",
 "command": "/testbin/dynrebind",
 "timeout_s": 180,
 "expect": {
  "screen_contains": ["RBD ok"],
  "screen_lacks": ["RBD FAIL", "ld.so:", "PANIC", "BRK"]
 }
}
```

- [ ] **Step 3: Build, run, control.**  Announce the rebuild.

Run: `python3 tools/ninja/gen.py > /dev/null && ninja > /tmp/sp5t6.log 2>&1; echo rc=$?; python3 tools/mame_test/run.py dynrebind`
Expected: `rc=0`; PASS, with `RBD ok` printed twice on screen.
Control: in `ld_bind.c`, replace `match = rec[0] | rec[1];` by `match = 1;` (and skip the compare loop), rebuild, run `dynrebind`: FAIL (`RBD FAIL`).  Restore, rebuild, rerun: PASS.

- [ ] **Step 4: Commit.**

```bash
git add src/userland/dynrebind tools/dynso-fgx2/build_dynso.sh tools/ninja/gen.py \
  tools/ninja/manifest.json tools/mame_test/tests/dynrebind.json
git commit -m "test(libc): the bind record's repatch, reached by a probe

<body: dynrebind corrupts a patched site and its record in its own
shared code, then execs itself; the binder must find the record stale
and repatch.>

```

---

### Task 7: Manifest tools link dynamically: wc, ls, ul, worm, ntpd

**Why not cat:** `disk_src/etc/rc.in:96` runs `cat /etc/motd` before `/sbin/modload ... ld` (`:137`) and `/sbin/ldload` (`:144`), so a dynamic cat would print `ld.so: libc.so.1 not loaded` at every boot.  Nothing else on this list runs before ldload (rc.in runs date, echo, adjkerntz, cat, chmod, fsck, mount, rm, modload and ldload there).  wc stands in for the one-segment case.

**Files:**
- Modify: `tools/ninja/gen.py` (the `dynlink` rule; the dynamic branch of the tool loop)
- Modify: `tools/ninja/manifest.json` (`"dynamic": true` on wc, ls, ul, worm, ntpd)
- Test: new `tools/mame_test/tests/dyntools.json`

**Interfaces:**
- Consumes: `fgx_dyn.py --code-seg` (Task 4).
- Produces: a manifest field `"dynamic": true`: the tool's `bin/<name>.bin` is fgx_dyn's output; staging is unchanged.

- [ ] **Step 1: Write the failing machine test.**  Create `tools/mame_test/tests/dyntools.json`:

```json
{
 "name": "dyntools",
 "description": "MANIFEST TOOLS LINKED DYNAMICALLY THROUGH THE BUILD (shared libc SP5 step 1).  ul runs first so libtermlib is loaded on first use under the new tables (nothing in ld.so.conf pins it); ldd shows each tool resolved against the shared libraries; wc and ls run from their dynamic images; worm and ntpd are proven through ldd, which runs their binders in full (libcurses first use for worm; ntpd's second code segment).  Markers by expansion: the file's contents, its name and wc's count are assembled from variables, so the typed line cannot satisfy them.  Before this step every one is a pile binary and ldd says `statically linked'.",
 "command": "A=UL; echo xyz | ul; echo ${A}=$?; ldd /bin/wc /bin/ls /bin/ul /bin/worm /sbin/ntpd; H=hel; D=/tmp/d; echo ${H}lo wor${H} > ${D}t; wc -w ${D}t; ls ${D}t",
 "timeout_s": 300,
 "expect": {
  "screen_contains": ["UL=0", "-lc.1 => /lib/libc.so.1.0", "-ltermlib.1 => /lib/libtermlib.so.1.0", "-lcurses.1 => /lib/libcurses.so.1.0", "2 /tmp/dt", "/tmp/dt"],
  "screen_lacks": ["statically linked", "ld.so:", "PANIC", "BRK"]
 }
}
```

The staged paths are `tools/ninja/manifest.json`'s: `disk_src/bin/wc`, `bin/ls`, `bin/ul`, `bin/worm`, `sbin/ntpd`.

- [ ] **Step 2: Run it and watch it fail.**

Run: `python3 tools/mame_test/run.py dyntools`
Expected: FAIL -- `statically linked` present, the `-l...` lines absent.

- [ ] **Step 3: The `dynlink` rule.**  In `tools/ninja/gen.py` beside `rule libso`:

```python
lines.append(
    "rule dynlink\n"
    "  command = python3 toolchain/src/ld/fgx_dyn.py --name $name --dir $dir "
    "--code $code $codesegs --data $data --lib $libs --out $out > $out.log 2>&1 "
    "|| (cat $out.log; false)\n"
    "  description = fgx_dyn $name")
```

(match how the surrounding rules are emitted -- a literal string in the rules block or `lines.append` -- by reading the neighbours.)

- [ ] **Step 4: The dynamic branch.**  In the tool loop, right after `tus`, `libs` and `src` are known and before `materialize_links(...)` is called, add:

```python
        if rec.get("dynamic"):
            lib_map = {"termlib": "libtermlib", "curses": "libcurses"}
            bad = [l for l in libs if l not in lib_map]
            if bad:
                raise SystemExit(f"{name}: dynamic, but {bad} has no shared library")
            dlibs = ",".join(["libc"] + [lib_map[l] for l in libs])
            b = f"tools/{name}-fgx2"
            os.makedirs(os.path.join(ROOT, b), exist_ok=True)
            tu_stems = [os.path.basename(t)[:-2] for t in tus]
            flags = (" " + rebase_flags(rec["flags"])) if rec["flags"] else ""
            lines.append(f"\n# ---- {name} (dynamic) " + "-" * 40)
            lines.append(
                f"build {b}/{name}.s | {b}/{name}.data.s: fcc_c {src} | $fcc build/libc.sigs\n"
                f"  data = {b}/{name}.data.s\n  flags ={flags}\n  softscc =")
            for tu, stem in zip(tus, tu_stems):
                lines.append(
                    f"build {b}/{stem}.s | {b}/{stem}.data.s: fcc_c {tu} | $fcc build/libc.sigs\n"
                    f"  data = {b}/{stem}.data.s\n  flags ={flags}\n  softscc =")
            seg3 = set(rec.get("seg3_tus", []))
            seg4 = set(rec.get("seg4_tus", []))
            code0 = [f"{b}/{name}.s"] + [f"{b}/{t}.s" for t in tu_stems if t not in seg3 | seg4]
            stub = os.path.join("src/userland", name, f"{name}_stubs.s")
            if os.path.isfile(os.path.join(ROOT, stub)):
                code0.append(stub)
            codesegs = "".join(
                " --code-seg " + ",".join(f"{b}/{t}.s" for t in tu_stems if t in grp)
                for grp in (seg3, seg4) if grp)
            data = [f"{b}/{name}.data.s"] + [f"{b}/{t}.data.s" for t in tu_stems]
            alls = code0 + [f"{b}/{t}.s" for t in tu_stems if t in seg3 | seg4]
            lines.append(
                f"build bin/{name}.bin: dynlink {' '.join(alls)} {' '.join(data)} | "
                "toolchain/src/ld/fgx_dyn.py toolchain/src/ld/fgx_imports.py "
                "toolchain/src/ld/fgx_sites.py toolchain/src/ld/fgx_static.py "
                "toolchain/lib/crt0_dyn.s toolchain/lib/crt0_lib.s "
                "toolchain/lib/crt0_lib_data.s "
                "toolchain/lib/libc.so.1.0 toolchain/lib/libtermlib.so.1.0 "
                "toolchain/lib/libcurses.so.1.0\n"
                f"  name = {name}\n  dir = {b}/dyn.ld\n  code = {','.join(code0)}\n"
                f"  codesegs ={codesegs}\n  data = {','.join(data)}\n  libs = {dlibs}")
            built.append(name)
            continue
```

Read the loop's surrounding code first: the variable that holds the tool's main source (`src` above), its flags (`rec["flags"]`), and the name of the built-list (`built`) must match what the loop already uses, and `continue` must skip exactly the pile path for this tool.  The soft-frame list (`src/softscc/<name>.txt`) is not applied to dynamic tools in step 1; none of the five has one (`ls src/softscc/`) -- check, and if one does, pass `softscc` as the pile path does.

- [ ] **Step 5: Mark the five tools.**  In `tools/ninja/manifest.json`, add `"dynamic": true` to the entries named `wc`, `ls`, `ul`, `worm` and `ntpd`.  ntpd's `libc_overlay` is ignored by the dynamic branch, which is right: libc.so exports what the overlay carried (syslog, ctime, the resolver).

- [ ] **Step 6: Build.**  Announce: the main checkout is rebuilt and five tools on the boot disk become dynamic.

Run: `python3 tools/ninja/gen.py > /dev/null && ninja > /tmp/sp5t7.log 2>&1; echo rc=$?; for t in wc ls ul worm ntpd; do tail -1 bin/$t.bin.log; done; ls tools/ntpd-fgx2/dyn.ld/seg2_Output.txt`
Expected: `rc=0`; five `dyn <name>: seg0 ... LIM $....` lines; the `ls` finds ntpd's second code segment's listing (its `ntp_proto` TU).  If fgx_dyn dies `no room for its data` on any of the five (ntpd's data and reached blocks against the dynamic ceiling are not measured yet), STOP and report the figures before narrowing the list.

- [ ] **Step 7: Machine.**

Run: `python3 tools/mame_test/run.py dyntools dynrepeat dynskip dynmulti dynrebind dynsodyn curssodyn ldfit ldd exectime`
Expected: `10 passed`.  Then the full gate, which stays green because no gate test runs a changed tool except through them: `tools/gate.sh > /tmp/sp5gate.log 2>&1; tail -3 /tmp/sp5gate.log` -> `GATE GREEN`.  If a gate test fails on wc or ls, that is a real regression in this step: debug it before committing.  Boot a fresh image once and read the console: no `ld.so:` line may appear during `/etc/rc` (the reason cat is not on the list).

- [ ] **Step 8: Commit.**

```bash
git add tools/ninja/gen.py tools/ninja/manifest.json tools/mame_test/tests/dyntools.json
git commit -m "feat(build): wc, ls, ul, worm and ntpd link dynamically

<body: a manifest tool marked dynamic is compiled as before and linked by
fgx_dyn against libc.so (and libtermlib.so, libcurses.so for termlib and
curses), its seg3/seg4 TUs as further code segments, instead of through a
libc pile.  Every other tool is unchanged.  dyntools: ul loads libtermlib
on first use; ldd resolves all five.>

```

---

## After the last task

- Run every probe of this step and of SP4 once together: `python3 tools/mame_test/run.py dynrepeat dynskip dynmulti dynrebind dyntools dynsodyn dynsomisdyn curssodyn cursexec dynso cursso ldfit lddigest ldd exectime` -> all pass.
- Final whole-branch review (a fresh reviewer on the most capable model) of `git diff 3c109e53c..HEAD`, with this plan's Review Focus and rulings R1-R5.
- Update the ROADMAP's shared libc paragraph: step 1 landed; two questions are open before step 2 -- libfgx's home (R3), and the programs `/etc/rc` runs before `ldload` (date, echo, adjkerntz, cat, chmod, rm; `disk_src/etc/rc.in:1-144`), which must stay static or run after it, since a dynamic program started before libc.so is resident exits with `ld.so: libc.so.1 not loaded`.
