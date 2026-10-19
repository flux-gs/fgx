# PTY subsystem — implementation plan (2026-07-20)

Executes item #4 of the networking scope
(`2026-07-19-networking-roadmap-scope.md` §4/§5): the **per-tty refactor + a
native pty chardev pair**, the last spine item before telnetd. This is an
implementation plan; the scoping and the telnetd requirements analysis live in
the scope doc and are not repeated.

**Agreed shape (the maintainer, 2026-07-20):** 2 pty pairs; kernel-builtin chardevs (not
a module); BSD naming `/dev/ptyp0`+`/dev/ttyp0`, `/dev/ptyp1`+`/dev/ttyp1`;
select learns chardev readiness by **dispatching the existing `COPS_Poll`
vtable op generically** (not a pty special case). `tty_pty.c` is the
**behavioral spec, not a lift** (it is welded to `linesw[]`/clists/`uio`
FGX lacks — scope doc §4).

**Estimate: 3–4 sessions.** P1 (per-tty refactor) ~1.5–2, P2 (pair driver) ~1,
P3 (select/TIOCPKT) ~0.5, P4 (test+docs) ~0.5.

---

## 1. Grounding (verified 2026-07-20, v1.12.0)

| Fact | Cite |
|---|---|
| One tty only: `NTTY = 1`; entry = FgPgrp + 10-byte sgttyb + 12-byte tchars + 256-byte canon buffer | `include/kernel.s:498,504-545`, `main.s:182-227` |
| Line discipline (cooked gather/erase/kill, CBREAK/RAW, echo) **inlined in `_Sys_Read`** against absolute `_ttyTable+` addresses; key source hardwired `Con_GetKey`, echo hardwired `Con_Write` | `syscall.s:2757-2950` (`@rd_console`, `@rd_gather`, `@rd_rawcbreak`) |
| tty ioctl block hardwired to tty[0], console fds only; recognizes GPGRP/SPGRP/GETP/SETP/SETN/GETC/SETC/GWINSZ | `syscall.s:1930-2026` (`@si_tty`) |
| ^C/^Z consumed by the 60 Hz heartbeat (never reaches the read path), delivered via `_kTtySigReq` → `_Tty_DeliverSig(fg pgrp)`; bg-read SIGTTIN gate in `_Sys_Read` | `toolbox.s:457-466`, `signal.s:153-164,522`, `syscall.s:2776-2783` |
| Chardev registry: 16 slots, 6-op long-ptr vtable (Open/Close/Read/Write/Ioctl/Poll), `_Chardev_RegisterInternal` for kernel builtins; `/dev/null` is the reference vtable | `include/chardev.s:23,71-79`, `chardev.s:59,483-489` |
| `/dev/console` is NOT a chardev (`FCB_FL_CONSOLE` inline path) | `include/fs.s:536`, `syscall.s:2537-2584` |
| Pipe = Kmalloc'd 512-byte ring + head/tail/count, copy engines honor wrap, blocks on `WCHAN_PIPE` — the reusable byte-ring pattern | `pipe.s:95,474-542,609-637`, `include/kernel.s:382-391` |
| Sleep/wake: `_sleep`(chan)/`_wakeup`(chan) broadcast + condition re-check; SEI-test-then-sleep rule; wchans `$FF01..$FF05` in use | `sched.s:380-435`, `include/kernel.s:362-373` |
| select classifier: console = kbd-ring count, socket = `NETOP_SockStatus`, **pipe/chardev/file = hardcoded always-ready (scope cut)**; `COPS_Poll` exists but is never dispatched | `syscall.s:985-1026` (`_Sel_Classify`) |
| **FIONBIO is socket-only** (`SOCK_NB` on the socket record); chardev/console fds have no nonblock bit | `syscall.s:1918,2101-2119,2608`, `include/socket.s:28-29` |
| Only `/dev/null` implements Poll; serial defines the EQU but registers no meaningful Poll handler | `chardev.s:474,489`, `serial.s:73` |
| spawn-on-slave recipe verified: `SYS_POSIX_SPAWNX` file_actions OPEN/CLOSE/DUP2 + `SYS_DUP2` | `process.s:198,361,670-830` |
| SIGCHLD never raised → master-EOF is the teardown signal | scope doc :204-206, `signal.s:849` |
| pty ioctls already declared, unimplemented: `TIOCPKT`(+`TIOCPKT_DATA`/`FLUSHWRITE`), `TIOCGLTC/SLTC`, `TIOCFLUSH` | `toolchain/include/sgtty.h:64-82` |
| Capacity: `FS_MAX_FDS=8`/task; `CHARDEV_MAX=16` (5 used incl. null); modules can't Kmalloc (moot — we're kernel-builtin) | `include/fs.s:282`, `include/chardev.s:23`, `docs/modules.md:164` |

