# Stage 0 audit — findings (combined fcc/ld BSD-alignment train)

**Date:** 2026-07-13
**Feeds:** `2026-07-13-fcc-ld-bsd-alignment-combined-train.md` (Stage 0)
**Method:** exhaustive grep of the whole tree; read-only. Results below are the
definitive lists Stages A/B execute against.

---

## Audit 1 — hand-asm C-arg boundary set (Scope B) — ✅ CONFIRMED, exhaustive

Swept EVERY `.s` (excl. fcc-generated `.code.s`/`.data.s`, `libc_c.s`, `.expected`,
`.link.s`) for `LD[AXY] n,S` with n≥4, classified by max offset.

**Flip-sensitive boundary = exactly the 13 multi-arg per-tool stubs:**
- read `10–12,S`: `jsh`, `cwdtest`, `pipetest`, `ttytest`, `tchtest`, `waittest`
- read `6,S`: `kill`, `killtest`, `duptest`, `pgrptest`, `stopper`, `ps`, `cwdkid`

**Everything else is IMMUNE — classified, not assumed:**
- `src/kernel/jumptable.s` (reads `10,S`), `src/kernel/syscall.s` (`4,S`) — the
  reads are **saved registers**, not C args. `jumptable.s`'s own layout comment
  (`SP+2..9 = Y/X/A/return`) proves it: the syscall ABI is register-based (A/X/Y);
  the stub converts C-stack→registers, the kernel reads registers back. **Not a C-arg
  boundary.**
- `toolchain/lib/libc.s` (reads `6,S`) — ALL in `setjmp` (lines 2501/2530),
  reading the caller PB/own frame (1-arg, register X=jmp_buf). `printf` trio reads
  fmt via register X (`STX pf_fmt`), and is dead (deleted in Stage A). Immune.
- 11 single-arg stubs (`sleep`, `mtprobe`, `echod`, `orphantest`, … max `4,S`) —
  order-agnostic; retire lazily.
- `crt0*.s` → `main` — bare `JSR main`; params magic-bound to globals. No-op.
- `ntpplay_stubs.s` — 0-arg DOC-IRQ engine. CARVE-OUT (do not delete).

→ **No hidden boundary exists.** The Scope-B flip's blast radius is the 13 stubs + the
fcc/build plumbing risks (struct-guard, `libc_c.s` regen) named in Scope B §7.

## Audit 2 — WIP-libc gate — ★ found a real Stage-B blocker

Binding-table targets annotated as stub/WIP/no-op:

| name | libc target | state | impact |
|---|---|---|---|
| `kill` | `c_kill` | **WIP STUB: no-op → 0** (globals.c:228) | ★ jsh's `kill_` does the REAL syscall (job control). Routing jsh→`c_kill` **silently breaks kill.** |
| `signal` | `c_signal` | **WIP STUB: no-op install** (globals.c:227) | elvis + shells need real signal delivery. |
| `chdir` | — | **no `c_chdir` in libc_c.c** | elvis `system.c` defines its own (no-op "pretend"); jsh has `chdir_`. Needs a real libc `chdir`. |
| `popen`/`pclose` | `c_popen`/`c_pclose` | STUB → NULL/-1 | shell `|`-via-popen absent (jsh does its own pipes; ok). |
| `fflush` | `c_fflush` | no-op → 0 | benign (unbuffered libc). |

**Real-signature-verified for jsh's routed syscalls** (no stub flag): `c_open`(2),
`c_ioctl`(3), `c_waitpid`(3), `c_getcwd`(2), `c_pipe`(1), `c_dup`(1), `c_dup2`(2),
`c_spawnv`(2), `c_spawnve`(3). Their *signatures* are real; Stage B1 must still confirm
each *implementation* is real (not a stubbed body) before deleting the per-tool copy.

