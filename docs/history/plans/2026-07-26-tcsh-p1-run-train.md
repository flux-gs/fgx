# tcsh P1 "make it run" train

Status: PLAN OF RECORD, nothing implemented. tcsh P0 (all 46 TUs compile) is
done and committed. Revision 2 — folds in the maintainer's bank-claim point, plus
heap-boxing and shared text as deferred architectural work, after a Fable review
that overturned three premises of revision 1.

**Priority (the maintainer, 2026-07-26): chip away at tcsh's primary blockers FIRST; no
major architectural changes until tcsh runs.** Heap-boxing and shared text are
therefore recorded below as Phase A/B, explicitly AFTER first boot, even though
both would make the numbers nicer.

All figures are MEASURED (`gen_tcsh_link.py --measure`, `stack_measure.analyze`,
`fgx_ld` with the cap temporarily lifted then restored), not estimated.

---

## Hard constraints — not fixable by policy

| constraint | why | consequence |
|---|---|---|
| HW stack is bank-0 only | 65816 `S` is 16-bit | `FGX_STK_ARENA` 112 pages (28 KB) serves ALL tasks; cannot move out of bank 0 |
| 64 KB per bank | 65816 addressing | code must be split across banks |
| `TCB_SIZE` <= 64 B | `ERR TCB_SIZE-1/$40` (include/kernel.s:300), fields sum to exactly 64, `SE_SIZE = TCB_SIZE/2` coupled (:486-490), x64 stride baked into the task table (task.s:675 + ~10 `ADC #TCB_SIZE` sites) | `TCB_BankList` 8 -> 9+ is a STRUCTURAL change (128-byte stride or parallel table), not a loop-bound edit |
| FGX2 = 8 segments | `FGX2_MAX_SEGS` (include/loader.s:73), loader-enforced at parse | 6 CODE banks max today (one segment each to DATA and the shared LIBC pile) |

Everything else is soft.

---

## Blockers

| # | blocker | measured | limit |
|---|---|---|---|
| B1 | FGX2 segment cap | 9 segments trimmed / 10 untrimmed | 8 |
| B2 | per-task stack | requests the whole cap (see B3); static path 12,706 B | 8,192 B (`TASK_STACK_MAX_PAGES=32`) |
| B3 | unguarded mutual recursion | 16-function cycle | fcc guards direct self-recursion only |
| B4 | libc `wait3` | 1 unresolved symbol | absent |
| B5 | user bank pool | tcsh needs 9 (trimmed) / 10 (untrimmed) | **12 banks live** |

### B1 — segment cap

Not structural at the format level: `n_segments` is a full byte
(include/loader.s:37), the segtab is variable-length 8 B/entry (:74), and reloc
entries are `<BHB` — segment indices are full bytes and encode to 255
(fgx_ld.py:918, include/loader.s:126-128). So raising it is a constants change
PLUS a handful of fixed-size loader sites.

**Key asymmetry that decides trimmed-vs-untrimmed:** the shared libc bank is
blanked out of `_ldExtraBanks` before spawn copies it (loader.s:810-827) and
rides `TCB_LibcBank` (kernel.s:258, process.s:224-233) — it never takes a
`BankList` slot. Segment order is code 0..n-1, DATA at n, LIBC last at n+1
(gen_tcsh_link.py:152-176). So:

- **trimmed** (7 code) = 9 segments, `BankList[0..7]` = 7 code + 1 data —
  **exactly 8, no TCB change**
- **untrimmed** (8 code) = 10 segments, needs 9 `BankList` slots — TCB restructure

Revision 1 claimed "the cap must rise either way, so lift it to 10 and keep all
features for the same work." That was WRONG: 9 vs 10 segments is the difference
between a constants bump and a TCB restructure. **Keep the trim for now.**

### B2 — per-task stack

`TASK_STACK_MAX_PAGES = 32` (8,192 B); tcsh's deepest static path is 12,706 B
(50 pages). The kernel adds **+1 guard page on top of the request**
(task.s:525-532), which revision 1's arithmetic omitted.

