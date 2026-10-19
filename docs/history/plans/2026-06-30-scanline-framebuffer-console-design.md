# Scanline-native framebuffer console — design spec

- **Status:** approved (design); implementation phased (see §7). Phase 0 is the immediate ship.
- **Date:** 2026-06-30
- **Branch:** `feat/scanline-fb-console`
- **Author:** flux (with Claude Opus 4.8)
- **Supersedes/relates:** the char-grid console driver in `src/drivers/console/*.s`; the
  "kernel console large-write hang" hypothesis (disproven 2026-05-31); the SHR
  scroll/render perf notes (`feedback_shr_scroll_perf`, `feedback_charbuf_render_perf`,
  `feedback_time_ls_slowdown_is_scroll_cost`).
- **Provenance:** dual-recorded in the project notes (`fgx` group) and the file ledger
  (`(project notes)`).

---

## 1. Summary

Re-architect the FGX SHR console from a **character-grid** driver into a
**scanline-native framebuffer** that treats scrolling, buffering, damage, and
compositing by *scanline* rather than by character row. This delivers the
project's original goal — a mixed graphics/text framebuffer in the spirit of a
Tektronix terminal, where text and graphics coexist on one screen — while fixing
the immediate performance problem (a per-newline scroll storm) as a no-regret
first step.

The work is phased so each phase ships value independently:

| Phase | Deliverable | Value | Impl |
|------|-------------|-------|------|
| **0** | Scroll coalescing on today's driver | Kills the "hang"; ~17× on `cat`/editor repaints | asm |
| **1** | Scanline FB core (addressing, damage, flush) | The substrate 2–4 build on; damage-optimal flush | asm |
| **2** | Bands + per-scanline SCB manager | Split-screen text/graphics regions | asm |
| **3** | Graphics layer (plot/blit, `/dev/fb`, escapes) | Inline graphics + full-screen handoff | asm + C |
| **4** | C-conversion of control logic | Maintainable driver; keeps asm blit leaves | C |

Phases 0 and 1 are specified in detail here. Phases 2–4 are a roadmap to be
specced as we reach them.

---

## 2. Motivation & findings

### 2.1 The "hang" is a scroll storm, not a hang

The reported "SHR console hangs on large writes" is **not** a kernel bug. The
large-write hang was disproven on 2026-05-31 (a single `SYS_WRITE` up to 1099 B
completes cleanly; the original symptom was the pre-`77bac44` far-call/DBR bug
feeding garbage to the VT parser). The current write path (`syscall.s`
`@sw_console` / `@swc_L`) is 16-bit clean.

The real cost is **rendering under scroll**:

- `Con_PutChar` → `Con_LineFeed` → `_Con_RowAdvance`: when the cursor sits at
  `VT_SR_BOT` with follow enabled, **every LF calls `Con_ScrollRegionUp`, which
  performs a full ~100 ms 30 KB SHR pixel `MVN`** (bank $01→$01, shadowed to $E1).
