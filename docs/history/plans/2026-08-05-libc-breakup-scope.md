# libc breakup -- scope (2026-08-05)

**STATUS: DONE, 2026-08-05 at `e544f5f12`.  Measured results in section 5.**

Retires GitLab #25: the fcc fixture link inlines the whole libc pile into one
segment, so any libc addition can blow Merlin's 64 KB seg0 ceiling.  The
login-stack campaign added four entry points (`getttyent` family, `crypt`,
`getpass`, `rewind`) and crossed it, taking 70 fixtures red.

Direction set by the maintainer 2026-08-04: reevaluate what is in libc and break it into
separate libraries with BSD discipline, as was already done for curses; and
(2026-08-05) do BOTH that and the archive conversion.

This is a scoping doc, not an implementation plan.

---

## 1. Measured state

| Artifact | Size |
|---|---|
| `toolchain/lib/libc_c/libc_c.c` | 3,875 lines C, **195 top-level definitions** |
| `toolchain/lib/libc_c.s` (generated, checked in) | **1,275,735 B / 41,925 lines** |
| `libc.s` (hand asm) | 28,646 B |
| `fcc_libc_shims.s` | 25,808 B |
| `libfgx.s` | 68,173 B |
| `args.s` | 15,010 B |

The fixture link template (`toolchain/tests/*/\_seg0.link.s`, 37 copies) `PUT`s
**all of it** into one segment at `ORG $0B0000`:

```
                PUT    ../../lib/crt0_far.s
                PUT    fcc_output.s
                PUT    ../../lib/fcc_runtime.s
                PUT    ../../lib/libc.s
                PUT    ../../lib/fcc_libc_shims.s
                PUT    ../../lib/libc_c.s
                PUT    ../../lib/libfgx.s
                PUT    ../../lib/args.s
```

A fixture that calls five libc functions links all 195.

**The diagnosis is not that libc contains the wrong things.**  Reading the 195
definitions, nearly all are legitimately libc by BSD's own layout: stdio, string,
malloc, the syscall wrappers, time, `getopt`, the pwent and ttyent databases.
The defect is that **FGX links libc as a monolith while BSD's `libc.a` is
per-object with archive dead-strip.**

## 2. The mechanism already exists

`toolchain/src/ld/fgx_ar.py` implements BSD archive semantics with member-level
dead-strip -- its own header: *"a tool that calls three curses functions links
three members, not the whole library."*

- `toolchain/lib/curses.fgxa/` has **one member per function** (`addch.s`,
  `box.s`, `refresh.s`, ...), built from one `.c` per member in
  `toolchain/lib/libcurses_c/`.  This is the model.
- `resolv.fgxa` and `termlib.fgxa` are **single-member** archives -- all or
  nothing.  They get the archive plumbing without the granularity.
- `libc_c.s` is **not an archive at all**.

`tools/ninja/seg3.py` runs `fgx_ar select` against a tool's compiled `.s`,
emits a filtered aggregate `<lib>.sel.c` holding only the transitively needed
members, and compiles it -- select and compile in one edge, because select
prints the compile command.

## 3. Scope

### Slice 1 -- topical moves (small, does not clear the ceiling alone)

Functions in `libc_c.c` that are not libc by BSD's layout:

- **`ifctl`** (76 lines) -- interface control. Belongs in `libfgx`; it is an
  FGX-specific device-control call, not a C library function.
- Audit for others on the same test: *would 2.11BSD put this in `libc.a`?*
  Candidates to examine, not yet judged: the FGX-specific syscall wrappers that
  have no BSD analogue.

Cheap, correct regardless of slice 2, and it makes the archive's member list
honest. **On its own it will not clear the ceiling** -- `ifctl` is 76 lines of C
against a 41,925-line problem.

### Slice 2 -- libc becomes an archive (the actual fix)

Split `libc_c.c` into grouped member `.c` files under `toolchain/lib/libc_c/`,
mirroring `libcurses_c/`, and publish `libc.fgxa`.

