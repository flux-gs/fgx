# Shared libc SP3 step 2: startup split between the program and libc -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A program linked against libc's library-mode compile starts
through a small program-side crt0 (`crt0_lib.s`) that calls libc's
`_libc_start` (argv, environ, `__progname`, signal publishing) and each
library's `_lib_init(table, bitmap)`, and whose signal stub jumps to
libc's `_libc_sigtramp` -- proven in MAME on the static path, which
switches to it.

**Architecture:** Everything in today's `crt0_far.s` that names libc's
private cells moves, as it is, into a new libc file `lib/libc_start.s`
(bank 0 of libc.so, and segment 0 of a static link), with its scratch
cells in a new core data file `lib/libc_start_data.s`.  The program keeps
its entry, its own fcc runtime cells (`_fcc_sfp`, `_fcc_dbr`), `main`,
the stdio flush and exit, and `_sig_tramp` as one `JML`.  The link
supplies `_crt0_inits`, which pushes each library's block table and
bitmap and calls `_lib_init`; fgx_static writes it for libc now, and step
3's dynamic mode writes it for every needed library.

**Tech Stack:** 65816 assembly (Merlin32), C (fcc: `libc_init.c`, the
`libcso` probe), Python 3 (`fgx_static.py`, `fgx_libso.py`, checkers),
MAME via `tools/mame_test/run.py`.

**Spec:** `docs/history/plans/2026-09-29-shared-libc-sp3-design.md`,
section 3 ("crt0 splits") and section 6 item 2.  Revised the same day
for an adversarial review (Fable), nine findings adopted.  Settled here,
from reading the code:

- **What moves, measured in `crt0_far.s`:** `_crt0_setup_argv` (with
  `_crt0_copyToEnv`, `_crt0_set_progname`) fills `args_argc`,
  `args_argv[]`, `args_optind`/`optarg`/`optopt`, `args_env`,
  `args_envv[]`, `args_envc`, `environ`, `__progname`; `_crt0_start`
  stores `_sig_tramp_off`, `_SIG_DATA_DP` (DP `$B8`) and `_fcc_dbr`;
  `_sig_tramp` (`crt0_far.s:469-674`) reads `_sig_curmask`,
  `_sig_act_maskoff`, `_sig_c_tab`, `_fcc_stkfloor`, and ends with a near
  `JMP _fcc_stkoflow`.  Its scratch is the ten pinned cells at seg0
  `$03..$12` (`crt0_far.s:74-107`).  The code moves unchanged except for
  cell names, frame depth, and the EQUs it duplicated.
- **Frame depth.**  `_crt0_setup_argv` was `JSR`ed and `PHP`ed, so it
  found the kernel's frame at `S+3`.  `_libc_start` is `JSL`ed (3 bytes)
  from crt0's first push and `PHP`s: `S+4`.  crt0 pushes nothing before
  the call (the soft-frame seed and `_fcc_dbr` capture balance their
  `PHB`/`PLA`), and `_libc_start` stores A (the stub offset) before
  `PHP`.
- **`crt0_far.s` stays as it is**: every shipped binary (the pile path)
  PUTs it, and Merlin32 does not follow a `PUT` inside a `PUT` file, so the
  two cannot share one body.  The copy in `libc_start.s` is what programs
  linked against libc's library-mode compile use; `crt0_far.s` goes with
  the pile path in sub-project 5.
- **`_lib_init(tab, bits)`** replaces `_libc_init()`: `tab` is a library's
  block table (4 words a row, zero-ended), `bits` its reachability bitmap
  (row i built when bit `i & 7` of byte `i >> 3` is set), NULL for every
  row.  fcc's far-call convention: the caller pushes each 4-byte argument
  high word then low word, the last argument first (measured: `PEI
  _fcc_fpr0+2` / `PEI _fcc_fpr0` before `FGX2_FARCALL getc`), and drops
  them after (`TSC / ADC #n / TCS`).
