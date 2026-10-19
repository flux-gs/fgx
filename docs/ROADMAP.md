# FGX Roadmap

> Forward-looking plan.  This file is the source of truth for "what's next" --
> versioned with the code, and not frozen (re-prioritize freely).  When
> evaluating a feature idea, relate it to the campaigns and backlog below.
>
> - **Current state** of each subsystem is in the reference docs indexed by
>   [README.md](README.md).
> - **Shipped work** is in [`CHANGELOG.md`](../CHANGELOG.md) (git-cliff).
> - **History** -- landed plans and specs, RESUME handoffs, point-in-time
>   audits -- lives under [`docs/history/`](history/).  Every campaign's full
>   narrative, as this file carried it until 2026-10-11, is kept verbatim in
>   [`history/roadmap-archive-2026-10-11.md`](history/roadmap-archive-2026-10-11.md);
>   each entry below names the archive section that holds its story.
> - **Defects** are [GitHub issues](https://github.com/flux-gs/fgx/issues);
>   this file carries at most a one-line pointer to one.  An `apple/fgx#N`
>   reference names an issue in the project's earlier, archived tracker.
>
> **Build/test infrastructure.** The toolchain is in-tree at `toolchain/`;
> **ninja** owns the build ([BUILDING.md](BUILDING.md)); the gate is
> `tools/gate.sh` -- the smoke test plus a budgeted set of MAME tests
> ([testing.md](testing.md)).

---

## Campaigns

Status words: **landed** (merged, nothing owed), **active** (work in hand),
**open** (chartered, work remains), **parked** (deliberately set down).

### Cooperative multitasking + job control -- landed

`yield()`, ready/blocked queues and the cooperative switch are in `sched.s`;
shell job control is tcsh's.  Its follow-ons moved into the
preemption campaign.  Archive: "Cooperative multitasking + job control".

### Preemption -- open (P4 tail)

Timer-quantum preemption, 2.11BSD-faithful (user code is preempted, the kernel
runs to completion), with fcc-emitted loop safepoints.  P0-P3 landed; P4 T1-T3
landed.  **Open:** P4 T4, retiring the `_kYieldReq` keyboard special-case into
the general sleep/wakeup mechanism (`_kYieldReq` is still live in `sched.s`,
`syscall.s` and `toolbox.s`), and T5, the blanket-wake cost, to be done only
with a measurement.  Design:
[`history/plans/2026-07-17-preemption-campaign-roadmap.md`](history/plans/2026-07-17-preemption-campaign-roadmap.md),
P4 plan
[`history/plans/2026-08-01-preemption-p4-blocking-io.md`](history/plans/2026-08-01-preemption-p4-blocking-io.md).
Archive: "Chartered campaigns", item 1.

### fcc self-host -- open (not started)

Build FGX software inside FGX; see the north star below.  The linker family
(`toolchain/src/ld/fgx_ld.py`, `fgx_static.py`, `fgx_dyn.py` and the rest) is
still host Python and must be ported to C (S1); fcc-built-fcc needs an
execution venue for its oracle (S2a); S0 measures the 7 MHz build-time
showstopper first.  Order S0 -> S1.5 -> S1 || S2-audit -> S2(+S2a) -> S4 -> S5.
Design:
[`history/plans/2026-07-17-fcc-selfhost-campaign-roadmap.md`](history/plans/2026-07-17-fcc-selfhost-campaign-roadmap.md).
Archive: "Chartered campaigns", item 2.

### UFS -- landed (two follow-ups open)

The root is 2.11BSD UFS (on-disk format) under a 4.3BSD-Reno VFS
(architecture); ProDOS is a mountable type (`mount -t prodos`).  Phase 1 and
Phase 2 are complete, an FGX volume mounts on a real 2.11BSD machine and vice
versa, and the boot image is a UFS volume built by
`tools/make_ufsboot.sh`.  Design:
[`history/plans/2026-08-09-ufs-migration-campaign.md`](history/plans/2026-08-09-ufs-migration-campaign.md).
Archive: "Chartered campaigns", item 3.

### TTY -- landed

BSD's `struct tty`, clists and line discipline in a third kernel bank, ptys via
`tty_pty.c`, `/dev/tty`, and the serial line through `ttyinput`; T1-T7 landed.
Open tty defect: apple/fgx#515.  Design:
[`history/plans/tty-kernel-bank.md`](history/plans/tty-kernel-bank.md),
placement survey
[`history/plans/2026-08-22-tty-bsd-shape-placement-survey.md`](history/plans/2026-08-22-tty-bsd-shape-placement-survey.md).
Archive: "Chartered campaigns", item 4.

### Bank-0 / kernel-scratch assessment -- landed

The language card's 16 KB of bank-0 RAM was mapped and put to use, and the
per-task kernel direct page it recommended (Option A) ships as the kernel slot
page (`include/kernel.s`, `KFGX_CUR_KDP`).  Conclusions:
[`history/audits/bank0-assessment-conclusions.md`](history/audits/bank0-assessment-conclusions.md)
(section 6).  Archive: "Chartered campaigns", item 5 (bank-0 / kernel-scratch).

### Bank-0 residency -- landed (limits recorded)

Bank 0 is a cache of task images: kernel-image slots, an oversubscribable user
arena with parked extents, the user direct page riding with the stack, NPROC
32, and a Second Sight card as `ttyv3`.  **Recorded limits, not owed work:**
the process table binds next at 32, and a small image's two banks (code and
data) are the structural cost past it.  The card's bitmap modes (320x200x8,
640x480) are a project of their own (see Graphics).  Design:
[`history/plans/2026-09-17-bank0-residency-architecture.md`](history/plans/2026-09-17-bank0-residency-architecture.md),
[`history/plans/2026-09-18-second-sight-console-plan.md`](history/plans/2026-09-18-second-sight-console-plan.md),
[`history/plans/2026-09-18-ansi-colour-card-design.md`](history/plans/2026-09-18-ansi-colour-card-design.md).
Archive: "Chartered campaigns", item 0.