---

## 2. Design

### 2.1 Data structures

- **`NTTY` 1 → 3** (tty0 = console, tty1/tty2 = pty slaves). `_ttyTable`
  becomes a true array; every former absolute `_ttyTable+TTY_x` reference
  becomes `TTY_x,X` off an X-indexed entry base (or a DP long-ptr where the
  path already juggles X). Entry gains one word: **`TTY_Backend`** — $0000 =
  console (key source `Con_GetKey`/`Con_PollKey`, echo `Con_Write`), else the
  pty-pair record offset (key source = pair input ring, echo = pair output
  ring). Two new entries ≈ 2×`TTY_SIZE` (~290 B each) of kernel-bank statics —
  cheap, and consistent with the header's own "future serial line" anticipation
  (`include/kernel.s:494-496`).
- **Pty pair table**: 2 records, Kmalloc'd soft-global via DP long-ptr
  (`_ptyTablePtr`), same pattern as `_pipeTablePtr`/`_cdTablePtr`. Per pair:
  ```
  PTY_Flags      ; MOPEN, SOPEN, PKT, FLUSHPEND
  PTY_TtyIdx     ; owning slave tty (1 or 2)
  PTY_InRing     ; master→slave: ptr/head/tail/count   (256 B ring)
  PTY_OutRing    ; slave→master: ptr/head/tail/count   (256 B ring)
  ```
  Ring engine: lift the `pipe.s` copy/wrap shape (`_Pipe_CopyIn/Out`) as a
  shared helper or a local twin — decide at implementation by size; do NOT
  grow a general clist abstraction (out of scope).
- **`WCHAN_PTY = $FF06`** — one broadcast channel for all pty sleeps
  (ring-empty reads, ring-full writes), consistent with the coarse
  chan-per-class + re-check convention.
- **`FCB_CdFlags EQU FCB_FstPriv+1`, bit 0 = nonblock** — `FCB_Flags` is a
  single byte with ALL EIGHT bits assigned (`include/fs.s:517-536`), so the
  nonblock bit lives in the chardev overlay of `FCB_FstPriv` instead: chardev
  fds use only FstPriv+0 (the chardev idx), leaving +1..+18 free — same
  overlay pattern as `FCB_SockIdx`/`FCB_PipeIdx` (`include/fs.s:508-514`).
  FIONBIO on a chardev fd sets it; pty read/write paths honor it
  (`EWOULDBLOCK` instead of sleep). Sockets keep their existing `SOCK_NB`;
  console-fd FIONBIO stays out of scope.

### 2.2 fd routing

Master and slave are ordinary chardevs (`FCB_FL_CHARDEV`, idx in
`FCB_FstPriv`): 4 registrations (`ptyp0`,`ttyp0`,`ptyp1`,`ttyp1`), minor byte
encodes pair# + side. Slave ops derive the tty entry from
`PTY_TtyIdx`; the `@si_tty` ioctl block becomes reachable from slave chardev
fds (today it is console-only) with X = tty index.

### 2.3 Line discipline over a pty

The refactored cook/cbreak path (P1) runs unchanged for slave reads, with the
per-tty backend supplying bytes from `PTY_InRing` instead of `Con_GetKey`, and
echo appending to `PTY_OutRing` instead of `Con_Write`.

