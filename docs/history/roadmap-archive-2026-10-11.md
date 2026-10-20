> This is docs/ROADMAP.md as of 2026-10-11, kept verbatim as the record of the
> campaigns it narrates.  Only relative link targets were adjusted so they resolve
> from docs/history/.  The live plan is [../ROADMAP.md](../ROADMAP.md).

# FGX Roadmap

> Forward-looking plan. The backward-looking record is `CHANGELOG.md`
> (git-cliff). This file is the **source of truth** for "what's next" —
> versioned with the code, unlike a point-in-time note. When evaluating a
> feature idea, relate it to this sequence; it is not frozen (re-prioritize
> freely). The current state of each subsystem is in the reference docs indexed
> by [README.md](../README.md); the campaigns below record how it got there.
>
> **Build/test infrastructure.** The toolchain is in-tree at `toolchain/`;
> **ninja** owns the build ([BUILDING.md](../BUILDING.md)); the gate is the smoke
> test plus a budgeted set of MAME tests ([testing.md](../testing.md)).  Items
> written before 2026-07-29 may name commands (`./build.sh ...`) or costs that
> no longer exist -- treat their mechanics as historical and re-measure.
>
> **Live status = this file (next) + `CHANGELOG.md` (shipped).** The historical
> trail — superseded `RESUME-*` handoff notes, landed plans/specs, and
> point-in-time audits — now lives under [`docs/history/`](./) (see its
> README). If a doc isn't in the canonical `docs/` set, this file, or the
> CHANGELOG, it's reference-only history.
>
> **Landed since the last refresh (2026-07-14 → 07-17): the BSD-foundations
> campaign, complete.** Train 1 (FGX v1.7.0 / toolchain v1.12.0): the lib
> family (libc = pure BSD names, libfgx split, multi-archive linking).
> Train 2 (v1.8.0 / v1.13.0): **MM-native 32-bit `malloc`** (the 64 KB
> allocation ceiling is gone; MM-backed growth kernel+user; shared libc pile
> for ALL binaries). Train 3 (release pending): the **BSD FS stack** — shared
> in-core **inode table** (live `i_size` via stat, promotion re-key), a
> transparent **block cache** under `Blk_Read`/`Blk_Write` (write-through,
> 16×512 B), **`fsync(2)`/`sync(2)` + `sync(1)`** with disk-extraction-proven
> durability, the switch-away **EIO latch**, and the **cooperative kbd-yield**
> (fg shell live during bg writes — `coop_yield.json` is the acceptance).
> The `_fsFileState` singleton retirement (F3) was deliberately resequenced
> into the preemption campaign (Fable-audited: no surviving corruption class).
> Earlier arc (06-24 → 07-14): multibank correctness program, multi-pass fcc
> front end, optimizing backend, shared-libc bank → libc-in-C, cooperative
> scheduler + job control, VT100 console, environ, elvis/vi, hand-asm
> retirement. See Done + `CHANGELOG.md`.

---

