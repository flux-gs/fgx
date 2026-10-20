# ntpplay → C framework + companion-asm engine (H3 final)

**Status:** design, 2026-07-12. The maintainer approved the shape: C framework with
inline `__asm` for foreground bit-banging + a companion `.s` for the sound-IRQ
engine. Last hand-asm userland tool; retiring it closes H3.

## Why the engine can't be C

The tracker engine (`do_one_tick` + all `se_*` effect handlers +
`note_to_freq`/`ptr_to_freq`/`note_to_ptr` + `read_pattern`/`load_pattern` +
`trigger_voice`/`trigger_stream` + the DOC register writes) runs **at interrupt
time**: the ROM sound IRQ `JML`s into a bare vector (`$E1002C`), and the handler
calls the engine ~50×/s. There is no C call frame at an async interrupt and fcc
codegen isn't interrupt-safe (touches the runtime, assumes a normal frame). §6A.
So the engine + IRQ machinery (`irq_install`/`irq_handler`/`ih_dispatch`/
`interrupt_stream`/`irq_uninstall`) stay asm — a companion `ntpplay_stubs.s`.

## The hard part: this is an FGX1→FGX2 multibank port of the engine

Today ntpplay is FGX1 (`ORG $0C0000`): code and data share one bank, every data
access is DBR-relative. The C build is FGX2/FGX3: code in seg0, data in seg1
(loader-relocated to its own bank). Every engine data reference must target the
right bank or it silently reads garbage (the elvis-class whack-a-mole).

**Taming it — one data bank, DBR-pinned:** put *all* ntpplay data in C's seg1:
- mutable state + parsed tables (below) as non-static C globals;
- the const freq table (`freqtables.s`, ≤3574 B) and sine table (`sinetbl.s`) as
  C `const` arrays (mechanical DFB→initializer conversion).

Then the engine accesses **everything** DBR-relative against seg1, with the rule:
*the engine always runs with DBR = the data bank.* Foreground entry points are
called from C, which already has DBR = data bank. The IRQ handler is entered
with the ROM's DBR, so it must set DBR = data bank before touching any seg1 C
global, and restore on exit.