### Memory (shared text and the coremap) -- landed

Code banks are loaded once and shared as 2.11BSD shares text; the user pool is
2.11BSD's resource map in 256-byte pages and new text is packed into shared
banks by size.  B4 and B5 were measured and not built (design section 6.6).
Design:
[`history/plans/2026-10-03-coremap-shared-text-design.md`](history/plans/2026-10-03-coremap-shared-text-design.md),
phase B
[`history/plans/2026-10-10-coremap-phase-b-code-packing-plan.md`](history/plans/2026-10-10-coremap-phase-b-code-packing-plan.md).
Archive: "Chartered campaigns", item 0 ("Memory campaign").

### Performance -- parked

Ad hoc; the seams are exhausted (the biggest non-idle profile item is 3.6%).
**Open if resumed:** 7.8 zero-init into bss (a linker change), 7.9 an
80-column console (interactive only); defects apple/fgx#381 (uiomove
overhead), #386 (`/dev/null` writes slower than a file).  Do not re-litigate 7.6, 7.7,
raising NBUF, PackBytes, or Toolbox-for-speed.  Design:
[`history/plans/2026-09-09-performance-dive-results.md`](history/plans/2026-09-09-performance-dive-results.md).
Archive: "Chartered campaigns", item 4 (Performance campaign).

### Shared libc -- landed

`libc.so` and its siblings are shared libraries bound before `main` by a
user-space binder (SunOS 4.1.3 model); the pile path is gone from the build
and the toolchain.  Sub-projects 1-5 merged.  Open defect: apple/fgx#519
(unguarded recursion cycles in elvis and tcsh).  Design:
[`history/plans/2026-09-28-shared-libc-design.md`](history/plans/2026-09-28-shared-libc-design.md)
and its SP2-SP5 specs and step plans beside it.  Archive: "Chartered
campaigns", item 6.

### Public repository -- landed

FGX is developed on GitHub, at <https://github.com/flux-gs/fgx>; this tree
is the repository's root, and the earlier history is archived.  Every licence
is stated in `docs/PROVENANCE.md`.  novi, two NinjaTracker modules and the
`small` and `vga` console fonts are not in the tree until their terms are
known.  Archive: "Chartered campaigns", item 7.

