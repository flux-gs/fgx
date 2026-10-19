# Console Phase 0 — scroll coalescing implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: implement task-by-task with
> `superpowers:executing-plans` (inline). **Do NOT use subagent-driven execution
> for this plan** — FGX Merlin32/asm work is unreliable under subagents
> (`feedback_fgx_subagents_unreliable`); the main agent executes inline. Steps use
> checkbox (`- [ ]`) syntax.

**Goal:** Eliminate the SHR console "scroll storm" — bound any single `SYS_WRITE`'s
render cost by deferring pixel work to the write boundary and flushing once.

**Architecture:** A 3-state DP flag (`_conRenderState`) makes the render entries and
the scroll `MVN` self-defer during a console write once a scroll occurs; the write
boundary (`@sw_console`/`@swc_done`) flushes with one `Con_RenderAll`. Non-scrolling
writes never defer (zero interactive regression). This is Phase 0 of the
scanline-framebuffer console (spec:
`docs/history/plans/2026-06-30-scanline-framebuffer-console-design.md`).

**Tech Stack:** 65816 asm (Merlin32) for the kernel/console; the headless MAME
harness (`tools/mame_test/run.py`) for closed-loop verification.

## Execution notes / deviations (2026-06-30)

Three deviations from the tasks as first written, decided during execution:

1. **No `conbench` / no `sys_ticks16` libc binding.** A `time` tool already ships
   (`src/userland/time/`, hand-asm), and `time cat <tallfile>` is exactly how the
   scroll cost was measured before (`feedback_time_ls_slowdown_is_scroll_cost`). A
   new C bench would have needed a `SYS_TICKS` libc binding in **both** dual-copy
   libc trees — and `toolchain/lib/` is a submodule, so that drags a toolchain
   release into a bench tool. Dropped it; measure with a `time cat` probe
   (`tools/mame_test/tests/console_scrollbench.json`) instead. Phase 0 stays purely
   FGX-side.
2. **Defer scroll-UP only.** `Con_ScrollRegionDown` has no `_conTopRow` ring
   advance, so its CharBuf is not ring-coherent; deferring it would make the
   `Con_RenderAll` flush repaint stale content. Scroll-down (rare — bulk output
   never reverse-indexes) stays on the immediate path. Only `Con_ScrollRegionUp`'s
   full-screen path defers. (The Phase 2 band model fixes scroll-down coherence.)
3. **FGX2 C tools need only their `.c`** (seg link files are generated from
   `tools/fgx2/*.in`) — moot now that conbench is dropped, but noted.

**Baseline measured:** `time cat /usr/man/cat1/GREP.1` (198 lines, screen full) =
**4.466 real** (emulated seconds) on the pre-coalescing kernel. After-number + ratio
recorded at Task 7.

## Global Constraints

- **Branch:** all work on `feat/scanline-fb-console`; never commit to `main`. Land
  later via merge→main + `./release.sh` (toolchain first if the toolchain changed).
- **Stage specific files** for every commit (pathspecs, not `git add -A`); leave
  untracked files that aren't ours (`src/userland/tput/tput.s`, `tools/fcc-repro/`,
  `tools/fgx2heap/`, `tools/mame_test/kprobe.py`, etc.) alone.
- **Closed-loop testing is headless:** `./build.sh disk && python3 tools/mame_test/run.py --headless --no-state <names…>`
  (or `--group fast`). Verify console output via the CharBuf region (`$03:0000`) /
  framebuffer (`$01:2000`) — headless MAME does not display SHR.
- **MX discipline:** the console runs `MX %00` (16-bit A/X) except the VT parser
  (`Con_Write`, `MX %10`). Byte reads of `_conRenderState` ($C5) in M=0 must mask
  (`AND #$00FF`) since a 16-bit `LDA $C5` also pulls `$C6` (`_conBufRows` low).
- **Toolchain-first:** the `SYS_TICKS` C binding is a libc addition (userland
  `src/userland/lib/libc.s` + mirror `toolchain/lib/libc.s`), not a per-tool stub.
- **New tools in C** (`feedback_all_new_tools_in_fcc_no_hand_asm`): `conbench` is C.
- **Commit trailer** on every commit:

---

### Task 1: SYS_TICKS libc binding + `conbench` measurement tool