**^C on a pty is in-band** (there is no heartbeat watching a pty): the
byte-source step for pty-backed ttys checks the byte against
`TTY_Tchars.t_intrc`/`t_quitc` when not RAW — on match, discard the byte, set
the per-tty sig request → `_Tty_DeliverSig(TTY_FgPgrp)` (SIGINT/SIGQUIT), and
flush the canon buffer (BSD behavior). This is the scope doc's "per-tty
`FgPgrp` + ^C→SIGINT so a remote ^C interrupts the remote command". The
console tty keeps the heartbeat mechanism untouched.

### 2.4 EOF / hangup matrix

| Event | Effect |
|---|---|
| slave writes | append `PTY_OutRing` (block/EWOULDBLOCK when full), wake `WCHAN_PTY` + select |
| master writes | append `PTY_InRing`, wake; in-band intrc handled at slave byte-source |
| all slave fds closed | master read: drain ring then **EOF (0)** — telnetd's teardown signal; master write: `EIO` |
| master closed | slave read: **EOF**; slave write: `EIO`; wake all sleepers (hangup; no SIGHUP delivery in v1 — jsh exits on read-EOF) |
| both sides closed | pair record + rings reset for reopen |
| master open while MOPEN | `EBUSY` (exclusive master) |

### 2.5 TIOCPKT

Master-side flag per pair. When set, every master read is prefixed with byte 0:
`TIOCPKT_DATA` ($00) normally; `TIOCPKT_FLUSHWRITE` ($02) once after a
`TIOCFLUSH` on the slave discarded pending output. That is the entire v1
surface — telnetd sets PKT unconditionally and skips byte 0 (telnetd.c:389,
568-576); the other TIOCPKT_* bits stay unsent. `TIOCGLTC`/`TIOCSLTC` land as
store/return state (no behavior) so telnet-family `mode()` calls succeed.

### 2.6 select

`_Sel_Classify` chardev arm stops hardcoding ready and **dispatches
`COPS_Poll`** through the existing trampoline. Pty Poll: POLLIN when
(out-ring count ≠ 0 or peer-closed) for the master / (in-ring count ≠ 0 or
hangup) for the slave; POLLOUT when the opposite ring has room. Audit the existing
vtables first: `/dev/null`'s Poll returns **POLLOUT only**
(`chardev.s:474-477`) — dispatching it changes /dev/null from always-ready to
write-ready-only in select, which is *more* correct but is a behavior change
to note; **serial registers no real Poll** — give serial a trivial
RX-ring-count Poll in passing, and fall back to always-ready when a vtable's
Poll slot is absent/null so unaudited devices keep today's behavior. Wake side: pty ring
transitions call the same `_nSelSleepers`-gated `_wakeup(WCHAN_SELECT)` the
kbd/sock sites use (`sched.s:156-185,625`).

---

## 3. Phases & gates

Every phase lands **suite-green** (full MAME fixture run — the console path is
exercised by all 269 fixtures, which is the regression net for P1) and is
individually revertible.

- **P0 — scaffolding (hours).** `NTTY=3` + array-shaped `_ttyTable` + backend
  word, zero behavior change; baseline suite run recorded. Reserve
  `WCHAN_PTY`, `FCB_FL_NONBLK`, pty ioctl EQUs in `include/`.
- **P1a — ioctl by tty index.** `@si_tty` parameterized by X = tty idx
  (console fds → 0); reachable later from slave fds. Gate: suite green
  (sgtty_roundtrip, jsh_c_mode, stty fixtures are the sharp edges).
- **P1b — discipline by tty pointer.** `@rd_console` cook/cbreak path
  parameterized: entry derives tty base, byte-source/echo-sink indirect
  through `TTY_Backend`. Console behavior byte-identical. Gate: suite green +
  a `vt100_*`/`jsh_*` interactive-fixture spot pass.
- **P1c — signals per-tty.** `_Tty_DeliverSig`/`_Tty_CurIsFg`/SIGTTIN gate
  take a tty idx; heartbeat stays console-only. Gate: suite green
  (pgrptest, killtest, jsh job-control fixtures).
- **P2 — the pair driver.** Pair table + rings + 4 registrations + the ops per
  §2.2–2.5 (TIOCPKT included; FIONBIO honored). Gate: new `ptytest` (below)
  passes headless; suite green.