**Granularity: grouped, not one-per-function.**  BSD groups related functions
per object (`strcpy.c` is its own object; `stdio` splits per function; but
several small string routines share).  195 separate members would be
build-system noise for no extra dead-strip benefit, because a caller of `printf`
pulls the whole `__lc_vpf` engine anyway.  Proposed grouping, ~20-25 members:

`string`, `mem`, `stdio_core`, `printf`, `scanf`, `malloc`, `syscall_file`,
`syscall_proc`, `signal`, `time`, `pwent`, `ttyent`, `crypt`, `getpass`,
`getopt`, `env`, `dir`, `stat`, `select`, `sgtty`, `atof`, `misc`.

The win is structural: a fixture linking `hello.c` pulls `stdio_core` +
`printf` + `string`, not `pwent` + `ttyent` + `crypt` + `select` + `dir` +
`stat`.

### Slice 3 -- convert the link sites

- 37 fixture `_seg0.link.s` templates.
- Every tool link template that `PUT`s `libc_c.s`.
- `tools/ninja/gen.py` so libc joins the `extra_libs` archive path.

This is the bulk of the mechanical work.

**It is NOT the correctness risk an earlier draft of this doc claimed.**  That
draft said a mis-selected member is "a link error at best and a silently missing
function at worst".  The second half is wrong, and the tree already has BSD's
answer (the maintainer, 2026-08-05: *if BSD has no problem managing this, we shouldn't
either*).  Verified:

- `fgx_ar.scan_refs` tokenises **every assembler identifier** in both a member's
  `.s` and its `.data.s`, drops Merlin comments, and filters against the library
  symbol universe.  That is *more* conservative than a relocation-record walk: it
  can OVER-pull but cannot UNDER-pull.  In particular a far function pointer
  sitting in a data initializer -- a real FGX bug class -- is covered, because
  `.data.s` is in the scan set.
- `fgx_ar.extract` returns an `unresolved` set, and BOTH `cmd_extract` call sites
  `die()` naming the symbols (fgx_ar.py:359, :403).
- `fgx_ld.py` independently dies on unresolved `FGX2_FARCALL` (:855) and
  `FGX2_LONG_PTR` (:803) relocations at link time.

So a genuinely missing function is a loud failure twice over.  The residual risk
is OVER-pulling -- a member dragged in because its name happened to appear as a
token -- which costs size and never correctness, and shows up as a smaller-than-
expected win rather than a bug.

The real risk in this slice is therefore mechanical breadth (210 templates), not
silent miscompilation.  The byte-identical check in section 5 remains the right
safety net for it.

---

## 4. The tradeoff -- MEASURED 2026-08-05, and it inverts

**Decision: convert to the archive. The objection does not survive measurement.**

| Measurement | Result |
|---|---|
| `merlin32` assembling `cat`'s seg2 WITH the full `libc_c.s` | **0.99 s** |
| the same seg2 with `libc_c.s` emptied | **0.09 s** |
| `fcc --pile` compiling the ENTIRE libc (3,875 lines -> 41,925) | **0.09 s** |
| one whole tool rebuild (`ninja bin/cat.bin`) | 1.32 s |
| link templates that `PUT libc_c.s` | **210** |

Assembling libc is **0.90 s of every tool's 1.32 s build, about 68%**.  With
~160 tools plus 546 fixtures, a full build-and-test cycle spends on the order of
**ten minutes** assembling libc functions the binary never calls.

The rule this campaign was worried about violating -- *"no fcc at link time"* --
protects against a cost of **0.09 s**.  The cost it locks in is **0.90 s**, an
order of magnitude larger.  Member selection makes each link assemble a subset,
so the archive path should make the build **faster**, not slower, while fixing
#25.

Section 4's original mitigations (a two-mechanism hybrid, or a member-set cache)
are therefore **not needed on wall-clock grounds**.  Revisit the cache only if a
measured full-build time after conversion says otherwise.

**Measured after implementation (2026-08-05):** the prediction held, and by more
than it claimed.  A from-scratch `ninja all` went **60.5 s -> 29.3 s** wall and
**572 s -> 114 s** of CPU.  The typical tool selects **8 of 42 members**.  Full
numbers in section 5.  The member-set cache is NOT needed and is not being
carried as follow-up work.

