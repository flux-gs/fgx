# Shared libc SP4 step 2: loading -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shared libraries are made resident on the machine: `ld_load.c` (libc, C) reads a library into banks `ld.mod` grants, relocates it once for the boot, binds its own imports and commits it; `/sbin/ldload` makes libc resident at boot and then each library `/etc/ld.so.conf` lists; `_lib_init` copies blocks with an `MVN` stub in the program's own segment 0.

**Architecture:** Two step 1 defects are fixed first in `ld.mod` (a library's imports are reclaimed only after it, and the core base is assigned at GRANT, before the loader needs it). The copier stub lands in `crt0_lib.s` and reaches `_lib_init` as an argument from `_crt0_inits`. `ld_load.c` keeps no statics: all state is in the caller's `struct ld_work`, so step 3's binder can call it before blocks exist. A host twin (`fgx_lddigest.py`, built on `fgx_bind`) lays the same libraries out and a testbin probe (`lddig`) checks the machine's banks against it.

**Tech Stack:** fcc K&R C (libc, ldload, lddig), Merlin32 65816 (ld.mod, crt0_lib.s), Python 3 (fgx_static, fgx_lddigest), ninja, headless MAME (`tools/mame_test/run.py`).

**Spec:** `docs/history/plans/2026-09-30-shared-libc-sp4-design.md` (sections 4, 5.2, 5.4, 5.5, 7, 9, 10 step 2). Step 1's plan, for the probe style: `docs/history/plans/2026-09-30-shared-libc-sp4-step1-plan.md`.

## Global Constraints

- Branch `feat/shared-libc`; no push, no MR. Each commit ends with the session's attribution trailers.
- ASCII only in every file (no em-dashes); source comments describe the current state only.
- Merlin32 has no operator precedence (`a+n*b` is `(a+n)*b`); `LDX n,S` does not exist; a new `PUT` file needs `python3 tools/ninja/gen.py` before ninja tracks it.
- fcc locals live on the bank-0 stack: anything a syscall reads (the `SYS_LDCTL` block, an iovec array, a path, a `SYS_LISTDIR` buffer) is in the data bank.
- fcc pointers are 3 bytes in a 4-byte slot; arguments are pushed right to left, the caller drops them; a function pointer call is `JSL`/`RTL` with only the 3-byte return above the arguments (`docs/userland-abi.md` 3.6).
- A library file is `/lib/<name>.so.<major>.<minor>`, the highest minor of the major, matching `<name>.so.<major>.` then digits only (spec 5.2.1).
- A MAME verdict marked "(cached)" did not run: every probe verdict here is a fresh run.
- Commit bodies are the changelog: informational, no names, no process.
- Nothing shipped changes bytes except what a task says it adds (spec section 1): checked with the staged-tree hash in Tasks 2 and 5.
- Spec 5.5's SunOS texts where rtld has one.

## Rulings this plan makes against the spec (each lands in the spec in Task 6)

1. **The copier reaches `_lib_init` as its third argument**, from `_crt0_inits`, not through a libc core cell (spec 5.4). The binder in step 3 gets it from crt0 as an argument already; a cell would add 4 bytes to libc's core, which every exec copies, and a `core.list` entry, for no reader the argument does not serve.
2. **The stub writes both bank bytes from its arguments** rather than carrying a loader reloc for the destination: every caller passes a full far pointer, no FGX2 macro shapes a reloc on an `MVN` operand byte, and it costs 6 bytes.
3. **A library's import from a library that changed (CRC differs) is refused** with a message in step 2; by-name binding through EXPT lands with the binder in step 3, which needs the same lookup. The build relinks termlib and curses whenever libc changes (the `libso` edge), so a shipped tree never meets it.
4. **In memory, EXPT and FIXS follow the block templates as tagged blocks, ended by an `END` tag**, at the row's `expt_off`: FIXS is what the binder sets per core copy, and the spec's "core template, block templates and EXPT" left it nowhere.
5. **Step 1 defects fixed here (Task 1):** reclaim freed an imported library while a READY importer still held its bank bytes; the core base was assigned at COMMIT, after the loader needed it.
6. **readv(2) carries at most 32767 bytes a call** (`_Sys_UioVec`, `src/kernel/syscall.s` ~3917-3946, read(2)'s return word), so a bank is read in 16 KB chunks, not one iovec per bank (spec 5.2.2).
7. **libc's binder entry** is committed from libc's own export `_ld_bind` when it has one: none in step 2, so 0; step 3 defines `_ld_bind` and the row carries it with no loader change.

Revised after an adversarial review of this plan (Fable, 2026-10-01), all thirteen findings adopted.

## Review Focus

1. **`ld.so.conf` as people write it** -- blank lines, comments, trailing spaces, a line with no major, a major with no file: each is skipped or named, and every other line still loads. Test: `ldorder` (Task 4).
2. **`ldload` run again by hand after boot** -- every library already resident: each reported resident, nothing reloaded, exit 0. Test: `ldload` probe runs it twice and needs `0 loaded, 3 resident` (Task 4).
3. **No `/etc/ld.so.conf` at all** -- libc alone, no error. Test: `ldorder` runs `ldload /nonexistent` (Task 4).
4. **A library listed above one it needs** -- refused naming both, the rest still loads. Test: `ldorder` (Task 4).
5. **A dependency loaded implicitly** (listed library needs an unlisted one) and then the pool runs dry -- the dependency is not reclaimed under a READY importer. Test: `ldctl deps` (Task 1).

---

### Task 1: ld.mod -- imports reclaimed after their importers; the core base at GRANT

**Files:**
- Create: `toolchain/include/sys/ldctl.h`
- Modify: `src/modules/ld/ld.s` (block equates :68-92, `svc_grant`, `svc_commit` :608-700, `hook_reclaim` :881-933, a new `depended`)
- Modify: `src/userland/ldctl/ldctl.c` (use the header; `basic`, `ready`, `reclaimm` drains; new `deps` mode)
- Create: `tools/mame_test/tests/ldctl_deps.json`
- Modify: `docs/userland-abi.md` (the `SYS_LDCTL` row: a 50-byte block)

**Interfaces:**
- Produces: `<sys/ldctl.h>`: `SYS_LDCTL`, `LDS_ACQUIRE..LDS_LOOKUP`, `LD_FREE/LD_LOADING/LD_READY`, `LD_MAXBANKS`, `struct ldblk` (50 bytes, `deps` last). GRANT takes `core_size` in the block and returns `core_base`; GRANT on a slotted row with another `core_size` is EINVAL; COMMIT takes `deps` (a mask of rows this one imports from) and no longer takes `core_size`.

- [ ] **Step 1: Write the header**

`toolchain/include/sys/ldctl.h`:

```c
/* FGX libc -- sys/ldctl.h.  SYS_LDCTL (syscall 8), the shared-library
 * registry ld.mod keeps (shared libc SP4 spec, section 4), and the state
 * ld_load(3) works in.
 *
 * Every service takes the 50-byte block below by offset and bank (X, Y)
 * and copies the row back into it.  ACQUIRE answers 1 "load it" (the
 * caller now owns the row LOADING) or 0 (READY, the caller counted a
 * user); GRANT takes core_size and adds nbanks banks to the row, and
 * answers core_base; COMMIT takes minor, crc, the offsets, rows, binder,
 * pinned and deps; ABORT frees the row and keeps its banks; LOOKUP only
 * reads.  -1 and errno on failure. */
#ifndef _SYS_LDCTL_H
#define _SYS_LDCTL_H

#include <sys/uio.h>

#define SYS_LDCTL       8
#define LDS_ACQUIRE     0
#define LDS_GRANT       1
#define LDS_COMMIT      2
#define LDS_ABORT       3
#define LDS_LOOKUP      4

#define LD_FREE         1
#define LD_LOADING      2
#define LD_READY        3
#define LD_MAXBANKS     8

struct ldblk {
    char name[16];
    unsigned char major, minor;
    unsigned char crc[4];
    unsigned char row, nbanks;
    unsigned char banks[LD_MAXBANKS];
    unsigned core_base, core_size, tmpl_off, expt_off, rows;
    unsigned char binder[3];
    unsigned char state, users, pinned;
    unsigned deps;              /* bit r: this row imports from row r */
};

#endif /* _SYS_LDCTL_H */
```

(Task 4 adds `struct ld_work`, `struct ld_need` and the `ld_*` prototypes to this header.)

- [ ] **Step 2: Switch ldctl to the header and write the failing checks**

In `src/userland/ldctl/ldctl.c`: delete the `#define SYS_LDCTL` .. `LDS_LOOKUP` lines and `struct ldblk { ... };`, add `#include <sys/ldctl.h>` after `<sys/wait.h>`, keep `static struct ldblk blk;`.

Replace `basic()` with:

```c
/* The arena's bottom as this boot left it: libc's base when ldload has
 * made it resident (rc, from Task 5 on), else HEAP_LIM. */
static unsigned
arena()
{
    name("libc", 1);
    if (ldctl(LDS_LOOKUP) >= 0 && blk.state == LD_READY)
        return blk.core_base;
    return 0xFFF8;
}

/* The services in one process: acquire, grant (the arena), commit, a
 * second acquire, majors, lookup, the selector, the grant cap, and a slot
 * kept for one core size. */
static int
basic()
{
    int r, row, yrow, b0;
    unsigned top;

    top = arena();
    name("libx", 1);
    r = ldctl(LDS_ACQUIRE);
    say("basic", r == 1, "first acquire says load");
    row = blk.row;
    blk.nbanks = 2;
    blk.core_size = 100;
    r = ldctl(LDS_GRANT);
    say("basic", r >= 0 && blk.nbanks == 2 && blk.banks[0] && blk.banks[1] &&
        blk.banks[0] != blk.banks[1], "grant two banks");
    say("basic", blk.core_base == top - 100, "grant: a core under the arena's bottom");
    b0 = blk.banks[0];
    blk.pinned = 0;
    say("basic", ldctl(LDS_COMMIT) >= 0 && blk.core_base == top - 100,
        "commit keeps the base");
    name("libx", 1);
    say("basic", ldctl(LDS_ACQUIRE) == 0 && blk.users == 1 &&
        blk.banks[0] == b0 && blk.row == row, "acquire again: no double count");
    name("liby", 1);
    ldctl(LDS_ACQUIRE);
    yrow = blk.row;
    blk.nbanks = 1;
    blk.core_size = 50;
    ldctl(LDS_GRANT);
    say("basic", blk.core_base == top - 150, "second core stacks below");
    ldctl(LDS_COMMIT);
    name("liby", 2);
    say("basic", ldctl(LDS_ACQUIRE) == 1 && blk.row != yrow,
        "another major is another row");
    ldctl(LDS_ABORT);                   /* liby 2 holds no banks */
    name("libnone", 1);
    say("basic", ldctl(LDS_LOOKUP) == -1 && errno == ENOENT, "lookup absent");
    say("basic", ldctl(0x80) == -1 && errno == ENOSYS, "hook selector refused");
    name("libz", 1);
    ldctl(LDS_ACQUIRE);
    blk.nbanks = 9;
    blk.core_size = 10;
    say("basic", ldctl(LDS_GRANT) == -1 && errno == EINVAL, "grant past 8");
    ldctl(LDS_ABORT);
    name("libw", 1);
    ldctl(LDS_ACQUIRE);
    blk.nbanks = 1;
    blk.core_size = 20;
    ldctl(LDS_GRANT);
    ldctl(LDS_ABORT);                   /* FREE; its slot and bank kept */
    name("libw", 1);
    ldctl(LDS_ACQUIRE);
    blk.nbanks = 0;
    blk.core_size = 30;
    say("basic", ldctl(LDS_GRANT) == -1 && errno == EINVAL,
        "a slot holds one core size");
    blk.core_size = 20;
    say("basic", ldctl(LDS_GRANT) >= 0 && blk.nbanks == 1, "the same size reloads");
    ldctl(LDS_ABORT);
    return 0;
}
```

Replace `ready()` with (and give every caller a fifth argument `0`: `forkm`'s `ready("libf", 1, 10, 0, 0)`, `execm`'s `ready("libe", 1, 10, 0, 0)`, `reclaimm`'s two, `reuse`'s):

```c
/* Make a row READY in this process: acquire, grant n banks, commit. */
static int
ready(s, n, size, pinned, deps)
char *s;
int n, size, pinned;
unsigned deps;
{
    name(s, 1);
    if (ldctl(LDS_ACQUIRE) != 1)
        return -1;
    blk.nbanks = n;
    blk.core_size = size;
    if (ldctl(LDS_GRANT) < 0)
        return -1;
    blk.pinned = pinned;
    blk.deps = deps;
    return ldctl(LDS_COMMIT);
}
```

In `reclaimm()`'s drain child, move `blk.core_size = 1;` above `ldctl(LDS_GRANT);`.

Add before `main`:

```c
/* A row a READY row imports from is reclaimed only after it: the
 * importer's bank bytes name the import's banks.  libdlo holds 8 banks, so
 * without the rule its reclaim alone satisfies a drain and libdhi, its
 * importer, is seen still holding its bank.  A pinned importer keeps its
 * import for the boot. */
static int
depsm()
{
    int pid, n, lo, pb, after;
    char dn[16];

    pid = fork();
    if (pid == 0)
        _exit(ready("libdlo", 8, 10, 0, 0) >= 0 ? 0 : 1);
    reap(pid);
    look("libdlo");
    lo = blk.row;
    pid = fork();
    if (pid == 0)
        _exit(ready("libdhi", 1, 10, 0, 1 << lo) >= 0 ? 0 : 1);
    reap(pid);
    pid = fork();
    if (pid == 0)
        _exit(ready("libpbase", 2, 10, 0, 0) >= 0 ? 0 : 1);
    reap(pid);
    look("libpbase");
    pb = blk.row;
    pid = fork();
    if (pid == 0)
        _exit(ready("libptop", 1, 10, 1, 1 << pb) >= 0 ? 0 : 1);
    reap(pid);
    after = -1;
    for (n = 0; n < 12; n++) {
        look("libdlo");
        if (blk.nbanks == 0 && after < 0) {
            look("libdhi");
            say("deps", blk.nbanks == 0, "an importer goes before its import");
            after = n;
        }
        if (after >= 0 && n >= after + 2)
            break;
        sprintf(dn, "drain%d", n);
        pid = fork();
        if (pid == 0) {
            name(dn, 1);
            ldctl(LDS_ACQUIRE);
            blk.nbanks = 8;
            blk.core_size = 1;
            ldctl(LDS_GRANT);
            ldctl(LDS_COMMIT);
            _exit(0);
        }
        reap(pid);
    }
    say("deps", after >= 0, "the import reclaimed");
    look("libpbase");
    say("deps", blk.nbanks == 2, "a pinned importer keeps its import");
    return 0;
}
```

Add the mode Task 4's `lddelta` probe uses to move the arena: a row that takes a slot of `size` bytes and is aborted, so the slot is held for the boot and the next library loads below it.

```c
/* Hold `size' bytes of the arena for the boot: a slot taken, then aborted. */
static int
padm(size)
int size;
{
    name("libpad", 1);
    if (ldctl(LDS_ACQUIRE) != 1)
        return 1;
    blk.nbanks = 1;
    blk.core_size = size;
    if (ldctl(LDS_GRANT) < 0)
        return 1;
    ldctl(LDS_ABORT);
    printf("LDC pad %u\n", blk.core_base);
    return 0;
}
```

and in `main` after the `reuse` arm: `else if (strcmp(argv[1], "deps") == 0) depsm();` and, beside the `look` arm, `else if (strcmp(argv[1], "pad") == 0 && argc > 2) return padm(atoi(argv[2]));` (add `#include <stdlib.h>`).

`tools/mame_test/tests/ldctl_deps.json`:

```json
{
 "name": "ldctl_deps",
 "description": "Shared libc SP4: under a dry pool a row that a READY row imports from is reclaimed only after its importer, and a pinned importer keeps its import.",
 "command": "/testbin/ldctl deps",
 "timeout_s": 180,
 "expect": {
  "screen_contains": ["LDC deps ok"],
  "screen_lacks": ["LDC FAIL", "PANIC", "BRK"]
 }
}
```

- [ ] **Step 3: Run them against today's ld.mod**

Run: `ninja > $S/t1_build.log 2>&1; tools/mame_test/run.py ldctl_basic ldctl_deps`
Expected: both FAIL -- basic `LDC FAIL basic grant: a core under the arena's bottom` (base 0 at GRANT); deps `LDC FAIL deps an importer goes before its import` or `... a pinned importer keeps its import`. Neither marked cached.

- [ ] **Step 4: Change ld.mod**

Equates (replace `BLK_SZ`/`R_OWNER`/`R_SLOT`; `ROW_SZ` stays 52, so `ld_rowtab` is unchanged), and every "48-byte" comment becomes 50:

```
B_DEPS          EQU     48              ; 2, bit r: this row imports from row r
BLK_SZ          EQU     50
R_OWNER         EQU     50              ; pid loading it (LOADING)
R_SLOT          EQU     51              ; 1 once core_base is assigned
ROW_SZ          EQU     52
```

`svc_grant`: at `@sg_room` (after the count check, `1,S` = how many more, `X` = the row), before `LDA ld_blk+B_ROW`, insert the slot:

```
@sg_room        SEP     #$20
                MX      %10
                LDA:    R_SLOT,X
                REP     #$30
                MX      %00
                AND     #$00FF
                BNE     @sg_slotted
                LDA     ld_arena                ; 0 means HEAP_LIM
                BNE     @sg_arena
                LDA     #HEAP_LIM
@sg_arena       SEC
                SBC     ld_blk+B_CORESIZE
                STA:    B_COREBASE,X
                STA     ld_arena
                LDA     ld_blk+B_CORESIZE
                STA:    B_CORESIZE,X
                SEP     #$20
                MX      %10
                LDA     #1
                STA:    R_SLOT,X
                REP     #$30
                MX      %00
                BRA     @sg_based
@sg_slotted     LDA     ld_blk+B_CORESIZE       ; a slot holds one core size
                CMP:    B_CORESIZE,X
                BEQ     @sg_based
                PLA
                LDA     #EINVAL
                CLC
                RTS
@sg_based       LDA     ld_blk+B_ROW
```

(the existing `LDA ld_blk+B_ROW / AND #$00FF / PHA` continues from `@sg_based`; delete the old `@sg_room` label on that line). Update the routine's header comment: GRANT assigns the core base the first time this boot, from `core_size`, and refuses another size after.

`svc_commit`: delete the `B_CORESIZE` copy and the whole slot block (from `SEP #$20 / LDA: R_SLOT,X` through `@sg_slotted`'s counterpart `@sc_slotted`), keeping `@sc_slotted`'s READY/users/owner stores; add with the other word copies:

```
                LDA     ld_blk+B_DEPS
                STA:    B_DEPS,X
```

Update its header: fields in (minor, crc, template and EXPT offsets, block rows, binder, pinned, deps); READY.

`hook_reclaim`: after the `B_NBANKS` test, before `@hr_free`, skip a row a READY row imports from:

```
                LDA:    B_NBANKS,X
                BEQ     @hr_next8
                REP     #$30
                MX      %00
                LDA     1,S                     ; this row
                JSR     depended
                BCS     @hr_next16
                SEP     #$20
                MX      %10
                ; give each bank back, last first
@hr_free        LDA:    B_NBANKS,X
```

and split the exit label:

```
@hr_next8       MX      %10
                REP     #$30
@hr_next16      MX      %00
                PLA
```

New routine after `hook_reclaim` (stack and row table only -- it runs inside `Bank_Alloc`):

```
;------------------------------------------------------------------------------
; depended - A = a row -> C=1 when a READY row's deps name it: that row's
; relocated bytes hold this one's banks, so it goes first.  X kept; only the
; stack and the row table (reclaim's rule).
;------------------------------------------------------------------------------
depended        MX      %00
                PHX
                JSR     row_bit
                PHA                             ; 1,S = its bit, 3,S = X
                LDA     #0
@dp_l           PHA                             ; 1,S = i, 3,S = bit, 5,S = X
                JSR     row_addr                ; X = row i
                SEP     #$20
                MX      %10
                LDA:    B_STATE,X
                CMP     #ST_READY
                REP     #$30
                MX      %00
                BNE     @dp_next
                LDA:    B_DEPS,X
                AND     3,S
                BNE     @dp_yes
@dp_next        PLA
                INC
                CMP     #LD_ROWS
                BCC     @dp_l
                PLA
                PLX
                CLC
                RTS
@dp_yes         PLA
                PLA
                PLX
                SEC
                RTS
```

`docs/userland-abi.md`: the `SYS_LDCTL` row says the block is 50 bytes (`<sys/ldctl.h>`).

- [ ] **Step 5: Run the probes fresh**

Run: `ninja > $S/t1_build2.log 2>&1; tools/mame_test/run.py ldctl_selector ldctl_basic ldlibexec modimage ldctl_fork ldctl_exec ldctl_race ldctl_intr ldctl_kill ldctl_eperm ldctl_reclaim ldctl_reuse ldctl_deps`
Expected: `13 passed, 0 failed`, none cached. Check `build/module_ld_Output.txt`'s `ld_end - ld_hdr` for ld.mod's size and note it in the ledger.

- [ ] **Step 6: Control -- the dependency rule off**

Make `depended` answer at once (`depended MX %00` / `CLC` / `RTS` as its first lines), `ninja`, run `tools/mame_test/run.py ldctl_deps`.
Expected: FAIL with `LDC FAIL deps an importer goes before its import` or `... a pinned importer keeps its import`. Restore (`git diff src/modules/ld/ld.s` shows only the Step 4 change), `ninja`.

- [ ] **Step 7: Gate and commit**

Run: `tools/gate.sh > $S/gate_t1.log 2>&1; tail -3 $S/gate_t1.log`
Expected: `GATE GREEN`.

```bash
git add toolchain/include/sys/ldctl.h src/modules/ld/ld.s src/userland/ldctl/ldctl.c \
        tools/mame_test/tests/ldctl_deps.json docs/userland-abi.md
git commit -F - <<'EOF'
fix(ld.mod): reclaim an import only after its importers; the core base at GRANT

A loaded library's relocated bytes hold the banks of the libraries it
imports from.  Reclaim freed any unused unpinned row, so an import could
lose its banks under a READY importer -- reloaded elsewhere, the importer
would jump into whatever owned them.  COMMIT now records the rows a
library imports from (a 2-byte mask; the block grows to 50 bytes, the row
keeps its 52), and reclaim skips a row while a READY row names it: an
unused importer goes first, and a pinned one keeps its imports for the
boot.

The core base was assigned at COMMIT, but the loader moves the core's
sites and binds imported data before it commits.  GRANT now takes the
core size and assigns the base the first time this boot; a row holds one
core size for the boot, and another is EINVAL.

<sys/ldctl.h> carries the block and the services for libc and the tools.
EOF
```

---

### Task 2: the copier stub in crt0_lib.s, and _lib_init on it

**Files:**
- Modify: `toolchain/lib/crt0_lib.s` (new `_lib_copy` after `_sig_tramp`)
- Modify: `toolchain/lib/libc_c/libc_init.c:40-74`
- Modify: `toolchain/src/ld/fgx_static.py` (`inits`, :73-104; its self-test, :262-268)
- Modify: `src/userland/libcso/libcso.c:118-126`

**Interfaces:**
- Produces: `_lib_copy(dst, src, n)` in every fgx_static/fgx_dyn program's segment 0 (`FGX2_EXPORT`); `void _lib_init(unsigned *tab, unsigned char *bits, int (*copy)())`; `_crt0_inits` passes `_lib_copy` as `copy`. Step 3's `crt0_dyn.s` carries the same stub.

- [ ] **Step 1: Record the shipped tree**

Run: `find disk_src -type f ! -path 'disk_src/testbin/*' -print0 | sort -z | xargs -0 shasum > $S/ship_before.txt; wc -l $S/ship_before.txt`
Expected: a line count (the tree as built at BASE; run `ninja` first if the tree is not current).

- [ ] **Step 2: Write the failing self-test**

In `fgx_static.py`'s `self_test`, replace the `inits` assertions with:

```python
    rows = [r.split() for r in inits(["_libc_blktab"])]
    assert rows[0] == ["_crt0_inits", "MX", "%00"] and rows[-1] == ["RTS"]
    ops = [r for r in rows[1:-1] if r[0] != "MX"]
    assert ops[0] == ["SEP", "#$20"] and ["PHK"] in ops[:4]        # copy: this bank
    assert ops.index(["PEA", "_lib_copy"]) < ops.index(["PEA", "0"])  # pushed first
    assert ["PEA", "_libc_blktab"] in ops and \
        ops.index(["PEA", "_libc_blktab"]) < ops.index(["FGX2_FARCALL", "_lib_init"])
    assert ["ADC", "#12"] in ops                               # the caller pops 3 args
```

Run: `python3 toolchain/src/ld/fgx_static.py --self-test`
Expected: `AssertionError` (no `PHK`, no `_lib_copy`).

- [ ] **Step 3: `_crt0_inits` passes the copier**

In `fgx_static.py`, add after `BANK`:

```python
COPY = ["                SEP     #$20",           # the copier's bank: this one
        "                MX      %10",
        "                PHK",
        "                PLA",
        "                REP     #$20",
        "                MX      %00",
        "                AND     #$00FF",
        "                PHA",
        "                PEA     _lib_copy"]
```

and replace `inits` with:

```python
def inits(tables, bits=None):
    """_crt0_inits: _lib_init(table, bits, _lib_copy) for each block table,
    in load order.  `bits' is the bitmap labels, parallel to `tables';
    without it each is NULL, every row.  _lib_copy is crt0's MVN copier
    (lib/crt0_lib.s).  fcc's far-call convention: each 4-byte argument high
    word then low word, the last argument first; the caller drops them."""
    rows = ["_crt0_inits     MX      %00"]
    for i, t in enumerate(tables):
        rows += COPY
        if bits:
            rows += BANK + ["                PEA     %s" % bits[i]]
        else:
            rows += ["                PEA     0",        # bits, high word
                     "                PEA     0"]        # bits: NULL, every row
        rows += BANK + ["                PEA     %s" % t,
                        "                FGX2_FARCALL _lib_init",
                        "                TSC",
                        "                CLC",
                        "                ADC     #12",
                        "                TCS"]
    return rows + ["                RTS"]
```

Run: `python3 toolchain/src/ld/fgx_static.py --self-test`
Expected: `fgx_static: self-test OK`. (`fgx_dyn.py:275` calls this same `inits`, so fgx_dyn's programs pass the copier too.)

- [ ] **Step 4: The stub and `_lib_init`**

Append to `toolchain/lib/crt0_lib.s`:

```
;------------------------------------------------------------------------------
; _lib_copy(dst, src, n) - copy n bytes from far pointer src to far pointer
; dst with MVN.  MVN's two bank bytes are immediates in the instruction, and
; libc's code bank is shared by every process, so the copier every template
; copy uses is here, in the process's own segment 0, and writes both bank
; bytes into itself per call (shared libc SP4 spec, section 5.4).  Segment 0's
; only sharers are fork children, which never run it concurrently with the
; parent's startup.  fcc's far-call convention: the first argument nearest,
; each pointer low word then bank word.  n = 0 copies nothing (MVN would copy
; 64 KB).
;------------------------------------------------------------------------------
                FGX2_EXPORT _lib_copy
_lib_copy       MX      %00
                LDA     12,S                    ; n
                BEQ     @lc_none
                DEC
                PHB
                PHA                             ; 1,S = n - 1; arguments up 3
                PHK
                PLB                             ; DBR = this bank, to write the MVN
                SEP     #$20
                MX      %10
                LDA     9,S                     ; dst bank
                STA     _lib_copy_mvn+1
                LDA     13,S                    ; src bank
                STA     _lib_copy_mvn+2
                REP     #$20
                MX      %00
                LDA     7,S                     ; dst offset
                TAY
                LDA     11,S                    ; src offset
                TAX
                PLA                             ; n - 1
_lib_copy_mvn   DFB     $54,$00,$00             ; MVN: opcode, dst bank, src bank
                PLB
@lc_none        RTL
```

Replace `_lib_init` in `libc_init.c` (and in its header comment, after "Everything here is in the process's data bank, the one `tab' is in.", add: "`copy' is the MVN copier in the program's segment 0 (crt0_lib.s's _lib_copy): libc's code bank is shared, so no routine in it can carry this process's bank in an MVN."):

```c
void
_lib_init(tab, bits, copy)
unsigned *tab;
unsigned char *bits;
int (*copy)();
{
    unsigned *t, *lim;
    unsigned long bank;
    unsigned top, need, i;
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
        (*copy)(blk, tmpl, t[3]);
        *(unsigned *)(bank | t[0]) = top;
    }
    *lim = top;
}
```

In `libcso.c`, add `extern int _lib_copy();` beside `extern void _lib_init();`, and pass it: `_lib_init(bt, bits, _lib_copy);` and `_lib_init(bt0, (unsigned char *)0, _lib_copy);`.

Confirm the call convention the stub assumes: `grep -n "_libc_indJump\|_libc_indCall" toolchain/lib/libc_so.s | head` after the build, and read the call site in `_lib_init`: the arguments are pushed, `_libc_indCall` set, then one `JSL`. If anything else is pushed above the arguments, the stub's offsets move by that much -- fix the stub, not the test.

- [ ] **Step 5: The probes that run `_lib_init`**

Run: `ninja > $S/t2_build.log 2>&1; tools/mame_test/run.py libcso libcsofull bytecatso dynso cursso dynsomis dynsonodata`
Expected: `7 passed, 0 failed`, none cached (`libcso` copies blocks through the stub, including its own four-byte row it compares with `memcmp`; `dynso`/`cursso` are fgx_bind images entering `_crt0_lib`).

- [ ] **Step 6: Control -- the copier one byte short**

Add a second `DEC` after the first in `_lib_copy`, `ninja`, run `tools/mame_test/run.py libcso`.
Expected: FAIL (`CSO FAIL` on the block-copy check; the row's last byte is missing). Restore, `ninja`.

- [ ] **Step 7: Host tests, shipped bytes, gate, commit**

Run: `make -s -C toolchain test-archives > $S/t2_host.log 2>&1; tail -3 $S/t2_host.log`
Expected: the archive tests pass.

Run: `find disk_src -type f ! -path 'disk_src/testbin/*' -print0 | sort -z | xargs -0 shasum > $S/ship_t2.txt; diff $S/ship_before.txt $S/ship_t2.txt && echo SAME`
Expected: `SAME` (`_lib_init` is in the static pile, which no shipped tool reaches).

Run: `tools/gate.sh > $S/gate_t2.log 2>&1; tail -3 $S/gate_t2.log`
Expected: `GATE GREEN`.

```bash
git add toolchain/lib/crt0_lib.s toolchain/lib/libc_c/libc_init.c \
        toolchain/src/ld/fgx_static.py src/userland/libcso/libcso.c
git commit -F - <<'EOF'
feat(crt0_lib): an MVN copier in segment 0, and _lib_init on it

_lib_init copied each block a byte at a time in C, about 25 times MVN's
cost.  MVN's bank bytes are immediates in the instruction and libc's code
bank is shared by every process, so the copier lives in the program's own
segment 0: crt0_lib.s's _lib_copy(dst, src, n) writes both bank bytes into
itself per call.  _crt0_inits passes it to _lib_init as a third argument,
in fgx_static's programs and fgx_dyn's alike.

No shipped binary reaches _lib_init; the staged tree is byte-identical.
EOF
```

---

### Task 3: the host's layout of loaded libraries (fgx_lddigest)

**Files:**
- Create: `toolchain/src/ld/fgx_lddigest.py`
- Modify: `tools/stage_piles.py` (the prune takes only pile-shaped names; a self-test case)
- Modify: `tools/ninja/gen.py` (rule `lddigest`, its edges to `build/ld.digest` and `build/ld.digest.pad`)
- Modify: `tools/ninja/manifest.json` (stage both digests to `disk_src/testbin/`; `toolchain/lib/{libc,libtermlib,libcurses}.so.1.0` to `disk_src/lib/`)

**Interfaces:**
- Consumes: `fgx_bind.parse`, `fgx_bind.Image.add_lib`, `fgx_bind.bind_sites`, `fgx_bind.Lib`, `fgx_ld.read_trailer`, `fgx_ld.block`, `fgx_imports.unpack`.
- Produces: `/testbin/ld.digest` (libc, termlib, curses) and `/testbin/ld.digest.pad` (libc, 100 bytes of arena held by `ldctl pad 100`, termlib, curses -- so curses binds termlib's data at a delta of -100), one line per library in load order: `<name> <major> <base hex4> <nbanks> <digest hex4> ...`. The digest is `h = rotl16(h, 1) ^ byte` over each bank from 0, the last bank through the END tag, with every reloc byte (including code import sites' bank bytes and the per-process fixups) taken as 0. Task 4's `lddig` reads it.

- [ ] **Step 1: Write the self-test first**

`toolchain/src/ld/fgx_lddigest.py` (the self-test pins the linearity `lddig` relies on, and the layout against the built libraries):

```python
#!/usr/bin/env python3
"""fgx_lddigest.py - what ld_load (lib/libc_c/ld_load.c) leaves in shared
libraries' banks, as a digest per bank, for the machine probe lddig to
check (shared libc SP4 spec, section 9).

Libraries load in the order given, cores stacked down from HEAP_LIM, each
laid out as fgx_bind lays it -- its code banks, then on the end of the last
the core template, the block templates -- followed by the trailer's EXPT
and FIXS blocks, tagged as in the file and ended by an END tag.  Its relocs
are applied, its core sites moved, its imports bound.  Every byte that
holds a runtime bank (a reloc's, a code import site's, a per-process
fixup's) is 0 in the digest; lddig checks those bytes itself.

The digest is h = rotl16(h, 1) ^ byte, which is linear: byte b at index i
of n contributes rotl16(b, (n - 1 - i) % 16), so lddig takes a byte out by
XORing its contribution away.

Run: fgx_lddigest.py --out F NAME=PATH ...
     fgx_lddigest.py --self-test
"""
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fgx_bind  # noqa: E402
import fgx_imports  # noqa: E402
import fgx_ld  # noqa: E402


def rotl(v, n):
    n &= 15
    return ((v << n) | (v >> (16 - n))) & 0xFFFF if n else v


def digest(b):
    h = 0
    for x in b:
        h = rotl(h, 1) ^ x
    return h


def tagged(tr):
    raw = tr["blocks_raw"]
    return (fgx_ld.block(b"EXPT", raw.get("EXPT", b""))
            + fgx_ld.block(b"FIXS", raw.get("FIXS", b""))
            + fgx_ld.block(b"END\0", b""))


def lay_out(libs):
    """[(name, major, base, [digest per bank])], libraries loaded in order.
    An entry ("pad", n) holds n bytes of the arena, as `ldctl pad n' does."""
    img = fgx_bind.Image({"segs": [], "relocs": [], "head": bytes(16)})
    loaded, out, base = {}, [], fgx_ld.HEAP_LIM
    for name, path in libs:
        if name == "pad":
            base -= int(path)
            continue
        lib = fgx_bind.parse(open(path, "rb").read())
        tr = fgx_ld.read_trailer(lib["trailer"])
        base -= tr["core_size"]
        placed = img.add_lib(name, lib, tr)
        delta = base - tr["core_base"]
        csit = tr["blocks_raw"].get("CSIT", b"")
        for i in range(len(csit) // 3):
            s, o = struct.unpack_from("<BH", csit, 3 * i)
            S, O = placed.place[s]
            img.word_add(S, O + o, delta)
        L = fgx_bind.Lib(name, path, lib, tr,
                         {e[0]: tuple(e[1:]) for e in tr["exports"]},
                         placed, base, delta)
        if "IMPS" in tr["blocks_raw"]:
            fgx_bind.bind_sites(img, placed.place,
                                fgx_imports.unpack(tr["blocks_raw"]["IMPS"]),
                                loaded, name, None, True,
                                {"lookups": 0, "sites": {k: 0 for k in fgx_imports.SITES}})
        img.segs[placed.last] += tagged(tr)
        if len(img.segs[placed.last]) > 0x10000:
            fgx_ld.die(f"{name}: its last bank with the tagged blocks is "
                       f"{len(img.segs[placed.last])} bytes")
        loaded[name] = L
        segs = sorted(set(placed.seg_of.values()))
        banks = []
        for s in segs:
            b = bytearray(img.segs[s])
            for rs, ro, _t in img.relocs:
                if rs == s:
                    b[ro] = 0
            banks.append(digest(b))
        out.append((name, tr["major"], base, banks))
    return out


def write(rows, out):
    with open(out, "w") as f:
        for name, major, base, banks in rows:
            f.write("%s %d %04x %d %s\n" % (name, major, base, len(banks),
                                            " ".join("%04x" % d for d in banks)))


def self_test():
    b = bytes(range(37)) * 3
    for i in (0, 5, 16, len(b) - 1):
        m = bytearray(b)
        m[i] = 0
        assert digest(m) == digest(b) ^ rotl(b[i], len(b) - 1 - i), i
    lib = os.path.join(os.path.dirname(os.path.dirname(HERE)), "lib")
    so = [(n, os.path.join(lib, n + ".so.1.0"))
          for n in ("libc", "libtermlib", "libcurses")]
    if not all(os.path.exists(p) for _n, p in so):
        print("fgx_lddigest: self-test OK (layout skipped: no built libraries)")
        return
    rows = lay_out(so)
    base = fgx_ld.HEAP_LIM
    for (n, p), (name, major, b, banks) in zip(so, rows):
        tr = fgx_ld.read_trailer(fgx_bind.parse(open(p, "rb").read())["trailer"])
        base -= tr["core_size"]
        assert (name, major, b, len(banks)) == (n, 1, base, tr["core"]), name
    padded = lay_out([so[0], ("pad", "100")] + so[1:])
    assert padded[1][2] == rows[1][2] - 100 and padded[0] == rows[0]
    print("fgx_lddigest: self-test OK")


def main():
    if "--self-test" in sys.argv:
        self_test()
        return 0
    a = sys.argv[1:]
    if len(a) < 3 or a[0] != "--out":
        sys.exit("usage: fgx_lddigest.py --out F NAME=PATH ...")
    write(lay_out([tuple(x.split("=", 1)) for x in a[2:]]), a[1])
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Run: `python3 toolchain/src/ld/fgx_lddigest.py --self-test`
Expected: `fgx_lddigest: self-test OK` (not "layout skipped": the libraries are built). Then break `digest` (drop the `rotl`, plain XOR) and run again: Expected `AssertionError`; restore.

- [ ] **Step 2: The pile prune leaves shared libraries alone**

`tools/stage_piles.py` prunes every `libc.so.*` it did not stage (`:110-113`), and `build/.piles_staged` runs after the stagecp edges, so it would delete `disk_src/lib/libc.so.1.0` on every build. First the self-test case, in `self_test` after `orphan.write_bytes(b"stale")`:

```python
        shared = out / "libc.so.1.0"
        shared.write_bytes(b"a shared library, not a pile")
```

and the case's condition becomes `not problems and staged == [want_name] and pruned == [orphan.name] and shared.exists()`, its message `the named pile is staged, the orphan pruned, libc.so.1.0 kept`.

Run: `python3 tools/stage_piles.py --self-test`
Expected: `WRONG ...` and `SELF-TEST FAILED (1)` (the shared library is pruned).

Then, beside `PILE_PREFIX`:

```python
# A pile's whole name: pile_name()'s four hex digits of length and six of
# checksum.  The prune matches this, not the prefix: /lib also holds the
# shared libraries (libc.so.1.0), which no binary's header names.
PILE_RE = re.compile(r"libc\.so\.[0-9A-F]{10}$")
```

(add `import re`) and the prune loop:

```python
    for f in sorted(out.glob(PILE_PREFIX + "*")):
        if PILE_RE.match(f.name) and f.name not in want:
```

Run: `python3 tools/stage_piles.py --self-test`
Expected: `stage_piles: self-test clean (7 cases)`.

- [ ] **Step 3: Build and stage it**

In `tools/ninja/gen.py`, beside `rule libso`:

```
# What ld_load leaves in libc's, termlib's and curses's banks, loaded in that
# order, for lddig (testbin) to check on the machine.
rule lddigest
  command = python3 toolchain/src/ld/fgx_lddigest.py --out $out libc=toolchain/lib/libc.so.1.0 $pad libtermlib=toolchain/lib/libtermlib.so.1.0 libcurses=toolchain/lib/libcurses.so.1.0
  description = $out <- the shared libraries
```

and beside the `libso` edge:

```python
    _dg_in = ("toolchain/lib/libc.so.1.0 toolchain/lib/libtermlib.so.1.0 "
              "toolchain/lib/libcurses.so.1.0 | "
              + " ".join(f"toolchain/src/ld/{f}.py" for f in
                         ("fgx_lddigest", "fgx_bind", "fgx_imports", "fgx_ld")))
    lines.append("build build/ld.digest: lddigest " + _dg_in + "\n  pad =")
    lines.append("build build/ld.digest.pad: lddigest " + _dg_in + "\n  pad = pad=100")
```

In `tools/ninja/manifest.json`'s staging list, beside the `libtermlib.so` entry (copy its shape exactly):

```json
  {"src": "build/ld.digest", "dst": "disk_src/testbin/ld.digest"},
  {"src": "build/ld.digest.pad", "dst": "disk_src/testbin/ld.digest.pad"},
  {"src": "toolchain/lib/libc.so.1.0", "dst": "disk_src/lib/libc.so.1.0"},
  {"src": "toolchain/lib/libtermlib.so.1.0", "dst": "disk_src/lib/libtermlib.so.1.0"},
  {"src": "toolchain/lib/libcurses.so.1.0", "dst": "disk_src/lib/libcurses.so.1.0"}
```

Run: `python3 tools/ninja/gen.py && ninja > $S/t3_build.log 2>&1; cat build/ld.digest build/ld.digest.pad; ls -l disk_src/lib/lib*.so.1.0; ninja -n | tail -1`
Expected: three lines each (`libc 1 f6a3 3 ...` with libc's current base; in the `.pad` file termlib's and curses's bases 100 lower), the three libraries staged and still there after the prune, and `ninja -n` reporting no work (the stage and the prune converge).

- [ ] **Step 4: Commit**

```bash
git add toolchain/src/ld/fgx_lddigest.py tools/stage_piles.py tools/ninja/gen.py \
        tools/ninja/manifest.json
git commit -F - <<'EOF'
feat(fgx_lddigest): the host's layout of shared libraries as loaded

What the machine's loader will leave in each library's banks, built on
fgx_bind's own placement and binding: code banks, the core and block
templates on the end of the last, then the trailer's EXPT and FIXS as
tagged blocks.  One digest per bank, with every byte that holds a runtime
bank taken as 0, written to /testbin/ld.digest for libc, termlib and
curses loaded in that order, and to ld.digest.pad with 100 bytes of the
arena held between libc and termlib.  The three libraries are staged in
/lib; the pile prune now removes only names of a pile's shape, where it
removed every libc.so.* -- libc.so.1.0 with them.
EOF
```

---

### Task 4: ld_load.c, /sbin/ldload, and lddig

**Files:**
- Modify: `toolchain/include/sys/ldctl.h` (add `struct ld_need`, `struct ld_work`, prototypes)
- Create: `toolchain/lib/libc_c/ld_load.c`
- Modify: `toolchain/lib/libc_c/libc_c.c` (`#include <sys/ldctl.h>` in the prologue; `#include "ld_load.c"` after `"libc_init.c"`)
- Create: `src/userland/ldload/ldload.c`, `tools/ldload-fgx2/build_ldload.sh`
- Modify: `.gitignore` (`!tools/ldload-fgx2/build_ldload.sh` beside `!tools/libcso-fgx2/build_libcso.sh`: `tools/*-fgx2/*` ignores everything else there)
- Create: `src/userland/lddig/lddig.c`, `src/userland/lddig/ld.so.conf.t`, `src/userland/lddig/ld.so.conf.bad`
- Modify: `tools/ninja/gen.py` (an `ldload` entry beside `libcso`), `tools/ninja/manifest.json` (`lddig` in the tool list; stage `ldload.bin` to `disk_src/sbin/ldload`, `lddig.bin` and the two conf files to `disk_src/testbin/`)
- Create: `tools/mame_test/tests/ldload.json`, `tools/mame_test/tests/ldorder.json`, `tools/mame_test/tests/lddelta.json`

**Interfaces:**
- Consumes: Task 1's `<sys/ldctl.h>` and GRANT/COMMIT semantics; Task 3's `/testbin/ld.digest` and `/lib` staging.
- Produces (step 3's binder calls these):
  - `int ld_ctl(struct ld_work *w, int svc)` -- `SYS_LDCTL` on `w->blk`; the answer, or -1 and errno.
  - `int ld_need(struct ld_work *w, char *name, int major, int minor, int pin)` -- 0 resident, 1 loaded now, -1 failed (message on fd 2). Loads the library's needed libraries first when they are absent.
  - `int ld_needs(struct ld_work *w, char *name, int major, struct ld_need *need, int max)` -- the libraries `name` imports from, in its IMPS order; -1 failed.
  - In memory, at the row's `expt_off` in its last bank: the trailer's `EXPT` and `FIXS` blocks as in the file (4-byte tag, 4-byte length, payload), then `END\0` with length 0. `tmpl_off` is the core template's offset in the last bank; the block templates follow it.

Before writing: read SunOS 4.1.3 `examples/SunOS-4.1.3/lang/rtld/cache_rtld.c:145-183` (the highest minor of a major, and the older-revision warning, `:180`) and the `rtld.c` lines spec 5.5 cites for each message; name them in the commit.

- [ ] **Step 1: The failing probes**

`src/userland/lddig/ld.so.conf.t`:

```
# termlib, then curses, which needs it
libtermlib 1
libcurses 1
```

`src/userland/lddig/ld.so.conf.bad` (blank line, trailing spaces, a missing major, a missing file, an order fault):

```
# a library above one it needs; one with no file; one with no major

libcurses 1   
libtermlib 1
libnope 1
libtermlib
```

`tools/mame_test/tests/ldload.json`:

```json
{
 "name": "ldload",
 "description": "Shared libc SP4: ldload makes libc resident, then termlib and curses from a conf file, pinned; lddig checks each library's banks against the host's layout (every runtime bank byte, a digest per bank); a second ldload finds them resident.",
 "command": "/sbin/ldload /testbin/ld.so.conf.t; /testbin/lddig libc libtermlib libcurses; /sbin/ldload /testbin/ld.so.conf.t; echo st=$?",
 "timeout_s": 300,
 "expect": {
  "screen_contains": ["ldload: libtermlib.so.1.0", "ldload: libcurses.so.1.0", "LDD libc ok", "LDD libtermlib ok", "LDD libcurses ok", "0 loaded, 3 resident", "st=0"],
  "screen_lacks": ["LDD FAIL", "ld.so:", "PANIC", "BRK"]
 }
}
```

`tools/mame_test/tests/ldorder.json`:

```json
{
 "name": "ldorder",
 "description": "Shared libc SP4: ldload with no conf file loads libc alone, silently; a conf with a library listed above one it needs refuses that one naming both, names a missing file and a line with no major, and loads the rest.",
 "command": "/sbin/ldload /nonexistent; /sbin/ldload /testbin/ld.so.conf.bad; /testbin/lddig libcurses",
 "timeout_s": 240,
 "expect": {
  "screen_contains": ["ldload: libcurses needs libtermlib, which is listed after it", "ld.so: libnope.so.1: not found", "line 6: expected", "ldload: libtermlib.so.1.0", "LDD FAIL libcurses not resident"],
  "screen_lacks": ["/nonexistent:", "PANIC", "BRK"]
 }
}
```

`tools/mame_test/tests/lddelta.json` (curses's data imports from termlib bound across a moved base: `ldctl pad` holds 100 bytes of the arena after libc, so termlib loads 100 below the base it was linked at):

```json
{
 "name": "lddelta",
 "description": "Shared libc SP4: with 100 bytes of the arena held after libc, termlib and curses load 100 below the bases they were linked at; lddig checks both against the host's layout for that order, so curses's data imports from termlib are bound at a non-zero delta.",
 "command": "/sbin/ldload /nonexistent; /testbin/ldctl pad 100; /sbin/ldload /testbin/ld.so.conf.t; /testbin/lddig -f /testbin/ld.digest.pad libtermlib libcurses",
 "timeout_s": 300,
 "expect": {
  "screen_contains": ["LDC pad", "LDD libtermlib ok", "LDD libcurses ok"],
  "screen_lacks": ["LDD FAIL", "ld.so:", "PANIC", "BRK"]
 }
}
```

Run: `tools/mame_test/run.py ldload ldorder lddelta`
Expected: all three FAIL (no `/sbin/ldload`: `not found` from sh).

- [ ] **Step 2: The header's loader half**

Append to `toolchain/include/sys/ldctl.h` before `#endif`:

```c
/* A library another needs, from its IMPS table. */
struct ld_need {
    char name[16];
    unsigned char major, minor;
    unsigned char crc[4];
    unsigned core_base;         /* the base it was linked against */
};

/* ld_load(3)'s state, all of it, in the caller's data bank: SYS_LDCTL,
 * read(2), readv(2) and SYS_LISTDIR reach only that bank, and the binder
 * calls ld_load before this process's blocks exist.  buf is scratch the
 * caller gives, in the same bank: the /lib listing, a run of relocs, a
 * library's whole trailer -- so it must hold the largest trailer
 * (libcurses.so.1.0's is 8,141 bytes) and the /lib listing. */
struct ld_work {
    struct ldblk blk;
    struct iovec iov;
    char path[48];              /* /lib/<name>.so.<major>.<minor> */
    unsigned char hdr[88];      /* header and segment table, 9 segments */
    char msg[96];               /* a message, assembled for write(2) */
    char *buf;
    unsigned bufsz;
};

int ld_ctl();
int ld_need();
int ld_needs();
```

- [ ] **Step 3: `ld_load.c`**

`toolchain/lib/libc_c/ld_load.c`:

```c
/*
 * ld_load -- make a shared library resident: read it into banks the
 * registry grants, relocate it once for the boot, bind its own imports
 * and commit it (shared libc SP4 spec, section 5.2).  /sbin/ldload calls
 * it at boot; the binder calls it on a library's first use.
 *
 * No statics: every byte of state is the caller's struct ld_work
 * (<sys/ldctl.h>).  Messages are SunOS 4.1.3 rtld's where it has one
 * (lang/rtld/rtld.c, cache_rtld.c), assembled in w->msg because a literal
 * here is in libc's code bank, which write(2) cannot read.
 *
 * The file is an FGX3 library: a 16-byte header, a segment table, its
 * segments -- code banks, the core template, the block templates -- then
 * 4-byte relocs (segment, offset, target segment) and the FGXL trailer
 * (toolchain/src/ld/fgx_ld.py).  In memory, the core template, the block
 * templates and the trailer's EXPT and FIXS blocks follow the last code
 * bank's bytes, as fgx_bind lays a library out (add_lib), the tagged
 * blocks ended by an END tag.  A reloc's byte is its target's bank, and a
 * target placed past offset 0 adds its offset to the word below.  A
 * per-process fixup (a core pointer into the core) is left for the binder
 * to set at each core copy.
 *
 * A library's imports bind only against the libraries it was linked with
 * (equal export CRCs): code imports take the recorded values, data sites
 * move by the needed core's base less the base recorded.
 */
#define LD_NDEP         4               /* needed libraries, at most */
#define LD_CHUNK        16384           /* readv(2) carries < 32768 a call */

static char *
ld_far(bank, off)
unsigned bank, off;
{
    return (char *)(((unsigned long)bank << 16) | off);
}

static unsigned
ld_rd16(p)
unsigned char *p;
{
    return p[0] | (p[1] << 8);
}

static void
ld_wr16(p, v)
unsigned char *p;
unsigned v;
{
    p[0] = v;
    p[1] = v >> 8;
}

static char *
ld_cat(d, s)
char *d, *s;
{
    while (*s)
        *d++ = *s++;
    return d;
}

static char *
ld_num(d, v)
char *d;
unsigned v;
{
    char t[6];
    int n;

    n = 0;
    do {
        t[n++] = '0' + v % 10;
        v /= 10;
    } while (v);
    while (n)
        *d++ = t[--n];
    return d;
}

/* "<a><name>.so.<major><b>\n" on fd 2; name may be 0. */
static void
ld_msg(w, a, name, major, b)
struct ld_work *w;
char *a, *name, *b;
int major;
{
    char *p;

    p = ld_cat(w->msg, a);
    if (name) {
        p = ld_cat(p, name);
        p = ld_cat(p, ".so.");
        p = ld_num(p, major);
    }
    p = ld_cat(p, b);
    *p++ = '\n';
    write(2, w->msg, p - w->msg);
}

/* SunOS cache_rtld.c:180's warning: "<file> has older revision than
 * expected <minor>". */
static void
ld_old(w, name, major, have, want)
struct ld_work *w;
char *name;
int major, have, want;
{
    char *p;

    p = ld_cat(w->msg, "ld.so: warning: ");
    p = ld_cat(p, name);
    p = ld_cat(p, ".so.");
    p = ld_num(p, major);
    *p++ = '.';
    p = ld_num(p, have);
    p = ld_cat(p, " has older revision than expected ");
    p = ld_num(p, want);
    *p++ = '\n';
    write(2, w->msg, p - w->msg);
}

int
ld_ctl(w, svc)
struct ld_work *w;
int svc;
{
    unsigned long a;
    int r;

    a = (unsigned long)(char *)&w->blk;
    r = (int)__syscall(SYS_LDCTL, svc, (unsigned)a, (unsigned)(a >> 16));
    if (__syscall_c() == 0) {
        errno = r;
        return -1;
    }
    return r;
}

static void
ld_set(w, name, major)
struct ld_work *w;
char *name;
int major;
{
    char *p;
    int i;

    p = (char *)&w->blk;
    for (i = 0; i < sizeof w->blk; i++)
        p[i] = 0;
    for (i = 0; i < 15 && name[i]; i++)
        w->blk.name[i] = name[i];
    w->blk.major = major;
}

/* w->path = /lib/<name>.so.<major>.<highest minor> -> that minor, or -1.
 * <name>.so.<major>. then digits only: a pile is libc.so.<10 hex>. */
static int
ld_find(w, name, major)
struct ld_work *w;
char *name;
int major;
{
    char pfx[32], *e, *s;
    unsigned long a;
    int n, loc, k, best, v, ok;

    e = ld_cat(pfx, name);
    e = ld_cat(e, ".so.");
    e = ld_num(e, major);
    *e++ = '.';
    *e = 0;
    e = ld_cat(w->path, "/lib");
    *e = 0;
    a = (unsigned long)w->path;
    n = (int)__syscall_db(49, (unsigned)(a >> 16), (unsigned)a,
                          (unsigned)(unsigned long)w->buf, w->bufsz);
    if (__syscall_c() == 0)
        return -1;
    if (n > w->bufsz - 64) {
        ld_msg(w, "ld.so: /lib: too many entries to search", (char *)0, 0, "");
        return -1;
    }
    best = -1;
    for (loc = 0; loc + 2 < n; loc += k + 1) {
        s = w->buf + loc + 2;
        for (k = 2; w->buf[loc + k]; k++)
            ;
        for (v = 0; pfx[v] && s[v] == pfx[v]; v++)
            ;
        if (pfx[v])
            continue;
        s += v;
        ok = *s != 0;
        for (v = 0; *s; s++) {
            if (*s < '0' || *s > '9')
                ok = 0;
            v = v * 10 + (*s - '0');
        }
        if (ok && v > best)
            best = v;
    }
    if (best < 0)
        return -1;
    e = ld_cat(w->path, "/lib/");
    e = ld_cat(e, pfx);
    e = ld_num(e, best);
    *e = 0;
    return best;
}

/* Open the library, read its header into w->hdr and its trailer into
 * w->buf -> the fd, *tlen = the trailer's length; -1 failed (named). */
static int
ld_open(w, name, major, tlen)
struct ld_work *w;
char *name;
int major;
unsigned *tlen;
{
    int fd, n, i;
    unsigned long pos, end;

    if (ld_find(w, name, major) < 0) {
        ld_msg(w, "ld.so: ", name, major, ": not found");
        return -1;
    }
    fd = open(w->path, 0);
    if (fd < 0) {
        ld_msg(w, "ld.so: ", name, major, ": not found");
        return -1;
    }
    if (read(fd, (char *)w->hdr, 16) != 16 || !(w->hdr[10] & 2) ||
        (n = w->hdr[6]) > 9 || read(fd, (char *)w->hdr + 16, 8 * n) != 8 * n)
        goto bad;
    pos = 16 + 8 * n + 4L * ld_rd16(w->hdr + 11);
    for (i = 0; i < n; i++)
        pos += ld_rd16(w->hdr + 16 + 8 * i);
    end = lseek(fd, 0L, 2);
    if (end < pos || end - pos > w->bufsz || end - pos < 17 ||
        lseek(fd, pos, 0) != pos)
        goto bad;
    *tlen = end - pos;
    if (read(fd, w->buf, *tlen) != *tlen || w->buf[0] != 'F' ||
        w->buf[1] != 'G' || w->buf[2] != 'X' || w->buf[3] != 'L' || w->buf[4] != 2)
        goto bad;
    return fd;
bad:
    ld_msg(w, "ld.so: ", name, major, ": not a shared library this loader reads");
    close(fd);
    return -1;
}

/* The tagged trailer block `tag' in w->buf -> its payload, *len; 0 if none. */
static unsigned char *
ld_blk(w, tlen, tag, len)
struct ld_work *w;
unsigned tlen;
char *tag;
unsigned *len;
{
    unsigned pos, n;
    unsigned char *b;

    b = (unsigned char *)w->buf;
    for (pos = 17; pos + 8 <= tlen; pos += 8 + n) {
        n = ld_rd16(b + pos + 4);
        if (b[pos] == tag[0] && b[pos + 1] == tag[1] && b[pos + 2] == tag[2] &&
            b[pos + 3] == tag[3]) {
            *len = n;
            return b + pos + 8;
        }
    }
    *len = 0;
    return (unsigned char *)0;
}

/* The needed libraries out of IMPS -> how many, or -1. */
static int
ld_parse_needs(p, len, need, max)
unsigned char *p;
unsigned len;
struct ld_need *need;
int max;
{
    int n, i, k, nl;

    if (p == 0 || len == 0)
        return 0;
    n = *p++;
    if (n > max)
        return -1;
    for (i = 0; i < n; i++) {
        nl = *p++;
        for (k = 0; k < nl && k < 15; k++)
            need[i].name[k] = p[k];
        need[i].name[k] = 0;
        p += nl;
        need[i].major = p[0];
        need[i].minor = p[1];
        for (k = 0; k < 4; k++)
            need[i].crc[k] = p[2 + k];
        need[i].core_base = ld_rd16(p + 6);
        p += 9 + (p[8] + 7) / 8;
    }
    return n;
}

int
ld_needs(w, name, major, need, max)
struct ld_work *w;
char *name;
int major, max;
struct ld_need *need;
{
    unsigned tlen, len;
    unsigned char *p;
    int fd, n;

    fd = ld_open(w, name, major, &tlen);
    if (fd < 0)
        return -1;
    close(fd);
    p = ld_blk(w, tlen, "IMPS", &len);
    n = ld_parse_needs(p, len, need, max);
    if (n < 0)
        ld_msg(w, "ld.so: ", name, major, ": needs too many libraries");
    return n;
}

/* Where a library's segment lives once loaded. */
struct ld_map {
    unsigned char banks[LD_MAXBANKS];
    unsigned ncode, core_at, tmpl_at;
};

static unsigned char *
ld_at(m, seg, off)
struct ld_map *m;
int seg;
unsigned off;
{
    if (seg < m->ncode)
        return (unsigned char *)ld_far(m->banks[seg], off);
    return (unsigned char *)ld_far(m->banks[m->ncode - 1],
                                   (seg == m->ncode ? m->core_at : m->tmpl_at) + off);
}

static int
ld_readin(w, fd, bank, off, n)
struct ld_work *w;
int fd;
unsigned bank, off;
unsigned long n;
{
    unsigned k;

    while (n) {
        k = n > LD_CHUNK ? LD_CHUNK : n;
        w->iov.iov_base = ld_far(bank, off);
        w->iov.iov_len = k;
        if (readv(fd, &w->iov, 1) != k)
            return -1;
        off += k;
        n -= k;
    }
    return 0;
}

/* A needed library, as the binding of imports sees it. */
struct ld_dep {
    unsigned char banks[LD_MAXBANKS];
    unsigned delta;             /* its row's base less the base recorded */
};

/* Bind one library's imports through its sites (fgx_imports.py's IMPS
 * layout: per needed library `namelen name major minor crc(4) core_base(2)
 * rows bitmap', then every import's record, then every import's sites in
 * the same order, so two cursors walk it together). */
static void
ld_bind_imps(m, p, dep)
struct ld_map *m;
unsigned char *p;
struct ld_dep *dep;
{
    unsigned char *r, *s, *site;
    unsigned ni, i, k, c, j, val;
    int lib, kind, seg;

    for (i = *p++; i; i--) {                    /* skip the libraries */
        p += 1 + p[0] + 8;                      /* name, major..core_base */
        p += 1 + (p[0] + 7) / 8;                /* rows, bitmap */
    }
    ni = ld_rd16(p);
    r = p + 2;
    for (s = r, i = 0; i < ni; i++)             /* the sites start after */
        s += 4 + s[3] + 6;
    for (i = 0; i < ni; i++) {
        lib = r[0];
        kind = r[4 + r[3]];
        seg = r[5 + r[3]];
        val = ld_rd16(r + 6 + r[3]);
        r += 4 + r[3] + 6;
        for (k = 0; k < 3; k++) {               /* call, ptr, data */
            c = ld_rd16(s);
            s += 2;
            for (j = 0; j < c; j++, s += 3) {
                site = ld_at(m, s[0], ld_rd16(s + 1));
                if (kind == 0) {
                    ld_wr16(site, val);
                    site[2] = dep[lib].banks[seg];
                } else
                    ld_wr16(site, ld_rd16(site) + dep[lib].delta);
            }
        }
    }
}
```

Then the loader proper and the entry:

```c
/* Load `name', whose row this process owns LOADING (row, holding `have'
 * banks), its needed libraries READY.  Commits, or aborts and says why. */
static int
ld_fill(w, name, major, minor, pin, row, have)
struct ld_work *w;
char *name;
int major, minor, pin, row, have;
{
    struct ld_need need[LD_NDEP];
    struct ld_dep dep[LD_NDEP];
    struct ld_map m;
    unsigned tlen, len, elen, flen, base, csize, cbase, deps, i, k, n, off, to;
    unsigned long expt_at, nrel, left;
    unsigned char *p, *e, *f, *q, *t;
    int fd, nd, core, tmpl, nseg, src, tgt, fmin;
    char crc[4];

    fd = ld_open(w, name, major, &tlen);
    if (fd < 0)
        goto abort;
    p = (unsigned char *)w->buf;
    fmin = p[6];
    core = p[7];
    tmpl = p[8];
    cbase = ld_rd16(p + 9);
    csize = ld_rd16(p + 11);
    for (k = 0; k < 4; k++)
        crc[k] = p[13 + k];
    nseg = w->hdr[6];
    if (core < 1 || core > LD_MAXBANKS || tmpl != core + 1 || nseg != tmpl + 1)
        goto bad;
    for (i = 0; i < nseg; i++)
        if (ld_rd16(w->hdr + 18 + 8 * i) || (i < core && w->hdr[20 + 8 * i]))
            goto bad;                           /* no bss; code banks CODE */
    if (fmin < minor)
        ld_old(w, name, major, fmin, minor);
    q = ld_blk(w, tlen, "IMPS", &len);
    nd = ld_parse_needs(q, len, need, LD_NDEP);
    if (nd < 0)
        goto bad;
    deps = 0;
    for (i = 0; i < nd; i++) {
        ld_set(w, need[i].name, need[i].major);
        if ((k = ld_ctl(w, LDS_ACQUIRE)) != 0) {
            if (k == 1)                         /* ours LOADING now: give it back */
                ld_ctl(w, LDS_ABORT);
            ld_msg(w, "ld.so: ", name, major, ": a library it needs is not loaded");
            goto close;
        }
        for (k = 0; k < 4; k++)
            if (w->blk.crc[k] != need[i].crc[k]) {
                ld_msg(w, "ld.so: ", name, major,
                       ": a library it needs differs from the one it was linked against");
                goto close;
            }
        for (k = 0; k < LD_MAXBANKS; k++)
            dep[i].banks[k] = w->blk.banks[k];
        dep[i].delta = w->blk.core_base - need[i].core_base;
        deps |= 1 << w->blk.row;
    }
    ld_set(w, name, major);
    w->blk.row = row;
    w->blk.nbanks = core > have ? core - have : 0;
    w->blk.core_size = csize;
    if (ld_ctl(w, LDS_GRANT) < 0) {
        ld_msg(w, "ld.so: ", name, major, errno == EINVAL ?
               ": its core size changed since it was loaded" : ": out of memory");
        goto close;
    }
    base = w->blk.core_base;
    m.ncode = core;
    for (k = 0; k < LD_MAXBANKS; k++)
        m.banks[k] = w->blk.banks[k];
    m.core_at = ld_rd16(w->hdr + 16 + 8 * (core - 1));
    m.tmpl_at = m.core_at + ld_rd16(w->hdr + 16 + 8 * core);
    expt_at = (unsigned long)m.tmpl_at + ld_rd16(w->hdr + 16 + 8 * tmpl);
    ld_blk(w, tlen, "EXPT", &elen);
    ld_blk(w, tlen, "FIXS", &flen);
    if (expt_at + 8 + elen + 8 + flen + 8 > 0x10000L)
        goto bad;

    /* The code banks, the last carrying the core and block templates. */
    if (lseek(fd, (long)(16 + 8 * nseg), 0) < 0)
        goto bad;
    for (i = 0; i < core; i++)
        if (ld_readin(w, fd, m.banks[i], 0, i < core - 1 ?
                      (unsigned long)ld_rd16(w->hdr + 16 + 8 * i) : expt_at) < 0)
            goto bad;

    /* The relocs, a buffer at a time. */
    nrel = ld_rd16(w->hdr + 11);
    n = w->bufsz / 4;
    for (left = nrel; left; left -= k) {
        k = left > n ? n : left;
        if (read(fd, w->buf, 4 * k) != 4 * k)
            goto bad;
        for (i = 0; i < k; i++) {
            p = (unsigned char *)w->buf + 4 * i;
            src = p[0];
            off = ld_rd16(p + 1);
            tgt = p[3];
            if (src >= nseg || tgt >= nseg || tgt == core ||
                off >= ld_rd16(w->hdr + 16 + 8 * src))
                goto bad;
            q = ld_at(&m, src, off);
            to = tgt == tmpl ? m.tmpl_at : 0;
            if (to)
                ld_wr16(q - 2, ld_rd16(q - 2) + to);
            *q = m.banks[tgt == tmpl ? core - 1 : tgt];
        }
    }

    /* The trailer again: core sites, imports, the tagged blocks. */
    close(fd);
    fd = ld_open(w, name, major, &tlen);
    if (fd < 0)
        goto abort;
    q = ld_blk(w, tlen, "CSIT", &len);
    for (i = 0; i + 3 <= len; i += 3) {
        t = ld_at(&m, q[i], ld_rd16(q + i + 1));
        ld_wr16(t, ld_rd16(t) + (base - cbase));
    }
    q = ld_blk(w, tlen, "IMPS", &len);
    if (q && len)
        ld_bind_imps(&m, q, dep);
    e = ld_blk(w, tlen, "EXPT", &elen);
    f = ld_blk(w, tlen, "FIXS", &flen);
    if (e == 0 || f == 0)
        goto bad;
    t = (unsigned char *)ld_far(m.banks[core - 1], (unsigned)expt_at);
    for (q = e - 8, i = 0; i < 8 + elen; i++)
        *t++ = *q++;
    for (q = f - 8, i = 0; i < 8 + flen; i++)
        *t++ = *q++;
    t[0] = 'E'; t[1] = 'N'; t[2] = 'D'; t[3] = 0;
    t[4] = t[5] = t[6] = t[7] = 0;
    ld_set(w, name, major);
    w->blk.row = row;
    for (q = e, i = 0; i < elen; i += 1 + q[i] + 6) {   /* libc's binder entry */
        n = q[i];
        if (n == 8 && q[i + 1 + n] == 0 && q[i + 1] == '_' && q[i + 2] == 'l' &&
            q[i + 3] == 'd' && q[i + 4] == '_' && q[i + 5] == 'b' &&
            q[i + 6] == 'i' && q[i + 7] == 'n' && q[i + 8] == 'd') {
            off = ld_rd16(q + i + 1 + n + 2);
            w->blk.binder[0] = off;
            w->blk.binder[1] = off >> 8;
            w->blk.binder[2] = m.banks[q[i + 1 + n + 1]];
        }
    }
    ld_blk(w, tlen, "BLKS", &len);
    close(fd);

    w->blk.minor = fmin;
    for (k = 0; k < 4; k++)
        w->blk.crc[k] = crc[k];
    w->blk.tmpl_off = m.core_at;
    w->blk.expt_off = expt_at;
    w->blk.rows = len / 6;
    w->blk.pinned = pin;
    w->blk.deps = deps;
    if (ld_ctl(w, LDS_COMMIT) < 0) {
        ld_msg(w, "ld.so: ", name, major, ": the registry refused it");
        goto abort;
    }
    return 1;
bad:
    ld_msg(w, "ld.so: ", name, major, ": not a shared library this loader reads");
close:
    close(fd);
abort:
    ld_set(w, name, major);
    w->blk.row = row;
    ld_ctl(w, LDS_ABORT);
    return -1;
}

int
ld_need(w, name, major, minor, pin)
struct ld_work *w;
char *name;
int major, minor, pin;
{
    struct ld_need need[LD_NDEP];
    int r, row, have, nd, i, rr;

    ld_set(w, name, major);
    r = ld_ctl(w, LDS_ACQUIRE);
    if (r < 0) {
        ld_msg(w, "ld.so: ", name, major, errno == EINTR ? ": interrupted" :
               errno == ENOSYS ? ": no library registry (ld.mod)" : ": registry error");
        return -1;
    }
    if (r == 0) {
        if (w->blk.minor < minor)
            ld_old(w, name, major, w->blk.minor, minor);
        return 0;
    }
    row = w->blk.row;
    have = w->blk.nbanks;
    nd = ld_needs(w, name, major, need, LD_NDEP);
    for (i = 0; nd > 0 && i < nd; i++) {
        ld_set(w, need[i].name, need[i].major);
        rr = ld_ctl(w, LDS_ACQUIRE);
        if (rr < 0)
            ld_msg(w, "ld.so: ", need[i].name, need[i].major,
                   errno == EINTR ? ": interrupted" : ": registry error");
        if (rr == 1)
            rr = ld_fill(w, need[i].name, need[i].major, need[i].minor, 0,
                         w->blk.row, w->blk.nbanks);
        if (rr < 0)
            nd = -1;
    }
    if (nd < 0) {
        ld_set(w, name, major);
        w->blk.row = row;
        ld_ctl(w, LDS_ABORT);
        return -1;
    }
    return ld_fill(w, name, major, minor, pin, row, have);
}
```

Notes for the implementer, each a place this code can be wrong in a way fcc will not report:
- `ld_fill`'s `ld_readin` for the last code bank reads `expt_at` bytes -- the bank, the core and the block templates are contiguous in the file and in memory.
- A needed library's ACQUIRE inside `ld_fill` returns 0 (it is READY: `ld_need` loaded it first, or it was resident); the IMPS list is the transitive closure in load order, so a needed library's own needs come earlier in it and nothing recurses.
- `deps |= 1 << w->blk.row` uses the row ACQUIRE copied back, before `ld_set` clears the block.
- The binder scan reads EXPT records as `fgx_ld.library_trailer` packs them -- `namelen name kind seg val(2) size(2)` -- and `ld_set` has already cleared `binder`, so a library without `_ld_bind` commits 0; it runs before `ld_blk(... "BLKS" ...)` overwrites `len`, and `e` still points into `w->buf`.
- `w->bufsz` must hold the largest trailer (curses's is 8,141 bytes today); say so in `struct ld_work`'s comment, for step 3's binder, which gives its own buffer.
- Every `ld_far` pointer is a 3-byte fcc pointer: `q - 2` stays in the bank because a reloc's offset is at least 2 (fgx_ld writes a bank byte after a word).
- If fcc rejects a construct here (an array of structs on the stack, a struct pointer member), the fix is in fcc with a fixture (CLAUDE.md, toolchain first), not a rewrite of this file.

In `libc_c.c`: add `#include <sys/ldctl.h>` with the system includes, and `#include "ld_load.c"` on the line after `#include "libc_init.c"`.

- [ ] **Step 4: `/sbin/ldload`**

`src/userland/ldload/ldload.c`:

```c
/*
 * ldload -- make shared libraries resident for the boot: libc first, then
 * each library /etc/ld.so.conf (or the file named) lists, in its order,
 * pinned (shared libc SP4 spec, section 7).  /etc/rc runs it after modload
 * has loaded ld.mod, the registry it fills.  A library listed above one it
 * needs is refused, naming both: cores stack in load order, and an
 * importer's core above its import's would waste the hole between them in
 * every process.  One line per library: version, banks, core base, time.
 *
 * Usage: ldload [conf]
 *
 * SunOS 4.1.3's ldconfig (lang/rtld/ldconfig.c) builds the cache rtld
 * reads at the same point in the boot; FGX has no cache -- the registry is
 * the resident set -- so ldload loads instead.
 *
 * FGX-Provenance: none
 */
#include <stdio.h>
#include <string.h>
#include <sys/time.h>
#include <sys/ldctl.h>

#define NLIB    16

static char lname[NLIB * 16];
static int lmajor[NLIB], skip[NLIB];
static int nlib, fails, nloaded, nresident;
static char buf[12288];
static struct ld_work w;
static struct timeval tv;

static long
ms()
{
    gettimeofday(&tv, (struct timezone *)0);
    return tv.tv_sec * 1000L + tv.tv_usec / 1000;
}

static void
load(name, major)
char *name;
int major;
{
    long t;
    int r, i;

    t = ms();
    r = ld_need(&w, name, major, 0, 1);
    if (r < 0) {
        fails++;
        return;
    }
    memset((char *)&w.blk, 0, sizeof w.blk);
    strcpy(w.blk.name, name);
    w.blk.major = major;
    ld_ctl(&w, LDS_LOOKUP);
    printf("ldload: %s.so.%d.%d: banks", name, major, w.blk.minor);
    for (i = 0; i < w.blk.nbanks; i++)
        printf(" %02X", w.blk.banks[i]);
    printf(", core $%04X", w.blk.core_base);
    if (r == 0) {
        printf(" (resident)\n");
        nresident++;
    } else {
        printf(", %ld ms\n", ms() - t);
        nloaded++;
    }
}

static void
readconf(path)
char *path;
{
    FILE *f;
    char line[80], nm[16], *p;
    int n, mj;

    f = fopen(path, "r");
    if (f == (FILE *)0)
        return;                         /* none is fine (spec section 7) */
    for (n = 1; fgets(line, sizeof line, f); n++) {
        if ((p = strchr(line, '#')) != 0)
            *p = 0;
        if (sscanf(line, "%15s", nm) != 1)
            continue;
        if (sscanf(line, "%15s %d", nm, &mj) != 2) {
            printf("ldload: %s: line %d: expected `library major'\n", path, n);
            continue;
        }
        if (nlib == NLIB) {
            printf("ldload: %s: more than %d libraries\n", path, NLIB);
            break;
        }
        strcpy(lname + 16 * nlib, nm);
        lmajor[nlib++] = mj;
    }
    fclose(f);
}

int
main(argc, argv)
int argc;
char **argv;
{
    struct ld_need need[4];
    int i, j, k, n;

    w.buf = buf;
    w.bufsz = sizeof buf;
    load("libc", 1);
    readconf(argc > 1 ? argv[1] : "/etc/ld.so.conf");
    for (i = 0; i < nlib; i++) {
        n = ld_needs(&w, lname + 16 * i, lmajor[i], need, 4);
        if (n < 0) {
            skip[i] = 1;
            fails++;
        }
        for (j = 0; j < n; j++)
            for (k = i + 1; k < nlib; k++)
                if (strcmp(need[j].name, lname + 16 * k) == 0) {
                    printf("ldload: %s needs %s, which is listed after it\n",
                           lname + 16 * i, need[j].name);
                    skip[i] = 1;
                }
    }
    for (i = 0; i < nlib; i++)
        if (!skip[i])
            load(lname + 16 * i, lmajor[i]);
    printf("ldload: %d loaded, %d resident\n", nloaded, nresident);
    return fails != 0;
}
```

`tools/ldload-fgx2/build_ldload.sh` (mode 755):

```bash
#!/bin/bash
# ldload(8), statically linked against libc's library-mode compile
# (toolchain/src/ld/fgx_static.py): it runs before any shared library is
# resident, so it cannot itself be dynamic.
set -eu
cd "$(dirname "$0")"
REPO="$(cd ../.. && pwd)"
"$REPO/toolchain/fcc" --sigs "$REPO/build/libc.sigs" \
    --data-segment ldload.data.s -o ldload.s "$REPO/src/userland/ldload/ldload.c"
python3 "$REPO/toolchain/src/ld/fgx_static.py" --name ldload --dir ldload.ld \
    --code ldload.s --data ldload.data.s --out ldload.bin
```

`tools/ninja/gen.py`, beside `"libcso"`:

```python
    # ldload(8): libc and ld.so.conf's libraries resident at boot.  Static
    # (fgx_static): nothing shared is resident when it runs.
    "ldload": dict(
        out="tools/ldload-fgx2/ldload.bin",
        script="tools/ldload-fgx2/build_ldload.sh",
        gate="src/userland/ldload",
        links=["tools/ldload-fgx2/build_ldload.sh"],
        globs=["src/userland/ldload/*"],
        extra=["toolchain/src/ld/fgx_static.py", "toolchain/src/ld/fgx_libso.py",
               "toolchain/lib/crt0_lib.s", "toolchain/lib/libc_start.s",
               "toolchain/lib/libc_start_data.s", "toolchain/lib/libc_c/core.list"],
        hard=["toolchain/lib/libc_so.s", "toolchain/lib/libc_so_data.s",
              "toolchain/lib/libc_so.blocks.json", "build/libc.sigs"],
    ),
```

`tools/ninja/manifest.json`: `{"name": "lddig"}` beside `{"name": "ldctl"}`; staging beside the ldctl entry:

```json
  {"src": "tools/ldload-fgx2/ldload.bin", "dst": "disk_src/sbin/ldload"},
  {"src": "bin/lddig.bin", "dst": "disk_src/testbin/lddig"},
  {"src": "src/userland/lddig/ld.so.conf.t", "dst": "disk_src/testbin/ld.so.conf.t"},
  {"src": "src/userland/lddig/ld.so.conf.bad", "dst": "disk_src/testbin/ld.so.conf.bad"}
```

- [ ] **Step 5: `lddig`**

`src/userland/lddig/lddig.c`:

```c
/*
 * lddig -- check what ld_load left in resident libraries' banks against the
 * host's layout of the same libraries (toolchain/src/ld/fgx_lddigest.py,
 * staged as /testbin/ld.digest).  Per library: its row (READY, base, banks,
 * template and tag offsets, block rows); every byte that holds a runtime
 * bank -- each reloc's, each code import site's -- equal to the bank it
 * names; and each bank's digest, those bytes and the per-process fixups
 * taken as 0, equal to the host's.  Prints `LDD <lib> ok' once all of a
 * library's checks pass, else `LDD FAIL <lib> <what>'.  -f names another
 * digest file (ld.digest.pad: the arena moved before termlib).
 *
 * Usage: lddig [-f digests] lib ...
 *
 * The digest h = rotl16(h, 1) ^ byte is linear: byte b at index i of n
 * contributes rotl16(b, (n - 1 - i) % 16), so a byte is taken out by XORing
 * its contribution away, with no copy of the bank.
 *
 * FGX-Provenance: none
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/ldctl.h>

static struct ld_work w;
static char wbuf[4096];
static unsigned char hdr[88], *rel, *tr;
static unsigned trlen, nrel, nseg, core, tmpl, core_at, tmpl_at;
static unsigned long tagend;
static unsigned char banks[8];
static unsigned dg[8];
static unsigned long dlen[8];
static char *digests = "/testbin/ld.digest";
static int bad;

static unsigned
rd16(p)
unsigned char *p;
{
    return p[0] | (p[1] << 8);
}

static unsigned
rotl(v, n)
unsigned v, n;
{
    n &= 15;
    return n ? (v << n) | (v >> (16 - n)) : v;
}

static unsigned char *
at(seg, off, bi, pos)
int seg;
unsigned off;
int *bi;
unsigned *pos;
{
    *bi = seg < core ? seg : core - 1;
    *pos = seg < core ? off : (seg == core ? core_at : tmpl_at) + off;
    return (unsigned char *)(((unsigned long)banks[*bi] << 16) | *pos);
}

/* Take the byte at (bank bi, pos) out of that bank's digest. */
static void
mask(bi, pos)
int bi;
unsigned pos;
{
    unsigned char *p;

    p = (unsigned char *)(((unsigned long)banks[bi] << 16) | pos);
    dg[bi] ^= rotl(*p, (unsigned)((dlen[bi] - 1 - pos) & 15));
}

static void
fail(lib, what)
char *lib, *what;
{
    if (!bad)
        printf("LDD FAIL %s %s\n", lib, what);
    bad = 1;
}

static unsigned char *
tblk(tag, len)
char *tag;
unsigned *len;
{
    unsigned pos, n;

    for (pos = 17; pos + 8 <= trlen; pos += 8 + n) {
        n = rd16(tr + pos + 4);
        if (memcmp((char *)tr + pos, tag, 4) == 0) {
            *len = n;
            return tr + pos + 8;
        }
    }
    *len = 0;
    return (unsigned char *)0;
}

static int
want(lib, base, nb, d)
char *lib;
unsigned *base, *nb, *d;
{
    FILE *f;
    char nm[16];
    int mj, i;

    f = fopen(digests, "r");
    if (f == (FILE *)0)
        return -1;
    while (fscanf(f, "%15s %d %x %u", nm, &mj, base, nb) == 4) {
        for (i = 0; i < *nb && i < 8; i++)
            fscanf(f, "%x", &d[i]);
        if (strcmp(nm, lib) == 0) {
            fclose(f);
            return 0;
        }
    }
    fclose(f);
    return -1;
}

static void
check(lib)
char *lib;
{
    char path[48];
    FILE *f;
    unsigned wbase, wnb, wd[8], elen, flen, len, i, j, k, c, ni, off, pos, d;
    unsigned long sum, left;
    unsigned char *p, *q, *r, *s, *b, dbanks[4 * 8];
    int bi, src, tgt, nd;

    bad = 0;
    if (want(lib, &wbase, &wnb, wd) < 0) {
        fail(lib, "not in the digest file");
        return;
    }
    memset((char *)&w.blk, 0, sizeof w.blk);
    strcpy(w.blk.name, lib);
    w.blk.major = 1;
    if (ld_ctl(&w, LDS_LOOKUP) < 0 || w.blk.state != LD_READY) {
        fail(lib, "not resident");
        return;
    }
    sprintf(path, "/lib/%s.so.1.%d", lib, w.blk.minor);
    if ((f = fopen(path, "r")) == (FILE *)0) {
        fail(lib, "no file");
        return;
    }
    fread((char *)hdr, 1, 16, f);
    nseg = hdr[6];
    fread((char *)hdr + 16, 1, 8 * nseg, f);
    for (sum = 16 + 8 * nseg, i = 0; i < nseg; i++)
        sum += rd16(hdr + 16 + 8 * i);
    fseek(f, sum, 0);
    nrel = rd16(hdr + 11);
    rel = (unsigned char *)malloc(4 * nrel + 1);
    fread((char *)rel, 1, 4 * nrel, f);
    tr = (unsigned char *)malloc(12288);
    trlen = fread((char *)tr, 1, 12288, f);
    fclose(f);
    core = tr[7];
    tmpl = tr[8];
    core_at = rd16(hdr + 16 + 8 * (core - 1));
    tmpl_at = core_at + rd16(hdr + 16 + 8 * core);
    tblk("EXPT", &elen);
    tblk("FIXS", &flen);
    tagend = (unsigned long)tmpl_at + rd16(hdr + 16 + 8 * tmpl) + 8 + elen + 8 + flen + 8;
    for (i = 0; i < 8; i++)
        banks[i] = w.blk.banks[i];
    tblk("BLKS", &len);
    if (w.blk.nbanks != core || w.blk.core_base != wbase || wnb != core ||
        w.blk.tmpl_off != core_at ||
        w.blk.expt_off != tmpl_at + rd16(hdr + 16 + 8 * tmpl) || w.blk.rows != len / 6)
        fail(lib, "its row");

    /* Digest every bank whole, then take the runtime bytes out. */
    for (i = 0; i < core; i++) {
        dlen[i] = i < core - 1 ? rd16(hdr + 16 + 8 * i) : tagend;
        b = (unsigned char *)((unsigned long)banks[i] << 16);
        for (d = 0, left = dlen[i]; left; left--)
            d = ((d << 1) | (d >> 15)) ^ *b++;
        dg[i] = d;
    }
    for (i = 0; i < nrel; i++) {
        p = rel + 4 * i;
        src = p[0];
        tgt = p[3];
        q = at(src, rd16(p + 1), &bi, &pos);
        if (*q != banks[tgt == tmpl ? core - 1 : tgt])
            fail(lib, "a reloc's bank byte");
        mask(bi, pos);
    }
    p = tblk("FIXS", &flen);
    for (i = 0; i + 2 <= flen; i += 2) {
        at(core, rd16(p + i), &bi, &pos);
        mask(bi, pos);
    }
    p = tblk("IMPS", &len);
    if (p && len) {
        nd = *p++;
        if (nd > 4) {
            fail(lib, "needs more than 4 libraries");
            nd = 0;
        }
        for (i = 0; i < nd; i++) {
            memset((char *)&w.blk, 0, sizeof w.blk);
            memcpy(w.blk.name, (char *)p + 1, p[0]);
            w.blk.major = p[1 + p[0]];
            ld_ctl(&w, LDS_LOOKUP);
            memcpy((char *)dbanks + 8 * i, (char *)w.blk.banks, 8);
            p += 1 + p[0] + 8;
            p += 1 + (p[0] + 7) / 8;
        }
        ni = rd16(p);
        r = p + 2;
        for (s = r, i = 0; i < ni; i++)
            s += 4 + s[3] + 6;
        for (i = 0; i < ni; i++) {
            k = r[4 + r[3]];                    /* kind */
            j = r[5 + r[3]];                    /* segment */
            nd = r[0];                          /* library */
            r += 4 + r[3] + 6;
            for (c = 0; c < 3; c++) {
                len = rd16(s);
                s += 2;
                for (off = 0; off < len; off++, s += 3) {
                    if (k != 0 || c == 2)
                        continue;
                    q = at(s[0], rd16(s + 1) + 2, &bi, &pos);
                    if (*q != dbanks[8 * nd + j])
                        fail(lib, "a code import's bank byte");
                    mask(bi, pos);
                }
            }
        }
    }
    for (i = 0; i < core; i++)
        if (dg[i] != wd[i]) {
            sprintf(path, "bank %d digest %04x, host %04x", i, dg[i], wd[i]);
            fail(lib, path);
        }
    free((char *)rel);
    free((char *)tr);
    if (!bad)
        printf("LDD %s ok\n", lib);
}

int
main(argc, argv)
int argc;
char **argv;
{
    int i;

    w.buf = wbuf;
    w.bufsz = sizeof wbuf;
    i = 1;
    if (argc > 2 && strcmp(argv[1], "-f") == 0) {
        digests = argv[2];
        i = 3;
    }
    for (; i < argc; i++)
        check(argv[i]);
    return 0;
}
```

- [ ] **Step 6: Build and run**

Run: `python3 tools/ninja/gen.py && ninja > $S/t4_build.log 2>&1; tail -5 $S/t4_build.log; grep -i "stack budget\|check_stack_budget" -A3 $S/t4_build.log | head; tools/mame_test/run.py ldload ldorder lddelta`
Expected: the build clean, with the arena stack-budget stamp passing now that `/sbin/ldload` is in the staged set it sums (read its line, do not infer it); `3 passed, 0 failed`, none cached. Copy the `ldload: libc.so.1.0: ... N ms` line from the `ldload` run's screen dump into the ledger: it is libc's load time, and Task 5 decides on it.

If `lddig` fails on a digest, the first question is which side is wrong: compare the failing bank's raw bytes (a `run.py` memory dump, `FGX_MAME_DUMP`) against `fgx_lddigest`'s layout at the reported bank before changing either.

- [ ] **Step 7: Controls -- the loader wrong two ways**

(a) In `ld_fill`, skip the core sites (`for (i = 0; i + 3 <= len && 0; ...)`), `ninja`, `tools/mame_test/run.py ldload`. Expected: FAIL with `LDD FAIL libtermlib bank 0 digest ...` (termlib has 220 core sites). Restore.
(b) In the reloc loop, drop the `to` add (`if (0)`), `ninja`, run `ldload`. Expected: FAIL with `LDD FAIL libc bank ...` (libc's core points into its templates 37 times). Restore.
(c) In `ld_bind_imps`, drop the data delta (`ld_wr16(site, ld_rd16(site))`), `ninja`, run `lddelta` and `ldload`. Expected: `lddelta` FAILs with `LDD FAIL libcurses bank ...` (curses's data sites into termlib move by -100); `ldload` still passes (every delta there is 0 -- why `lddelta` exists). Restore, `ninja`.

- [ ] **Step 8: Shipped bytes, gate, commit**

Run: `find disk_src -type f ! -path 'disk_src/testbin/*' -print0 | sort -z | xargs -0 shasum > $S/ship_t4.txt; diff $S/ship_t2.txt $S/ship_t4.txt`
Expected: only the added `disk_src/lib/lib*.so.1.0` (Task 3) and `disk_src/sbin/ldload`; every existing binary and pile file unchanged (`ld_load.c` is in the static pile, which no shipped tool reaches).

Run: `tools/gate.sh > $S/gate_t4.log 2>&1; tail -3 $S/gate_t4.log`
Expected: `GATE GREEN`.

```bash
git add toolchain/include/sys/ldctl.h toolchain/lib/libc_c/ld_load.c \
        toolchain/lib/libc_c/libc_c.c src/userland/ldload src/userland/lddig \
        .gitignore tools/ldload-fgx2/build_ldload.sh tools/ninja/gen.py \
        tools/ninja/manifest.json tools/mame_test/tests/ldload.json \
        tools/mame_test/tests/ldorder.json tools/mame_test/tests/lddelta.json
git status --short tools/ldload-fgx2      # build_ldload.sh tracked, nothing else
git commit -F - <<'EOF'
feat(libc): ld_load, and ldload(8) to make libraries resident

ld_load(3) makes a shared library resident: the highest minor of its
major in /lib (SunOS 4.1.3 cache_rtld.c), its code banks read with
readv(2) into banks the registry grants -- the core and block templates
on the end of the last, the trailer's EXPT and FIXS as tagged blocks
after them -- its relocs applied once for the boot, its core sites moved
to the base GRANT assigned, its imports bound against the libraries it
was linked with, and COMMIT with the rows it imports from.  Libraries it
needs load first.  It keeps no statics -- all its state is the caller's
struct ld_work -- so the binder can call it before blocks exist.

ldload(8), static, makes libc resident and then each library a conf file
lists, in its order, pinned; it refuses a library listed above one it
needs, naming both, and prints each library's banks, core base and load
time.

lddig (testbin) checks every runtime bank byte the loader wrote and a
digest of each bank against fgx_lddigest's layout of the same libraries,
including curses bound across a moved termlib base.
EOF
```

---

### Task 5: libc resident at boot

**Files:**
- Create: `disk_src/etc/ld.so.conf`
- Modify: `disk_src/etc/rc.in` (after the `modload` line)
- Create: `disk_src/usr/man/cat8/ldload.8`
- Modify: `tools/mame_test/tests/ldload.json` (libc checked before ldload runs)

**Interfaces:**
- Consumes: Task 4's `/sbin/ldload`.

Before writing: read where SunOS 4.1.3's boot runs ldconfig -- `examples/SunOS-4.1.3/etc/files/rc.local:262-263` (`if [ -f /usr/etc/ldconfig ]; then ldconfig; echo "link-editor directory cache"`) -- and read `examples/SunOS-4.1.3/man/man8/ldconfig.8` for the man page's shape; name both in the commit. Read `disk_src/usr/man/cat8/adjkerntz.8` for the format FGX's pages are in.

- [ ] **Step 1: The failing probe**

In `tools/mame_test/tests/ldload.json`, the command becomes `/testbin/lddig libc; /sbin/ldload /testbin/ld.so.conf.t; /testbin/lddig libtermlib libcurses; /sbin/ldload /testbin/ld.so.conf.t; echo st=$?`, and the description says libc is resident from boot.

Run: `tools/mame_test/run.py ldload`
Expected: FAIL with `LDD FAIL libc not resident` (nothing loads it at boot yet).

- [ ] **Step 2: The boot's headroom, before**

The harness types its command a fixed `FGX_MAME_BOOT_S` (60) seconds after power-on (`tools/mame_test/run.py:123-146`), and the prompt arrives at about 54-55 s, so every gate test shares about 5 s of headroom. A `prompt-exit @ frame` figure is counted from the paste and does not move until the boot overruns it -- it cannot measure this. Two numbers can: Task 4's libc `N ms` line (from the ledger), and the smallest `FGX_MAME_BOOT_S` at which a boot probe still passes.

Run: `for b in 53 54 55 56 57; do FGX_MAME_BOOT_S=$b tools/mame_test/run.py ldctl_selector > $S/boot_before_$b.log 2>&1; echo "$b $(grep -E 'passed' $S/boot_before_$b.log | tail -1)"; done`
Expected: a pass/fail per value; the smallest passing value is the boot's length before. Record it.

If Task 4's libc load time is over 2,000 ms, STOP before Step 3: libc at boot spends more than half the shared headroom, and that trade is the maintainer's call.

- [ ] **Step 3: The conf, the rc line, the page**

`disk_src/etc/ld.so.conf`:

```
# Shared libraries made resident at boot, after libc, by ldload(8): one per
# line, `library major', in the order their cores stack -- a library after
# the ones it needs.  Every other library loads when a program first needs it.
```

`disk_src/etc/rc.in`, after the `/sbin/modload ...` line:

```
# SHARED LIBRARIES FOR THE BOOT: libc, then what /etc/ld.so.conf lists,
# resident and pinned (ldload(8)).  After modload, which loads ld.mod, the
# registry ldload fills.  SunOS 4.1.3's rc.local runs ldconfig to build
# rtld's cache (etc/files/rc.local); FGX has no cache to build -- the
# registry is the resident set -- so ldload loads instead.
/sbin/ldload >/dev/console 2>&1
```

`disk_src/usr/man/cat8/ldload.8`, in adjkerntz.8's format: NAME (`ldload - make shared libraries resident`), SYNOPSIS (`/sbin/ldload [conf]`), DESCRIPTION (libc, then the conf's libraries in order, pinned; the order rule; the output line; a missing conf is fine), FILES (`/etc/ld.so.conf`, `/lib/*.so.*`), SEE ALSO (`modload(8)`), BUGS:
- a library resident before ldload runs (loaded by a program) and listed in the conf stays unpinned;
- a library whose needed library changed since it was linked is refused until it is relinked;
- any user can make an installed library resident, bounded by its banks (spec section 11).

- [ ] **Step 4: Rebuild and run**

Run: `ninja > $S/t5_build.log 2>&1; for b in 53 54 55 56 57 58 59; do FGX_MAME_BOOT_S=$b tools/mame_test/run.py ldctl_selector > $S/boot_after_$b.log 2>&1; echo "$b $(grep -E 'passed' $S/boot_after_$b.log | tail -1)"; done`
Expected: the smallest passing value; record it against Step 2's. If it rose by more than 2 s, or is above 57, STOP: the gate's boot timing is the maintainer's call, not a ruling.

Then every probe this step and step 1 own, fresh (libc is resident from boot now, so step 1's arena assertions run against libc's base):

Run: `tools/mame_test/run.py ldctl_selector ldctl_basic ldlibexec modimage ldctl_fork ldctl_exec ldctl_race ldctl_intr ldctl_kill ldctl_eperm ldctl_reclaim ldctl_reuse ldctl_deps ldload ldorder lddelta > $S/t5_probes.log 2>&1; tail -3 $S/t5_probes.log`
Expected: `16 passed, 0 failed`, none cached.

- [ ] **Step 5: Shipped bytes, gate, commit**

Run: `find disk_src -type f ! -path 'disk_src/testbin/*' -print0 | sort -z | xargs -0 shasum > $S/ship_t5.txt; diff $S/ship_t4.txt $S/ship_t5.txt`
Expected: only `etc/rc.in`, `etc/ld.so.conf`, `usr/man/cat8/ldload.8` (and their staged copies) differ.

Run: `tools/gate.sh > $S/gate_t5.log 2>&1; tail -3 $S/gate_t5.log`
Expected: `GATE GREEN`.

```bash
git add disk_src/etc/ld.so.conf disk_src/etc/rc.in disk_src/usr/man/cat8/ldload.8 \
        tools/mame_test/tests/ldload.json
git commit -F - <<'EOF'
feat(rc): libc resident at boot, and /etc/ld.so.conf

/etc/rc runs ldload(8) after modload: libc becomes resident and pinned
for the boot, then each library /etc/ld.so.conf lists, which ships
empty.  Every other library loads when a program first needs it.
EOF
```

---

### Task 6: the spec and the roadmap

**Files:**
- Modify: `docs/history/plans/2026-09-30-shared-libc-sp4-design.md` (sections 4, 5.2, 5.4, 7, 11, 12)
- Modify: `docs/ROADMAP.md` (the shared libc paragraph)

- [ ] **Step 1: Amend the spec to the build**

- Section 4: the block is 50 bytes with `deps`; GRANT takes the core size and assigns the base (a row holds one size for the boot); COMMIT takes `deps`; reclaim skips a row a READY row imports from, so importers go first and a pinned importer keeps its imports.
- Section 5.2: in memory, EXPT and FIXS follow the block templates as tagged blocks ended by `END`, at `expt_off`; a library's import from a changed library is refused until step 3's by-name binding; a bank is read in 16 KB readv(2) chunks, since one call carries at most 32767 bytes (ruling 6); libc's binder entry comes from its `_ld_bind` export (ruling 7).
- Section 5.5: the older-revision warning carries both minors, as SunOS `cache_rtld.c:180` does.
- Section 5.4: the copier reaches `_lib_init` as its third argument from `_crt0_inits`, and writes both bank bytes from its arguments (rulings 1 and 2, with their reasons).
- Section 7: ldload's output line and the order rule as built.
- Section 11: the "unpinned when resident first" behaviour, as in ldload(8)'s BUGS.
- Section 12: "Step 2 landed 2026-MM-DD": what was built, the measured libc load time and the boot's length before and after (the smallest passing `FGX_MAME_BOOT_S`), ld.mod's size, the probes and their controls (the data-delta path proven only by `lddelta`'s moved base), and what was found (the two step 1 defects, and the pile prune that removed `libc.so.1.0`).

- [ ] **Step 2: ROADMAP**

One sentence in the shared libc paragraph: step 2 (loading; libc resident at boot) landed; next, step 3 (binding).

- [ ] **Step 3: Commit**

```bash
git add docs/history/plans/2026-09-30-shared-libc-sp4-design.md docs/ROADMAP.md
git commit -F - <<'EOF'
docs(shared-libc): SP4 step 2 as built

The spec's registry, loading and copier sections brought to the build --
the 50-byte block with its import mask, the base at GRANT, reclaim's
order, the tagged blocks after the templates, the copier as an argument
-- and step 2's measurements: libc's load time at boot and the boot's
length before and after.
EOF
```