**The saved-bank chicken-and-egg (Fable-review Risk 1).** The data bank saved at
install CANNOT itself be a seg1 global — reading seg1 needs DBR already set. It
lives in a **seg0 cell** (`eng_dbank`, the *one* exception to "engine defines no
data"), reachable DBR-independently:
- install (called from C, so DBR = data bank): `PHB` capture — `PHB`/`PLA` gives
  the data bank in A; `PHK`/`PLB` (DBR = code bank, always derivable); `STA:
  eng_dbank`; then `PLB` restore.
- handler entry: the ROM JSLs in with **the osc-interrupt value in A** (ntpplay.s
  ~1476) and its own DBR. Prologue: `PHB`; `PHK`/`PLB` (DBR = code); **preserve A**
  across the next load (the osc value must survive — stash `PHA`/pull after, or
  `TAX` if X is free); `LDA: eng_dbank`; `PHA`/`PLB` (DBR = data). Everything else
  in the existing prologue (PHD push-only, forced-native XCE, CLC+RTL exit) is
  unchanged; `PLB` on exit restores the ROM's bank.

Inherently-far accesses stay long-addressed exactly as today: the MM resident
pattern block (`res_base`) and stream pool (`pool_base`) — 24-bit pointers into
MM banks — and the DOC GLU / RAM at `$E1C03C..F` (`STAL`/`LDAL`). No change.

## The shared-state ABI (C seg1 globals; engine refs by bare name)

The engine `.s` references these by bare name; `seg0.link.s` already PUTs
`seg1_layout.s`, which emits `<name> EQU <seg1 offset>` for every seg1 label, so
the refs resolve. The engine `.s` **defines no data** — it only references C's.

Parsed module (C writes at load, engine reads): `ntracks ninstr npat norder
order0 patstep patbase(3) sampoff(3) rowstep`; arrays `track_osc[16]
track_chan[16] ins_type[32] ins_len_lo/hi[32] ins_rep_ptr_lo/hi[32]
ins_rep_len_lo/hi[32] ins_vol[32] ins_finetune[32] ins_docptr[32] ins_docsize[32]
ins_pooloff_lo/hi[32]`.

MM bases (C allocs+derefs, engine reads): `res_base(3) res_ok pool_base(3)
pool_ok`.

Control (both): `g_check g_trace g_inspect g_autoquit g_done g_abort`.

Engine play-state (engine owns; declared in C so it lives in seg1): `songpos
ttick trigcnt pend_jump start_row master_vol last_ins[16] curr_vol[16]` + the
effect/slide/vibrato/arp state arrays + streaming state (`strm_base_pg[16]
strm_pg_off[16] osc_strm_trk[32]` + per-voice ptrs) + the `TICK_DBG` counter.

Const tables (C `const`, engine reads) — these are **16-bit words**, not bytes,
and keep their **exact current asm names** so the engine's by-name refs resolve:
`freq_finetune[]` (16-bit DOC-freq entries indexed by *byte* offset, last valid
offset MAX_FT_PTR=3574 ≈ 1787 words), `note_freq_ptrs[]`, `note_freq_ptrs_offset[]`
(referenced at ntpplay.s ~2574/2592), and `sine_tbl[]` (17×64 signed words). C
shape: `const int freq_finetune[] = {...}` — fcc int==16 little-endian → byte-
identical to the `DA` tables; abs,X byte-offset indexing has no alignment
constraint on the 65816. The DOC timer dummy wave stays wherever the IRQ install
needs it. **Byte-exactness is load-bearing** (a stride slip mistunes every note):
after conversion, dump the seg1 table region and `cmp` it against the bytes
assembled from freqtables.s / sinetbl.s.

**Fixed-address debug mailboxes stay put (Risk 3).** `TICK_DBG`/`STREAM_DBG` at
`$0C0F00`/`$0C0F02` are bank-blind absolute-long cells (`LDAL`/`STAL`) that the
`ntpplay_irqtick`/`ntpplay_pool` fixtures peek by absolute address. They must NOT
become seg1 globals (the harness can't find a loader-relocated bank). Keep them
exactly as-is — zero port risk, fixtures stay green.

## Decomposition

**ntpplay.c** (framework; inline `__asm` islands for foreground pokes):
- arg parse (`-c -t -i -Q` + path); open; header/track/instr/order parse into the
  seg1 globals (ntpinfo-shaped, extended);
- geometry (patstep/patbase/sampoff/order0) in C long/int math;
- resident pattern load: `SYS_MM_ALLOC` + handle-deref (`__asm`) + per-pattern
  `fseek`/`fread` into a scratch buf + `__asm` cross-bank copy to `res_base`;
- DOC bring-up: `__asm` island (verbatim register sequence);
- stream-pool alloc + deref (`__asm`);
- sample upload loop: `fread` chunk → `__asm` DOC-RAM write / pool copy;
- song init (clear arrays, assign stream buffers) — C;
- control loop: call engine `eng_load_pattern()`, then engine-in-IRQ
  (`eng_irq_install()`) with a C `poll_keyboard`/wait/yield/done spin, or the
  foreground tick loop (`eng_do_one_tick()` + wait); teardown `eng_irq_uninstall()`;
- `pattern_fetch(pat)` (Risk 4): the engine's disk-fallback `read_pattern` path
  (lseek+fread) is hoisted here as a small C function the engine JSRs (fcc-ABI
  push + near JSR to a bare seg0 label). The resident/IRQ path never calls it
  (gated on `res_ok`), but the foreground `-c` and non-resident modes do — the
  `bst_check`/`e51`/`e52` fixtures exercise it, so it can't be dropped. Keeping it
  C avoids the hand-asm engine having to `FGX2_FARCALL` the seg2 far-libc `fread`;
- diagnostics (printf).

**ntpplay_stubs.s** (companion engine; code only, refs seg1 globals):
- exported entry points C calls: `eng_load_pattern eng_irq_install
  eng_irq_uninstall eng_do_one_tick eng_inspect_run` (+ any upload/DOC helpers
  cleaner as asm than islands);
- the whole engine + IRQ, moved nearly verbatim from ntpplay.s, re-audited so
  every data access is DBR-relative to seg1 (or long for MM/GLU), and the IRQ
  handler sets DBR from the saved data bank.

## Build wiring

`build.sh`: `build_userbin ntpplay` → `build_userbin_fgx2_c ntpplay`. The engine
goes in `src/userland/ntpplay/ntpplay_stubs.s` (the template PUTs
`@NAME@_stubs.s` into seg0). freqtables/sinetbl become C const arrays in
ntpplay.c. Delete ntpplay.s / ntpplay.link.s.

## Increments (each builds + keeps prior MAME tests green)

1. **Bridge proof:** C skeleton that parses the header and calls a trivial
   `eng_ping()` in ntpplay_stubs.s that reads a seg1 global (e.g. `ntracks`) and
   returns it. Also make the canary compile one **big const array** (~1800 words)
   to prove fcc swallows the table initializers before converting them all.
   Proves the seg1-global bridge (foreground DBR inheritance) + build wiring.
1.5. **Mini-irqtick (front-loads Risk 1):** a stripped irq_install/irq_handler/
   irq_uninstall skeleton (copied from ntpplay.s ~1396-1526/1651) whose only job
   is to bump a seg1 counter each tick — exercising the async ROM entry, the
   seg0 saved-bank two-step, A-preservation, vector install/teardown, and the WAI
   spin, checked by a TICK_DBG-style probe. ~80 lines. This validates the genuinely
   novel mechanism BEFORE the 2000-line port (bridge-proof only tests the easy
   half). Optionally also run one SMC-bracketed copy loop (Risk 2's IRQ case).
2. **Foreground load path in C** (parse + geometry + resident load + DOC bring-up
   + pool + upload + `pattern_fetch`), engine still stubbed; verify `-c` check mode
   (no audio) via ntpplay_bst_check-style parse/seek markers.
3. **Port the engine** into ntpplay_stubs.s (verbatim + the Risk-2 SMC checklist
   below); wire the foreground/IRQ control loop; DBR-in-IRQ discipline.
4. **Green the existing suite:** ntpplay_e51, resident, resident_big, irqtick,
   pool, play_sanity, e52_break, bst_check — the by-ear-proven fixtures.

## Risk 2 — the six SMC sites (bank-audit checklist, not a hunt)

Each patches a code-side `LDAL/STAL $000000` operand via a DBR-relative store
(`STA: @label+1`). Today code+data share a bank so the store hits the operand;
under the split with DBR = data, the store lands in **seg1** (corrupting a C
global) while the `LDAL` keeps reading bank 0 — double corruption, invisible
until playback garbles. Fix each: bracket the patch store with `PHB` / `PHK`;`PLB`
(DBR = code) / `STA:` / `PLB`.

| site | ntpplay.s | new home | note |
|------|-----------|----------|------|
| `@rl_dA/@rl_dB` MM-handle deref | ~451-466 | C `__asm` island | island is still seg0 code — same bracket |
| `@pp_dA/@pp_dB` pool deref | ~675-679 | C `__asm` island | same |
| `res_to_pat` | ~2720-2724 | engine .s | |
| `pat_to_res` | ~2738-2742 | engine .s | |
| `upbuf_to_pool` | ~2762-2766 | engine .s | |
| `strm_copy` | ~3148-3152 | engine .s | **runs at IRQ time** — bracket is mandatory |

Keep the engine DP-free (no `[dp]` rewrite): the handler never re-points D (PHD is
push-only), a property worth preserving. Effect dispatch is BNE+BRL chains
(~2049/2189), PBR-relative and split-safe — no data-resident jump tables.

## Other risks

- IRQ-handler DBR + A-preservation: see the saved-bank two-step above — get the
  prologue right first (increment 1.5) or everything downstream is suspect.
- freq/sine tables DFB→C: byte-exact or every note mistunes — `cmp` the seg1
  region against assembled freqtables/sinetbl bytes; exact names so refs resolve.
- seg1 capacity: ~13.7 KB of ntpplay data (pattbuf 2304 + upbuf 4096 + tables
  ~6 KB + arrays) + fcc/args prefix — comfortably < 64 KB (Fable-confirmed).