### Original framing, kept for the record

`toolchain/lib/libc_c.s` is **generated and CHECKED IN**, and the pile rules
state the reason explicitly (`libc_c.c` header): *"Compiled by `make libc_c`
(fcc --pile) into the CHECKED-IN lib/libc_c.s that every pile link PUTs -- no
fcc at link time."*

The archive path inverts that: `seg3.py` runs `fcc` **per tool at link time** on
the filtered aggregate.  So converting libc to an archive means:

- **Gained:** every binary shrinks to what it actually calls; #25 retired
  permanently rather than deferred to the next libc addition; `mv(1)`-style
  size surprises stop.
- **Lost:** libc is no longer precompiled once.  Every tool that links libc runs
  fcc over its own libc subset.  There are ~160 tools plus 546 fixtures.

**This needs measuring before committing**, not guessing.  The build already
does this for curses on the handful of tools that use it; doing it for libc
multiplies the fcc invocations across the whole tree.  Two mitigations exist if
the cost is real:

1. Keep a **precompiled full pile** for the common case and use the archive path
   only where size binds (fixtures, the big tools).  Ugly -- two mechanisms.
2. **Cache** the filtered aggregates by member-set hash: most tools select the
   same handful of members, so the compile happens once per distinct set rather
   than once per tool.

**Recommendation:** measure the wall-clock cost on a subset before converting all
link sites.  If a full `ninja all` grows by more than a few minutes, do the
member-set cache in the same campaign rather than accepting the regression.

## 5. Verification -- RESULTS, measured 2026-08-05 at `e544f5f12`

All numbers below were taken on one machine (16 cores, `ninja` default `-j18`).

### 5.1 The fixture suite -- the reason the campaign exists

```
bash toolchain/tests/run.sh    ->  549 passed, 0 failed
```

Before: **477 passed, 72 failed** -- the same 549 fixtures, 72 of them unable to
assemble because the link template `PUT`s the whole pile.  GitLab #25 retired.

### 5.2 Build wall clock -- section 4's open question

From-scratch builds (`ninja -t clean`, then `ninja all`).  `toolchain/fcc` and
`toolchain/fas` are host C binaries built beforehand and excluded from the timing
in every row, so the rows compare the same work.

| Tree | Wall | CPU (user) | Edges |
|---|---|---|---|
| `a4a989127` merge-base (pre-login-stack, pre-breakup) | 53.30 s / 52.77 s | 476.1 s / 473.3 s | 1066 |
| `1115217a5` login stack complete, immediately pre-breakup | 60.54 s | 572.1 s | 1122 |
| `e544f5f12` campaign complete | 29.56 s / 29.12 s | 113.9 s / 113.2 s | 1259 |

Two runs each where two numbers are shown; the pre-breakup row was measured once.

- **Isolated effect of the breakup** (`1115217a5` -> `e544f5f12`): wall
  **-51.5%**, CPU **-80.2%**.
- **Against the merge-base**: wall **-44.7%**, CPU **-76.1%**.

The middle row was first written up as corroboration of the mechanism -- adding
four libc entry points made a full build 7 s slower than the merge-base, because
under the pile model every link assembles every addition.  **That reading is
CONFOUNDED and the number should not be cited.**  The edge count also rose from
1066 to 1122 between those two trees, and that growth includes genuinely NEW
build targets the login-stack campaign added -- `getty`, `login`, `passwd`,
`halt`, `logintest`, `ttysprobe` -- not only existing binaries paying more
pile-assembly cost.  Nothing here decomposes new-target edges from
existing-target edges, so the 7 s cannot be attributed to pile bloat alone.

The mechanism is not in doubt; it is measured directly and controlled in
section 4 (merlin32 on cat's seg2: 0.99 s with the full pile, 0.09 s with it
emptied).  This row adds nothing to that and is kept only so the timing table
is complete.

