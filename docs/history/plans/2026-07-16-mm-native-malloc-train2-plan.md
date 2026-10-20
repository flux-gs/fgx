# MM-native malloc — train 2 plan (drafted 2026-07-16)

**Campaign:** `2026-07-16-bsd-foundations-campaign.md`, train 2.
**Status:** DRAFT — opens after the P1 release train (toolchain v1.12.0 /
FGX v1.7.0) lands. Branch: `feat/mm-native-malloc` off post-P1 main.
**Design references:** ROADMAP.md (Kernel / memory: MM-native malloc; DP-page
pressure relief), `docs/superpowers/specs/2026-06-24-dp-pressure-relief-design.md`,
memory `feedback_fcc_multibank_untested_whackamole.md` (oracle follow-on scope).

## Phase 0a — DP-pressure relief P1+P2 (prerequisite, small)

Why first: the MM-block arena manager needs 24-bit free-list walkers + a
block-table long-pointer; `$68–$6B` (`_kDpFree68`) is the LAST 3-byte-capable
DP hole and is earmarked as the `_kHeapCur` seed (dpmap.s). Consuming it for
malloc directly would leave train 3's inode/buffer-cache heap structures no
DP at all.

1. Define `_kHeapCur` (3 B + 1 pad) at `$68–$6B`; retire the `_kDpFree68`
   placeholder comment-block into the real definition.
2. Access macro (`KHEAP_USE <bank2_base_static>` → load `_kHeapCur` from the
   structure's bank-`$02` base, then `[_kHeapCur],Y`) + the caller-saved /
   reload-after-foreign-JSR discipline documented at the definition site
   (the `feedback_dp_scratch_aliasing` class is the hazard).
3. Forward rule (enforced by review, stated in dpmap.s): every NEW heap
   soft-global uses `_kHeapCur` + a bank-`$02` base static — no new dedicated
   DP long-pointers.
4. NO big-bang conversion of the ~17 existing dedicated pointers (P3 of the
   design: opportunistic, cold paths first, hot paths measured).

## Phase 0b — multibank oracle: heap-source extension (task #56 follow-on)

Why before malloc: the `MULTIBANK_VERIFIED` release gate currently proves the
~21 PHK/PHB decision sites; malloc rewrites exactly the HEAP bank source,
which the sweep does not yet cover — the gate would be blind to the class of
bug this train is most likely to introduce.

1. Extend `tests/multibank/` constructs: malloc'd-pointer provenance shapes —
   store/load heap far ptr through globals, chained deref-store via heap ptr,
   heap ptr as K&R/varargs arg, heap ptr return value, realloc-moved block.
2. Extend `flip/` (site-flip instrument) to the non-PHK/PHB bank *sources*:
   `_fcc_ptr+2` (stored-pointer bank) and the heap-provenance sites — per-kind
   mutations, not simple PHK/PHB flips (the 2026-07-05 sweep deferred these).
3. libc-shim caller-buffer population: constructs covering shims that fill a
   caller buffer (stat-model) with DBR≠caller-bank.
4. Regenerate `flip/MATRIX.md`; sites that red nothing are enumerated gaps.

## Main — MM-backed malloc (the 64 KB ceiling lift)

**Boot-claim migration (the maintainer's question, 2026-07-16 — the staged path from
"two boot MM calls" to full dynamic MM).** Today `LoaderAllocKernelBank`
claims the kernel and `LoaderAllocRestBank` claims ONE `RESTOFOS_BANKS`
($1D = 29-bank) region; all kernel allocators carve inside it.  Migration:

- **M-1 — block-table seam (no behavior change):** the arena manager gets a
  block TABLE ({base bank, count, MM handle, kind}; the first `_kHeapCur`
  consumer), with boot's REST claim handed over as block[0].  All allocators
  (Kmalloc byte-grain, loader whole-bank grants) route through the table.
  **Grounded geography (main.s ~L130-165):** the kernel seeds `_restBaseBank`
  from `KFGX_REST_ANCHOR` and derives `_kFontsBank`/`_kUserFirstBank`/
  `_kConsoleBank` as `_restBaseBank + REST_*_OFF` fixed offsets, and
  `Bank_Init` sizes the user-bank bitmap against the claim — THESE are the
  contiguity assumptions the block table must absorb (block[0] keeps the
  boot-carved regions; only allocations BEYOND them go table-general), and
  the exact list M-3's shrink will flush.
- **M-2 — runtime growth:** `Arena_Grow` calls NewHandle at RUNTIME
  (locked|fixed, page-aligned + the loader's round-up-to-bank/over-allocate
  trick — `_LoaderDerefAlignedBank` logic moves kernel-side) and appends
  block[N].  Growth ONLY from task/syscall context — IRQ-path allocations
  satisfy-or-fail from resident blocks (toolbox not reentrant); kernel
  toolbox-call contract = the today_init `JSL $E10000` / `D=$0000` pattern.
  Handles stay inside the table (future DisposeHandle; never exposed).
  Test: shrink the boot claim in a test build; force growth on first big malloc.
- **M-3 — shrink the boot claim:** `RESTOFOS_BANKS` drops to a minimal boot
  working set; the deferred "OS pool clamped, add RAM" howl is superseded by
  growth-failure ENOMEM + kernel log at the point of use.  Full gate here —
  this rung flushes hidden contiguity/geography assumptions.
- **M-4:** the 32-bit `size_t` malloc rides the table — >bank requests get a
  dedicated MM block; free lists never cross block boundaries.
- **Never changes:** kernel-bank claim, boot.conf/PreClaim fixed banks,
  TN#27 low-mem reservation, kernel DP page (position-fixed boot
  infrastructure); and the MM stays a block-granting landlord — byte-level
  management remains FGX's kmalloc/malloc, now over N blocks.