### Hand-asm retirement adjunct -- landed for userland; H5 partial

H0-H4 converted the userland tool tier to C.  H5 (kernel and modules in C) is
realised for the VFS, UFS and tty discipline (kernel C in `src/kernel/`); the
core kernel, drivers and module wrappers remain assembly, with IRQ paths and
boot staying asm until fcc grows interrupt codegen.  Design:
[`history/plans/2026-07-11-fgx-hand-asm-retirement-roadmap.md`](history/plans/2026-07-11-fgx-hand-asm-retirement-roadmap.md).
Archive: the "Hand-asm retirement adjunct" note at the top.

### Architecture adjunct -- landed except one stage

The multibank/far-pointer redesign (Phase 2+3, T5, T7, the multi-pass front
end) is released.  **Open:** Track-2 phase 2, the whole-function allocator on
the lifted IR (see Toolchain).  The archive also lists T8 co-location and the
multibank shim/bank-source sweep as remaining; neither is re-verified here.
Design:
[`history/plans/architecture-redesign.md`](history/plans/architecture-redesign.md).
Archive: the "Architecture adjunct" note at the top.

---

## Active push / north star: self-hosting `fcc`

"Build FGX software inside FGX." `fas` already self-hosts on-device; `fcc` is
the missing half -- today it runs on the Mac host. All prereqs are cleared
(libc, multi-bank loader, FGX2 ABI, per-task fd). The M12 self-host bootstrap
was parked once (bending `fcc.c` to fcc-accepted form + the on-device
`fcc -> fas -> fgx_ld` pipeline + memory). Doesn't need multitasking, so it
sequences naturally after the concurrency work.

Already done: the shells are C ports (`/bin/sh` is the 2.11BSD Bourne shell,
the interactive shell is tcsh), the fcc multi-pass front end (whole-TU token
vector -> AST) retired the source-replay bug class a self-host would have
tripped on, and separate compilation of multi-file programs works. What remains
to de-risk M12: the memory shape and `#`/`##` items catalogued below, then
bending fcc's own source to fcc-accepted form. See `docs/fcc-known-issues.md`.

**Self-host catalogue (tagged for this push, NOT gating current work --
compiler correctness first, self-host after):**
- **Memory shape (T2-4 report; table in
  `docs/history/plans/2026-07-09-fgx-t2-frontend-completion.md`):** worst
  elvis-TU front-end footprint ~0.9MB on the host (token vector 486KB +
  macro-body tokens 262KB + AST peak 117KB + intern 10KB at
  sizeof(Tok)=56); ~350KB at a packed 16-byte Tok; fcc's own
  parse_stmt.c is ~2.7x the largest elvis TU by lines -> ~1MB packed.
  Needs the multi-bank arena; per-function AST windowing already caps the
  parse side.  Budget number: decided when this push starts.
- **Capacity limits** (`fcc-known-issues.md`, "Capacity limits"): each a
  fail-loud die; whether fcc's own source fits them is measured when this
  push starts.
- **`#`/`##` token paste** -- never supported, explicitly deferred until
  self-host/a port demands them.
- **fcc-source C subset audit** -- chained assignment now compiles; the
  remaining "can fcc parse fcc" delta gets measured when the push starts
  (the M12 bootstrap notes are the seed).

---

## Backlog by area

Only open items.  An `apple/fgx#N` reference names an issue in the earlier,
archived tracker; new work is tracked in GitHub Issues.

### Networking (build on the W5100 socket stack)

- **TCP urgent data (out-of-band), U2-U5.**  U0 and U1 landed (`MSG_OOB` is
  refused with EOPNOTSUPP; `select(2)` has an exceptional set).  Remaining:
  apple/fgx#424 (socket urgent state, `so_oobmark`/`SS_RCVATMARK`/`SIOCATMARK`),
  #425 (socket owner process group for SIGURG), #426 (loopback
  `PRU_SENDOOB`/`PRU_RCVOOB`), with telnetd's `interrupt()`/`sendbrk()`
  arriving in the apple/fgx#540 re-port; also #445 (a character device never reports an exceptional condition).  The W5100
  cannot pass the flag, so loopback gets full semantics and W5100 TCP answers
  EOPNOTSUPP.  Design:
  `docs/history/plans/2026-09-13-tcp-urgent-mechanism-design.md`.