> **Hand-asm retirement adjunct (2026-07-11):**
> [`history/plans/2026-07-11-fgx-hand-asm-retirement-roadmap.md`](plans/2026-07-11-fgx-hand-asm-retirement-roadmap.md)
> — the complete post-T5-C catalog of remaining hand-assembled code
> (26 active userland tools / ~13k lines, kernel+drivers ~44k lines,
> toolchain lib) with a per-item path: BSD port (9 tools have vendored
> sources), plain C rewrite (10 diagnostics/formatters), C + `__asm`
> islands (5 hardware tools), asm-on-C-libc (ntpplay's DOC/IRQ engine),
> or permanent (fcc runtime, crt0_lib/crt0_dyn, macros).  Phases H0-H5.
> **H5 (kernel + modules in C) CHARTERED 2026-07-11 (the maintainer):** the
> kernel (19k lines), drivers/modules/boot (25k) follow the libc arc —
> sub-phases H5-0 (T9 spike: one C TU in the kernel image, ORG/DP/bank
> contracts, byte budget) → H5-1 (kernel libc: alloc.s first) → H5-2
> (dispatch/IPC leaves) → H5-3 (FS) → H5-4 (net) → H5-5 (FGXM C-module
> framework: serial/bpf/net as C modules) → H5-6 (sched/dispatcher/
> loader last; IRQ paths + boot stay asm until fcc grows interrupt
> codegen).  Rewrite against the SAME syscall contract, each rung green
> through the MAME suite + taps before the next opens.
> **H0 executed 2026-07-11**: the "stale .s sweep" claim dissolved on
> audit (those files are fcc-GENERATED, gitignored artifacts — nothing
> to sweep); the real H0 find was build.sh's stale hardcoded MX-audit
> list (the CI FileNotFoundError), now manifest-driven with all
> 26 hand tools audited clean.

---

> **Architecture adjunct (2026-07-05; status 2026-07-10):**
> [`architecture-redesign.md`](plans/architecture-redesign.md) — the verified
> diagnosis of the multibank/far-pointer problem class and the staged
> redesign path. **Status: the whole Phase-2+3+T5-A/B arc is RELEASED
> (toolchain v1.0.0/v1.1.0, FGX v1.0.0/v1.0.1), and T2 is COMPLETE**
> (T2-2 pp-as-token-pass + T2-4 measurement on `feat/t22-pp-token-pass`,
> release pending; plan doc under `docs/history/plans/2026-07-09-fgx-t2-*`).
> **Priority ruling (the maintainer, 2026-07-10): compiler CORRECTNESS first** —
> flesh fcc out end to end (the `fcc-known-issues.md` gap registry is the
> queue) before optimization- or self-host-shaped work; self-hosting stays
> the north star, with memory-shape findings (e.g. the T2-4 report)
> catalogued below rather than gating.  **Landed since:** T5-C (libc in
> C, toolchain v1.3.0), T7 (environ, ~v1.2.0), the multi-pass front end
> (whole-TU token vector → AST, toolchain v1.0.0).  **Remaining redesign
> stages:** Track-2 phase 2 (whole-function allocator on the lifted IR —
> now unblocked by the AST substrate); T8 co-location; T9 kernel-in-C
> spike (H5); the multibank shim/bank-source sweep.

---

## Cooperative multitasking + job control — ★LANDED

The keystone that lets the subsystems below run *together* is in. `sched.s` is
wired (not the "orphaned scaffold" this file used to claim):
1. **`yield()` + ready/blocked queues + cooperative context switch** — DONE
   (`_Sys_Yield` = SYS_YIELD 79; round-robin so a busy task that yields no
   longer immediately re-wins; `@sw_idle` idle loop).
2. **Blocking-I/O hooks** — DONE for the console keyboard path (`@sw_idle_kbd`
   wakes a keyboard sleeper when the 60 Hz heartbeat enqueues a key, instead of
   spinning). *(Confirm/extend the `Fs_Read` / `recv` yield paths when the TCP
   server payoff demo forces the W5100 `U2_LOCK` + IRQ-RX concurrency test.)*
3. **Shell job control** — DONE: `jsh` has `jobs` / `fg [%n]` / `bg [%n]`, `^Z`
   (SIGTSTP/SIGCONT), job table, `tcsetpgrp`, non-blocking bg reap/report. (The
   earlier background `&` spawn + `^C`/tty isolation landed in v0.4.0.)

Remaining follow-ons (no longer "the active push"):
- **Payoff demos** — a TCP echo/HTTP **server** (needs blocking `accept`),
  background `ntpplay`, the long-deferred audio+net IRQ-latency A/B.
- **Cooperative kbd-yield — ★LANDED (train 3 F5, 2026-07-17).** The
  fg shell is scheduled mid-bg-write and the interleaving is byte-clean
  (`coop_yield.json` green); the FS write-state hazards that blocked the
  2026-07-15 attempt were retired by train 3 (F0.5 swap completeness +
  shared inode + coherent block cache). The **preemptive scheduler** is now
  a chartered campaign — see below.

---

## Chartered campaigns (2026-07-17, at train-3 close)

Three campaigns are planned and sequenced; their sub-roadmaps are the plan of
record and fold in here at the current release:

0. **Bank-0 residency campaign (2026-09-17) -- R0 to R6 MERGED in
   !343, 2026-09-18.**  Design of record:
   [`history/plans/2026-09-17-bank0-residency-architecture.md`](plans/2026-09-17-bank0-residency-architecture.md);
   the Second Sight driver plan beside it,
   [`history/plans/2026-09-18-second-sight-console-plan.md`](plans/2026-09-18-second-sight-console-plan.md).
   Bank 0 is a cache of task images, not their home: kernel-image slots
   (seven of 1,024 bytes, parked to home images when another task needs one
   -- the apple/fgx#442 fix), a user arena that may be oversubscribed with
   parked live extents in a swap pool, the user direct page riding with the
   stack, NPROC 32 (decision 5, taken 2026-09-18: `FGX_CODE` at `$021000`,
   the file table a heap arena), and a Second Sight card as the display of a
   fourth virtual console `ttyv3` with one keyboard (Option-4 moves it to the
   card's console).  What runs out is banks, not the stack arena: a
   process's data bank, its code banks shared as text, and the resident
   shared libraries, from the 56-bank pool and then Memory Manager grants
   recorded in the arena block table, which has thirty-two rows; a dry
   pool takes back an unused text first and then an unused library.  Open: the process table is
   the next limit at 32, and a small image's two banks (code and data
   segments) are the structural cost past that.  The core kernel bank has
   1,293 bytes free since the ProDOS mount table and SYS_DIAG left it
   (2026-10-04); the TCB table below the code (32 x 64 B) is the next large
   exit if it runs short again.

   **Memory campaign (2026-10-03) -- CLOSED 2026-10-11: quick wins (!405),
   shared text (phase A, !406) and the coremap's B1-B3 (!409) merged.**  Design of record:
   [`history/plans/2026-10-03-coremap-shared-text-design.md`](plans/2026-10-03-coremap-shared-text-design.md).
   A program's code banks are loaded once and shared by every instance, as
   2.11BSD shares text: the bank spawn and exec allocate holds the data
   segment, a sixteen-entry table in the tty bank holds each text keyed by
   device, inode and change time, and a dry pool takes back the least
   recently used text no process runs.  Twenty-one sleeps hold 22 banks for
   their images where they held 42.  No ETXTBSY: a text is an in-memory copy,
   so writing a running program stays allowed.  Phase B steps B1-B3
   ([plan](plans/2026-10-10-coremap-phase-b-code-packing-plan.md),
   as built in the design's section 6.5): the user pool is 2.11BSD's
   resource map in 256-byte pages, every code segment up to $FEFF bytes
   carries offset relocations found by a second assembly at $0101, and the
   loader places a new text's code by size in shared banks.  At an idle
   prompt 28.2 of the 56 pool banks are in use, from 46; exec time is
   unchanged within 3%.  B4 and B5 were measured first and not built: they
   would free about two banks while 28 stand free and the process table
   binds first (design section 6.6).

   **ANSI colour on the card (2026-09-18, MR !347).**  The card's
   console shows sixteen colours on sixteen backgrounds and code page 437:
   the console's cells hold ANSI colour indexes and eight-bit bytes, which
   the IIgs screen folds to its four slots and seven-bit font exactly as
   before (its framebuffer is byte-identical, measured), and each console
   has a default pair (`CSI 8 ]`).  `ansicat(1)` shows ANSI art and paces
   animations.  Design and as-built:
   [`history/plans/2026-09-18-ansi-colour-card-design.md`](plans/2026-09-18-ansi-colour-card-design.md).
   Next on the card: its bitmap modes (320x200x8, 640x480) for images, a
   project of its own.

1. **Preemption campaign — ★P0–P3 RELEASED (FGX v1.10.0 / toolchain v1.15.0,
   2026-07-19); P4 is the open train.** —
   [`history/plans/2026-07-17-preemption-campaign-roadmap.md`](plans/2026-07-17-preemption-campaign-roadmap.md).
   Timer-quantum preemption, 2.11BSD-faithful (Model A: user-code preemption
   only, kernel runs to completion). **Shipped:** P0 latency survey, P1 quantum
   resched at the dispatcher boundary, **P2′ compiler loop-safepoints** (the
   chartered P2 RTI-redirect was proven dead — firmware switches stacks — and
   replaced by fcc-emitted `_fcc_safepoint` at loop back-edges; toolchain
   v1.15.0), and P3 the F3 `_fsFileState` singleton retirement. Core preemption
   (busy task loses the CPU on a timer quantum, fg shell stays live) is DONE and
   proven. **Remaining — P4 blocking-I/O completion:** sleep-instead-of-poll for
   `recv`/`accept`/serial/pipe backpressure so preemption + sleep compose into
   real concurrency (the TCP-server payoff demo lands here), plus retiring the
   `_kYieldReq` kbd special-case into the general mechanism. P4 is independent of
   P2 and lower-risk — cleanly pickable now.
   **Implementation plan: [`history/plans/2026-08-01-preemption-p4-blocking-io.md`](plans/2026-08-01-preemption-p4-blocking-io.md)**
   (2026-08-01).  Key finding from that planning pass: `recv`/`accept` and pipe
   reads ALREADY sleep — they are not busy-polls — so the charter's
   "sleep instead of poll" framing is only half right.  The urgent half is that
   both blocking helpers peek the keyboard ring for a literal `$03`, which can
   never fire once a shell owns the tty (the heartbeat consumes `^C` as a
   signal), AND both discard the interrupt flag the 2026-08-01 `_sleep` fix now
   returns.  So `recv`, `accept` and pipe reads are un-interruptible today, and
   the first two tasks fix that by DELETING code.
   **T1 + T2 LANDED 2026-08-01**: both helpers now consume `_sleep`'s carry and
   the `$03` peek is gone from both (it also *dequeued and discarded* the key it
   found, so a blocked reader ate the foreground shell's keystrokes).  **T3 is
   CLOSED with no kernel work**: `serial_read` is a genuinely non-blocking
   IRQ-fed ring and `tip`/`cu` must service the console *and* the line, so a
   blocking serial read would be wrong for its only customer — the improvement,
   if wanted, is porting `tip` to the `select()` that already shipped, which is
   userland work.  The same train fixed
   #3 — a background
   job halted the machine when it exited, because `_Sig_PendingActionable`
   treated a SIG_DFL signal whose *default action* is `SA_IGN` (SIGCHLD) as
   actionable, so every child death returned EINTR from the parent shell's
   console read.  **T4/T5 remain open** and are now unblocked: their acceptance
   probes (`spin_yield`, `spin_sigint`) are built on background tasks, which
   work again.
2. **fcc self-host campaign** —
   [`history/plans/2026-07-17-fcc-selfhost-campaign-roadmap.md`](plans/2026-07-17-fcc-selfhost-campaign-roadmap.md).
   Key reframes: **fgx_ld is 950 lines of host Python** and must be ported
   to C (S1, dual-built so the clang build oracles the fcc build); the
   subset/ceiling audit de-risks host-side, but **fcc-built-fcc is a 65816
   binary** — its correctness oracle needs an execution venue (S2a:
   oracle-sim vs MAME, an explicit deliverable); S0 MEASURES the 7 MHz
   build-time showstopper before anything is built on-device; and the
   catalogued compiler gaps (`#`/`##`, unsigned hex) land toolchain-first
   (S1.5) BEFORE any source-bending. Order: S0 → S1.5 → S1 ∥ S2-audit →
   S2(+S2a) → S4 → S5. Train-2's 32-bit malloc already cleared the
   memory-arena prereq.
3. **UFS campaign — replacing ProDOS with the 2.11BSD filesystem** (chartered
   2026-08-09) —
   [`history/plans/2026-08-09-ufs-migration-campaign.md`](plans/2026-08-09-ufs-migration-campaign.md).
   Scoped after eight BSD-parity issues traced to one root cause: **ProDOS has
   no inodes, no permissions and no device nodes**, so the kernel keeps growing
   BSD mechanisms the filesystem cannot express. ProDOS stops being *the*
   filesystem and becomes *a* loadable type (`mount -t prodos`, read/write),
   required for neither boot nor root. The structural decision is a two-source
   split: **architecture from 4.3BSD-Reno, on-disk format from 2.11BSD** — the
   goal is that an FGX volume mounts on a PDP-11/70 and vice versa, which
   Reno's `ufs/` cannot deliver because it is FFS (cylinder groups, 128-byte
   dinodes, 32-bit `ino_t`). Both seam blockers are closed: the kernel-C direct
   page is carved and checked, and kernel C survives `_sleep` (the register file
   is 104 bytes, saved across a context switch).
   **Landed:** 0.2/0.4 (host `fgxfs` oracle + struct-layout conformance), 1.0
   (32-bit block keys), 1.1 (vnode sizing), 1.3a/b/c — the Reno buffer cache is
   wired into the kernel and proven end to end against a real 2.11BSD volume on
   a second SmartPort spindle, with the layer BELOW as its oracle rather than
   the cache's own flags. The chartered 60-singleton conversion was
   **challenged and dropped**: FGX disk I/O is synchronous SmartPort PIO, so
   `bio_strategy` completes before `biowait` is ever called and `Blk_*` never
   becomes able to block — traded for one enforced rule, `DEV_FLAG_VFSOWNED`
   (a device is cached by exactly one stack, never both).
   1.4 (the vnode layer — pool, free list, reference counting, the 32-slot
   Reno operations vector, `dead_vnops`, and reclaim) is complete. It closed
   apple/fgx#84 (`vinvalbuf`/`vflushbuf`, which the buffer cache could not have
   without vnode block lists) and corrected two fields narrowed by looking at
   the values in use rather than the ones BSD defines: `VALIASED` sat on Reno's
   `VBWAIT` bit, and `mnt_flag` was too narrow to represent `MNT_MPBUSY` at all.
   1.4c adds the device half — `specinfo`, the alias hash, `checkalias`,
   `bdevvp`, `vfinddev`, `vcount`, and the two arms that were placeholders:
   `vgone`'s chain unlink and `vflush`'s forced-unmount revert, which keeps a
   device working after the filesystem that named it goes away.
   1.5 adds `specfs` — `spec_vnodeops` and its operations, so a device node can
   be a file in one filesystem and a reference to a driver at the same time.
   **The kernel wiring then landed with
   #88**, which 1.5
   uncovered: a function-pointer table compiled into the far bank assembled to
   ALL ZEROES, because fcc emitted each entry as `FGX2_LONG_PTR` — offset
   resolved by `fgx_ld`, bank byte written by the FGX2 loader — and the far
   kernel bank is a Merlin link that goes through neither. The fix is fcc's new
   `--kernel-bank`, which resolves the offset at assembly (the far bank is one
   Merlin invocation) and takes an indirect call's target bank from `PHK`,
   which is what `--pile` has always done for a DIRECT call. With it,
   `vfs_subr.c`, `dead_vnops.c` and `spec_vnops.c` are in the kernel, `bread()`
   dispatches through `VOP_STRATEGY`, and the boot probe reaches a real 2.11BSD
   volume through a device vnode from `bdevvp`.
   1.6a adds the **name cache** — the hash of (directory, name) → vnode that
   keeps a five-component path from costing five directory scans every time.
   Its hard part is staleness rather than lookup: a cached entry names a vnode
   that can be recycled underneath it, and `v_id` is what catches that, which
   is why `vnode.h` keeps that field 32 bits against every other narrowing in
   this campaign. `getnewvnode` now mints through `cache_purge`, as Reno does,
   so the counter's WRAP is handled rather than only the common case.
   **THE FAR BANK WAS THE CONSTRAINT AND IS NOT ANY MORE.** It stood at
   55,211 of 60,480 used with 5,269 free, of which the VFS was ~38 KB, and
   namei (1.6b) would not have fitted. Two moves cleared it. First the pools
   went to the heap — plain memory with no reason to sit beside code — which
   bought ~7.5 KB. Then **the VFS itself left the bank entirely**: it is
   `vfs.mod` now (2026-08-12), 36 KB of kernel C in a loadable FGXM module in
   a module bank of its own, and the far bank is down to **15,587 used with
   44,893 free**.
   The C did not change and was not recompiled — `vfs.mod` PUTs the same
   generated `.s` files the far bank did, from the same `kernelc` edges. Only
   `kc_sys.s` differs, and only in how it reaches the kernel: the far bank
   JSLs shims at addresses scraped from the kernel's build listing, which a
   module cannot do because it does not know the kernel's bank at build time,
   so the module goes through the bank-0 gateway instead. `far.s` predicted
   exactly this — "promoting a subsystem out of here into a real module later
   is a LINK CHANGE, NOT A REWRITE" — and it was.
   **The kernel now calls into the VFS at zero points**, which was not the
   plan. `_BufInit` and `_VfsInit` existed only because far-bank C could not
   allocate its own arenas; `KSVC_KMALLOC` retired that, so `mod_init` does
   its own bring-up and the three export slots that reached the VFS are halt
   stubs again. Even the wiring probe moved, because the device table turns
   out to be reachable through DIRECT PAGE cells rather than core-bank
   statics. An inward seam returns when 1.6b gives the VFS a syscall-path
   customer, shaped by that customer.
   1.6b (namei) landed in that final home, and so did 1.6a's name cache;
   `vfs_lookup.c`, `namei.h`, `namei_probe.c` and `probefs.c` are all on main.
   **1.9 (host `fgxfs mkfs` + `fsck`) is also done** and has been all along --
   `tools/fgxfs.py` carries both, ported step for step from 2.11BSD's
   `usr/sbin/mkfs/mkfs.c`, and `tools/gate.sh` has been running its self-test
   (7 mutation arms, plus a read of a real 2.11BSD volume) on every gate run.
   That is seven of Phase 1's thirteen complete, plus 1.2a.
   **Since then 1.2, 1.7, 1.10a and 1.10b have all landed**, in that order,
   and the paragraph below describing 1.2 as the next thing is kept as the
   record of how it was sized rather than as a plan. `struct file` and the
   open-file table are `vfs_file.c`; `struct uio` and `uiomove` are
   `kern_subr.c`; `spec_read`/`spec_write` are the transfer path; the 2.11BSD
   superblock is `ufs_vfsops.c`; and the block and inode allocators are
   `ufs_alloc.c`. **1.10 was done before 1.8 deliberately** — `fgxfs` can
   write a real volume and act as an independent oracle, where 1.8's `mount(2)`
   would have registered an empty `vfssw[]` the plan itself called untestable.
   **What 1.10b also did was run vfs.mod out of bank, and that now blocks the
   campaign rather than merely pinching it.** The allocators cost 5,770 bytes
   of shipping code; the module is one 64 KB bank; the shipping side alone is
   now 54,893 of 65,536, and `kernel.nameiprobe = 1` no longer assembles at
   all.
   **Next, and scoped ahead of 1.10c: UFS becomes its own module**, on its own
   bank ordinal rather than crowding the shared one —
   `gen_modplace.py`'s `OWN_BANK` comment already argues that case ("a module
   that outgrows its bank mid-campaign is a rebuild of every module placed
   after it"), and 1.11-1.13 is the read path, the write path and directory
   ops. Moving `ufs_vfsops` and `ufs_alloc` out takes 7,789 bytes off
   `vfs.mod`, which brings `nameiprobe` back with 4,916 to spare, and starts
   `ufs.mod` at 21,892 with 43,644 free. The piece that does not exist yet is a
   module-to-module call path: `Mod_FindVtable` is a kernel routine with no
   `KSVC_`, so nothing has ever called from one module into another, and
   `ufs.mod` needs `bread`/`getblk`/`brelse`/`bwrite`.
   **The probes are not the problem and cannot be the solution** — all four
   gates default to 0, so the 54,893 contains no probe code; what they cost is
   gate space (41,364 across the four, mutually exclusive since 1.7b), and
   deleting them would remove the only on-target coverage those layers have.
   #169 carries
   the per-gate measurements and the plan.
   **1.11a (the in-core inode) is DONE and green**, on
   `feat/ufs-1.11a-inode`: `ufs_ifind`/`ufs_ihashget`/`iget`/`iput`, the
   allocator's in-core guards, `ufs_reclaim`, and the device-vnode reference
   `iget` takes and reclaim gives back. Four defects had to be closed under it,
   and three of them were larger than the issue that led to them.
   #173: a
   module's `&f` was a bare in-bank offset, so a vnode's ops vector stored by
   one module dispatched into another's bank — K&R A.7.4.2 says `&f` yields "a
   pointer to the ... function referred to", which a bare offset stops being the
   moment a second bank exists, so fcc gained `--module-bank`, `MOD_FN_PTR`
   cells stamped at `mod_init`, and an indirect call that reads the bank.
   #178: that call
   carried the callee's bank but not its **DBR**, and fcc reads every global,
   literal and runtime scratch DBR-relatively — so `ufs_reclaim`, dispatched by
   vfs.mod's `vclean`, ran in vfs.mod's image and got away with it only by
   touching no module-local data. Every vnode op 1.11b and 1.11c add goes down
   that path.
   #177: the boot
   console had been dead since `_LC_MapRam`, which maps language-card RAM over
   `$00:D000-$FFFF` for the life of the system with `$00:FDED` inside it — and
   `SYS_PANIC` is the one jump-table slot nothing ever re-patches, so every
   `kc_panic` in the VFS wandered instead of halting. That one is the
   instrument rather than the subject: none of #178's diagnosis was readable
   until it was fixed.
   #175 was the
   symptom that led to both, and its own bisection was right about every
   measurement and wrong about the cause.
   #172, the
   256-byte kernel stack, turned out not to be a blocker, but the margin is
   real and measured: the 1.11a chain fits with under 32 bytes to spare, where
   2.11BSD budgets `KERN_SSIZE` = 2 KB. Found alongside them:
   #171, a build
   that reported "no work to do" while two C files compiled to nothing.
   **1.11b (the read path) is DONE and green**: `ufs_getattr`, `ufs_read`,
   and `ufs_strategy` under them -- the logical-to-physical map that makes the
   buffer cache work for FILES rather than only for devices, and the piece
   `vfs_bio`, `bgetvp` and `bio_strategy` had each been written against without
   its existing.  `struct vattr` arrives with it, and two entries join the
   module ABI (`uiomove`, and `biodone` for the hole alone).  Under it,
   #180: fcc
   decayed an array member one `.` hop past an arrow only for `char` and `int`,
   so `ip->i_addr` pushed two bytes where a pointer belonged and every argument
   after it shifted -- K&R A.7.1's exception list does not reach an array that
   is the RIGHT operand of `.`, and the element type is not among the
   conditions.  **1.11c (the name lookup) is DONE and green**: `ufs_lookup`
   reduced to the LOOKUP operation, `ufs_readdir`, and `dir.h` -- which is
   2.11BSD's `struct direct` and not Reno's, because Reno opens it with a
   32-bit `d_ino` and the header is six bytes here against eight there.  The
   format was measured off the volume, not assumed: it is the VARIABLE-LENGTH
   one -- `d_ino`, `d_reclen`, `d_namlen`, then the name padded to a 4-byte
   multiple -- and not 2.11BSD's older fixed 16-byte `direct` either.  Probe
   cases 820-854 assert the search, `.`, `..`, the ENOENT miss and the whole
   root directory read as bytes, against what `fgxfs ls` put there.
   #183 held it
   for two sessions and was not the filesystem: `_Probe_Drive` moved S off page
   1 while `mod_init` still had a live frame at the top of it, and page 1
   belongs to emulation-mode firmware -- four kernel bounce sites, and every
   interrupt, because the ROM's handler switches to emulation mode.  The probe
   passed, logged `ufs: ok`, and returned into `FGX_SYSVARS`.  The general
   invariant is still open as
   #185.

   **1.12a (the block write core) is DONE and green** on
   `feat/ufs-1.12a-write`: `ufs_write`, `ufs_fsync`, `iupdat`, `ufs_iencode`
   and the allocating half of bmap (`ufs_bmapx`, with `ufs_bmap` left as the
   read-only door onto the same descent so no 1.10c caller moved). The
   allocation arms are 2.11BSD's `bmap` rather than Reno's `balloc`: Reno's is
   half FFS fragment management and this volume has no fragments. Probe cases
   860-900 assert it, every one of them verified with a RAW `kc_blkio` read
   under the buffer cache -- because the failure this increment can actually
   have is a write path that does nothing, and that one leaves fsck clean and
   passes any test that reads its own writes back through the cache. Five
   mutation arms; two of them found defects in the probe rather than the code
   (a case that could not fail because the buffer it needed evicted was still
   resident, and a mutation that was inert because the recycled buffer already
   held zeros).
   **What 1.12a also had to do is split the probe across two module banks.**
   ufs.mod is one 64 KB bank; at the commit before, the shipping module was
   29,372 bytes and `kernel.ufsprobe = 1` added 31,915 for 61,287, leaving
   4,249 -- and 1.12a's *shipping* code alone is 4,612, which put the
   single-gate build over before a write case existed. That is
   #169's
   prediction arriving. The seam is the MOUNT: `ufs_probe.c` keeps the volume
   as blocks (superblock, allocators, bmap) and the new `ufs_vnprobe.c`
   (`kernel.ufsvnprobe`) takes everything that needs a `struct mount`. Both
   halves now sit near 48 KB with 17 KB free, which carries 1.12b and 1.12c.
   `vfs.mod` had already done this twice -- `vfs.s:246-261` is the record --
   so the shape was in the tree, not invented here. `tools/tryprobe.sh` takes
   the gate as its argument (`sh tools/tryprobe.sh ufsvnprobe`).
   Filed under it:
   #188, the
   `$01FF` firmware bounce window -- a global singleton whose only guarantee
   is a remark in `block.s` about SmartPort I/O not yielding, which 1.12's
   sleeping paths are what break.

   **`ufs_readlink` landed with it** -- Reno's is one line (it forwards to
   `ufs_read`, because a symlink's target IS the file's contents on this
   format) and it needed nothing 1.12a did not already have. Probe cases
   901-911 build a real `IFLNK` inode, write its target through `VOP_WRITE`
   the way Reno's `ufs_symlink` does after `maknode`, and read it back both
   raw and through `VOP_READLINK`. `ufs_symlink` itself is 1.12c (it needs
   `maknode`), and **namei must be taught to FOLLOW them** -- Reno's
   `vfs_lookup.c:281-290`, the `FOLLOW` flag against a `VLNK`, the re-prepend,
   `ni_loopcnt`/`MAXSYMLINKS`/`ELOOP`. FGX's `vfs_lookup.c` already carries the
   flags and the counter and says the arm is missing only because "nothing here
   can produce a VLNK vnode yet"; 1.12a is what stops that being true, and its
   note at `:119-136` warns that one nameidata pathname buffer per slot is not
   enough once a restart can happen.
   **A port audit against the vendor source found one defect and two silent
   drops in 1.12a's own code**, which is the standing rule earning its keep
   again: `iupdat` tested `IMOD` alone where both upstreams test all four dirty
   flags, and `ufs_itimes` declines to set `IMOD` when the clock cannot be read
   -- so on a machine with an unset RTC every write would have allocated blocks
   and never written the inode. Reno's `munhash` loop and its `b_resid` clamp
   had been dropped without saying so; the clamp is now carried, the loop is
   named as having no counterpart. **Still absent and consequential: the inode
   lock.** Reno's `iget` spins on ILOCKED/IWANT and every mutating op runs
   under it; writes exist here now and that lock does not, which matters most
   at 1.12c's directory ops.

   **1.12b (truncate and release) is DONE and green**: `ufs_itrunc` with real
   block reclaim, the recursive `ufs_indirtrunc` under it, `ufs_setattr` (the
   size arm; chown/chmod refused with EPERM until 2.6 rather than ignored) and
   `ufs_inactive` -- which is what gives an unlinked-but-open file its blocks
   back at the last close, and where 1.12a's temporary unconditional `iupdat`
   came back out. Probe cases 920-960; six mutation arms, all red (931 the
   reclaim leak, 951 the stale buffer, 946 the unzeroed tail, 957 the unlinked
   file keeping its blocks, 930 the indirect walk, 954 a silently-ignored
   chmod). A seventh finding came out of them: the case *written* for
   `vinvalbuf` could not fail, because `ufs_write` clears a freshly allocated
   block's buffer anyway -- only a HOLE, which no write ever touches, exposes a
   stale one.
   **It needed two new module-ABI entries and one fcc fix.** `vinvalbuf` and
   `vgone` join `VFSCORE_*`: itrunc must drop the cached buffers of blocks it
   frees, and inactive must get a freed inode off the hash before its number is
   reissued. In fcc, storing through `p->structfield.longarray[i]` was an
   artificial reject -- the arm took `int` and `char` elements and stopped --
   which K&R settles in two sentences: A.7.3.3 makes `p->arr` a non-lvalue
   *because* it is an array, so the subscript decays it and A.7.4.3's
   indirection is "an lvalue if the operand is a pointer to an object of
   arithmetic" type, saying nothing about the element. Fixture
   `M37/arrfieldlong`, three codegen arms red; the libc piles came back
   byte-identical, only their fingerprints moving, which is what says the
   change is additive.
   **And the probe split a second time**, to `kernel.ufswprobe`: 1.12b's
   shipping code is 9,778 bytes (ufs.mod 34,283 -> 44,061) and the vnode gate
   went over the bank again. The seam is reading versus writing. Three gates
   now, mutually exclusive, `sh tools/tryprobe.sh [ufsvnprobe|ufswprobe]`.

   **1.12c-a (the directory-entry layer) is DONE and green**: `ufs_lookup`'s
   CREATE/DELETE slot bookkeeping, `direnter`, `dirremove`, `dirrewrite`,
   `blkatoff`, `maknode`, `ufs_create` and `ufs_remove`. A name can be created
   and removed. Probe cases 968-1037 in `dirguard`; nine mutation arms, all
   red at the case written for the property.

   **The probes had to leave ufs.mod to make that provable.** At 1.12c-a the
   shipping side reached 50,992 bytes of the bank and two of the three gates
   stopped assembling; a fourth split would have bought one increment. So test
   code got a bank ordinal of its own -- `ufsprobe.mod`, 60,256 free at
   shipping -- and reaches back through a new `VT_UFSCORE`, with the shims
   GENERATED by `tools/gen_mod_imports.py` and the generator validated by
   reproducing the thirteen hand-written ones instruction for instruction.
   **Two defects came out of standing that up**, both filed in the commit that
   fixes them: the generator sized a SUBSET import table by its own length
   while `mod_init` copies the whole vtable into it, so 26 bytes went into 12
   and overwrote the `bread` shim's code; and the module-C compile loop never
   included the probe sources, so `ufs_probe.s` was an input to the module link
   with no producing edge and every probe `.c` edit was a silent no-op.

   **The directory probe is three hand-built layouts, not one.** ROOMY drives
   `ni_count != 0`, FULL drives `ni_count == 0`, and COMPACTABLE -- two
   adjacent dead records, neither big enough alone -- is the only shape that
   reaches direnter's compaction loop. `ni_count` means a SIZE on a create and
   a DISTANCE BACK on a delete, so each value gets a case in both routines:
   four separate pieces of code, and a case for one says nothing about the
   other. Every assertion is a raw block read on the record AND on its
   neighbour's `d_reclen`. `maknode`'s failure arm is reachable only through a
   full disk -- a hole is not an error, `ufs_strategy` returns a zeroed buffer
   for one -- so the free list is emptied in core for exactly one call, and the
   oracle is `sb_tinode` rather than `sb_ninode` because `ufs_ifree` has an arm
   that discards the number and still owes the count.

   **Two cases had to be rewritten because they could not fail**, and one
   ordering because it answered for its neighbours: "the directory still
   scans" was asserted with a lookup of `"."`, which `ufs_lookup` answers from
   the vnode it was handed without reading a byte; and with the lookup
   asserted before the raw read, BOTH arms aimed at the platter reported the
   lookup's case instead, because a record the scan cannot reach is invisible
   whether its bytes are wrong or its neighbour is still claiming its span.

   **1.12c-b is DONE and green**: `ufs_link`, `ufs_symlink`, `ufs_mkdir`,
   `ufs_rmdir` and `ufs_dirempty`, with `VOP_LINK`/`VOP_MKDIR`/`VOP_RMDIR`/
   `VOP_SYMLINK` added to `vnode.h` -- Reno's macros arrive with their callers,
   which is why they did not exist before. Probe cases 1038-1103 in
   `dirguard2`; ten mutation arms, all red at the case written for the
   property.

   **The audit found an unstated divergence in the whole layer, and a panic is
   what surfaced it.** In Reno every directory-modifying routine CONSUMES
   `ni_dvp`: `direnter` ends with `iput(dp)`, so does `ufs_remove`, `ufs_rmdir`
   releases both, and `maknode`'s error arm sets `pdir = NULL` precisely
   because direnter already gave the reference back. Nothing in this tree does
   -- the caller owns `ni_dvp` from namei to the end of the operation -- and
   1.12c-a never wrote that down. A faithful transcription of upstream's rmdir
   into it releases a reference the caller still holds, which the probe
   reported as `vrele: zero usecount` at the first refusal. The contract is now
   stated in `ufs_vnops.c` and `ufs_lookup.c`.

   **rmdir's two preconditions refuse DIFFERENT directories**, so each has its
   own case: the link count says nobody else names this directory, `dirempty`
   says it names nobody else. Written with only the `dirempty` half, a rmdir
   that dropped the count test entirely stayed green -- case 1103 is an EMPTY
   directory carrying a third link.

   **And two probe cases fired on a correct kernel.** They hardcoded where a
   record lands, but every create trims the record before it, so each later
   entry moves. `dirfind` walks `d_reclen` from the raw bytes instead, which
   asserts something the offset never did: that the chain ON THE PLATTER is
   walkable, independently of the kernel scan that also has to walk it. Fixed
   offsets stay in `dirguard`, where placement genuinely is the property.

   **1.12c-c (rename) is DONE and green**, which completes 1.12c: `ufs_rename`
   and `ufs_checkpath`, with `VOP_RENAME` added. Probe cases 1104-1181 in
   `dirguard3`; eleven mutation arms.

   **The case the section exists for is the one Reno's reasoning would talk you
   out of.** Upstream re-runs `namei` in step 3 because it dropped locks and
   another process may have moved things; this tree drops no locks and nothing
   else runs during the call, so that re-find reads like a concurrency
   artefact. It is not: step 2's `direnter` can compact the very block step 1
   recorded an offset in. The arm aimed at it then showed something sharper --
   deleting the re-find fires on the PLAIN rename, because `ni_dent.d_reclen`
   is stale too, so the re-find is load-bearing on every rename and not only
   on one that compacts.

   **Two vendor findings.** `checkpath` has two answers and they are different
   errors -- into ITSELF is `EEXIST` from its first test, into a DESCENDANT is
   `EINVAL` from the `".."`-walk -- so each needs its own case and its own arm.
   And the type-mismatch errnos read backwards: a file renamed onto a directory
   gives `ENOTDIR`, a directory onto a file gives `EISDIR`, identically in Reno
   `ufs_vnops.c:1035` and 2.11BSD `ufs_syscalls.c:959`. The errno names the
   SOURCE's unsuitability. **Not verified against POSIX** -- no copy of the
   text is in this tree and `rename(2)` is not a syscall yet; two independent
   BSDs agreeing is what it rests on, and the day it gets a man page is the day
   to check and put any divergence in BUGS.

   **A probe case broke this file's own rule and fired on a correct kernel.**
   The `".."` check read the block back with `bread(devvp, ...)`, but rename
   patches `".."` through the DIRECTORY vnode at logical block 0 while the
   device vnode holds a separate buffer for the same disk block -- the one
   `bmapnew` cleared at allocation. Two cache keys for one block are two
   different answers, and only one is what a PDP-11 mounting the volume would
   see. Verification goes under the buffer cache; that is what the rule is for.

   **AND THE BANK ARRIVED, AND WAS DEALT WITH -- THE UFS BANK SPLIT.**
   (It carried the label "1.13a" for one afternoon, which was wrong: **1.13 is
   `mknod` + IFCHR/IFBLK + the real `/dev`** and has not started. The split is
   infrastructure under the campaign, like apple/fgx#169 before it, and takes
   no deliverable number. Commit `6a2b8756a` still says 1.13a in its subject.) ufs.mod's
   shipping side had reached 60,211 bytes of 65,536 with 1.13 and 2.6 still
   ahead, and the escape used at 1.12c (moving the probes out) was spent. So
   the filesystem's own two halves separated: the BLOCK layer stayed in
   ufs.mod, the NAME layer -- the vnode operations and the directory scan --
   became **ufsdir.mod** on bank ordinal 4.

   | | before | after |
   |---|---|---|
   | ufs.mod | 60,211 used / 5,325 free | **33,234 / 32,302** |
   | ufsdir.mod | -- | **33,152 / 32,384** |

   **THE SEAM WAS MEASURED, NOT CHOSEN BY SUBJECT.** Every pile call between
   the eight translation units was counted: 42 cross from the name half into
   the block half through 11 entry points, and after two small moves --
   `clrbuf` to `ufs_bmap.c` beside its heaviest callers, and `iget` given the
   vnodeops table at load time instead of naming it -- **zero** cross the other
   way. One `MOD_FN_PTR` cell in the ops table still had to name a block-half
   function (`ufs_reclaim`, inode lifecycle); the generated shim carries the
   name, so the cell points at the shim and the shim pile-calls across, which
   is what a vector entry does anyway. The probes are untouched: they reach the
   name half only through VOP_ vectors, which carry the callee's bank since
   apple/fgx#178.

   **The load order is what the probe caught.** Written with `ufsdir` after
   `ufsprobe`, the block gate still passed and both vnode gates stopped at case
   711 -- `VFS_ROOT`, the first thing on the boot path that mints a vnode,
   refused by an `iget` that had never been handed the ops table. That refusal
   is the designed one: absent rather than half-present.

   **namei NOW FOLLOWS SYMLINKS, AND FILLS IN THE NAME IT WALKED.** Both gaps
   `vfs_lookup.c`'s header named are closed. The component goes into `ni_dent`
   in `dirloop`, which is what wires 1.12c's write path to a path resolution --
   until now the UFS probe filled it by hand, which is how a probe tells you a
   layer is not connected. And the symlink arm is Reno's, condition included:
   `(v_type == VLNK) && ((FOLLOW) || *ni_next == '/')` -- a link in the MIDDLE
   of a path is always followed, whatever the caller asked, because there is no
   other way to reach what comes after it. FOLLOW governs the last component
   only; it is the difference between `stat` and `lstat`, not a global switch.

   `struct nameidata` 154 -> 158 for a second pathname buffer: Reno's expansion
   needs two live at once whenever path remains after the link, which
   `fsparam.h` has said since 1.6a. Probe cases 1184-1204 drive a real path
   resolution over a real symlink on the scratch volume; four arms, all red at
   their own case, and the one that matters is `nofollowmid` -- drop the
   `*ni_next` half and every `cat /usr/link/file` in the system fails.

   Two smaller corrections from reading the same routine against upstream:
   `docache` is now killed for `wantparent` as well as DELETE (a caller that
   asked for the parent is about to change the directory), and a zero-length
   link is ENOENT rather than a restart on an empty path -- which the caller
   would resolve as "the directory itself", a symlink that silently means ".".

   **1.12d (the inode lock) is DONE and green.** `ufs_lock`, `ufs_unlock` and
   `ufs_islocked` fill the three vnodeops slots that were `ufs_nullop`, and the
   contract is upstream's: `iget` returns a LOCKED inode and `iput` unlocks and
   releases, so the `iget ... iput` pairs written against it from 1.11a onward
   start being true. They do not pair by COUNT -- `ufs_vnops.c` has three of
   one and eleven of the other -- because what pairs with `iput` is the lock:
   `namei` hands back `ni_vp` locked and an operation given one of those gives
   it back with `iput`. Two divergences, both stated at the site: `vget` does
   not take the lock (Reno's does; here `namei` locks each directory
   explicitly, so both would double-lock), and `ufs_checkpath` walks with
   references rather than locks, because this tree's `ufs_rename` re-finds its
   source with a direct `VOP_LOOKUP` and so holds the source's parent LOCKED
   where Reno holds it with WANTPARENT -- locking the ancestors would deadlock
   `mv a/b a/c/b` and not merely a corrupt volume.

   **It found eight things, all latent while the slots were nullops**: a
   lookup whose result was never released, on an entry whose `d_ino` is a
   placeholder naming the ROOT (a leaked root reference since 1.12c-c); two
   teardowns clearing the whole `i_flag` word one line before `iput`, now that
   the lock lives in that word; a rename source handed over locked, which
   deadlocks the TARGET lookup that follows it because for `mv d d/kid` the
   target's parent IS the source; probe sections holding a directory locked
   across a search that reaches it; and `vget` refusing a VXLOCKed vnode
   without sleeping -- honest while its only caller returned null on a
   refusal, a spin the moment one retried.

   **THE PROBE CANNOT SHOW WHAT THE LOCK IS FOR** and `lockguard`'s header says
   so first: it runs single-threaded at boot, so nothing in it fails when the
   exclusion itself is removed. What a single-threaded run buys instead is that
   every protocol error is DETERMINISTIC -- a lock taken twice is a certain
   panic, a lock never released a certain stop at the next acquisition -- and
   all five defects above reproduced on every run. Of eight mutations, four
   fired at the case they were aimed at (863, 865, 874, 878) and four were
   caught earlier by a panic naming the inode; which is which is recorded in
   the code rather than left to someone counting cases.

   Two panics name the inode rather than the fault, and that was measured:
   four on-target runs printed `locking against myself` and the fifth printed
   the number and named the site on the first reading. `ufs_ihashget` also
   gains a self-deadlock check upstream does not have -- Reno sleeps on ILOCKED
   before `ilock` can ask whose lock it is, so a process that `iget`s an inode
   it already holds waits forever on a channel only it could wake.
   `struct inode` is 100 bytes: `i_lockholder` is Reno's `i_spare0`.

   `tools/check_fs_sleep_invariant.py` grows a third class (ILOCKED/IWANT are
   neither buffer nor vnode state) and, with it, four files the checker had
   never looked at although three of them had been sleeping correctly since
   1.4b. `tools/tryprobe.sh` regenerates `ufsdir.mod`'s fn-ptr table, which it
   had not done since that module existed.

   **AND THE PROBE BANK IS FULL AT THE WRITING GATE**, which is a planning
   constraint rather than a remark: `ufsprobe.mod` built with
   `kernel.ufswprobe = 1` is **64,295 bytes of 65,536**, 1,241 free, against
   40,179 free at the reading gate. `lockguard` was written for the writing
   gate, would not link, and belongs at the reading gate anyway -- the lock's
   properties are `iget`'s and `VOP_LOOKUP`'s. The next thing that needs a
   case in `ufs_wprobe.c` will not fit, and the escape used twice already
   (move something out) is available once more: `dirguard3` alone is a third
   of that file.

   **1.13a (the on-disk device inode) is DONE and green.** `ufs_mknod` writes a
   device number, `iget` joins the alias chain from the mode it just read, and
   `ufs_getattr` reports `va_rdev` for the two types that have one. Where the
   number lives was READ rather than recalled: 2.11BSD overlays the address
   array with `u_short i_dummy; dev_t i_rdev` and copies it to the dinode with
   a straight `bcopy`, and a PDP-11 `daddr_t` is stored high word first -- so
   the device number is the **second 16-bit word of `di_addr[0]`** and the
   first is zero. Getting that backwards is invisible by every other means, so
   case 1316 reads the platter raw and the mutation that reaches it has to move
   BOTH accessors; moving one is caught earlier by the vnode's own `v_rdev`.

   **`spec_inodeops` is a THIRD vnodeops table**, not a refinement of the two
   that existed: a device file needs the DEVICE's read/write/ioctl and the
   INODE's getattr/inactive/reclaim, and neither existing table has both.
   Plain `spec_vnodeops` answers getattr with EBADF (`ls -l /dev` fails on
   every entry) and reclaim with a nullop, which is apple/fgx#175 reached from
   a device file. Its lock/unlock/islocked are `ufs_*`, which is only possible
   because 1.12d made them real. It is built in `ufsdir.mod`, so VFSCORE grew
   by eleven entries; building it in `vfs.mod` needs eleven in a direction
   nothing crosses today.

   **THREE VNODE DISPATCHES WERE WRONG and only a non-UFS leaf could show it.**
   `VOP_REMOVE` and `VOP_RMDIR` dispatched on `ni_vp` and `VOP_LINK` on the
   source vnode; Reno sends all three through `ni_dvp` (`sys/vnode.h:158-163`),
   because changing a directory entry is the DIRECTORY's operation. Every leaf
   was an ordinary UFS file until now, so all three were right by accident --
   the first `rm` of a device file panicked in `spec_badop`. `checkalias` also
   loses Reno's `vput`/`VOP_UNLOCK`: both exist to undo Reno's LOCKING `vget`,
   and this tree's does not lock.

   **A fourth probe gate**, `kernel.ufsdevprobe` -- the first split forced by
   the size of the PROBE module rather than the module under test. Cases
   1300-1349; ten mutations, eight landing where aimed.

   **AND THE GATE WAS GREEN OVER A REGRESSION FOR ONE COMMIT**, which is worth
   more than the deliverable. 1.12d's `vget` sleep broke `M37/vnodepool.c`;
   its golden moved and was regenerated, and the runtime oracle reported
   `238/238` because its broad arm REPLACED the changed-fixture set with a
   240-of-586 spread sample that did not include it -- while `gate.sh` grepped
   out the pass count and discarded the note saying 346 were uncovered. Both
   fixed: the fixtures whose goldens moved go in first, and the note is
   printed. A third of the same shape came with it -- no `git diff` form lists
   untracked files, so a brand-new fixture was skipped during exactly the
   session that added it. This is apple/fgx#87's family, second sighting.

   **1.13b (the character device switch) is DONE and green.** `spec_open`,
   `spec_close`, `spec_read` and `spec_write` dispatch onto the chardev
   registry, so a device file reaches the same drivers `syscall.s` reaches.
   Reno dispatches `cdevsw[major(dev)]`; FGX has one major and a registry
   indexed by registration order, so `v_rdev` IS that index -- the arrangement
   `spec_vnops.c`'s head has described since 1.7b and nothing could use. Five
   KSVC services and five `kc_` shims are the path, and it is **per byte**,
   because that is the registry's own shape.

   **The op ABI documented a design replaced before the first driver shipped.**
   `include/chardev.s` said each op takes `(fcb.l, buf.l, len.w)` on the stack;
   what arrives is `Y` = the minor and `A` = `_cdArgByte`. Reading
   `_Ttyv_Write` against it also found that an op may read MORE than its
   arguments -- it asks `_Sys_WrCdIdx` which line it is writing to, so a caller
   that dispatches without setting it writes to whichever line the last
   `write(2)` was for.

   **A direct-page cell was claimed and the map asked for it not to be.**
   `KSVC_CDLOOKUP` is handed a name in the caller's bank and `LDA [ptr],Y`
   needs the pointer in the direct page. Borrowing `_conFontStage` costs
   nothing and rests on "no interrupt path makes a chardev call" -- true today,
   cheap to break, and the shape of every shared-DP defect this tree has paid
   for. Three bytes at `$C3`; the free run is ten now rather than thirteen.
   Kernel bank: 2,062 free before, 1,932 after.

   **Ioctl and select still panic**, deliberately: ioctl's argument is a
   pointer into the caller's bank and select's is a per-process wait record,
   and making that marshalling decision before a caller exists is how a knob
   nothing sets gets built. No tty is driven either -- `/dev/tty` needs a
   controlling terminal, which is #60 and #117's question.

   **1.13c's HOST HALF is DONE and green**, and the deliverable turned out to
   be smaller than its name: `fgxfs` can now make device nodes, and `#76` was
   ALREADY CLOSED -- by MR !179 on 2026-08-14, at the chardev registry rather
   than by `vcount`. The paragraph that said 1.13c would close it predates
   that fix. `fgxfs mknod` writes `i_rdev` into the low half of `di_addr[0]`
   with the high half zero, which is what 2.11BSD's union over the address
   array (`h/inode.h:60-63`) and its `mknod` (`ufs_syscalls.c:220-231`)
   between them require, and the assertion reads those two bytes off the
   PLATTER because `addr[0] == dev` is true for either half-placement of a
   small number. The tool's `fsck` had been EXCUSING device inodes entirely
   (`if isdev(): continue`); 2.11BSD's own reaches the same place by
   arithmetic (`pass1.c:66-104`) and checks every address slot but the first,
   so a device inode carrying a stray block passed here and is CLEARED by the
   referee. Two arms, each red at its own case.

   **1.13 ALSO RETIRES `DTYPE_CONSOLE` AND ITS FOUR OPS ARMS** (the maintainer,
   2026-08-28, closing
   #197).  A
   descriptor is console-typed only when its FCB carries `FCB_FL_CONSOLE`, and
   nothing in userland can open one: the flag is set once at boot on the shared
   console pseudo-FCB `_Fcb_SeedStdFds' puts in every task's slots 0/1/2, and a
   task keeps one only while nothing has replaced it.  #121 gave the console a
   device NODE, so init opens the line for the console entry and every
   descriptor below it -- fd 0 included -- is a `/dev/console` vnode.  MEASURED rather
   than assumed: `TIOCGETP` is the discriminator, and a probe reporting its
   result reads `getp=0` both on the shipping kernel and on one with the
   console row's `FO_IOCTL` repointed at `_IoOp_Notty`, so a harness-launched
   program's descriptors do not reach the console row and NO FIXTURE CAN PUT A
   CONSOLE-TYPED DESCRIPTOR IN FRONT OF THOSE ARMS.  They stay until 1.13
   finishes the road, because they still serve init-lineage descriptors; the
   decision is recorded at `_kOpsConsole` in src/drivers/fs/fcb.s, where
   whoever deletes them will be standing.  New console work, if any is wanted
   later, is evaluated on its own rather than by keeping four unwitnessable
   arms alive for it.

   **AND THE REST OF 1.13c IS BLOCKED ON A SEAM NOBODY HAD BUILT.** A real
   `/dev` that userland can see needs `open(2)` to reach `namei`, and
   `syscall.s` contains no reference to `namei` or to any `VOP_` -- the VFS has
   been a complete, well-tested filesystem with NO CUSTOMER. That is deliverable
   1.7, and `src/kernel/main.s` had already said the seam "returns when namei
   gives the VFS a syscall-path customer, shaped by that customer".

   **1.7c (the file/vnode glue) is DONE and green.** `vfs_vnops.c`: `vn_open`,
   `vn_writechk`, `vn_rdwr`, `vn_read`, `vn_write`, `vn_close` and
   `vattr_null`, ported from 4.3BSD-Reno `kern/vfs_vnops.c`, plus the open-mode
   flags in `file.h` that `file.h` itself said 1.7 would bring. A FIFTH probe
   gate, `kernel.vnopsprobe`, cases 1400-1434 -- the first whose subject is not
   the filesystem.

   **THE ni_dvp CONTRACT IS NOT UPSTREAM'S, AND A LINE-FOR-LINE PORT
   DEADLOCKS.** Reno's `vn_open` does not release the parent on the create
   path because its `ufs_maknode` has already consumed it; this tree's
   `ufs_maknode` never touches `ni_dvp` and leaves it to the caller, as every
   routine in that layer does. So the `LOCKPARENT` lock survives `VOP_CREATE`
   and the next lookup into that directory waits for a lock this process owns
   -- `lockself 0012`, the panic naming the inode. Second sighting of this
   class; rmdir at 1.12c was the first.

   **A MUTATION LANDED GREEN BECAUSE ITS CASE COULD NOT FAIL.** The read
   section took the payload in two EQUAL halves, so every read was full,
   `count - uio_resid` equalled `count`, and a `vn_read` advancing by the
   amount ASKED FOR rather than MOVED passed everything. A third read at end of
   file is what makes the two formulas disagree. Six of seven arms landed where
   aimed on the first try; that one needed the case rebuilt first.

   `kc_blkio` takes the block number in TWO halves and passing the `daddr_t`
   whole compiles, shifting every later argument by a word -- and block 0 still
   reads, because zero survives being taken apart. Four runs before the first
   nonzero block asked the question. Also filed:
   #189, fcc
   rejecting `VTOI(vp)->i_size` while accepting `VTOI(vp)->i_number`.

   **1.7d IS LANDED IN FULL as of 2026-08-30, I1 through I4.**  This line said
   "Next: 1.7d" for a day after it was mostly done, and then "Next: I4" for
   eight days after that; the habit it records is that a status line goes stale
   in the direction of understating progress, so read the increment notes below
   rather than the heading.

   The syscall layer went in as six sub-increments. Five landed on main via
   !252: **I1** the `vfs_syscalls` bodies, **I2** every descriptor a
   `struct file`, **I2b** the open-file table carved at boot, **I2c** dispatch
   through `fp->f_ops`, and **I3** (`9665ce564`) `/dev` mounted with the
   `open(2)` prefix hook and bank-aware dispatch -- so userland has a real
   `/dev` today. **I4** is the sixth and closes the increment.

   **TWO DEFECTS THE RETIREMENT SURFACED AND DID NOT FIX**, filed with their
   evidence rather than written up here:
   #351, a
   `PANIC B3: interruptible sleep with SEF_STKLOCK held, pid 0' that
   `coldgarbage' reproduces on a RAM-poisoned boot and that is present at
   `origin/main'; and
   #352, closing a
   pty master not hanging up the slave's session -- measured identical through
   both spellings, so the parking comment that blamed the road was wrong about
   that one.

   **THE SYNTHESIZED DEVICE NAMESPACE IS RETIRED (2026-09-07),
   #311.**
   `Path_Resolve`'s prefix short-circuit is deleted, `Fs_Open`'s and
   `Fs_Stat`'s arms that read its result channel went with it, and init opens
   its lines as `/dev/<name>` -- real IFCHR inodes on the mounted root, reached
   by namei and served through `spec_*`.

   **IT WAS NOT TIDINESS, AND THE PARAGRAPH FURTHER DOWN THIS FILE THAT SAYS IT
   WAS IS WRONG.** "the sweep is tidiness the campaign does not depend on" was
   written on 2026-08-31 and moving ONE consumer across found six defects, five
   of them in the kernel and every one invisible for as long as a caller could
   be on either road:

   - virtual-console writes through `/dev` painted onto the LIVE console --
     the `_Vc_WriteEnter` bracket the write(2) dispatcher has carried since
     #129 was missing from the vnode road's `d_write` ops;
   - `ttyopen`'s session block read `_curTask`, a PER-PAGE cell, off the
     ENTERK-cached page and got 0, so a device opened through its node bound
     NO controlling terminal and no process group;
   - the pty master's `d_read` asked `pt_send` after the output queue instead
     of before it, so packet-mode flush/stop/start were never delivered;
   - a master's `TIOCFLUSH` answered ENOTTY where the registry spelling
     discarded the queue;
   - `spec_chwrite` counted a REFUSED byte as written -- silent data loss on
     every character device that can say no, measured as 400 writes accepted
     against 253 bytes delivered;
   - spawn file actions opened through `Fs_Open`, whose root hook passes
     FS_FREAD alone, so a spawned session got a read-only descriptor for the
     line it was about to write to.

   `isatty(3)` is the seventh and it is not in the kernel any more: SYS_ISATTY
   classified the DESCRIPTOR and could only ever say yes for the two FGX
   descriptor types that `/dev` being real retires.  It is libc's again, built
   on `ioctl(fd, TIOCGETP)` as BSD's is.

   With one namespace, `_Sys_Open` propagates every errno the root answers
   rather than EACCES alone -- the general case that was written, measured to
   break login, and backed out on 2026-09-07 because the namespace was still
   split.

   **I4, the `/ldev` sweep -- DONE; see the closing note below. #198 IS CLOSED
   and the stateful-device case is PAID.** Writing I3's suite case found
   #198 instead of
   testing it: three chardev ops did not honour the per-byte contract that
   `spec_chread`/`spec_chwrite` depend on. All three are fixed -- the first two
   at T2.2b, the third by the tty campaign's cdevsw `d_read` wiring -- and the
   suite case is the `devpty` fixture: a pty pair opened as `/dev/./ttyp0`,
   written at the master and read at the slave THROUGH THE VNODE, with the same
   byte on the same line through `/ldev` as its control.

   **The WRITE direction cost a stack move --
   #246, a sibling
   defect #198 never named.** `ttwrite` kept upstream's `char obuf[OBUFSIZ]`
   (100) on the kernel stack, and the vnode road is ~136 bytes deeper than
   `/ldev`, so a tty `d_write` reached 516 of the 512-byte per-task stack and
   reset the machine with no diagnostic. The buffer is per-task in the u-area
   now (`U_TtyObuf`), which gives all 100 bytes back on EVERY tty write rather
   than buying one road its margin by shrinking a chunk size: read and write
   together now sit at 420 of 512.

   **I4 IS DONE (2026-08-30), and it closed on three deliverables rather than
   the five this paragraph used to list.** What it promised and shipped:

   - **The door onto the character-device switch.** The switch itself was never
     missing -- `_Chardev_Ioctl` and `_Chardev_Poll` have dispatched
     `COPS_Ioctl`/`COPS_Poll` for the `/ldev` road since T2, and the tty bank
     reached `d_ioctl` through `_FarSh_CdIoctl`. What no MODULE could reach was
     any of it, so `vfs.mod`'s `spec_ioctl`/`spec_select` had nothing to call
     and `kc_panic`'d. `KSVC_CDIOCTL`/`KSVC_CDPOLL` are that door, 35 bytes.
   - **`ioctl(2)` and `select(2)` routed over the seam** for a far-ops
     descriptor. Both call sites had written down the condition for doing it
     and both were met; the ioctl one turned out to rest on a marshalling
     problem FGX does not have, since its ioctl numbers are 16 bits and carry
     no `IOCPARM_LEN` to size a copy with.
   - **The discipline reached THROUGH the switch**
     (#267), so a
     `/dev` tty answers sgtty. `_Io_CdThenTty` is upstream's `ptyioctl` order in
     the one place both roads pass.

   **`ls /dev`, `lseek` on a `/dev` descriptor and `stat` on one are NOT owed
   by I4 -- they are owed by the ROOT SWAP, and listing them here was a
   category error.** Each would be another per-syscall hook onto the `/dev`
   mount, and the tail is open-ended: of the path-taking syscalls -- `unlink`,
   `chdir`, `stat`, `mkdir`, `utime`, `rmdir`, `rename`, `ftruncate`,
   `opendir` -- exactly ONE is hooked, `open(2)`'s `_Sys_DevOpen`. Hooking a
   second leaves seven. The campaign plan is explicit that mounting UFS at
   `/dev` is the step taken "while root is still ProDOS ... with the root swap
   still ahead", and the root swap deletes every one of these hooks at once:
   when `namei` resolves all path syscalls, `/dev` is an ordinary directory and
   `ls /dev` needs no code. Building hook #4 is scaffolding the next phase
   demolishes.

   **#193 IS CLOSED**, so the truncate walk is now asserted at recursion level
   1 -- the level where fcc's row-stride miscompile lived and where, until
   2026-08-30, nothing looked. The case is cases 1370-1380 of `ufsdevprobe`,
   and its header records why it is in the device gate rather than the truncate
   one: `ufs_wprobe` has 571 bytes of its 64 KB module bank left and the case
   costs 1,864. Worth reading for its own sake -- the first draft was GREEN
   with the defect put back by hand, because a walk that scans downward
   recurses on a single live entry LAST and the clobber is never read back.

   **1.8 (`mount(2)`) IS LANDED except for its userland door (2026-08-30), and
   it turned out smaller than the plan's one line.** 1.8a -- `ufs_mountfs`,
   `ufs_statfs`, `ufs_unmount` and the `ufs_vfsops` vector -- was already done
   at 1.10a. 1.8b-1 gave the vector's `mount` slot a body and `getmdev` a
   device to resolve. 1.8b-2 is `vfs_mountat`, `mount(2)`'s body: the covered
   directory, upstream's refusals, a mount-table slot, and the cover wired both
   ways. **THERE IS NO `vfssw[]` AND NEVER WILL BE** -- Reno's `mount(2)` sets
   `mp->mnt_op = vfssw[type]` and dispatches through it, and `&ufs_vfsops` is
   an address inside `ufs.mod` that the far bank cannot call through
   (#178), so the
   type is VALIDATED and the filesystem's own mount entry is called directly.

   **No vnode field was added, and the increment was planned around adding
   one.** Reno's `v_mountedhere` is an ARM of the `v_un` union rather than a
   member, and `vnode.h` has carried that word since 1.4a with a note saying
   mountedhere would cast at the two or three places that touch it.
   `sizeof(struct vnode)` does not move, so `VNODE_FIXED`, `VFS_VNODE_SIZE`,
   the vnode pool arena and `vfslayout.c`'s boot assertion were all untouched.

   **1.8b-3 IS LANDED IN FULL, in three slices, and a path now crosses a mount
   in both directions.** **3a** taught `lookup` to descend `v_mountedhere` and
   `iget` to mark a root `VROOT` -- and the marker vfs_lookup.c had carried
   since 1.6b pointed at the WRONG PLACE, inside the `lastcomponent == 0` arm,
   where crossing only happens for components with something after them. Reno's
   `mntloop` runs before `nextname` for every component and updates `ni_vp`.
   With the loop in the marker's place `mnt/big` still resolves and
   `stat("/mnt")` quietly answers with the COVERED directory. **3b** is the
   `..` ascent through `mnt_vnodecovered`, plus a guard Reno does not need: FGX
   has a mount root with NO cover -- `/dev` is carved for a ProDOS-path hook
   and `rootdir` is zero, so upstream's `dp == rootdir` test never fires --
   and without it the boot reports `vref: zero usecount` and panics. **3c** is
   `unmount(2)`, which names the mount's own root exactly as Reno does, plus
   the `vflush` that had been ported and never called since 1.11.

   **Two defects were masking each other and both are closed.** `ufs_unmount`
   never cleared `um_mountp`, so every unmount burned one of `VFS_NMOUNT`
   ufsmount slots -- invisible while nothing could call it. It does not fail at
   the fourteenth mount, which is what made it worth measuring: a leaked slot
   still claims the DEVICE, so #269's duplicate-device scan refuses the very
   next remount of the same volume. Neither is visible without the other.

   **What 1.8 does NOT have is `SYS_MOUNT`, and the reason is a measurement.**
   Numbers 21 and 22 have been reserved for it since 2026-07-28. The thunk is
   the cheap kind -- 8 bytes of core bank each, the `_thunk_RtcRead` shape --
   but the core bank has 49 free, there is no `mount(8)` to call it, and
   `rootdir` is still zero, so an absolute mount path cannot resolve at all
   until root is a UFS filesystem. A door with no caller and no reachable
   argument is 16 bytes of the last 49 spent on something no test can turn red.
   It goes in with the root swap, or with whatever first needs it.

   **AND UPSTREAM ANSWERS IT, which the byte-count above does not.** The
   measurement is true and is the wrong reason. `mount(2)` does nothing special
   with its mount point in either tree: 2.11BSD's `smount` is
   `NDINIT(ndp, LOOKUP, FOLLOW, UIO_USERSPACE, uap->freg)` and then `namei`,
   and namei picks the starting directory the way it does for every path --
   `if (*cp == '/') dp = u.u_rdir ? u.u_rdir : rootdir; else dp = u.u_cdir;`
   (`ufs_namei.c:171-177`; Reno's `ni_cdir`/`ni_rdir` is the same shape).

   **There is no `at`-style mount in BSD**, so `vfs_mountat`'s `dvp` is FGX
   scaffolding and nothing more -- exactly what `vfs_openat` already says of
   its own: "when there is a per-process cwd, I3 passes it here and nothing
   else changes." Which makes `SYS_MOUNT` not a special case but the TENTH
   PATH-TAKING SYSCALL, waiting on what `unlink`, `chdir`, `stat`, `mkdir`,
   `utime`, `rmdir`, `rename`, `ftruncate` and `opendir` are waiting on: a
   namespace with a root and a per-process cwd. The rule for that is three
   paragraphs above and was written for the same situation -- "Building hook #4
   is scaffolding the next phase demolishes." Mount is hook #4. It lands with
   the root swap, with the other nine, and not before.

   **The witness is `mountprobe`**, a suite test and the first filesystem probe
   that is NOT behind a knob -- because it reads where the other four write. It
   covers the whole lifecycle now: mount, cross in, cross out, refuse while a
   vnode is held, unmount, remount, and leave nothing behind. It needed two
   fixture entries on the `/dev` volume (a directory to cover and a block node
   to name) and its own positive control on the block node's baked unit, since
   `mknod` runs on the host and cannot scan.

   **Three of its cases have no case number, and that is recorded rather than
   tidied.** Removing 3b's null-cover guard, or Reno's `vfs_remove` line that
   clears the cover on unmount, does not report a case -- it takes the machine
   down before `/dev` is even mounted, which the manifest catches as PANIC or
   as a missing klog line. The second is the rare divergence note in the OTHER
   direction: upstream frees the mount to the heap, where a stale cover points
   at freed memory, while FGX hands a STATIC SLOT back and a freed slot is a
   far more plausible-looking pointer.

   #269 came out
   of reading 2.11BSD's `mountfs` for that work and **is closed**: the same
   device could be mounted twice, because FGX ported the free-slot scan and not
   the duplicate-device scan immediately above it. Harmless while mounts are
   read-only; corruption at 1.12, when two in-core superblocks over one device
   both write back.

   **SUPERSEDED BY THIS FILE'S OWN LATER ENTRY, AND IT COST A SESSION A FALSE
   START.**  The gate below records "ARM 3 PASSES, AND PHASE 1'S GATE IS
   COMPLETE (2026-08-31)"; 2.1, 2.2, 2.3 and 2.4's root-swap half all landed
   after it.  The paragraph that follows is kept for its reasoning about the
   ordering, not as a statement of what is next.

   **NEXT IS PHASE 1'S GATE, AND THE ROOT SWAP IS NOT THE NEXT TASK.**  The
   handoff that opened 2026-08-31 said it was, and that reads past two things
   the campaign plan puts in front of it.  Every numbered deliverable from 1.1
   to 1.13 is recorded as landed in the paragraphs above -- with what is left of
   1.13c deferred to the swap by the reasoning three paragraphs up -- so "the
   rest of Phase 1" IS the gate.  And the root swap is Phase 2, which opens on
   **2.1, on-target `fsck`**, explicitly "ahead of the swap: FGX writes are
   deferred-sync and not crash-safe, and an unrepairable root is the failure
   mode that ends campaigns."  Two items stand between here and the swap, and
   neither is the swap.

   **THE GATE'S FIVE ARMS, MEASURED RATHER THAN ASSUMED (2026-08-31).**  The
   plan lists them: `mount -t ufs` survives a full read/write exercise; host
   `fgxfs fsck` clean; 2.11BSD's own fsck clean on the same image; an image
   written by 2.11BSD mounts and reads on FGX; and new tests that go red
   without this phase.  The last is DONE and has been for a while --
   per-component lookup across a mount point is `mountprobe` cases 19-28,
   `vcount`-driven last-close is `ufsdevprobe` cases 1324-1327 and
   `VOP_INACTIVE` reclaim of an unlinked open file is its 1335-1340.  The
   middle three were not started, and one of them was believed to be running.

   **ARM 2 IS NOW WIRED, AND WHAT IT REPLACED WAS A SENTENCE RATHER THAN A
   LOOP.**  `tools/gate.sh` says fgxfs is "the independent implementation every
   claim FGX makes about a volume it wrote gets checked against", and the plan
   says "attribution comes from the ORACLE, not from the disk image being
   unchanged".  Both were true of the TOOL and false of the LOOP: `fgxfs
   --self-test` ran on every gate and every volume in it was one fgxfs had made
   itself, so what the oracle established was that fgxfs agrees with fgxfs --
   the one thing the plan's own words rule out as evidence.  **The obstacle was
   the staging, not the tool.**  MAME opens a hard disk read-write and was
   pointed at `disk/ufsscratch.po` in the repo, so all four filesystem write
   probes put every byte back by hand -- which is why they are knobs, and why
   there was never a written-on volume to hand anybody.  Spindles stage into the
   per-test scratch directory now, as the boot disk already did; a staged volume
   is disposable, so a run may LEAVE its writes and be judged on them.
   `tools/mame_test/ufsfsck_check.py` is the verdict, wired as an ordinary
   `check_script`.  Measured both ways: truncating the scratch volume by 8 KB
   leaves all six of `mountprobe`'s existing assertions PASSING and fails on the
   oracle alone, so the new check discriminates on the real path rather than
   riding on the others.

   **A SECOND SPINDLE WAS ALSO AN INPUT THE RESULT CACHE COULD NOT SEE.**
   `extra_hards` names a path, so the manifest bytes pinned the NAME and nothing
   pinned the CONTENT: rebuilding `disk/ufsscratch.po` to a different layout
   left `mountprobe`'s verdict cached against the volume it replaced.  Both it
   and the `/dev` volume are in the key now.

   **RUNNING THE WRITE PROBE FOR ARM 1 FOUND THREE DEFECTS BEFORE IT FOUND AN
   ANSWER, and the first two were this branch's own.**
   #272: 1.8b-3c
   gave `ufs_unmount` its `vflush`, and vflush opens with Reno's
   `panic("vflush: not busy")` against a `MNT_MPBUSY` that only `vfs_dounmount`
   publishes -- so `unmount(2)` was fine and the FOUR probes that dispatch the
   vector directly, on a mount of their own, all panicked before reporting a
   case.  Upstream puts the obligation on the caller (`vfs_busy`,
   `vendor/4.3BSD-Reno/kern/vfs_subr.c:102`), so the probes publish it
   themselves; `ufs_unmount`'s header named the precondition and still shipped
   the break, which is what auditing an entry point's callers rather than its
   increment would have caught.
   #273 is why a
   day and a green gate passed first: `tryprobe.sh` printed `NO VERDICT` and
   EXITED 0, its run step being the one step #184's "every step is checked"
   never reached.  Both are fixed and both were measured in both directions --
   `vnopsprobe` now reports `ufs: ok` with exit 0 where it panicked, and a red
   probe exits 1.

   **AND THEN ARM 1 ASKED ITS QUESTION.**
   #274:
   `ufswprobe` reaches its unmount and is refused EBUSY -- `ufs: BROKEN, case
   714` -- because it still holds a vnode from the filesystem it is unmounting.
   That is the condition `mountprobe` case 30 asserts on purpose, so the
   machinery is right and the probe is out of contract; measured as
   probe-specific rather than systemic, since `vnopsprobe` does the same mount
   and unmount and passes.  Nothing could have asked before: `ufs_unmount` had
   no `vflush` until 1.8b-3c, so a leftover reference cost nothing.

   **ARM 1 IS WIRED, and it cost a manifest key rather than any on-target
   code.**  The exercise had existed for increments -- write, fsync, readlink,
   truncate, setattr, create, link, symlink, mkdir, rmdir and rename across the
   five probe gates -- and what was missing was the second half of the plan's
   sentence.  It works despite the probes RESTORING the volume, because that
   restore is SEMANTIC rather than byte for byte: a completed run puts the free
   list and the counts back where it found them, so anything damaged OUTSIDE
   what the exercise meant to touch still shows.  Measured on two completed
   runs, `vnopsprobe` and `ufsvnprobe`: 305 used, 3,725 free, 1,020 free
   inodes, identical to a fresh `mkfs`.  **It is not self-sufficient and each
   manifest says so**: a run that PANICS before doing anything leaves a clean
   volume too -- not hypothetical, it is what #272 produced -- so the arm is
   worth something only beside the probe's own `ufs: ok` and #273's exit
   status.

   **#274 IS CLOSED, and the method is the part worth keeping.**  `dirguard3`'s
   directory-move case re-gets the moved directory to read `i_addr[0]` --
   `iget(mp, submade, &sub)` -- but `sub` already held the `dirkeep` taken when
   `mkdir` made it, so that is the SECOND reference, and `iget` hands its one
   back LOCKED (`ufs_inode.c:489`'s `VOP_LOCK`, the contract `iput` asserts).
   The release was `dirdrop`, a bare `vrele`: it returned one of the two and
   left the inode locked as well.  The leak is very likely older than the
   symptom, since nothing asked until 1.8b-3c gave `ufs_unmount` its `vflush`.

   **ASK WHICH GUARD, NOT WHICH INODE.**  Four builds went into instruments
   discriminating the busy vnode's inode NUMBER, and they produced a WRONG
   answer: the `switch` had cases for 2 and 5-32 and none for 1, 3 and 4, so
   three runs reported three different labels that could all have meant inode
   3.  A `switch` instrument is only as good as its case list, and a `default`
   arm carrying a range label lies about everything the list skipped.  One
   further build partitioned the file instead -- a temporary `busyafter(mp,
   base)` walking `mnt_mounth` between guards and returning a CASE NUMBER
   rather than panicking, so the probe's own reporting carried it -- and it
   named `dirguard3` on the first run.  Second trap, caught only by reading the
   diff before committing: removing that helper by cutting to the first blank
   line left its BODY orphaned at file scope, and the next build rejected it.

   **`ufswprobe` reports `ufs: ok` and `tryprobe` exits 0** -- the write gate's
   first end-to-end pass since 1.8b-3c -- and the volume it leaves is fsck
   clean, so arm 1 holds on the heaviest of the five probes rather than only on
   the two that write least.

   **ARM 4 HOLDS: FGX MOUNTS AND READS A FILESYSTEM A REAL 2.11BSD MACHINE
   WROTE.**  It is the only one of the five arms whose bytes this project did
   not lay down -- everything else is checked against `fgxfs`, an independent
   implementation but one written here.  The material was already in the tree:
   `examples/pdp11/2.11BSD_rq.dsk`, a real machine's 1 GB disk whose root
   filesystem starts at block 0, and the SAME machine and state as
   `tools/testdata/211bsd/` (35 root entries, root link count 15, which is what
   that machine's own `ls` reported the day those blocks were lifted).
   `tools/bsd211vol.py` carves it, reading the length from `fs_fsize` rather
   than baking it, because a 2.11BSD 32-bit field is stored HIGH WORD FIRST and
   reading 7,942 with `'<I'` carves 8 TB.  The probe is `bsd211probe`, cases
   40-50 in `dev_mount.c`.

   **IT REPLACES THE SCRATCH VOLUME RATHER THAN JOINING IT**, which is forced:
   a mount names a block NODE whose unit is baked at image-build time, and the
   `/dev` volume's sixteen inodes are all spoken for, so there is no `/dev/sd3`.
   **What only a foreign volume can assert**: `df` as that machine reported it
   -- 7,942 blocks less a 126-block i-list, 4,767 free, numbers FGX does not get
   to choose -- and a SYMLINK, `sys`, where nothing on `disk/ufsscratch.po` is
   one, so an IFLNK decoded wrongly had never been able to fail a mount-side
   case.  Measured discriminating, since a scan that finds nothing returns 0 and
   would pass like a clean run: expecting inode 677 instead of 676 reports CODE
   AE, and reaching that case at all means the volume was found by superblock,
   mounted, agreed with both the scanned unit and that machine's `df`, and was
   walked into.  Far bank 4,167 free before, 2,087 after.

   **IT STAYS LOCAL, AND THAT IS DECIDED** (the maintainer, 2026-08-31): the volume is
   not vendored, `bsd211probe` is not in `GATE_TESTS`, and if a gated foreign
   volume is ever wanted the answer is to PURPOSE-BUILD a filesystem image
   rather than to carry this one.  The measurement that was offered against it:
   7.76 MB raw, 3.44 gzip, 2.39 xz, against a largest tracked file of 1.35 MB
   and a 569 MB `.git`.

   **THE ARM IS RETIRED (the maintainer, 2026-09-08): "we know the feature works."**
   `bsd211mnt` and the build edge that carved the volume are gone; the volume
   had no other reader and the manifest was never in `GATE_TESTS` and skipped
   by default, the source disk being gitignored.  WHAT WENT WITH IT, stated so
   it is not rediscovered as a gap: this was the ONLY check whose bytes were
   laid down by 2.11BSD itself -- every other filesystem arm is judged against
   `fgxfs`, an independent implementation but still one written here.
   `tools/bsd211vol.py` stays, with its `--self-test`: the procedure is
   `python3 tools/bsd211vol.py SRC.dsk disk/bsd211root.po`, then attach it
   through a manifest's `extra_hards` as unit 1.

   So this arm is evidence held on the development machine rather than standing
   coverage, and the tree is arranged to make that safe rather than fragile.
   Verified by hiding `examples/pdp11` and regenerating: `gen.py` emits no build
   edge, and the build completes.  `disk/bsd211root.po` is untracked
   (`.gitignore:365`, `disk/*.po`), nothing but `bsd211probe` names it, and
   `run.py` fatals on a missing `extra_hards` image -- so running it without the
   volume is loud rather than a silent skip.  What a fresh clone loses is arm 4;
   what it does not lose is the ability to build and gate everything else.

   **ARM 3 PASSES, AND PHASE 1'S GATE IS COMPLETE (2026-08-31).**  2.11BSD's
   own `fsck`, run on the 11/70 at host `bsd` against a volume FGX wrote:

       ** Phase 1 - Check Blocks and Sizes   ** Phase 4 - Check Reference Counts
       ** Phase 2 - Check Pathnames          ** Phase 5 - Check Free List
       ** Phase 3 - Check Connectivity       3 files, 305 used, 3725 free

   No problems in any phase, and **`305 used, 3725 free` is what `fgxfs` reports
   for the same volume** -- two implementations forty years apart agreeing on
   the accounting.

   **THE `FILE SYSTEM WAS MODIFIED` LINE COULD HAVE HIDDEN A SILENT REPAIR, so
   the superblock was brought back and diffed.**  Exactly ONE byte differs: the
   high half of `fs_flags` (offset 444-445), which is the clean marker.
   `fs_tfree`, `fs_tinode`, `fs_nfree`, `fs_isize`, `fs_fsize`, `fs_time`, the
   100-entry inode cache and all 200 bytes of the free list are byte-identical.
   That is the result rather than the summary line: **every field fsck would
   have rewritten had it disagreed with FGX's accounting, it left alone.**

   The volume was the one `ufswprobe` left after its write, truncate, symlink,
   directory and rename exercise -- carried over by `tools/pdp11put.exp`, fscked
   with `-y`, and removed afterwards.  It went to `/usr/tmp` and not `/tmp`: `/`
   there has 4.7M free against `/usr`'s 291.6M, so a 4 MB file in `/tmp` is a
   risk to a working system rather than a tidy temp file.  No SIMH was involved.

   **AND THE LIVE MACHINE'S fsck IS NEWER THAN `vendor/2.11BSD/`**
   (#277).  The
   vendored source contains no "Marking file system clean" and does not mention
   `fs_flags` at all, so the byte that changed is written by a feature the
   snapshot does not have.  The porting source of truth and the conformance
   oracle are different vintages, and anyone reading fsck's behaviour off
   `vendor/` will be surprised by the machine.

   **ALSO LEARNED, and it is the constraint on any future transfer:** 2.11BSD's
   `uncompress` refuses a 16-bit stream -- "compressed with 16 bits, can only
   handle 12 bits" -- because that code table does not fit a PDP-11's 64 KB data
   space, and macOS `compress` defaults to 16.  `-b 12` costs 100 KB against
   52 KB on a 4 MB volume, which is nothing next to what it buys.

   **THE ORACLE REFUSED THAT VOLUME, AND UPSTREAM SETTLED IT**
   (#271, CLOSED).
   `fgxfs fsck` called the real 2.11BSD root inconsistent -- "fs_tinode says
   1373 free inodes, the i-list holds 1397" -- and 2.11BSD's own fsck does not
   make that check.  `pass5.c` validates the free BLOCK count and repairs it;
   its inode half `ifreechk()` only checks that the superblock's cached
   free-inode LIST holds no allocated inode.  `fs_tinode` appears once in the
   entire tool, in an `if (debug)` printf at `main.c:234`, and is never written
   -- `makefree()` rebuilds the free list and leaves it alone.  The KERNEL
   treats it the same way: `ufs_alloc.c:170` decrements it in ialloc, `:292`
   increments it in ifree, `ufs_syscalls2.c:76` hands it to statfs as
   `f_ffree`, and nothing reads it to DECIDE anything, ialloc finding a free
   inode by scanning.  It is a `df` statistic, which is why no repair tool
   touches it.

   So it is a note now, printed under `verbose` as upstream prints it under
   `debug`, and neither fails a run; the comparison stays because this tool's
   own writers keep the field exact, so a disagreement on a volume FGX WROTE
   would mean FGX's ialloc/ifree had stopped keeping 2.11BSD's statistic.  The
   real root fscks clean end to end.  **The self-test gained the two arms whose
   absence hid this**: every volume in the nine mutation arms is one the tool
   made and maintained, so `fs_tinode` is exact by construction there and a
   rule stricter than upstream cannot show.  The new arm bumps `fs_tinode` and
   requires CLEAN -- the mirror of the `fs_tfree` arm beside it, which must
   FAIL -- and a second fscks the whole real volume, saying so in the summary
   line when the image is absent.

   **2.2 IS DONE: STAGE 1 IS ONE SECTOR AND FINDS STAGE 2 WITHOUT A LOOKUP.**
   The disklabel owns sector 1 -- `vendor/2.11BSD/usr/sys/h/disklabel.h:53`,
   `LABELSECTOR 1`, `LABELOFFSET 0` -- so the boot area available to code is 512
   bytes rather than the 1,024 the loader had been self-loading into.  What came
   out to pay for it was the whole ProDOS half of stage 1: the volume-directory
   scan, the sapling index walk, and the inline SmartPort call that fetched
   block 1 in the first place.  What went in is a descriptor holding a COUNT
   and then that many 24-bit device block numbers, which
   `tools/bake_stage2.py` patches into the sector once the image is built.
   The loader is **348 bytes**, and `build/loader_padded.bin` is 512.

   **UPSTREAM DOES FIT A REAL LOOKUP IN 512 BYTES, AND READING IT IS WHAT MAKES
   THE DIVERGENCE HONEST.**  `examples/2.11BSD/usr/sys/mdec/rauboot.s` `iget`s
   `ROOTINO`, walks the root directory comparing `d_namlen` then the name, and
   reads the four direct addresses of the inode it finds -- in a file whose own
   header says `assembled size must be <= 512`, and whose comment names the
   price it paid to get there: *"all options of reading an alternate name or
   echoing to the keyboard had to be removed to make room for the code which
   understands the new directory structure on disc"*.  That is a PDP-11's 512
   bytes against a 65816's, and this tree's own measurement of that ratio is
   ~2.5-3x, so the same walk does not fit.  The campaign plan dropped it by
   decision rather than by discovery, and the loader now cites both the plan and
   `rauboot.s` at the point of divergence.

   **STAGE 2 STAYS A REAL FILE, WHICH IS THE PART THAT IS ABOUT fsck RATHER THAN
   ABOUT BOOTING.**  Blocks owned by no inode and absent from the free list are
   exactly what fsck classifies as missing and salvages back into the free list,
   so a reserved boot range would be reclaimed and then handed out -- by the
   on-target fsck 2.1 just landed, or by a real 2.11 system fscking an FGX
   volume, which is goal 2.  So the baker resolves the file THROUGH the
   filesystem.

   **AND THE PLAN'S CONTIGUITY SENTENCE IS WRONG, WHICH A MEASUREMENT CAUGHT
   BEFORE A UFS VOLUME EVER BOOTED.**  2.2 as written says stage 2 is "a REAL
   FILE whose blocks `mkfs` guarantees contiguous", and the first cut of the
   descriptor was a start block and a count on the strength of it.  `mkfs`
   guarantees the opposite: it builds the free list with a rotational
   interleave -- `2.11BSD mkfs.c:214` defaults `f_m = 3` when there is no
   disklabel to read a step from, and `fgxfs` uses 2 -- so blocks leave the
   list every `f_m`'th and a fresh file is systematically NOT consecutive.
   Measured on a volume `fgxfs` made rather than argued: `/boot` got filesystem
   blocks **70, 72, 74**, and `/KERNEL` 76, 78, 80, 82 and on.  It held on
   ProDOS only because cadius happens to allocate a fresh volume in order.  So
   the descriptor is a LIST, which is what upstream does too -- `rauboot.s`
   walks the inode's four direct addresses one at a time rather than a run --
   and the bound is not contiguity but LENGTH: at most eight device blocks,
   4 KB, `NDADDR`, exactly what a 2.11BSD boot block can reach.  Over that
   FAILS THE BUILD: an unbootable image is worth less than a red build.

   **THE GUARDS ARE ASSERTED RATHER THAN OBSERVED, AND EACH WAS MADE TO FIRE.**
   In one sector the copy loop that moves the trampoline blob to `$0800` lives
   in the bytes it is overwriting -- free in the two-sector loader, where
   `LoadDone` sat at `$0B32` in a block the blob could not reach -- so
   `loader.s` carries `ERR TrampEnd/LoadDone` beside the existing
   `ERR TrampEnd/$0900`, plus one that keeps the whole file inside sector 0.
   Both new ones were mutated and seen to report.  `bake_stage2.py --self-test`
   runs eight arms, five of them inputs it must REJECT: an over-length file, a
   sparse one, a missing descriptor, a duplicated one, and a missing name.  Its
   accept arm bakes a list whose blocks are DELIBERATELY not consecutive, and
   its last arm runs on a volume `fgxfs` actually made -- the arm that would
   have caught the contiguity mistake, and which FAILS if that volume ever
   hands out a consecutive run, because then it could no longer show that a
   list is needed.  **The boot itself was mutated**: one wrong entry in the
   middle of the list takes `smoke` from 1 passed to 0 passed, so the loop is
   walking every entry and the suite's oldest green is discriminating on the
   new mechanism rather than riding on the rest of the machine.  A zero count
   is refused in the loader as well -- the descriptor ships as zeros, and an
   unbaked image would otherwise read block 0, itself, into `$2000` and jump
   into it.

   Measured on both images, which is how the baking is known to be per-image
   rather than a constant that happens to work: `disk/fgx.po` bakes blocks
   8,822-8,827, `disk/fgx-floppy.po` 336-341.  The baker's `--ufs` arm takes the
   same list off the inode through `fgxfs`, so 2.3 has its extent already.  The
   ProDOS reader in it is small, read-only and temporary -- it goes at 2.4, when
   `disk_src` staging moves to `fgxfs` entirely.

   **2.3 IS DONE: STAGE 2 READS 2.11BSD, AND THE WHOLE BOOT CHAIN RUNS OFF A
   UFS VOLUME.**  `ufs_probe` picks the reader once from the volume itself --
   device block 2 is the ProDOS volume directory AND the first half of the
   superblock, so one read answers it, and the test is a POSITIVE ProDOS one
   (zero prev-block pointer, storage-type nibble `$F`) because `fs_isize` is
   never zero on a volume `mkfs` made.  `walk_path` and `LoadDispatch` became
   two-instruction dispatchers on that flag, so **every caller above is
   unchanged**.  Underneath: `itod`/`itoo` from `h/fs.h:87-88`, the 64-byte
   dinode from `h/inode.h:74-102`, variable-length dirents from `h/dir.h:25-30`
   with `DIRBLKSIZ` 512 and the guarantee that an entry never straddles one,
   and four direct addresses plus a single indirect -- which is what
   `rauboot.s` reads and more than a 58 KB kernel bank needs.

   **ONE LOOP AND NOT TWO.**  The block loop, the end-of-file guard
   #218 bought,
   the sparse-block zero fill
   #225 bought and
   the multipass MVN are shared; only the block NUMBER is behind a call.
   Copying the loop would have been the shorter diff and would have left two
   places for those two fixes to rot in.  The loop counts DEVICE blocks, so a
   1024-byte filesystem block is simply two of them.  Stage 2 is 3,645 bytes of
   its 4,096 and stage 1 is 410 of its 512.

   **THE DEFECT WORTH RECORDING IS THE ASSEMBLER'S, NOT THE FILESYSTEM'S.**
   `LDY #UFS_DI_ADDR+4*UFS_NDADDR` reads `di_addr[64]`, not `di_addr[28]`:
   **Merlin32 evaluates strictly left to right with no operator precedence**,
   so `12+4*4` is `(12+4)*4`.  Measured with a two-line fixture rather than
   inferred -- `LDY #12+4*4` emits `A0 40`.  It assembled clean, read past the
   64-byte dinode, found a zero, and **a zero address is a legal HOLE**: the
   kernel loaded its four direct blocks, zero-filled the other fifty-four, and
   the machine reset into ROM with a blank screen.  A second bug rode with it
   -- `ufs_blkno` kept its half-of-a-block flag in the same scratch byte
   `ufs_bmap` uses for the indirect index -- and had the same reach, everything
   past the fourth block.

   **WHICH IS WHY THE TEST ASSERTS MEMORY AND NOT PIXELS.**  A blank screen was
   the symptom of BOTH the working and the broken reader, because the root
   filesystem is ProDOS until 2.4 and a kernel booted from UFS halts for want
   of a root either way.  `ufsboot_check.py` compares two windows of the LIVE
   kernel bank against `bin/fgx.bin`: one ~1 KB in, inside the first direct
   block, and one at byte **53,560**, which can only be right if the indirect
   block, its half-swapped `daddr_t` and the MVN all worked.  The shallow arm
   is kept precisely because **it passed the broken reader** -- it is the
   control that says the deep one is measuring something the other cannot.  The
   third arm is the halt: reaching `_Halt` in the kernel bank says six path
   walks, four file loads, the module pre-stage and the handoff all ran, where
   reaching ROM is what a broken load looks like.  Measured discriminating by
   putting the Merlin32 expression back: `kdeep` reports byte 53,560 zero and
   the CPU in bank `$00`.  The checker's own six-arm self-test mutates each.

   `tools/make_ufsboot.sh` builds the volume with `fgxfs` -- stage 2, the three
   kernel banks, `/ETC`'s two config files and the modules `preload.conf` names
   -- and **fscks it with the oracle before shipping it**.  The paths stay the
   ProDOS ones on purpose: renaming the tree to BSD conventions is 2.4/2.5
   work, and keeping them identical means the only variable under test is the
   filesystem.  `ufsboot` is in `GATE_TESTS` for the reason `floppy_boot` is --
   nothing else runs stage 1's baked list or the second reader at all.


   **2.4 IS DONE IN ITS ROOT-SWAP HALF: A 2.11BSD VOLUME BOOTS ITSELF
   (2026-09-01).**  `disk/fgxufs.po` mounts its own root, reads `/sbin/init`
   off it and reaches a shell.  Four commits: the root open, the far-bank
   reader, an errno defect the first two uncovered, and the module loader
   moving down past the seam.  **The number is doing double duty** -- the plan's
   2.4 is "build system: `disk_src` staging moves to `fgxfs`", which is
   untouched, while the handoffs have been calling the root swap 2.4 as well.

   `Fs_Open` gained a hook at `@fo_notDev` that asks the mounted root about an
   absolute path and falls through untouched on a miss, so a ProDOS machine is
   unaffected and this can only add a capability.  Then `Load_Binary` stopped
   crossing banks to read: it is compiled into the far bank and so is the VFS,
   and **BSD does not read an executable through a descriptor at all** --
   `vendor/4.3BSD-Reno/kern/kern_exec.c:156` is `vn_rdwr(UIO_READ, vp, ...,
   UIO_SYSSPACE, ...)`, on the vnode, with no fd in it.  Reading in the bank the
   VFS already lives in cost ZERO core bytes; routing `Fs_ReadN` back out of the
   core instead was built and measured at 74 against 33 free, and that patch is
   parked at `docs/history/plans/attic/frn-far-routing.patch`.

   **AN ERRNO THAT HAD BEEN LYING SINCE apple/fgx#14 IS FIXED
   (#289).**  Three
   error tails saved an errno in `_shTmp0`, called `Fs_Close`, and read
   `_shTmp0` back -- and `Fs_Close` reaches `_Fcb_LookupPtr`, whose scratch cell
   IS `_shTmp0`, which `fcb.s:628` warns these callers about by name.  Every
   failure through them reported EBADF.  The FGX2 tails were fixed at #14 and
   these three were missed; `loader.s:862` records the shape ("the lie was
   consistently EBADF, which is Fs_Close's own error").  It cost this session a
   wrong diagnosis before it was found: sentinels on both of `Fs_ReadN`'s error
   arms, verified present in the assembled image, still reported `$09`, and only
   fixing the tails made the same boot report the sentinel.  **THE HONEST AND
   DISHONEST VALUES COINCIDE HERE** -- the real errno is EBADF too -- so a test
   asserting the VALUE cannot discriminate and only the sentinel run could.

   **`vfs_read`'s `len` IS A SIGNED 16-BIT int** and `rwcommon` refuses a
   negative one with EINVAL before reading a byte, so a segment over 32,767
   bytes -- which `/sbin/init` has -- was rejected outright.  That is what
   turned the boot's errno from EBADF to EINVAL the moment the reads began
   working.  Clamped at 32,512 and returning short, which is safe because
   `Fs_ReadN` moves at most 512 bytes per call and its callers have always
   looped.

   **`ufsboot`'s HALT ARMS ARE REPLACED, NOT INVERTED**, as its own description
   said they would have to be.  Both read DIRECT PAGE cells at a baked bank-0
   address, sound only because the page AT A HALT is `$0900`; on a running
   machine that page belongs to whichever task the sample frame caught, so an
   inverted arm would go red on scheduling.  The claim moved to the screen,
   where `/etc/rc`'s own "Starting network..." asserts that init was found on
   the root, read, execve'd and ran.

   **WHAT DOES NOT WORK YET, MEASURED RATHER THAN ASSUMED.**  `_Fs_RootOpen` has
   exactly ONE call site and `Path_Resolve` still has nine, so `open(2)` reaches
   the root and `stat`, `chdir`, `unlink`, `rmdir`, `rename`, `utime` and
   `opendir` do not -- which is why the UFS shell comes up as `/bin/sh` (`#`)
   rather than tcsh (`fgx#`).  And **`Mod_LoadConf` loads nothing on that
   volume**: `Mod_Load` reads through `Fs_ReadN`, which answers EBADF for a root
   descriptor, so the four pre-staged modules come up and the six in
   `modload.conf` do not.  The console says so without a debugger -- `fs: /dev
   SELF-TEST FAILED CODE 09`, `dhclient: no network interface`, `inetd:
   telnet/tcp: socket: Function not implemented`.  **Moving the call is not the
   fix**: `Fs_ReadN`'s refusal does not depend on when it runs.  The fix is
   userland, which is where 2.11BSD and NetBSD both run `modload(8)` from, and
   the increments are planned in
   `docs/history/plans/2026-09-01-userland-modload.md` -- A1 first, because A1
   IS campaign 2.5 and 2.5 deletes the `/dev` mount that is the real reason the
   loader cannot move past init.

   Two work items opened on the way:
   #289 above, and
   #290, where
   `modimage` declares two module-bank regions and there are five ordinals, so
   it cannot witness whether a module loaded at all -- it skips an ordinal it
   has no dump for and then reports it "not found loaded".  That has to be
   fixed before any test can prove the userland loader works.
   **#270 IS CLOSED, AND ITS CAUSE WAS A MISSING FIXTURE.**  `b3pty`'s workload
   IS `/testbin/logintest`, and logintest's LT11 requires `ttyp1` NOT to be
   marked secure -- which the shipped image stopped providing on 2026-08-29,
   when both pty lines were marked secure so a second concurrent telnet session
   could be root
   (#252). Only
   the logintest manifest staged the fixture that makes ttyp1 insecure, so the
   SAME BINARY ON THE SAME DISK reported `LT11 OK` run as itself and `LT11 FAIL
   root-not-refused` run under b3pty.  The workload never reached its PASS
   line, so the tap had nothing to watch.  The fixture's own header states the
   rule: a fixture that needs a particular configuration should CARRY it rather
   than depend on a policy line somebody is free to change for unrelated
   reasons.

   **THAT UNCOVERED TWO THINGS NOTHING HAD BEEN ABLE TO SEE**
   (#276).  The
   `gettystk` tap was STALE -- "$1FF0 belongs to inetd, not getty" -- and is
   retuned by
   #248's SWEEP
   rather than by arithmetic, which matters because the arithmetic route
   failed: top-16 resolved to the right task and then tripped the checker's
   third requirement, no write from the owner's own DP, since the top of a
   freshly exec'd stack holds the argv frame the PARENT staged.  The sweep gave
   3,584 hits, 2,645 from pid 9's own DP, hottest at $2257.

   **AND THE ONE THAT MATTERS IS NOT WHAT ITS MESSAGE SAYS.**  `initstk`
   reports eight writes into init's live stack from another task's context, and
   the checker calls that "B3 is unsafe as designed".  The PC resolves through
   the core bank's listing to `src/kernel/process.s:1582`, inside
   **`_Fork_Restore`** -- the loop that copies a saved stack image back after a
   vfork child exits. FGX's fork is snapshot-shaped and the child BORROWS the
   parent's stack; init is the forking parent, the values written are its own
   stack base and base+$4D, and all eight come from one copy loop.
   `classify_write`'s own soundness argument names this as its breaking
   condition -- one context writing THROUGH A POINTER rather than only pushing
   -- so the model never enumerated it.

   **AND THE KERNEL ALREADY DOES.**  `SEF_STKBORROW` is defined for exactly this
   window, and `include/kernel.s` says so in the EQU's own comment: "it also
   covers `_Fork_Restore` for free, WHICH THE FIRST SURVEY MISSED: that routine
   writes the parent's stack from the CHILD's context, and it runs BEFORE the
   hand-back clear at both of its call sites, so the parent is still flagged
   ineligible while it happens."  Verified in `process.s` rather than taken from
   the comment -- `:1087` sets it, `:2320`/`:2869` restore, `:2440` clears under
   a comment stating the ordering outright -- and both edges are panic-guarded
   at `task.s:2326-2327`.  So the parent is not "a sleeping task": it has LENT
   ITS BYTES OUT and is marked unswappable for the duration, and B3 was made
   safe for this deliberately.  The checker's verdict line said the opposite and
   now asks the question it can answer.  **The arm to write asserts the kernel's
   own invariant** -- legitimate iff the owner had `SEF_STKBORROW` set at the
   time -- which, unlike blessing a PC range, cannot be satisfied by a restore
   into the WRONG lane.  `capture_writes` records `seq`, so a tap on the flag
   word puts its set and its clear in the same ordered stream as the writes and
   the arm brackets by it.

   **A GATE FLAKE WAS FOUND ON THE WAY OUT**
   (#275):
   `logintest` failed the gate once at `LT17 no-greeting7`, passed 3 of 3 run
   alone, and the same SHA gated GREEN on a re-run -- so it is the suite's own
   8-way parallelism.  It matters more than an ordinary flake because
   `logintest` is IN `GATE_TESTS`, and an intermittent there is what trains
   people to re-run a red gate.  `logintest.c:612-620` has already diagnosed
   this exact symptom once, from a session left un-torn-down into the next
   child; `PTY_NPAIR` is 2, so nothing absorbs a lag in reclaiming a pair.  The
   gate's own history file said "this SHA has been RED 1 time(s) before -- a
   green here does not undo that", which is the line that kept it from being
   waved through.

   Also folding in as they are
   passed:
   #165 (the
   `uio_resid` overflow obligation, living only in a source comment) and
   #123 (probes
   carrying baked kernel addresses).
   #164 is CLOSED
   and was sixteen files rather than the nine it listed -- with the check it
   suggested, which found a registry row that had not kept up with its file on
   its first run, and a fix to the header TEMPLATE, which is what had been
   manufacturing the defect.

   **PHASE 1'S GATE IS COMPLETE (2026-08-31): all five arms hold.**  Arm 1 (a
   full read/write exercise, fsck clean) and arm 2 (the oracle judging a volume
   FGX wrote) are standing gate coverage; arm 5 (tests that go red without this
   phase's machinery) predates them; arm 4 (an image 2.11BSD wrote, read by FGX)
   is local evidence by decision; and arm 3 -- 2.11BSD's own fsck on a volume
   FGX wrote -- passed on the live 11/70 with one byte changed, the clean flag.

   Phase 1's gate is described arm by arm above; its bar, in the plan's words,
   is that every phase ships at least one test that goes RED without that
   phase's machinery, and that attribution comes from the oracle -- host `fgxfs
   fsck` and 2.11BSD's own fsck under SIMH -- not from the disk image being
   unchanged.  **"Under SIMH" is that sentence's phrasing and not a
   requirement**: the same plan's deliverable 0.3 reaches a live 11/70 over
   telnet and says "no local SIMH needed", which is what `tools/pdp11.exp`
   does.  Arm 3 above is scoped against that script.
   Note vfs.mod has 9,659 bytes free.
   Superseded by the above, kept as the record: 1.12b (truncate and release: `itrunc` with block reclaim,
   `ufs_setattr`, `ufs_access`, `ufs_inactive` for the unlink-while-open case,
   #66), then 1.12c (directory mutation: `direnter`/`dirremove`/`dirrewrite`
   and create/remove/link/mkdir/rmdir/rename). What landed as 1.2a is
   the DISPATCH LADDER -- `DTYPE_*` and `_Fcb_ClassifyFlags`, the single
   classifier at nine sites; `struct file`, `u_ofile[]`, refcounted `ucred`
   and per-process `nameidata` did not. 1.7 needs them and 1.6 did not.
   **Where the file table lives has to be decided before it is written, and
   the answer is not the core bank.** The constraint inverted when the VFS
   became a module: the kernel bank has 2,340 bytes free against the far
   bank's 44,658. A `struct file` on this ABI is 24 bytes -- `f_flag`,
   `f_type`, `f_count`, `f_msgcount` at 2 each, then `f_cred`, `f_ops`,
   `f_data` and `off_t f_offset` at 4 -- so a conventional NFILE of 100 is
   2,400 bytes and does not fit at all, and even NFILE=64 would leave under a
   kilobyte for everything else. It belongs on the heap, as the VFS pools
   already went (task #28); `_BufInit` in `src/kernel/main.s` is the worked
   example of an allocation that checks out loud that it does not straddle a
   bank boundary, which is required because addresses are derived with a
   16-bit add and no carry into the bank.
   Three defects filed while building it, each with its evidence:
   #85 (fcc
   silently resolves a nonexistent field in a two-hop dot chain to the wrong
   offset — and the suite has no negative-test harness at all, so every
   rejection fcc is supposed to make is unverified),
   #86, and
   #87 (`sysops`
   and `ttyops` regressed against the runtime oracle on `main`, unnoticed
   because that oracle only runs when fcc's *source* changes).

   **A PORT-FIDELITY SWEEP OF THE CAMPAIGN'S NEW C** (the maintainer, 2026-09-02, after
   catching a path resolver about to be WRITTEN that was already ported and in
   the tree) found four things, two of them behavioural.  The surface is not
   the one `check_provenance.py` covers: it verifies REGISTERED ports well, and
   a MISSING port is invisible to it by construction, since a file claiming
   `FGX-Origin: original` needs no row.  So the audit reads the files CLAIMING
   to be original, and the port claims that were never read back against
   upstream.  `src/userland/fsck` and `src/drivers/fs` came back clean; three
   namei callers had dropped Reno's `FOLLOW`, on the authority of two contract
   blocks that still listed symlinks as absent long after they landed
   (#294, closed).
   The check written for that fix then found
   #295: `stat(2)`
   and `listdir(2)` against a UFS root are still ABSOLUTE-ONLY, so bare `ls`
   answers `. not found` while `ls /etc` works.  It queues behind core relief --
   `vfs_cdir` is indexed by pid and neither core hook takes one.

   **ACCEPTANCE TESTING IS THE DRIVER FROM 2026-09-04** (the maintainer).  The image is
   now booted and used on every fix, so the ordering below is by WHAT A TESTER
   HITS, not by what blocks the gate.  The gate tiers that follow are still the
   landing criterion; they are no longer the work queue.

   *First, because a tester stops here.*
   #318 THE UFS
   ROOT IS READ-ONLY.  `ufs_write`, `ufs_create`, `ufs_mkdir` and `ufs_remove`
   all exist; the syscall layer has only `root_stat` and `root_listdir`, and
   `_Fs_RootOpen`'s header says "FREAD, AND ONLY FREAD".  So there is no vi, no
   editing, no redirection onto the root, nothing that creates -- the
   filesystem can write and the road to it was never built.  `_Sys_Open`
   already holds the flags that header says are missing.

   *Then the ProDOS-shaped structures, which are ONE piece of work with three
   symptoms.*  **DONE, 2026-09-05.**  `root_stat` filled a legacy 15-byte ST_
   image and `include/fs.s` already carried the BSD `STX_` layout meant to
   replace it; the cutover landed, closing
   #319 (every
   file dated Jan 1 1970) and
   #317 (a name
   over 15 characters truncated).  #317 turned out to be a THIRD site rather
   than either of the two it named -- libc's own `MAXNAMLEN 15`, "ProDOS name
   cap", in `readdir`'s copy loop; `DE_Name` and `FS_NAME_MAX` are still 15 but
   a UFS path no longer reaches them, `Path_Resolve` being called only for the
   `/dev` prefix.  It also unblocks reporting mode for
   #320,
   permissions -- campaign 2.6, the last of the three things this campaign was
   scoped on and the one that retires the charter.  **The deferral's own stated
   condition is met**: it waited on ProDOS ceasing to be a filesystem this
   kernel resolves through, which the maintainer decided on 2026-09-01.

   *Then correctness of large reads.*
   #322 --
   `ntpplay` loads nothing, and its modules are 129-379 KB against a
   single-indirect ceiling near 260 KB.  `ufs_bmap` handles double and triple
   indirect; NOTHING HAS EVER READ ONE through the vnode path, since `bigread`
   at 48 KB is the only test past the direct blocks at all.  Measure which
   files fail before assuming the size is the cause.

   *Then the rest, in UAT order.*
   #321 name
   resolution (a shipped `resolv.conf` with no nameserver, and nothing saying
   that is why), then
   #316 -- module
   loading should cost no process slot, which is architecture rather than a
   symptom -- then the gate tiers below.

   **WHAT STANDS BETWEEN HERE AND PHASE 2'S GATE, ordered (2026-09-03).**  The
   gate is "boots from UFS with no ProDOS module loaded at all; suite green".
   Ordered by that and by nothing else -- several items below are older and
   larger than items above them, and several loud ones are not here at all.

   *Tier 1, the gate cannot be reached until these are fixed.*
   ~~#309~~ **CLOSED 2026-09-03** (`11bb29b0e`).  A module streamed in after
   boot was REGISTERED BUT UNREACHABLE: `_Fst_LoadOpsPtr`, `_Ram_LoadOpsPtr`,
   `_Pty_LoadOpsPtr` and `_Net_LoadOpsPtr` -- FOUR, not the three the issue
   named -- each ran once from `main.s`.  `_thunk_ModLoad` re-runs all four
   after any successful SYS_MODLOAD, on the syscall's own direct page, which
   is the half that could not have been done on the far side: `_Pty_LoadOpsPtr`
   reaches the chardev table through `_cdTablePtr` (DP $30) while
   `_Far_ModLoad` runs on `FGX_DP_KERNELC`.  `modloadpty` asserts
   `PTYSHELL PASS` now instead of carrying the failure on screen as evidence.
   ~~#312~~ **CLOSED 2026-09-03** (`31df8245f`): the fcc fixture `vreclaim` had
   stopped linking because M37's seg0 crossed merlin32's 64 KB limit, and M37
   was the only one of 37 fixture directories whose wrapper PUT `libtermlib.s`
   -- for one fixture out of 113.  **The gate ran GREEN end to end at
   `31df8245f`**, the first full pass since before 2026-08-31.

   **THE HEAD OF THE TIER IS NOW THE GATE'S OWN WORK, not a defect.  A UFS BOOT
   STILL HAS NO NETWORK, NO PTY AND NO SERIAL**, and it is visible in the boot
   log of every UFS manifest: three `mod: ... loaded` lines for the preloaded
   filesystem, then `dhclient: no network interface` and `inetd: telnet/tcp:
   socket: Function not implemented`.  `Mod_LoadConf` runs from `main.s:692` --
   the KERNEL reads `/etc/modload.conf` -- and `Fs_ReadN` answers EBADF for a
   root descriptor, so none of serial, bpf, net, ramdisk or pty arrives.
   modload.conf's own header already names the fix and BSD's reason for it:
   "which is where BSD runs modload(8) from too, out of /etc/rc".

   **LANDED 2026-09-03** (`c979156e8`).  /etc/rc runs modload(8) for the five,
   which is where modload.conf's own header has always said BSD runs it, and
   `ufsmodules' is green: all five announces on disk/fgxufs.po, with inetd
   re-arming telnet behind them.  The names are UPPERCASE because the files
   are -- `disk_src/lib/modules' holds NET, PTY, BPF in ProDOS's naming and a
   2.11BSD root is case-sensitive, so `modload net' cannot open the module it
   is sitting on while `modload NET' loads it.  That artifact belongs to the
   staging and goes with 2.4's move to fgxfs.

   On a ProDOS root the kernel has already loaded these and each line is
   refused by the placement check.  **That is the transition showing, and it
   does not gate the change** -- ProDOS is the side that is leaving (the maintainer,
   2026-09-01).  Two manifests encoded the old assumption and were corrected
   rather than accommodated: `modloadundo' now names the module its rollback
   test is about, and `modloadpty' stopped typing the load because rc does it
   at boot, which is a stronger statement of the same thing.

   #314 is
   therefore NOT on the critical path after all.  It was reached by way of
   test(1), wanted so /etc/rc could branch on which root it is -- a
   requirement that only existed while ProDOS's console output was treated as
   a veto.  It stays open on its own merits: nested members are a real fcc
   gap and test(1) is a real missing tool.
   #315 matters
   more now, since the UFS image can ship a stale /etc/rc and this change
   lives in exactly that file.

   ~~#297~~ **CLOSED 2026-09-05** (fixed in `cfcb1b158`, 2026-09-04, and left
   open).  `vn_open` carried a 42-byte `struct vattr` it did not use; taking it
   out of the deep chain moved the worst slice from 12 bytes spare to 52, and
   the ratchet went 24 -> 48 in the same work -- the part that mattered, since
   the old ratchet was guarding a number already below the 14 bytes an
   interrupt costs.  Re-measured 2026-09-05 on a confirmed UFS boot
   (`rootstatus 0100`): deepest slice 460 of 512, **52 spare**, every canary
   intact.  Never a ProDOS defect -- ProDOS was the baseline that passed, and
   it has since left the boot path.

   **CAMPAIGN GOAL 2 IS MET IN BOTH DIRECTIONS (2026-09-06).**  The charter's
   structural bet was "an FGX volume mounts on a PDP-11/70 and vice versa",
   and both halves now hold on real material rather than on the oracle.
   INWARD, 2026-09-05: `bsd211mnt' mounts the filesystem carved out of
   examples/pdp11/2.11BSD_rq.dsk and reads /mnt/VERSION off it -- "Current
   Patch Level: 498", that machine's own file.  OUTWARD, 2026-09-06: the maintainer
   attached `disk/fgxufs.dsk' to SIMH as rq3, and

       [71] root@pdp11:/# mount /dev/ra3a /mnt
       [73] root@pdp11:/mnt# ls
       TESTS/  bin/  boot  dev/  etc/  fgxunix  lib/  lost+found/
       mnt/  root/  sbin/  testbin/  testdata/  tmp/  usr/  var/

   -- all sixteen entries of disk/fgxufs.po's root, listed by a 2.11BSD
   kernel.  tools/fgxdsk.py is what makes the .po attachable: an RA92 image
   with a real disklabel at sector 1, every field from 2.11BSD's own
   `struct disklabel' and `dkcksum', geometry from that machine's /etc/disktab
   (`ns#69:nt#13:nc#3279', `pc#2940951').  The checksum routine is validated by
   running it over the reference disk's own label, which returns 0.

   Two-source split vindicated: architecture from 4.3BSD-Reno, ON-DISK FORMAT
   from 2.11BSD.  Reno's FFS could not have done this.

   **RE-CHECKED AGAINST GITLAB, 2026-09-06.**  The tiers below were ordered on
   2026-09-03 and three things in them had gone stale -- each issue's state was
   read from the tracker rather than from this file.

   **TWO OF PHASE 2'S THREE GATE CONDITIONS NOW HOLD, MEASURED.**  The gate is
   "boots from UFS with no ProDOS module loaded at all; suite green".  The
   suite's boot image IS `disk/fgxufs.po`; `/etc/modload.conf` on it reads
   `serial bpf net ramdisk pty ufsprobe` and a boot log contains no occurrence
   of `prodos` at all.  Every phase-2 deliverable is landed -- 2.1 on-target
   fsck, 2.2 one-sector stage 1, 2.3 stage 2 reads 2.11BSD, 2.4 the volume
   boots itself, 2.5 /dev in the root, 2.6 permissions -- with mount(2),
   umount(2) and the four tools on top.  **`suite green' is the whole of what
   is left.**

   **AND `suite green' NOW HOLDS FOR THE GATE'S OWN SET (2026-09-06).**
   Measured `--fresh` over all 265 manifests with the green-result cache
   bypassed: **230 passed, 21 failed, 14 skipped**, and NOT ONE of the 21 is in
   `GATE_TESTS`.  A bare `run.py' runs every manifest and is NOT the gate's
   set, which is worth writing down because it was read the other way once:
   `ttyprobe1..6' are gate.sh's own probe-kernel steps (cfg/system.cfg says a
   `requires' on them would be "coverage that disappears quietly"),
   `wirecon'/`wirelogin' need the host's MAME bridge, and the rest are outside
   GATE_TESTS and unexamined.  The six tty probe halves were built and booted
   by hand and all six print their verdicts; `ttyprobe2' does it with **162
   bytes** of tty bank free, which is the tightest thing in the tree and will
   be the next thing to break.

   THE ProDOS LAYER IS FOUR STEPS SMALLER (apple/fgx#344, 2026-09-06):
   `Bm_CountFree', prodos.mod itself -- built, staged and reachable from a
   boot fallback -- eight jumptable slots and `_Fs_Utime' are gone, and core
   went from 1,016 free to 1,394.  The measurement that step asked for BEFORE
   deleting the `fs.s' fallback arms was taken and it corrected the plan: only
   `Fs_Open's arm is unreachable.  `Fs_Stat's was reached on every failing
   stat and answered the wrong errno
   (#345, fixed,
   with `statenoent' now in GATE_TESTS), and `Fs_Chdir' runs `Path_Resolve'
   unconditionally to keep the per-task cwd STRING, so `path.s' is live rather
   than dead and cannot be deleted until something else owns that string.  The
   note on #344 carries both.

   THE SUITE'S 23 FAILURES ARE TRIAGED AND ELEVEN ARE GONE (2026-09-06).
   Six were the tty-bank probes, which are compiled in only at
   `kernel.ttyprobe<N> = 1' and now SKIP through `requires.config' as the seven
   VFS probes already did -- gate.sh runs them properly through tryprobe.sh, so
   no coverage moved.  Four were rot: `vcoff' and `modimage' asserted strings
   the 2026-09-06 boot-log cleanup deleted or moved, `novidraw' opened a ProDOS
   upper-case path on a case-sensitive root (a sweep finds no others), and
   `kstkcanary' poisoned pid 8's stack canary with the base address baked in
   while the login shell had become pid 9.  ONE WAS A REAL DEFECT and the best
   find of the campaign so far:
   #348 -- the
   vnode pool was initialised nine fields deep where Reno zeroes the whole
   structure, so `coldgarbage' PANICKED in `vrele: zero usecount'.  It agreed
   with upstream only because MAME zero-fills RAM and a IIgs does not.

   THE REMAINING TWELVE ARE ALL PRE-EXISTING, measured by rebuilding
   c5a52b333 in a worktree and running them there: `b3pty', `inittermbusy',
   `initthrottle', `ptyeintrs', `ptyeintrw', `vcclose', `vcstate', `vcwrite',
   `winsz', `wirecon', `wirelogin' and `morepty'.  Two carry write-ups already:
   #349, where
   init's `cannot spawn' report is printed onto the console of the line that
   just failed to start, and #346 below.

   AND ONE GATE TEST IS RED FOR A REASON OUTSIDE THE TREE.
   #346:
   `morepty' fails with `sh: more: cannot execute', and the failure follows
   the DISK IMAGE rather than the kernel -- crossed trials with byte-identical
   `bin/fgx.bin` put it on the image, and the variable is the PRESENCE of the
   gitignored local `disk_src/etc/dhclient.conf', content-independent.  So the
   gate says different things on a working tree and on a fresh checkout, and
   whatever the underlying limit is, its margin is one directory entry wide.

   apple/fgx#335 (ten manifests) and apple/fgx#339 (the three gate reds) are
   done.  Two of #339's three were real defects rather than test faults --
   ftruncate(2) was a stub answering ENOSYS, and a full file table answered
   EBADF where BSD answers ENFILE.  What is NOT done and is not a test:
   **apple/fgx#340**, the 800K floppy, which cannot be built (75,261 bytes
   over) and is PARKED at the maintainer's direction rather than trimmed -- `ninja
   release' no longer carries it, so it does not block.

   *Tier 1, the gate cannot be reached until these are fixed.*
   #335 -- SEVEN
   manifests still describe the ProDOS root and have been red since the boot
   volume swapped on 2026-09-04 (`0fdde5723`): `bigread`, `ckmodule`,
   `credprobe`, `mountorder`, `vfsmod`, `twodrive`, `modrollback`.  Confirmed
   pre-existing by stashing a working tree and reproducing them at HEAD.  The
   suite cannot go green while they sit, so this IS the gate's own second half
   and not the loose end it was filed as.  The fixes are per-manifest and are
   not one change: a UFS-sized timeout for `bigread`, root-cased staging paths
   for `credprobe` and `ckmodule`, and whatever a UFS root actually mounts a
   ramdisk as for the `/MNT/RAM5` arms.

   #309, #312, #315 and #297 are all closed and the rc module load landed, so
   nothing else stands here.

   **THE CAMPAIGN IS DOWN TO THREE ITEMS (2026-09-08).**  Tier 1 is empty and
   Tier 3 is nearly so.  apple/fgx#344 closed in full -- the FOP layer and then
   the cwd string, with `getwd(3)` now 2.11BSD's own tree walk and `path.s`
   gone; apple/fgx#360's cold-boot lottery turned out to be `BLKCACHE_USE`
   reading `_kBlkTabBase` through the wrong DBR, one `PHB/PHK/PLB` to fix, and
   apple/fgx#359 was RIGHT to name that cell; #358, #355, #356, #357 and #277
   closed; #299 closed won't-fix with the probes removed.  What is left is #288
   and #275 in Tier 2, and #165 in Tier 3.  See
   `history/RESUME-2026-09-08c-ufs-campaign-wrap.md`.

   *Tier 2, blocks JUDGING the gate.*
   #288 -- the
   suite's flake floor -- is what makes "green" a claim anyone can check;
   #275 is
   probably the same cause.  **AND THAT IS ALL OF TIER 2 NOW.**  This list also
   carried #292 (`cp` hands `stat()` a 16-byte buffer it writes 32 bytes into)
   and #289 (errno clobbered across `Fs_Close`) as "the two live defects a gate
   run would trip over"; **both are CLOSED** -- #292 went with the `struct stat`
   cutover on 2026-09-05, which replaced the ProDOS-shaped 15-byte image the
   defect depended on, and `cpstat` is green.

   *Tier 3, on-disk correctness -- which is campaign GOAL 2, that a volume
   moves between FGX and a real 2.11BSD.*  These do not stop a boot and they do
   decide whether the result is a filesystem or a lookalike.
   #278
   (`ufs_ialloc` rescans without discarding -- 2.11BSD patch 433, which the
   vendored tree predates),
   #159
   (`ftruncate` orphans a TREE file's blocks, which a real `fsck` calls
   corruption), #165
   (`uio_resid` overflow), and
   #277 -- the live
   oracle runs a NEWER fsck than `vendor/2.11BSD/` and nothing at either end
   says so, which undermines the instrument the whole campaign leans on.
   #299: two
   `vfs.mod` probes cannot be built at all, so part of the VFS has no
   verification path.

   *Tier 4, enablers rather than blockers.*
   #268 core
   relief -- **the cheap tap is now DRY**.  `_Tty_Flush` moved on 2026-09-03
   and was the last clean bracket; it netted 29 bytes against the 39 it
   occupied, because each of four call sites costs a byte for JSL over JSR plus
   a two-byte row in `_TtyPatchTbl`, which is core-bank too.  What is left in
   `ttyv.s` is a different shape: `_Tty_OutqUio` (43 B) wants a three-argument
   macro, and `_Tty_Write`/`_Tty_Read`/`_Tty_Ioctl` read core statics between
   the stage and the cross, which no stub can carry.  **Core stands at 1,394
   free** (`tools/check_kernel_ceiling.py`, which is the authority -- the
   `FGX_DATA` gap is NOT the ceiling and overstates it by thousands).  It said
   16 for weeks after the relief arrived and nothing went back to correct it,
   which is what kept #318's remaining half parked; measured 2026-09-06 after
   four steps of the ProDOS removal (apple/fgx#344) took it from 1,016, with
   far at 8,872 free and tty at 11,100.  The next core-side
   change needs a source of room this issue does not currently have,
   #264 the kernel
   stack guard, #293
   the untyped-extern audit.

   **AND WHAT IS NOT ON THIS LIST, said plainly because a day went into it.**
   #310 and
   #311 -- the
   `/ldev` -> `/dev` transition -- DO NOT BLOCK THE GATE.  The gate is about
   booting from UFS, and `/ldev` resolved perfectly well on a UFS root; the
   sweep is tidiness the campaign does not depend on.  **THE LAST CLAUSE WAS
   WRONG and the retirement note in the UFS section above is what it cost:**
   the two roads did not carry the same semantics, and six defects were living
   in the gap.  Kept as written, with the correction beside it, because a
   judgement that turned out wrong is worth more on the page than a quiet
   edit.  Nor do the net (#296,
   #157, #156, #143), tty (#279, #287, #265, #276), fcc (#280-#284),
   spawn/argv-widening (#301, #303, #304) or userland-memory (#37, #48, #62,
   #63, #66, #69, #107) items, however loud any of them is.

   **df(1) IS DONE** (the maintainer, 2026-09-05),
   #329, CLOSED by
   `71df71c3a` and `522ad679b`.  It is `vendor/2.11BSD/usr/bin/df.c` at 8.8 --
   the 1996 base plus patch 466 -- and the gaps went into the OS rather than out
   of the source: statfs(2) and getfsstat(2) ported from 4.3BSD-Reno (they
   dispatch through vfsops, so the VFS half is Reno's while df itself is
   2.11BSD's), getmntinfo(3) and err(3) in libc, and vfprintf(3) under them.
   `/dev/sd0` and an `/etc/fstab` root line landed with it.

   **THE BOOT fsck IS DONE** (the maintainer, 2026-09-05),
   #330.  All six
   steps: mount(2)/umount(2) as syscalls, MNT_UPDATE, 2.11BSD's
   mount(8)/umount(8), a read-only root at boot, 2.11BSD's own rc block with
   its exit-code case, and reboot(2)/reboot(8) -- halt(8) included, that being
   the same binary under another argv[0].  `/dev/rsd0..7` and a computed fsck
   arena landed on the way.

   The inconsistencies that first looked like a reason to wait were NOT the
   filesystem moving underneath fsck: they were fsck's own 24-block scratch
   file, which existed because its maps did not fit in memory.

   **THE CLEAN FLAG IS WHAT MAKES IT AFFORDABLE** -- 2.11BSD update #456, which
   is also the `fs_flags` marker
   #277 records the
   live 11/70 using.  A full check of the 32000-block root reads the whole
   i-list and every block of every file through a single-block read path, and
   measured at over 45 seconds -- doubling a boot the suite already pays 45 for.
   With MNT_CLEAN the boot says `file system is clean; not checking` and the
   stock timing is back.  fgxfs stamps the images it writes, a volume it has
   just finished writing being consistent by construction; the kernel clears the
   flag on the first writable mount and restores it on a clean unmount.

   **reboot(8) HAS TWO HALVES AND THE IIgs ONE IS SETTLED.**  BSD's is a
   syscall the kernel implements with a thin userland wrapper, so FGX needs
   SYS_REBOOT plus `/sbin/reboot`; the flags and the tool are
   `vendor/2.11BSD/usr/sys/h/reboot.h` and `usr/sbin/reboot`, and `boot(dev,
   howto)` in `pdp/machdep2.c` is the kernel shape -- mark the root superblock
   modified, sync unless RB_NOSYNC, wait out busy buffers, raise the priority
   level, then halt for RB_HALT or `doboot` otherwise.  halt(8) IS the same
   binary under another argv[0], which is how 2.11BSD spells it.

   FGX's `doboot` is `JML $00FAA6` -- PWRUP, the system cold-start routine,
   entered in emulation mode with D=$0000, DBR=$00 and K=$00 or "RESET will not
   work" (Firmware Reference, Appendix C, Firmware Entry Points in Bank $00).
   It performs a partial system reset, zeros bank 00 from $0800-$BFFF, re-reads
   the clock chip into firmware RAM, sets the system to match, sets the
   power-up byte so the NEXT reset is a warm start, and scans for a startup
   device.  The $3F2/$3F3/$3F4 power-up-byte trick is NOT needed: that is how
   RESET ($FA62) decides between warm and cold, and PWRUP is the cold path
   entered directly.  What FGX must do first is the quiesce -- interrupts off,
   and whatever the SCC and the VGC need to not be left armed across a restart
   that re-initialises neither.

   The harness wants this too: a working cold restart would let `run.py` reset
   the machine without tearing down and relaunching MAME, and the 45-second
   boot dominates every timing measurement in the current campaign.

   **THE SHORTEST LINE IS NOW TIER 2** -- #288, the suite's flake floor, which
   is what makes "green" a claim anyone can check, and which cost a full
   baseline bisection on 2026-09-05 when `cpstat` and `fsckprobe` went red on
   boot-timing margin at the default `FGX_MAME_BOOT_S=25` and green 3/3 at 45.
   (#297 -> #315 was the line until both closed; #309, #312 and the rc module
   load landed, #307 measured out, #314 is off the path.)  Then the 2.4
   deliverable the number does NOT currently do double duty for -- `disk_src`
   staging moves to `fgxfs`, still untouched -- and then **2.6, permissions**,
   which is the largest unstarted piece and the one that actually retires the
   charter: the campaign was scoped on ProDOS having no inodes, no permissions
   and no device nodes, and two of those three are now answered.

   **AND #318'S REMAINING HALF IS NO LONGER BLOCKED.**  Its own text says
   `unlink`, `mkdir` and `rmdir` wait on core-bank space, "the kernel is now
   FULL at 57968 of 57968 bytes, 0 free", and this file said 16 free.
   `check_kernel_ceiling.py` on 2026-09-06 says **1,394 free**: the relief
   arrived with `/fgxunix` and the far-bank moves and nothing went back to say
   so.  RE-MEASURE BEFORE QUOTING THIS -- it has been wrong in this file three
   times, always in the direction of "there is no room", which is the direction
   that stops work.  The `_Sys_DevOpen`/`_Fs_RootOpen` merge that issue identifies as the
   source of 40-50 bytes is no longer needed to proceed.

4. **TTY campaign — porting BSD's tty layer.  ★T1 LANDED 2026-08-22**
   (#108).  The maintainer's
   ruling: adopt BSD's `struct tty` and its queues, match BSD wherever feasible.
   Design in [`tty-kernel-bank.md`](plans/tty-kernel-bank.md); the placement survey
   that decided it is
   [`history/plans/2026-08-22-tty-bsd-shape-placement-survey.md`](plans/2026-08-22-tty-bsd-shape-placement-survey.md).

   **T1 is a THIRD statically linked kernel bank plus its first tenant.**  The
   layer cannot be a module -- the input discipline runs at interrupt time, live
   152 lines of boot before `Mod_LoadConf` -- and it does not fit in the far
   bank at ~46,900 bytes against 18,411 free.  `KERNEL_BANKS` `$02` -> `$03` was
   the whole allocation change; the per-bank apparatus was taught a third bank
   rather than copied.  The tenant is 2.11BSD's clists (`tty.h`, `clist.h`,
   `ttychars.h`, `tty_subr.c`), driven at boot by a fifty-case probe the smoke
   gate asserts.  **The port found three fcc defects, all silent or
   parse-rejecting and all with zero fixture coverage in 592:**
   #199 (a struct
   copy through a dereferenced pointer moved two bytes),
   #200 (an array
   field at the end of a multi-hop arrow run -- rejected in one reader,
   silently dereferenced in the other) and
   #201.

   **T1 IS ON MAIN** (!253): a third statically linked kernel bank at live
   kernel bank + 2 (`/KERNELTTY`), arriving with 2.11BSD's clists and a boot
   probe the smoke gate asserts as `tty: clists ok`.

   **T2 is complete for correctness and not yet landed** -- 24 commits, gate
   green (596 fixtures, 37 tests, sweep 43, oracle 238/238), `ufsdevprobe`
   green. It is the cdevsw/linesw ABI, which IS
   #198's fix and
   what unblocks UFS 1.7d's I4.  The discipline does NOT move in T2 -- `l_read`
   and `l_write` point at a thin adapter over today's per-byte loop, because
   relocating 790 lines that T3 deletes is paying twice.

   **T2 COST AN UNPLANNED DETOUR THROUGH ANOTHER CAMPAIGN.** It would not build:
   the core kernel bank was 67 bytes from its ceiling and T2 needs 747. That was
   not T2's doing -- 1.7d I2 had spent 1,388 bytes of it and T1's own apparatus
   another 310 -- but it had to be paid before T2 could compile at all, so
   far-bank phase 3 (item under "Kernel-bank code room") was pulled forward and
   `loader.s` left the core bank. Core is 1,807 free with T2 applied.

   **T3's PORT IS COMPLETE**: all thirty-one of `tty.c`'s routines are ported -- the output
   and echo cluster, the rub-out pair `ttyrub`/`ttyretype`, the input
   flow-control pair `ttyblock`/`ttyunblock`, the waiter-wakeup pair
   `ttwakeup`/`ttyowake`, `ttyflush`, the close/carrier pair
   `ttyclose`/`ttymodem`, the input half `ttyinput`/`ttypend`, and **the
   readiness trio `ttnread`/`ttyselect`/`ttselect`, the waiting trio
   `ttywait`/`ttywflush`/`ttylclose`, `ttyopen`, `ttwrite`, `ttread` and
   `ttycheckoutq`** -- and
   NINETEEN seam pieces are landed, counted from `src/kernel/tty/kc_sys.s` rather than
   tallied: `kc_wakeup`, `kc_sleep`, `kc_panic`, `kc_uiomove`, `kc_cdttyidx`,
   `kc_cdioctl`, `kc_cdstop`, `kc_selwakeup`, `kc_gsignal`, `kc_ttyopen`,
   `kc_lbolt`, `kc_curpgrp`, `kc_curctty`, `kc_isvforked`, `kc_sigopted`,
   `kc_ureadc`, `kc_pendsig`, `kc_uid` and `kc_spgok`.
   The rub-out pair needed
   #212 fixed
   first: `tty.h` defines `t_rawq` as `t_nu.t_t.T_rawq`, so `nextc(&tp->t_rawq,
   cp)` is address-of a member reached by a dot after an arrow, and fcc
   rejected it outright with no workaround available in the C.

   HAS MOVED AT EVERY INCREMENT, and twice it was because the scan was wrong
   about what the bank ALREADY HAS rather than about the call graph.  A THIRD
   BLIND SPOT SHOWED UP HERE, and it is not about the bank: the scan sees CALLS,
   so it ranked five routines portable when only `ttyclose` and `ttymodem` were.
   The other three go through `ttnread` -> `ttypend` -> `ttyinput`, which no
   seam is missing from and which apple/fgx#215 blocks anyway, and `ttyselect`
   additionally reads `u.u_procp`, `selwait` and `t_rsel` -- DATA dependencies
   the scan cannot see at all, and which need FGX's poll-and-yield select
   answered for rather than transcribed.  Read the ranking as "needs no new
   SEAM", never as "portable".

   **EVERYTHING PORTABLE WITHOUT A NEW SEAM IS NOW IN.**  The scan's remaining
   rows all need `sleep` or more.  The select question that gated the readiness
   trio was answered from the source and is written up in
   `docs/history/plans/tty-kernel-bank.md`: BSD's select is itself a poll-and-rescan loop and
   the `t_rsel` registration never carried readiness, so `ttyselect` ports with
   its readiness tests intact and its registration arms dropped.

   `kc_sleep` landed and took `ttywait` (20), `ttywflush` (8) and `ttylclose`
   (15) with it -- **three, not the four the scan promised**: `ttyopen` also
   reads `u.u_procp`, `u.u_ttyp`, `u.u_ttyd`, `p_pgrp` and `p_pid`, a u-area
   rather than a seam.  That was the scan's blind spot for the third time, and
   it can now say so (a checked `DATA_DEPS` table, reported instead of
   "PORTABLE NOW").

   **EVERY ROUTINE LEFT NEEDS `u.u_procp`.**  That is the finding, and it took
   reading rather than the scan to see: `ttycheckoutq` is ranked behind
   `sleep, timeout` and also does `oldsig = u.u_procp->p_sig`, so a `timeout`
   seam alone would not have ported it.  The scan says so now -- it prints data
   dependencies ALONGSIDE missing seams rather than only when no seam is
   missing, which is how that one read as one seam from portable.

   ```
   ttyopen        26  no seam missing  + DATA: u.u_procp, u.u_ttyp, u.u_ttyd, p_pgrp, p_pid
   ttycheckoutq   25  sleep, timeout   + DATA: u.u_procp, p_sig
   ttwrite       126  sigmask, sleep   + DATA: u.u_procp
   ttread        115  sigmask, sleep, ureadc  + DATA: u.u_procp
   ttioctl       258  bcmp, inferior, linesw.l_*, pfind, sigmask, sleep + DATA: u.u_procp
   ```

   **THAT DECISION IS SETTLED, AND THE SOURCE SETTLED IT** -- see
   `tty-kernel-bank.md` section 9.  The name was wrong twice: only `u_uid` of
   the six fields is in FGX's u-area (the rest are `SE_PGroup`, the ctty bits
   in `SE_Flags`, the sigHnd tables and `TCB_PendingSig`), and the question was
   never a mechanism but a PLACEMENT.  Both trees answer it the same way --
   every SIGTTIN/SIGTTOU background gate is in the tty layer, none in the
   syscall layer or the signal code, and Reno factors it into `sys/tty.h` as
   `isbackground(p, tp)`, HANDED the proc rather than reaching a global.  So
   the gates port as C over field accessors, and FGX's `_Tty_BgWriteGate` and
   the inline `_Sys_Read` gate retire when `linesw[0]` repoints.  `ttyopen`'s
   session block is the one exception, because `_kCttyTarget` answers a
   question `u.u_procp` cannot; it landed as a single `kc_ttyopen` shim over a
   `_Se_TtyOpen` split so the core stops reading `_ttyTable` on the bank's
   behalf.  **`lbolt` and `ttwrite` have landed on that shape.**  `lbolt` is
   BSD's wait-and-retry channel and FGX had never had one; it is driven as
   2.11BSD drives it -- the clock MARKS (`_kLboltDue`, in the heartbeat) and a
   safe context PERFORMS (`_Lbolt_Wake`, at the two kernel-DP sites
   `_Tty_DrainSigPend` already uses), which is upstream's own
   `needsoft`/`softclock` split.  The guarantee is weaker than upstream's in one
   stated way: 2.11BSD writes `++runrun` beside the wake to force a reschedule
   each second and FGX's Model A preemption cannot, so a CPU-bound task issuing
   no syscall delays an `lbolt` sleeper.  `ttwrite` then carried the background
   gate across as C over four accessors -- which is where `_Tty_BgWriteGate`
   retires to when `linesw[0]` repoints.  `ureadc` and `ttread` followed.  `ureadc` went into
   **vfs.mod beside `uiomove`**, not into the tty bank: `kern_subr.c` had
   reserved the spot with the reasoning, BSD puts it there, and T4's
   `tty_pty.c` calls it four times from a third bank -- two callers in two
   banks is what settles it.  `ttycheckoutq` followed, and with it the last
   routine that needed a seam this campaign had not already built: its
   `timeout(wakeup, &tp->t_outq, hz)` is `kc_lbolt`, and `p_sig` is
   `kc_pendsig`, which returns a LONG because this kernel puts signals 16..23 --
   every job-control signal -- in the mask's high word.  `ttioctl` closed the
   file: **NOTHING IS LEFT IN `tty.c`**, and `tools/tty_closure_scan.py` now
   prints an empty routine table.

   **IT COST NO CORE BANK AT ALL, and the seam bill it was scoped against was
   wrong in three ways.**  `pfind` and `inferior` are NOT ported: the core owns
   both already as `Task_Lookup` and `_Spg_Permitted`, whose header quotes the
   identical 2.11BSD `kern_prot.c` guard, so `kc_spgok` answers the whole of
   TIOCSPGRP's ownership conjunction in one call.  The three `linesw` hops are
   not seams either -- `linesw[]` is defined in the bank.  What WAS missing and
   unlisted is `u.u_uid`, which upstream reads four times.  So two shims, not
   seven, and the 258 lines land in the tty bank where there was room.

   **`data` IS THE CALLER'S OWN POINTER, WHERE UPSTREAM'S IS A KERNEL COPY.**
   2.11BSD's ioctl(2) copies the parameter block in before dispatch and out
   after; FGX has no second address space to cross, so a caller's pointer is an
   ordinary far pointer and upstream's `*(int *)data` ports unchanged.  The
   command encoding needed no work at all: `sys_generic.c:199` hands the DRIVER
   the 16-bit kernel form and that is already FGX's own numbering.  What it
   costs is stated in the routine: no single validation point and no atomicity
   across the block -- inert on a machine with no page faults, and not a new
   divergence, because every existing `_IoOp_Tty` arm already does the same.

   **T6 IS NOT A REASON TO WAIT, WHICH IS THE OTHER HALF THAT DISSOLVED.**
   Every `u.` in `tty.c` is inside those five routines, all top-half and all
   process context; `ttyinput` touches no u-area field at all, so T6 returning
   it to arrival time is independent of this seam.  The bank has 33,677 free,
   so room gates nothing either.

   What is left after `ttwrite`: `ureadc` (+`ttread`), `kc_timeout`
   (+`ttycheckoutq`), and `ttioctl` (258), which also wants `bcmp`, `bcopy`,
   `pfind`, `inferior` and the `linesw` open/close/rint hops.  **`sigmask` is
   NOT among them** -- it is `#define sigmask(m) (1L << ((m)-1))`
   (`h/signal.h:136`), a macro the closure scan had been counting as an
   unbuilt seam for four increments.

   **THE BANK WAS THE NEXT CONSTRAINT AND HAS BEEN EASED ONCE.**  `ttyinput`
   (198 lines) was ported, built and booted during this work before being
   backed out behind apple/fgx#215, and with it in the bank stood at 60,133 B
   of 60,480 -- 347 free -- having overflowed by 22 on the way, which
   `check_kernel_ceiling` caught.  Measured density: ~29 B per source line.

   `FGX_KTTY_DATA` moved $09EC40 -> $09FC00 -> **$09FF00**, so the code region
   is **65,280 B (250 free with `ttyinput` and its probe cases in)** rather
   than 60,480.  The DUM block is still EMPTY at every step -- this is the
   reserve being sized to what it holds, not consumed.

   **THE BANK IS NOW AGAINST A SECOND, REAL CEILING** and it is not the linker's:
   stage2's sapling loader ran away on any image of 128 blocks or more
   (#218, fixed),
   which capped every kernel image at 65,024 B.  With that fixed the limit is
   65,535 -- one short of a full bank, because `ZP_EOF` is 16 bits.  There is
   no more room to buy above that: the next increment that does not fit must
   retire `tty_probe`, not raise a constant.  The old split reserved 5,056 bytes for
   a DUM region that was EMPTY -- `ttybank.s`'s block holds only its own start
   marker, and every tty-bank static is an fcc data segment inside the CODE
   region (2,336 bytes of them, `cfree` at 1,024 the largest) -- so four
   kilobytes were being held back to hold nothing.  Safe because stage2 loads
   this image into a bank-aligned, locked multi-bank block, so the bytes above
   the image are real RAM either way; the ceiling only bounds the linker.
   VERIFIED BY BOOTING, not by the checker agreeing with itself: a temporary
   12 KB filler pushed the probe's own code 2.8 KB past the old ceiling and
   the machine came up with `tty: clists ok` and `tty: linesw ok` both
   present.  1,024 bytes are kept back so the DUM contract still has a home.

   **THE PROBES ARE BEHIND `kernel.ttyprobe` NOW, AND THE BANK CONSTRAINT IS
   GONE**: 31,603 B of 65,280, with 33,677 free against ~13 KB of `tty.c` left
   to port.  Retiring clusters had cost 5 KB of coverage to land 1.8 KB of code
   across two increments -- the echo cluster and `ttyflush`'s own cases, leaving
   `nullmodem` untested and `ttylclose` with no witness -- and finishing that
   way would have emptied the probe one irreversible decision at a time.

   The flag defaults to 0 so the shipping kernel does not carry 34 KB of test
   code, and **`tools/gate.sh` builds a probe kernel and boots it as a step of
   its own**: a `requires` on the manifest would have SKIPPED when the flag was
   off, which is the quiet-coverage-loss `kcprobe`'s comment warns about.  Both
   verdicts are asserted present, and the step is measured to go red when the
   probe is built but not called.

   THAT IS NOT THE WHOLE ANSWER.  ~912 source lines remain (~27 KB at the
   measured density) against 14,115 free, so the room now covers `ttread`
   (115) and `ttwrite` (126) comfortably -- which is the pair that unlocks the
   `linesw[0]` repoint.  After that **`tty_probe`'s 22,987 B, 40% of the bank
   and more than `tty.c` itself, retires** as the existing userland suite
   becomes the witness, and `ttioctl` (258) has room.  The deadlock is broken;
   what is left is ordinary sequencing.
   `ttread`/`ttwrite`/`ttyinput` is the EXISTING userland
   suite after `linesw[0]` repoints -- boot cannot see them, because
   `Task_AllocUarea` builds init's u-area rather than one this code runs as.
   Then the rest of T3 (`tty.c`, the
   assembly `putc` and permanent `PENDIN`; retires #108), T4 (`tty_pty.c` into
   pty.mod), T5 (`tty_tty.c`) and T6 (a second fcc register file, which returns
   `ttyinput` to arrival time).  **Accepted divergence until T6 (the maintainer,
   2026-08-22):** `^S`/`^Q` are honoured when a reader runs rather than at
   arrival, on the grounds that nothing drives serial.  Reopen if anything
   starts to.

   **T3 STAGE 4 IS COMPLETE: INCREMENTS 0-8b ARE LANDED.**  tty[0], the
   VC pair and both pty slaves all read through the ported `ttread` now, so
   nothing enters the core's `@rd_disc`. Increment 8 then deleted it, the core
   background gate, the echo trio and the canonical line buffer, and added two
   export slots (`kc_ttflush`, `kc_ttnread`) for the four flush sites and
   select(2) that still needed real answers.

   **T4 IS COMPLETE: INCREMENTS 1-6 ARE LANDED.**  `tty_pty.c` is in: carrier
   follows the master, the slave's open/close go through the discipline, a pty's
   pending output lives in `t_outq` as it does upstream, and the slave line has
   a real `d_stop` -- so `TIOCOUTQ`, `ttywait`, `ttyflush(FWRITE)`, `TS_TTSTOP`
   and packet mode all reason about the queue that actually holds the bytes.
   BSD drew the seam itself and FGX had already built both hooks (`t_oproc` and
   `d_stop`), so no bank decision was ever needed.

   **Increment 6 is a DECLARATION, and that was the row's own alternative.**
   REMOTE mode needs a record boundary FGX's write path does not have: upstream
   ends each remote write with a NUL sentinel and the slave's read drains up to
   it, while FGX's chardev write is a per-byte loop in which no byte knows it is
   the last.  A bulk `d_write` would not settle it either -- that entry serves
   the /dev route while the syscall route a master actually uses stays per-byte.
   Nothing asks for it in either tree: `TIOCREMOTE` appears only in `ioctl.h`
   and `tty_pty.c`, and 2.11BSD's own vendored `rlogin` does not use it.  So
   FGX refuses it with ENOTTY rather than accepting it and doing nothing, the
   refusal is pinned by `ptyremote`, and the divergence is stated in a new
   `pty(4)` -- FGX's first section-4 page -- whose BUGS text `manpty` greps for
   so the declaration cannot go stale unnoticed.

   **The ring's out half is retired** (T4 increment 7): 256 bytes of the core
   bank back, the slave-write blocking append and the record's out cursors gone.
   Deleting the field found a live defect first -- `_PtyS_Poll` answered POLLOUT
   from that dead ring, so select promised a write which `ttwrite` would then
   block on, the same shape `_PtyM_Poll` had one increment earlier and with no
   fixture on either end.  `ptyswsel` is that fixture and `kc_ttselect` (slot
   32) is the fix.

   **T5 NEEDS NO PORT.**  `tty_tty.c` went in at `a9c76016b` under
   #151, before the
   T-numbering caught up: all five upstream routines are covered, the resolve is
   wired at all four dispatch points, the one divergence (not forwarding
   `syopen`) is argued in the file, and `devtty` witnesses it.

   **AND #151 IS CLOSED WITH IT.**  Surveyed 2026-08-26 by counting CALLS
   rather than reading comments: worm, udpecho, robots, ping, netdump, devttyx,
   `more(1)` and elvis are all at ZERO.  Every caller that remains is
   deliberate.  `fractal` is not an exception to the issue but an application of
   it -- `console_only()` opens `/dev/tty`, calls `ttyname()` and refuses
   anything but `/dev/console`, because the SHR screen is the machine and there
   is no per-terminal framebuffer to route to, so its ring reads ARE its own
   terminal (`fracpty` proves the refusal, `fraccon` that it still runs).
   `rdtimed` drains the ring on purpose -- what must be EMPTY is the ring
   itself.  `ptykeyx` and `nottykey` are the fixtures that MEASURE the bypass.
   So the syscalls stay as a console primitive and have stopped being any
   program's terminal input path, which is what the issue asked for.  The one
   genuine remainder is `tip`, already an item below: it multiplexes
   {terminal, line} so it wants `select()`, not a swap.

   **T6 IS COMPLETE.**  A second fcc register file, which returns `ttyinput` to
   arrival time and retires the pump: increments 1 to 3, then 4a, then 4b in
   four commits -- see "T6 DESIGNED 2026-08-26" in docs/history/plans/tty-kernel-bank.md and
   the landed sections under it.  The measurement that sized the whole thing: `spltty()`/`splx()` were
   ALREADY at seventy call sites in the ported code, every one upstream's and
   every one a no-op, so T6 gave two macros bodies rather than adding a bracket.

   1. **The context** (`a281b1380`): `FGX_DP_KERNELC_IRQ` + `FGX_STK_KIRQ` in
      the language card, `KTTY_KC_ENTER_IRQ`, a seeded stack floor -- the first
      working fcc stack guard in this kernel.  NPROC now caps at 13.
   2. **The bracket** (`8bc25b21c`): real bodies on the 65816's I flag, which is
      what sched.s already calls spl.  `ttyunblock`'s missing `splx` -- verbatim
      upstream, a dead store there and a silent hang here -- fixed, with
      `tools/check_spl_balance.py` holding the rule.
   3. **The brackets** (`5e4f1b065`): `_wakeup` and `_Kill_GroupFanout` mask,
      because measuring showed `_wakeup`'s "callable from an ISR" header was a
      claim and none of its sixteen callers masked.  The row said this increment
      was the mark-and-perform rail; the rail turns out to be for the chardev
      dispatch, which the row never mentioned, because `_Chardev_Dispatch`
      self-modifies a shared trampoline and cannot be bracketed at all.
   4. **IT SPLITS BY CONTEXT, NOT BY LINE**, and that split is the design:
      `ptcwrite` is a `write(2)` on the master and runs in TASK context; the
      heartbeat is an INTERRUPT.  Stage 4a of the earlier attempt changed both
      at once and so could not say which half was wrong.

      **4a IS COMPLETE.**  The flip (`797ec9060`): `_PtyM_Write` reaches
      `ttyinput` through KSVC_TTYPTCINPUT, and the two byte-source shims answer
      -2, "this line is not pumped", before entering the core.  Every DEEP pty
      path is exercised with no interrupt-time C at all, including the four
      fixtures the earlier stage 4a failed.  Then the retirement (`cdb8b7bb0`):
      the master->slave ring and `_ptyInRings` are gone, **385 bytes of the core
      bank back**, and `_ptyOpsOK` went with them having been write-only since
      T4 increment 7.  The survey before it found three live defects -- both pty
      poll arms reading the ring the flip had stopped feeding, in opposite
      directions, with all 54 fixtures green (fixed, `7b61f57d5`), and
      #241, filed
      not fixed.

      **4b IS LANDED.**  The heartbeat calls `ttyinput` for the line the
      keystroke belongs to (`b307e2fcd`), and the pump, `kc_getbyte`,
      `kc_pollbyte` and the two `_FarSh_Tty*Byte` export slots went with it
      (`7c1db9f50`) -- plus `^S` -> `d_stop` onto the mark-and-perform rail
      (`9a0966d60`), because `_Chardev_Dispatch` cannot be bracketed.

      **AND THE FLIP WAS BLOCKED FIRST, BY A DEFECT IN INCREMENT 1**:
      #242 --
      increment 1 put the interrupt-time register file and stack in the
      language card, and bank 0 `$D000`-`$FFFF` is ROM-mapped while the
      firmware Heartbeat handler is dispatching, so the whole context was
      unreachable from the one interrupt it exists to serve.  It presented as a
      dead keyboard, not a crash.  **`_KcIrqProbe` passed all twelve cases
      throughout**, because it runs at boot in TASK context: nothing had ever
      executed `KTTY_KC_ENTER_IRQ` from an actual interrupt, so increments 1,
      2, 3 and 4b steps 1 to 3 all validated the bracket from the wrong side of
      the distinction it is named for.  Fixed at `a282e2db9` by saving STATEREG
      bit 3 and double-reading `$C08B` inside the bracket -- `boot_console.s`'s
      idiom mirrored, eight instructions, no geometry change.
   5. What it closed: the `^S`/`^Q` divergence above for every pumped line, and
      the unpumped-input flush question -- which answers itself once no input
      is unpumped.

   **T7 IS COMPLETE, IN THREE STEPS, AND WITH IT THE CAMPAIGN'S PORT.**
   `7753da804` the `struct tty` and the service a self-registering driver needs
   to name its own line; `e6e99b79d` the flip, `serial_isr` calling `ttyinput`
   at arrival; `98ccb7a57` the roads -- `d_read`/`d_write`, the `/ldev` read and
   sgtty-ioctl detours, `serial_poll` onto the discipline, and `_sccRxBuf`
   retired for 256 bytes back.  **`/dev/tty01` is a terminal now** rather than
   a byte pipe with a ring behind it, which closes the accepted `^S`/`^Q`
   divergence for the last line that had it.  Witnesses `t7bind`, `t7flip`,
   `t7noopen` and the restored `tip_rx_diag`, all four needing
   `tools/mame_test/serial_feeder.py` on :25232 and declaring it, so they SKIP
   rather than fail where no peer is running.

   **STILL OWED BEHIND IT, AND THE TWO ITEMS TURNED OUT TO BE ONE.**
   `check_hb_scratch.py` followed only the HEARTBEAT's calls; it covers the SCC
   handler now (`305a67cff`), and catches nothing -- T6's second register file
   had already retired the structural hazard, so this enforces a property that
   already holds rather than closing a gap.  The other one is open:
   #247, **CLOSED**
   -- tty[5] was bound but never SEEDED, so `t_flags` and every control
   character were 0: no `^C`, no `^U`, no `^S`.  `tty_devinit` does
   `ttychars(tp)` and `t_flags` for every bound line now, at BIND rather than at
   open, for the reason `t_oproc` and carrier are set there: FGX has no getty,
   so a line not seeded there is never seeded at all.  Both placements closer to
   `dzopen` were tried and REVERTED -- from the open op it hung the machine (a
   chardev op runs inside `_Chardev_Dispatch`'s shared self-modified
   trampoline), from `mod_init` it broke the boot.  **AND IT CLOSED WHAT #240
   LEFT OWED**: `serial_stop` has a witness for the first time (`t7stop`), since
   `ttyinput`'s stop arm needed a `t_stopc` the line did not have.

   **THE GATE COVERS THE SERIAL LINE NOW** (`ae064ba3b`) rather than skipping
   it: the four witnesses declare `requires.tcp`, and the gate STARTS THE PEER
   itself, the way it already builds a probe kernel rather than leaving the tty
   bank to a flag.  A skip would not merely go unnoticed -- the gate asserts an
   exact `N passed, 0 failed`, so it would fail for the wrong reason.

   **THE TELNET DEFECT BEHIND THE CAMPAIGN WAS NOT IN THE TTY.**
   #227 --
   "the second telnet session connects, negotiates and never prompts", confirmed
   on hardware -- **CLOSED** at `5d87cc009`.  A DUP2 file action mirrored into
   the file table against `_fdDupSrc', which only `dup(2)' and `dup2(2)' ever
   set, so a spawn's dup2 ran against whatever descriptor the last dup syscall
   anywhere in the system had used; `fddup' then mirrored nothing and the child
   held descriptors one table had and the other did not, EBADF on every syscall.
   A completed login is what changes that cell, which is why the first session
   after a boot always worked.  `wirelogin' drives the reproduction now rather
   than a control that the broken state also passed.
   #249 was
   CORRECTED AND THEN FIXED (`756c92bba`): its "first login refused on a cold
   boot" is `logintest' LT3 sending a deliberately wrong password, and the real
   red was LT9 -- whose `^D' was not at a fresh prompt, because `drain_until'
   returns on a command's OUTPUT and the shell has not yet redrawn.  All
   seventeen cases run now, LT10 among them, and the fixture is
   mutation-verified against #227, which makes it that defect's first witness
   needing no network.  The discipline was measured innocent on the way past:
   `ptyshell' (`3f90473c7`) takes the same `^D' in the same window through
   `/bin/sh' and still gets its EOF.  And
   #250 --
   `t7stop' flaking one run in three -- **CLOSED** at `4621f4e81`: it asserted
   `TS_TTSTOP', and the next `^S' clears it (endcase falls into
   `restartoutput'), so the assertion is the DISPATCH COUNT now, paired with a
   zero required of the two runs whose peer sends no stop character.

   T7 gave the SERIAL line an `l_rint`.
   `serial_isr` fills `_sccRxBuf` and `serial_read` pops it, and **those bytes
   still meet no discipline** -- the survey named this a seventh increment from
   the start ("WHAT T6 IS NOT" in docs/history/plans/tty-kernel-bank.md).  It calls
   `kc_ttyinput(idx, c)` from the SCC RX interrupt as the heartbeat now does
   for the keyboard, and serial's `d_read`/`d_write` cdevsw slots then join
   `ttyv.s`'s -- they are `0,0,0` today DELIBERATELY, because a cdevsw slot on
   a line whose bytes never meet `ttyinput` would point at nothing.  It is the
   increment that makes the accepted `^S`/`^Q` divergence matter for serial,
   which is why it comes after T6.

   **ITS FIRST TASK IS A SERIAL PEER, AND THE RIG IS ALREADY IN THE TREE.**  No
   test drives SCC traffic, so nothing has ever measured serial input -- and
   `serial_stop` has been reachable since #240 with nothing measuring that
   either.  But four pieces exist and were simply never combined:
   `mame-hd.sh -serial` (`-modem terminal`, a second MAME screen as a terminal)
   and `-socat` (`-modem null_modem -bitb socket.localhost:25232`);
   `tools/mame_test/serial_feeder.py`, a listener on 25232 that sends `RXOK `
   every 500 ms; the `mame_slots` manifest key, which appends args to MAME's
   command line with no run.py change; and `requires.tcp`, whose documented
   example is that very port.  The worked template is in git history --
   `git show 2bbf4cca3^:tools/mame_test/tests/tip_rx_diag.json` -- deleted with
   the whole suite at `2bbf4cca3`, not because it was wrong.  The feeder starts
   OUTSIDE the harness, which is why `requires.tcp` gates it; `host_proc`
   cannot serve, it starts after MAME.

   The probe bank is the live constraint, not the product.  RE-MEASURED
   2026-08-28 with T1-T7 all landed, every half built and read with
   `tools/check_kernel_ceiling.py` immediately after its own build:

       shipping   53,119 B of 65,280   12,161 free
       ttyprobe   63,420                1,860
       ttyprobe2  64,057                1,223   <- the tightest
       ttyprobe3  61,584                3,696
       ttyprobe4  62,725                2,555
       ttyprobe5  62,488                2,792
       ttyprobe6  62,606                2,674

   #233 is CLOSED
   on those numbers: it was filed when `ttyprobe3' had NINE bytes and named the
   re-split as its exit condition, and the re-split happened -- that half has
   3,696 now and the tightest is `ttyprobe2'.  `tools/tryprobe.sh' prints the
   headroom on every run, so the number is in the gate's per-half logs rather
   than existing only while one config happens to be built.

   Two defects came out of increment 5, both filed with their evidence:
   #239 -- a pty
   slave's `TIOCFLUSH` announced a flush that discarded nothing, because the
   driver answered it out of the ring that increment 4 stopped feeding -- and
   #240 --
   `kc_cdstop`'s far shim read its two arguments one byte low, so EVERY
   `ttyflush(FWRITE)` and every `TIOCSTOP` on every line had been dispatching
   `d_stop` against chardev `$02` with the flag arriving as `rw << 8`.  Both
   closed.  #240 was invisible for as long as it existed because the serial
   line was the only device with a `d_stop` body, so the wrong dispatch found a
   zero slot and returned in silence; a pty slave's is the first one a tty line
   was ever meant to reach.

   **THE BACKLOG WAS THEN DRAINED RATHER THAN GROWN (the maintainer, 2026-08-26).**
   Nineteen work items closed in one pass: thirteen had been FIXED IN CODE and
   left open because the branch is not pushed and no MR could auto-close them,
   and six were genuinely open and every one touched tty/UFS.  Those six, in the
   severity order they were fixed:
   #204 -- the
   kernel-C per-task register file was gated on `KCPROBE`, a knob documented as
   "0 in a shipping kernel", and T4 increment 4 had just given the tty bank a
   real sleep (`ttywait`); ungated, and the knob's 0 setting turns out not to
   ASSEMBLE, in three banks, so it now fails at its declaration with the reason
   beside it.
   #237 -- fcc
   emitted no safepoint at a backward `goto`, so a `goto`-formed loop reached no
   syscall boundary and could not be interrupted; K&R A.9.6 decides it ("a
   continue ... is the same as goto contin") and `tests/M21/goto_test.c` was
   already a red witness nobody had read.
   #235 -- the
   heartbeat's signal post wrote `_shTmp0` against its own file's discipline;
   the value rides the stack now and `tools/check_hb_scratch.py` holds the rule.
   #220 -- a
   machine with no /dev volume HUNG at boot, because `Blk_Read`/`Blk_Write`/
   `Blk_Status` never tested `DEV_CLASS_EMPTY` and dispatched SmartPort PIO at a
   slot nobody had registered.
   #203 -- the
   bank-listing race is structurally impossible now, and its residual was real:
   a SUCCESSFUL link left the last failure's 11 MB `error_output.txt` in place.
   #229 -- ERASE
   and KILL had no fixture; `delkill` drives both, and its first draft passed
   VACUOUSLY with `^U` dead, which is what its `zqk`-absent assertion now
   catches.

   Increment 7 of stage 4 measured red first and the
   cause was not in the tty code:
   #234 --
   `_fcc_bank_for_int` read a crt0-seeded cell that nothing seeds in the
   kernel, so every runtime int-to-pointer cast in kernel C reconstituted bank
   0 and `cinit` built the clist pool inside the `STK_PAINT` user-stack arena.
   One fcc-runtime fix retired that and
   #230 with it,
   and `OBUFSIZ` is back to upstream's 100.  The review that found it also
   turned up
   #235, the
   heartbeat writing `_shTmp0` against `toolbox.s`'s own discipline.

   **FIVE DEFECTS BEHIND THE CAMPAIGN, FIXED 2026-08-29 AND NOT PART OF IT.**
   The port is done; these are things it made reachable, and each is written up
   on its own work item rather than here.
   #253 is the one
   worth knowing about, because it was not a tty defect at all: libc's signal
   disposition table lives in the DATA BANK, a vfork child SHARES that bank, and
   tcsh's child sets `signal(SIGINT, vffree)` before it execs -- so every
   external command left the shell with SIGINT pointing at the child's cleanup
   routine, whose tail is `_exit(1)`.
   #254 restores
   dzstop's half of the TS_FLUSH handshake that the dzstart/dzxint collapse
   dropped;
   #255 gives the
   kernel-C write seam the line name and the cursor accounting the syscall path
   already had; and
   #65 -- open for
   twenty days -- was `Con_PutChar` rendering unhandled control bytes as SPACES,
   so each echoed `^C` ate a column until the line wrapped.  The console follows
   `partab`'s classes now, which is the same table `ttyoutput` keeps `t_col`
   with, so the screen and the kernel agree by construction.  `stty` gained the
   local modes on the way, without which none of #65 could be tested.

   **THE PATTERN IN THEM IS A STALE COMMENT, FOUR TIMES.**  `_vf_common` claimed
   a vfork child borrows its parent's pid (it does not -- `Task_Alloc` hands
   back a fresh slot), `_Vc_ConWriteEnter` claimed `_Vc_FromCdIdx` answers C=0
   for the console (false since #121), `tty.c` called spltty/splx empty macros
   (T6 gave them bodies) and `stty.c` said the console had no local modes.  All
   four were true when written and were corrected in the same pass; the first
   cost a written-built-and-measured fix for a non-problem.  A comment is a
   remembered conclusion, and this campaign invalidated a lot of them.

5. **Bank-0 / kernel-scratch campaign — ★ASSESSED, and the map was wrong.**
   Conclusions:
   [`bank0-assessment-conclusions.md`](audits/bank0-assessment-conclusions.md)
   (**read section 6** — sections 1-5 are the original ranking, superseded in
   part). The question asked was whether bank 0 could be cleared enough to
   hold BSD-shaped per-process state; the answer to that is still no. But the
   assessment's own map **stopped at `$C000` and was short a quarter of the
   bank** — the language card is 16 KB of real RAM reachable by both `S` and
   `D`, measured in MAME and **confirmed on a real IIgs**. Landed since:
   `$C035` shadow inhibits (!156), the per-pid kernel stacks into
   language-card RAM (!158), and the console scalars out of the direct page
   (!159), which frees `$C0-$CF` and retires Option A's stated blocker.
   **Next: Option A, the per-task kernel direct page**, into the `$0C00-$17FF`
   that !158 vacated — the only costed option that fixes the whole
   shared-scratch class without touching any of the 3,744 use sites.

   *NPROC is no longer bounded by bank 0 at all.* !158 removed that wall
   (per-pid kernel stacks vs `BLK_STAGE`, apple/fgx#43/#45). Measured
   2026-08-13 across NPROC 11-20: **12 passes today** for one
   `cfg/system.cfg` knob and one arena page; 13+ fails on the TCB table in the
   **kernel** bank (`$02:0800` into `FGX_CODE` at `$02:0B00`); 16 is a hard
   ceiling from five statically sized signal handler tables. The arena was
   never the limit — it stays at or above 150 pages through NPROC=14 — so
   extra arena pages buy deeper user stacks, not more processes.

   One defect filed:
   #101 — **no
   test covers the per-VC console scalar save/restore.** Mutating the copied
   range so the scalars are not saved at all leaves all six VC tests passing;
   `vccursor` counts whether a cursor is *drawn*, not whether one *survives a
   switch*. The last defect in that mechanism was found by a person noticing a
   homed cursor did not stick. `far.s` now pins the range with
   `ERR VT_ATTR/VCS_VT_LEN` (mutation-verified), but that is a layout check —
   it cannot tell whether the copy is correct.

4. **Performance campaign — ★ THE SEAMS ARE EXHAUSTED, 2026-09-11.** Ad-hoc
   rather than chartered; the plan of record is
   [`history/plans/2026-09-09-performance-dive-results.md`](plans/2026-09-09-performance-dive-results.md),
   whose section 7 numbers the options 7.1-7.9.
   **Five-exec mixed workload 1573 -> 1104 frames, -29.8% (1.43x); read-shaped
   7.12x.** Landed: 7.1 (libc output buffering, #373), 7.2 (boot-class pile,
   #368), 7.4 (printf's 32-bit division, and the signed long modulo at !309),
   7.5 (loop safepoint, #371), plus the VFS name cache (#380), three fcc
   codegen changes (signed `/2^k`, compare-branch fusion at -7.8%, 32-bit
   constant shifts) and `clrbuf` (!311, -20.8% on a copy).
   **Dead on measurement, do not re-litigate:** 7.6 `bdwrite` (the stdio write
   buffer is already one UFS block, so every block is written exactly once and
   there is nothing to coalesce), 7.7 indexed blkcache, raising NBUF (inert,
   not a regression), PackBytes, the universal libc pile, Toolbox-for-speed.
   **Open:** 7.3 (fork, #372) is the last item measured in hundreds of
   milliseconds and only its pair-0 half is blocked on #361; 7.8 (zero-init
   into bss) is the only untried lever and is a linker change; 7.9 (80-column
   console) is interactive-only and cannot be regression-tested under MAME.
   **Why it is being set down:** the biggest non-idle item in the profile is
   now 3.6%, roughly a quarter of the run is outside FGX (idle 10.4%, the
   SmartPort card's own firmware 14.0% -- and the card CLASS is worth 7.6%,
   `retronet` 1104 frames against `microdrive` 1020), and the last three
   compiler-side changes measured zero.
   **The campaign's instruments were wrong three times, which is its main
   legacy.** `FGX_MAME_PRIMARY` defaults to `autoboot`, which types the command
   at 6.24 frames a character and added a flat +755 frames to every timing and
   42% of a profile (fixed at !306: a `primary_input` manifest key, and each
   test now prints the path it used). The runtime oracle scored a hung chunk's
   forty fixtures as regressions while printing that they were not (fixed at
   !308). And `> /dev/null` is not a valid control at all -- see #386 below.
   Defects the campaign turned up, with their evidence on the issues:
   **#381** (uio copy, 2.4% ceiling), **#382** (module-bank attribution),
   **#383** (four fixtures main carries unseen, the oracle samples so nobody
   sees them), **#384** (`ufsprobe` is red on main: a block on the free list
   and owned by an inode), **#385** (why generated files are committed),
   **#386** (`/dev/null` writes take a per-byte fallback and are 59% SLOWER
   than writing to a real file).

6. **Shared libc campaign -- ★ SUB-PROJECTS 1-5 DONE, merged (!408,
   2026-10-10).**  The per-tool
   libc pile becomes one `libc.so.MAJOR.MINOR` across several banks, loaded
   once and bound by name before `main` by a user-space binder, on the SunOS
   4.1.3 model; design and its measured motivation (376 KB of pile re-reads
   per everyday-session round, 142 of 157 pile classes serving one binary):
   [`history/plans/2026-09-28-shared-libc-design.md`](plans/2026-09-28-shared-libc-design.md).
   **Sub-project 1** (on main): the heap limit cell `HEAP_LIM` at $FFF8 --
   the break's ceiling, and fork carries everything from it up (1f5e257,
   5e16ae2, 4fc1baa; probe `forkpair_lim`).  **Sub-project 2**
   ([spec](plans/2026-09-28-shared-libc-sp2-design.md)):
   `lib/libc.so.1.0`, compiled once in library mode with each member's
   statics in a per-process block; statically linked programs start through
   it (`libcso` in MAME).  **Sub-project 3**
   ([spec](plans/2026-09-29-shared-libc-sp3-design.md)): termlib
   and curses as shared libraries too; `fgx_dyn.py` links a program
   against them (import tables, prebound ordinals and CRC, reachability
   bitmaps, K&R common symbols, the fit rule, the shadowing warning), and a
   host binder, `fgx_bind.py`, writes an image the existing loader runs --
   `dynso` (prebound and by name) and `cursso` pass in MAME.  **Sub-project
   4** ([spec](plans/2026-09-30-shared-libc-sp4-design.md)), on the
   same branch: step 1 (the kernel's hooks and `ld.mod`, the registry),
   step 2 (loading: `ld_load`, `/sbin/ldload`, `/etc/ld.so.conf`, libc
   resident from boot) and step 3 (binding on the machine: `crt0_dyn`, the
   binder in libc, `LD_TRACE_LOADED_OBJECTS`, `LD_BIND_DIGEST`, `ldd(1)`; a
   dynamic `true(1)` execs in 87 ms, the same as the static one) landed.
   Step 4 (first use, the race, the kill, reclaim and the binder's
   errors, in MAME with their controls) landed, and with it fixes to
   SIGKILL of a stopped process (apple/fgx#505), wait(2)'s ECHILD
   (apple/fgx#508), sh's signal() calls (apple/fgx#507) and an fcc
   function-pointer store (apple/fgx#506): sub-project 4 is complete, and
   apple/fgx#509 (a first-use load with no room past the binder's scratch)
   is fixed on the branch.  **Sub-project 5**, the cut-over
   ([spec](plans/2026-10-04-shared-libc-sp5-design.md)): step 1
   landed ([plan](plans/2026-10-04-shared-libc-sp5-step1-plan.md))
   -- a program of any number of code segments links dynamically through
   the build, its binder tables go in the code segment with room, the
   binder's patches are repeatable and a bound shared text's later execs
   patch only the data segment; `wc`, `ls`, `ul`, `worm` and `ntpd` are
   dynamic, every other tool still on piles; and host-bound images copy
   their cores into their own data bank (apple/fgx#517).  Step 2 landed
   ([plan](plans/2026-10-04-shared-libc-sp5-step2-plan.md)) --
   `/etc/rc` loads `ld.mod` and runs `ldload` first, before `fsck`, and
   stops if libc cannot be made resident (`ldload` exits 2);
   `/etc/ld.so.conf` lists libfgx, so libc and libfgx are resident from
   boot, and the boot's daemons use libfgx; libfgx.so and libutil.so are
   shared libraries above libc, and libfgx's spawn family passes
   `environ`; the static set -- init, getty, login, fsck, mount,
   ifconfig, modload, test, echo, hostname, mv, tar and ln, plus ldload
   -- links with fgx_static, sh stays a pile program until step 3, and
   179 manifest tools and fas link dynamically (ac stays on its pile
   until step 3 measures it); found and fixed along the way:
   apple/fgx#518 (the pty stand-in tables lacked d_stop, and a
   cooked-defaults flush hit the wrong line) and a second instance of
   apple/fgx#517's class (a host-bound image's core fixups frozen in
   shared text).  Step 3 landed
   ([plan](plans/2026-10-05-shared-libc-sp5-step3-plan.md)): one
   code-bank packer (`fgx_pack`, `--pack` in fgx_dyn and fgx_static)
   replaces the three per-shell packers. tcsh and vi are dynamic against
   libc.so and libtermlib.so, and tcsh fits 8 segments with its binder
   tables in a code bank. sh is static (fgx_static gained `end` as ld(1)
   defines it, `--stack-pad`, and archive-search shadowing, so libc's
   own malloc/free callers bind to sh's, as 2.11BSD's ld does). All
   three are FGX3. ac is dynamic
   (data 56,546 bytes under LIM $EA23). Found along the way:
   apple/fgx#519 (pre-existing unguarded recursion cycles in elvis and
   tcsh, open) and apple/fgx#520 (a failed segment load lost its errno,
   fixed).  Step 4 landed
   ([plan](plans/2026-10-05-shared-libc-sp5-step4-plan.md)): the
   toolchain fixtures link with fgx_static instead of `crt0_far.s`
   (`toolchain/tests/fixture_link.py`), goldens unchanged.  Step 5 landed
   ([plan](plans/2026-10-06-shared-libc-sp5-step5-plan.md)): the
   pile path is gone from the build, the toolchain (fgx_ld's LIBC kinds,
   `crt0_far.s`, the `.fgxa` archive outputs; `fgx_ar` stays) and all three
   kernel banks (the far loader's pile read and registry arm, the core
   bank's registry and reference counts, the text table's pile byte); the
   loader refuses an unknown segment kind and a relocation naming a
   segment the image lacks (apple/fgx#522, which crashed the machine) with
   ENOEXEC, and `FGX2_MAX_SEGS` is 8.  Static links take 2.11BSD's
   fltused/ffltpr split (apple/fgx#521): a static program that prints no
   floating point links a stub in place of the float printer, 7.2-7.5 KB
   less in each of twelve static tools.  Step 6, measured against SP5's
   start (2f40a0fa0, built and booted the same way): at an idle prompt
   46-47 of the 56 pool banks are in use, from 53 (the cached pile classes
   are gone); the volume holds 12,704 blocks, from 17,694 (the 164 pile
   files were 3,934,630 bytes); the core bank has 1,394 bytes free, from
   1,163, the far bank 800, from 19.  Exec time: a dynamic `true(1)` 91 ms,
   a static `echo(1)` 149 ms; the pile-era static `true` was 80 ms, accepted
   (the maintainer, 2026-10-07).  `manyproc` passes at SP5's start as well: shared
   text, merged before SP5, is what made twenty-two sleeps fit.  The
   working-set buffer cache follows the campaign, sized to what it leaves.

7. **Public disclosure campaign -- CHARTERED 2026-10-10, ACTIVE from
   2026-10-11 (the memory campaign closed).**  A sanitized copy of the
   repository goes public on GitHub.  Before it does: no personal
   identifiers anywhere in the tree or its history (names, addresses,
   hostnames, internal URLs, machine paths); every licence correct and
   stated, FGX's own and each vendored or ported source's (2.11BSD,
   4.3BSD-Reno, NetBSD, MIT krb5, llvm-mos's soft-double, and the rest
   `docs/PROVENANCE.md` names); and no inaccurate historical cruft --
   stale plans, RESUMEs and docs that describe a tree that no longer
   exists are corrected, archived or dropped.  The campaign also decides
   how development runs once the public copy exists: where work happens,
   how changes reach GitHub, and how the private history relates to the
   public one.  Its first deliverable is that process and an audit of the
   tree against the three criteria; the plan follows from the audit.

   **State (2026-10-11):** audit, decisions and plan in
   `docs/history/plans/2026-10-11-public-disclosure-{audit,plan}.md`.  Done
   on `feat/disclosure`: licence defects (elvis's invented Regents notice,
   the llvm-mos licence text, third-party licences named in LICENSE and the
   README, the font and music provenance, free stories in place of the
   Infocom files); escaped and stray files untracked; current files free of
   names, private hosts and paths; `tools/check_public.py` (the identifier
   gate, run by `tools/gate.sh`) and `tools/export_public.py` (the export).
   The first export (FGX 1.17.0, one commit, 7,009 files) builds from a fresh
   clone.  The process is in `docs/RELEASING.md`, "The public copy".
   Remaining: the maintainer creates the GitHub repository and pushes; the
   final public address replaces the placeholder; novi waits on its
   author's licence.

---

## Active push / north star: self-hosting `fcc`

"Build FGX software inside FGX." `fas` already self-hosts on-device; `fcc` is
the missing half — today it runs on the Mac host. All prereqs are cleared
(libc, multi-bank loader, FGX2 ABI, per-task fd). The M12 self-host bootstrap
was parked once (bending `fcc.c` to fcc-accepted form + the on-device
`fcc → fas → fgx_ld` pipeline + memory). Doesn't need multitasking, so it
sequences naturally after the concurrency work.

Already done: the shells are C ports (`/bin/sh` is the 2.11BSD Bourne shell,
the interactive shell is tcsh), the fcc multi-pass front end (whole-TU token
vector -> AST) retired the source-replay bug class a self-host would have
tripped on, and separate compilation of multi-file programs works. What remains
to de-risk M12: the memory shape and `#`/`##` items catalogued below, then
bending fcc's own source to fcc-accepted form. See `docs/fcc-known-issues.md`.

**Self-host catalogue (tagged for this push, NOT gating current work —
The maintainer's 2026-07-10 ruling: compiler correctness first, self-host after):**
- **Memory shape (T2-4 report, 2026-07-10; table in
  `docs/history/plans/2026-07-09-fgx-t2-frontend-completion.md`):** worst
  elvis-TU front-end footprint ≈0.9MB on the host (token vector 486KB +
  macro-body tokens 262KB + AST peak 117KB + intern 10KB at
  sizeof(Tok)=56); ≈350KB at a packed 16-byte Tok; fcc's own
  parse_stmt.c is ~2.7× the largest elvis TU by lines → ~1MB packed.
  Needs the multi-bank arena; per-function AST windowing already caps the
  parse side.  Budget number: decided when this push starts.
- **Capacity limits** (`fcc-known-issues.md`, "Capacity limits"): each a
  fail-loud die; whether fcc's own source fits them is measured when this
  push starts.
- **`#`/`##` token paste** — never supported, explicitly deferred until
  self-host/a port demands them.
- **Unsigned literals** (hex ≥0x8000 as unsigned per C89) — deferred at
  A-1 for blast radius; revisit on the token-pass front end.
- **fcc-source C subset audit** — chained assignment now compiles; the
  remaining "can fcc parse fcc" delta gets measured when the push starts
  (the M12 bootstrap notes are the seed).

---

## Backlog by area

### Networking (build on the W5100 socket stack)

- **syslog: syslogd runs at boot, and `logger(1)` writes to it** -- `syslog(3)` sends its
  line to `/dev/log` over AF_UNIX SOCK_DGRAM, and **2.11BSD's `syslogd(8)`** is
  started by `/etc/rc`, routing by 2.11BSD's own `/etc/syslog.conf` into
  `/usr/adm/messages`, the console and logged-in users, with `/dev/klog`
  (increment 4) as its kernel input. `su`'s audit line lands there. Two deltas
  in the daemon itself: six stack buffers made static (75 -> 11 pages, measured),
  the internet bind address zeroed as netbsd-0-9 does, and the UDP port opened
  only with `-u`, OpenBSD's flag -- by default the machine is not a network log
  server, and needs no W5100 socket for one. `daemon(3)` forks as upstream's
  does (apple/fgx#494), so rc starts syslogd, `update(8)` and `inetd(8)`
  without `&`; `update` is upstream's verbatim and inetd detaches as
  upstream's does.
  `logger(1)` is 2.11BSD's, with three defects repaired as 4.3BSD-Reno's has
  them (a `%` in the message was the format; an unbounded strcat; a stream-less
  fprintf). Boot is about five seconds longer (the klog replay, an
  fsync per line) and the MAME harness boot estimate is 55 s.

  **Remaining:** the kernel's scheduler trace lines are to be **removed** once
  the kernel-slot and stack-arena subsystems settle.  They have been hidden from
  `/dev/klog` since apple/fgx#482
  (delivered, they fed syslogd a loop that kept the root busy), and in the ring
  they still crowd out what the harness looks for.

  Found and fixed on the way: a socket buffer now carries its bank (apple/fgx#480),
  `recvfrom` works on AF_UNIX (#479), chip-transport sockets on a card-less
  machine no longer answer from floating bus (#296 -- its select half; the
  FIONBIO half is unexamined), `sigsuspend(2)`, and `syslog(3)` bounding the
  line it forms -- through a new `vsnprintf(3)` -- where an over-long `logger`
  message ran into the format it was reading and away through the bank. Design and census:
  `docs/history/plans/2026-09-19-syslog-af-unix-design.md`, sections 4.5 and 10.

  Subsumes the "Software IP/ICMP/ARP stack (Backend B)" item below (→ P2/P5) and
  unblocks IPv6 (needs the software stack).
  See also `docs/history/plans/2026-07-19-networking-roadmap-scope.md` (Track A/B;
  reframes P4 from a bespoke FSM to a **faithful 2.11BSD `netinet` port**) and
  `docs/history/plans/2026-07-20-loopback-multinic-ifconfig-caps-scope.md`
  (loopback + multi-NIC triggers, the W5100 coexist-vs-replace decision, near-term
  `ifconfig` slice). **Coexist first:** the software stack serves `127.x`/local;
  the W5100 keeps the wire. `lo0` comes up organically here (loopback-first),
  NOT as a bespoke socket-layer shim (rejected as throwaway).
- **TCP urgent data (out-of-band)** -- **U0 LANDED; U1 (apple/fgx#423) is next.**
  The socket layer still has no urgent mechanism: `so_oobmark`/`SS_RCVATMARK`/
  `sohasoutofband` are absent, `select(2)` has no exceptional set, and nothing
  raises SIGURG. `send(MSG_OOB)` no longer silently succeeds as an ORDINARY send
  -- it is refused with EOPNOTSUPP (apple/fgx#422), which also took three
  adjacent defects with it: `sendto`/`recvfrom` carry their flags word now
  (apple/fgx#440), `send` honours `MSG_DONTWAIT` (apple/fgx#441), and
  `setsockopt` validates its level, option and value length instead of answering
  success for everything (apple/fgx#439). The maintainer scoped this 2026-09-13: other
  controllers exist besides the Uthernet II, so the stack should implement the
  mechanism
  correctly even where the W5100 cannot pass the flag -- which the datasheet
  confirms it cannot (no urgent register, no URG bit in `Sn_IR`, no urgent
  command in `Sn_CR`). This is the capability model this section already
  charters, arriving one feature at a time: loopback gets full semantics and is
  testable by the existing telnet fixtures, W5100 TCP answers EOPNOTSUPP, and
  `telnetd`'s deferred `interrupt()`/`sendbrk()` path becomes reachable. Six
  increments U0-U5, smallest-blocker-first. Full design:
  `docs/history/plans/2026-09-13-tcp-urgent-mechanism-design.md`.
- **DNS resolver** — ★**LANDED.** The "natural next net feature" note was stale.
  libc has a real `gethostbyname` (slim purpose-built resolver: `/etc/hosts` then
  a single DNS A-query over UDP, `/etc/resolv.conf` written by dhclient), and
  `host`, `nc`, `ping` and `telnet` all take hostnames today.
- **TCP server** — `listen`/`accept` — **LANDED** (`SYS_LISTEN`/`SYS_ACCEPT`,
  `net.mod` `_Net_Xport_Listen`/`_Accept`, `echod` tool; CHANGELOG "Server-side
  TCP — Phase 6.2"). As predicted, W5100 has no accept backlog — the listening
  socket *becomes* the connection.
  - *Open design point: **who re-arms the listener**.* Because the listening
    socket becomes the connection, `accept()` leaves the listening descriptor
    owning no hardware socket, and today `inetd` rebuilds it — measured working,
    4/4 connections served on the wire and again back-to-back, guarded by the
    `wireacc` fixture. The BSD-shaped alternative is for the kernel to re-issue
    OPEN + LISTEN itself so `listen(2)` means what it says and no server has to
    know the hardware moved. That is design direction, not a defect
    (apple/fgx#149 was closed as not reproducing once it was measured); it
    belongs with the P1 `ifnet` seam below, where the W5100 stops being the
    thing userland is written against.
- **Connected-UDP** `connect()` on `SOCK_DGRAM`; `getpeername`/`getsockname` —
  one shared prerequisite: the socket record has nowhere to keep a peer address,
  so it needs a field-add + resize.  `shutdown()` half-close is ★**LANDED**
  (`SYS_SHUTDOWN` #100) and no longer part of this item.
  **Value is modest and worth stating honestly:** everything that speaks UDP
  today (`dhclient`, the resolver, `ntpinfo`/`ntpplay`, `udpecho`) works with
  `sendto`/`recvfrom`.  `connect()` would let them use `send`/`recv` and get ICMP
  port-unreachable reported instead of timing out — a real but small win, mostly
  in error reporting.  `getsockname` is what a BSD port would reach for to print
  its own address.  Pick this up when a port needs it, not before.
- **`select`** — ★**LANDED** (`SYS_SELECT` #99; libc marshals the fd_sets and
  pre-converts `timeval`->ticks).  **`poll` is open but has NO CUSTOMER** and
  should probably stay unbuilt: it is SVR3/POSIX, not BSD, and **zero files in
  the vendored 2.11BSD tree call it** (measured 2026-08-01), while `select` is
  what `ping`, `telnet`, `ftp`, `rsh` and `date` actually use.  Build it only if
  a future port demands it; it would be a libc wrapper over the select
  machinery, not kernel work.
- **`ifconfig` capabilities + real flags + `-a`** — **LANDED 2026-07-31** (tool-only:
  status rendered from the real `IF_Flags` byte, so a down card no longer prints
  the hardcoded `flags=67<UP,BROADCAST,RUNNING>` every interface used to show;
  honest W5100 `options=<TCP4,UDP4,ICMP4,ARP,CSUM_*>` offload line, `-a` list-all,
  `ifconfig(8)` man page). Retired later by the SIOC* model below.  *Written
  2026-07-20 and held unmerged on `feat/ifconfig-caps-trackb-scope` until
  2026-07-31; the branch's own roadmap entry claimed it had landed on the day it
  was written, which it had not.*
- **SIOCGIFCONF / SIOCGIFFLAGS ioctl model** — **this is also the gate on porting
  `ifconfig` and `route` from BSD.**  Provenance audit 2026-08-01: both are
  FGX-native C written against our own `IFC_*` ABI, and 2.11BSD ships
  `sbin/ifconfig` + `sbin/route` — but the BSD tools are written against the
  socket-ioctl model below.  Land the ioctls and the two tools become ports
  rather than rewrites; do them before, and the work is thrown away.
  Original item: evolve the kernel ifconfig ABI from
  the bespoke `SYS_IFCONFIG` (32-byte ifreq, `IFC_GETN/GET/SET`) to BSD `SIOC*`
  over a socket, so a real 2.11BSD `ifconfig` ports and the tool-side capability
  rendering retires for a kernel `SIOCGIFCAP` report. Fits the P1 `ifnet` seam.
- **Multi-NIC (2nd Uthernet-II)** — the ifnet table holds 4 (`IF_MAX`), but the
  W5100 driver is self-mod-bound to one detected slot (231 `_w5PatchTbl` sites), so
  a 2nd card is detected but undriven (no crash). Rework to per-card indexed base
  addressing + ifnet multi-registration + slotscan-all. Shares the P1 `ifnet` seam.
- **Software IP/ICMP/ARP stack (Backend B)** — drop the W5100 offload for ICMP
  and run a software path over MACRAW so netdump *sees* ICMP and there's no
  hardware interception. Big effort; fits the offload-agnostic `_Net_Xport_*`
  seam as a non-offload link backend. Keep UDP/TCP on the offload.
- **IPv6** — W5100 is IPv4-only (would need the software stack).
- **AppleTalk driver** — LocalTalk/AppleTalk over the SCC. It would own the
  printer port (SCC chan A) and set `_apTalkPort` (the kernel SIM layer already
  arbitrates chan ownership: `_Sys_SimInstallImpl` refuses an `ESIM_ATALK` to a
  driver requesting an AppleTalk-owned channel). Until it lands, `_apTalkPort`
  is always 0 on raw-IIgs FGX, so `serial.mod` brings up both ports; once it
  exists, `serial.mod` cleanly skips whichever channel AppleTalk claims (the
  tty00 work wired + tested that skip path). Big effort (LLAP/DDP/NBP, the LAP
  manager, a `protosw` address family); fits the network driver re-architecture
  (P1+) as another link backend / address family. Would ideally be a C module.

### Kernel / memory

- **Concurrent fork (apple/fgx#494) -- MERGED in !396, 2026-09-27.**  After
  `fork(2)` the parent and the child both run: the child releases its parent
  at its first interruptible sleep, and the two are swapped in and out of
  their shared addresses as they are scheduled -- 2.11BSD newproc's no-core
  path.  A fork's members form an image group: the stack range and direct page
  swap through the image cache's homes, and the mutable banks through bank
  homes, N-1 for N members, the live banks exchanging with a home at each swap
  so nothing is allocated in swtch.  An owner that exits or execs hands the
  image to a remaining member.  daemon(3) forks as upstream's does and
  /etc/rc starts its daemons without `&`.  Cost: the shell's fork-then-exec is
  still two image copies (it neither sleeps nor outlasts a quantum before the
  exec); a released member's swap is one exchange of its live extent.  A child
  that computes without sleeping still keeps its parent waiting.  Design and
  plan: docs/history/plans/2026-09-26-concurrent-fork-{design,plan}.md.

- **Kernel UTC clock and time zones (sub-projects 1 and 2 of the time work for
  NTP and Kerberos 5).**  Sub-project 1, merged in !393: the kernel keeps UTC as
  32.32 seconds, advanced per VBL by `machdep.tick` (16688 us, measured on a
  real NTSC IIgs); `gettimeofday`/`settimeofday`/`adjtime` are syscalls
  124-126, the battery clock is read at boot and written back in local time,
  and modules stamp through `KSVC_TIME`.  Sub-project 2, on
  feat/libc-time-zones: localtime(3) reads IANA tzdata 2026d zone files (all 597,
  /usr/share/zoneinfo; /etc/localtime is UTC unless the image is built with
  `FGX_TZ`) through 4.3BSD-Reno's ctime.c, with mktime(3) and POSIX `TZ`
  strings; date(1) takes local time (2.11BSD patch #454); adjkerntz(8) sets
  the kernel's zone offset at boot and exits.  Designs and plans:
  `docs/history/plans/2026-09-19-kernel-clock-{design,plan}.md`,
  `docs/history/plans/2026-09-25-libc-time-zones-{design,plan}.md`.
  Sub-project 3's cron half, on feat/libc-overlay: 2.11BSD's cron(8) and
  crontab(1) (Vixie cron 2.1, entry.c's @ keywords fixed), started by /etc/rc
  after update; /etc/crontab runs `adjkerntz -a` every half hour from midnight
  to five, so a DST change the machine is up across moves the kernel's zone
  offset.  It brought fchown(2)/fchmod(2) (SYS 129/130), stdio's update modes
  and the libc overlay.  Open: `ntp -s`.

- **Multi-bank module container: one `.mod` file, several bank overlays
  (deferred 2026-09-20).**  A module is currently one bank, so a subsystem that
  outgrows a bank becomes two names in two boot lists: `prodos` + `prodosw`, and
  `ufs` + `ufsdir` + `ufsprobe`.  The proposal is that `prodos.mod` be one file
  carrying both bank images, placed into their respective banks by one
  `modload prodos`.

  **Most of this already exists and the finding should be the starting point.**
  `bin/fgxunix` is an `FGXUNIX1` container (`tools/mkfgxunix.py`) whose block-0
  segment table already carries six bank overlays under two selectors --
  `SEL_KERN` for `fgx.bin`/`fgxfar.bin`/`fgxtty.bin`, and `SEL_KMOD` for
  `vfs`/`ufs`/`ufsdir`.  So the VFS trio is already one file and three banks,
  pre-staged by stage 2 rather than `modload`ed, for the reason that header
  states: they were in `modload.conf`, "which needs a filesystem -- so they
  could never be the filesystem".  `ufs` is therefore already a kernel overlay,
  and only `ufsprobe` sits outside -- deliberately, as probe code that leaves
  when the UFS campaign closes, so folding it in is the wrong direction.

  The open work is `prodos`.  Two routes: generalise the `FGXUNIX1` segment
  table into the FGXM container so `Mod_Load` can place N bank images from one
  streamed file (keeps ProDOS optional, no kernel rebuild to change a
  filesystem), or move it into the pre-stage window.  The window holds **four**
  kmod banks with three used (`REST_KMOD_FIRST_OFF`, `include/kernel.s:108`), so
  the second route needs two more banks out of the user pool and five lockstep
  edits -- `REST_HEAP_FIRST_OFF`, `REST_USER_FIRST_OFF`, `RESTOFOS_MIN_BANKS`,
  the duplicate in `src/boot/stage2.s`, and `BANK_BITMAP_BYTES` in `loader.s`.
  Banks are the binding resource, so the streamed container is the likelier fit.

  **Do not motivate this with module-count arithmetic.**  apple/fgx#463 appeared
  to be a defect at eleven loaded modules and was not: the count set the kernel
  heap's layout, and the layout decided which object a wild store from
  `_Pipe_FreeSlot` landed on.  It is fixed in net.mod, not by loading fewer
  modules.  Consolidation is worth doing for atomicity and for a module being a
  subsystem rather than a bank -- not for a count.

- **Kernel placement / core-bank campaign -- ★COMPLETE 2026-08-12.**  Six
  subsystems left the core bank -- the blockdev registration seam, `ramdisk`,
  `pty`, `net_loop` + `pipe`, and the loopback-first decision -- taking it from
  **662 bytes free to 5,133** (52,835 of 57,968), with eight modules sharing one
  bank and 41 KB spare.

  **The list is exhausted, not paused.**  Every remaining core-bank occupant is
  held there by the placement rule itself: reachable from an interrupt or a
  firmware callback, bound by boot order, or substrate the module loader runs
  on top of.  `toolbox.s` installs the 60 Hz heartbeat via `_SetHeartBeat`;
  `sim.s` is the serial interrupt manager; `dev.s` is read *through* by the
  loader when it fetches module images; `ttyv.s` costs 29 crossings including
  seven `far_patchsites` entries.  `uthernet.s` splits on boot order rather than
  on the ISR alone -- `_ScanSlots` and `_W5_PatchSlot` run at `main.s:433-434`,
  before `Mod_LoadConf` at `:443`, while the probe half runs at `:490` and is
  genuinely eligible.  The whole eligible remainder across the kernel is ~635
  bytes, and collecting it would cost a new `NETOP`, a stranded bank-0 slot,
  about eight DBR-discipline fixes of the #93
  class, and a new filesystem service trio -- into a bank with 5,133 bytes free.

  **Do not re-derive the target list by file size.**  Ranking candidates by
  emitted bytes puts `toolbox.s` third and picks rule-forbidden code three times
  out of seven; size cannot see interrupt coupling, boot order, or substrate.
  The next core-bank pressure should be answered by re-reading the rule against
  whatever is new.  The two large module-shaped subsystems are blocked on
  something other than effort: the console on an early-output story (a
  prestaged console is only callable after the prestage walk, so early panics
  would have nowhere to print), and the VFS on the UFS campaign.

- **BUG: a blocked `SYS_WRITE` lost its residual count to another task** --
  issue #89,
  ★FIXED 2026-08-11.  `@sw_chardev`'s per-byte loop keeps its remaining count
  and target device index in the kernel singletons `_Sys_WrRem` /
  `_Sys_WrCdIdx`, and `_PtyM_Write` blocks while the pty in-ring is full.
  `swtch` carries only `SE_UserSP`/`SE_UserDP`/`SE_CallerBank`, so an
  intervening task's write overwrote both and the sleeper resumed with a
  foreign count, running off the end of its own buffer and emitting whatever
  followed it -- a `$03` among those bytes is a `^C` to the pty line
  discipline, which killed the reader with SIGINT.  `SE_CallerBank` was added
  in Phase 5.3d for the identical failure in the READ direction; these are its
  write-side counterparts.  Fixed by parking both on the task's own kernel
  stack across the call: the sched entry has no room (`SE_SIZE` is full at 32
  and must stay `TCB_SIZE/2`), and the kernel stack is per-task anyway.

- **BUG: the RAM-disk driver's slot scratch aliases the block layer's 32-bit
  key** -- issue
  #91, ★FIXED
  2026-08-11 on `feat/ramdisk-module`.  `RamDisk_RegisterDev` used `_blkBuf+2`
  as its device-slot scan scratch; that address is `$14`, which is `_blkNumHi`,
  the block layer's block-key HIGH word.  Registration therefore returned with
  `_blkNumHi = 1`, and the next `Blk_Read` latched it and asked for block
  `$0001_0002` instead of block 2.  `$14` was genuinely spare padding when the
  driver was written -- `dpmap.s` records it as "was `_blkUnit` (retired) +
  pad" -- and UFS 1.0 made it live.  In-kernel the poisoned read was some
  unremarkable boot read, which is why it never surfaced; as a module it was
  the mount enumeration, so `/MNT/RAM5` silently stopped mounting.  Fixed by
  moving the scratch to `_fsTmp1`, which `Blk_Read`/`Blk_Write` preserve for
  their callers.

- **The sbrk malloc rework broke large allocations** -- issue
  #11, ★FIXED
  2026-08-02.  `malloc(>= $F000)` routes back to dedicated Memory Manager
  blocks, and snapshot-fork now COPIES those banks (kind-4 block-table rows
  carry an owner pid), so the capacity comes back without reintroducing #4's
  write-through.  Fails closed: a fork that cannot copy a bank returns EAGAIN
  rather than sharing it, proven by `bigforkx` rather than asserted.  The
  mid-size hole this exposed -- payloads from 32762 to $F000 failed outright,
  too big for the signed-sbrk guard and too small for the MM path -- is closed
  too.  Per-process heap is one private sbrk bank, ~59 KB, the same data space
  2.11BSD gave a PDP-11 process; the "19.7 KB" in the original report was
  `mallocmax`'s leftover after probes it never frees, and `heapcap` measures it
  honestly now.  **DECIDED (the maintainer, 2026-08-02): the small-allocation ceiling
  stays at one bank.**  Main's ~512 KB was the SHARED kernel arena, which is
  exactly what fork could not isolate, so it was never a figure to restore as
  such; ~59 KB is what 2.11BSD gave a PDP-11 process and what every port here
  was written against, and large buffers have the big path, which is unbounded
  and fork-safe.  Growing the heap by private banks would work and stay
  fork-safe, but costs a 64 KB copy per bank per fork AND per restore, paid by
  every fork of a program that grew.  Revisit if a real program hits the limit.
  Related: #10,
  a latent K&R argument-width bug the new allocator's guard made fatal, also
  fixed.


- **BUG: `tcsh` hangs on `^Z` of a FOREGROUND pipeline** -- issue
  #5, ★FIXED
  2026-08-02.  Root cause was in **libc, not the kernel**: `setpgrp()` was
  defined as the zero-argument SysV form hardcoded to `setpgid(0, 0)`, but
  2.11BSD userland calls the BSD **two-argument** form, and K&R C has no
  prototypes -- so the arguments were pushed and silently ignored and every
  call meant "make me a group leader under my own pid".  tcsh reaches setpgid
  through `tc.os.h`'s `#define setpgid(pid, pgrp) setpgrp(pid, pgrp)`, so each
  pipeline member landed in its OWN group; `^Z` stopped only the leader and the
  shell waited forever.  Guarded by `pgrptest` (proven red first) and the
  `p5_z_*` reproducer set.

- **fcc implicit int-to-pointer bank stamp -- KNOWN DEFECT, deferred
  (apple/fgx#12).** fcc stamps bank 0 on an int-to-pointer conversion written
  WITHOUT a cast; the explicit-cast path was fixed 2026-07-24 and this one was
  missed.  2.11BSD's `round()` macro does it on every stak update, so bsh's
  arena aliases the kernel's bank-0 stack region and a `.` sourced script over
  ~14 KB kills the shell with no output.  Documented in sh(1).  Fixing it means
  converting every int-to-pointer path AT ONCE (global, local, DP-IMG, call
  return) and revalidating the 2.11BSD ports as a unit -- a partial landing is
  measurably worse than none, because the ports currently sit at a coherent
  wrong-bank equilibrium.  Plan in `docs/history/RESUME-2026-08-03-fcc-int-to-ptr-campaign.md`.
  Three attempts at merely ANNOUNCING the failure were tried and reverted: with
  no MMU the kernel cannot see the write, and every sampling point either false-
  positives on healthy programs or is never reached because the machine has
  already stopped.

- **`uncompress` corrupt-input guard FIXED 2026-08-04 --
  [#17](https://gitlab.com/apple/fgx/-/issues/17).**
  2.11BSD used the MMU as an INPUT VALIDATOR: compress armed
  `signal(SIGSEGV, oops)` and the handler's own comment is
  "wild pointer -- assume bad input".  Our port dropped it (FGX cannot deliver
  SIGSEGV) without replacing the check, so a corrupt `.Z` walked the LZW decode
  stack off its 8000-byte block and into the malloc arena in silence.  Bounded
  and reported explicitly; the bound is derived (a chain of L needs ~L*L/2 input
  bytes, so 8192 exceeds anything a ProDOS volume can hold).  Verified by
  fuzzing 300 corrupt files against a HOST build, where the MMU is the oracle:
  71 fired the guard, the same 71 faulted unguarded, 300/300 agreement.
  `czcorrupt` is in the gate.  Found by sweeping 2.11BSD for fault-dependent
  code after #13 -- `sh` was the only one that RECOVERS, `roff/nroff` looks
  similar but checks `sbrk` properly, and the rest only lose a message.

- **`sbrk(2)` is POSIX again FIXED 2026-08-04 --
  [#13](https://gitlab.com/apple/fgx/-/issues/13).**
  sbrk had been `_exit(136)`ing on refusal because "the vendored source cannot
  be taught to check".  It already checks: `fault.c:30` carries
  `IF setbrk(brkincr) == -1 THEN error(nospace)`, and what FGX lacks is the
  write-fault that DELIVERS that signal -- so upstream's out-of-memory path was
  unreachable code, not absent code.  The maintainer took the POSIX option: sbrk returns
  -1 + errno, and BSD's own response is routed to the one call site FGX can
  reach (`stak.c` locstak).  An interactive shell now prints `sh: no space` and
  keeps its prompt.  Second bug fixed alongside: `sbrk` was undeclared in the sh
  sources, so K&R int-truncation stamped bank 0 on `brkend`.  Coverage is
  libc-level only (`heapkill`, both halves, mutation-tested); a shell-level
  fixture is blocked behind #12 and #16.

- **`exec cmd` FIXED 2026-08-04 --
  [#14](https://gitlab.com/apple/fgx/-/issues/14).**
  execve had two arms, and the non-fork one -- the one `exec cmd` takes, since
  the shell builtin does not fork -- called `Load_Binary` with A=0, "honor the
  header's bank".  That is FGX1 shape: `_LoadFGX2` (shared by FGX3) requires a
  caller-supplied override bank and returns EINVAL without one, so on a disk
  where every binary is FGX2/FGX3 that arm could not load a single one.  The
  issue's reported EBADF was a misreported errno pointing at fd handling.
  Deleted the arm; all execs now take the bank-swapping path, which additionally
  frees the outgoing image when the caller owns it.  `softexec` is in the gate
  and covers all three failure modes independently (correctness, the -1-with-
  caller-intact failure contract, and a 61-generation leak loop).

- **BUG: fork does not inherit signal handler tables** -- issue
  [#27](https://gitlab.com/apple/fgx/-/issues/27).  `signal.s:1131`'s own
  comment on `_Sig_ResetOnExec` claims "fork correctly INHERITS handlers; exec
  is what has to undo that" -- the first half is false: `process.s` never
  touches `_sigHndPtr`/`SIGHND_*`, so a forked child's handler slots come back
  zeroed like any fresh task's, and only `TCB_SigIgnore` is copied.  Masked
  today because the dominant pattern is fork-then-exec, and exec is supposed
  to reset caught handlers anyway; a fork WITHOUT exec silently drops a caught
  SIGTERM/SIGINT to the default action instead.  Needs a decision, not just a
  patch: implement real POSIX inheritance, or fix the comment and document the
  deviation in signal(3)/fork(2).

- **BUG: three `pty.s` sleep sites discard the interrupted-carry** -- issue
  [#28](https://gitlab.com/apple/fgx/-/issues/28).  Same class as the
  `_waitpid_core` hang this branch fixed: a `JSR _sleep` whose returned carry
  -- "a signal is pending, do not block" -- gets thrown away, so the caller
  re-waits and spins forever instead of returning EINTR.  The waitpid site is
  fixed; `pty.s:385`, `:472` and `:633` still have it.  None is known to hang
  today (none was reachable from this branch's tests), but the failure mode is
  identical and needs the same unwind-and-return-EINTR treatment, checked
  per-site for what state has to be restored first.

- **Bank-0 stack campaign -- CLOSED 2026-08-03 (MR !45).**
  bsh's bank-0 reservation drops 6,912 B -> 2,816 B (27 -> 11 pages), giving
  SIXTEEN pages back to the 149-page shared arena per shell in a pipeline, while
  its sourced-script depth goes ~60 -> ~84 AND the death at that limit becomes
  loud instead of silent.  Recursion-cycle locals move to a DEDICATED bank (the
  task data bank was tried and does not work -- bsh's stak arena owns it).  tcsh
  cannot take it: ~16,749 B of code against ~3,998 B free.  Open: GitLab #12
  (bsh's arena silently truncates a sourced read past ~158 commands) and
  #16 (a sourced line over ~256 chars hangs bsh silently -- pre-existing,
  found while testing #13, and with #12 the reason #13 has no shell-level
  fixture).  #13 and #14 are FIXED (see below).
  The worst-case pipeline now reserves 87 of 149 arena pages, down from 106.
  **SUPERSEDED 2026-08-06: 123 of 156** -- the arena gave two pages to `NPROC`
  8 -> 10, and `stack_measure`'s one-hop allowance fix (MR !60) re-sized vi and
  tcsh UPWARD because both had been sized to a floor.  Current numbers and the
  status of both structural options:
  [`bank0-stack-status.md`](audits/bank0-stack-status.md).
  DEPTH is fixed and its failure is loud; CAPACITY is relieved but the arena is
  still fixed at 149 pages -- chaining (3.3) remains the answer there and is
  unbuilt, blocked behind 1.2's size wall.  3.3b (far-backed window) is decided
  AGAINST on its own gate: `mints` had to reach 0 and stands at 12/573.
  See `docs/history/plans/bank0-stack.md` sections 5.8 and 8.
  Supersedes the B0-B3 sketch below for everything except the B1 reclaim (done)
  and the rejected-alternatives record.  The maintainer ruled: fix it once, not kick the
  can.  Measured by a new fcc census (`FCC_STACK_CENSUS`): exiling address-taken
  locals to the data bank takes tcsh's reservation 55 pages -> 8, and exiling
  ALL locals in recursion-cycle members takes bsh's `execute()` from 121 to 19
  bytes per level (~60 -> ~380 sourced commands).  Then chained bank-0
  stacklets make the bound the whole 149-page arena, shared dynamically rather
  than reserved statically -- ~2,000 levels.  NOT far-memory-backed and NOT
  unbounded: the 65816's 16-bit S means a live stack can never leave bank 0.
  Increment 1.3 is a shippable end state on its own; the commitment point is
  3.3.  Liens (was B3's successor) are deleted as redundant.

- **tcsh's stack shrink: MEASURED, WORKS, BLOCKED on the DATA bank.**
  (2026-08-06.)  tcsh is CLAMPED -- it needs 133 pages of bank-0 stack and
  reserves 83, i.e. it ships sized to a FLOOR, the same condition that made vi
  die on its first keystroke.

  Five one-word changes take it to **74 pages, unclamped** (worst case
  123 -> 114 of 147): `ChangeSize` (`ed.screen.c`), `backeval` (`sh.glob.c`),
  `heredoc` (`sh.dol.c`), `t_search` (`tw.parse.c`), `bgetc` (`sh.lex.c`), each
  function's large locals made `static`.  The code is written and behaviour-
  tested (`tcstatic`, `tccomp`; `tcstatic` is mutation-proven), and it is
  DISABLED -- `build_tcsh_link.sh` ships `TRACKED=""`.

  **SHIPPED 2026-08-06** once apple/fgx#42 was fixed.  #42 was never about these
  conversions: adding ANY ~6 KB to tcsh's data segment -- including a
  `char[5924]` that is never referenced -- stalled a VIRTUAL-CONSOLE login, with
  tcsh alive in state R and 27 KB of heap free.  Root cause was in **fcc**:
  casting an AUTOMATIC struct to a pointer took the int->pointer bank rule
  (always DBR) instead of the struct value's own carrier bank, so
  `(char *)osetexit` in tcsh's `sh.parse.c alias()` -- `getexit()` on a stack
  `jmp_buf` -- addressed the DATA bank at a bank-0 frame offset and wrote 12
  bytes into the malloc heap.  Where that landed depended on the heap base, i.e.
  on the data-segment size; past ~34 KB it hit a live free-list block header and
  the next `free()` walked a cycle forever.  Fixed in fcc's `N_CAST` arm;
  regression fixture `toolchain/tests/M4/struct_cast_bank.c`.

  **The earlier claim here -- that tcsh exhausts its data-bank heap during login
  -- was WRONG on both halves.**  The `heap full: brk refused` lines it cited are
  bsh's, and routine (`_Sys_Brk`'s own comment says so); tcsh's peak heap use
  during an interactive login is 6,632 B of a 37,206 B heap.  That was settled by
  adding a break HIGH-WATER MARK to the kernel and a HEAP column to `ps` -- the
  first attempt reported the LIVE break, which shows a process that peaks at
  startup and frees as idle, the same current-versus-peak trap the stack side
  already paid for.

  Also measured while doing this, and closing an old hope: the same five changes
  moved `mints` 663 -> 573, so the static lever does NOT cheaply open the
  far-backed window's gate (§3.3b) -- ~30 more conversions would be needed,
  through code that cannot safely take them.

- **Bank-0 compaction: +9 arena pages, no Memory Manager change.  DONE 2026-08-06.**
  (2026-08-06 audit; full map in
  [`bank0-stack-status.md`](audits/bank0-stack-status.md) section 11.)  Nothing in bank
  0 can move to another bank or to the heap -- stacks and direct pages are
  pinned by the 65816's 16-bit S and D, BLK_STAGE's bank is firmware-mandated,
  and the $0300 gateway exists to BE a bank-0 address.  But the layout below the
  arena is loose:

  - `FGX_STK_KTASKS` reserves 16 pages and uses 11 (NPROC=10), each 256 B with a
    measured peak of ~58 B;
  - `$0C00-$0FFF` is stage-2-only (DIR_BUF/IDX_BUF), transient like the
    $3000-$BFFF KERNEL_BUFFER the arena already covers;
  - `BLK_STAGE` needs 512 B at an address FGX picks.

  Kernel stacks moved to $0C00-$16FF and BLK_STAGE to $1700; FGX_STK_ARENA
  $2200 -> $1900, 147 -> 156 pages.  Four constants, no code -- everything else
  already read them symbolically.  `ps` reports `stack arena: 25/156 pages used`
  on the running machine, and the worst-case pipeline is 123/154 (arena 156 ->
  154 when `kernel.nproc` went to 11; the figure also now includes `init` and
  the argv-frame page, both of which apple/fgx#30 found missing).  TN#27 claims $0800-$BFFF as
  ONE block, so the MM never sees it.  A further +5 needs the kernel stacks
  narrowed to 128 B (pid<<8 -> pid<<7 in the allocator, canary and dispatcher) --
  separate step, real risk, a fifth of the gain.

  ALSO FOUND: `FGX_SYSVARS` ($0200) has ZERO references tree-wide, and
  `$0400-$07FF` looks free (the loader claims only 256 B at $0300).  Both are
  STRANDED -- live stage-1 code at $0800-$0BFF (BlkTramp/CoutTramp, which the
  kernel JSLs forever) sits between them and the arena, and ROM loads stage 1
  there.

- **BANK-0 NEXT STEPS -- five tracked items (2026-08-06).**  Ranked; the case for
  each is in [`bank0-stack-status.md`](audits/bank0-stack-status.md).

  1. **Refresh the baseline harvest.**  `tools/stack_baseline.py` works but its
     numbers predate MR !60 (which re-sized vi and tcsh UPWARD), the vi shrink
     and the 156-page arena.  Cheap, and it is the evidence base item 2 rests
     on.  What it already shows: tcsh reserves 21,504 B against a measured peak
     of 2,942-4,234 B, tar 4,608 against 1,204 -- while grep/ls/wc (1,024 vs
     540) and bsh under a sourced script (8,192 vs 7,150) are TIGHT.  **The
     over-reservation is concentrated in exactly the programs that cause the
     pressure.**
  2. **Make the one-hop allowance honest.**  `maxfn` charged TWICE is 20,360 B
     of tcsh's 34,012 (60%), plus 2,312 B of `CYCLE_TURNS` reserve -- model
     terms, not measured consumption, and the reason tcsh is clamped.  The
     signal half narrows to the actually-registered handlers for **+4 pages**
     (measured: `maxfn` 10,159 vs `alrmcatch` 9,064), sound ONLY with a fallback
     to `maxfn` when any `signal()` call passes a non-literal.  `CYCLE_TURNS=8`
     is an admitted guess; calibrate, never blind-cut (an undersized reserve
     fails as a silent neighbour spill).
     ALREADY MEASURED AND WORTH ZERO: narrowing the FN-PTR half to address-taken
     functions.  Both `maxfn` heads (tcsh's `dosettc`, elvis's `v_overtype`) are
     in their program's builtin dispatch table.
  3. ~~**Fix apple/fgx#42.**~~  DONE 2026-08-06 -- an fcc bank bug on
     `(char *)automatic_struct`, not a resource limit.  The tcsh shrink is on
     (arena worst case 123 -> 114 of 156) and the third virtual console is
     unblocked.
  4. **Kernel stacks 256 -> 128 B.**  +5 arena pages; peak use is ~58 B.  Changes
     `pid<<8` to `pid<<7` in the allocator, the canary seed and the dispatcher
     check.
  5. **argv/envp frame off the stack.**  ~1 page per live task, up to 11.  NOT a
     lever: `argv[]`/`envp[]` are 16-bit BANK-0 OFFSETS into that same stack page
     (`include/loader.s`), read by crt0 and libc, so it is an ABI train across
     every binary.  Recorded so nobody re-derives it as cheap.

- **Demand-swapped task stacks (retire the fixed bank-0 stack arena).**
  (2026-07-31, from the `tar`-under-`tcsh` ENOMEM.)  **The structural problem:**
  the 65816's stack pointer is 16-bit, so *every* task's hardware stack must live
  in bank 0.  FGX carves them all from ONE fixed region -- `FGX_STK_ARENA`
  (`include/kernel.s`) -- via a first-fit page bitmap (`Task_AllocStack`).
  The arena is **$2200, 147 pages**, ending at `FGX_DP_KTASKS` $B500 (it was
  $3200-$AFFF / 126 pages in the 2026-07-31 layout this item was written
  against).  Each task's share is a **static worst-case
  reservation held for its whole life**, sized by `stack_measure.py` from the
  deepest static call-graph path plus a `CYCLE_TURNS` recursion reserve.  A shell
  blocked in `wait()` is touching a few hundred bytes of a multi-KB reservation
  while its children cannot spawn.

  That coupling has now produced the SAME bug twice -- a co-resident set that
  overflows 126 pages, surfacing as `stk ENOMEM <n>p` and a useless
  "Cannot allocate memory" from the shell:
  - 2026-07-27 (`1aa865c44`): arena grown 112 -> 126 to fit bsh + tcsh(56) + tar.
  - 2026-07-28 (`39adfaeeb`): `TASK_STACK_MAX_PAGES` 56 -> 83 so tcsh fit
    unclamped -- its budget note checked tcsh + bsh + *elvis*, but not tar, the
    exact workload the arena grow existed for.  Re-broke it the next day.
  - 2026-07-31: fixed by shrinking the three binaries (tar 30 -> 16 via
    `putfile`'s per-recursion-level buffer, tcsh 83 -> 55 via `-DTC_BUFSIZ=256`,
    bsh 23 -> 9 via `gocsh`'s static `newt[1000]`).  **87/149 then.**
    **123/154 as of 2026-08-07**, on a corrected model (apple/fgx#30).  The 55 quoted for tcsh above never held:
    `TC_BUFSIZ=256` is still set, but that measurement was taken while
    `stack_measure`'s one-hop allowance was suppressed (fixed in MR !60), and
    tcsh reads 83 CLAMPED with it restored.  The shrink-the-binary lever that
    took vi 51 -> 22 also takes tcsh to 74, but is blocked on tcsh's data bank;
    see the tcsh item above and
    [`bank0-stack-status.md`](audits/bank0-stack-status.md).

  Shrinking binaries buys headroom; it does not remove the coupling.  Two things
  make it bite again: **pipelines** (each stage is a co-resident task -- Unix's
  bread and butter, so the arena must absorb N children, not one), and a **deeper
  process chain**.  The chain LANDED 2026-08-04 -- `init(8)` as a real respawn
  engine plus `getty`/`login`/`passwd`/`halt`; design in
  [`history/plans/2026-08-04-login-stack-vc-design.md`](plans/2026-08-04-login-stack-vc-design.md)
  -- and it cost the arena almost nothing, because the design lever noted here
  was taken: `login` `exec()`s the shell rather than `fork()`ing it, so only the
  exec transient is ever co-resident.  The deepest login-chain scenario measures
  **28/149** against 87/149 for `tcsh` running `tar` in a pipeline.  Note what is
  NOT yet real: `/etc/ttys` ships exactly ONE line `on` (`console`, running
  `/bin/sh` directly), the `ttyv*` virtual consoles are `off` pending a later
  slice, and it is those concurrent sessions -- not the chain depth -- that run
  into the 3 x `tcsh` = 168 > 149 ceiling below.

  Target: stop reserving peak-for-life.  **Strategy reviewed and settled
  2026-07-31** -- see `docs/history/plans/2026-07-31-bsd-login-stack-scope.md`
  sec 4, which supersedes the earlier sketch here.  Phases B0-B3:
  - **B0 -- budget assertion. ★DONE 2026-08-01 (`cb302fa83`):
    `tools/check_stack_budget.py`, run by the ninja graph.**  A build-time check
    that the known co-resident worst case fits `FGX_STK_ARENA_PAGES`.  The linker
    already knows every binary's page count, so this is a sum and a compare, and
    it is the check whose absence let `39adfaeeb` land.  It counts two things the
    hand sums kept omitting: `Task_AllocStack`'s **+1 guard page per task**
    (task.s:611) and the **execve transient**, where the new stack is allocated
    (process.s:1494) while the old one is still held.  With guards counted,
    2 x tcsh + tar = 129 > 126 is DEAD, not "exactly at the ceiling".  The
    scenario list grows when a co-residency becomes real -- slice C added the
    login chain on 2026-08-04.  Two under-counts remain, both documented in the
    checker's own header: `init`'s pages (it is in the arena, contrary to a
    long-lived comment) and the argv/envp frame pages the loader adds on top of
    the linker's hint (the accounting itself is GitLab #45; the checker's own
    gap in modeling it is filed separately as
    [#30](https://gitlab.com/apple/fgx/-/issues/30)).
  - **B1 -- reclaim bank-0 pages. ★DONE 2026-07-31: 126 -> 149 (+23).**
    - **B1a (+7, `b426d97e4`).**  `FGX_DP_KTASKS` reserved 16 pid-indexed slots
      at $B000-$BFFF while `CFG_KERNEL_NPROC` is 8, so slots 9-15 were dead AND
      arena-adjacent.  Re-based to $B700 it holds exactly pids 0..NPROC.  The
      trade is now a build error rather than a discovery: NPROC cannot exceed 8
      without moving the block back down and shrinking the arena equally.
    - **B1c (`3a8cb358a`).**  Two-ended first-fit -- big stacks (>= 8 pages) from
      the TOP, small from the bottom -- against the fragmentation noted below.
    - **B1b (+16, `05dbe46e8`).**  `BLK_STAGE` is *claimed* as 4 KB at $00:2000
      but its **working set is 512 bytes**: every transfer is one block
      (`block.s` `LDA #511` + `MVN`) and the only other access is
      `BLK_STAGE+1/+2` for the SmartPort STATUS reply.  `FGX_STK_ARENA` dropped
      $3200 -> $2200 and swallowed that unused tail plus the equally dead
      $3000-$31FF.  No pre-marking of the page map was needed: init has NO
      static $3100 page (it calls `Task_AllocStack` like every other task) --
      three comments claiming otherwise were corrected in the same commit.

      **The `BLK_STAGE` MM claim deliberately STAYS 4 KB** (`toolbox.s:274`,
      `stage2.s:1847`).  Those `DW` entries tell the Memory Manager "hands off";
      the arena spending $2200-$2FFF of that is FGX using its own reservation.
      Shrinking the claim to "match reality" would hand those pages BACK to the
      MM, which now hands them to task stacks.

    Guarded by `memmap.s`'s ERR (arena end == `FGX_DP_KTASKS`, exact equality)
    plus `tools/check_bank0_geometry.py` for the NPROC ceiling and the
    hand-mirrored `stage2.s` copy of `FGX_DP_KTASKS`.  The NPROC ceiling cannot
    be an ERR: it resolves through `CFG_KERNEL_NPROC` and Merlin32 rejects the
    resulting nested-brace expression, and the braces are not optional because
    Merlin32 evaluates strictly left-to-right with no operator precedence.

    **Reclaim is now finished as a source of pages.**  What is left of the old
    "retire `BLK_STAGE` via extended SmartPort" idea is an **I/O throughput**
    item, not an arena one -- see *Extended SmartPort transfers* under
    Filesystem.  Three concurrent deep shells (3 x tcsh = 168) still do not fit
    149, so B3 remains the phase that delivers concurrent multiuser.
  - **B2 -- right-size the reserve (optional).**  `CYCLE_TURNS`(8) x the deepest
    cycle frame dominated every binary pre-shrink (8,488 B of tcsh's 21,194),
    but `-DTC_BUFSIZ=256` already cut that frame, so the remaining win is ~5-6
    pages, not 33.  Risk is asymmetric: `STKGUARD` arms on DIRECT recursion
    only, so mutual cycles are UNGUARDED (tcsh has a 117-member SCC) and an
    undersized reserve fails as a silent neighbour spill, not a clean exit-134.
    Measured turn count only, never a blind constant cut.
  - **B3 -- address-preserving stack swap.  SCOPED 2026-08-06:
    [`docs/history/plans/b3-stack-swap-scope.md`](plans/b3-stack-swap-scope.md)** (phasing B3.0-B3.4,
    gates, and the conditions under which it should be abandoned).

    **GENERALISED 2026-09-18 -- the lane is gone.**  Bank 0 is a cache of
    user images (`docs/history/plans/2026-09-17-bank0-residency-architecture.md`,
    section 5.2): every task is a member of its own range, and when the arena
    has no free run a request of `kernel.stkover` pages or more may be placed
    over tasks that are not running and can be parked -- they are parked at
    the placement, live extent only, and the scheduler restores each to its own
    addresses when it next picks it (`Uimg_*`, task.s).  B3's eligibility rule,
    its two flags, its dwell and its "victim is whoever sits on the addresses"
    finding all carry over unchanged; what changed is that the fixed 78-page
    lane and the staging of a member's argv frame into its home bank are no
    longer needed.  The kernel images went the same way first (R1, kernel-image
    slots).  The scope document below is the record of how the mechanism was
    built and proved; the design document is current.  The scope was
    written against the 2.11BSD kernel plus an independent second review of it;
    two things it changed are worth knowing without opening the doc.  FIRST,
    address-preserving swap makes eviction ADDRESS-constrained, not
    size-constrained -- a returning task needs ITS OWN addresses, so the victim
    is whoever sits on the range the incoming task needs, which turns the shared
    "lane" from a convenience into a derived requirement.  SECOND, the
    eligibility rule is 2.11BSD's (interruptibly asleep), which is blind to
    console focus and therefore correct for pty sessions -- _kVcActive is an
    optimisation hint, not the mechanism.  Original sketch follows.

    **STATUS 2026-08-07: B3.0 and B3.1 are MET and landed; B3.2 is NOT, and its
    design is being amended before any more swap code is written.**  B3.0 is
    `SEF_STKLOCK` plus a `_sleep` assertion; B3.1 is the 78-page lane at `$6700`
    that admits one member at a time, always at the same base.  B3.2 (swap out
    at block, in at resume) was built, wedged on `tcsh -c 'tcsh -c ps'`, and was
    reverted: the design assumed the lane is always free when a member needs it,
    which holds for the scheduler's resume path but NOT for the spawn path,
    where the spawning task can ITSELF be the resident member.  A subsequent
    adversarial review found two more instances of the same shape -- a
    fork/vfork child BORROWS its parent's bank-0 stack while the parent sleeps
    interruptibly (so the parent is an eligible swap victim while its child runs
    on those bytes), and `_Fork_Restore` writes the parent's stack from the
    CHILD's context at two unlocked call sites.  Neither is in the §3.3 survey.
    **B3.2 IS NOW MET (2026-08-07): the lane swap works.**  Two members
    co-resident at `$6700`, parked to private home banks and restored
    byte-exact; `b3swap` proves it with an interleaved-marker workload and a
    per-member stack verification.  All six B3 tests green.  The trigger is
    demand eviction at pick time rather than the scoped eager swap-at-block, and
    residency has exactly one writer.  What remains is B3.3 (hysteresis: two
    RUNNABLE members currently ping-pong, swapping on nearly every context
    switch) -- **B3.3 is now MET too (2026-08-07)**: a runnable resident holds the
    lane for a measured dwell (12 ticks = 200 ms), a blocked one is evicted at
    once so the interactive path never pays it, and the contended cost is
    recorded across four dwells (532 / 208 / 130 / 47 swaps) at the knob itself.
    What remains is B3.4 (`ttyv2` on, three shells).

    Both are now CLOSED (2026-08-07): the survey is amended, and `SEF_STKBORROW`
    supplies the borrower condition -- a parent-side flag that, unlike
    `SEF_STKLOCK`, is allowed to span a sleep and is read only by the victim
    scan, never by the `_sleep` assertion.  It covers `_Fork_Restore` for free,
    since that runs inside the borrow window.  Its set/clear pairing is checked
    by the kernel on every fork (an unmatched clear, or a set that finds the flag
    already on, reports and names the parent), and all three ways of breaking it
    fail `tools/gate.sh`.  What B3.2 still needs is the victim scan that reads
    the flag, plus the spawn-path hand-off in scope section 4.3.

  - **B3 (original sketch) -- console-lane swap.**  Address-preserving swap-out-on-block, scoped
    to console session-leader shells sharing ONE overlapping page range with
    home copies in MM handles outside bank 0, swapped at dispatch on focus
    change.  Console shells are mutually exclusive by human focus; live depth of
    a shell blocked in `read()` is ~1-3 KB, so a switch costs ~3-8 ms at 2.8 MHz.
    Enabling fact: signal delivery is ALREADY swap-compatible -- the kernel
    pushes the handler far-target onto the user stack only at syscall-return, in
    the task's own context (syscall.s:350-391).  Prerequisite audit: confirm no
    IRQ-time path (tty ring, W5100 RX) writes through a stored user pointer
    while its owner is blocked.

    **STATUS 2026-08-06: B3's premise stopped being hypothetical.**  This entry
    was written before virtual consoles existed.  They ship now, exactly one is
    displayed at a time, and the kernel already names the focused one
    (`_kVcActive`) -- so "console shells are mutually exclusive by human focus"
    is no longer an assumption about how people work, it is a kernel invariant
    with a variable holding it.

    **And the audit's main question is answered for the case B3 targets.**  A
    console shell blocks in `read()` on a tty, and the tty path does NOT write
    through a user pointer: keystrokes land in a KERNEL-side ring fed by the
    heartbeat (`Con_PollKey`, console_kbd.s), and `_kTtyRdPtr` holds a
    `_ttyTable` address -- kernel memory, not a user buffer.  Nothing writes into
    a blocked console shell's stack from another context.

    STILL TO AUDIT before this is safe: (b) W5100 RX.  (c) any syscall that
    stores a user-stack pointer across a sleep.  Each is a "does X write into a
    blocked task's stack" question with a yes/no answer in the source.

    (a) IS ANSWERED, and favourably: pty data goes through KERNEL rings
    (`_ptyInRings`/`_ptyOutRings`, pty.s -- 128 B each, kernel-bank `DS`), so a
    write from telnetd's context deposits into the ring and wakes the reader;
    the sleeping shell copies out of the ring into its own buffer IN ITS OWN
    CONTEXT.  Same shape as the console's heartbeat-fed kbd ring.  Nothing
    writes into a blocked shell's user stack from another task.

    **REMOTE ACCESS (the maintainer, 2026-08-06): the safety survives, the PREMISE does
    not.**  B3 was scoped to console shells because they are mutually exclusive
    by human focus.  A telnetd session on a pty has NO focus relationship with
    the console: two remote users plus the local one are three session shells
    made runnable independently by three separate input streams.  Consequences
    for the design, and they are structural rather than cosmetic:

    - **Key the lane on BLOCKED-NESS, not on focus.**  `_kVcActive` becomes an
      optimization hint for the console case, not the mechanism.  A
      focus-keyed lane would have to be rebuilt the day telnetd lands.
    - **The trigger rate changes character.**  Focus switching is human-scale
      (seconds, one per Option-N).  Swap-on-block/swap-in-on-wake fires per
      input burst -- at 1-3 KB live depth and ~3-8 ms a copy, a remote user
      typing at 10 cps costs 3-8% of the machine.  Needs hysteresis (do not
      evict while the lane is uncontended), not a naive swap-on-block.
    - **More than one shell can be mid-syscall at once**, which the focus model
      structurally prevented.  The lane's width must cover however many session
      leaders can simultaneously need their user stack resident -- so the
      admission rule is part of the design, not a tuning parameter.

    Capacity says this is the ENABLING condition rather than an optimization:
    NTTY = 5 (console + ttyp0/ttyp1 + ttyv1/ttyv2), so up to five session
    shells; at tcsh's 84 pages that is 420 against a 156-page arena.

    **Timing WAS on our side; it no longer is.**  This said "telnetd does not
    exist yet (only the telnet CLIENT and `ptyshell`)", which was true when it
    was written.  telnetd(8) and inetd(8) both ship as of 2026-08-17, and inetd
    starts from `/etc/rc`, so a remote session is now something a booted machine
    offers rather than something a future campaign will add.  The constraint is
    live: every accepted connection is a session shell against the same arena.
    See docs/history/RESUME-2026-08-17-inetd-and-lan-telnet.md.

    Why it matters more than the reclaim levers: **reclaim alone can never fund
    three concurrent deep shells** (3 x tcsh = 252 pages against a 156-page
    arena).  Items 1-5 above are worth ~20 pages between them.  B3 funds N
    console shells for the price of ONE, which is a different order of answer --
    and it is the only design on the table whose cost does not grow with N.

  **REJECTED: commit-on-use / lazy growth.**  It reads as the cheap win and is
  not one -- it is a category error on MMU-less hardware.  With no
  virtual/physical split, a growable limit inside a contiguous arena must be
  held free, which is exactly a reservation.  Growing downward in place needs
  the page below the guard page free, but first-fit packs tasks tight, so that
  page is a neighbour's hottest top page; and "grow if it happens to be free"
  converts a deterministic spawn-time ENOMEM into a nondeterministic mid-run
  failure at arbitrary depth.  Growth-by-RELOCATION is unsound outright: fcc
  frames hold ABSOLUTE bank-0 addresses (the prologue `PEI _fcc_fb` saves an
  absolute frame-base word, and `&local` yields absolute pointers that escape
  into DP cells, the heap, and kernel-held syscall args), so the pointers into a
  C stack cannot be enumerated.  **Corollaries:** the same argument kills
  relocate-while-blocked and segmented stacks, and **the arena can never be
  compacted** -- fragmentation must be prevented, not repaired.

  **Unplanned-for risk: fragmentation.**  Today's workloads are LIFO-ish (shell
  spawns child, child exits) so first-fit stays clean, but long-lived login
  sessions ending in arbitrary order produce ENOMEM with sufficient free pages
  and no possible compaction.  B0's assertion will NOT catch it -- it checks
  sums, not placements.  Containment is B1's two-ended first-fit plus
  spawn-time worst-case admission.

  Reclaim alone can never fund three concurrent deep shells (3 x tcsh = 168 > the
  ~150 ceiling), so the gap must come from policy, sizing, or B3's swap.

- **BUG: `check_stack_budget.py` under-counts every scenario** -- issue
  [#30](https://gitlab.com/apple/fgx/-/issues/30).  Two independent
  under-counts, both verified against kernel source.  `init` is treated as
  outside the arena (a static $3100 page, costing it nothing) but that has not
  been true since 2026-07-31 -- `include/kernel.s:263-267` -- it calls
  `Task_AllocStack` like every other task, sized from its FGX1 header hint,
  and B1b's reclaim swallowed $3100 precisely because nothing owns it anymore.
  Separately, `pages_for()` models only `hint + guard`, omitting the
  argv/envp frame pages GitLab #45 added to both real allocation paths
  (`process.s`, `main.s`) -- so every task in every scenario is short at least
  one page.  Neither under-count creates a false green today (worst case is
  still 87/149, comfortably under the 149-page ceiling), so nothing needs
  emergency re-baselining, but headroom decisions made against the checker's
  numbers were made against numbers that were quietly low.

- **Kernel-bank code room: move statics OUT of FGX_DATA (bank-reclaim, continues P0.1).**
  **LARGELY OBSOLETED 2026-08-01 by the far kernel bank** (`docs/history/plans/far-kernel-bank.md`).
  Moving CODE to a second bank turned out to be far cheaper than moving STATICS out
  of `FGX_DATA`: the sound driver, BRAM RTC and the whole console driver relocating
  to the far bank took the core kernel to **47,545 B of 57,968 -- 10,423 free**,
  against the +304 B this item bought before its lever was spent.  The analysis
  below stays because it is still the right analysis IF the kernel bank ever gets
  tight again, and because blocker 2 (relocation self-mod) is a live hazard for any
  cross-bank buffer move.  Phase 3 of the far-bank plan was the lever it named as
  available before this one, and it has now been pulled: `loader.s` moved to the
  far bank on 2026-08-23, core 67 -> 2,554 bytes free.  "Nothing needs it now" has
  been false twice; the honest reading is that this item is the NEXT lever, not a
  retired one, and the far bank has no third obvious tenant.

  (2026-07-26.)  The kernel bank is nearly full and the code ceiling is
  `FGX_DATA - ORG`, so every byte of static data reclaimed is a byte of code room.
  DONE this session: `FGX_DATA $02EC40 -> $02ED70`, ceiling **57664 -> 57968**
  (+304 B).  The binding guard is NOT the top of the bank but
  `ERR KMem_KGlobals_end-1/$02FE00` in memmap.s -- the main `DUM FGX_DATA` region
  must end below $FE00, while the `DUM $02FF00` KGlobals block is SEPARATELY
  ANCHORED and does not shift (raising the canary pin with FGX_DATA is a mistake;
  the ERR catches it).  `KMem_end` now lands at $02FDEA, 22 B spare -- **this lever
  is spent.**

  Candidate statics, ranked by (size x how few reference sites -- moving one swaps
  direct addressing for indirect + pointer setup, so a HOT buffer costs more code
  than it saves):

  | static | size | refs | files | verdict |
  |---|---|---|---|---|
  | `CON_EXPAND` | 512 B | 10 | 1 | good candidate |
  | `CON_FONT_HDR_BUF` | 256 B | 8 | 1 | good candidate |
  | `_cidParentPath` | 72 B | 2 | 1 | trivial but small |
  | `_kAlarmTicks` | 64 B | 12 | 1 | small |
  | `CON_VT_STATE` | 256 B | 231 | 10 | NO -- indirection would cost more |
  | `_fsDirBuf` | 512 B | 122 | 6 | NO -- hot FS path |
  | `_fsPathScratch` | 288 B | 55 | 6 | NO |
  | `_busTable` / `_diskStates` | 64 / 128 B | 34 / 37 | 2 / 3 | marginal |

  **Two blockers found, and they rule out the obvious approaches:**

  1. **The heap route needs DP, and kernel DP is full.**  The established pattern
     (`_kLogBufPtr`, memmap.s:243 -- `Kmalloc(size, M_KERN)` in an `_AllocXxx`
     right after `Kmem_Init`) reaches the block through a **DP long-pointer**,
     because `[dp],Y` indirect-long REQUIRES direct page.  Kernel DP `$A4-$BE` is
     fully allocated with only 1-byte pads at `$A7/$AB/$B3` -- no contiguous 3-byte
     slot, let alone four.  A shared DP "window" pointer would add ~9 B of code per
     site (~290 B over 32 sites, eating most of the 904 B saved) AND is NOT
     REENTRANT -- an IRQ or preemption mid-sequence corrupts it.  Reclaiming DP is
     its own campaign.

  2. **Moving a buffer to another BANK must honour the relocation self-mod.**
     (the maintainer flagged this; it would otherwise have been a silent bug.)  Banks are
     DYNAMIC -- `$03`/`$04` are only `REST_BASE_DEFAULT`-relative nominal values;
     at runtime the console framebuffer bank is `_kConsoleBank`
     (`_restBaseBank + REST_CONSOLE_BANK_OFF`) and fonts are `_kFontsBank`
     (`+ REST_FONTS_BANK_OFF`) -- a THIRD bank, so the two console buffers may not
     even share a destination.  Existing sites such as `console_buffer.s:65`
     `STAL CON_CHARBUF,X` carry an assembly-time baked bank byte that survives only
     because `_RelocPatchWaveE` (main.s:117) rewrites it at boot from a GENERATED
     table (`src/kernel/wavee_bankpatch.s`, "Do NOT hand-edit. Re-run the generator
     if Wave-E baked-$02 sites move", produced by
     `tools/gen_wavee_bankpatch.py`).  A new long-op site
     added without registering it would address a STALE nominal bank and scribble
     into an unrelated region -- silent cross-bank corruption, not a clean failure.
     NOTE Wave-E patches to the live KERNEL bank (`_BANKK`); a console/font-bank
     operand needs its bank from `_kConsoleBank`/`_kFontsBank` instead, so confirm
     how the existing CON_* sites actually resolve their bank before copying the
     pattern.

  **Checklist when this is picked up:**
    1. Determine how existing console-bank long-ops get their runtime bank
       (Wave-E table vs a console-specific patch vs DBR switching).  Do not assume.
    2. Pick the right destination per buffer: `_kConsoleBank` vs `_kFontsBank`.
       The console bank has ~44 KB spare (memmap.s:1024-1029, "about 20 KB inside
       the 64 KB bank; remainder is free for future console growth"), so bank space
       is NOT the constraint -- addressing correctness is.
    3. Re-run the bank-patch generator so new sites are registered.
    4. `tools/check_baked_addrs.py` must pass, plus a boot gate -- the failure mode
       is silent cross-bank corruption, so a green build proves little on its own.

- **Split testing onto its own disk image(s); keep the boot image ship-only.**
  (the maintainer, 2026-07-26.)  MAME's retronet SmartPort (`-sl7`) takes `-hard1`..`-hard8`,
  so we can mount up to EIGHT 32 MB volumes.  Today everything shares one image and
  it has hit the wall: `disk_src` is 44 MB against a HARD 32 MB ProDOS ceiling, and
  on 2026-07-26 `./build.sh disk` began FAILING outright ("59904 bytes required,
  36352 available" staging `TESTS/FCC/PTRBIGFR`).  The fcc runtime-oracle sweep
  image cannot build at all.
  Shape:
    - `/` (hard1) = ONLY what ships with the real OS.
    - test corpora on hard2.. (fcc fixtures ~31 MB alone, testbin, testdata).
  Work items:
    1. **PROVE FGX mounts N units first** -- this gates everything else.  There IS
       a bus/unit table (`_busTable`, `BS_UnitCount` in include/fs.s, populated by
       src/drivers/dev/dev.s), but "discovers >1 unit" and "mounts and addresses
       N volumes correctly" are different claims and only the first is evidenced.
       Write a probe that boots with several `-hardN` images and reports what was
       enumerated and mounted, BEFORE moving any content.
    2. Path changes: the harness, `run_runtime.py` staging, and any test that
       hardcodes `/TESTS`, `/TESTBIN`, `/TESTDATA` need a volume prefix.
    3. `make_disk.sh`/`build.sh`: build several images; `mame_test/run.py` must
       pass the extra `-hardN` args.
  Interim levers already landed: the sweep image sets
  `DISK_EXCLUDE="testbin ntp"`, and `DISK_EXCLUDE="TESTS"` is the stopgap that
  makes the main image build again.  NOTE `disk_src/TESTS/FCC` is UNTRACKED
  oracle scratch (~31 MB of staged fixtures) that accumulates across runs --
  clearing it is safe and is the quickest relief.
  **RE-MEASURE BEFORE ACTING (2026-07-30):** the mechanics under this item all
  changed with the monorepo/ninja merge -- `build.sh` and the `FGX_NO_NTP=1`
  lever are gone, images are built by `tools/ninja/mkimage.sh` (three distinct
  variants; the release one already excludes testbin/testdata/tests), and the
  ~310-manifest MAME corpus was deleted on 2026-07-29.  The premise (fixture
  corpus vs the 32 MB ceiling) may no longer bind; take fresh numbers first.

- **On-disk libc-pile duplication — 567 copies of the same ~50 KB pile.**
  Every FGX2/FGX3 binary embeds its own copy of the shared libc segment, and the
  kernel dedupes at LOAD time by `{size, checksum}` -- not on disk.  Measured
  2026-07-26: `disk_src/TESTS/FCC` is **31.2 MB across 567 fixture binaries
  averaging 56.4 KB**, of which roughly 28 MB is duplicated pile; a fixture as
  trivial as `return_0` costs 56 KB.  `disk_src` totals 44 MB against a **32 MB
  ProDOS volume ceiling that is HARD** (`make_disk.sh` exits 4 over it), and this
  now blocks the fcc runtime-oracle sweep image from building at all.
  Directions, cheapest first:
    1. Stage fixtures PER CHUNK rather than the whole corpus on one disk -- the
       sweep already runs 24 at a time (23 chunk scripts) but stages all 567.
    2. Cull dead fixtures/tools from the image (linear win, no design change).
    3. Structural: a shared on-disk pile that binaries reference rather than
       embed -- i.e. extend the load-time `{size,checksum}` dedup back onto the
       filesystem.  Changes the binary format, so it needs its own design pass.
  The `FGX_NO_NTP=1` lever that dropped the ~1 MB /root/ntp payload went away
  with `build.sh` (2026-07-29); the sweep image still excludes it always.  The
  duplication itself is unchanged -- but see the re-measure note on the item
  above before sizing the work.

- **MM-native `malloc` + DP-pressure relief — ★LANDED (train 2, 2026-07-17;
  FGX v1.8.0 / toolchain v1.13.0).** 32-bit-size MM-backed `malloc` (the
  64 KB per-allocation ceiling is gone), MM-block growth kernel+user, the
  shared `_kHeapCur` heap-cursor pattern (KHEAP_USE) with the "no new
  dedicated DP pointers" rule — since consumed by the train-3 inode table
  and block cache, which share one heap block precisely because both DP and
  KGlobals are at their ceilings. Residual: hot-path (IRQ/sched/console)
  heap-soft-global conversions remain forward-only; unlocked full 16-bit
  `.Z` decode in compress/zcat is still an un-cashed follow-up in the
  userland backlog.
- **Per-tty winsize storage (settable window size / `TIOCSWINSZ`)** — the
  console window is currently a fixed `CON_VIS_ROWS`×`CON_VIS_COLS` (25×80)
  compile-time constant; `TIOCGWINSZ` reads it and there is no `TIOCSWINSZ`
  (`si_gwinsz` in `syscall.s` returns the EQUs). Give each tty in `_ttyTable` a
  mutable `ws_row`/`ws_col` pair (init to the console constants; serial ttys get
  their own), add the `TIOCSWINSZ` ioctl to set it, and deliver `SIGWINCH` to
  the foreground pgrp on change. Unblocks `stty rows N` / `stty cols N` (the P4
  stty port reports winsize read-only for exactly this reason) and lets a
  resized serial terminal propagate to `vi`/curses. Surfaced by the stty(1)
  port (2026-07-14); small once the signal-model `SIGWINCH` path exists.
- **Classic desk accessories (the Ctrl-OA-Esc menu and `$B9` CDAs).**  WHAT
  WORKS TODAY, measured 2026-09-15 on 62415e8fa by pressing the real chord
  through MAME's ADB key fields: the ROM Desk Manager's menu comes up over the
  FGX console, and both Quit and a Control Panel visit followed by Quit return
  to a working shell -- the Super Hi-Res console repaints and `ls` runs.  stage2
  already starts Text Tools and the Desk Manager (`stage2.s:1752-1754`).  What
  that run showed or did not cover:
  - the Desk Manager puts NEWVIDEO and the shadow register back but not the
    border ($C034 low nibble, 2 to 5) or the text colours ($C022, F2 to F4):
    it leaves the Control Panel's settings.  `cda.mod` (increment C1) patches
    SaveAll and RestAll and puts FGX's back;
  - the menu can open anywhere, because FGX never sets the firmware busy flag
    ($E1/00FF) around non-reentrant code, which is what the Desk Manager checks
    before it opens (Toolbox Reference vol 1, 5-3); the run opened it only at an
    idle prompt;
  - FGX's heartbeat keeps running while the menu is open (_kSystemTicks
    advanced a tick a frame through it); what tasks and the serial and
    network drivers do then is unmeasured;
  - CDAs from disk need an OMF loader: the System Loader is in P16 on disk, not
    in ROM, and FGX executables are FGX2.  Then InstallCDA at boot from a
    DESK.ACCS directory;
  - CDAs that call GS/OS have no GS/OS to call, and are NOT IN SCOPE at first
    (the maintainer, 2026-09-15).
  PRIOR ART is GNO/ME, a multitasking Unix on the IIgs that kept CDAs working:
  it patches the Desk Manager's SaveAll/RestAll ($0B05/$0C05) to stop
  processes, run the CDA as process 0 and put Apple's Text Tools back
  (`examples/gno/kern/gno/patch.c:42`, `kern.asm:605-750`), and its console
  driver hands the keyboard to the CDA (`kern/drivers/inout.asm:1812-1881`).
  THE TARGET CDA IS DocVue (the maintainer, 2026-09-15): DOCVu 2.0, Brian Ballweber
  1993-94, freeware ("distribute freely, but do not sell"), an Ensoniq DOC
  monitor drawn in Super Hi-Res, in gitignored `examples/docvu2/` (the 1994
  ShrinkIt archive and its extraction).  Read from its OMF file (one code
  segment of 19,824 bytes plus ~ExpressLoad; cRELOC and SUPER relocation
  records) -- a static scan, so a call built at runtime would not show:
  - IT CALLS GS/OS, narrowly and only on first use: the Loader's
    LGetPathname2 ($2211) for its own pathname, then GS/OS Open ($2010) of
    its RESOURCE FORK (resourceNumber 1, read access), SetMark ($2016) to
    byte 1024, Read ($2012) of the rest, and Close ($2014).  The fork is raw
    packed screen data, not a Resource Manager fork, unpacked with
    UnPackBytes ($2703).  So it is outside the no-GS/OS first scope unless
    those five calls are provided, and the fork has to be reachable (FGX's
    ProDOS mount presents it as `._DOCVu.CDA`; a UFS root has no forks).
  - Toolbox otherwise: MMStartUp/MMShutDown/NewHandle/DisposeAll (it needs
    about 95 KB), FWEntry ($2403), Text Tools WriteLine ($1A0C).
  - Hardware and firmware state it touches: the sound interrupt vector
    $E1/002C and the next vector $E1/0030 (both read and written -- FGX's
    own sound driver also takes $E1/002C), the busy flag $E1/00FF (written:
    its `b' key clears it while it runs), $E1/00CA (the firmware's sound
    volume byte), $E1/00BC and $E1/00CC, the video counters $C02E/$C02F, and
    $C047.
  - It refuses to start unless os_kind ($E1/00BC) is nonzero, GS/OS running
    (`GS.OS/Common/hw.equ.src:440` in Apple's System 6.0.1 source); FGX never
    sets it.
  THE USE CASE is watching the DOC while ntpplay plays (the maintainer, 2026-09-15),
  as players are watched under GS/OS and GNO.  How the sound interrupt allows
  it, from DocVue's code at $009D-$00FD and $2619-$267E: the ROM reads the
  DOC's oscillator interrupt register, saves it at IRQ_SOUNDDATA ($E1/00CC,
  "Save for sound tools", `GSFirmware/Monitor/BRAM.INTR071.aii:1042`) and
  JSLs IRQ.SOUND ($E1/002C).  DocVue saves the JML target it finds there --
  ntpplay's handler -- into a JML of its own, installs a wrapper that reads
  the vertical counter, calls the saved handler, reads it again for its CPU
  load meter, and restores the vector on exit.  So the player keeps running
  underneath, in the sound interrupt, while every FGX task is stopped for the
  CDA; FGX's IRQ entry already passes non-SCC interrupts to the ROM.
  ntpplay reads the oscillator number from $E1/00CC as NinjaTrackerPlus
  does, so a wrapper that overwrites A no longer stops its engine (measured
  with a DocVue-shaped wrapper under MAME).  What stands in the way:
  - DocVue replaces IRQ.VBL ($E1/0030) with a handler whose two exits
    ($2744, $2856) both RTL without calling the old one; the old vector is
    used only to restore it.  FGX's heartbeat runs from the ROM's VBL
    handler: with a handler of that shape put in the vector under MAME,
    _kSystemTicks stopped for as long as it was there and resumed at full
    rate when the vector was put back.  So while DocVue is on screen FGX's
    tick, lbolt and keyboard poll stop, and the clock loses that time.
    (A VBL handler that returns carry set also makes the ROM clear the VBL
    enable in $C041, after which the heartbeat never resumes on its own;
    DocVue's exit rewrites $C041 from the value it saved on entry.)
  The CDAs under `examples/mentzer/` (the ORCA/C Echo and Calendar samples, APPOINT, ZipDA,
  TextPrinterCDA, SoftSwitch, GNO Snooper) are REFERENCE ONLY, never test
  material or fixtures: their provenance is unknown (the maintainer, 2026-09-15).
  DECIDED (the maintainer, 2026-09-15): DocVue's GS/OS and Loader calls are in scope if
  DocVue runs unmodified; os_kind is set only as part of providing them; CDAs
  are loaded by a privileged userland `loadcda FILE`, one per run.  Design:
  `docs/history/plans/2026-09-15-classic-desk-accessories.md` (`cda.mod` with
  `/dev/cda`, in the shape of BSD's modload and /dev/lkm).  C1, C2 and C3
  landed: `loadcda` installs DocVue with its resource fork, cda.mod's GS/OS
  and Loader stubs serve the fork from memory, and with
  `ntpplay` playing DocVue shows the live oscillators; Quit repaints the
  console.  `/etc/rc` installs every CDA in `/usr/fgx/cda` at boot, and DocVue
  ships there.  OPEN: the busy flag around kernel sections the menu must not
  interrupt; RemoveCDA.

- **A monitor desk accessory (`fgxmon`).**  The Ctrl-OA-Esc menu opens from
  anywhere -- mid-syscall, mid-driver, with the shell wedged -- so a desk
  accessory is the one program that runs when nothing else can.  `fgxmon` is a
  READ-ONLY kernel inspector for the two cases the MAME harness cannot serve:
  real hardware, which has no Lua, and a wedged machine, where a memory dump is
  a guess about what the addresses meant.  Panels for tasks and their wait
  channels, the deferred-work flags an interrupt sets for someone else to
  consume, the kernel log ring (which `dmesg(1)` cannot print once the shell is
  gone), console and video state, the interrupt vectors, banks, devices, and a
  memory viewer; each names in a sentence what looks wrong in what it sampled.
  DECIDED (the maintainer, 2026-09-15): it serves PEOPLE AND MACHINES from ONE
  rendering -- columnar, with a schema version and the kernel build id -- and
  every value is printed the way a person understands it, with the raw value
  beside it where that is what one would type into a debugger: `S sleeping`,
  `WCHAN_KBD (console keyboard)`, `19 /dev/cda`, `$7C:EDB2`, `15062 (4m 11s)`.
  It calls nothing in the kernel, allocates nothing while frozen, refuses to
  read I/O space, and refuses to decode a kernel whose build id it does not
  match, reading its addresses from a GENERATED debug map rather than
  hardcoding them.  A report it saves survives to a shell through a buffer
  loadcda registered.  Design:
  `docs/history/plans/2026-09-15-fgxmon-monitor-cda.md`.  Not started; D1 (it
  runs, with the memory and vector panels) needs no kernel change.

### Filesystem
- **A ProDOS filesystem type (`mount -t prodos`), read and write** -- the
  sanctioned return of ProDOS, per the 2026-09-04 decision that removed the
  in-core layer "until an FST is created for mount_prodos", and campaign goal
  3 ("support external filesystem types, consistent with BSD").  The maintainer scoped
  it 2026-09-13 with WRITE in scope, which is what decides the design: a
  read-only mount could key a node on the ProDOS key block the way isofs keys
  on the ISO extent, but seedling->sapling->tree promotion MOVES the key block
  (FGX's own retired `_pfw_promoteSeedToSap` says so), so the node key has to
  be the directory-entry location instead.  P1 (apple/fgx#428) is done:
  mount(2) is Reno's `mount(type, dir, flags, data)` and vfs_mountat
  dispatches through a vfssw[] each filesystem module fills at load, which
  took fcc's far-bank indirect call reading the pointer's bank first -- the
  alternative, a vfs.mod hop, overflowed mount(2)'s 512-byte kernel stack.
  P2 (apple/fgx#429) is done: prodos.mod mounts a ProDOS volume read-only,
  with the node layer keyed on directory-entry location (a directory on its
  own key block, pcfs's canonical form).  P3 (apple/fgx#430) is done:
  `mount -t prodos -r` reads a volume -- lookup, read, readdir with `.` and
  `..` -- through mount_prodos(8).  Inode numbers are key blocks, because the
  entry-location key does not fit 16 bits (apple/fgx#434).  A GS/OS extended
  file reads as its data fork, with its resource fork and Finder info in an
  AppleDouble `._NAME`, as macOS and netatalk present one.  P4 (apple/fgx#431)
  settled names and metadata: GS/OS's recorded case, uid/gid 0, and a mode
  from the access byte, enforced for non-root callers; mount_prodos(8) states
  them.  P5a (apple/fgx#432) writes files that exist, under `mount_prodos -o
  write`: allocation, promotion to sapling and tree, and ProDOS 8's entry and
  directory revision, checked by cadius.  P5b (apple/fgx#432) creates files
  and makes directories as ProDOS 8's create does, growing a full
  subdirectory; prodos.mod moved to a module bank of its own for the room.
  P5c (apple/fgx#432) removes files and directories, freeing blocks at the last
  reference so an open unlinked file keeps working.  P6 (apple/fgx#433) renames
  and truncates, and splits the write half into prodosw.mod, a bank of its own.
  MODELS:
  netbsd-0-9's isofs for the skeleton (3,102 lines, foreign; ~800 of them are
  Rock Ridge, which is the synthesize-Unix-semantics reference) and its pcfs
  for everything write needs that a read-only filesystem cannot answer.  Reno
  has NEITHER -- it ships nfs and ufs and reserves MOUNT_PC empty -- so Reno
  is the model for the switch only.  ~8,500 lines of ProDOS format knowledge
  are recoverable from git, written against the retired `_fop_*` vtable rather
  than vnodeops.  cadius is the independent write oracle.  Six increments
  P1-P6.  Full design:
  `docs/history/plans/2026-09-13-prodos-fst-design.md`.
- **`rename(2)` cross-directory hang FIXED by this branch (`74a7b154f`)** --
  issue [#29](https://gitlab.com/apple/fgx/-/issues/29), to be closed on
  merge.  `mv` between two different directories hung the machine (a PC
  histogram was dominated by ROM block-I/O firmware -- an unbounded
  block-read loop, not a CPU spin); same-directory rename was fine.  Root
  cause was `_Mod_RegistryAppend` smashing the module it had just loaded.
  No test in `tools/mame_test/tests/` had ever exercised `rename`/`mv` at
  all before this branch.

- **Extended SmartPort transfers -- kill the per-block `MVN`.** (2026-07-31,
  reframed out of the stack-arena campaign, where it was mis-filed as a
  page-reclaim item. B1b already took the pages; what remains is throughput.)

  **The problem.** Standard SmartPort `ReadBlock`/`WriteBlock` ($01/$02) take a
  **2-byte** buffer pointer with bank $00 implied, so every transfer must land
  in `BLK_STAGE` and then be `MVN`'d to its real destination bank (`block.s`,
  both directions). At 7 cycles/byte that is ~3,584 cycles ≈ **1.3 ms per
  block** at 2.8 MHz -- pure overhead, ~164 ms on a 64 KB read, and it is worst
  exactly where the device is fastest (RAM-backed SmartPort HD, CF).

  **The fix.** Extended calls ($41/$42) take a **longword** buffer pointer, so
  the firmware writes straight into the destination bank and the `MVN`
  disappears. (Their 4-byte block number is irrelevant to FGX -- the ProDOS
  volume format caps at 65535 blocks / 32 MB, far under the 3-byte limit.)
  Verified in *Apple IIgs Firmware Reference* ch. 7: p.141 "For standard calls,
  this is a word-wide pointer defaulting to bank $00. For extended calls, this
  is a longword pointer"; Table 7-3 p.156.

  **Support is per-CARD firmware, not the IIgs ROM, so PROBE -- do not assume.**
  Issue an extended Status ($40) during device scan and keep the standard path
  for any unit that rejects it. That makes this safe to attempt without betting
  the boot on it; the cost is carrying two transfer paths in `block.s`
  permanently, since the standard one can never be dropped.

  **This was DONE and it works** -- see the next entry for what the probe
  measured, including the five-byte inline structure an extended call requires
  (without which $40 and $41 fail identically and the firmware never returns).

- **Multi-block reads -- THE 2026-07-21 REJECTION WAS WRONG, and the reason is
  worth more than the conclusion.** (Corrected 2026-07-31 by a gated probe;
  findings folded in here 2026-08-08 so the branch that measured them can be
  retired.) `ReadBlock` is always exactly one 512 B block; multi-block lives in
  the *generic* `Read` call ($08 / extended $48), which is **byte-count based**:
  Unit / buffer ptr / byte count / block number.

  The old entry said the Apple II SCSI card "rejected the call", and quoted the
  spec's "in some SmartPort implementations may not be larger than **767
  bytes**" to conclude multi-block was "nearly worthless". **Both halves were
  artifacts of how the call was issued.** Measured on the same card:

  | transfer | result |
  |---|---|
  | extended Read $48, 1024 B | **2 blocks in one call**, across a bank boundary |
  | standard Read $08, 1536 B | **3 blocks** into bank 0 |
  | extended Read $48, 65,504 B | carry clear, real data at the last byte |

  **127 blocks/call is the PARAMETER FIELD's limit, not the card's.** The byte
  count is a 2-byte field, so 65,535 B is the arithmetic ceiling -- 127 whole
  blocks plus a 511 B remainder -- and the card runs clean right up to it.
  Nothing refuses a larger transfer; the field cannot express one. The 767-byte
  caveat did not apply.

  **THE TWO DEFECTS THAT PRODUCED THE FALSE REJECTION**, because both are the
  same class and either would sink a retry:

  1. **An extended call needs a FIVE-byte inline structure.** From Apple's own
     IIgs SmartPort firmware source (`GSFirmware/SmartPort/C5XXcode.aii:70-76`):
     standard is `jsr SPentry / dfb Cmd / dw ParmList / bcs err`; extended is
     `jsr SPentry / dfb Cmd+$40 / dw ParmList / **dw ^ParmList** / bcs err`.
     The firmware returns after the FIVE-byte form. `BlkTramp` emitted only the
     three-byte one, so an extended call read its pointer's bank word out of the
     `BCS` opcode, parsed a parameter list from bank $B0, and never returned.
     That is why $40 and $41 failed *identically*, why the buffer's bank looked
     irrelevant, and why two unrelated firmwares -- the Apple II SCSI Card and
     the IIgs internal SmartPort -- hung the same way. The fix is two bytes at
     `BlkTramp+14` that default to `NOP NOP` (which a standard call executes
     harmlessly on its way to the `BCS`, since NOP preserves carry).
  2. **The parameter list overran its buffer.** The $08 test wrote a 9-entry
     standard Read list into `BlkTrampParams`, which is SEVEN bytes -- so it
     spilled into `CoutTramp`'s code and handed the firmware a malformed list.

  **SUPPORT IS PER-CARD, AND $CnFB BIT 7 IS THE GATE.** Measured from the ROM
  images MAME actually loads: A2retroNET, CFFA2, Focus, AppleIISD, Booti all
  report `$CnFB = $00`; Apple II SCSI, Apple II High-Speed SCSI and the IIgs
  internal SmartPort report `$82`. **Never probe a bus whose bit 7 is clear** --
  A2retroNET's pico firmware answers $08/$09 with `SP_BADCMD`, and its 6502 side
  dispatches `LDX cmd / LDA SPCMD,X` over a ten-entry table with no bit-6 mask
  and no bounds check, so $41 there is a jump to a garbage $C8xx address: a
  crash, not a rejection. Multi-block $48 succeeded only on `a2scsi`; `cffa2`
  and `retronet` never returned. (Later work refined this further: bit 7 means
  extended *addressing*, not the extended *command set* -- the MicroDrive serves
  $41 but fails every $48, so multi-block must be latched by trial per device.)

  **DEBUGGING TRAP, recorded because it cost the session twice.** The "hang
  after a successful call" was an **MX index-width bug, not the firmware**:
  `_blkSmartJump` returns via `SEP #$30` (8-bit index) while the probe declared
  `MX %10` (16-bit), so Merlin emitted `LDY #imm` as three bytes and the CPU ran
  it as two, executing the stray `$00` as `BRK`. `_SP_ReadBlock` dodges it by
  doing its own `REP #$30` first; the probe did not. Progress markers pointed
  straight at it -- execution reached the carry capture and died at the very next
  instruction -- and it was misread as "a run of plain stores cannot hang, so the
  code was never entered", when the first of those stores WAS the fault.

  **What landed:** the extended-SmartPort trampoline and boot-time read-path
  detection (`ae2b2fe4d`), which is why the console now prints either
  `blk: extended SmartPort - multi-block read path` or
  `blk: standard SmartPort - single-block read path` at boot. What remains is
  using it -- issuing multi-block reads from `fs.s`'s bulk paths.

  *(One finding from that probe is now SUPERSEDED and must not be re-used: it
  measured `$1900-$1FFF` as genuinely free -- 0 of 1792 poison bytes written
  across two workloads -- and noted that taking it would pin NPROC at 8. The
  bank-0 layout is derived from `kernel.nproc` since apple/fgx#45, NPROC is 11,
  and that region is now `BLK_STAGE` + the arena base.)*

  **Before optimizing either of these, MEASURE.** "Block I/O is slow" could be
  SmartPort call overhead, the `MVN`, `blkcache` miss rate, or per-block work in
  `fs.s` -- and those want different fixes.

- **BSD FS stack — ★LANDED (train 3, 2026-07-17; release pending).** The
  in-core inode table (live `i_size` visible via stat/ls the instant it
  grows — probe-proven mid-write; promotion re-key closed), the transparent
  block cache under `Blk_Read`/`Blk_Write` (write-through, coherent for all
  ~300 buffer consumers with zero call-site changes), `fsync(2)`/`sync(2)`/
  `sync(1)` (disk-extraction-proven durability), the switch-away EIO latch
  (`FCB_ErrLatch`), the readdir dirbuf re-read fix, and the cooperative
  kbd-yield acceptance. Plan of record + decision log:
  `history/plans/2026-07-17-bsd-fs-stack-train3-plan.md`. **The
  `_fsFileState` singleton retirement (F3) was resequenced to the preemption
  campaign** (Fable-audited: no surviving corruption class; the ~600-site
  module pointer flip's slice order + risk analysis are recorded in the
  train-3 plan doc).
- **Tree-file WRITE** (>128 KB files) — **LANDED 2026-06-17** (seed→sap→tree
  growth, master + sub-index alloc/flush, up to the 16 MB ProDOS tree ceiling;
  `cp` of 158/340/379 KB modules cmp-clean). Sparse write via seek-past-EOF also
  landed (2026-06-22 — holes read back zero at sapling+tree levels); only exotic
  sparse edge cases remain.
- **FOP_Bmap generalization** — **effectively LANDED.** The bulk-read loop
  dispatches `FOP_Bmap` via `_Fst_Dispatch` and falls back to per-byte on `ENOSYS`
  for FSTs without a bulk mapper (`src/drivers/fs/fs.s`), with ProDOS `_fop_bmap`
  as the fast path — i.e. the FST-agnostic seam is in place. Remaining is only
  actually implementing a novelty FST (FAT/HFS) to exercise the fallback.
- **FS buffer migration** (Phase 3c §3.7) — **SUPERSEDED by the F3 plan**
  (train-3 decision log): the preemption campaign's F3 train DELETES
  `_fsDataBuf`/`_fsIndexBuf`/`_fsMasterBuf` outright at the pool-pointer
  flip instead of migrating them to `prodos.mod`'s bank (moved-then-deleted
  churn); `_fsDirBuf` is explicitly retained in F3's scope. The loader-cap
  headroom arrives via the deletion.
- **Symbolic links** (assessment 2026-06-24; feasible, deferred). ProDOS (the
  FST) has no native symlink type, and **GNO/ME never implemented them** ("Too
  bad we don't have symlinks for GNO" — its headers stub the API, `S_IFLNK` is
  defined, but the kernel has no support; ProDOS even fakes `st_nlink`). So FGX
  would retrofit symlinks the standard way, matching **2.11BSD** semantics
  (`S_IFLNK`, target stored as the file's data, `MAXSYMLINKS=8`→`ELOOP`, the
  FOLLOW flag applies only to the **last** path component — intermediate links
  always follow; `lstat`/`readlink`/`unlink` operate on the link, not the target).
  - **Encoding:** a symlink = a regular **seedling** file whose *content* is the
    target string (<512 B, one block — `FOP_Create`+`FOP_Write` already do this),
    marked by a reserved value in the dir-entry **`file_type` byte** (offset `$10`,
    today hardcoded `$00`). Use `file_type`, **not** a storage nibble (`$5` storage
    is already ProDOS "extended file").
  - **Free seams (all confirmed):** syscall slots `92/93/94` for
    `symlink`/`readlink`/`lstat` (`SYS_NUM_MAX=91`); `O_NOFOLLOW=$1000` (open-flag
    bit free); `S_IFLNK=$A000` fits the **defined-but-unused 32-byte `STX_` stat
    struct** (`include/fs.s`); the `file_type` byte is unused today.
  - **The two hard parts.** (1) **Path-resolver auto-follow** — teach
    `_prodos_walkPath` (`src/modules/prodos/prodos.s`, ~the storage-nibble check)
    to detect a symlink component, read its target, splice + re-resolve with the
    depth/last-component rules. This is the cost and the **risk**: it's the most
    load-bearing asm in the tree (a bug breaks *all* file access); the resolver is
    pure root→leaf with **no "current dir" tracking** (relative targets like
    `../x` have nothing to anchor to), uses **single global buffers** (following =
    reading another file mid-walk → save/restore or a dedicated buffer; the
    recurring FS-reentrancy class), and the canonical-path buffer is only 64 B
    (target+remainder can overflow). (2) **stat-struct migration** — `SYS_STAT`
    today writes the legacy **16-byte** struct whose mode is one byte (dir/file/
    other only, **no room for symlink**); reporting `S_IFLNK` means moving stat to
    the 32-byte `STX_` struct, which ripples into libc + every `stat` consumer
    (`ls`, …). Hook for type-mapping: `_Fs_DirEntryToStat` (`src/drivers/fs/fs.s`).
  - **Phasing.** *Phase 1* (cheap, low-risk, **no resolver change**): encoding +
    `symlink`/`readlink`/`lstat` + `ln -s`/`readlink`/`ls -l` `name -> target` —
    links exist, are readable, are visible, but aren't auto-followed. *Phase 2*
    (expensive, high-risk): the resolver auto-follow that makes them transparent —
    where most of the utility lives. `readdir` `d_type` (currently name-only) is a
    separate slice-3 enhancement.
  - **Recommendation: not urgent.** The motivating case (`/bin/sh = jsh`) is
    already solved by a file copy, and a copy is fine for a *binary* alias.
    Symlinks pay back for not duplicating large files, `/man`↔`/usr/man` compat
    shims, and BSD-port fidelity. Land it as a deliberate FS feature when a port
    forces the issue — Phase 1 first (under test), then Phase 2 heavily gated (it
    also forces the FS-reentrancy story). Medium-large effort, dominated by the
    resolver work + the stat migration; small in LOC, high in care.

### Toolchain / self-host
- **Library function-level GC (apple/fgx#457): implemented on
  feat/457-libc-gc.**  A tool links only the library functions and data items
  it can reach: `fcc --sections` marks each unit and
  `toolchain/src/ld/fgx_gc.py` keeps what the tool's own text reaches, for
  libc, libfgx, the optional libraries and the self-packing shells.  3.1 MB
  less library code across 173 tools, none larger.  su's libc bank, which
  apple/fgx#456 found 1,559 bytes from full, has 23,617 free; syslogd's
  28,706.  See `docs/fgx2-linker.md` "Library selection and GC" and
  `docs/history/plans/2026-09-25-libc-gc-{design,plan}.md`.  Shared
  libraries remain a later design.
- **libc overlay (2.11BSD `ld -Z` for the libc pile): implemented on
  feat/libc-overlay.**  A tool whose libc selection outgrows the 64 KB bank
  names libc members in its manifest's `libc_overlay`; fgx_gc moves them, and
  what only they reach, to a private CODE segment, refuses a list seg2 would
  call into (naming the member to add), and writes one `FGX2_FARJUMP` thunk per
  seg2 routine the overlay calls.  cron and crontab are the first:
  `["ctime", "syslog"]`, seg2 56 KB and 50 KB.  See `docs/fgx2-linker.md`
  "The libc overlay" and `docs/history/plans/2026-09-27-libc-overlay-{design,plan}.md`.
- **libc overlay banks are private: one unshared bank per process (follow-up
  for a memory-efficiency pass).**  A tool whose libc does not fit seg2 names
  members in `libc_overlay`, and the linker moves them to a private CODE segment
  (the 2.11BSD `ld -Z` mechanism applied to the pile;
  `docs/history/plans/2026-09-27-libc-overlay-design.md`).  Private was chosen
  to keep the kernel and loader unchanged: seg2 stays shared and reloc-free
  because nothing in it calls the overlay.  The price is one bank per running
  process that uses an overlay, never shared -- cron, a daemon, holds one for
  its whole uptime, against a pool where banks are already the process ceiling.
  Correcting it means sharing the overlay the way seg2 is shared: content-keyed
  and refcounted by the loader, with its calls OUT to seg2 made reloc-free
  (a per-process cell or loader-guaranteed bank adjacency in place of the JML
  thunk's relocated bank byte).  Worth doing once a second overlaid tool runs
  alongside the first, or when a bank-pressure measurement names it.
- **The sleep-safety callgraph stops at a function pointer** -- apple/fgx#459
  took it into C (the `PEA target-1` pile call is an edge now, a generated C
  function is one routine rather than a dozen, and a patch marker no longer cuts
  one in half), which took the routines that can reach a sleep from 72 to 233 and
  left the gate clean.  What remains is indirect dispatch: fcc calls through a
  pointer by pushing a computed address, so there is no name to follow, and that
  is why `ttyopen` is known to sleep while `kc_ttopen` -- one
  `linesw[].l_open` away -- is not.  It keeps three of `KSVC_SEAMS`' fourteen
  verdicts un-derivable, and those three are the ones that sleep.  Treating every
  indirect call as able to sleep was measured and REJECTED as a standing setting:
  it found apple/fgx#460 on the way, but it then reports `FGX_Entry` -- the
  single-threaded boot path -- and makes the seam cross-check meaningless, since
  an over-approximated "can sleep" is not corroboration of a verdict that was
  reached by reading the C.  Closing this properly means resolving the tables
  (`linesw`, the `vnodeops`/`cacheops` vectors, the module import tables), not
  widening the closure.
- **CAMPAIGN (chartered 2026-08-18): fcc lvalue matrix sweep** -- close the
  lvalue / pointer-arithmetic defect class as a CLASS.  apple/fgx#153, #154 and
  #155 took 26 commits and found twelve emitter sites carrying the same
  mistake, each one made visible only by fixing the one before it.  fcc has ~20
  read-modify-write arms and 19 store helpers, one per shape, and nothing
  forces two arms that mean the same thing to agree -- #155's
  `f()->next += 1` reached the EXPRESSION emitter from STATEMENT position
  because a call in the base routes the whole statement through the expression
  layer.  Four phases: enumerate and classify every cell of
  (shape x operation x position x leaf type x storage class), close the silent
  miscompiles, close the band of valid K&R that fcc currently REJECTS
  (`s.parr[i]` in any form, `q = (*pp += 1)`, `q = p->ip++`, cast-as-lvalue),
  then collapse duplicated arms onto the uniform walker so the shape count goes
  DOWN.  Prerequisite in practice for the self-host push: a compiler that
  miscompiles `p += 1` on some shapes cannot be trusted to compile itself, and
  the rejection band is exactly the C a compiler source base contains.
  Charter, with the measured starting map and the method:
  [`history/plans/2026-08-18-fcc-lvalue-matrix-sweep.md`](plans/2026-08-18-fcc-lvalue-matrix-sweep.md).
  Blocked on nothing; !214 and !215 should land first so Phase 1 measures the
  current compiler.

- **BUG: fcc fixture links inline the whole libc pile, blowing the 64 KB seg0
  ceiling** -- issue [#25](https://gitlab.com/apple/fgx/-/issues/25), ★FIXED
  2026-08-05 on `feat/login-stack-vc`.  libc is now a 42-member `libc.fgxa`
  archive with member-level dead-strip, so every link takes only what it
  references: `run.sh` is **549 passed / 0 failed** (was 477/72), `/bin` fell
  6,170,465 -> 3,923,250 B (-36.4%), the typical tool selects 8 of 42 members,
  and a from-scratch `ninja all` got FASTER (60.5 s -> 29.3 s wall, 572 s ->
  114 s CPU).  `tools/check_libc_link_sites.py` gates against a regression.
  Scope + full measurements:
  [`history/plans/2026-08-05-libc-breakup-scope.md`](plans/2026-08-05-libc-breakup-scope.md).

- **BUG: fcc runtime fixture oracle scored STALE SCREENS** -- issue
  #7, ★FIXED on
  `feat/preempt-p4-interruptible`. It was un-runnable since the monorepo
  migration deleted `build.sh`, and worse, `run.py`'s green cache skips the boot
  and writes no dump on a hit -- while this harness ignores run.py's verdict and
  scrapes the SCREEN, so cached chunks were scored against a previous, often
  differently-split run's markers. Now `--fresh` forced, stale dumps deleted,
  and a chunk missing its end sentinel is a loud harness failure rather than N
  quiet regressions. **An earlier claim here that ~12 of 20 fixtures were red on
  main is RETRACTED** -- that was this artifact, and it reproduced on main
  because the cache behaves identically there. The suite is now change-scoped:
  546 binaries are 33 MB against a 32 MB ProDOS ceiling, so it cannot fit one
  volume regardless of layout.

- **A sourced script stopped after 17 commands** -- issue
  #9, ★FIXED
  2026-08-02, and it was a STACK OVERFLOW, not the table or file-offset theory
  the original report guessed at. bsh's `.` parses the whole file up front and
  walks the tree, and `xec.c`'s list case is
  `execute(t->lstlef,0); execute(t->lstrit,execflg);` with NO tail loop -- so
  depth is O(commands in the sourced file). `sh file` is immune because main()'s
  loop executes one command per iteration, depth 1. `stack_measure` sizes
  recursion with a FIXED `CYCLE_TURNS = 8` reserve, a constant standing in for a
  data-dependent depth. Measured ~122 B/level; bsh went 9 -> 30 pages (~60
  commands) and the kernel now LOGS `stack overflow: killed pid` on the guard's
  exit status, which it never did before -- the silence is what made this a
  two-session hunt. Gated by `srcdepth` (55 commands, must complete) and
  `srcdepth_loud` (200, must report). See the bank-0 stack campaign below: this
  is the depth face of the same structural problem as the arena.

- **BUG: truth test on a `long`/`float` may test only the low word** -- issue
  #8. SUSPECTED, not
  yet reproduced: raised reviewing the #6 fix as the same mistake one type over
  -- a multi-word value truth-tested through a single-word accumulator compare,
  so `65536L` may read as false while `v != 0` reads true. Not touched or
  worsened by the #6 fix, which selects the full-width test on `ISPTR` only.

- **fcc far-pointer truth test weighed the offset only** -- issue
  #6, ★FIXED on
  `feat/preempt-p4-interruptible`. `if (p)`/`!p`/ternary/`&&`/`||` compared the
  offset word alone, so a bank:0000 pointer read as NULL while `p == (T *)0`
  compared both halves and disagreed. Now routed through the same FPR carrier
  the `==` form uses; guarded by multibank construct `c43_ptrnull`, proven RED
  before green.

- **Multi-bank fcc far-pointer oracle (task #56)** — ★ BUILT (toolchain
  `tests/multibank/`, on `feat/elvis-port-prep`). Makes the DBR≠PB "wrong bank
  byte" class — previously single-bank-INVISIBLE and only found by ports crashing
  ("whack-a-mole") — test-visible in one vi-footprint FGX2 binary: 23 self-checking
  far-pointer constructs (fail-closed preflight + anti-coincidence scan + run-all
  driver), plus a **site-flip coverage instrument** (`flip/`) that flips each of
  the ~21 PHK/PHB decision sites and produces a measured site→construct matrix
  (`flip/MATRIX.md`). Run via `run_runtime.py --multibank`; `release.sh` gates on it
  when bank-emission codegen changes. Surfaced + fixed 4 fcc gaps (scalar-struct
  brace-init, `p-q` ÷sizeof for any stride, abstract fn-ptr proto extern, by-value
  jmp_buf fail-closed guard) — all RELEASED (shipped through toolchain v1.7.0).
  Follow-on: extend to the non-PHK/PHB bank *sources* (`_fcc_ptr+2`, heap;
  the soft-stack source was deleted at P3-3) + the libc/shim caller-buffer
  population. Ledger: memory
  `feedback_fcc_multibank_untested_whackamole.md`.
- **fcc-2.0 optimizing backend (Track 2)** — ★ COMPLETE-AT-FRONTIER (released
  through toolchain v0.18.0 / FGX v0.18.3). Evolved fcc from a one-pass
  stack-machine emitter into a small optimizing backend: frontend → Stack-IR →
  stack→TAC → linear-scan allocator over {A,X,Y} + DP-IMG imaginary registers
  (`$C0–$DF`) → load-op-fold isel → Merlin32; `IR_TEXT` escape hatch for un-lifted
  ops. **Delivered:** DP-IMG promotion (scalar / param / loop-weighted / region),
  pointer promotion B1a–c, INC/DEC-dp isel, const-multiply shift-add lowering, the
  dead-code / dead-store / dead-LDA size peephole streams, and the Phase-1
  load-op-fold isel pass. **Cycles met** (strLen −54%, memcmp −30%, t12_* −32%);
  the MX-leak / stale-flag miscompile class is retired by the explicit-width
  structured IR. ★ **Size at its structural ceiling.** A Phase-3 read-only
  measurement spike (`FCC_P3_STATS`, toolchain `626c4ce`) PROVED the unmet ≥15%
  gen-code SIZE-band DoD is architecturally unreachable: the removable structural
  spill/reload is ~2% of gen-code (ceiling), ~0% reachable now (floor) — confirmed
  against the earlier asm-level re-grounding (~3%). The whole-function global
  allocator was therefore **not built** (it would buy <2% size and an uncertain,
  small incremental cycle gain over the shipped within-BB allocator + promotion).
  Findings: `docs/history/2026-06-29-fcc2-p3-spillreload-measurement.md`. Knowledge
  oracle = `examples/65816-llvm-mos` (a real Apache-2.0 W65816 LLVM backend,
  measured 0.62× Calypsi; algorithms-only / clean-room — not adopted). Ledger:
  memory `project_fcc2_optimizing_backend.md`. Remaining options are targeted, not
  initiative-level: a cheap L3 leaf-fold extension (~0.4% size) or per-hot-path
  cycle spikes if a specific need arises.
- **Shared-libc bank — ★LANDED 2026-07-09 (T5-A/B, under the hold)** as a
  refcounted load-once LIBC segment (kind 3 + checksum share key; 3-seg
  C-tool template; see `docs/history/plans/2026-07-09-fgx-t5a-shared-libc.md`).
  The original framing below is kept for history: **(RAM footprint).** Today a
  multi-code-bank `--far-calls` program (the elvis link model:
  `gen_elvis_link.py`, since retired / `build_userbin_fgx2_c` + `fgx_ld.py`) PUTs a **full copy
  of `libc.s` + `fcc_runtime.s` + `fcc_libc_shims.s` + `args.s` into EVERY code
  bank** (Merlin's PUT model has no dead-stripping). Measured on elvis:
  ~11.2 KB/bank × 5 code banks = **~56 KB of duplicated libc**, ~45 KB of it
  reclaimable — a non-trivial slice of a RAM-expanded IIgs. Fix: one **shared
  libc/runtime bank** every code bank reaches by FARCALL, instead of a per-bank
  copy. Touches `fgx_ld.py` (emit the shared seg once + resolve all libc/runtime
  calls to it as cross-bank FARCALLs), the packer (stop padding each bank with
  libc), the userland-ABI/crt0 (libc then runs in a foreign code bank; the
  DBR/data-bank convention already holds, but libc's own near helpers must stay
  self-consistent), and the kernel loader (load the shared bank once, wire its
  FARCALL bank relocs). Benefits every future big C program, not just elvis, and
  is a bigger structural win than per-bank libc dead-stripping (which the PUT
  model can't do anyway). Motivation: the elvis 356 KB size review (this file's
  size decomposition; ~240 KB elvis gen-code + ~56 KB dup libc + 53 KB data).
- **libc/libfgx split — ★LANDED (P1, through toolchain v1.15.0); real
  multi-archive linking (P2) is the surviving work.** The **library-level split
  shipped**: `libc` is pure-BSD names, the ~19 IIgs/FGX-specific functions moved
  to **`libfgx`** (`toolchain/lib/libfgx.s` + `libfgx_c/libfgx.c`, prototyped in
  `toolchain/include/fgx.h`), and `build.sh` links both piles into FGX-native
  tools (2.11BSD ports link libc-only). This achieved the collision/namespace
  goal via the **pile model**, and **per-tool LIBRARY-level selection already
  ships**: `build_userbin_fgx2_c … extra_libs="termlib,curses"` links whole-library
  piles per tool (each its own seg; libc+libfgx default) — the ordinary `-lc
  -lfgx -ltermlib -lcurses` capability, live under worm/robots/curtest. `fgx_ld`
  does archive-*emulation* (weak/strong `resolve_precedence` over one flat pile,
  A1/A2 through v1.5.0/v1.6.0), NOT `-l`/archive extraction. **Intra-library
  MEMBER-level dead-strip for libc ★LANDED 2026-08-05** (the libc breakup, #25):
  `libc.fgxa` is 42 members with a symbol index and on-demand extraction, so a
  `printf`-only tool does drop `qsort`/sockets. **The 2026-07-19 "payoff is
  conditional, not clearly positive" assessment is SUPERSEDED** -- it weighed
  disk size against the shared-libc bank's cross-tool sharing and never priced
  the 64 KB per-link ceiling, which is what actually bound (72 fixtures dead) or
  the assembler time, which is what actually dominated the build (-80% CPU).
  Measured: `/bin` -36.4%, full build 60.5 s -> 29.3 s. Surviving P2 work is
  giving `resolv.fgxa`/`termlib.fgxa` the same member granularity (same fix,
  cheap now) and deciding whether the shared-libc bank still earns its keep once
  per-tool footprints diverge. Plan of
  record: [`history/plans/2026-07-13-multi-archive-linker-scoping.md`](plans/2026-07-13-multi-archive-linker-scoping.md)
  (§4 granularity fork, §6 open questions). Ledger:
  `project_fgx_libc_libfgx_split_multiarchive`.
- **fcc front-end: multi-pass (tokenize → AST) — ★LANDED (toolchain v1.0.0).**
  fcc-2.0 gave fcc an optimizing *backend*; the front-end was still single-pass
  (the parser re-lexed **source** for lookahead/replay), and every "save a source
  position, re-lex it later" site was a landmine that cost real bugs (the
  macro-frame token-lifetime crash, the G39 for-step replay, the `#include`-frame
  variant that read an out-of-bounds `0x02`). That whole class is **retired**:
  `lex_tokenize_all()` now materializes a whole-TU token vector (`g_toks[]`, each
  token carrying stable frame provenance) and the parser walks it into an AST
  (expression + statement + per-function trees), so a rewind is a cursor restore
  that can no longer corrupt a frame. Ledger:
  `feedback_fcc_single_pass_source_replay_bug_class`.
  - **↳ NOW ENABLES the deeper optimizing backend (Track 2, phase 2).** The
    fcc-2.0 backend was COMPLETE-AT-FRONTIER but proved the ≥15% gen-code SIZE
    band architecturally unreachable *at the old architecture* — a
    single-pass front-end + within-basic-block allocator can't see whole-function
    or whole-program structure. The materialized AST + multi-pass IR substrate now
    exists (item above landed), so this is unblocked (still unbuilt): a
    whole-function / global register
    allocator, cross-BB spill/reload elimination, dead-code elimination across
    the whole TU, and inlining — i.e. the lever that would actually shrink big C
    binaries. **Motivation, sized:** elvis compiles to ~240 KB of 65816 gen-code
    (356 KB linked); ~2.5–3× of that is inherent 65816-vs-PDP-11 ISA density, but
    the removable structural overhead only opens up with a global view the
    current backend architecturally lacks. So: sequence a global/whole-function
    optimizing backend *on top of* the multi-pass front-end, not before it.
    Ledger: `project_fcc2_optimizing_backend` (the phase-1 within-BB ceiling
    measurement).
- **C module framework** — let new kernel modules be written in C (fcc), not
  hand-asm, on top of the FGXM module framework (header v2 + kernel
  `mod: <name> loaded` announce + `SYS_MODLOG`; landed 2026-06-24). A `module.c`
  + `link.s` stub would produce a v2 FGXM module, mirroring the userland
  `tool.c + link.s` pattern — but a module runs under the kernel-bank ABI
  (`mod_init` JSL-entered, no crt0/argv, DBR/data-bank handling, syscalls via the
  module jump table). **Prerequisite: a feasibility spike** — prove a minimal C
  module compiles, loads, announces a detail line via `SYS_MODLOG`, and returns
  C=1. Design: `docs/superpowers/specs/2026-06-24-module-framework-design.md`.
  Pairs with the network driver re-architecture (P1+), whose drivers would
  ideally be C modules.
- **fcc hardening** — 2026-07-06 truth pass (see the dated status block in
  `docs/fcc-known-issues.md`): the decay bugs, chained assignment, scalar
  `long` struct fields, array-dim expressions, and `long` `%`/`/` are ALL
  fixed/stale.  All of that batch is now closed: B-8 char packing landed with the
  quick-wins (2026-07-06, under the hold), `long` ARRAY struct fields
  landed 2026-07-06 (M33/longfield), and `float` ARRAY struct fields
  landed 2026-07-09 (M34/floatfield).  Float field brace-init + array-field
  `op=` since FIXED (toolchain v1.2.0, "Correctness queue 2").  Still fail-closed
  (honest dies): float-array decay, chained `->a[i]` on long/float array members.
- **fcc: softfloat + reliable printf width + full function pointers** — the trio
  that blocked a faithful `od(1)` port — **ALL THREE LANDED (2026-06-19); od/hd
  are now unblocked**:
  - **full function pointers** (**B-7**) — **MERGED+RELEASED** (fcc v0.6.0):
    fn-ptr local/global initializers, arrays of fn-ptrs (od's `conv_vec`, via
    `cb_t f = conv[i]; f(x)` and direct `conv[i](x)`), inline abstract casts.
  - **32-bit `printf`** (**G-PF1**) — **MERGED+RELEASED** (fcc v0.6.1):
    `%ld`/`%lu`/`%lx`/`%lX` via a high-word vararg stash + `pf_format_udec32`.
    (Width/precision/justify for `%s %d %u %x %X` were already in.)  Remaining
    `G-PF2` space-padded-negative-sign edge — low value.
  - **softfloat + `%f`/`%e`/`%g`** (**B-6**, "L") — **MERGED + RELEASED**
    (toolchain v0.8.0): `float`==`double`==32-bit
    IEEE-754 single.  3 phases (type/lexer/storage → arithmetic runtime
    `_fcc_itof/ftoi/fneg/fmul/fadd/fsub/fdiv/fcmp/ltof/ffloor` → libc
    `pf_emit_float` `%f`/`%e`) **plus 9 follow-ups** (float params/returns,
    4-byte long/float pointer-deref + array-element read/write — which also
    fixed pre-existing *long* 16-bit bugs — `(float)long`/`(long)float` casts,
    float struct/union fields, real `%e`, round-to-nearest-even, real `%g`,
    `%f`/`%e`/`%g` field width+justify+zero-pad, long/float array-elem compound
    assign).  19 fixtures `tests/M28/f_*`, golden 254/0, **19/19 MAME**.
    Arithmetic rounds to nearest-even (`ftoi`/`ftol`/`ffloor` truncate, per
    C-cast semantics); `%g` is real shortest-form (dtoa-lite + strip); `%f`
    integer part verified across the full `<2^32` range (`>=2^32` = bignum,
    deferred).  Remaining quality items in the registry.  Integration **DONE**:
    branch merged, fcc pin bumped, FGX-side dual-copy libc + hand-asm tools synced.
  → `od`/`hd` **ported to C** (the motivation); `ed`/`tr`/`sed`/`man` followed.  See
  `docs/fcc-known-issues.md` (B-6 block).
- **Self-host `fcc`** (M12) — see north star above.
- **Decouple fcc tests/goldens from FGX** — **DONE 2026-07-06.** `build.sh`
  no longer stages the ~36 toolchain fcc acceptance fixtures (RETURN42,
  CONDMUL, AUD*, M*, PP*, …) into `/testbin`; the toolchain's own golden
  suite + `run_runtime.py` cover them. The two FGX-side mame tests that
  still exercise a golden on FGX proper (`for_long_init`, `lc_malloc`)
  stage it at TEST time via `stage_files` (cadius `#060000` BIN suffix).

### Audio
- **Kernel sound driver** — `/dev/dsp`-style `SYS_SOUND_OPEN/CLOSE/DOC_POKE/...`
  with per-fd DOC ownership + auto-silence on exit; first tool `beep`.
- **`libsnd` + `play` + tracker tools** — wrap the DOC poke surface
  (`tone`/`note_off`/`play_sample`); background music task (needs scheduler).

### Graphics
- **BUG: the whole screen went inverse video after the first scroll** -- issue
  #20, ★FIXED
  2026-08-04.  `MVN` leaves DBR = the destination bank, so the `LDA
  _Con_RowBytesM2` between the back-to-back row-fill blocks in
  `_Con_ClearRingRow` / `_Vt_FillAttrRow_At` read its byte count from CHARBUF
  instead of the far bank -- $2020 (spaces) = 8224 rather than 78 -- and each
  79-byte fill smeared across FGBUF, BGBUF and the alt-screen snapshots.  Fixed
  with `_DBRK` after every MVN, not just the last.  Latent since forever; the
  far-bank move (de12a73fe) is what shifted the symbol onto live text.  Nothing
  in the suite saw it because every console assertion reads CHARBUF, the one
  buffer the smear missed -- `coninv` now asserts the colour buffers directly
  and is in `GATE_TESTS`.

- **Phase 2 — mixed text + pixel regions** — per-row gfx-mode bitmap, renderer
  skips text blit for gfx rows, `LockGraphicsRegion` + a minimal `SYS_DRAW_PIXEL`
  / block-blit surface. Higher-level primitives (line/circle/fill) → userland
  `libgfx` later. Self-contained; can slot in opportunistically.

### Userland / polish
- **`su(1)` -- TO PORT, and the pty lines lose their `secure` bit when it
  lands (the maintainer, 2026-08-29).** Both `ttyp0` and `ttyp1` are marked `secure` in
  `disk_src/etc/ttys` TODAY so that two concurrent telnet sessions can both be
  root; before that only `ttyp0` was, and the second session was refused --
  which is how #252
  was found. That is a stopgap and is written down as one: marking a remote
  line `secure` is what `su` exists to make unnecessary, and conventional BSD
  practice is that no pty line is secure at all. **When `su` is ported, take
  `secure` off both pty lines**, so a remote session logs in as a user and
  elevates rather than arriving as root. Two things depend on the bit and must
  move with it: `logintest` LT11 drives login's `TTY_SECURE` refusal and stages
  its own `/etc/ttys` for a line that is not secure (`ttys.logintest`), and
  `wirecon` asserts that both concurrent sessions reach a shell.  THE SOURCE IS
  `examples/2.11BSD/usr/bin/su.c`, which is in the gitignored full
  distribution and NOT under `vendor/` yet, so vendor it in the same commit,
  per the port-source rule.
- **`tip`/`cu` — RE-PORT NEEDED (the maintainer, 2026-08-17).** Landed 2026-07-12 as one
  C binary (cu is tip's other staged name; ~. / ~~ / ~? / ~> send-file / ~<
  capture escapes; hand-asm tip.s + cu.s retired), but it reads its local
  keystrokes with `pollkey()`, and apple/fgx#151 withdrew that: SYS_GETKEY and
  SYS_POLLKEY take no fd, so a caller on a pty read the physical console. The
  kernel now answers ENOTTY (getkey) or "no key" (pollkey) to a task whose
  controlling terminal is a pty, which leaves tip working on the console and
  inert over telnet rather than stealing the console's keys. tip is the ONE
  caller not converted with the rest of the class, because its shape needs
  more than a mechanical swap: it multiplexes two sources (the terminal and
  the line), so it wants `select()` on both rather than a poll loop — which is
  what the other ports had, and is why it is a re-port and not a patch.
- **BSD ports — `grep`/`od`/`hd`/`ed`/`tr`/`sed`/`man` all LANDED** (joining
  `more`/`rm`/`cp`/`wc`/`cal`/`uniq`/`cat`/`head`/`cmp`/`clear`/`ul`/…), released
  through FGX v0.11.1. Hand-asm tool re-ports COMPLETE: `ntpinfo` + `ntpplay`
  (C framework + companion asm DOC-IRQ engine — the last FGX1 hand-asm tool)
  landed, `doctone`/`docirq` DELETED 2026-07-12 per the maintainer. Remaining polish:
  consistent `-?` usage across the set.
- **Regex engine** — **LANDED** (BSD `re_comp`/`re_exec`): the shared engine
  behind `grep` and `more`'s `/pattern` search (`sed` ships its own regexp;
  `ed` too). Surfaced 2026-06-17 by the `more(1)` port. Now also feeds the vi
  search command (elvis shipped) and `expr(1)` (`src/userland/expr/`, landed).
- **vi port (elvis)** — ★**WORKS + SHIPPED (v1.3.0 → v1.4.0).** The old "ON HOLD /
  slow-render / no-draw" framing is obsolete. Root cause of the exit-134 hang was a
  `getkey` name collision (libc weak `getkey(void)` vs elvis strong `getkey(int)` →
  ttyread recursion → stack overflow), fixed by renaming libc `getkey`→`waitkey`
  (v1.3.0). elvis is now promoted into the normal userland build and disk image as
  `/FGX/bin/vi` (`src/userland/elvis/`, `disk_src/bin/vi`), with VT100 keyboard +
  DELETE/arrow-in-ex handling (v1.4.0). Interactive editing is headless-testable via
  the kernel kbd-ring injection harness.
- **terminfo / termcap layer** — **PARTIALLY LANDED.** The libc surface exists:
  `src/userland/lib/termcap.c` (2.11BSD libtermlib port — `tgoto`/`tputs` +
  `tgetent`/`tgetstr`/`tgetnum`/`tgetflag`), and `tput(1)` (`src/userland/tput/`)
  consumes it. What's still baked is the *database*: a single hard-coded "fgx"/vt100
  entry in `fcc_libc_shims.s`, not an external termcap DB file. Remaining work =
  the standalone capability database so BSD/curses ports stop relying on the one
  baked entry. (`clear(1)` still emits raw `ESC[H ESC[2J` in lieu of
  `tputs(clear_screen)` — the seam to fill once the DB exists.)
- **curses (4.3BSD libcurses)** — ★**PORTED 2026-07-13 (landed to main via MR !1,
  toolchain v1.8.0).** The 2.11BSD `usr.lib/libcurses` (Ken Arnold curses, 39 TUs)
  lives at `src/userland/lib/curses/` and links into a consuming tool via
  `build_userbin_fgx2_c <tool> "-DFGX_ELVIS_CURSES" FGX3
  src/userland/lib/curses/tu.list` (the multi-TU elvis link model, now a
  first-class build path).  Smoke test: `curtest` (`/testbin`, MAME fixture
  `curtest.json`) — initscr/box/standout/mvprintw/refresh/endwin against the
  baked `fgx` termcap entry.  Notes: printw runs over the new libc
  `vsprintf`; **scanw is a read-and-ERR stub** (no libc scanf engine — a
  toolchain-first follow-up: add `vsscanf`/`_doscan`, mirroring how `printw` got
  `vsprintf`); no keypad/nodelay/colors (this curses never had them — timed input
  stays the `pollkey`+`ticks`+`yield` idiom).  Unblocks the wave-4 BSD games
  (worm/hangman/robots/canfield/cribbage/mille/boggle/battlestar; see the
  2026-07-11 bsdgames assessment).
- **worm(6) — wave-4 bsdgames pilot** — ★**PORTED 2026-07-15 (toolchain v1.9.0).**
  2.11BSD `games/worm.c` (Michael Toy, 5.2 6/25/85) at `src/userland/worm/`,
  `/bin/worm` on the HD image (excluded from the 800K floppy).  First consumer of
  the new libc `rand`/`srand` + `random`/`srandom` (one 32-bit LCG in the C pile,
  sequence pinned by `M37/rnd` host + on-target); upstream's SIGALRM 1-second
  auto-move became the `pollkey`+`ticks(60)`+`yield` idle loop — the template for
  every timed wave-4 game.  MAME fixture `worm.json` (drives the worm into the
  `*` border; asserts the crash text + clean rc=0 exit).
- **robots(6) — wave-4 #2** — ★**PORTED 2026-07-15.**  2.11BSD `games/robots`
  (11 TUs — the first multi-TU GAME link, `src/userland/robots/tu.list` chains
  the game TUs ahead of the curses set).  Exercises delwin/newwin-stdscr
  (25x80 console vs the game's 24x80), setjmp/longjmp (builtin), qsort, the
  staged `/lib/robots.roll` score file (ProDOS name, no `_`), and the
  Real_time `-r` mode over the worm poll-loop template.  MAME fixture
  `robots.json` (field + help furniture, quit query, rc=0).  fcc gaps
  catalogued (source-delta'd at the site, each a toolchain-first follow-up):
  2-D-subscript `++`/`--`, `sizeof` on a subscript, `->`-member compound-assign
  as expression operand (curses' `flushok` macro), static-LOCAL `char *[]`
  initializers + parenthesized static-local literal inits, `getpwuid` is a
  header-only stub (no libc impl), no `bzero`.  Remaining wave 4:
  hangman, canfield, cribbage, mille, boggle, battlestar (atc HARD —
  needs the yacc/lex pregen + async loop rework).
- **Process environment (`environ` / `getenv`/`setenv` + shell `export`)** —
  ★**LANDED (T7, ~v1.2.0).** The old "getenv() always returns NULL" note is false.
  The full arc shipped: the spawn/loader ABI passes a parent's `KEY=VALUE` block to
  the child parallel to argv; `crt0_c.s` walks it into `args_env`; libc has real
  `getenv`/`environ`/`setenv`; the shell has `export`/`env`/`$VAR` expansion +
  inheritance on `spawnve` (this said `jsh`, which was REMOVED 2026-07-29 — bsh
  and tcsh carry it now); `/etc/profile` is sourced and ships `export TERM=vt100`
  (retiring the old hard-coded `c_getenv` stub). This is what unblocked correct
  `$TERM` selection for vi/elvis/more.
- Console **CR/LF standardization** — **LANDED** (FGX v0.19.0 / toolchain v0.19.0,
  2026-07-01): FGX is now LF-native end to end. True-VT console (CR = carriage
  return, LF = line feed as distinct ops) + a kernel tty ONLCR/ICRNL discipline
  replacing the old CR-centric model; ~27 hand-asm tools + libc emit LF; the whole
  `disk_src` tree was lowercased; content + docs converted to LF. Text files now
  round-trip cleanly with a Mac. This was one of the three "console correctness"
  **vi precursors**; the console **scroll storm** is now fixed too (Phase 0 below,
  v0.20.0), leaving just the baked `fgx` **termcap** entry (the terminfo/termcap
  item above).
- **Scanline-native framebuffer console** — Phase 0 **LANDED** (FGX v0.20.0,
  2026-07-01); Phases 1–4 designed. Re-architects the SHR console from a char grid
  to a scanline-native framebuffer (mixed graphics/text, Tektronix-style) treating
  scroll/buffer/damage by scanline. Corrects the old "large-write hang" note: that
  was **disproven** (2026-05-31) — the real issue was a **scroll storm** (every LF
  at screen-bottom did a full ~100 ms 30 KB pixel `MVN`, so a screenful of output
  stalled for seconds). **Phase 0 (scroll coalescing)** shipped it: defer pixel work
  and flush once per output burst (at the post-command prompt) + across writes, so
  `cat GREP.1` went 4.466→0.316 s and `ls -l /bin` 2.55→0.43 s. Remaining: **P1**
  scanline FB core + a `$C02E` beam-counter hi-res timer (60 Hz is too coarse to
  profile a ~6 ms row render), **P2** split-screen bands, **P3** graphics layer,
  **P4** C-conversion of the control logic. Spec:
  `docs/history/plans/2026-06-30-scanline-framebuffer-console-design.md`.
- Smaller cosmetic/standardization items — `docs/cosmetic-todo.md`.

---

## Done (condensed — see CHANGELOG.md for detail)

- **Boot + console** — two-stage loader; SHR 640-mode console + VT102 layer;
  Toolbox 60 Hz heartbeat (tick + keyboard ring).
- **Kernel** — monolithic kernel + loadable **FGXM modules** (`Mod_Load`);
  Memory Manager (`Bank_Alloc`/`NewHandle`, per-task DP + stacks); per-task **fd
  tables**; synchronous **signals** (SIGINT/SIGALRM/SIGTSTP/SIGCONT); POSIX
  syscalls via `SYS_TRAMP`; kernel-memory modernization (build-time address
  resolution); **relocatable kernel** — runs at any MM-assigned bank, `$02` fully
  vacated; **cooperative scheduler + job control** (`_Sys_Yield`, ready/blocked
  queues, `jsh` `jobs`/`fg`/`bg`/`^Z` + `tcsetpgrp`); **VT100 console + keyboard**
  (CSI handler, arrows/Ctrl as ESC-sequences); **process environment** (envp ABI +
  `getenv`/`export`/`/etc/profile`, T7).
- **Filesystem** — the root is 2.11BSD UFS through a 4.3BSD-Reno VFS (vnodes,
  namei and the name cache, permissions, links and symlinks, device nodes),
  checked by `fsck` at boot; ProDOS volumes mount through `mount_prodos(8)`,
  read or write; the RAM disk; `df` / `SYS_GETFSSTAT`.
- **Toolchain** — `fcc` (C90: structs/unions/pointers/multi-level-ptrs/multi-dim/
  longs/argv/static-locals/do-while, **softfloat IEEE-754 `%f`/`%e`/`%g`**,
  **32-bit `printf`**, **function pointers**, **struct/union pointer arithmetic**),
  now with a **multi-pass front end** (whole-TU token vector → AST, retiring the
  source-replay bug class) and an **optimizing backend** (Stack-IR → linear-scan
  allocator → isel, complete-at-frontier); **libc-in-C** (T5-C) over a **shared
  libc bank** (T5-A/B); `fas` (self-hosting on-device assembler), `fgx_ld` (FGX2
  multi-bank linker, weak/strong archive-emulation resolution); submodule +
  SemVer-released (**v1.7.0**); golden suite + runtime oracle (incl. the multibank
  far-pointer oracle); libc + crt0.
- **Userland (C ports)** — the BSD tool tier, all FGX2/fcc-compiled, MAME-green:
  `grep` (BRE engine), `od`/`hd`, `ed`, `tr`, `sed`, `man(1)` (catman locator at
  `/usr/man/cat<N>`), `more`, `stty`, `stat`, `ps`, `kill`, `ls`, `expr`, `tput`,
  `strings`, `date`/`uname`/`uptime`/`touch`/`time`/`sleep`/`basename`/`dirname`/
  `hostname`/`dmesg`, `tip`/`cu` (serial terminal), `init` (C) — joining the earlier
  `cat`/`wc`/`head`/`cmp`/`uniq`/`fold`/`cal`/`clear`/`ul`/`rm`/`cp`/`df`/… set.
  **`vi` (elvis)** ships as a first-class tool (`/FGX/bin/vi`). The **hand-asm
  retirement** campaign converted the tool tier to C (last FGX1 hand-asm tools
  `ntpinfo`/`ntpplay` retired). Released through **FGX v1.4.0**.
- **Login stack** (2026-08-04) -- `init(8)` as 2.11BSD's respawn engine driven by
  `/etc/ttys`, plus `getty`, `login`, `passwd` and `halt`, over libc's `ttyent`
  database, `crypt(3)` (a tagged non-DES hash) and `getpass(3)`.  One line is
  `on` today (`console`, `/bin/sh` directly); the `ttyv*` virtual consoles are a
  later slice.  Design:
  [`history/plans/2026-08-04-login-stack-vc-design.md`](plans/2026-08-04-login-stack-vc-design.md).
- **Networking** — Uthernet II / W5100; offload-agnostic socket seam, now
  extracted into `net.mod` (socket layer + W5100 transport + RX ring out of the
  kernel); **UDP** sockets + `dhclient`; **ICMP** (ping + hardware auto-reply);
  **TCP** client *and* **server** (`connect`/`send`/`recv`/`close`, `listen`/
  `accept` + `echod`); `netdump` MACRAW capture; `ifconfig`/`route`; **slotscan** —
  auto-detect the Uthernet II in any slot.
- **Audio** — DOC (Ensoniq) bring-up; `ntpplay` IRQ-driven MOD player (placed +
  streamed samples).

---

## How to use this file

When a feature is proposed: if it slots into the active push or the backlog,
green-light it; if it leapfrogs a dependency, flag it ("easier once X lands").
When a feature surfaces a missing primitive, prefer landing it via the relevant
backlog item over a one-off. Update this file as pushes complete — move items
from backlog → active → Done, and let `CHANGELOG.md` carry the commit-level
detail.

### Binary size and load time

Every FGX2/FGX3 binary carries the whole libc pile, so `/bin/login` is 60 KB
and its `execve` costs ~630 ms -- measured, and the dominant remaining term in
the login path once apple/fgx#50 removed the file-scanning cost (3.3 s -> 0.8 s,
of which 0.63 s is the image load).  The same tax is paid by every tool the
shell runs.

Two directions worth measuring before choosing:

- **Share the pile rather than copy it -- MEASURED, AND UNDERWAY.**  The
  multi-archive carve (`libc.fgxa`) already selects only the members a tool
  calls; the ceiling was that each binary still links its own copy.  RUNTIME
  sharing landed at !294 and is done -- every tool's pile is resident.  What
  remained was the DISK: apple/fgx#376 measured 46.7% of the root as duplicated
  pile, 6,353,750 bytes in 63 distinct classes across 149 binaries, of a thing
  the loader already content-addresses.  Consolidating classes by padding makes
  it WORSE (+2.97 MB to cover 134 binaries), so the answer is BSD's -- the
  shared object in one file and the binary naming it.  That mechanism
  (`SEG_KIND_LIBCREF`, `/lib/libc.so.<key>`, the loader's open-on-miss) now
  carries every tool but the four the machine needs to boot and repair itself:
  3,469,136 bytes off the root, 3,345 blocks back to free, and no measurable
  exec cost.  Collapsing the 63 classes to ~35 members is free of disk cost from
  here, and is a follow-up rather than part of the campaign.
- **Reduce demand.** `perf(elvis)`'s CRUNCH flag reclaimed 21 KB of data bank
  for one `-D` (2026-08-08) by using a configuration the port already shipped.
  Other vendored ports are unlikely to be tuned for a 64 KB data space either;
  nobody has looked.

Raised by the maintainer 2026-08-08 while closing out the data-bank pressure that
blocked apple/fgx#61.  Filed here rather than as a work item because it is
direction, not a defect.
