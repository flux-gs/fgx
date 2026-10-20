# Hand-asm inventory + retirement roadmap (2026-07-11)

Complete catalog of every remaining hand-assembled component in FGX and
the toolchain as of T5-C completion (toolchain `cfd37de8` / FGX
`f7c30ae3`, branch `feat/t5c-libc-in-c`), with a per-item retirement
path: **BSD port** (vendored `examples/2.11BSD` / `examples/netbsd-0-9`
source exists), **C rewrite** (no BSD equivalent; plain fcc C), **C +
inline `__asm`** (hardware/timing-critical loops), or **asm-on-C-libc /
permanent** (stays assembly by design).

Context: T5-C put all of libc (82 exports + printf family) in C.  This
doc is the map of everything that ISN'T C yet.

## 0. Headline numbers

| Region                                   | Lines (asm) | End state |
|------------------------------------------|------------:|-----------|
| Active hand-asm userland tools (26)      |      12,978 | ~0 (ports/rewrites; small __asm islands) |
| STALE .s next to converted C tools       |    ~100,000 | 0 (sweep — already dead) |
| Kernel (`src/kernel/`, 25 files)         |      19,183 | kernel-in-C campaign (T9→) |
| Drivers + modules + boot                 |      25,123 | kernel-in-C campaign |
| Toolchain `lib/libc.s` (register-ABI libc)|      3,182 | 0 (shrinks with each tool conversion) |
| Toolchain runtime/startup/infra          |      ~4,100 | PERMANENT (fcc_runtime, crt0_far, macros) |
| FGX `src/userland/lib/crt0*.s`           |         609 | dies with FGX1 retirement |

## 1. Active hand-asm userland tools (the 26 `build_userbin` entries)

### 1a. BSD PORT — vendored source exists

**Source-tree POLICY (the maintainer, 2026-07-11 — now standing, in
CLAUDE.md): port from 2.11BSD; netbsd-0-9 is ADVISORY-ONLY** (behavior
questions, interface archaeology — never the porting source without a
per-tool ruling from the maintainer, as elvis was).  Three reasons: (1) 2.11BSD
is a 16-bit-int codebase (PDP-11) — it matches fcc's int==16 exactly,
where netbsd-0-9 assumes 32-bit int throughout (the silent-truncation
porting-bug class, cf. the c_stat st_size sign-extend); (2) its K&R
style is fcc's home turf (the ed/sed ports proved the path — sed is
verbatim 2.11BSD); (3) it is sized for small machines.