Build the measurement instrument first, so baseline (Task 2) uses the *same* binary
as after (Task 7). No kernel behavior change here.

**Files:**
- Modify: `src/userland/lib/libc_data.s` (add `_ticksScratch DS 4`)
- Modify: `src/userland/lib/libc.s` (add `sys_ticks16` wrapper)
- Modify: `toolchain/lib/libc.s` + `toolchain/lib/libc_data.s` (mirror, per the
  dual-copy discipline — verify whether the C-tool link path PUTs the userland or
  toolchain copy; `clear.link.s` PUTs `../lib/libc.s` = userland, so the userland
  copy is authoritative for tools; mirror the toolchain copy for parity)
- Create: `src/userland/conbench/conbench.c`
- Create: `src/userland/conbench/conbench.link.s` (model on `src/userland/clear/clear.link.s`)
- Modify: the userbin build list so `conbench` is built + staged (grep `build_userbin_fgx2_c` callers in `lib/build_common.sh` / `build.sh`; add `conbench` alongside e.g. `clear`)
- Create: `tools/mame_test/tests/conbench.json`

**Interfaces:**
- Produces: `unsigned sys_ticks16(void)` — returns the low 16 bits of the 60 Hz
  kernel tick counter (`SYS_TICKS` = 52). 16 bits = ~18 min at 60 Hz, ample for the
  bench. Consumed by `conbench.c` and any future console-perf tool.

- [ ] **Step 1: Add the libc scratch + wrapper**

In `src/userland/lib/libc_data.s`, add near the other libc scratch:
```
_ticksScratch   DS      4               ; SYS_TICKS 4-byte snapshot buffer
```
In `src/userland/lib/libc.s`, near `getpid` (C-callable syscall wrappers), add
(`SYS_TICKS` EQU may need adding — it's 52; check `include/loader.s` is PUT or add a
local `SYS_TICKS_NUM EQU 52`):
```
;------------------------------------------------------------------------------
; sys_ticks16 - low 16 bits of the 60 Hz kernel tick counter (SYS_TICKS=52).
; SYS_TICKS fills a 4-byte caller buffer; we point it at the libc-internal
; _ticksScratch (data bank == caller bank) and return the low word in A, so C
; callers avoid the caller-buffer-bank gotcha (feedback_libc_buffer_must_be_data_bank).
;------------------------------------------------------------------------------
sys_ticks16     MX      %00
                LDA     #_ticksScratch
                JSL     SYS_TRAMP
                DFB     SYS_TICKS_NUM
                LDA     _ticksScratch           ; low 16 bits of the 32-bit count
                RTS
```
Mirror both additions into `toolchain/lib/libc.s` / `toolchain/lib/libc_data.s`.

- [ ] **Step 2: Write `conbench.c`**

```c
/* conbench.c - SHR console scroll/render microbench.
 * Fills the screen so the cursor sits at the bottom, then times a single
 * many-newline write() (the scroll-storm path) via the 60 Hz tick counter.
 * Prints "conbench: N ticks" (60 Hz; N*16.67ms). Keeper diagnostic. */
#include <stdio.h>

unsigned sys_ticks16(void);          /* libc: low 16 bits of SYS_TICKS */
int write(int fd, char *buf, int n); /* libc */

#define LINES 50
static char page[LINES * 41];        /* 40 dots + '\n' per line */

int main(int argc, char **argv)
{
	int i, j, k;
	unsigned t0, t1;

	/* Fill + scroll to the bottom so follow-scroll is armed. */
	for (i = 0; i < 30; i++)
		write(1, "\n", 1);

	/* Build one buffer of LINES lines. */
	k = 0;
	for (i = 0; i < LINES; i++) {
		for (j = 0; j < 40; j++)
			page[k++] = '.';
		page[k++] = '\n';
	}

	t0 = sys_ticks16();
	write(1, page, k);               /* the scroll-storm write */
	t1 = sys_ticks16();

	printf("conbench: %u ticks\n", (unsigned)(t1 - t0));
	return 0;
}
```
Write `conbench.link.s` by copying `clear/clear.link.s` and renaming (it needs no
custom syscall stubs — `write`, `printf`, `sys_ticks16` are all libc).

- [ ] **Step 3: Wire the build + a headless test**