Per the ROADMAP item (authoritative text there):

- Boot "large single allocation" reshaped into a small set of large
  `locked|fixed` MM blocks, grown on demand; BSD malloc free-list/marking
  semantics operate INSIDE MM blocks.
- Coalescing never crosses an MM-block boundary (cross-block is a chained
  free-list walk); MM handles never reach userland (handle/lock duality stays
  inside the arena manager; callers get flat far pointers).
- `size_t` widens to `unsigned long` (32-bit): fcc/libc ABI ripple; the
  dispatcher zero-extends legacy 16-bit callers.
- Kernel side: `Kmalloc` arena walkers (`_kmem_prev/_kmem_avail/...`,
  today 16-bit bank-`$02` offsets, single-arena) become 24-bit via
  `_kHeapCur`-style access; the block table is itself a phase-0a consumer.
- **Gates:** dedicated branch; full `MULTIBANK_VERIFIED=1` (with the phase-0b
  extended sweep); goldens + runtime oracle; FGX MAME fast + heap-heavy tests
  (compress/tar/ed/elvis); explicit >64 KB allocation test (new fixture +
  MAME test — e.g. full 16-bit `.Z` decode, the motivating case).
- **Unblocks:** compress full 16-bit decode (CODE_LIMIT retires), large tar
  buffers, train 3's buffer cache.

## Exit criteria

- `malloc(80_000)` succeeds and the block is usable across its bank crossing.
- compress decodes a 16-bit `.Z` byte-exactly (the shipped bridge limitation
  retires; update the compress provenance row + man page).
- DP free-slot count is FLAT vs pre-train (relief working: malloc consumed
  zero dedicated DP slots).
- All release gates green; toolchain + FGX release train (hold until
  green-light).

## Status (2026-07-17 session 2)

- **M-1 DONE** (`2bfcdc60`): the "IRQ hang" root cause was NOT DP-$68
  aliasing — it was Bm_Sync's loop tail re-entering its 8-bit guard with
  M=16, making `CMP _bm_dirty_hi` a 16-bit read of DP $67+$68 that picked up
  the newly-seeded `_kHeapCur` low byte as the comparand high byte → runaway
  sync loop → zero-length copy DEC-wrap → 64KB kernel-bank scribble →
  `_simExit*` cells destroyed → IRQ stack collapse.  Block table live,
  fresh-NVRAM 3× green.  `check_mx.py` rewritten to live-entry-mode analysis
  (`d2503c9b`); found + fixed a second latent path-dependent-M bug
  (`@afa_errExit` fd-table-ptr half-write).
- **M-2 DONE** (`d34c079a`): `_Arena_GrowMM` — runtime MM bank growth via
  NewHandle($10000, $801C); TN#78 full-bank no-cross trick (zero alignment
  waste; the loader's over-allocate trick is only needed for MULTI-bank
  claims).  kind=2 block-table rows carry the handles.  Verified live with a
  forced-growth boot (dmesg breadcrumb).
- **M-3 DONE** (this session): `KFGX_REST_COUNT` bank-0 anchor ($00:03CE,
  loader-written CLAIMED count); Bank_Init pre-marks past-claim bitmap
  indices (no new static — the bound bakes into the bitmap); block-table
  row 0 count reads the anchor; RESTOFOS_BANKS $1D→$13 (19 banks: 7 fixed +
  12 user; runtime growth covers overflow).
- **M-4 IN PROGRESS**: SYS_MALLOC32 (#96, A=lo16/X=hi16); legacy #62
  zero-extends by fallthrough and $F000..$FFFF legacy sizes now succeed;
  `_MM_ClaimBanksToRow` common claim engine (kind=4 dedicated big blocks,
  tombstone row reuse); `_Kmalloc_Big`/`_Kfree_Big`; `_Sys_Free` routes
  offset-0 pointers; `_Sys_Realloc` EINVALs big old-pointers (no big
  realloc — old length invisible to the copy path).  Toolchain: size_t →
  unsigned long (stdio.h + sys/types.h), malloc/realloc prototypes widened,
  piles regenerated; fcc's prototype-driven int→long arg widening verified
  in the generated calloc.  K&R empty-paren `malloc()` decls fixed in ed.c
  + curses newwin.c (would have passed 16-bit where the wide malloc reads
  32).  Fixture: `mbig` (malloc(80000L) across-bank + free/row-reuse).
  DONE (`937998be` + toolchain `88389b5a`).
- **compress 16-bit .Z decode DONE** (`ee903589`): CODE_LIMIT retired;
  byte-exact vs host `compress -b 16` (test `compress16z`).  Found+dodged
  the fcc single-bank pointer-ARITHMETIC gap (`&p[i]`/`p+i` drop the bank;
  long-indexed DEREFS carry it — mbig-proven): de_stack gets its own block
  instead of the `&htab[1<<maxbits]` overlay.  Pointer-model queue item.
- **M-3 shrink regression found+fixed by the gate**: modules+jsh eat the
  12-bank pool and elvis no longer fit (spawn fails as "not found" — jsh
  prints that for ANY spawn errno).  Fix = kind=3 user-grant rows: a dry
  Bank_Alloc claims runtime MM banks; Bank_Free disposes by table lookup.
- Exit criteria: malloc(80000L) across-bank GREEN (mbig); 16-bit .Z
  byte-exact GREEN (compress16z); DP free-slot count FLAT (zero new
  dedicated DP slots across M-1..M-4).  Full-suite gate at track end, then
  HOLD for the release train.