| Tool | Lines | 2.11BSD source | Notes |
|------|------:|----------------|-------|
| ls      | 831 | `usr/bin/ls`         | biggest daily-use win; scope the dirent libc surface first |
| date    | 267 | `usr/bin/date.c`     | single file; c_time exists; -s (set) needs a settime syscall — scope or drop-with-ASK |
| touch   | 106 | `usr/usr.bin/touch.c`| single file; needs a utime(2)-shape syscall (new small syscall) |
| time    | 799 | `usr/bin/time.c`     | single file; spawnv+waitpid+ticks all exist in C libc |
| dmesg   |  69 | `usr/sbin/dmesg`     | port the FORMATTER; backend = FGX SYS_KLOG read, not /dev/kmem |
| vmstat  | 781 | `usr/ucb/vmstat.c`   | port shape only; backend = FGX kstat syscalls |
| uptime  | 370 | `usr/ucb/w.c` (uptime mode) | needs boottime kernel export; loadavg doesn't exist on FGX — STOP-and-ASK on the display contract |
| tip     | 284 | `usr/usr.bin/tip`    | sgtty(2) already kernel-owned; serial /dev/tty00 held on feat/serial-tty00 |
| cu      | 328 | `usr/old/cu` (or tip's cu mode) | RETIRE into ported tip (tip provides cu) |

Policy reminders for every port: add the man page (`man <tool>` must
work), never silently drop a feature for a missing primitive (STOP,
scope, ASK), validate against host-built reference where practical.

### 1b. NO BSD equivalent — plain C REWRITE (syscall+printf formatters, trivial under the C libc)

| Tool | Lines | Notes |
|------|------:|-------|
| stat     | 943 | stat(1) postdates netbsd-0-9; c_stat does the work now — thin C formatter |
| init     |  81 | FGX init is exec-of-jsh; BSD init's ttys/session model is wrong-shaped — keep tiny, rewrite in C |
| kstat    | 243 | kernel-stats formatter |
| kdiag    | 433 | kernel diagnostics |
| serinfo  | 587 | serial/SCC state dump |
| serstat  | 284 | serial stats |
| ticks    | 136 | SYS_TICKS reader (c_ticks exists) |
| hello    |  63 | demo; rewrite or retire |
| growtest | 152 | test scaffold — join the C test fleet |
| sigtest  | 175 | test scaffold (real signal() exists in C libc now) |

### 1c. NO BSD equivalent — C + inline `__asm` (hardware/timing islands)

| Tool | Lines | Notes |
|------|------:|-------|
| color    | 535 | SHR console palette utility — C over console ioctl/escapes; palette pokes may keep an __asm island |
| font     | 546 | console font loader — C control; font-blit loop as __asm if hot |
| vbldiag  | 428 | VBL timing diagnostic — measurement loop is timing-sensitive → __asm island, C harness |
| doctone  | 243 | DOC/Ensoniq register exerciser — C control + __asm register sequences |
| docirq   | 400 | DOC IRQ diagnostic — IRQ handler stays asm (§6A reentrancy rules), C harness |

### 1d. Sound/IRQ core — asm-on-C-libc, phased

| Tool | Lines | Notes |
|------|------:|-------|
| ntpinfo  | 416 | pure .ntp parser/printer, NO hardware — actually a plain C rewrite (frees fopen/fclose/fread asm engines) |
| ntpplay  | 3,478 | DOC streaming player with sound-IRQ handlers (proven IRQ work) — keep the DOC/IRQ engine asm; rewrite file I/O + control/UI in C; end shape = C tool with an asm playback module |

### 1e. Special

- **fswbig** — DELETED 2026-07-12 (the maintainer).  It was a one-off FS large-
  single-write reproducer (the elvis vi temp-file sparse-block hunt),
  already C but the last tool riding the FGX1 build path; not worth a
  FGX2 flip once the FS bug was resolved.  Source dir + fswbig.json test
  removed.  With it gone, no C tool links FGX1 — H4's FGX1 retirement is
  unblocked on the userland side.  (fswtest, the byte-at-a-time
  companion, stays.)
- **yacc calc/expr** (`build_userbin_yacc`) — host-yacc-generated C;
  not hand-asm.

## 2. ~~STALE .s sweep~~ — CORRECTED 2026-07-11 (same day): NOT stale

The original claim here (~100k lines of dead .s beside converted C
tools) was WRONG.  The H0 audit found those files — jsh.s, ed.s, od.s,
grep.s, … — are **fcc-GENERATED build artifacts** (header: "fcc 0.0 —
generated from <tool>.c"), each individually gitignored and regenerated
every `build_userbin_fgx2_c` run.  `git ls-files` is the honest lens:
the 83 TRACKED userland .s files decompose exactly into the 26 active
hand-asm mains + 57 live support files (per-tool .link.s glue, syscall
stub .s referenced by generated seg0 links, ntpplay's data tables,
crt0s, tput.s).  **There is nothing to sweep.**

What H0 DID find (via the the CI host CI failure): build.sh's MX-flag audit
list was a hardcoded snapshot with the same staleness disease — seven
entries for tools long since flipped to C (fresh CI trees have no such
listings → FileNotFoundError) and TEN hand tools missing entirely.
Fixed: `build_userbin` writes `build/mx_audit.list`; check_mx audits
exactly the manifest.  All 26 hand tools now audited, all clean.

Lesson for this doc's own method: distinguish tracked sources from
generated artifacts before counting "debt" — `git ls-files`, not `ls`.

## 3. Toolchain `lib/` — the libc.s shrink-to-empty path

| File | Lines | Path |
|------|------:|------|
| libc.s | 3,182 | The register-ABI libc for hand-asm callers.  Shrinks as §1 executes.  Load-bearing engines and their release conditions: **pf_ printf engine + libc_args** (dies with the last printf-using hand tool); **fopen/fclose/fread/_libc_FILE_to_fd** (dies when ntpinfo/ntpplay convert); **exit** (crt0 + hand tools); **strerror/tgetent/tgetnum/tgetstr/tgetflag engines** (still JSR'd from the C wrappers — convert to C independently: message table + termcap walk are plain C over libc_data). End state: DELETE. |
| fcc_libc_shims.s | 419 | comments/EQUs only (SYSCALL_* docs + c_strcmp DP EQUs); collapses into docs + libc_c.c once the __asm loops stop using the EQUs |
| libc_data.s | 516 | DATA not code (termcap caps, strerror table, FILE table, stdio far-ptr cells) — stays; candidate to migrate into pile data later |
| crt0.s | 272 | FGX1 startup — dies with FGX1 retirement |
| args.s + args_data.s | 425 | FGX1 argv staging — dies with FGX1 |
| **fcc_runtime.s + _data** | 2,242 | **PERMANENT** — compiler runtime (softfloat, long ops, far-ptr helpers, stack guard); this is what C compiles TO |
| **crt0_far.s** | 477 | **PERMANENT-ish** — FGX2/3 process entry; startup must be asm |
| **macros.s** | 762 | **PERMANENT** — assembler infrastructure |
| FGX `src/userland/lib/crt0.s + crt0_c.s` | 609 | FGX1-only — die with FGX1 retirement |

## 4. Kernel + drivers + modules (44,306 lines) — the kernel-in-C campaign (H5, CHARTERED)

**Chartered as a roadmap phase per the maintainer, 2026-07-11** (previously an
out-of-scope pointer): the userland ports retire the hand-asm *libc*;
the kernel and the modules must follow the same arc to C.  This is the
`architecture-redesign.md` final phase (T9 spike → campaign), gated on
fcc gaps that T5-C did NOT close: interrupt-handler codegen (reentry,
short-M/X windows), DP/bank discipline contracts, kernel segment/ORG
model, and the dispatcher invariants (5 structural contracts).

There is no "port" path for the kernel — the FS and net subsystems are
BSD-informed but FGX-native, so H5 is a rewrite against the SAME
syscall contract, subsystem by subsystem, each rung landing green
through the full MAME suite + kprobe/fgxdebug taps before the next
opens.  2.11BSD stays the ADVISORY reference for interface questions
(the port-source ruling applies to userland, not kernel rewrites).

Sub-phases:

- **H5-0 — T9 spike (the gate-opener):** prove ONE C TU inside the
  KERNEL image.  Deliverables: fcc kernel segment/ORG model (kernel
  assembles at ORG $02, relocated at boot — the C TU must survive
  that), the DP/bank contract for C-in-kernel (D=$B000 kernel DP vs
  fcc's $10-$BB band — resolve or remap), `log.s` (343 lines,
  formatter-shaped, no IRQ) compiled from C and linked in, MAME boot +
  suite green, and a byte-budget report (the kernel sits at ~45KB of a
  55KB one-bank box — C codegen size is a real constraint; measure
  before committing further rungs).
- **H5-1 — kernel libc:** `src/kernel/libc/` (alloc.s Kmalloc/Kfree —
  today's exonerated-but-opaque suspect is exactly why this tier goes
  first — plus string/format helpers) rewritten in C on the H5-0
  model, guard/audit semantics preserved (SYS_MEMINFO stays the
  oracle).
- **H5-2 — dispatch + IPC leaves:** `fst_dispatch.s` (133),
  `net_dispatch.s` (267), `socket.s` (147, glue), `pipe.s` (745).
  Low-IRQ, table-shaped, well-oracled by the existing suite.
- **H5-3 — filesystem:** the ProDOS FST + write-state layer.  The
  recurring "singleton write-state concurrency" bug class and this
  week's it-must-be-the-FS suspicion both argue for getting this
  subsystem out of opaque asm early; crash-safety semantics (task #55
  lineage) are the acceptance tests.
- **H5-4 — net stack:** IPv4/ARP/ICMP/UDP/TCP per the net
  re-architecture design (BSD-shaped, `ifnet` seam).  The W5100
  register driver keeps its asm core; `w5100_patchsites.s` /
  `wavee_bankpatch.s` are GENERATED — not debt.
- **H5-5 — modules to C:** the FGXM **C-module framework** (already
  on the module-framework roadmap) becomes real here: serial, bpf,
  net modules rebuilt as C modules with a thin asm entry veneer.
  The DOC sound-IRQ engine (ntpplay module) stays asm by design.
- **H5-6 — core, last:** `sched.s`, the `syscall.s` dispatcher,
  `loader.s`.  These encode the 5 dispatcher invariants and the
  task-switch DP/bank dance; they move only once H5-0's contracts have
  survived every earlier rung.  IRQ paths (sound, serial SIM, VBL),
  `src/boot/`, and the console render inner loops stay asm
  indefinitely — until fcc grows real interrupt-handler codegen, they
  are cheaper to keep correct than to move.

## 5. Suggested phase order

- **H0 (hygiene) — DONE 2026-07-11:** the "stale-.s sweep" dissolved
  (§2 — generated artifacts, not debt); the real find was the stale
  hardcoded MX-audit list (fixed, manifest-driven); fswbig flip
  deferred (§1e).
- **H1 (BSD ports, user-visible) — COMPLETE 2026-07-12:** ls →
  date/touch/time → stat(C) → dmesg → tip+cu.  Each with man page.
  *tip/cu STATUS 2026-07-12: ★DONE — one C binary (cu = tip's other
  staged name, jsh/sh precedent); the "serial branch permitting" gate
  was stale (feat/serial-tty00 landed to main 2026-06-25, both ports
  live).  FGX-native single poll loop (no fork), pollkey + read/EAGAIN,
  device arg tty00|tty01 (default tty01), ~. ~~ ~? ~> send-file ~<
  capture escapes; libc grew strncat (strncatops pinned).  tip_port /
  cu_port MAME tests green; cu_port needs fresh_nvram (shared Ample
  BRAM had Slot 1 = AppleTalk, which correctly suppresses tty00 — and
  had been making echo/cat_dev_tty00 pass VACUOUSLY via the shell '>'
  creating a regular file; both now fresh_nvram too).  Follow-up same day: the
  "harness can't deliver keys" limit turned out to be a SILENT HARNESS
  REGRESSION — MAME 0.288 removed the natural_keyboard Lua property, so
  every fgxdebug paste had become a no-op (only -autoboot_command text
  got through; kbd_shell_paste was failing).  Fixed by kernel-kbd-ring
  injection (feat/kbd-ring-inject): post_commands now reach a running
  program's pollkey, tip_port/cu_port drive the full ~. escape flow
  headlessly, and tip_rx_diag + serial_feeder.py prove serial RX over a
  null_modem socket.*
  *ls STATUS 2026-07-11: ★WORKS (ls_port green).  The port shook out
  three toolchain-class bugs — fcc struct** stride-2 (struct_id dropped
  by ptr-ptr decls; THE heap-corruption cause, kernel exonerated after
  a wrong kernel-allocator theory), fcc long compound-assign dropping
  the LHS high word (`now += 60` → year branch), and c_ctime's 16-bit
  secs-in-day overflow.  All fixed + fixture-pinned (ppstride,
  longcompound, ctimeops-afternoon, dirchurn restored); full detail in
  docs/fcc-known-issues.md and RESUME-2026-07-11-h1-ls-port.md.*
- **H2 (diagnostics — RESCOPED by the maintainer 2026-07-11, EXECUTED same
  day):** the test/probe tier was DELETED rather than ported (kstat,
  kdiag, serstat, ticks, hello, growtest, sigtest — scaffolding, not
  product); **serinfo** was the one keeper, rewritten as C + __asm
  islands (the port fixed the hand tool's latent 6-word FWEntry frame
  — the manual wants 8).  **init is NOT a diagnostic** (the maintainer): it is
  system software and gets its own careful C-rewrite rung later.
  *init STATUS 2026-07-12: ★DONE — init.c (spawnv/waitpid/halt, parity,
  no respawn) + the real work: the kernel boot block now launches PID 1
  through the spawn-parity FGX3 path (BankList extras, TCB_LibcBank,
  Task_AllocStack from header hint + argv pages, stkfloor DP seed,
  kern-stack + u-area — pid 1 used to run with a NULL SE_UareaPtr —
  and _Loader_StageArgs lays the frame + persists the real DataBank).
  Gates: fast 21/21, runtime 430/430, port battery 9/9, new init_halt
  test covers the wait/halt half.*
  Remaining port-shaped: vmstat/uptime; color/font/vbldiag (C + __asm
  islands) later.
- **H3 (sound tier — RESCOPED by the maintainer 2026-07-12):** doctone/docirq
  DELETED rather than ported (DOC register/IRQ exercisers — probe
  scaffolding, same ruling class as the H2 deletions).  **ntpinfo DONE
  2026-07-12** — ntpinfo.s (15 KB FGX1) → ntpinfo.c (FGX3, byte-identical
  output; test ntpinfo_conrad).  Sidebar: the maintainer flagged fcc's `\033`
  string-escape as a landmine; it was ALREADY working (lex_pp.c G19) —
  stale colortest.c comment, now pinned by tests/M37/strescapes.c, no code
  fix.  Remaining: ntpplay (C tool shell + asm DOC-IRQ playback module —
  the engine stays asm by §6A design; a C+__asm-island rung, not plain C).
- **H4 (libc.s → empty + FGX1 retirement):** strerror/tget* engines to
  C; after H1-H3, pf_ engine + libc_args + fopen/fread/exit engines
  die; then crt0.s/args.s and the `build_userbin` FGX1 path itself.
- **H5 (kernel + modules in C) — CHARTERED 2026-07-11 (the maintainer):** the
  full campaign per §4 (sub-phases H5-0 spike → H5-1 kernel libc →
  H5-2 dispatch/IPC → H5-3 FS → H5-4 net → H5-5 C-modules → H5-6
  core) + architecture-redesign.md.  Opens with the T9 spike (task
  #54); may interleave with late H1/H2 rungs once H5-0's contracts
  hold.

H0–H2 are incremental tool-at-a-time work (each lands green through
the MAME suite alone); H4 falls out mechanically; H5 is the only one
needing new design.