- **Who re-arms a TCP listener.**  The W5100's listening socket becomes the
  connection, and `inetd` rebuilds the listener today (measured working,
  `wireacc`).  The BSD-shaped alternative is the kernel re-issuing OPEN +
  LISTEN so `listen(2)` means what it says; design direction, belongs with the
  P1 `ifnet` seam.
- **Port `ifconfig(8)` and `route(8)` from 2.11BSD.**  The `SIOCGIF*` socket
  ioctls they are written against are in (`net_op_ifioctl`,
  `src/modules/net/net.s`); both tools are still FGX-native C against the
  `IFC_*` ABI.  Retires the bespoke `SYS_IFCONFIG`.
- **Socket defects:** apple/fgx#156 (loopback connector has no local port),
  #157 (`bind(2)` leaves TCP and loopback unchecked), #546 (getpeername on
  AF_UNIX answers ENOTCONN).
- **telnetd(8) from 2.11BSD** for real, replacing the reimplementation:
  apple/fgx#540.
- **Multi-NIC (2nd Uthernet II)** -- the ifnet table holds 4 (`IF_MAX`), but
  the W5100 driver is self-mod-bound to one detected slot (`_w5PatchTbl`), so a
  2nd card is detected but undriven.  Needs per-card indexed base addressing +
  ifnet multi-registration + slotscan-all.  Shares the P1 `ifnet` seam.
- **Software IP/ICMP/ARP stack (Backend B)** -- a software path over MACRAW so
  netdump sees ICMP and nothing is intercepted in hardware; keep UDP/TCP on the
  offload.  Plans: `docs/history/plans/2026-07-19-networking-roadmap-scope.md`
  (Track A/B; P4 as a faithful 2.11BSD `netinet` port) and
  `docs/history/plans/2026-07-20-loopback-multinic-ifconfig-caps-scope.md`.
- **IPv6** -- needs the software stack (the W5100 is IPv4-only).
- **AppleTalk driver** -- LocalTalk over the SCC; would own the printer port
  and set `_apTalkPort`, which `serial.mod` already honours.  Big effort
  (LLAP/DDP/NBP, a `protosw` address family); ideally a C module.

### Kernel / memory

- **Multi-bank module container** (deferred 2026-09-20): one `.mod` carrying
  several bank images, so `prodos` + `prodosw` is one `modload`.  `bin/fgxunix`
  (`tools/mkfgxunix.py`) already carries six bank overlays; generalising its
  segment table into FGXM is the likelier route than widening the pre-stage
  window.  Motivate it by atomicity, not module count (apple/fgx#463 was a wild
  store, not a count limit).
- **Classic desk accessories -- the remainder.**  `cda.mod`, `/dev/cda` and
  `loadcda` run DocVue unmodified, with its GS/OS and Loader calls served from
  memory.  **Open:** set the firmware busy flag ($E1/00FF) around kernel
  sections the Desk Manager must not interrupt, and RemoveCDA.  Design:
  `docs/history/plans/2026-09-15-classic-desk-accessories.md`.
- **`fgxmon`, a read-only monitor CDA** -- not started; D1 (memory and vector
  panels) needs no kernel change.  Design:
  `docs/history/plans/2026-09-15-fgxmon-monitor-cda.md`.
- **Sleep-safety callgraph through function pointers** (apple/fgx#459):
  resolve the dispatch tables (`linesw`, the vnodeops/cacheops vectors, module
  import tables) rather than treating every indirect call as able to sleep.
  Sibling: apple/fgx#470 (no checker for the direct-page discipline across a
  KSVC call).
- **Kernel stack headroom:** apple/fgx#264 (arming fcc's kernel stack guard),
  #188 (the `$01FF` firmware bounce window).