- A `cat` of a tall file (or an editor's full-screen repaint) with the screen
  full = N newlines × ~100 ms = a multi-second stall. That reads as a "hang."
- The good optimizations are already landed: the O(1) ring-buffer `_conTopRow`
  advance, the `PreExpFont` unrolled renderer (~6 ms/row), and fast per-cell
  typing render (~150 cyc). What is missing is that **pixel work happens
  per-character instead of once per write.**

Measured baselines (from prior POC work, `feedback_shr_scroll_perf` /
`feedback_charbuf_render_perf`): full-screen 1-row scroll via `MVN` ≈ 100–110 ms;
optimized per-row render ≈ 6 ms; a naive full-viewport repaint ≈ 400 ms
(~150 ms with the landed `PreExpFont` path). There is **no hardware scroll
register** on SHR, so scroll is always a pixel move; the only structural win is
to stop doing it per character.

### 2.2 The original goal: mixed graphics/text (Tektronix-style)

FGX's console was always intended to become a mixed-mode graphics/text
framebuffer. The SHR hardware is *natively scanline-oriented*, which makes this
the hardware-true direction (see §4). The char-grid model is an abstraction on
top of a scanline machine; peeling it back to scanlines both fixes the perf
problem structurally and unlocks the mixed-mode goal.

---

## 3. Goals & non-goals

### Goals
- Eliminate the per-newline scroll storm; bound any single write's render cost.
- Make the scanline framebuffer the addressable source of truth.
- Support, over the phased roadmap: inline graphics in the text stream,
  split-screen text/graphics regions, and full-screen framebuffer handoff.
- Keep text scrollback cheap (character-backed, 80 B/row — not 1280 B/row).
- Preserve interactive typing latency (no regression on per-keystroke echo).
- Establish an asm-leaf / C-control boundary so the driver can migrate to C
  without sacrificing the hot pixel loops.

### Non-goals (this spec)
- Smooth (sub-8-scanline) pixel scrolling — enabled by the substrate but not a
  deliverable here.
- Graphics scrollback / pixel history — opt-in, deferred to Phase 3 when asked.
- Rewriting the hot glyph-blit or `MVN` in C — those stay asm indefinitely.
- Partial-region (DECSTBM) correctness under the ring model — unused today;
  fixed properly by the Phase 2 band model.

---

## 4. Hardware grounding (SHR)

Confirmed against FGX's own `src/drivers/console/console_init.s` (`_Con_InitSCBs`)
and the IIgs SHR model:

- **Framebuffer:** bank `$E1` `$2000`–`$9CFF` = **200 scanlines × 160 bytes**.
  FGX writes bank `$01` `$2000` (shadowed to `$E1`) for speed. Scanline *s* is
  always at offset `s × 160`; there is no start-line/scroll register.
- **SCBs (Scanline Control Bytes):** bank `$E1` `$9D00`–`$9DC7` = **one byte per
  scanline** (200 total). Bit 7 = 640 (1) / 320 (0) mode; bit 6 = scanline IRQ;
  bit 5 = fill mode (320); bits 3–0 = palette (one of 16). FGX writes these at
  `$019D00` in `_Con_InitSCBs`, whose comment already anticipates *"per-row
  palette switching can later rewrite individual SCBs."*
- **Palettes:** bank `$E1` `$9E00`–`$9FFF` = 16 palettes × 16 colors × 2 bytes.
- **Mixed mode is a hardware primitive:** because each scanline's SCB
  independently selects mode + palette, a band of scanlines can be 640-mono text
  while another is 320-color graphics, with **zero software compositing**. This
  is the basis of the band model (§7, Phase 2).
- **Text metrics:** 640 mode → 80 cols × 25 rows, each cell 8 px wide (2 bytes) ×
  8 scanlines tall, one 16-bit word per scanline (the `PreExpFont` blit). 320
  mode → 40 cols. Column count is therefore a per-band property once bands exist.

---

## 5. Architecture

Three layers, plus the parser that drives them.

### 5.1 FB core (asm leaves, scanline-addressed) — the truth
Owns the SHR pixels, the 200 SCBs, and the palettes. All coordinates are
scanlines. Primitives (all leaf-callable, later from C):

- `Fb_ScrollUp(top_sl, height_sl, n_sl)` — `MVN` the band `[top_sl, top_sl+height)`
  up by `n_sl` scanlines (move `(height − n) × 160` bytes). Today's full-screen
  char-row scroll becomes `Fb_ScrollUp(0, 200, 8)`.
- `Fb_ScrollDown(top_sl, height_sl, n_sl)` — `MVP` variant.
- `Fb_FillScanlines(top_sl, n_sl, wordval)` — fill `n_sl` scanlines (row clear).
- `Fb_SetScbBand(top_sl, n_sl, scb)` — set SCBs for a scanline band
  (generalizes `_Con_InitSCBs`).
- The existing `PreExpFont` glyph blit (already a 1-char × 8-scanline write) is
  re-cast as the **text blit leaf** — unchanged hot code.

### 5.2 Text layer (cache-backed client)
Keeps the CharBuf/AttrBuf/FGBUF/BGBUF ring (bank `$03`, 100 rows × 80 — cheap
deep scrollback), the cursor, and the VT100/102 parser. A **text region is a band
of scanlines** whose pixels are rendered *from* CharBuf on demand. Text scroll =
`Fb_ScrollUp` of that band's scanlines + re-render of the exposed row(s). The
ring `_conTopRow` advance stays as the O(1) logical scroll.

### 5.3 Compositor / band map (Phase 2+)
The screen is a stack of typed **bands**: `[top_sl, bot_sl) → {type: text|graphics,
mode, palette}`. Bands composite for free via per-scanline SCBs. The compositor
routes scroll/damage/flush to the owning layer and manages SCBs per band. Phase 0
and 1 have a single implicit full-screen text band; the band table is introduced
in Phase 2.

### 5.4 asm-leaf / C-control boundary (Phase 4)
- **C owns control:** VT parser/state machine, band/compositor logic, damage &
  scroll bookkeeping, escape/ioctl dispatch.
- **asm keeps the leaves:** glyph blit, scroll `MVN`/`MVP`, fill, SCB/palette
  pokes.

This is how "convert the driver to C" happens safely — the ~1,760 lines of
parser/compositor logic (`console_vt.s`, `console_vthandler.s`, scroll/char
bookkeeping) become maintainable C; the ~200 lines of pixel-blast stay asm and
are called as leaf functions.

---

## 6. Phase 0 — scroll coalescing (ship now)

**Goal:** bound any single write's render cost; zero interactive regression.
**Approach:** defer pixel work during a console `SYS_WRITE` and flush once at the
write boundary. The write path is already bracketed
`Con_HideCursor … @swc_L loop … Con_ShowCursor` (`syscall.s:1072`/`1113`).

### 6.1 State
One 3-state byte `_conRenderState` at the free DP pad `$C5` (currently
`DS 1 ; $C5 pad`, immediately after `_conFollow` at `$C4`):
- `0` — not batching → **immediate** render (today's behavior; also the state for
  kernel-direct `Con_Write` callers such as boot/dmesg).
- `1` — batching, no scroll yet → still immediate (so short/non-scrolling writes
  keep per-cell latency).
- `2` — batching, deferred → skip pixel work; a flush is owed.

### 6.2 Control flow
1. `@sw_console`, after `Con_HideCursor`: set `_conRenderState = 1`.
2. Guard the three render entries to early-`RTS` when `_conRenderState == 2`:
   `_Con_RenderCell`, `Con_RenderRow`, and (inheriting via its RenderRow loop)
   `Con_RenderAll`. Because *every* render call site flows through these entries —
   `Con_PutChar`'s per-cell `JSR`, the scroll tail's `JMP Con_RenderRow`, and
   `ESC[2J`'s `JMP Con_RenderAll` — **no call-site edits are needed**; they all
   auto-defer.
3. Guard the pixel `MVN` in `Con_ScrollRegionUp` / `Con_ScrollRegionDown`: if
   `_conRenderState ≥ 1`, set it to `2` and **skip the `MVN`**, keeping the
   `_conTopRow` ring-advance and the CharBuf row-clear (the logical model stays
   coherent). If `_conRenderState == 0` (kernel-direct), do the `MVN` as today.
4. `@swc_done`: if `_conRenderState == 2`, set it to `0` then call `Con_RenderAll`
   (one ~150 ms repaint) **before** `Con_ShowCursor`; else just `Con_ShowCursor`
   (today's path). Ordering matters — the full repaint must precede the cursor
   paint so the cursor cell isn't overwritten.

### 6.3 Properties
- Non-scrolling / interactive writes never reach state `2` → per-cell render is
  immediate → **no regression**.
- Any scrolling write costs ~150 ms flat instead of N × 100 ms → **~17× on a
  full-screen `cat`**; unbounded → bounded.
- Correctness: the final CharBuf state fully determines the screen, and
  `Con_RenderAll` paints it — final content is byte-identical to today.
- DECSTBM partial-region scroll stays on the immediate path (deferral engages
  only on the full-screen, ring-coherent scroll). Unused today; fixed in Phase 2.
- Reentrancy: console writes run to completion within a syscall (cooperative MT,
  no mid-write preemption of the render), so a single flag is safe.

### 6.4 Files touched
`src/kernel/syscall.s` (`@sw_console`/`@swc_done`), `src/drivers/console/console_render.s`
(guard `_Con_RenderCell`, `Con_RenderRow`), `src/drivers/console/console_scroll.s`
(guard the `MVN` in `Con_ScrollRegionUp/Down`), `include/dpmap.s` (name `$C5`).

---

## 7. Phase 1 — scanline FB core

**Goal:** introduce the scanline-addressed substrate and a damage-optimal flush;
refactor the char-row scroll onto it. No new user-visible capability — this is
the foundation for Phases 2–4, and it turns Phase 0's blanket `RenderAll` flush
into a minimal one.

### 7.1 Scanline addressing
Add `_Con_ScanlineOfs(s) = s × 160` (a 200-entry word table = 400 B, or shift
math: `160 = 128 + 32`). Recast `Con_ScrollRegionUp`'s `MVN` as
`Fb_ScrollUp(0, 200, 8)`; the char-row scroll becomes a thin caller. Keep the
existing `_Con_RowOffsets` (row × 1280) table for the text blit.

### 7.2 Damage model (in scanlines)
During a batch, maintain:
- a signed `_conPendShift` (net scanlines the batch scrolled up; negative =
  down), accumulated by scrolls instead of `MVN`-ing;
- a dirty **row span** `[_conDmgLo, _conDmgHi]` (2 bytes; contiguous damage is the
  norm), widened by cell writes and clears.

### 7.3 Damage-optimal flush (replaces Phase 0's blanket RenderAll)
At the write boundary:
- If `|_conPendShift| ≥ visible height`: nothing on-screen is retained → full
  `Con_RenderAll` (skip a pointless `MVN`).
- Else if `_conPendShift ≠ 0`: **one** `Fb_ScrollUp(0, 200, _conPendShift)` to
  retain the still-visible pixels, then render only the newly-exposed rows + the
  dirty span — not all 25.
- Else (`_conPendShift == 0`): render only the dirty span.

Effect: a 3-row editor update flushes in ~18 ms; a single-scroll `cat` line in
~1 `MVN` + 1 row render; the pathological full-screen scroll storm stays bounded.
Phase 0's correctness fix becomes a special case of this.

### 7.4 Data model additions
`_conPendShift` (signed, 2 B) and `_conDmgLo`/`_conDmgHi` (2 B) in the DP console
region or `CON_VT_STATE`. No new banks; CharBuf/AttrBuf/PreExp layout unchanged.

---

## 8. Roadmap — Phases 2–4 (spec when reached)

- **P2 — Bands + SCB manager.** `Fb_SetScbBand` generalizes `_Con_InitSCBs`; a
  band table types scanline ranges text/graphics with independent mode + palette.
  Unlocks split-screen. Note: a 320 band is 40 cols — text metrics become
  per-band; the parser must consult the active band's geometry.
- **P3 — Graphics layer.** Plot/blit/clear into graphics bands via VT/Tek-style
  escape sequences and/or a `/dev/fb` chardev with an ioctl surface. Unlocks
  inline graphics + full-screen handoff. Graphics scrollback (pixel history) is
  opt-in per band, deferred until requested (memory cost: 1280 B/row).
- **P4 — C-conversion.** Port parser → compositor → bookkeeping to C
  incrementally as each stabilizes, keeping the asm leaves. Overlaps P1–P3. This
  is also a precursor enabler for the elvis editor port (a maintainable,
  table-driven console).

---

## 9. Testing & measurement

**Correctness first (every phase must keep final screen content byte-identical
where behavior is unchanged):**
- The fast-group tests that assert charbuf/framebuffer content must stay green:
  `cat_*`, `clear_test`, `shr_framebuffer`, `font_default_revert`, `ls_*`,
  `dmesg_ring`.
- Add a "tall `cat` + scroll" content test: `cat` a >25-line file with the screen
  full, assert the final visible rows match the file tail (proves deferral
  doesn't corrupt output).
- Headless MAME does not display SHR; verify via the CharBuf region `$03:0000`
  and the framebuffer `$01:2000`, as the harness already does.

**Performance measured, not assumed (FCC-project discipline):**
- Add a `SYS_TICKS` (52) libc binding (a legitimate libc addition, not a per-tool
  stub) and a `conbench` C tool: fill the screen, read ticks, issue a
  many-newline write in one `write()`, read ticks, print the delta. Run before
  (tagged `pre-console-perf`) and after Phase 0; report the ratio.
- 60 Hz tick resolution (16.67 ms) is coarse for one scroll but decisive for the
  aggregate (seconds → ~0.15 s).

---

## 10. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Deferral corrupts output for an untested escape path | `Con_RenderAll` from the final CharBuf is the source of truth; content-assert tests + a tall-cat test. |
| DECSTBM partial-region scroll incoherent under the ring | Phase 0 leaves it on the immediate path (unused today); Phase 2 band model fixes it. |
| Cursor cell overwritten by the flush | Flush order: `RenderAll` then `Con_ShowCursor`. |
| `$C5`/DP collision | `$C5` is an existing unused pad after `_conFollow`; `_conFg` is 8-bit-only so its `$CD` pad is also free if a 2nd byte is needed. |
| C-converted control loop too slow | Only *control* moves to C; the hot glyph-blit/`MVN`/fill stay asm leaves; measure at Phase 4. |
| Headless timing unrepresentative | Ticks count *emulated* VBLs; the scroll `MVN` is a fixed emulated-cycle cost → representative of real hardware. |

---

## 11. Alternatives considered

- **B — Pure pixel framebuffer (Linux-fbcon style):** everything is pixels, no
  char backing. Uniform and simplest, but text scrollback costs 16× RAM
  (128 KB/screen) or is dropped, and reflow/attributes get harder. Rejected: a
  strict subset of A that throws away cheap scrollback.
- **C — Separate text console + independent `/dev/fb`:** keep the char console,
  bolt on a switchable full-screen graphics device (VT↔X style). Simplest, but no
  *simultaneous* text+graphics — no split regions, no inline graphics. Rejected:
  fails the "general/all" goal.
- **A — Scanline compositor with typed bands (chosen):** the only option that
  delivers inline graphics, split regions, and full-screen handoff while keeping
  text scrollback cheap.

Sequencing alternative — "spec all of 0–4 up front" — was rejected in favor of
"spec 0+1 now, roadmap 2–4" so the coalescing win ships without waiting on the
full design.

---

## 12. References

- Code: `src/drivers/console/console_char.s` (Con_PutChar/LineFeed/CR),
  `console_scroll.s` (Con_ScrollRegion*), `console_render.s`
  (Con_RenderRow/All/Cell, PreExpFont), `console_vt.s` / `console_vthandler.s`
  (parser), `console_init.s` (`_Con_InitSCBs`), `src/kernel/syscall.s`
  (`@sw_console`), `include/dpmap.s`, `include/memmap.s`, `include/console.s`.
- Memory: `feedback_kernel_console_large_write_hang` (hang disproven),
  `feedback_shr_scroll_perf`, `feedback_charbuf_render_perf`,
  `feedback_time_ls_slowdown_is_scroll_cost`, `project_fgx_vi_port`,
  `project_video_design`, `reference_video_color_model`.