`stack_pages` returns `max_pages` VERBATIM whenever a cycle exists
(`floored = bool(cycles)`, then `pages = max_pages` — stack_measure.py:189,
204-205). Measured: cap 32->32, 52->52, 80->80, 112->112 while `worst` stays
12,578. So tcsh does not request a measured size, it requests *whatever the
maximum is* — raise the cap to 112 and it consumes the entire arena.

**B3 therefore gates B2.** At cap 56 a floored request is 57 pages and
2 x 57 = 114 > 112, so a second shell ENOMEMs; only after B3 does 51+1 = 52 give
two concurrent shells.

Two mirrors of the cap must move together: `MAX_STACK_PAGES` (fgx_ld.py:109) and
`DEFAULT_MAX_PAGES` (stack_measure.py:96).

### B3 — unguarded mutual recursion (fails SILENTLY)

16 functions in one cycle: `syntax`/`asyntax`/`syn0`, `globexpand`/`globall`/
`glob2`, `getC1`/`getexcl`, `dobackp`, `aliasrun`, `set`, `stderror`, `Calloc`,
`blkspl`, `DgetC`.

Part is a static artifact: `stderror` ends in `reset()` /* Unwind */
(examples/2.11BSD/usr/bin/tcsh/sh.err.c:471) so edges through it unwind rather
than nest, and `stack_measure` has NO notion of non-returning functions. A small
noreturn list (`stderror`/`exit`/`xexit`/`longjmp`) cutting outgoing edges
shrinks the cycle to the genuinely recursive parser/glob/history cores before any
allowance policy is designed.

