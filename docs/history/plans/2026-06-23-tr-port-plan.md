# tr(1) Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port 2.11BSD `tr(1)` to FGX as an FGX2 C userland tool, ported **verbatim** — by first **implementing the missing libc functions** (`putchar`, `clearerr`, `ferror`, `feof`) it needs, never by rewriting the source to dodge them.

**Architecture:** Two layers. (1) Grow the FGX libc: the `__sFILE` table already reserves `_IOEOF`/`_IOERR` flag bits but no I/O path sets them — wire them up and add the four standard accessors. (2) Port `examples/2.11BSD/usr/usr.bin/tr.c` (137 lines) into `src/userland/tr/tr.c` essentially byte-for-byte (provenance header only), built via `build_userbin_fgx2_c`. A host clang build of the upstream source is the test oracle; MAME JSON manifests are the gate.

**Tech Stack:** 65816 asm (`toolchain/lib/libc.s`, `fcc_libc_shims.s`), C (fcc), `toolchain/src/cc/globals.c` (binding table), Merlin32 + `fgx_ld.py`, `build.sh`, `tools/mame_test/run.py`, host `clang` (oracle only).

## Global Constraints

- **Branch:** `feat/tr-sed-port` — never commit to `main`.
- **Build target:** FGX2 via `build_userbin_fgx2_c tr`.
- **CORE RULE — implement, never work around.** When libc lacks a function a port needs, IMPLEMENT it in libc as a proper reusable function (bare entry in `libc.s` + `c_<name>` shim in `fcc_libc_shims.s` + binding row in `globals.c` + prototype in the header), then rebuild fcc. Do NOT adapt/rewrite the BSD source to avoid it, and do NOT use a per-tool stub. The historical dodges (`strings.c` collapsing `ferror`/`feof`; `clear.c`'s local `putchar`) are tech debt, not precedent.
- **Provenance:** `tr.c` MUST carry the three header markers (`SPDX-License-Identifier: BSD-2-Clause`, `FGX-Provenance: 2.11BSD`, `Regents of the University of California`) + a `docs/PROVENANCE.md` registry row; `check_provenance.py` (in `./build.sh disk`) enforces it.
- **Testing:** closed-loop silent/headless MAME (`run.py --headless`), per-test progress; validate against the host clang reference.
- **Scope:** full `tr` — `-c`, `-d`, `-s`, `a-z` ranges, `\nnn` octal escapes.
- **Execution split:** Task 1 is **65816 asm → run inline** in the main agent (subagents are unreliable for FGX asm). Tasks 2–4 are **C porting → subagent-OK** (writing C, clang oracle, build.sh, MAME tests are not the asm failure class).
- **Toolchain submodule:** Task 1 modifies `toolchain/` and re-pins it; follow the toolchain workflow (`cd toolchain && make`; `bash toolchain/tests/run.sh` golden suite stays green).

## File Structure

- `toolchain/lib/libc.s` — set `_IOEOF`/`_IOERR` in `fgetc`/`fread`/`fputc`/`fputs`/`fwrite`; add bare `putchar`/`feof`/`ferror`/`clearerr`.
- `toolchain/lib/fcc_libc_shims.s` — `c_putchar`/`c_feof`/`c_ferror`/`c_clearerr` (fcc stack-ABI shims).
- `toolchain/src/cc/globals.c` — 4 binding rows.
- `toolchain/include/stdio.h` — 4 prototypes.
- `toolchain/tests/M*/…` — one runtime fixture exercising the new accessors.
- `src/userland/tr/tr.c` — the tool (tracked; verbatim + provenance header). Only new userland source.
- `tools/tr-fgx2/`, `bin/tr.bin` — build artifacts (already gitignored).
- `build.sh` — two one-line edits. `docs/PROVENANCE.md` — one row.
- `tools/mame_test/tests/tr_*.json` — 6 manifests.

---

### Task 1 (ASM — INLINE): implement `putchar`/`clearerr`/`ferror`/`feof` + EOF/err flag tracking in libc

**Files:**
- Modify: `toolchain/lib/libc.s` (`fgetc` ~3036, `fputc` ~3064, `fputs` ~3095, `fread`, `fwrite`; add 4 entries)
- Modify: `toolchain/lib/fcc_libc_shims.s` (add 4 `c_*` shims)
- Modify: `toolchain/src/cc/globals.c` (~line 143, after `fputs`)
- Modify: `toolchain/include/stdio.h`
- Create: `toolchain/tests/<M-dir>/stdio_flags.c` (+ expected golden) — runtime fixture

**Interfaces:**
- Produces (C-visible): `int putchar(int c)` (= `fputc(c, stdout)`); `int feof(FILE *fp)`; `int ferror(FILE *fp)`; `void clearerr(FILE *fp)`. `feof`/`ferror` return nonzero iff the FILE's `_IOEOF`/`_IOERR` bit is set; `clearerr` clears both. EOF on `getc`/`fgetc`/`fread` sets `_IOEOF`; a syscall write/read *error* sets `_IOERR`.
- Existing facts: `struct __sFILE { short _file; short _flag; }`, `__sFILE_flag EQU 2`; `_IOEOF EQU $0010`, `_IOERR EQU $0020`; `fgetc` caches the FILE* in `fio_fp`, returns `$FFFF`/`CLC` on both EOF and error (the BCC = syscall error, the `CMP #0/BEQ` = 0-byte EOF). `fputc`/`fputs` cache `fio_fp` and take the error exit on `BCC`. Binding rows look like `{"fputc", "c_fputc", 0},`.

- [ ] **Step 1: Set the EOF/error flags in the read path (`fgetc`)**

In `libc.s` `fgetc`, split the single `@fgc_eof` target so the syscall-error branch (`BCC`) sets `_IOERR` and the 0-byte branch (`BEQ`) sets `_IOEOF`, both then returning `$FFFF`/`CLC`. Set the bit via the cached `fio_fp` FILE* at offset `__sFILE_flag` (read flag word, `ORA #_IOEOF`/`#_IOERR`, store back). Mirror the same flag-setting into `fread`'s EOF/short-read and error exits.

- [ ] **Step 2: Set the error flag in the write path (`fputc`, `fputs`, `fwrite`)**

At each `@…_err` exit (reached on `BCC` after `SYS_WRITE`), set `_IOERR` in the cached `fio_fp` FILE*'s flag word before `CLC/RTS`.

- [ ] **Step 3: Add the four bare entries in `libc.s`**

`feof`/`ferror` (A = FILE*): load `__sFILE_flag,(fp)`, mask `_IOEOF`/`_IOERR`, return A = 0/nonzero. `clearerr` (A = FILE*): `AND #~(_IOEOF|_IOERR)` into the flag word. `putchar` (A.lo = c): set Y = `stdout`, fall through / `JMP fputc`.

- [ ] **Step 4: Add the fcc shims + bindings + prototypes**

- `fcc_libc_shims.s`: `c_putchar` (pull `c` off the fcc stack → A, `JMP putchar`), `c_feof`/`c_ferror`/`c_clearerr` (pull `FILE*` → A, `JMP` the bare entry). Model on the existing `c_fputc`/`c_fgetc` shims.
- `globals.c` after line 143: add
  ```c
      {"putchar",  "c_putchar",  0},
      {"feof",     "c_feof",     0},
      {"ferror",   "c_ferror",   0},
      {"clearerr", "c_clearerr", 0},
  ```
- `stdio.h`: add
  ```c
  int   putchar(int c);
  int   feof(FILE *fp);
  int   ferror(FILE *fp);
  void  clearerr(FILE *fp);
  ```

- [ ] **Step 5: Rebuild fcc; golden suite stays green**

```bash
cd ~/projects/Retro/Apple/fgx/toolchain && make 2>&1 | tail -5
bash tests/run.sh 2>&1 | tail -5
```
Expected: fcc builds; golden suite reports its current pass count with 0 failures (adding shims/entries is additive; if a golden regenerates because a shared file changed, regen + verify per the toolchain workflow).

- [ ] **Step 6: Runtime fixture for the new accessors**

Add a minimal fcc runtime fixture (`stdio_flags.c`) modelled on the existing `tests/M*` runtime tests: read `stdin` to EOF via `getc`, then assert `feof(stdin)` is nonzero and `ferror(stdin)` is zero; `putchar` a known byte; return a fixed status (< 100, per the harness marker note). Run via `python3 toolchain/tests/run_runtime.py <name>` (the toolchain runtime harness). Expected: PASS.

- [ ] **Step 7: Commit (toolchain), then re-pin the submodule in FGX**

```bash
cd ~/projects/Retro/Apple/fgx/toolchain
git add lib/libc.s lib/fcc_libc_shims.s src/cc/globals.c include/stdio.h tests/
git commit -m "feat(libc): implement putchar/clearerr/ferror/feof + EOF/err flag tracking

__sFILE _IOEOF/_IOERR were defined but never set; fgetc/fread now set
them on EOF vs error, fputc/fputs/fwrite set _IOERR on write error.
Adds the four standard accessors + fcc bindings.  Unblocks verbatim
BSD ports (tr) instead of per-tool ferror/putchar workarounds.

cd ~/projects/Retro/Apple/fgx
git add toolchain
git commit -m "chore(toolchain): re-pin to libc putchar/clearerr/ferror/feof

```

---

### Task 2 (C — subagent-OK): port `tr.c` verbatim and validate against the host clang oracle

**Files:**
- Create: `src/userland/tr/tr.c`
- Oracle (throwaway): `<scratchpad>/tr-oracle/`

**Interfaces:**
- Consumes: the libc functions from Task 1 (so `tr.c` keeps `getc`/`putchar`/`clearerr`/`ferror` unchanged).
- Produces: `src/userland/tr/tr.c` — upstream `tr.c` + provenance header, otherwise byte-for-byte.

- [ ] **Step 1: Host oracle from the unmodified upstream source**

```bash
SCRATCH="<scratch>
mkdir -p "$SCRATCH"
clang -std=gnu89 -w -o "$SCRATCH/tr_upstream" ~/projects/Retro/Apple/fgx/examples/2.11BSD/usr/usr.bin/tr.c
T="$SCRATCH/tr_upstream"
{ printf 'hello\n'  | "$T" a-z A-Z
  printf 'a1b2c3\n' | "$T" -d 0-9
  printf 'hello\n'  | "$T" -s l
  printf 'ab12cd\n' | "$T" -cd 'a-z'
  printf 'abc\n'    | "$T" 'a' '\101'
  printf 'HELLO\n'  | "$T" A-Z a-z ; } | tee "$SCRATCH/golden.txt"
```
Expected `golden.txt`:
```
HELLO
abc
helo
abcd
Abc
hello
```
(If any differ, correct the Task 4 inputs to match — the oracle is authoritative.)

- [ ] **Step 2: Create `src/userland/tr/tr.c` = upstream verbatim + provenance header**

Copy `examples/2.11BSD/usr/usr.bin/tr.c` verbatim, then replace ONLY the `sccsid` line 1 with this header (keep the existing `#include <stdio.h>` and ALL logic, including `putchar`/`clearerr`/`ferror`, unchanged):

```c
/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD tr(1)
 *   Ported from tr(1), 2.11BSD (4.2, Berkeley, 4/22/85).  Original work:
 *   Copyright (c) 1985 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * tr - transliterate / delete / squeeze characters.  Port of 2.11BSD tr(1),
 * VERBATIM: -c/-d/-s, a-z ranges, \nnn octal escapes.  No source adaptation —
 * the libc functions it needs (putchar/clearerr/ferror) are implemented in
 * libc (see toolchain/lib/libc.s), per the implement-don't-work-around rule.
 */
```

- [ ] **Step 3: Confirm verbatim source still matches the oracle on the host**

```bash
SCRATCH="<scratch>
clang -std=gnu89 -w -o "$SCRATCH/tr_fgx" ~/projects/Retro/Apple/fgx/src/userland/tr/tr.c
T="$SCRATCH/tr_fgx"
{ printf 'hello\n'|"$T" a-z A-Z; printf 'a1b2c3\n'|"$T" -d 0-9; printf 'hello\n'|"$T" -s l
  printf 'ab12cd\n'|"$T" -cd 'a-z'; printf 'abc\n'|"$T" 'a' '\101'; printf 'HELLO\n'|"$T" A-Z a-z; } > "$SCRATCH/fgx_out.txt"
diff "$SCRATCH/golden.txt" "$SCRATCH/fgx_out.txt" && echo "ORACLE MATCH"
```
Expected: `ORACLE MATCH` (only the header comment changed, so it must match).

- [ ] **Step 4: Commit**

```bash
cd ~/projects/Retro/Apple/fgx
git add src/userland/tr/tr.c
git commit -m "feat(tr): port 2.11BSD tr(1) verbatim to C (FGX2)

Verbatim port (provenance header only); relies on the libc
putchar/clearerr/ferror just implemented.  Host-clang oracle matches.

```

---

### Task 3 (C — subagent-OK): wire `tr` into the FGX2 build

**Files:**
- Modify: `build.sh` (build list ~line 152; `/bin` disk-stage ~line 390), `docs/PROVENANCE.md`

**Interfaces:**
- Consumes: `src/userland/tr/tr.c`, the re-pinned toolchain.
- Produces: `bin/tr.bin` (FGX2) staged to `disk_src/BIN/TR`; provenance gate green.

- [ ] **Step 1: Build list** — after the `build_userbin_fgx2_c ed` block add:
```bash
    build_userbin_fgx2_c tr       # FGX2 (default for new C userland)
```

- [ ] **Step 2: Disk-stage** — in the `# /bin` block (near `cp bin/grep.bin disk_src/BIN/GREP`) add:
```bash
    cp bin/tr.bin    disk_src/BIN/TR
```
(No `_FileInformation.txt` edit — `_gen_fileinfo disk_src/BIN` auto-emits type 06. No `.gitignore` edit.)

- [ ] **Step 3: Provenance row** — in `docs/PROVENANCE.md` "Registered" table add:
```markdown
| `src/userland/tr/tr.c`             | 2.11BSD `tr(1)`       | verbatim; -c/-d/-s, a-z ranges, \nnn octal; uses libc putchar/clearerr/ferror |
```

- [ ] **Step 4: Build and verify**
```bash
cd ~/projects/Retro/Apple/fgx
./build.sh disk 2>&1 | tee /tmp/tr_build.log | tail -40
ls -l bin/tr.bin && ls -l disk_src/BIN/TR && echo "TR STAGED OK"
```
Expected: `Built bin/tr.bin (FGX2)`; `bin/tr.bin` + `disk_src/BIN/TR` exist; provenance gate passes. If `fcc` errors on `tr.c`, it is a real fcc gap (`register`, the `if(c = code[...]&0377)` assign-in-condition, `argv[0][1]` double-index) — diagnose vs `docs/fcc-known-issues.md`, fix in `toolchain/src/cc/` with a fixture (golden green), re-pin; do NOT alter `tr.c`. This is an asm/fcc fix → escalate to inline.

- [ ] **Step 5: Commit**
```bash
cd ~/projects/Retro/Apple/fgx
git add build.sh docs/PROVENANCE.md
git commit -m "build(tr): register FGX2 tr in build + disk-stage + provenance

```

---

### Task 4 (C — subagent-OK): closed-loop MAME tests — 6 manifests, green headless

**Files:**
- Create: `tools/mame_test/tests/tr_{basic,delete,squeeze,compdel,octal,range}.json`

**Interfaces:**
- Consumes: staged `TR` + the Task 2 golden outputs.

- [ ] **Step 1: Basic manifest** — `tools/mame_test/tests/tr_basic.json`:
```json
{"name":"tr_basic","description":"C tr(1): tr a-z A-Z transliterates to uppercase.","command":"clear; echo hello | tr a-z A-Z; echo TRDONE","timeout_s":40,"expect":{"screen_contains":["HELLO","TRDONE","fgx:/root/#"],"screen_lacks":["not found","BRK","PANIC"]}}
```

- [ ] **Step 2: Run it headless (proves the whole pipeline)**
```bash
cd ~/projects/Retro/Apple/fgx
python3 tools/mame_test/run.py --headless tr_basic
```
Expected: `tr_basic` PASS. (Fail on missing binary → recheck Task 3 staging; boots but mis-outputs → capture the screen dump, debug — a codegen issue escalates to inline.)

- [ ] **Step 3: The other 5 manifests**

`tr_delete.json`:
```json
{"name":"tr_delete","description":"C tr(1): tr -d 0-9 deletes digits.","command":"clear; echo a1b2c3 | tr -d 0-9; echo TRDONE","timeout_s":40,"expect":{"screen_contains":["abc","TRDONE","fgx:/root/#"],"screen_lacks":["a1b2","not found","BRK","PANIC"]}}
```
`tr_squeeze.json`:
```json
{"name":"tr_squeeze","description":"C tr(1): tr -s l squeezes repeated l.","command":"clear; echo hello | tr -s l; echo TRDONE","timeout_s":40,"expect":{"screen_contains":["helo","TRDONE","fgx:/root/#"],"screen_lacks":["hello","not found","BRK","PANIC"]}}
```
`tr_compdel.json`:
```json
{"name":"tr_compdel","description":"C tr(1): tr -cd a-z keeps only lowercase letters.","command":"clear; echo ab12cd | tr -cd a-z; echo TRDONE","timeout_s":40,"expect":{"screen_contains":["abcd","TRDONE","fgx:/root/#"],"screen_lacks":["12","not found","BRK","PANIC"]}}
```
`tr_octal.json`:
```json
{"name":"tr_octal","description":"C tr(1): tr a \\101 maps a->A via octal escape.","command":"clear; echo abc | tr 'a' '\\101'; echo TRDONE","timeout_s":40,"expect":{"screen_contains":["Abc","TRDONE","fgx:/root/#"],"screen_lacks":["not found","BRK","PANIC"]}}
```
`tr_range.json`:
```json
{"name":"tr_range","description":"C tr(1): tr A-Z a-z lowercases.","command":"clear; echo HELLO | tr A-Z a-z; echo TRDONE","timeout_s":40,"expect":{"screen_contains":["hello","TRDONE","fgx:/root/#"],"screen_lacks":["HELLO","not found","BRK","PANIC"]}}
```

- [ ] **Step 4: Run the full tr suite headless**
```bash
cd ~/projects/Retro/Apple/fgx
python3 tools/mame_test/run.py --headless tr_basic tr_delete tr_squeeze tr_compdel tr_octal tr_range
```
Expected: 6/6 PASS. **Octal fallback:** if `tr_octal` fails because the FGX shell strips the backslash before `tr` (screen shows the digits), drive it from a file (`echo abc > /root/TRIN; tr 'a' '\\101' < /root/TRIN`); if single-quotes don't protect backslashes at all, drop `tr_octal` from the MAME suite and rely on the Task 2 host oracle for octal — note the gap in the commit, don't silently drop it.

- [ ] **Step 5: Commit**
```bash
cd ~/projects/Retro/Apple/fgx
git add tools/mame_test/tests/tr_basic.json tools/mame_test/tests/tr_delete.json tools/mame_test/tests/tr_squeeze.json tools/mame_test/tests/tr_compdel.json tools/mame_test/tests/tr_octal.json tools/mame_test/tests/tr_range.json
git commit -m "test(tr): closed-loop MAME suite (basic/delete/squeeze/compdel/octal/range)

```

---

## Post-plan: the sed gate

With `tr` green, assess how cleanly it flowed (fcc compile first try? libc gaps beyond the four?) and choose the **sed regex-risk strategy** (spike-first vs full-port). Then write the sed plan.

## Self-Review

**Spec coverage** (`docs/plans/2026-06-22-tr-sed-port-design.md`, `tr` section):
- FGX2 build → Task 3. ✓
- Full scope `-c/-d/-s`/ranges/octal → Task 2 (verbatim) + Task 4 tests. ✓
- libc touchpoints `getc/clearerr/ferror/EOF`/`putchar` → **implemented** in Task 1 (corrected from the earlier work-around approach per the core rule). ✓
- fcc touchpoints (`register`, `argv[0][1]`, assign-in-condition) → Task 3 Step 4. ✓
- Tests vs host clang → Task 2 oracle + Task 4. ✓
- Provenance → Task 2 header + Task 3 row. ✓

**Placeholder scan:** Task 1 steps describe the asm changes at spec level (exact files/symbols/offsets/bit values given) because they are executed inline by the main agent with full context; Tasks 2–4 contain complete commands/code/JSON/expected output. The conditionals (fcc-error, octal-quoting) are explicit branch-on-result procedures. No TBD/TODO. ✓

**Name consistency:** `putchar`/`feof`/`ferror`/`clearerr` + their `c_*` shims and `globals.c` bindings; `build_userbin_fgx2_c tr`, `bin/tr.bin`, `disk_src/BIN/TR`, the 6 `tr_*` test names — used identically across tasks. ✓