- **Module loading should cost no process slot:** apple/fgx#316.
- **spawnx file actions as far pointers:** apple/fgx#304.
- **vfork signal dispatch through the child's table:** apple/fgx#258.
- **Untyped-extern audit:** apple/fgx#293.
- **vmstat statistics not kept:** vmstat reads the 2.11BSD meters through
  sysctl, but disk transfers (dk_xfer), text-cache (xstats), forks
  (forkstat) and name-cache (nchstats) still print as 0 or are omitted; they
  arrive with the counters themselves or with /dev/kmem below.
- **`/dev/kmem` and `nlist(3)` against `/fgxunix`** -- 2.11BSD's own path to
  kernel state, so ps, vmstat, iostat and pstat can port verbatim: a symbol
  table carrying each symbol's bank, a bank-crossing kmem device:
  apple/fgx#538.
- **malloc's arena in Memory Manager memory** (a design record):
  apple/fgx#63.

### Filesystem

- **512-byte block granularity** once a native disk driver lands:
  apple/fgx#397.
- **Permissions gaps:** apple/fgx#421 (directory read permission not enforced
  through `SYS_LISTDIR`), #418 (setrlimit hard limit and utimes privilege
  checks).
- **Mounting a separate image from userland:** on-target newfs(8) and an APM
  writer, apple/fgx#331.
- **mount(8)/umount(8) manual pages:** apple/fgx#354.

### Toolchain / self-host

- **CAMPAIGN (chartered 2026-08-18): fcc lvalue matrix sweep** -- close the
  lvalue / pointer-arithmetic defect class as a class: enumerate every cell of
  (shape x operation x position x leaf type x storage class), close silent
  miscompiles, close the valid-K&R rejection band, then collapse duplicated
  arms onto the uniform walker.  Phase status is not recorded; the rejection
  examples the charter listed no longer appear among
  `docs/fcc-known-issues.md`'s open gaps, so re-measure before resuming.
  Charter:
  [`history/plans/2026-08-18-fcc-lvalue-matrix-sweep.md`](history/plans/2026-08-18-fcc-lvalue-matrix-sweep.md).
- **fcc open gaps** -- `docs/fcc-known-issues.md` "Open gaps" is the queue
  (struct return by value, multi-dim arrays of struct, nested aggregate local
  initializers, >8 macro parameters, and the file-scope absolute-address
  pointer).  Filed: apple/fgx#524 (`q[i] = q[j]` on a struct pointer is
  rejected).
- **Track-2 phase 2: a whole-function / global optimizing backend** on the
  multi-pass AST substrate -- global register allocation, cross-BB
  spill/reload elimination, whole-TU dead-code elimination, inlining.  The
  within-BB backend is complete-at-frontier and its size ceiling was measured
  (`docs/history/2026-06-29-fcc2-p3-spillreload-measurement.md`); unbuilt.
- **Multibank far-pointer oracle follow-on** -- extend
  `toolchain/tests/multibank/` to the non-PHK/PHB bank sources (`_fcc_ptr+2`,
  heap) and the libc/shim caller-buffer population.
- **Runtime oracle coverage:** apple/fgx#392 (samples 240 of 633 fixtures
  against a ProDOS volume ceiling that no longer binds).
- **Self-host `fcc`** (M12) -- see the north star above.

### Audio

- **Kernel sound device** -- today a program claims the DOC with
  `SYS_SOUND_CLAIM` (`include/loader.s`) and programs it directly.  The plan
  is a `/dev/dsp`-style interface with per-fd DOC ownership and auto-silence on
  exit; first tool `beep`.  Open question: apple/fgx#306 (a DOC interrupt
  running user code on the interrupted kernel stack).
- **`libsnd` + `play` + tracker tools** -- wrap the DOC poke surface
  (`tone`/`note_off`/`play_sample`); background music task.

### Graphics / console

- **Phase 2 -- mixed text + pixel regions** -- per-row gfx-mode bitmap, the
  renderer skipping text blit for gfx rows, a lock call + a minimal pixel /
  block-blit surface; line/circle/fill go to a userland `libgfx` later.
- **Scanline-native framebuffer console, Phases 1-4** (Phase 0, scroll
  coalescing, landed): P1 scanline FB core + a `$C02E` beam-counter timer, P2
  split-screen bands, P3 graphics layer, P4 C-conversion of the control logic.
  Spec: `docs/history/plans/2026-06-30-scanline-framebuffer-console-design.md`.
