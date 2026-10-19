# ntpplay — streamed-sample playback & the "static" investigation

`src/userland/ntpplay/` plays NinjaTracker+ (`.ntp`) modules — the C driver
`ntpplay.c` plus the DOC-IRQ engine in `ntpplay_stubs.s`. (The hand-asm
`ntpplay.s` this doc was written against was retired when the last FGX1 tool
went; every engine symbol named below survived the split.) Samples that
fit in the 64 KB DOC wave RAM are *placed* (uploaded once, played from RAM). Samples
that don't fit are *streamed* (`doc_ptr == 0`): kept resident in an MM pool and fed
to the DOC a little at a time under the sound IRQ. The streaming engine mirrors
NinjaTracker+ (NTP+). This doc records how it works, two real bugs we fixed, and a
detailed post-mortem of the streamed-sample **static** that we could *not* remove in
emulation — including everything ruled out, so a future attempt starts ahead.

Status as of 2026-06-03: **faithful, correct, audible.** Loop + crash bugs fixed.
The residual streamed-sample static is almost certainly an **emulator artifact** of
the NTP+ streaming method (see §5). Tag `ntp-stream-working` marks the good state.

---

## 1. The streaming model (mirrors NTP+)

Each streamed voice uses **two** DOC oscillators:

| Osc | Role | Wave / size reg | Freq | Ctl |
|-----|------|-----------------|------|-----|
| **A** (timer) | drives refill IRQs | `$FF` square wave, `TIMER_PAGE`, size `$00` (256 B, res 0) | note freq | `$08` free-run + IE, vol 0 (silent) |
| **B** (sample)| plays the audio | the voice's stream buffer, size `$09` (512 B, res 1) | note freq | `$00` free-run + channel, vol |

Osc B plays a **512-byte double-buffer** (two 256-byte halves/pages) free-running and
wrapping. Osc A (the timer) free-runs a 256-byte table at the **same note frequency**;
each time it wraps it raises a sound IRQ → `interrupt_stream` refills the 256-byte
half that osc B *just finished* playing (256 B pool → DOC), advances the pool pointer,
toggles which half to refill next, and loops/halts at the sample end.

