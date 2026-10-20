# BSD foundations campaign — roadmap (2026-07-16)

**Status:** ACTIVE — ordering agreed (the maintainer, 2026-07-16); this doc is the
campaign plan of record. Train details live in per-train plan docs as each
train starts.

**North star:** the full BSD-style stack — real libraries, real 32-bit
memory, a real FS stack — **in preparation for proper preemptive
multitasking.** Each train removes one structural non-BSD-ism: the monolithic
libc pile, the 64 KB single-arena malloc, and the single-writer FS state
singleton.

Out of the six flagged high-priority items, sequenced into three trains
(the "multi-bank fcc far-pointer oracle follow-on" folds into train 2 as its
phase 0b; cooperative fairness folds into train 3 as its closing increment):

---

## Train 1 — BSD library family + multi-archive linking

Design: `docs/history/plans/2026-07-13-multi-archive-linker-scoping.md`
(all of §3 applies unchanged). Phasing confirmed by the maintainer 2026-07-16, with
P1 scope **widened**:

- **P0 — DONE:** link-time recursion-trap guard (toolchain 6518eef4).
- **P1 — library-level split, per the 2.11BSD library map.** Not just
  libc/libfgx: **ALL non-libc functions leave the pile** (the maintainer ruling
  2026-07-16), each to the library 2.11BSD puts it in — the vendored
  `examples/2.11BSD/usr/src/{lib,usr.lib}/` tree is the placement authority
  (`lib/libc` = libc proper; `usr.lib/libtermlib`, `usr.lib/libcurses`,
  `usr.lib/libutil`, …). Concretely from today's pile + FGX-side sources:
  - **libc** keeps only ISO C / POSIX / 2.11BSD-libc names (str*/mem*,
    stdio, malloc family, qsort/rand/getopt/getenv, time family, dirent,
    syscall wrappers, sockets, popen/system, stty/gtty — 2.11BSD libc
    compat names — etc.).
  - **libfgx** (+ new `<fgx.h>`): waitkey/pollkey/ticks/yield, fontload/
    fontname/fontrevert/setpal, slotscan, dmesg/meminfo/listdir, spawn*,
    and the rest of the ~19 FGX-only names.
  - **libtermlib**: tgetent/tgetflag/tgetnum/tgetstr (today in the pile)
    reunited with tgoto/tputs (today FGX-side `src/userland/lib/termcap.c`).
  - **libcurses**: the ported 2.11BSD curses (today FGX-side per-tool TUs,
    `src/userland/lib/curses/`) becomes a proper selectable library.
  - Build emits one pile per library; manifests/templates select by name
    (`libs: ["c","fgx",…]`); the KIND=LIBC emit-once machinery is reused
    per-library. **Deliverable: collision safety + BSD-correct namespaces;
    ports link libc-only, FGX-native tools add libfgx.**