**Revision 1's "guard every prologue with frame >= N" CANNOT WORK.** Measured
frames of the cycle members (tools/tcsh-fgx2/*.code.s):

    syntax 0 | asyntax 0 | glob2 40 | globexpand 42 | getC1 2 | globall 8
    ...all STKGUARD=0.  Only dobackp (1040) is guarded.

The gate is `indirect || self_recursive || 2*slots >= 128`
(parse_stmt.c:6533-6535). Every genuinely recursive member has a 0-42 byte frame,
so "frames >= N" misses all of them for any N > 42; to work it degenerates to
guard-everything, i.e. maximal golden churn for every tool.

Replacement: an fcc FLAG (`-fstack-guard-all`) forcing `STKGUARD=1`, applied to
tcsh's TUs only. Every cycle member gets guarded, ZERO goldens move (goldens
build without the flag), cost confined to the one binary that needs it, reusable
for the next recursive port. The guard mechanism itself is sound against a single
huge frame: after `SBC #FRAMESIZE`, `BCC` catches wrap and `CMP _fcc_stkfloor`/
`BCC` catches any landing below the floor regardless of jump size
(emit.c:1668-1672), ~9 bytes / ~9 cycles per call.

### B4 — libc `wait3`

tcsh uses it for job control. FGX has `waitpid`; the kernel returns status
correctly (bank-drop bug fixed 2026-07-24). The `struct rusage` third argument
has nothing behind it on FGX — zero-fill and document.

### B5 — user bank pool (NEW; the maintainer 2026-07-26)

`BANK_USER_COUNT = 22` is only an EQU ceiling. `Bank_Init` CLAMPS the pool to the
loader's actual claim (`KFGX_REST_COUNT - REST_USER_FIRST_OFF`, bank.s:35-45),
and the claim is `RESTOFOS_BANKS EQU $13` = 19 banks, of which 7 are fixed
regions -> **12 user banks live**. Untrimmed tcsh at 10 banks is **83%** of that.

The maintainer: the claim can go up to ~6 MB conservatively, and it is essentially one
knob. Verified — the machinery already anticipates it:

- pool floor is dynamic (`_kUserFirstBank = _restBaseBank + REST_USER_FIRST_OFF`,
  "was fixed $0A", bank.s:2-3);
- `Bank_Init` already handles a claim SMALLER than the target by pre-marking the
  shortfall allocated, so small-RAM machines keep working (`RESTOFOS_MIN_BANKS
  $0A` is the halt floor).

**Companion that hard-stops otherwise:** `BankBitmap DS 3` (include/memmap.s:606)
is 24 bits, capping the pool at 24 banks REGARDLESS of the claim. ~6 MB of user
banks (89) needs 12 bytes, and `Bank_Init`'s three unrolled `STA`s become a loop.
A `KMem_BankBitmap_canary` sits immediately after it (:608), so an over-claim
without widening trips the canary rather than corrupting silently.

**Trade-off the code documents:** `RESTOFOS_BANKS` was SHRUNK from `$1D` because
"the kernel heap now GROWS at runtime via `_Arena_GrowMM`, so the boot claim is a
working set, not the ceiling; the freed banks stay with the MM for runtime
growth" (kernel.s:63-69). A large static claim trades a runtime-extensible kernel
heap for a fixed user pool. Pick the number against `_Arena_GrowMM` headroom, not
just against tcsh.

B5 removes pool pressure but touches NONE of B1/B2/B3 — those are per-binary or
hardware.

---

## Phase sequence — tcsh first

### P1. B4 `wait3` (independent, smallest)

Thin wrapper over `waitpid(-1, status, options)` in libc_c.c, zero-filling
`*rusage` when non-NULL with a comment saying so. Fixture + goldens + runtime.
Risk: low.

### P2. B5 bank claim + bitmap

`RESTOFOS_BANKS` `$13` -> target (~6 MB of user banks), `BankBitmap` 3 -> 12 B,
`Bank_Init`'s unrolled zeroing -> a loop, `BANK_USER_LAST`/`BANK_USER_COUNT`
EQUs. Verify the small-RAM clamp path still halts/clamps correctly, and that the
bitmap canary is intact. Decide the claim against `_Arena_GrowMM` headroom.
Risk: low-medium; the clamp path is the thing to test, not the happy path.

### P3. B1 segment cap 8 -> 9, MINIMAL (keep the trim)

Constants: `FGX2_MAX_SEGS`, `MAX_SEGS` (fgx_ld.py:104), `_ldSegTable` 64 -> 72 B.
Add a linker+loader rule "segment 8 must be `kind=LIBC`" so the 9th segment
cannot be a code bank and `BankList` can never need a 9th slot.

**Enumerated sites (a "[1..7] loop" grep MISSES most of these):**
- `_ldExtraBanks DS 7` (loader.s:39) -> 8. At 9 segments the libc segment is
  index 8, so the reloc pass writes slot `Y = 8-1 = 7` (loader.s:594) — ONE PAST
  THE BUFFER, into the adjacent `_ldLibcSeg`. Silent adjacent-variable stomp.
- `_BankForSeg`'s `CMP #FGX2_MAX_SEGS` (loader.s:1041) — NOT a loop; if missed,
  every JSL-into-libc reloc silently patches bank 0.
- unrolled F4 zeroing (loader.s:491-497) and the second zeroing (:135-141)
- `_FreeExtras` 0..6 walk (loader.s:1058)
- unrolled 7-entry spawn copy (process.s:210-223)

Also fix `gen_sh_link.py:98` `n_max=7` -> 6 (7 code banks = 9 segments, which
fgx_ld rejects; latent because bsh needs 2).

Kernel TCB, exit free walk, fork/exec bank copying: UNTOUCHED at 9 segments.
Risk: MEDIUM. Mitigation: the site list above verbatim in the commit, plus a
probe that spawns/exits a 9-segment binary repeatedly and checks the bank free
count returns to baseline.

### P4. FIRST BOOT of trimmed tcsh

`tcsh -c 'echo hi'` under MAME. Trivial stack depth, so the +1 guard page and the
128 B floor margin cover the smoke test without B2/B3. Revision 1 gated first
boot behind its shakiest phase; this surfaces P2-class runtime gaps weeks
earlier. Measure and record the reloc count here (fgx_ld dies above 65535 —
fgx_ld.py:845-846; the cap-lifted link succeeded so tcsh fits, but a 466 KB
binary is the first plausible tenant of that ceiling).

### P5. B3 guard + accounting

`-fstack-guard-all` applied to tcsh's TUs; noreturn list + a bounded per-cycle
allowance in `stack_measure` so the linker stops demanding `max_pages`. Required
before interactive/deep-input use, NOT before the smoke boot.

### P6. B2 stack cap

`TASK_STACK_MAX_PAGES` 32 -> 56 plus `MAX_STACK_PAGES` and `DEFAULT_MAX_PAGES`.
Re-derive `stkfloor`'s calibration (it drifted once already this month when the
+1 guard page landed). With B3 fixed the request should be the measured ~51.

### P7. Interactive bring-up

Job control, tty modes, the editor. Expect a second round of gaps — that is P2 of
the port proper. Measure the cost of any plain-`fork` path here: forking a
9-bank tcsh copies ~600 KB per call (tcsh uses vfork for command execution, but
backquote/pipeline paths need checking).

---

## Phase A/B — architectural, AFTER tcsh runs

Both would improve the numbers above; neither is a prerequisite, and per the maintainer's
priority neither starts before P4.

### A. Compiler-owned heap-boxing of large aggregates

Already the recorded design, never built: *"compiler-owned heap-boxing for large
aggregate locals (>~1KB: frame slot holds a far pointer, prologue allocates,
epilogue frees) so elvis-class frames compile unmodified"*
(docs/history/plans/architecture-redesign.md:360; it was T4's other half — the soft stack got
deleted, this did not land; `grep` finds nothing in fcc's source).

Targets tcsh directly: `ChangeSize` 2068, `main` 1676, `heredoc` 1576,
`do_aliases` 1570, `EchoTC` 1560 — 30 functions >= 512 B totalling 25 KB. Moves
the deepest path from 12,706 B toward the ~4,846 B of genuine frames.

**May retire B2 entirely** — if the boxed path drops under 8,192 B, the stack cap
never needs raising. Worth re-measuring before committing to P6, but NOT worth
blocking P4 on.

### B. Shared text

The mechanism EXISTS and is proven — for one bank. `loader.s:51-55` describes a
registry keyed on a match, `refcount++`, and critically `lseek()`s PAST the file
bytes rather than reading them; the bank is freed only at refcount zero
(:583, :1091). Application code is the opposite today: `Bank_Alloc` per segment
per load (loader.s:414, :641), so every exec copies the whole 466 KB.

Generalising it to application code banks buys, on both axes at once:
- memory: N shells share one copy instead of N x ~450 KB
- load time: a re-exec skips reading those bytes entirely

Biggest single win for a shell that is re-exec'd constantly, and an extension of
working machinery rather than new invention. Note the recorded caveat: shared
segments must currently be closed zero-reloc call graphs, which is why libc can
be shared but a library that calls libc cannot — that constraint has to be
understood before generalising.

### C. Untrimmed tcsh (its own train)

Needs 10 segments -> 9 `BankList` slots -> the TCB restructure (128-byte stride
or a parallel bank table). Decide then whether bindkey/watch/time/nice/sched/
spell/run-help/prompt-escapes are worth it; none is needed for a login shell.

### D. Smaller items

- Deduplicate the per-bank `fcc_runtime` (25.9 KB at 7 banks / 29.5 KB at 8,
  5.6-6.3%). Partly load-bearing: the guard's near-`JMP _fcc_stkoflow` needs the
  handler in the guarded function's own bank.
- Reclaim `$0800/$2000/$3000` for the stack arena: +10 KB, 28 -> 38 KB
  (architecture-redesign.md's own note, "when NPROC pressure appears").
- On-disk compression: probably a wash (SmartPort read vs LZW decode at
  2.8 MHz), unmeasured, lowest priority.

---

## Closed questions

- **Cheaper LIBC representation to free a code bank?** No. The libc-last +
  cap-9 rule already harvests the whole benefit (libc never uses a `BankList`
  slot); removing its FILE segment would need a new header field for the share
  key currently carried in its segtab entry (include/loader.s:80-87).
- **Trim further to reach 6 banks?** No. Measured ~104 KB more, into globbing,
  expression evaluation, history and the editor.