**Why A and B stay rate-locked.** DOC address step rate ∝ `freq / 2^resshift`, where
`resshift = RES_SHIFTS[res] − wavetblsize` and `RES_SHIFTS = (9,10,11,12,…)` (from
ntpconvert's `doc.py` (the **external** `ntpconvert` repo, not this tree) / `make_tables.php`: `output_freq = SR / 2^(17+RES) · FHL`).
- Timer size `$00` → wavetblsize 0, res 0 → `resshift = 9 − 0 = 9`.
- Sample size `$09` → wavetblsize 1, res 1 → `resshift = 10 − 1 = 9`.

Equal `resshift` ⇒ both advance bytes at the same rate ⇒ A wraps (IRQs) exactly once
per 256 sample-bytes B plays ⇒ the refill always targets the half B is *not* reading.
The res difference is intentional and **correct** — verified against the authoritative
`doc.py` model. (Beware: an earlier "they drift" hypothesis was wrong; they don't.)

Key code: `trigger_stream` (set up + initial 512 B fill), `interrupt_stream` (refill),
`strm_copy` (pool→DOC), `irq_handler`/`ih_dispatch` (Method-B `$E0`-in-A dispatch),
`irq_install`/`irq_uninstall`. Buffers live at the top of DOC RAM: `strm_base_pg[t] =
STREAM_BUF_TOP ($FC) − t*2`, under the timer page `$FF`.

---

## 2. Bug fixed: looped samples looped the wrong region (`49ea647`)

`trigger_stream` set `strm_end = strm_ptr + total_length` for **every** streamed
sample. NTP+'s `setup_instrument_ptrs` instead uses, for a **looped** instrument,
`end = ptr + rep_ptr + rep_len`, so the IRQ loop-back (`−rep_len`) lands on `rep_ptr`
(the file's true loop start). Ours dragged in a post-loop tail and looped
`[total−rep_len, total]` instead of `[rep_ptr, rep_ptr+rep_len]` → audible distortion
on every sustained looped note. Fix: parse `rep_ptr` (instrument bytes 4–6) and branch
`strm_end` on looped vs one-shot. The maintainer by-ear: **"considerably better."**

---

## 3. Bug fixed: ESC during playback crashed the firmware (`50818e2`)

`irq_uninstall` halted only the tick osc 31, leaving the per-voice streaming **timer
oscs** (free-run + IE) running. After it restored the firmware `$E1002C` vector and
`CLI`'d, those oscs kept firing sound IRQs into the firmware handler (no sound tools
set up) → crash, stuck oscillator, garbled firmware error on a blue screen.

Fix: while SEI'd, **halt all 32 oscs** (`ctl $01` clears run + IE), then **drain `$E0`**
(ack any latched osc IRQ, capped at 40) so `CLI` can't deliver a stale one, *then*
restore the vector. Regression-guarded by `-Q` (self-abort after ~4 s of playback) +
the `ntpplay_teardown` gate, since keystroke injection can't drive it (MAME drops
chars — see §7).

---

## 4. The static — symptoms

On streamed samples (placed samples are clean):
- Distortion/static, **pulsing** ("comes and goes" over seconds), sometimes nearly
  inaudible, sometimes obscuring the sample.
- Present on a **single** streamed voice in isolation (`ntpplay -i`), so not multi-voice
  contention.
- **CPU-speed dependent**: KEGS at 64 MHz (vs the usual 8/14) *lessened* it but did not
  remove it ⇒ a real timing/duration component **plus** a CPU-independent residual.

---

## 5. The static — conclusion: NTP+ method + imperfect ES5503 emulation

Two independent lines of evidence:

1. **senseiplay shows the same static.** senseiplay (`examples/senseiplay`) links the
   *genuine* NTP+ engine (`LoadNTP` → `_NTPplay`) with **zero** streaming changes — it's
   the real NTP+ binary, not a port — and statics in both MAME and KEGS. So the static
   is in the NTP+ **method**, not our port.
2. **The host-side render is clean.** `ntpsamples --mode doc` (ntpconvert's
   `_render_doc_stream`) is *linear* playback through the DOC phase accumulator with **no
   double-buffer**; it's clean. So the sample data and playback params (res/freq/sign)
   are correct — the streaming *execution* (writing wave-RAM during playback) is the
   variable.

**Mechanism (best hypothesis):** streaming fundamentally writes the ES5503's wave RAM
*while* its oscillators read it for playback. Real hardware interleaves host and
oscillator RAM access by cycle-stealing — clean. MAME and KEGS apparently perturb the
oscillators on the concurrent write, so each refill blips the audio. The CPU-speed
dependence fits (faster CPU → shorter write burst → shorter perturbation); the residual
at 64 MHz is the CPU-independent part (per-refill GLU register/mode traffic — the `$E0`
drain etc., which run at real-time GLU rate regardless of CPU speed).

**The decisive open test is real hardware.** NinjaForce developed/tested NTP+ on a real
GS, where this isn't audible. If real HW is clean, our streaming is *done and correct*.

---

## 6. Levers tried that do NOT fix it (and why)

- **Unroll `strm_copy`** (reverted). A *correct* unroll produces **byte-identical
  audio** (same data, faster copy); the 64 MHz evidence already showed copy-speed barely
  moves the residual. Clean optimization, **not a fidelity lever**.
  - ⚠️ The first unroll attempt shipped a real bug: it advanced the 16-bit source index
    with `TXA/ADC #16/TAX` in `MX %10` (8-bit A) — `TAX` pulls the hidden B into X.hi,
    corrupting the source address → every in-bank refill copied garbage. **The no-hang
    harness can't see copied-data corruption, so it "passed."** Correct fix is to do the
    index add in `MX %00` (`REP #$20 … SEP #$20`). It's not worth re-landing (no payoff).
- **Larger buffer (2 KB)** (reverted). Backfires: same total write-load packed into
  fewer/longer bursts → audible **clicks** (vs a fine buzz); and the 2 KB **in-IRQ**
  trigger fill (×voices) overruns the sound IRQ period → engine crawl/hang.
  Perturbation scales with write *time*, not refill *count*.
- **Smaller buffer**: impossible. The double-buffer needs page-aligned halves; 1 page
  (256 B) per half is the floor, so 512 B is already minimal.

---

## 7. Debugging affordances & gotchas (read before retrying)

**Tools in the player:**
- `ntpplay -i <file>` — **not re-ported**: the flag is parsed but is a no-op in the
  C driver, and `INSPECT_LOOP` no longer exists. Re-porting the inspector is a
  prerequisite for retrying the static investigation. Historically it auditioned
  `INSPECT_INS` (default instr 3) at `INSPECT_NOTE` (37)
  as a *single* streamed voice, song engine off (tick job → NONE). Isolates one voice.
  `INSPECT_LOOP` toggles natural-loop vs one-shot.
- `ntpplay -Q <file>` — self-abort after ~4 s of playback (drives the teardown test).
- Fixed debug addresses: `TICK_DBG $0C0F00` (engine ticks), `STREAM_DBG $0C0F02`
  (refill count). Healthy = PC in `$0E` (ntpplay) or `$02` (kernel); PC in `$FE/$FF`
  (ROM) = firmware crash/hang.

**Gotchas this investigation cost us:**
- **The no-hang harness cannot verify audio data.** It checks PC/tick/refill-count, not
  the bytes copied. A copy that writes garbage passes. *A real copy-integrity check is
  the missing guard.* Attempt: read the DOC buffer back through the GLU and diff vs the
  pool source — but the GLU **wave-RAM read** in MAME mismatched even a known-correct
  copy (read-back protocol not yet right; `$6F` mode + autoinc + sequential reads was
  wrong). Unsolved; revisit if the tool is wanted.
- **Merlin32 honors `*` precedence** (`2+1*8` = 10, *not* left-to-right): a derived
  `STRM_B_SIZE` EQU silently assembled `$0D` instead of `$1B`. Always verify
  mixed-operator EQUs in the `-V` listing; prefer hard-coded values.
- **`TAX/TXA` at M=8/X=16** corrupt the 16-bit register with the hidden B. Do 16-bit
  index math in `MX %00`.
- **Streamed sample data is interior-`$00`-free** (converter clamps); only type-8
  one-shots carry exactly 8 trailing `$00` stoppers. So free-run osc B won't halt
  mid-sample — `$00`-halt is not the cause.
- MAME **drops injected keystrokes** during long flows (the 553 KB africa upload), so
  ESC/quit-driven tests must self-trigger (`-Q`), not use `post_commands`.

---

## 8. Remaining directions (unproven)

1. **Real-hardware listen** — the decisive test. If clean, streaming is done.
2. **Trim CPU-independent per-refill GLU traffic** below NTP+ (e.g. skip the `$E0`
   drain when only one osc is pending). Speculative, and risks multi-voice IRQ
   correctness; NTP+ itself has the static, so matching it won't help — only *beating*
   it would.
3. **Converter side-step**: down-sample samples that only slightly exceed 64 KB so they
   fit as *placed* samples (no streaming, no perturbation) — trades sample bandwidth for
   zero static on borderline cases. A ntpconvert change, not the player.

## Commit map

- `49ea647` loop-region fix · `97a3410` `-i` inspector · `50818e2` ESC-crash fix + `-Q`
  + the `ntpplay_teardown` gate — **that test was deleted** with the 2026-07-30 gate
  collapse; `-Q` remains as the manual driver.
- Reverted dead-ends: `798084e` unroll (had the TAX bug) → reverted `a64f1ff`;
  `ed2b3e0` 2 KB buffer → reverted `9861a3c`.
- Tag `ntp-stream-working` = the verified-good baseline.
- Reference: `examples/senseiplay` (genuine NTP+), ntpconvert `src/ntpconvert/doc.py`
  + `sample_browser.py` (`ntpsamples`), NTP+ source via the iigs-docs example corpus.