Edge count rose (1066 -> 1259) because each tool gained a select-and-compile
edge.  Those edges cost the 0.09 s fcc invocation that section 4's original
framing worried about; they replace far more assembler work than they add.

### 5.3 Per-binary size

`disk_src/bin`, 67 staged files: **6,170,465 -> 3,923,250 B, -2,247,215
(-36.4%)**.

| Binary | Before | After | Delta |
|---|---|---|---|
| `true`, `false` | 72,362 | 16,717 | -76.9% |
| `sync` | 72,412 | 18,143 | -74.9% |
| `echo` | 72,844 | 26,362 | -63.8% |
| `cat` | 76,452 | 38,130 | -50.1% |
| `ls` | 86,349 | 63,184 | -26.8% |
| `sh` | 143,298 | 110,162 | -23.1% |
| `vi` (elvis) | 366,804 | 341,809 | -6.8% |
| `tcsh` | 562,622 | 550,997 | -2.1% |

The shape is exactly what member selection predicts: the saving is a near-fixed
~36 KB of unreferenced libc removed from every binary, so it dominates a small
tool and disappears into a large one.  `tcsh` selects 30 of 42 members and
therefore has almost nothing to give back.

`tools/fas/fas_fgx`: **136,533 -> 104,766 B (-23.3%)**, selecting 11 members.
Its seg2 fell 62,753 -> 32,972 B, so headroom under the 65,536 B bank went
**2,783 -> 32,564 B**.  fas was one bad week from the same ceiling that took the
fixtures down.

The ProDOS image is a fixed-size 32 MB volume, so the win shows up as free
blocks, not as a smaller `fgx.po`.

### 5.4 Member counts -- how much libc a tool actually pulls

`libc.fgxa` has **42 members** (`toolchain/lib/libc_c/` holds 43 `.c` files: the
42 members plus `libc_c.c`, the umbrella that `#include`s them).

Across the **153** tools that select from it:

| | members |
|---|---|
| minimum | 2 (`true`, `false`) |
| median | **8** |
| mean | 9.0 |
| maximum | 30 (`tcsh`) |

So the typical FGX tool genuinely needs **19% of libc** and used to link 100% of
it.  That is the answer to the question section 4 left open, and it is why the
measured CPU saving (-80%) exceeded the 68% ceiling quoted there: the 68% was
measured on `cat`'s seg2 alone, and selection also shrinks the OTHER segments and
the link itself.

### 5.5 The rest of the gate

- `tools/gate.sh`: **GREEN in 90 s**, receipt
  `.gate/e544f5f1249b898510fdc7095ca5de7351be2a60.json`.
- Full MAME corpus, `run.py --fresh` (cache deliberately bypassed -- a cached
  wall of PASS already fooled this campaign once): **45 passed, 3 failed** over
  48 tests.  The three are the known baseline: `shell_smoke` and `floppy_boot`
  (#21) and `wide60` (#18).  The recorded baseline of 44/3 was over 47 tests; the
  corpus gained `ttysprobe` from the login-stack work.
- `python3 tools/check_stack_budget.py -v`: output is **byte-identical** before
  and after; worst case stays **87/149 pages** (deepest tool in a pipeline under
  tcsh).  Smaller binaries do not move stack pages -- frame depth is a property
  of the call graph, not of how much dead library sat in the image.
- Two new gates ship with the campaign: `tools/check_libc_link_sites.py` (no link
  site may `PUT` the whole pile again; 5 dead FGX1-era files allowlisted with
  reasons) and `tools/check_vacuous_assertions.py`.

## 6. Out of scope

- `libcurses`, `libtermlib`, `libc_net` already have archives.  Giving
  `resolv.fgxa` and `termlib.fgxa` real member granularity is a follow-up, not
  this campaign.  Nor were the 12 stale checked-in archive files touched
  (GitLab #33) -- regenerating them is a real codegen change and needs its own
  verification.
- GitLab #30 (`check_stack_budget.py` under-counts) is independent.
- The login-stack branch is **unblocked**: `run.sh` is green, so the merge
  condition is met.