Add `conbench` to the FGX2 C userbin build+stage list (same place `clear` is listed
in `lib/build_common.sh` / `build.sh`). Create `tools/mame_test/tests/conbench.json`:
```json
{
  "name": "conbench",
  "description": "SHR console scroll/render microbench: conbench fills the screen then times one 50-line write() via SYS_TICKS. Prints 'conbench: N ticks' (60 Hz). Measures the scroll path; used for Phase 0 before/after. Non-gating (timing varies by host); asserts only a clean run + that it printed a tick count.",
  "command": "conbench",
  "timeout_s": 90,
  "expect": {
    "registers": {"DB_hex": "KERNEL"},
    "screen_contains": ["conbench:", "ticks"]
  }
}
```

- [ ] **Step 4: Build + verify it runs**

Run: `./build.sh disk && python3 tools/mame_test/run.py --headless --no-state conbench`
Expected: PASS; the captured screen shows `conbench: <N> ticks`. (On the *baseline*
kernel N will be large — that's Task 2. Here we only confirm it builds and runs.)

- [ ] **Step 5: Commit**

```bash
git add src/userland/lib/libc.s src/userland/lib/libc_data.s \
        toolchain/lib/libc.s toolchain/lib/libc_data.s \
        src/userland/conbench/conbench.c src/userland/conbench/conbench.link.s \
        lib/build_common.sh tools/mame_test/tests/conbench.json
git commit -m "test(console): SYS_TICKS libc binding + conbench scroll microbench

sys_ticks16() exposes the 60Hz kernel tick counter (SYS_TICKS=52) to C via a
libc-internal scratch buffer. conbench fills the screen then times one 50-line
write() — the scroll path — for Phase 0 before/after measurement.

```

---

### Task 2: Record the BASELINE measurement

**Files:** none (measurement only; the kernel is still unmodified here).

- [ ] **Step 1: Run conbench on the unmodified kernel**

Run: `./build.sh disk && python3 tools/mame_test/run.py --headless --no-state conbench`
Capture the printed `conbench: N ticks`.

- [ ] **Step 2: Record the number**

Note the baseline tick count in the Task 7 comparison (expected: large — ~50 scrolls
× ~100 ms ≈ ~5 s ≈ ~300 ticks). This is the number Phase 0 must slash. No commit.

---

### Task 3: Declare + initialize the `_conRenderState` DP flag

**Files:**
- Modify: `include/dpmap.s` (name the `$C5` pad)
- Modify: `src/drivers/console/console_init.s` (zero it in `Con_Init`)

**Interfaces:**
- Produces: `_conRenderState` (DP byte at `$C5`): `0` = immediate (default / kernel-
  direct callers), `1` = batching, no scroll yet, `2` = batching, deferred.

- [ ] **Step 1: Name the pad**

In `include/dpmap.s`, replace the `$C5` pad line:
```
_conFollow      DS      1                   ; $C4
                DS      1                   ; $C5 pad
```
with:
```
_conFollow      DS      1                   ; $C4
_conRenderState DS      1                   ; $C5  0=immediate 1=batch 2=deferred (Phase 0 scroll coalesce)
```

- [ ] **Step 2: Zero it at console init**

In `src/drivers/console/console_init.s` `Con_Init` (near where other console DP is
initialized, e.g. the `_conFollow`/`_conTopRow` stores around line 128–133), add:
```
                STZ     _conRenderState         ; start immediate (kernel-direct writes)
```
Match the surrounding MX state (M=0; `STZ` on a byte address writes 16 bits at
`$C5`/`$C6` — do it BEFORE `_conBufRows`/`_conTopRow` are set, or use `SEP #$20`/`STZ`/
`REP #$20` to avoid clobbering `$C6`). Simplest: place it in an M=1 window or guard
with SEP/REP.

- [ ] **Step 3: Build + boot smoke (inert change)**

Run: `./build.sh disk && python3 tools/mame_test/run.py --headless --no-state shell_smoke shr_framebuffer`
Expected: PASS (nothing sets state to 1/2 yet; behavior unchanged).

- [ ] **Step 4: Commit**

```bash
git add include/dpmap.s src/drivers/console/console_init.s
git commit -m "feat(console): add _conRenderState defer flag (Phase 0, inert)

```

---

### Task 4: Guard the render entries (deferral consumers)

Make `_Con_RenderCell` and `Con_RenderRow` no-ops when `_conRenderState == 2`. Because
every render call site (`Con_PutChar`'s per-cell `JSR`, the scroll tail's
`JMP Con_RenderRow`, `ESC[2J`'s `JMP Con_RenderAll` → its RenderRow loop) flows
through these two entries, no call-site edits are needed. Still inert (state never 2
until Task 6).

**Files:**
- Modify: `src/drivers/console/console_render.s` (`Con_RenderRow` entry ~line 31;
  `_Con_RenderCell` entry ~line 276)

**Interfaces:**
- Consumes: `_conRenderState` (Task 3).

- [ ] **Step 1: Guard `Con_RenderRow`**

At `Con_RenderRow` (currently `PHA` first, MX %00), insert before the `PHA`:
```
Con_RenderRow
                LDA     _conRenderState         ; M=0: low byte = state, mask off $C6
                AND     #$00FF
                CMP     #$0002
                BNE     @crr_go
                RTS                             ; deferred: skip pixel work
@crr_go         PHA
                ...                             ; (existing body unchanged)
```

- [ ] **Step 2: Guard `_Con_RenderCell`**

At `_Con_RenderCell` (currently `PHA` save vpRow first), insert the same guard before
the first `PHA`:
```
_Con_RenderCell
                LDA     _conRenderState
                AND     #$00FF
                CMP     #$0002
                BNE     @rc_go
                RTS
@rc_go          PHA                             ; (existing body unchanged)
```
(Adjust the local label name if `@rc_go`/`@crr_go` collide with existing labels.)

- [ ] **Step 3: Build + verify inert**

Run: `./build.sh disk && python3 tools/mame_test/run.py --headless --no-state shr_framebuffer font_default_revert cat_hello`
Expected: PASS (state is never 2 yet; renders happen as before).

- [ ] **Step 4: Commit**

```bash
git add src/drivers/console/console_render.s
git commit -m "feat(console): defer-guard Con_RenderRow/_Con_RenderCell (Phase 0)

```

---

### Task 5: Deferral trigger in the full-screen scroll

On a full-screen scroll during a batch (`_conRenderState ≥ 1`), engage deferral
(set state = 2) and **skip the pixel `MVN`**, keeping the `_conTopRow` ring-advance and
the CharBuf row-clear so the logical model stays coherent. Partial DECSTBM regions
(unused today) stay on the immediate path.

**Files:**
- Modify: `src/drivers/console/console_scroll.s` (`Con_ScrollRegionUp` full-screen
  path; `Con_ScrollRegionDown` mirror)

**Interfaces:**
- Consumes: `_conRenderState`. Produces: state transition `1 → 2` on first full-screen
  scroll; deferred-scroll semantics (topRow/CharBuf updated, pixels not moved).

- [ ] **Step 1: Add the defer branch to `Con_ScrollRegionUp`**

The full-screen ring-advance already runs at the top (the `SR_TOP==0 && SR_BOT==VisRowsM1`
block, ~lines 53–66). Immediately AFTER `@sru_skipRingAdvance` sets `_conTmp0=top`,
`_conTmp1=bot` (lines 67–70), and only when this scroll is full-screen, insert a defer
check that skips the `MVN` computation and jumps to the CharBuf-clear tail
(`@sru` clear/re-render at ~line 126). Concretely, gate on state and on full-screen
(reuse the top/bot == 0/VisRowsM1 test), e.g. after `_conTmp1` is set:
```
                ; Phase 0: during a batch, first full-screen scroll engages deferral.
                SEP     #$20
                LDA     _conRenderState
                CMP     #1
                BCC     @sru_immediate          ; state 0 → immediate MVN (kernel-direct)
                LDA     #2
                STA     _conRenderState         ; engage/stay deferred
                REP     #$20
                ; skip the pixel MVN; keep CharBuf coherent + let RenderRow self-skip
                LDA     _conTmp1
                AND     #$00FF
                JSR     _Con_LogicalRowFromVp
                JSR     _Con_ClearRingRow
                LDA     _conTmp1
                AND     #$00FF
                JSR     _Vt_FillAttrRow_At
                LDA     _conTmp1
                AND     #$00FF
                JMP     Con_RenderRow           ; self-skips at state 2 (Task 4)
@sru_immediate  REP     #$20
                ; (fall through to the existing MVN path unchanged)
```
Only apply this within the full-screen case. If the ring-advance branch structure
makes "are we full-screen here?" ambiguous at this point, compute a 1-byte
`deferrable` marker in the full-screen block (lines 53–66: set it to 1; else 0) and
test it alongside `_conRenderState` here. Verify against Merlin32 at build.

- [ ] **Step 2: Mirror in `Con_ScrollRegionDown`**

Apply the same defer branch to the full-screen `Con_ScrollRegionDown` path (revealed
row = `top`, not `bot`): on `_conRenderState ≥ 1`, set state 2, skip the `MVP`, do the
`_Con_LogicalRowFromVp`/`_Con_ClearRingRow`/`_Vt_FillAttrRow_At` for `_conTmp0` (top),
`JMP Con_RenderRow`.

- [ ] **Step 3: Build + verify still inert (no batch boundary yet)**

Run: `./build.sh disk && python3 tools/mame_test/run.py --headless --no-state shell_smoke cat_hello clear_test`
Expected: PASS. State is only ever ≥1 once Task 6 sets it at the write boundary; until
then scrolls see state 0 → immediate `MVN` → unchanged behavior.

- [ ] **Step 4: Commit**

```bash
git add src/drivers/console/console_scroll.s
git commit -m "feat(console): full-screen scroll engages defer + skips MVN (Phase 0)

```

---

### Task 6: Batch boundary — activate coalescing

Set `_conRenderState = 1` at the start of a console `SYS_WRITE` and flush at the end.
This is where the feature turns on.

**Files:**
- Modify: `src/kernel/syscall.s` (`@sw_console` ~line 1068–1072; `@swc_done` ~line 1113)

**Interfaces:**
- Consumes: `_conRenderState`, `Con_RenderAll`, `Con_HideCursor`, `Con_ShowCursor`.

- [ ] **Step 1: Arm the batch at `@sw_console`**

After the existing `JSR Con_HideCursor` (line 1072), add:
```
                SEP     #$20
                LDA     #1
                STA     _conRenderState         ; batching; scroll may escalate to 2
                REP     #$20
```

- [ ] **Step 2: Flush at `@swc_done`**

Replace the `@swc_done` body (currently `JSR Con_ShowCursor` / `BRA @sw_done`):
```
@swc_done       SEP     #$20
                LDA     _conRenderState
                STZ     _conRenderState         ; back to immediate for the flush + future
                REP     #$20
                AND     #$00FF
                CMP     #$0002
                BNE     @swc_show               ; no scroll happened → nothing deferred
                JSR     Con_RenderAll           ; one repaint from the final CharBuf
@swc_show       JSR     Con_ShowCursor          ; AFTER RenderAll so the cursor survives
                BRA     @sw_done
```
(`STZ _conRenderState` before `Con_RenderAll` is essential — the Task 4 guard would
otherwise make `Con_RenderAll` a no-op.)

- [ ] **Step 3: Build + correctness (feature ON)**

Run: `./build.sh disk && python3 tools/mame_test/run.py --headless --no-state cat_hello cat_files clear_test shr_framebuffer shell_smoke ls_root_only ls_to_devnull dmesg_ring`
Expected: PASS — final screen content byte-identical to before (the flush repaints the
same final CharBuf). If `shr_framebuffer`'s hash trips, inspect: a correct flush
produces identical row-0 pixels; a mismatch means the flush ordering or a guard is
wrong.

- [ ] **Step 4: Commit**

```bash
git add src/kernel/syscall.s
git commit -m "feat(console): coalesce scrolls at the SYS_WRITE boundary (Phase 0)

@sw_console arms _conRenderState=1; the first full-screen scroll escalates to 2
(defer pixels); @swc_done flushes one Con_RenderAll then ShowCursor. Bounds any
write to ~one repaint instead of N per-newline MVNs. Non-scrolling writes never
defer, so interactive typing is unchanged.

```

---

### Task 7: Record the AFTER measurement + report the win

**Files:** none.

- [ ] **Step 1: Run conbench on the coalesced kernel**

Run: `./build.sh disk && python3 tools/mame_test/run.py --headless --no-state conbench`
Capture `conbench: N ticks`.

- [ ] **Step 2: Compute + report the ratio**

Compare to Task 2's baseline. Expected: baseline ~hundreds of ticks (≈ LINES × ~6
ticks/scroll), after ~single-digit ticks (one `Con_RenderAll`). Report
`baseline / after` (target ≥ ~15×). If the ratio is < 5×, STOP and investigate
(systematic-debugging): confirm deferral engaged (state reached 2) and the flush ran
once — the `conbench` write must actually scroll (screen full at t0).

---

### Task 8: Tall-`cat` correctness test + full fast-group gate

Prove deferral never corrupts final content, and lock it against regression.

**Files:**
- Create: `tools/mame_test/tests/console_tallcat.json`
- Modify: `tools/mame_test/groups/fast.txt` (add `console_tallcat`)

- [ ] **Step 1: Write the correctness test**

`/usr/man/cat1/GREP.1` is 198 lines (well over 25). Its last content line ends the
grep man page; pick a stable substring from the file's tail to assert. Confirm the
exact tail substring first: `tail -3 disk_src/usr/man/cat1/GREP.1`.
```json
{
  "name": "console_tallcat",
  "description": "Phase 0 scroll-coalescing correctness: cat a 198-line file (well past the 25-row screen) so the write scrolls many times and the coalesced flush repaints once. Asserts the final screen shows the FILE TAIL (deferral produced the correct final CharBuf) + a returned prompt. Guards against a flush that drops/duplicates/mis-orders rows.",
  "command": "cat /usr/man/cat1/GREP.1",
  "timeout_s": 60,
  "expect": {
    "registers": {"DB_hex": "KERNEL"},
    "screen_contains": ["<STABLE-TAIL-SUBSTRING-FROM-GREP.1>", "fgx:/root/#"],
    "screen_lacks": ["PANIC"]
  }
}
```
Replace `<STABLE-TAIL-SUBSTRING-FROM-GREP.1>` with the verified tail substring.

- [ ] **Step 2: Run the new test**

Run: `./build.sh disk && python3 tools/mame_test/run.py --headless --no-state console_tallcat`
Expected: PASS (final visible rows = the file tail; prompt returned).

- [ ] **Step 3: Add to the fast group + full gate**

Append `console_tallcat` to `tools/mame_test/groups/fast.txt`. Then run the whole
fast group:
Run: `python3 tools/mame_test/run.py --headless --no-state --group fast`
Expected: 0 failures (Phase 0 leaves every content assertion intact).

- [ ] **Step 4: Commit**

```bash
git add tools/mame_test/tests/console_tallcat.json tools/mame_test/groups/fast.txt
git commit -m "test(console): tall-cat scroll-coalescing correctness + fast-group gate

```

---

## Self-review

**Spec coverage (§6 of the design):** _conRenderState 3-state at $C5 (T3) ✓; guard
the three render entries so all call sites auto-defer (T4 — RenderAll inherits via its
RenderRow loop) ✓; guard the scroll MVN, keep ring-advance + CharBuf clear (T5) ✓;
@sw_console arms state=1 / @swc_done flush-then-ShowCursor with state cleared before
RenderAll (T6) ✓; DECSTBM partial regions stay immediate (T5 gates on full-screen) ✓;
measured before/after via SYS_TICKS (T1/T2/T7) ✓; final content byte-identical, fast
group green, tall-cat test (T6/T8) ✓. No §6 requirement is unimplemented.

**Placeholder scan:** one intentional fill-in — `<STABLE-TAIL-SUBSTRING-FROM-GREP.1>`
in T8 Step 1, resolved by the `tail -3` command in the same step. No other TBDs.

**Type/label consistency:** `_conRenderState` (byte, $C5) used identically in T3–T6;
`sys_ticks16`/`_ticksScratch` consistent T1↔conbench; guard local labels flagged for
collision-check against existing `@crr_*`/`@rc_*` in console_render.s.

**Ordering guarantee:** T3→T4→T5 are each inert (state never reaches 2 until T6 arms
it), so every intermediate commit builds and boots green; T6 activates the feature;
T2 (baseline) precedes T6, T7 (after) follows it, both using the T1 binary.