- **The block tables become data exports**: `_libc_blktab`,
  `_libtermlib_blktab`, `_libcurses_blktab`, so a dynamic program's
  `_crt0_inits` (step 3) can name them.  With them, `args_argc`,
  `args_argv` (every compiled `main` names them, `parse_stmt.c:8723,
  8742`) and `__progname` (spec section 3).
- **The bitmap's skip path is tested on the machine now**: `libcso` builds
  a two-row table of its own in its data and calls `_lib_init` with one
  bit set.  A static link's own table holds only reached rows and passes
  NULL, so nothing else exercises it until step 4.
- **Out of this step:** the copy step (step 4's bound image; SP4's
  binder), the dynamic `_crt0_inits` (step 3).

## Global Constraints

- ASCII only; comments describe the current state; BSD named in commits
  where a behaviour has a counterpart (crt0's argv walk has none -- it is
  FGX's kernel frame); commit bodies informational, ending with
- `crt0_far.s` and every shipped binary are unchanged (the gate proves it).
- MAME runs headless (`run.py --fresh`); announce every rebuild and MAME
  run; never `git checkout` a generated file.
- Branch `feat/shared-libc`, not pushed.

## Review Focus

1. The argv frame at the wrong depth -- argc and argv[0] would be read
   from the return address: `libcso` checks argc and argv[0]'s basename,
   and a mutation (`ADC #3` for `#4`) must turn it red (Task 3).
2. A signal delivered through the `JML` stub -- the handler runs, and the
   interrupted syscall resumes with its result: `libcso`'s signal check
   (alarm during pause) passes through `_libc_sigtramp` (Task 3).
3. A bitmap with a row's bit clear -- that row's cell stays 0 and
   `HEAP_LIM` comes down by the set rows only (Task 3's bitmap check).
4. A table with no rows -- `_lib_init` returns at once and `HEAP_LIM`
   stays: libcso's `empty` check (Task 3); no static link has one
   (bytecatso's table has two rows).
5. The stub offset `_libc_start` stores is the program's `_sig_tramp`, in
   segment 0 -- `c_signal` registers it with the kernel; a wrong one
   kills the signal check (Task 3).

---

### Task 1: libc's half of startup in libc.so

**Files:**
- Create: `toolchain/lib/libc_start.s`, `toolchain/lib/libc_start_data.s`
- Modify: `toolchain/src/ld/fgx_libso.py` (`LIBSO_BANK0`, `DATA`),
  `toolchain/lib/libc_c/data.exports`,
  `toolchain/lib/libtermlib_c/data.exports`,
  `toolchain/lib/libcurses_c/data.exports`, `tools/check_libc_data.py`
  (`DATA`), `tools/libc_so_check.py` (check below), `toolchain/Makefile`
  (libc.so.1.0's prerequisites)

**Interfaces:**
- Produces: `_libc_start` -- `JSL` with MX `%00`, A = the offset of the
  program's `_sig_tramp` in segment 0, entered before crt0 pushes
  anything; returns `RTL`, A/X/Y clobbered, DBR and the stack as found.
  `_libc_sigtramp` -- today's `_sig_tramp`, entered by `JML` from the
  program's stub with the kernel's delivery frame.  Both in bank 0.
  Data exports `_libc_blktab`, `args_argc`, `args_argv`, `__progname`
  (libc), `_libtermlib_blktab`, `_libcurses_blktab`.

- [ ] **Step 1: The failing check.**  In `libc_so_check.py`'s libc-only
  part add: `_libc_start` and `_libc_sigtramp` are code exports in segment
  0, and the data exports include `args_argc`, `args_argv`, `__progname`,
  `_libc_blktab`.

Run: `python3 tools/libc_so_check.py`
Expected: FAIL naming `_libc_start` (and the data exports).

- [ ] **Step 2: `libc_start_data.s`.**

```
;==============================================================================
; libc_start_data.s - libc_start.s's scratch cells, in libc's core (shared
; libc SP3 spec, section 3).  crt0_far.s pins its copies at segment-0
; offsets $03..$12, where DBR-relative stores alias the data segment's pad;
; libc_start.s runs from libc's bank, so its cells are ordinary core cells.
;==============================================================================
_ls_callerS     DA      0
_ls_kernArgc    DA      0
_ls_walkIdx     DA      0
_ls_strBank0Ptr DA      0
_ls_envIdx      DA      0
_ls_envOff      DA      0
_ls_baseOff     DA      0
_ls_dataBank    DA      0
_ls_sigbit      DA      0
_ls_sigbitHi    DA      0
```

- [ ] **Step 3: `libc_start.s`.**  Header:

```
;==============================================================================
; libc_start.s - libc's half of program startup (shared libc SP3 spec,
; section 3).  A program's crt0 (crt0_lib.s) calls _libc_start first, and
; its signal stub jumps to _libc_sigtramp: both name libc's own core cells,
; which a program linked against libc.so cannot.  The bodies are crt0_far.s's
; (_crt0_setup_argv, _crt0_copyToEnv, _crt0_set_progname, _sig_tramp), which
; the pile path still PUTs; only the cells, the frame depth and the EQUs
; differ.
;==============================================================================
_LS_DATA_DP     EQU     $B8     ; DP byte: the task's data bank (fcc_runtime.s DP map)
_LS_SETMASK     EQU     102     ; SYS_SIGSETMASK
_LS_ARGS_MAX    EQU     16      ; MUST MATCH args_data.s ARGS_MAX
_LS_ENV_MAX     EQU     256     ; MUST MATCH args_data.s ARGS_ENV_MAX
_LS_ENVV_MAX    EQU     32      ; MUST MATCH args_data.s ARGS_ENVV_MAX

;------------------------------------------------------------------------------
; _libc_start - fill libc's argument, environment and signal cells.
; JSL'd by crt0 before it pushes anything, A = the offset of the program's
; _sig_tramp in segment 0 (the kernel delivers signals there).  After the JSL
; (3) and PHP (1) the kernel's argv frame starts at S+4+1: argc at +1, argv[i]
; at +3+2i, envp after argv's NULL.  MX %00 in and out; RTL.
;------------------------------------------------------------------------------
                FGX2_EXPORT _libc_start
_libc_start     MX      %00
                STA     _sig_tramp_off
                PHP
                REP     #$30
                MX      %00
                TSC
                CLC
                ADC     #4
                STA     _ls_callerS
```

  then `crt0_far.s:222-359`'s body (from `; Zero output state.` to the
  `STA environ+2` after the environ publish; the `PLP`/`RTS` at 360-361
  are replaced by what follows) with every `_crt0_<x>` cell
  renamed `_ls_<x>`, `ARGS_MAX`/`ARGS_ENV_MAX`/`ARGS_ENVV_MAX` renamed to
  the `_LS_` EQUs, and `JSR _crt0_set_progname` / `JSR _crt0_copyToEnv`
  renamed to the two routines below; then

```
                ; The task's data bank, which the walk above cached in
                ; _ls_dataBank: for _libc_sigtramp (DP is per-task and
                ; bank-free) and for libc's int->pointer conversions.
                LDA     _ls_dataBank
                STA     _fcc_dbr
                SEP     #$20
                MX      %10
                STA     _LS_DATA_DP
                REP     #$20
                MX      %00
                PLP
                RTL
```

  then `_ls_copyToEnv` and `_ls_set_progname`: `crt0_far.s:371-393`
  (`_crt0_copyToEnv`) and `:409-428` (`_crt0_set_progname`) with the same
  renames; then

```
;------------------------------------------------------------------------------
; _libc_sigtramp - the fcc signal-handler adapter, reached by JML from the
; program's _sig_tramp with the kernel's delivery frame (crt0_far.s's
; _sig_tramp header gives the contract).
;------------------------------------------------------------------------------
                FGX2_EXPORT _libc_sigtramp
```

  followed by `crt0_far.s:469-674` (`_sig_tramp MX %00` through `@st_oflow
  JMP _fcc_stkoflow`) with the label `_sig_tramp` renamed
  `_libc_sigtramp`, `_crt0_sigbit`/`_crt0_sigbitHi` renamed `_ls_sigbit`/
  `_ls_sigbitHi`, `_SIG_DATA_DP` -> `_LS_DATA_DP`, `_SIG_SETMASK` ->
  `_LS_SETMASK`, and its comments' references to "crt0" adjusted to say
  `_libc_start` stashes the DP byte.  Do the renames with a script over
  the extracted lines and diff the result against crt0_far.s's lines to
  prove nothing else changed:

Run: `diff <(sed -n 469,674p toolchain/lib/crt0_far.s | sed -E 's/_crt0_sigbit/_ls_sigbit/g; s/_SIG_DATA_DP/_LS_DATA_DP/g; s/_SIG_SETMASK/_LS_SETMASK/g; s/^_sig_tramp /_libc_sigtramp /; s/;.*//; s/[[:space:]]+$//' | grep -v '^\*' | grep -v '^$') <(sed -n '/^_libc_sigtramp /,/JMP     _fcc_stkoflow/p' toolchain/lib/libc_start.s | sed -E 's/;.*//; s/[[:space:]]+$//' | grep -v '^\*' | grep -v '^$') | wc -l`
Expected: `0` (comments stripped on both sides, so only code is compared).

- [ ] **Step 4: Wire it in.**  `fgx_libso.py`: `LIBSO_BANK0 = BANK0 +
  [libc_so_helpers.s, libc_start.s]` (BANK0 itself unchanged -- Task 2
  moves the static path); `DATA += [libc_start_data.s]`.  `data.exports`:
  add `_libc_blktab`, `args_argc`, `args_argv`, `__progname` (libc);
  `_libtermlib_blktab` (termlib); `_libcurses_blktab` (curses), each with
  a one-line comment ("the block table crt0's _crt0_inits passes to
  _lib_init").  `check_libc_data.py`: `DATA` gains
  `toolchain/lib/libc_start_data.s`.  `toolchain/Makefile`: add
  `lib/libc_start.s lib/libc_start_data.s` to `lib/libc.so.1.0`'s
  prerequisites.  Announce the rebuild.

check_libc_data scans `git ls-files` only, so mark the new files first:
`git add -N toolchain/lib/libc_start.s toolchain/lib/libc_start_data.s`.

Run: `make -C toolchain libso_all 2>&1 | grep '\.so:' && for l in libc libtermlib libcurses; do python3 tools/libc_so_check.py --lib $l || exit 1; done && python3 tools/check_libc_data.py`
Expected: three libraries build (libc's bank 0 a little larger, its core
by 20 bytes, its exports 349 = 343 + 4 data + `_libc_start` and
`_libc_sigtramp`); three clean reports;
check_libc_data clean (every `_ls_` cell is named by libc_start.s).

- [ ] **Step 5: Commit.**

```bash
git add toolchain/lib/libc_start.s toolchain/lib/libc_start_data.s toolchain/src/ld/fgx_libso.py toolchain/lib/libc_c/data.exports toolchain/lib/libtermlib_c/data.exports toolchain/lib/libcurses_c/data.exports tools/check_libc_data.py tools/libc_so_check.py toolchain/Makefile
git commit -F - <<'EOF'
feat(libc): libc.so carries libc's half of program startup

_libc_start fills the argument, environment and signal cells a program
linked against libc.so cannot name -- crt0_far.s's argv walk, environ
packing, __progname and signal publishing, reading the kernel's frame at
S+4 behind its JSL -- and _libc_sigtramp is crt0_far.s's signal
trampoline, reached by JML from the program's segment-0 stub.  Their
scratch cells are core cells.  The block tables, args_argc, args_argv and
__progname become data exports.

EOF
```

---

### Task 2: `_lib_init` and the program's crt0; the static path uses them

**Files:**
- Modify: `toolchain/lib/libc_c/libc_init.c` (`_libc_init()` ->
  `_lib_init(tab, bits)`)
- Create: `toolchain/lib/crt0_lib.s`
- Delete: `toolchain/lib/crt0_libso.s`
- Modify: `toolchain/src/ld/fgx_static.py` (seg0 files, `_crt0_inits`,
  entry, `OUTPUT`), `toolchain/src/ld/fgx_libso.py` (`BANK0` += libc_start.s),
  `toolchain/tests/libso/test_libso.py` (static_link's entry check),
  `tools/ninja/gen.py` (libcso/libcsofull/bytecatso `links`),
  `tools/libcso-fgx2/build_libcso.sh` (comment),
  `tools/mame_test/tests/{libcso,libcsofull}.json` (descriptions)

**Interfaces:**
- Consumes: Task 1's `_libc_start`, `_libc_sigtramp`, `_libc_blktab`.
- Produces: `void _lib_init(unsigned *tab, unsigned char *bits)`;
  `crt0_lib.s` exporting `_crt0_lib` (the entry) and needing the link to
  define `_crt0_inits` (near, `RTS`); `fgx_static.inits(tables) -> [rows]`
  where `tables` is a list of block-table labels (static: `["_libc_blktab"]`).

- [ ] **Step 1: Failing host test.**  In `test_libso.py`'s `static_link`,
  replace the `_crt0_libso` entry check with: the entry export is
  `_crt0_lib`; segment 0 holds no `JMP _crt0_start` (crt0_far.s is not in
  the link: `"_crt0_start" not in` seg0's listing); seg0's listing defines
  `_crt0_inits`, `_libc_start`, `_libc_sigtramp` and `_sig_tramp`, and
  `_sig_tramp`'s first byte is `JML` (`$5C`).  In `fgx_static.self_test`:
  `inits(["_libc_blktab"])` returns rows that push `0`, `0`, the bank,
  `_libc_blktab`, then `FGX2_FARCALL _lib_init`, `ADC #8`, and end `RTS`.

  The `$5C` check reads `_sig_tramp`'s offset from segment 0's listing
  (`seg0_Output.txt`, via `libc_so_check.label_addrs` or the same row
  parse): the stub is not exported.

Run: `cd toolchain && python3 src/ld/fgx_static.py --self-test; python3 tests/libso/test_libso.py | grep -E 'FAIL|passed'`
Expected: the self-test stops with a NameError traceback (`inits` is
undefined); test_libso FAILs (the entry is `_crt0_libso`).

- [ ] **Step 2: `_lib_init`.**  In `libc_init.c` replace `_libc_init` with:

```c
/*
 * _lib_init -- give this process its own copy of each block of one
 * library.
 *
 * A library's statics outside its core live in per-member blocks (shared
 * libc SP2 spec, section 4).  Code reaches member m's statics through the
 * core cell _<lib>_blk_<m>, which must hold the address of THIS process's
 * block.  `tab' is the library's block table: per member four words, the
 * cell's address, a far pointer to the member's template (offset, then
 * bank) and the block's size; a zero word ends it.  `bits' is the
 * program's reachability bitmap for the library -- row i is built when bit
 * i & 7 of byte i >> 3 is set -- or NULL, every row (a static link's table
 * holds only the members it reaches).  A template holds every static's
 * initial bytes and zeros for the rest, which is K&R A.8.7's rule, "A
 * static object not explicitly initialized is initialized as if it (or
 * its members) were assigned the constant 0", so copying it is the whole
 * initialisation.
 *
 * The blocks go at the top of the heap's room, just below HEAP_LIM, and
 * HEAP_LIM comes down to the lowest of them: sbrk stops there, and fork
 * carries [HEAP_LIM, $FFFF] with the data below the break
 * (include/kernel.s), so a child gets its own copy.  crt0's _crt0_inits
 * calls this once per library, in load order.  Everything here is in the
 * process's data bank, the one `tab' is in.
 *
 * No BSD counterpart: 2.11BSD links libc statically and its data is the
 * program's.
 */
extern int write();
extern void _exit();

static int
wanted(bits, i)
unsigned char *bits;
unsigned i;
{
    return bits == (unsigned char *)0 || (bits[i >> 3] & (1 << (i & 7)));
}

void
_lib_init(tab, bits)
unsigned *tab;
unsigned char *bits;
{
    unsigned *t, *lim;
    unsigned long bank;
    unsigned top, need, n, i;
    char *blk, *tmpl;

    bank = (unsigned long)(char *)tab & 0xFF0000L;
    lim = (unsigned *)(bank | 0xFFF8L);                 /* HEAP_LIM */
    need = 0;
    for (t = tab, i = 0; t[0]; t += 4, i++)
        if (wanted(bits, i))
            need += t[3];
    if (need == 0)
        return;
    top = *lim;
    if (need > top - *(unsigned *)(bank | 0xFFFEL)) {   /* HEAP_BRK */
        write(2, "libc: no room for its data\n", 27);
        _exit(1);
    }
    for (t = tab, i = 0; t[0]; t += 4, i++) {
        if (!wanted(bits, i))
            continue;
        top -= t[3];
        blk = (char *)(bank | top);
        tmpl = (char *)(((unsigned long)t[2] << 16) | t[1]);
        for (n = 0; n < t[3]; n++)
            blk[n] = tmpl[n];
        *(unsigned *)(bank | t[0]) = top;
    }
    *lim = top;
}
```

  (`wanted` is a static of member `libc_init`: fcc gives it the member's
  prefix, and it has no data, so the member gains no block.)

- [ ] **Step 3: `crt0_lib.s`.**

```
;==============================================================================
; crt0_lib.s - the startup of a program linked against libc's library-mode
; compile (shared libc SP3 spec, section 3): statically by fgx_static, and
; dynamically from step 3.  libc's half is _libc_start (libc_start.s), which
; fills the cells a program cannot name; the program keeps its entry, its own
; fcc runtime cells, main, the stdio flush and exit, and the signal stub the
; kernel enters in segment 0.  The link defines _crt0_inits, which calls
; _lib_init for each library's blocks.
;
; Entry (the loader's JML): native, MX %11, DBR = the data bank, and only the
; kernel's argv frame on the stack -- so _libc_start, JSL'd before crt0 pushes
; anything, finds it at a fixed depth.
;==============================================================================
                FGX2_EXPORT _crt0_lib
_crt0_lib       MX      %11
                REP     #$30
                MX      %00
                ; The soft-frame pointer, as crt0_far.s seeds it: the loader
                ; seeds all three bytes when the binary asks for a soft bank,
                ; so a non-zero bank byte means leave it.
                SEP     #$20
                MX      %10
                LDA     _fcc_sfp+2
                REP     #$20
                MX      %00
                AND     #$00FF
                BNE     @cl_sfpSeeded
                LDA     #$FFFE
                STA     _fcc_sfp
@cl_sfpSeeded
                ; The program's own data-bank cache for int->pointer
                ; conversions (libc's is _libc_start's).
                STZ     _fcc_dbr
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_dbr
                REP     #$20
                MX      %00
                LDA     #_sig_tramp
                FGX2_FARCALL _libc_start
                JSR     _crt0_inits
                FGX2_FARCALL main                   ; A = exit status (RTL)
                AND     #$00FF
                PHA                                 ; returning from main flushes
                FGX2_FARCALL __lc_stdio_flush       ; stdio, as crt0_far.s does
                PLA
                JSL     SYS_TRAMP
                DFB     SYS_EXIT
@cl_safety      BRA     @cl_safety

;------------------------------------------------------------------------------
; _sig_tramp - the kernel delivers signals into segment 0 at the offset
; _libc_start published; JML leaves the delivery frame as it is.
;------------------------------------------------------------------------------
_sig_tramp      FGX2_FARJUMP _libc_sigtramp
```

- [ ] **Step 4: fgx_static.**  `CRT0 = crt0_lib.s` (drop `crt0_far.s`
  and `CRT0_LIBSO`); `seg0_fixed = [CRT0, fgx_libso.RUNTIME] +
  fgx_libso.BANK0` with `BANK0` now ending in `libc_start.s`
  (fgx_libso: `BANK0 = [...] + [libc_start.s]`, `LIBSO_BANK0 = BANK0 +
  [libc_so_helpers.s]`, replacing Task 1's append).  Add

```python
def inits(tables):
    """_crt0_inits: _lib_init(table, NULL) for each block table, in load
    order.  fcc's far-call convention: each 4-byte argument high word then
    low word, the last argument first; the caller drops them."""
    rows = ["_crt0_inits     MX      %00"]
    for t in tables:
        rows += ["                PEA     0",            # bits, high word
                 "                PEA     0",            # bits: NULL, every row
                 "                SEP     #$20",
                 "                MX      %10",
                 "                PHB",
                 "                PLA",
                 "                REP     #$20",
                 "                MX      %00",
                 "                AND     #$00FF",
                 "                PHA",                  # table's bank
                 "                PEA     %s" % t,        # table's offset
                 "                FGX2_FARCALL _lib_init",
                 "                TSC",
                 "                CLC",
                 "                ADC     #8",
                 "                TCS"]
    return rows + ["                RTS"]
```

  `build()` writes `d/inits.s` with `inits(["_libc_blktab"])` BEFORE
  `collect()`, and puts its path in `seg0_fixed` (so in `order` and
  `files`): fgx_gc's roots are the unpruned files, and inits.s is the only
  one naming `_lib_init` -- left out, `_lib_init` reaches no bank and
  fgx_ld dies "unresolved symbol".  Segment 0 PUTs it after the runtime
  and BANK0 files; the entry is read from the `_crt0_lib` export;
  `OUTPUT` gains `inits`.  Fix the seg1 comment (`fgx_static.py:110-112`):
  the 256-byte pad keeps every data label at `$0100` or above, as every
  program's data segment does; crt0_lib.s has no DBR-relative scratch for
  it to absorb.  Update the module
  docstring (entry `_crt0_lib`, `_crt0_inits`).  Delete `crt0_libso.s`;
  in `gen.py` the three testbin entries' `links` name
  `toolchain/lib/crt0_lib.s` and `toolchain/lib/libc_start.s` instead of
  `crt0_libso.s`, and their `extra` gains `toolchain/lib/libc_start_data.s`;
  `build_libcso.sh`'s and the two MAME manifests'
  descriptions say `_lib_init`.

Run: `cd toolchain && make lib/libc_so.s libso_all 2>&1 | grep 'libc.so:' && python3 src/ld/fgx_static.py --self-test && python3 tests/libso/test_libso.py | tail -1 && python3 ../tools/libc_so_check.py`
Expected: libc.so builds (libc_so.s regenerated from the new
libc_init.c first -- the static link needs `_lib_init` in it); self-test
OK; `libso checks passed`; clean.

- [ ] **Step 5: Commit.**

```bash
git add -A toolchain/lib/libc_c/libc_init.c toolchain/lib/crt0_lib.s toolchain/lib/crt0_libso.s toolchain/src/ld/fgx_static.py toolchain/src/ld/fgx_libso.py toolchain/tests/libso/test_libso.py tools/ninja/gen.py tools/libcso-fgx2/build_libcso.sh tools/mame_test/tests/libcso.json tools/mame_test/tests/libcsofull.json
git commit -F - <<'EOF'
feat(libc): a program's crt0 calls libc's start and each library's init

crt0_lib.s is the startup of a program linked against libc's
library-mode compile: it seeds its own runtime cells, JSLs _libc_start
before pushing anything, calls the link's _crt0_inits, then main, the
stdio flush and exit, and its segment-0 _sig_tramp is a JML to
_libc_sigtramp.  _lib_init(tab, bits) replaces _libc_init: one library's
block table and the program's bitmap for it (NULL, every row).
fgx_static links through it, writing _crt0_inits for libc's table;
crt0_libso.s goes.

EOF
```

---

### Task 3: the probe proves it on the machine

**Files:**
- Modify: `src/userland/libcso/libcso.c` (argv, `__progname`, bitmap
  checks)

- [ ] **Step 1: The checks.**  `main(argc, argv) int argc; char **argv;`
  and, first thing:

```c
    /* _libc_start read the kernel's frame at its fixed depth: argc and
     * argv[0] (typed as /testbin/libcso), and __progname, a bank-0 offset
     * into argv[0]'s string in the frame. */
    s1 = strrchr(argv[0], '/');
    say("argv", argc == 1 && strcmp(s1 ? s1 + 1 : argv[0], "libcso") == 0);
    say("progname", strcmp((char *)(unsigned long)__progname, "libcso") == 0);
```

  with `extern unsigned __progname; extern char *strrchr();`.  Then,
  before `lim = heaplim()`, the bitmap:

```c
    /* _lib_init builds a row only when its bit is set: row 0 of a table of
     * the probe's own, not row 1. */
    lim = heaplim();
    bt[0] = lo((char *)&c0); bt[1] = lo(t0); bt[2] = (unsigned)((unsigned long)t0 >> 16); bt[3] = 4;
    bt[4] = lo((char *)&c1); bt[5] = lo(t1); bt[6] = (unsigned)((unsigned long)t1 >> 16); bt[7] = 6;
    bt[8] = 0;
    bits[0] = 1;
    _lib_init(bt, bits);
    say("bitmap", heaplim() == lim - 4 && c0 == lim - 4 && c1 == 0 &&
        memcmp((char *)(bankof() | c0), t0, 4) == 0);
```

  and the empty table, which returns before touching anything (no static
  link reaches it: bytecatso's table has two rows, `_libc_blk_malloc` and
  `_libc_blk_proc`, measured):

```c
    lim = heaplim();
    _lib_init(bt0, (unsigned char *)0);
    say("empty", heaplim() == lim);
```

  with file-scope `static unsigned bt[9], bt0[1], c0, c1; static unsigned
  char bits[1]; static char t0[4] = { 'a', 'b', 'c', 'd' }, t1[6];`,
  `extern void _lib_init(); extern int memcmp();`.

- [ ] **Step 2: Build.**  Announce the rebuild.

Run: `ninja 2>&1 | tail -1`
Expected: success.

- [ ] **Step 3: MAME.**  Announce the runs.

Run: `for t in libcso libcsofull bytecatso bytecat; do python3 tools/mame_test/run.py --fresh $t | tail -1; done`
Expected: 4 x `1 passed`: `CSO ok` with the new `argv`, `progname`,
`bitmap` and `empty` lines; libcsofull still refuses before main; bytecat and
bytecatso copy and compare.

- [ ] **Step 4: The frame-depth mutation.**  In `libc_start.s` change
  `ADC #4` to `ADC #3`, rebuild, run libcso, then restore.

Run: `python3 tools/mame_test/run.py --fresh libcso | tail -1`
Expected: `0 passed, 1 failed` (argv or a later check fails).  Restore,
rebuild, and rerun: `1 passed`.

- [ ] **Step 5: Commit** (`test(libc): libcso checks argv, __progname and _lib_init's bitmap`,
  body: what each proves, the mutation's result; trailers).

---

### Task 4: record the step, run the gate

- [ ] **Step 1: The spec.**  Section 3's crt0 paragraph: the names as
  built (`crt0_lib.s`, `libc_start.s`, `_lib_init(tab, bits)`,
  `_crt0_inits`), the `S+4` depth, the block tables as data exports.
  Section 8: "Step 2 landed <date>" with libc.so's new sizes and the MAME
  results.

- [ ] **Step 2: The gate** (libc_init.c is a libc member; the archives
  recompile it).  Announce it.

Run: `tools/gate.sh 2>&1 | tail -3`
Expected: `GATE GREEN`.

- [ ] **Step 3: Commit and the project notes** (`group_id="fgx"`): step 2 landed;
  `_libc_start`'s S+4 contract; `_lib_init(tab, bits)` SUPERSEDES
  `_libc_init()`; crt0_libso.s gone.

```bash
git add docs/history/plans/2026-09-29-shared-libc-sp3-design.md
git commit -F - <<'EOF'
docs(plans): shared libc SP3 step 2 landed

EOF
```