**★ Consequence for the plan:** Stage B1 is NOT "route the `_`-dupes to existing libc
functions" for kill/signal/chdir — those libc functions are **no-op stubs; the per-tool
stub IS the real implementation.** Stage B1 must first **port the real syscall logic
(from `jsh_stubs.s`) into libc C** (`c_kill`/`c_signal`/`c_chdir` become real), THEN
retire the per-tool stub. This is more than a routing change — it's implementing the
libc functions for real. Sequence jsh LAST in B1, after kill/signal/chdir are real.

## Audit 3 — collision census (Scope A) — ✅ clean, known set only

Real *user definitions* of libc-table names (will win under weak/strong resolution):
- `src/userland/elvis/system.c`: `access`(75), `chdir`(89, no-op), `geteuid`(90) —
  K&R defs; all resolve to elvis's own under weak/strong (desired).
- vendored `tio.c:694`: `getkey(when)` — elvis's high-level getkey; wins over pile
  weak `getkey` (this is the getkey-shadow fix, now via the linker instead of the
  temporary override table).

Everything else the census flagged (`cat`/`cmp`/`more`/`head`/`jsh`/… `int read(...)`,
`int open(...)`, `int getkey(void)`) is a **forward DECLARATION**, not a definition —
full ANSI prototypes that call the pile. No competing definition → resolves to pile
weak. Not collisions. **No malloc/free/allocator override anywhere** → the split-brain
heap caveat (Scope A §6) has no live trigger.

## Audit 4 — ABI decl-audit (Scope B) — ✅ empty-paren risk contained

Empty-paren (`f()`) declarations of functions in userland — the only ones that push
R-to-L against a possibly-L-to-R definition — exist ONLY in the elvis machine layer
`src/userland/elvis/unix.c`: `getkey/pollkey/ticks/yield` (all 0-arg → order-agnostic)
and `ttyread` (the 3-arg one, the hack added 2026-07-13). Every other tool declares
libc functions with **full ANSI prototypes** (typed args) → L-to-R both sides → safe
today and after a uniform flip (fcc controls both). **Under uniform R-to-L the unix.c
empty-paren decls become consistent by construction and the `ttyread` hack is retired.**

## Net Stage 0 result

- Scope-B boundary set is CLOSED at 13 stubs (exhaustively confirmed).
- **One real new dependency surfaced:** `c_kill`/`c_signal`/`c_chdir` are no-op stubs;
  the per-tool stubs are the real implementations. Stage B1 must implement them for
  real in libc before retiring the stubs; jsh converts LAST.
- Scope-A collisions are the known elvis set; all resolve correctly under weak/strong;
  no allocator-override → no split-brain-heap trigger.
- ABI empty-paren risk is contained to elvis unix.c and is *fixed* (not merely dodged)
  by the flip.

→ Both scopes are GO. Adjust the combined-train Stage B1 to lead with
"make `c_kill`/`c_signal`/`c_chdir` real," then jsh.

---

## Stage A2 pre-execution review (2026-07-13, Fable) — TWO showstoppers found + verified

Stage A1 (linker weak/strong) LANDED green (toolchain `ca311b83`, runtime oracle
433/433, 0 regressions). Before executing A2 (the atomic fcc+pile change) a review
surfaced two plan-breaking holes the scope doc missed; both VERIFIED against source:

**★ P0-1 — libc.s has 26 dead/colliding hand-asm labels co-assembled with the pile.**
`libc.s` and `libc_c.s` are `PUT` into the SAME Merlin segment (e.g.
`tools/color-fgx2/seg2.link.s:56-58`). `libc.s` still defines 26 plain code labels
that are the pre-T5-C hand-asm libc, superseded by the C pile but never deleted:
`exit fclose fopen fread free kill malloc memcmp memcpy memset printf fprintf
sprintf signal strcat strcmp strcpy strerror strlen strncmp strncpy tgetent
tgetflag tgetnum tgetstr ticks`. After the rename `c_malloc→malloc` &c, each collides
→ **Merlin dup-label death** before fgx_ld runs. Of the 26, exactly **4 are LIVE**
engines the C pile calls via inline `__asm JSR` (`tgetflag` libc_c.c:1069, `tgetnum`
:1087, `tgetstr` :1105, `strerror` :1225) — these must be RENAMED to private labels
(`_tc_*`/`_libc_*`) with the `__asm` strings updated in the same commit. The other 22
have zero pile/tool callers (the `JSR fprintf` hits in `src/userland/*.s` are stale
GITIGNORED fcc outputs that regenerate) and are deletable after a BRA/fallthrough
audit. `LIBC_EXPORT ticks` (:2937) and `tgetent` are plain-exported today — same
dup-export class as the printf trio the plan already named. **`getpid` (libc.s:2330,
`LIBC_EXPORT getpid`) STAYS** — table entry `{"getpid","getpid",0}` is already plain,
the pile has no counterpart, it's the live impl (an 8th special case, NOT an alias).