- **P2 — true multi-archive linking.** `.fgxa` archive format (member =
  per-source-file object + symbol index), the classic extraction loop in
  `fgx_ld`, packing moves after extraction, member-level dead-strip; retires
  the A1 weak/strong app-vs-lib precedence. Link-order convention: app libs
  first, libc last (classic Unix `-lcurses -ltermlib -lc` order), gated by
  the linker. Enables accreting the BSD library family during ports.
  **`.fgxa` IS `ar(1)` format (ruled, the maintainer 2026-07-16):** the portable
  archive format 2.11BSD itself uses — `!<arch>\n` magic, 60-byte member
  headers, `__.SYMDEF` symbol-index member (a member *inside* the archive,
  so the ProDOS no-underscore filename rule doesn't apply to it). The
  16-char member-name field fits ProDOS-sized names natively. Host-side,
  archives are created with the system BSD `ar` (macOS ships one) or a
  trivial Python writer in the build — nothing to port; `ar t libc.fgxa`
  works on the host for free. `__.SYMDEF` generation reads FGX member
  objects (listing-derived exports), not a.out symtabs, so it's fgx_ld's
  (or an `ar s` flag's) job rather than a ranlib port. On-device `ar(1)`
  ports from 2.11BSD when the self-host pipeline needs it — file-only
  subset, small K&R C, man page per policy — not before.
  **Shared-vs-static policy (P2):** every library ships as a `.fgxa`;
  libraries where sharing pays (ubiquity × size, bottom-of-stack closure,
  release-cadence stability — libc, likely libfgx) additionally ship a
  prebuilt shared-segment artifact that `fgx_ld` prefers over extraction,
  BSD `-lc`→`libc.so`-else-`libc.a` style. Each library its own shared
  segment per the inter-shared-segment-call requirement above.
- **P3 (future, direction set by the maintainer 2026-07-16) — detangle toolchain
  from OS.** The compiler/assembler/linker (`fcc`/`fas`/`fgx_ld` +
  `fcc_runtime.s`, the compiler's own runtime) become their own thing; the
  OS libraries (libc/libfgx/libtermlib/libcurses piles, asm libc.s,
  crt0/csu, args.s, the `include/` headers, probably `fcc_libc_shims.s`)
  are packaged and built with the OS itself, the way source-based BSDs do
  it. **P2 is the enabler:** today every link template hard-wires
  `toolchain/lib/*.s` PUT paths; once `fgx_ld` consumes named archives on
  a libpath, libraries become relocatable artifacts the FGX repo can own.
  The one real tangle to scope: the fcc golden/oracle suite (461 fixtures)
  links against the libc pile — a detangled toolchain needs either a
  minimal vendored fixture-runtime or a pinned FGX-libc for CI.
  **Placement (agreed slot):** last phase of train 1, gated on P2, and
  explicitly **off the campaign's critical path** — trains 2 and 3 do not
  wait on it and do not need it. Preferably it lands *after* train 2:
  malloc's `size_t → unsigned long` ABI ripple churns every library, and
  files move cheapest while quiescent — detangling first would put repo
  surgery under the campaign's biggest ABI change. Expected order of
  actual execution: P1 (now) → train 2 → train 3 → P2 when dead-strip
  pressure is real → P3 detangle immediately on top of P2 (same linker
  machinery, plus the release-flow rework: library changes stop requiring
  a toolchain release + FGX re-pin, and the MULTIBANK/goldens gates split
  between the two repos).

## Train 2 — MM-native malloc (32-bit memory)

The full item text lives in `docs/ROADMAP.md` (Kernel / memory). Order
within the train:

- **Phase 0a — DP-page pressure relief P1+P2** (design:
  `docs/superpowers/specs/2026-06-24-dp-pressure-relief-design.md`).
  Checked 2026-07-16: the reclaimed `$68–$6B` hole is the **last**
  3-byte-capable DP slot and the earmarked `_kHeapCur` seed; the MM-block
  arena manager needs 24-bit free-list walkers + a block-table long-pointer
  (today's `_kmem_*` walkers are 16-bit single-arena offsets). Seed the
  shared cursor + establish the "no new dedicated DP pointers" rule first,
  or malloc consumes the final hole and train 3 has no DP left.
- **Phase 0b — multibank far-pointer oracle: heap-source extension**
  (task #56 follow-on): extend the flip/construct sweep to the non-PHK/PHB
  bank *sources* (`_fcc_ptr+2`, heap) + the libc-shim caller-buffer
  population. Malloc rewrites exactly the heap bank source; without this the
  `MULTIBANK_VERIFIED` gate is blind to the class of bug the malloc train is
  most likely to introduce.
- **Main — MM-backed malloc:** boot allocation reshaped into large
  `locked|fixed` MM blocks grown on demand; BSD free-list semantics inside
  the blocks; coalescing never crosses an MM-block boundary; `size_t`
  widens to `unsigned long` (dispatcher zero-extends legacy 16-bit callers);
  MM handles never reach userland. Dedicated branch, full
  `MULTIBANK_VERIFIED=1` gate. **Unblocks:** full 16-bit `.Z` decode,
  large tar buffers, any >64 KB port need, and train 3's buffer cache.

## Train 3 — BSD FS stack (one train)

The scope note added to `docs/ROADMAP.md` (Filesystem) 2026-07-16 governs:
**in-core inode/metadata cache + buffer cache + FS buffer migration land as
one train whose explicit goal is retiring the `_fsFileState` write-state
singleton into genuinely per-FCB state** — the full BSD-style FS stack
(shared in-core inode table + buffer cache + per-FCB file state), shaped as
the foundation for proper preemptive multitasking.

- Shared in-core inode (`i_size`) + buffer cache: immediate cross-process
  visibility, no ~1s `_fwSyncTick` approximation; `fsync(2)`/`sync(2)` land
  as the durability primitives in the same push.
- FS buffer migration (Phase 3c §3.7): ProDOS buffers out of kernel
  FGX_DATA into `prodos.mod`'s bank; kernel becomes FS-agnostic; pairs with
  B2.6 (the same singleton retirement). Buffer allocations use train 2's
  MM-backed malloc; DP access via `_kHeapCur` (no new DP slots).
- Known latent piece to fix on the way: `_Fs_SwitchToFCB` sap/tree reload
  restores `_fsDataBuf`/`_fwDataBlk` but not `_fwDataBlkIdx`; the full fix
  is all write-state per-FCB (the carved-out `FCB_DataBuf`/`IdxBuf` slots).
- **Closing increment — cooperative bg-task fairness:** re-apply the proven
  kbd-gated cooperative `swtch` at the syscall dispatcher exit (reverted
  2026-07-15 only because two-writer interleaving broke the shared
  write-state). **Acceptance test:** `tools/mame_test/tests/coop_yield.json`
  (bg `tar cf … &` + live fg shell, no "tape write error"), plus byte-exact
  bg-write artifacts. Preemptive (IRQ-driven) scheduling remains a separate
  later decision — this train builds the state model it requires.

---

## Sequencing rationale (agreed 2026-07-16)

1. **Train 1 before train 2:** toolchain-only, no kernel risk; and malloc's
   `size_t = unsigned long` ABI ripple should land in the clean split
   libraries + `.a` machinery, not the monolithic pile.
2. **Train 2 before train 3:** the buffer cache wants flexible >64 KB
   cross-bank allocations (MM-backed malloc), and both trains need DP
   headroom that only exists if phase 0a lands first.
3. **Fairness inside train 3:** the yield is already proven; only the FS
   write-state concurrency blocks it, so it ships with the work that fixes
   that, not as a standalone phase.
4. **Toolchain/OS detangle last (train 1 P3, off the critical path):** it
   needs P2's archive machinery, benefits from the libraries being
   quiescent (i.e. after train 2's `size_t` ABI ripple), and nothing in
   trains 2–3 needs it — so it closes the campaign rather than
   interrupting it.

## Discipline

Feature branch per train (never on main; tag `pre-<feature>` before merge);
toolchain changes released via MR-native flow, then FGX re-pin; hold-releases
until the maintainer green-lights each train; `MULTIBANK_VERIFIED=1` whenever bank
codegen / bank-emission-adjacent code changes (all of train 2, parts of
train 1 P2); release.sh is the single gate.