- **Second Sight card bitmap modes** (320x200x8, 640x480) for images.
- **Console defects:** apple/fgx#187
  (two blind border writes), #495 (screensaver).

### Userland / polish

- **Take `secure` off the pty lines.**  `su(1)` is ported (2.11BSD, verbatim),
  but `disk_src/etc/ttys` still marks `ttyp0` and `ttyp1` `secure`, the
  stopgap that let two telnet sessions both be root.  Conventional BSD
  practice is no secure pty line.  Moves with it: `logintest` LT11 and
  `wirecon`'s two-session assertion.
- **`tip`/`cu` re-port onto `select()`** -- tip reads local keys with
  `pollkey()`, which apple/fgx#151 made console-only, so it is inert over
  telnet; it multiplexes the terminal and the line and wants `select()` on
  both (`src/userland/tip/tip.c` says so at its head).
- **A termcap database** -- `tgetent` still answers from baked entries
  (`toolchain/lib/libtermlib_c/libtermlib.c`) and ignores its buffer; reading
  `/etc/termcap` is the BSD end state and changes every caller's buffer size.
- **Wave-4 bsdgames** -- worm and robots are ported; hangman, canfield,
  cribbage, mille, boggle, battlestar remain (atc needs the yacc/lex pregen and
  an async loop rework).
- **Ports owing upstream behaviour:** apple/fgx#540 (telnetd is a
  reimplementation; re-port it), #539 (stty, ed, man, worm and
  robots cut code for features FGX has since gained), #501 (twelve BSD-named
  tools call libfgx where upstream uses a BSD mechanism).
- **Reduce demand** -- vendored ports are rarely tuned for a 64 KB data space;
  elvis's CRUNCH flag reclaimed 21 KB for one `-D`.  Nobody has looked at the
  others.
- Smaller cosmetic/standardization items -- `docs/cosmetic-todo.md`.

---

## Done (condensed -- see CHANGELOG.md for detail)

- **Boot + console** -- two-stage loader; SHR 640-mode console + VT102 layer;
  Toolbox 60 Hz heartbeat (tick + keyboard ring).
- **Kernel** -- monolithic kernel + loadable **FGXM modules** (`Mod_Load`);
  Memory Manager (`Bank_Alloc`/`NewHandle`, per-task DP + stacks); per-task **fd
  tables**; synchronous **signals** (SIGINT/SIGALRM/SIGTSTP/SIGCONT); POSIX
  syscalls via `SYS_TRAMP`; kernel-memory modernization (build-time address
  resolution); **relocatable kernel** -- runs at any MM-assigned bank, `$02` fully
  vacated; **cooperative scheduler + job control** (`_Sys_Yield`, ready/blocked
  queues, `jobs`/`fg`/`bg`/`^Z` + `tcsetpgrp`); **VT100 console + keyboard**
  (CSI handler, arrows/Ctrl as ESC-sequences); **process environment** (envp ABI +
  `getenv`/`export`/`/etc/profile`, T7).
- **Filesystem** -- the root is 2.11BSD UFS through a 4.3BSD-Reno VFS (vnodes,
  namei and the name cache, permissions, links and symlinks, device nodes),
  checked by `fsck` at boot; ProDOS volumes mount through `mount_prodos(8)`,
  read or write; the RAM disk; `df` / `SYS_GETFSSTAT`.
- **Toolchain** -- `fcc` (C90: structs/unions/pointers/multi-level-ptrs/multi-dim/
  longs/argv/static-locals/do-while, **softfloat IEEE-754 `%f`/`%e`/`%g`**,
  **32-bit `printf`**, **function pointers**, **struct/union pointer arithmetic**),
  now with a **multi-pass front end** (whole-TU token vector -> AST, retiring the
  source-replay bug class) and an **optimizing backend** (Stack-IR -> linear-scan
  allocator -> isel, complete-at-frontier); **libc-in-C** (T5-C); `fas`
  (self-hosting on-device assembler), `fgx_ld` (FGX2 multi-bank linker) with
  function-level library GC; in-tree at `toolchain/`; golden suite + runtime
  oracle (incl. the multibank far-pointer oracle); libc + crt0.