- **P3 — select integration.** Generic `COPS_Poll` dispatch + pty Poll + wake
  sites (+ serial's trivial Poll). Gate: `seltest` extended with a pty case;
  suite green.
- **P4 — tests + docs.** Fixtures below; ROADMAP/scheduler.md/userland-abi.md
  notes; flip the `sgtty.h` "kernel must grow support" comment.

## 4. Test plan

- **`ptytest` (userland, new)** — the zero-network closed loop:
  1. open `/dev/ptyp0`; spawnx `jsh` with file_actions {open `/dev/ttyp0`,
     DUP2 → 0,1,2} (the verified recipe);
  2. master-write `echo PTYOK\n`; assert echo + `PTYOK` + next prompt appear
     in master reads;
  3. enable TIOCPKT; assert byte 0 == TIOCPKT_DATA on the next read;
  4. master-write `\003`; assert the fg command dies (SIGINT path);
  5. master-write `exit\n`; assert master read → EOF (teardown signal);
  6. rc=0. MAME manifest `ptytest.json` asserts the transcript.
- **`seltest` pty case** — select on master: not-ready before slave output,
  ready after, block-and-wake via a jsh child writing.
- **Regression cadence** — full suite after each P1 sub-phase; the 9-test
  interactive sweep (jsh/stty/sgtty/curses) after every kernel edit.

## 5. Risks & coordination

1. **Console-path regression** (P1b is the hot edit). Mitigation: sub-phase
   gates + the fixture net; keep P1b a pure parameterization (no behavior
   change) so diffs stay reviewable.
2. **Preemption P4 collision** — the open blocking-I/O train touches the same
   sleep/wake surface (`ROADMAP.md:114-126`, "fold the `_kYieldReq` kbd
   special-case into the general mechanism"). **Sync with the P4 owner before
   P1 starts**; the pty sleeps follow the same SEI-test-sleep rule either way,
   and `WCHAN_PTY` slots into whatever P4 generalizes.
3. **In-band intrc subtlety** — canon-flush + discard ordering on ^C is easy
   to get half-right; `ptytest` step 4 pins it.
4. **fd budget** — telnetd at 6/8 fds later; nothing to do now, noted.

## 6. Out of scope (follow-ons)

telnetd itself (accept loop + relay + spawn-on-slave, ~1 session); the
socket-layer **loopback backend** (§4b of the scope doc — telnetd's test
vehicle); console-fd FIONBIO honoring; SIGHUP delivery on master close;
`TIOCSWINSZ` on ptys (slave GWINSZ returns the console 80×24 for now);
getty/multi-session anything.

Ledger: `project_fgx_networking`. Cross-refs: the networking scope
(`2026-07-19-networking-roadmap-scope.md` §4/§5), the preemption campaign
(`2026-07-17-preemption-campaign-roadmap.md`, P4).


---

## Execution status (2026-07-21)

All phases landed on `feat/pty`, each suite-gated:

- **P0** scaffolding, **P1a/b/c** per-tty refactor (ioctls / discipline-by-
  pointer / signals), **P2** the pair driver, **P3** select `COPS_Poll`
  dispatch, **P4** the spawn-on-slave closed loop.
- **ptytest** (single-process, 8 stages) + **ptyshell** (the `cat` relay:
  spawn-on-slave, bidirectional data through the cooked discipline, ^D→EOF
  teardown) both pass on target; **seltest** gained a pty readiness case.

Two findings worth carrying to the telnetd work:

1. **General chardev-close bug, fixed here.** The FS chardev-close path called
   the device's `COPS_Close` unconditionally — a spawn-inherited/dup2'd chardev
   fd (shared FCB, refcount ≥ 2) fired device teardown on a non-final close.
   Surfaced as the child's inherited pty master clearing the pair's global
   MOPEN under the parent. Fixed by gating `_Chardev_Close` on `FCB_RefCount < 2`
   (mirrors the pipe path). Latent for serial/bpf too; now correct for all.

2. **jsh can't yet be driven over a pty (telnetd follow-on, NOT a pty gap).**
   jsh's interactive line editor reads the physical console keyboard via
   `SYS_GETKEY`/`waitkey`, not fd 0 — so a jsh on a pty slave writes its prompt
   through the pty (output flows) but reads the real keyboard. telnetd needs a
   shell that reads fd 0: either teach jsh to use its byte-path `read_line()`
   when stdin isn't the console, or run a simpler shell. The pty subsystem is
   proven with `cat` (which does read fd 0) as the honest relay.

**In-band ^C** delivery (t_intrc → SIGINT to the slave's fg pgrp) is implemented
in the discipline byte-source and exercised by the code path, but its end-to-end
signal-delivery assertion is deferred with the jsh-over-pty work (it needs a
foreground pgrp on the slave, which the shell sets via tcsetpgrp).

**Follow-ons (unchanged):** telnetd itself, the socket-layer loopback backend,
jsh-over-pty (item 2), console-fd FIONBIO, SIGHUP-on-hangup.


---

## jsh-over-pty (2026-07-21) — partial

Follow-on toward telnetd: teach jsh to read fd 0 over a pty instead of the
physical console keyboard.

**Done:**
- **`TIOCISCONS` ioctl** (kernel): `*arg = 1` iff the fd is the physical console
  (tty[0]).  Cheap — the shared `@si_ttyX` block already has X=0 only for the
  console.  jsh `#define`s it locally (no toolchain change).
- **jsh input path is console-aware**: `read_line_edit()` (SYS_GETKEY editor)
  only when `stdin_is_console()`, else `read_line()` (plain fd-0 byte reads).
  History load/save gated on the console too.  Over a pty jsh now reads fd 0 —
  demonstrable: the cooked discipline echoes jsh's typed command back to the
  master, which only happens when jsh actually reads the slave.
- jsh runs commands driven over the pty (`echo` output relayed back, prompts
  reprinted) — verified interactively via ptyshell-driving-jsh.

**Both remaining bugs are now fixed (2026-07-21):**
1. **Blocking byte-at-a-time cooked read over a pty — ★FIXED 2026-07-21.**
   Root cause: the SYS_READ working set (`_Sys_RdRem`, `_Sys_BytesRead`,
   `_Sys_CallerBank`) lives in ABSOLUTE kernel cells, not CPU registers, so the
   context switch does NOT save them.  When a pty slave read blocks mid-gather
   (`_Tty_GetByte` `_sleep`, empty InRing) and the DRIVING task's own `read()`
   runs, it overwrites those globals; on wake the drain used the other task's
   read state.  A single console never had two concurrent readers, so the bug
   was pty-only.  Fix: `_Tty_GetByte` saves that working set on the stack at
   entry and restores it at a single exit (all arms stage the key in
   `_ptyGbByte`); `_kTtyRdPtr` stays saved around each internal sleep since the
   pty arm needs it immediately after.  jsh now runs a full session over a pty
   (ptyshell drives real jsh: prompt, two commands, ^D->exit->EOF).
2. **Pair 1 (ptyp1/ttyp1) cooked read — ★FIXED 2026-07-21.**  Root cause: a
   Merlin operator-precedence trap in the slave-read detour.  Merlin32 has NO
   precedence and evaluates left-to-right, so `#_ttyTable+TTY_SIZE*2` assembled
   as `(_ttyTable+TTY_SIZE)*2` — a wild address — instead of
   `_ttyTable + 2*TTY_SIZE` (tty[2]).  So the pair-1 detour pointed the
   discipline at garbage; pair 0 (`#_ttyTable+TTY_SIZE`, no `*2`) was unaffected.
   Fix: `#_ttyTable+TTY_SIZE+TTY_SIZE`.  (The ring-helper 16-bit-index fix was a
   real but separate correctness improvement.)  ptytest PT9 now exercises
   byte-at-a-time cooked reads on BOTH pairs.

The P4 fixture is now **real jsh driven over a pty** (ptyshell) — the actual
telnetd session shape.  telnetd still wants pair-1 fixed (item 2) if it uses the
second pair, plus its own accept loop + relay + the socket-layer loopback.