**★ P0-2 — the multibank link generators pack the pile as CODE, defeating A1.**
`tools/elvis-fgx2/gen_elvis_link.py` (pile into seg0 via `puts += [LIBC,SHIMS,LIBC_C,
ARGS]` :119; segments emitted `"kind":"CODE"` :135) and
`toolchain/tests/multibank/gen_sweep_link.py` do NOT put the pile in a `KIND=LIBC`
segment. `resolve_precedence` keys weak off `kind=="LIBC"` (fgx_ld.py:517), so in
elvis the pile exports are **strong**. After A2, elvis's own `getkey` + the pile's
plain `getkey` = two strong → fgx_ld "defined by multiple segments" (or Merlin dup if
same seg). **getkey_shadow passes (standard KIND=LIBC template) while elvis — the very
binary that motivated this — cannot link.** Fix: hoist the pile into its own
`KIND=LIBC` segment in BOTH generators (seg0 can't be LIBC per the LIBC gate at
fgx_ld.py:832; the pile must move OUT of seg0). This is multibank bank-emission →
needs a **`MULTIBANK_VERIFIED=1`** run. (elvis termcap.c defines only tgoto/tputs, no
tget* → no termcap resolution flip.)

**P1/P2 (smaller, folded into A2 scope):**
- stack_measure.py `SIGNAL_RE` (src/ld/stack_measure.py:62) matches `c_(signal|
  sigaction)`; post-A2 fcc emits plain `signal` → handler stack-extra silently
  dropped → runtime stack overflow. Update regex + fixture (test_stack_measure.py:153).
- ALL 7 aliases → thin WEAK pile **wrappers** (not macros): stdio.h already declares
  getc/putc as functions, and a function-like macro would both mangle the prototype
  and defeat user-wins for a port defining its own getc. Uniform wrappers, zero
  preprocessor interaction.
- Variadic residual: empty-paren K&R `int printf();` already sets `is_variadic_expl`
  (parse_stmt.c:4317) → marshals R-to-L correctly; only FULLY-implicit decls break.
  One found: `src/userland/msgtest/msgtest.c` (printf/sprintf, no stdio.h). Fix the
  include — do NOT blanket-set is_variadic_expl on implicit decls.
- c_-name hard-codings to update: tests/M11/lc_malloc.c, tests/M37/pfvar.c,
  tests/M37/getkey_shadow.c, tests/oracle.json; FGX tools/mame_test/tests/
  lc_malloc.json (+ groups/fast.txt); comment fgx_ld.py:514.
- Behavior-flip: A2 flips EVERY table name pile-wins→user-wins. One-time grep of
  userland for local defs matching the 116 names to enumerate any unintended flips.
- Ordering (strict): new fcc BEFORE `make libc_c` (old fcc would rewrite pile-internal
  `strlen`→`c_strlen`); then golden REGEN + oracle; no run_runtime in flight.

**Net:** the fcc-side plan (delete tables + collapse emit branch) is verified SOUND,
but A2 as written **cannot assemble** the LIBC segment (26 dup labels) and **cannot
link elvis** (pile-in-CODE). A2's real scope = fcc-table-deletion + libc.s
dead-hand-asm retirement (22 delete + 4 rename) + a KIND=LIBC segment restructure in
both multibank generators + the P1/P2 items. Two of these (hand-asm retirement,
multibank-layout restructure) are substantial and multibank-sensitive.