- **Userland (C ports)** -- the BSD tool tier, all FGX2/fcc-compiled, MAME-green:
  `grep` (BRE engine), `od`/`hd`, `ed`, `tr`, `sed`, `man(1)` (catman locator at
  `/usr/man/cat<N>`), `more`, `stty`, `stat`, `ps`, `kill`, `ls`, `expr`, `tput`,
  `strings`, `date`/`uname`/`uptime`/`touch`/`time`/`sleep`/`basename`/`dirname`/
  `hostname`/`dmesg`, `tip`/`cu` (serial terminal), `init` (C) -- joining the earlier
  `cat`/`wc`/`head`/`cmp`/`uniq`/`fold`/`cal`/`clear`/`ul`/`rm`/`cp`/`df`/... set.
  **`vi` (elvis)** ships as a first-class tool.  The **hand-asm
  retirement** campaign converted the tool tier to C (last FGX1 hand-asm tools
  `ntpinfo`/`ntpplay` retired).
- **Login stack** (2026-08-04) -- `init(8)` as 2.11BSD's respawn engine driven by
  `/etc/ttys`, plus `getty`, `login`, `passwd` and `halt`, over libc's `ttyent`
  database, `crypt(3)` (a tagged non-DES hash) and `getpass(3)`; `su(1)`.  Design:
  [`history/plans/2026-08-04-login-stack-vc-design.md`](history/plans/2026-08-04-login-stack-vc-design.md).
- **Networking** -- Uthernet II / W5100; offload-agnostic socket seam, now
  extracted into `net.mod` (socket layer + W5100 transport + RX ring out of the
  kernel); **UDP** sockets + `dhclient`; **ICMP** (ping + hardware auto-reply);
  **TCP** client *and* **server** (`connect`/`send`/`recv`/`close`, `listen`/
  `accept` + `echod`); `netdump` MACRAW capture; `ifconfig`/`route`; **slotscan** --
  auto-detect the Uthernet II in any slot; DNS resolver; `select(2)`; connected
  UDP and `getpeername`/`getsockname`; AF_UNIX and syslogd(8); telnetd/inetd.
- **Audio** -- DOC (Ensoniq) bring-up; `ntpplay` IRQ-driven MOD player (placed +
  streamed samples).
- **Time** -- kernel UTC clock (`gettimeofday`/`settimeofday`/`adjtime`), IANA
  time zones through 4.3BSD-Reno's ctime.c, `adjkerntz(8)`, cron(8)/crontab(1).
- **Processes** -- concurrent `fork(2)` (2.11BSD newproc's no-core path, image
  groups), `daemon(3)` forking as upstream's does.
- **TTY** -- BSD's tty layer (clists, discipline, ptys, `/dev/tty`, the serial
  line) in a third kernel bank.
- **Bank-0 residency** -- bank 0 as a cache of task images, NPROC 32, the
  Second Sight card as `ttyv3` with ANSI colour.
- **Memory** -- shared text and the coremap (2.11BSD's resource map, packed
  code banks).
- **Shared libc** -- `libc.so` and friends bound by a user-space binder; the
  pile path removed.
- **Desk accessories** -- `cda.mod`, `loadcda`, DocVue running over `ntpplay`.

---

## How to use this file

When a feature is proposed: if it slots into a campaign or the backlog,
green-light it; if it leapfrogs a dependency, flag it ("easier once X lands").
When a feature surfaces a missing primitive, prefer landing it via the relevant
backlog item over a one-off.  Update this file as work completes -- move items
from backlog -> campaign -> Done, keep each entry to what is still owed, and let
`CHANGELOG.md` carry the commit-level detail.  A defect gets a GitHub issue
and at most a one-line pointer here.  The reasoning and measurements behind a
landed campaign belong in its `docs/history/plans/` record; the narrative this
file used to carry is in
[`history/roadmap-archive-2026-10-11.md`](history/roadmap-archive-2026-10-11.md),
which is the place to look before re-deriving an old decision.
